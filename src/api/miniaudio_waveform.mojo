from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_INVALID_ARGS
from miniaudio_handles import MiniAudioWaveformHandle
from miniaudio_result_utils import format_result_error

comptime MMJ_WAVEFORM_TYPE_SINE = UInt32(0)
comptime MMJ_WAVEFORM_TYPE_SQUARE = UInt32(1)
comptime MMJ_WAVEFORM_TYPE_TRIANGLE = UInt32(2)
comptime MMJ_WAVEFORM_TYPE_SAWTOOTH = UInt32(3)


def run_waveform_sine_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.waveform_sine_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "waveform sine smoke failed", result))

    print("waveform sine smoke ok")


def run_waveform_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.waveform_invalid_args_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "waveform invalid-args smoke failed", result))

    print("waveform invalid-args smoke ok")


def run_waveform_handle_invalid_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var waveform = MiniAudioWaveformHandle(bridge)

    try:
        var result = bridge.waveform_set_frequency(waveform.raw, 0.0)
        if result != MA_INVALID_ARGS:
            raise Error(
                "waveform handle invalid smoke: expected MA_INVALID_ARGS from set_frequency on uninitialized handle, got: "
                + String(result)
            )
    finally:
        waveform.close(bridge)

    print("waveform handle invalid smoke ok")
