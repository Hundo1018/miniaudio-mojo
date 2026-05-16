from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_capture_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    var result = bridge.capture_smoke(48000, 2, 0.5)
    if result != 0:
        raise Error(format_result_error(bridge, "capture smoke failed", result))

    print("capture smoke ok (init + start + stop)")


def run_capture_file_smoke(output_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    var result = bridge.capture_to_wav_f32(output_path, 48000, 2, 0.5)
    if result != 0:
        raise Error(format_result_error(bridge, "capture file smoke failed", result))

    print("capture file smoke ok ->", output_path)


def run_encoder_wav_smoke(output_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var encoder = bridge.encoder_create()
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    if encoder == null_ptr:
        raise Error("encoder create failed")

    var result = bridge.encoder_init_wav_file_f32(encoder, output_path, 2, 48000)
    if result != 0:
        bridge.encoder_destroy(encoder)
        raise Error(format_result_error(bridge, "encoder init wav failed", result))

    result = bridge.encoder_write_silence_f32(encoder, 24000)
    if result != 0:
        _ = bridge.encoder_uninit(encoder)
        bridge.encoder_destroy(encoder)
        raise Error(format_result_error(bridge, "encoder write silence failed", result))

    result = bridge.encoder_uninit(encoder)
    bridge.encoder_destroy(encoder)
    if result != 0:
        raise Error(format_result_error(bridge, "encoder uninit failed", result))

    print("encoder wav smoke ok ->", output_path)
