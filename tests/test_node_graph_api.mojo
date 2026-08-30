"""TDD tests for the idiomatic node graph API (RAII NodeGraph).

L3 behavioral: verifies that an empty graph yields nothing, that the graph
reports the shape it was built with, and that its clock can be read and moved.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.node import NodeGraph


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_an_empty_graph_yields_no_frames() raises:
    """With nothing attached to the endpoint there is nothing to pull."""
    var g = NodeGraph.create(_lib())
    assert_equal(len(g.read(UInt64(64))), 0)
    assert_true(g.time() == UInt64(0))


def test_the_graph_reports_the_shape_it_was_built_with() raises:
    """Channels come back as configured, and the endpoint offers an input bus."""
    var g = NodeGraph.create(_lib(), channels=2)
    assert_true(g.channels() == UInt32(2))
    assert_true(g.endpoint_input_bus_count() >= UInt32(1))
    _ = g.processing_size()


def test_the_graph_clock_can_be_moved() raises:
    """Global time starts at zero and can be set."""
    var g = NodeGraph.create(_lib())
    assert_true(g.time() == UInt64(0))
    g.set_time(UInt64(1000))
    assert_true(g.time() == UInt64(1000))


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var g = NodeGraph.create(_lib())
    g.uninit()
    with assert_raises():
        _ = g.channels()
    with assert_raises():
        _ = g.read(UInt64(4))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
