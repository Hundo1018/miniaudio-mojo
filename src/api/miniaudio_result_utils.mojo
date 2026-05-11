from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import result_name


def format_result_error(
    bridge: MiniAudioCtypes,
    action: String,
    code: Int,
) raises -> String:
    if action == "":
        return (
            result_name(code)
            + " - "
            + bridge.result_description(code)
            + " ("
            + String(code)
            + ")"
        )

    return (
        action
        + ": "
        + result_name(code)
        + " - "
        + bridge.result_description(code)
        + " ("
        + String(code)
        + ")"
    )