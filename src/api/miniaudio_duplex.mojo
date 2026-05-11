from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_ALREADY_IN_USE, MA_DOES_NOT_EXIST, MA_UNAVAILABLE, result_name


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
            "duplex smoke skipped: "
            + result_name(result)
            + " - "
            + bridge.result_description(result)
            + " ("
            + String(result)
            + ")"
        )
        return

    raise Error(
        "duplex smoke failed: "
        + result_name(result)
        + " - "
        + bridge.result_description(result)
        + " ("
        + String(result)
        + ")"
    )
