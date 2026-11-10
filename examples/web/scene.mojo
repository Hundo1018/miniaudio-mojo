"""The audio scene behind the browser example: an offline engine mixing a decoded
clip with a procedural tone written in Mojo.

Everything on the render path is deterministic: the clip is decoded from bytes
(no file system), the tone is a `UserNode` driven by an integer phase
accumulator (no sin/cos), and every sound skips spatialization and pitch. So the
same frames come out natively and in WebAssembly (`pixi run -e wasm test-wasm`
compares them byte for byte).

Sound effects: register clips once (`add_clip` from an encoded file image,
`add_clip_pcm` from samples), then `play(clip_id, gain)` starts a one-shot voice.
Voices overlap, the same clip included; with all `MAX_VOICES` busy the oldest
voice is taken over.
"""

from std.memory import ArcPointer

from miniaudio import MaLib, MaError, MaResult, Engine
from miniaudio.data_source import DataSource
from miniaudio.decode_util import decode_memory
from miniaudio.node import NodeGraph, EndpointNode, UserNode
from miniaudio.processor import NodeProcessor
from miniaudio.sound import Sound, SOUND_FLAG_NO_SPATIALIZATION, SOUND_FLAG_NO_PITCH

comptime CHANNELS: UInt32 = 2
comptime MAX_VOICES = 8


struct Tone(NodeProcessor):
    """A triangle wave from a 32-bit phase accumulator: exact integer steps, so
    every platform produces the same samples."""

    var phase: UInt32
    var step: UInt32
    var gain: Float32

    def __init__(out self):
        self.phase = 0
        self.step = 0
        self.gain = 0

    def set(mut self, frequency_hz: Float32, gain: Float32, sample_rate: UInt32):
        self.step = UInt32(Float64(frequency_hz) * 4294967296.0 / Float64(sample_rate))
        self.gain = gain

    def process(
        mut self,
        input: Span[Float32, ImmutAnyOrigin],
        output: Span[Float32, MutAnyOrigin],
        frame_count: Int,
        channels: Int,
    ):
        for i in range(frame_count):
            var p = Int(self.phase >> 16)  # 0 .. 65535
            var tri = p if p < 32768 else 65535 - p  # 0 .. 32767 .. 0
            var v = (Float32(tri) / 16384.0 - 1.0) * self.gain
            self.phase += self.step
            for c in range(channels):
                output[i * channels + c] = v


