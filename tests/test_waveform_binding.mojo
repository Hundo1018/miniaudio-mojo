"""TDD contract tests for the waveform BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: waveform PCM generation is purely
in-memory. All 9 MA_API waveform functions are exercised here (positive and
negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.waveform_raw as raw


comptime FMT_F32: Int = 5
comptime CHANNELS: UInt32 = 1
comptime SAMPLE_RATE: UInt32 = 44100


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_read_seek() raises:
    """init + read_pcm_frames + seek_to_pcm_frame — positive path."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_true(wf != null_handle())
    assert_equal(
        raw.waveform_init(lib, wf, FMT_F32, CHANNELS, SAMPLE_RATE, raw.WAVEFORM_TYPE_SINE, 1.0, 440.0),
        MA_SUCCESS,
    )

    var buf = List[Float32]()
    buf.resize(Int(CHANNELS) * 512, Float32(0))
    var rc = raw.waveform_read_pcm_frames(lib, wf, buf, UInt64(512))
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value == UInt64(512))

    assert_equal(raw.waveform_seek_to_pcm_frame(lib, wf, UInt64(0)), MA_SUCCESS)

    raw.waveform_free(lib, wf)


def test_set_params() raises:
    """set_amplitude / set_frequency / set_type / set_sample_rate — positive path."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_equal(
        raw.waveform_init(lib, wf, FMT_F32, CHANNELS, SAMPLE_RATE, raw.WAVEFORM_TYPE_SINE, 1.0, 440.0),
        MA_SUCCESS,
    )
    assert_equal(raw.waveform_set_amplitude(lib, wf, 0.5), MA_SUCCESS)
    assert_equal(raw.waveform_set_frequency(lib, wf, 880.0), MA_SUCCESS)
    assert_equal(raw.waveform_set_type(lib, wf, raw.WAVEFORM_TYPE_SQUARE), MA_SUCCESS)
    assert_equal(raw.waveform_set_type(lib, wf, raw.WAVEFORM_TYPE_TRIANGLE), MA_SUCCESS)
    assert_equal(raw.waveform_set_type(lib, wf, raw.WAVEFORM_TYPE_SAWTOOTH), MA_SUCCESS)
    assert_equal(raw.waveform_set_sample_rate(lib, wf, 48000), MA_SUCCESS)
    raw.waveform_free(lib, wf)


def test_read_produces_nonzero_samples() raises:
    """Sine waveform must produce non-silent output for amplitude > 0."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_equal(
        raw.waveform_init(lib, wf, FMT_F32, CHANNELS, SAMPLE_RATE, raw.WAVEFORM_TYPE_SINE, 1.0, 440.0),
        MA_SUCCESS,
    )
    var buf = List[Float32]()
    buf.resize(512, Float32(0))
    var rc = raw.waveform_read_pcm_frames(lib, wf, buf, UInt64(512))
    assert_equal(rc.result, MA_SUCCESS)
    var found_nonzero = False
    for i in range(len(buf)):
        if buf[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)
    raw.waveform_free(lib, wf)


def test_null_handle_ops_invalid_args() raises:
    """All ops on a null handle return MA_INVALID_ARGS."""
    var lib = _lib()
    assert_equal(
        raw.waveform_init(lib, null_handle(), FMT_F32, CHANNELS, SAMPLE_RATE, 0, 1.0, 440.0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.waveform_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.waveform_seek_to_pcm_frame(lib, null_handle(), UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_amplitude(lib, null_handle(), 0.5), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_frequency(lib, null_handle(), 440.0), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_type(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_sample_rate(lib, null_handle(), 44100), MA_INVALID_ARGS)


def test_ops_before_init_invalid_args() raises:
    """Ops on an allocated-but-uninitialised handle return MA_INVALID_ARGS."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_equal(raw.waveform_seek_to_pcm_frame(lib, wf, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_amplitude(lib, wf, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_frequency(lib, wf, 440.0), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_type(lib, wf, 0), MA_INVALID_ARGS)
    assert_equal(raw.waveform_set_sample_rate(lib, wf, 44100), MA_INVALID_ARGS)
    raw.waveform_free(lib, wf)


def test_uninit_uninitialized_is_success() raises:
    """uninit on an allocated-but-uninitialised handle returns MA_SUCCESS (idempotent)."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_true(wf != null_handle())
    assert_equal(raw.waveform_uninit(lib, wf), MA_SUCCESS)
    raw.waveform_free(lib, wf)


def test_free_null_handle_is_noop() raises:
    """free(null) must not crash."""
    var lib = _lib()
    raw.waveform_free(lib, null_handle())


def test_reinit_same_handle() raises:
    """Re-initialising an initialised handle resets state cleanly."""
    var lib = _lib()
    var wf = raw.waveform_alloc(lib)
    assert_equal(
        raw.waveform_init(lib, wf, FMT_F32, CHANNELS, SAMPLE_RATE, raw.WAVEFORM_TYPE_SINE, 1.0, 440.0),
        MA_SUCCESS,
    )
    assert_equal(
        raw.waveform_init(lib, wf, FMT_F32, 2, SAMPLE_RATE, raw.WAVEFORM_TYPE_SQUARE, 0.5, 880.0),
        MA_SUCCESS,
    )
    raw.waveform_free(lib, wf)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
