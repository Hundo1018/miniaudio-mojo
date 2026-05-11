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

    def decoder_uninit(
        self, decoder_handle: OpaquePointer[MutExternalOrigin]
    ) -> Int:
        return Int(
            self._lib.call["mmj_decoder_uninit", Int32](decoder_handle)
        )

    def decoder_destroy(self, decoder_handle: OpaquePointer[MutExternalOrigin]):
        self._lib.call["mmj_decoder_destroy", NoneType](decoder_handle)
