"""Binding layer: raw 1:1 wrappers over the format utility shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes.
No lifecycle / error policy; that lives in format_util.mojo.

These are miniaudio's stateless helpers — volume scaling, clipping, buffer-size
arithmetic and the format / backend name tables. Nothing here owns anything, so
there are no handles: every wrapper is a plain call on a caller-owned list.

The clip wrappers take a *wider* source than destination, which is the point of
them: s32 clips down into s16, s64 into s32 and s24, s16 into u8. The widths are
kept as miniaudio declares them.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt, MaText


@fieldwise_init
struct MaBackends(Movable):
    """Raw (result_code, backend codes) pair for get_enabled_backends."""

    var result: Int
    var value: List[Int32]


# ---- volume, applied in place ------------------------------------------------


def apply_volume_factor_u8(lib: MaLib, mut samples: List[UInt8], factor: Float32) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_u8", Int32](
            samples.unsafe_ptr(), UInt64(len(samples)), factor
        )
    )


def apply_volume_factor_s16(lib: MaLib, mut samples: List[Int16], factor: Float32) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_s16", Int32](
            samples.unsafe_ptr(), UInt64(len(samples)), factor
        )
    )


def apply_volume_factor_s24(
    lib: MaLib, mut samples: List[UInt8], sample_count: UInt64, factor: Float32
) -> Int:
    """s24 samples are three bytes each, so the count is passed separately."""
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_s24", Int32](
            samples.unsafe_ptr(), sample_count, factor
        )
    )


def apply_volume_factor_s32(lib: MaLib, mut samples: List[Int32], factor: Float32) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_s32", Int32](
            samples.unsafe_ptr(), UInt64(len(samples)), factor
        )
    )


def apply_volume_factor_f32(lib: MaLib, mut samples: List[Float32], factor: Float32) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_f32", Int32](
            samples.unsafe_ptr(), UInt64(len(samples)), factor
        )
    )


def apply_volume_factor_pcm_frames(
    lib: MaLib,
    mut frames: List[Float32],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames", Int32](
            frames.unsafe_ptr(), frame_count, Int32(format), channels, factor
        )
    )


def apply_volume_factor_pcm_frames_u8(
    lib: MaLib, mut frames: List[UInt8], frame_count: UInt64, channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames_u8", Int32](
            frames.unsafe_ptr(), frame_count, channels, factor
        )
    )


def apply_volume_factor_pcm_frames_s16(
    lib: MaLib, mut frames: List[Int16], frame_count: UInt64, channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames_s16", Int32](
            frames.unsafe_ptr(), frame_count, channels, factor
        )
    )


def apply_volume_factor_pcm_frames_s24(
    lib: MaLib, mut frames: List[UInt8], frame_count: UInt64, channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames_s24", Int32](
            frames.unsafe_ptr(), frame_count, channels, factor
        )
    )


def apply_volume_factor_pcm_frames_s32(
    lib: MaLib, mut frames: List[Int32], frame_count: UInt64, channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames_s32", Int32](
            frames.unsafe_ptr(), frame_count, channels, factor
        )
    )


def apply_volume_factor_pcm_frames_f32(
    lib: MaLib, mut frames: List[Float32], frame_count: UInt64, channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_apply_volume_factor_pcm_frames_f32", Int32](
            frames.unsafe_ptr(), frame_count, channels, factor
        )
    )


# ---- clipping ----------------------------------------------------------------


def clip_samples_u8(
    lib: MaLib, mut dst: List[UInt8], src: List[Int16], count: UInt64
) -> Int:
    """s16 clipped down into u8."""
    return Int(
        lib.handle.call["ma_shim_clip_samples_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count
        )
    )


def clip_samples_s16(
    lib: MaLib, mut dst: List[Int16], src: List[Int32], count: UInt64
) -> Int:
    """s32 clipped down into s16."""
    return Int(
        lib.handle.call["ma_shim_clip_samples_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count
        )
    )


def clip_samples_s24(
    lib: MaLib, mut dst: List[UInt8], src: List[Int64], count: UInt64
) -> Int:
    """s64 clipped down into packed 3-byte s24."""
    return Int(
        lib.handle.call["ma_shim_clip_samples_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count
        )
    )


def clip_samples_s32(
    lib: MaLib, mut dst: List[Int32], src: List[Int64], count: UInt64
) -> Int:
    """s64 clipped down into s32."""
    return Int(
        lib.handle.call["ma_shim_clip_samples_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count
        )
    )


def clip_samples_f32(
    lib: MaLib, mut dst: List[Float32], src: List[Float32], count: UInt64
) -> Int:
    """f32 clipped to [-1, 1]."""
    return Int(
        lib.handle.call["ma_shim_clip_samples_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count
        )
    )


def clip_pcm_frames(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_clip_pcm_frames", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, Int32(format), channels
        )
    )


# ---- buffer-size arithmetic --------------------------------------------------


def calculate_buffer_size_in_frames_from_milliseconds(
    lib: MaLib, milliseconds: UInt32, sample_rate: UInt32
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_calculate_buffer_size_in_frames_from_milliseconds", Int32
        ](milliseconds, sample_rate, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def calculate_buffer_size_in_milliseconds_from_frames(
    lib: MaLib, frames: UInt32, sample_rate: UInt32
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_calculate_buffer_size_in_milliseconds_from_frames", Int32
        ](frames, sample_rate, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def calculate_frame_count_after_resampling(
    lib: MaLib, sample_rate_out: UInt32, sample_rate_in: UInt32, frame_count_in: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_calculate_frame_count_after_resampling", Int32](
            sample_rate_out, sample_rate_in, frame_count_in, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def calculate_buffer_size_in_frames_from_descriptor(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    period_size_in_frames: UInt32,
    period_size_in_milliseconds: UInt32,
    native_sample_rate: UInt32,
    performance_profile: Int,
) -> MaUInt:
    """The shim builds the ma_device_descriptor from these fields."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_calculate_buffer_size_in_frames_from_descriptor", Int32
        ](
            Int32(format),
            channels,
            sample_rate,
            period_size_in_frames,
            period_size_in_milliseconds,
            native_sample_rate,
            Int32(performance_profile),
            holder.unsafe_ptr(),
        )
    )
    return MaUInt(code, holder[0])


