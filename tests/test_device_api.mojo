"""TDD tests for the idiomatic playback device API (RAII Device).

L3 behavioral: every device runs on the null backend (deterministic, no audio
hardware). We assert observable streaming progress (frames_processed) and that
the device's RAII lifetime (which owns the source Decoder) cleans up safely.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Device, Decoder
from miniaudio._lib import MaLib


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _play_briefly(lib: ArcPointer[MaLib], var source: Decoder) raises -> UInt64:
    """Open a null-backend device over `source`, run it briefly, return frames."""
    var dev = Device.play(lib, source^, use_null_backend=True)
    dev.start()
    sleep(RUN_SECONDS)
    dev.stop()
    return dev.frames_processed()


def test_play_streams_frames() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)
    assert_equal(dev.channels(), UInt32(2))
    assert_equal(dev.sample_rate(), UInt32(48000))

    dev.start()
    sleep(RUN_SECONDS)
    dev.stop()
    assert_true(dev.frames_processed() > 0)


def test_sample_rate_override() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, sample_rate=22050, use_null_backend=True)
    assert_equal(dev.sample_rate(), UInt32(22050))


def test_device_owns_decoder_and_cleans_up() raises:
    """Behavioral: the device owns the decoder; playing then dropping is safe,
    and a second device can be created afterwards."""
    var lib = _lib()
    var frames1 = _play_briefly(lib, Decoder.from_file(lib, WAV_PATH))
    assert_true(frames1 > 0)
    # First device fully torn down (its __del__ joined the audio thread); a
    # fresh device over a new decoder still works.
    var frames2 = _play_briefly(lib, Decoder.from_file(lib, WAV_PATH))
    assert_true(frames2 > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
