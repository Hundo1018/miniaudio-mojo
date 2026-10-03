"""TDD contract tests for the gainer BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 10 MA_API gainer functions are
exercised (positive and negative).

miniaudio 0.11.25 quirk: after a non-initial gain change the next process()
call lerps across the whole block and can overshoot, so behaviour assertions
measure the block AFTER a warm-up call (see effect.mojo module docs).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.effect_raw as raw


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


def test_heap_size() raises:
    var lib = _lib()
    var rc = raw.gainer_get_heap_size(lib, 2, 16)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value >= UInt64(2 * 2 * 4))  # old + new gain per channel
    var bad = raw.gainer_get_heap_size(lib, 0, 16)
    assert_equal(bad.result, MA_INVALID_ARGS)
    assert_equal(bad.value, UInt64(0))


def test_initial_gain_applies_immediately() raises:
    """The first set_gain is not smoothed: the very next block is exact."""
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.gainer_init(lib, h, 2, 8), MA_SUCCESS)
    assert_equal(raw.gainer_set_gain(lib, h, 0.5), MA_SUCCESS)
    var src = _ones(32)
    var dst = _zeros(32)
    assert_equal(raw.gainer_process(lib, h, dst, src, 16), MA_SUCCESS)
    for i in range(32):
        assert_equal(dst[i], Float32(0.5))
    raw.gainer_free(lib, h)


def test_set_gains_per_channel_and_master() raises:
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_equal(raw.gainer_init_preallocated(lib, h, 2, 4), MA_SUCCESS)
    var gains: List[Float32] = [Float32(0.25), Float32(1.0)]
    assert_equal(raw.gainer_set_gains(lib, h, gains), MA_SUCCESS)
    assert_equal(raw.gainer_set_master_volume(lib, h, 0.5), MA_SUCCESS)
    var mv = raw.gainer_get_master_volume(lib, h)
    assert_equal(mv.result, MA_SUCCESS)
    assert_equal(mv.value, Float32(0.5))
    var src = _ones(16)
    var dst = _zeros(16)
    assert_equal(raw.gainer_process(lib, h, dst, src, 8), MA_SUCCESS)
    assert_equal(dst[14], Float32(0.125))  # left: 0.25 * 0.5
    assert_equal(dst[15], Float32(0.5))    # right: 1.0 * 0.5
    raw.gainer_free(lib, h)


def test_gain_change_settles_after_warmup() raises:
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_equal(raw.gainer_init(lib, h, 1, 4), MA_SUCCESS)
    assert_equal(raw.gainer_set_gain(lib, h, 1.0), MA_SUCCESS)
    assert_equal(raw.gainer_set_gain(lib, h, 0.25), MA_SUCCESS)  # smoothed change
    var src = _ones(64)
    var dst = _zeros(64)
    assert_equal(raw.gainer_process(lib, h, dst, src, 64), MA_SUCCESS)  # warm-up
    assert_equal(raw.gainer_process(lib, h, dst, src, 64), MA_SUCCESS)
    for i in range(64):
        assert_equal(dst[i], Float32(0.25))
    raw.gainer_free(lib, h)


def test_set_gains_wrong_count_invalid() raises:
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_equal(raw.gainer_init(lib, h, 2, 4), MA_SUCCESS)
    var one: List[Float32] = [Float32(0.5)]
    assert_equal(raw.gainer_set_gains(lib, h, one), MA_INVALID_ARGS)
    raw.gainer_free(lib, h)


def test_init_zero_channels_invalid() raises:
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_equal(raw.gainer_init(lib, h, 0, 4), MA_INVALID_ARGS)
    assert_equal(raw.gainer_init_preallocated(lib, h, 0, 4), MA_INVALID_ARGS)
    assert_equal(raw.gainer_set_gain(lib, h, 0.5), MA_INVALID_ARGS)
    raw.gainer_free(lib, h)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var src = _ones(4)
    var dst = _zeros(4)
    var gains: List[Float32] = [Float32(0.5)]
    assert_equal(raw.gainer_init(lib, n, 1, 4), MA_INVALID_ARGS)
    assert_equal(raw.gainer_init_preallocated(lib, n, 1, 4), MA_INVALID_ARGS)
    assert_equal(raw.gainer_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.gainer_process(lib, n, dst, src, 4), MA_INVALID_ARGS)
    assert_equal(raw.gainer_set_gain(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.gainer_set_gains(lib, n, gains), MA_INVALID_ARGS)
    assert_equal(raw.gainer_set_master_volume(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.gainer_get_master_volume(lib, n).result, MA_INVALID_ARGS)
    raw.gainer_free(lib, n)


def test_uninit_and_reinit() raises:
    var lib = _lib()
    var h = raw.gainer_alloc(lib)
    assert_equal(raw.gainer_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.gainer_init_preallocated(lib, h, 1, 4), MA_SUCCESS)
    assert_equal(raw.gainer_init(lib, h, 2, 4), MA_SUCCESS)  # reinit frees the old heap
    assert_equal(raw.gainer_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.gainer_get_master_volume(lib, h).result, MA_INVALID_ARGS)
    raw.gainer_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
