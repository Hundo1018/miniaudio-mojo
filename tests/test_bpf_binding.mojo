"""TDD contract tests for the band-pass BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the filters are pure DSP objects and
the node variant only needs an engine on the null backend. All 20 MA_API
bpf functions are exercised here (positive and negative paths).

A band-pass rejects both extremes, so DC and a signal alternating every
frame are both driven to zero while the band around the cutoff survives.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.filter_raw as raw
import miniaudio._ffi.engine_raw as eraw


comptime FMT_F32: Int = 5
comptime MONO: UInt32 = 1
comptime STEREO: UInt32 = 2
comptime RATE: UInt32 = 48000
comptime N: Int = 256


def _lib() raises -> MaLib:
    return MaLib.default()


def _dc(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for _ in range(n):
        out.append(Float32(1.0))
    return out^


def _alternating(n: Int) -> List[Float32]:
    """+1, -1, +1, ... — the fastest signal the sample rate can carry."""
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(1.0) if i % 2 == 0 else Float32(-1.0))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _abs(x: Float32) -> Float32:
    return x if x >= Float32(0) else -x


# ---- ma_bpf2 ------------------------------------------------------------------


def test_bpf2_response_matches_its_definition() raises:
    """A second-order band-pass rejects both DC and the fastest signal."""
    var lib = _lib()
    var f = raw.bpf2_alloc(lib)
    assert_true(f != null_handle())
    assert_equal(raw.bpf2_init(lib, f, FMT_F32, MONO, RATE, 1000.0, 0.707107), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.bpf2_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_true(_abs(dc_out[N - 1]) < Float32(0.001))
    raw.bpf2_free(lib, f)

    var g = raw.bpf2_alloc(lib)
    assert_equal(raw.bpf2_init(lib, g, FMT_F32, MONO, RATE, 1000.0, 0.707107), MA_SUCCESS)
    var fast_out = _sink(N)
    assert_equal(
        raw.bpf2_process(lib, g, fast_out, _alternating(N), UInt64(N)), MA_SUCCESS
    )
    assert_true(_abs(fast_out[N - 1]) < Float32(0.001))
    raw.bpf2_free(lib, g)


def test_bpf2_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the lifecycle: heap size, both init paths, reinit, latency."""
    var lib = _lib()
    assert_equal(
        raw.bpf2_get_heap_size(lib, FMT_F32, MONO, RATE, 1000.0, 0.707107).result, MA_SUCCESS
    )

    var managed = raw.bpf2_alloc(lib)
    var prealloc = raw.bpf2_alloc(lib)
    assert_equal(raw.bpf2_init(lib, managed, FMT_F32, MONO, RATE, 1000.0, 0.707107), MA_SUCCESS)
    assert_equal(
        raw.bpf2_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, 1000.0, 0.707107),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.bpf2_process(lib, managed, a, _dc(N), UInt64(N))
    _ = raw.bpf2_process(lib, prealloc, b, _dc(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(
        raw.bpf2_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, 0.707107), MA_SUCCESS
    )
    assert_equal(raw.bpf2_get_latency(lib, managed).result, MA_SUCCESS)

    raw.bpf2_free(lib, managed)
    raw.bpf2_free(lib, prealloc)


def test_bpf2_rejects_an_uninitialised_or_null_handle() raises:
    """Every entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.bpf2_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.bpf2_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.bpf2_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(
        raw.bpf2_reinit(lib, f, FMT_F32, MONO, RATE, 1000.0, 0.707107), MA_INVALID_ARGS
    )
    assert_equal(raw.bpf2_uninit(lib, f), MA_SUCCESS)
    assert_equal(raw.bpf2_uninit(lib, f), MA_SUCCESS)
    raw.bpf2_free(lib, f)

    assert_equal(raw.bpf2_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.bpf2_init(lib, null_handle(), FMT_F32, MONO, RATE, 1000.0, 0.707107), MA_INVALID_ARGS
    )
    assert_equal(
        raw.bpf2_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, 1000.0, 0.707107),
        MA_INVALID_ARGS,
    )
    raw.bpf2_free(lib, null_handle())


# ---- ma_bpf ------------------------------------------------------------------


def test_bpf_response_matches_its_definition() raises:
    """The compound band-pass rejects both extremes at any order."""
    var lib = _lib()
    var f = raw.bpf_alloc(lib)
    assert_true(f != null_handle())
    assert_equal(raw.bpf_init(lib, f, FMT_F32, MONO, RATE, 1000.0, UInt32(2)), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.bpf_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_true(_abs(dc_out[N - 1]) < Float32(0.001))
    raw.bpf_free(lib, f)

    var g = raw.bpf_alloc(lib)
    assert_equal(raw.bpf_init(lib, g, FMT_F32, MONO, RATE, 1000.0, UInt32(2)), MA_SUCCESS)
    var fast_out = _sink(N)
    assert_equal(
        raw.bpf_process(lib, g, fast_out, _alternating(N), UInt64(N)), MA_SUCCESS
    )
    assert_true(_abs(fast_out[N - 1]) < Float32(0.001))
    raw.bpf_free(lib, g)


def test_bpf_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the lifecycle: heap size, both init paths, reinit, latency."""
    var lib = _lib()
    assert_equal(
        raw.bpf_get_heap_size(lib, FMT_F32, MONO, RATE, 1000.0, UInt32(2)).result, MA_SUCCESS
    )

    var managed = raw.bpf_alloc(lib)
    var prealloc = raw.bpf_alloc(lib)
    assert_equal(raw.bpf_init(lib, managed, FMT_F32, MONO, RATE, 1000.0, UInt32(2)), MA_SUCCESS)
    assert_equal(
        raw.bpf_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, 1000.0, UInt32(2)),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.bpf_process(lib, managed, a, _dc(N), UInt64(N))
    _ = raw.bpf_process(lib, prealloc, b, _dc(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(
        raw.bpf_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, UInt32(2)), MA_SUCCESS
    )
    assert_equal(raw.bpf_get_latency(lib, managed).result, MA_SUCCESS)

    raw.bpf_free(lib, managed)
    raw.bpf_free(lib, prealloc)


def test_bpf_rejects_an_uninitialised_or_null_handle() raises:
    """Every entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.bpf_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.bpf_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.bpf_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(
        raw.bpf_reinit(lib, f, FMT_F32, MONO, RATE, 1000.0, UInt32(2)), MA_INVALID_ARGS
    )
    assert_equal(raw.bpf_uninit(lib, f), MA_SUCCESS)
    assert_equal(raw.bpf_uninit(lib, f), MA_SUCCESS)
    raw.bpf_free(lib, f)

    assert_equal(raw.bpf_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.bpf_init(lib, null_handle(), FMT_F32, MONO, RATE, 1000.0, UInt32(2)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.bpf_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, 1000.0, UInt32(2)),
        MA_INVALID_ARGS,
    )
    raw.bpf_free(lib, null_handle())


# ---- ma_bpf_node -------------------------------------------------------------


def test_bpf_node_attaches_to_an_engine_graph() raises:
    """The node variant initialises against an engine's node graph and retunes."""
    var lib = _lib()
    var engine = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, engine, True), MA_SUCCESS)

    var node = raw.bpf_node_alloc(lib)
    assert_true(node != null_handle())
    assert_equal(
        raw.bpf_node_init(lib, node, engine, STEREO, RATE, 1000.0, UInt32(2)), MA_SUCCESS
    )
    assert_equal(
        raw.bpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, 500.0, UInt32(2)), MA_SUCCESS
    )
    assert_equal(raw.bpf_node_uninit(lib, node), MA_SUCCESS)

    raw.bpf_node_free(lib, node)
    eraw.engine_free(lib, engine)


def test_bpf_node_rejects_a_missing_engine() raises:
    """Without a live engine there is no graph to attach to."""
    var lib = _lib()
    var node = raw.bpf_node_alloc(lib)

    assert_equal(
        raw.bpf_node_init(lib, node, null_handle(), STEREO, RATE, 1000.0, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.bpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, 500.0, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.bpf_node_uninit(lib, node), MA_SUCCESS)

    raw.bpf_node_free(lib, node)
    raw.bpf_node_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
