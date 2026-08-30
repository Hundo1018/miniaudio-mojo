"""TDD tests for the idiomatic splitter node API (RAII SplitterNode).

L3 behavioral: verifies that the splitter carries its input to the endpoint and
that both of its output buses carry the same signal.
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
from miniaudio.node import NodeGraph, OffsetNode, SplitterNode


comptime FRAMES: UInt64 = 64


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _graph() raises -> ArcPointer[NodeGraph]:
    return ArcPointer(NodeGraph.create(_lib(), channels=2))


def test_a_splitter_carries_its_input_through() raises:
    """Source -> splitter -> endpoint delivers the source unchanged."""
    var g = _graph()
    var s = SplitterNode.create(g)
    var src = OffsetNode.create(g, offset=Float32(0.3))

    src.attach_to(s)
    s.attach_to_endpoint()

    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    for i in range(len(frames)):
        assert_almost_equal(frames[i], Float32(0.3), atol=0.0001)
    # Both nodes have to outlive the read: dropping a node detaches it, and
    # Mojo destroys a value after its last use rather than at end of scope.
    assert_true(src.belongs_to(g))
    s.attach_to_endpoint()


def test_both_outputs_carry_the_same_signal() raises:
    """Attaching both buses to the endpoint sums the signal with itself."""
    var g = _graph()
    var s = SplitterNode.create(g)
    var src = OffsetNode.create(g, offset=Float32(0.3))

    src.attach_to(s)
    s.attach_to_endpoint(output_bus=0)
    s.attach_to_endpoint(output_bus=1)

    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    assert_almost_equal(frames[0], Float32(0.6), atol=0.0001)
    assert_true(src.belongs_to(g))
    s.attach_to_endpoint()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit attaching raises."""
    var g = _graph()
    var s = SplitterNode.create(g)
    s.uninit()
    with assert_raises():
        s.attach_to_endpoint()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
