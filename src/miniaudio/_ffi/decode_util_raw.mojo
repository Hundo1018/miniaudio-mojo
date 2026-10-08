"""Binding layer: raw 1:1 wrappers over the one-shot decode shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in
decode_util.mojo.

`ma_decode_file` / `ma_decode_memory` / `ma_decode_from_vfs` decode a whole
stream and return a buffer miniaudio allocated. `MaDecoded.frames` is that
buffer: it is owned by the caller and MUST be released with `decode_free`
exactly once when `result` is MA_SUCCESS (it is NULL otherwise). `format`,
`channels` and `sample_rate` describe what the buffer holds; `frame_count`
counts frames, not samples.
"""

from miniaudio._lib import MaLib, null_handle


@fieldwise_init
struct MaDecoded(Copyable, Movable):
    """Raw result of a one-shot decode; `frames` is owned by the caller."""

    var result: Int
    var frame_count: UInt64
    var frames: OpaquePointer[MutUntrackedOrigin]
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


@fieldwise_init
struct MaBackendConfig(Copyable, Movable):
    """Raw (result_code, preferred_format, seek_point_count)."""

    var result: Int
    var preferred_format: Int
    var seek_point_count: UInt32


def decoding_backend_config_init(
    lib: MaLib, preferred_format: Int, seek_point_count: UInt32
) -> MaBackendConfig:
    var fmt = [Int32(0)]
    var seeks = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_decoding_backend_config_init", Int32](
            Int32(preferred_format),
            seek_point_count,
            fmt.unsafe_ptr(),
            seeks.unsafe_ptr(),
        )
    )
    return MaBackendConfig(code, Int(fmt[0]), seeks[0])


def decode_file(
    lib: MaLib,
    path: String,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaDecoded:
    """Decodes a whole file. `format` / `channels` / `sample_rate` of 0 keep the native value."""
    var path_c = path + "\x00"
    var count = [UInt64(0)]
    var frames = [null_handle()]
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var sr = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_decode_file", Int32](
            path_c.as_bytes().unsafe_ptr(),
            Int32(format),
            channels,
            sample_rate,
            count.unsafe_ptr(),
            frames.unsafe_ptr(),
            fmt.unsafe_ptr(),
            ch.unsafe_ptr(),
            sr.unsafe_ptr(),
        )
    )
    return MaDecoded(code, count[0], frames[0], Int(fmt[0]), ch[0], sr[0])


def decode_memory(
    lib: MaLib,
    data: List[UInt8],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaDecoded:
    """Decodes an in-memory file image. `data` need only live for the call."""
    var count = [UInt64(0)]
    var frames = [null_handle()]
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var sr = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_decode_memory", Int32](
            data.unsafe_ptr(),
            len(data),
            Int32(format),
            channels,
            sample_rate,
            count.unsafe_ptr(),
            frames.unsafe_ptr(),
            fmt.unsafe_ptr(),
            ch.unsafe_ptr(),
            sr.unsafe_ptr(),
        )
    )
    return MaDecoded(code, count[0], frames[0], Int(fmt[0]), ch[0], sr[0])


def decode_from_vfs(
    lib: MaLib,
    vfs: OpaquePointer[MutUntrackedOrigin],
    path: String,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaDecoded:
    """Decodes a file through a Vfs handle (an initialised ma_shim_vfs_*), or
    through miniaudio's default file system when `vfs` is null."""
    var path_c = path + "\x00"
    var count = [UInt64(0)]
    var frames = [null_handle()]
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var sr = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_decode_from_vfs", Int32](
            vfs,
            path_c.as_bytes().unsafe_ptr(),
            Int32(format),
            channels,
            sample_rate,
            count.unsafe_ptr(),
            frames.unsafe_ptr(),
            fmt.unsafe_ptr(),
            ch.unsafe_ptr(),
            sr.unsafe_ptr(),
        )
    )
    return MaDecoded(code, count[0], frames[0], Int(fmt[0]), ch[0], sr[0])


def decode_free(lib: MaLib, frames: OpaquePointer[MutUntrackedOrigin]):
    """Releases a buffer returned by a successful decode. Null is a no-op."""
    lib.handle.call["ma_shim_decode_free", NoneType](frames)
