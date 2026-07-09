"""TDD tests for the idiomatic engine API (RAII Engine).

L3 behavioral: every engine runs on the null backend (deterministic, no audio
hardware). We assert observable streaming progress (the engine clock advances),
volume round-trips, and RAII lifetime cleans up safely.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine
from miniaudio._lib import MaLib


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _play_briefly(lib: ArcPointer[MaLib]) raises -> UInt64:
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    return eng.time_in_frames()


def test_engine_plays_and_clock_advances() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    assert_true(eng.sample_rate() > 0)
    assert_true(eng.channels() > 0)
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_volume_roundtrip() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.set_volume(0.5)
    assert_true(eng.volume() > 0.4 and eng.volume() < 0.6)


def test_engine_start_stop() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.stop()
    eng.start()  # restartable
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_lifetime_sequential() raises:
    """Behavioral: an engine fully tears down; a fresh one still works."""
    var lib = _lib()
    var t1 = _play_briefly(lib)
    var t2 = _play_briefly(lib)
    assert_true(t1 > 0)
    assert_true(t2 > 0)


def test_engine_play_sound_ex() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound_ex(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_clock_set_get() raises:
    """Stop freezes the clock; set/get round-trips exactly (offline)."""
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.stop()
    eng.set_time_in_frames(4800)
    assert_equal(eng.time_in_frames(), UInt64(4800))
    assert_true(eng.time_in_milliseconds() > 0)
    eng.set_time_in_milliseconds(50)
    assert_true(eng.time_in_frames() > 0)


def test_engine_read_offline() raises:
    """A playing sound feeds the graph; manual read pulls it (device stopped)."""
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound(WAV_PATH)
    eng.stop()  # single reader
    var buf = List[Float32]()
    var read = eng.read(buf, UInt64(128))
    assert_true(read > UInt64(0))
    assert_equal(len(buf), Int(read) * Int(eng.channels()))


def test_engine_listener_spatialization() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    assert_true(eng.listener_count() >= UInt32(1))

    eng.set_listener_position(0, 1.0, 2.0, 3.0)
    var p = eng.listener_position(0)
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    eng.set_listener_direction(0, 0.0, 0.0, -1.0)
    assert_true(eng.listener_direction(0).z == -1.0)

    eng.set_listener_cone(0, 0.5, 1.0, 0.25)
    var cone = eng.listener_cone(0)
    assert_true(cone.inner_angle == 0.5 and cone.outer_gain == 0.25)

    eng.set_listener_enabled(0, False)
    assert_true(not eng.listener_is_enabled(0))
    eng.set_listener_enabled(0, True)
    assert_true(eng.listener_is_enabled(0))

    assert_true(eng.find_closest_listener(1.0, 0.0, 0.0) < eng.listener_count())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
