"""Shared fixtures and signal checks for the wav / flac / mp3 / decode_util tests.

Fixtures
- WAV: build/test_assets/sine_440_stereo.wav, produced by `pixi run gen-test-wav`
  (tools/gen_test_wav.py): 1 s, 48 kHz, stereo, 16-bit PCM, 440 Hz, amplitude 0.2.
- FLAC / MP3: committed under tests/fixtures/ (see tests/fixtures/README.md):
  0.25 s, 44.1 kHz, stereo, 440 Hz sine of amplitude 0.5 (11025 frames),
  encoded once from Python-generated PCM. Tests never need ffmpeg / lame / sox
  at run time.

Paths are relative to the repo root (the pixi test tasks run from there).
"""

from std.math import sin, sqrt


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime FLAC_PATH = "./tests/fixtures/sine_440_stereo_44100.flac"
comptime MP3_PATH = "./tests/fixtures/sine_440_stereo_44100.mp3"
comptime MISSING_PATH = "/tmp/mmj-does-not-exist/nope.bin"

# Facts about the fixtures.
comptime WAV_FRAMES = 48000
comptime WAV_RATE = 48000
comptime CODEC_FRAMES = 11025  # FLAC / MP3 fixtures: 0.25 s at 44.1 kHz
comptime CODEC_RATE = 44100
comptime SINE_HZ = 440.0
comptime TWO_PI = 6.283185307179586

# The MP3 fixture's encoder delay (576 decoder delay + 529 LAME): dr_mp3 reads it from
# the LAME tag, trims it from the length and the audio, but miniaudio's *cursor* still
# counts it (see tests/test_mp3_binding.mojo).
comptime MP3_ENCODER_DELAY = 1105

# ma_result codes the tests assert beyond the ones in miniaudio.result.
comptime MA_ERROR = Int(-1)
comptime MA_INVALID_FILE = Int(-10)
comptime MA_NO_BACKEND = Int(-203)

# ma_channel codes.
comptime MA_CHANNEL_FRONT_LEFT = UInt8(2)
comptime MA_CHANNEL_FRONT_RIGHT = UInt8(3)


def read_file_bytes(path: String) raises -> List[UInt8]:
    var data: List[UInt8]
    with open(path, "r") as f:
        data = f.read_bytes()
    return data^


def garbage_bytes(n: Int) -> List[UInt8]:
    """Deterministic bytes that are not any audio container."""
    var out = List[UInt8]()
    for i in range(n):
        out.append(UInt8((i * 37 + 11) % 251))
    return out^


def channel_rms(buf: List[Float32], channels: Int, channel: Int) -> Float64:
    """Root-mean-square of one channel of an interleaved buffer."""
    var n = len(buf) // channels
    if n == 0:
        return 0.0
    var acc = Float64(0)
    for i in range(n):
        var s = Float64(buf[i * channels + channel])
        acc += s * s
    return sqrt(acc / Float64(n))


def rising_crossings(buf: List[Float32], channels: Int, channel: Int) -> Int:
    """Count negative-to-non-negative zero crossings: one per sine cycle."""
    var n = len(buf) // channels
    var count = 0
    var prev = Float32(0)
    for i in range(n):
        var s = buf[i * channels + channel]
        if i > 0 and prev < 0 and s >= 0:
            count += 1
        prev = s
    return count


def max_abs_diff(a: List[Float32], b: List[Float32]) -> Float32:
    """Largest |a[i] - b[i]| over the common prefix; use equal lengths."""
    var n = len(a)
    if len(b) < n:
        n = len(b)
    var m = Float32(0)
    for i in range(n):
        var d = a[i] - b[i]
        if d < 0:
            d = -d
        if d > m:
            m = d
    return m


def sine16(index: Int, sample_rate: Int, amplitude: Float64) -> Int:
    """The 16-bit PCM value the fixture generators wrote at frame `index`."""
    var v = amplitude * 32767.0 * sin(TWO_PI * SINE_HZ * Float64(index) / Float64(sample_rate))
    return Int(v)  # truncates toward zero, like Python's int()


def sine_f32(index: Int, sample_rate: Int, amplitude: Float64) -> Float32:
    """`sine16` as the f32 miniaudio converts it to (s16 / 32768)."""
    return Float32(Float64(sine16(index, sample_rate, amplitude)) / 32768.0)


def sine_rms_error(
    buf: List[Float32], channels: Int, channel: Int, sample_rate: Int, amplitude: Float64
) -> Float64:
    """RMS of (decoded - ideal sine) over the buffer, ideal sine starting at phase 0."""
    var n = len(buf) // channels
    if n == 0:
        return 0.0
    var acc = Float64(0)
    for i in range(n):
        var want = Float64(sine_f32(i, sample_rate, amplitude))
        var d = Float64(buf[i * channels + channel]) - want
        acc += d * d
    return sqrt(acc / Float64(n))
