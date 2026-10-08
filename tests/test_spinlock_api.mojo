"""TDD tests for the idiomatic Spinlock API (RAII, L3 behavioural, single-threaded)."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.util import Spinlock


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_lock_state_follows_lock_and_unlock() raises:
    var s = Spinlock.create(_lib())
    assert_false(s.is_locked())
    s.lock()
    assert_true(s.is_locked())
    s.unlock()
    assert_false(s.is_locked())
    s.lock_noyield()
    assert_true(s.is_locked())
    s.unlock()
    assert_false(s.is_locked())


def test_repeated_critical_sections_leave_the_lock_free() raises:
    """Lock / work / unlock repeated many times ends with the lock free."""
    var s = Spinlock.create(_lib())
    var counter = 0
    for _ in range(1000):
        s.lock()
        counter += 1
        assert_true(s.is_locked())
        s.unlock()
    assert_equal(counter, 1000)
    assert_false(s.is_locked())


def test_unlock_of_a_free_lock_does_nothing() raises:
    var s = Spinlock.create(_lib())
    s.unlock()
    assert_false(s.is_locked())
    s.lock()
    assert_true(s.is_locked())
    s.unlock()


def test_separate_locks_do_not_affect_each_other() raises:
    var lib = _lib()
    var a = Spinlock.create(lib)
    var b = Spinlock.create(lib)
    a.lock()
    assert_false(b.is_locked())
    b.lock()
    assert_true(a.is_locked())
    assert_true(b.is_locked())
    a.unlock()
    assert_false(a.is_locked())
    assert_true(b.is_locked())
    b.unlock()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
