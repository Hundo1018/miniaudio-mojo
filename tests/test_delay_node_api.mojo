"""TDD tests for the idiomatic delay node API (RAII DelayNode).

L3 behavioral: verifies that the node passes audio when fed from another node,
that each mix control round-trips, and that `dry`/`wet` behave as the input and
output gains miniaudio actually implements rather than as a blend.
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
from miniaudio.node import NodeGraph, OffsetNode, DelayNode


comptime FRAMES: UInt64 = 64


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _graph() raises -> ArcPointer[NodeGraph]:
    return ArcPointer(NodeGraph.create(_lib(), channels=2))


def test_a_delay_node_passes_audio_from_the_node_feeding_it() raises:
    """Source -> delay -> endpoint delivers the source on the first frames."""
    var g = _graph()
    var d = DelayNode.create(g, delay_in_frames=UInt32(16))
    var src = OffsetNode.create(g, offset=Float32(0.25))

    d.set_dry(Float32(1.0))
    d.set_wet(Float32(1.0))
    src.attach_to(d)
    d.attach_to_endpoint()

    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    assert_almost_equal(frames[0], Float32(0.25), atol=0.0001)
    # Both nodes have to outlive the read: dropping a node detaches it, and
    # Mojo destroys a value after its last use rather than at end of scope.
    assert_true(src.belongs_to(g))
    _ = d.wet()


def test_the_mix_controls_round_trip() raises:
    """Each control reads back what was written."""
    var g = _graph()
    var d = DelayNode.create(g, delay_in_frames=UInt32(16))

    d.set_wet(Float32(0.25))
    d.set_dry(Float32(0.75))
    d.set_decay(Float32(0.3))

    assert_almost_equal(d.wet(), Float32(0.25), atol=0.0001)
    assert_almost_equal(d.dry(), Float32(0.75), atol=0.0001)
    assert_almost_equal(d.decay(), Float32(0.3), atol=0.0001)


def test_wet_at_zero_silences_the_node_whatever_dry_is() raises:
    """`wet` is the node's output gain, not the blend its name suggests.

    See `DelayNode.set_wet` and the binding tests: miniaudio scales the whole
    output by `wet`, so there is no un-delayed path to survive it.
    """
    var g = _graph()
    var d = DelayNode.create(g, delay_in_frames=UInt32(16))
    var src = OffsetNode.create(g, offset=Float32(0.4))

    d.set_dry(Float32(1.0))
    d.set_wet(Float32(0.0))
    src.attach_to(d)
    d.attach_to_endpoint()

    var frames = g[].read(FRAMES)
    assert_equal(len(frames), Int(FRAMES) * 2)
    for i in range(len(frames)):
        assert_equal(frames[i], Float32(0))
    assert_true(src.belongs_to(g))
    _ = d.wet()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var g = _graph()
    var d = DelayNode.create(g, delay_in_frames=UInt32(16))
    d.uninit()
    with assert_raises():
        _ = d.wet()
    with assert_raises():
        d.attach_to_endpoint()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
