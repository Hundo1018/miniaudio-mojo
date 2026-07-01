"""TDD contract tests for the sound BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the owning engine runs on the NULL
backend. A sound is initialised against the engine handle (resolved C-side via
shimint_engine_ptr) and exercised across its full control/query surface.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.engine_raw as eraw
import miniaudio._ffi.sound_raw as raw


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_control_query() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_true(snd != null_handle())
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)
    assert_equal(raw.sound_is_playing(lib, snd), 1)
    assert_equal(raw.sound_set_volume(lib, snd, 0.5), MA_SUCCESS)
    assert_true(raw.sound_get_volume(lib, snd) > 0.0)
    assert_equal(raw.sound_set_pan(lib, snd, 0.25), MA_SUCCESS)
    _ = raw.sound_get_pan(lib, snd)
    assert_equal(raw.sound_set_pitch(lib, snd, 1.5), MA_SUCCESS)
    _ = raw.sound_get_pitch(lib, snd)
    assert_equal(raw.sound_set_looping(lib, snd, True), MA_SUCCESS)
    assert_equal(raw.sound_is_looping(lib, snd), 1)
    assert_equal(raw.sound_set_spatialization_enabled(lib, snd, False), MA_SUCCESS)
    assert_equal(raw.sound_is_spatialization_enabled(lib, snd), 0)

    var length = raw.sound_get_length_in_pcm_frames(lib, snd)
    assert_equal(length.result, MA_SUCCESS)
    assert_true(length.value > 0)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, snd, 0), MA_SUCCESS)
    assert_equal(raw.sound_get_cursor_in_pcm_frames(lib, snd).result, MA_SUCCESS)
    _ = raw.sound_at_end(lib, snd)
    assert_equal(raw.sound_stop(lib, snd), MA_SUCCESS)

    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.sound_init_from_file(lib, null_handle(), null_handle(), WAV_PATH, 0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.sound_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_set_volume(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_volume(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_pan(lib, null_handle(), 0.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_pan(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_pitch(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_pitch(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_looping(lib, null_handle(), True), MA_INVALID_ARGS)
    assert_equal(raw.sound_is_looping(lib, null_handle()), 0)
    assert_equal(raw.sound_is_playing(lib, null_handle()), 0)
    assert_equal(raw.sound_at_end(lib, null_handle()), 0)
    assert_equal(
        raw.sound_set_spatialization_enabled(lib, null_handle(), True), MA_INVALID_ARGS
    )
    assert_equal(raw.sound_is_spatialization_enabled(lib, null_handle()), 0)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_get_cursor_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_get_length_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )


def test_init_with_uninitialized_engine_invalid() raises:
    """A null/uninitialised engine handle resolves to NULL -> MA_INVALID_ARGS."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)  # allocated but NOT initialised
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_INVALID_ARGS)
    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_ops_before_init_invalid() raises:
    var lib = _lib()
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_start(lib, snd), MA_INVALID_ARGS)
    assert_equal(raw.sound_set_volume(lib, snd, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, snd, 0), MA_INVALID_ARGS)
    raw.sound_free(lib, snd)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var snd = raw.sound_alloc(lib)
    assert_true(snd != null_handle())
    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    raw.sound_free(lib, snd)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.sound_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)  # reinit
    raw.sound_free(lib, snd)  # free initialized
    eraw.engine_free(lib, eng)


