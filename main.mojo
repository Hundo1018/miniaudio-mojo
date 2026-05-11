from miniaudio import run_playback_file_smoke, run_playback_smoke
from miniaudio_capture import run_capture_file_smoke, run_capture_smoke
from miniaudio_context import run_context_smoke
from miniaudio_decoder import run_decoder_read_smoke, run_decoder_smoke
from miniaudio_device import run_device_config_smoke, run_device_control_smoke, run_device_volume_smoke
from miniaudio_devices import run_devices_smoke
from miniaudio_duplex import run_duplex_control_smoke, run_duplex_smoke
from std.os.env import getenv


def main() raises:
    run_playback_smoke()

    var context_smoke = getenv("MINIAUDIO_CONTEXT_SMOKE")
    if context_smoke != "":
        print("Running context smoke")
        run_context_smoke()

    var capture_smoke = getenv("MINIAUDIO_CAPTURE_SMOKE")
    if capture_smoke != "":
        print("Running capture smoke")
        run_capture_smoke()

    var capture_file = getenv("MINIAUDIO_CAPTURE_FILE")
    if capture_file != "":
        print("Running capture file smoke for:", capture_file)
        run_capture_file_smoke(capture_file)

    var duplex_smoke = getenv("MINIAUDIO_DUPLEX_SMOKE")
    if duplex_smoke != "":
        print("Running duplex smoke")
        run_duplex_smoke()

    var duplex_control_smoke = getenv("MINIAUDIO_DUPLEX_CONTROL_SMOKE")
    if duplex_control_smoke != "":
        print("Running duplex control smoke")
        run_duplex_control_smoke()

    var devices_smoke = getenv("MINIAUDIO_DEVICES_SMOKE")
    if devices_smoke != "":
        print("Running devices smoke")
        run_devices_smoke()

    var device_control_smoke = getenv("MINIAUDIO_DEVICE_CONTROL_SMOKE")
    if device_control_smoke != "":
        print("Running device control smoke")
        run_device_control_smoke()

    var device_volume_smoke = getenv("MINIAUDIO_DEVICE_VOLUME_SMOKE")
    if device_volume_smoke != "":
        print("Running device volume smoke")
        run_device_volume_smoke()

    var device_config_smoke = getenv("MINIAUDIO_DEVICE_CONFIG_SMOKE")
    if device_config_smoke != "":
        print("Running device config smoke")
        run_device_config_smoke()

    var decoder_file = getenv("MINIAUDIO_DECODER_FILE")
    if decoder_file != "":
        print("Running decoder smoke for:", decoder_file)
        run_decoder_smoke(decoder_file)

    var decoder_read_file = getenv("MINIAUDIO_DECODER_READ_FILE")
    if decoder_read_file != "":
        print("Running decoder read smoke for:", decoder_read_file)
        run_decoder_read_smoke(decoder_read_file)

    var playback_file = getenv("MINIAUDIO_PLAYBACK_FILE")
    if playback_file != "":
        print("Running playback file smoke for:", playback_file)
        run_playback_file_smoke(playback_file)
