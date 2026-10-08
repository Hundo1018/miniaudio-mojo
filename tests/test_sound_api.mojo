"""TDD tests for the idiomatic sound API (RAII Sound).

L3 behavioral: the owning engine runs on the null backend. `Sound` holds an
ArcPointer[Engine] so the engine outlives the sound; we assert playback state,
length/cursor queries, and control round-trips.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine, Sound
from miniaudio.sound import (
    ATTENUATION_LINEAR,
    POSITIONING_RELATIVE,
    PAN_MODE_PAN,
)
from miniaudio._lib import MaLib
from std.testing import assert_raises
from miniaudio.data_source import DataSource, DataSourceNode
from miniaudio.sound_group import SoundGroup
from miniaudio.node import EngineNode, NodeGraph
from miniaudio.sound import SoundConfig, SOUND_FLAG_LOOPING, SOUND_FLAG_NO_PITCH, SOUND_FLAG_NO_SPATIALIZATION


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.1


def _engine() raises -> ArcPointer[Engine]:
    return ArcPointer(Engine.create(ArcPointer(MaLib.default()), use_null_backend=True))


def test_sound_plays_and_reports_length() raises:
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    assert_true(snd.length_in_frames() > 0)
    snd.start()
    assert_true(snd.is_playing())
    sleep(RUN_SECONDS)
    snd.stop()


def test_sound_volume_roundtrip() raises:
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    snd.set_volume(0.5)
    assert_true(snd.volume() > 0.4 and snd.volume() < 0.6)


def test_sound_looping_toggle() raises:
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    snd.set_looping(True)
    assert_true(snd.is_looping())
    snd.set_looping(False)
    assert_true(not snd.is_looping())


def test_sound_seek_to_zero() raises:
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    snd.seek(0)
    assert_equal(snd.cursor(), UInt64(0))


def test_sound_lifetime_sequential() raises:
    """Behavioral: a sound tears down (while its engine stays alive via the
    ArcPointer); a second sound on the same engine still works."""
    var engine = _engine()
    var s1 = Sound.from_file(engine, WAV_PATH)
    assert_true(s1.length_in_frames() > 0)
    var s2 = Sound.from_file(engine, WAV_PATH)
    assert_true(s2.length_in_frames() > 0)


def test_sound_seconds_queries_agree_with_frames() raises:
    """Length in seconds ≈ length_in_frames / sample_rate (invariant)."""
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    var fmt = snd.data_format()
    assert_true(fmt.channels > 0 and fmt.sample_rate > 0)
    var len_frames = snd.length_in_frames()
    var len_seconds = snd.length_in_seconds()
    var expected = Float32(len_frames) / Float32(fmt.sample_rate)
    # within one frame's worth of tolerance
    var diff = len_seconds - expected
    if diff < 0.0:
        diff = -diff
    assert_true(diff < 0.01)
    snd.seek_to_second(0.0)
    assert_true(snd.cursor_in_seconds() >= 0.0)


def test_sound_spatial_roundtrips() raises:
    """Position/velocity/gain/distance/model setters read back their values."""
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)

    snd.set_position(1.0, 2.0, 3.0)
    var p = snd.position()
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    snd.set_velocity(0.0, -1.0, 0.0)
    assert_true(snd.velocity().y == -1.0)

    snd.set_attenuation_model(ATTENUATION_LINEAR)
    assert_true(snd.attenuation_model() == ATTENUATION_LINEAR)
    snd.set_positioning(POSITIONING_RELATIVE)
    assert_true(snd.positioning() == POSITIONING_RELATIVE)
    snd.set_pan_mode(PAN_MODE_PAN)
    assert_true(snd.pan_mode() == PAN_MODE_PAN)

    snd.set_min_distance(1.0)
    snd.set_max_distance(10.0)
    assert_true(snd.min_distance() == 1.0 and snd.max_distance() == 10.0)
    snd.set_rolloff(2.0)
    assert_true(snd.rolloff() == 2.0)
    snd.set_doppler_factor(1.5)
    assert_true(snd.doppler_factor() == 1.5)


def test_sound_fade_and_time() raises:
    """Fade config + scheduled stop are accepted; the clock advances on play."""
    var engine = _engine()
    var snd = Sound.from_file(engine, WAV_PATH)
    snd.set_fade_in_milliseconds(0.0, 1.0, 20)
    snd.set_stop_time_in_pcm_frames(snd.length_in_frames())
    snd.start()
    sleep(RUN_SECONDS)
    # time_in_frames reflects the sound's own clock; must be readable
    _ = snd.time_in_frames()
    snd.stop_with_fade_in_milliseconds(5)
    snd.reset_fade()
    snd.reset_stop_time_and_fade()


def test_sound_copy_of_shares_length() raises:
    """Copy_of yields an independent Sound with the same length as its source."""
    var engine = _engine()
    var src = Sound.from_file(engine, WAV_PATH)
    var dup = Sound.copy_of(src)
    assert_equal(dup.length_in_frames(), src.length_in_frames())


# ---------------------------------------------------------------------------
# Sounds from a data source and from a config; the engine back-reference; the
# borrowed view of a sound's data source.
#
# The engine is stopped so the test is its only reader, and reads are whole
# periods because the engine renders whole periods. A sound (or group, or node)
# that is not used again is dropped immediately and so stops sounding: every test
# here touches what it built *after* the read.
# ---------------------------------------------------------------------------

comptime PERIOD: UInt64 = 480
comptime PASS_THROUGH: UInt32 = SOUND_FLAG_NO_PITCH | SOUND_FLAG_NO_SPATIALIZATION
comptime LEFT: Float32 = 0.25
comptime RIGHT: Float32 = -0.5


def _stopped_engine() raises -> ArcPointer[Engine]:
    var eng = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    eng[].stop()
    return eng^


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _source(eng: ArcPointer[Engine], periods: Int = 4) raises -> ArcPointer[DataSource]:
    """A stereo source at the engine's rate: LEFT on the left, RIGHT on the right."""
    var samples = List[Float32]()
    for _ in range(Int(PERIOD) * periods):
        samples.append(LEFT)
        samples.append(RIGHT)
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


