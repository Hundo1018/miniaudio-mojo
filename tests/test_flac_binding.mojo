"""TDD contract tests for the ma_flac BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: decodes the committed fixture
tests/fixtures/sine_440_stereo_44100.flac (0.25 s, 44.1 kHz, stereo, 16-bit,
440 Hz, amplitude 0.5; 11025 frames). miniaudio cannot encode FLAC, so the file
is checked in (tests/fixtures/README.md). All 8 bindable MA_API ma_flac
functions are exercised, positive and negative.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_AT_END
import miniaudio._ffi.flac_raw as raw
from support.codec_fixtures import (
    FLAC_PATH,
    MISSING_PATH,
    CODEC_FRAMES,
    CODEC_RATE,
    MA_INVALID_FILE,
    MA_CHANNEL_FRONT_LEFT,
    MA_CHANNEL_FRONT_RIGHT,
    read_file_bytes,
    garbage_bytes,
    channel_rms,
    sine16,
)

comptime FMT_UNKNOWN = 0
comptime FMT_U8 = 1
comptime FMT_S16 = 2
comptime FMT_S32 = 4
comptime FMT_F32 = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _open(lib: MaLib, fmt: Int = FMT_F32) raises -> OpaquePointer[MutUntrackedOrigin]:
    var h = raw.flac_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, fmt, 0), MA_SUCCESS)
    return h


def _zeros(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(0))
    return buf^


def test_alloc_and_free() raises:
    var lib = _lib()
    var h = raw.flac_alloc(lib)
    assert_true(h != null_handle())
    raw.flac_free(lib, h)  # never initialised: free must still be clean
    raw.flac_free(lib, null_handle())  # null is a no-op


def test_init_file_reports_data_format() raises:
    var lib = _lib()
    var h = _open(lib)
    var f = raw.flac_get_data_format(lib, h)
    assert_equal(f.result, MA_SUCCESS)
    assert_equal(f.format, FMT_F32)
    assert_equal(f.channels, UInt32(2))
    assert_equal(f.sample_rate, UInt32(CODEC_RATE))
    raw.flac_free(lib, h)


def test_preferred_format_selection() raises:
    """FLAC defaults to f32; s16 and s32 are honoured; anything else is ignored."""
    var lib = _lib()
    var s16 = _open(lib, FMT_S16)
    assert_equal(raw.flac_get_data_format(lib, s16).format, FMT_S16)
    var s32 = _open(lib, FMT_S32)
    assert_equal(raw.flac_get_data_format(lib, s32).format, FMT_S32)
    # unknown (0) and a valid-but-unsupported preference (u8) both fall back to f32;
    # miniaudio ignores them silently rather than failing.
    var native = _open(lib, FMT_UNKNOWN)
    assert_equal(raw.flac_get_data_format(lib, native).format, FMT_F32)
    var u8 = _open(lib, FMT_U8)
    assert_equal(raw.flac_get_data_format(lib, u8).format, FMT_F32)
    raw.flac_free(lib, s16)
    raw.flac_free(lib, s32)
    raw.flac_free(lib, native)
    raw.flac_free(lib, u8)


def test_init_file_missing_path() raises:
    var lib = _lib()
    var h = raw.flac_alloc(lib)
    assert_equal(raw.flac_init_file(lib, h, MISSING_PATH, FMT_F32, 0), MA_INVALID_FILE)
    # A failed init leaves the handle unusable.
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).result, MA_INVALID_ARGS)
    raw.flac_free(lib, h)


def test_init_memory_matches_file() raises:
    var lib = _lib()
    var data = read_file_bytes(FLAC_PATH)
    var m = raw.flac_alloc(lib)
    assert_equal(raw.flac_init_memory(lib, m, data, FMT_F32, 0), MA_SUCCESS)
    var f = _open(lib)
    var mf = raw.flac_get_data_format(lib, m)
    var ff = raw.flac_get_data_format(lib, f)
    assert_equal(mf.format, ff.format)
    assert_equal(mf.channels, ff.channels)
    assert_equal(mf.sample_rate, ff.sample_rate)
    assert_equal(raw.flac_get_length_in_pcm_frames(lib, m).value, UInt64(CODEC_FRAMES))
    var a = _zeros(512)
    var b = _zeros(512)
    assert_equal(raw.flac_read_pcm_frames(lib, m, a, 256).value, UInt64(256))
    assert_equal(raw.flac_read_pcm_frames(lib, f, b, 256).value, UInt64(256))
    for i in range(512):
        assert_equal(a[i], b[i])
    raw.flac_free(lib, m)
    raw.flac_free(lib, f)


def test_init_memory_negative() raises:
    var lib = _lib()
    var h = raw.flac_alloc(lib)
    assert_equal(raw.flac_init_memory(lib, h, garbage_bytes(256), FMT_F32, 0), MA_INVALID_FILE)
    assert_equal(raw.flac_init_memory(lib, h, List[UInt8](), FMT_F32, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_init_memory(lib, null_handle(), garbage_bytes(8), FMT_F32, 0), MA_INVALID_ARGS)
    raw.flac_free(lib, h)


def test_init_rejects_out_of_range_format() raises:
    var lib = _lib()
    var h = raw.flac_alloc(lib)
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, 99, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, -1, 0), MA_INVALID_ARGS)
    var data = read_file_bytes(FLAC_PATH)
    assert_equal(raw.flac_init_memory(lib, h, data, 99, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).result, MA_INVALID_ARGS)
    raw.flac_free(lib, h)


def test_reinit_replaces_previous_stream() raises:
    var lib = _lib()
    var h = _open(lib, FMT_F32)
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, FMT_S16, 0), MA_SUCCESS)
    assert_equal(raw.flac_get_data_format(lib, h).format, FMT_S16)
    raw.flac_free(lib, h)


def test_read_returns_sine_signal() raises:
    var lib = _lib()
    var h = _open(lib)
    var buf = _zeros(2 * 4410)
    var r = raw.flac_read_pcm_frames(lib, h, buf, 4410)
    assert_equal(r.result, MA_SUCCESS)
    assert_equal(r.value, UInt64(4410))
    # amplitude 0.5 -> RMS 0.5 / sqrt(2) = 0.3536 on each channel
    var rms = channel_rms(buf, 2, 0)
    assert_true(rms > 0.34 and rms < 0.37)
    assert_equal(buf[0], Float32(0.0))
    raw.flac_free(lib, h)


def test_read_zero_frames_is_invalid_args() raises:
    var lib = _lib()
    var h = _open(lib)
    var buf = _zeros(8)
    var r = raw.flac_read_pcm_frames(lib, h, buf, 0)
    assert_equal(r.result, MA_INVALID_ARGS)
    assert_equal(r.value, UInt64(0))
    raw.flac_free(lib, h)


def test_read_rejects_undersized_buffer() raises:
    """Miniaudio cannot know the buffer size; the shim refuses an overflowing read."""
    var lib = _lib()
    var h = _open(lib)
    var buf = _zeros(20)  # room for 10 stereo f32 frames
    var bad = raw.flac_read_pcm_frames(lib, h, buf, 11)
    assert_equal(bad.result, MA_INVALID_ARGS)
    assert_equal(bad.value, UInt64(0))
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).value, UInt64(0))
    assert_equal(raw.flac_read_pcm_frames(lib, h, buf, 10).result, MA_SUCCESS)
    raw.flac_free(lib, h)


def test_read_past_end_returns_short_then_at_end() raises:
    var lib = _lib()
    var h = _open(lib)
    assert_equal(raw.flac_seek_to_pcm_frame(lib, h, UInt64(CODEC_FRAMES - 10)), MA_SUCCESS)
    var buf = _zeros(2 * 100)
    var tail = raw.flac_read_pcm_frames(lib, h, buf, 100)
    assert_equal(tail.result, MA_SUCCESS)
    assert_equal(tail.value, UInt64(10))
    var after = raw.flac_read_pcm_frames(lib, h, buf, 100)
    assert_equal(after.result, MA_AT_END)
    assert_equal(after.value, UInt64(0))
    raw.flac_free(lib, h)


def test_read_s16_matches_generator_samples() raises:
    var lib = _lib()
    var h = _open(lib, FMT_S16)
    var buf = List[Int16]()
    buf.resize(2 * 4000, Int16(0))
    var r = raw.flac_read_pcm_frames_s16(lib, h, buf, 4000)
    assert_equal(r.result, MA_SUCCESS)
    assert_equal(r.value, UInt64(4000))
    # FLAC is lossless: the 16-bit values are exactly what the generator wrote.
    for i in [0, 1, 100, 1234, 3999]:
        assert_equal(Int(buf[2 * i]), sine16(i, CODEC_RATE, 0.5))
        assert_equal(Int(buf[2 * i + 1]), sine16(i, CODEC_RATE, 0.5))
    # An undersized s16 buffer is refused too (2 bytes per sample).
    var small = List[Int16]()
    small.resize(10, Int16(0))
    assert_equal(raw.flac_read_pcm_frames_s16(lib, h, small, 6).result, MA_INVALID_ARGS)
    raw.flac_free(lib, h)


def test_seek_then_cursor_equals_target() raises:
    var lib = _lib()
    var h = _open(lib)
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).value, UInt64(0))
    assert_equal(raw.flac_seek_to_pcm_frame(lib, h, 5000), MA_SUCCESS)
    var c = raw.flac_get_cursor_in_pcm_frames(lib, h)
    assert_equal(c.result, MA_SUCCESS)
    assert_equal(c.value, UInt64(5000))
    var buf = _zeros(2)
    _ = raw.flac_read_pcm_frames(lib, h, buf, 1)
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).value, UInt64(5001))
    # Pinned upstream behaviour: dr_flac clamps a seek past the end to the end.
    assert_equal(raw.flac_seek_to_pcm_frame(lib, h, 1000000), MA_SUCCESS)
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, h).value, UInt64(CODEC_FRAMES))
    raw.flac_free(lib, h)


def test_length_in_frames() raises:
    var lib = _lib()
    var h = _open(lib)
    var l = raw.flac_get_length_in_pcm_frames(lib, h)
    assert_equal(l.result, MA_SUCCESS)
    assert_equal(l.value, UInt64(CODEC_FRAMES))
    raw.flac_free(lib, h)


def test_channel_map_is_front_left_right() raises:
    var lib = _lib()
    var h = _open(lib)
    var m = raw.flac_get_channel_map(lib, h, 2)
    assert_equal(m.result, MA_SUCCESS)
    assert_equal(len(m.value), 2)
    assert_equal(m.value[0], MA_CHANNEL_FRONT_LEFT)
    assert_equal(m.value[1], MA_CHANNEL_FRONT_RIGHT)
    raw.flac_free(lib, h)


def test_null_pointer_arguments_rejected() raises:
    """Pointer arguments the typed raw wrappers cannot express as NULL."""
    var lib = _lib()
    var h = _open(lib)
    var n = null_handle()
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_init_file", Int32](h, n, Int32(FMT_F32), UInt32(0))),
        MA_INVALID_ARGS,
    )
    var frames = [UInt64(0)]
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_read_pcm_frames", Int32](
            h, n, UInt64(64), UInt64(4), frames.unsafe_ptr())),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_get_cursor_in_pcm_frames", Int32](h, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_get_length_in_pcm_frames", Int32](h, n)),
        MA_INVALID_ARGS,
    )
    # Every output pointer of get_data_format is optional.
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_get_data_format", Int32](h, n, n, n, n, UInt32(0))),
        MA_SUCCESS,
    )
    # read without an frames_read out-pointer still works.
    var buf = _zeros(8)
    assert_equal(
        Int(lib.handle.call["ma_shim_flac_read_pcm_frames", Int32](
            h, buf.unsafe_ptr(), UInt64(32), UInt64(4), n)),
        MA_SUCCESS,
    )
    raw.flac_free(lib, h)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var buf = _zeros(8)
    var s16 = List[Int16]()
    s16.resize(8, Int16(0))
    assert_equal(raw.flac_init_file(lib, n, FLAC_PATH, FMT_F32, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.flac_read_pcm_frames(lib, n, buf, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_read_pcm_frames_s16(lib, n, s16, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_seek_to_pcm_frame(lib, n, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_get_data_format(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_get_channel_map(lib, n, 2).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_get_cursor_in_pcm_frames(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_get_length_in_pcm_frames(lib, n).result, MA_INVALID_ARGS)


def test_uninit_is_idempotent_and_reinit_ok() raises:
    var lib = _lib()
    var h = raw.flac_alloc(lib)
    assert_equal(raw.flac_uninit(lib, h), MA_SUCCESS)  # before init: a no-op
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, FMT_F32, 0), MA_SUCCESS)
    assert_equal(raw.flac_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.flac_uninit(lib, h), MA_SUCCESS)  # twice is fine
    var buf = _zeros(8)
    assert_equal(raw.flac_read_pcm_frames(lib, h, buf, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_seek_to_pcm_frame(lib, h, 0), MA_INVALID_ARGS)
    assert_equal(raw.flac_get_length_in_pcm_frames(lib, h).result, MA_INVALID_ARGS)
    assert_equal(raw.flac_init_file(lib, h, FLAC_PATH, FMT_F32, 0), MA_SUCCESS)
    assert_equal(raw.flac_get_length_in_pcm_frames(lib, h).value, UInt64(CODEC_FRAMES))
    raw.flac_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
