"""TDD contract tests for the noise BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: noise PCM generation is purely
in-memory. All bound MA_API noise functions are exercised here (positive and
negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.noise_raw as raw


comptime FMT_F32: Int = 5
comptime CHANNELS: UInt32 = 1


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_read() raises:
    """Init + read_pcm_frames — positive path."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_true(ns != null_handle())
    assert_equal(
        raw.noise_init(lib, ns, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(42), 1.0),
        MA_SUCCESS,
    )

    var buf = List[Float32]()
    buf.resize(Int(CHANNELS) * 512, Float32(0))
    var rc = raw.noise_read_pcm_frames(lib, ns, buf, UInt64(512))
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value == UInt64(512))

    raw.noise_free(lib, ns)


def test_set_params() raises:
    """Set_amplitude / set_seed — positive path."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_equal(
        raw.noise_init(lib, ns, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(0), 1.0),
        MA_SUCCESS,
    )
    assert_equal(raw.noise_set_amplitude(lib, ns, 0.5), MA_SUCCESS)
    assert_equal(raw.noise_set_seed(lib, ns, Int32(123)), MA_SUCCESS)
    raw.noise_free(lib, ns)


def test_read_produces_nonzero_samples() raises:
    """White noise with amplitude 1.0 must produce non-silent output."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_equal(
        raw.noise_init(lib, ns, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(42), 1.0),
        MA_SUCCESS,
    )
    var buf = List[Float32]()
    buf.resize(512, Float32(0))
    var rc = raw.noise_read_pcm_frames(lib, ns, buf, UInt64(512))
    assert_equal(rc.result, MA_SUCCESS)
    var found_nonzero = False
    for i in range(len(buf)):
        if buf[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)
    raw.noise_free(lib, ns)


def test_null_handle_ops_invalid_args() raises:
    """All ops on a null handle return MA_INVALID_ARGS."""
    var lib = _lib()
    assert_equal(
        raw.noise_init(lib, null_handle(), FMT_F32, CHANNELS, 0, Int32(0), 1.0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.noise_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.noise_set_amplitude(lib, null_handle(), 0.5), MA_INVALID_ARGS)
    assert_equal(raw.noise_set_seed(lib, null_handle(), Int32(0)), MA_INVALID_ARGS)


def test_ops_before_init_invalid_args() raises:
    """Ops on an allocated-but-uninitialised handle return MA_INVALID_ARGS."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_equal(raw.noise_set_amplitude(lib, ns, 0.5), MA_INVALID_ARGS)
    assert_equal(raw.noise_set_seed(lib, ns, Int32(0)), MA_INVALID_ARGS)
    raw.noise_free(lib, ns)


def test_uninit_uninitialized_is_success() raises:
    """Uninit on an allocated-but-uninitialised handle returns MA_SUCCESS (idempotent)."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_true(ns != null_handle())
    assert_equal(raw.noise_uninit(lib, ns), MA_SUCCESS)
    raw.noise_free(lib, ns)


def test_free_null_handle_is_noop() raises:
    """Free(null) must not crash."""
    var lib = _lib()
    raw.noise_free(lib, null_handle())


def test_reinit_same_handle() raises:
    """Re-initialising an initialised handle resets state cleanly."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_equal(
        raw.noise_init(lib, ns, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(0), 1.0),
        MA_SUCCESS,
    )
    assert_equal(
        raw.noise_init(lib, ns, FMT_F32, 2, raw.NOISE_TYPE_PINK, Int32(99), 0.5),
        MA_SUCCESS,
    )
    raw.noise_free(lib, ns)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
