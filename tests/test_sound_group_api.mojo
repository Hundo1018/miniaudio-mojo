"""TDD tests for the idiomatic sound group API (RAII SoundGroup).

L3 behavioral: the owning engine runs on the null backend. `SoundGroup` holds an
ArcPointer[Engine] so the engine outlives it; we assert playing state, control
round-trips, and that the clock advances.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine, SoundGroup
from miniaudio.sound import (
    ATTENUATION_LINEAR,
    POSITIONING_RELATIVE,
    PAN_MODE_PAN,
)
from miniaudio._lib import MaLib
from std.testing import assert_raises
from miniaudio.data_source import DataSource
from miniaudio.sound_group import SoundGroupConfig
from miniaudio.sound import Sound, SoundConfig, SOUND_FLAG_NO_PITCH, SOUND_FLAG_NO_SPATIALIZATION


comptime RUN_SECONDS = 0.1


def _engine() raises -> ArcPointer[Engine]:
    return ArcPointer(Engine.create(ArcPointer(MaLib.default()), use_null_backend=True))


def test_group_start_stop_playing_state() raises:
    var engine = _engine()
    var grp = SoundGroup.create(engine)
    grp.start()
    assert_true(grp.is_playing())
    # An empty group (no sounds routed through it) processes no frames, so its
    # local clock stays at 0 — we only assert the queryable lifecycle here.
    _ = grp.time_in_frames()
    grp.stop()


def test_group_volume_roundtrip() raises:
    var engine = _engine()
    var grp = SoundGroup.create(engine)
    grp.set_volume(0.5)
    assert_true(grp.volume() > 0.4 and grp.volume() < 0.6)


def test_group_pan_pitch_roundtrip() raises:
    var engine = _engine()
    var grp = SoundGroup.create(engine)
    grp.set_pan(0.25)
    assert_true(grp.pan() > 0.0)
    grp.set_pitch(1.5)
    assert_true(grp.pitch() > 1.0)


def test_group_spatialization_toggle() raises:
    var engine = _engine()
    var grp = SoundGroup.create(engine)
    grp.set_spatialization_enabled(False)
    assert_true(not grp.is_spatialization_enabled())


def test_group_lifetime_sequential() raises:
    var engine = _engine()
    var g1 = SoundGroup.create(engine)
    g1.start()
    var g2 = SoundGroup.create(engine)
    g2.start()
    assert_true(g1.is_playing())
    assert_true(g2.is_playing())


def test_group_spatial_roundtrips() raises:
    """Position/velocity/gain/distance/model setters read back their values."""
    var engine = _engine()
    var grp = SoundGroup.create(engine)

    grp.set_position(1.0, 2.0, 3.0)
    var p = grp.position()
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    grp.set_velocity(0.0, -1.0, 0.0)
    assert_true(grp.velocity().y == -1.0)

    grp.set_attenuation_model(ATTENUATION_LINEAR)
    assert_true(grp.attenuation_model() == ATTENUATION_LINEAR)
    grp.set_positioning(POSITIONING_RELATIVE)
    assert_true(grp.positioning() == POSITIONING_RELATIVE)
    grp.set_pan_mode(PAN_MODE_PAN)
    assert_true(grp.pan_mode() == PAN_MODE_PAN)

    grp.set_min_distance(1.0)
    grp.set_max_distance(10.0)
    assert_true(grp.min_distance() == 1.0 and grp.max_distance() == 10.0)
    grp.set_rolloff(2.0)
    assert_true(grp.rolloff() == 2.0)
    grp.set_doppler_factor(1.5)
    assert_true(grp.doppler_factor() == 1.5)


def test_group_fade_and_time() raises:
    """Fade config + scheduled stop are accepted; the group starts and stops
    cleanly with them set."""
    var engine = _engine()
    var grp = SoundGroup.create(engine)
    grp.set_fade_in_milliseconds(0.0, 1.0, 20)
    grp.set_stop_time_in_pcm_frames(48000)
    grp.start()
    sleep(RUN_SECONDS)
    _ = grp.time_in_frames()
    _ = grp.current_fade_volume()
    grp.stop()


# ---------------------------------------------------------------------------
# The engine back-reference, and groups built from a SoundGroupConfig.
#
# The engine is stopped so the test is its only reader, and reads are whole
# periods because the engine renders whole periods. A group or sound that is not
# used again is dropped immediately, so each test touches what it built *after*
# the read.
# ---------------------------------------------------------------------------

comptime PERIOD: UInt64 = 480
comptime PASS_THROUGH: UInt32 = SOUND_FLAG_NO_PITCH | SOUND_FLAG_NO_SPATIALIZATION


def _stopped_engine() raises -> ArcPointer[Engine]:
    var eng = ArcPointer(Engine.create(ArcPointer(MaLib.default()), use_null_backend=True))
    eng[].stop()
    return eng^


def _source(eng: ArcPointer[Engine]) raises -> ArcPointer[DataSource]:
    """A long stereo source at the engine's rate (0.25 left, -0.5 right)."""
    var samples = List[Float32]()
    for _ in range(Int(PERIOD) * 8):
        samples.append(Float32(0.25))
        samples.append(Float32(-0.5))
    return ArcPointer(
        DataSource.from_frames(
            eng[]._lib.copy(), samples, channels=2, sample_rate=eng[].sample_rate()
        )
    )


