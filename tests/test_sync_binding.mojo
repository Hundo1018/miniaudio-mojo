"""TDD contract tests for the sync BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: these are plain in-memory primitives.
All 24 MA_API sync functions are exercised here (positive and negative paths).

Every waiting call is bound and every waiting call is exercised — always after
a signal, a release, or on a fence already back at zero, so nothing blocks.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.sync_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def test_a_mutex_locks_and_unlocks() raises:
    """The lock round-trips, and the handle rejects use before init."""
    var lib = _lib()
    var m = raw.mutex_alloc(lib)
    assert_true(m != null_handle())

    assert_equal(raw.mutex_lock(lib, m), MA_INVALID_ARGS)
    assert_equal(raw.mutex_init(lib, m), MA_SUCCESS)
    assert_equal(raw.mutex_lock(lib, m), MA_SUCCESS)
    assert_equal(raw.mutex_unlock(lib, m), MA_SUCCESS)
    assert_equal(raw.mutex_uninit(lib, m), MA_SUCCESS)
    assert_equal(raw.mutex_lock(lib, m), MA_INVALID_ARGS)

    raw.mutex_free(lib, m)
    assert_equal(raw.mutex_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.mutex_free(lib, null_handle())


def test_an_event_can_be_signalled_then_waited_on() raises:
    """Signalling first means the wait returns instead of blocking."""
    var lib = _lib()
    var e = raw.event_alloc(lib)

    assert_equal(raw.event_signal(lib, e), MA_INVALID_ARGS)
    assert_equal(raw.event_init(lib, e), MA_SUCCESS)
    assert_equal(raw.event_signal(lib, e), MA_SUCCESS)
    assert_equal(raw.event_wait(lib, e), MA_SUCCESS)
    assert_equal(raw.event_uninit(lib, e), MA_SUCCESS)
    assert_equal(raw.event_wait(lib, e), MA_INVALID_ARGS)

    raw.event_free(lib, e)
    assert_equal(raw.event_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.event_free(lib, null_handle())


def test_a_semaphore_counts_releases() raises:
    """A semaphore starting at one lets a wait straight through."""
    var lib = _lib()
    var s = raw.semaphore_alloc(lib)

    assert_equal(raw.semaphore_release(lib, s), MA_INVALID_ARGS)
    assert_equal(raw.semaphore_init(lib, s, 1), MA_SUCCESS)
    assert_equal(raw.semaphore_wait(lib, s), MA_SUCCESS)

    # Back to zero: put one back before waiting again.
    assert_equal(raw.semaphore_release(lib, s), MA_SUCCESS)
    assert_equal(raw.semaphore_wait(lib, s), MA_SUCCESS)

    assert_equal(raw.semaphore_uninit(lib, s), MA_SUCCESS)
    raw.semaphore_free(lib, s)
    assert_equal(raw.semaphore_init(lib, null_handle(), 0), MA_INVALID_ARGS)
    raw.semaphore_free(lib, null_handle())


def test_a_fence_waits_for_its_counter_to_reach_zero() raises:
    """A fresh fence is already at zero; acquire/release brings it back."""
    var lib = _lib()
    var f = raw.fence_alloc(lib)

    assert_equal(raw.fence_acquire(lib, f), MA_INVALID_ARGS)
    assert_equal(raw.fence_init(lib, f), MA_SUCCESS)
    assert_equal(raw.fence_wait(lib, f), MA_SUCCESS)

    assert_equal(raw.fence_acquire(lib, f), MA_SUCCESS)
    assert_equal(raw.fence_release(lib, f), MA_SUCCESS)
    assert_equal(raw.fence_wait(lib, f), MA_SUCCESS)

    assert_equal(raw.fence_uninit(lib, f), MA_SUCCESS)
    raw.fence_free(lib, f)
    assert_equal(raw.fence_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.fence_free(lib, null_handle())


def test_a_poll_notification_flips_when_signalled() raises:
    """The polled notification reads false until the generic signal reaches it.

    Pins an upstream bug in miniaudio 0.11.25: ma_async_notification_signal
    calls the notification's onSignal callback and then returns
    MA_INVALID_ARGS — the success path returns an error code:

        pNotificationCallbacks->onSignal(pNotification);
        return MA_INVALID_ARGS;

    The signal itself lands, which is what the is_signalled check below proves.
    Only the returned code is wrong, so the raw layer reports it as-is and the
    API layer ignores that particular code (see `AsyncPoll.signal`). If a future
    miniaudio fixes this, the assertion on MA_INVALID_ARGS fails and both the
    workaround and this note should go.
    """
    var lib = _lib()
    var p = raw.async_poll_alloc(lib)

    assert_equal(raw.async_poll_is_signalled(lib, p).result, MA_INVALID_ARGS)
    assert_equal(raw.async_poll_init(lib, p), MA_SUCCESS)

    var before = raw.async_poll_is_signalled(lib, p)
    assert_equal(before.result, MA_SUCCESS)
    assert_true(not before.value)

    assert_equal(raw.async_poll_signal(lib, p), MA_INVALID_ARGS)
    assert_true(raw.async_poll_is_signalled(lib, p).value)

    raw.async_poll_free(lib, p)
    assert_equal(raw.async_poll_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.async_poll_free(lib, null_handle())


def test_an_event_notification_can_be_signalled_then_waited_on() raises:
    """The event-shaped notification behaves like the plain event."""
    var lib = _lib()
    var e = raw.async_event_alloc(lib)

    assert_equal(raw.async_event_signal(lib, e), MA_INVALID_ARGS)
    assert_equal(raw.async_event_init(lib, e), MA_SUCCESS)
    assert_equal(raw.async_event_signal(lib, e), MA_SUCCESS)
    assert_equal(raw.async_event_wait(lib, e), MA_SUCCESS)
    assert_equal(raw.async_event_uninit(lib, e), MA_SUCCESS)
    assert_equal(raw.async_event_wait(lib, e), MA_INVALID_ARGS)

    raw.async_event_free(lib, e)
    assert_equal(raw.async_event_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.async_event_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
