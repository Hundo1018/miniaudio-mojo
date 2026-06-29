"""TDD contract tests for the device BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: every device runs on miniaudio's NULL
backend (use_null_backend=True), which drives the shim-owned data callback on a
real-time timer thread with no audio hardware. The callback pulls f32 PCM from a
decoder, so we assert observable progress (frames_processed + decoder cursor).
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.decoder_raw as draw
import miniaudio._ffi.device_raw as raw
from support.wav_fixtures import embedded_wav_stereo_2frames


comptime FMT_F32 = 5
comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> MaLib:
    return MaLib.default()


def test_playback_pulls_from_decoder() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)

    var dev = raw.device_alloc(lib)
    assert_true(dev != null_handle())
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    assert_equal(raw.device_get_channels(lib, dev), UInt32(2))
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(48000))

    assert_equal(raw.device_start(lib, dev), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_equal(raw.device_stop(lib, dev), MA_SUCCESS)

    # The null backend drove the callback -> frames flowed and the decoder advanced.
    assert_true(raw.device_get_frames_processed(lib, dev) > 0)
    assert_true(draw.decoder_get_cursor_in_pcm_frames(lib, dec).value > 0)

    assert_equal(raw.device_uninit(lib, dev), MA_SUCCESS)
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_eof_tail_is_zero_filled() raises:
    """Source shorter than one period: callback zero-fills the tail (coverage)."""
    var lib = _lib()
    var data = embedded_wav_stereo_2frames()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_memory(lib, dec, data, FMT_F32, 2, 8000), MA_SUCCESS)

    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    assert_equal(raw.device_start(lib, dev), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_equal(raw.device_stop(lib, dev), MA_SUCCESS)

    # The 2 source frames are read once; later callbacks read 0 (tail zeroed).
    assert_true(raw.device_get_frames_processed(lib, dev) >= 1)

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)
    _ = data  # keep the backing bytes alive until after playback


def test_null_device_ops_invalid_args() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, null_handle(), dec, 0, True),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.device_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_get_channels(lib, null_handle()), UInt32(0))
    assert_equal(raw.device_get_sample_rate(lib, null_handle()), UInt32(0))
    assert_equal(raw.device_get_frames_processed(lib, null_handle()), UInt64(0))
    draw.decoder_free(lib, dec)


def test_init_with_null_decoder_invalid() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, null_handle(), 0, True),
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)


def test_init_with_uninitialized_decoder_invalid() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)  # allocated but not initialised
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True),
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_start_stop_before_init_invalid() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_equal(raw.device_start(lib, dev), MA_INVALID_ARGS)
    assert_equal(raw.device_stop(lib, dev), MA_INVALID_ARGS)
    raw.device_free(lib, dev)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_true(dev != null_handle())
    assert_equal(raw.device_uninit(lib, dev), MA_SUCCESS)
    raw.device_free(lib, dev)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.device_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    """Re-init auto-uninits the previous device; then free an initialized handle."""
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    # Re-init on the same handle (with a sample-rate override): shim uninits first.
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 22050, True), MA_SUCCESS
    )
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(22050))
    # Free an initialised device without an explicit uninit.
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
