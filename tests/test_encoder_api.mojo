"""TDD tests for the idiomatic encoder API layer (RAII Encoder).

L3 behavioral: encode a WAV with `Encoder`, then read it back with the
already-migrated `Decoder` and assert the round-trip preserves channels,
sample rate, and frame count.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import Encoder, Decoder, ENCODING_FORMAT_WAV
from miniaudio._lib import MaLib


comptime ROUNDTRIP_PATH = "./build/test_assets/encoder_api_roundtrip.wav"
comptime MONO_PATH = "./build/test_assets/encoder_api_mono.wav"
comptime BAD_PATH = "/tmp/mmj-no-such-dir-xyz/encoder_api.wav"


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _silence(frames: Int, channels: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(frames * channels, Float32(0))
    return buf^


def _write_wav(
    lib: ArcPointer[MaLib],
    path: String,
    channels: UInt32,
    sample_rate: UInt32,
    frames: Int,
) raises -> UInt64:
    """Encode `frames` of silence to `path`. The Encoder is destroyed on return,
    which finalises (flushes) the WAV file before any reader opens it."""
    var enc = Encoder.to_file(lib, path, channels=channels, sample_rate=sample_rate)
    return enc.write(_silence(frames, Int(channels)))


def test_round_trip_stereo_via_decoder() raises:
    var lib = _lib()
    var written = _write_wav(lib, ROUNDTRIP_PATH, 2, 8000, 100)
    assert_equal(written, UInt64(100))

    var dec = Decoder.from_file(lib, ROUNDTRIP_PATH)
    assert_equal(dec.channels(), UInt32(2))
    assert_equal(dec.sample_rate(), UInt32(8000))
    assert_equal(dec.length_in_frames(), UInt64(100))


def test_round_trip_mono_via_decoder() raises:
    var lib = _lib()
    var written = _write_wav(lib, MONO_PATH, 1, 44100, 50)
    assert_equal(written, UInt64(50))

    var dec = Decoder.from_file(lib, MONO_PATH)
    assert_equal(dec.channels(), UInt32(1))
    assert_equal(dec.sample_rate(), UInt32(44100))
    assert_equal(dec.length_in_frames(), UInt64(50))


def test_default_encoding_format_is_wav() raises:
    var lib = _lib()
    var enc = Encoder.to_file(lib, ROUNDTRIP_PATH, channels=2, sample_rate=8000)
    assert_equal(enc.channels(), UInt32(2))
    assert_true(ENCODING_FORMAT_WAV.code == 1)


def test_to_file_bad_dir_raises() raises:
    var lib = _lib()
    with assert_raises():
        var enc = Encoder.to_file(lib, BAD_PATH, channels=2, sample_rate=8000)
        _ = enc.write(_silence(1, 2))


def test_write_decodes_back_to_same_samples() raises:
    """Behavioral: frames written equals frames read back (round-trip invariant)."""
    var lib = _lib()
    var written = _write_wav(lib, ROUNDTRIP_PATH, 2, 8000, 256)
    assert_equal(written, UInt64(256))

    var dec = Decoder.from_file(lib, ROUNDTRIP_PATH)
    var buf = List[Float32]()
    var read = dec.read(buf, 256)
    assert_equal(read, UInt64(256))
    assert_equal(len(buf), 256 * 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
