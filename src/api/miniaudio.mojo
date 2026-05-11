from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_playback_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    print("Mojo native FFI bridge -> miniaudio")
    print("miniaudio version:", bridge.version())

    var result = bridge.play_sine(48000, 2, 440.0, 1.0, 0.15)
    if result != 0:
        raise Error(format_result_error(bridge, "playback failed", result))

    print("playback ok")


def run_playback_file_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    var result = bridge.play_file_f32(file_path, 2, 48000)
    if result != 0:
        raise Error(format_result_error(bridge, "playback file failed", result))

    print("playback file ok")
