from miniaudio import run_playback_smoke
from miniaudio_context import run_context_smoke
from miniaudio_decoder import run_decoder_smoke
from std.os.env import getenv


def main() raises:
    run_playback_smoke()

    var context_smoke = getenv("MINIAUDIO_CONTEXT_SMOKE")
    if context_smoke != "":
        print("Running context smoke")
        run_context_smoke()

    var decoder_file = getenv("MINIAUDIO_DECODER_FILE")
    if decoder_file != "":
        print("Running decoder smoke for:", decoder_file)
        run_decoder_smoke(decoder_file)
