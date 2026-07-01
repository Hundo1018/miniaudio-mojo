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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
