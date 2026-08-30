"""TDD tests for the idiomatic band-pass API (RAII Bpf2 / Bpf / BpfNode).

L3 behavioral: verifies the response that defines the filter, that filtering
never changes the frame count, that a retuned filter matches a freshly built
one, that both init paths agree, and that the node variant attaches to an
engine's graph.
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
from miniaudio.filter import Bpf2, Bpf, BpfNode


comptime N: Int = 256


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


def test_bpf2_response_matches_its_definition() raises:
    """A second-order band-pass rejects both DC and the fastest signal."""
    var f = Bpf2.create(_lib(), cutoff=1000.0)
    var dc = f.process(_dc(N))
    assert_true(_abs(dc[N - 1]) < Float32(0.001))

    var g = Bpf2.create(_lib(), cutoff=1000.0)
    var fast = g.process(_alternating(N))
    assert_true(_abs(fast[N - 1]) < Float32(0.001))


def test_bpf2_processing_never_changes_the_frame_count() raises:
    """Filtering is out-of-place and one frame in, one frame out."""
    var f = Bpf2.create(_lib(), cutoff=1000.0)
    assert_equal(len(f.process(_dc(N))), N)


def test_bpf2_retune_matches_a_freshly_built_filter() raises:
    """A retuned filter settles where a filter built with that tuning does."""
    var retuned = Bpf2.create(_lib(), cutoff=1000.0)
    retuned.retune(cutoff=500.0)
    var fresh = Bpf2.create(_lib(), cutoff=500.0)

    var a = retuned.process(_dc(N))
    var b = fresh.process(_dc(N))
    assert_almost_equal(a[N - 1], b[N - 1], atol=0.001)


def test_bpf2_preallocated_and_managed_heaps_filter_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = Bpf2.create(_lib(), cutoff=1000.0)
    var prealloc = Bpf2.create(_lib(), cutoff=1000.0, preallocated=True)

    var a = managed.process(_dc(N))
    var b = prealloc.process(_dc(N))
    for i in range(N):
        assert_equal(a[i], b[i])


def test_bpf2_heap_size_and_latency_are_queryable() raises:
    """Heap size answers before building; latency answers after."""
    _ = Bpf2.heap_size(_lib(), cutoff=1000.0)
    var f = Bpf2.create(_lib(), cutoff=1000.0)
    _ = f.latency()


def test_bpf2_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var f = Bpf2.create(_lib(), cutoff=1000.0)
    f.uninit()
    with assert_raises():
        _ = f.process(_dc(4))
    with assert_raises():
        _ = f.latency()


def test_bpf_response_matches_its_definition() raises:
    """The compound band-pass rejects both extremes."""
    var f = Bpf.create(_lib(), cutoff=1000.0)
    var dc = f.process(_dc(N))
    assert_true(_abs(dc[N - 1]) < Float32(0.001))

    var g = Bpf.create(_lib(), cutoff=1000.0)
    var fast = g.process(_alternating(N))
    assert_true(_abs(fast[N - 1]) < Float32(0.001))


def test_bpf_processing_never_changes_the_frame_count() raises:
    """Filtering is out-of-place and one frame in, one frame out."""
    var f = Bpf.create(_lib(), cutoff=1000.0)
    assert_equal(len(f.process(_dc(N))), N)


def test_bpf_retune_matches_a_freshly_built_filter() raises:
    """A retuned filter settles where a filter built with that tuning does."""
    var retuned = Bpf.create(_lib(), cutoff=1000.0)
    retuned.retune(cutoff=500.0)
    var fresh = Bpf.create(_lib(), cutoff=500.0)

    var a = retuned.process(_dc(N))
    var b = fresh.process(_dc(N))
    assert_almost_equal(a[N - 1], b[N - 1], atol=0.001)


def test_bpf_preallocated_and_managed_heaps_filter_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = Bpf.create(_lib(), cutoff=1000.0)
    var prealloc = Bpf.create(_lib(), cutoff=1000.0, preallocated=True)

    var a = managed.process(_dc(N))
    var b = prealloc.process(_dc(N))
    for i in range(N):
        assert_equal(a[i], b[i])


def test_bpf_heap_size_and_latency_are_queryable() raises:
    """Heap size answers before building; latency answers after."""
    _ = Bpf.heap_size(_lib(), cutoff=1000.0)
    var f = Bpf.create(_lib(), cutoff=1000.0)
    _ = f.latency()


def test_bpf_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var f = Bpf.create(_lib(), cutoff=1000.0)
    f.uninit()
    with assert_raises():
        _ = f.process(_dc(4))
    with assert_raises():
        _ = f.latency()


def test_bpf_node_attaches_to_an_engine_graph() raises:
    """The node variant lives in an engine's node graph and can be retuned."""
    var engine = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    var node = BpfNode.create(engine, cutoff=1000.0)
    node.retune(cutoff=500.0)
    node.uninit()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
