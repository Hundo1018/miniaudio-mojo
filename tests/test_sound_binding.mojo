"""TDD contract tests for the sound BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the owning engine runs on the NULL
backend. A sound is initialised against the engine handle (resolved C-side via
shimint_engine_ptr) and exercised across its full control/query surface.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.engine_raw as eraw
import miniaudio._ffi.sound_raw as raw


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_control_query() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_true(snd != null_handle())
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    assert_equal(raw.sound_start(lib, snd), MA_SUCCESS)
    assert_equal(raw.sound_is_playing(lib, snd), 1)
    assert_equal(raw.sound_set_volume(lib, snd, 0.5), MA_SUCCESS)
    assert_true(raw.sound_get_volume(lib, snd) > 0.0)
    assert_equal(raw.sound_set_pan(lib, snd, 0.25), MA_SUCCESS)
    _ = raw.sound_get_pan(lib, snd)
    assert_equal(raw.sound_set_pitch(lib, snd, 1.5), MA_SUCCESS)
    _ = raw.sound_get_pitch(lib, snd)
    assert_equal(raw.sound_set_looping(lib, snd, True), MA_SUCCESS)
    assert_equal(raw.sound_is_looping(lib, snd), 1)
    assert_equal(raw.sound_set_spatialization_enabled(lib, snd, False), MA_SUCCESS)
    assert_equal(raw.sound_is_spatialization_enabled(lib, snd), 0)

    var length = raw.sound_get_length_in_pcm_frames(lib, snd)
    assert_equal(length.result, MA_SUCCESS)
    assert_true(length.value > 0)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, snd, 0), MA_SUCCESS)
    assert_equal(raw.sound_get_cursor_in_pcm_frames(lib, snd).result, MA_SUCCESS)
    _ = raw.sound_at_end(lib, snd)
    assert_equal(raw.sound_stop(lib, snd), MA_SUCCESS)

    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.sound_init_from_file(lib, null_handle(), null_handle(), WAV_PATH, 0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.sound_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.sound_set_volume(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_volume(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_pan(lib, null_handle(), 0.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_pan(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_pitch(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_get_pitch(lib, null_handle()), Float32(0))
    assert_equal(raw.sound_set_looping(lib, null_handle(), True), MA_INVALID_ARGS)
    assert_equal(raw.sound_is_looping(lib, null_handle()), 0)
    assert_equal(raw.sound_is_playing(lib, null_handle()), 0)
    assert_equal(raw.sound_at_end(lib, null_handle()), 0)
    assert_equal(
        raw.sound_set_spatialization_enabled(lib, null_handle(), True), MA_INVALID_ARGS
    )
    assert_equal(raw.sound_is_spatialization_enabled(lib, null_handle()), 0)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(
        raw.sound_get_cursor_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.sound_get_length_in_pcm_frames(lib, null_handle()).result, MA_INVALID_ARGS
    )


def test_init_with_uninitialized_engine_invalid() raises:
    """A null/uninitialised engine handle resolves to NULL -> MA_INVALID_ARGS."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)  # allocated but NOT initialised
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_INVALID_ARGS)
    raw.sound_free(lib, snd)
    eraw.engine_free(lib, eng)


def test_ops_before_init_invalid() raises:
    var lib = _lib()
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_start(lib, snd), MA_INVALID_ARGS)
    assert_equal(raw.sound_set_volume(lib, snd, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.sound_seek_to_pcm_frame(lib, snd, 0), MA_INVALID_ARGS)
    raw.sound_free(lib, snd)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var snd = raw.sound_alloc(lib)
    assert_true(snd != null_handle())
    assert_equal(raw.sound_uninit(lib, snd), MA_SUCCESS)
    raw.sound_free(lib, snd)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.sound_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var snd = raw.sound_alloc(lib)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)
    assert_equal(raw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)  # reinit
    raw.sound_free(lib, snd)  # free initialized
    eraw.engine_free(lib, eng)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