struct Scene(Movable):
    var lib: ArcPointer[MaLib]
    var engine: ArcPointer[Engine]
    var tone: UserNode[Tone]
    var clip: List[Sound]  # zero or one; a List because Sound is not copyable
    var sample_rate: UInt32
    var clips: List[List[Float32]]  # registered clips: interleaved f32 at the engine's format
    var voices: List[Sound]  # one-shot voices, at most MAX_VOICES
    var voice_seq: List[Int]  # the play() count at which each voice started
    var plays: Int

    def __init__(out self, sample_rate: UInt32) raises MaError:
        self.lib = ArcPointer(MaLib.default())
        self.engine = ArcPointer(Engine.create_offline(self.lib, channels=CHANNELS, sample_rate=sample_rate))
        var graph = ArcPointer(NodeGraph.of_engine(self.engine))
        self.tone = UserNode.create(graph, Tone(), channels=CHANNELS)
        self.tone.attach_to(EndpointNode.of_engine(self.engine))
        self.clip = List[Sound]()
        self.sample_rate = sample_rate
        self.clips = List[List[Float32]]()
        self.voices = List[Sound]()
        self.voice_seq = List[Int]()
        self.plays = 0

    def set_tone(mut self, frequency_hz: Float32, gain: Float32) raises MaError:
        self.tone.processor().set(frequency_hz, gain, self.sample_rate)

    def load_clip(mut self, bytes: List[UInt8]) raises MaError:
        """Decode an encoded file image (WAV / FLAC / MP3) at the engine's format
        and start playing it once; replaces the previous clip."""
        var decoded = decode_memory(self.lib, bytes, channels=CHANNELS, sample_rate=self.sample_rate)
        var source = ArcPointer(
            DataSource.from_frames(self.lib, decoded.samples_f32(), channels=CHANNELS, sample_rate=self.sample_rate)
        )
        var sound = Sound.from_data_source(
            self.engine, source, flags=SOUND_FLAG_NO_SPATIALIZATION | SOUND_FLAG_NO_PITCH
        )
        sound.start()
        self.clip.clear()
        self.clip.append(sound^)

    def add_clip_pcm(mut self, samples: List[Float32]) raises MaError -> Int:
        """Register interleaved stereo f32 samples at the scene's sample rate; returns the clip id."""
        if len(samples) == 0 or len(samples) % Int(CHANNELS) != 0:
            raise MaError(MaResult.INVALID_ARGS, "clip samples must be a non-empty whole number of stereo frames")
        self.clips.append(samples.copy())
        return len(self.clips) - 1

    def add_clip(mut self, bytes: List[UInt8]) raises MaError -> Int:
        """Decode an encoded file image (WAV / FLAC / MP3) and register it; returns the clip id."""
        var decoded = decode_memory(self.lib, bytes, channels=CHANNELS, sample_rate=self.sample_rate)
        return self.add_clip_pcm(decoded.samples_f32())

    def clip_count(self) -> Int:
        return len(self.clips)

    def active_voices(self) -> Int:
        var n = 0
        for i in range(len(self.voices)):
            if self.voices[i].is_playing():
                n += 1
        return n

    def play(mut self, clip_id: Int, gain: Float32 = 1.0) raises MaError:
        """Start a one-shot voice for a registered clip. Each voice has its own read position, so a clip can
        overlap itself. A finished voice's slot is reused first; with none free the oldest voice is replaced."""
        if clip_id < 0 or clip_id >= len(self.clips):
            raise MaError(MaResult.INVALID_ARGS, "unknown clip id")
        var source = ArcPointer(
            DataSource.from_frames(self.lib, self.clips[clip_id], channels=CHANNELS, sample_rate=self.sample_rate)
        )
        var sound = Sound.from_data_source(
            self.engine, source, flags=SOUND_FLAG_NO_SPATIALIZATION | SOUND_FLAG_NO_PITCH
        )
        sound.set_volume(gain)
        sound.start()
        self.plays += 1
        var slot = -1
        for i in range(len(self.voices)):
            if not self.voices[i].is_playing():
                slot = i
                break
        if slot < 0 and len(self.voices) < MAX_VOICES:
            self.voices.append(sound^)
            self.voice_seq.append(self.plays)
            return
        if slot < 0:
            slot = 0
            for i in range(1, len(self.voices)):
                if self.voice_seq[i] < self.voice_seq[slot]:
                    slot = i
        swap(self.voices[slot], sound)
        self.voice_seq[slot] = self.plays
        _ = sound^

    def render(mut self, mut out: List[Float32], frames: UInt64) raises MaError:
        self.engine[].render(out, frames)
        _ = self.engine[].process_jobs()


def render_scene(clip: List[UInt8], frames: Int, block: Int = 128) raises MaError -> List[Float32]:
    """The fixed scene the parity test renders: a 220 Hz tone at 0.25 plus `clip`,
    pulled `block` frames at a time as an AudioWorklet would."""
    var scene = Scene(48000)
    scene.set_tone(220.0, 0.25)
    scene.load_clip(clip)
    var all = List[Float32](capacity=frames * Int(CHANNELS))
    var buf = List[Float32]()
    var done = 0
    while done < frames:
        var n = min(block, frames - done)
        scene.render(buf, UInt64(n))
        for x in buf:
            all.append(x)
        done += n
    return all^
