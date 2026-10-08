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
import miniaudio._ffi.data_source_raw as dsraw
import miniaudio._ffi.sound_group_raw as graw
import miniaudio._ffi.node_raw as nraw


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


# ---------------------------------------------------------------------------
# init from a data source, the engine back-reference, borrowed data-source views
# ---------------------------------------------------------------------------

comptime FLAG_LOOPING: UInt32 = 0x20
comptime FLAG_NO_PITCH_NO_SPATIAL: UInt32 = 0x2000 | 0x4000
comptime RANGE_END: UInt64 = 0xFFFFFFFFFFFFFFFF
comptime LEFT: Float32 = 0.25
comptime RIGHT: Float32 = -0.5


def _engine(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A null-backend engine with its device stopped, so the test is the only reader."""
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(eraw.engine_stop(lib, eng), MA_SUCCESS)
    return eng


def _constant_source(
    lib: MaLib, frames: Int, rate: UInt32
) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A stereo buffer data source whose left samples are LEFT and right are RIGHT."""
    var samples = List[Float32]()
    for _ in range(frames):
        samples.append(LEFT)
        samples.append(RIGHT)
    var ds = dsraw.data_source_alloc(lib)
    assert_true(ds != null_handle())
    assert_equal(
        dsraw.data_source_init_buffer(lib, ds, samples, UInt64(frames), 2, rate),
        MA_SUCCESS,
    )
    return ds


comptime PERIOD: Int = 480  # frames the engine renders per pass (10 ms at 48 kHz)


def _pull(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], frames: Int = PERIOD
) raises -> List[Float32]:
    """Read `frames` stereo frames from the engine's node graph.

    The engine renders its graph a whole period at a time and serves reads from
    that block, so a setting changed mid-period is only heard from the next
    period on. Reading whole periods (the default) makes "change, then read"
    mean what it says.
    """
    var buf = List[Float32]()
    buf.resize(frames * 2, Float32(0))
    var rc = eraw.engine_read_pcm_frames(lib, eng, buf, UInt64(frames))
    assert_equal(rc.result, MA_SUCCESS)
    buf.resize(Int(rc.value) * 2, Float32(0))
    return buf^


def _peak(samples: List[Float32]) -> Float32:
    var peak = Float32(0)
    for i in range(len(samples)):
        var v = samples[i]
        if v < Float32(0):
            v = -v
        if v > peak:
            peak = v
    return peak


def test_init_from_data_source_plays_the_sources_frames() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _constant_source(lib, 480, eraw.engine_get_sample_rate(lib, eng))

    var snd = raw.sound_alloc(lib)
    assert_equal(
        raw.sound_init_from_data_source(lib, snd, eng, ds, FLAG_NO_PITCH_NO_SPATIAL),
        MA_SUCCESS,
    )
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(480))
    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)

    var got = _pull(lib, eng)
    assert_equal(len(got), 2 * PERIOD)
    for i in range(PERIOD):
        assert_equal(got[2 * i], LEFT)
        assert_equal(got[2 * i + 1], RIGHT)

    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_init_from_data_source_rejects_bad_arguments() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _constant_source(lib, 16, eraw.engine_get_sample_rate(lib, eng))
    var snd = raw.sound_alloc(lib)

    assert_equal(
        raw.sound_init_from_data_source(lib, null_handle(), eng, ds, 0), MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_init_from_data_source(lib, snd, null_handle(), ds, 0), MA_INVALID_ARGS
    )
    # No source: miniaudio would quietly build a group-like node; the shim refuses.
    assert_equal(
        raw.sound_init_from_data_source(lib, snd, eng, null_handle(), 0), MA_INVALID_ARGS
    )
    # A source that has been uninitialised is not a source.
    assert_equal(dsraw.data_source_uninit(lib, ds), MA_SUCCESS)
    assert_equal(raw.sound_init_from_data_source(lib, snd, eng, ds, 0), MA_INVALID_ARGS)
    # A failed init leaves the sound uninitialised.
    assert_equal(raw.sound_start(lib, snd), MA_INVALID_ARGS)

    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_get_engine_is_the_engine_the_sound_was_built_with() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var other = _engine(lib)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    assert_true(raw.sound_get_engine(lib, snd) == eng)
    assert_true(raw.sound_get_engine(lib, snd) != other)

    # Not initialised / not there: nothing to report.
    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    assert_true(raw.sound_get_engine(lib, snd) == null_handle())
    assert_true(raw.sound_get_engine(lib, null_handle()) == null_handle())

    raw.sound_free(lib, snd)
    eraw.engine_free(lib, other)
    eraw.engine_free(lib, eng)


