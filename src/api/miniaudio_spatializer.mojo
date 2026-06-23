from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_spatializer_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.spatializer_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "spatializer smoke failed", result))

    print("spatializer smoke ok")


def run_spatializer_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.spatializer_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "spatializer invalid-args smoke failed",
                result,
            )
        )

    print("spatializer invalid-args smoke ok")
