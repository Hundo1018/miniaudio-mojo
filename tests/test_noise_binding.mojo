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


def test_heap_size_is_reported_without_initialising() raises:
    """Heap size: white noise keeps no state (0); pink/brownian scale with channels."""
    var lib = _lib()
    var white = raw.noise_get_heap_size(lib, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE)
    assert_equal(white.result, MA_SUCCESS)
    assert_equal(white.value, UInt64(0))

    var pink1 = raw.noise_get_heap_size(lib, FMT_F32, UInt32(1), raw.NOISE_TYPE_PINK)
    var pink4 = raw.noise_get_heap_size(lib, FMT_F32, UInt32(4), raw.NOISE_TYPE_PINK)
    assert_equal(pink1.result, MA_SUCCESS)
    assert_equal(pink4.result, MA_SUCCESS)
    assert_true(pink1.value > UInt64(0))
    assert_true(pink4.value > pink1.value)

    var brown = raw.noise_get_heap_size(lib, FMT_F32, UInt32(2), raw.NOISE_TYPE_BROWNIAN)
    assert_equal(brown.result, MA_SUCCESS)
    assert_true(brown.value > UInt64(0))


def test_heap_size_rejects_zero_channels() raises:
    var lib = _lib()
    var rc = raw.noise_get_heap_size(lib, FMT_F32, UInt32(0), raw.NOISE_TYPE_PINK)
    assert_true(rc.result != MA_SUCCESS)
    assert_equal(rc.value, UInt64(0))


def test_preallocated_init_matches_the_managed_one() raises:
    """Same seed + type through init_preallocated yields the identical stream."""
    var lib = _lib()
    var managed = raw.noise_alloc(lib)
    var prealloc = raw.noise_alloc(lib)
    assert_equal(
        raw.noise_init(lib, managed, FMT_F32, UInt32(2), raw.NOISE_TYPE_PINK, Int32(7), 0.5),
        MA_SUCCESS,
    )
    assert_equal(
        raw.noise_init_preallocated(
            lib, prealloc, FMT_F32, UInt32(2), raw.NOISE_TYPE_PINK, Int32(7), 0.5
        ),
        MA_SUCCESS,
    )
    var a = List[Float32]()
    var b = List[Float32]()
    a.resize(256, Float32(0))
    b.resize(256, Float32(0))
    assert_equal(raw.noise_read_pcm_frames(lib, managed, a, UInt64(128)).result, MA_SUCCESS)
    assert_equal(raw.noise_read_pcm_frames(lib, prealloc, b, UInt64(128)).result, MA_SUCCESS)
    for i in range(256):
        assert_equal(a[i], b[i])

    # The preallocated handle is a fully working one: params still apply, and
    # uninit releases the shim-owned heap so the handle can be re-initialised.
    assert_equal(raw.noise_set_amplitude(lib, prealloc, 0.25), MA_SUCCESS)
    assert_equal(raw.noise_uninit(lib, prealloc), MA_SUCCESS)
    assert_equal(raw.noise_set_seed(lib, prealloc, Int32(1)), MA_INVALID_ARGS)
    assert_equal(
        raw.noise_init_preallocated(
            lib, prealloc, FMT_F32, UInt32(1), raw.NOISE_TYPE_BROWNIAN, Int32(3), 1.0
        ),
        MA_SUCCESS,
    )
    raw.noise_free(lib, prealloc)
    raw.noise_free(lib, managed)


def test_preallocated_white_noise_needs_no_heap() raises:
    """White noise has a zero-byte heap; the preallocated path still initialises."""
    var lib = _lib()
    var ns = raw.noise_alloc(lib)
    assert_equal(
        raw.noise_init_preallocated(
            lib, ns, FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(5), 1.0
        ),
        MA_SUCCESS,
    )
    var buf = List[Float32]()
    buf.resize(64, Float32(0))
    var rc = raw.noise_read_pcm_frames(lib, ns, buf, UInt64(64))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(64))
    raw.noise_free(lib, ns)


def test_preallocated_negative_paths() raises:
    """Null handle -> INVALID_ARGS; zero channels is refused and leaves the handle usable."""
    var lib = _lib()
    assert_equal(
        raw.noise_init_preallocated(
            lib, null_handle(), FMT_F32, CHANNELS, raw.NOISE_TYPE_WHITE, Int32(0), 1.0
        ),
        MA_INVALID_ARGS,
    )
    var ns = raw.noise_alloc(lib)
    assert_true(
        raw.noise_init_preallocated(
            lib, ns, FMT_F32, UInt32(0), raw.NOISE_TYPE_PINK, Int32(0), 1.0
        )
        != MA_SUCCESS
    )
    # A failed init leaves the handle uninitialised.
    assert_equal(raw.noise_set_amplitude(lib, ns, 0.5), MA_INVALID_ARGS)
    raw.noise_free(lib, ns)


def test_read_from_a_handle_that_is_not_ready_reports_nothing() raises:
    var lib = _lib()
    var buf = List[Float32]()
    buf.resize(16, Float32(0))

    var none = raw.noise_read_pcm_frames(lib, null_handle(), buf, UInt64(8))
    assert_equal(none.result, MA_INVALID_ARGS)
    assert_equal(none.value, UInt64(0))

    var ns = raw.noise_alloc(lib)    # allocated, never initialised
    var cold = raw.noise_read_pcm_frames(lib, ns, buf, UInt64(8))
    assert_equal(cold.result, MA_INVALID_ARGS)
    assert_equal(cold.value, UInt64(0))
    raw.noise_free(lib, ns)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
