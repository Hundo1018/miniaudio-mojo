"""TDD contract tests for the high-pass BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the filters are pure DSP objects and
the node variant only needs an engine on the null backend. All 28 MA_API hpf
functions are exercised here — the first-order ma_hpf1, the second-order
ma_hpf2, the compound ma_hpf, and ma_hpf_node (positive and negative paths).

Behaviour is asserted the way a high-pass is defined rather than against
hard-coded coefficients: a constant (DC) signal is rejected, while a signal
alternating every frame — the highest frequency representable — survives.

Note that miniaudio gives the high-pass filters no `clear_cache` entry point,
so unlike the low-pass family there is none to bind here.
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


# ---- ma_hpf1 — first order ---------------------------------------------------


def test_hpf1_tilts_towards_high_frequencies_without_nulling_dc() raises:
    """Pins what ma_hpf1 actually is: a gentle shelf, not a true high-pass.

    Its per-frame recursion is `y = b*x - a*r1` with `a = 1 - alpha` and
    `b = alpha`, where alpha is the same pole coefficient ma_lpf1 stores. That
    gives a DC gain of b/(1+a) = alpha/(2-alpha) and a Nyquist gain of
    b/(1-a) = 1. At cutoff 1 kHz and 48 kHz, alpha is ~0.877, so DC settles at
    ~0.781 rather than decaying to zero — about 2 dB of tilt, not a null.

    The second-order ma_hpf2 is biquad-based and *does* reject DC (see below),
    as does the compound ma_hpf at even orders. Reach for those when a real
    high-pass is wanted.
    """
    var lib = _lib()
    var f = raw.hpf1_alloc(lib)
    assert_true(f != null_handle())
    assert_equal(raw.hpf1_init(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.hpf1_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_almost_equal(dc_out[N - 1], Float32(0.781), atol=0.01)
    raw.hpf1_free(lib, f)

    var g = raw.hpf1_alloc(lib)
    assert_equal(raw.hpf1_init(lib, g, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)
    var fast_out = _sink(N)
    assert_equal(
        raw.hpf1_process(lib, g, fast_out, _alternating(N), UInt64(N)), MA_SUCCESS
    )
    assert_true(_abs(fast_out[N - 1]) > Float32(0.9))
    # The tilt is the point: highs come through, DC is held back.
    assert_true(_abs(fast_out[N - 1]) > _abs(dc_out[N - 1]))
    raw.hpf1_free(lib, g)


def test_hpf1_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the first-order lifecycle: heap size, both inits, reinit, latency."""
    var lib = _lib()
    assert_equal(
        raw.hpf1_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF).result, MA_SUCCESS
    )

    var managed = raw.hpf1_alloc(lib)
    var prealloc = raw.hpf1_alloc(lib)
    assert_equal(raw.hpf1_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF), MA_SUCCESS)
    assert_equal(
        raw.hpf1_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.hpf1_process(lib, managed, a, _alternating(N), UInt64(N))
    _ = raw.hpf1_process(lib, prealloc, b, _alternating(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(raw.hpf1_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0), MA_SUCCESS)
    assert_equal(raw.hpf1_get_latency(lib, managed).result, MA_SUCCESS)

    raw.hpf1_free(lib, managed)
    raw.hpf1_free(lib, prealloc)


def test_hpf1_rejects_an_uninitialised_or_null_handle() raises:
    """Every first-order entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.hpf1_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.hpf1_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.hpf1_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(raw.hpf1_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF), MA_INVALID_ARGS)
    assert_equal(raw.hpf1_uninit(lib, f), MA_SUCCESS)
    raw.hpf1_free(lib, f)

    assert_equal(raw.hpf1_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.hpf1_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF), MA_INVALID_ARGS
    )
    assert_equal(
        raw.hpf1_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF),
        MA_INVALID_ARGS,
    )
    raw.hpf1_free(lib, null_handle())


# ---- ma_hpf2 — second order --------------------------------------------------


def test_hpf2_rejects_dc_and_passes_the_fastest_signal() raises:
    """A second-order high-pass rolls off DC harder than the first-order one."""
    var lib = _lib()
    var f = raw.hpf2_alloc(lib)
    assert_equal(raw.hpf2_init(lib, f, FMT_F32, MONO, RATE, CUTOFF, Q), MA_SUCCESS)

    var dc_out = _sink(N)
    assert_equal(raw.hpf2_process(lib, f, dc_out, _dc(N), UInt64(N)), MA_SUCCESS)
    assert_true(_abs(dc_out[N - 1]) < Float32(0.2))
    raw.hpf2_free(lib, f)

    var g = raw.hpf2_alloc(lib)
    assert_equal(raw.hpf2_init(lib, g, FMT_F32, MONO, RATE, CUTOFF, Q), MA_SUCCESS)
    var fast_out = _sink(N)
    _ = raw.hpf2_process(lib, g, fast_out, _alternating(N), UInt64(N))
    assert_true(_abs(fast_out[N - 1]) > Float32(0.8))
    raw.hpf2_free(lib, g)


def test_hpf2_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the second-order lifecycle."""
    var lib = _lib()
    assert_equal(
        raw.hpf2_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF, Q).result, MA_SUCCESS
    )

    var managed = raw.hpf2_alloc(lib)
    var prealloc = raw.hpf2_alloc(lib)
    assert_equal(raw.hpf2_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF, Q), MA_SUCCESS)
    assert_equal(
        raw.hpf2_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.hpf2_process(lib, managed, a, _alternating(N), UInt64(N))
    _ = raw.hpf2_process(lib, prealloc, b, _alternating(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(
        raw.hpf2_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, Q), MA_SUCCESS
    )
    assert_equal(raw.hpf2_get_latency(lib, managed).result, MA_SUCCESS)

    raw.hpf2_free(lib, managed)
    raw.hpf2_free(lib, prealloc)


def test_hpf2_rejects_an_uninitialised_or_null_handle() raises:
    """Every second-order entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.hpf2_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.hpf2_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.hpf2_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(
        raw.hpf2_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF, Q), MA_INVALID_ARGS
    )
    assert_equal(raw.hpf2_uninit(lib, f), MA_SUCCESS)
    raw.hpf2_free(lib, f)

    assert_equal(raw.hpf2_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.hpf2_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.hpf2_init_preallocated(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, Q),
        MA_INVALID_ARGS,
    )
    raw.hpf2_free(lib, null_handle())


# ---- ma_hpf — compound -------------------------------------------------------


def test_hpf_stacks_blocks_to_the_requested_order() raises:
    """Second- and fourth-order compounds both reject DC and pass alternation."""
    var lib = _lib()
    var second = raw.hpf_alloc(lib)
    var fourth = raw.hpf_alloc(lib)
    assert_equal(
        raw.hpf_init(lib, second, FMT_F32, MONO, RATE, CUTOFF, UInt32(2)), MA_SUCCESS
    )
    assert_equal(
        raw.hpf_init(lib, fourth, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)), MA_SUCCESS
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.hpf_process(lib, second, a, _dc(N), UInt64(N))
    _ = raw.hpf_process(lib, fourth, b, _dc(N), UInt64(N))
    assert_true(_abs(a[N - 1]) < Float32(0.2))
    assert_true(_abs(b[N - 1]) < Float32(0.2))

    var fast_out = _sink(N)
    _ = raw.hpf_process(lib, fourth, fast_out, _alternating(N), UInt64(N))
    assert_true(_abs(fast_out[N - 1]) > Float32(0.5))

    raw.hpf_free(lib, second)
    raw.hpf_free(lib, fourth)


def test_hpf_heap_size_preallocated_reinit_and_latency() raises:
    """The rest of the compound lifecycle."""
    var lib = _lib()
    assert_equal(
        raw.hpf_get_heap_size(lib, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)).result,
        MA_SUCCESS,
    )

    var managed = raw.hpf_alloc(lib)
    var prealloc = raw.hpf_alloc(lib)
    assert_equal(
        raw.hpf_init(lib, managed, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)), MA_SUCCESS
    )
    assert_equal(
        raw.hpf_init_preallocated(lib, prealloc, FMT_F32, MONO, RATE, CUTOFF, UInt32(4)),
        MA_SUCCESS,
    )

    var a = _sink(N)
    var b = _sink(N)
    _ = raw.hpf_process(lib, managed, a, _alternating(N), UInt64(N))
    _ = raw.hpf_process(lib, prealloc, b, _alternating(N), UInt64(N))
    for i in range(N):
        assert_equal(a[i], b[i])

    assert_equal(
        raw.hpf_reinit(lib, managed, FMT_F32, MONO, RATE, 500.0, UInt32(4)), MA_SUCCESS
    )
    assert_equal(raw.hpf_get_latency(lib, managed).result, MA_SUCCESS)

    raw.hpf_free(lib, managed)
    raw.hpf_free(lib, prealloc)


def test_hpf_rejects_an_uninitialised_or_null_handle() raises:
    """Every compound entry point rejects handles that are not ready."""
    var lib = _lib()
    var f = raw.hpf_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.hpf_process(lib, f, dst, _dc(4), UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.hpf_get_latency(lib, f).result, MA_INVALID_ARGS)
    assert_equal(
        raw.hpf_reinit(lib, f, FMT_F32, MONO, RATE, CUTOFF, UInt32(2)), MA_INVALID_ARGS
    )
    assert_equal(raw.hpf_uninit(lib, f), MA_SUCCESS)
    raw.hpf_free(lib, f)

    assert_equal(raw.hpf_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.hpf_init(lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.hpf_init_preallocated(
            lib, null_handle(), FMT_F32, MONO, RATE, CUTOFF, UInt32(2)
        ),
        MA_INVALID_ARGS,
    )
    raw.hpf_free(lib, null_handle())


# ---- ma_hpf_node -------------------------------------------------------------


def test_hpf_node_attaches_to_an_engine_graph() raises:
    """The node variant initialises against an engine's node graph and retunes."""
    var lib = _lib()
    var engine = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, engine, True), MA_SUCCESS)

    var node = raw.hpf_node_alloc(lib)
    assert_true(node != null_handle())
    assert_equal(
        raw.hpf_node_init(lib, node, engine, STEREO, RATE, CUTOFF, UInt32(2)), MA_SUCCESS
    )
    assert_equal(
        raw.hpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, 500.0, UInt32(2)),
        MA_SUCCESS,
    )
    assert_equal(raw.hpf_node_uninit(lib, node), MA_SUCCESS)

    raw.hpf_node_free(lib, node)
    eraw.engine_free(lib, engine)


def test_hpf_node_rejects_a_missing_engine() raises:
    """Without a live engine there is no graph to attach to."""
    var lib = _lib()
    var node = raw.hpf_node_alloc(lib)

    assert_equal(
        raw.hpf_node_init(lib, node, null_handle(), STEREO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.hpf_node_reinit(lib, node, FMT_F32, STEREO, RATE, CUTOFF, UInt32(2)),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.hpf_node_uninit(lib, node), MA_SUCCESS)

    raw.hpf_node_free(lib, node)
    raw.hpf_node_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
