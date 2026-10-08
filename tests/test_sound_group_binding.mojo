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
import miniaudio._ffi.sound_raw as sraw
import miniaudio._ffi.data_source_raw as dsraw


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


# ---------------------------------------------------------------------------
# the engine back-reference, ma_sound_group_config behind a handle, init_ex
# ---------------------------------------------------------------------------

comptime PERIOD: Int = 480  # frames the engine renders per pass (10 ms at 48 kHz)
comptime FLAG_NO_PITCH: UInt32 = 0x2000
comptime LEFT: Float32 = 0.25
comptime RIGHT: Float32 = -0.5


def _engine(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A null-backend engine with its device stopped, so the test is the only reader."""
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(eraw.engine_stop(lib, eng), MA_SUCCESS)
    return eng


def _pull(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) raises -> List[Float32]:
    """One engine period of stereo frames. The engine renders whole periods, so a
    setting changed between two pulls is heard in the second."""
    var buf = List[Float32]()
    buf.resize(PERIOD * 2, Float32(0))
    var rc = eraw.engine_read_pcm_frames(lib, eng, buf, UInt64(PERIOD))
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


def _playing_sound(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    ds: OpaquePointer[MutUntrackedOrigin],
    group: OpaquePointer[MutUntrackedOrigin],
) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A started sound, playing `ds` into `group` (pitch and spatialization off)."""
    var cfg = sraw.sound_config_alloc(lib)
    assert_equal(sraw.sound_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(sraw.sound_config_set_data_source(lib, cfg, ds), MA_SUCCESS)
    assert_equal(sraw.sound_config_set_flags(lib, cfg, 0x2000 | 0x4000), MA_SUCCESS)
    assert_equal(
        sraw.sound_config_set_initial_attachment_group(lib, cfg, group, 0), MA_SUCCESS
    )
    var snd = sraw.sound_alloc(lib)
    assert_equal(sraw.sound_init_ex(lib, snd, eng, cfg), MA_SUCCESS)
    sraw.sound_config_free(lib, cfg)
    assert_equal(sraw.sound_start(lib, snd), MA_SUCCESS)
    return snd


def _source(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A long stereo buffer source: LEFT on the left channel, RIGHT on the right."""
    var samples = List[Float32]()
    for _ in range(PERIOD * 8):
        samples.append(LEFT)
        samples.append(RIGHT)
    var ds = dsraw.data_source_alloc(lib)
    assert_equal(
        dsraw.data_source_init_buffer(
            lib, ds, samples, UInt64(PERIOD * 8), 2, eraw.engine_get_sample_rate(lib, eng)
        ),
        MA_SUCCESS,
    )
    return ds


def test_get_engine_is_the_engine_the_group_was_built_with() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var other = _engine(lib)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, grp, eng, 0), MA_SUCCESS)

    assert_true(raw.sound_group_get_engine(lib, grp) == eng)
    assert_true(raw.sound_group_get_engine(lib, grp) != other)

    # Not initialised / not there: nothing to report.
    assert_equal(raw.sound_group_uninit(lib, grp), MA_SUCCESS)
    assert_true(raw.sound_group_get_engine(lib, grp) == null_handle())
    assert_true(raw.sound_group_get_engine(lib, null_handle()) == null_handle())

    raw.sound_group_free(lib, grp)
    eraw.engine_free(lib, other)
    eraw.engine_free(lib, eng)


def test_group_config_builds_the_same_kind_of_group_as_init() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var plain = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, plain, eng, 0), MA_SUCCESS)

    var cfg = raw.sound_group_config_alloc(lib)
    assert_true(cfg != null_handle())
    assert_equal(raw.sound_group_config_init(lib, cfg), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, grp, eng, cfg), MA_SUCCESS)

    # Same defaults: full volume, playing, and (a group's default) not spatialised.
    assert_equal(raw.sound_group_get_volume(lib, grp), raw.sound_group_get_volume(lib, plain))
    assert_equal(
        raw.sound_group_is_spatialization_enabled(lib, grp),
        raw.sound_group_is_spatialization_enabled(lib, plain),
    )
    assert_equal(raw.sound_group_is_spatialization_enabled(lib, grp), 0)
    assert_equal(raw.sound_group_is_playing(lib, grp), raw.sound_group_is_playing(lib, plain))
    assert_true(raw.sound_group_get_engine(lib, grp) == eng)

    raw.sound_group_free(lib, grp)
    raw.sound_group_free(lib, plain)
    raw.sound_group_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_group_config_for_engine_is_a_working_starting_point() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var cfg = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init_for_engine(lib, cfg, eng), MA_SUCCESS)
    var grp = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, grp, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_set_volume(lib, grp, 0.5), MA_SUCCESS)
    assert_equal(raw.sound_group_get_volume(lib, grp), Float32(0.5))

    raw.sound_group_free(lib, grp)
    raw.sound_group_config_free(lib, cfg)
    eraw.engine_free(lib, eng)


def test_group_config_flags_change_what_the_group_does() raises:
    """A group resamples (a frame of latency) unless NO_PITCH is in its flags."""
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _source(lib, eng)

    var cfg = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init(lib, cfg), MA_SUCCESS)
    var pitched = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, pitched, eng, cfg), MA_SUCCESS)
    var s1 = _playing_sound(lib, eng, ds, pitched)
    var through_resampler = _pull(lib, eng)
    assert_equal(through_resampler[0], Float32(0))      # the resampler's latency
    assert_equal(through_resampler[2], LEFT)
    assert_equal(sraw.sound_stop(lib, s1), MA_SUCCESS)
    sraw.sound_free(lib, s1)

    assert_equal(raw.sound_group_config_set_flags(lib, cfg, FLAG_NO_PITCH), MA_SUCCESS)
    var direct = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, direct, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_stop(lib, pitched), MA_SUCCESS)
    var s2 = _playing_sound(lib, eng, ds, direct)
    var bypassed = _pull(lib, eng)
    assert_equal(bypassed[0], LEFT)
    assert_equal(bypassed[1], RIGHT)
    assert_equal(sraw.sound_get_engine(lib, s2) == eng, True)

    sraw.sound_free(lib, s2)
    raw.sound_group_free(lib, direct)
    raw.sound_group_free(lib, pitched)
    raw.sound_group_config_free(lib, cfg)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_group_config_parent_nests_one_group_inside_another() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _source(lib, eng)

    var parent = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init(lib, parent, eng, FLAG_NO_PITCH), MA_SUCCESS)
    var cfg = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_config_set_flags(lib, cfg, FLAG_NO_PITCH), MA_SUCCESS)
    assert_equal(raw.sound_group_config_set_parent(lib, cfg, parent, 0), MA_SUCCESS)
    var child = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, child, eng, cfg), MA_SUCCESS)

    # sound -> child -> parent -> endpoint
    var snd = _playing_sound(lib, eng, ds, child)
    var heard = _pull(lib, eng)
    assert_equal(heard[0], LEFT)
    assert_equal(heard[1], RIGHT)

    # The parent is the only way out, so shutting it silences the child's sound.
    assert_equal(raw.sound_group_set_volume(lib, parent, 0.0), MA_SUCCESS)
    assert_equal(_peak(_pull(lib, eng)), Float32(0))

    # Clearing the parent puts a group on the endpoint directly.
    assert_equal(raw.sound_group_config_set_parent(lib, cfg, null_handle(), 0), MA_SUCCESS)
    var top = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, top, eng, cfg), MA_SUCCESS)
    assert_equal(sraw.sound_stop(lib, snd), MA_SUCCESS)
    var snd2 = _playing_sound(lib, eng, ds, top)
    assert_true(_peak(_pull(lib, eng)) > Float32(0.2))

    sraw.sound_free(lib, snd2)
    sraw.sound_free(lib, snd)
    raw.sound_group_free(lib, top)
    raw.sound_group_free(lib, child)
    raw.sound_group_free(lib, parent)
    raw.sound_group_config_free(lib, cfg)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_group_config_channels_decide_what_can_be_attached() raises:
    """A group's input channel count has to match what is fed into it."""
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _source(lib, eng)    # stereo

    var cfg = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_config_set_channels(lib, cfg, 2, 2), MA_SUCCESS)
    var stereo = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, stereo, eng, cfg), MA_SUCCESS)
    var ok = _playing_sound(lib, eng, ds, stereo)
    assert_true(_peak(_pull(lib, eng)) > Float32(0.2))

    assert_equal(raw.sound_group_config_set_channels(lib, cfg, 1, 2), MA_SUCCESS)
    var mono = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, mono, eng, cfg), MA_SUCCESS)
    # A stereo sound cannot feed a mono input.
    var scfg = sraw.sound_config_alloc(lib)
    assert_equal(sraw.sound_config_init(lib, scfg), MA_SUCCESS)
    assert_equal(sraw.sound_config_set_data_source(lib, scfg, ds), MA_SUCCESS)
    assert_equal(sraw.sound_config_set_initial_attachment_group(lib, scfg, mono, 0), MA_SUCCESS)
    var bad = sraw.sound_alloc(lib)
    assert_true(sraw.sound_init_ex(lib, bad, eng, scfg) != MA_SUCCESS)

    sraw.sound_config_free(lib, scfg)
    sraw.sound_free(lib, bad)
    sraw.sound_free(lib, ok)
    raw.sound_group_free(lib, mono)
    raw.sound_group_free(lib, stereo)
    raw.sound_group_config_free(lib, cfg)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_group_config_volume_smoothing_ramps_a_volume_change() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var ds = _source(lib, eng)

    var cfg = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init(lib, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_config_set_flags(lib, cfg, FLAG_NO_PITCH), MA_SUCCESS)
    var abrupt = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, abrupt, eng, cfg), MA_SUCCESS)
    assert_equal(raw.sound_group_config_set_volume_smooth_time(lib, cfg, UInt32(PERIOD)), MA_SUCCESS)
    var smooth = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_init_ex(lib, smooth, eng, cfg), MA_SUCCESS)

    # Warm up, then cut the volume to zero.
    var s1 = _playing_sound(lib, eng, ds, abrupt)
    assert_true(_peak(_pull(lib, eng)) > Float32(0.2))
    assert_equal(raw.sound_group_set_volume(lib, abrupt, 0.0), MA_SUCCESS)
    assert_equal(_peak(_pull(lib, eng)), Float32(0))
    assert_equal(sraw.sound_stop(lib, s1), MA_SUCCESS)

    var ds2 = _source(lib, eng)
    var s2 = _playing_sound(lib, eng, ds2, smooth)
    assert_true(_peak(_pull(lib, eng)) > Float32(0.2))
    assert_equal(raw.sound_group_set_volume(lib, smooth, 0.0), MA_SUCCESS)
    # Smoothed: still sounding at the start of the period it was cut in.
    var ramp = _pull(lib, eng)
    assert_true(_peak(ramp) > Float32(0.1))

    sraw.sound_free(lib, s2)
    sraw.sound_free(lib, s1)
    raw.sound_group_free(lib, smooth)
    raw.sound_group_free(lib, abrupt)
    raw.sound_group_config_free(lib, cfg)
    dsraw.data_source_free(lib, ds2)
    dsraw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_group_config_negative_paths() raises:
    var lib = _lib()
    var eng = _engine(lib)
    var blank = raw.sound_group_config_alloc(lib)   # never initialised
    var grp = raw.sound_group_alloc(lib)

    assert_equal(raw.sound_group_config_init(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_group_config_init_for_engine(lib, blank, null_handle()), MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_group_config_init_for_engine(lib, null_handle(), eng), MA_INVALID_ARGS
    )

    # Unready configs reject every setter and init_ex.
    assert_equal(raw.sound_group_config_set_flags(lib, blank, 0), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_group_config_set_parent(lib, blank, null_handle(), 0), MA_INVALID_ARGS
    )
    assert_equal(raw.sound_group_config_set_channels(lib, blank, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_config_set_volume_smooth_time(lib, blank, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_init_ex(lib, grp, eng, blank), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_config_set_flags(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_group_config_set_parent(lib, null_handle(), null_handle(), 0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.sound_group_config_set_channels(lib, null_handle(), 0, 0), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_group_config_set_volume_smooth_time(lib, null_handle(), 0), MA_INVALID_ARGS
    )

    var good = raw.sound_group_config_alloc(lib)
    assert_equal(raw.sound_group_config_init(lib, good), MA_SUCCESS)
    # A bus wider than miniaudio supports is an error here, not an abort there.
    assert_equal(raw.sound_group_config_set_channels(lib, good, 4096, 0), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_config_set_channels(lib, good, 0, 4096), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_init_ex(lib, null_handle(), eng, good), MA_INVALID_ARGS)
    assert_equal(raw.sound_group_init_ex(lib, grp, null_handle(), good), MA_INVALID_ARGS)
    # A parent that was never initialised is not a parent.
    var parent = raw.sound_group_alloc(lib)
    assert_equal(raw.sound_group_config_set_parent(lib, good, parent, 0), MA_INVALID_ARGS)
    # A failed init leaves the group uninitialised.
    assert_equal(raw.sound_group_start(lib, grp), MA_INVALID_ARGS)

    raw.sound_group_config_free(lib, null_handle())
    raw.sound_group_free(lib, parent)
    raw.sound_group_config_free(lib, good)
    raw.sound_group_free(lib, grp)
    raw.sound_group_config_free(lib, blank)
    eraw.engine_free(lib, eng)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