def _is_the_source(samples: List[Float32], skip: Int = 0) -> Bool:
    """Every frame (past the first `skip`) is LEFT, RIGHT."""
    if len(samples) < 2 * (skip + 1):
        return False
    for i in range(skip, len(samples) // 2):
        if samples[2 * i] != LEFT or samples[2 * i + 1] != RIGHT:
            return False
    return True


# ---- Sound.from_data_source ----


def test_a_sound_from_a_data_source_plays_the_sources_frames() raises:
    var eng = _stopped_engine()
    var src = _source(eng)
    var snd = Sound.from_data_source(eng, src, flags=PASS_THROUGH)
    assert_equal(snd.length_in_frames(), PERIOD * 4)
    snd.start()

    var out = _period(eng)
    assert_equal(len(out), Int(PERIOD) * 2)
    assert_true(_is_the_source(out))
    assert_true(snd.is_playing())


def test_a_sound_keeps_its_data_source_alive() raises:
    var eng = _stopped_engine()
    var snd = _sound_over_a_source_nobody_else_holds(eng)
    snd.start()
    assert_true(_is_the_source(_period(eng)))
    assert_true(snd.is_playing())


def _sound_over_a_source_nobody_else_holds(eng: ArcPointer[Engine]) raises -> Sound:
    var src = _source(eng)
    return Sound.from_data_source(eng, src, flags=PASS_THROUGH)


def test_sounds_over_separate_sources_mix() raises:
    var eng = _stopped_engine()
    var a = Sound.from_data_source(eng, _source(eng), flags=PASS_THROUGH)
    var b = Sound.from_data_source(eng, _source(eng), flags=PASS_THROUGH)
    a.start()
    b.start()
    var out = _period(eng)    # both play: the sum
    assert_equal(out[0], LEFT + LEFT)
    assert_equal(out[1], RIGHT + RIGHT)
    assert_true(a.is_playing() and b.is_playing())


# ---- Sound.engine ----


def test_engine_is_the_engine_the_sound_was_built_with() raises:
    var eng = _stopped_engine()
    var from_file = Sound.from_file(eng, WAV_PATH)
    var from_source = Sound.from_data_source(eng, _source(eng))
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path(WAV_PATH)
    var from_config = Sound.from_config(eng, cfg)

    assert_true(from_file.engine()[]._ptr == eng[]._ptr)
    assert_true(from_source.engine()[]._ptr == eng[]._ptr)
    assert_true(from_config.engine()[]._ptr == eng[]._ptr)
    # It is the engine itself, shared: using it affects the one engine.
    from_file.engine()[].set_volume(Float32(0.5))
    assert_equal(eng[].volume(), Float32(0.5))


# ---- Sound.data_source ----


def test_the_data_source_view_is_the_source_the_sound_was_given() raises:
    var eng = _stopped_engine()
    var src = _source(eng)
    var snd = Sound.from_data_source(eng, src)
    var view = snd.data_source()

    assert_true(view.is_same(src[]))
    assert_equal(view.length_frames(), PERIOD * 4)
    var fmt = view.data_format()
    assert_equal(fmt.channels, UInt32(2))
    assert_equal(fmt.sample_rate, eng[].sample_rate())
    # A source that is not the sound's is not the same.
    var stranger = _source(eng)
    assert_true(not view.is_same(stranger[]))
    assert_true(snd.is_playing() == False)


def test_acting_on_the_view_acts_on_the_sound() raises:
    var eng = _stopped_engine()
    var snd = Sound.from_data_source(eng, _source(eng))
    var view = snd.data_source()

    view.set_range(10, 110)
    assert_equal(snd.length_in_frames(), UInt64(100))
    assert_equal(view.length_frames(), UInt64(100))
    view.set_looping(True)
    assert_true(view.is_looping())
    var loop = view.range()
    assert_equal(loop.beg, UInt64(10))
    assert_equal(loop.end, UInt64(110))

    # Dropping the view (its last use was just above) takes nothing with it.
    assert_equal(snd.length_in_frames(), UInt64(100))


def test_a_view_of_a_file_sound_describes_the_file() raises:
    var eng = _stopped_engine()
    var snd = Sound.from_file(eng, WAV_PATH)
    var view = snd.data_source()
    assert_equal(view.length_frames(), snd.length_in_frames())
    assert_equal(view.data_format().channels, snd.data_format().channels)
    assert_equal(view.data_format().sample_rate, snd.data_format().sample_rate)


def test_a_view_fails_cleanly_once_its_sound_is_gone() raises:
    var eng = _stopped_engine()
    var view = _view_of_a_dropped_sound(eng)
    with assert_raises():
        _ = view.length_frames()
    with assert_raises():
        _ = view.data_format()
    # And dropping the orphaned view is safe (it holds nothing but a shell).


def _view_of_a_dropped_sound(eng: ArcPointer[Engine]) raises -> DataSource:
    var snd = Sound.from_data_source(eng, _source(eng))
    return snd.data_source()


def test_a_view_cannot_be_kept_by_anything_else() raises:
    var eng = _stopped_engine()
    var snd = Sound.from_data_source(eng, _source(eng))
    var view = snd.data_source()
    var other = _source(eng)

    with assert_raises():
        other[].set_current(view)
    with assert_raises():
        other[].set_next(view)
    with assert_raises():
        other[].set_next_callback(view)
    with assert_raises():
        view.set_next_callback(other[])
    with assert_raises():
        _ = DataSourceNode.create(eng, ArcPointer(view^))
    var again = snd.data_source()
    with assert_raises():
        _ = Sound.from_data_source(eng, ArcPointer(again^))
    # Asking about chains is fine.
    var plain = snd.data_source()
    assert_true(plain.current_is_self())
    assert_true(not snd.is_playing())    # `snd` has to outlive the views of it


def test_a_sound_with_no_data_source_has_no_view() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.create(_lib())    # no file, no source: a group-like sound
    var bare = Sound.from_config(eng, cfg)
    with assert_raises():
        _ = bare.data_source()
    with assert_raises():
        _ = bare.length_in_frames()
    assert_true(bare.engine()[]._ptr == eng[]._ptr)


# ---- SoundConfig ----


def test_a_config_with_a_file_path_builds_the_sound_from_file_would() raises:
    var eng = _stopped_engine()
    var plain = Sound.from_file(eng, WAV_PATH)

    var cfg = SoundConfig.create(_lib())
    cfg.set_file_path(WAV_PATH)
    var made = Sound.from_config(eng, cfg)
    var for_engine = SoundConfig.for_engine(eng)
    for_engine.set_file_path(WAV_PATH)
    var made2 = Sound.from_config(eng, for_engine)

    assert_equal(made.length_in_frames(), plain.length_in_frames())
    assert_equal(made2.length_in_frames(), plain.length_in_frames())
    assert_equal(made.data_format().channels, plain.data_format().channels)


def test_a_config_range_narrows_the_sound_and_a_seek_point_moves_its_start() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path(WAV_PATH)
    cfg.set_range(100, 1100)
    var ranged = Sound.from_config(eng, cfg)
    assert_equal(ranged.length_in_frames(), UInt64(1000))

    var seek = SoundConfig.for_engine(eng)
    seek.set_file_path(WAV_PATH)
    seek.set_initial_seek_point(300)
    var started_late = Sound.from_config(eng, seek)
    assert_equal(started_late.cursor(), UInt64(300))
    assert_true(ranged.length_in_frames() > UInt64(0))


def test_a_config_can_ask_for_looping() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path(WAV_PATH)
    var once = Sound.from_config(eng, cfg)
    cfg.set_flags(SOUND_FLAG_LOOPING)
    cfg.set_loop_point(200, 800)
    var looping = Sound.from_config(eng, cfg)

    assert_true(not once.is_looping())
    assert_true(looping.is_looping())


def test_a_config_can_play_a_data_source_that_only_it_holds() raises:
    var eng = _stopped_engine()
    var cfg = _config_over_a_source_nobody_else_holds(eng)
    var snd = Sound.from_config(eng, cfg)
    snd.start()
    assert_true(_is_the_source(_period(eng)))
    assert_true(snd.is_playing())


def _config_over_a_source_nobody_else_holds(eng: ArcPointer[Engine]) raises -> SoundConfig:
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng))
    cfg.set_flags(PASS_THROUGH)
    return cfg^


