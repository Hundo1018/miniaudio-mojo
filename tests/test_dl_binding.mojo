"""TDD contract tests for the dl BINDING layer (raw 1:1 over the shim).

Deterministic on Linux/glibc: libm.so.6 is the shared library opened, cos / sin /
sqrt / floor the symbols resolved. All 3 MA_API dl functions are exercised
(positive and negative). Resolved symbols are proved real by calling them
through the shim's `double f(double)` helper.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.util_raw as raw

comptime LIBM = "libm.so.6"


def _lib() raises -> MaLib:
    return MaLib.default()


def test_open_loads_a_shared_library() raises:
    var lib = _lib()
    var h = raw.dl_open(lib, raw.c_bytes(LIBM))
    assert_true(h != null_handle())
    assert_equal(raw.dl_close(lib, h), MA_SUCCESS)


def test_sym_resolves_exported_functions_that_really_run() raises:
    var lib = _lib()
    var h = raw.dl_open(lib, raw.c_bytes(LIBM))
    var cos = raw.dl_sym(lib, h, raw.c_bytes("cos"))
    var sqrt = raw.dl_sym(lib, h, raw.c_bytes("sqrt"))
    var floor = raw.dl_sym(lib, h, raw.c_bytes("floor"))
    assert_true(cos != null_handle())
    assert_true(sqrt != null_handle())
    assert_true(floor != null_handle())
    assert_true(cos != sqrt)

    var one = raw.dl_call_f64(lib, cos, 0.0)
    assert_equal(one.result, MA_SUCCESS)
    assert_equal(one.value, 1.0)
    assert_almost_equal(raw.dl_call_f64(lib, cos, 3.141592653589793).value, -1.0, atol=1e-12)
    assert_equal(raw.dl_call_f64(lib, sqrt, 9.0).value, 3.0)
    assert_equal(raw.dl_call_f64(lib, floor, 2.75).value, 2.0)
    assert_equal(raw.dl_close(lib, h), MA_SUCCESS)


def test_sym_for_a_missing_symbol_is_null() raises:
    var lib = _lib()
    var h = raw.dl_open(lib, raw.c_bytes(LIBM))
    assert_true(raw.dl_sym(lib, h, raw.c_bytes("definitely_not_a_libm_symbol")) == null_handle())
    assert_equal(raw.dl_close(lib, h), MA_SUCCESS)


def test_open_for_a_missing_library_is_null() raises:
    var lib = _lib()
    assert_true(raw.dl_open(lib, raw.c_bytes("libminiaudio_mojo_missing.so.99")) == null_handle())
    assert_true(raw.dl_open(lib, raw.c_bytes("/no/such/dir/libm.so.6")) == null_handle())


def test_null_arguments_are_refused() raises:
    var lib = _lib()
    var h = raw.dl_open(lib, raw.c_bytes(LIBM))
    assert_true(raw.dl_open(lib, List[UInt8]()) == null_handle())  # NULL filename
    assert_true(raw.dl_sym(lib, null_handle(), raw.c_bytes("cos")) == null_handle())  # NULL library
    assert_true(raw.dl_sym(lib, h, List[UInt8]()) == null_handle())  # NULL symbol
    assert_equal(raw.dl_close(lib, null_handle()), MA_INVALID_ARGS)
    var bad = raw.dl_call_f64(lib, null_handle(), 1.0)
    assert_equal(bad.result, MA_INVALID_ARGS)
    assert_equal(bad.value, 0.0)
    assert_equal(raw.dl_close(lib, h), MA_SUCCESS)


def test_a_library_can_be_opened_twice_and_closed_twice() raises:
    var lib = _lib()
    var a = raw.dl_open(lib, raw.c_bytes(LIBM))
    var b = raw.dl_open(lib, raw.c_bytes(LIBM))
    assert_true(a != null_handle())
    assert_true(b != null_handle())
    assert_equal(raw.dl_close(lib, a), MA_SUCCESS)
    # The second handle is still good after the first is closed.
    assert_true(raw.dl_sym(lib, b, raw.c_bytes("cos")) != null_handle())
    assert_equal(raw.dl_close(lib, b), MA_SUCCESS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
