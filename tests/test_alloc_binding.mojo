"""TDD contract tests for the alloc BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: ma_malloc / ma_calloc / ma_realloc /
ma_free and the aligned pair run on the default allocator (NULL callbacks). All
6 MA_API alloc functions are exercised (positive and negative). Memory is read
and written through the returned pointers.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib, null_handle
import miniaudio._ffi.util_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def _byte(p: OpaquePointer[MutUntrackedOrigin], i: Int) -> UInt8:
    return p.unsafe_bitcast[UInt8]()[unsafe_offset=i]


def _set(p: OpaquePointer[MutUntrackedOrigin], i: Int, value: UInt8):
    p.unsafe_bitcast[UInt8]()[unsafe_offset=i] = value


def test_malloc_returns_usable_memory() raises:
    var lib = _lib()
    var p = raw.mem_malloc(lib, 64)
    assert_true(p != null_handle())
    for i in range(64):
        _set(p, i, UInt8(i))
    for i in range(64):
        assert_equal(_byte(p, i), UInt8(i))
    raw.mem_free(lib, p)


def test_malloc_refuses_a_zero_size() raises:
    var lib = _lib()
    assert_true(raw.mem_malloc(lib, 0) == null_handle())


def test_calloc_zero_fills() raises:
    var lib = _lib()
    var p = raw.mem_calloc(lib, 256)
    assert_true(p != null_handle())
    var all_zero = True
    for i in range(256):
        if _byte(p, i) != 0:
            all_zero = False
    assert_true(all_zero)
    raw.mem_free(lib, p)


def test_calloc_refuses_a_zero_size() raises:
    var lib = _lib()
    assert_true(raw.mem_calloc(lib, 0) == null_handle())


def test_realloc_grows_and_keeps_the_contents() raises:
    var lib = _lib()
    var p = raw.mem_malloc(lib, 16)
    for i in range(16):
        _set(p, i, UInt8(100 + i))
    var grown = raw.mem_realloc(lib, p, 4096)
    assert_true(grown != null_handle())
    for i in range(16):
        assert_equal(_byte(grown, i), UInt8(100 + i))
    _set(grown, 4095, 7)  # the new tail is usable
    assert_equal(_byte(grown, 4095), UInt8(7))
    raw.mem_free(lib, grown)


def test_realloc_shrinks_and_keeps_the_prefix() raises:
    var lib = _lib()
    var p = raw.mem_malloc(lib, 128)
    for i in range(128):
        _set(p, i, UInt8(i))
    var small = raw.mem_realloc(lib, p, 8)
    assert_true(small != null_handle())
    for i in range(8):
        assert_equal(_byte(small, i), UInt8(i))
    raw.mem_free(lib, small)


def test_realloc_of_null_allocates() raises:
    var lib = _lib()
    var p = raw.mem_realloc(lib, null_handle(), 32)
    assert_true(p != null_handle())
    _set(p, 31, 1)
    raw.mem_free(lib, p)


def test_realloc_with_zero_size_returns_null_and_leaves_the_block_alone() raises:
    var lib = _lib()
    var p = raw.mem_malloc(lib, 8)
    _set(p, 0, 42)
    assert_true(raw.mem_realloc(lib, p, 0) == null_handle())
    assert_equal(_byte(p, 0), UInt8(42))  # still ours to use and free
    raw.mem_free(lib, p)


def test_free_accepts_null() raises:
    var lib = _lib()
    raw.mem_free(lib, null_handle())


def test_aligned_malloc_honours_the_alignment() raises:
    var lib = _lib()
    var alignments: List[UInt64] = [1, 2, 4, 8, 16, 32, 64, 256, 4096]
    for a in alignments:
        var p = raw.mem_aligned_malloc(lib, 100, a)
        assert_true(p != null_handle())
        assert_equal(UInt64(Int(p)) % a, UInt64(0))
        for i in range(100):  # the whole requested size is usable
            _set(p, i, UInt8(i))
        assert_equal(_byte(p, 99), UInt8(99))
        raw.mem_aligned_free(lib, p)


def test_aligned_malloc_rejects_bad_requests() raises:
    var lib = _lib()
    assert_true(raw.mem_aligned_malloc(lib, 0, 16) == null_handle())  # zero size
    assert_true(raw.mem_aligned_malloc(lib, 64, 0) == null_handle())  # zero alignment
    assert_true(raw.mem_aligned_malloc(lib, 64, 3) == null_handle())  # not a power of two
    assert_true(raw.mem_aligned_malloc(lib, 64, 48) == null_handle())
    # A size that would wrap around once padded must not return a short block.
    assert_true(raw.mem_aligned_malloc(lib, UInt64.MAX, 16) == null_handle())
    assert_true(raw.mem_aligned_malloc(lib, UInt64.MAX - 7, 1) == null_handle())


def test_aligned_free_accepts_null() raises:
    var lib = _lib()
    raw.mem_aligned_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
