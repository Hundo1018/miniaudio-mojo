from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import result_name


def run_capture_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    var result = bridge.capture_smoke(48000, 2, 0.5)
    if result != 0:
        raise Error(
            "capture smoke failed: "
            + result_name(result)
            + " - "
            + bridge.result_description(result)
            + " ("
            + String(result)
            + ")"
        )

    print("capture smoke ok (init + start + stop)")
