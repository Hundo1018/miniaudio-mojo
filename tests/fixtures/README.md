# Test fixtures

Binary audio fixtures for the `flac` and `mp3` binding tests (and the FLAC/MP3
halves of `decode_util`). miniaudio can only *decode* these formats, so they are
generated once with external tools and committed. **Tests never need ffmpeg,
lame or sox at run time**; they open these files by repo-relative path
(`./tests/fixtures/...`, tests run from the repo root).

The WAV fixture is not stored here: `pixi run gen-test-wav` writes
`build/test_assets/sine_440_stereo.wav` (1 s, 48 kHz, stereo, 16-bit, 440 Hz,
amplitude 0.2) and the `test-wav` / `test-decode-util` tasks run it first.

| File | Size | Content |
|---|---|---|
| `sine_440_stereo_44100.flac` | 11800 B | 11025 frames (0.25 s), 44.1 kHz, stereo, 16-bit, 440 Hz sine, amplitude 0.5, lossless |
| `sine_440_stereo_44100.mp3`  |  2526 B | same audio, 64 kbps CBR; carries a Xing/LAME header (encoder delay 1105 frames) |

SHA-256:

```
01eeabd460b0dea2d948bbd51cb5026be4a22183cd1173cb6ec72bc5bde834e8  sine_440_stereo_44100.flac
769f140d19ef02bb288d1cc22b288ebf6438c3f75c95ce8b34b785e73bd30235  sine_440_stereo_44100.mp3
```

## Regenerating

The commands below are exactly what produced the committed files (ffmpeg 6.1.1,
libmp3lame; bit-exact flags make the output reproducible, so re-running them
must give the same checksums). Run from any scratch directory:

```sh
# 1. Source PCM: 11025 frames of a 440 Hz sine, amplitude 0.5, 16-bit stereo
#    (identical channels) at 44.1 kHz. Python stdlib only.
python3 - src.wav <<'PY'
import math, struct, sys, wave
rate, frames, amp, hz = 44100, 11025, 0.5, 440.0
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(rate)
    for i in range(frames):
        s = int(amp * 32767.0 * math.sin(2.0 * math.pi * hz * i / rate))
        w.writeframesraw(struct.pack("<hh", s, s))
PY

# 2. FLAC (lossless).
ffmpeg -hide_banner -loglevel error -y -i src.wav -map_metadata -1 \
    -fflags +bitexact -flags:a +bitexact -c:a flac -compression_level 8 \
    sine_440_stereo_44100.flac

# 3. MP3 (64 kbps CBR, ffmpeg writes the Xing/LAME header by default).
ffmpeg -hide_banner -loglevel error -y -i src.wav -map_metadata -1 \
    -fflags +bitexact -flags:a +bitexact -c:a libmp3lame -b:a 64k -ac 2 \
    sine_440_stereo_44100.mp3

sha256sum sine_440_stereo_44100.*
```

Then copy the two outputs into this directory.

## Things the tests rely on

- The FLAC decodes to exactly the Python generator's 16-bit samples
  (`int(0.5 * 32767 * sin(2π · 440 · i / 44100))`).
- The MP3 *must* keep its Xing/LAME header: the tests pin that miniaudio's
  dr_mp3 then reports the gapless length (11025 frames; delay 1105 and the end
  padding are trimmed). Encoding with `-write_xing 0` would give a header-less
  stream that decodes to 12672 frames (11 x 1152) and change the pinned values.
