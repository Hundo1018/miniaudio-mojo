"""TDD tests for the idiomatic PulseWave API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.waveform import PulseWave


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _high(buf: List[Float32]) -> Int:
    var n = 0
    for i in range(len(buf)):
        if buf[i] > Float32(0):
            n += 1
    return n


def test_symmetric_square_by_default() raises:
    var pw = PulseWave.create(_lib(), frequency=441.0)
    var out = pw.read_frames(UInt64(1000))
    var high = _high(out)
    assert_true(high >= 490 and high <= 510)


def test_duty_cycle_change() raises:
    var pw = PulseWave.create(_lib(), duty_cycle=0.5, frequency=441.0)
    pw.set_duty_cycle(0.1)
    pw.seek_to_frame(UInt64(0))
    var high = _high(pw.read_frames(UInt64(1000)))
    assert_true(high >= 90 and high <= 110)


def test_seek_restarts() raises:
    var pw = PulseWave.create(_lib(), duty_cycle=0.3, frequency=300.0)
    var a = pw.read_frames(UInt64(128))
    pw.seek_to_frame(UInt64(0))
    var b = pw.read_frames(UInt64(128))
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_amplitude_frequency_sample_rate() raises:
    var pw = PulseWave.create(_lib(), channels=2, frequency=441.0)
    pw.set_amplitude(0.25)
    pw.set_frequency(882.0)
    pw.set_sample_rate(44100)
    var out = pw.read_frames(UInt64(100))
    assert_equal(len(out), 200)
    for i in range(len(out)):
        assert_true(out[i] == Float32(0.25) or out[i] == Float32(-0.25))
    assert_equal(out[0], out[1])  # channels identical


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
