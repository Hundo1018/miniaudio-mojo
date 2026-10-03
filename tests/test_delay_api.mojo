"""TDD tests for the idiomatic Delay API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.effect import Delay


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_stereo_delay_shifts_both_channels() raises:
    var d = Delay.create(_lib(), channels=2, sample_rate=48000, delay_in_frames=3)
    var src = List[Float32]()
    src.resize(12, Float32(0))
    src[0] = 1.0   # left impulse, frame 0
    src[1] = -1.0  # right impulse, frame 0
    var out = d.process(src)
    assert_equal(len(out), 12)
    assert_equal(out[6], Float32(1.0))
    assert_equal(out[7], Float32(-1.0))
    assert_equal(out[0], Float32(0.0))


def test_state_carries_across_calls() raises:
    """The delay line persists between process() calls."""
    var d = Delay.create(_lib(), channels=1, sample_rate=48000, delay_in_frames=4)
    var first = List[Float32]()
    first.resize(2, Float32(0))
    first[0] = 1.0
    _ = d.process(first)
    var silence = List[Float32]()
    silence.resize(4, Float32(0))
    var out = d.process(silence)
    assert_equal(out[2], Float32(1.0))  # absolute frame 4


def test_params_round_trip() raises:
    var d = Delay.create(_lib(), channels=1, sample_rate=48000, delay_in_frames=8, decay=0.5)
    assert_equal(d.decay(), Float32(0.5))
    d.set_wet(0.25)
    d.set_dry(0.5)
    d.set_decay(0.75)
    assert_equal(d.wet(), Float32(0.25))
    assert_equal(d.dry(), Float32(0.5))
    assert_equal(d.decay(), Float32(0.75))


def test_invalid_decay_raises() raises:
    with assert_raises():
        _ = Delay.create(_lib(), channels=1, sample_rate=48000, delay_in_frames=8, decay=2.0)


def test_zero_length_raises() raises:
    with assert_raises():
        _ = Delay.create(_lib(), channels=1, sample_rate=48000, delay_in_frames=0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
