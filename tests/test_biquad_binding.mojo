"""TDD contract tests for the biquad BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a biquad is a pure DSP object, and the
node variant only needs an engine on the null backend. All 13 MA_API biquad
functions are exercised here (positive and negative paths).

The identity biquad (b0=1, everything else 0, a0=1) passes frames through
untouched, which makes the filter's behaviour assertable without depending on
any particular filter response.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.filter_raw as raw
import miniaudio._ffi.engine_raw as eraw


comptime FMT_F32: Int = 5
comptime MONO: UInt32 = 1
comptime STEREO: UInt32 = 2


def _lib() raises -> MaLib:
    return MaLib.default()


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i + 1))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _identity(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A biquad that passes its input straight through."""
    var bq = raw.biquad_alloc(lib)
    assert_equal(
        raw.biquad_init(lib, bq, FMT_F32, MONO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_SUCCESS,
    )
    return bq


def test_identity_coefficients_pass_frames_through() raises:
    """With b0=1 and no feedback the output equals the input."""
    var lib = _lib()
    var bq = _identity(lib)

    var src = _ramp(8)
    var dst = _sink(8)
    assert_equal(raw.biquad_process(lib, bq, dst, src, UInt64(8)), MA_SUCCESS)
    for i in range(8):
        assert_almost_equal(dst[i], src[i], atol=0.001)

    raw.biquad_free(lib, bq)


def test_a_gain_biquad_scales_every_frame() raises:
    """Halving b0 halves the output, frame for frame."""
    var lib = _lib()
    var bq = raw.biquad_alloc(lib)
    assert_true(bq != null_handle())
    assert_equal(
        raw.biquad_init(lib, bq, FMT_F32, MONO, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_SUCCESS,
    )

    var src = _ramp(8)
    var dst = _sink(8)
    assert_equal(raw.biquad_process(lib, bq, dst, src, UInt64(8)), MA_SUCCESS)
    for i in range(8):
        assert_almost_equal(dst[i], src[i] * Float32(0.5), atol=0.001)

    raw.biquad_free(lib, bq)


def test_heap_size_is_reported_without_initialising() raises:
    """The get_heap_size call answers from the coefficients alone."""
    var lib = _lib()
    var rc = raw.biquad_get_heap_size(lib, FMT_F32, STEREO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    assert_equal(rc.result, MA_SUCCESS)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path filters identically to the miniaudio-owned one."""
    var lib = _lib()
    var managed = _identity(lib)
    var prealloc = raw.biquad_alloc(lib)
    assert_equal(
        raw.biquad_init_preallocated(
            lib, prealloc, FMT_F32, MONO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0
        ),
        MA_SUCCESS,
    )

    var src = _ramp(8)
    var a = _sink(8)
    var b = _sink(8)
    _ = raw.biquad_process(lib, managed, a, src, UInt64(8))
    _ = raw.biquad_process(lib, prealloc, b, src, UInt64(8))
    for i in range(8):
        assert_equal(a[i], b[i])

    raw.biquad_free(lib, managed)
    raw.biquad_free(lib, prealloc)


def test_reinit_retunes_in_place() raises:
    """The reinit call swaps the coefficients on a live filter."""
    var lib = _lib()
    var bq = _identity(lib)

    assert_equal(
        raw.biquad_reinit(lib, bq, FMT_F32, MONO, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_SUCCESS,
    )
    var src = _ramp(4)
    var dst = _sink(4)
    _ = raw.biquad_process(lib, bq, dst, src, UInt64(4))
    assert_almost_equal(dst[0], src[0] * Float32(0.5), atol=0.001)

    raw.biquad_free(lib, bq)


def test_latency_and_clear_cache_are_available() raises:
    """Latency is queryable and clear_cache drops the running state."""
    var lib = _lib()
    var bq = _identity(lib)

    var latency = raw.biquad_get_latency(lib, bq)
    assert_equal(latency.result, MA_SUCCESS)
    assert_true(latency.value >= UInt32(0))

    var src = _ramp(4)
    var dst = _sink(4)
    _ = raw.biquad_process(lib, bq, dst, src, UInt64(4))
    assert_equal(raw.biquad_clear_cache(lib, bq), MA_SUCCESS)

    raw.biquad_free(lib, bq)


def test_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var bq = raw.biquad_alloc(lib)
    var src = _ramp(4)
    var dst = _sink(4)

    assert_equal(raw.biquad_process(lib, bq, dst, src, UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.biquad_get_latency(lib, bq).result, MA_INVALID_ARGS)
    assert_equal(raw.biquad_clear_cache(lib, bq), MA_INVALID_ARGS)
    assert_equal(
        raw.biquad_reinit(lib, bq, FMT_F32, MONO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_INVALID_ARGS,
    )

    raw.biquad_free(lib, bq)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var bq = _identity(lib)
    assert_equal(raw.biquad_uninit(lib, bq), MA_SUCCESS)
    assert_equal(raw.biquad_uninit(lib, bq), MA_SUCCESS)
    raw.biquad_free(lib, bq)

    assert_equal(raw.biquad_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.biquad_init(lib, null_handle(), FMT_F32, MONO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.biquad_init_preallocated(
            lib, null_handle(), FMT_F32, MONO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0
        ),
        MA_INVALID_ARGS,
    )
    raw.biquad_free(lib, null_handle())


# ---- the node-graph variant --------------------------------------------------


def test_biquad_node_attaches_to_an_engine_graph() raises:
    """The node variant initialises against an engine's node graph and retunes."""
    var lib = _lib()
    var engine = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, engine, True), MA_SUCCESS)

    var node = raw.biquad_node_alloc(lib)
    assert_true(node != null_handle())
    assert_equal(
        raw.biquad_node_init(
            lib, node, engine, STEREO,
            Float32(1.0), Float32(0.0), Float32(0.0),
            Float32(1.0), Float32(0.0), Float32(0.0),
        ),
        MA_SUCCESS,
    )
    assert_equal(
        raw.biquad_node_reinit(lib, node, FMT_F32, STEREO, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_SUCCESS,
    )
    assert_equal(raw.biquad_node_uninit(lib, node), MA_SUCCESS)

    raw.biquad_node_free(lib, node)
    eraw.engine_free(lib, engine)


def test_biquad_node_rejects_a_missing_engine() raises:
    """Without a live engine there is no graph to attach to."""
    var lib = _lib()
    var node = raw.biquad_node_alloc(lib)

    assert_equal(
        raw.biquad_node_init(
            lib, node, null_handle(), STEREO,
            Float32(1.0), Float32(0.0), Float32(0.0),
            Float32(1.0), Float32(0.0), Float32(0.0),
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.biquad_node_reinit(lib, node, FMT_F32, STEREO, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.biquad_node_uninit(lib, node), MA_SUCCESS)

    raw.biquad_node_free(lib, node)
    raw.biquad_node_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
