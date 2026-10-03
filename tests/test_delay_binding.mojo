"""TDD contract tests for the delay BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: ma_delay is an in-memory f32 delay
line. All 10 MA_API delay functions are exercised (positive and negative).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.effect_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def _impulse(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(0))
    buf[0] = 1.0
    return buf^


def test_pure_delay_shifts_impulse() raises:
    """decay=0 -> delayed start: an impulse at frame 0 reappears at frame D."""
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.delay_init(lib, h, 1, 48000, 4, 0.0), MA_SUCCESS)
    var src = _impulse(8)
    var dst = List[Float32]()
    dst.resize(8, Float32(-1))
    assert_equal(raw.delay_process(lib, h, dst, src, 8), MA_SUCCESS)
    for i in range(8):
        assert_equal(dst[i], Float32(1.0) if i == 4 else Float32(0.0))
    raw.delay_free(lib, h)


def test_echo_decays_each_pass() raises:
    """decay=0.5 -> immediate start: 1.0 at 0, 0.5 at D, 0.25 at 2D."""
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_equal(raw.delay_init(lib, h, 1, 48000, 4, 0.5), MA_SUCCESS)
    var src = _impulse(12)
    var dst = List[Float32]()
    dst.resize(12, Float32(0))
    assert_equal(raw.delay_process(lib, h, dst, src, 12), MA_SUCCESS)
    assert_equal(dst[0], Float32(1.0))
    assert_equal(dst[4], Float32(0.5))
    assert_equal(dst[8], Float32(0.25))
    assert_equal(dst[1], Float32(0.0))
    raw.delay_free(lib, h)


def test_wet_dry_decay_round_trip() raises:
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_equal(raw.delay_init(lib, h, 2, 44100, 16, 0.25), MA_SUCCESS)
    assert_equal(raw.delay_get_wet(lib, h).value, Float32(1.0))
    assert_equal(raw.delay_get_dry(lib, h).value, Float32(1.0))
    assert_equal(raw.delay_get_decay(lib, h).value, Float32(0.25))
    assert_equal(raw.delay_set_wet(lib, h, 0.5), MA_SUCCESS)
    assert_equal(raw.delay_set_dry(lib, h, 0.75), MA_SUCCESS)
    assert_equal(raw.delay_set_decay(lib, h, 0.125), MA_SUCCESS)
    var wet = raw.delay_get_wet(lib, h)
    assert_equal(wet.result, MA_SUCCESS)
    assert_equal(wet.value, Float32(0.5))
    assert_equal(raw.delay_get_dry(lib, h).value, Float32(0.75))
    assert_equal(raw.delay_get_decay(lib, h).value, Float32(0.125))
    raw.delay_free(lib, h)


def test_wet_scales_output() raises:
    """wet=0.5 halves the delayed impulse."""
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_equal(raw.delay_init(lib, h, 1, 48000, 2, 0.0), MA_SUCCESS)
    assert_equal(raw.delay_set_wet(lib, h, 0.5), MA_SUCCESS)
    var src = _impulse(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))
    assert_equal(raw.delay_process(lib, h, dst, src, 4), MA_SUCCESS)
    assert_equal(dst[2], Float32(0.5))
    raw.delay_free(lib, h)


def test_init_rejects_bad_config() raises:
    """decay outside [0,1], zero channels and zero delay length are invalid."""
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_equal(raw.delay_init(lib, h, 1, 48000, 4, 1.5), MA_INVALID_ARGS)
    assert_equal(raw.delay_init(lib, h, 1, 48000, 4, -0.1), MA_INVALID_ARGS)
    assert_equal(raw.delay_init(lib, h, 0, 48000, 4, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.delay_init(lib, h, 1, 48000, 0, 0.0), MA_INVALID_ARGS)
    # A failed init leaves the handle unusable.
    assert_equal(raw.delay_set_wet(lib, h, 0.5), MA_INVALID_ARGS)
    raw.delay_free(lib, h)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var src = _impulse(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))
    assert_equal(raw.delay_init(lib, n, 1, 48000, 4, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.delay_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.delay_process(lib, n, dst, src, 4), MA_INVALID_ARGS)
    assert_equal(raw.delay_set_wet(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.delay_set_dry(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.delay_set_decay(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.delay_get_wet(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.delay_get_dry(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.delay_get_decay(lib, n).result, MA_INVALID_ARGS)
    raw.delay_free(lib, n)


def test_uninit_then_ops_invalid_and_reinit_ok() raises:
    var lib = _lib()
    var h = raw.delay_alloc(lib)
    assert_equal(raw.delay_uninit(lib, h), MA_SUCCESS)  # uninit before init is a no-op
    assert_equal(raw.delay_init(lib, h, 1, 48000, 4, 0.0), MA_SUCCESS)
    assert_equal(raw.delay_init(lib, h, 2, 48000, 8, 0.5), MA_SUCCESS)  # reinit
    assert_equal(raw.delay_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.delay_get_decay(lib, h).result, MA_INVALID_ARGS)
    raw.delay_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
