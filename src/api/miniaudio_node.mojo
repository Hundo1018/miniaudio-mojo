from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioEngineHandle, MiniAudioSoundHandle
from miniaudio_result_utils import format_result_error


def _require_node_output_bus(
    bridge: MiniAudioCtypes,
    node: OpaquePointer[MutExternalOrigin],
) raises:
    var output_bus_count = bridge.node_get_output_bus_count(node)
    if output_bus_count < 0:
        raise Error(format_result_error(bridge, "node output bus query failed", output_bus_count))

    if output_bus_count == 0:
        raise Error("node has no output bus")


def _attach_to_endpoint(
    bridge: MiniAudioCtypes,
    source_node: OpaquePointer[MutExternalOrigin],
    endpoint_node: OpaquePointer[MutExternalOrigin],
) raises:
    var result = bridge.node_attach_output_bus(source_node, 0, endpoint_node, 0)
    if result != 0:
        raise Error(format_result_error(bridge, "node attach output bus failed", result))


def _detach_from_endpoint(
    bridge: MiniAudioCtypes,
    source_node: OpaquePointer[MutExternalOrigin],
) raises:
    var result = bridge.node_detach_output_bus(source_node, 0)
    if result != 0:
        raise Error(format_result_error(bridge, "node detach output bus failed", result))


def run_node_attach_detach_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        sound.init_from_file(bridge, engine, file_path)

        var source_node = sound.get_node(bridge)
        var endpoint_node = engine.get_endpoint_node(bridge)

        _require_node_output_bus(bridge, source_node)
        _attach_to_endpoint(bridge, source_node, endpoint_node)
        _detach_from_endpoint(bridge, source_node)
        _attach_to_endpoint(bridge, source_node, endpoint_node)

        sound.start(bridge)
        sound.stop(bridge)
    finally:
        sound.close(bridge)
        engine.close(bridge)

    print("node attach/detach ok")


def run_node_routing_scene_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        sound.init_from_file(bridge, engine, file_path)
        sound.set_looping(bridge, True)

        var source_node = sound.get_node(bridge)
        var endpoint_node = engine.get_endpoint_node(bridge)

        _require_node_output_bus(bridge, source_node)
        _attach_to_endpoint(bridge, source_node, endpoint_node)

        var set_volume_result = bridge.node_set_output_bus_volume(source_node, 0, 0.45)
        if set_volume_result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "node set output bus volume failed",
                    set_volume_result,
                )
            )

        var output_bus_volume = bridge.node_get_output_bus_volume(source_node, 0)
        if output_bus_volume < 0.0:
            raise Error("node get output bus volume failed")

        sound.start(bridge)
        sound.stop(bridge)
    finally:
        sound.close(bridge)
        engine.close(bridge)

    print("node routing scene ok")
