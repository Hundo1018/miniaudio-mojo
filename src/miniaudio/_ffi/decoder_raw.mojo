"""Binding layer: raw 1:1 wrappers over the decoder shim functions.

These are deliberately thin and policy-free — they marshal Mojo types to the C
ABI and return the raw ma_result code (or a MaCount carrying result+value). All
lifecycle/error policy lives in the API layer (decoder.mojo). This is the layer
that the TDD contract tests target directly.
"""

from miniaudio._lib import MaLib
from miniaudio.result import MaResult
from miniaudio.stream import ReadSeekStream
from miniaudio._ffi.stream_raw import (
    StreamPtr,
    stream_read_tramp,
    stream_seek_tramp,
    stream_destroy,
    stream_tag,
)


@fieldwise_init
struct MaCount(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a uint64 out-param."""

    var result: MaResult
    var value: UInt64


def decoder_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.call[
        "ma_shim_decoder_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def decoder_free(lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]):
    lib.call["ma_shim_decoder_free", NoneType](dec)


def decoder_init_file(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    path: String,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_decoder_init_file", Int32](
            dec,
            path_c.as_bytes().unsafe_ptr(),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_init_memory(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    data: List[UInt8],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    return MaResult(
        lib.call["ma_shim_decoder_init_memory", Int32](
            dec,
            data.unsafe_ptr(),
            len(data),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_init_file_default(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    path: String,
) -> MaResult:
    """Init from a file with the default (native-format-preserving) config."""
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_decoder_init_file_default", Int32](
            dec,
            path_c.as_bytes().unsafe_ptr(),
        )
    )


def decoder_init_file_vfs(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    path: String,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    """Init from a file path through the VFS API (default stdio VFS)."""
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_decoder_init_file_vfs", Int32](
            dec,
            path_c.as_bytes().unsafe_ptr(),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_uninit(lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(lib.call["ma_shim_decoder_uninit", Int32](dec))


def decoder_read_pcm_frames(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count frames into `out` (caller pre-sizes the buffer).

    Returns MaCount(result_code, frames_read). frames_read is meaningful when
    result is MA_SUCCESS or MA_AT_END.
    """
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_decoder_read_pcm_frames", Int32](
            dec,
            out.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def decoder_seek_to_pcm_frame(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> MaResult:
    return MaResult(
        lib.call["ma_shim_decoder_seek_to_pcm_frame", Int32](
            dec, frame_index
        )
    )


def decoder_get_length_in_pcm_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_decoder_get_length_in_pcm_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_get_cursor_in_pcm_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_decoder_get_cursor_in_pcm_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_get_available_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    """Frames still available to read from the current cursor position."""
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_decoder_get_available_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_output_channels(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.call["ma_shim_decoder_output_channels", UInt32](dec)


def decoder_output_sample_rate(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.call["ma_shim_decoder_output_sample_rate", UInt32](dec)


def decoder_output_format(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.call["ma_shim_decoder_output_format", Int32](dec))


def decoder_init_stream[
    S: ReadSeekStream
](
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    user: StreamPtr[S],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    """Init a decoder that reads through the stream at `user` (custom I/O).

    `user` is a heap cell from `stream_leak`. The shim ALWAYS takes it over,
    whether this succeeds or fails: it destroys the stream after the decoder is
    uninitialised, or straight away when init fails (invalid arguments
    included). The caller must not touch `user` afterwards.
    """
    return MaResult(
        lib.call["ma_shim_decoder_init_stream", Int32](
            dec,
            stream_read_tramp[S],
            stream_seek_tramp[S],
            stream_destroy[S],
            user,
            stream_tag[S](),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_init_stream_ptrs(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    on_read: OpaquePointer[MutUntrackedOrigin],
    on_seek: OpaquePointer[MutUntrackedOrigin],
    on_destroy: OpaquePointer[MutUntrackedOrigin],
    user: OpaquePointer[MutUntrackedOrigin],
    type_tag: UInt64,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    """The same shim call with every pointer passed bare, NULLs included. Only
    for exercising the shim's argument checks: a real stream goes through
    `decoder_init_stream`."""
    return MaResult(
        lib.call["ma_shim_decoder_init_stream", Int32](
            dec,
            on_read,
            on_seek,
            on_destroy,
            user,
            type_tag,
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_stream_user(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin], type_tag: UInt64
) -> OpaquePointer[MutUntrackedOrigin]:
    """The stream the decoder was initialised with, or NULL if it has none or
    `type_tag` (see `stream_tag`) is not the tag it was initialised with."""
    return lib.call[
        "ma_shim_decoder_stream_user", OpaquePointer[MutUntrackedOrigin]
    ](dec, type_tag)
