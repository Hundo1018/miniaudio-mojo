"""TDD contract tests for the engine BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: every engine runs on the NULL backend
(use_null_backend=True). The engine auto-starts and its clock advances, so we
assert observable progress via get_time_in_pcm_frames.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.engine_raw as raw


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_play_query() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_true(eng != null_handle())
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)

    assert_true(raw.engine_get_sample_rate(lib, eng) > 0)
    assert_true(raw.engine_get_channels(lib, eng) > 0)
    assert_equal(raw.engine_set_volume(lib, eng, 0.5), MA_SUCCESS)
    assert_true(raw.engine_get_volume(lib, eng) > 0.0)
    assert_equal(raw.engine_set_gain_db(lib, eng, -6.0), MA_SUCCESS)
    _ = raw.engine_get_gain_db(lib, eng)

    assert_equal(raw.engine_start(lib, eng), MA_SUCCESS)
    assert_equal(raw.engine_play_sound(lib, eng, WAV_PATH), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_true(raw.engine_get_time_in_pcm_frames(lib, eng) > 0)
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)

    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)
    raw.engine_free(lib, eng)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(raw.engine_init(lib, null_handle(), True), MA_INVALID_ARGS)
    assert_equal(raw.engine_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_play_sound(lib, null_handle(), WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_sample_rate(lib, null_handle()), UInt32(0))
    assert_equal(raw.engine_get_channels(lib, null_handle()), UInt32(0))
    assert_equal(raw.engine_set_volume(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_volume(lib, null_handle()), Float32(0))
    assert_equal(raw.engine_set_gain_db(lib, null_handle(), 0.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_gain_db(lib, null_handle()), Float32(0))
    assert_equal(raw.engine_get_time_in_pcm_frames(lib, null_handle()), UInt64(0))


def test_ops_before_init_invalid() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_start(lib, eng), MA_INVALID_ARGS)
    assert_equal(raw.engine_stop(lib, eng), MA_INVALID_ARGS)
    assert_equal(raw.engine_play_sound(lib, eng, WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.engine_set_volume(lib, eng, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_set_gain_db(lib, eng, 0.0), MA_INVALID_ARGS)
    raw.engine_free(lib, eng)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_true(eng != null_handle())
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)
    raw.engine_free(lib, eng)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.engine_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    """Re-init auto-uninits the previous engine + context; then free initialized."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)  # reinit branch
    raw.engine_free(lib, eng)  # free initialized (+ context) branch


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