def test_a_sound_built_from_a_config_outlives_the_config_and_keeps_its_source() raises:
    var eng = _stopped_engine()
    var snd = _sound_from_a_throwaway_config(eng)
    snd.start()
    assert_true(_is_the_source(_period(eng)))
    assert_true(snd.is_playing())


def _sound_from_a_throwaway_config(eng: ArcPointer[Engine]) raises -> Sound:
    var cfg = _config_over_a_source_nobody_else_holds(eng)
    return Sound.from_config(eng, cfg)


def test_a_config_routes_a_sound_through_a_group() raises:
    var eng = _stopped_engine()
    var group = ArcPointer(SoundGroup.create(eng, flags=SOUND_FLAG_NO_PITCH))
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng, 8))
    cfg.set_flags(PASS_THROUGH)
    cfg.set_group(group)
    var snd = Sound.from_config(eng, cfg)
    snd.start()

    assert_true(_is_the_source(_period(eng)))
    # The group is the sound's only way out, so its volume is the sound's.
    group[].set_volume(Float32(0))
    assert_equal(_peak(_period(eng)), Float32(0))
    group[].set_volume(Float32(1))
    assert_true(_peak(_period(eng)) > Float32(0.2))
    assert_true(snd.is_playing())
    assert_true(group[].is_playing())    # a dropped group detaches its sounds


