"""TDD tests for the idiomatic high-pass API (RAII Hpf1 / Hpf2 / Hpf / HpfNode).

L3 behavioral: verifies that the biquad-based shapes reject a constant signal
and keep an alternating one, that the first-order shape is the gentle shelf
miniaudio actually implements, that retuning works on a live filter, and that
the node variant attaches to an engine's graph.
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
from miniaudio.filter import Hpf1, Hpf2, Hpf, HpfNode


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


def test_second_order_and_compound_reject_dc() raises:
    """The biquad-based shapes drive a constant signal towards zero."""
    var f2 = Hpf2.create(_lib(), cutoff=1000.0)
    var f4 = Hpf.create(_lib(), cutoff=1000.0, order=UInt32(4))

    assert_true(_abs(f2.process(_dc(N))[N - 1]) < Float32(0.2))
    assert_true(_abs(f4.process(_dc(N))[N - 1]) < Float32(0.2))


def test_first_order_is_a_gentle_shelf() raises:
    """Hpf1 tilts towards highs without nulling DC — see the binding tests."""
    var f1 = Hpf1.create(_lib(), cutoff=1000.0)
    var dc = f1.process(_dc(N))
    assert_almost_equal(dc[N - 1], Float32(0.781), atol=0.01)

    var fast = Hpf1.create(_lib(), cutoff=1000.0)
    assert_true(_abs(fast.process(_alternating(N))[N - 1]) > _abs(dc[N - 1]))


def test_every_order_passes_the_fastest_signal() raises:
    """All three shapes let a signal alternating every frame through."""
    var f1 = Hpf1.create(_lib(), cutoff=1000.0)
    var f2 = Hpf2.create(_lib(), cutoff=1000.0)
    var f4 = Hpf.create(_lib(), cutoff=1000.0, order=UInt32(4))

    assert_true(_abs(f1.process(_alternating(N))[N - 1]) > Float32(0.5))
    assert_true(_abs(f2.process(_alternating(N))[N - 1]) > Float32(0.5))
    assert_true(_abs(f4.process(_alternating(N))[N - 1]) > Float32(0.5))


def test_processing_never_changes_the_frame_count() raises:
    """Filtering is out-of-place and one frame in, one frame out."""
    var f = Hpf2.create(_lib(), cutoff=1000.0)
    assert_equal(len(f.process(_dc(N))), N)


def test_retune_changes_a_live_filter() raises:
    """A retuned filter behaves like one built with the new cutoff."""
    var retuned = Hpf2.create(_lib(), cutoff=100.0)
    retuned.retune(cutoff=8000.0)
    var fresh = Hpf2.create(_lib(), cutoff=8000.0)

    var a = retuned.process(_dc(N))
    var b = fresh.process(_dc(N))
    assert_almost_equal(a[N - 1], b[N - 1], atol=0.001)


def test_preallocated_and_managed_heaps_filter_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = Hpf.create(_lib(), cutoff=1000.0, order=UInt32(4))
    var prealloc = Hpf.create(
        _lib(), cutoff=1000.0, order=UInt32(4), preallocated=True
    )

    var a = managed.process(_alternating(N))
    var b = prealloc.process(_alternating(N))
    for i in range(N):
        assert_equal(a[i], b[i])


def test_heap_size_and_latency_are_queryable() raises:
    """Heap size answers before building; latency answers after."""
    _ = Hpf2.heap_size(_lib(), cutoff=1000.0)
    var f = Hpf2.create(_lib(), cutoff=1000.0)
    _ = f.latency()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var f = Hpf2.create(_lib(), cutoff=1000.0)
    f.uninit()
    with assert_raises():
        _ = f.process(_dc(4))
    with assert_raises():
        _ = f.latency()


def test_node_attaches_to_an_engine_graph() raises:
    """The node variant lives in an engine's node graph and can be retuned."""
    var engine = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    var node = HpfNode.create(engine, cutoff=1000.0)
    node.retune(cutoff=500.0)
    node.uninit()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
