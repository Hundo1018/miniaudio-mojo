"""TDD tests for the idiomatic log API (RAII Log).

L3 behavioral: verifies that a registered callback sees every posting shape,
that unregistering stops it, and that each level has a name.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.sync import Log, LOG_LEVEL_INFO, LOG_LEVEL_WARNING


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_a_registered_callback_counts_every_posting_shape() raises:
    """All three posting shapes reach the callback."""
    var lg = Log.create(_lib())
    lg.register_callback()

    lg.post("plain")
    lg.postf("formatted %s", "arg")
    lg.postv("va %s", "arg", level=LOG_LEVEL_WARNING)

    assert_true(lg.message_count() == UInt32(3))


def test_unregistering_stops_the_callback() raises:
    """Posts after unregistering leave the count where it was."""
    var lg = Log.create(_lib())
    lg.register_callback()
    lg.post("seen")
    lg.unregister_callback()
    lg.post("unseen")

    assert_true(lg.message_count() == UInt32(1))
    with assert_raises():
        lg.unregister_callback()


def test_posting_without_a_callback_is_fine() raises:
    """A log nobody is listening to still accepts messages."""
    var lg = Log.create(_lib())
    lg.post("nobody home", level=LOG_LEVEL_INFO)
    assert_true(lg.message_count() == UInt32(0))


def test_each_level_has_a_name() raises:
    """Every level has a name, which the API hands back."""
    var lib = _lib()
    assert_true(Log.level_name(lib, LOG_LEVEL_INFO).byte_length() > 0)
    assert_true(Log.level_name(lib, LOG_LEVEL_WARNING).byte_length() > 0)


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit posting raises."""
    var lg = Log.create(_lib())
    lg.uninit()
    with assert_raises():
        lg.post("x")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
