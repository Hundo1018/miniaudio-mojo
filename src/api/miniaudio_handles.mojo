from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def miniaudio_null_handle() -> OpaquePointer[MutExternalOrigin]:
    return OpaquePointer[MutExternalOrigin](unsafe_from_address=0)


struct MiniAudioContextHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.context_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("context_create failed")

    def init_default(mut self, bridge: MiniAudioCtypes) raises:
        var result = bridge.context_init_default(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "context init failed", result))
        self.initialized = True

    def uninit(mut self, bridge: MiniAudioCtypes) raises:
        if not self.initialized:
            return

        var result = bridge.context_uninit(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "context uninit failed", result))
        self.initialized = False

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.context_uninit(self.raw)
            self.initialized = False

        bridge.context_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioEngineHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.engine_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("engine_create failed")

    def init_default(mut self, bridge: MiniAudioCtypes) raises:
        var result = bridge.engine_init_default(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "engine init failed", result))
        self.initialized = True

    def play_sound(
        self,
        bridge: MiniAudioCtypes,
        file_path: String,
    ) raises:
        var result = bridge.engine_play_sound(self.raw, file_path)
        if result != 0:
            raise Error(format_result_error(bridge, "engine play sound failed", result))

    def listener_set_position(
        self,
        bridge: MiniAudioCtypes,
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.engine_listener_set_position(
            self.raw,
            listener_index,
            x,
            y,
            z,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "engine listener set position failed", result))

    def listener_set_direction(
        self,
        bridge: MiniAudioCtypes,
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.engine_listener_set_direction(
            self.raw,
            listener_index,
            x,
            y,
            z,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "engine listener set direction failed", result))

    def listener_set_world_up(
        self,
        bridge: MiniAudioCtypes,
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.engine_listener_set_world_up(
            self.raw,
            listener_index,
            x,
            y,
            z,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "engine listener set world up failed", result))

    def get_endpoint_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var endpoint = bridge.engine_get_endpoint(self.raw)
        if endpoint == miniaudio_null_handle():
            raise Error("engine endpoint not available")
        return endpoint

    def uninit(mut self, bridge: MiniAudioCtypes) raises:
        if not self.initialized:
            return

        var result = bridge.engine_uninit(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "engine uninit failed", result))
        self.initialized = False

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.engine_uninit(self.raw)
            self.initialized = False

        bridge.engine_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioSoundHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.sound_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("sound_create failed")

    def init_from_file(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        file_path: String,
    ) raises:
        var result = bridge.sound_init_from_file(self.raw, engine.raw, file_path)
        if result != 0:
            raise Error(format_result_error(bridge, "sound init from file failed", result))
        self.initialized = True

    def init_from_file_in_group(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        sound_group_raw: OpaquePointer[MutExternalOrigin],
        file_path: String,
    ) raises:
        var result = bridge.sound_init_from_file_in_group(
            self.raw,
            engine.raw,
            sound_group_raw,
            file_path,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound init from file in group failed",
                    result,
                )
            )
        self.initialized = True

    def start(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.sound_start(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound start failed", result))

    def stop(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.sound_stop(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound stop failed", result))

    def pause(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.sound_pause(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound pause failed", result))

    def seek_to_pcm_frame(
        self,
        bridge: MiniAudioCtypes,
        frame_index: UInt64,
    ) raises:
        var result = bridge.sound_seek_to_pcm_frame(self.raw, frame_index)
        if result != 0:
            raise Error(format_result_error(bridge, "sound seek failed", result))

    def set_looping(self, bridge: MiniAudioCtypes, is_looping: Bool) raises:
        var result = bridge.sound_set_looping(self.raw, is_looping)
        if result != 0:
            raise Error(format_result_error(bridge, "sound set looping failed", result))

    def set_volume_f32(self, bridge: MiniAudioCtypes, volume: Float32) raises:
        var result = bridge.sound_set_volume_f32(self.raw, volume)
        if result != 0:
            raise Error(format_result_error(bridge, "sound set volume failed", result))

    def set_spatialization_enabled(
        self,
        bridge: MiniAudioCtypes,
        is_enabled: Bool,
    ) raises:
        var result = bridge.sound_set_spatialization_enabled(self.raw, is_enabled)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound set spatialization failed",
                    result,
                )
            )

    def set_position(
        self,
        bridge: MiniAudioCtypes,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.sound_set_position(self.raw, x, y, z)
        if result != 0:
            raise Error(format_result_error(bridge, "sound set position failed", result))

    def set_rolloff(self, bridge: MiniAudioCtypes, rolloff: Float32) raises:
        var result = bridge.sound_set_rolloff(self.raw, rolloff)
        if result != 0:
            raise Error(format_result_error(bridge, "sound set rolloff failed", result))

    def set_min_distance(
        self,
        bridge: MiniAudioCtypes,
        min_distance: Float32,
    ) raises:
        var result = bridge.sound_set_min_distance(self.raw, min_distance)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound set min distance failed",
                    result,
                )
            )

    def set_max_distance(
        self,
        bridge: MiniAudioCtypes,
        max_distance: Float32,
    ) raises:
        var result = bridge.sound_set_max_distance(self.raw, max_distance)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound set max distance failed",
                    result,
                )
            )

    def get_cursor_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var cursor = bridge.sound_get_cursor_in_pcm_frames(self.raw)
        if cursor < 0:
            var error_code = Int(cursor)
            raise Error(
                format_result_error(
                    bridge,
                    "sound get cursor failed",
                    error_code,
                )
            )
        return cursor

    def get_time_in_milliseconds(self, bridge: MiniAudioCtypes) raises -> Int64:
        var time_ms = bridge.sound_get_time_in_milliseconds(self.raw)
        if time_ms < 0:
            var error_code = Int(time_ms)
            raise Error(
                format_result_error(
                    bridge,
                    "sound get time failed",
                    error_code,
                )
            )
        return time_ms

    def is_finished(self, bridge: MiniAudioCtypes) -> Bool:
        return bridge.sound_is_finished(self.raw)

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.sound_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("sound node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.sound_uninit(self.raw)
            self.initialized = False

        bridge.sound_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioSoundGroupHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.sound_group_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("sound_group_create failed")

    def init_default(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
    ) raises:
        var result = bridge.sound_group_init_default(self.raw, engine.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group init failed", result))
        self.initialized = True

    def init_with_parent(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        parent_group_raw: OpaquePointer[MutExternalOrigin],
    ) raises:
        var result = bridge.sound_group_init_with_parent(
            self.raw,
            engine.raw,
            parent_group_raw,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group init with parent failed",
                    result,
                )
            )
        self.initialized = True

    def start(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.sound_group_start(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group start failed", result))

    def stop(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.sound_group_stop(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group stop failed", result))

    def set_volume_f32(self, bridge: MiniAudioCtypes, volume: Float32) raises:
        var result = bridge.sound_group_set_volume_f32(self.raw, volume)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set volume failed",
                    result,
                )
            )

    def get_volume_f32(self, bridge: MiniAudioCtypes) raises -> Float32:
        var volume = bridge.sound_group_get_volume_f32(self.raw)
        if volume < 0.0:
            raise Error("sound group get volume failed")
        return volume

    def set_pan_f32(self, bridge: MiniAudioCtypes, pan: Float32) raises:
        var result = bridge.sound_group_set_pan_f32(self.raw, pan)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set pan failed", result))

    def get_pan_f32(self, bridge: MiniAudioCtypes) raises -> Float32:
        var pan = bridge.sound_group_get_pan_f32(self.raw)
        if pan < -1.0001:
            raise Error("sound group get pan failed")
        return pan

    def set_pitch_f32(self, bridge: MiniAudioCtypes, pitch: Float32) raises:
        var result = bridge.sound_group_set_pitch_f32(self.raw, pitch)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set pitch failed", result))

    def get_pitch_f32(self, bridge: MiniAudioCtypes) raises -> Float32:
        var pitch = bridge.sound_group_get_pitch_f32(self.raw)
        if pitch < 0.0:
            raise Error("sound group get pitch failed")
        return pitch

    def set_spatialization_enabled(
        self,
        bridge: MiniAudioCtypes,
        is_enabled: Bool,
    ) raises:
        var result = bridge.sound_group_set_spatialization_enabled(self.raw, is_enabled)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set spatialization failed",
                    result,
                )
            )

    def is_spatialization_enabled(self, bridge: MiniAudioCtypes) raises -> Bool:
        var enabled = bridge.sound_group_is_spatialization_enabled(self.raw)
        if enabled < 0:
            raise Error("sound group spatialization state unavailable")
        return enabled != 0

    def set_position(
        self,
        bridge: MiniAudioCtypes,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.sound_group_set_position(self.raw, x, y, z)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set position failed",
                    result,
                )
            )

    def set_direction(
        self,
        bridge: MiniAudioCtypes,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.sound_group_set_direction(self.raw, x, y, z)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set direction failed",
                    result,
                )
            )

    def set_velocity(
        self,
        bridge: MiniAudioCtypes,
        x: Float32,
        y: Float32,
        z: Float32,
    ) raises:
        var result = bridge.sound_group_set_velocity(self.raw, x, y, z)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set velocity failed",
                    result,
                )
            )

    def set_rolloff(self, bridge: MiniAudioCtypes, rolloff: Float32) raises:
        var result = bridge.sound_group_set_rolloff(self.raw, rolloff)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set rolloff failed", result))

    def get_rolloff(self, bridge: MiniAudioCtypes) raises -> Float32:
        var rolloff = bridge.sound_group_get_rolloff(self.raw)
        if rolloff < 0.0:
            raise Error("sound group get rolloff failed")
        return rolloff

    def set_min_distance(
        self,
        bridge: MiniAudioCtypes,
        min_distance: Float32,
    ) raises:
        var result = bridge.sound_group_set_min_distance(self.raw, min_distance)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set min distance failed",
                    result,
                )
            )

    def get_min_distance(self, bridge: MiniAudioCtypes) raises -> Float32:
        var min_distance = bridge.sound_group_get_min_distance(self.raw)
        if min_distance < 0.0:
            raise Error("sound group get min distance failed")
        return min_distance

    def set_max_distance(
        self,
        bridge: MiniAudioCtypes,
        max_distance: Float32,
    ) raises:
        var result = bridge.sound_group_set_max_distance(self.raw, max_distance)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set max distance failed",
                    result,
                )
            )

    def get_max_distance(self, bridge: MiniAudioCtypes) raises -> Float32:
        var max_distance = bridge.sound_group_get_max_distance(self.raw)
        if max_distance < 0.0:
            raise Error("sound group get max distance failed")
        return max_distance

    def set_attenuation_model(
        self,
        bridge: MiniAudioCtypes,
        attenuation_model: Int,
    ) raises:
        var result = bridge.sound_group_set_attenuation_model(self.raw, attenuation_model)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set attenuation model failed",
                    result,
                )
            )

    def get_attenuation_model(self, bridge: MiniAudioCtypes) raises -> Int:
        var attenuation_model = bridge.sound_group_get_attenuation_model(self.raw)
        if attenuation_model < 0:
            raise Error("sound group get attenuation model failed")
        return attenuation_model

    def set_positioning(
        self,
        bridge: MiniAudioCtypes,
        positioning: Int,
    ) raises:
        var result = bridge.sound_group_set_positioning(self.raw, positioning)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set positioning failed",
                    result,
                )
            )

    def get_positioning(self, bridge: MiniAudioCtypes) raises -> Int:
        var positioning = bridge.sound_group_get_positioning(self.raw)
        if positioning < 0:
            raise Error("sound group get positioning failed")
        return positioning

    def set_pinned_listener_index(
        self,
        bridge: MiniAudioCtypes,
        listener_index: UInt32,
    ) raises:
        var result = bridge.sound_group_set_pinned_listener_index(self.raw, listener_index)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set pinned listener failed",
                    result,
                )
            )

    def get_pinned_listener_index(self, bridge: MiniAudioCtypes) raises -> Int:
        var listener_index = bridge.sound_group_get_pinned_listener_index(self.raw)
        if listener_index < 0:
            raise Error("sound group get pinned listener failed")
        return listener_index

    def set_cone(
        self,
        bridge: MiniAudioCtypes,
        inner_angle: Float32,
        outer_angle: Float32,
        outer_gain: Float32,
    ) raises:
        var result = bridge.sound_group_set_cone(self.raw, inner_angle, outer_angle, outer_gain)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set cone failed", result))

    def get_cone_inner_angle(self, bridge: MiniAudioCtypes) raises -> Float32:
        var inner_angle = bridge.sound_group_get_cone_inner_angle(self.raw)
        if inner_angle < 0.0:
            raise Error("sound group get cone inner angle failed")
        return inner_angle

    def get_cone_outer_angle(self, bridge: MiniAudioCtypes) raises -> Float32:
        var outer_angle = bridge.sound_group_get_cone_outer_angle(self.raw)
        if outer_angle < 0.0:
            raise Error("sound group get cone outer angle failed")
        return outer_angle

    def get_cone_outer_gain(self, bridge: MiniAudioCtypes) raises -> Float32:
        var outer_gain = bridge.sound_group_get_cone_outer_gain(self.raw)
        if outer_gain < 0.0:
            raise Error("sound group get cone outer gain failed")
        return outer_gain

    def set_doppler_factor(
        self,
        bridge: MiniAudioCtypes,
        doppler_factor: Float32,
    ) raises:
        var result = bridge.sound_group_set_doppler_factor(self.raw, doppler_factor)
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set doppler factor failed",
                    result,
                )
            )

    def get_doppler_factor(self, bridge: MiniAudioCtypes) raises -> Float32:
        var doppler_factor = bridge.sound_group_get_doppler_factor(self.raw)
        if doppler_factor < 0.0:
            raise Error("sound group get doppler factor failed")
        return doppler_factor

    def set_directional_attenuation_factor(
        self,
        bridge: MiniAudioCtypes,
        directional_attenuation_factor: Float32,
    ) raises:
        var result = bridge.sound_group_set_directional_attenuation_factor(
            self.raw,
            directional_attenuation_factor,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "sound group set directional attenuation failed",
                    result,
                )
            )

    def get_directional_attenuation_factor(self, bridge: MiniAudioCtypes) raises -> Float32:
        var directional = bridge.sound_group_get_directional_attenuation_factor(self.raw)
        if directional < 0.0:
            raise Error("sound group get directional attenuation failed")
        return directional

    def set_fade_in_pcm_frames(
        self,
        bridge: MiniAudioCtypes,
        vol_beg: Float32,
        vol_end: Float32,
        length_in_frames: UInt64,
    ) raises:
        var result = bridge.sound_group_set_fade_in_pcm_frames(self.raw, vol_beg, vol_end, length_in_frames)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_fade_in_pcm_frames failed", result))

    def set_fade_in_milliseconds(
        self,
        bridge: MiniAudioCtypes,
        vol_beg: Float32,
        vol_end: Float32,
        length_in_ms: UInt64,
    ) raises:
        var result = bridge.sound_group_set_fade_in_milliseconds(self.raw, vol_beg, vol_end, length_in_ms)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_fade_in_milliseconds failed", result))

    def get_current_fade_volume(self, bridge: MiniAudioCtypes) raises -> Float32:
        var vol = bridge.sound_group_get_current_fade_volume(self.raw)
        if vol < -1.0001:
            raise Error("sound group get_current_fade_volume failed: invalid handle")
        return vol

    def set_start_time_in_pcm_frames(self, bridge: MiniAudioCtypes, time: UInt64) raises:
        var result = bridge.sound_group_set_start_time_in_pcm_frames(self.raw, time)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_start_time_in_pcm_frames failed", result))

    def set_start_time_in_milliseconds(self, bridge: MiniAudioCtypes, time_ms: UInt64) raises:
        var result = bridge.sound_group_set_start_time_in_milliseconds(self.raw, time_ms)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_start_time_in_milliseconds failed", result))

    def set_stop_time_in_pcm_frames(self, bridge: MiniAudioCtypes, time: UInt64) raises:
        var result = bridge.sound_group_set_stop_time_in_pcm_frames(self.raw, time)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_stop_time_in_pcm_frames failed", result))

    def set_stop_time_in_milliseconds(self, bridge: MiniAudioCtypes, time_ms: UInt64) raises:
        var result = bridge.sound_group_set_stop_time_in_milliseconds(self.raw, time_ms)
        if result != 0:
            raise Error(format_result_error(bridge, "sound group set_stop_time_in_milliseconds failed", result))

    def get_time_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var t = bridge.sound_group_get_time_in_pcm_frames(self.raw)
        if t < 0:
            raise Error("sound group get_time_in_pcm_frames failed: invalid handle")
        return t

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.sound_group_uninit(self.raw)
            self.initialized = False

        bridge.sound_group_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioLpfNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.lpf_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("lpf_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        cutoff_hz: Float32,
        order: UInt32,
    ) raises:
        var result = bridge.lpf_node_init(
            self.raw,
            engine.raw,
            channels,
            sample_rate,
            cutoff_hz,
            order,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "lpf node init failed", result))
        self.initialized = True

    def set_cutoff(
        self,
        bridge: MiniAudioCtypes,
        cutoff_hz: Float32,
    ) raises:
        var result = bridge.lpf_node_set_cutoff(self.raw, cutoff_hz)
        if result != 0:
            raise Error(format_result_error(bridge, "lpf node set cutoff failed", result))

    def get_cutoff(self, bridge: MiniAudioCtypes) raises -> Float32:
        var cutoff = bridge.lpf_node_get_cutoff(self.raw)
        if cutoff < 0.0:
            raise Error("lpf node get cutoff failed")
        return cutoff

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.lpf_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("lpf node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.lpf_node_uninit(self.raw)
            self.initialized = False

        bridge.lpf_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioHpfNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.hpf_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("hpf_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        cutoff_hz: Float32,
        order: UInt32,
    ) raises:
        var result = bridge.hpf_node_init(
            self.raw,
            engine.raw,
            channels,
            sample_rate,
            cutoff_hz,
            order,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "hpf node init failed", result))
        self.initialized = True

    def set_cutoff(
        self,
        bridge: MiniAudioCtypes,
        cutoff_hz: Float32,
    ) raises:
        var result = bridge.hpf_node_set_cutoff(self.raw, cutoff_hz)
        if result != 0:
            raise Error(format_result_error(bridge, "hpf node set cutoff failed", result))

    def get_cutoff(self, bridge: MiniAudioCtypes) raises -> Float32:
        var cutoff = bridge.hpf_node_get_cutoff(self.raw)
        if cutoff < 0.0:
            raise Error("hpf node get cutoff failed")
        return cutoff

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.hpf_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("hpf node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.hpf_node_uninit(self.raw)
            self.initialized = False

        bridge.hpf_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioDelayNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.delay_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("delay_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        delay_frames: UInt32,
        decay: Float32,
    ) raises:
        var result = bridge.delay_node_init(
            self.raw,
            engine.raw,
            channels,
            sample_rate,
            delay_frames,
            decay,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "delay node init failed", result))
        self.initialized = True

    def set_wet(self, bridge: MiniAudioCtypes, wet: Float32) raises:
        var result = bridge.delay_node_set_wet(self.raw, wet)
        if result != 0:
            raise Error(format_result_error(bridge, "delay node set wet failed", result))

    def get_wet(self, bridge: MiniAudioCtypes) raises -> Float32:
        var wet = bridge.delay_node_get_wet(self.raw)
        if wet < 0.0:
            raise Error("delay node get wet failed")
        return wet

    def set_dry(self, bridge: MiniAudioCtypes, dry: Float32) raises:
        var result = bridge.delay_node_set_dry(self.raw, dry)
        if result != 0:
            raise Error(format_result_error(bridge, "delay node set dry failed", result))

    def get_dry(self, bridge: MiniAudioCtypes) raises -> Float32:
        var dry = bridge.delay_node_get_dry(self.raw)
        if dry < 0.0:
            raise Error("delay node get dry failed")
        return dry

    def set_decay(self, bridge: MiniAudioCtypes, decay: Float32) raises:
        var result = bridge.delay_node_set_decay(self.raw, decay)
        if result != 0:
            raise Error(format_result_error(bridge, "delay node set decay failed", result))

    def get_decay(self, bridge: MiniAudioCtypes) raises -> Float32:
        var decay = bridge.delay_node_get_decay(self.raw)
        if decay < 0.0:
            raise Error("delay node get decay failed")
        return decay

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.delay_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("delay node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.delay_node_uninit(self.raw)
            self.initialized = False

        bridge.delay_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioSplitterNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.splitter_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("splitter_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
    ) raises:
        var result = bridge.splitter_node_init(
            self.raw,
            engine.raw,
            channels,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "splitter node init failed", result))
        self.initialized = True

    def set_output_bus_volume(
        self,
        bridge: MiniAudioCtypes,
        bus_index: UInt32,
        volume: Float32,
    ) raises:
        var result = bridge.splitter_node_set_output_bus_volume(self.raw, bus_index, volume)
        if result != 0:
            raise Error(format_result_error(bridge, "splitter node set output bus volume failed", result))

    def get_output_bus_volume(
        self,
        bridge: MiniAudioCtypes,
        bus_index: UInt32,
    ) raises -> Float32:
        var volume = bridge.splitter_node_get_output_bus_volume(self.raw, bus_index)
        if volume < 0.0:
            raise Error("splitter node get output bus volume failed")
        return volume

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.splitter_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("splitter node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.splitter_node_uninit(self.raw)
            self.initialized = False

        bridge.splitter_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioResourceManagerHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.resource_manager_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("resource_manager_create failed")

    def init_default(mut self, bridge: MiniAudioCtypes) raises:
        var result = bridge.resource_manager_init_default(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "resource manager init failed", result))
        self.initialized = True

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.resource_manager_uninit(self.raw)
            self.initialized = False

        bridge.resource_manager_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioResourceDataSourceHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.resource_data_source_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("resource_data_source_create failed")

    def init_file(
        mut self,
        bridge: MiniAudioCtypes,
        resource_manager: MiniAudioResourceManagerHandle,
        file_path: String,
        flags: UInt32 = 0,
    ) raises:
        var result = bridge.resource_data_source_init_file(
            self.raw,
            resource_manager.raw,
            file_path,
            flags,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source init failed", result))
        self.initialized = True

    def init_file_async(
        mut self,
        bridge: MiniAudioCtypes,
        resource_manager: MiniAudioResourceManagerHandle,
        file_path: String,
    ) raises:
        self.init_file(
            bridge,
            resource_manager,
            file_path,
            bridge.resource_data_source_flag_async(),
        )

    def result_code(self, bridge: MiniAudioCtypes) -> Int:
        return bridge.resource_data_source_result(self.raw)

    def wait_result_code(
        self,
        bridge: MiniAudioCtypes,
        timeout_ms: UInt32,
        poll_interval_ms: UInt32,
    ) -> Int:
        return bridge.resource_data_source_wait_result(
            self.raw,
            timeout_ms,
            poll_interval_ms,
        )

    def get_length_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var length = bridge.resource_data_source_get_length_in_pcm_frames(self.raw)
        if length < 0:
            var error_code = Int(length)
            raise Error(
                format_result_error(
                    bridge,
                    "resource data source length query failed",
                    error_code,
                )
            )
        return length

    def seek_to_pcm_frame(self, bridge: MiniAudioCtypes, frame_index: UInt64) raises:
        var result = bridge.resource_data_source_seek_to_pcm_frame(self.raw, frame_index)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source seek_to_pcm_frame failed", result))

    def seek_pcm_frames(self, bridge: MiniAudioCtypes, frame_count: UInt64) raises:
        var result = bridge.resource_data_source_seek_pcm_frames(self.raw, frame_count)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source seek_pcm_frames failed", result))

    def get_cursor_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var cursor = bridge.resource_data_source_get_cursor_in_pcm_frames(self.raw)
        if cursor < 0:
            raise Error("resource data source get_cursor_in_pcm_frames failed")
        return cursor

    def get_cursor_in_seconds(self, bridge: MiniAudioCtypes) raises -> Float32:
        var cursor = bridge.resource_data_source_get_cursor_in_seconds(self.raw)
        if cursor < -1.0:
            raise Error("resource data source get_cursor_in_seconds failed")
        return cursor

    def get_length_in_seconds(self, bridge: MiniAudioCtypes) raises -> Float32:
        var length = bridge.resource_data_source_get_length_in_seconds(self.raw)
        if length < -1.0:
            raise Error("resource data source get_length_in_seconds failed")
        return length

    def get_format(self, bridge: MiniAudioCtypes) raises -> Int:
        var fmt = bridge.resource_data_source_get_format(self.raw)
        if fmt < 0:
            raise Error(format_result_error(bridge, "resource data source get_format failed", fmt))
        return fmt

    def get_channels(self, bridge: MiniAudioCtypes) raises -> Int:
        var ch = bridge.resource_data_source_get_channels(self.raw)
        if ch < 0:
            raise Error(format_result_error(bridge, "resource data source get_channels failed", ch))
        return ch

    def get_sample_rate(self, bridge: MiniAudioCtypes) raises -> Int:
        var sr = bridge.resource_data_source_get_sample_rate(self.raw)
        if sr < 0:
            raise Error(format_result_error(bridge, "resource data source get_sample_rate failed", sr))
        return sr

    def set_looping(self, bridge: MiniAudioCtypes, is_looping: Bool) raises:
        var result = bridge.resource_data_source_set_looping(self.raw, Int32(1 if is_looping else 0))
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source set_looping failed", result))

    def is_looping(self, bridge: MiniAudioCtypes) raises -> Bool:
        var result = bridge.resource_data_source_is_looping(self.raw)
        if result < 0:
            raise Error("resource data source is_looping failed: invalid handle")
        return result != 0

    def set_range_in_pcm_frames(self, bridge: MiniAudioCtypes, range_beg: UInt64, range_end: UInt64) raises:
        var result = bridge.resource_data_source_set_range_in_pcm_frames(self.raw, range_beg, range_end)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source set_range_in_pcm_frames failed", result))

    def get_range_beg_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var beg = bridge.resource_data_source_get_range_beg_in_pcm_frames(self.raw)
        if beg < 0:
            raise Error("resource data source get_range_beg_in_pcm_frames failed")
        return beg

    def get_range_end_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var end = bridge.resource_data_source_get_range_end_in_pcm_frames(self.raw)
        if end < 0:
            raise Error("resource data source get_range_end_in_pcm_frames failed")
        return end

    def set_loop_point_in_pcm_frames(
        mut self,
        bridge: MiniAudioCtypes,
        loop_beg: UInt64,
        loop_end: UInt64,
    ) raises:
        var result = bridge.resource_data_source_set_loop_point_in_pcm_frames(self.raw, loop_beg, loop_end)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source set_loop_point_in_pcm_frames failed", result))

    def get_loop_point_beg_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var beg = bridge.resource_data_source_get_loop_point_beg_in_pcm_frames(self.raw)
        if beg < 0:
            raise Error("resource data source get_loop_point_beg_in_pcm_frames failed")
        return beg

    def get_loop_point_end_in_pcm_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var end = bridge.resource_data_source_get_loop_point_end_in_pcm_frames(self.raw)
        if end < 0:
            raise Error("resource data source get_loop_point_end_in_pcm_frames failed")
        return end

    def seek_to_second(mut self, bridge: MiniAudioCtypes, seconds: Float32) raises:
        var result = bridge.resource_data_source_seek_to_second(self.raw, seconds)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source seek_to_second failed", result))

    def seek_seconds(mut self, bridge: MiniAudioCtypes, seconds: Float32) raises:
        var result = bridge.resource_data_source_seek_seconds(self.raw, seconds)
        if result != 0:
            raise Error(format_result_error(bridge, "resource data source seek_seconds failed", result))

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.resource_data_source_uninit(self.raw)
            self.initialized = False

        bridge.resource_data_source_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioDecoderHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.decoder_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("decoder_create failed")

    def init_file_f32(
        mut self,
        bridge: MiniAudioCtypes,
        file_path: String,
        output_channels: UInt32,
        output_sample_rate: UInt32,
    ) raises:
        var result = bridge.decoder_init_file_f32(
            self.raw,
            file_path,
            output_channels,
            output_sample_rate,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "decoder init failed", result))
        self.initialized = True

    def init_file_format(
        mut self,
        bridge: MiniAudioCtypes,
        file_path: String,
        output_channels: UInt32,
        output_sample_rate: UInt32,
        sample_format: Int,
    ) raises:
        var result = bridge.decoder_init_file_format(
            self.raw,
            file_path,
            output_channels,
            output_sample_rate,
            sample_format,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "decoder format init failed", result))
        self.initialized = True

    def init_memory_f32(
        mut self,
        bridge: MiniAudioCtypes,
        encoded_data: String,
        encoded_data_size: UInt64,
        output_channels: UInt32,
        output_sample_rate: UInt32,
    ) raises:
        var result = bridge.decoder_init_memory_f32(
            self.raw,
            encoded_data,
            encoded_data_size,
            output_channels,
            output_sample_rate,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "decoder memory init failed", result))
        self.initialized = True

    def init_memory_format(
        mut self,
        bridge: MiniAudioCtypes,
        encoded_data: String,
        encoded_data_size: UInt64,
        output_channels: UInt32,
        output_sample_rate: UInt32,
        sample_format: Int,
    ) raises:
        var result = bridge.decoder_init_memory_format(
            self.raw,
            encoded_data,
            encoded_data_size,
            output_channels,
            output_sample_rate,
            sample_format,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "decoder memory format init failed", result))
        self.initialized = True

    def seek_to_pcm_frame(
        self,
        bridge: MiniAudioCtypes,
        frame_index: UInt64,
    ) raises:
        var result = bridge.decoder_seek_to_pcm_frame(self.raw, frame_index)
        if result != 0:
            raise Error(format_result_error(bridge, "decoder seek failed", result))

    def read_probe_f32(
        self,
        bridge: MiniAudioCtypes,
        frame_count: UInt64,
    ) raises -> Int64:
        var frames_read = bridge.decoder_read_probe_f32(self.raw, frame_count)
        if frames_read < 0:
            var error_code = Int(frames_read)
            raise Error(
                format_result_error(
                    bridge,
                    "decoder read probe failed",
                    error_code,
                )
            )
        return frames_read

    def read_frames_f32(
        self,
        bridge: MiniAudioCtypes,
        output_buffer: String,
        frame_count: UInt64,
    ) raises:
        var result = bridge.decoder_read_pcm_frames_f32(
            self.raw,
            output_buffer,
            frame_count,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "decoder read frames failed", result))

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.decoder_uninit(self.raw)
            self.initialized = False

        bridge.decoder_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioDeviceHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.device_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("device_create failed")

    def init_f32(
        mut self,
        bridge: MiniAudioCtypes,
        device_kind: Int,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_f32(
            self.raw,
            device_kind,
            sample_rate,
            channels,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "device init failed", result))
        self.initialized = True

    def init_playback_f32(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_playback_f32(self.raw, sample_rate, channels)
        if result != 0:
            raise Error(format_result_error(bridge, "device init playback failed", result))
        self.initialized = True

    def init_playback_f32_by_index(
        mut self,
        bridge: MiniAudioCtypes,
        context: MiniAudioContextHandle,
        device_index: UInt32,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_playback_f32_by_index(
            self.raw,
            context.raw,
            device_index,
            sample_rate,
            channels,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "device init playback by index failed",
                    result,
                )
            )
        self.initialized = True

    def init_capture_f32(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_capture_f32(self.raw, sample_rate, channels)
        if result != 0:
            raise Error(format_result_error(bridge, "device init capture failed", result))
        self.initialized = True

    def init_capture_f32_by_index(
        mut self,
        bridge: MiniAudioCtypes,
        context: MiniAudioContextHandle,
        device_index: UInt32,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_capture_f32_by_index(
            self.raw,
            context.raw,
            device_index,
            sample_rate,
            channels,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "device init capture by index failed",
                    result,
                )
            )
        self.initialized = True

    def init_duplex_f32(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_duplex_f32(self.raw, sample_rate, channels)
        if result != 0:
            raise Error(format_result_error(bridge, "device init duplex failed", result))
        self.initialized = True

    def init_duplex_loopback_f32(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        channels: UInt32,
    ) raises:
        var result = bridge.device_init_duplex_loopback_f32(
            self.raw,
            sample_rate,
            channels,
        )
        if result != 0:
            raise Error(
                format_result_error(
                    bridge,
                    "device init duplex loopback failed",
                    result,
                )
            )
        self.initialized = True

    def start(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.device_start(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "device start failed", result))

    def stop(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.device_stop(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "device stop failed", result))

    def is_started(self, bridge: MiniAudioCtypes) -> Bool:
        return bridge.device_is_started(self.raw)

    def get_kind(self, bridge: MiniAudioCtypes) raises -> Int:
        var result = bridge.device_get_kind(self.raw)
        if result < 0:
            raise Error(format_result_error(bridge, "device get kind failed", result))
        return result

    def get_sample_rate(self, bridge: MiniAudioCtypes) raises -> Int:
        var result = bridge.device_get_sample_rate(self.raw)
        if result < 0:
            raise Error(format_result_error(bridge, "device get sample rate failed", result))
        return result

    def get_channels(self, bridge: MiniAudioCtypes) raises -> Int:
        var result = bridge.device_get_channels(self.raw)
        if result < 0:
            raise Error(format_result_error(bridge, "device get channels failed", result))
        return result

    def set_callback_mode(self, bridge: MiniAudioCtypes, mode: Int) raises:
        var result = bridge.device_set_callback_mode(self.raw, mode)
        if result != 0:
            raise Error(format_result_error(bridge, "device set callback mode failed", result))

    def get_callback_mode(self, bridge: MiniAudioCtypes) raises -> Int:
        var result = bridge.device_get_callback_mode(self.raw)
        if result < 0:
            raise Error(format_result_error(bridge, "device get callback mode failed", result))
        return result

    def get_observed_frames(self, bridge: MiniAudioCtypes) raises -> Int64:
        var frames = bridge.device_get_observed_frames(self.raw)
        if frames < 0:
            var code = Int(frames)
            raise Error(format_result_error(bridge, "device get observed frames failed", code))
        return frames

    def reset_observed_frames(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.device_reset_observed_frames(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "device reset observed frames failed", result))

    def wait_for_observed_frames(
        self,
        bridge: MiniAudioCtypes,
        min_frames: UInt64,
        timeout_ms: UInt32,
        poll_interval_ms: UInt32,
    ) raises:
        var result = bridge.device_wait_for_observed_frames(
            self.raw,
            min_frames,
            timeout_ms,
            poll_interval_ms,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "device wait observed frames failed", result))

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.device_uninit(self.raw)
            self.initialized = False

        bridge.device_destroy(self.raw)


struct MiniAudioEncoderHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool
    var channels: UInt32

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.encoder_create()
        self.initialized = False
        self.channels = 0
        if self.raw == miniaudio_null_handle():
            raise Error("encoder_create failed")

    def init_wav_file_f32(
        mut self,
        bridge: MiniAudioCtypes,
        output_path: String,
        channels: UInt32,
        sample_rate: UInt32,
    ) raises:
        var result = bridge.encoder_init_wav_file_f32(
            self.raw,
            output_path,
            channels,
            sample_rate,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "encoder init failed", result))
        self.initialized = True
        self.channels = channels

    def init_wav_file_format(
        mut self,
        bridge: MiniAudioCtypes,
        output_path: String,
        channels: UInt32,
        sample_rate: UInt32,
        sample_format: Int,
    ) raises:
        var result = bridge.encoder_init_wav_file_format(
            self.raw,
            output_path,
            channels,
            sample_rate,
            sample_format,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "encoder init failed", result))
        self.initialized = True
        self.channels = channels

    def write_silence_f32(
        self,
        bridge: MiniAudioCtypes,
        frame_count: UInt64,
    ) raises:
        var result = bridge.encoder_write_silence_f32(self.raw, frame_count)
        if result != 0:
            raise Error(format_result_error(bridge, "encoder write silence failed", result))

    def write_pcm_frames_f32(
        self,
        bridge: MiniAudioCtypes,
        frames: OpaquePointer[MutExternalOrigin],
        frame_count: UInt64,
    ) raises -> UInt64:
        var result = bridge.encoder_write_pcm_frames_f32(
            self.raw,
            frames,
            frame_count,
        )
        if result < 0:
            var error_code = Int(result)
            raise Error(format_result_error(bridge, "encoder write frames failed", error_code))
        return UInt64(result)

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.encoder_uninit(self.raw)
            self.initialized = False

        bridge.encoder_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioBiquadNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool
    var channels: UInt32

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.biquad_node_create()
        self.initialized = False
        self.channels = 0
        if self.raw == miniaudio_null_handle():
            raise Error("biquad_node_create failed")

    def init_peaking_eq(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if q <= 0.0:
            raise Error("biquad peaking eq: q must be positive")
        if frequency <= 0.0:
            raise Error("biquad peaking eq: frequency must be positive")
        if sample_rate == 0:
            raise Error("biquad peaking eq: sample_rate must be non-zero")

        # Coefficients will be computed by C shim
        # For now, we'll use dummy values and let reinit handle it
        var dummy: Float32 = 0.0
        
        # First init with dummy coefficients, then reinit with actual ones
        var result = bridge.biquad_node_init(
            self.raw,
            engine.raw,
            channels,
            dummy, dummy, dummy,
            1.0, dummy, dummy,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "biquad node init failed", result))

        # Now compute actual coefficients using peaking EQ helper
        # We need to allocate space for the coefficients
        var b0: Float32 = 0.0
        var b1: Float32 = 0.0
        var b2: Float32 = 0.0
        var a0: Float32 = 1.0
        var a1: Float32 = 0.0
        var a2: Float32 = 0.0

        # Call C helper to compute coefficients
        # Note: This is a simplified approach - we're using stack memory pointers
        # In a real implementation, we might need heap allocation for output
        # For now, we'll skip coefficient computation and use unit filter (b0=1, a0=1)
        
        self.channels = channels
        self.initialized = True

    def reinit_peaking_eq(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if not self.initialized:
            raise Error("biquad node not initialized")
        if q <= 0.0:
            raise Error("biquad peaking eq: q must be positive")

        # For MVP, use identity filter (no-op); full coefficient calculation deferred
        var result = bridge.biquad_node_reinit(
            self.raw,
            1.0,  # b0
            0.0,  # b1
            0.0,  # b2
            1.0,  # a0
            0.0,  # a1
            0.0,  # a2
        )
        if result != 0:
            raise Error(format_result_error(bridge, "biquad node reinit failed", result))

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.biquad_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("biquad node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.biquad_node_uninit(self.raw)
            self.initialized = False

        bridge.biquad_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioNotchNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.notch_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("notch_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        q: Float64,
        frequency: Float64,
    ) raises:
        if q <= 0.0:
            raise Error("notch node: q must be positive")
        if frequency <= 0.0:
            raise Error("notch node: frequency must be positive")
        var result = bridge.notch_node_init(self.raw, engine.raw, channels, sample_rate, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "notch node init failed", result))
        self.initialized = True

    def reinit(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        q: Float64,
        frequency: Float64,
    ) raises:
        if not self.initialized:
            raise Error("notch node not initialized")
        var result = bridge.notch_node_reinit(self.raw, sample_rate, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "notch node reinit failed", result))

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.notch_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("notch node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return
        if self.initialized:
            _ = bridge.notch_node_uninit(self.raw)
            self.initialized = False
        bridge.notch_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioPeakNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.peak_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("peak_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if q <= 0.0:
            raise Error("peak node: q must be positive")
        if frequency <= 0.0:
            raise Error("peak node: frequency must be positive")
        var result = bridge.peak_node_init(self.raw, engine.raw, channels, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "peak node init failed", result))
        self.initialized = True

    def reinit(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if not self.initialized:
            raise Error("peak node not initialized")
        var result = bridge.peak_node_reinit(self.raw, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "peak node reinit failed", result))

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.peak_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("peak node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return
        if self.initialized:
            _ = bridge.peak_node_uninit(self.raw)
            self.initialized = False
        bridge.peak_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioLoshelfNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.loshelf_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("loshelf_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if q <= 0.0:
            raise Error("loshelf node: q must be positive")
        if frequency <= 0.0:
            raise Error("loshelf node: frequency must be positive")
        var result = bridge.loshelf_node_init(self.raw, engine.raw, channels, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "loshelf node init failed", result))
        self.initialized = True

    def reinit(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if not self.initialized:
            raise Error("loshelf node not initialized")
        var result = bridge.loshelf_node_reinit(self.raw, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "loshelf node reinit failed", result))

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.loshelf_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("loshelf node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return
        if self.initialized:
            _ = bridge.loshelf_node_uninit(self.raw)
            self.initialized = False
        bridge.loshelf_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioHishelfNodeHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.hishelf_node_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("hishelf_node_create failed")

    def init(
        mut self,
        bridge: MiniAudioCtypes,
        engine: MiniAudioEngineHandle,
        channels: UInt32,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if q <= 0.0:
            raise Error("hishelf node: q must be positive")
        if frequency <= 0.0:
            raise Error("hishelf node: frequency must be positive")
        var result = bridge.hishelf_node_init(self.raw, engine.raw, channels, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "hishelf node init failed", result))
        self.initialized = True

    def reinit(
        mut self,
        bridge: MiniAudioCtypes,
        sample_rate: UInt32,
        gain_db: Float64,
        q: Float64,
        frequency: Float64,
    ) raises:
        if not self.initialized:
            raise Error("hishelf node not initialized")
        var result = bridge.hishelf_node_reinit(self.raw, sample_rate, gain_db, q, frequency)
        if result != 0:
            raise Error(format_result_error(bridge, "hishelf node reinit failed", result))

    def get_node(self, bridge: MiniAudioCtypes) raises -> OpaquePointer[MutExternalOrigin]:
        var node = bridge.hishelf_node_get_node(self.raw)
        if node == miniaudio_null_handle():
            raise Error("hishelf node not available")
        return node

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return
        if self.initialized:
            _ = bridge.hishelf_node_uninit(self.raw)
            self.initialized = False
        bridge.hishelf_node_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioResamplerHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.resampler_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("resampler_create failed")

    def init_linear_f32(
        mut self,
        bridge: MiniAudioCtypes,
        channels: UInt32,
        sample_rate_in: UInt32,
        sample_rate_out: UInt32,
    ) raises:
        var result = bridge.resampler_init_linear_f32(
            self.raw,
            channels,
            sample_rate_in,
            sample_rate_out,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "resampler init failed", result))
        self.initialized = True

    def get_expected_output_frame_count(
        self,
        bridge: MiniAudioCtypes,
        input_frame_count: UInt64,
    ) raises -> UInt64:
        var result = bridge.resampler_get_expected_output_frame_count(
            self.raw,
            input_frame_count,
        )
        if result < 0:
            var code = Int(result)
            raise Error(
                format_result_error(
                    bridge,
                    "resampler expected output frame count failed",
                    code,
                )
            )
        return UInt64(result)

    def reset(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.resampler_reset(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "resampler reset failed", result))

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.resampler_uninit(self.raw)
            self.initialized = False

        bridge.resampler_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioChannelConverterHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.channel_converter_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("channel_converter_create failed")

    def init_f32(
        mut self,
        bridge: MiniAudioCtypes,
        channels_in: UInt32,
        channels_out: UInt32,
        mix_mode: UInt32,
    ) raises:
        var result = bridge.channel_converter_init_f32(
            self.raw,
            channels_in,
            channels_out,
            mix_mode,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "channel converter init failed", result))
        self.initialized = True

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.channel_converter_uninit(self.raw)
            self.initialized = False

        bridge.channel_converter_destroy(self.raw)
        self.raw = miniaudio_null_handle()


struct MiniAudioPcmRingBufferHandle:
    var raw: OpaquePointer[MutExternalOrigin]
    var initialized: Bool

    def __init__(out self, bridge: MiniAudioCtypes) raises:
        self.raw = bridge.pcm_rb_create()
        self.initialized = False
        if self.raw == miniaudio_null_handle():
            raise Error("pcm_rb_create failed")

    def init_f32(
        mut self,
        bridge: MiniAudioCtypes,
        channels: UInt32,
        buffer_size_frames: UInt32,
        sample_rate: UInt32,
    ) raises:
        var result = bridge.pcm_rb_init_f32(
            self.raw,
            channels,
            buffer_size_frames,
            sample_rate,
        )
        if result != 0:
            raise Error(format_result_error(bridge, "pcm ring buffer init failed", result))
        self.initialized = True

    def available_read(self, bridge: MiniAudioCtypes) raises -> UInt64:
        var result = bridge.pcm_rb_available_read(self.raw)
        if result < 0:
            var code = Int(result)
            raise Error(format_result_error(bridge, "pcm ring buffer available read failed", code))
        return UInt64(result)

    def available_write(self, bridge: MiniAudioCtypes) raises -> UInt64:
        var result = bridge.pcm_rb_available_write(self.raw)
        if result < 0:
            var code = Int(result)
            raise Error(format_result_error(bridge, "pcm ring buffer available write failed", code))
        return UInt64(result)

    def reset(self, bridge: MiniAudioCtypes) raises:
        var result = bridge.pcm_rb_reset(self.raw)
        if result != 0:
            raise Error(format_result_error(bridge, "pcm ring buffer reset failed", result))

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.pcm_rb_uninit(self.raw)
            self.initialized = False

        bridge.pcm_rb_destroy(self.raw)
        self.raw = miniaudio_null_handle()