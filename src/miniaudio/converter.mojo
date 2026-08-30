"""Idiomatic converter API (Layer 3).

Three RAII wrappers over miniaudio's conversion objects:

- `Resampler` over ma_resampler — sample-rate conversion.
- `ChannelConverter` over ma_channel_converter — channel count / channel map.
- `DataConverter` over ma_data_converter — format, channels and rate in one
  pipeline.

All three are pure DSP: no device, engine, or file is involved. Each can be
built either way miniaudio offers — `preallocated=True` routes init through the
`get_heap_size` + `init_preallocated` pair with a shim-owned working heap
instead of letting miniaudio allocate one. `__deinit__` uninits either shape.

`Resampler.process` and `DataConverter.process` return a `ConversionResult`:
the converted frames plus how many input frames were actually consumed, because
a rate change means those two numbers differ. `ChannelConverter.process` keeps
the frame count and just returns the frames.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.converter_raw as raw


@fieldwise_init
struct ResampleAlgorithm(ImplicitlyCopyable, Movable, Equatable):
    """Resampling algorithm. Codes match miniaudio's ma_resample_algorithm."""

    var code: Int

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime RESAMPLE_ALGORITHM_LINEAR = ResampleAlgorithm(0)
comptime RESAMPLE_ALGORITHM_CUSTOM = ResampleAlgorithm(1)


@fieldwise_init
struct ChannelMixMode(ImplicitlyCopyable, Movable, Equatable):
    """Channel mixing mode. Codes match miniaudio's ma_channel_mix_mode."""

    var code: Int

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime CHANNEL_MIX_MODE_RECTANGULAR = ChannelMixMode(0)
comptime CHANNEL_MIX_MODE_SIMPLE = ChannelMixMode(1)
comptime CHANNEL_MIX_MODE_CUSTOM_WEIGHTS = ChannelMixMode(2)


@fieldwise_init
struct ConversionResult(Movable):
    """Converted frames plus the input frame count the converter consumed."""

    var frames_consumed: UInt64
    var frames: List[Float32]


