from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioContextHandle
from miniaudio_result_utils import format_result_error


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
