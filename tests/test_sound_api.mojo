"""TDD tests for the idiomatic sound API (RAII Sound).

L3 behavioral: the owning engine runs on the null backend. `Sound` holds an
ArcPointer[Engine] so the engine outlives the sound; we assert playback state,
length/cursor queries, and control round-trips.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine, Sound
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