struct Resampler(Movable):
    """Sample-rate converter (RAII). Owns its shim handle; uninits on drop."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib],
        *,
        sample_rate_in: UInt32,
        sample_rate_out: UInt32,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        algorithm: ResampleAlgorithm = RESAMPLE_ALGORITHM_LINEAR,
    ) raises -> UInt64:
        """Working-heap size for this configuration, without building anything."""
        var rc = raw.resampler_get_heap_size(
            lib[], format.code, channels, sample_rate_in, sample_rate_out, algorithm.code
        )
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("resampler heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        sample_rate_in: UInt32,
        sample_rate_out: UInt32,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        algorithm: ResampleAlgorithm = RESAMPLE_ALGORITHM_LINEAR,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.resampler_alloc(lib[])
        if ptr == null_handle():
            raise Error("resampler_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.resampler_init_preallocated(
                lib[], ptr, format.code, channels, sample_rate_in, sample_rate_out,
                algorithm.code,
            )
        else:
            code = raw.resampler_init(
                lib[], ptr, format.code, channels, sample_rate_in, sample_rate_out,
                algorithm.code,
            )
        if code != MA_SUCCESS:
            raw.resampler_free(lib[], ptr)
            raise Error(lib[].describe("resampler init failed", code))
        return Self(lib.copy(), ptr, channels)

    def process(
        mut self, input: List[Float32], max_output_frames: UInt64
    ) raises -> ConversionResult:
        """Convert `input`, producing at most max_output_frames frames."""
        var input_frames = UInt64(len(input)) // UInt64(self._channels)
        var samples = Int(max_output_frames) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.resampler_process(
            self._lib[], self._ptr, input, input_frames, buf, max_output_frames
        )
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("resampler process failed", rc.result))
        buf.resize(Int(rc.frames_out) * Int(self._channels), Float32(0))
        return ConversionResult(rc.frames_in, buf^)

    def set_rate(mut self, sample_rate_in: UInt32, sample_rate_out: UInt32) raises:
        var code = raw.resampler_set_rate(
            self._lib[], self._ptr, sample_rate_in, sample_rate_out
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("resampler set_rate failed", code))

    def set_rate_ratio(mut self, ratio: Float32) raises:
        """Input rate as a multiple of the output rate (miniaudio's ratioInOut).

        A ratio of 2.0 therefore halves the sample rate, not doubles it.
        """
        var code = raw.resampler_set_rate_ratio(self._lib[], self._ptr, ratio)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("resampler set_rate_ratio failed", code))

    def input_latency(self) raises -> UInt64:
        var rc = raw.resampler_get_input_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resampler input latency failed", rc.result)
            )
        return rc.value

    def output_latency(self) raises -> UInt64:
        var rc = raw.resampler_get_output_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resampler output latency failed", rc.result)
            )
        return rc.value

    def required_input_frames(self, output_frame_count: UInt64) raises -> UInt64:
        """Input frames needed to produce output_frame_count output frames."""
        var rc = raw.resampler_get_required_input_frame_count(
            self._lib[], self._ptr, output_frame_count
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resampler required input failed", rc.result)
            )
        return rc.value

    def expected_output_frames(self, input_frame_count: UInt64) raises -> UInt64:
        """Output frames input_frame_count input frames will produce."""
        var rc = raw.resampler_get_expected_output_frame_count(
            self._lib[], self._ptr, input_frame_count
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resampler expected output failed", rc.result)
            )
        return rc.value

    def reset(mut self) raises:
        """Clear the filter state, as if no frames had been processed."""
        var code = raw.resampler_reset(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("resampler reset failed", code))

    def uninit(mut self) raises:
        """Release the converter early; the handle stays valid but empty."""
        var code = raw.resampler_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("resampler uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.resampler_free(self._lib[], self._ptr)


struct ChannelConverter(Movable):
    """Channel count / channel map converter (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels_in: UInt32
    var _channels_out: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels_in: UInt32,
        channels_out: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels_in = channels_in
        self._channels_out = channels_out

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib],
        *,
        channels_in: UInt32,
        channels_out: UInt32,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        mix_mode: ChannelMixMode = CHANNEL_MIX_MODE_RECTANGULAR,
    ) raises -> UInt64:
        var rc = raw.channel_converter_get_heap_size(
            lib[], format.code, channels_in, channels_out, mix_mode.code
        )
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("channel converter heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels_in: UInt32,
        channels_out: UInt32,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        mix_mode: ChannelMixMode = CHANNEL_MIX_MODE_RECTANGULAR,
        preallocated: Bool = False,
    ) raises -> Self:
        """Channel maps default to miniaudio's standard map for each count."""
        var ptr = raw.channel_converter_alloc(lib[])
        if ptr == null_handle():
            raise Error("channel_converter_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.channel_converter_init_preallocated(
                lib[], ptr, format.code, channels_in, channels_out, mix_mode.code
            )
        else:
            code = raw.channel_converter_init(
                lib[], ptr, format.code, channels_in, channels_out, mix_mode.code
            )
        if code != MA_SUCCESS:
            raw.channel_converter_free(lib[], ptr)
            raise Error(lib[].describe("channel converter init failed", code))
        return Self(lib.copy(), ptr, channels_in, channels_out)

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Convert every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels_in)
        var samples = Int(frame_count) * Int(self._channels_out)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var code = raw.channel_converter_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("channel converter process failed", code)
            )
        return buf^

    def input_channel_map(self) raises -> List[UInt8]:
        var rc = raw.channel_converter_get_input_channel_map(
            self._lib[], self._ptr, self._channels_in
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("channel converter input map failed", rc.result)
            )
        return rc.value.copy()

    def output_channel_map(self) raises -> List[UInt8]:
        var rc = raw.channel_converter_get_output_channel_map(
            self._lib[], self._ptr, self._channels_out
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("channel converter output map failed", rc.result)
            )
        return rc.value.copy()

    def uninit(mut self) raises:
        """Release the converter early; the handle stays valid but empty."""
        var code = raw.channel_converter_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("channel converter uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.channel_converter_free(self._lib[], self._ptr)


struct DataConverter(Movable):
    """Format + channels + rate conversion in one pipeline (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels_in: UInt32
    var _channels_out: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels_in: UInt32,
        channels_out: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels_in = channels_in
        self._channels_out = channels_out

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib],
        *,
        sample_rate_in: UInt32,
        sample_rate_out: UInt32,
        channels_in: UInt32 = 1,
        channels_out: UInt32 = 1,
        format_in: SampleFormat = SAMPLE_FORMAT_F32,
        format_out: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        var rc = raw.data_converter_get_heap_size(
            lib[], format_in.code, format_out.code, channels_in, channels_out,
            sample_rate_in, sample_rate_out,
        )
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("data converter heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        sample_rate_in: UInt32,
        sample_rate_out: UInt32,
        channels_in: UInt32 = 1,
        channels_out: UInt32 = 1,
        format_in: SampleFormat = SAMPLE_FORMAT_F32,
        format_out: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        var ptr = raw.data_converter_alloc(lib[])
        if ptr == null_handle():
            raise Error("data_converter_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.data_converter_init_preallocated(
                lib[], ptr, format_in.code, format_out.code, channels_in,
                channels_out, sample_rate_in, sample_rate_out,
            )
        else:
            code = raw.data_converter_init(
                lib[], ptr, format_in.code, format_out.code, channels_in,
                channels_out, sample_rate_in, sample_rate_out,
            )
        if code != MA_SUCCESS:
            raw.data_converter_free(lib[], ptr)
            raise Error(lib[].describe("data converter init failed", code))
        return Self(lib.copy(), ptr, channels_in, channels_out)

    @staticmethod
    def create_default(
        lib: ArcPointer[MaLib],
        *,
        sample_rate: UInt32,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """Built from miniaudio's default config — a pass-through converter."""
        var ptr = raw.data_converter_alloc(lib[])
        if ptr == null_handle():
            raise Error("data_converter_alloc failed (out of memory)")
        var code = raw.data_converter_init_default(
            lib[], ptr, format.code, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.data_converter_free(lib[], ptr)
            raise Error(lib[].describe("data converter default init failed", code))
        return Self(lib.copy(), ptr, channels, channels)

    def process(
        mut self, input: List[Float32], max_output_frames: UInt64
    ) raises -> ConversionResult:
        """Convert `input`, producing at most max_output_frames frames."""
        var input_frames = UInt64(len(input)) // UInt64(self._channels_in)
        var samples = Int(max_output_frames) * Int(self._channels_out)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.data_converter_process(
            self._lib[], self._ptr, input, input_frames, buf, max_output_frames
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter process failed", rc.result)
            )
        buf.resize(Int(rc.frames_out) * Int(self._channels_out), Float32(0))
        return ConversionResult(rc.frames_in, buf^)

    def set_rate(mut self, sample_rate_in: UInt32, sample_rate_out: UInt32) raises:
        var code = raw.data_converter_set_rate(
            self._lib[], self._ptr, sample_rate_in, sample_rate_out
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data converter set_rate failed", code))

    def set_rate_ratio(mut self, ratio: Float32) raises:
        var code = raw.data_converter_set_rate_ratio(self._lib[], self._ptr, ratio)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter set_rate_ratio failed", code)
            )

    def input_latency(self) raises -> UInt64:
        var rc = raw.data_converter_get_input_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter input latency failed", rc.result)
            )
        return rc.value

    def output_latency(self) raises -> UInt64:
        var rc = raw.data_converter_get_output_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter output latency failed", rc.result)
            )
        return rc.value

    def required_input_frames(self, output_frame_count: UInt64) raises -> UInt64:
        var rc = raw.data_converter_get_required_input_frame_count(
            self._lib[], self._ptr, output_frame_count
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter required input failed", rc.result)
            )
        return rc.value

    def expected_output_frames(self, input_frame_count: UInt64) raises -> UInt64:
        var rc = raw.data_converter_get_expected_output_frame_count(
            self._lib[], self._ptr, input_frame_count
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter expected output failed", rc.result)
            )
        return rc.value

    def input_channel_map(self) raises -> List[UInt8]:
        var rc = raw.data_converter_get_input_channel_map(
            self._lib[], self._ptr, self._channels_in
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter input map failed", rc.result)
            )
        return rc.value.copy()

    def output_channel_map(self) raises -> List[UInt8]:
        var rc = raw.data_converter_get_output_channel_map(
            self._lib[], self._ptr, self._channels_out
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data converter output map failed", rc.result)
            )
        return rc.value.copy()

    def reset(mut self) raises:
        """Clear the pipeline's resampler state.

        Note that in miniaudio 0.11.25 this does *not* restore a cold pipeline:
        a converter that has been reset produces different first frames from a
        freshly built one, because the resampler's low-pass state is not put
        back the way init leaves it. Rebuild the converter when bit-identical
        restarts matter. `Resampler.reset` does not have this problem.
        """
        var code = raw.data_converter_reset(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data converter reset failed", code))

    def uninit(mut self) raises:
        """Release the converter early; the handle stays valid but empty."""
        var code = raw.data_converter_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data converter uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.data_converter_free(self._lib[], self._ptr)
