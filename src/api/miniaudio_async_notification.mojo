from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_result_utils import format_result_error


def run_async_notification_poll_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.async_notification_poll_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "async notification poll smoke failed",
                result,
            )
        )

    print("async notification poll smoke ok")


def run_async_notification_poll_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.async_notification_poll_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "async notification poll invalid-args smoke failed",
                result,
            )
        )

    print("async notification poll invalid-args smoke ok")


def run_async_notification_event_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.async_notification_event_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "async notification event smoke failed",
                result,
            )
        )

    print("async notification event smoke ok")


def run_async_notification_event_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.async_notification_event_invalid_args_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "async notification event invalid-args smoke failed",
                result,
            )
        )

    print("async notification event invalid-args smoke ok")
