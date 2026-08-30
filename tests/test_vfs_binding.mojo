"""TDD contract tests for the VFS BINDING layer (raw 1:1 over the shim).

Deterministic: everything runs against a file the test writes itself under
build/. All 16 bindable MA_API VFS functions are exercised here (positive and
negative paths); the 3 `_w` wide-char variants are excluded project-wide.

Both entry-point families are covered: the plain `ma_vfs_*` calls against the
shim's own default VFS, and the `ma_vfs_or_default_*` calls with a NULL VFS,
which is the fallback those functions exist for.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.context_raw as raw


comptime PATH = "./build/test_assets/vfs_roundtrip.bin"
comptime MODE_READ: UInt32 = 1
comptime MODE_WRITE: UInt32 = 2


def _lib() raises -> MaLib:
    return MaLib.default()


def _vfs(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var v = raw.vfs_alloc(lib)
    assert_true(v != null_handle())
    assert_equal(raw.vfs_init(lib, v), MA_SUCCESS)
    return v


def _payload() -> List[UInt8]:
    var out = List[UInt8](capacity=16)
    for i in range(16):
        out.append(UInt8(i))
    return out^


def _write_fixture(lib: MaLib, v: OpaquePointer[MutUntrackedOrigin]) raises:
    assert_equal(raw.vfs_open(lib, v, PATH, MODE_WRITE), MA_SUCCESS)
    var written = raw.vfs_write(lib, v, _payload())
    assert_equal(written.result, MA_SUCCESS)
    assert_equal(written.value, UInt64(16))
    assert_equal(raw.vfs_close(lib, v), MA_SUCCESS)


def test_a_file_written_through_the_vfs_reads_back() raises:
    """Write, reopen, read: the bytes survive the round trip."""
    var lib = _lib()
    var v = _vfs(lib)
    _write_fixture(lib, v)

    assert_equal(raw.vfs_open(lib, v, PATH, MODE_READ), MA_SUCCESS)
    var dst = List[UInt8]()
    dst.resize(16, UInt8(0))
    var read = raw.vfs_read(lib, v, dst, UInt64(16))
    assert_equal(read.result, MA_SUCCESS)
    assert_equal(read.value, UInt64(16))
    for i in range(16):
        assert_equal(dst[i], UInt8(i))

    assert_equal(raw.vfs_close(lib, v), MA_SUCCESS)
    raw.vfs_free(lib, v)


def test_seek_tell_and_info_agree_on_the_file() raises:
    """The cursor moves where it is told and the size matches what was written."""
    var lib = _lib()
    var v = _vfs(lib)
    _write_fixture(lib, v)

    assert_equal(raw.vfs_open(lib, v, PATH, MODE_READ), MA_SUCCESS)
    var size = raw.vfs_info(lib, v)
    assert_equal(size.result, MA_SUCCESS)
    assert_equal(size.value, UInt64(16))

    assert_equal(raw.vfs_seek(lib, v, Int64(8), 0), MA_SUCCESS)
    var cursor = raw.vfs_tell(lib, v)
    assert_equal(cursor.result, MA_SUCCESS)
    assert_equal(cursor.value, Int64(8))

    var dst = List[UInt8]()
    dst.resize(8, UInt8(0))
    assert_equal(raw.vfs_read(lib, v, dst, UInt64(8)).value, UInt64(8))
    assert_equal(dst[0], UInt8(8))

    assert_equal(raw.vfs_close(lib, v), MA_SUCCESS)
    raw.vfs_free(lib, v)


def test_a_whole_file_can_be_read_in_one_call() raises:
    """Reading a whole file in one call reports the size it read."""
    var lib = _lib()
    var v = _vfs(lib)
    _write_fixture(lib, v)

    var rc = raw.vfs_open_and_read_file(lib, v, PATH)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(16))

    raw.vfs_free(lib, v)


def test_the_or_default_family_reaches_the_same_file() raises:
    """The NULL-VFS fallback path does everything the plain family does."""
    var lib = _lib()
    var v = _vfs(lib)
    _write_fixture(lib, v)

    assert_equal(raw.vfs_or_default_open(lib, v, PATH, MODE_READ), MA_SUCCESS)
    assert_equal(raw.vfs_or_default_info(lib, v).value, UInt64(16))
    assert_equal(raw.vfs_or_default_seek(lib, v, Int64(4), 0), MA_SUCCESS)
    assert_equal(raw.vfs_or_default_tell(lib, v).value, Int64(4))

    var dst = List[UInt8]()
    dst.resize(4, UInt8(0))
    var read = raw.vfs_or_default_read(lib, v, dst, UInt64(4))
    assert_equal(read.result, MA_SUCCESS)
    assert_equal(read.value, UInt64(4))
    assert_equal(dst[0], UInt8(4))
    assert_equal(raw.vfs_or_default_close(lib, v), MA_SUCCESS)

    # And the write side of the fallback path.
    assert_equal(raw.vfs_or_default_open(lib, v, PATH, MODE_WRITE), MA_SUCCESS)
    assert_equal(raw.vfs_or_default_write(lib, v, _payload()).value, UInt64(16))
    assert_equal(raw.vfs_or_default_close(lib, v), MA_SUCCESS)

    raw.vfs_free(lib, v)


def test_operations_without_an_open_file_are_invalid() raises:
    """Every file operation rejects a handle with nothing open."""
    var lib = _lib()
    var v = _vfs(lib)
    var dst = List[UInt8]()
    dst.resize(4, UInt8(0))

    assert_equal(raw.vfs_close(lib, v), MA_INVALID_ARGS)
    assert_equal(raw.vfs_read(lib, v, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.vfs_write(lib, v, _payload()).result, MA_INVALID_ARGS)
    assert_equal(raw.vfs_seek(lib, v, Int64(0), 0), MA_INVALID_ARGS)
    assert_equal(raw.vfs_tell(lib, v).result, MA_INVALID_ARGS)
    assert_equal(raw.vfs_info(lib, v).result, MA_INVALID_ARGS)

    assert_equal(raw.vfs_or_default_close(lib, v), MA_INVALID_ARGS)
    assert_equal(
        raw.vfs_or_default_read(lib, v, dst, UInt64(4)).result, MA_INVALID_ARGS
    )
    assert_equal(raw.vfs_or_default_write(lib, v, _payload()).result, MA_INVALID_ARGS)
    assert_equal(raw.vfs_or_default_seek(lib, v, Int64(0), 0), MA_INVALID_ARGS)
    assert_equal(raw.vfs_or_default_tell(lib, v).result, MA_INVALID_ARGS)
    assert_equal(raw.vfs_or_default_info(lib, v).result, MA_INVALID_ARGS)

    raw.vfs_free(lib, v)


def test_a_missing_file_and_null_handles_are_rejected() raises:
    """Opening what is not there fails, and an uninitialised handle refuses work."""
    var lib = _lib()
    var v = _vfs(lib)
    assert_true(
        raw.vfs_open(lib, v, "/tmp/does-not-exist/nope.bin", MODE_READ) != MA_SUCCESS
    )
    raw.vfs_free(lib, v)

    var fresh = raw.vfs_alloc(lib)
    assert_equal(raw.vfs_open(lib, fresh, PATH, MODE_READ), MA_INVALID_ARGS)
    raw.vfs_free(lib, fresh)

    assert_equal(raw.vfs_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.vfs_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
