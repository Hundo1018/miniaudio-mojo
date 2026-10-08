"""TDD tests for the idiomatic runtime-info API (free functions, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
import miniaudio.util as u
from miniaudio.format_util import enabled_backends


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_version_reports_the_vendored_release() raises:
    var lib = _lib()
    var v = u.version(lib)
    assert_equal(v.major, UInt32(0))
    assert_equal(v.minor, UInt32(11))
    assert_equal(v.revision, UInt32(25))
    assert_equal(v.to_string(), "0.11.25")


def test_version_string_matches_the_library_banner() raises:
    var lib = _lib()
    assert_equal(u.version(lib).to_string(), lib[].version())


def test_backend_availability_on_this_build() raises:
    var lib = _lib()
    assert_true(u.is_backend_enabled(lib, u.BackendNull))
    assert_true(u.is_backend_enabled(lib, u.BackendCustom))
    assert_true(u.is_backend_enabled(lib, u.BackendAlsa))
    assert_true(u.is_backend_enabled(lib, u.BackendPulseaudio))
    assert_false(u.is_backend_enabled(lib, u.BackendWasapi))  # Windows only


def test_enabled_backends_agree_with_the_enabled_list() raises:
    var lib = _lib()
    var listed = enabled_backends(lib)
    for backend in range(u.BackendNull + 1):
        var in_list = False
        for b in listed:
            if Int(b) == backend:
                in_list = True
        assert_equal(u.is_backend_enabled(lib, backend), in_list)


def test_only_wasapi_can_capture_loopback() raises:
    var lib = _lib()
    assert_true(u.is_loopback_supported(lib, u.BackendWasapi))
    assert_false(u.is_loopback_supported(lib, u.BackendNull))
    assert_false(u.is_loopback_supported(lib, u.BackendAlsa))
    assert_false(u.is_loopback_supported(lib, u.BackendPulseaudio))
    assert_false(u.is_loopback_supported(lib, u.BackendJack))


def test_an_unknown_backend_code_raises() raises:
    var lib = _lib()
    var raised = False
    try:
        _ = u.is_backend_enabled(lib, 99)
    except:
        raised = True
    assert_true(raised)
    raised = False
    try:
        _ = u.is_loopback_supported(lib, -1)
    except:
        raised = True
    assert_true(raised)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
