from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import result_name


def run_playback_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    print("Mojo native FFI bridge -> miniaudio")
    print("miniaudio version:", bridge.version())

    var result = bridge.play_sine(48000, 2, 440.0, 1.0, 0.15)
    if result != 0:
        raise Error(
            "playback failed: "
            + result_name(result)
            + " - "
            + bridge.result_description(result)
            + " ("
            + String(result)
            + ")"
        )

    print("playback ok")
