"""TDD tests for the idiomatic MemoryBlock / AlignedBlock API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.util import MemoryBlock, AlignedBlock


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_allocated_block_stores_and_loads_bytes() raises:
    var b = MemoryBlock.allocate(_lib(), 32)
    assert_equal(b.size(), UInt64(32))
    assert_true(b.address() != 0)
    for i in range(32):
        b.store(i, UInt8(i * 2))
    for i in range(32):
        assert_equal(b.load(i), UInt8(i * 2))


def test_zeroed_block_is_all_zero() raises:
    var b = MemoryBlock.zeroed(_lib(), 512)
    var sum = 0
    for i in range(512):
        sum += Int(b.load(i))
    assert_equal(sum, 0)


def test_resize_keeps_the_bytes_that_fit() raises:
    var b = MemoryBlock.zeroed(_lib(), 16)
    for i in range(16):
        b.store(i, UInt8(200 + i))
    b.resize(1024)
    assert_equal(b.size(), UInt64(1024))
    for i in range(16):
        assert_equal(b.load(i), UInt8(200 + i))
    b.store(1023, 5)
    b.resize(4)
    assert_equal(b.size(), UInt64(4))
    assert_equal(b.load(3), UInt8(203))


def test_access_is_bounds_checked() raises:
    var b = MemoryBlock.zeroed(_lib(), 4)
    with assert_raises():
        _ = b.load(4)
    with assert_raises():
        _ = b.load(-1)
    with assert_raises():
        b.store(4, 1)


def test_zero_size_is_refused() raises:
    with assert_raises():
        _ = MemoryBlock.allocate(_lib(), 0)
    with assert_raises():
        _ = MemoryBlock.zeroed(_lib(), 0)
    var b = MemoryBlock.zeroed(_lib(), 8)
    with assert_raises():
        b.resize(0)
    assert_equal(b.size(), UInt64(8))  # a refused resize leaves the block as it was


def test_aligned_block_address_is_a_multiple_of_the_alignment() raises:
    var lib = _lib()
    var alignments: List[UInt64] = [16, 64, 128, 4096]
    for a in alignments:
        var b = AlignedBlock.allocate(lib, 200, a)
        assert_true(b.is_aligned())
        assert_equal(UInt64(b.address()) % a, UInt64(0))
        assert_equal(b.alignment(), a)
        assert_equal(b.size(), UInt64(200))


def test_aligned_block_stores_and_loads_bytes() raises:
    var b = AlignedBlock.allocate(_lib(), 64, 32)
    for i in range(64):
        b.store(i, UInt8(255 - i))
    for i in range(64):
        assert_equal(b.load(i), UInt8(255 - i))
    with assert_raises():
        _ = b.load(64)
    with assert_raises():
        b.store(64, 0)


def test_aligned_block_rejects_a_bad_alignment() raises:
    with assert_raises():
        _ = AlignedBlock.allocate(_lib(), 64, 0)
    with assert_raises():
        _ = AlignedBlock.allocate(_lib(), 64, 24)
    with assert_raises():
        _ = AlignedBlock.allocate(_lib(), 0, 16)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
