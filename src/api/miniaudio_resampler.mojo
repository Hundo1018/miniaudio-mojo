from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioChannelConverterHandle, MiniAudioResamplerHandle
from miniaudio_result_utils import format_result_error

comptime MMJ_CHANNEL_MIX_MODE_RECTANGULAR = UInt32(0)


def run_resampler_linear_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.resampler_linear_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "resampler linear smoke failed", result))

    print("resampler linear smoke ok")


def run_resampler_invalid_rate_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.resampler_invalid_rate_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "resampler invalid-rate smoke failed", result))

    print("resampler invalid-rate smoke ok")


def run_resampler_expected_count_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resampler = MiniAudioResamplerHandle(bridge)

    try:
        resampler.init_linear_f32(bridge, 2, 44100, 48000)
        var expected = resampler.get_expected_output_frame_count(bridge, 64)
        if expected < 65:
            raise Error("resampler expected output frame count should increase for upsampling")
    finally:
        resampler.close(bridge)

    print("resampler expected-count smoke ok")


def run_channel_converter_stereo_to_mono_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.channel_converter_stereo_to_mono_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "channel converter stereo-to-mono smoke failed",
                result,
            )
        )

    print("channel converter stereo-to-mono smoke ok")


def run_channel_converter_invalid_channels_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.channel_converter_invalid_channels_smoke()
    if result != 0:
        raise Error(
            format_result_error(
                bridge,
                "channel converter invalid-channels smoke failed",
                result,
            )
        )

    print("channel converter invalid-channels smoke ok")


def run_channel_converter_init_mode_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var converter = MiniAudioChannelConverterHandle(bridge)

    try:
        converter.init_f32(bridge, 2, 1, MMJ_CHANNEL_MIX_MODE_RECTANGULAR)
    finally:
        converter.close(bridge)

    print("channel converter init-mode smoke ok")
