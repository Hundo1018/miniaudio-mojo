from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_ALREADY_IN_USE, MA_DOES_NOT_EXIST, MA_UNAVAILABLE
from miniaudio_handles import MiniAudioContextHandle, MiniAudioDeviceHandle
from miniaudio_result_utils import format_result_error


def is_device_select_skip_code(code: Int) -> Bool:
    return (
        code == MA_DOES_NOT_EXIST
        or code == MA_UNAVAILABLE
        or code == MA_ALREADY_IN_USE
    )


def run_devices_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var context = MiniAudioContextHandle(bridge)
    try:
        context.init_default(bridge)

        var playback_count_probe = bridge.context_get_playback_device_count(context.raw)
        if playback_count_probe < 0:
            var code = Int(playback_count_probe)
            raise Error(format_result_error(bridge, "context_get_playback_device_count failed", code))

        var capture_count_probe = bridge.context_get_capture_device_count(context.raw)
        if capture_count_probe < 0:
            var code = Int(capture_count_probe)
            raise Error(format_result_error(bridge, "context_get_capture_device_count failed", code))

        var playback_count = UInt32(playback_count_probe)
        var capture_count = UInt32(capture_count_probe)

        print("device smoke counts -> playback:", playback_count, "capture:", capture_count)

        var playback_to_show = playback_count
        if playback_to_show > 3:
            playback_to_show = 3

        var i = UInt32(0)
        while i < playback_to_show:
            var item_name = bridge.context_get_playback_device_name(context.raw, i)
            print("playback[", i, "]:", item_name)
            i += 1

        var capture_to_show = capture_count
        if capture_to_show > 3:
            capture_to_show = 3

        var j = UInt32(0)
        while j < capture_to_show:
            var item_name = bridge.context_get_capture_device_name(context.raw, j)
            print("capture[", j, "]:", item_name)
            j += 1
    except e:
        context.close(bridge)
        raise e^

    context.close(bridge)
    print("device smoke ok")


def run_device_select_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var context = MiniAudioContextHandle(bridge)
    var device = MiniAudioDeviceHandle(bridge)

    try:
        context.init_default(bridge)

        var playback_count_probe = bridge.context_get_playback_device_count(context.raw)
        if playback_count_probe < 0:
            var code = Int(playback_count_probe)
            raise Error(
                format_result_error(
                    bridge,
                    "device select playback count failed",
                    code,
                )
            )

        if playback_count_probe == 0:
            print("device select smoke skipped: no playback devices")
            return

        var init_result = bridge.device_init_playback_f32_by_index(
            device.raw,
            context.raw,
            0,
            48000,
            2,
        )
        if init_result != 0:
            if is_device_select_skip_code(init_result):
                print(format_result_error(bridge, "device select smoke skipped", init_result))
                return
            raise Error(
                format_result_error(
                    bridge,
                    "device init playback by index failed",
                    init_result,
                )
            )

        device.initialized = True

        var sample_rate = device.get_sample_rate(bridge)
        if sample_rate <= 0:
            raise Error("device select smoke sample rate must be positive")

        var channels = device.get_channels(bridge)
        if channels <= 0:
            raise Error("device select smoke channels must be positive")
    finally:
        device.close(bridge)
        context.close(bridge)

    print("device select smoke ok")
