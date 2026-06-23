from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_data_converter_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.data_converter_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "data converter smoke failed",
                result,
            )
        )

    print("data converter smoke ok")


def run_data_converter_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.data_converter_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "data converter invalid-args smoke failed",
                result,
            )
        )

    print("data converter invalid-args smoke ok")
