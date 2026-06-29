"""TDD tests for the idiomatic waveform API (RAII Waveform).

L3 behavioral: verifies that the Waveform struct generates audible PCM,
that amplitude / frequency / type / sample_rate round-trip, and that
re-reads after a seek restart from the beginning.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer
from std.math import abs

from miniaudio import MaLib
from miniaudio.waveform import Waveform, WaveformTypeSine, WaveformTypeSquare


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_sine_generates_nonzero_audio() raises:
    """Sine wave with amplitude 1.0 must produce non-silent output."""
    var wf = Waveform.create(_lib(), waveform_type=WaveformTypeSine, amplitude=1.0, frequency=440.0)
    var frames = wf.read_frames(UInt64(512))
    assert_true(len(frames) == 512)
    var found_nonzero = False
    for i in range(len(frames)):
        if frames[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)


def test_zero_amplitude_is_silent() raises:
    """Amplitude 0.0 must produce all-zero samples."""
    var wf = Waveform.create(_lib(), waveform_type=WaveformTypeSine, amplitude=0.0, frequency=440.0)
    var frames = wf.read_frames(UInt64(256))
    for i in range(len(frames)):
        assert_equal(frames[i], Float32(0))


def test_seek_restarts_from_beginning() raises:
    """Two reads from frame 0 after a seek must produce identical samples."""
    var wf = Waveform.create(_lib(), waveform_type=WaveformTypeSine, amplitude=1.0, frequency=440.0)
    var first = wf.read_frames(UInt64(64))
    wf.seek_to_frame(UInt64(0))
    var second = wf.read_frames(UInt64(64))
    assert_equal(len(first), len(second))
    for i in range(len(first)):
        assert_equal(first[i], second[i])


def test_set_amplitude_changes_output() raises:
    """After lowering amplitude the output peak should be smaller."""
    var wf = Waveform.create(_lib(), waveform_type=WaveformTypeSine, amplitude=1.0, frequency=440.0)
    var loud = wf.read_frames(UInt64(512))
    wf.seek_to_frame(UInt64(0))
    wf.set_amplitude(0.1)
    var quiet = wf.read_frames(UInt64(512))
    var loud_max = Float32(0)
    var quiet_max = Float32(0)
    for i in range(len(loud)):
        if abs(loud[i]) > loud_max:
            loud_max = abs(loud[i])
    for i in range(len(quiet)):
        if abs(quiet[i]) > quiet_max:
            quiet_max = abs(quiet[i])
    assert_true(quiet_max < loud_max)


def test_set_type_and_frequency() raises:
    """set_type and set_frequency must succeed and not crash on subsequent read."""
    var wf = Waveform.create(_lib(), waveform_type=WaveformTypeSine)
    wf.set_type(WaveformTypeSquare)
    wf.set_frequency(880.0)
    var frames = wf.read_frames(UInt64(256))
    assert_true(len(frames) == 256)


def test_set_sample_rate() raises:
    """set_sample_rate must succeed and reads must still work."""
    var wf = Waveform.create(_lib(), channels=1, sample_rate=44100)
    wf.set_sample_rate(48000)
    var frames = wf.read_frames(UInt64(128))
    assert_true(len(frames) == 128)


def test_stereo_channels() raises:
    """2-channel waveform read of N frames yields 2*N f32 samples."""
    var wf = Waveform.create(_lib(), channels=2, sample_rate=44100, amplitude=1.0)
    var frames = wf.read_frames(UInt64(100))
    assert_true(len(frames) == 200)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
