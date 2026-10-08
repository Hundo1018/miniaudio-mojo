"""Binding layer: raw 1:1 wrappers over the PCM conversion shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes.
No lifecycle / error policy; that lives in pcm_convert.mojo.

These are stateless: every wrapper is a plain call on caller-owned lists. The
typed wrappers take the natural Mojo element type for their format: u8 as UInt8,
s16 as Int16, s32 as Int32, f32 as Float32, and s24 as UInt8 packed three bytes
per sample, which is how miniaudio stores it. The wrappers that dispatch on a
runtime `format` argument cannot be typed, so they take raw bytes (List[UInt8]).

The clipping variants take a *wider* source than their destination: s16 into
u8, s32 into s16, s64 into s24 and s32, f32 into f32.

Deinterleaving writes one buffer per channel and interleaving reads from one, so
miniaudio takes an array of pointers. Mojo has no safe home for such an array,
so these pass a single flat buffer with the planes laid out one after another,
`channel_stride_in_bytes` apart, and the shim builds the pointer array over it.

The shim cannot see how long these lists are, so sizing them to match the count
arguments is the caller's job; pcm_convert.mojo does it.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaText
from miniaudio._ffi.node_raw import MaFloat


# ---- the 25 format-pair converters -------------------------------------------


def pcm_u8_to_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_u8_to_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_u8_to_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[UInt8],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_u8_to_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_u8_to_s24(
    lib: MaLib,
    mut dst: List[UInt8],  # packed 3 bytes per sample
    src: List[UInt8],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_u8_to_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_u8_to_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[UInt8],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_u8_to_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_u8_to_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[UInt8],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_u8_to_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s16_to_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[Int16],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s16_to_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s16_to_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Int16],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s16_to_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s16_to_s24(
    lib: MaLib,
    mut dst: List[UInt8],  # packed 3 bytes per sample
    src: List[Int16],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s16_to_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s16_to_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Int16],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s16_to_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s16_to_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Int16],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s16_to_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s24_to_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],  # packed 3 bytes per sample
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s24_to_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s24_to_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[UInt8],  # packed 3 bytes per sample
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s24_to_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s24_to_s24(
    lib: MaLib,
    mut dst: List[UInt8],  # packed 3 bytes per sample
    src: List[UInt8],  # packed 3 bytes per sample
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s24_to_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s24_to_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[UInt8],  # packed 3 bytes per sample
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s24_to_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s24_to_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[UInt8],  # packed 3 bytes per sample
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s24_to_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s32_to_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[Int32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s32_to_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s32_to_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Int32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s32_to_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s32_to_s24(
    lib: MaLib,
    mut dst: List[UInt8],  # packed 3 bytes per sample
    src: List[Int32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s32_to_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s32_to_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Int32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s32_to_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_s32_to_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Int32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_s32_to_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_f32_to_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[Float32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_f32_to_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_f32_to_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Float32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_f32_to_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_f32_to_s24(
    lib: MaLib,
    mut dst: List[UInt8],  # packed 3 bytes per sample
    src: List[Float32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_f32_to_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_f32_to_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Float32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_f32_to_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


def pcm_f32_to_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_f32_to_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, Int32(dither_mode)
        )
    )


# ---- interleave / deinterleave, over a flat multi-plane buffer ----------------


def pcm_deinterleave_u8(
    lib: MaLib,
    mut planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
    interleaved: List[UInt8],
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_pcm_deinterleave_u8", Int32](
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
            frame_count,
            channels,
        )
    )


def pcm_interleave_u8(
    lib: MaLib,
    mut interleaved: List[UInt8],
    planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """The inverse of `pcm_deinterleave_u8`."""
    return Int(
        lib.handle.call["ma_shim_pcm_interleave_u8", Int32](
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            frame_count,
            channels,
        )
    )


def pcm_deinterleave_s16(
    lib: MaLib,
    mut planes: List[Int16],
    channel_stride_in_bytes: UInt64,
    interleaved: List[Int16],
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_pcm_deinterleave_s16", Int32](
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
            frame_count,
            channels,
        )
    )


def pcm_interleave_s16(
    lib: MaLib,
    mut interleaved: List[Int16],
    planes: List[Int16],
    channel_stride_in_bytes: UInt64,
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """The inverse of `pcm_deinterleave_s16`."""
    return Int(
        lib.handle.call["ma_shim_pcm_interleave_s16", Int32](
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            frame_count,
            channels,
        )
    )


def pcm_deinterleave_s24(
    lib: MaLib,
    mut planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
    interleaved: List[UInt8],
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_pcm_deinterleave_s24", Int32](
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
            frame_count,
            channels,
        )
    )


def pcm_interleave_s24(
    lib: MaLib,
    mut interleaved: List[UInt8],
    planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """The inverse of `pcm_deinterleave_s24`."""
    return Int(
        lib.handle.call["ma_shim_pcm_interleave_s24", Int32](
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            frame_count,
            channels,
        )
    )


def pcm_deinterleave_s32(
    lib: MaLib,
    mut planes: List[Int32],
    channel_stride_in_bytes: UInt64,
    interleaved: List[Int32],
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_pcm_deinterleave_s32", Int32](
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
            frame_count,
            channels,
        )
    )


def pcm_interleave_s32(
    lib: MaLib,
    mut interleaved: List[Int32],
    planes: List[Int32],
    channel_stride_in_bytes: UInt64,
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """The inverse of `pcm_deinterleave_s32`."""
    return Int(
        lib.handle.call["ma_shim_pcm_interleave_s32", Int32](
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            frame_count,
            channels,
        )
    )


def pcm_deinterleave_f32(
    lib: MaLib,
    mut planes: List[Float32],
    channel_stride_in_bytes: UInt64,
    interleaved: List[Float32],
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_pcm_deinterleave_f32", Int32](
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
            frame_count,
            channels,
        )
    )


def pcm_interleave_f32(
    lib: MaLib,
    mut interleaved: List[Float32],
    planes: List[Float32],
    channel_stride_in_bytes: UInt64,
    frame_count: UInt64,
    channels: UInt32,
) -> Int:
    """The inverse of `pcm_deinterleave_f32`."""
    return Int(
        lib.handle.call["ma_shim_pcm_interleave_f32", Int32](
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            frame_count,
            channels,
        )
    )


# ---- whole-buffer conversion --------------------------------------------------


def pcm_convert(
    lib: MaLib,
    mut dst: List[UInt8],
    format_out: Int,
    src: List[UInt8],
    format_in: Int,
    sample_count: UInt64,
    dither_mode: Int = 0,
) -> Int:
    """The format-dispatching sample converter. Both buffers are raw bytes."""
    return Int(
        lib.handle.call["ma_shim_pcm_convert", Int32](
            dst.unsafe_ptr(), Int32(format_out), src.unsafe_ptr(), Int32(format_in),
            sample_count, Int32(dither_mode),
        )
    )


def convert_pcm_frames_format(
    lib: MaLib,
    mut dst: List[UInt8],
    format_out: Int,
    src: List[UInt8],
    format_in: Int,
    frame_count: UInt64,
    channels: UInt32,
    dither_mode: Int = 0,
) -> Int:
    """The same dispatch, counted in frames rather than samples."""
    return Int(
        lib.handle.call["ma_shim_convert_pcm_frames_format", Int32](
            dst.unsafe_ptr(), Int32(format_out), src.unsafe_ptr(), Int32(format_in),
            frame_count, channels, Int32(dither_mode),
        )
    )


def convert_frames(
    lib: MaLib,
    mut dst: List[UInt8],
    frame_count_out: UInt64,
    format_out: Int,
    channels_out: UInt32,
    sample_rate_out: UInt32,
    src: List[UInt8],
    frame_count_in: UInt64,
    format_in: Int,
    channels_in: UInt32,
    sample_rate_in: UInt32,
) -> MaCount:
    """Format, channel and rate conversion in one call. `value` is frames written."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_convert_frames", Int32](
            dst.unsafe_ptr(), frame_count_out, Int32(format_out), channels_out,
            sample_rate_out, src.unsafe_ptr(), frame_count_in, Int32(format_in),
            channels_in, sample_rate_in, holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def convert_frames_measure(
    lib: MaLib,
    format_out: Int,
    channels_out: UInt32,
    sample_rate_out: UInt32,
    frame_count_in: UInt64,
    format_in: Int,
    channels_in: UInt32,
    sample_rate_in: UInt32,
) -> MaCount:
    """`convert_frames` with a NULL output: how many frames it would produce."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_convert_frames", Int32](
            Int(0), UInt64(0), Int32(format_out), channels_out, sample_rate_out,
            Int(0), frame_count_in, Int32(format_in), channels_in, sample_rate_in,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def convert_frames_ex(
    lib: MaLib,
    mut dst: List[UInt8],
    frame_count_out: UInt64,
    src: List[UInt8],
    frame_count_in: UInt64,
    format_in: Int,
    format_out: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
    dither_mode: Int = 0,
    lpf_order: UInt32 = 1,
) -> MaCount:
    """Same, through a data converter config the shim builds from these fields."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_convert_frames_ex", Int32](
            dst.unsafe_ptr(), frame_count_out, src.unsafe_ptr(), frame_count_in,
            Int32(format_in), Int32(format_out), channels_in, channels_out,
            sample_rate_in, sample_rate_out, Int32(dither_mode), lpf_order,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def convert_frames_ex_measure(
    lib: MaLib,
    frame_count_in: UInt64,
    format_in: Int,
    format_out: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
    dither_mode: Int = 0,
    lpf_order: UInt32 = 1,
) -> MaCount:
    """`convert_frames_ex` with a NULL output: how many frames it would produce."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_convert_frames_ex", Int32](
            Int(0), UInt64(0), Int(0), frame_count_in, Int32(format_in),
            Int32(format_out), channels_in, channels_out, sample_rate_in,
            sample_rate_out, Int32(dither_mode), lpf_order, holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def copy_pcm_frames(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
) -> Int:
    """A frame-aware copy. Both buffers are raw bytes."""
    return Int(
        lib.handle.call["ma_shim_copy_pcm_frames", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, Int32(format), channels
        )
    )


# ---- volume and mixing, copying rather than in place --------------------------


def copy_and_apply_volume_factor_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    sample_count: UInt64,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, factor
        )
    )


def copy_and_apply_volume_factor_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Int16],
    sample_count: UInt64,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, factor
        )
    )


def copy_and_apply_volume_factor_s24(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    sample_count: UInt64,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, factor
        )
    )


def copy_and_apply_volume_factor_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Int32],
    sample_count: UInt64,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, factor
        )
    )


def copy_and_apply_volume_factor_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    sample_count: UInt64,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), sample_count, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    frame_count: UInt64,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Int16],
    frame_count: UInt64,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames_s24(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    frame_count: UInt64,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Int32],
    frame_count: UInt64,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
    channels: UInt32,
    factor: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, factor
        )
    )


def copy_and_apply_volume_factor_pcm_frames(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
    factor: Float32,
) -> Int:
    """The format-dispatching volume copy. Both buffers are raw bytes."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, Int32(format), channels,
            factor,
        )
    )


