"""TDD contract tests for the pulsewave BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: ma_pulsewave generates a square wave
with an adjustable duty cycle in memory. All 9 MA_API pulsewave functions are
exercised (positive and negative).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.waveform_raw as raw


comptime FMT_F32: Int = 5
comptime SAMPLE_RATE: UInt32 = 44100


def _lib() raises -> MaLib:
    return MaLib.default()


def _positive_count(buf: List[Float32]) -> Int:
    var n = 0
    for i in range(len(buf)):
        if buf[i] > Float32(0):
            n += 1
    return n


def test_duty_cycle_sets_high_fraction() raises:
    """441 Hz at 44.1 kHz = 100-frame period; 25% duty -> 25 high frames per period."""
    var lib = _lib()
    var pw = raw.pulsewave_alloc(lib)
    assert_true(pw != null_handle())
    assert_equal(raw.pulsewave_init(lib, pw, FMT_F32, 1, SAMPLE_RATE, 0.25, 1.0, 441.0), MA_SUCCESS)
    var buf = List[Float32]()
    buf.resize(1000, Float32(0))
    var rc = raw.pulsewave_read_pcm_frames(lib, pw, buf, UInt64(1000))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(1000))
    var high = _positive_count(buf)
    assert_true(high >= 240 and high <= 260)
    for i in range(len(buf)):
        assert_true(buf[i] == Float32(1.0) or buf[i] == Float32(-1.0))
    raw.pulsewave_free(lib, pw)


def test_setters_and_seek() raises:
    var lib = _lib()
    var pw = raw.pulsewave_alloc(lib)
    assert_equal(raw.pulsewave_init(lib, pw, FMT_F32, 1, SAMPLE_RATE, 0.5, 1.0, 441.0), MA_SUCCESS)
    assert_equal(raw.pulsewave_set_duty_cycle(lib, pw, 0.75), MA_SUCCESS)
    assert_equal(raw.pulsewave_set_amplitude(lib, pw, 0.5), MA_SUCCESS)
    assert_equal(raw.pulsewave_set_frequency(lib, pw, 441.0), MA_SUCCESS)
    assert_equal(raw.pulsewave_set_sample_rate(lib, pw, SAMPLE_RATE), MA_SUCCESS)
    assert_equal(raw.pulsewave_seek_to_pcm_frame(lib, pw, UInt64(0)), MA_SUCCESS)
    var buf = List[Float32]()
    buf.resize(1000, Float32(0))
    assert_equal(raw.pulsewave_read_pcm_frames(lib, pw, buf, UInt64(1000)).result, MA_SUCCESS)
    var high = _positive_count(buf)
    assert_true(high >= 740 and high <= 760)
    assert_true(buf[0] == Float32(0.5) or buf[0] == Float32(-0.5))
    raw.pulsewave_free(lib, pw)


def test_zero_frame_read_rejected() raises:
    """miniaudio rejects frame_count == 0 with MA_INVALID_ARGS (unlike ma_waveform)."""
    var lib = _lib()
    var pw = raw.pulsewave_alloc(lib)
    assert_equal(raw.pulsewave_init(lib, pw, FMT_F32, 1, SAMPLE_RATE, 0.5, 1.0, 440.0), MA_SUCCESS)
    var buf = List[Float32]()
    buf.resize(4, Float32(0))
    var rc = raw.pulsewave_read_pcm_frames(lib, pw, buf, UInt64(0))
    assert_equal(rc.result, MA_INVALID_ARGS)
    assert_equal(rc.value, UInt64(0))
    raw.pulsewave_free(lib, pw)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var buf = List[Float32]()
    buf.resize(4, Float32(0))
    assert_equal(raw.pulsewave_init(lib, n, FMT_F32, 1, SAMPLE_RATE, 0.5, 1.0, 440.0), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_read_pcm_frames(lib, n, buf, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_seek_to_pcm_frame(lib, n, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_set_amplitude(lib, n, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_set_frequency(lib, n, 440.0), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_set_sample_rate(lib, n, 48000), MA_INVALID_ARGS)
    assert_equal(raw.pulsewave_set_duty_cycle(lib, n, 0.5), MA_INVALID_ARGS)
    raw.pulsewave_free(lib, n)


def test_uninit_then_ops_invalid_and_reinit() raises:
    var lib = _lib()
    var pw = raw.pulsewave_alloc(lib)
    assert_equal(raw.pulsewave_uninit(lib, pw), MA_SUCCESS)  # before init: no-op
    assert_equal(raw.pulsewave_init(lib, pw, FMT_F32, 1, SAMPLE_RATE, 0.5, 1.0, 440.0), MA_SUCCESS)
    assert_equal(raw.pulsewave_init(lib, pw, FMT_F32, 2, SAMPLE_RATE, 0.1, 0.5, 880.0), MA_SUCCESS)
    assert_equal(raw.pulsewave_uninit(lib, pw), MA_SUCCESS)
    assert_equal(raw.pulsewave_set_duty_cycle(lib, pw, 0.5), MA_INVALID_ARGS)
    raw.pulsewave_free(lib, pw)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
