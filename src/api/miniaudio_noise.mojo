from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_noise_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.noise_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "noise smoke failed", result))

    print("noise smoke ok")


def run_noise_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.noise_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "noise invalid-args smoke failed",
                result,
            )
        )

    print("noise invalid-args smoke ok")
