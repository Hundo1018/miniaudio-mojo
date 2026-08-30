"""TDD contract tests for the context BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the context runs on the null backend,
so enumeration returns miniaudio's synthetic devices. All 9 MA_API context
functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.context_raw as raw


comptime DEVICE_TYPE_PLAYBACK: Int = 1


def _lib() raises -> MaLib:
    return MaLib.default()


def _context(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var c = raw.context_alloc(lib)
    assert_true(c != null_handle())
    assert_equal(raw.context_init(lib, c), MA_SUCCESS)
    return c


def test_a_context_reports_its_own_size() raises:
    """The sizeof call answers without a context existing at all."""
    var lib = _lib()
    var rc = raw.context_sizeof(lib)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_a_context_has_a_log_and_a_loopback_answer() raises:
    """Both flag-shaped accessors answer on a live context."""
    var lib = _lib()
    var c = _context(lib)

    var log = raw.context_has_log(lib, c)
    assert_equal(log.result, MA_SUCCESS)
    assert_true(log.value)

    assert_equal(raw.context_is_loopback_supported(lib, c).result, MA_SUCCESS)

    raw.context_free(lib, c)


def test_enumeration_and_the_device_lists_agree() raises:
    """The callback sees as many devices as the arrays hold."""
    var lib = _lib()
    var c = _context(lib)

    var enumerated = raw.context_enumerate_devices(lib, c)
    assert_equal(enumerated.result, MA_SUCCESS)
    assert_true(enumerated.value > UInt32(0))

    var counts = raw.context_get_devices(lib, c)
    assert_equal(counts.result, MA_SUCCESS)
    assert_equal(counts.playback + counts.capture, enumerated.value)

    raw.context_free(lib, c)


def test_the_default_playback_device_can_be_described() raises:
    """The default device has a name and at least one native format."""
    var lib = _lib()
    var c = _context(lib)

    var info = raw.context_get_device_info(lib, c, DEVICE_TYPE_PLAYBACK)
    assert_equal(info.result, MA_SUCCESS)
    assert_true(info.name_length > UInt32(0))

    raw.context_free(lib, c)


def test_operations_before_init_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var c = raw.context_alloc(lib)

    assert_equal(raw.context_has_log(lib, c).result, MA_INVALID_ARGS)
    assert_equal(raw.context_is_loopback_supported(lib, c).result, MA_INVALID_ARGS)
    assert_equal(raw.context_enumerate_devices(lib, c).result, MA_INVALID_ARGS)
    assert_equal(raw.context_get_devices(lib, c).result, MA_INVALID_ARGS)
    assert_equal(
        raw.context_get_device_info(lib, c, DEVICE_TYPE_PLAYBACK).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.context_uninit(lib, c), MA_SUCCESS)

    raw.context_free(lib, c)
    assert_equal(raw.context_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.context_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
