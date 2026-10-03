"""TDD tests for the idiomatic Fader API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.effect import Fader


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ones(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(1))
    return buf^


def test_fade_out_is_monotonic_and_ends_silent() raises:
    var f = Fader.create(_lib(), channels=2, sample_rate=48000)
    f.set_fade(1.0, 0.0, 64)
    var out = f.process(_ones(2 * 80))
    for i in range(1, 80):
        assert_true(out[2 * i] <= out[2 * (i - 1)])
        assert_equal(out[2 * i], out[2 * i + 1])  # both channels identical
    assert_equal(out[2 * 79], Float32(0.0))
    assert_equal(f.current_volume(), Float32(0.0))


def test_fade_continues_across_calls() raises:
    var f = Fader.create(_lib(), channels=1, sample_rate=48000)
    f.set_fade(0.0, 1.0, 8)
    _ = f.process(_ones(4))
    assert_equal(f.current_volume(), Float32(0.5))
    var out = f.process(_ones(4))
    assert_equal(out[0], Float32(0.5))


def test_negative_begin_uses_current_volume() raises:
    var f = Fader.create(_lib(), channels=1, sample_rate=48000)
    f.set_fade(0.0, 1.0, 4)
    _ = f.process(_ones(2))  # current volume now 0.5
    f.set_fade(-1.0, 0.0, 4)
    assert_equal(f.current_volume(), Float32(0.5))


def test_delayed_fade() raises:
    var f = Fader.create(_lib(), channels=1, sample_rate=48000)
    f.set_fade(1.0, 0.0, 1, start_offset_in_frames=3)
    var out = f.process(_ones(5))
    assert_equal(out[2], Float32(1.0))
    assert_equal(out[4], Float32(0.0))


def test_data_format_accessors() raises:
    var f = Fader.create(_lib(), channels=2, sample_rate=22050)
    assert_equal(f.channels(), UInt32(2))
    assert_equal(f.sample_rate(), UInt32(22050))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
