"""TDD contract tests for the spinlock BINDING layer (raw 1:1 over the shim).

Single-threaded and deterministic: the lock is a heap word, observable through
`spinlock_is_locked`. All 3 MA_API spinlock functions are exercised (positive
and negative). Locking an already-held lock from the same thread would spin
forever, so no test does that.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.util_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def test_a_new_lock_is_free() raises:
    var lib = _lib()
    var h = raw.spinlock_alloc(lib)
    assert_true(h != null_handle())
    var state = raw.spinlock_is_locked(lib, h)
    assert_equal(state.result, MA_SUCCESS)
    assert_false(state.value)
    raw.spinlock_free(lib, h)


def test_lock_takes_the_lock_and_unlock_releases_it() raises:
    var lib = _lib()
    var h = raw.spinlock_alloc(lib)
    assert_equal(raw.spinlock_lock(lib, h), MA_SUCCESS)
    assert_true(raw.spinlock_is_locked(lib, h).value)
    assert_equal(raw.spinlock_unlock(lib, h), MA_SUCCESS)
    assert_false(raw.spinlock_is_locked(lib, h).value)
    raw.spinlock_free(lib, h)


def test_lock_noyield_takes_the_lock_too() raises:
    var lib = _lib()
    var h = raw.spinlock_alloc(lib)
    assert_equal(raw.spinlock_lock_noyield(lib, h), MA_SUCCESS)
    assert_true(raw.spinlock_is_locked(lib, h).value)
    assert_equal(raw.spinlock_unlock(lib, h), MA_SUCCESS)
    assert_false(raw.spinlock_is_locked(lib, h).value)
    raw.spinlock_free(lib, h)


def test_unlocking_a_free_lock_is_harmless() raises:
    var lib = _lib()
    var h = raw.spinlock_alloc(lib)
    assert_equal(raw.spinlock_unlock(lib, h), MA_SUCCESS)
    assert_false(raw.spinlock_is_locked(lib, h).value)
    assert_equal(raw.spinlock_lock(lib, h), MA_SUCCESS)  # and it can still be taken
    assert_equal(raw.spinlock_unlock(lib, h), MA_SUCCESS)
    raw.spinlock_free(lib, h)


def test_many_lock_unlock_cycles_leave_the_lock_free() raises:
    var lib = _lib()
    var h = raw.spinlock_alloc(lib)
    for i in range(1000):
        var code = raw.spinlock_lock(lib, h) if i % 2 == 0 else raw.spinlock_lock_noyield(lib, h)
        assert_equal(code, MA_SUCCESS)
        assert_equal(raw.spinlock_unlock(lib, h), MA_SUCCESS)
    assert_false(raw.spinlock_is_locked(lib, h).value)
    raw.spinlock_free(lib, h)


def test_locks_are_independent() raises:
    var lib = _lib()
    var a = raw.spinlock_alloc(lib)
    var b = raw.spinlock_alloc(lib)
    assert_equal(raw.spinlock_lock(lib, a), MA_SUCCESS)
    assert_true(raw.spinlock_is_locked(lib, a).value)
    assert_false(raw.spinlock_is_locked(lib, b).value)
    assert_equal(raw.spinlock_lock(lib, b), MA_SUCCESS)  # does not wait on a
    assert_equal(raw.spinlock_unlock(lib, a), MA_SUCCESS)
    assert_true(raw.spinlock_is_locked(lib, b).value)
    assert_equal(raw.spinlock_unlock(lib, b), MA_SUCCESS)
    raw.spinlock_free(lib, a)
    raw.spinlock_free(lib, b)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    assert_equal(raw.spinlock_lock(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.spinlock_lock_noyield(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.spinlock_unlock(lib, n), MA_INVALID_ARGS)
    var state = raw.spinlock_is_locked(lib, n)
    assert_equal(state.result, MA_INVALID_ARGS)
    assert_false(state.value)
    raw.spinlock_free(lib, n)  # freeing NULL is a no-op


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
