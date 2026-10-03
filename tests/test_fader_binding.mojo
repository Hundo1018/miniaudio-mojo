"""TDD contract tests for the fader BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 7 MA_API fader functions are
exercised (positive and negative). ma_fader has no uninit upstream; the shim's
uninit only clears its own initialised flag.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.effect_raw as raw


comptime FMT_S16: Int = 2
comptime FMT_F32: Int = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _ones(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(1))
    return buf^


def _zeros(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(0))
    return buf^


def test_init_and_data_format() raises:
    var lib = _lib()
    var h = raw.fader_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.fader_init(lib, h, FMT_F32, 2, 48000), MA_SUCCESS)
    var df = raw.fader_get_data_format(lib, h)
    assert_equal(df.result, MA_SUCCESS)
    assert_equal(df.format, FMT_F32)
    assert_equal(df.channels, UInt32(2))
    assert_equal(df.sample_rate, UInt32(48000))
    var v = raw.fader_get_current_volume(lib, h)
    assert_equal(v.result, MA_SUCCESS)
    assert_equal(v.value, Float32(1.0))
    raw.fader_free(lib, h)


def test_linear_ramp() raises:
    """0 -> 1 over 4 frames: 0, .25, .5, .75, then 1."""
    var lib = _lib()
    var h = raw.fader_alloc(lib)
    assert_equal(raw.fader_init(lib, h, FMT_F32, 1, 48000), MA_SUCCESS)
    assert_equal(raw.fader_set_fade(lib, h, 0.0, 1.0, 4), MA_SUCCESS)
    assert_equal(raw.fader_get_current_volume(lib, h).value, Float32(0.0))
    var src = _ones(6)
    var dst = _zeros(6)
    assert_equal(raw.fader_process(lib, h, dst, src, 6), MA_SUCCESS)
    assert_equal(dst[0], Float32(0.0))
    assert_equal(dst[1], Float32(0.25))
    assert_equal(dst[2], Float32(0.5))
    assert_equal(dst[3], Float32(0.75))
    assert_equal(dst[4], Float32(1.0))
    assert_equal(raw.fader_get_current_volume(lib, h).value, Float32(1.0))
    raw.fader_free(lib, h)


def test_fade_ex_delays_start() raises:
    """A start offset of 2 passes the first 2 frames through unchanged."""
    var lib = _lib()
    var h = raw.fader_alloc(lib)
    assert_equal(raw.fader_init(lib, h, FMT_F32, 1, 48000), MA_SUCCESS)
    assert_equal(raw.fader_set_fade_ex(lib, h, 0.0, 0.0, 4, 2), MA_SUCCESS)
    assert_equal(raw.fader_get_current_volume(lib, h).value, Float32(1.0))  # before start
    var src = _ones(4)
    var dst = _zeros(4)
    assert_equal(raw.fader_process(lib, h, dst, src, 4), MA_SUCCESS)
    assert_equal(dst[0], Float32(1.0))
    assert_equal(dst[1], Float32(1.0))
    assert_equal(dst[2], Float32(0.0))
    assert_equal(dst[3], Float32(0.0))
    raw.fader_free(lib, h)


def test_non_f32_format_rejected() raises:
    var lib = _lib()
    var h = raw.fader_alloc(lib)
    assert_equal(raw.fader_init(lib, h, FMT_S16, 1, 48000), MA_INVALID_ARGS)
    assert_equal(raw.fader_set_fade(lib, h, 0.0, 1.0, 4), MA_INVALID_ARGS)
    raw.fader_free(lib, h)


def test_null_and_uninit_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var src = _ones(2)
    var dst = _zeros(2)
    assert_equal(raw.fader_init(lib, n, FMT_F32, 1, 48000), MA_INVALID_ARGS)
    assert_equal(raw.fader_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.fader_process(lib, n, dst, src, 2), MA_INVALID_ARGS)
    var df = raw.fader_get_data_format(lib, n)
    assert_equal(df.result, MA_INVALID_ARGS)
    assert_equal(df.channels, UInt32(0))
    assert_equal(raw.fader_set_fade(lib, n, 0.0, 1.0, 4), MA_INVALID_ARGS)
    assert_equal(raw.fader_set_fade_ex(lib, n, 0.0, 1.0, 4, 1), MA_INVALID_ARGS)
    assert_equal(raw.fader_get_current_volume(lib, n).result, MA_INVALID_ARGS)
    raw.fader_free(lib, n)

    var h = raw.fader_alloc(lib)
    assert_equal(raw.fader_init(lib, h, FMT_F32, 1, 48000), MA_SUCCESS)
    assert_equal(raw.fader_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.fader_get_current_volume(lib, h).result, MA_INVALID_ARGS)
    raw.fader_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
