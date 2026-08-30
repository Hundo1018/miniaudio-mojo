"""Idiomatic node graph API (Layer 3).

A node graph is a tree of processing nodes feeding an endpoint; reading from the
graph pulls audio through it. `NodeGraph` here is standalone — no device and no
engine — so it is deterministic and needs no hardware.

`OffsetNode` is the shim's own node. miniaudio's `ma_node_init` takes a vtable
supplied by the caller, and a Mojo function cannot cross the FFI boundary as a
function pointer on this toolchain, so the concrete node lives in C: it adds a
constant to whatever arrives on its input bus. With nothing attached it emits
that constant on its own, which makes graph reads observable, and two of them in
series produce twice the offset.

`DelayNode` and `SplitterNode` are miniaudio's own nodes, wrapped the same way.

Nodes keep their graph alive: every node holds a reference to the `NodeGraph`
it was built against, so the graph cannot be dropped out from under it.

**A node's attachment lasts only as long as the node value.** Dropping a node
detaches it, and Mojo destroys a value after its *last use*, not at the end of
the enclosing scope. A source node that is only ever touched when it is attached
is therefore gone before the graph is read:

    var src = OffsetNode.create(graph, offset=0.25)
    src.attach_to(delay)          # last use of `src`...
    var frames = graph[].read(64) # ...so it is already detached: no frames

Keep a node in use for as long as it should be heard — read something back from
it after the graph read, or hold it in a longer-lived binding.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.node_raw as raw


comptime NODE_STATE_STARTED = Int(0)
comptime NODE_STATE_STOPPED = Int(1)


struct NodeGraph(Movable):
    """A standalone graph of processing nodes feeding an endpoint (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(lib: ArcPointer[MaLib], *, channels: UInt32 = 2) raises -> Self:
        """An empty graph. Attach nodes to its endpoint, then read from it."""
        var ptr = raw.node_graph_alloc(lib[])
        if ptr == null_handle():
            raise Error("node_graph_alloc failed (out of memory)")
        var code = raw.node_graph_init(lib[], ptr, channels)
        if code != MA_SUCCESS:
            raw.node_graph_free(lib[], ptr)
            raise Error(lib[].describe("node graph init failed", code))
        return Self(lib.copy(), ptr, channels)

    def read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Pull frame_count frames through the graph."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.node_graph_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node graph read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def channels(self) raises -> UInt32:
        var rc = raw.node_graph_get_channels(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node graph channels failed", rc.result)
            )
        return rc.value

    def time(self) raises -> UInt64:
        """The graph's global time, in frames."""
        var rc = raw.node_graph_get_time(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node graph time failed", rc.result))
        return rc.value

    def set_time(mut self, global_time: UInt64) raises:
        var code = raw.node_graph_set_time(self._lib[], self._ptr, global_time)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node graph set_time failed", code))

    def processing_size(self) raises -> UInt32:
        """Frames the graph processes per internal pass."""
        var rc = raw.node_graph_get_processing_size(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node graph processing size failed", rc.result)
            )
        return rc.value

    def endpoint_input_bus_count(self) raises -> UInt32:
        """How many input buses the endpoint offers for nodes to attach to."""
        var rc = raw.node_graph_endpoint_input_bus_count(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node graph endpoint failed", rc.result)
            )
        return rc.value

    def uninit(mut self) raises:
        """Release the graph early; the handle stays valid but empty."""
        var code = raw.node_graph_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node graph uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.node_graph_free(self._lib[], self._ptr)


struct OffsetNode(Movable):
    """The shim's own node: adds a constant to its input bus (RAII).

    It exists because a node's processing callback has to live in C. Attach it
    to the graph's endpoint and read: with no input of its own it emits the
    offset, so the graph produces a constant signal you can assert on.
    """

    var _lib: ArcPointer[MaLib]
    var _graph: ArcPointer[NodeGraph]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var graph: ArcPointer[NodeGraph],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._graph = graph^
        self._ptr = ptr

    @staticmethod
    def heap_size(graph: ArcPointer[NodeGraph], *, channels: UInt32 = 2) raises -> UInt64:
        """Working-heap size for a node in this graph, without building one."""
        var lib = graph[]._lib.copy()
        var rc = raw.node_get_heap_size(lib[], graph[]._ptr, channels)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("node heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        graph: ArcPointer[NodeGraph],
        *,
        offset: Float32,
        channels: UInt32 = 2,
        preallocated: Bool = False,
    ) raises -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var lib = graph[]._lib.copy()
        var ptr = raw.node_alloc(lib[])
        if ptr == null_handle():
            raise Error("node_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.node_init_preallocated(
                lib[], ptr, graph[]._ptr, channels, offset
            )
        else:
            code = raw.node_init(lib[], ptr, graph[]._ptr, channels, offset)
        if code != MA_SUCCESS:
            raw.node_free(lib[], ptr)
            raise Error(lib[].describe("node init failed", code))
        return Self(lib^, graph.copy(), ptr)

    def attach_to(
        mut self,
        other: Self,
        *,
        output_bus: UInt32 = 0,
        other_input_bus: UInt32 = 0,
    ) raises:
        """Feed this node's output into another offset node's input."""
        self._attach(other._ptr, output_bus, other_input_bus)

    def attach_to(
        mut self,
        other: DelayNode,
        *,
        output_bus: UInt32 = 0,
        other_input_bus: UInt32 = 0,
    ) raises:
        """Feed this node's output into a delay node's input."""
        self._attach(other._ptr, output_bus, other_input_bus)

    def attach_to(
        mut self,
        other: SplitterNode,
        *,
        output_bus: UInt32 = 0,
        other_input_bus: UInt32 = 0,
    ) raises:
        """Feed this node's output into a splitter node's input."""
        self._attach(other._ptr, output_bus, other_input_bus)

    def _attach(
        mut self,
        other: OpaquePointer[MutUntrackedOrigin],
        output_bus: UInt32,
        other_input_bus: UInt32,
    ) raises:
        """Shared body: the shim resolves any node handle to its ma_node."""
        var code = raw.node_attach_output_bus(
            self._lib[], self._ptr, output_bus, other, other_input_bus
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node attach failed", code))

    def attach_to_endpoint(
        mut self, *, output_bus: UInt32 = 0, endpoint_input_bus: UInt32 = 0
    ) raises:
        """Feed this node's output straight into the graph's endpoint."""
        var code = raw.node_attach_to_endpoint(
            self._lib[], self._ptr, output_bus, self._graph[]._ptr, endpoint_input_bus
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node attach to endpoint failed", code))

    def detach(mut self, *, output_bus: UInt32 = 0) raises:
        var code = raw.node_detach_output_bus(self._lib[], self._ptr, output_bus)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node detach failed", code))

    def detach_all(mut self) raises:
        var code = raw.node_detach_all_output_buses(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node detach all failed", code))

    def set_volume(mut self, volume: Float32, *, output_bus: UInt32 = 0) raises:
        var code = raw.node_set_output_bus_volume(
            self._lib[], self._ptr, output_bus, volume
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node set volume failed", code))

    def volume(self, *, output_bus: UInt32 = 0) raises -> Float32:
        var rc = raw.node_get_output_bus_volume(self._lib[], self._ptr, output_bus)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node volume failed", rc.result))
        return rc.value

    def input_bus_count(self) raises -> UInt32:
        var rc = raw.node_get_input_bus_count(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node input bus count failed", rc.result)
            )
        return rc.value

    def output_bus_count(self) raises -> UInt32:
        var rc = raw.node_get_output_bus_count(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node output bus count failed", rc.result)
            )
        return rc.value

    def input_channels(self, *, bus: UInt32 = 0) raises -> UInt32:
        var rc = raw.node_get_input_channels(self._lib[], self._ptr, bus)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node input channels failed", rc.result)
            )
        return rc.value

    def output_channels(self, *, bus: UInt32 = 0) raises -> UInt32:
        var rc = raw.node_get_output_channels(self._lib[], self._ptr, bus)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node output channels failed", rc.result)
            )
        return rc.value

    def set_state(mut self, state: Int) raises:
        """NODE_STATE_STARTED or NODE_STATE_STOPPED."""
        var code = raw.node_set_state(self._lib[], self._ptr, state)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node set state failed", code))

    def state(self) raises -> Int:
        var rc = raw.node_get_state(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node state failed", rc.result))
        return rc.value

    def set_state_time(mut self, state: Int, global_time: UInt64) raises:
        """Schedule `state` to take effect at a global time."""
        var code = raw.node_set_state_time(
            self._lib[], self._ptr, state, global_time
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node set state time failed", code))

    def state_time(self, state: Int) raises -> UInt64:
        var rc = raw.node_get_state_time(self._lib[], self._ptr, state)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node state time failed", rc.result))
        return rc.value

    def state_at(self, global_time: UInt64) raises -> Int:
        """What the node's state will be at a given global time."""
        var rc = raw.node_get_state_by_time(self._lib[], self._ptr, global_time)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node state at failed", rc.result))
        return rc.value

    def state_in_range(self, begin: UInt64, end: UInt64) raises -> Int:
        """The node's state across a span of global time."""
        var rc = raw.node_get_state_by_time_range(
            self._lib[], self._ptr, begin, end
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("node state in range failed", rc.result)
            )
        return rc.value

    def time(self) raises -> UInt64:
        """The node's local time, in frames."""
        var rc = raw.node_get_time(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node time failed", rc.result))
        return rc.value

    def set_time(mut self, local_time: UInt64) raises:
        var code = raw.node_set_time(self._lib[], self._ptr, local_time)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node set time failed", code))

    def belongs_to(self, graph: ArcPointer[NodeGraph]) raises -> Bool:
        """Whether this node lives in that graph."""
        var rc = raw.node_belongs_to_graph(self._lib[], self._ptr, graph[]._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("node graph identity failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.node_free(self._lib[], self._ptr)


struct DelayNode(Movable):
    """miniaudio's delay/echo node (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _graph: ArcPointer[NodeGraph]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var graph: ArcPointer[NodeGraph],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._graph = graph^
        self._ptr = ptr

    @staticmethod
    def create(
        graph: ArcPointer[NodeGraph],
        *,
        delay_in_frames: UInt32,
        decay: Float32 = Float32(0.5),
        channels: UInt32 = 2,
        sample_rate: UInt32 = 48000,
    ) raises -> Self:
        var lib = graph[]._lib.copy()
        var ptr = raw.delay_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("delay_node_alloc failed (out of memory)")

        var code = raw.delay_node_init(
            lib[], ptr, graph[]._ptr, channels, sample_rate, delay_in_frames, decay
        )
        if code != MA_SUCCESS:
            raw.delay_node_free(lib[], ptr)
            raise Error(lib[].describe("delay node init failed", code))
        return Self(lib^, graph.copy(), ptr)

    def attach_to_endpoint(mut self) raises:
        var code = raw.delay_node_attach_to_endpoint(
            self._lib[], self._ptr, self._graph[]._ptr
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node attach failed", code))

    def set_wet(mut self, value: Float32) raises:
        """Output gain of the whole node — *not* a wet/dry blend.

        miniaudio computes `buffer = buffer*decay + in*dry` and then
        `out = buffer*wet`, so there is no separate un-delayed path: `wet` at 0
        silences the node whatever `dry` is, and the immediate signal comes out
        scaled by `dry * wet`.
        """
        var code = raw.delay_node_set_wet(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node set wet failed", code))

    def wet(self) raises -> Float32:
        var rc = raw.delay_node_get_wet(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node wet failed", rc.result))
        return rc.value

    def set_dry(mut self, value: Float32) raises:
        """Gain applied to the signal going *into* the delay line.

        See `set_wet` — despite the name this is not an un-delayed path.
        """
        var code = raw.delay_node_set_dry(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node set dry failed", code))

    def dry(self) raises -> Float32:
        var rc = raw.delay_node_get_dry(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node dry failed", rc.result))
        return rc.value

    def set_decay(mut self, value: Float32) raises:
        """Feedback: how much each echo carries into the next."""
        var code = raw.delay_node_set_decay(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node set decay failed", code))

    def decay(self) raises -> Float32:
        var rc = raw.delay_node_get_decay(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node decay failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.delay_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("delay node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.delay_node_free(self._lib[], self._ptr)


struct SplitterNode(Movable):
    """miniaudio's splitter node: one input, two identical outputs (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _graph: ArcPointer[NodeGraph]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var graph: ArcPointer[NodeGraph],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._graph = graph^
        self._ptr = ptr

    @staticmethod
    def create(graph: ArcPointer[NodeGraph], *, channels: UInt32 = 2) raises -> Self:
        var lib = graph[]._lib.copy()
        var ptr = raw.splitter_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("splitter_node_alloc failed (out of memory)")

        var code = raw.splitter_node_init(lib[], ptr, graph[]._ptr, channels)
        if code != MA_SUCCESS:
            raw.splitter_node_free(lib[], ptr)
            raise Error(lib[].describe("splitter node init failed", code))
        return Self(lib^, graph.copy(), ptr)

    def attach_to_endpoint(mut self, *, output_bus: UInt32 = 0) raises:
        var code = raw.splitter_node_attach_to_endpoint(
            self._lib[], self._ptr, output_bus, self._graph[]._ptr
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("splitter node attach failed", code))

    def uninit(mut self) raises:
        """Detach and release the node early; the handle stays valid but empty."""
        var code = raw.splitter_node_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("splitter node uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.splitter_node_free(self._lib[], self._ptr)
