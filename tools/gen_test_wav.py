#!/usr/bin/env python3
import math
import struct
import wave
from pathlib import Path


def main() -> None:
    out_path = Path("build/test_assets/sine_440_stereo.wav")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    sample_rate = 48_000
    duration_seconds = 1.0
    channels = 2
    frequency_hz = 440.0
    amplitude = 0.2

    total_frames = int(sample_rate * duration_seconds)

    with wave.open(str(out_path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for i in range(total_frames):
            sample = int(amplitude * 32767.0 * math.sin(2.0 * math.pi * frequency_hz * i / sample_rate))
            frame = struct.pack("<hh", sample, sample)
            wav.writeframesraw(frame)

    print(f"generated {out_path} ({total_frames} frames @ {sample_rate}Hz)")


if __name__ == "__main__":
    main()
