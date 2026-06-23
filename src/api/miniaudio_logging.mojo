from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_INVALID_ARGS
from miniaudio_result_utils import format_result_error


def run_logging_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var log_handle = bridge.log_create()
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))

    if log_handle == null_ptr:
        raise Error("log create failed")

    var result = bridge.log_init(log_handle)
    if result != 0:
        bridge.log_destroy(log_handle)
        raise Error(format_result_error(bridge, "log init failed", result))

    result = bridge.log_register_counting_callback(log_handle)
    if result != 0:
        _ = bridge.log_uninit(log_handle)
        bridge.log_destroy(log_handle)
        raise Error(format_result_error(bridge, "log register callback failed", result))

    result = bridge.log_post_info(log_handle, "miniaudio-mojo logging smoke")
    if result != 0:
        _ = bridge.log_unregister_counting_callback(log_handle)
        _ = bridge.log_uninit(log_handle)
        bridge.log_destroy(log_handle)
        raise Error(format_result_error(bridge, "log post info failed", result))

    var callback_count = bridge.log_get_callback_count(log_handle)
    if callback_count <= 0:
        _ = bridge.log_unregister_counting_callback(log_handle)
        _ = bridge.log_uninit(log_handle)
        bridge.log_destroy(log_handle)
        raise Error("log callback was not invoked")

    result = bridge.log_unregister_counting_callback(log_handle)
    if result != 0:
        _ = bridge.log_uninit(log_handle)
        bridge.log_destroy(log_handle)
        raise Error(format_result_error(bridge, "log unregister callback failed", result))

    result = bridge.log_uninit(log_handle)
    bridge.log_destroy(log_handle)
    if result != 0:
        raise Error(format_result_error(bridge, "log uninit failed", result))

    print("logging smoke ok (callbacks observed:", callback_count, ")")


def run_logging_invalid_state_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var log_handle = bridge.log_create()
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))

    if log_handle == null_ptr:
        raise Error("log create failed")

    var result = bridge.log_post_info(log_handle, "should fail before init")
    bridge.log_destroy(log_handle)

    if result != MA_INVALID_ARGS:
        raise Error(
            "log invalid-state smoke expected MA_INVALID_ARGS, got: " + String(result)
        )

    print("logging invalid-state smoke ok")
