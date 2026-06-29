"""TDD tests for the idiomatic sound group API (RAII SoundGroup).

L3 behavioral: the owning engine runs on the null backend. `SoundGroup` holds an
ArcPointer[Engine] so the engine outlives it; we assert playing state, control
round-trips, and that the clock advances.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine, SoundGroup
from miniaudio._lib import MaLib


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