def test_a_data_source_view_acts_on_the_sounds_own_source() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _constant_source(lib, 480, eraw.engine_get_sample_rate(lib, eng))
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, snd, eng, ds, 0), MA_SUCCESS)

    var view = dsraw.data_source_alloc(lib)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_SUCCESS)

    # It is the source the sound was given, and it reads like one.
    var same = dsraw.data_source_is_same(lib, view, ds)
    assert_equal(same.result, MA_SUCCESS)
    assert_true(same.value)
    var len_before = dsraw.data_source_get_length_in_pcm_frames(lib, view)
    assert_equal(len_before.result, MA_SUCCESS)
    assert_equal(len_before.value, UInt64(480))
    var fmt = dsraw.data_source_get_data_format(lib, view)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_equal(fmt.channels, UInt32(2))

    # Narrowing the range through the view narrows what the *sound* reports: the
    # view is not a copy.
    assert_equal(dsraw.data_source_set_range_in_pcm_frames(lib, view, 10, 110), MA_SUCCESS)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(100))
    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, ds).value, UInt64(100))

    # Dropping the view takes nothing with it.
    dsraw.data_source_free(lib, view)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(100))

    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_a_data_source_view_of_a_file_sound_reports_its_format() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    var view = dsraw.data_source_alloc(lib)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_SUCCESS)
    var from_view = dsraw.data_source_get_length_in_pcm_frames(lib, view)
    assert_equal(from_view.result, MA_SUCCESS)
    assert_equal(from_view.value, raw.sound_get_length_in_pcm_frames(lib, snd).value)
    assert_equal(
        dsraw.data_source_get_data_format(lib, view).channels,
        raw.sound_get_data_format(lib, snd).channels,
    )

    dsraw.data_source_free(lib, view)
    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_a_data_source_view_fails_cleanly_once_the_sound_is_gone() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _constant_source(lib, 64, eraw.engine_get_sample_rate(lib, eng))
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, snd, eng, ds, 0), MA_SUCCESS)
    var view = dsraw.data_source_alloc(lib)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_SUCCESS)

    # Uninitialised sound: the view has nothing to point at any more.
    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    assert_equal(
        dsraw.data_source_get_length_in_pcm_frames(lib, view).result, MA_INVALID_ARGS
    )
    # Freed sound: the bookkeeping outlives it for the view's sake, so this is
    # still a clean error rather than a read of freed memory.
    raw.sound_free(lib, snd)
    assert_equal(
        dsraw.data_source_get_length_in_pcm_frames(lib, view).result, MA_INVALID_ARGS
    )
    assert_equal(dsraw.data_source_uninit(lib, view), MA_SUCCESS)

    dsraw.data_source_free(lib, view)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_a_data_source_view_can_be_rebound_and_uninitialised() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds_a = _constant_source(lib, 100, eraw.engine_get_sample_rate(lib, eng))
    var ds_b = _constant_source(lib, 200, eraw.engine_get_sample_rate(lib, eng))
    var a = raw.sound_alloc(lib)
    var b = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, a, eng, ds_a, 0), MA_SUCCESS)
    assert_equal(raw.sound_init_from_data_source(lib, b, eng, ds_b, 0), MA_SUCCESS)

    var view = dsraw.data_source_alloc(lib)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, a), MA_SUCCESS)
    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, view).value, UInt64(100))
    # Borrowing again re-points the view (and lets go of the first sound).
    assert_equal(dsraw.data_source_borrow_sound(lib, view, b), MA_SUCCESS)
    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, view).value, UInt64(200))
    assert_true(dsraw.data_source_is_same(lib, view, ds_b).value)
    assert_true(not dsraw.data_source_is_same(lib, view, ds_a).value)

    # Uninit hands the view back; the sound and its source are untouched.
    assert_equal(dsraw.data_source_uninit(lib, view), MA_SUCCESS)
    assert_equal(
        dsraw.data_source_get_length_in_pcm_frames(lib, view).result, MA_INVALID_ARGS
    )
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, b).value, UInt64(200))

    # A view handle can become an ordinary buffer source afterwards.
    var samples = List[Float32]()
    samples.resize(8, Float32(0.5))
    assert_equal(dsraw.data_source_borrow_sound(lib, view, a), MA_SUCCESS)
    assert_equal(dsraw.data_source_init_buffer(lib, view, samples, UInt64(4), 2, 48000), MA_SUCCESS)
    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, view).value, UInt64(4))

    dsraw.data_source_free(lib, view)
    raw.sound_free(lib, a)
    raw.sound_free(lib, b)
    dsraw.data_source_free(lib, ds_a)
    dsraw.data_source_free(lib, ds_b)
    eraw.engine_free(lib, eng)


