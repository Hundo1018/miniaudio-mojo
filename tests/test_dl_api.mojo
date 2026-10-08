"""TDD tests for the idiomatic DynamicLibrary API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, assert_almost_equal, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio._lib import null_handle
from miniaudio.util import DynamicLibrary


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_loaded_library_resolves_and_calls_math_functions() raises:
    var libm = DynamicLibrary.load(_lib(), "libm.so.6")
    assert_equal(libm.call_f64("cos", 0.0), 1.0)
    assert_almost_equal(libm.call_f64("sin", 1.5707963267948966), 1.0, atol=1e-12)
    assert_equal(libm.call_f64("sqrt", 144.0), 12.0)
    assert_equal(libm.call_f64("ceil", 2.25), 3.0)
    assert_almost_equal(libm.call_f64("exp", 0.0), 1.0, atol=1e-12)


def test_has_symbol_distinguishes_present_from_missing() raises:
    var libm = DynamicLibrary.load(_lib(), "libm.so.6")
    assert_true(libm.has_symbol("cos"))
    assert_false(libm.has_symbol("no_such_symbol_xyz"))
    assert_true(libm.symbol("cos") != null_handle())


def test_missing_symbol_raises() raises:
    var libm = DynamicLibrary.load(_lib(), "libm.so.6")
    with assert_raises():
        _ = libm.symbol("no_such_symbol_xyz")
    with assert_raises():
        _ = libm.call_f64("no_such_symbol_xyz", 1.0)


def test_missing_library_raises() raises:
    with assert_raises():
        _ = DynamicLibrary.load(_lib(), "libminiaudio_mojo_missing.so.99")


def test_two_handles_to_one_library_are_independent() raises:
    var lib = _lib()
    var first = DynamicLibrary.load(lib, "libm.so.6")
    var second = DynamicLibrary.load(lib, "libm.so.6")
    assert_equal(first.call_f64("sqrt", 16.0), 4.0)
    _ = first^  # close the first
    assert_equal(second.call_f64("sqrt", 25.0), 5.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
