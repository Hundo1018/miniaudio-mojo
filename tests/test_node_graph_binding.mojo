"""TDD contract tests for the node graph BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the graph is created standalone, with
no device and no engine, so reading from it is a pure computation. All 9 MA_API
ma_node_graph functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.node_raw as raw


comptime STEREO: UInt32 = 2
comptime FRAMES: UInt64 = 64


def _lib() raises -> MaLib:
    return MaLib.default()


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _graph(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var g = raw.node_graph_alloc(lib)
    assert_equal(raw.node_graph_init(lib, g, STEREO), MA_SUCCESS)
    return g


def test_an_empty_graph_produces_no_frames() raises:
    """With nothing attached the endpoint has nothing to pull.

    The read succeeds but delivers zero frames — miniaudio does not invent
    silence for an empty graph. The clock therefore stays put too; see the node
    suite for the same read once a node is attached.
    """
    var lib = _lib()
    var g = _graph(lib)

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(0))
    assert_equal(raw.node_graph_get_time(lib, g).value, UInt64(0))

    raw.node_graph_free(lib, g)


def test_channels_and_processing_size_are_reported() raises:
    """The graph reports the channel count it was built with."""
    var lib = _lib()
    var g = _graph(lib)

    var ch = raw.node_graph_get_channels(lib, g)
    assert_equal(ch.result, MA_SUCCESS)
    assert_true(ch.value == STEREO)

    assert_equal(raw.node_graph_get_processing_size(lib, g).result, MA_SUCCESS)

    raw.node_graph_free(lib, g)


def test_the_graph_clock_can_be_read_and_set() raises:
    """Global time starts at zero and can be moved."""
    var lib = _lib()
    var g = _graph(lib)

    assert_equal(raw.node_graph_get_time(lib, g).value, UInt64(0))
    assert_equal(raw.node_graph_set_time(lib, g, UInt64(1000)), MA_SUCCESS)
    assert_equal(raw.node_graph_get_time(lib, g).value, UInt64(1000))
    assert_equal(raw.node_graph_set_time(lib, g, UInt64(0)), MA_SUCCESS)
    assert_equal(raw.node_graph_get_time(lib, g).value, UInt64(0))

    raw.node_graph_free(lib, g)


def test_the_endpoint_offers_an_input_bus() raises:
    """The endpoint is bound as what it can be asked: its input bus count."""
    var lib = _lib()
    var g = _graph(lib)

    var rc = raw.node_graph_endpoint_input_bus_count(lib, g)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value >= UInt32(1))

    raw.node_graph_free(lib, g)


def test_operations_on_an_uninitialised_graph_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var g = raw.node_graph_alloc(lib)
    assert_true(g != null_handle())
    var dst = _sink(8)

    assert_equal(raw.node_graph_read(lib, g, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.node_graph_get_channels(lib, g).result, MA_INVALID_ARGS)
    assert_equal(raw.node_graph_get_time(lib, g).result, MA_INVALID_ARGS)
    assert_equal(raw.node_graph_set_time(lib, g, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.node_graph_get_processing_size(lib, g).result, MA_INVALID_ARGS)
    assert_equal(
        raw.node_graph_endpoint_input_bus_count(lib, g).result, MA_INVALID_ARGS
    )

    raw.node_graph_free(lib, g)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var g = _graph(lib)
    assert_equal(raw.node_graph_uninit(lib, g), MA_SUCCESS)
    assert_equal(raw.node_graph_uninit(lib, g), MA_SUCCESS)
    raw.node_graph_free(lib, g)

    assert_equal(raw.node_graph_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.node_graph_init(lib, null_handle(), STEREO), MA_INVALID_ARGS)
    raw.node_graph_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
