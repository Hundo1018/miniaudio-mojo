"""Binding layer: raw 1:1 wrappers over the paged audio buffer shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
paged_audio_buffer.mojo.

One shim handle owns both halves of the family — the page list
(`data_*`) and the reader over it. Pages themselves are raw pointers with no
safe Mojo home, so `data_allocate_page` returns a slot index on the handle that
`data_append_page` / `data_free_page` take back, and the head/tail getters are
bound as the page properties Mojo can assert on.

Frames are f32 here, matching the format the tests use; the shim itself takes a
ma_format code and is format-agnostic.
"""

from miniaudio._lib import MaLib, null_handle
from miniaudio._ffi.decoder_raw import MaCount


@fieldwise_init
struct MaPage(Copyable, Movable):
    """Raw (result_code, frame count, list-is-empty) triple for a page getter."""

    var result: Int
    var frames: UInt64
    var list_is_empty: Bool


@fieldwise_init
struct MaSlot(Copyable, Movable):
    """Raw (result_code, slot index) pair for data_allocate_page."""

    var result: Int
    var value: Int


def paged_audio_buffer_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_paged_audio_buffer_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def paged_audio_buffer_free(lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_paged_audio_buffer_free", NoneType](pab)


# ---- the page list ----------------------------------------------------------


def paged_audio_buffer_data_init(
    lib: MaLib,
    pab: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_init", Int32](
            pab, Int32(format), channels
        )
    )


def paged_audio_buffer_data_uninit(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_uninit", Int32](pab)
    )


def paged_audio_buffer_data_get_length(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    """Total frames across every appended page."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_get_length", Int32](
            pab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def paged_audio_buffer_data_get_head(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> MaPage:
    """The head dummy: always 0 frames; `list_is_empty` is False once appended to."""
    var size = [UInt64(0)]
    var has_pages = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_get_head", Int32](
            pab, size.unsafe_ptr(), has_pages.unsafe_ptr()
        )
    )
    return MaPage(code, size[0], has_pages[0] == Int32(0))


def paged_audio_buffer_data_get_tail(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> MaPage:
    """The last appended page, or the head dummy while the list is empty."""
    var size = [UInt64(0)]
    var is_head = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_get_tail", Int32](
            pab, size.unsafe_ptr(), is_head.unsafe_ptr()
        )
    )
    return MaPage(code, size[0], is_head[0] != Int32(0))


def paged_audio_buffer_data_allocate_page(
    lib: MaLib,
    pab: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    page_size_in_frames: UInt64,
) -> MaSlot:
    """Allocate a page from `src` and park it in a handle slot."""
    var holder = [Int32(-1)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_allocate_page", Int32](
            pab, page_size_in_frames, src.unsafe_ptr(), holder.unsafe_ptr()
        )
    )
    return MaSlot(code, Int(holder[0]))


def paged_audio_buffer_data_allocate_page_silent(
    lib: MaLib,
    pab: OpaquePointer[MutUntrackedOrigin],
    page_size_in_frames: UInt64,
) -> MaSlot:
    """Allocate an uninitialised page (NULL initial data)."""
    var holder = [Int32(-1)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_allocate_page", Int32](
            pab, page_size_in_frames, null_handle(), holder.unsafe_ptr()
        )
    )
    return MaSlot(code, Int(holder[0]))


def paged_audio_buffer_data_append_page(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin], slot: Int
) -> Int:
    return Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_append_page", Int32](
            pab, Int32(slot)
        )
    )


def paged_audio_buffer_data_free_page(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin], slot: Int
) -> Int:
    return Int(
        lib.handle.call["ma_shim_paged_audio_buffer_data_free_page", Int32](
            pab, Int32(slot)
        )
    )


def paged_audio_buffer_data_allocate_and_append_page(
    lib: MaLib,
    pab: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    page_size_in_frames: UInt32,
) -> Int:
    return Int(
        lib.handle.call[
            "ma_shim_paged_audio_buffer_data_allocate_and_append_page", Int32
        ](pab, page_size_in_frames, src.unsafe_ptr())
    )


# ---- the reader -------------------------------------------------------------


def paged_audio_buffer_init(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_paged_audio_buffer_init", Int32](pab))


def paged_audio_buffer_uninit(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_paged_audio_buffer_uninit", Int32](pab))


def paged_audio_buffer_read(
    lib: MaLib,
    pab: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count frames. MA_AT_END means the pages ran out."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_read", Int32](
            pab, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def paged_audio_buffer_seek(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_paged_audio_buffer_seek", Int32](pab, frame_index)
    )


def paged_audio_buffer_get_cursor(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_get_cursor", Int32](
            pab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def paged_audio_buffer_get_length(
    lib: MaLib, pab: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_paged_audio_buffer_get_length", Int32](
            pab, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])