def test_seconds_and_data_format() raises:
    """Seek_to_second / cursor+length in seconds / data_format — positive path."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    assert_equal(raw.sound_seek_to_second(lib, snd, 0.0), MA_SUCCESS)
    var cur = raw.sound_get_cursor_in_seconds(lib, snd)
    assert_equal(cur.result, MA_SUCCESS)
    var length = raw.sound_get_length_in_seconds(lib, snd)
    assert_equal(length.result, MA_SUCCESS)
    assert_true(length.value > 0.0)

    var fmt = raw.sound_get_data_format(lib, snd)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_true(fmt.channels > 0)
    assert_true(fmt.sample_rate > 0)

    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_spatialization_accessors() raises:
    """Position/direction/velocity + attenuation/positioning/gains/distances/
    cone/doppler/rolloff/pan-mode/listener — positive round-trips."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    raw.sound_set_position(lib, snd, 1.0, 2.0, 3.0)
    var p = raw.sound_get_position(lib, snd)
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    raw.sound_set_direction(lib, snd, 0.0, 0.0, -1.0)
    var d = raw.sound_get_direction(lib, snd)
    assert_true(d.z == -1.0)
    _ = raw.sound_get_direction_to_listener(lib, snd)

    raw.sound_set_velocity(lib, snd, 0.5, 0.0, 0.0)
    var v = raw.sound_get_velocity(lib, snd)
    assert_true(v.x == 0.5)

    raw.sound_set_attenuation_model(lib, snd, 2)  # linear
    assert_equal(raw.sound_get_attenuation_model(lib, snd), UInt32(2))
    raw.sound_set_positioning(lib, snd, 1)  # relative
    assert_equal(raw.sound_get_positioning(lib, snd), UInt32(1))

    raw.sound_set_rolloff(lib, snd, 1.5)
    assert_true(raw.sound_get_rolloff(lib, snd) == 1.5)
    raw.sound_set_min_gain(lib, snd, 0.1)
    assert_true(raw.sound_get_min_gain(lib, snd) == 0.1)
    raw.sound_set_max_gain(lib, snd, 0.9)
    assert_true(raw.sound_get_max_gain(lib, snd) == 0.9)
    raw.sound_set_min_distance(lib, snd, 2.0)
    assert_true(raw.sound_get_min_distance(lib, snd) == 2.0)
    raw.sound_set_max_distance(lib, snd, 20.0)
    assert_true(raw.sound_get_max_distance(lib, snd) == 20.0)

    raw.sound_set_cone(lib, snd, 0.5, 1.0, 0.25)
    var cone = raw.sound_get_cone(lib, snd)
    assert_true(cone.outer_gain == 0.25)

    raw.sound_set_doppler_factor(lib, snd, 1.2)
    assert_true(raw.sound_get_doppler_factor(lib, snd) == 1.2)
    raw.sound_set_directional_attenuation_factor(lib, snd, 0.7)
    assert_true(raw.sound_get_directional_attenuation_factor(lib, snd) == 0.7)

    raw.sound_set_pan_mode(lib, snd, 1)  # pan
    assert_equal(raw.sound_get_pan_mode(lib, snd), UInt32(1))
    raw.sound_set_pinned_listener_index(lib, snd, 0)
    assert_equal(raw.sound_get_pinned_listener_index(lib, snd), UInt32(0))
    _ = raw.sound_get_listener_index(lib, snd)

    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_fade_and_scheduling() raises:
    """Fade setters + get_current_fade_volume/reset + start/stop scheduling +
    stop_with_fade + time queries — positive path."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    raw.sound_set_fade_in_pcm_frames(lib, snd, 0.0, 1.0, 1000)
    raw.sound_set_fade_in_milliseconds(lib, snd, 0.0, 1.0, 50)
    raw.sound_set_fade_start_in_pcm_frames(lib, snd, 0.0, 1.0, 1000, 0)
    raw.sound_set_fade_start_in_milliseconds(lib, snd, 0.0, 1.0, 50, 0)
    _ = raw.sound_get_current_fade_volume(lib, snd)
    raw.sound_reset_fade(lib, snd)

    raw.sound_set_start_time_in_pcm_frames(lib, snd, 0)
    raw.sound_set_start_time_in_milliseconds(lib, snd, 0)
    raw.sound_set_stop_time_in_pcm_frames(lib, snd, 48000)
    raw.sound_set_stop_time_in_milliseconds(lib, snd, 1000)
    raw.sound_set_stop_time_with_fade_in_pcm_frames(lib, snd, 48000, 1000)
    raw.sound_set_stop_time_with_fade_in_milliseconds(lib, snd, 1000, 50)

    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)
    assert_equal(raw.sound_stop_with_fade_in_pcm_frames(lib, snd, 500), MA_SUCCESS)
    assert_equal(raw.sound_stop_with_fade_in_milliseconds(lib, snd, 10), MA_SUCCESS)

    raw.sound_reset_start_time(lib, snd)
    raw.sound_reset_stop_time(lib, snd)
    raw.sound_reset_stop_time_and_fade(lib, snd)
    _ = raw.sound_get_time_in_pcm_frames(lib, snd)
    _ = raw.sound_get_time_in_milliseconds(lib, snd)

    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_init_copy() raises:
    """Init_copy clones a sound sharing the source's data; both are queryable."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var src = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, src, eng, WAV_PATH, 0), MA_SUCCESS)
    var dst = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_copy(lib, dst, eng, src, 0), MA_SUCCESS)
    assert_true(raw.sound_get_length_in_pcm_frames(lib, dst).value > 0)

    raw.sound_free(lib, dst)
    raw.sound_free(lib, src)
    eraw.engine_free(lib, eng)


