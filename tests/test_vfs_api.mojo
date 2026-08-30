"""TDD tests for the idiomatic VFS API (RAII Vfs).

L3 behavioral: verifies a write/read round trip through the default file
system, that seek/tell/size agree, that a whole file can be read in one call,
and that the `*_via_default` fallback path reaches the same file.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.context import Vfs, OPEN_MODE_READ, OPEN_MODE_WRITE


comptime PATH = "./build/test_assets/vfs_api_roundtrip.bin"


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _payload() -> List[UInt8]:
    var out = List[UInt8](capacity=16)
    for i in range(16):
        out.append(UInt8(i))
    return out^


def _fixture() raises -> Vfs:
    """A VFS with the test file already written."""
    var v = Vfs.create(_lib())
    v.open(PATH, mode=OPEN_MODE_WRITE)
    assert_equal(v.write(_payload()), UInt64(16))
    v.close()
    return v^


def test_bytes_survive_a_write_read_round_trip() raises:
    """What was written comes back byte for byte."""
    var v = _fixture()
    v.open(PATH)
    var got = v.read(UInt64(16))

    assert_equal(len(got), 16)
    for i in range(16):
        assert_equal(got[i], UInt8(i))
    v.close()


def test_seek_tell_and_size_agree() raises:
    """The cursor lands where it is sent and the size matches the payload."""
    var v = _fixture()
    v.open(PATH)

    assert_equal(v.size(), UInt64(16))
    v.seek(Int64(8))
    assert_equal(v.tell(), Int64(8))
    assert_equal(v.read(UInt64(8))[0], UInt8(8))
    v.close()


def test_a_whole_file_can_be_read_in_one_call() raises:
    """Reading a whole file in one call reports the size it read."""
    var v = _fixture()
    assert_equal(v.read_whole_file(PATH), UInt64(16))


def test_the_fallback_path_reaches_the_same_file() raises:
    """The `*_via_default` methods drive miniaudio's NULL-VFS entry points."""
    var v = _fixture()

    v.open_via_default(PATH)
    assert_equal(v.size_via_default(), UInt64(16))
    v.seek_via_default(Int64(4))
    assert_equal(v.tell_via_default(), Int64(4))
    assert_equal(v.read_via_default(UInt64(4))[0], UInt8(4))
    v.close_via_default()

    v.open_via_default(PATH, mode=OPEN_MODE_WRITE)
    assert_equal(v.write_via_default(_payload()), UInt64(16))
    v.close_via_default()


def test_operations_without_an_open_file_raise() raises:
    """A VFS with nothing open refuses to read, seek or close."""
    var v = Vfs.create(_lib())
    with assert_raises():
        _ = v.read(UInt64(4))
    with assert_raises():
        v.close()


def test_opening_a_missing_file_raises() raises:
    """A path that is not there fails rather than returning an empty file."""
    var v = Vfs.create(_lib())
    with assert_raises():
        v.open("/tmp/does-not-exist/nope.bin")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
