"""Idiomatic context and VFS API (Layer 3).

`Context` is miniaudio's backend handle — the thing that knows which audio
devices exist. It is built on the null backend here, so enumeration returns
miniaudio's synthetic devices and no hardware is touched.

Three of its calls hand back things Mojo cannot hold: the enumeration callback,
the device-info arrays the context owns, and the log pointer. Each is bound as
what can safely cross — a count, two counts, and a yes/no.

`Vfs` wraps miniaudio's default (stdio) file system. `ma_vfs_file` is an opaque
pointer, so an open file lives in a slot on the handle rather than in a Mojo
value. There are two slots, because miniaudio has two entry points for every
operation: the plain `ma_vfs_*` family and the `ma_vfs_or_default_*` family,
which falls back to the default VFS when given none. The `*_via_default` methods
here drive that second path.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.context_raw as raw


comptime OPEN_MODE_READ = UInt32(1)
comptime OPEN_MODE_WRITE = UInt32(2)

comptime SEEK_ORIGIN_START = Int(0)
comptime SEEK_ORIGIN_CURRENT = Int(1)
comptime SEEK_ORIGIN_END = Int(2)


@fieldwise_init
struct DeviceCounts(Copyable, Movable):
    """How many devices of each direction the context knows about."""

    var playback: UInt32
    var capture: UInt32


@fieldwise_init
struct DeviceSummary(Copyable, Movable):
    """What a device info can say once the pointer is left behind."""

    var name_length: UInt32
    var native_format_count: UInt32


struct Context(Movable):
    """miniaudio's backend handle, on the null backend (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        var ptr = raw.context_alloc(lib[])
        if ptr == null_handle():
            raise Error("context_alloc failed (out of memory)")
        var code = raw.context_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.context_free(lib[], ptr)
            raise Error(lib[].describe("context init failed", code))
        return Self(lib.copy(), ptr)

    @staticmethod
    def size_in_bytes(lib: ArcPointer[MaLib]) raises -> UInt64:
        """How large an ma_context is — answerable without building one."""
        var rc = raw.context_sizeof(lib[])
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("context sizeof failed", rc.result))
        return rc.value

    def has_log(self) raises -> Bool:
        var rc = raw.context_has_log(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("context log failed", rc.result))
        return rc.value

    def is_loopback_supported(self) raises -> Bool:
        var rc = raw.context_is_loopback_supported(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("context loopback failed", rc.result))
        return rc.value

    def enumerate_devices(mut self) raises -> UInt32:
        """Run miniaudio's enumeration; returns how many devices it offered."""
        var rc = raw.context_enumerate_devices(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("context enumerate failed", rc.result))
        return rc.value

    def device_counts(mut self) raises -> DeviceCounts:
        """The lengths of the device arrays the context keeps."""
        var rc = raw.context_get_devices(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("context get_devices failed", rc.result))
        return DeviceCounts(rc.playback, rc.capture)

    def default_device(mut self, device_type: Int) raises -> DeviceSummary:
        """Summarise the backend's default device of that type."""
        var rc = raw.context_get_device_info(self._lib[], self._ptr, device_type)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("context device info failed", rc.result)
            )
        return DeviceSummary(rc.name_length, rc.native_format_count)

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.context_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("context uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.context_free(self._lib[], self._ptr)


struct Vfs(Movable):
    """miniaudio's default (stdio) file system (RAII).

    One file at a time per path: `open` puts it in the handle's slot and the
    other methods work on that slot. The `*_via_default` methods drive
    miniaudio's `_or_default` entry points, which take a NULL VFS and fall back
    to the default one; they use a second, independent slot.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        var ptr = raw.vfs_alloc(lib[])
        if ptr == null_handle():
            raise Error("vfs_alloc failed (out of memory)")
        var code = raw.vfs_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.vfs_free(lib[], ptr)
            raise Error(lib[].describe("default vfs init failed", code))
        return Self(lib.copy(), ptr)

    def open(mut self, path: String, *, mode: UInt32 = OPEN_MODE_READ) raises:
        var code = raw.vfs_open(self._lib[], self._ptr, path, mode)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs open failed", code))

    def close(mut self) raises:
        var code = raw.vfs_close(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs close failed", code))

    def read(mut self, size: UInt64) raises -> List[UInt8]:
        """Read up to `size` bytes; the result is truncated to what arrived."""
        var buf = List[UInt8](capacity=Int(size))
        buf.resize(Int(size), UInt8(0))
        var rc = raw.vfs_read(self._lib[], self._ptr, buf, size)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs read failed", rc.result))
        buf.resize(Int(rc.value), UInt8(0))
        return buf^

    def write(mut self, data: List[UInt8]) raises -> UInt64:
        var rc = raw.vfs_write(self._lib[], self._ptr, data)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs write failed", rc.result))
        return rc.value

    def seek(mut self, offset: Int64, *, origin: Int = SEEK_ORIGIN_START) raises:
        var code = raw.vfs_seek(self._lib[], self._ptr, offset, origin)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs seek failed", code))

    def tell(mut self) raises -> Int64:
        var rc = raw.vfs_tell(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs tell failed", rc.result))
        return rc.value

    def size(mut self) raises -> UInt64:
        """The open file's size in bytes."""
        var rc = raw.vfs_info(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs info failed", rc.result))
        return rc.value

    def read_whole_file(mut self, path: String) raises -> UInt64:
        """Read a file in one call; returns its size. The shim frees the block."""
        var rc = raw.vfs_open_and_read_file(self._lib[], self._ptr, path)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("vfs open_and_read_file failed", rc.result)
            )
        return rc.value

    def open_via_default(
        mut self, path: String, *, mode: UInt32 = OPEN_MODE_READ
    ) raises:
        """Open through the fallback path, which takes no VFS at all."""
        var code = raw.vfs_or_default_open(self._lib[], self._ptr, path, mode)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default open failed", code))

    def close_via_default(mut self) raises:
        var code = raw.vfs_or_default_close(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default close failed", code))

    def read_via_default(mut self, size: UInt64) raises -> List[UInt8]:
        var buf = List[UInt8](capacity=Int(size))
        buf.resize(Int(size), UInt8(0))
        var rc = raw.vfs_or_default_read(self._lib[], self._ptr, buf, size)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default read failed", rc.result))
        buf.resize(Int(rc.value), UInt8(0))
        return buf^

    def write_via_default(mut self, data: List[UInt8]) raises -> UInt64:
        var rc = raw.vfs_or_default_write(self._lib[], self._ptr, data)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("vfs or_default write failed", rc.result)
            )
        return rc.value

    def seek_via_default(
        mut self, offset: Int64, *, origin: Int = SEEK_ORIGIN_START
    ) raises:
        var code = raw.vfs_or_default_seek(self._lib[], self._ptr, offset, origin)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default seek failed", code))

    def tell_via_default(mut self) raises -> Int64:
        var rc = raw.vfs_or_default_tell(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default tell failed", rc.result))
        return rc.value

    def size_via_default(mut self) raises -> UInt64:
        var rc = raw.vfs_or_default_info(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vfs or_default info failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.vfs_free(self._lib[], self._ptr)
