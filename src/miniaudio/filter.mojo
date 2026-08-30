"""Idiomatic filter API (Layer 3).

RAII wrappers over miniaudio's biquad-derived filter family. Every one of them
has the same shape, because miniaudio's do:

    var f = Lpf2.create(lib, cutoff=1000.0)
    var filtered = f.process(frames)

`create` takes the filter's tuning as keyword arguments and, like the
converters, accepts `preallocated=True` to route init through miniaudio's
`get_heap_size` + `init_preallocated` pair with a shim-owned working heap
instead of letting miniaudio allocate one. `retune` re-tunes a live filter in
place, keeping its running state; `clear_cache` drops that state while keeping
the tuning (only the filters miniaudio gives a clear_cache to have one).
`__deinit__` uninits either init shape.

Filtering is out-of-place and never changes the frame count.

The `*Node` types are the same filters as node-graph nodes. They attach to the
graph belonging to an `Engine`, and keep that engine alive for as long as the
node exists.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.engine import Engine
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.filter_raw as raw


struct Biquad(Movable):
    """A raw biquad, configured directly by its six coefficients."""

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
        b0: Float64,
        b1: Float64,
        b2: Float64,
        a0: Float64,
        a1: Float64,
        a2: Float64,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.biquad_get_heap_size(lib[], format.code, channels, b0, b1, b2, a0, a1, a2)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("biquad heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        b0: Float64,
        b1: Float64,
        b2: Float64,
        a0: Float64,
        a1: Float64,
        a2: Float64,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.biquad_alloc(lib[])
        if ptr == null_handle():
            raise Error("biquad_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.biquad_init_preallocated(lib[], ptr, format.code, channels, b0, b1, b2, a0, a1, a2)
        else:
            code = raw.biquad_init(lib[], ptr, format.code, channels, b0, b1, b2, a0, a1, a2)
        if code != MA_SUCCESS:
            raw.biquad_free(lib[], ptr)
            raise Error(lib[].describe("biquad init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        b0: Float64,
        b1: Float64,
        b2: Float64,
        a0: Float64,
        a1: Float64,
        a2: Float64,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.biquad_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            b0, b1, b2, a0, a1, a2,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.biquad_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.biquad_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad latency failed", rc.result))
        return rc.value

    def clear_cache(mut self) raises:
        """Drop the running state, keeping the tuning."""
        var code = raw.biquad_clear_cache(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad clear_cache failed", code))

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.biquad_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.biquad_free(self._lib[], self._ptr)


struct Lpf1(Movable):
    """A first-order low-pass filter."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.lpf1_get_heap_size(lib[], format.code, channels, sample_rate, cutoff)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("lpf1 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.lpf1_alloc(lib[])
        if ptr == null_handle():
            raise Error("lpf1_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.lpf1_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff)
        else:
            code = raw.lpf1_init(lib[], ptr, format.code, channels, sample_rate, cutoff)
        if code != MA_SUCCESS:
            raw.lpf1_free(lib[], ptr)
            raise Error(lib[].describe("lpf1 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.lpf1_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf1 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.lpf1_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf1 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.lpf1_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf1 latency failed", rc.result))
        return rc.value

    def clear_cache(mut self) raises:
        """Drop the running state, keeping the tuning."""
        var code = raw.lpf1_clear_cache(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf1 clear_cache failed", code))

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.lpf1_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf1 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.lpf1_free(self._lib[], self._ptr)


struct Hpf1(Movable):
    """A first-order high-pass filter."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.hpf1_get_heap_size(lib[], format.code, channels, sample_rate, cutoff)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("hpf1 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.hpf1_alloc(lib[])
        if ptr == null_handle():
            raise Error("hpf1_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.hpf1_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff)
        else:
            code = raw.hpf1_init(lib[], ptr, format.code, channels, sample_rate, cutoff)
        if code != MA_SUCCESS:
            raw.hpf1_free(lib[], ptr)
            raise Error(lib[].describe("hpf1 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.hpf1_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf1 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.hpf1_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf1 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.hpf1_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf1 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.hpf1_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf1 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hpf1_free(self._lib[], self._ptr)


struct Lpf2(Movable):
    """A second-order low-pass filter."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.lpf2_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, q)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("lpf2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.lpf2_alloc(lib[])
        if ptr == null_handle():
            raise Error("lpf2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.lpf2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        else:
            code = raw.lpf2_init(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        if code != MA_SUCCESS:
            raw.lpf2_free(lib[], ptr)
            raise Error(lib[].describe("lpf2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.lpf2_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff, q,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.lpf2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.lpf2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf2 latency failed", rc.result))
        return rc.value

    def clear_cache(mut self) raises:
        """Drop the running state, keeping the tuning."""
        var code = raw.lpf2_clear_cache(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf2 clear_cache failed", code))

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.lpf2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.lpf2_free(self._lib[], self._ptr)


struct Hpf2(Movable):
    """A second-order high-pass filter."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.hpf2_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, q)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("hpf2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.hpf2_alloc(lib[])
        if ptr == null_handle():
            raise Error("hpf2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.hpf2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        else:
            code = raw.hpf2_init(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        if code != MA_SUCCESS:
            raw.hpf2_free(lib[], ptr)
            raise Error(lib[].describe("hpf2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.hpf2_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff, q,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.hpf2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.hpf2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.hpf2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hpf2_free(self._lib[], self._ptr)


struct Lpf(Movable):
    """A low-pass filter of arbitrary order, stacked from first- and second-order blocks."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.lpf_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, order)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("lpf heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.lpf_alloc(lib[])
        if ptr == null_handle():
            raise Error("lpf_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.lpf_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        else:
            code = raw.lpf_init(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.lpf_free(lib[], ptr)
            raise Error(lib[].describe("lpf init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.lpf_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff, order,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.lpf_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.lpf_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf latency failed", rc.result))
        return rc.value

    def clear_cache(mut self) raises:
        """Drop the running state, keeping the tuning."""
        var code = raw.lpf_clear_cache(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf clear_cache failed", code))

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.lpf_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.lpf_free(self._lib[], self._ptr)


struct Hpf(Movable):
    """A high-pass filter of arbitrary order, stacked from first- and second-order blocks."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.hpf_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, order)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("hpf heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.hpf_alloc(lib[])
        if ptr == null_handle():
            raise Error("hpf_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.hpf_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        else:
            code = raw.hpf_init(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.hpf_free(lib[], ptr)
            raise Error(lib[].describe("hpf init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.hpf_reinit(
            self._lib[], self._ptr, format.code, self._channels,
            sample_rate, cutoff, order,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.hpf_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.hpf_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.hpf_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hpf_free(self._lib[], self._ptr)


struct BiquadNode(Movable):
    """A biquad living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        b0: Float32,
        b1: Float32,
        b2: Float32,
        a0: Float32,
        a1: Float32,
        a2: Float32,
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.biquad_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("biquad_node_alloc failed (out of memory)")

        var code = raw.biquad_node_init(lib[], ptr, engine[]._ptr, channels, b0, b1, b2, a0, a1, a2)
        if code != MA_SUCCESS:
            raw.biquad_node_free(lib[], ptr)
            raise Error(lib[].describe("biquad_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        b0: Float64,
        b1: Float64,
        b2: Float64,
        a0: Float64,
        a1: Float64,
        a2: Float64,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.biquad_node_reinit(
            self._lib[], self._ptr, format.code, self._channels, b0, b1, b2, a0, a1, a2,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.biquad_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("biquad_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.biquad_node_free(self._lib[], self._ptr)


struct LpfNode(Movable):
    """A compound low-pass filter living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.lpf_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("lpf_node_alloc failed (out of memory)")

        var code = raw.lpf_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.lpf_node_free(lib[], ptr)
            raise Error(lib[].describe("lpf_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.lpf_node_reinit(
            self._lib[], self._ptr, format.code, self._channels, sample_rate, cutoff, order,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.lpf_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("lpf_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.lpf_node_free(self._lib[], self._ptr)


struct HpfNode(Movable):
    """A compound high-pass filter living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.hpf_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("hpf_node_alloc failed (out of memory)")

        var code = raw.hpf_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.hpf_node_free(lib[], ptr)
            raise Error(lib[].describe("hpf_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.hpf_node_reinit(
            self._lib[], self._ptr, format.code, self._channels, sample_rate, cutoff, order,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.hpf_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hpf_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hpf_node_free(self._lib[], self._ptr)


struct Bpf2(Movable):
    """A second-order band-pass filter."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.bpf2_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, q)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("bpf2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.bpf2_alloc(lib[])
        if ptr == null_handle():
            raise Error("bpf2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.bpf2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        else:
            code = raw.bpf2_init(lib[], ptr, format.code, channels, sample_rate, cutoff, q)
        if code != MA_SUCCESS:
            raw.bpf2_free(lib[], ptr)
            raise Error(lib[].describe("bpf2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.bpf2_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, cutoff, q)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.bpf2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.bpf2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.bpf2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.bpf2_free(self._lib[], self._ptr)


struct Bpf(Movable):
    """A band-pass filter of arbitrary order."""

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
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.bpf_get_heap_size(lib[], format.code, channels, sample_rate, cutoff, order)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("bpf heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.bpf_alloc(lib[])
        if ptr == null_handle():
            raise Error("bpf_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.bpf_init_preallocated(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        else:
            code = raw.bpf_init(lib[], ptr, format.code, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.bpf_free(lib[], ptr)
            raise Error(lib[].describe("bpf init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.bpf_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.bpf_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.bpf_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.bpf_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.bpf_free(self._lib[], self._ptr)


struct Notch2(Movable):
    """A second-order notch: `frequency` is removed, `q` sets how narrowly."""

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
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.notch2_get_heap_size(lib[], format.code, channels, sample_rate, q, frequency)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("notch2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.notch2_alloc(lib[])
        if ptr == null_handle():
            raise Error("notch2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.notch2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, q, frequency)
        else:
            code = raw.notch2_init(lib[], ptr, format.code, channels, sample_rate, q, frequency)
        if code != MA_SUCCESS:
            raw.notch2_free(lib[], ptr)
            raise Error(lib[].describe("notch2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.notch2_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, q, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("notch2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.notch2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("notch2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.notch2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("notch2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.notch2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("notch2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.notch2_free(self._lib[], self._ptr)


struct Peak2(Movable):
    """A peaking EQ band: `gain_db` applied around `frequency`."""

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
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.peak2_get_heap_size(lib[], format.code, channels, sample_rate, gain_db, q, frequency)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("peak2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.peak2_alloc(lib[])
        if ptr == null_handle():
            raise Error("peak2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.peak2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, gain_db, q, frequency)
        else:
            code = raw.peak2_init(lib[], ptr, format.code, channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raw.peak2_free(lib[], ptr)
            raise Error(lib[].describe("peak2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.peak2_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("peak2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.peak2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("peak2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.peak2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("peak2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.peak2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("peak2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.peak2_free(self._lib[], self._ptr)


struct Loshelf2(Movable):
    """A low shelf: `gain_db` applied below `frequency`."""

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
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.loshelf2_get_heap_size(lib[], format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("loshelf2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.loshelf2_alloc(lib[])
        if ptr == null_handle():
            raise Error("loshelf2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.loshelf2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        else:
            code = raw.loshelf2_init(lib[], ptr, format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raw.loshelf2_free(lib[], ptr)
            raise Error(lib[].describe("loshelf2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.loshelf2_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.loshelf2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.loshelf2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.loshelf2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.loshelf2_free(self._lib[], self._ptr)


struct Hishelf2(Movable):
    """A high shelf: `gain_db` applied above `frequency`."""

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
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> UInt64:
        """Working-heap size for this tuning, without building the filter."""
        var rc = raw.hishelf2_get_heap_size(lib[], format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("hishelf2 heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.hishelf2_alloc(lib[])
        if ptr == null_handle():
            raise Error("hishelf2_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.hishelf2_init_preallocated(lib[], ptr, format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        else:
            code = raw.hishelf2_init(lib[], ptr, format.code, channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raw.hishelf2_free(lib[], ptr)
            raise Error(lib[].describe("hishelf2 init failed", code))
        return Self(lib.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune in place, keeping the filter's running state."""
        var code = raw.hishelf2_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf2 retune failed", code))

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Filter every frame in `input`; the frame count is unchanged."""
        var frame_count = UInt64(len(input)) // UInt64(self._channels)
        var buf = List[Float32](capacity=len(input))
        buf.resize(len(input), Float32(0))

        var code = raw.hishelf2_process(
            self._lib[], self._ptr, buf, input, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf2 process failed", code))
        return buf^

    def latency(self) raises -> UInt32:
        """Filter latency in frames."""
        var rc = raw.hishelf2_get_latency(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf2 latency failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release the filter early; the handle stays valid but empty."""
        var code = raw.hishelf2_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf2 uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hishelf2_free(self._lib[], self._ptr)


struct BpfNode(Movable):
    """A band-pass filter living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.bpf_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("bpf_node_alloc failed (out of memory)")

        var code = raw.bpf_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raw.bpf_node_free(lib[], ptr)
            raise Error(lib[].describe("bpf_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        cutoff: Float64,
        sample_rate: UInt32 = UInt32(48000),
        order: UInt32 = UInt32(2),
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.bpf_node_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, cutoff, order)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.bpf_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("bpf_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.bpf_node_free(self._lib[], self._ptr)


struct NotchNode(Movable):
    """A notch filter living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.notch_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("notch_node_alloc failed (out of memory)")

        var code = raw.notch_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, q, frequency)
        if code != MA_SUCCESS:
            raw.notch_node_free(lib[], ptr)
            raise Error(lib[].describe("notch_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.notch_node_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, q, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("notch_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.notch_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("notch_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.notch_node_free(self._lib[], self._ptr)


struct PeakNode(Movable):
    """A peaking EQ band living in an engine's node graph."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.peak_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("peak_node_alloc failed (out of memory)")

        var code = raw.peak_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raw.peak_node_free(lib[], ptr)
            raise Error(lib[].describe("peak_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.peak_node_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("peak_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.peak_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("peak_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.peak_node_free(self._lib[], self._ptr)


struct LoshelfNode(Movable):
    """A low shelf living in an engine's node graph.

    miniaudio tunes the shelf *nodes* by q where the standalone shelf filters
    take a shelf slope, so `create` takes `q` and `retune` takes `shelf_slope`."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.loshelf_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("loshelf_node_alloc failed (out of memory)")

        var code = raw.loshelf_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raw.loshelf_node_free(lib[], ptr)
            raise Error(lib[].describe("loshelf_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.loshelf_node_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.loshelf_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("loshelf_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.loshelf_node_free(self._lib[], self._ptr)


struct HishelfNode(Movable):
    """A high shelf living in an engine's node graph.

    miniaudio tunes the shelf *nodes* by q where the standalone shelf filters
    take a shelf slope, so `create` takes `q` and `retune` takes `shelf_slope`."""

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        engine: ArcPointer[Engine],
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        q: Float64 = 0.707107,
        channels: UInt32 = 2,
    ) raises -> Self:
        """Attach a new node to the graph belonging to `engine`."""
        var lib = engine[]._lib.copy()
        var ptr = raw.hishelf_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("hishelf_node_alloc failed (out of memory)")

        var code = raw.hishelf_node_init(lib[], ptr, engine[]._ptr, channels, sample_rate, gain_db, q, frequency)
        if code != MA_SUCCESS:
            raw.hishelf_node_free(lib[], ptr)
            raise Error(lib[].describe("hishelf_node init failed", code))
        return Self(lib^, engine.copy(), ptr, channels)

    def retune(
        mut self,
        *,
        gain_db: Float64,
        frequency: Float64,
        sample_rate: UInt32 = UInt32(48000),
        shelf_slope: Float64 = 1.0,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Re-tune the node's filter in place, keeping it attached."""
        var code = raw.hishelf_node_reinit(self._lib[], self._ptr, format.code, self._channels, sample_rate, gain_db, shelf_slope, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf_node retune failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.hishelf_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("hishelf_node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.hishelf_node_free(self._lib[], self._ptr)
