from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import result_name


def run_devices_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    var context = bridge.context_create()
    if context == null_ptr:
        raise Error("context_create failed")

    var init_result = bridge.context_init_default(context)
    if init_result != 0:
        bridge.context_destroy(context)
        raise Error(
            "context init failed: "
            + bridge.result_description(init_result)
            + " ("
            + String(init_result)
            + ")"
        )

    var playback_count_probe = bridge.context_get_playback_device_count(context)
    if playback_count_probe < 0:
        _ = bridge.context_uninit(context)
        bridge.context_destroy(context)
        var code = Int(playback_count_probe)
        raise Error(
            "context_get_playback_device_count failed: "
            + result_name(code)
            + " - "
            + bridge.result_description(code)
            + " ("
            + String(code)
            + ")"
        )

    var capture_count_probe = bridge.context_get_capture_device_count(context)
    if capture_count_probe < 0:
        _ = bridge.context_uninit(context)
        bridge.context_destroy(context)
        var code = Int(capture_count_probe)
        raise Error(
            "context_get_capture_device_count failed: "
            + result_name(code)
            + " - "
            + bridge.result_description(code)
            + " ("
            + String(code)
            + ")"
        )

    var playback_count = UInt32(playback_count_probe)
    var capture_count = UInt32(capture_count_probe)

    print("device smoke counts -> playback:", playback_count, "capture:", capture_count)

    var playback_to_show = playback_count
    if playback_to_show > 3:
        playback_to_show = 3

    var i = UInt32(0)
    while i < playback_to_show:
        var item_name = bridge.context_get_playback_device_name(context, i)
        print("playback[", i, "]:", item_name)
        i += 1

    var capture_to_show = capture_count
    if capture_to_show > 3:
        capture_to_show = 3

    var j = UInt32(0)
    while j < capture_to_show:
        var item_name = bridge.context_get_capture_device_name(context, j)
        print("capture[", j, "]:", item_name)
        j += 1

    _ = bridge.context_uninit(context)
    bridge.context_destroy(context)
    print("device smoke ok")
