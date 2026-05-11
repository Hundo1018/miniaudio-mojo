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

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.sound_uninit(self.raw)
            self.initialized = False

        bridge.sound_destroy(self.raw)
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

    def close(mut self, bridge: MiniAudioCtypes):
        if self.raw == miniaudio_null_handle():
            return

        if self.initialized:
            _ = bridge.device_uninit(self.raw)
            self.initialized = False

        bridge.device_destroy(self.raw)
        self.raw = miniaudio_null_handle()