def test_a_config_routes_a_sound_through_an_engine_node() raises:
    var eng = _stopped_engine()
    var node = ArcPointer(EngineNode.create(eng, flags=PASS_THROUGH))
    node[].attach_to_endpoint()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng, 8))
    cfg.set_flags(PASS_THROUGH)
    cfg.set_engine_node(node)
    var snd = Sound.from_config(eng, cfg)
    snd.start()

    assert_true(_is_the_source(_period(eng)))
    node[].set_volume(Float32(0))
    assert_equal(_peak(_period(eng)), Float32(0))
    assert_true(snd.is_playing())
    assert_true(node[].belongs_to(ArcPointer(NodeGraph.of_engine(eng))))


def test_clearing_the_attachment_puts_the_sound_back_on_the_endpoint() raises:
    var eng = _stopped_engine()
    var group = ArcPointer(SoundGroup.create(eng, flags=SOUND_FLAG_NO_PITCH))
    group[].set_volume(Float32(0))
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng, 8))
    cfg.set_flags(PASS_THROUGH)
    cfg.set_group(group)
    var behind_the_group = Sound.from_config(eng, cfg)
    behind_the_group.start()
    assert_equal(_peak(_period(eng)), Float32(0))

    behind_the_group.stop()
    cfg.clear_attachment()
    var direct = Sound.from_config(eng, cfg)
    direct.start()
    assert_true(_peak(_period(eng)) > Float32(0.2))
    assert_true(direct.is_playing())
    assert_true(group[].is_playing())


