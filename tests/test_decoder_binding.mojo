"""TDD contract tests for the decoder BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: uses an embedded in-memory WAV and a
generated WAV file (build/test_assets/sine_440_stereo.wav).
"""

from std.testing import assert_equal, assert_true, TestSuite
from miniaudio.result import MaResult

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_INVALID_ARGS
import miniaudio._ffi.decoder_raw as raw
from miniaudio._ffi.stream_raw import (
    Opaque,
    stream_leak,
    stream_tag,
    stream_null_ptr,
)
from support.wav_fixtures import embedded_wav_stereo_2frames
from support.codec_fixtures import (
    read_file_bytes,
    garbage_bytes,
    MA_INVALID_FILE,
)
from support.stream_fixtures import (
    T_READS,
    T_SEEKS,
    T_DESTROYED,
    TallyBytes,
    TallySink,
    new_tally,
    tally_ptr,
)


comptime FMT_F32 = 5
comptime FMT_S16 = 2  # native format of the generated test WAV (16-bit PCM)
comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> MaLib:
    return MaLib.default()


def test_version_nonempty() raises:
    var lib = _lib()
    assert_true(lib.version().byte_length() > 0)


def test_result_description_nonempty() raises:
    var lib = _lib()
    assert_true(lib.result_description(MaResult.SUCCESS).byte_length() > 0)


def test_init_memory_read_seek_query() raises:
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_true(dec != null_handle())

    var data = embedded_wav_stereo_2frames()
    assert_equal(raw.decoder_init_memory(lib, dec, data, FMT_F32, 2, 8000), MA_SUCCESS)

    var length = raw.decoder_get_length_in_pcm_frames(lib, dec)
    assert_equal(length.result, MA_SUCCESS)
    assert_true(length.value >= 1)

    var buf = List[Float32]()
    buf.resize(2 * 2, Float32(0))
    var rr = raw.decoder_read_pcm_frames(lib, dec, buf, 2)
    assert_true(rr.result == MA_SUCCESS or rr.result == MA_AT_END)
    assert_true(rr.value >= 1)

    assert_equal(raw.decoder_seek_to_pcm_frame(lib, dec, 0), MA_SUCCESS)
    var cursor = raw.decoder_get_cursor_in_pcm_frames(lib, dec)
    assert_equal(cursor.result, MA_SUCCESS)
    assert_equal(cursor.value, UInt64(0))

    assert_equal(raw.decoder_output_channels(lib, dec), UInt32(2))
    assert_equal(raw.decoder_output_sample_rate(lib, dec), UInt32(8000))
    assert_equal(raw.decoder_output_format(lib, dec), FMT_F32)

    assert_equal(raw.decoder_uninit(lib, dec), MA_SUCCESS)
    raw.decoder_free(lib, dec)


def test_init_file_and_read() raises:
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_equal(raw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)

    var buf = List[Float32]()
    buf.resize(1024 * 2, Float32(0))
    var rr = raw.decoder_read_pcm_frames(lib, dec, buf, 1024)
    assert_true(rr.result == MA_SUCCESS or rr.result == MA_AT_END)
    assert_true(rr.value > 0)

    assert_equal(raw.decoder_uninit(lib, dec), MA_SUCCESS)
    raw.decoder_free(lib, dec)


def test_init_file_missing_fails() raises:
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_true(
        raw.decoder_init_file(lib, dec, "/tmp/mmj-does-not-exist.wav", FMT_F32, 2, 48000)
        != MA_SUCCESS
    )
    raw.decoder_free(lib, dec)


