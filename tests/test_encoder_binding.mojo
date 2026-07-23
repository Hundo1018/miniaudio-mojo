"""TDD contract tests for the encoder BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: writes WAV files under build/test_assets
and exercises every shim branch (positive write path + all defensive guards) so
the ma_shim.c line-coverage gate stays >= 95%.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.encoder_raw as raw


comptime FMT_F32 = 5
comptime ENC_WAV = 1
comptime OUT_PATH = "./build/test_assets/encoder_binding_test.wav"
comptime BAD_PATH = "/tmp/mmj-no-such-dir-xyz/encoder_out.wav"


def _lib() raises -> MaLib:
    return MaLib.default()


def _silence(frames: Int, channels: Int) -> List[Float32]:
    var buf = List[Float32]()
    buf.resize(frames * channels, Float32(0))
    return buf^


def test_init_file_write_uninit() raises:
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_true(enc != null_handle())

    assert_equal(
        raw.encoder_init_file(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_SUCCESS,
    )

    var frames = _silence(8, 2)
    var wr = raw.encoder_write_pcm_frames(lib, enc, frames, 8)
    assert_equal(wr.result, MA_SUCCESS)
    assert_equal(wr.value, UInt64(8))

    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)
    raw.encoder_free(lib, enc)


def test_invalid_encoding_format_rejected() raises:
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_equal(
        raw.encoder_init_file(lib, enc, OUT_PATH, 999, FMT_F32, 2, 8000),
        MA_INVALID_ARGS,
    )
    raw.encoder_free(lib, enc)


def test_invalid_sample_format_rejected() raises:
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_equal(
        raw.encoder_init_file(lib, enc, OUT_PATH, ENC_WAV, 999, 2, 8000),
        MA_INVALID_ARGS,
    )
    raw.encoder_free(lib, enc)


def test_init_file_bad_path_fails() raises:
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    # Init into a non-existent directory: miniaudio fails to open the file.
    # Leaves the handle uninitialized -> free() takes its !initialized branch.
    assert_true(
        raw.encoder_init_file(lib, enc, BAD_PATH, ENC_WAV, FMT_F32, 2, 8000)
        != MA_SUCCESS
    )
    raw.encoder_free(lib, enc)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.encoder_init_file(lib, null_handle(), OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.encoder_uninit(lib, null_handle()), MA_INVALID_ARGS)
    var frames = _silence(2, 2)
    assert_equal(
        raw.encoder_write_pcm_frames(lib, null_handle(), frames, 2).result,
        MA_INVALID_ARGS,
    )


def test_free_null_handle_is_noop() raises:
    """Freeing a null handle must be a safe no-op (C guard: if h == NULL return)."""
    var lib = _lib()
    raw.encoder_free(lib, null_handle())  # must not crash


def test_uninit_uninitialized_handle_is_success() raises:
    """Uninit on allocated-but-not-initialized handle returns MA_SUCCESS."""
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_true(enc != null_handle())
    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)
    raw.encoder_free(lib, enc)


def test_write_before_init_invalid() raises:
    """Writing before init returns MA_INVALID_ARGS (!initialized guard)."""
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    var frames = _silence(2, 2)
    assert_equal(
        raw.encoder_write_pcm_frames(lib, enc, frames, 2).result, MA_INVALID_ARGS
    )
    raw.encoder_free(lib, enc)


def test_reinit_resets_and_free_initialized() raises:
    """Re-init auto-uninits the previous encoder; then free an initialized handle.

    Exercises the init_file re-init branch (h->initialized) and the
    encoder_free initialized branch (free without a preceding uninit).
    """
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_equal(
        raw.encoder_init_file(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_SUCCESS,
    )
    # Re-init on the same handle: shim must uninit the previous encoder first.
    assert_equal(
        raw.encoder_init_file(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 1, 44100),
        MA_SUCCESS,
    )
    # Free without an explicit uninit -> free's initialized-true branch runs.
    raw.encoder_free(lib, enc)


def test_init_file_vfs_write_uninit() raises:
    """init_file_vfs: NULL-VFS path writes a WAV like init_file (default VFS)."""
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    assert_true(enc != null_handle())
    assert_equal(
        raw.encoder_init_file_vfs(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_SUCCESS,
    )
    var frames = _silence(8, 2)
    var wr = raw.encoder_write_pcm_frames(lib, enc, frames, 8)
    assert_equal(wr.result, MA_SUCCESS)
    assert_equal(wr.value, UInt64(8))
    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)
    raw.encoder_free(lib, enc)


def test_init_file_vfs_negative_and_reinit() raises:
    """init_file_vfs: null handle, bad encoding/format, bad path, and re-init branch."""
    var lib = _lib()
    assert_equal(
        raw.encoder_init_file_vfs(lib, null_handle(), OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_INVALID_ARGS,
    )
    var enc = raw.encoder_alloc(lib)
    assert_equal(
        raw.encoder_init_file_vfs(lib, enc, OUT_PATH, 999, FMT_F32, 2, 8000),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.encoder_init_file_vfs(lib, enc, OUT_PATH, ENC_WAV, 999, 2, 8000),
        MA_INVALID_ARGS,
    )
    assert_true(
        raw.encoder_init_file_vfs(lib, enc, BAD_PATH, ENC_WAV, FMT_F32, 2, 8000)
        != MA_SUCCESS
    )
    assert_equal(
        raw.encoder_init_file_vfs(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 2, 8000),
        MA_SUCCESS,
    )
    # Re-init on the same initialized handle: shim uninits the previous encoder first.
    assert_equal(
        raw.encoder_init_file_vfs(lib, enc, OUT_PATH, ENC_WAV, FMT_F32, 1, 44100),
        MA_SUCCESS,
    )
    raw.encoder_free(lib, enc)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
