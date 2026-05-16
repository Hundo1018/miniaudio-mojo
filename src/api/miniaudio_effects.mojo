from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioDelayNodeHandle, MiniAudioEngineHandle, MiniAudioLpfNodeHandle, MiniAudioSoundHandle
from miniaudio_result_utils import format_result_error


def _attach(
    bridge: MiniAudioCtypes,
    source_node: OpaquePointer[MutExternalOrigin],
    target_node: OpaquePointer[MutExternalOrigin],
) raises:
    var result = bridge.node_attach_output_bus(source_node, 0, target_node, 0)
    if result != 0:
        raise Error(format_result_error(bridge, "node attach output bus failed", result))


def _detach_ignore(
    bridge: MiniAudioCtypes,
    source_node: OpaquePointer[MutExternalOrigin],
):
    _ = bridge.node_detach_output_bus(source_node, 0)


def run_lpf_node_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)
    var lpf = MiniAudioLpfNodeHandle(bridge)

    var sound_node = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
    var lpf_node = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    try:
        engine.init_default(bridge)
        sound.init_from_file(bridge, engine, file_path)
        sound.set_looping(bridge, True)
        lpf.init(bridge, engine, 2, 48000, 3000.0, 2)

        sound_node = sound.get_node(bridge)
        lpf_node = lpf.get_node(bridge)

        _attach(bridge, sound_node, lpf_node)
        _attach(bridge, lpf_node, engine.get_endpoint_node(bridge))

        lpf.set_cutoff(bridge, 4000.0)
        lpf.set_cutoff(bridge, 2400.0)
        lpf.set_cutoff(bridge, 1200.0)
        lpf.set_cutoff(bridge, 600.0)

        sound.start(bridge)
        sound.stop(bridge)
    finally:
        if lpf_node != OpaquePointer[MutExternalOrigin](unsafe_from_address=0):
            _detach_ignore(bridge, lpf_node)
        if sound_node != OpaquePointer[MutExternalOrigin](unsafe_from_address=0):
            _detach_ignore(bridge, sound_node)
        lpf.close(bridge)
        sound.close(bridge)
        engine.close(bridge)

    print("lpf node smoke ok")


def run_reverb_like_chain_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)
    var lpf = MiniAudioLpfNodeHandle(bridge)
    var delay = MiniAudioDelayNodeHandle(bridge)

    var sound_node = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
    var lpf_node = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
    var delay_node = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    try:
        engine.init_default(bridge)
        sound.init_from_file(bridge, engine, file_path)
        sound.set_looping(bridge, True)
        sound.set_volume_f32(bridge, 0.7)

        lpf.init(bridge, engine, 2, 48000, 2200.0, 2)
        delay.init(bridge, engine, 2, 48000, 9600, 0.45)
        delay.set_wet(bridge, 0.7)
        delay.set_dry(bridge, 0.85)

        sound_node = sound.get_node(bridge)
        lpf_node = lpf.get_node(bridge)
        delay_node = delay.get_node(bridge)

        _attach(bridge, sound_node, lpf_node)
        _attach(bridge, lpf_node, delay_node)
        _attach(bridge, delay_node, engine.get_endpoint_node(bridge))

        lpf.set_cutoff(bridge, 1800.0)
        delay.set_decay(bridge, 0.55)

        sound.start(bridge)
        sound.stop(bridge)
    finally:
        if delay_node != OpaquePointer[MutExternalOrigin](unsafe_from_address=0):
            _detach_ignore(bridge, delay_node)
        if lpf_node != OpaquePointer[MutExternalOrigin](unsafe_from_address=0):
            _detach_ignore(bridge, lpf_node)
        if sound_node != OpaquePointer[MutExternalOrigin](unsafe_from_address=0):
            _detach_ignore(bridge, sound_node)
        delay.close(bridge)
        lpf.close(bridge)
        sound.close(bridge)
        engine.close(bridge)

    print("reverb-like chain smoke ok")
