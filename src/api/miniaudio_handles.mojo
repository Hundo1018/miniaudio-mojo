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