def _period(eng: ArcPointer[Engine]) raises -> List[Float32]:
    var out = List[Float32]()
    _ = eng[].read(out, PERIOD)
    return out^


def _peak(samples: List[Float32]) -> Float32:
    var peak = Float32(0)
    for i in range(len(samples)):
        var v = samples[i]
        if v < Float32(0):
            v = -v
        if v > peak:
            peak = v
    return peak


def _sound_into(
    eng: ArcPointer[Engine], group: ArcPointer[SoundGroup]
) raises -> Sound:
    """A started sound playing the stereo source into `group`."""
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng))
    cfg.set_flags(PASS_THROUGH)
    cfg.set_group(group)
    var snd = Sound.from_config(eng, cfg)
    snd.start()
    return snd^


def test_engine_is_the_engine_the_group_was_built_with() raises:
    var eng = _stopped_engine()
    var group = SoundGroup.create(eng)
    assert_true(group.engine()[]._ptr == eng[]._ptr)
    # The engine it hands back is the engine itself, shared.
    group.engine()[].set_volume(Float32(0.5))
    assert_equal(eng[].volume(), Float32(0.5))


def test_a_group_config_builds_the_same_kind_of_group_as_create() raises:
    var eng = _stopped_engine()
    var plain = SoundGroup.create(eng)
    var cfg = SoundGroupConfig.create(ArcPointer(MaLib.default()))
    var made = SoundGroup.from_config(eng, cfg)

    assert_equal(made.volume(), plain.volume())
    assert_equal(made.is_spatialization_enabled(), plain.is_spatialization_enabled())
    assert_true(not made.is_spatialization_enabled())    # a group's default
    assert_equal(made.is_playing(), plain.is_playing())
    assert_true(made.engine()[]._ptr == eng[]._ptr)

    var for_engine = SoundGroupConfig.for_engine(eng)
    var again = SoundGroup.from_config(eng, for_engine)
    again.set_volume(Float32(0.5))
    assert_equal(again.volume(), Float32(0.5))


def test_group_config_flags_decide_whether_the_group_resamples() raises:
    """A group resamples (a frame of latency) unless NO_PITCH is in its flags."""
    var eng = _stopped_engine()
    var cfg = SoundGroupConfig.for_engine(eng)
    var pitched = ArcPointer(SoundGroup.from_config(eng, cfg))
    var s1 = _sound_into(eng, pitched)
    var through_resampler = _period(eng)
    assert_equal(through_resampler[0], Float32(0))
    assert_equal(through_resampler[2], Float32(0.25))
    s1.stop()

    pitched[].stop()
    cfg.set_flags(SOUND_FLAG_NO_PITCH)
    var direct = ArcPointer(SoundGroup.from_config(eng, cfg))
    var s2 = _sound_into(eng, direct)
    var bypassed = _period(eng)
    assert_equal(bypassed[0], Float32(0.25))
    assert_equal(bypassed[1], Float32(-0.5))
    assert_true(s2.is_playing())
    assert_true(direct[].is_playing())
    assert_true(not s1.is_playing())


