"""Play an audio file through the default playback device.

    pixi run play                      # plays build/test_assets/sine_440_stereo.wav
    pixi run play -- path/to/file.mp3  # WAV, FLAC or MP3

Set MINIAUDIO_NULL_BACKEND=1 to run without an audio device (nothing is heard;
the sound still advances on the engine's clock).
"""

from std.memory import ArcPointer
from std.os.env import getenv
from std.sys import argv
from std.time import sleep

from miniaudio import MaLib, MaResult, MaError
from miniaudio.engine import Engine
from miniaudio.sound import Sound

comptime DEFAULT_FILE = "build/test_assets/sine_440_stereo.wav"
comptime TIMEOUT_SECONDS = 30.0


def play(path: String, use_null_backend: Bool) raises MaError:
    var lib = ArcPointer(MaLib.default())
    var engine = ArcPointer(Engine.create(lib, use_null_backend=use_null_backend))
    var sound = Sound.from_file(engine, path)
    print("playing", path, "(", sound.length_in_seconds(), "s )")
    sound.start()
    var waited = 0.0
    while not sound.at_end() and waited < TIMEOUT_SECONDS:
        sleep(0.05)
        waited += 0.05
    print("done at", sound.cursor_in_seconds(), "s")


def main() raises:
    var args = argv()
    var path = String(args[1]) if len(args) > 1 else String(DEFAULT_FILE)
    try:
        play(path, getenv("MINIAUDIO_NULL_BACKEND") == "1")
    except e:
        # MaError carries the miniaudio result, so the cause can be matched on.
        match e.result:
            case .DOES_NOT_EXIST:
                print("no such file (or shim not built: run `pixi run build-shim`):", e)
            case .NO_BACKEND | .NO_DEVICE | .FAILED_TO_INIT_BACKEND:
                print("no playback device; retry with MINIAUDIO_NULL_BACKEND=1:", e)
            case _:
                print("playback failed:", e)
