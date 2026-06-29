"""TDD contract tests for the sound_group BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the owning engine runs on the NULL
backend. A group is initialised against the engine handle and exercised across
its control/query surface.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.engine_raw as eraw
import miniaudio._ffi.sound_group_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_control_query() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_true(grp != null_handle())
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)

    assert_equal(raw.sound_group_start(lib, grp), MA_SUCCESS)
    assert_equal(raw.sound_group_is_playing(lib, grp), 1)
    assert_equal(raw.sound_group_set_volume(lib, grp, 0.5), MA_SUCCESS)
    assert_true(raw.sound_group_get_volume(lib, grp) > 0.0)
    assert_equal(raw.sound_group_set_pan(lib, grp, 0.25), MA_SUCCESS)
    _ = raw.sound_group_get_pan(lib, grp)
    assert_equal(raw.sound_group_set_pitch(lib, grp, 1.5), MA_SUCCESS)
    _ = raw.sound_group_get_pitch(lib, grp)
    assert_equal(raw.sound_group_set_spatialization_enabled(lib, grp, False), MA_SUCCESS)
    assert_equal(raw.sound_group_is_spatialization_enabled(lib, grp), 0)
    _ = raw.sound_group_get_time_in_pcm_frames(lib, grp)
    assert_equal(raw.sound_group_stop(lib, grp), MA_SUCCESS)

    assert_equal(raw.sound_group_uninit(lib, grp), MA_SUCCESS)
    raw.sound_group_free(lib, grp)
    eraw.engine_free(lib, eng)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(raw.sound_group_init(lib, null_handle(), null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_set_volume(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_get_volume(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_group_set_pan(lib, null_handle(), 0.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_get_pan(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_group_set_pitch(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_get_pitch(lib, null_handle()), Float32(0))
    assert_equal(
        raw.sound_group_set_spatialization_enabled(lib, null_handle(), True),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.sound_group_is_spatialization_enabled(lib, null_handle()), 0)
    assert_equal(raw.sound_group_is_playing(lib, null_handle()), 0)
    assert_equal(raw.sound_group_get_time_in_pcm_frames(lib, null_handle()), UInt64(0))


def test_init_with_uninitialized_engine_invalid() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)  # not initialised -> shimint returns NULL
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_INVALID_ARGS)
    raw.sound_group_free(lib, grp)
    eraw.engine_free(lib, eng)


def test_ops_before_init_invalid() raises:
    var lib = _lib()
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_start(lib, grp), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_set_volume(lib, grp, 1.0), MA_INVALID_ARGS)
    raw.sound_group_free(lib, grp)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var grp = raw.sound_group_alloc(lib)
    assert_true(grp != null_handle())
    assert_equal(raw.sound_group_uninit(lib, grp), MA_SUCCESS)
    raw.sound_group_free(lib, grp)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.sound_group_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)  # reinit
    raw.sound_group_free(lib, grp)  # free initialized
    eraw.engine_free(lib, eng)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
