"""TDD contract tests for the encoder BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: writes WAV files under build/test_assets
and exercises every shim branch (positive write path + all defensive guards) so
the ma_shim.c line-coverage gate stays >= 95%.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.encoder_raw as raw
import miniaudio._ffi.decoder_raw as dec_raw
from miniaudio._ffi.stream_raw import (
    Opaque,
    stream_leak,
    stream_tag,
)
from support.codec_fixtures import read_file_bytes
from support.stream_fixtures import (
    T_WRITES,
    T_SEEKS,
    T_DESTROYED,
    TallyBytes,
    TallySink,
    new_tally,
    tally_ptr,
)


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


# ---- init_stream: ma_encoder_init with a user-supplied write/seek sink -------
#
# The sink is a TallySink (tests/support/stream_fixtures.mojo): a user type that
# implements the sink trait and counts what miniaudio does to it.

comptime REF_PATH = "./build/test_assets/encoder_binding_stream_ref.wav"


def _ramp(frames: Int, channels: Int) -> List[Float32]:
    var buf = List[Float32]()
    for i in range(frames * channels):
        buf.append(Float32(i % 200) / 200.0 - 0.5)
    return buf^


def _sink_of(lib: MaLib, enc: OpaquePointer[MutUntrackedOrigin]) raises -> Pointer[TallySink, MutUntrackedOrigin]:
    """The TallySink behind an encoder handle (checked by its type tag)."""
    var user = raw.encoder_stream_user(lib, enc, stream_tag[TallySink]())
    assert_true(user != null_handle())
    return user.unsafe_bitcast[TallySink]()


def test_init_stream_writes_the_same_bytes_as_init_file() raises:
    var lib = _lib()
    var frames = _ramp(300, 2)

    var f = raw.encoder_alloc(lib)
    assert_equal(raw.encoder_init_file(lib, f, REF_PATH, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(raw.encoder_write_pcm_frames(lib, f, frames, 300).value, UInt64(300))
    assert_equal(raw.encoder_uninit(lib, f), MA_SUCCESS)
    raw.encoder_free(lib, f)
    var want = read_file_bytes(REF_PATH)

    var tally = new_tally()
    var s = raw.encoder_alloc(lib)
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    assert_equal(raw.encoder_init_stream(lib, s, cell, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    var wr = raw.encoder_write_pcm_frames(lib, s, frames, 300)
    assert_equal(wr.result, MA_SUCCESS)
    assert_equal(wr.value, UInt64(300))
    assert_equal(raw.encoder_uninit(lib, s), MA_SUCCESS)
    var got = _sink_of(lib, s)[].data.copy()
    assert_equal(len(got), len(want))
    assert_equal(len(got), 44 + 300 * 2 * 4)  # RIFF header + f32 stereo frames
    var mismatches = 0
    for i in range(len(got)):
        if got[i] != want[i]:
            mismatches += 1
    assert_equal(mismatches, 0)
    assert_true(tally[T_WRITES] > 0)
    raw.encoder_free(lib, s)
    assert_equal(tally[T_DESTROYED], 1)


def test_uninit_patches_the_header_by_seeking_back_and_keeps_the_sink() raises:
    var lib = _lib()
    var tally = new_tally()
    var enc = raw.encoder_alloc(lib)
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    assert_equal(raw.encoder_init_stream(lib, enc, cell, ENC_WAV, FMT_F32, 1, 8000), MA_SUCCESS)
    assert_equal(raw.encoder_write_pcm_frames(lib, enc, _ramp(100, 1), 100).value, UInt64(100))
    var seeks_before = tally[T_SEEKS]
    var before = _sink_of(lib, enc)[].data.copy()
    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)
    assert_true(tally[T_SEEKS] > seeks_before)  # the sizes are patched in place
    var after = _sink_of(lib, enc)[].data.copy()
    assert_equal(len(after), 44 + 100 * 4)
    assert_true(len(before) <= len(after))
    var changed = 0
    for i in range(len(before)):
        if before[i] != after[i]:
            changed += 1
    assert_true(changed > 0)  # the header differs once it carries the real sizes
    # the encoder is gone, the sink is not: nothing more can be written
    assert_equal(raw.encoder_write_pcm_frames(lib, enc, _ramp(4, 1), 4).result, MA_INVALID_ARGS)
    assert_equal(tally[T_DESTROYED], 0)
    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)  # idempotent
    raw.encoder_free(lib, enc)
    assert_equal(tally[T_DESTROYED], 1)


def test_sink_output_decodes_back_to_the_frames_written() raises:
    var lib = _lib()
    var frames = _ramp(250, 2)
    var tally = new_tally()
    var enc = raw.encoder_alloc(lib)
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    assert_equal(raw.encoder_init_stream(lib, enc, cell, ENC_WAV, FMT_F32, 2, 22050), MA_SUCCESS)
    _ = raw.encoder_write_pcm_frames(lib, enc, frames, 250)
    assert_equal(raw.encoder_uninit(lib, enc), MA_SUCCESS)
    var bytes = _sink_of(lib, enc)[].data.copy()
    var dec = dec_raw.decoder_alloc(lib)
    assert_equal(dec_raw.decoder_init_memory(lib, dec, bytes, FMT_F32, 0, 0), MA_SUCCESS)
    assert_equal(dec_raw.decoder_output_channels(lib, dec), UInt32(2))
    assert_equal(dec_raw.decoder_output_sample_rate(lib, dec), UInt32(22050))
    assert_equal(dec_raw.decoder_get_length_in_pcm_frames(lib, dec).value, UInt64(250))
    var back = _silence(250, 2)
    assert_equal(dec_raw.decoder_read_pcm_frames(lib, dec, back, 250).value, UInt64(250))
    for i in range(250 * 2):
        assert_equal(back[i], frames[i])  # f32 in, f32 out: lossless
    dec_raw.decoder_free(lib, dec)
    raw.encoder_free(lib, enc)
    assert_equal(len(bytes), 44 + 250 * 2 * 4)  # (the decoder reads `bytes` in place)
    assert_equal(tally[T_DESTROYED], 1)


def test_a_sink_failing_while_the_header_is_written_goes_unnoticed_by_init() raises:
    """Pinned upstream quirk: dr_wav ignores the results of the header writes, so a
    sink that raises on its very first write does not make init fail."""
    var lib = _lib()
    var enc = raw.encoder_alloc(lib)
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally), fail_write_at=1))
    assert_equal(raw.encoder_init_stream(lib, enc, cell, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(tally[T_DESTROYED], 0)
    raw.encoder_free(lib, enc)
    assert_equal(tally[T_DESTROYED], 1)


def test_a_sink_that_fails_midway_surfaces_as_a_short_write() raises:
    """Pinned upstream behaviour: miniaudio's WAV encoder reports MA_SUCCESS and
    tells a failed write only by the frames-written count."""
    var lib = _lib()
    var tally = new_tally()
    var enc = raw.encoder_alloc(lib)
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    assert_equal(raw.encoder_init_stream(lib, enc, cell, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(raw.encoder_write_pcm_frames(lib, enc, _ramp(10, 2), 10).result, MA_SUCCESS)
    cell[].fail_write_at = tally[T_WRITES] + 1  # the next write call raises
    var wr = raw.encoder_write_pcm_frames(lib, enc, _ramp(10, 2), 10)
    assert_equal(wr.result, MA_SUCCESS)
    assert_equal(wr.value, UInt64(0))  # nothing of the failed write counts
    raw.encoder_free(lib, enc)
    assert_equal(tally[T_DESTROYED], 1)


def test_init_stream_rejects_bad_arguments() raises:
    var lib = _lib()
    var t = new_tally()
    var enc = raw.encoder_alloc(lib)
    # each of these consumes (destroys) the sink it was given
    var c1 = stream_leak(TallySink(tally_ptr(t)))
    assert_equal(raw.encoder_init_stream(lib, null_handle(), c1, ENC_WAV, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 1)
    var c2 = stream_leak(TallySink(tally_ptr(t)))
    assert_equal(raw.encoder_init_stream(lib, enc, c2, 999, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 2)
    var c3 = stream_leak(TallySink(tally_ptr(t)))
    assert_equal(raw.encoder_init_stream(lib, enc, c3, ENC_WAV, 999, 2, 8000), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 3)
    var c4 = stream_leak(TallySink(tally_ptr(t)))  # miniaudio itself refuses zero channels
    assert_equal(raw.encoder_init_stream(lib, enc, c4, ENC_WAV, FMT_F32, 0, 8000), MA_INVALID_ARGS)
    assert_equal(t[T_DESTROYED], 4)
    # null callbacks / user pointer, passed bare (never called: the shim refuses first)
    var fake = Opaque(unsafe_from_address=Int(4096))
    var none = null_handle()
    assert_equal(raw.encoder_init_stream_ptrs(lib, enc, none, fake, none, fake, 1, ENC_WAV, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    assert_equal(raw.encoder_init_stream_ptrs(lib, enc, fake, none, none, fake, 1, ENC_WAV, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    assert_equal(raw.encoder_init_stream_ptrs(lib, enc, fake, fake, none, none, 1, ENC_WAV, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    assert_equal(raw.encoder_init_stream_ptrs(lib, null_handle(), fake, fake, none, fake, 1, ENC_WAV, FMT_F32, 2, 8000), MA_INVALID_ARGS)
    # none of that left the handle usable
    assert_equal(raw.encoder_write_pcm_frames(lib, enc, _ramp(4, 2), 4).result, MA_INVALID_ARGS)
    raw.encoder_free(lib, enc)
    assert_equal(t[T_DESTROYED], 4)


def test_stream_user_hands_back_the_sink_only_for_its_type() raises:
    var lib = _lib()
    var tally = new_tally()
    var enc = raw.encoder_alloc(lib)
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    assert_equal(raw.encoder_init_stream(lib, enc, cell, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(Int(raw.encoder_stream_user(lib, enc, stream_tag[TallySink]())), Int(cell))
    assert_equal(Int(raw.encoder_stream_user(lib, enc, stream_tag[TallyBytes]())), 0)  # another type
    assert_equal(Int(raw.encoder_stream_user(lib, null_handle(), stream_tag[TallySink]())), 0)
    # an encoder writing to a file has no sink
    var f = raw.encoder_alloc(lib)
    assert_equal(raw.encoder_init_file(lib, f, REF_PATH, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(Int(raw.encoder_stream_user(lib, f, stream_tag[TallySink]())), 0)
    raw.encoder_free(lib, f)
    raw.encoder_free(lib, enc)
    assert_equal(tally[T_DESTROYED], 1)


def test_reinit_destroys_the_previous_sink_exactly_once() raises:
    var lib = _lib()
    var ta = new_tally()
    var tb = new_tally()
    var enc = raw.encoder_alloc(lib)
    var a = stream_leak(TallySink(tally_ptr(ta)))
    assert_equal(raw.encoder_init_stream(lib, enc, a, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    var b = stream_leak(TallySink(tally_ptr(tb)))
    assert_equal(raw.encoder_init_stream(lib, enc, b, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(ta[T_DESTROYED], 1)  # replaced
    assert_equal(tb[T_DESTROYED], 0)
    assert_equal(raw.encoder_init_file(lib, enc, REF_PATH, ENC_WAV, FMT_F32, 2, 8000), MA_SUCCESS)
    assert_equal(tb[T_DESTROYED], 1)  # replaced by a file encoder
    assert_equal(Int(raw.encoder_stream_user(lib, enc, stream_tag[TallySink]())), 0)
    raw.encoder_free(lib, enc)
    assert_equal(ta[T_DESTROYED], 1)
    assert_equal(tb[T_DESTROYED], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
