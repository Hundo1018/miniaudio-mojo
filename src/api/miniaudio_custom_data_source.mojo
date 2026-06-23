from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_custom_buffer_data_source_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.custom_buffer_data_source_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "custom buffer data source smoke failed",
                result,
            )
        )

    print("custom buffer data source smoke ok")


def run_custom_buffer_data_source_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.custom_buffer_data_source_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "custom buffer data source invalid-args smoke failed",
                result,
            )
        )

    print("custom buffer data source invalid-args smoke ok")
