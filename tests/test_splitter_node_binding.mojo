"""TDD contract tests for the splitter node BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a standalone graph, fed by the shim's
offset node. All 3 MA_API ma_splitter_node functions are exercised here
(positive and negative paths).
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


def test_a_splitter_passes_its_input_to_the_endpoint() raises:
    """One output bus of the splitter carries the input through unchanged."""
    var lib = _lib()
    var g = _graph(lib)
    var s = raw.splitter_node_alloc(lib)
    assert_true(s != null_handle())
    assert_equal(raw.splitter_node_init(lib, s, g, STEREO), MA_SUCCESS)

    var src = raw.node_alloc(lib)
    assert_equal(raw.node_init(lib, src, g, STEREO, Float32(0.3)), MA_SUCCESS)
    assert_equal(
        raw.node_attach_output_bus(lib, src, UInt32(0), s, UInt32(0)), MA_SUCCESS
    )
    assert_equal(
        raw.splitter_node_attach_to_endpoint(lib, s, UInt32(0), g), MA_SUCCESS
    )

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    for i in range(len(dst)):
        assert_almost_equal(dst[i], Float32(0.3), atol=0.0001)

    raw.node_free(lib, src)
    raw.splitter_node_free(lib, s)
    raw.node_graph_free(lib, g)


def test_both_splitter_outputs_carry_the_same_signal() raises:
    """Attaching both output buses to the endpoint sums the signal with itself."""
    var lib = _lib()
    var g = _graph(lib)
    var s = raw.splitter_node_alloc(lib)
    _ = raw.splitter_node_init(lib, s, g, STEREO)

    var src = raw.node_alloc(lib)
    _ = raw.node_init(lib, src, g, STEREO, Float32(0.3))
    _ = raw.node_attach_output_bus(lib, src, UInt32(0), s, UInt32(0))
    _ = raw.splitter_node_attach_to_endpoint(lib, s, UInt32(0), g)
    _ = raw.splitter_node_attach_to_endpoint(lib, s, UInt32(1), g)

    var dst = _sink(Int(FRAMES) * 2)
    _ = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_almost_equal(dst[0], Float32(0.6), atol=0.0001)

    raw.node_free(lib, src)
    raw.splitter_node_free(lib, s)
    raw.node_graph_free(lib, g)


def test_operations_on_an_uninitialised_splitter_are_invalid() raises:
    """Attaching a handle that was never initialised is rejected."""
    var lib = _lib()
    var g = _graph(lib)
    var s = raw.splitter_node_alloc(lib)

    assert_equal(
        raw.splitter_node_attach_to_endpoint(lib, s, UInt32(0), g), MA_INVALID_ARGS
    )

    raw.splitter_node_free(lib, s)
    raw.node_graph_free(lib, g)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var g = _graph(lib)
    var s = raw.splitter_node_alloc(lib)
    _ = raw.splitter_node_init(lib, s, g, STEREO)

    assert_equal(raw.splitter_node_uninit(lib, s), MA_SUCCESS)
    assert_equal(raw.splitter_node_uninit(lib, s), MA_SUCCESS)
    raw.splitter_node_free(lib, s)

    assert_equal(raw.splitter_node_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.splitter_node_init(lib, null_handle(), g, STEREO), MA_INVALID_ARGS
    )
    raw.splitter_node_free(lib, null_handle())
    raw.node_graph_free(lib, g)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