# ---- name and priority tables ------------------------------------------------


def get_bytes_per_sample(lib: MaLib, format: Int) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_get_bytes_per_sample", Int32](
            Int32(format), holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def get_format_name(lib: MaLib, format: Int) -> MaText:
    var buf = List[UInt8](capacity=32)
    buf.resize(32, UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_get_format_name", Int32](
            Int32(format), buf.unsafe_ptr(), UInt32(32)
        )
    )
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


def get_format_priority_index(lib: MaLib, format: Int) -> MaUInt:
    """Where this format sits in miniaudio's preference order."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_get_format_priority_index", Int32](
            Int32(format), holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def get_backend_name(lib: MaLib, backend: Int) -> MaText:
    var buf = List[UInt8](capacity=32)
    buf.resize(32, UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_get_backend_name", Int32](
            Int32(backend), buf.unsafe_ptr(), UInt32(32)
        )
    )
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


def get_backend_from_name(lib: MaLib, name: String) -> MaUInt:
    """The backend code miniaudio maps that name to."""
    var name_c = name + "\x00"
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_get_backend_from_name", Int32](
            name_c.as_bytes().unsafe_ptr(), holder.unsafe_ptr()
        )
    )
    return MaUInt(code, UInt32(Int(holder[0])))


def get_enabled_backends(lib: MaLib, capacity: UInt32 = 16) -> MaBackends:
    """The backend codes this build of miniaudio was compiled with."""
    var buf = List[Int32](capacity=Int(capacity))
    buf.resize(Int(capacity), Int32(0))
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_get_enabled_backends", Int32](
            buf.unsafe_ptr(), capacity, holder.unsafe_ptr()
        )
    )
    buf.resize(Int(holder[0]), Int32(0))
    return MaBackends(code, buf^)
