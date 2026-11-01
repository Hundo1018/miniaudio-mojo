"""Contract tests for the raw user-node binding (ma_shim_node_init_user / _user).

The shim takes the processor over whether init succeeds or not, so every
rejected call must still run the drop callback exactly once.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
from miniaudio.processor import NodeProcessor
from miniaudio._ffi.stream_raw import stream_leak
import miniaudio._ffi.node_raw as raw


comptime Opaque = OpaquePointer[MutUntrackedOrigin]


struct Flat(NodeProcessor):
    var value: Float32
    var dropped: UnsafePointer[Int, MutUntrackedOrigin]

    def __init__(out self, value: Float32, dropped: UnsafePointer[Int, MutUntrackedOrigin]):
        self.value = value
        self.dropped = dropped

    def process(
        mut self,
        input: Span[Float32, ImmutAnyOrigin],
        output: Span[Float32, MutAnyOrigin],
        frame_count: Int,
        channels: Int,
    ):
        for i in range(frame_count * channels):
            output[i] = self.value

    def __del__(deinit self):
        self.dropped[] += 1


def _lib() raises -> MaLib:
    return MaLib.default()


def _graph(lib: MaLib) raises -> Opaque:
    var g = raw.node_graph_alloc(lib)
    assert_equal(raw.node_graph_init(lib, g, 2), MA_SUCCESS)
    return g


def test_init_user_reads_and_drops_once() raises:
    var lib = _lib()
    var dropped = List[Int](length=1, fill=0)
    var dp = dropped.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    var g = _graph(lib)
    var n = raw.node_alloc(lib)
    assert_equal(raw.node_init_user(lib, n, g, 2, 0, stream_leak(Flat(0.125, dp))), MA_SUCCESS)
    assert_true(raw.node_user(lib, n) != null_handle())
    assert_equal(raw.node_attach_to_endpoint(lib, n, 0, g, 0), MA_SUCCESS)
    var out = List[Float32](length=16, fill=0)
    var rc = raw.node_graph_read(lib, g, out, 8)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(out[0], Float32(0.125))
    assert_equal(dropped[0], 0)
    assert_equal(raw.node_uninit(lib, n), MA_SUCCESS)
    assert_equal(dropped[0], 1)
    assert_equal(raw.node_user(lib, n), null_handle())  # gone after uninit
    raw.node_free(lib, n)
    assert_equal(dropped[0], 1)  # free does not drop it again
    raw.node_graph_free(lib, g)


def test_rejected_inits_drop_the_processor() raises:
    var lib = _lib()
    var dropped = List[Int](length=1, fill=0)
    var dp = dropped.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    var g = _graph(lib)
    var n = raw.node_alloc(lib)
    assert_equal(raw.node_init_user(lib, null_handle(), g, 2, 0, stream_leak(Flat(0, dp))), MA_INVALID_ARGS)
    assert_equal(raw.node_init_user(lib, n, null_handle(), 2, 0, stream_leak(Flat(0, dp))), MA_INVALID_ARGS)
    assert_equal(raw.node_init_user(lib, n, g, 0, 0, stream_leak(Flat(0, dp))), MA_INVALID_ARGS)
    assert_equal(raw.node_init_user(lib, n, g, 2, 2, stream_leak(Flat(0, dp))), MA_INVALID_ARGS)
    assert_equal(dropped[0], 4)
    # no drop callback: nothing could free the user pointer, so nothing is touched
    assert_equal(raw.node_init_user_ptrs(lib, n, g, 2, 0, null_handle(), null_handle(), null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.node_user(lib, n), null_handle())
    assert_equal(raw.node_user(lib, null_handle()), null_handle())
    raw.node_free(lib, n)
    raw.node_graph_free(lib, g)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
