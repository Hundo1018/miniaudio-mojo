"""Binding layer: raw 1:1 wrappers over the audio buffer shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
audio_buffer.mojo.

Two buffers are covered: `audio_buffer_ref_*` over ma_audio_buffer_ref (a
non-owning view) and `audio_buffer_*` over ma_audio_buffer (the owning variant).
Frames are f32 here, matching the format the tests use; the shim itself takes a
ma_format code and is format-agnostic.

miniaudio's map/unmap pair hands out a pointer into the buffer's interior that
Mojo has no safe home for, so the shim owns that sequence and this layer exposes
it as `*_map_read`, which copies the mapped frames out.
"""

from miniaudio._lib import MaLib, null_handle
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaBool


# ---- ma_audio_buffer_ref — non-owning view ----------------------------------


def audio_buffer_ref_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_audio_buffer_ref_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def audio_buffer_ref_free(lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_audio_buffer_ref_free", NoneType](ab)


def audio_buffer_ref_init(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Points the ref at a shim-owned copy of frame_count frames from `src`."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_ref_init", Int32](
            ab, Int32(format), channels, src.unsafe_ptr(), frame_count
        )
    )


def audio_buffer_ref_init_null_data(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    frame_count: UInt64,
) -> Int:
    """init with a NULL source pointer — the shim rejects it (negative path)."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_ref_init", Int32](
            ab, Int32(format), channels, null_handle(), frame_count
        )
    )


def audio_buffer_ref_uninit(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_audio_buffer_ref_uninit", Int32](ab))


def audio_buffer_ref_set_data(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Replace the shim-owned frames and rewind the cursor to 0."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_ref_set_data", Int32](
            ab, src.unsafe_ptr(), frame_count
        )
    )


def audio_buffer_ref_read(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
    loop: Bool = False,
) -> MaCount:
    """Reads up to frame_count frames into `dst` (caller pre-sizes the buffer).

    Returns MaCount(result_code, frames_read); a short read means the end was hit.
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_read", Int32](
            ab,
            dst.unsafe_ptr(),
            frame_count,
            Int32(1) if loop else Int32(0),
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_ref_seek(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_audio_buffer_ref_seek", Int32](ab, frame_index)
    )


def audio_buffer_ref_map_read(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """map -> copy -> unmap. MA_AT_END means the cursor landed on the end."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_map_read", Int32](
            ab, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_ref_at_end(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_at_end", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def audio_buffer_ref_get_cursor(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_get_cursor", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_ref_get_length(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_get_length", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_ref_get_available(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_ref_get_available", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


# ---- ma_audio_buffer — owning buffer ----------------------------------------


def audio_buffer_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_audio_buffer_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def audio_buffer_free(lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_audio_buffer_free", NoneType](ab)


def audio_buffer_init(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Non-copying init: the shim keeps the frames alive for miniaudio."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_init", Int32](
            ab, Int32(format), channels, src.unsafe_ptr(), frame_count
        )
    )


def audio_buffer_init_copy(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Copying init: miniaudio allocates and copies the frames itself."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_init_copy", Int32](
            ab, Int32(format), channels, src.unsafe_ptr(), frame_count
        )
    )


def audio_buffer_init_copy_silent(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    frame_count: UInt64,
) -> Int:
    """init_copy with a NULL source — miniaudio fills the buffer with silence."""
    return Int(
        lib.handle.call["ma_shim_audio_buffer_init_copy", Int32](
            ab, Int32(format), channels, null_handle(), frame_count
        )
    )


def audio_buffer_alloc_and_init(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Heap-allocates the ma_audio_buffer with the frames in its trailing data.

    Upstream defect (miniaudio 0.11.25): this path clears the low 3 bytes of the
    first frame — see the note in ma_shim_audio_buffer.h. Bound as-is.
    """
    return Int(
        lib.handle.call["ma_shim_audio_buffer_alloc_and_init", Int32](
            ab, Int32(format), channels, src.unsafe_ptr(), frame_count
        )
    )


def audio_buffer_uninit(lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_audio_buffer_uninit", Int32](ab))


def audio_buffer_read(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
    loop: Bool = False,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_read", Int32](
            ab,
            dst.unsafe_ptr(),
            frame_count,
            Int32(1) if loop else Int32(0),
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_seek(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_audio_buffer_seek", Int32](ab, frame_index)
    )


def audio_buffer_map_read(
    lib: MaLib,
    ab: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """map -> copy -> unmap. MA_AT_END means the cursor landed on the end."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_map_read", Int32](
            ab, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_at_end(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_at_end", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def audio_buffer_get_cursor(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_get_cursor", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_get_length(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_get_length", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def audio_buffer_get_available(
    lib: MaLib, ab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_audio_buffer_get_available", Int32](
            ab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])