def test_new_ops_null_handle_invalid() raises:
    """Every new op is null-safe: int-returning -> MA_INVALID_ARGS, getters -> 0,
    void setters must not crash (exercises the shim guard branches)."""
    var lib = _lib()
    var n = null_handle()

    assert_equal(raw.sound_seek_to_second(lib, n, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_cursor_in_seconds(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.sound_get_length_in_seconds(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.sound_get_data_format(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.sound_init_copy(lib, n, n, n, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_stop_with_fade_in_pcm_frames(lib, n, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_stop_with_fade_in_milliseconds(lib, n, 0), MA_INVALID_ARGS)

    # getters return zeroed values
    assert_equal(raw.sound_get_attenuation_model(lib, n), UInt32(0))
    assert_equal(raw.sound_get_positioning(lib, n), UInt32(0))
    assert_equal(raw.sound_get_pan_mode(lib, n), UInt32(0))
    assert_equal(raw.sound_get_pinned_listener_index(lib, n), UInt32(0))
    assert_equal(raw.sound_get_listener_index(lib, n), UInt32(0))
    assert_equal(raw.sound_get_rolloff(lib, n), Float32(0))
    assert_equal(raw.sound_get_min_gain(lib, n), Float32(0))
    assert_equal(raw.sound_get_max_gain(lib, n), Float32(0))
    assert_equal(raw.sound_get_min_distance(lib, n), Float32(0))
    assert_equal(raw.sound_get_max_distance(lib, n), Float32(0))
    assert_equal(raw.sound_get_doppler_factor(lib, n), Float32(0))
    assert_equal(raw.sound_get_directional_attenuation_factor(lib, n), Float32(0))
    assert_equal(raw.sound_get_current_fade_volume(lib, n), Float32(0))
    assert_equal(raw.sound_get_time_in_pcm_frames(lib, n), UInt64(0))
    assert_equal(raw.sound_get_time_in_milliseconds(lib, n), UInt64(0))
    var p = raw.sound_get_position(lib, n)
    assert_true(p.x == 0.0 and p.y == 0.0 and p.z == 0.0)
    _ = raw.sound_get_direction(lib, n)
    _ = raw.sound_get_direction_to_listener(lib, n)
    _ = raw.sound_get_velocity(lib, n)
    _ = raw.sound_get_cone(lib, n)

    # void setters on null handle: guard branch, must not crash
    raw.sound_set_position(lib, n, 1.0, 1.0, 1.0)
    raw.sound_set_direction(lib, n, 1.0, 1.0, 1.0)
    raw.sound_set_velocity(lib, n, 1.0, 1.0, 1.0)
    raw.sound_set_attenuation_model(lib, n, 1)
    raw.sound_set_positioning(lib, n, 1)
    raw.sound_set_rolloff(lib, n, 1.0)
    raw.sound_set_min_gain(lib, n, 0.0)
    raw.sound_set_max_gain(lib, n, 1.0)
    raw.sound_set_min_distance(lib, n, 1.0)
    raw.sound_set_max_distance(lib, n, 1.0)
    raw.sound_set_cone(lib, n, 0.0, 1.0, 1.0)
    raw.sound_set_doppler_factor(lib, n, 1.0)
    raw.sound_set_directional_attenuation_factor(lib, n, 1.0)
    raw.sound_set_pan_mode(lib, n, 0)
    raw.sound_set_pinned_listener_index(lib, n, 0)
    raw.sound_set_fade_in_pcm_frames(lib, n, 0.0, 1.0, 0)
    raw.sound_set_fade_in_milliseconds(lib, n, 0.0, 1.0, 0)
    raw.sound_set_fade_start_in_pcm_frames(lib, n, 0.0, 1.0, 0, 0)
    raw.sound_set_fade_start_in_milliseconds(lib, n, 0.0, 1.0, 0, 0)
    raw.sound_reset_fade(lib, n)
    raw.sound_set_start_time_in_pcm_frames(lib, n, 0)
    raw.sound_set_start_time_in_milliseconds(lib, n, 0)
    raw.sound_set_stop_time_in_pcm_frames(lib, n, 0)
    raw.sound_set_stop_time_in_milliseconds(lib, n, 0)
    raw.sound_set_stop_time_with_fade_in_pcm_frames(lib, n, 0, 0)
    raw.sound_set_stop_time_with_fade_in_milliseconds(lib, n, 0, 0)
    raw.sound_reset_start_time(lib, n)
    raw.sound_reset_stop_time(lib, n)
    raw.sound_reset_stop_time_and_fade(lib, n)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
