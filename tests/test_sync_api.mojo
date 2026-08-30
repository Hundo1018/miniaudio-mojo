"""TDD tests for the idiomatic sync API (RAII Mutex / Event / Semaphore / Fence).

L3 behavioral: verifies each primitive does what it is for, always signalling
before waiting so nothing blocks, and that a released handle rejects further use.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.sync import Mutex, Event, Semaphore, Fence, AsyncPoll, AsyncEvent


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_a_mutex_round_trips_its_lock() raises:
    """Lock then unlock, and a released mutex refuses to lock."""
    var m = Mutex.create(_lib())
    m.lock()
    m.unlock()
    m.uninit()
    with assert_raises():
        m.lock()


def test_an_event_wait_returns_once_signalled() raises:
    """Signalling first means the wait comes straight back."""
    var e = Event.create(_lib())
    e.signal()
    e.wait()
    e.uninit()
    with assert_raises():
        e.wait()


def test_a_semaphore_lets_through_what_was_released() raises:
    """A semaphore starting at one admits one waiter, then needs a release."""
    var s = Semaphore.create(_lib(), initial_value=1)
    s.wait()
    s.release()
    s.wait()
    s.uninit()
    with assert_raises():
        s.release()


def test_a_fence_returns_when_its_counter_is_zero() raises:
    """A fresh fence is already clear; acquire and release bring it back."""
    var f = Fence.create(_lib())
    f.wait()
    f.acquire()
    f.release()
    f.wait()
    f.uninit()
    with assert_raises():
        f.acquire()


def test_a_poll_notification_reads_back_its_signal() raises:
    """The polled notification flips once signalled.

    `signal` tolerates the bogus MA_INVALID_ARGS miniaudio returns on its
    success path — see `AsyncPoll.signal` and the binding tests.
    """
    var p = AsyncPoll.create(_lib())
    assert_true(not p.is_signalled())
    p.signal()
    assert_true(p.is_signalled())


def test_an_event_notification_waits_like_an_event() raises:
    """The event-shaped notification behaves like the plain event."""
    var e = AsyncEvent.create(_lib())
    e.signal()
    e.wait()
    e.uninit()
    with assert_raises():
        e.signal()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
