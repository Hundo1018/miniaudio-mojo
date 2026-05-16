from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioEngineHandle, MiniAudioSoundGroupHandle, MiniAudioSoundHandle
from miniaudio_errors import MA_INVALID_ARGS


def run_sound_group_control_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var group = MiniAudioSoundGroupHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        group.init_default(bridge, engine)
        group.set_volume_f32(bridge, 0.35)

        var group_volume = group.get_volume_f32(bridge)
        if group_volume < 0.0:
            raise Error("sound group volume must be non-negative")

        sound.init_from_file_in_group(bridge, engine, group.raw, file_path)
        group.start(bridge)
        sound.start(bridge)
        sound.stop(bridge)
        group.stop(bridge)
    finally:
        sound.close(bridge)
        group.close(bridge)
        engine.close(bridge)

    print("sound group control ok")


def run_sound_group_extended_controls_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var parent_group = MiniAudioSoundGroupHandle(bridge)
    var child_group = MiniAudioSoundGroupHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        parent_group.init_default(bridge, engine)
        child_group.init_with_parent(bridge, engine, parent_group.raw)

        parent_group.set_volume_f32(bridge, 0.5)
        child_group.set_pan_f32(bridge, -0.25)
        child_group.set_pitch_f32(bridge, 1.1)
        child_group.set_spatialization_enabled(bridge, True)

        var pan = child_group.get_pan_f32(bridge)
        var pitch = child_group.get_pitch_f32(bridge)
        var spatial_enabled = child_group.is_spatialization_enabled(bridge)

        if pan < -1.0 or pan > 1.0:
            raise Error("sound group pan must be in [-1, 1]")
        if pitch <= 0.0:
            raise Error("sound group pitch must be > 0")
        if not spatial_enabled:
            raise Error("sound group spatialization should be enabled")

        sound.init_from_file_in_group(bridge, engine, child_group.raw, file_path)
        parent_group.start(bridge)
        child_group.start(bridge)
        sound.start(bridge)
        sound.stop(bridge)
        child_group.stop(bridge)
        parent_group.stop(bridge)
    finally:
        sound.close(bridge)
        child_group.close(bridge)
        parent_group.close(bridge)
        engine.close(bridge)

    print("sound group extended controls ok")


def run_sound_group_spatial_controls_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var group = MiniAudioSoundGroupHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        group.init_default(bridge, engine)
        group.set_spatialization_enabled(bridge, True)
        group.set_position(bridge, 0.5, 0.0, -2.0)
        group.set_direction(bridge, 0.0, 0.0, -1.0)
        group.set_velocity(bridge, 0.1, 0.0, 0.0)
        group.set_rolloff(bridge, 1.0)
        group.set_min_distance(bridge, 0.25)
        group.set_max_distance(bridge, 30.0)

        var rolloff = group.get_rolloff(bridge)
        var min_distance = group.get_min_distance(bridge)
        var max_distance = group.get_max_distance(bridge)

        if rolloff < 0.0:
            raise Error("sound group rolloff must be non-negative")
        if min_distance < 0.0:
            raise Error("sound group min distance must be non-negative")
        if max_distance < min_distance:
            raise Error("sound group max distance must be >= min distance")

        sound.init_from_file_in_group(bridge, engine, group.raw, file_path)
        group.start(bridge)
        sound.start(bridge)
        sound.stop(bridge)
        group.stop(bridge)
    finally:
        sound.close(bridge)
        group.close(bridge)
        engine.close(bridge)

    print("sound group spatial controls ok")


def run_sound_group_attenuation_controls_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var group = MiniAudioSoundGroupHandle(bridge)
    var sound = MiniAudioSoundHandle(bridge)

    try:
        engine.init_default(bridge)
        group.init_default(bridge, engine)
        group.set_spatialization_enabled(bridge, True)

        var current_attenuation_model = group.get_attenuation_model(bridge)
        var current_positioning = group.get_positioning(bridge)

        group.set_attenuation_model(bridge, current_attenuation_model)
        group.set_positioning(bridge, current_positioning)
        group.set_pinned_listener_index(bridge, UInt32(0))
        group.set_cone(bridge, 0.3, 1.2, 0.5)
        group.set_doppler_factor(bridge, 1.0)
        group.set_directional_attenuation_factor(bridge, 0.8)

        var pinned_listener = group.get_pinned_listener_index(bridge)
        var cone_inner = group.get_cone_inner_angle(bridge)
        var cone_outer = group.get_cone_outer_angle(bridge)
        var cone_outer_gain = group.get_cone_outer_gain(bridge)
        var doppler = group.get_doppler_factor(bridge)
        var directional = group.get_directional_attenuation_factor(bridge)

        if pinned_listener < 0:
            raise Error("sound group pinned listener must be non-negative")
        if cone_inner < 0.0 or cone_outer < cone_inner:
            raise Error("sound group cone angles must be valid")
        if cone_outer_gain < 0.0:
            raise Error("sound group cone outer gain must be non-negative")
        if doppler < 0.0:
            raise Error("sound group doppler must be non-negative")
        if directional < 0.0:
            raise Error("sound group directional attenuation must be non-negative")

        sound.init_from_file_in_group(bridge, engine, group.raw, file_path)
        group.start(bridge)
        sound.start(bridge)
        sound.stop(bridge)
        group.stop(bridge)
    finally:
        sound.close(bridge)
        group.close(bridge)
        engine.close(bridge)

    print("sound group attenuation controls ok")