def test_borrowing_a_sounds_data_source_negative_paths() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var view = dsraw.data_source_alloc(lib)
    var snd = raw.sound_alloc(lib)

    assert_equal(dsraw.data_source_borrow_sound(lib, null_handle(), snd), MA_INVALID_ARGS)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, null_handle()), MA_INVALID_ARGS)
    # Allocated but never initialised.
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_INVALID_ARGS)

    # A sound with no data source (a group-like sound) has nothing to borrow.
    var cfg = raw.sound_config_alloc(lib)
    assert_equal(raw.sound_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_INVALID_ARGS)

    # Identity needs two live handles.
    assert_equal(dsraw.data_source_is_same(lib, view, view).result, MA_INVALID_ARGS)
    assert_equal(
        dsraw.data_source_is_same(lib, null_handle(), view).result, MA_INVALID_ARGS
    )

    raw.sound_config_free(lib, cfg)
    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, view)
    eraw.engine_free(lib, eng)


def test_a_data_source_view_is_refused_anywhere_it_would_be_kept() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var rate = eraw.engine_get_sample_rate(lib, eng)
    var ds = _constant_source(lib, 64, rate)
    var other = _constant_source(lib, 64, rate)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, snd, eng, ds, 0), MA_SUCCESS)
    var view = dsraw.data_source_alloc(lib)
    assert_equal(dsraw.data_source_borrow_sound(lib, view, snd), MA_SUCCESS)

    # Chain links keep the pointer they are given.
    assert_equal(dsraw.data_source_set_current(lib, other, view), MA_INVALID_ARGS)
    assert_equal(dsraw.data_source_set_next(lib, other, view), MA_INVALID_ARGS)
    assert_equal(dsraw.data_source_set_next_callback(lib, other, view), MA_INVALID_ARGS)
    # ...and so does a view being the one that is chained: its callback is the
    # shim's own, written for the buffer source.
    assert_equal(dsraw.data_source_set_next_callback(lib, view, other), MA_INVALID_ARGS)
    # A node keeps its source.
    var node = dsraw.data_source_node_alloc(lib)
    assert_equal(dsraw.data_source_node_init(lib, node, eng, view), MA_INVALID_ARGS)
    dsraw.data_source_node_free(lib, node)
    # So does a sound.
    var snd2 = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, snd2, eng, view, 0), MA_INVALID_ARGS)
    # And a sound config.
    var cfg = raw.sound_config_alloc(lib)
    assert_equal(raw.sound_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, view), MA_INVALID_ARGS)

    # Asking *about* chains is fine: those are identity tests, not links.
    assert_equal(dsraw.data_source_current_is(lib, view, view).result, MA_SUCCESS)

    raw.sound_config_free(lib, cfg)
    raw.sound_free(lib, snd2)
    dsraw.data_source_free(lib, view)
    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, other)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


# ---------------------------------------------------------------------------
# ma_sound_config behind a handle, and ma_sound_init_ex
# ---------------------------------------------------------------------------


