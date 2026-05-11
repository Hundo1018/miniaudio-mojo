from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_ALREADY_IN_USE, MA_DOES_NOT_EXIST, MA_INVALID_ARGS, MA_UNAVAILABLE, result_name
from miniaudio_handles import MiniAudioDeviceHandle
from miniaudio_result_utils import format_result_error


def run_duplex_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    var result = bridge.duplex_smoke(48000, 2, 0.5)
    if result == 0:
        print("duplex smoke ok (capture + playback)")
        return

    if (
        result == MA_DOES_NOT_EXIST
        or result == MA_UNAVAILABLE
        or result == MA_ALREADY_IN_USE
    ):
        print(
            format_result_error(bridge, "duplex smoke skipped", result)
        )
        return

    raise Error(format_result_error(bridge, "duplex smoke failed", result))


def run_duplex_control_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var device = MiniAudioDeviceHandle(bridge)

    var preinit_start = bridge.device_start(device.raw)
    if preinit_start != MA_INVALID_ARGS:
        device.close(bridge)
        raise Error(
            "duplex control pre-init start expected MA_INVALID_ARGS, got: "
            + result_name(preinit_start)
            + " ("
            + String(preinit_start)
            + ")"
        )

    var init_result = bridge.device_init_duplex_loopback_f32(device.raw, 48000, 2)
    if init_result != 0:
        device.close(bridge)
        if (
            init_result == MA_DOES_NOT_EXIST
            or init_result == MA_UNAVAILABLE
            or init_result == MA_ALREADY_IN_USE
        ):
            print(format_result_error(bridge, "duplex control smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "duplex control init failed", init_result))

    var start_result = bridge.device_start(device.raw)
    if start_result != 0:
        device.close(bridge)
        raise Error(format_result_error(bridge, "duplex control start failed", start_result))

    if not bridge.device_is_started(device.raw):
        device.close(bridge)
        raise Error("duplex control expected started state after start")

    var stop_result = bridge.device_stop(device.raw)
    if stop_result != 0:
        device.close(bridge)
        raise Error(format_result_error(bridge, "duplex control stop failed", stop_result))

    if bridge.device_is_started(device.raw):
        device.close(bridge)
        raise Error("duplex control expected stopped state after stop")

    device.close(bridge)
    print("duplex control smoke ok (pre-init checks + init + start + stop)")
