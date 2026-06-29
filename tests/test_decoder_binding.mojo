"""TDD contract tests for the decoder BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: uses an embedded in-memory WAV and a
generated WAV file (build/test_assets/sine_440_stereo.wav).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_INVALID_ARGS
import miniaudio._ffi.decoder_raw as raw
from support.wav_fixtures import embedded_wav_stereo_2frames


comptime FMT_F32 = 5
comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> MaLib:
    return MaLib.default()


def test_version_nonempty() raises:
    var lib = _lib()
    assert_true(lib.version().byte_length() > 0)


def test_result_description_nonempty() raises:
    var lib = _lib()
    assert_true(lib.result_description(0).byte_length() > 0)


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