def test_a_sound_keeps_the_group_it_feeds_alive() raises:
    """The group is held by the config, then by the sound built from it."""
    var eng = _stopped_engine()
    var cfg = _config_for_a_sound_in_a_group_nobody_else_holds(eng)
    var snd = Sound.from_config(eng, cfg)    # the config dies right here
    snd.start()
    assert_true(_peak(_period(eng)) > Float32(0.2))
    assert_true(snd.is_playing())


def _config_for_a_sound_in_a_group_nobody_else_holds(eng: ArcPointer[Engine]) raises -> SoundConfig:
    var group = ArcPointer(SoundGroup.create(eng, flags=SOUND_FLAG_NO_PITCH))
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_data_source(_source(eng, 8))
    cfg.set_flags(PASS_THROUGH)
    cfg.set_group(group)
    return cfg^


def test_a_config_without_a_file_or_source_builds_a_group_like_sound() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path(WAV_PATH)
    cfg.clear_file_path()
    cfg.set_data_source(_source(eng))
    cfg.clear_data_source()
    var bare = Sound.from_config(eng, cfg)
    with assert_raises():
        _ = bare.length_in_frames()
    bare.set_volume(Float32(0.5))
    assert_equal(bare.volume(), Float32(0.5))


def test_the_remaining_config_knobs_are_accepted() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path(WAV_PATH)
    cfg.set_channels(0, 2)
    cfg.set_volume_smooth_time(64)
    cfg.set_mono_expansion_mode(1)
    var snd = Sound.from_config(eng, cfg)
    snd.start()
    assert_true(_peak(_period(eng)) > Float32(0))
    assert_true(snd.is_playing())


def test_config_errors_surface_as_errors() raises:
    var eng = _stopped_engine()
    var cfg = SoundConfig.for_engine(eng)
    cfg.set_file_path("./build/test_assets/does-not-exist.wav")
    with assert_raises():
        _ = Sound.from_config(eng, cfg)
    with assert_raises():
        cfg.set_channels(4096)
    with assert_raises():
        cfg.set_channels(0, 4096)

    # A view cannot be set as a config's source.
    var snd = Sound.from_data_source(eng, _source(eng))
    var view = snd.data_source()
    with assert_raises():
        cfg.set_data_source(ArcPointer(view^))

    # A node that has been uninitialised cannot be attached to.
    var node = ArcPointer(EngineNode.create(eng))
    node[].uninit()
    with assert_raises():
        cfg.set_engine_node(node)
    assert_true(snd.engine()[]._ptr == eng[]._ptr)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
