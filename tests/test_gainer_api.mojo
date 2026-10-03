"""TDD tests for the idiomatic Gainer API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.effect import Gainer


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ones(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(1))
    return buf^


def test_default_gain_is_unity() raises:
    var g = Gainer.create(_lib(), channels=2, smooth_time_in_frames=8)
    var out = g.process(_ones(16))
    for i in range(len(out)):
        assert_equal(out[i], Float32(1.0))
    assert_equal(g.master_volume(), Float32(1.0))


def test_master_volume_scales_output() raises:
    var g = Gainer.create(_lib(), channels=1, smooth_time_in_frames=8, preallocated=True)
    g.set_master_volume(0.5)
    assert_equal(g.master_volume(), Float32(0.5))
    var out = g.process(_ones(8))
    assert_equal(out[7], Float32(0.5))


def test_smoothed_change_reaches_target() raises:
    var g = Gainer.create(_lib(), channels=2, smooth_time_in_frames=16)
    g.set_gain(1.0)
    g.set_gain(0.0)
    _ = g.process(_ones(64))  # ramp block (upstream lerp quirk)
    var out = g.process(_ones(64))
    for i in range(len(out)):
        assert_equal(out[i], Float32(0.0))


def test_per_channel_gains() raises:
    var g = Gainer.create(_lib(), channels=2, smooth_time_in_frames=4)
    var gains: List[Float32] = [Float32(0.0), Float32(2.0)]
    g.set_gains(gains)
    var out = g.process(_ones(8))
    assert_equal(out[6], Float32(0.0))
    assert_equal(out[7], Float32(2.0))


def test_heap_size_and_bad_config() raises:
    assert_true(Gainer.heap_size(_lib(), 4, 32) > UInt64(0))
    with assert_raises():
        _ = Gainer.create(_lib(), channels=0)
    var g = Gainer.create(_lib(), channels=2)
    var wrong: List[Float32] = [Float32(1.0), Float32(1.0), Float32(1.0)]
    with assert_raises():
        g.set_gains(wrong)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
