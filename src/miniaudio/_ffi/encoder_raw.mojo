"""Binding layer: raw 1:1 wrappers over the encoder shim functions.

Mirrors decoder_raw.mojo: deliberately thin and policy-free — marshals Mojo
types to the C ABI and returns the raw ma_result code (or a MaCount carrying
result+value). All lifecycle/error policy lives in the API layer (encoder.mojo).
This is the layer the TDD contract tests target directly.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio.stream import WriteSeekStream
from miniaudio._ffi.stream_raw import (
    StreamPtr,
    sink_write_tramp,
    sink_seek_tramp,
    stream_destroy,
    stream_tag,
)


def encoder_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_encoder_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def encoder_free(lib: MaLib, enc: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_encoder_free", NoneType](enc)


def encoder_init_file(
    lib: MaLib,
    enc: OpaquePointer[MutUntrackedOrigin],
    path: String,
    encoding_format: Int,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_encoder_init_file", Int32](
            enc,
            path_c.as_bytes().unsafe_ptr(),
            Int32(encoding_format),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def encoder_init_file_vfs(
    lib: MaLib,
    enc: OpaquePointer[MutUntrackedOrigin],
    path: String,
    encoding_format: Int,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """Init to a file path through the VFS API (default stdio VFS)."""
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_encoder_init_file_vfs", Int32](
            enc,
            path_c.as_bytes().unsafe_ptr(),
            Int32(encoding_format),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def encoder_uninit(lib: MaLib, enc: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_encoder_uninit", Int32](enc))


def encoder_write_pcm_frames(
    lib: MaLib,
    enc: OpaquePointer[MutUntrackedOrigin],
    input: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Writes frame_count frames from `input` (interleaved, caller-sized).

    Returns MaCount(result_code, frames_written).
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_encoder_write_pcm_frames", Int32](
            enc,
            input.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def encoder_init_stream[
    S: WriteSeekStream
](
    lib: MaLib,
    enc: OpaquePointer[MutUntrackedOrigin],
    user: StreamPtr[S],
    encoding_format: Int,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """Init an encoder that writes through the sink at `user` (custom I/O).

    `user` is a heap cell from `stream_leak`. The shim ALWAYS takes it over,
    whether this succeeds or fails: it destroys the sink after the encoder is
    uninitialised (which is when the WAV header gets its final sizes), or
    straight away when init fails (invalid arguments included). The caller must
    not touch `user` afterwards.
    """
    return Int(
        lib.handle.call["ma_shim_encoder_init_stream", Int32](
            enc,
            sink_write_tramp[S],
            sink_seek_tramp[S],
            stream_destroy[S],
            user,
            stream_tag[S](),
            Int32(encoding_format),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def encoder_init_stream_ptrs(
    lib: MaLib,
    enc: OpaquePointer[MutUntrackedOrigin],
    on_write: OpaquePointer[MutUntrackedOrigin],
    on_seek: OpaquePointer[MutUntrackedOrigin],
    on_destroy: OpaquePointer[MutUntrackedOrigin],
    user: OpaquePointer[MutUntrackedOrigin],
    type_tag: UInt64,
    encoding_format: Int,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """The same shim call with every pointer passed bare, NULLs included. Only
    for exercising the shim's argument checks: a real sink goes through
    `encoder_init_stream`."""
    return Int(
        lib.handle.call["ma_shim_encoder_init_stream", Int32](
            enc,
            on_write,
            on_seek,
            on_destroy,
            user,
            type_tag,
            Int32(encoding_format),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def encoder_stream_user(
    lib: MaLib, enc: OpaquePointer[MutUntrackedOrigin], type_tag: UInt64
) -> OpaquePointer[MutUntrackedOrigin]:
    """The sink the encoder was initialised with, or NULL if it has none or
    `type_tag` (see `stream_tag`) is not the tag it was initialised with."""
    return lib.handle.call[
        "ma_shim_encoder_stream_user", OpaquePointer[MutUntrackedOrigin]
    ](enc, type_tag)
