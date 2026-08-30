"""TDD tests for the idiomatic context API (RAII Context).

L3 behavioral: verifies the context reports its own size, enumerates the null
backend's devices consistently with its device lists, and describes the default
device.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.context import Context
from miniaudio.device import DEVICE_TYPE_PLAYBACK


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_the_context_size_is_known_without_one() raises:
    """The size_in_bytes query answers before anything is built."""
    assert_true(Context.size_in_bytes(_lib()) > UInt64(0))


def test_a_context_reports_its_log_and_loopback_support() raises:
    """Both flag-shaped accessors answer on a live context."""
    var c = Context.create(_lib())
    assert_true(c.has_log())
    _ = c.is_loopback_supported()


def test_enumeration_matches_the_device_lists() raises:
    """The callback sees exactly as many devices as the arrays hold."""
    var c = Context.create(_lib())
    var enumerated = c.enumerate_devices()
    var counts = c.device_counts()

    assert_true(enumerated > UInt32(0))
    assert_equal(counts.playback + counts.capture, enumerated)


def test_the_default_playback_device_has_a_name() raises:
    """The default device summarises to a non-empty name."""
    var c = Context.create(_lib())
    var info = c.default_device(DEVICE_TYPE_PLAYBACK)
    assert_true(info.name_length > UInt32(0))


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var c = Context.create(_lib())
    c.uninit()
    with assert_raises():
        _ = c.has_log()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
