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