def test_invalid_format_code_rejected() raises:
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    var data = embedded_wav_stereo_2frames()
    assert_equal(raw.decoder_init_memory(lib, dec, data, 999, 2, 8000), MA_INVALID_ARGS)
    raw.decoder_free(lib, dec)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(raw.decoder_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.decoder_seek_to_pcm_frame(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(
        raw.decoder_get_length_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )
    # Remaining null-handle paths
    assert_equal(raw.decoder_init_file(lib, null_handle(), WAV_PATH, FMT_F32, 2, 48000), MA_INVALID_ARGS)
    assert_equal(
        raw.decoder_get_cursor_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )
    assert_equal(raw.decoder_output_channels(lib, null_handle()), UInt32(0))
    assert_equal(raw.decoder_output_sample_rate(lib, null_handle()), UInt32(0))
    assert_equal(raw.decoder_output_format(lib, null_handle()), 0)


def test_free_null_handle_is_noop() raises:
    """Freeing a null handle must be a safe no-op (C guard: if h == NULL return)."""
    var lib = _lib()
    raw.decoder_free(lib, null_handle())  # must not crash


def test_uninit_uninitialized_handle_is_success() raises:
    """Uninit on allocated-but-not-initialized handle returns MA_SUCCESS (early exit)."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_true(dec != null_handle())
    assert_equal(raw.decoder_uninit(lib, dec), MA_SUCCESS)
    raw.decoder_free(lib, dec)


def test_init_memory_empty_data_invalid() raises:
    """init_memory with zero-length data returns MA_INVALID_ARGS (data_size==0 guard)."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    var empty = List[UInt8]()
    assert_equal(raw.decoder_init_memory(lib, dec, empty, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    raw.decoder_free(lib, dec)


def test_reinit_same_handle_resets_state() raises:
    """Re-init an already-initialized handle: shim auto-uninits the previous decoder."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    # First init
    assert_equal(raw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    # Second init on the same handle: shim must uninit first (lines 78-79 in shim)
    assert_equal(raw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    var cursor = raw.decoder_get_cursor_in_pcm_frames(lib, dec)
    assert_equal(cursor.result, MA_SUCCESS)
    assert_equal(cursor.value, UInt64(0))
    raw.decoder_free(lib, dec)


def test_reinit_memory_on_initialized_handle() raises:
    """Re-init via init_memory on already-initialized handle: shim auto-uninits first (lines 111-112)."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    # First init from file
    assert_equal(raw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    # Re-init from memory (shim must uninit old decoder first)
    var data = embedded_wav_stereo_2frames()
    assert_equal(raw.decoder_init_memory(lib, dec, data, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(raw.decoder_output_sample_rate(lib, dec), UInt32(8000))
    raw.decoder_free(lib, dec)


def test_init_file_default_preserves_native_format() raises:
    """init_file_default: default config preserves the file's native format (S16)."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_equal(raw.decoder_init_file_default(lib, dec, WAV_PATH), MA_SUCCESS)
    # Default config = native format; the test WAV is 16-bit PCM stereo @ 48kHz.
    assert_equal(raw.decoder_output_channels(lib, dec), UInt32(2))
    assert_equal(raw.decoder_output_sample_rate(lib, dec), UInt32(48000))
    assert_equal(raw.decoder_output_format(lib, dec), FMT_S16)
    raw.decoder_free(lib, dec)


def test_init_file_default_negative_and_reinit() raises:
    """init_file_default: null handle, missing file, and re-init auto-uninit branch."""
    var lib = _lib()
    assert_equal(raw.decoder_init_file_default(lib, null_handle(), WAV_PATH), MA_INVALID_ARGS)

    var dec = raw.decoder_alloc(lib)
    assert_true(
        raw.decoder_init_file_default(lib, dec, "/tmp/mmj-does-not-exist.wav") != MA_SUCCESS
    )
    # Re-init on the same handle: shim must uninit the previous decoder first.
    assert_equal(raw.decoder_init_file_default(lib, dec, WAV_PATH), MA_SUCCESS)
    assert_equal(raw.decoder_init_file_default(lib, dec, WAV_PATH), MA_SUCCESS)
    raw.decoder_free(lib, dec)


def test_init_file_vfs_positive() raises:
    """init_file_vfs: NULL-VFS path decodes a file like init_file (default VFS)."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_equal(
        raw.decoder_init_file_vfs(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS
    )
    var buf = List[Float32]()
    buf.resize(256 * 2, Float32(0))
    var rr = raw.decoder_read_pcm_frames(lib, dec, buf, 256)
    assert_true(rr.result == MA_SUCCESS or rr.result == MA_AT_END)
    assert_true(rr.value > 0)
    assert_equal(raw.decoder_output_channels(lib, dec), UInt32(2))
    raw.decoder_free(lib, dec)


def test_init_file_vfs_negative_and_reinit() raises:
    """init_file_vfs: null handle, invalid format, missing file, and re-init branch."""
    var lib = _lib()
    assert_equal(
        raw.decoder_init_file_vfs(lib, null_handle(), WAV_PATH, FMT_F32, 2, 48000),
        MA_INVALID_ARGS,
    )
    var dec = raw.decoder_alloc(lib)
    assert_equal(
        raw.decoder_init_file_vfs(lib, dec, WAV_PATH, 999, 2, 48000), MA_INVALID_ARGS
    )
    assert_true(
        raw.decoder_init_file_vfs(lib, dec, "/tmp/mmj-does-not-exist.wav", FMT_F32, 2, 48000)
        != MA_SUCCESS
    )
    assert_equal(
        raw.decoder_init_file_vfs(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS
    )
    # Re-init on the same initialized handle: shim uninits first.
    assert_equal(
        raw.decoder_init_file_vfs(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS
    )
    raw.decoder_free(lib, dec)


def test_get_available_frames() raises:
    """get_available_frames: equals length at cursor 0, decreases after a read."""
    var lib = _lib()
    var dec = raw.decoder_alloc(lib)
    assert_equal(raw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)

    var length = raw.decoder_get_length_in_pcm_frames(lib, dec)
    assert_equal(length.result, MA_SUCCESS)
    var avail0 = raw.decoder_get_available_frames(lib, dec)
    assert_equal(avail0.result, MA_SUCCESS)
    assert_equal(avail0.value, length.value)

    var buf = List[Float32]()
    buf.resize(128 * 2, Float32(0))
    _ = raw.decoder_read_pcm_frames(lib, dec, buf, 128)
    var avail1 = raw.decoder_get_available_frames(lib, dec)
    assert_equal(avail1.result, MA_SUCCESS)
    assert_true(avail1.value < avail0.value)
    raw.decoder_free(lib, dec)


def test_get_available_frames_invalid() raises:
    """get_available_frames: null handle and before-init both return MA_INVALID_ARGS."""
    var lib = _lib()
    assert_equal(raw.decoder_get_available_frames(lib, null_handle()).result, MA_INVALID_ARGS)
    var dec = raw.decoder_alloc(lib)
    # Allocated but not initialized -> !initialized guard.
    assert_equal(raw.decoder_get_available_frames(lib, dec).result, MA_INVALID_ARGS)
    raw.decoder_free(lib, dec)


# ---- init_stream: ma_decoder_init with a user-supplied read/seek stream ------
#
# The stream is a TallyBytes (tests/support/stream_fixtures.mojo): a user type
# that implements the stream trait and counts what miniaudio does to it.


def _stream_decoder(
    lib: MaLib, mut tally: List[Int], data: List[UInt8]
) raises -> OpaquePointer[MutUntrackedOrigin]:
    var dec = raw.decoder_alloc(lib)
    var cell = stream_leak(TallyBytes(data.copy(), tally_ptr(tally)))
    assert_equal(raw.decoder_init_stream(lib, dec, cell, FMT_F32, 0, 0), MA_SUCCESS)
    return dec


def _memory_decoder(lib: MaLib, data: List[UInt8]) raises -> OpaquePointer[MutUntrackedOrigin]:
    var dec = raw.decoder_alloc(lib)
    assert_equal(raw.decoder_init_memory(lib, dec, data, FMT_F32, 0, 0), MA_SUCCESS)
    return dec


def _zeros(n: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(n, Float32(0))
    return buf^


def test_init_stream_decodes_like_init_memory() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var tally = new_tally()
    var s = _stream_decoder(lib, tally, data)
    var m = _memory_decoder(lib, data)
    assert_equal(raw.decoder_output_channels(lib, s), raw.decoder_output_channels(lib, m))
    assert_equal(raw.decoder_output_sample_rate(lib, s), raw.decoder_output_sample_rate(lib, m))
    assert_equal(raw.decoder_output_format(lib, s), FMT_F32)
    assert_equal(raw.decoder_get_length_in_pcm_frames(lib, s).value, UInt64(48000))
    var a = _zeros(2 * 1024)
    var b = _zeros(2 * 1024)
    assert_equal(raw.decoder_read_pcm_frames(lib, s, a, 1024).value, UInt64(1024))
    assert_equal(raw.decoder_read_pcm_frames(lib, m, b, 1024).value, UInt64(1024))
    for i in range(2 * 1024):
        assert_equal(a[i], b[i])
    assert_true(tally[T_READS] > 0)  # the bytes really came through the user's read
    raw.decoder_free(lib, s)
    raw.decoder_free(lib, m)
    assert_equal(tally[T_DESTROYED], 1)


def test_seek_goes_through_the_stream_callback() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var tally = new_tally()
    var s = _stream_decoder(lib, tally, data)
    var m = _memory_decoder(lib, data)
    var seeks_before = tally[T_SEEKS]
    assert_equal(raw.decoder_seek_to_pcm_frame(lib, s, 24000), MA_SUCCESS)
    assert_equal(raw.decoder_seek_to_pcm_frame(lib, m, 24000), MA_SUCCESS)
    assert_true(tally[T_SEEKS] > seeks_before)
    var a = _zeros(2 * 256)
    var b = _zeros(2 * 256)
    assert_equal(raw.decoder_read_pcm_frames(lib, s, a, 256).value, UInt64(256))
    assert_equal(raw.decoder_read_pcm_frames(lib, m, b, 256).value, UInt64(256))
    for i in range(2 * 256):
        assert_equal(a[i], b[i])
    assert_equal(raw.decoder_get_cursor_in_pcm_frames(lib, s).value, UInt64(24256))
    raw.decoder_free(lib, s)
    raw.decoder_free(lib, m)
    assert_equal(tally[T_DESTROYED], 1)


def test_init_stream_fails_when_the_stream_fails_and_still_destroys_it_once() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var dec = raw.decoder_alloc(lib)

    # a read that raises: no backend can parse anything
    var t1 = new_tally()
    var c1 = stream_leak(TallyBytes(data.copy(), tally_ptr(t1), fail_read_at=1))
    # miniaudio's verdict on a stream it cannot parse, whatever went wrong: the last backend's
    assert_equal(raw.decoder_init_stream(lib, dec, c1, FMT_F32, 0, 0), MA_INVALID_FILE)
    assert_equal(t1[T_DESTROYED], 1)  # consumed on failure, before any free
    var buf = _zeros(8)
    assert_equal(raw.decoder_read_pcm_frames(lib, dec, buf, 4).result, MA_INVALID_ARGS)

    # a seek that raises
    var t2 = new_tally()
    var c2 = stream_leak(TallyBytes(data.copy(), tally_ptr(t2), fail_seek=True))
    assert_true(raw.decoder_init_stream(lib, dec, c2, FMT_F32, 0, 0) != MA_SUCCESS)
    assert_equal(t2[T_DESTROYED], 1)

    # not audio at all
    var t3 = new_tally()
    var c3 = stream_leak(TallyBytes(garbage_bytes(4096), tally_ptr(t3)))
    assert_equal(raw.decoder_init_stream(lib, dec, c3, FMT_F32, 0, 0), MA_INVALID_FILE)
    assert_equal(t3[T_DESTROYED], 1)

    raw.decoder_free(lib, dec)
    assert_equal(t1[T_DESTROYED], 1)  # freeing the handle does not destroy it again
    assert_equal(t2[T_DESTROYED], 1)
    assert_equal(t3[T_DESTROYED], 1)


def test_init_stream_rejects_bad_arguments() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var t = new_tally()
    # a null handle: still consumes (destroys) the stream
    var c1 = stream_leak(TallyBytes(data.copy(), tally_ptr(t)))
    assert_equal(raw.decoder_init_stream(lib, null_handle(), c1, FMT_F32, 0, 0), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 1)
    # an out-of-range format code
    var dec = raw.decoder_alloc(lib)
    var c2 = stream_leak(TallyBytes(data.copy(), tally_ptr(t)))
    assert_equal(raw.decoder_init_stream(lib, dec, c2, 99, 0, 0), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 2)
    # null callbacks / user pointer, passed bare (never called: the shim refuses first)
    var fake = Opaque(unsafe_from_address=Int(4096))
    var none = null_handle()
    assert_equal(raw.decoder_init_stream_ptrs(lib, dec, none, fake, none, fake, 1, FMT_F32, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.decoder_init_stream_ptrs(lib, dec, fake, none, none, fake, 1, FMT_F32, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.decoder_init_stream_ptrs(lib, dec, fake, fake, none, none, 1, FMT_F32, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.decoder_init_stream_ptrs(lib, null_handle(), fake, fake, none, fake, 1, FMT_F32, 0, 0), MA_INVALID_ARGS)
    # none of that left the handle usable
    var buf = _zeros(8)
    assert_equal(raw.decoder_read_pcm_frames(lib, dec, buf, 4).result, MA_INVALID_ARGS)
    raw.decoder_free(lib, dec)
    assert_equal(t[T_DESTROYED], 2)


def test_stream_user_hands_back_the_stream_only_for_its_type() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var tally = new_tally()
    var dec = raw.decoder_alloc(lib)
    var cell = stream_leak(TallyBytes(data.copy(), tally_ptr(tally)))
    assert_equal(raw.decoder_init_stream(lib, dec, cell, FMT_F32, 0, 0), MA_SUCCESS)
    assert_equal(Int(raw.decoder_stream_user(lib, dec, stream_tag[TallyBytes]())), Int(cell))
    assert_equal(Int(raw.decoder_stream_user(lib, dec, stream_tag[TallySink]())), 0)  # another type
    assert_equal(Int(raw.decoder_stream_user(lib, null_handle(), stream_tag[TallyBytes]())), 0)
    # a decoder opened from a file or memory has no stream
    var f = raw.decoder_alloc(lib)
    assert_equal(raw.decoder_init_file(lib, f, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    assert_equal(Int(raw.decoder_stream_user(lib, f, stream_tag[TallyBytes]())), 0)
    raw.decoder_free(lib, f)
    raw.decoder_free(lib, dec)
    assert_equal(tally[T_DESTROYED], 1)


def test_uninit_keeps_the_stream_until_the_handle_is_freed() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var tally = new_tally()
    var dec = raw.decoder_alloc(lib)
    var cell = stream_leak(TallyBytes(data.copy(), tally_ptr(tally)))
    assert_equal(raw.decoder_init_stream(lib, dec, cell, FMT_F32, 0, 0), MA_SUCCESS)
    assert_equal(raw.decoder_uninit(lib, dec), MA_SUCCESS)
    var buf = _zeros(8)
    assert_equal(raw.decoder_read_pcm_frames(lib, dec, buf, 4).result, MA_INVALID_ARGS)
    assert_equal(tally[T_DESTROYED], 0)  # the decoder is gone, the stream is not
    assert_equal(Int(raw.decoder_stream_user(lib, dec, stream_tag[TallyBytes]())), Int(cell))
    assert_equal(raw.decoder_uninit(lib, dec), MA_SUCCESS)  # idempotent
    assert_equal(tally[T_DESTROYED], 0)
    raw.decoder_free(lib, dec)
    assert_equal(tally[T_DESTROYED], 1)


def test_reinit_destroys_the_previous_stream_exactly_once() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var ta = new_tally()
    var tb = new_tally()
    var dec = raw.decoder_alloc(lib)
    var a = stream_leak(TallyBytes(data.copy(), tally_ptr(ta)))
    assert_equal(raw.decoder_init_stream(lib, dec, a, FMT_F32, 0, 0), MA_SUCCESS)
    var b = stream_leak(TallyBytes(data.copy(), tally_ptr(tb)))
    assert_equal(raw.decoder_init_stream(lib, dec, b, FMT_F32, 0, 0), MA_SUCCESS)
    assert_equal(ta[T_DESTROYED], 1)  # replaced
    assert_equal(tb[T_DESTROYED], 0)
    assert_equal(Int(raw.decoder_stream_user(lib, dec, stream_tag[TallyBytes]())), Int(b))
    assert_equal(raw.decoder_init_memory(lib, dec, data, FMT_F32, 0, 0), MA_SUCCESS)
    assert_equal(tb[T_DESTROYED], 1)  # replaced by a memory decoder
    assert_equal(Int(raw.decoder_stream_user(lib, dec, stream_tag[TallyBytes]())), 0)
    raw.decoder_free(lib, dec)
    assert_equal(ta[T_DESTROYED], 1)
    assert_equal(tb[T_DESTROYED], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
