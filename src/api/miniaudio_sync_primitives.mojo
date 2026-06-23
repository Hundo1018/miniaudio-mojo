from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_sync_primitives_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.sync_primitives_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "sync primitives smoke failed",
                result,
            )
        )

    print("sync primitives smoke ok")


def run_sync_primitives_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.sync_primitives_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "sync primitives invalid-args smoke failed",
                result,
            )
        )

    print("sync primitives invalid-args smoke ok")
