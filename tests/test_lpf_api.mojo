"""TDD tests for the idiomatic low-pass API (RAII Lpf1 / Lpf2 / Lpf / LpfNode).

L3 behavioral: verifies the defining property of a low-pass — a constant signal
survives, an alternating one does not — across all three orders, that retuning
works on a live filter, that both init paths agree, and that the node variant
attaches to an engine's graph.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_raises,
    assert_almost_equal,
    TestSuite,
)
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.engine import Engine
from miniaudio.filter import Lpf1, Lpf2, Lpf, LpfNode


comptime N: Int = 64


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _dc(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for _ in range(n):
        out.append(Float32(1.0))
    return out^


def _alternating(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(1.0) if i % 2 == 0 else Float32(-1.0))
    return out^


def _abs(x: Float32) -> Float32:
    return x if x >= Float32(0) else -x


def test_every_order_passes_dc() raises:
    """First, second and compound low-pass all let a constant signal through."""
    var f1 = Lpf1.create(_lib(), cutoff=1000.0)
    var f2 = Lpf2.create(_lib(), cutoff=1000.0)
    var f4 = Lpf.create(_lib(), cutoff=1000.0, order=UInt32(4))

    assert_almost_equal(f1.process(_dc(N))[N - 1], Float32(1.0), atol=0.05)
    assert_almost_equal(f2.process(_dc(N))[N - 1], Float32(1.0), atol=0.05)
    assert_almost_equal(f4.process(_dc(N))[N - 1], Float32(1.0), atol=0.05)


def test_every_order_attenuates_the_fastest_signal() raises:
    """All three shapes kill a signal that alternates every frame."""
    var f1 = Lpf1.create(_lib(), cutoff=1000.0)
    var f2 = Lpf2.create(_lib(), cutoff=1000.0)
    var f4 = Lpf.create(_lib(), cutoff=1000.0, order=UInt32(4))

    assert_true(_abs(f1.process(_alternating(N))[N - 1]) < Float32(0.1))
    assert_true(_abs(f2.process(_alternating(N))[N - 1]) < Float32(0.05))
    assert_true(_abs(f4.process(_alternating(N))[N - 1]) < Float32(0.05))


def test_processing_never_changes_the_frame_count() raises:
    """Filtering is out-of-place and one frame in, one frame out."""
    var f = Lpf2.create(_lib(), cutoff=1000.0)
    assert_equal(len(f.process(_dc(N))), N)


def test_retune_changes_a_live_filter() raises:
    """A retuned filter behaves like one built with the new cutoff."""
    var retuned = Lpf2.create(_lib(), cutoff=20000.0)
    retuned.retune(cutoff=200.0)
    var fresh = Lpf2.create(_lib(), cutoff=200.0)

    var a = retuned.process(_alternating(N))
    var b = fresh.process(_alternating(N))
    assert_almost_equal(a[N - 1], b[N - 1], atol=0.001)


def test_preallocated_and_managed_heaps_filter_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = Lpf.create(_lib(), cutoff=1000.0, order=UInt32(4))
    var prealloc = Lpf.create(
        _lib(), cutoff=1000.0, order=UInt32(4), preallocated=True
    )

    var a = managed.process(_dc(N))
    var b = prealloc.process(_dc(N))
    for i in range(N):
        assert_equal(a[i], b[i])


def test_heap_size_and_latency_are_queryable() raises:
    """Heap size answers before building; latency answers after."""
    _ = Lpf2.heap_size(_lib(), cutoff=1000.0)
    var f = Lpf2.create(_lib(), cutoff=1000.0)
    _ = f.latency()


def test_clear_cache_on_lpf1_needs_a_retune_afterwards() raises:
    """Pins the upstream lpf1 quirk at the API level.

    ma_lpf1_clear_cache zeroes the coefficient rather than the delay register,
    which turns the filter into a pass-through — see the binding tests for the
    detail. `retune` puts the tuning back.
    """
    var f = Lpf1.create(_lib(), cutoff=1000.0)
    f.clear_cache()

    var src = _alternating(N)
    var passthrough = f.process(src)
    for i in range(N):
        assert_equal(passthrough[i], src[i])

    f.retune(cutoff=1000.0)
    assert_true(_abs(f.process(_alternating(N))[N - 1]) < Float32(0.1))


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var f = Lpf2.create(_lib(), cutoff=1000.0)
    f.uninit()
    with assert_raises():
        _ = f.process(_dc(4))
    with assert_raises():
        _ = f.latency()


def test_node_attaches_to_an_engine_graph() raises:
    """The node variant lives in an engine's node graph and can be retuned."""
    var engine = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    var node = LpfNode.create(engine, cutoff=1000.0)
    node.retune(cutoff=500.0)
    node.uninit()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
