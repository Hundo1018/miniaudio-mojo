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

    def sound_get_cursor_in_pcm_frames(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_sound_get_cursor_in_pcm_frames", Int64](
            sound_handle
        )

    def sound_get_time_in_milliseconds(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_sound_get_time_in_milliseconds", Int64](
            sound_handle
        )

    def sound_is_finished(
        self,
        sound_handle: OpaquePointer[MutExternalOrigin],
    ) -> Bool:
        return self._lib.call["mmj_sound_is_finished", Int32](sound_handle) != 0

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

    def node_attach_output_bus(
        self,
        node_handle: OpaquePointer[MutExternalOrigin],
        output_bus_index: UInt32,
        other_node_handle: OpaquePointer[MutExternalOrigin],
        other_node_input_bus_index: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_node_attach_output_bus", Int32](
                node_handle,
                output_bus_index,
                other_node_handle,
                other_node_input_bus_index,
            )
        )

    def node_detach_output_bus(
        self,
        node_handle: OpaquePointer[MutExternalOrigin],
        output_bus_index: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_node_detach_output_bus", Int32](
                node_handle,
                output_bus_index,
            )
        )

    def node_get_output_bus_count(
        self,
        node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_node_get_output_bus_count", Int32](node_handle)
        )

    def node_set_output_bus_volume(
        self,
        node_handle: OpaquePointer[MutExternalOrigin],
        output_bus_index: UInt32,
        volume: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_node_set_output_bus_volume", Int32](
                node_handle,
                output_bus_index,
                volume,
            )
        )

    def node_get_output_bus_volume(
        self,
        node_handle: OpaquePointer[MutExternalOrigin],
        output_bus_index: UInt32,
    ) -> Float32:
        return self._lib.call["mmj_node_get_output_bus_volume", Float32](
            node_handle,
            output_bus_index,
        )

    def lpf_node_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_lpf_node_create", OpaquePointer[MutExternalOrigin]]()

    def lpf_node_init(
        self,
        lpf_node_handle: OpaquePointer[MutExternalOrigin],
        engine_handle: OpaquePointer[MutExternalOrigin],
        channels: UInt32,
        sample_rate: UInt32,
        cutoff_hz: Float32,
        order: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_lpf_node_init", Int32](
                lpf_node_handle,
                engine_handle,
                channels,
                sample_rate,
                cutoff_hz,
                order,
            )
        )

    def lpf_node_set_cutoff(
        self,
        lpf_node_handle: OpaquePointer[MutExternalOrigin],
        cutoff_hz: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_lpf_node_set_cutoff", Int32](
                lpf_node_handle,
                cutoff_hz,
            )
        )

    def lpf_node_get_cutoff(
        self,
        lpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Float32:
        return self._lib.call["mmj_lpf_node_get_cutoff", Float32](lpf_node_handle)

    def lpf_node_get_node(
        self,
        lpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_lpf_node_get_node", OpaquePointer[MutExternalOrigin]](
            lpf_node_handle
        )

    def lpf_node_uninit(
        self,
        lpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(self._lib.call["mmj_lpf_node_uninit", Int32](lpf_node_handle))

    def lpf_node_destroy(self, lpf_node_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_lpf_node_destroy", NoneType](lpf_node_handle)

    def hpf_node_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_hpf_node_create", OpaquePointer[MutExternalOrigin]]()

    def hpf_node_init(
        self,
        hpf_node_handle: OpaquePointer[MutExternalOrigin],
        engine_handle: OpaquePointer[MutExternalOrigin],
        channels: UInt32,
        sample_rate: UInt32,
        cutoff_hz: Float32,
        order: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_hpf_node_init", Int32](
                hpf_node_handle,
                engine_handle,
                channels,
                sample_rate,
                cutoff_hz,
                order,
            )
        )

    def hpf_node_set_cutoff(
        self,
        hpf_node_handle: OpaquePointer[MutExternalOrigin],
        cutoff_hz: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_hpf_node_set_cutoff", Int32](
                hpf_node_handle,
                cutoff_hz,
            )
        )

    def hpf_node_get_cutoff(
        self,
        hpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Float32:
        return self._lib.call["mmj_hpf_node_get_cutoff", Float32](hpf_node_handle)

    def hpf_node_get_node(
        self,
        hpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_hpf_node_get_node", OpaquePointer[MutExternalOrigin]](
            hpf_node_handle
        )

    def hpf_node_uninit(
        self,
        hpf_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(self._lib.call["mmj_hpf_node_uninit", Int32](hpf_node_handle))

    def hpf_node_destroy(self, hpf_node_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_hpf_node_destroy", NoneType](hpf_node_handle)

    def delay_node_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_delay_node_create", OpaquePointer[MutExternalOrigin]]()

    def delay_node_init(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
        engine_handle: OpaquePointer[MutExternalOrigin],
        channels: UInt32,
        sample_rate: UInt32,
        delay_frames: UInt32,
        decay: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_delay_node_init", Int32](
                delay_node_handle,
                engine_handle,
                channels,
                sample_rate,
                delay_frames,
                decay,
            )
        )

    def delay_node_set_wet(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
        wet: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_delay_node_set_wet", Int32](
                delay_node_handle,
                wet,
            )
        )

    def delay_node_get_wet(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Float32:
        return self._lib.call["mmj_delay_node_get_wet", Float32](delay_node_handle)

    def delay_node_set_dry(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
        dry: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_delay_node_set_dry", Int32](
                delay_node_handle,
                dry,
            )
        )

    def delay_node_get_dry(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Float32:
        return self._lib.call["mmj_delay_node_get_dry", Float32](delay_node_handle)

    def delay_node_set_decay(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
        decay: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_delay_node_set_decay", Int32](
                delay_node_handle,
                decay,
            )
        )

    def delay_node_get_decay(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Float32:
        return self._lib.call["mmj_delay_node_get_decay", Float32](delay_node_handle)

    def delay_node_get_node(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_delay_node_get_node", OpaquePointer[MutExternalOrigin]](
            delay_node_handle
        )

    def delay_node_uninit(
        self,
        delay_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(self._lib.call["mmj_delay_node_uninit", Int32](delay_node_handle))

    def delay_node_destroy(self, delay_node_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_delay_node_destroy", NoneType](delay_node_handle)

    def splitter_node_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_splitter_node_create", OpaquePointer[MutExternalOrigin]]()

    def splitter_node_init(
        self,
        splitter_node_handle: OpaquePointer[MutExternalOrigin],
        engine_handle: OpaquePointer[MutExternalOrigin],
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_splitter_node_init", Int32](
                splitter_node_handle,
                engine_handle,
                channels,
            )
        )

    def splitter_node_set_output_bus_volume(
        self,
        splitter_node_handle: OpaquePointer[MutExternalOrigin],
        bus_index: UInt32,
        volume: Float32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_splitter_node_set_output_bus_volume", Int32](
                splitter_node_handle,
                bus_index,
                volume,
            )
        )

    def splitter_node_get_output_bus_volume(
        self,
        splitter_node_handle: OpaquePointer[MutExternalOrigin],
        bus_index: UInt32,
    ) -> Float32:
        return self._lib.call["mmj_splitter_node_get_output_bus_volume", Float32](
            splitter_node_handle,
            bus_index,
        )

    def splitter_node_get_node(
        self,
        splitter_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_splitter_node_get_node", OpaquePointer[MutExternalOrigin]](
            splitter_node_handle
        )

    def splitter_node_uninit(
        self,
        splitter_node_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(self._lib.call["mmj_splitter_node_uninit", Int32](splitter_node_handle))

    def splitter_node_destroy(self, splitter_node_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_splitter_node_destroy", NoneType](splitter_node_handle)

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

    def device_init_playback_f32_by_index(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        context_handle: OpaquePointer[MutExternalOrigin],
        device_index: UInt32,
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_playback_f32_by_index", Int32](
                device_handle,
                context_handle,
                device_index,
                sample_rate,
                channels,
            )
        )

    def device_init_capture_f32_by_index(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        context_handle: OpaquePointer[MutExternalOrigin],
        device_index: UInt32,
        sample_rate: UInt32,
        channels: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_init_capture_f32_by_index", Int32](
                device_handle,
                context_handle,
                device_index,
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

    def device_set_callback_mode(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        mode: Int,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_set_callback_mode", Int32](
                device_handle,
                Int32(mode),
            )
        )

    def device_get_callback_mode(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_get_callback_mode", Int32](device_handle)
        )

    def device_get_observed_frames(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int64:
        return self._lib.call["mmj_device_get_observed_frames", Int64](device_handle)

    def device_reset_observed_frames(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_reset_observed_frames", Int32](device_handle)
        )

    def device_wait_for_observed_frames(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        min_frames: UInt64,
        timeout_ms: UInt32,
        poll_interval_ms: UInt32,
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_wait_for_observed_frames", Int32](
                device_handle,
                min_frames,
                timeout_ms,
                poll_interval_ms,
            )
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

    def encoder_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_encoder_create", OpaquePointer[MutExternalOrigin]]()

    def encoder_init_wav_file_f32(
        self,
        encoder_handle: OpaquePointer[MutExternalOrigin],
        output_path: String,
        channels: UInt32,
        sample_rate: UInt32,
    ) -> Int:
        var output_path_c = output_path + "\x00"
        return Int(
            self._lib.call["mmj_encoder_init_wav_file_f32", Int32](
                encoder_handle,
                output_path_c.as_bytes().unsafe_ptr(),
                channels,
                sample_rate,
            )
        )

    def encoder_write_silence_f32(
        self,
        encoder_handle: OpaquePointer[MutExternalOrigin],
        frame_count: UInt64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_encoder_write_silence_f32", Int32](
                encoder_handle,
                frame_count,
            )
        )

    def encoder_uninit(
        self,
        encoder_handle: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_encoder_uninit", Int32](encoder_handle)
        )

    def encoder_destroy(self, encoder_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_encoder_destroy", NoneType](encoder_handle)

    # === Memory-based I/O methods ===

    def playback_from_buffer_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_playback_from_buffer_create", OpaquePointer[MutExternalOrigin]]()

    def playback_from_buffer_init_f32(
        self,
        playback_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
        buffer_ptr: UnsafePointer[Float32],
        buffer_frame_count: UInt64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_playback_from_buffer_init_f32", Int32](
                playback_handle,
                sample_rate,
                channels,
                buffer_ptr,
                buffer_frame_count,
            )
        )

    def playback_from_buffer_start(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_playback_from_buffer_start", Int32](playback_handle)
        )

    def playback_from_buffer_stop(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_playback_from_buffer_stop", Int32](playback_handle)
        )

    def playback_from_buffer_is_finished(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_playback_from_buffer_is_finished", Int32](playback_handle)
        )

    def playback_from_buffer_get_position_in_frames(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int64:
        return self._lib.call["mmj_playback_from_buffer_get_position_in_frames", Int64](
            playback_handle
        )

    def playback_from_buffer_uninit(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_playback_from_buffer_uninit", Int32](playback_handle)
        )

    def playback_from_buffer_destroy(
        self, playback_handle: OpaquePointer[MutExternalOrigin]
    ):
        self._lib.call["mmj_playback_from_buffer_destroy", NoneType](playback_handle)

    def capture_to_buffer_create(self) -> OpaquePointer[MutExternalOrigin]:
        return self._lib.call["mmj_capture_to_buffer_create", OpaquePointer[MutExternalOrigin]]()

    def capture_to_buffer_init_f32(
        self,
        capture_handle: OpaquePointer[MutExternalOrigin],
        sample_rate: UInt32,
        channels: UInt32,
        buffer_ptr: UnsafePointer[Float32],
        buffer_frame_capacity: UInt64,
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_to_buffer_init_f32", Int32](
                capture_handle,
                sample_rate,
                channels,
                buffer_ptr,
                buffer_frame_capacity,
            )
        )

    def capture_to_buffer_start(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_to_buffer_start", Int32](capture_handle)
        )

    def capture_to_buffer_stop(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_to_buffer_stop", Int32](capture_handle)
        )

    def capture_to_buffer_get_frames_captured(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int64:
        return self._lib.call["mmj_capture_to_buffer_get_frames_captured", Int64](
            capture_handle
        )

    def capture_to_buffer_reset(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_to_buffer_reset", Int32](capture_handle)
        )

    def capture_to_buffer_uninit(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_capture_to_buffer_uninit", Int32](capture_handle)
        )

    def capture_to_buffer_destroy(
        self, capture_handle: OpaquePointer[MutExternalOrigin]
    ):
        self._lib.call["mmj_capture_to_buffer_destroy", NoneType](capture_handle)

    # User-defined callback registration methods
    
    def device_set_data_callback(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        callback: OpaquePointer[MutExternalOrigin],
        user_data: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_set_data_callback", Int32](
                device_handle, callback, user_data
            )
        )

    def device_set_stop_callback(
        self,
        device_handle: OpaquePointer[MutExternalOrigin],
        callback: OpaquePointer[MutExternalOrigin],
        user_data: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_set_stop_callback", Int32](
                device_handle, callback, user_data
            )
        )

    def device_clear_callbacks(
        self, device_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_device_clear_callbacks", Int32](device_handle)
        )

    # Test helper for user callbacks
    
    def device_test_callback_smoke(self, duration_ms: UInt32) -> Int:
        return Int(
            self._lib.call["mmj_device_test_callback_smoke", Int32](duration_ms)
        )
