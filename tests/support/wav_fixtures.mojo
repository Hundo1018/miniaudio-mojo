"""Deterministic, hardware-free test fixtures.

`embedded_wav_stereo_2frames` is a minimal valid 52-byte PCM WAV: stereo,
8000 Hz, 16-bit, 2 frames of silence. Used to exercise the in-memory decoder
path without touching the filesystem or audio hardware.
"""


def embedded_wav_stereo_2frames() -> List[UInt8]:
    var data: List[UInt8] = [
        82, 73, 70, 70, 44, 0, 0, 0,        # "RIFF", chunk size 44
        87, 65, 86, 69, 102, 109, 116, 32,  # "WAVE", "fmt "
        16, 0, 0, 0, 1, 0, 2, 0,            # fmt size 16, PCM, 2 channels
        64, 31, 0, 0, 0, 125, 0, 0,         # 8000 Hz, byte rate 32000
        4, 0, 16, 0, 100, 97, 116, 97,      # block align 4, 16 bits, "data"
        8, 0, 0, 0, 0, 0, 0, 0,             # data size 8, samples...
        0, 0, 0, 0,                          # ...frame 2 (silence)
    ]
    return data^
