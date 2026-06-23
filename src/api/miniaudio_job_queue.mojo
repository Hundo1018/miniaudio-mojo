from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_job_queue_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.job_queue_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "job queue smoke failed",
                result,
            )
        )

    print("job queue smoke ok")


def run_job_queue_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.job_queue_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "job queue invalid-args smoke failed",
                result,
            )
        )

    print("job queue invalid-args smoke ok")
