from std.ffi import OwnedDLHandle


struct MiniAudioCtypes:
    var _lib: OwnedDLHandle

    def __init__(out self, lib_path: String) raises:
        self._lib = OwnedDLHandle(lib_path)

    def version(self) raises -> String:
        var raw = self._lib.call["mmj_miniaudio_version", OpaquePointer[MutExternalOrigin]]()
        var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
        if raw == null_ptr:
            raise Error("mmj_miniaudio_version returned null")
        var ptr = raw.bitcast[UInt8]()
        return String(unsafe_from_utf8_ptr=ptr)

    def result_description(self, result: Int) raises -> String:
        var raw = self._lib.call["mmj_result_description", OpaquePointer[MutExternalOrigin]](Int32(result))
        var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
        if raw == null_ptr:
            return String("unknown error")
        var ptr = raw.bitcast[UInt8]()
        return String(unsafe_from_utf8_ptr=ptr)

    def play_sine(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        frequency_hz: Float64,
        duration_seconds: Float64,
        gain: Float32,
    ) raises -> Int:
        return Int(
            self._lib.call["mmj_play_sine_f32", Int32](
                sample_rate,
                channels,
                frequency_hz,
                duration_seconds,
                gain,
            )
        )

    def play_file_f32(
        self,
        file_path: String,
        output_channels: UInt32,
        output_sample_rate: UInt32,
    ) -> Int:
        var file_path_c = file_path + "\x00"
        return Int(
            self._lib.call["mmj_play_file_f32", Int32](
                file_path_c.as_bytes().unsafe_ptr(),
                output_channels,
                output_sample_rate,
            )
        )

    def capture_smoke(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        duration_seconds: Float64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_smoke_f32", Int32](
                sample_rate,
                channels,
                duration_seconds,
            )
        )

    def capture_to_wav_f32(
        self,
        output_path: String,
        sample_rate: UInt32,
        channels: UInt32,
        duration_seconds: Float64,
    ) -> Int:
        var output_path_c = output_path + "\x00"
        return Int(
            self._lib.call["mmj_capture_to_wav_f32", Int32](
                output_path_c.as_bytes().unsafe_ptr(),
                sample_rate,
                channels,
                duration_seconds,
            )
        )

    def duplex_smoke(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        duration_seconds: Float64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_duplex_smoke_f32", Int32](
                sample_rate,
                channels,
                duration_seconds,
            )
        )

    def context_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_context_create", OpaquePointer[MutExternalOrigin]]()

    def context_init_default(
        self, context_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_context_init_default", Int32](context_handle)
        )

    def context_uninit(
        self, context_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_context_uninit", Int32](context_handle)
        )

    def context_get_playback_device_count(
        self,
        context_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_context_get_playback_device_count", Int64](
            context_handle
        )

    def context_get_capture_device_count(
        self,
        context_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_context_get_capture_device_count", Int64](
            context_handle
        )

    def context_get_playback_device_name(
        self,
        context_handle: OpaquePointer[MutExternalOrigin],
        index: UInt32,
    ) raises -> String:
        var buffer = String(" ") * 512
        var bytes = buffer.as_bytes()
        var result = Int(
            self._lib.call["mmj_context_get_playback_device_name", Int32](
                context_handle,
                index,
                bytes.unsafe_ptr(),
                UInt32(512),
            )
        )
        if result != 0:
            raise Error(
                "context_get_playback_device_name failed: "
                + self.result_description(result)
                + " ("
                + String(result)
                + ")"
            )

        return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())

    def context_get_capture_device_name(
        self,
        context_handle: OpaquePointer[MutExternalOrigin],
        index: UInt32,
    ) raises -> String:
        var buffer = String(" ") * 512
        var bytes = buffer.as_bytes()
        var result = Int(
            self._lib.call["mmj_context_get_capture_device_name", Int32](
                context_handle,
                index,
                bytes.unsafe_ptr(),
                UInt32(512),
            )
        )
        if result != 0:
            raise Error(
                "context_get_capture_device_name failed: "
                + self.result_description(result)
                + " ("
                + String(result)
                + ")"
            )

        return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())

    def context_destroy(self, context_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_context_destroy", NoneType](context_handle)

    def engine_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_engine_create", OpaquePointer[MutExternalOrigin]]()

    def engine_init_default(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_engine_init_default", Int32](engine_handle)
        )

    def engine_uninit(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_engine_uninit", Int32](engine_handle)
        )

    def engine_play_sound(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
        file_path: String,
    ) -> Int:
        var file_path_c = file_path + "\x00"
        return Int(
            self._lib.call["mmj_engine_play_sound", Int32](
                engine_handle,
                file_path_c.as_bytes().unsafe_ptr(),
            )
        )

    def engine_listener_set_position(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_engine_listener_set_position", Int32](
                engine_handle,
                listener_index,
                x,
                y,
                z,
            )
        )

    def engine_listener_set_direction(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_engine_listener_set_direction", Int32](
                engine_handle,
                listener_index,
                x,
                y,
                z,
            )
        )

    def engine_listener_set_world_up(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
        listener_index: UInt32,
        x: Float32,
        y: Float32,
        z: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_engine_listener_set_world_up", Int32](
                engine_handle,
                listener_index,
                x,
                y,
                z,
            )
        )

    def engine_destroy(self, engine_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_engine_destroy", NoneType](engine_handle)

    def engine_get_endpoint(
        self,
        engine_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_engine_get_endpoint", OpaquePointer[MutExternalOrigin]](
            engine_handle
        )

    def sound_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_sound_create", OpaquePointer[MutExternalOrigin]]()

    def sound_init_from_file(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        engine_handle: OpaquePointer[MutExternalOrigin],
        file_path: String,
    ) -> Int:
        var file_path_c = file_path + "\x00"
        return Int(
            self._lib.call["mmj_sound_init_from_file", Int32](
                sound_handle,
                engine_handle,
                file_path_c.as_bytes().unsafe_ptr(),
            )
        )

    def sound_start(self, sound_handle: OpaquePointer[MutExternalOrigin]) -> Int:
        return Int(
            self._lib.call["mmj_sound_start", Int32](sound_handle)
        )

    def sound_stop(self, sound_handle: OpaquePointer[MutExternalOrigin]) -> Int:
        return Int(
            self._lib.call["mmj_sound_stop", Int32](sound_handle)
        )

    def sound_set_looping(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        is_looping: Bool,
    ) -> Int:
        var looping_flag = Int32(0)
        if is_looping:
            looping_flag = Int32(1)

        return Int(
            self._lib.call["mmj_sound_set_looping", Int32](
                sound_handle,
                looping_flag,
            )
        )

    def sound_set_volume_f32(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        volume: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_sound_set_volume_f32", Int32](
                sound_handle,
                volume,
            )
        )

    def sound_set_spatialization_enabled(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        is_enabled: Bool,
    ) -> Int:
        var enabled_flag = Int32(0)
        if is_enabled:
            enabled_flag = Int32(1)

        return Int(
            self._lib.call["mmj_sound_set_spatialization_enabled", Int32](
                sound_handle,
                enabled_flag,
            )
        )

    def sound_set_position(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        x: Float32,
        y: Float32,
        z: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_sound_set_position", Int32](
                sound_handle,
                x,
                y,
                z,
            )
        )

    def sound_set_rolloff(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        rolloff: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_sound_set_rolloff", Int32](
                sound_handle,
                rolloff,
            )
        )

    def sound_set_min_distance(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        min_distance: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_sound_set_min_distance", Int32](
                sound_handle,
                min_distance,
            )
        )

    def sound_set_max_distance(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
        max_distance: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_sound_set_max_distance", Int32](
                sound_handle,
                max_distance,
            )
        )

    def sound_get_node(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_sound_get_node", OpaquePointer[MutExternalOrigin]](
            sound_handle
        )

    def sound_uninit(self, sound_handle: OpaquePointer[MutExternalOrigin]) -> Int:
        return Int(
            self._lib.call["mmj_sound_uninit", Int32](sound_handle)
        )

    def sound_destroy(self, sound_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_sound_destroy", NoneType](sound_handle)

    def resource_manager_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_resource_manager_create", OpaquePointer[MutExternalOrigin]]()

    def resource_manager_init_default(
        self,
        resource_manager_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_resource_manager_init_default", Int32](resource_manager_handle)
        )

    def resource_manager_uninit(
        self,
        resource_manager_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_resource_manager_uninit", Int32](resource_manager_handle)
        )

    def resource_manager_destroy(
        self,
        resource_manager_handle: OpaquePointer[MutExternalOrigin],
    ):
        self._lib.call["mmj_resource_manager_destroy", NoneType](resource_manager_handle)

    def resource_data_source_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_resource_data_source_create", OpaquePointer[MutExternalOrigin]]()

    def resource_data_source_init_file(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
        resource_manager_handle: OpaquePointer[MutExternalOrigin],
        file_path: String,
        flags: UInt32,
    ) -> Int:
        var file_path_c = file_path + "\x00"
        return Int(
            self._lib.call["mmj_resource_data_source_init_file", Int32](
                data_source_handle,
                resource_manager_handle,
                file_path_c.as_bytes().unsafe_ptr(),
                flags,
            )
        )

    def resource_data_source_result(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_resource_data_source_result", Int32](data_source_handle)
        )

    def resource_data_source_wait_result(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
        timeout_ms: UInt32,
        poll_interval_ms: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_resource_data_source_wait_result", Int32](
                data_source_handle,
                timeout_ms,
                poll_interval_ms,
            )
        )

    def resource_data_source_get_length_in_pcm_frames(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_resource_data_source_get_length_in_pcm_frames", Int64](
            data_source_handle
        )

    def resource_data_source_uninit(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_resource_data_source_uninit", Int32](data_source_handle)
        )

    def resource_data_source_destroy(
        self,
        data_source_handle: OpaquePointer[MutExternalOrigin],
    ):
        self._lib.call["mmj_resource_data_source_destroy", NoneType](data_source_handle)

    def resource_data_source_flag_async(self) -> UInt32:
        return self._lib.call["mmj_resource_data_source_flag_async", UInt32]()

    def device_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_device_create", OpaquePointer[MutExternalOrigin]]()

    def device_init_playback_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_playback_f32", Int32](
                device_handle,
                sample_rate,
                channels,
            )
        )

    def device_init_capture_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_capture_f32", Int32](
                device_handle,
                sample_rate,
                channels,
            )
        )

    def device_init_duplex_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_duplex_f32", Int32](
                device_handle,
                sample_rate,
                channels,
            )
        )

    def device_init_duplex_loopback_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_duplex_loopback_f32", Int32](
                device_handle,
                sample_rate,
                channels,
            )
        )

    def device_init_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        device_kind: Int,
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_f32", Int32](
                device_handle,
                Int32(device_kind),
                sample_rate,
                channels,
            )
        )

    def device_start(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_start", Int32](device_handle)
        )

    def device_stop(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_stop", Int32](device_handle)
        )

    def device_is_started(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Bool:
        return self._lib.call["mmj_device_is_started", Int32](device_handle) != 0

    def device_get_kind(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_get_kind", Int32](device_handle)
        )

    def device_get_sample_rate(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_get_sample_rate", Int32](device_handle)
        )

    def device_get_channels(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_get_channels", Int32](device_handle)
        )

    def device_set_master_volume_f32(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        volume: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_set_master_volume_f32", Int32](
                device_handle,
                volume,
            )
        )

    def device_get_master_volume_milli(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_get_master_volume_milli", Int32](
                device_handle
            )
        )

    def device_uninit(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_uninit", Int32](device_handle)
        )

    def device_destroy(self, device_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_device_destroy", NoneType](device_handle)

    def decoder_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_decoder_create", OpaquePointer[MutExternalOrigin]]()

    def decoder_init_file_f32(
        self,
        decoder_handle: OpaquePointer[MutExternalOrigin],
        file_path: String,
        output_channels: UInt32,
        output_sample_rate: UInt32,
    ) -> Int:
        var file_path_c = file_path + "\x00"
        return Int(
            self._lib.call["mmj_decoder_init_file_f32", Int32](
                decoder_handle,
                file_path_c.as_bytes().unsafe_ptr(),
                output_channels,
                output_sample_rate,
            )
        )

    def decoder_seek_to_pcm_frame(
        self,
        decoder_handle: OpaquePointer[MutExternalOrigin],
        frame_index: UInt64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_decoder_seek_to_pcm_frame", Int32](
                decoder_handle,
                frame_index,
            )
        )

    def decoder_read_probe_f32(
        self,
        decoder_handle: OpaquePointer[MutExternalOrigin],
        frame_count: UInt64,
    ) -> Int64:
        return self._lib.call["mmj_decoder_read_probe_f32", Int64](
            decoder_handle,
            frame_count,
        )

    def decoder_read_pcm_frames_f32(
        self,
        decoder_handle: OpaquePointer[MutExternalOrigin],
        output_buffer: String,
        frame_count: UInt64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_decoder_read_pcm_frames_f32", Int32](
                decoder_handle,
                output_buffer.as_bytes().unsafe_ptr(),
                frame_count,
                OpaquePointer[MutExternalOrigin](unsafe_from_address=0),
            )
        )

    def decoder_uninit(
        self, decoder_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_decoder_uninit", Int32](decoder_handle)
        )

    def decoder_destroy(self, decoder_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_decoder_destroy", NoneType](decoder_handle)