def run_sound_group_attenuation_boundary_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var group = MiniAudioSoundGroupHandle(bridge)

    try:
        engine.init_default(bridge)
        group.init_default(bridge, engine)

        var bad_cone = bridge.sound_group_set_cone(group.raw, 1.5, 1.0, 0.5)
        if bad_cone != MA_INVALID_ARGS:
            raise Error(
                "sound group boundary smoke expected MA_INVALID_ARGS for invalid cone, got: "
                + String(bad_cone)
            )

        var bad_doppler = bridge.sound_group_set_doppler_factor(group.raw, -0.1)
        if bad_doppler != MA_INVALID_ARGS:
            raise Error(
                "sound group boundary smoke expected MA_INVALID_ARGS for negative doppler, got: "
                + String(bad_doppler)
            )

        var bad_directional = bridge.sound_group_set_directional_attenuation_factor(group.raw, -0.1)
        if bad_directional != MA_INVALID_ARGS:
            raise Error(
                "sound group boundary smoke expected MA_INVALID_ARGS for negative directional attenuation, got: "
                + String(bad_directional)
            )
    finally:
        group.close(bridge)
        engine.close(bridge)

    print("sound group attenuation boundary smoke ok")


def run_sound_group_invalid_state_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var group = MiniAudioSoundGroupHandle(bridge)

    try:
        var set_volume_result = bridge.sound_group_set_volume_f32(group.raw, 0.4)
        if set_volume_result != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for set_volume, got: "
                + String(set_volume_result)
            )

        var set_pan_result = bridge.sound_group_set_pan_f32(group.raw, 0.1)
        if set_pan_result != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for set_pan, got: "
                + String(set_pan_result)
            )

        var spatial_state = bridge.sound_group_is_spatialization_enabled(group.raw)
        if spatial_state != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for spatial state, got: "
                + String(spatial_state)
            )

        var set_position_result = bridge.sound_group_set_position(group.raw, 0.0, 0.0, 0.0)
        if set_position_result != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for set_position, got: "
                + String(set_position_result)
            )

        var set_attenuation_result = bridge.sound_group_set_attenuation_model(group.raw, 0)
        if set_attenuation_result != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for set_attenuation_model, got: "
                + String(set_attenuation_result)
            )

        var set_cone_result = bridge.sound_group_set_cone(group.raw, 0.2, 1.0, 0.5)
        if set_cone_result != MA_INVALID_ARGS:
            raise Error(
                "sound group invalid-state smoke expected MA_INVALID_ARGS for set_cone, got: "
                + String(set_cone_result)
            )
    finally:
        group.close(bridge)

    print("sound group invalid-state smoke ok")


def run_sound_group_fade_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var group = MiniAudioSoundGroupHandle(bridge)

    try:
        engine.init_default(bridge)
        group.init_default(bridge, engine)

        # fade from 0.0 to 1.0 over 4410 pcm frames (~0.1 s at 44100 Hz)
        group.set_fade_in_pcm_frames(bridge, 0.0, 1.0, 4410)
        var fade_vol = group.get_current_fade_volume(bridge)
        if fade_vol < 0.0 or fade_vol > 1.001:
            raise Error(
                "sound group fade smoke: current fade volume out of range: "
                + String(fade_vol)
            )

        # fade from current to 0 over 200 ms
        group.set_fade_in_milliseconds(bridge, -1.0, 0.0, 200)

        # schedule start / stop (absolute global time; 0 = engine-relative immediate)
        group.set_start_time_in_pcm_frames(bridge, 0)
        group.set_start_time_in_milliseconds(bridge, 0)
        group.set_stop_time_in_pcm_frames(bridge, 88200)
        group.set_stop_time_in_milliseconds(bridge, 5000)

        # get_time_in_pcm_frames returns the engine's global clock, >= 0
        var t = group.get_time_in_pcm_frames(bridge)
        if t < 0:
            raise Error(
                "sound group fade smoke: get_time_in_pcm_frames returned negative: "
                + String(t)
            )
    finally:
        group.close(bridge)
        engine.close(bridge)

    print("sound group fade smoke ok")


def run_sound_group_fade_invalid_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var group = MiniAudioSoundGroupHandle(bridge)

    # all operations on an uninitialised group must return MA_INVALID_ARGS / sentinel

    var fade_result = bridge.sound_group_set_fade_in_pcm_frames(group.raw, 0.0, 1.0, 100)
    if fade_result != MA_INVALID_ARGS:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected MA_INVALID_ARGS for set_fade_in_pcm_frames, got: "
            + String(fade_result)
        )

    var fade_ms_result = bridge.sound_group_set_fade_in_milliseconds(group.raw, 0.0, 1.0, 100)
    if fade_ms_result != MA_INVALID_ARGS:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected MA_INVALID_ARGS for set_fade_in_milliseconds, got: "
            + String(fade_ms_result)
        )

    var fade_vol = bridge.sound_group_get_current_fade_volume(group.raw)
    if fade_vol > -1.0001:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected sentinel (<=-1.0001) from get_current_fade_volume, got: "
            + String(fade_vol)
        )

    var start_result = bridge.sound_group_set_start_time_in_pcm_frames(group.raw, 0)
    if start_result != MA_INVALID_ARGS:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected MA_INVALID_ARGS for set_start_time_in_pcm_frames, got: "
            + String(start_result)
        )

    var stop_result = bridge.sound_group_set_stop_time_in_milliseconds(group.raw, 0)
    if stop_result != MA_INVALID_ARGS:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected MA_INVALID_ARGS for set_stop_time_in_milliseconds, got: "
            + String(stop_result)
        )

    var time_result = bridge.sound_group_get_time_in_pcm_frames(group.raw)
    if time_result >= 0:
        group.close(bridge)
        raise Error(
            "sound group fade-invalid smoke: expected negative sentinel from get_time_in_pcm_frames, got: "
            + String(time_result)
        )

    group.close(bridge)
    print("sound group fade invalid smoke ok")