def copy_and_apply_volume_factor_per_channel_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
    channels: UInt32,
    channel_gains: List[Float32],
) -> Int:
    """One gain per channel rather than one for the whole buffer."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_factor_per_channel_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels,
            channel_gains.unsafe_ptr(),
        )
    )


def copy_and_apply_volume_and_clip_samples_u8(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[Int16],
    count: UInt64,
    volume: Float32,
) -> Int:
    """Volume then clip, from the wider source type miniaudio expects."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_u8", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count, volume
        )
    )


def copy_and_apply_volume_and_clip_samples_s16(
    lib: MaLib,
    mut dst: List[Int16],
    src: List[Int32],
    count: UInt64,
    volume: Float32,
) -> Int:
    """Volume then clip, from the wider source type miniaudio expects."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s16", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count, volume
        )
    )


def copy_and_apply_volume_and_clip_samples_s24(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[Int64],
    count: UInt64,
    volume: Float32,
) -> Int:
    """Volume then clip, from the wider source type miniaudio expects."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s24", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count, volume
        )
    )


def copy_and_apply_volume_and_clip_samples_s32(
    lib: MaLib,
    mut dst: List[Int32],
    src: List[Int64],
    count: UInt64,
    volume: Float32,
) -> Int:
    """Volume then clip, from the wider source type miniaudio expects."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count, volume
        )
    )


def copy_and_apply_volume_and_clip_samples_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    count: UInt64,
    volume: Float32,
) -> Int:
    """Volume then clip, from the wider source type miniaudio expects."""
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), count, volume
        )
    )


def copy_and_apply_volume_and_clip_pcm_frames(
    lib: MaLib,
    mut dst: List[UInt8],
    src: List[UInt8],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
    volume: Float32,
) -> Int:
    """Volume then clip, dispatched on `format`.

    `dst` holds samples of `format`; `src` holds the wider type that format clips
    from (s16 for u8, s32 for s16, s64 for s24 and s32, f32 for f32).
    """
    return Int(
        lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_pcm_frames", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, Int32(format), channels,
            volume,
        )
    )


# ---- blending, mixing, decibels and strings -----------------------------------


def blend_f32(
    lib: MaLib,
    mut dst: List[Float32],
    in_a: List[Float32],
    in_b: List[Float32],
    factor: Float32,
    channels: UInt32,
) -> Int:
    """Cross-fade one frame between two inputs; 0 gives `in_a`, 1 gives `in_b`."""
    return Int(
        lib.handle.call["ma_shim_blend_f32", Int32](
            dst.unsafe_ptr(), in_a.unsafe_ptr(), in_b.unsafe_ptr(), factor, channels
        )
    )


def mix_pcm_frames_f32(
    lib: MaLib,
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
    channels: UInt32,
    volume: Float32,
) -> Int:
    """Adds `src` into `dst` at the given volume."""
    return Int(
        lib.handle.call["ma_shim_mix_pcm_frames_f32", Int32](
            dst.unsafe_ptr(), src.unsafe_ptr(), frame_count, channels, volume
        )
    )


def volume_linear_to_db(lib: MaLib, factor: Float32) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_volume_linear_to_db", Int32](
            factor, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def volume_db_to_linear(lib: MaLib, gain: Float32) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_volume_db_to_linear", Int32](
            gain, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def copy_string(lib: MaLib, src: String, capacity: UInt32 = 256) -> MaText:
    """miniaudio duplicates the string; the shim copies it out and frees it."""
    var src_c = src + "\x00"
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_copy_string", Int32](
            src_c.as_bytes().unsafe_ptr(), buf.unsafe_ptr(), capacity
        )
    )
    if code != 0:
        # The shim leaves the buffer empty (or untouched when capacity is 0).
        return MaText(code, String())
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))
