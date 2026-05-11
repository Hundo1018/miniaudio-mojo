from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioEngineHandle, MiniAudioSoundHandle


def run_sound_control_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        sound.init_from_file(bridge, engine, file_path)
        sound.set_looping(bridge, False)
        sound.set_volume_f32(bridge, 0.8)
        sound.start(bridge)
        sound.stop(bridge)
    finally:
        sound.close(bridge)
        engine.close(bridge)

    print("sound control ok")


def run_sound_spatial_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        engine.listener_set_position(bridge, 0, 0.0, 0.0, 0.0)
        engine.listener_set_direction(bridge, 0, 0.0, 0.0, -1.0)
        engine.listener_set_world_up(bridge, 0, 0.0, 1.0, 0.0)

        sound.init_from_file(bridge, engine, file_path)
        sound.set_spatialization_enabled(bridge, True)
        sound.set_position(bridge, 1.5, 0.0, -2.0)
        sound.set_rolloff(bridge, 1.0)
        sound.set_min_distance(bridge, 0.25)
        sound.set_max_distance(bridge, 25.0)
        sound.start(bridge)
        sound.stop(bridge)
    finally:
        sound.close(bridge)
        engine.close(bridge)

    print("sound spatial control ok")


def run_sound_spatial_scene_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)

        sound.init_from_file(bridge, engine, file_path)
        sound.set_looping(bridge, True)
        sound.set_volume_f32(bridge, 0.6)
        sound.set_spatialization_enabled(bridge, True)
        sound.set_rolloff(bridge, 1.0)
        sound.set_min_distance(bridge, 0.25)
        sound.set_max_distance(bridge, 40.0)

        engine.listener_set_position(bridge, 0, 0.0, 0.0, 0.0)
        engine.listener_set_direction(bridge, 0, 0.0, 0.0, -1.0)
        engine.listener_set_world_up(bridge, 0, 0.0, 1.0, 0.0)

        sound.set_position(bridge, -1.5, 0.0, -2.0)
        sound.start(bridge)

        sound.set_position(bridge, 1.5, 0.0, -2.0)
        engine.listener_set_position(bridge, 0, 0.5, 0.0, 0.0)
        engine.listener_set_direction(bridge, 0, 0.0, 0.0, -1.0)

        sound.set_position(bridge, 0.0, 0.0, -3.0)
        engine.listener_set_position(bridge, 0, -0.5, 0.0, 0.0)
        engine.listener_set_direction(bridge, 0, 0.2, 0.0, -1.0)

        sound.stop(bridge)
    finally:
        sound.close(bridge)
        engine.close(bridge)

    print("sound spatial scene ok")
