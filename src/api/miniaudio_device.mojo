from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_ALREADY_IN_USE, MA_DOES_NOT_EXIST, MA_INVALID_ARGS, MA_UNAVAILABLE, result_name
from miniaudio_handles import MiniAudioDeviceHandle
from miniaudio_result_utils import format_result_error

comptime MMJ_DEVICE_KIND_PLAYBACK = Int(1)
comptime MMJ_DEVICE_KIND_CAPTURE = Int(2)
comptime MMJ_DEVICE_KIND_DUPLEX = Int(3)
comptime MMJ_DEVICE_KIND_DUPLEX_LOOPBACK = Int(4)


def is_device_control_skip_code(code: Int) -> Bool:
    return (
        code == MA_DOES_NOT_EXIST
        or code == MA_UNAVAILABLE
        or code == MA_ALREADY_IN_USE
    )


def run_device_control_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var device = MiniAudioDeviceHandle(bridge)

    try:
        device.init_playback_f32(bridge, 48000, 2)

        if device.is_started(bridge):
            raise Error("device should not be started immediately after init")

        var start_result = bridge.device_start(device.raw)
        if start_result != 0:
            if is_device_control_skip_code(start_result):
                device.close(bridge)
                print(format_result_error(bridge, "device control smoke skipped", start_result))
                return

            raise Error(format_result_error(bridge, "device start failed", start_result))

        if not device.is_started(bridge):
            raise Error("device should report started after start")

        var stop_result = bridge.device_stop(device.raw)
        if stop_result != 0:
            raise Error(format_result_error(bridge, "device stop failed", stop_result))

        if device.is_started(bridge):
            raise Error("device should report stopped after stop")
    except e:
        device.close(bridge)
        raise e^

    device.close(bridge)
    print("device control smoke ok (init + start + stop + close)")


def run_device_volume_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var preinit_set = bridge.device_set_master_volume_f32(device, 0.5)
    if preinit_set != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_set_master_volume_f32 pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_set)
        )

    var preinit_get = bridge.device_get_master_volume_milli(device)
    if preinit_get != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_get_master_volume_milli pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_get)
        )

    var init_result = bridge.device_init_playback_f32(device, 48000, 2)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print(format_result_error(bridge, "device volume smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "device init playback failed", init_result))

    var set_result = bridge.device_set_master_volume_f32(device, 0.25)
    if set_result != 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(format_result_error(bridge, "device set volume failed", set_result))

    var volume_milli = bridge.device_get_master_volume_milli(device)
    if volume_milli < 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        var code = Int(volume_milli)
        raise Error(format_result_error(bridge, "device get volume failed", code))

    if volume_milli < 100 or volume_milli > 400:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(
            "device volume out of expected range after set, got milli: "
            + String(volume_milli)
        )

    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)
    print("device volume smoke ok (pre-init checks + set/get)")


def run_device_config_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var preinit_kind = bridge.device_get_kind(device)
    if preinit_kind != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_get_kind pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_kind)
        )

    var invalid_init = bridge.device_init_f32(device, 999, 48000, 2)
    if invalid_init != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_init_f32 invalid kind expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_init)
        )

    var init_result = bridge.device_init_f32(
        device,
        MMJ_DEVICE_KIND_PLAYBACK,
        48000,
        2,
    )
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print(format_result_error(bridge, "device config smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "device init f32 failed", init_result))

    var kind = bridge.device_get_kind(device)
    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)

    if kind != MMJ_DEVICE_KIND_PLAYBACK:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device kind mismatch after init: " + String(kind))

    if sample_rate != 48000:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device sample rate mismatch after init: " + String(sample_rate))

    if channels != 2:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device channels mismatch after init: " + String(channels))

    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)
    print("device config smoke ok (unified init + config getters)")