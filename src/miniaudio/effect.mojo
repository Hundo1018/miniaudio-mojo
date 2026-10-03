"""Idiomatic standalone-effect API (Layer 3).

RAII wrappers over miniaudio's four non-node effect objects. Each processes
interleaved f32 frames in memory (no device or engine) and frees its shim
handle on drop:

- `Delay`  — ma_delay: delay line / echo with wet, dry and feedback decay.
- `Gainer` — ma_gainer: per-channel gain with linear smoothing, plus a master
  volume.
- `Panner` — ma_panner: stereo balance or true pan; mono passes through.
- `Fader`  — ma_fader: linear volume ramp over a number of frames.

Note (miniaudio 0.11.25): after any gain change, ma_gainer's next process()
call interpolates across the whole block rather than the configured smoothing
time and can overshoot the target. The following call is settled and exact.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.effect_raw as raw

comptime PanModeBalance: Int = raw.PAN_MODE_BALANCE
comptime PanModePan: Int = raw.PAN_MODE_PAN

comptime _FORMAT_F32: Int = 5


def _frames_of(input: List[Float32], channels: UInt32) -> UInt64:
    return UInt64(len(input)) // UInt64(channels)


def _zeros(n: Int) -> List[Float32]:
    var buf = List[Float32](capacity=n)
    buf.resize(n, Float32(0))
    return buf^


struct Delay(Movable):
    """Delay line / echo (RAII over ma_delay). f32 only.

    decay = 0 configures a pure delay (output starts after delay_in_frames);
    decay > 0 configures an echo whose feedback is scaled by `decay` per pass.
    """

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
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32,
        sample_rate: UInt32,
        delay_in_frames: UInt32,
        decay: Float32 = 0.0,
    ) raises -> Self:
        """decay must be in [0, 1]; channels and delay_in_frames must be > 0."""
        var ptr = raw.delay_alloc(lib[])
        if ptr == null_handle():
            raise Error("delay_alloc failed (out of memory)")
        var code = raw.delay_init(lib[], ptr, channels, sample_rate, delay_in_frames, decay)
        if code != MA_SUCCESS:
            raw.delay_free(lib[], ptr)
            raise Error(lib[].describe("delay init failed", code))
        return Self(lib.copy(), ptr, channels)

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        """Run every frame of `input` through the delay; frame count is unchanged."""
        var buf = _zeros(len(input))
        var code = raw.delay_process(
            self._lib[], self._ptr, buf, input, UInt32(_frames_of(input, self._channels))
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay process failed", code))
        return buf^

    def set_wet(mut self, value: Float32) raises:
        var code = raw.delay_set_wet(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay set_wet failed", code))

    def wet(self) raises -> Float32:
        var rc = raw.delay_get_wet(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay wet failed", rc.result))
        return rc.value

    def set_dry(mut self, value: Float32) raises:
        var code = raw.delay_set_dry(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay set_dry failed", code))

    def dry(self) raises -> Float32:
        var rc = raw.delay_get_dry(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay dry failed", rc.result))
        return rc.value

    def set_decay(mut self, value: Float32) raises:
        var code = raw.delay_set_decay(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay set_decay failed", code))

    def decay(self) raises -> Float32:
        var rc = raw.delay_get_decay(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay decay failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.delay_free(self._lib[], self._ptr)


struct Gainer(Movable):
    """Smoothed per-channel gain (RAII over ma_gainer). f32 only."""

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
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32,
        smooth_time_in_frames: UInt32 = 0,
        preallocated: Bool = False,
    ) raises -> Self:
        """preallocated=True takes the get_heap_size + init_preallocated path."""
        var ptr = raw.gainer_alloc(lib[])
        if ptr == null_handle():
            raise Error("gainer_alloc failed (out of memory)")
        var code: Int
        if preallocated:
            code = raw.gainer_init_preallocated(lib[], ptr, channels, smooth_time_in_frames)
        else:
            code = raw.gainer_init(lib[], ptr, channels, smooth_time_in_frames)
        if code != MA_SUCCESS:
            raw.gainer_free(lib[], ptr)
            raise Error(lib[].describe("gainer init failed", code))
        return Self(lib.copy(), ptr, channels)

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib], channels: UInt32, smooth_time_in_frames: UInt32 = 0
    ) raises -> UInt64:
        """Bytes ma_gainer needs for this configuration."""
        var rc = raw.gainer_get_heap_size(lib[], channels, smooth_time_in_frames)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("gainer heap_size failed", rc.result))
        return rc.value

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        var buf = _zeros(len(input))
        var code = raw.gainer_process(
            self._lib[], self._ptr, buf, input, _frames_of(input, self._channels)
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("gainer process failed", code))
        return buf^

    def set_gain(mut self, gain: Float32) raises:
        """Set the same target gain on every channel."""
        var code = raw.gainer_set_gain(self._lib[], self._ptr, gain)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("gainer set_gain failed", code))

    def set_gains(mut self, gains: List[Float32]) raises:
        """Set one target gain per channel; len(gains) must equal channels."""
        var code = raw.gainer_set_gains(self._lib[], self._ptr, gains)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("gainer set_gains failed", code))

    def set_master_volume(mut self, volume: Float32) raises:
        var code = raw.gainer_set_master_volume(self._lib[], self._ptr, volume)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("gainer set_master_volume failed", code))

    def master_volume(self) raises -> Float32:
        var rc = raw.gainer_get_master_volume(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("gainer master_volume failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.gainer_free(self._lib[], self._ptr)


struct Panner(Movable):
    """Stereo balance / pan (RAII over ma_panner), f32 frames.

    pan is clamped to [-1, 1]: -1 = full left, +1 = full right. In balance mode
    the far side is attenuated; in pan mode it is blended into the near side.
    Non-stereo input is copied through unchanged.
    """

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
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32 = 2,
        mode: Int = PanModeBalance,
        pan: Float32 = 0.0,
    ) raises -> Self:
        var ptr = raw.panner_alloc(lib[])
        if ptr == null_handle():
            raise Error("panner_alloc failed (out of memory)")
        var code = raw.panner_init(lib[], ptr, _FORMAT_F32, channels, mode, pan)
        if code != MA_SUCCESS:
            raw.panner_free(lib[], ptr)
            raise Error(lib[].describe("panner init failed", code))
        return Self(lib.copy(), ptr, channels)

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        var buf = _zeros(len(input))
        var code = raw.panner_process(
            self._lib[], self._ptr, buf, input, _frames_of(input, self._channels)
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("panner process failed", code))
        return buf^

    def set_mode(mut self, mode: Int) raises:
        var code = raw.panner_set_mode(self._lib[], self._ptr, mode)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("panner set_mode failed", code))

    def mode(self) raises -> Int:
        var rc = raw.panner_get_mode(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("panner mode failed", rc.result))
        return Int(rc.value)

    def set_pan(mut self, pan: Float32) raises:
        var code = raw.panner_set_pan(self._lib[], self._ptr, pan)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("panner set_pan failed", code))

    def pan(self) raises -> Float32:
        var rc = raw.panner_get_pan(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("panner pan failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.panner_free(self._lib[], self._ptr)


struct Fader(Movable):
    """Linear volume ramp (RAII over ma_fader). f32 only."""

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
    def create(
        lib: ArcPointer[MaLib], *, channels: UInt32, sample_rate: UInt32
    ) raises -> Self:
        var ptr = raw.fader_alloc(lib[])
        if ptr == null_handle():
            raise Error("fader_alloc failed (out of memory)")
        var code = raw.fader_init(lib[], ptr, _FORMAT_F32, channels, sample_rate)
        if code != MA_SUCCESS:
            raw.fader_free(lib[], ptr)
            raise Error(lib[].describe("fader init failed", code))
        return Self(lib.copy(), ptr, channels)

    def process(mut self, input: List[Float32]) raises -> List[Float32]:
        var buf = _zeros(len(input))
        var code = raw.fader_process(
            self._lib[], self._ptr, buf, input, _frames_of(input, self._channels)
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fader process failed", code))
        return buf^

    def set_fade(
        mut self,
        volume_beg: Float32,
        volume_end: Float32,
        length_in_frames: UInt64,
        start_offset_in_frames: Int64 = 0,
    ) raises:
        """Ramp from volume_beg to volume_end over length_in_frames.

        A negative volume_beg starts from the current volume. A positive
        start_offset_in_frames delays the ramp by that many frames.
        """
        var code: Int
        if start_offset_in_frames == 0:
            code = raw.fader_set_fade(
                self._lib[], self._ptr, volume_beg, volume_end, length_in_frames
            )
        else:
            code = raw.fader_set_fade_ex(
                self._lib[],
                self._ptr,
                volume_beg,
                volume_end,
                length_in_frames,
                start_offset_in_frames,
            )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fader set_fade failed", code))

    def current_volume(self) raises -> Float32:
        var rc = raw.fader_get_current_volume(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("fader current_volume failed", rc.result))
        return rc.value

    def channels(self) raises -> UInt32:
        var rc = raw.fader_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("fader data_format failed", rc.result))
        return rc.channels

    def sample_rate(self) raises -> UInt32:
        var rc = raw.fader_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("fader data_format failed", rc.result))
        return rc.sample_rate

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.fader_free(self._lib[], self._ptr)
