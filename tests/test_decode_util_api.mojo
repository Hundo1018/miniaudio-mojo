"""TDD tests for the idiomatic one-shot decode API (RAII DecodedAudio, L3 behavioural).

`decode_file` / `decode_memory` / `decode_from_vfs` must agree with each other
and with the format-specific WavDecoder / FlacDecoder / Mp3Decoder paths, and
the decoded buffer (allocated by miniaudio) must be released by DecodedAudio.
Fixtures: the WAV from `pixi run gen-test-wav` (48 kHz) and the committed
FLAC / MP3 files (tests/fixtures/README.md).
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.decode_util import (
    DecodedAudio,
    DecodingBackendConfig,
    decode_file,
    decode_memory,
    decode_from_vfs,
    decode_from_default_vfs,
    decoding_backend_config,
)
from miniaudio.decoder import (
    SampleFormat,
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_F32,
)
from miniaudio.context import Vfs
from miniaudio.wav import WavDecoder
from miniaudio.flac import FlacDecoder
from miniaudio.mp3 import Mp3Decoder
from support.codec_fixtures import (
    WAV_PATH,
    FLAC_PATH,
    MP3_PATH,
    MISSING_PATH,
    WAV_FRAMES,
    WAV_RATE,
    CODEC_FRAMES,
    CODEC_RATE,
    read_file_bytes,
    garbage_bytes,
    channel_rms,
    rising_crossings,
    max_abs_diff,
    sine16,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _resident_pages() raises -> Int:
    var text: String
    with open("/proc/self/statm", "r") as f:
        text = f.read()
    var fields = text.split(" ")
    return Int(fields[1])


def test_wav_decode_matches_wav_decoder() raises:
    var lib = _lib()
    var d = decode_file(lib, WAV_PATH)
    assert_equal(d.frame_count, UInt64(WAV_FRAMES))
    assert_equal(d.channels, UInt32(2))
    assert_equal(d.sample_rate, UInt32(WAV_RATE))
    assert_true(d.format == SAMPLE_FORMAT_F32)
    assert_equal(d.sample_count(), 2 * WAV_FRAMES)
    var got = d.samples_f32()
    var w = WavDecoder.from_file(lib, WAV_PATH)
    var want = List[Float32]()
    assert_equal(w.read(want, UInt64(WAV_FRAMES)), UInt64(WAV_FRAMES))
    assert_equal(max_abs_diff(got, want), Float32(0))
    # And it is the 440 Hz sine the generator wrote: RMS 0.1414, 439 rising crossings.
    var rms = channel_rms(got, 2, 0)
    assert_true(rms > 0.140 and rms < 0.143)
    var crossings = rising_crossings(got, 2, 0)
    assert_true(crossings >= 438 and crossings <= 441)


def test_flac_decode_matches_flac_decoder() raises:
    var lib = _lib()
    var d = decode_file(lib, FLAC_PATH)
    assert_equal(d.frame_count, UInt64(CODEC_FRAMES))
    assert_equal(d.channels, UInt32(2))
    assert_equal(d.sample_rate, UInt32(CODEC_RATE))
    var got = d.samples_f32()
    var f = FlacDecoder.from_file(lib, FLAC_PATH)
    var want = List[Float32]()
    assert_equal(f.read(want, UInt64(CODEC_FRAMES)), UInt64(CODEC_FRAMES))
    assert_equal(max_abs_diff(got, want), Float32(0))


def test_mp3_decode_matches_mp3_decoder() raises:
    var lib = _lib()
    var d = decode_file(lib, MP3_PATH)
    # Gapless: the LAME tag in the fixture trims delay and padding.
    assert_equal(d.frame_count, UInt64(CODEC_FRAMES))
    assert_equal(d.channels, UInt32(2))
    assert_equal(d.sample_rate, UInt32(CODEC_RATE))
    var got = d.samples_f32()
    var m = Mp3Decoder.from_file(lib, MP3_PATH)
    var want = List[Float32]()
    assert_equal(m.read(want, UInt64(CODEC_FRAMES)), UInt64(CODEC_FRAMES))
    assert_equal(max_abs_diff(got, want), Float32(0))


def test_mp3_and_flac_decode_to_nearly_the_same_signal() raises:
    var lib = _lib()
    var mp3 = decode_file(lib, MP3_PATH).samples_f32()
    var flac = decode_file(lib, FLAC_PATH).samples_f32()
    # Same source audio; the lossy MP3 stays within 0.05 of the lossless FLAC
    # (measured 0.033), i.e. the two decodes are time-aligned.
    assert_true(max_abs_diff(mp3, flac) < 0.05)


def test_decode_memory_equals_decode_file() raises:
    var lib = _lib()
    var by_file = decode_file(lib, FLAC_PATH)
    var by_mem = decode_memory(lib, read_file_bytes(FLAC_PATH))
    assert_equal(by_mem.frame_count, by_file.frame_count)
    assert_equal(by_mem.channels, by_file.channels)
    assert_equal(by_mem.sample_rate, by_file.sample_rate)
    assert_equal(max_abs_diff(by_mem.samples_f32(), by_file.samples_f32()), Float32(0))
    var wav_mem = decode_memory(lib, read_file_bytes(WAV_PATH))
    assert_equal(wav_mem.frame_count, UInt64(WAV_FRAMES))
    var mp3_mem = decode_memory(lib, read_file_bytes(MP3_PATH))
    assert_equal(mp3_mem.frame_count, UInt64(CODEC_FRAMES))


def test_decode_from_vfs_equals_decode_file() raises:
    var lib = _lib()
    var vfs = Vfs.create(lib)
    var by_vfs = decode_from_vfs(lib, vfs, WAV_PATH)
    var by_default = decode_from_default_vfs(lib, WAV_PATH)
    var by_file = decode_file(lib, WAV_PATH)
    assert_equal(by_vfs.frame_count, by_file.frame_count)
    assert_equal(by_default.frame_count, by_file.frame_count)
    var want = by_file.samples_f32()
    assert_equal(max_abs_diff(by_vfs.samples_f32(), want), Float32(0))
    assert_equal(max_abs_diff(by_default.samples_f32(), want), Float32(0))


def test_native_format_keeps_s16_pcm_exactly() raises:
    var d = decode_file(_lib(), WAV_PATH, format=SAMPLE_FORMAT_UNKNOWN)
    assert_true(d.format == SAMPLE_FORMAT_S16)
    var pcm = d.samples_s16()
    assert_equal(len(pcm), 2 * WAV_FRAMES)
    for i in [0, 1, 777, 24000, 47999]:
        assert_equal(Int(pcm[2 * i]), sine16(i, WAV_RATE, 0.2))
        assert_equal(Int(pcm[2 * i + 1]), sine16(i, WAV_RATE, 0.2))


def test_output_conversion_is_applied_and_reported() raises:
    var d = decode_file(
        _lib(), FLAC_PATH, format=SAMPLE_FORMAT_S16, channels=1, sample_rate=22050
    )
    assert_true(d.format == SAMPLE_FORMAT_S16)
    assert_equal(d.channels, UInt32(1))
    assert_equal(d.sample_rate, UInt32(22050))
    # 0.25 s at 22.05 kHz = 5512.5 frames, rounded up by the resampler.
    assert_true(d.frame_count >= 5512 and d.frame_count <= 5514)
    var pcm = d.samples_s16()
    assert_equal(len(pcm), Int(d.frame_count))
    # The mono s16 stream is still the 440 Hz sine: peak near 0.5 * 32767.
    var peak = 0
    for i in range(len(pcm)):
        var v = Int(pcm[i])
        if v < 0:
            v = -v
        if v > peak:
            peak = v
    assert_true(peak > 15500 and peak < 17000)


def test_wrong_sample_accessor_raises() raises:
    var lib = _lib()
    var f = decode_file(lib, FLAC_PATH)
    with assert_raises():
        _ = f.samples_s16()
    var s = decode_file(lib, FLAC_PATH, format=SAMPLE_FORMAT_S16)
    with assert_raises():
        _ = s.samples_f32()


def test_failures_raise() raises:
    var lib = _lib()
    with assert_raises():
        _ = decode_file(lib, MISSING_PATH)
    with assert_raises():
        _ = decode_file(lib, "./pixi.toml")  # exists, but is not audio
    with assert_raises():
        _ = decode_file(lib, WAV_PATH, format=SampleFormat(99))
    with assert_raises():
        _ = decode_memory(lib, List[UInt8]())
    with assert_raises():
        _ = decode_memory(lib, garbage_bytes(512))
    with assert_raises():
        _ = decode_from_default_vfs(lib, MISSING_PATH)
    var vfs = Vfs.create(lib)
    with assert_raises():
        _ = decode_from_vfs(lib, vfs, MISSING_PATH)


def test_backend_config_round_trips() raises:
    var lib = _lib()
    var c = decoding_backend_config(lib, SAMPLE_FORMAT_F32, 32)
    assert_true(c.preferred_format == SAMPLE_FORMAT_F32)
    assert_equal(c.seek_point_count, UInt32(32))
    var d = decoding_backend_config(lib, SAMPLE_FORMAT_S16)
    assert_true(d.preferred_format == SAMPLE_FORMAT_S16)
    assert_equal(d.seek_point_count, UInt32(0))
    with assert_raises():
        _ = decoding_backend_config(lib, SampleFormat(99))


def test_dropping_decoded_audio_releases_the_buffer() raises:
    """Each WAV decode fills ~375 KB (94 pages); 25 unreleased buffers would add
    ~2350 resident pages, far over the threshold."""
    var lib = _lib()
    for _ in range(3):
        _ = decode_file(lib, WAV_PATH).frame_count
    var before = _resident_pages()
    for _ in range(25):
        var d = decode_file(lib, WAV_PATH)
        assert_equal(d.frame_count, UInt64(WAV_FRAMES))
    var grown = _resident_pages() - before
    assert_true(grown < 1000)  # 1000 pages = ~4 MB


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
