"""Binding layer: raw 1:1 wrappers over the decoder shim functions.

These are deliberately thin and policy-free — they marshal Mojo types to the C
ABI and return the raw ma_result code (or a MaCount carrying result+value). All
lifecycle/error policy lives in the API layer (decoder.mojo). This is the layer
that the TDD contract tests target directly.
"""

from miniaudio._lib import MaLib


@fieldwise_init
struct MaCount(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a uint64 out-param."""

    var result: Int
    var value: UInt64


def decoder_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_decoder_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def decoder_free(lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_decoder_free", NoneType](dec)


def decoder_init_file(
    lib: MaLib,
    dec: OpaquePointer[MutUntrackedOrigin],
    path: String,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_decoder_init_file", Int32](
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
) -> Int:
    return Int(
        lib.handle.call["ma_shim_decoder_init_memory", Int32](
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
) -> Int:
    """Init from a file with the default (native-format-preserving) config."""
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_decoder_init_file_default", Int32](
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
) -> Int:
    """Init from a file path through the VFS API (default stdio VFS)."""
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_decoder_init_file_vfs", Int32](
            dec,
            path_c.as_bytes().unsafe_ptr(),
            Int32(format),
            channels,
            sample_rate,
        )
    )


def decoder_uninit(lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_decoder_uninit", Int32](dec))


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
    var code = Int(
        lib.handle.call["ma_shim_decoder_read_pcm_frames", Int32](
            dec,
            out.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def decoder_seek_to_pcm_frame(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_decoder_seek_to_pcm_frame", Int32](
            dec, frame_index
        )
    )


def decoder_get_length_in_pcm_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_decoder_get_length_in_pcm_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_get_cursor_in_pcm_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_decoder_get_cursor_in_pcm_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_get_available_frames(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    """Frames still available to read from the current cursor position."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_decoder_get_available_frames", Int32](
            dec, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def decoder_output_channels(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_decoder_output_channels", UInt32](dec)


def decoder_output_sample_rate(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_decoder_output_sample_rate", UInt32](dec)


def decoder_output_format(
    lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_decoder_output_format", Int32](dec))
