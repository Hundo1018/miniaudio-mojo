"""TDD contract tests for the node BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the graph is standalone, and the node
under test is the shim's own offset node, which adds a constant to its input.
With nothing attached it emits that constant, so a graph read is an assertable
number rather than silence. All 23 MA_API ma_node functions are exercised here
(positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.node_raw as raw


comptime STEREO: UInt32 = 2
comptime FRAMES: UInt64 = 64
comptime STARTED: Int = 0
comptime STOPPED: Int = 1


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


def _node(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin], offset: Float32
) raises -> OpaquePointer[MutUntrackedOrigin]:
    var n = raw.node_alloc(lib)
    assert_equal(raw.node_init(lib, n, g, STEREO, offset), MA_SUCCESS)
    return n


def test_a_node_attached_to_the_endpoint_reaches_the_output() raises:
    """The offset node emits its constant, and reading the graph delivers it."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))
    assert_equal(raw.node_attach_to_endpoint(lib, n, UInt32(0), g), MA_SUCCESS)

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, FRAMES)
    for i in range(len(dst)):
        assert_almost_equal(dst[i], Float32(0.25), atol=0.0001)

    # Pulling frames through the graph advances its clock.
    assert_equal(raw.node_graph_get_time(lib, g).value, FRAMES)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_chained_nodes_accumulate() raises:
    """A -> B -> endpoint: B adds its offset on top of A's."""
    var lib = _lib()
    var g = _graph(lib)
    var a = _node(lib, g, Float32(0.25))
    var b = _node(lib, g, Float32(0.5))

    assert_equal(raw.node_attach_output_bus(lib, a, UInt32(0), b, UInt32(0)), MA_SUCCESS)
    assert_equal(raw.node_attach_to_endpoint(lib, b, UInt32(0), g), MA_SUCCESS)

    var dst = _sink(Int(FRAMES) * 2)
    _ = raw.node_graph_read(lib, g, dst, FRAMES)
    for i in range(len(dst)):
        assert_almost_equal(dst[i], Float32(0.75), atol=0.0001)

    raw.node_free(lib, a)
    raw.node_free(lib, b)
    raw.node_graph_free(lib, g)


