"""Binding layer: raw 1:1 wrappers over the encoder shim functions.

Mirrors decoder_raw.mojo: deliberately thin and policy-free — marshals Mojo
types to the C ABI and returns the raw ma_result code (or a MaCount carrying
result+value). All lifecycle/error policy lives in the API layer (encoder.mojo).
This is the layer the TDD contract tests target directly.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


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
