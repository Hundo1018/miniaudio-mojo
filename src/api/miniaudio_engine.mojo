from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioEngineHandle


def run_engine_play_sound_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)

    try:
        engine.init_default(bridge)
        engine.play_sound(bridge, file_path)
    finally:
        engine.close(bridge)

    print("engine play sound ok")


def run_engine_listener_control_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)

    try:
        engine.init_default(bridge)
        engine.listener_set_position(bridge, 0, 0.0, 0.0, 0.0)
        engine.listener_set_direction(bridge, 0, 0.0, 0.0, -1.0)
        engine.listener_set_world_up(bridge, 0, 0.0, 1.0, 0.0)
    finally:
        engine.close(bridge)

    print("engine listener control ok")
