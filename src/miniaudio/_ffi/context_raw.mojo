"""Binding layer: raw 1:1 wrappers over the context and VFS shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in context.mojo.

The context runs on the null backend, so device enumeration returns miniaudio's
synthetic devices and no hardware is touched. `ma_context_enumerate_devices`
takes a callback Mojo cannot supply, so the shim owns one that counts what it is
offered; `ma_context_get_devices` hands back arrays the context owns, so only
their lengths cross over.

The VFS half wraps miniaudio's default (stdio) VFS. `ma_vfs_file` is an opaque
pointer with no safe Mojo home, so files live in slots on the handle — one for
the shim's own VFS and one for the `_or_default` fallback path.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt, MaBool


@fieldwise_init
struct MaCounts(Copyable, Movable):
    """Raw (result_code, playback count, capture count) for get_devices."""

    var result: Int
    var playback: UInt32
    var capture: UInt32


@fieldwise_init
struct MaDeviceSummary(Copyable, Movable):
    """Raw (result_code, name length, native format count) for get_device_info."""

    var result: Int
    var name_length: UInt32
    var native_format_count: UInt32


@fieldwise_init
struct MaCursor(Copyable, Movable):
    """Raw (result_code, signed cursor) pair for the VFS tell calls."""

    var result: Int
    var value: Int64


# ================= context =================


def context_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_context_alloc", OpaquePointer[MutUntrackedOrigin]]()


def context_free(lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_context_free", NoneType](c)


def context_init(lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Initialises on the null backend, so enumeration is deterministic."""
    return Int(lib.handle.call["ma_shim_context_init", Int32](c))


def context_uninit(lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_context_uninit", Int32](c))


def context_sizeof(lib: MaLib) -> MaCount:
    """Size of an ma_context, which miniaudio reports without one existing."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_sizeof", Int32](holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def context_has_log(lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_has_log", Int32](c, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != Int32(0))


def context_is_loopback_supported(
    lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_is_loopback_supported", Int32](
            c, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def context_enumerate_devices(
    lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    """Runs the enumeration and reports how many devices the callback saw."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_enumerate_devices", Int32](
            c, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def context_get_devices(
    lib: MaLib, c: OpaquePointer[MutUntrackedOrigin]
) -> MaCounts:
    var playback = [UInt32(0)]
    var capture = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_get_devices", Int32](
            c, playback.unsafe_ptr(), capture.unsafe_ptr()
        )
    )
    return MaCounts(code, playback[0], capture[0])


def context_get_device_info(
    lib: MaLib, c: OpaquePointer[MutUntrackedOrigin], device_type: Int
) -> MaDeviceSummary:
    """The default device of that type, summarised in numbers Mojo can hold."""
    var name_length = [UInt32(0)]
    var formats = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_context_get_device_info", Int32](
            c, Int32(device_type), name_length.unsafe_ptr(), formats.unsafe_ptr()
        )
    )
    return MaDeviceSummary(code, name_length[0], formats[0])


# ================= VFS =================


def vfs_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_vfs_alloc", OpaquePointer[MutUntrackedOrigin]]()


def vfs_free(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_vfs_free", NoneType](v)


def vfs_init(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_vfs_init", Int32](v))


def vfs_open(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], path: String, open_mode: UInt32
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_vfs_open", Int32](
            v, path_c.as_bytes().unsafe_ptr(), open_mode
        )
    )


def vfs_close(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_vfs_close", Int32](v))


def vfs_read(
    lib: MaLib,
    v: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[UInt8],
    size: UInt64,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_read", Int32](
            v, dst.unsafe_ptr(), size, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def vfs_write(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], src: List[UInt8]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_write", Int32](
            v, src.unsafe_ptr(), UInt64(len(src)), holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def vfs_seek(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], offset: Int64, origin: Int = 0
) -> Int:
    return Int(
        lib.handle.call["ma_shim_vfs_seek", Int32](v, offset, Int32(origin))
    )


def vfs_tell(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> MaCursor:
    var holder = [Int64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_tell", Int32](v, holder.unsafe_ptr())
    )
    return MaCursor(code, holder[0])


def vfs_info(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    """File size in bytes."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_info", Int32](v, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def vfs_open_and_read_file(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], path: String
) -> MaCount:
    """Reads a whole file in one call; the shim frees the block, size comes back."""
    var path_c = path + "\x00"
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_open_and_read_file", Int32](
            v, path_c.as_bytes().unsafe_ptr(), holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def vfs_or_default_open(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], path: String, open_mode: UInt32
) -> Int:
    """The fallback path: a NULL VFS means "use the default"."""
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_vfs_or_default_open", Int32](
            v, path_c.as_bytes().unsafe_ptr(), open_mode
        )
    )


def vfs_or_default_close(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_vfs_or_default_close", Int32](v))


def vfs_or_default_read(
    lib: MaLib,
    v: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[UInt8],
    size: UInt64,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_or_default_read", Int32](
            v, dst.unsafe_ptr(), size, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def vfs_or_default_write(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], src: List[UInt8]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_or_default_write", Int32](
            v, src.unsafe_ptr(), UInt64(len(src)), holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def vfs_or_default_seek(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin], offset: Int64, origin: Int = 0
) -> Int:
    return Int(
        lib.handle.call["ma_shim_vfs_or_default_seek", Int32](
            v, offset, Int32(origin)
        )
    )


def vfs_or_default_tell(
    lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]
) -> MaCursor:
    var holder = [Int64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_or_default_tell", Int32](v, holder.unsafe_ptr())
    )
    return MaCursor(code, holder[0])


def vfs_or_default_info(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_vfs_or_default_info", Int32](v, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])
