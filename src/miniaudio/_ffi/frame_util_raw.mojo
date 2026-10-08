"""Binding layer: raw 1:1 wrappers over the PCM frame utility shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes.
No lifecycle / error policy; that lives in frame_util.mojo.

These are miniaudio's format-dispatching frame helpers: interleave / deinterleave,
silence, pointer offsetting and the debug sine fill. Nothing here owns anything,
and the format is chosen at run time, so every buffer is raw bytes (List[UInt8]).

Deinterleaving writes one buffer per channel and interleaving reads from one, so
miniaudio takes an array of pointers. Mojo has no safe home for such an array,
so these pass a single flat buffer with the planes laid out one after another,
`channel_stride_in_bytes` apart, and the shim builds the pointer array over it.

The offset helpers return a pointer, which comes back as an address.

The shim cannot see how long these lists are, so sizing them to match the count
arguments is the caller's job; frame_util.mojo does it.
"""

from miniaudio._lib import MaLib


@fieldwise_init
struct MaAddress(Copyable, Movable):
    """Raw (result_code, address) pair for the pointer-returning offset helpers."""

    var result: Int
    var address: Int


def interleave_pcm_frames(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    frame_count: UInt64,
    planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
    mut interleaved: List[UInt8],
) -> Int:
    """Weave one plane per channel into `interleaved`."""
    return Int(
        lib.handle.call["ma_shim_interleave_pcm_frames", Int32](
            Int32(format),
            channels,
            frame_count,
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
            interleaved.unsafe_ptr(),
        )
    )


def deinterleave_pcm_frames(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    frame_count: UInt64,
    interleaved: List[UInt8],
    mut planes: List[UInt8],
    channel_stride_in_bytes: UInt64,
) -> Int:
    """Split `interleaved` into one plane per channel, `channel_stride_in_bytes` apart."""
    return Int(
        lib.handle.call["ma_shim_deinterleave_pcm_frames", Int32](
            Int32(format),
            channels,
            frame_count,
            interleaved.unsafe_ptr(),
            planes.unsafe_ptr(),
            channel_stride_in_bytes,
        )
    )


def silence_pcm_frames(
    lib: MaLib,
    mut frames: List[UInt8],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
) -> Int:
    """Zero the frames; u8 is unsigned, so its silence is 128 instead."""
    return Int(
        lib.handle.call["ma_shim_silence_pcm_frames", Int32](
            frames.unsafe_ptr(), frame_count, Int32(format), channels
        )
    )


def offset_pcm_frames_ptr(
    lib: MaLib,
    mut frames: List[UInt8],
    offset_in_frames: UInt64,
    format: Int,
    channels: UInt32,
) -> MaAddress:
    """The address `offset_in_frames` frames into the buffer."""
    var holder = [Int(0)]
    var code = Int(
        lib.handle.call["ma_shim_offset_pcm_frames_ptr", Int32](
            frames.unsafe_ptr(), offset_in_frames, Int32(format), channels,
            holder.unsafe_ptr(),
        )
    )
    return MaAddress(code, holder[0])


def offset_pcm_frames_const_ptr(
    lib: MaLib,
    frames: List[UInt8],
    offset_in_frames: UInt64,
    format: Int,
    channels: UInt32,
) -> MaAddress:
    """`offset_pcm_frames_ptr` for a read-only buffer."""
    var holder = [Int(0)]
    var code = Int(
        lib.handle.call["ma_shim_offset_pcm_frames_const_ptr", Int32](
            frames.unsafe_ptr(), offset_in_frames, Int32(format), channels,
            holder.unsafe_ptr(),
        )
    )
    return MaAddress(code, holder[0])


def debug_fill_pcm_frames_with_sine_wave(
    lib: MaLib,
    mut frames: List[UInt8],
    frame_count: UInt32,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """Fill with a full-scale 400 Hz sine, in `format`."""
    return Int(
        lib.handle.call["ma_shim_debug_fill_pcm_frames_with_sine_wave", Int32](
            frames.unsafe_ptr(), frame_count, Int32(format), channels, sample_rate
        )
    )