def _config(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var cfg = raw.sound_config_alloc(lib)
    assert_true(cfg != null_handle())
    assert_equal(raw.sound_config_init(lib, cfg), MA_SUCCESS)
    return cfg


def test_config_from_a_file_path_builds_the_same_sound_as_init_from_file() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var plain = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, plain, eng, WAV_PATH, 0), MA_SUCCESS)

    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)

    assert_equal(
        raw.sound_get_length_in_pcm_frames(lib, snd).value,
        raw.sound_get_length_in_pcm_frames(lib, plain).value,
    )
    assert_equal(
        raw.sound_get_data_format(lib, snd).channels,
        raw.sound_get_data_format(lib, plain).channels,
    )
    assert_true(raw.sound_get_engine(lib, snd) == eng)

    raw.sound_free(lib, snd)
    raw.sound_free(lib, plain)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_init_for_engine_is_a_working_starting_point() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = raw.sound_config_alloc(lib)
    assert_equal(raw.sound_config_init_for_engine(lib, cfg, eng), MA_SUCCESS)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_true(raw.sound_get_length_in_pcm_frames(lib, snd).value > UInt64(0))

    # Re-initialising a config is allowed and drops what it held.
    assert_equal(raw.sound_config_init_for_engine(lib, cfg, eng), MA_SUCCESS)
    var empty = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, empty, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, empty).result != MA_SUCCESS, True)

    raw.sound_free(lib, empty)
    raw.sound_free(lib, snd)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_init_for_engine_rejects_a_missing_engine() raises:
    var lib = _lib()
    var cfg = raw.sound_config_alloc(lib)
    assert_equal(
        raw.sound_config_init_for_engine(lib, cfg, null_handle()), MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_config_init_for_engine(lib, null_handle(), null_handle()),
        MA_INVALID_ARGS,
    )
    # An engine that was allocated but never initialised is no engine.
    var eng = eraw.engine_alloc(lib)
    assert_equal(raw.sound_config_init_for_engine(lib, cfg, eng), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_init(lib, null_handle()), MA_INVALID_ARGS)
    eraw.engine_free(lib, eng)
    raw.sound_config_free(lib, cfg)


