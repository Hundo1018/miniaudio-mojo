"""Binding layer: raw 1:1 wrappers over the standalone-effect shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in
effect.mojo.

Four object kinds share this module: `ma_delay` (delay line / echo),
`ma_gainer` (smoothed per-channel gain), `ma_panner` (stereo balance / pan) and
`ma_fader` (linear volume ramp). Every shim entry point returns a result code,
so getters come back as (result, value) pairs and an uninitialised handle is
observable as MA_INVALID_ARGS rather than a silent default.

Frames are interleaved f32 buffers here; the caller sizes `dst` to match `src`.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.spatializer_raw import MaFloat, MaU32


comptime PAN_MODE_BALANCE: Int = 0
comptime PAN_MODE_PAN: Int = 1


@fieldwise_init
struct MaFaderFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) from fader_get_data_format."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


# ---- ma_delay ---------------------------------------------------------------


def delay_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_delay_alloc", OpaquePointer[MutUntrackedOrigin]]()


def delay_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_delay_free", NoneType](h)


def delay_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    sample_rate: UInt32,
    delay_in_frames: UInt32,
    decay: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_delay_init", Int32](
            h, channels, sample_rate, delay_in_frames, decay
        )
    )


def delay_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_delay_uninit", Int32](h))


def delay_process(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt32,
) -> Int:
    """Runs frame_count f32 frames through the delay line, out-of-place."""
    return Int(
        lib.handle.call["ma_shim_delay_process", Int32](
            h, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def delay_set_wet(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_delay_set_wet", Int32](h, value))


def delay_get_wet(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(lib.handle.call["ma_shim_delay_get_wet", Int32](h, holder.unsafe_ptr()))
    return MaFloat(code, holder[0])


def delay_set_dry(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_delay_set_dry", Int32](h, value))


def delay_get_dry(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(lib.handle.call["ma_shim_delay_get_dry", Int32](h, holder.unsafe_ptr()))
    return MaFloat(code, holder[0])


def delay_set_decay(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_delay_set_decay", Int32](h, value))


def delay_get_decay(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(lib.handle.call["ma_shim_delay_get_decay", Int32](h, holder.unsafe_ptr()))
    return MaFloat(code, holder[0])


# ---- ma_gainer --------------------------------------------------------------


def gainer_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_gainer_alloc", OpaquePointer[MutUntrackedOrigin]]()


def gainer_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_gainer_free", NoneType](h)


def gainer_get_heap_size(
    lib: MaLib, channels: UInt32, smooth_time_in_frames: UInt32
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_gainer_get_heap_size", Int32](
            channels, smooth_time_in_frames, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def gainer_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    smooth_time_in_frames: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_gainer_init", Int32](h, channels, smooth_time_in_frames)
    )


def gainer_init_preallocated(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    smooth_time_in_frames: UInt32,
) -> Int:
    """Init with a shim-owned heap sized by ma_gainer_get_heap_size."""
    return Int(
        lib.handle.call["ma_shim_gainer_init_preallocated", Int32](
            h, channels, smooth_time_in_frames
        )
    )


def gainer_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_gainer_uninit", Int32](h))


def gainer_process(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_gainer_process", Int32](
            h, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def gainer_set_gain(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], gain: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_gainer_set_gain", Int32](h, gain))


def gainer_set_gains(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], gains: List[Float32]
) -> Int:
    """One gain per channel; len(gains) must equal the configured channel count."""
    return Int(
        lib.handle.call["ma_shim_gainer_set_gains", Int32](
            h, gains.unsafe_ptr(), UInt32(len(gains))
        )
    )


def gainer_set_master_volume(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], volume: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_gainer_set_master_volume", Int32](h, volume))


def gainer_get_master_volume(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_gainer_get_master_volume", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])


# ---- ma_panner --------------------------------------------------------------


def panner_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_panner_alloc", OpaquePointer[MutUntrackedOrigin]]()


def panner_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_panner_free", NoneType](h)


def panner_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    mode: Int,
    pan: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_panner_init", Int32](
            h, Int32(format), channels, Int32(mode), pan
        )
    )


def panner_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_panner_uninit", Int32](h))


def panner_process(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_panner_process", Int32](
            h, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def panner_set_mode(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], mode: Int) -> Int:
    return Int(lib.handle.call["ma_shim_panner_set_mode", Int32](h, Int32(mode)))


def panner_get_mode(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [Int32(0)]
    var code = Int(lib.handle.call["ma_shim_panner_get_mode", Int32](h, holder.unsafe_ptr()))
    return MaU32(code, UInt32(holder[0]))


def panner_set_pan(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], pan: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_panner_set_pan", Int32](h, pan))


def panner_get_pan(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(lib.handle.call["ma_shim_panner_get_pan", Int32](h, holder.unsafe_ptr()))
    return MaFloat(code, holder[0])


# ---- ma_fader ---------------------------------------------------------------


def fader_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_fader_alloc", OpaquePointer[MutUntrackedOrigin]]()


def fader_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_fader_free", NoneType](h)


def fader_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_fader_init", Int32](h, Int32(format), channels, sample_rate)
    )


def fader_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_fader_uninit", Int32](h))


def fader_process(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_fader_process", Int32](
            h, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def fader_get_data_format(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFaderFormat:
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var sr = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_fader_get_data_format", Int32](
            h, fmt.unsafe_ptr(), ch.unsafe_ptr(), sr.unsafe_ptr()
        )
    )
    return MaFaderFormat(code, Int(fmt[0]), ch[0], sr[0])


def fader_set_fade(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    volume_beg: Float32,
    volume_end: Float32,
    length_in_frames: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_fader_set_fade", Int32](
            h, volume_beg, volume_end, length_in_frames
        )
    )


def fader_set_fade_ex(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    volume_beg: Float32,
    volume_end: Float32,
    length_in_frames: UInt64,
    start_offset_in_frames: Int64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_fader_set_fade_ex", Int32](
            h, volume_beg, volume_end, length_in_frames, start_offset_in_frames
        )
    )


def fader_get_current_volume(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_fader_get_current_volume", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])
