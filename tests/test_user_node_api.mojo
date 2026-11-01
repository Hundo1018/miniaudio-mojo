"""Tests for UserNode: a node whose processing is Mojo code (NodeProcessor).

A source (no input bus) and an effect (one input bus) are read through a plain
node graph and through an offline engine. The processors keep integer state, so
every expected sample is exact.
"""

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_raises, TestSuite

from miniaudio import MaLib, Engine
from miniaudio.node import NodeGraph, OffsetNode, EndpointNode, UserNode, NODE_STATE_STOPPED
from miniaudio.processor import NodeProcessor

comptime Counters = UnsafePointer[Int, MutUntrackedOrigin]


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _graph() raises -> ArcPointer[NodeGraph]:
    return ArcPointer(NodeGraph.create(_lib(), channels=2))


struct Ramp(NodeProcessor):
    """Frame n carries (n mod 100) / 100 on every channel; counts its calls and
    its destruction through `counters` ([0] = process calls, [1] = destroyed)."""

    var n: Int
    var counters: Counters

    def __init__(out self, counters: Counters):
        self.n = 0
        self.counters = counters

    def process(
        mut self,
        input: Span[Float32, ImmutAnyOrigin],
        output: Span[Float32, MutAnyOrigin],
        frame_count: Int,
        channels: Int,
    ):
        self.counters[0] += 1
        for i in range(frame_count):
            var v = Float32(self.n % 100) / 100.0
            for c in range(channels):
                output[i * channels + c] = v
            self.n += 1

    def __del__(deinit self):
        self.counters[1] += 1


struct Doubler(NodeProcessor):
    """An effect: twice its input, silence when nothing is attached."""

    var calls_without_input: Int

    def __init__(out self):
        self.calls_without_input = 0

    def process(
        mut self,
        input: Span[Float32, ImmutAnyOrigin],
        output: Span[Float32, MutAnyOrigin],
        frame_count: Int,
        channels: Int,
    ):
        if len(input) == 0:
            self.calls_without_input += 1
        for i in range(frame_count * channels):
            output[i] = input[i] * 2.0 if i < len(input) else Float32(0)


def _counters() -> List[Int]:
    return List[Int](length=2, fill=0)


def _ptr(mut counters: List[Int]) -> Counters:
    return counters.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()


def test_a_source_node_is_what_the_graph_plays() raises:
    var counters = _counters()
    var g = _graph()
    var ramp = UserNode.create(g, Ramp(_ptr(counters)))
    assert_equal(ramp.input_bus_count(), UInt32(0))
    assert_equal(ramp.output_channels(), UInt32(2))
    ramp.attach_to_endpoint()
    var frames = g[].read(250)
    assert_equal(len(frames), 500)
    for n in range(250):
        assert_equal(frames[2 * n], Float32(n % 100) / 100.0)
        assert_equal(frames[2 * n + 1], frames[2 * n])
    assert_true(counters[0] >= 1)
    _ = ramp^
    assert_equal(counters[1], 1)  # destroyed once, with the node


def test_the_processor_is_reachable_and_mutable() raises:
    var counters = _counters()
    var g = _graph()
    var ramp = UserNode.create(g, Ramp(_ptr(counters)))
    ramp.attach_to_endpoint()
    _ = g[].read(10)
    assert_equal(ramp.processor().n, 10)
    ramp.processor().n = 50  # state changed between reads is what the next read uses
    var frames = g[].read(1)
    assert_equal(frames[0], Float32(0.5))
    _ = ramp^
    assert_equal(counters[1], 1)


def test_an_effect_node_transforms_its_input() raises:
    var g = _graph()
    var src = OffsetNode.create(g, offset=Float32(0.25))
    var fx = UserNode.create(g, Doubler(), input=True)
    assert_equal(fx.input_bus_count(), UInt32(1))
    src.attach_to(fx)
    fx.attach_to_endpoint()
    var frames = g[].read(64)
    for x in frames:
        assert_equal(x, Float32(0.5))
    assert_equal(fx.processor().calls_without_input, 0)
    _ = src^


def test_an_effect_with_nothing_attached_still_runs() raises:
    var g = _graph()
    var fx = UserNode.create(g, Doubler(), input=True)
    fx.attach_to_endpoint()
    var frames = g[].read(32)
    for x in frames:
        assert_equal(x, Float32(0))
    assert_true(fx.processor().calls_without_input >= 1)


def test_a_source_node_in_an_offline_engine() raises:
    var counters = _counters()
    var lib = _lib()
    var engine = ArcPointer(Engine.create_offline(lib, channels=2, sample_rate=48000))
    var g = ArcPointer(NodeGraph.of_engine(engine))
    var ramp = UserNode.create(g, Ramp(_ptr(counters)))
    ramp.attach_to(EndpointNode.of_engine(engine))
    var out = List[Float32]()
    engine[].render(out, 480)
    assert_equal(len(out), 960)
    for n in range(480):
        assert_equal(out[2 * n], Float32(n % 100) / 100.0)
    _ = ramp^
    assert_equal(counters[1], 1)


def test_a_stopped_node_is_not_called() raises:
    var counters = _counters()
    var g = _graph()
    var ramp = UserNode.create(g, Ramp(_ptr(counters)))
    ramp.attach_to_endpoint()
    ramp.set_state(NODE_STATE_STOPPED)
    var frames = g[].read(64)
    assert_equal(counters[0], 0)
    for x in frames:
        assert_equal(x, Float32(0))
    _ = ramp^
    assert_equal(counters[1], 1)


def test_uninit_destroys_the_processor_and_the_accessor_refuses() raises:
    var counters = _counters()
    var g = _graph()
    var ramp = UserNode.create(g, Ramp(_ptr(counters)))
    ramp.uninit()
    assert_equal(counters[1], 1)
    with assert_raises(contains="uninitialised"):
        _ = ramp.processor().n
    _ = ramp^
    assert_equal(counters[1], 1)  # not again


def test_bad_arguments_still_destroy_the_processor_once() raises:
    var counters = _counters()
    var g = _graph()
    with assert_raises(contains="MA_INVALID_ARGS"):
        _ = UserNode.create(g, Ramp(_ptr(counters)), channels=0)
    assert_equal(counters[1], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
