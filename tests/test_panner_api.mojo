"""TDD tests for the idiomatic Panner API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.effect import Panner, PanModeBalance, PanModePan


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ones(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(1))
    return buf^


def test_center_is_passthrough() raises:
    var p = Panner.create(_lib())
    var out = p.process(_ones(8))
    for i in range(len(out)):
        assert_equal(out[i], Float32(1.0))


def test_balance_left_attenuates_right() raises:
    var p = Panner.create(_lib(), pan=-1.0)
    var out = p.process(_ones(4))
    assert_equal(out[0], Float32(1.0))
    assert_equal(out[1], Float32(0.0))


def test_mode_switch_changes_output() raises:
    var p = Panner.create(_lib(), mode=PanModeBalance, pan=-1.0)
    p.set_mode(PanModePan)
    assert_equal(p.mode(), PanModePan)
    var out = p.process(_ones(2))
    assert_equal(out[0], Float32(2.0))  # right folded into left
    assert_equal(out[1], Float32(0.0))


def test_mono_unaffected_by_pan() raises:
    var p = Panner.create(_lib(), channels=1, pan=1.0)
    var out = p.process(_ones(4))
    for i in range(len(out)):
        assert_equal(out[i], Float32(1.0))


def test_set_pan_round_trip_and_bad_mode() raises:
    var p = Panner.create(_lib())
    p.set_pan(0.25)
    assert_equal(p.pan(), Float32(0.25))
    with assert_raises():
        p.set_mode(9)
    with assert_raises():
        _ = Panner.create(_lib(), mode=5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
