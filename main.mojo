from miniaudio import run_playback_smoke
from miniaudio_capture import run_capture_smoke
from miniaudio_context import run_context_smoke
from miniaudio_decoder import run_decoder_smoke
from miniaudio_devices import run_devices_smoke
from miniaudio_duplex import run_duplex_smoke
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

    var duplex_smoke = getenv("MINIAUDIO_DUPLEX_SMOKE")
    if duplex_smoke != "":
        print("Running duplex smoke")
        run_duplex_smoke()

    var devices_smoke = getenv("MINIAUDIO_DEVICES_SMOKE")
    if devices_smoke != "":
        print("Running devices smoke")
        run_devices_smoke()

    var decoder_file = getenv("MINIAUDIO_DECODER_FILE")
    if decoder_file != "":
        print("Running decoder smoke for:", decoder_file)
        run_decoder_smoke(decoder_file)
