"""TDD tests for the idiomatic decoder API layer (RAII Decoder)."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import Decoder, SampleFormat, SAMPLE_FORMAT_F32, SAMPLE_FORMAT_S16
from miniaudio._lib import MaLib
from support.wav_fixtures import embedded_wav_stereo_2frames


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_from_file_reads_into_list() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    assert_equal(dec.channels(), UInt32(2))
    var buf = List[Float32]()
    var frames = dec.read(buf, 512)
    assert_true(frames > 0)
    assert_equal(len(buf), Int(frames) * 2)


def test_from_file_missing_raises() raises:
    var lib = _lib()
    with assert_raises():
        var dec = Decoder.from_file(lib, "/tmp/mmj-does-not-exist.wav")
        _ = dec.channels()


def test_seek_resets_cursor() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var buf = List[Float32]()
    _ = dec.read(buf, 128)
    dec.seek(0)
    assert_equal(dec.cursor(), UInt64(0))


def test_default_format_is_f32() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    assert_true(dec.format() == SAMPLE_FORMAT_F32)


def test_from_memory_reads() raises:
    var lib = _lib()
    var data = embedded_wav_stereo_2frames()
    var dec = Decoder.from_memory(lib, data^, channels=2, sample_rate=8000)
    assert_equal(dec.sample_rate(), UInt32(8000))
    var buf = List[Float32]()
    var frames = dec.read(buf, 2)
    assert_true(frames >= 1)


def test_consecutive_reads_advance_cursor() raises:
    """L3 behavioral: two consecutive reads advance the cursor by the frames read."""
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var buf = List[Float32]()
    var f1 = dec.read(buf, 64)
    var cursor_after_first = dec.cursor()
    assert_equal(cursor_after_first, f1)
    var f2 = dec.read(buf, 64)
    var cursor_after_second = dec.cursor()
    assert_equal(cursor_after_second, f1 + f2)


def test_length_is_invariant() raises:
    """L3 behavioral: length_in_frames is stable across reads and seeks."""
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var len_before = dec.length_in_frames()
    assert_true(len_before > 0)
    var buf = List[Float32]()
    _ = dec.read(buf, 128)
    assert_equal(dec.length_in_frames(), len_before)
    dec.seek(0)
    assert_equal(dec.length_in_frames(), len_before)


def test_seek_then_reread_matches_initial() raises:
    """L3 behavioral: reading from frame 0 twice yields the same sample count."""
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var buf1 = List[Float32]()
    var frames_first = dec.read(buf1, 256)
    dec.seek(0)
    var buf2 = List[Float32]()
    var frames_second = dec.read(buf2, 256)
    assert_equal(frames_first, frames_second)
    assert_equal(len(buf1), len(buf2))


def test_reinit_from_file_resets_state() raises:
    """L3 behavioral: a new Decoder.from_file starts cursor at 0."""
    var lib = _lib()
    var dec1 = Decoder.from_file(lib, WAV_PATH)
    var buf = List[Float32]()
    _ = dec1.read(buf, 512)
    var mid_cursor = dec1.cursor()
    assert_true(mid_cursor > 0)
    var dec2 = Decoder.from_file(lib, WAV_PATH)
    assert_equal(dec2.cursor(), UInt64(0))


def test_from_file_native_preserves_source_format() raises:
    """L3 behavioral: from_file_native keeps the file's native format (S16), not f32."""
    var lib = _lib()
    var dec = Decoder.from_file_native(lib, WAV_PATH)
    assert_true(dec.format() == SAMPLE_FORMAT_S16)
    assert_equal(dec.channels(), UInt32(2))
    assert_equal(dec.sample_rate(), UInt32(48000))
    # Native decoder still reads audio.
    var buf = List[Float32]()
    var frames = dec.read(buf, 256)
    assert_true(frames > 0)


def test_from_file_native_missing_raises() raises:
    var lib = _lib()
    with assert_raises():
        var dec = Decoder.from_file_native(lib, "/tmp/mmj-does-not-exist.wav")
        _ = dec.channels()


def test_from_file_vfs_reads_like_from_file() raises:
    """L3 behavioral: the default-VFS path yields the same channels/length as from_file."""
    var lib = _lib()
    var via_vfs = Decoder.from_file_vfs(lib, WAV_PATH)
    var via_file = Decoder.from_file(lib, WAV_PATH)
    assert_equal(via_vfs.channels(), via_file.channels())
    assert_equal(via_vfs.length_in_frames(), via_file.length_in_frames())
    var buf = List[Float32]()
    var frames = via_vfs.read(buf, 512)
    assert_true(frames > 0)


def test_from_file_vfs_missing_raises() raises:
    var lib = _lib()
    with assert_raises():
        var dec = Decoder.from_file_vfs(lib, "/tmp/mmj-does-not-exist.wav")
        _ = dec.channels()


def test_available_frames_tracks_cursor() raises:
    """L3 behavioral: available_frames == length at start and length - cursor after a read."""
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var length = dec.length_in_frames()
    assert_equal(dec.available_frames(), length)
    var buf = List[Float32]()
    var read = dec.read(buf, 200)
    assert_equal(dec.available_frames(), length - read)
    dec.seek(0)
    assert_equal(dec.available_frames(), length)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
