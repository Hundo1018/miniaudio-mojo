"""TDD contract tests for the low-pass BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the filters are pure DSP objects and
the node variant only needs an engine on the null backend. All 31 MA_API lpf
functions are exercised here — the first-order ma_lpf1, the second-order
ma_lpf2, the compound ma_lpf, and ma_lpf_node (positive and negative paths).

Behaviour is asserted the way a low-pass is defined rather than against
hard-coded coefficients: a constant (DC) signal survives, while a signal
alternating every frame — the highest frequency representable — is strongly
attenuated.
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
comptime CUTOFF: Float64 = 1000.0
comptime Q: Float64 = 0.707107
comptime N: Int = 64


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


# ---- ma_lpf1 — first order ---------------------------------------------------


def test_lpf1_passes_dc_and_attenuates_the_fastest_signal() raises:
    """A first-order low-pass keeps DC and kills frame-to-frame alternation."""
    var lib = _lib()
    var f = raw.lpf1_alloc(lib)
    assert_true(f != null_handle())
    assert_equal(raw.lpf1_init(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.lpf1_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_almost_equal(dc_out[N - 1], Float32(1.0), atol=0.05)
    raw.lpf1_free(lib, f)

    var g = raw.lpf1_alloc(lib)
    assert_equal(raw.lpf1_init(lib, g, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)
    var fast_out = _sink(N)
    assert_equal(
        raw.lpf1_process(lib, g, fast_out, _alternating(N), UInt64(N)), MA_SUCCESS
    )
    assert_true(_abs(fast_out[N - 1]) < Float32(0.1))
    raw.lpf1_free(lib, g)


def test_lpf1_clear_cache_zeroes_the_coefficient_not_the_cache() raises:
    """Pins an upstream bug in ma_lpf1_clear_cache (miniaudio 0.11.25).

    ma_lpf1 holds its filter coefficient in `a` and its delay register behind
    `pR1`. ma_biquad_clear_cache correctly zeroes the registers (pR1/pR2), but
    ma_lpf1_clear_cache zeroes `a` — the *coefficient* — leaving the cached
    sample untouched. The filter is therefore not cleared but de-tuned: with
    a = 0 it becomes y[n] = x[n], a pass-through, as asserted below.

    The compound ma_lpf inherits this through its first-order section. Call
    reinit after clear_cache to restore the tuning, or avoid clear_cache on the
    first-order filters. If a future miniaudio fixes this, the pass-through
    assertion fails and this note should go away.
    """
    var lib = _lib()
    var f = raw.lpf1_alloc(lib)
    assert_equal(raw.lpf1_init(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)

    var before = _sink(N)
    _ = raw.lpf1_process(lib, f, before, _alternating(N), UInt64(N))
    assert_true(_abs(before[N - 1]) < Float32(0.1))

    assert_equal(raw.lpf1_clear_cache(lib, f), MA_SUCCESS)

    var after = _sink(N)
    var src = _alternating(N)
    _ = raw.lpf1_process(lib, f, after, src, UInt64(N))
    for i in range(N):
        assert_equal(after[i], src[i])  # unfiltered: the coefficient is gone

    # reinit puts the tuning back.
    assert_equal(raw.lpf1_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)
    var restored = _sink(N)
    _ = raw.lpf1_process(lib, f, restored, _alternating(N), UInt64(N))
    assert_true(_abs(restored[N - 1]) < Float32(0.1))

    raw.lpf1_free(lib, f)


def test_lpf1_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the first-order lifecycle: heap size, both inits, reinit, latency."""
    var lib = _lib()
    var size = raw.lpf1_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF)
    assert_equal(size.result, MA_SUCCESS)

    var managed = raw.lpf1_alloc(lib)
    var prealloc = raw.lpf1_alloc(lib)
    assert_equal(raw.lpf1_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)
    assert_equal(
        raw.lpf1_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.lpf1_process(lib, managed, a, _dc(N), UInt64(N))
    _ = raw.lpf1_process(lib, prealloc, b, _dc(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(raw.lpf1_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0), MA_SUCCESS)
    assert_equal(raw.lpf1_get_latency(lib, managed).result, MA_SUCCESS)

    raw.lpf1_free(lib, managed)
    raw.lpf1_free(lib, prealloc)


def test_lpf1_rejects_an_uninitialised_or_null_handle() raises:
    """Every first-order entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.lpf1_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.lpf1_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.lpf1_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(raw.lpf1_clear_cache(lib, f), MA_INVALID_ARGS)
    assert_equal(raw.lpf1_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_INVALID_ARGS)
    assert_equal(raw.lpf1_uninit(lib, f), MA_SUCCESS)
    raw.lpf1_free(lib, f)

    assert_equal(raw.lpf1_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.lpf1_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF), MA_INVALID_ARGS
    )
    assert_equal(
        raw.lpf1_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF),
        MA_INVALID_ARGS,
    )
    raw.lpf1_free(lib, null_handle())


# ---- ma_lpf2 — second order --------------------------------------------------


def test_lpf2_passes_dc_and_attenuates_the_fastest_signal() raises:
    """A second-order low-pass rolls off harder than the first-order one."""
    var lib = _lib()
    var f = raw.lpf2_alloc(lib)
    assert_equal(raw.lpf2_init(lib, f, FMT_F32, MONO, RATE, CUTOFF, Q), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.lpf2_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_almost_equal(dc_out[N - 1], Float32(1.0), atol=0.05)

    assert_equal(raw.lpf2_clear_cache(lib, f), MA_SUCCESS)
    var fast_out = _sink(N)
    _ = raw.lpf2_process(lib, f, fast_out, _alternating(N), UInt64(N))
    assert_true(_abs(fast_out[N - 1]) < Float32(0.05))

    raw.lpf2_free(lib, f)


def test_lpf2_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the second-order lifecycle."""
    var lib = _lib()
    assert_equal(
        raw.lpf2_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF, Q).result, MA_SUCCESS
    )

    var managed = raw.lpf2_alloc(lib)
    var prealloc = raw.lpf2_alloc(lib)
    assert_equal(raw.lpf2_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF, Q), MA_SUCCESS)
    assert_equal(
        raw.lpf2_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.lpf2_process(lib, managed, a, _dc(N), UInt64(N))
    _ = raw.lpf2_process(lib, prealloc, b, _dc(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(
        raw.lpf2_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, Q), MA_SUCCESS
    )
    assert_equal(raw.lpf2_get_latency(lib, managed).result, MA_SUCCESS)

    raw.lpf2_free(lib, managed)
    raw.lpf2_free(lib, prealloc)


def test_lpf2_rejects_an_uninitialised_or_null_handle() raises:
    """Every second-order entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.lpf2_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.lpf2_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.lpf2_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(raw.lpf2_clear_cache(lib, f), MA_INVALID_ARGS)
    assert_equal(
        raw.lpf2_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF, Q), MA_INVALID_ARGS
    )
    assert_equal(raw.lpf2_uninit(lib, f), MA_SUCCESS)
    raw.lpf2_free(lib, f)

    assert_equal(raw.lpf2_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.lpf2_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.lpf2_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_INVALID_ARGS,
    )
    raw.lpf2_free(lib, null_handle())


# ---- ma_lpf — compound -------------------------------------------------------


def test_lpf_stacks_blocks_to_the_requested_order() raises:
    """Second- and fourth-order compounds both pass DC and kill the fastest signal.

    Deliberately not asserting that a higher order attenuates *more*: measured
    at the alternating signal, order 4 settles around 1.5e-3 and order 2 around
    1e-4, so the ordering does not hold sample-for-sample at Nyquist. Both are
    far below the input, which is the property that actually defines the filter.
    """
    var lib = _lib()
    var second = raw.lpf_alloc(lib)
    var fourth = raw.lpf_alloc(lib)
    assert_equal(
        raw.lpf_init(lib, second, FMT_F32, MONO, RATE, CUTOFF, UInt32(2)), MA_SUCCESS
    )
    assert_equal(
        raw.lpf_init(lib, fourth, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)), MA_SUCCESS
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.lpf_process(lib, second, a, _alternating(N), UInt64(N))
    _ = raw.lpf_process(lib, fourth, b, _alternating(N), UInt64(N))
    assert_true(_abs(a[N - 1]) < Float32(0.01))
    assert_true(_abs(b[N - 1]) < Float32(0.01))

    var dc_out = _sink(N)
    _ = raw.lpf_process(lib, fourth, dc_out, _dc(N), UInt64(N))
    assert_almost_equal(dc_out[N - 1], Float32(1.0), atol=0.05)

    raw.lpf_free(lib, second)
    raw.lpf_free(lib, fourth)


def test_lpf_heap_size_preallocated_reinit_latency_and_cache() raises:
    """The rest of the compound lifecycle."""
    var lib = _lib()
    assert_equal(
        raw.lpf_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)).result,
        MA_SUCCESS,
    )

    var managed = raw.lpf_alloc(lib)
    var prealloc = raw.lpf_alloc(lib)
    assert_equal(
        raw.lpf_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)), MA_SUCCESS
    )
    assert_equal(
        raw.lpf_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.lpf_process(lib, managed, a, _dc(N), UInt64(N))
    _ = raw.lpf_process(lib, prealloc, b, _dc(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    # clear_cache de-tunes the first-order section upstream (see the lpf1 test),
    # so reinit follows it here to put the tuning back.
    assert_equal(raw.lpf_clear_cache(lib, managed), MA_SUCCESS)
    assert_equal(
        raw.lpf_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, UInt32(4)), MA_SUCCESS
    )
    assert_equal(raw.lpf_get_latency(lib, managed).result, MA_SUCCESS)

    raw.lpf_free(lib, managed)
    raw.lpf_free(lib, prealloc)


def test_lpf_rejects_an_uninitialised_or_null_handle() raises:
    """Every compound entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.lpf_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.lpf_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.lpf_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(raw.lpf_clear_cache(lib, f), MA_INVALID_ARGS)
    assert_equal(
        raw.lpf_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF, UInt32(2)), MA_INVALID_ARGS
    )
    assert_equal(raw.lpf_uninit(lib, f), MA_SUCCESS)
    raw.lpf_free(lib, f)

    assert_equal(raw.lpf_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.lpf_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.lpf_init_preallocated(
            lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, UInt32(2)
        ),
        MA_INVALID_ARGS,
    )
    raw.lpf_free(lib, null_handle())


# ---- ma_lpf_node -------------------------------------------------------------


def test_lpf_node_attaches_to_an_engine_graph() raises:
    """The node variant initialises against an engine's node graph and retunes."""
    var lib = _lib()
    var engine = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, engine, True), MA_SUCCESS)

    var node = raw.lpf_node_alloc(lib)
    assert_true(node != null_handle())
    assert_equal(
        raw.lpf_node_init(lib, node, engine, STEREO, RATE, CUTOFF, UInt32(2)), MA_SUCCESS
    )
    assert_equal(
        raw.lpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, 500.0, UInt32(2)),
        MA_SUCCESS,
    )
    assert_equal(raw.lpf_node_uninit(lib, node), MA_SUCCESS)

    raw.lpf_node_free(lib, node)
    eraw.engine_free(lib, engine)


def test_lpf_node_rejects_a_missing_engine() raises:
    """Without a live engine there is no graph to attach to."""
    var lib = _lib()
    var node = raw.lpf_node_alloc(lib)

    assert_equal(
        raw.lpf_node_init(lib, node, null_handle(), STEREO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.lpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.lpf_node_uninit(lib, node), MA_SUCCESS)

    raw.lpf_node_free(lib, node)
    raw.lpf_node_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
