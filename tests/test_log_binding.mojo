"""TDD contract tests for the log BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 9 MA_API log functions are
exercised here (positive and negative paths).

A log callback has to be a C function, so the shim owns one that counts the
messages it is handed; the count is how Mojo observes that registering,
posting and unregistering all took effect.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.sync_raw as raw


comptime LEVEL_INFO: UInt32 = 3


def _lib() raises -> MaLib:
    return MaLib.default()


def test_a_registered_callback_sees_every_posted_message() raises:
    """All three posting shapes reach the callback and bump its count."""
    var lib = _lib()
    var lg = raw.log_alloc(lib)
    assert_true(lg != null_handle())
    assert_equal(raw.log_init(lib, lg), MA_SUCCESS)
    assert_equal(raw.log_register_callback(lib, lg), MA_SUCCESS)

    assert_equal(raw.log_post(lib, lg, LEVEL_INFO, "plain"), MA_SUCCESS)
    assert_equal(raw.log_message_count(lib, lg).value, UInt32(1))

    assert_equal(raw.log_postf(lib, lg, LEVEL_INFO, "formatted %s", "arg"), MA_SUCCESS)
    assert_equal(raw.log_message_count(lib, lg).value, UInt32(2))

    assert_equal(raw.log_postv(lib, lg, LEVEL_INFO, "va %s", "arg"), MA_SUCCESS)
    assert_equal(raw.log_message_count(lib, lg).value, UInt32(3))

    raw.log_free(lib, lg)


def test_unregistering_stops_the_callback() raises:
    """After unregistering, further posts leave the count alone."""
    var lib = _lib()
    var lg = raw.log_alloc(lib)
    assert_equal(raw.log_init(lib, lg), MA_SUCCESS)
    assert_equal(raw.log_register_callback(lib, lg), MA_SUCCESS)
    _ = raw.log_post(lib, lg, LEVEL_INFO, "seen")

    assert_equal(raw.log_unregister_callback(lib, lg), MA_SUCCESS)
    _ = raw.log_post(lib, lg, LEVEL_INFO, "unseen")
    assert_equal(raw.log_message_count(lib, lg).value, UInt32(1))

    # Unregistering twice is rejected: there is nothing registered.
    assert_equal(raw.log_unregister_callback(lib, lg), MA_INVALID_ARGS)

    raw.log_free(lib, lg)


def test_posting_works_without_a_callback() raises:
    """A log with nobody listening still accepts messages."""
    var lib = _lib()
    var lg = raw.log_alloc(lib)
    assert_equal(raw.log_init(lib, lg), MA_SUCCESS)
    assert_equal(raw.log_post(lib, lg, LEVEL_INFO, "nobody home"), MA_SUCCESS)
    assert_equal(raw.log_message_count(lib, lg).value, UInt32(0))
    raw.log_free(lib, lg)


def test_log_levels_have_names() raises:
    """Every level has a name; the shim copies the string out."""
    var lib = _lib()
    for level in range(1, 5):
        var rc = raw.log_level_to_string(lib, UInt32(level))
        assert_equal(rc.result, MA_SUCCESS)
        assert_true(rc.value.byte_length() > 0)


def test_operations_before_init_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var lg = raw.log_alloc(lib)

    assert_equal(raw.log_post(lib, lg, LEVEL_INFO, "x"), MA_INVALID_ARGS)
    assert_equal(raw.log_postf(lib, lg, LEVEL_INFO, "%s", "x"), MA_INVALID_ARGS)
    assert_equal(raw.log_postv(lib, lg, LEVEL_INFO, "%s", "x"), MA_INVALID_ARGS)
    assert_equal(raw.log_register_callback(lib, lg), MA_INVALID_ARGS)
    assert_equal(raw.log_unregister_callback(lib, lg), MA_INVALID_ARGS)
    assert_equal(raw.log_message_count(lib, lg).result, MA_INVALID_ARGS)
    assert_equal(raw.log_uninit(lib, lg), MA_SUCCESS)

    raw.log_free(lib, lg)
    assert_equal(raw.log_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.log_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