def test_output_bus_volume_scales_what_reaches_the_endpoint() raises:
    """Halving the output bus volume halves the signal."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.4))
    _ = raw.node_attach_to_endpoint(lib, n, UInt32(0), g)

    assert_equal(
        raw.node_set_output_bus_volume(lib, n, UInt32(0), Float32(0.5)), MA_SUCCESS
    )
    var vol = raw.node_get_output_bus_volume(lib, n, UInt32(0))
    assert_equal(vol.result, MA_SUCCESS)
    assert_almost_equal(vol.value, Float32(0.5), atol=0.0001)

    var dst = _sink(Int(FRAMES) * 2)
    _ = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_almost_equal(dst[0], Float32(0.2), atol=0.0001)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_a_stopped_node_contributes_nothing() raises:
    """Stopping the node takes it out of the mix."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))
    _ = raw.node_attach_to_endpoint(lib, n, UInt32(0), g)

    var started = raw.node_get_state(lib, n)
    assert_equal(started.result, MA_SUCCESS)
    assert_equal(started.value, STARTED)

    assert_equal(raw.node_set_state(lib, n, STOPPED), MA_SUCCESS)
    assert_equal(raw.node_get_state(lib, n).value, STOPPED)

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    for i in range(Int(rc.value) * 2):
        assert_equal(dst[i], Float32(0))

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_detaching_removes_the_node_from_the_mix() raises:
    """Both detach entry points take the node back out of the graph."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    _ = raw.node_attach_to_endpoint(lib, n, UInt32(0), g)
    assert_equal(raw.node_detach_output_bus(lib, n, UInt32(0)), MA_SUCCESS)
    var dst = _sink(Int(FRAMES) * 2)
    assert_equal(raw.node_graph_read(lib, g, dst, FRAMES).value, UInt64(0))

    _ = raw.node_attach_to_endpoint(lib, n, UInt32(0), g)
    assert_equal(raw.node_detach_all_output_buses(lib, n), MA_SUCCESS)
    assert_equal(raw.node_graph_read(lib, g, dst, FRAMES).value, UInt64(0))

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_bus_counts_and_channels_describe_the_node() raises:
    """The offset node has one input bus and one output bus, both stereo."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    assert_true(raw.node_get_input_bus_count(lib, n).value == UInt32(1))
    assert_true(raw.node_get_output_bus_count(lib, n).value == UInt32(1))
    assert_true(raw.node_get_input_channels(lib, n, UInt32(0)).value == STEREO)
    assert_true(raw.node_get_output_channels(lib, n, UInt32(0)).value == STEREO)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_state_can_be_scheduled_against_the_clock() raises:
    """A scheduled state change reads back, and the state-by-time queries agree."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    assert_equal(raw.node_set_state_time(lib, n, STOPPED, UInt64(500)), MA_SUCCESS)
    var when = raw.node_get_state_time(lib, n, STOPPED)
    assert_equal(when.result, MA_SUCCESS)
    assert_equal(when.value, UInt64(500))

    var before = raw.node_get_state_by_time(lib, n, UInt64(100))
    assert_equal(before.result, MA_SUCCESS)
    assert_equal(before.value, STARTED)
    assert_equal(raw.node_get_state_by_time(lib, n, UInt64(900)).value, STOPPED)

    var span = raw.node_get_state_by_time_range(lib, n, UInt64(0), UInt64(100))
    assert_equal(span.result, MA_SUCCESS)
    assert_equal(span.value, STARTED)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_local_time_can_be_read_and_set() raises:
    """The node keeps its own clock alongside the graph's."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    assert_equal(raw.node_get_time(lib, n).value, UInt64(0))
    assert_equal(raw.node_set_time(lib, n, UInt64(1234)), MA_SUCCESS)
    assert_equal(raw.node_get_time(lib, n).value, UInt64(1234))

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_a_node_knows_which_graph_it_belongs_to() raises:
    """The graph identity question, which is how get_node_graph is bound."""
    var lib = _lib()
    var g = _graph(lib)
    var other = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    var mine = raw.node_belongs_to_graph(lib, n, g)
    assert_equal(mine.result, MA_SUCCESS)
    assert_true(mine.value)
    assert_true(not raw.node_belongs_to_graph(lib, n, other).value)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)
    raw.node_graph_free(lib, other)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path produces the same audio as the managed one."""
    var lib = _lib()
    var size = raw.node_get_heap_size(lib, _graph(lib), STEREO)
    assert_equal(size.result, MA_SUCCESS)

    var g = _graph(lib)
    var n = raw.node_alloc(lib)
    assert_equal(
        raw.node_init_preallocated(lib, n, g, STEREO, Float32(0.25)), MA_SUCCESS
    )
    _ = raw.node_attach_to_endpoint(lib, n, UInt32(0), g)

    var dst = _sink(Int(FRAMES) * 2)
    _ = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_almost_equal(dst[0], Float32(0.25), atol=0.0001)

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_operations_on_an_uninitialised_node_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var g = _graph(lib)
    var n = raw.node_alloc(lib)
    assert_true(n != null_handle())

    assert_equal(raw.node_attach_to_endpoint(lib, n, UInt32(0), g), MA_INVALID_ARGS)
    assert_equal(raw.node_detach_output_bus(lib, n, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.node_detach_all_output_buses(lib, n), MA_INVALID_ARGS)
    assert_equal(
        raw.node_set_output_bus_volume(lib, n, UInt32(0), Float32(1)), MA_INVALID_ARGS
    )
    assert_equal(raw.node_get_output_bus_volume(lib, n, UInt32(0)).result, MA_INVALID_ARGS)
    assert_equal(raw.node_get_input_bus_count(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.node_get_output_bus_count(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.node_get_input_channels(lib, n, UInt32(0)).result, MA_INVALID_ARGS)
    assert_equal(raw.node_get_output_channels(lib, n, UInt32(0)).result, MA_INVALID_ARGS)
    assert_equal(raw.node_set_state(lib, n, STOPPED), MA_INVALID_ARGS)
    assert_equal(raw.node_get_state(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.node_set_state_time(lib, n, STOPPED, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.node_get_state_time(lib, n, STOPPED).result, MA_INVALID_ARGS)
    assert_equal(raw.node_get_state_by_time(lib, n, UInt64(0)).result, MA_INVALID_ARGS)
    assert_equal(
        raw.node_get_state_by_time_range(lib, n, UInt64(0), UInt64(1)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.node_get_time(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.node_set_time(lib, n, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.node_belongs_to_graph(lib, n, g).result, MA_INVALID_ARGS)
    assert_equal(
        raw.node_attach_output_bus(lib, n, UInt32(0), n, UInt32(0)), MA_INVALID_ARGS
    )

    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var g = _graph(lib)
    var n = _node(lib, g, Float32(0.25))

    assert_equal(raw.node_uninit(lib, n), MA_SUCCESS)
    assert_equal(raw.node_uninit(lib, n), MA_SUCCESS)
    raw.node_free(lib, n)

    assert_equal(raw.node_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.node_init(lib, null_handle(), g, STEREO, Float32(0)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.node_init_preallocated(lib, null_handle(), g, STEREO, Float32(0)),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.node_get_heap_size(lib, null_handle(), STEREO).result, MA_INVALID_ARGS)
    raw.node_free(lib, null_handle())
    raw.node_graph_free(lib, g)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
