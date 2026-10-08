"""TDD tests for the idiomatic Mp3Decoder API (RAII, L3 behavioural).

Decodes the committed fixture tests/fixtures/sine_440_stereo_44100.mp3 (0.25 s,
44.1 kHz, stereo, 64 kbps CBR, 440 Hz, amplitude 0.5) and asserts real signal
values. MP3 is lossy, so the checks are tolerance-based against the ideal sine
(measured: RMS 0.336 vs ideal 0.354, error vs the ideal sine 0.018 RMS).

Length: the fixture has a Xing/LAME header, so dr_mp3 reports the gapless source
length (11025 frames) rather than a multiple of 1152. The cursor still counts
the 1105-frame encoder delay; see tests/test_mp3_binding.mojo.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.mp3 import Mp3Decoder
from miniaudio.decoder import (
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
from support.codec_fixtures import (
    MP3_PATH,
    MISSING_PATH,
    CODEC_FRAMES,
    CODEC_RATE,
    MP3_ENCODER_DELAY,
    MA_CHANNEL_FRONT_LEFT,
    MA_CHANNEL_FRONT_RIGHT,
    read_file_bytes,
    garbage_bytes,
    channel_rms,
    rising_crossings,
    max_abs_diff,
    sine_rms_error,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _decode_all(mut d: Mp3Decoder) raises -> List[Float32]:
    var buf = List[Float32]()
    assert_equal(d.read(buf, UInt64(CODEC_FRAMES + 1000)), UInt64(CODEC_FRAMES))
    return buf^


def test_data_format_matches_fixture() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    assert_true(d.format() == SAMPLE_FORMAT_F32)
    assert_equal(d.channels(), UInt32(2))
    assert_equal(d.sample_rate(), UInt32(CODEC_RATE))
    assert_equal(d.cursor(), UInt64(0))
    var f = d.data_format()
    assert_equal(f.format, SAMPLE_FORMAT_F32.code)
    assert_equal(f.channels, UInt32(2))
    assert_equal(f.sample_rate, UInt32(CODEC_RATE))


def test_length_is_the_gapless_source_length() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    # 11025 = 0.25 s at 44.1 kHz; without the LAME tag it would be 12672 (11 x 1152).
    assert_equal(d.length_in_frames(), UInt64(CODEC_FRAMES))
    # Decoding really yields that many frames, no more.
    var buf = _decode_all(d)
    assert_equal(len(buf), 2 * CODEC_FRAMES)


def test_decoded_signal_is_the_440hz_sine() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    var buf = _decode_all(d)
    for ch in range(2):
        # Ideal RMS 0.3536; lossy coding at 64 kbps lands at 0.336.
        var rms = channel_rms(buf, 2, ch)
        assert_true(rms > 0.32 and rms < 0.35)
        # 110 cycles in 0.25 s; the one starting at frame 0 is not counted.
        var crossings = rising_crossings(buf, 2, ch)
        assert_true(crossings >= 108 and crossings <= 110)
        # Gapless trimming keeps the phase aligned with the source: the error
        # against the ideal sine (phase 0) is codec noise only.
        assert_true(sine_rms_error(buf, 2, ch, CODEC_RATE, 0.5) < 0.03)
    # The source was dual-mono: both channels decode identically.
    var left = List[Float32]()
    var right = List[Float32]()
    for i in range(CODEC_FRAMES):
        left.append(buf[2 * i])
        right.append(buf[2 * i + 1])
    assert_true(max_abs_diff(left, right) < 1e-6)


def test_read_advances_cursor_with_encoder_delay() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    var buf = List[Float32]()
    assert_equal(d.read(buf, 1000), UInt64(1000))
    assert_equal(len(buf), 2000)
    assert_equal(d.cursor(), UInt64(1000 + MP3_ENCODER_DELAY))
    d.seek(0)
    assert_equal(d.cursor(), UInt64(0))


def test_seek_lands_on_the_same_samples_as_sequential_reading() raises:
    var lib = _lib()
    var seq = Mp3Decoder.from_file(lib, MP3_PATH)
    var all = _decode_all(seq)
    var d = Mp3Decoder.from_file(lib, MP3_PATH)
    d.seek(5000)
    assert_equal(d.cursor(), UInt64(5000 + MP3_ENCODER_DELAY))
    var buf = List[Float32]()
    assert_equal(d.read(buf, 500), UInt64(500))
    var want = List[Float32]()
    for i in range(1000):
        want.append(all[2 * 5000 + i])
    assert_equal(max_abs_diff(buf, want), Float32(0))


def test_seek_table_open_decodes_the_same_stream() raises:
    var lib = _lib()
    var plain = Mp3Decoder.from_file(lib, MP3_PATH)
    var tabled = Mp3Decoder.from_file(lib, MP3_PATH, seek_points=16)
    assert_equal(tabled.length_in_frames(), UInt64(CODEC_FRAMES))
    assert_equal(max_abs_diff(_decode_all(plain), _decode_all(tabled)), Float32(0))
    # Pinned dr_mp3 quirk: seek-table seeks report the bare target as the cursor.
    tabled.seek(5000)
    assert_equal(tabled.cursor(), UInt64(5000))


def test_read_past_end_returns_short_then_zero() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    d.seek(UInt64(CODEC_FRAMES - 10))
    var buf = List[Float32]()
    assert_equal(d.read(buf, 100), UInt64(10))
    assert_equal(len(buf), 20)
    assert_equal(d.read(buf, 100), UInt64(0))  # at the end: 0 frames, not an error
    assert_equal(len(buf), 0)


def test_seek_past_end_raises() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    with assert_raises():
        d.seek(1000000)


def test_memory_decode_equals_file_decode() raises:
    var lib = _lib()
    var from_file = Mp3Decoder.from_file(lib, MP3_PATH)
    var from_mem = Mp3Decoder.from_memory(lib, read_file_bytes(MP3_PATH))
    assert_equal(from_mem.length_in_frames(), from_file.length_in_frames())
    assert_equal(from_mem.channels(), from_file.channels())
    assert_equal(from_mem.sample_rate(), from_file.sample_rate())
    assert_equal(max_abs_diff(_decode_all(from_file), _decode_all(from_mem)), Float32(0))


def test_s16_stream_is_the_f32_stream_quantised() raises:
    var lib = _lib()
    var f = Mp3Decoder.from_file(lib, MP3_PATH)
    var s = Mp3Decoder.from_file(lib, MP3_PATH, format=SAMPLE_FORMAT_S16)
    assert_true(s.format() == SAMPLE_FORMAT_S16)
    var want = _decode_all(f)
    var pcm = List[Int16]()
    assert_equal(s.read_s16(pcm, UInt64(CODEC_FRAMES)), UInt64(CODEC_FRAMES))
    assert_equal(len(pcm), 2 * CODEC_FRAMES)
    for i in [0, 1, 1000, 12345, 22049]:
        assert_true(abs(Float32(pcm[i]) / 32768.0 - want[i]) < 1e-6)
    # The wrong reader for the stream format is an error, not garbage.
    var f32 = List[Float32]()
    with assert_raises():
        _ = s.read(f32, 10)
    with assert_raises():
        _ = f.read_s16(pcm, 10)


def test_only_f32_and_s16_are_offered() raises:
    var lib = _lib()
    var native = Mp3Decoder.from_file(lib, MP3_PATH, format=SAMPLE_FORMAT_UNKNOWN)
    assert_true(native.format() == SAMPLE_FORMAT_F32)
    var s32 = Mp3Decoder.from_file(lib, MP3_PATH, format=SAMPLE_FORMAT_S32)
    assert_true(s32.format() == SAMPLE_FORMAT_F32)  # silently ignored by miniaudio


def test_channel_map_is_stereo() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    var m = d.channel_map()
    assert_equal(len(m), 2)
    assert_equal(m[0], MA_CHANNEL_FRONT_LEFT)
    assert_equal(m[1], MA_CHANNEL_FRONT_RIGHT)


def test_missing_file_raises() raises:
    with assert_raises():
        _ = Mp3Decoder.from_file(_lib(), MISSING_PATH)


def test_garbage_memory_raises() raises:
    with assert_raises():
        _ = Mp3Decoder.from_memory(_lib(), garbage_bytes(4096))
    with assert_raises():
        _ = Mp3Decoder.from_memory(_lib(), List[UInt8]())


def test_zero_frame_read_raises() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH)
    var buf = List[Float32]()
    with assert_raises():
        _ = d.read(buf, 0)


def test_operations_after_uninit_raise() raises:
    var d = Mp3Decoder.from_file(_lib(), MP3_PATH, seek_points=8)
    d.uninit()
    d.uninit()  # idempotent
    var buf = List[Float32]()
    with assert_raises():
        _ = d.length_in_frames()
    with assert_raises():
        _ = d.cursor()
    with assert_raises():
        d.seek(0)
    with assert_raises():
        _ = d.read(buf, 10)
    with assert_raises():
        _ = d.channels()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
