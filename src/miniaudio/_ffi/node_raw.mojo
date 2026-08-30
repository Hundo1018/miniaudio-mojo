"""Binding layer: raw 1:1 wrappers over the node graph shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in node.mojo.

The graph is created standalone — no device and no engine — so everything here
is deterministic. `ma_node_init` takes a caller-supplied vtable, which a Mojo
function cannot cross the FFI boundary as, so the shim owns a concrete node: an
offset node that adds a constant to its input. With nothing attached it emits
that constant, which makes graph reads observable.

`ma_node_get_node_graph` and `ma_node_graph_get_endpoint` hand out raw pointers
with no safe Mojo home; they are bound as the questions Mojo can ask —
`node_belongs_to_graph` and `node_attach_to_endpoint`.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt, MaBool


@fieldwise_init
struct MaFloat(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a float out-param."""

    var result: Int
    var value: Float32


@fieldwise_init
struct MaState(Copyable, Movable):
    """Raw (result_code, ma_node_state code) pair. started=0, stopped=1."""

    var result: Int
    var value: Int


# ================= ma_node_graph =================


def node_graph_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_node_graph_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def node_graph_free(lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_node_graph_free", NoneType](g)


def node_graph_init(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin], channels: UInt32
) -> Int:
    return Int(lib.handle.call["ma_shim_node_graph_init", Int32](g, channels))


def node_graph_uninit(lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_node_graph_uninit", Int32](g))


def node_graph_read(
    lib: MaLib,
    g: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Pulls frame_count frames through the graph. Returns (code, frames_read)."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_graph_read", Int32](
            g, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def node_graph_get_channels(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_graph_get_channels", Int32](
            g, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_graph_get_time(lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_graph_get_time", Int32](g, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def node_graph_set_time(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin], global_time: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_graph_set_time", Int32](g, global_time)
    )


def node_graph_get_processing_size(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    """Frames the graph processes per internal pass."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_graph_get_processing_size", Int32](
            g, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_graph_endpoint_input_bus_count(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    """The endpoint's input bus count — what the endpoint pointer can safely say."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_graph_endpoint_input_bus_count", Int32](
            g, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


# ================= the shim's offset node =================


def node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_node_alloc", OpaquePointer[MutUntrackedOrigin]]()


def node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_node_free", NoneType](n)


def node_get_heap_size(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin], channels: UInt32
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_heap_size", Int32](
            g, channels, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    offset: Float32,
) -> Int:
    """`offset` is the constant the shim's node adds to its input."""
    return Int(
        lib.handle.call["ma_shim_node_init", Int32](n, g, channels, offset)
    )


def node_init_preallocated(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    offset: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_init_preallocated", Int32](
            n, g, channels, offset
        )
    )


def node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_node_uninit", Int32](n))


def node_attach_output_bus(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    output_bus: UInt32,
    other: OpaquePointer[MutUntrackedOrigin],
    other_input_bus: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_attach_output_bus", Int32](
            n, output_bus, other, other_input_bus
        )
    )


def node_attach_to_endpoint(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    output_bus: UInt32,
    g: OpaquePointer[MutUntrackedOrigin],
    endpoint_input_bus: UInt32 = 0,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_attach_to_endpoint", Int32](
            n, output_bus, g, endpoint_input_bus
        )
    )


def node_detach_output_bus(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], output_bus: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_detach_output_bus", Int32](n, output_bus)
    )


def node_detach_all_output_buses(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_node_detach_all_output_buses", Int32](n))


def node_set_output_bus_volume(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    output_bus: UInt32,
    volume: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_set_output_bus_volume", Int32](
            n, output_bus, volume
        )
    )


def node_get_output_bus_volume(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], output_bus: UInt32
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_output_bus_volume", Int32](
            n, output_bus, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def node_get_input_bus_count(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_input_bus_count", Int32](
            n, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_get_output_bus_count(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_output_bus_count", Int32](
            n, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_get_input_channels(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], bus: UInt32
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_input_channels", Int32](
            n, bus, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_get_output_channels(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], bus: UInt32
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_output_channels", Int32](
            n, bus, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def node_set_state(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], state: Int
) -> Int:
    return Int(lib.handle.call["ma_shim_node_set_state", Int32](n, Int32(state)))


def node_get_state(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> MaState:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_state", Int32](n, holder.unsafe_ptr())
    )
    return MaState(code, Int(holder[0]))


def node_set_state_time(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    state: Int,
    global_time: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_node_set_state_time", Int32](
            n, Int32(state), global_time
        )
    )


def node_get_state_time(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], state: Int
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_state_time", Int32](
            n, Int32(state), holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def node_get_state_by_time(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], global_time: UInt64
) -> MaState:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_state_by_time", Int32](
            n, global_time, holder.unsafe_ptr()
        )
    )
    return MaState(code, Int(holder[0]))


def node_get_state_by_time_range(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    begin: UInt64,
    end: UInt64,
) -> MaState:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_state_by_time_range", Int32](
            n, begin, end, holder.unsafe_ptr()
        )
    )
    return MaState(code, Int(holder[0]))


def node_get_time(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_get_time", Int32](n, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def node_set_time(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], local_time: UInt64
) -> Int:
    return Int(lib.handle.call["ma_shim_node_set_time", Int32](n, local_time))


def node_belongs_to_graph(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
) -> MaBool:
    """get_node_graph, asked as an identity question Mojo can hold."""
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_node_belongs_to_graph", Int32](
            n, g, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


# ================= ma_delay_node =================


def delay_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_delay_node_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def delay_node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_delay_node_free", NoneType](n)


def delay_node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    sample_rate: UInt32,
    delay_in_frames: UInt32,
    decay: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_delay_node_init", Int32](
            n, g, channels, sample_rate, delay_in_frames, decay
        )
    )


def delay_node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_delay_node_uninit", Int32](n))


def delay_node_attach_to_endpoint(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    return Int(
        lib.handle.call["ma_shim_delay_node_attach_to_endpoint", Int32](n, g)
    )


def delay_node_set_wet(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], value: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_delay_node_set_wet", Int32](n, value))


def delay_node_get_wet(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_delay_node_get_wet", Int32](n, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])


def delay_node_set_dry(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], value: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_delay_node_set_dry", Int32](n, value))


def delay_node_get_dry(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_delay_node_get_dry", Int32](n, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])


def delay_node_set_decay(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin], value: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_delay_node_set_decay", Int32](n, value))


def delay_node_get_decay(
    lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_delay_node_get_decay", Int32](
            n, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


# ================= ma_splitter_node =================


def splitter_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_splitter_node_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def splitter_node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_splitter_node_free", NoneType](n)


def splitter_node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    g: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_splitter_node_init", Int32](n, g, channels)
    )


def splitter_node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_splitter_node_uninit", Int32](n))


def splitter_node_attach_to_endpoint(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    output_bus: UInt32,
    g: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    return Int(
        lib.handle.call["ma_shim_splitter_node_attach_to_endpoint", Int32](
            n, output_bus, g
        )
    )