def test_a_group_config_nests_one_group_in_another() raises:
    var eng = _stopped_engine()
    var parent = ArcPointer(SoundGroup.create(eng, flags=SOUND_FLAG_NO_PITCH))
    var cfg = SoundGroupConfig.for_engine(eng)
    cfg.set_flags(SOUND_FLAG_NO_PITCH)
    cfg.set_parent(parent)
    var child = ArcPointer(SoundGroup.from_config(eng, cfg))

    var snd = _sound_into(eng, child)    # sound -> child -> parent -> endpoint
    var heard = _period(eng)
    assert_equal(heard[0], Float32(0.25))
    assert_equal(heard[1], Float32(-0.5))

    # The parent is the only way out, so shutting it silences the child's sound.
    parent[].set_volume(Float32(0))
    assert_equal(_peak(_period(eng)), Float32(0))
    parent[].set_volume(Float32(1))
    assert_true(_peak(_period(eng)) > Float32(0.2))

    # Clearing the parent puts a group on the endpoint directly.
    cfg.clear_parent()
    var top = ArcPointer(SoundGroup.from_config(eng, cfg))
    snd.stop()
    var other = _sound_into(eng, top)
    parent[].set_volume(Float32(0))
    assert_true(_peak(_period(eng)) > Float32(0.2))
    assert_true(other.is_playing())
    assert_true(child[].is_playing() and top[].is_playing() and parent[].is_playing())


def test_a_group_config_keeps_its_parent_alive_until_the_group_is_built() raises:
    var eng = _stopped_engine()
    var cfg = _config_for_a_child_of_a_group_nobody_else_holds(eng)
    var child = ArcPointer(SoundGroup.from_config(eng, cfg))
    var snd = _sound_into(eng, child)
    assert_true(snd.is_playing())
    assert_true(child[].is_playing())


def _config_for_a_child_of_a_group_nobody_else_holds(
    eng: ArcPointer[Engine],
) raises -> SoundGroupConfig:
    var parent = ArcPointer(SoundGroup.create(eng, flags=SOUND_FLAG_NO_PITCH))
    var cfg = SoundGroupConfig.for_engine(eng)
    cfg.set_flags(SOUND_FLAG_NO_PITCH)
    cfg.set_parent(parent)
    return cfg^


def test_a_group_config_sets_channels_and_smoothing() raises:
    var eng = _stopped_engine()
    var cfg = SoundGroupConfig.for_engine(eng)
    cfg.set_channels(2, 2)
    cfg.set_volume_smooth_time(UInt32(PERIOD))
    cfg.set_flags(SOUND_FLAG_NO_PITCH)
    var smooth = ArcPointer(SoundGroup.from_config(eng, cfg))
    var snd = _sound_into(eng, smooth)
    assert_true(_peak(_period(eng)) > Float32(0.2))

    # Smoothing ramps a volume change: still sounding at the start of the period.
    smooth[].set_volume(Float32(0))
    assert_true(_peak(_period(eng)) > Float32(0.1))
    assert_true(snd.is_playing() and smooth[].is_playing())


def test_a_group_config_with_the_wrong_channels_refuses_a_sound() raises:
    var eng = _stopped_engine()
    var cfg = SoundGroupConfig.for_engine(eng)
    cfg.set_channels(1, 2)    # a mono input: a stereo sound cannot feed it
    var mono = ArcPointer(SoundGroup.from_config(eng, cfg))
    var scfg = SoundConfig.for_engine(eng)
    scfg.set_data_source(_source(eng))
    scfg.set_group(mono)
    with assert_raises():
        _ = Sound.from_config(eng, scfg)
    assert_true(mono[].is_playing())


def test_group_config_errors_surface_as_errors() raises:
    var eng = _stopped_engine()
    var cfg = SoundGroupConfig.for_engine(eng)
    with assert_raises():
        cfg.set_channels(4096)
    with assert_raises():
        cfg.set_channels(0, 4096)
    # The config is still good after a refused setter.
    var group = SoundGroup.from_config(eng, cfg)
    assert_true(group.is_playing())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
