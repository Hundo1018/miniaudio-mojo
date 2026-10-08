"""TDD contract tests for the runtime_info BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the version is a compile-time constant
of the vendored miniaudio.h (0.11.25), and backend availability is a
compile-time property of this linux-64 build. The 3 MA_API functions bound here
(ma_version, ma_is_backend_enabled, ma_is_loopback_supported) are exercised
positive and negative; ma_version_string was already bound with the core shim.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.util_raw as raw
import miniaudio._ffi.format_util_raw as fmt


def _lib() raises -> MaLib:
    return MaLib.default()


def test_version_is_the_vendored_miniaudio_release() raises:
    var lib = _lib()
    var v = raw.runtime_version(lib)
    assert_equal(v.result, MA_SUCCESS)
    assert_equal(v.major, UInt32(0))
    assert_equal(v.minor, UInt32(11))
    assert_equal(v.revision, UInt32(25))


def test_version_agrees_with_the_version_string() raises:
    var lib = _lib()
    var v = raw.runtime_version(lib)
    var joined = String(v.major) + "." + String(v.minor) + "." + String(v.revision)
    assert_equal(joined, lib.version())


def test_null_backend_is_always_enabled() raises:
    var lib = _lib()
    var rc = raw.runtime_is_backend_enabled(lib, raw.BACKEND_NULL)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value)
    assert_true(raw.runtime_is_backend_enabled(lib, raw.BACKEND_CUSTOM).value)


def test_backends_for_other_platforms_are_off_on_linux() raises:
    var lib = _lib()
    var absent: List[Int] = [
        raw.BACKEND_WASAPI,
        raw.BACKEND_DSOUND,
        raw.BACKEND_WINMM,
        raw.BACKEND_COREAUDIO,
        raw.BACKEND_AUDIO4,
        raw.BACKEND_OSS,
        raw.BACKEND_SNDIO,
        raw.BACKEND_AAUDIO,
        raw.BACKEND_OPENSL,
        raw.BACKEND_WEBAUDIO,
    ]
    for backend in absent:
        var rc = raw.runtime_is_backend_enabled(lib, backend)
        assert_equal(rc.result, MA_SUCCESS)
        assert_false(rc.value)


def test_linux_audio_backends_are_compiled_in() raises:
    var lib = _lib()
    assert_true(raw.runtime_is_backend_enabled(lib, raw.BACKEND_ALSA).value)
    assert_true(raw.runtime_is_backend_enabled(lib, raw.BACKEND_PULSEAUDIO).value)
    assert_true(raw.runtime_is_backend_enabled(lib, raw.BACKEND_JACK).value)


def test_enabled_matches_the_enabled_backend_list() raises:
    """Cross-check against ma_get_enabled_backends (bound with the format utilities)."""
    var lib = _lib()
    var listed = fmt.get_enabled_backends(lib)
    assert_equal(listed.result, MA_SUCCESS)
    for backend in range(raw.BACKEND_NULL + 1):
        var in_list = False
        for b in listed.value:
            if Int(b) == backend:
                in_list = True
        assert_equal(raw.runtime_is_backend_enabled(lib, backend).value, in_list)


def test_backend_outside_the_enum_is_invalid() raises:
    var lib = _lib()
    for bad in [-1, 15, 100, 1 << 20]:
        var rc = raw.runtime_is_backend_enabled(lib, bad)
        assert_equal(rc.result, MA_INVALID_ARGS)
        assert_false(rc.value)


def test_only_wasapi_supports_loopback() raises:
    var lib = _lib()
    var rc = raw.runtime_is_loopback_supported(lib, raw.BACKEND_WASAPI)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value)  # a property of the backend, even though it is not built here
    for backend in range(raw.BACKEND_WASAPI + 1, raw.BACKEND_NULL + 1):
        var other = raw.runtime_is_loopback_supported(lib, backend)
        assert_equal(other.result, MA_SUCCESS)
        assert_false(other.value)


def test_loopback_for_a_backend_outside_the_enum_is_invalid() raises:
    var lib = _lib()
    for bad in [-1, 15, 255]:
        var rc = raw.runtime_is_loopback_supported(lib, bad)
        assert_equal(rc.result, MA_INVALID_ARGS)
        assert_false(rc.value)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
