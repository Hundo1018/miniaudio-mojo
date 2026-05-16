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