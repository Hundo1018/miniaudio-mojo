"""TDD tests for the idiomatic slot allocator API (RAII SlotAllocator).

L3 behavioral: verifies slots are handed out distinctly and can be returned,
that both init paths work, and that a released allocator refuses further use.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.sync import SlotAllocator


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_slots_are_distinct_and_returnable() raises:
    """Two claims give two different slots, and both go back."""
    var a = SlotAllocator.create(_lib())
    var first = a.claim()
    var second = a.claim()
    assert_true(first != second)

    a.release(first)
    a.release(second)


def test_both_init_paths_build_a_working_allocator() raises:
    """Where the allocator's heap lives makes no difference."""
    _ = SlotAllocator.heap_size(_lib())
    var a = SlotAllocator.create(_lib(), preallocated=True)
    var slot = a.claim()
    a.release(slot)


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit claiming raises."""
    var a = SlotAllocator.create(_lib())
    a.uninit()
    with assert_raises():
        _ = a.claim()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
