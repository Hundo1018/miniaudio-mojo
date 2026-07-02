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


def test_spatialization_accessors() raises:
    """Position/direction/velocity + attenuation/positioning/gains/distances/
    cone/doppler/pan-mode/listener — positive round-trips."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)

    raw.sound_group_set_position(lib, grp, 1.0, 2.0, 3.0)
    var p = raw.sound_group_get_position(lib, grp)
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    raw.sound_group_set_direction(lib, grp, 0.0, 0.0, -1.0)
    var d = raw.sound_group_get_direction(lib, grp)
    assert_true(d.z == -1.0)
    _ = raw.sound_group_get_direction_to_listener(lib, grp)

    raw.sound_group_set_velocity(lib, grp, 0.5, 0.0, 0.0)
    var v = raw.sound_group_get_velocity(lib, grp)
    assert_true(v.x == 0.5)

    raw.sound_group_set_attenuation_model(lib, grp, 2)  # linear
    assert_equal(raw.sound_group_get_attenuation_model(lib, grp), UInt32(2))
    raw.sound_group_set_positioning(lib, grp, 1)  # relative
    assert_equal(raw.sound_group_get_positioning(lib, grp), UInt32(1))

    raw.sound_group_set_rolloff(lib, grp, 1.5)
    assert_true(raw.sound_group_get_rolloff(lib, grp) == 1.5)
    raw.sound_group_set_min_gain(lib, grp, 0.1)
    assert_true(raw.sound_group_get_min_gain(lib, grp) == 0.1)
    raw.sound_group_set_max_gain(lib, grp, 0.9)
    assert_true(raw.sound_group_get_max_gain(lib, grp) == 0.9)
    raw.sound_group_set_min_distance(lib, grp, 2.0)
    assert_true(raw.sound_group_get_min_distance(lib, grp) == 2.0)
    raw.sound_group_set_max_distance(lib, grp, 20.0)
    assert_true(raw.sound_group_get_max_distance(lib, grp) == 20.0)

    raw.sound_group_set_cone(lib, grp, 0.5, 1.0, 0.25)
    var cone = raw.sound_group_get_cone(lib, grp)
    assert_true(cone.outer_gain == 0.25)

    raw.sound_group_set_doppler_factor(lib, grp, 1.2)
    assert_true(raw.sound_group_get_doppler_factor(lib, grp) == 1.2)
    raw.sound_group_set_directional_attenuation_factor(lib, grp, 0.7)
    assert_true(raw.sound_group_get_directional_attenuation_factor(lib, grp) == 0.7)

    raw.sound_group_set_pan_mode(lib, grp, 1)  # pan
    assert_equal(raw.sound_group_get_pan_mode(lib, grp), UInt32(1))
    raw.sound_group_set_pinned_listener_index(lib, grp, 0)
    assert_equal(raw.sound_group_get_pinned_listener_index(lib, grp), UInt32(0))
    _ = raw.sound_group_get_listener_index(lib, grp)

    raw.sound_group_free(lib, grp)
    eraw.engine_free(lib, eng)


def test_fade_and_scheduling() raises:
    """Fade setters + get_current_fade_volume + start/stop scheduling + time
    queries — positive path."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)

    raw.sound_group_set_fade_in_pcm_frames(lib, grp, 0.0, 1.0, 1000)
    raw.sound_group_set_fade_in_milliseconds(lib, grp, 0.0, 1.0, 50)
    _ = raw.sound_group_get_current_fade_volume(lib, grp)

    raw.sound_group_set_start_time_in_pcm_frames(lib, grp, 0)
    raw.sound_group_set_start_time_in_milliseconds(lib, grp, 0)
    raw.sound_group_set_stop_time_in_pcm_frames(lib, grp, 48000)
    raw.sound_group_set_stop_time_in_milliseconds(lib, grp, 1000)

    assert_equal(raw.sound_group_start(lib, grp), MA_SUCCESS)
    _ = raw.sound_group_get_time_in_pcm_frames(lib, grp)
    assert_equal(raw.sound_group_stop(lib, grp), MA_SUCCESS)

    raw.sound_group_free(lib, grp)
    eraw.engine_free(lib, eng)


def test_new_ops_null_handle_invalid() raises:
    """Every new op is null-safe: getters -> 0, void setters must not crash
    (exercises the shim guard branches)."""
    var lib = _lib()
    var n = null_handle()

    # getters return zeroed values
    assert_equal(raw.sound_group_get_attenuation_model(lib, n), UInt32(0))
    assert_equal(raw.sound_group_get_positioning(lib, n), UInt32(0))
    assert_equal(raw.sound_group_get_pan_mode(lib, n), UInt32(0))
    assert_equal(raw.sound_group_get_pinned_listener_index(lib, n), UInt32(0))
    assert_equal(raw.sound_group_get_listener_index(lib, n), UInt32(0))
    assert_equal(raw.sound_group_get_rolloff(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_min_gain(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_max_gain(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_min_distance(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_max_distance(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_doppler_factor(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_directional_attenuation_factor(lib, n), Float32(0))
    assert_equal(raw.sound_group_get_current_fade_volume(lib, n), Float32(0))
    var p = raw.sound_group_get_position(lib, n)
    assert_true(p.x == 0.0 and p.y == 0.0 and p.z == 0.0)
    _ = raw.sound_group_get_direction(lib, n)
    _ = raw.sound_group_get_direction_to_listener(lib, n)
    _ = raw.sound_group_get_velocity(lib, n)
    _ = raw.sound_group_get_cone(lib, n)

    # void setters on null handle: guard branch, must not crash
    raw.sound_group_set_position(lib, n, 1.0, 1.0, 1.0)
    raw.sound_group_set_direction(lib, n, 1.0, 1.0, 1.0)
    raw.sound_group_set_velocity(lib, n, 1.0, 1.0, 1.0)
    raw.sound_group_set_attenuation_model(lib, n, 1)
    raw.sound_group_set_positioning(lib, n, 1)
    raw.sound_group_set_rolloff(lib, n, 1.0)
    raw.sound_group_set_min_gain(lib, n, 0.0)
    raw.sound_group_set_max_gain(lib, n, 1.0)
    raw.sound_group_set_min_distance(lib, n, 1.0)
    raw.sound_group_set_max_distance(lib, n, 1.0)
    raw.sound_group_set_cone(lib, n, 0.0, 1.0, 1.0)
    raw.sound_group_set_doppler_factor(lib, n, 1.0)
    raw.sound_group_set_directional_attenuation_factor(lib, n, 1.0)
    raw.sound_group_set_pan_mode(lib, n, 0)
    raw.sound_group_set_pinned_listener_index(lib, n, 0)
    raw.sound_group_set_fade_in_pcm_frames(lib, n, 0.0, 1.0, 0)
    raw.sound_group_set_fade_in_milliseconds(lib, n, 0.0, 1.0, 0)
    raw.sound_group_set_start_time_in_pcm_frames(lib, n, 0)
    raw.sound_group_set_start_time_in_milliseconds(lib, n, 0)
    raw.sound_group_set_stop_time_in_pcm_frames(lib, n, 0)
    raw.sound_group_set_stop_time_in_milliseconds(lib, n, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
