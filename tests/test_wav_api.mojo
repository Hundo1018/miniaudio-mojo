"""TDD tests for the idiomatic WavDecoder API (RAII, L3 behavioural).

Decodes the WAV `pixi run gen-test-wav` writes (1 s, 48 kHz, stereo, 16-bit,
440 Hz, amplitude 0.2) and asserts real signal values, not just that calls
return.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.wav import WavDecoder
from miniaudio.decoder import (
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
from support.codec_fixtures import (
    WAV_PATH,
    MISSING_PATH,
    WAV_FRAMES,
    WAV_RATE,
    MA_CHANNEL_FRONT_LEFT,
    MA_CHANNEL_FRONT_RIGHT,
    read_file_bytes,
    garbage_bytes,
    channel_rms,
    rising_crossings,
    max_abs_diff,
    sine16,
    sine_f32,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_data_format_matches_fixture() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    assert_true(d.format() == SAMPLE_FORMAT_F32)
    assert_equal(d.channels(), UInt32(2))
    assert_equal(d.sample_rate(), UInt32(WAV_RATE))
    assert_equal(d.length_in_frames(), UInt64(WAV_FRAMES))
    assert_equal(d.cursor(), UInt64(0))
    var f = d.data_format()
    assert_equal(f.format, SAMPLE_FORMAT_F32.code)
    assert_equal(f.channels, UInt32(2))
    assert_equal(f.sample_rate, UInt32(WAV_RATE))


def test_read_decodes_the_generated_sine() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    var buf = List[Float32]()
    var n = d.read(buf, UInt64(WAV_FRAMES))
    assert_equal(n, UInt64(WAV_FRAMES))
    assert_equal(len(buf), 2 * WAV_FRAMES)
    # Sample-exact against the generator: s16 value / 32768.
    for i in [0, 1, 55, 1000, 24000, 47999]:
        assert_true(abs(buf[2 * i] - sine_f32(i, WAV_RATE, 0.2)) < 1e-6)
        assert_true(abs(buf[2 * i + 1] - sine_f32(i, WAV_RATE, 0.2)) < 1e-6)
    # Sine character: amplitude 0.2 -> RMS 0.1414, one rising crossing per cycle
    # (440 cycles in one second; the cycle that starts at frame 0 is not counted).
    for ch in range(2):
        var rms = channel_rms(buf, 2, ch)
        assert_true(rms > 0.140 and rms < 0.143)
        var crossings = rising_crossings(buf, 2, ch)
        assert_true(crossings >= 438 and crossings <= 441)


def test_read_advances_cursor_and_buffer_tracks_result() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    var buf = List[Float32]()
    assert_equal(d.read(buf, 1000), UInt64(1000))
    assert_equal(len(buf), 2000)
    assert_equal(d.cursor(), UInt64(1000))
    assert_equal(d.read(buf, 24), UInt64(24))
    assert_equal(len(buf), 48)
    assert_equal(d.cursor(), UInt64(1024))
    # The second read continues the stream rather than restarting it.
    assert_true(abs(buf[0] - sine_f32(1000, WAV_RATE, 0.2)) < 1e-6)


def test_seek_then_cursor_and_read_continue_from_target() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    d.seek(30000)
    assert_equal(d.cursor(), UInt64(30000))
    var buf = List[Float32]()
    assert_equal(d.read(buf, 4), UInt64(4))
    for i in range(4):
        assert_true(abs(buf[2 * i] - sine_f32(30000 + i, WAV_RATE, 0.2)) < 1e-6)
    d.seek(0)
    assert_equal(d.cursor(), UInt64(0))


def test_read_past_end_returns_short_then_zero() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    var buf = List[Float32]()
    assert_equal(d.read(buf, UInt64(WAV_FRAMES + 5000)), UInt64(WAV_FRAMES))
    assert_equal(len(buf), 2 * WAV_FRAMES)
    assert_equal(d.cursor(), UInt64(WAV_FRAMES))
    assert_equal(d.read(buf, 100), UInt64(0))  # at the end: 0 frames, not an error
    assert_equal(len(buf), 0)


def test_memory_decode_equals_file_decode() raises:
    var lib = _lib()
    var from_file = WavDecoder.from_file(lib, WAV_PATH)
    var from_mem = WavDecoder.from_memory(lib, read_file_bytes(WAV_PATH))
    assert_equal(from_mem.length_in_frames(), from_file.length_in_frames())
    assert_equal(from_mem.channels(), from_file.channels())
    assert_equal(from_mem.sample_rate(), from_file.sample_rate())
    var a = List[Float32]()
    var b = List[Float32]()
    assert_equal(from_file.read(a, 8000), UInt64(8000))
    assert_equal(from_mem.read(b, 8000), UInt64(8000))
    assert_equal(max_abs_diff(a, b), Float32(0))


def test_s16_stream_reads_exact_pcm() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH, format=SAMPLE_FORMAT_S16)
    assert_true(d.format() == SAMPLE_FORMAT_S16)
    var pcm = List[Int16]()
    assert_equal(d.read_s16(pcm, 2000), UInt64(2000))
    assert_equal(len(pcm), 4000)
    for i in [0, 7, 500, 1999]:
        assert_equal(Int(pcm[2 * i]), sine16(i, WAV_RATE, 0.2))
    # The wrong reader for the stream format is an error, not garbage.
    var f32 = List[Float32]()
    with assert_raises():
        _ = d.read(f32, 10)


def test_native_and_s32_formats() raises:
    var lib = _lib()
    var native = WavDecoder.from_file(lib, WAV_PATH, format=SAMPLE_FORMAT_UNKNOWN)
    assert_true(native.format() == SAMPLE_FORMAT_S16)  # the file is 16-bit PCM
    var s32 = WavDecoder.from_file(lib, WAV_PATH, format=SAMPLE_FORMAT_S32)
    assert_true(s32.format() == SAMPLE_FORMAT_S32)
    var f32 = WavDecoder.from_file(lib, WAV_PATH)
    var pcm = List[Int16]()
    with assert_raises():
        _ = f32.read_s16(pcm, 10)


def test_channel_map_is_stereo() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    var m = d.channel_map()
    assert_equal(len(m), 2)
    assert_equal(m[0], MA_CHANNEL_FRONT_LEFT)
    assert_equal(m[1], MA_CHANNEL_FRONT_RIGHT)


def test_missing_file_raises() raises:
    with assert_raises():
        _ = WavDecoder.from_file(_lib(), MISSING_PATH)


def test_garbage_memory_raises() raises:
    with assert_raises():
        _ = WavDecoder.from_memory(_lib(), garbage_bytes(512))
    with assert_raises():
        _ = WavDecoder.from_memory(_lib(), List[UInt8]())


def test_zero_frame_read_raises() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
    var buf = List[Float32]()
    with assert_raises():
        _ = d.read(buf, 0)


def test_operations_after_uninit_raise() raises:
    var d = WavDecoder.from_file(_lib(), WAV_PATH)
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
