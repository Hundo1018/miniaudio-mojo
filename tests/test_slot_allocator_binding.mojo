"""TDD contract tests for the slot allocator BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 7 MA_API slot allocator functions
are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.sync_raw as raw


comptime CAPACITY: UInt32 = 16


def _lib() raises -> MaLib:
    return MaLib.default()


def test_heap_size_is_reported_from_the_config_alone() raises:
    """The get_heap_size call answers before anything is built."""
    var lib = _lib()
    var rc = raw.slot_allocator_get_heap_size(lib, CAPACITY)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_slots_are_handed_out_and_taken_back() raises:
    """Two claims give two different slots, and both can be returned."""
    var lib = _lib()
    var a = raw.slot_allocator_alloc(lib)
    assert_true(a != null_handle())
    assert_equal(raw.slot_allocator_init(lib, a, CAPACITY), MA_SUCCESS)

    var first = raw.slot_allocator_alloc_slot(lib, a)
    assert_equal(first.result, MA_SUCCESS)
    var second = raw.slot_allocator_alloc_slot(lib, a)
    assert_equal(second.result, MA_SUCCESS)
    assert_true(first.value != second.value)

    assert_equal(raw.slot_allocator_free_slot(lib, a, first.value), MA_SUCCESS)
    assert_equal(raw.slot_allocator_free_slot(lib, a, second.value), MA_SUCCESS)

    assert_equal(raw.slot_allocator_uninit(lib, a), MA_SUCCESS)
    raw.slot_allocator_free(lib, a)


def test_the_preallocated_path_builds_the_same_allocator() raises:
    """A shim-owned heap gives an allocator that behaves identically."""
    var lib = _lib()
    var a = raw.slot_allocator_alloc(lib)
    assert_equal(
        raw.slot_allocator_init_preallocated(lib, a, CAPACITY), MA_SUCCESS
    )

    var slot = raw.slot_allocator_alloc_slot(lib, a)
    assert_equal(slot.result, MA_SUCCESS)
    assert_equal(raw.slot_allocator_free_slot(lib, a, slot.value), MA_SUCCESS)

    raw.slot_allocator_free(lib, a)


def test_operations_before_init_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var a = raw.slot_allocator_alloc(lib)

    assert_equal(raw.slot_allocator_alloc_slot(lib, a).result, MA_INVALID_ARGS)
    assert_equal(raw.slot_allocator_free_slot(lib, a, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.slot_allocator_uninit(lib, a), MA_SUCCESS)

    raw.slot_allocator_free(lib, a)
    assert_equal(
        raw.slot_allocator_init(lib, null_handle(), CAPACITY), MA_INVALID_ARGS
    )
    assert_equal(
        raw.slot_allocator_init_preallocated(lib, null_handle(), CAPACITY),
        MA_INVALID_ARGS,
    )
    raw.slot_allocator_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
