"""TDD contract tests for the panner BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 7 MA_API panner functions are
exercised (positive and negative). ma_panner has no uninit upstream; the shim's
uninit only clears its own initialised flag.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.effect_raw as raw


comptime FMT_F32: Int = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _ones(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(1))
    return buf^


def test_init_defaults_and_round_trip() raises:
    var lib = _lib()
    var h = raw.panner_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, raw.PAN_MODE_BALANCE, 0.0), MA_SUCCESS)
    var m = raw.panner_get_mode(lib, h)
    assert_equal(m.result, MA_SUCCESS)
    assert_equal(Int(m.value), raw.PAN_MODE_BALANCE)
    assert_equal(raw.panner_set_mode(lib, h, raw.PAN_MODE_PAN), MA_SUCCESS)
    assert_equal(Int(raw.panner_get_mode(lib, h).value), raw.PAN_MODE_PAN)
    assert_equal(raw.panner_set_pan(lib, h, -0.5), MA_SUCCESS)
    var p = raw.panner_get_pan(lib, h)
    assert_equal(p.result, MA_SUCCESS)
    assert_equal(p.value, Float32(-0.5))
    raw.panner_free(lib, h)


def test_pan_is_clamped() raises:
    var lib = _lib()
    var h = raw.panner_alloc(lib)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, raw.PAN_MODE_BALANCE, 0.0), MA_SUCCESS)
    assert_equal(raw.panner_set_pan(lib, h, 3.0), MA_SUCCESS)
    assert_equal(raw.panner_get_pan(lib, h).value, Float32(1.0))
    raw.panner_free(lib, h)


def test_balance_right_attenuates_left() raises:
    var lib = _lib()
    var h = raw.panner_alloc(lib)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, raw.PAN_MODE_BALANCE, 0.5), MA_SUCCESS)
    var src = _ones(8)
    var dst = List[Float32]()
    dst.resize(8, Float32(0))
    assert_equal(raw.panner_process(lib, h, dst, src, 4), MA_SUCCESS)
    assert_equal(dst[0], Float32(0.5))
    assert_equal(dst[1], Float32(1.0))
    raw.panner_free(lib, h)


def test_true_pan_moves_left_into_right() raises:
    var lib = _lib()
    var h = raw.panner_alloc(lib)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, raw.PAN_MODE_PAN, 1.0), MA_SUCCESS)
    var src = _ones(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))
    assert_equal(raw.panner_process(lib, h, dst, src, 2), MA_SUCCESS)
    assert_equal(dst[0], Float32(0.0))
    assert_equal(dst[1], Float32(2.0))
    raw.panner_free(lib, h)


def test_invalid_mode_rejected() raises:
    var lib = _lib()
    var h = raw.panner_alloc(lib)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, 7, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, raw.PAN_MODE_BALANCE, 0.0), MA_SUCCESS)
    assert_equal(raw.panner_set_mode(lib, h, -1), MA_INVALID_ARGS)
    raw.panner_free(lib, h)


def test_null_and_uninit_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var src = _ones(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))
    assert_equal(raw.panner_init(lib, n, FMT_F32, 2, 0, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.panner_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.panner_process(lib, n, dst, src, 2), MA_INVALID_ARGS)
    assert_equal(raw.panner_set_mode(lib, n, 0), MA_INVALID_ARGS)
    assert_equal(raw.panner_get_mode(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.panner_set_pan(lib, n, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.panner_get_pan(lib, n).result, MA_INVALID_ARGS)
    raw.panner_free(lib, n)

    var h = raw.panner_alloc(lib)
    assert_equal(raw.panner_init(lib, h, FMT_F32, 2, 0, 0.0), MA_SUCCESS)
    assert_equal(raw.panner_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.panner_set_pan(lib, h, 0.0), MA_INVALID_ARGS)
    raw.panner_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