def test_config_range_and_initial_seek_shape_a_file_sound() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var full = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, full, eng, WAV_PATH, 0), MA_SUCCESS)
    var total = raw.sound_get_length_in_pcm_frames(lib, full).value
    assert_true(total > UInt64(1500))

    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    assert_equal(raw.sound_config_set_range(lib, cfg, 100, 1100), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(1000))

    # An open end ("to the end of the file") leaves the reported length alone:
    # miniaudio only narrows the length when the range has an end.
    assert_equal(raw.sound_config_set_range(lib, cfg, 100, RANGE_END), MA_SUCCESS)
    var tail = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, tail, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, tail).value, total)

    # Starting position: the cursor begins where the config said.
    assert_equal(raw.sound_config_set_range(lib, cfg, 0, RANGE_END), MA_SUCCESS)
    assert_equal(raw.sound_config_set_initial_seek_point(lib, cfg, 300), MA_SUCCESS)
    var seeked = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, seeked, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_get_cursor_in_pcm_frames(lib, seeked).value, UInt64(300))

    raw.sound_free(lib, seeked)
    raw.sound_free(lib, tail)
    raw.sound_free(lib, snd)
    raw.sound_free(lib, full)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_loop_point_and_looping_flag() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    assert_equal(raw.sound_config_set_flags(lib, cfg, FLAG_LOOPING), MA_SUCCESS)
    assert_equal(raw.sound_config_set_loop_point(lib, cfg, 200, 800), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_is_looping(lib, snd), 1)

    # Without the flag the same config does not loop.
    assert_equal(raw.sound_config_set_flags(lib, cfg, 0), MA_SUCCESS)
    var once = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, once, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_is_looping(lib, once), 0)

    raw.sound_free(lib, once)
    raw.sound_free(lib, snd)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_data_source_can_be_set_replaced_and_cleared() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var rate = eraw.engine_get_sample_rate(lib, eng)
    var ds = _constant_source(lib, 320, rate)

    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, ds), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(320))

    # The same source, played through a config, comes out of the engine.
    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)
    var got = _pull(lib, eng)
    assert_equal(len(got), 2 * PERIOD)
    assert_true(_peak(got) > Float32(0.2))

    # Cleared: the config describes a source-less (group-like) sound again.
    assert_equal(raw.sound_config_set_data_source(lib, cfg, null_handle()), MA_SUCCESS)
    var bare = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, bare, eng, cfg), MA_SUCCESS)
    assert_true(raw.sound_get_length_in_pcm_frames(lib, bare).result != MA_SUCCESS)

    # A source that is not there is refused, and the config keeps what it had.
    assert_equal(dsraw.data_source_uninit(lib, ds), MA_SUCCESS)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, ds), MA_INVALID_ARGS)

    raw.sound_free(lib, bare)
    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, ds)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_file_path_can_be_replaced_and_cleared() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, "./build/test_assets/nope.wav"), MA_SUCCESS)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)

    # A path that does not exist fails the init instead of building a sound.
    assert_equal(
        raw.sound_config_set_file_path(lib, cfg, "./build/test_assets/nope.wav"),
        MA_SUCCESS,
    )
    var missing = raw.sound_alloc(lib)
    assert_true(raw.sound_init_ex(lib, missing, eng, cfg) != MA_SUCCESS)
    assert_equal(raw.sound_start(lib, missing), MA_INVALID_ARGS)

    # Cleared: no file, no source.
    assert_equal(raw.sound_config_clear_file_path(lib, cfg), MA_SUCCESS)
    var bare = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, bare, eng, cfg), MA_SUCCESS)
    assert_true(raw.sound_get_length_in_pcm_frames(lib, bare).result != MA_SUCCESS)

    raw.sound_free(lib, bare)
    raw.sound_free(lib, missing)
    raw.sound_free(lib, snd)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_tuning_knobs_are_accepted_by_init_ex() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_SUCCESS)
    # A bus wider than miniaudio supports is an error here, not an abort there;
    # "follow the data source" (all ones) is a legal output width.
    assert_equal(raw.sound_config_set_channels(lib, cfg, 4096, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_channels(lib, cfg, 0, 4096), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_channels(lib, cfg, 0, 0xFFFFFFFF), MA_SUCCESS)
    assert_equal(raw.sound_config_set_channels(lib, cfg, 0, 2), MA_SUCCESS)
    assert_equal(raw.sound_config_set_volume_smooth_time(lib, cfg, 64), MA_SUCCESS)
    assert_equal(raw.sound_config_set_mono_expansion_mode(lib, cfg, 1), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)
    assert_true(_peak(_pull(lib, eng)) > Float32(0))
    assert_true(raw.sound_get_engine(lib, snd) == eng)

    raw.sound_free(lib, snd)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_attached_to_a_group_is_heard_through_the_group() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var rate = eraw.engine_get_sample_rate(lib, eng)
    var group = graw.sound_group_alloc(lib)
    assert_equal(graw.sound_group_init(lib, group, eng, 0), MA_SUCCESS)

    var ds = _constant_source(lib, 2000, rate)
    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, ds), MA_SUCCESS)
    assert_equal(raw.sound_config_set_flags(lib, cfg, FLAG_NO_PITCH_NO_SPATIAL), MA_SUCCESS)
    assert_equal(raw.sound_config_set_initial_attachment_group(lib, cfg, group, 0), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)

    # Through the group at full volume the source comes out. (A group resamples,
    # which costs it one frame of latency, so look past the first frame.)
    var open = _pull(lib, eng)
    assert_equal(open[2], LEFT)
    assert_equal(open[3], RIGHT)
    assert_equal(open[2 * PERIOD - 2], LEFT)

    # The group is the only route to the endpoint, so its volume is the sound's.
    assert_equal(graw.sound_group_set_volume(lib, group, 0.0), MA_SUCCESS)
    var shut = _pull(lib, eng)
    assert_equal(_peak(shut), Float32(0))

    # Clearing the attachment puts a sound on the endpoint directly.
    assert_equal(raw.sound_config_set_initial_attachment_group(lib, cfg, null_handle(), 0), MA_SUCCESS)
    var direct = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, direct, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_start(lib, direct), MA_SUCCESS)
    assert_equal(raw.sound_stop(lib, snd), MA_SUCCESS)
    assert_true(_peak(_pull(lib, eng)) > Float32(0.2))

    raw.sound_free(lib, direct)
    raw.sound_free(lib, snd)
    graw.sound_group_free(lib, group)
    dsraw.data_source_free(lib, ds)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_config_attached_to_a_node_is_heard_through_the_node() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var rate = eraw.engine_get_sample_rate(lib, eng)

    # A pass-through engine node between the sound and the endpoint.
    var node = nraw.engine_node_alloc(lib)
    assert_equal(
        nraw.engine_node_init(lib, node, eng, FLAG_NO_PITCH_NO_SPATIAL, 0, 0, 0, 0),
        MA_SUCCESS,
    )
    var graph = nraw.node_graph_alloc(lib)
    assert_equal(nraw.node_graph_borrow_engine(lib, graph, eng), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, node, 0, graph, 0), MA_SUCCESS)

    var ds = _constant_source(lib, 2000, rate)
    var cfg = _config(lib)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, ds), MA_SUCCESS)
    assert_equal(raw.sound_config_set_flags(lib, cfg, FLAG_NO_PITCH_NO_SPATIAL), MA_SUCCESS)
    assert_equal(raw.sound_config_set_initial_attachment_node(lib, cfg, node, 0), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)

    var through = _pull(lib, eng)
    assert_equal(through[2], LEFT)
    assert_equal(through[3], RIGHT)

    # The node's output bus volume is the dial on that route.
    assert_equal(nraw.node_set_output_bus_volume(lib, node, 0, 0.0), MA_SUCCESS)
    assert_equal(_peak(_pull(lib, eng)), Float32(0))

    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, ds)
    raw.sound_config_free(lib, cfg)
    nraw.node_graph_free(lib, graph)
    nraw.engine_node_free(lib, node)
    eraw.engine_free(lib, eng)


