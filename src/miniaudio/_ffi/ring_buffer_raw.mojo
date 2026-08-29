"""Binding layer: raw 1:1 wrappers over the ring buffer shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
ring_buffer.mojo.

Two ring buffers are covered: `rb_*` over ma_rb (untyped, sized in bytes) and
`pcm_rb_*` over ma_pcm_rb (PCM-aware, sized in frames). miniaudio's acquire /
commit pair hands out an interior pointer that Mojo has no safe home for, so
the shim owns that loop and this layer exposes copy-in / copy-out `write` /
`read` instead.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt


@fieldwise_init
struct MaDistance(Copyable, Movable):
    """Raw (result_code, distance) pair for the pointer_distance getters."""

    var result: Int
    var value: Int


# ---- ma_rb — byte-oriented ring buffer --------------------------------------


def rb_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_rb_alloc", OpaquePointer[MutUntrackedOrigin]]()


def rb_free(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_rb_free", NoneType](rb)


def rb_init(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], buffer_size_in_bytes: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_rb_init", Int32](rb, buffer_size_in_bytes)
    )


def rb_init_ex(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    subbuffer_size_in_bytes: UInt64,
    subbuffer_count: UInt64,
    subbuffer_stride_in_bytes: UInt64,
    use_preallocated: Bool,
) -> Int:
    """`use_preallocated` routes init through miniaudio's preallocated-buffer path.

    The shim then owns that backing store and frees it on uninit.
    """
    return Int(
        lib.handle.call["ma_shim_rb_init_ex", Int32](
            rb,
            subbuffer_size_in_bytes,
            subbuffer_count,
            subbuffer_stride_in_bytes,
            Int32(1) if use_preallocated else Int32(0),
        )
    )


def rb_uninit(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_rb_uninit", Int32](rb))


def rb_reset(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_rb_reset", Int32](rb))


def rb_write(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    src: List[UInt8],
    size_in_bytes: UInt64,
) -> MaCount:
    """Copies up to size_in_bytes from `src`. Returns MaCount(code, bytes_written).

    Short writes are not an error: the count is capped by the free space.
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_write", Int32](
            rb, src.unsafe_ptr(), size_in_bytes, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rb_read(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[UInt8],
    size_in_bytes: UInt64,
) -> MaCount:
    """Copies up to size_in_bytes into `dst` (caller pre-sizes the buffer).

    Returns MaCount(code, bytes_read); a short read means the buffer ran empty.
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_read", Int32](
            rb, dst.unsafe_ptr(), size_in_bytes, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rb_seek_read(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], offset_in_bytes: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_rb_seek_read", Int32](rb, offset_in_bytes)
    )


def rb_seek_write(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], offset_in_bytes: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_rb_seek_write", Int32](rb, offset_in_bytes)
    )


def rb_pointer_distance(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaDistance:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_pointer_distance", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaDistance(code, Int(holder[0]))


def rb_available_read(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_available_read", Int32](rb, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def rb_available_write(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_available_write", Int32](rb, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def rb_get_subbuffer_size(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_get_subbuffer_size", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rb_get_subbuffer_stride(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_get_subbuffer_stride", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rb_get_subbuffer_offset(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], subbuffer_index: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_get_subbuffer_offset", Int32](
            rb, subbuffer_index, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rb_get_subbuffer_ptr_offset(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], subbuffer_index: UInt64
) -> MaCount:
    """Byte offset of subbuffer N's pointer from the ring buffer's backing store."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_rb_get_subbuffer_ptr_offset", Int32](
            rb, subbuffer_index, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


# ---- ma_pcm_rb — frame-oriented ring buffer ---------------------------------


def pcm_rb_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_pcm_rb_alloc", OpaquePointer[MutUntrackedOrigin]]()


def pcm_rb_free(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_pcm_rb_free", NoneType](rb)


def pcm_rb_init(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    buffer_size_in_frames: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_rb_init", Int32](
            rb, Int32(format), channels, buffer_size_in_frames
        )
    )


def pcm_rb_init_ex(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    subbuffer_size_in_frames: UInt32,
    subbuffer_count: UInt32,
    subbuffer_stride_in_frames: UInt32,
    use_preallocated: Bool,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_rb_init_ex", Int32](
            rb,
            Int32(format),
            channels,
            subbuffer_size_in_frames,
            subbuffer_count,
            subbuffer_stride_in_frames,
            Int32(1) if use_preallocated else Int32(0),
        )
    )


def pcm_rb_uninit(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_pcm_rb_uninit", Int32](rb))


def pcm_rb_reset(lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_pcm_rb_reset", Int32](rb))


def pcm_rb_write(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    frame_count: UInt32,
) -> MaUInt:
    """Copies up to frame_count f32 frames from `src`. Returns (code, frames_written)."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_write", Int32](
            rb, src.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_read(
    lib: MaLib,
    rb: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt32,
) -> MaUInt:
    """Copies up to frame_count f32 frames into `dst`. Returns (code, frames_read)."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_read", Int32](
            rb, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_seek_read(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], offset_in_frames: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_rb_seek_read", Int32](rb, offset_in_frames)
    )


def pcm_rb_seek_write(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], offset_in_frames: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_rb_seek_write", Int32](rb, offset_in_frames)
    )


def pcm_rb_pointer_distance(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaDistance:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_pointer_distance", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaDistance(code, Int(holder[0]))


def pcm_rb_available_read(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_available_read", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_available_write(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_available_write", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_get_subbuffer_size(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_get_subbuffer_size", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_get_subbuffer_stride(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_get_subbuffer_stride", Int32](
            rb, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_get_subbuffer_offset(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], subbuffer_index: UInt32
) -> MaUInt:
    """Frame offset of subbuffer N (frames, unlike the byte-valued ptr offset)."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_get_subbuffer_offset", Int32](
            rb, subbuffer_index, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def pcm_rb_get_subbuffer_ptr_offset(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], subbuffer_index: UInt32
) -> MaCount:
    """Byte offset of subbuffer N's pointer from the ring buffer's backing store."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_get_subbuffer_ptr_offset", Int32](
            rb, subbuffer_index, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


@fieldwise_init
struct MaPcmRbFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) from get_data_format."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


def pcm_rb_get_data_format(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin]
) -> MaPcmRbFormat:
    var fmt = [Int32(0)]
    var channels = [UInt32(0)]
    var sample_rate = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_pcm_rb_get_data_format", Int32](
            rb,
            fmt.unsafe_ptr(),
            channels.unsafe_ptr(),
            sample_rate.unsafe_ptr(),
        )
    )
    return MaPcmRbFormat(code, Int(fmt[0]), channels[0], sample_rate[0])


def pcm_rb_set_sample_rate(
    lib: MaLib, rb: OpaquePointer[MutUntrackedOrigin], sample_rate: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_pcm_rb_set_sample_rate", Int32](rb, sample_rate)
    )
