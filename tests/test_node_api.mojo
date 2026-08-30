"""TDD tests for the idiomatic node API (RAII OffsetNode).

L3 behavioral: verifies that a node attached to the endpoint reaches the output,
that chains accumulate, that bus volume and node state change what is heard,
that the node describes its own buses, and that scheduling against the clock
works.
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
from miniaudio.node import (
    NodeGraph,
    OffsetNode,
    NODE_STATE_STARTED,
    NODE_STATE_STOPPED,
)


comptime FRAMES: UInt64 = 64


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _graph() raises -> ArcPointer[NodeGraph]:
    return ArcPointer(NodeGraph.create(_lib(), channels=2))


def test_a_node_attached_to_the_endpoint_reaches_the_output() raises:
    """The offset node emits its constant and the graph delivers it."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))
    n.attach_to_endpoint()

    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    for i in range(len(frames)):
        assert_almost_equal(frames[i], Float32(0.25), atol=0.0001)
    assert_true(n.belongs_to(g))


def test_chained_nodes_accumulate() raises:
    """A -> B -> endpoint adds both offsets."""
    var g = _graph()
    var a = OffsetNode.create(g, offset=Float32(0.25))
    var b = OffsetNode.create(g, offset=Float32(0.5))
    a.attach_to(b)
    b.attach_to_endpoint()

    var frames = g[].read(FRAMES)
    assert_almost_equal(frames[0], Float32(0.75), atol=0.0001)
    # Both nodes have to outlive the read: dropping a node detaches it, and
    # Mojo destroys a value after its last use rather than at end of scope.
    assert_true(a.belongs_to(g))
    assert_true(b.belongs_to(g))


def test_output_bus_volume_scales_the_contribution() raises:
    """Halving the bus volume halves what reaches the endpoint."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.4))
    n.attach_to_endpoint()
    n.set_volume(Float32(0.5))

    assert_almost_equal(n.volume(), Float32(0.5), atol=0.0001)
    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    assert_almost_equal(frames[0], Float32(0.2), atol=0.0001)
    assert_true(n.belongs_to(g))


def test_a_stopped_node_contributes_nothing() raises:
    """Stopping a node takes it out of the mix."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))
    n.attach_to_endpoint()

    assert_equal(n.state(), NODE_STATE_STARTED)
    n.set_state(NODE_STATE_STOPPED)
    assert_equal(n.state(), NODE_STATE_STOPPED)

    var frames = g[].read(FRAMES)
    for i in range(len(frames)):
        assert_equal(frames[i], Float32(0))
    assert_true(n.belongs_to(g))


def test_detaching_takes_the_node_back_out() raises:
    """Both detach shapes remove the node from the graph."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))

    n.attach_to_endpoint()
    n.detach()
    assert_equal(len(g[].read(FRAMES)), 0)

    n.attach_to_endpoint()
    n.detach_all()
    assert_equal(len(g[].read(FRAMES)), 0)


def test_a_node_describes_its_own_buses() raises:
    """One input bus, one output bus, both with the graph's channel count."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))

    assert_true(n.input_bus_count() == UInt32(1))
    assert_true(n.output_bus_count() == UInt32(1))
    assert_true(n.input_channels() == UInt32(2))
    assert_true(n.output_channels() == UInt32(2))
    assert_true(n.belongs_to(g))


def test_state_can_be_scheduled_against_the_clock() raises:
    """A scheduled stop reads back and the state-by-time queries agree."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))

    n.set_state_time(NODE_STATE_STOPPED, UInt64(500))
    assert_true(n.state_time(NODE_STATE_STOPPED) == UInt64(500))
    assert_equal(n.state_at(UInt64(100)), NODE_STATE_STARTED)
    assert_equal(n.state_at(UInt64(900)), NODE_STATE_STOPPED)
    assert_equal(n.state_in_range(UInt64(0), UInt64(100)), NODE_STATE_STARTED)


def test_local_time_can_be_moved() raises:
    """The node keeps its own clock alongside the graph's."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))

    assert_true(n.time() == UInt64(0))
    n.set_time(UInt64(1234))
    assert_true(n.time() == UInt64(1234))


def test_preallocated_and_managed_heaps_behave_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    _ = OffsetNode.heap_size(_graph())

    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25), preallocated=True)
    n.attach_to_endpoint()
    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    assert_almost_equal(frames[0], Float32(0.25), atol=0.0001)
    assert_true(n.belongs_to(g))


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var g = _graph()
    var n = OffsetNode.create(g, offset=Float32(0.25))
    n.uninit()
    with assert_raises():
        _ = n.state()
    with assert_raises():
        n.attach_to_endpoint()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