def test_config_attachment_to_something_that_is_not_there_is_refused() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = _config(lib)
    var group = graw.sound_group_alloc(lib)       # never initialised
    var node = nraw.engine_node_alloc(lib)        # never initialised

    assert_equal(
        raw.sound_config_set_initial_attachment_group(lib, cfg, group, 0), MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_config_set_initial_attachment_node(lib, cfg, node, 0), MA_INVALID_ARGS
    )

    graw.sound_group_free(lib, group)
    nraw.engine_node_free(lib, node)
    raw.sound_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def _expect_config_rejected(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    snd: OpaquePointer[MutUntrackedOrigin],
    ds: OpaquePointer[MutUntrackedOrigin],
    cfg: OpaquePointer[MutUntrackedOrigin],
) raises:
    """Every config call that needs a ready config says INVALID_ARGS to `cfg`."""
    assert_equal(raw.sound_config_set_file_path(lib, cfg, WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_clear_file_path(lib, cfg), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_data_source(lib, cfg, ds), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_config_set_initial_attachment_group(lib, cfg, null_handle(), 0),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.sound_config_set_initial_attachment_node(lib, cfg, null_handle(), 0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.sound_config_set_flags(lib, cfg, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_channels(lib, cfg, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_volume_smooth_time(lib, cfg, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_mono_expansion_mode(lib, cfg, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_initial_seek_point(lib, cfg, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_range(lib, cfg, 0, RANGE_END), MA_INVALID_ARGS)
    assert_equal(raw.sound_config_set_loop_point(lib, cfg, 0, RANGE_END), MA_INVALID_ARGS)
    assert_equal(raw.sound_init_ex(lib, snd, eng, cfg), MA_INVALID_ARGS)


def test_config_setters_and_init_ex_reject_missing_or_unready_handles() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var blank = raw.sound_config_alloc(lib)       # allocated, never initialised
    var snd = raw.sound_alloc(lib)
    var ds = _constant_source(lib, 8, eraw.engine_get_sample_rate(lib, eng))

    _expect_config_rejected(lib, eng, snd, ds, null_handle())
    _expect_config_rejected(lib, eng, snd, ds, blank)

    var good = _config(lib)
    assert_equal(raw.sound_init_ex(lib, null_handle(), eng, good), MA_INVALID_ARGS)
    assert_equal(raw.sound_init_ex(lib, snd, null_handle(), good), MA_INVALID_ARGS)
    raw.sound_config_free(lib, null_handle())

    raw.sound_config_free(lib, good)
    dsraw.data_source_free(lib, ds)
    raw.sound_free(lib, snd)
    raw.sound_config_free(lib, blank)
    eraw.engine_free(lib, eng)


def test_an_initialised_buffer_source_handle_can_become_a_view() raises:
    """Borrowing re-purposes a handle that already owned a buffer source."""
    var lib = _lib()
    var eng = _engine(lib)
    var own = _constant_source(lib, 32, eraw.engine_get_sample_rate(lib, eng))
    var ds = _constant_source(lib, 64, eraw.engine_get_sample_rate(lib, eng))
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_data_source(lib, snd, eng, ds, 0), MA_SUCCESS)

    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, own).value, UInt64(32))
    assert_equal(dsraw.data_source_borrow_sound(lib, own, snd), MA_SUCCESS)
    assert_equal(dsraw.data_source_get_length_in_pcm_frames(lib, own).value, UInt64(64))
    assert_true(dsraw.data_source_is_same(lib, own, ds).value)

    raw.sound_free(lib, snd)
    dsraw.data_source_free(lib, own)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
