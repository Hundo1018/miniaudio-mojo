"""TDD contract tests for the decode_util BINDING layer (raw 1:1 over the shim).

Covers ma_decode_file, ma_decode_memory, ma_decode_from_vfs and
ma_decoding_backend_config_init, positive and negative, against the WAV from
`pixi run gen-test-wav` (48 kHz) and the committed FLAC / MP3 fixtures
(tests/fixtures/README.md). Deterministic and hardware-independent.

miniaudio allocates the decoded buffer; every successful raw decode here is
paired with raw.decode_free, and the leak test checks the shim really releases it.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_DOES_NOT_EXIST
import miniaudio._ffi.decode_util_raw as raw
import miniaudio._ffi.context_raw as craw
from support.codec_fixtures import (
    WAV_PATH,
    FLAC_PATH,
    MP3_PATH,
    MISSING_PATH,
    WAV_FRAMES,
    WAV_RATE,
    CODEC_FRAMES,
    CODEC_RATE,
    MA_INVALID_FILE,
    read_file_bytes,
    garbage_bytes,
    sine16,
)

comptime FMT_UNKNOWN = 0
comptime FMT_S16 = 2
comptime FMT_F32 = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _f32(frames: OpaquePointer[MutUntrackedOrigin], n: Int) -> List[Float32]:
    var p = frames.unsafe_bitcast[Float32]()
    var out = List[Float32]()
    out.resize(n, Float32(0))
    for i in range(n):
        out[i] = p[unsafe_offset=i]
    return out^


def _s16(frames: OpaquePointer[MutUntrackedOrigin], n: Int) -> List[Int16]:
    var p = frames.unsafe_bitcast[Int16]()
    var out = List[Int16]()
    out.resize(n, Int16(0))
    for i in range(n):
        out[i] = p[unsafe_offset=i]
    return out^


def _resident_pages() raises -> Int:
    """Resident set size in pages, from /proc/self/statm (linux-64 only project)."""
    var text: String
    with open("/proc/self/statm", "r") as f:
        text = f.read()
    var fields = text.split(" ")
    return Int(fields[1])


# ---- ma_decoding_backend_config_init ---------------------------------------


def test_backend_config_echoes_its_fields() raises:
    var lib = _lib()
    var c = raw.decoding_backend_config_init(lib, FMT_F32, 16)
    assert_equal(c.result, MA_SUCCESS)
    assert_equal(c.preferred_format, FMT_F32)
    assert_equal(c.seek_point_count, UInt32(16))
    var u = raw.decoding_backend_config_init(lib, FMT_UNKNOWN, 0)
    assert_equal(u.result, MA_SUCCESS)
    assert_equal(u.preferred_format, FMT_UNKNOWN)
    assert_equal(u.seek_point_count, UInt32(0))


def test_backend_config_rejects_out_of_range_format() raises:
    var lib = _lib()
    for bad in [-1, 99]:
        var c = raw.decoding_backend_config_init(lib, bad, 4)
        assert_equal(c.result, MA_INVALID_ARGS)
        assert_equal(c.preferred_format, 0)
        assert_equal(c.seek_point_count, UInt32(0))


def test_backend_config_output_pointers_are_optional() raises:
    var lib = _lib()
    var n = null_handle()
    assert_equal(
        Int(lib.handle.call["ma_shim_decoding_backend_config_init", Int32](Int32(FMT_S16), UInt32(8), n, n)),
        MA_SUCCESS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decoding_backend_config_init", Int32](Int32(99), UInt32(8), n, n)),
        MA_INVALID_ARGS,
    )


# ---- ma_decode_file ---------------------------------------------------------


def test_decode_file_native_format_keeps_the_stream() raises:
    var lib = _lib()
    var d = raw.decode_file(lib, WAV_PATH, FMT_UNKNOWN, 0, 0)
    assert_equal(d.result, MA_SUCCESS)
    assert_true(d.frames != null_handle())
    assert_equal(d.frame_count, UInt64(WAV_FRAMES))
    assert_equal(d.format, FMT_S16)  # the generated WAV is 16-bit PCM
    assert_equal(d.channels, UInt32(2))
    assert_equal(d.sample_rate, UInt32(WAV_RATE))
    var pcm = _s16(d.frames, 2 * 2000)
    for i in [0, 1, 99, 1999]:
        assert_equal(Int(pcm[2 * i]), sine16(i, WAV_RATE, 0.2))
    raw.decode_free(lib, d.frames)


def test_decode_file_converts_format_channels_and_rate() raises:
    var lib = _lib()
    # FLAC fixture: 44.1 kHz stereo; ask for s16, mono, 22.05 kHz.
    var d = raw.decode_file(lib, FLAC_PATH, FMT_S16, 1, 22050)
    assert_equal(d.result, MA_SUCCESS)
    assert_equal(d.format, FMT_S16)
    assert_equal(d.channels, UInt32(1))
    assert_equal(d.sample_rate, UInt32(22050))
    # Half the rate -> half the frames (5512.5, rounded up by the resampler).
    assert_true(d.frame_count >= 5512 and d.frame_count <= 5514)
    raw.decode_free(lib, d.frames)
    # Up-mixing and re-rating the WAV: the frame count tracks the rate only.
    var up = raw.decode_file(lib, WAV_PATH, FMT_F32, 6, 8000)
    assert_equal(up.result, MA_SUCCESS)
    assert_equal(up.channels, UInt32(6))
    assert_equal(up.frame_count, UInt64(8000))
    raw.decode_free(lib, up.frames)


def test_decode_file_covers_all_three_codecs() raises:
    var lib = _lib()
    var w = raw.decode_file(lib, WAV_PATH, FMT_F32, 0, 0)
    var f = raw.decode_file(lib, FLAC_PATH, FMT_F32, 0, 0)
    var m = raw.decode_file(lib, MP3_PATH, FMT_F32, 0, 0)
    assert_equal(w.frame_count, UInt64(WAV_FRAMES))
    assert_equal(f.frame_count, UInt64(CODEC_FRAMES))
    assert_equal(m.frame_count, UInt64(CODEC_FRAMES))  # gapless via the LAME tag
    assert_equal(f.sample_rate, UInt32(CODEC_RATE))
    assert_equal(m.sample_rate, UInt32(CODEC_RATE))
    raw.decode_free(lib, w.frames)
    raw.decode_free(lib, f.frames)
    raw.decode_free(lib, m.frames)


def test_decode_file_negative() raises:
    var lib = _lib()
    var missing = raw.decode_file(lib, MISSING_PATH, FMT_F32, 0, 0)
    assert_equal(missing.result, MA_DOES_NOT_EXIST)
    assert_true(missing.frames == null_handle())
    assert_equal(missing.frame_count, UInt64(0))
    # A file that exists but is not audio.
    var not_audio = raw.decode_file(lib, "./pixi.toml", FMT_F32, 0, 0)
    assert_equal(not_audio.result, MA_INVALID_FILE)
    assert_true(not_audio.frames == null_handle())
    assert_equal(raw.decode_file(lib, "", FMT_F32, 0, 0).result, MA_INVALID_ARGS)
    assert_equal(raw.decode_file(lib, WAV_PATH, 99, 0, 0).result, MA_INVALID_ARGS)
    assert_equal(raw.decode_file(lib, WAV_PATH, -1, 0, 0).result, MA_INVALID_ARGS)


def test_decode_file_null_pointer_arguments_rejected() raises:
    var lib = _lib()
    var n = null_handle()
    var path = WAV_PATH + "\x00"
    var count = [UInt64(0)]
    var frames = [null_handle()]
    # NULL path, NULL frame-count out, NULL frames out.
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_file", Int32](
            n, Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_file", Int32](
            path.as_bytes().unsafe_ptr(), Int32(FMT_F32), UInt32(0), UInt32(0), n, frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_file", Int32](
            path.as_bytes().unsafe_ptr(), Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), n, n, n, n)),
        MA_INVALID_ARGS,
    )
    # The describing out-parameters (format / channels / rate) are optional.
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_file", Int32](
            path.as_bytes().unsafe_ptr(), Int32(FMT_F32), UInt32(0), UInt32(0),
            count.unsafe_ptr(), frames.unsafe_ptr(), n, n, n)),
        MA_SUCCESS,
    )
    assert_equal(count[0], UInt64(WAV_FRAMES))
    raw.decode_free(lib, frames[0])


# ---- ma_decode_memory -------------------------------------------------------


def test_decode_memory_matches_decode_file() raises:
    var lib = _lib()
    var by_file = raw.decode_file(lib, FLAC_PATH, FMT_F32, 0, 0)
    var by_mem = raw.decode_memory(lib, read_file_bytes(FLAC_PATH), FMT_F32, 0, 0)
    assert_equal(by_mem.result, MA_SUCCESS)
    assert_equal(by_mem.frame_count, by_file.frame_count)
    assert_equal(by_mem.format, by_file.format)
    assert_equal(by_mem.channels, by_file.channels)
    assert_equal(by_mem.sample_rate, by_file.sample_rate)
    var a = _f32(by_file.frames, 2 * CODEC_FRAMES)
    var b = _f32(by_mem.frames, 2 * CODEC_FRAMES)
    for i in range(2 * CODEC_FRAMES):
        assert_equal(a[i], b[i])
    raw.decode_free(lib, by_file.frames)
    raw.decode_free(lib, by_mem.frames)


def test_decode_memory_negative() raises:
    var lib = _lib()
    var empty = raw.decode_memory(lib, List[UInt8](), FMT_F32, 0, 0)
    assert_equal(empty.result, MA_INVALID_ARGS)
    assert_true(empty.frames == null_handle())
    var junk = raw.decode_memory(lib, garbage_bytes(512), FMT_F32, 0, 0)
    assert_equal(junk.result, MA_INVALID_FILE)
    assert_true(junk.frames == null_handle())
    assert_equal(raw.decode_memory(lib, read_file_bytes(WAV_PATH), 99, 0, 0).result, MA_INVALID_ARGS)


def test_decode_memory_null_pointer_arguments_rejected() raises:
    var lib = _lib()
    var n = null_handle()
    var data = read_file_bytes(FLAC_PATH)
    var count = [UInt64(0)]
    var frames = [null_handle()]
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_memory", Int32](
            n, len(data), Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_memory", Int32](
            data.unsafe_ptr(), len(data), Int32(FMT_F32), UInt32(0), UInt32(0), n, frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_memory", Int32](
            data.unsafe_ptr(), len(data), Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), n, n, n, n)),
        MA_INVALID_ARGS,
    )


# ---- ma_decode_from_vfs -----------------------------------------------------


def test_decode_from_vfs_matches_decode_file() raises:
    var lib = _lib()
    var vfs = craw.vfs_alloc(lib)
    assert_equal(craw.vfs_init(lib, vfs), MA_SUCCESS)
    var by_vfs = raw.decode_from_vfs(lib, vfs, WAV_PATH, FMT_F32, 0, 0)
    var by_file = raw.decode_file(lib, WAV_PATH, FMT_F32, 0, 0)
    assert_equal(by_vfs.result, MA_SUCCESS)
    assert_equal(by_vfs.frame_count, by_file.frame_count)
    assert_equal(by_vfs.channels, by_file.channels)
    assert_equal(by_vfs.sample_rate, by_file.sample_rate)
    var a = _f32(by_vfs.frames, 2 * 4000)
    var b = _f32(by_file.frames, 2 * 4000)
    for i in range(2 * 4000):
        assert_equal(a[i], b[i])
    raw.decode_free(lib, by_vfs.frames)
    raw.decode_free(lib, by_file.frames)
    craw.vfs_free(lib, vfs)


def test_decode_from_vfs_null_handle_uses_default_filesystem() raises:
    var lib = _lib()
    var d = raw.decode_from_vfs(lib, null_handle(), MP3_PATH, FMT_F32, 0, 0)
    assert_equal(d.result, MA_SUCCESS)
    assert_equal(d.frame_count, UInt64(CODEC_FRAMES))
    raw.decode_free(lib, d.frames)


def test_decode_from_vfs_negative() raises:
    var lib = _lib()
    var vfs = craw.vfs_alloc(lib)
    # An allocated but not yet initialised Vfs handle is refused, not dereferenced.
    var cold = raw.decode_from_vfs(lib, vfs, WAV_PATH, FMT_F32, 0, 0)
    assert_equal(cold.result, MA_INVALID_ARGS)
    assert_true(cold.frames == null_handle())
    assert_equal(craw.vfs_init(lib, vfs), MA_SUCCESS)
    var missing = raw.decode_from_vfs(lib, vfs, MISSING_PATH, FMT_F32, 0, 0)
    assert_equal(missing.result, MA_DOES_NOT_EXIST)
    assert_true(missing.frames == null_handle())
    assert_equal(raw.decode_from_vfs(lib, vfs, WAV_PATH, 99, 0, 0).result, MA_INVALID_ARGS)
    assert_equal(raw.decode_from_vfs(lib, vfs, "", FMT_F32, 0, 0).result, MA_INVALID_ARGS)
    craw.vfs_free(lib, vfs)


def test_decode_from_vfs_null_pointer_arguments_rejected() raises:
    var lib = _lib()
    var n = null_handle()
    var count = [UInt64(0)]
    var frames = [null_handle()]
    var path = WAV_PATH + "\x00"
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_from_vfs", Int32](
            n, n, Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_from_vfs", Int32](
            n, path.as_bytes().unsafe_ptr(), Int32(FMT_F32), UInt32(0), UInt32(0), n, frames.unsafe_ptr(), n, n, n)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_decode_from_vfs", Int32](
            n, path.as_bytes().unsafe_ptr(), Int32(FMT_F32), UInt32(0), UInt32(0), count.unsafe_ptr(), n, n, n, n)),
        MA_INVALID_ARGS,
    )


# ---- ownership --------------------------------------------------------------


def test_decode_free_null_is_noop() raises:
    raw.decode_free(_lib(), null_handle())


def test_decode_free_releases_the_buffer() raises:
    """Each WAV decode fills ~375 KB (94 pages); 25 unreleased buffers would add
    ~2350 resident pages, far over the threshold."""
    var lib = _lib()
    # Warm up allocator / page tables before the baseline.
    for _ in range(3):
        var w = raw.decode_file(lib, WAV_PATH, FMT_F32, 0, 0)
        raw.decode_free(lib, w.frames)
    var before = _resident_pages()
    for _ in range(25):
        var d = raw.decode_file(lib, WAV_PATH, FMT_F32, 0, 0)
        assert_equal(d.result, MA_SUCCESS)
        assert_equal(d.frame_count, UInt64(WAV_FRAMES))
        raw.decode_free(lib, d.frames)
    var grown = _resident_pages() - before
    assert_true(grown < 1000)  # 1000 pages = ~4 MB


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
