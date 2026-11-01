"""The audio scene behind the browser example: an offline engine mixing a decoded
clip with a procedural tone written in Mojo.

Everything on the render path is deterministic: the clip is decoded from bytes
(no file system), the tone is a `UserNode` driven by an integer phase
accumulator (no sin/cos), and both sounds skip spatialization and pitch. So the
same frames come out natively and in WebAssembly (`pixi run -e wasm test-wasm`
compares them byte for byte).
"""

from std.memory import ArcPointer

from miniaudio import MaLib, MaError, MaResult, Engine
from miniaudio.data_source import DataSource
from miniaudio.decode_util import decode_memory
from miniaudio.node import NodeGraph, EndpointNode, UserNode
from miniaudio.processor import NodeProcessor
from miniaudio.sound import Sound, SOUND_FLAG_NO_SPATIALIZATION, SOUND_FLAG_NO_PITCH

comptime CHANNELS: UInt32 = 2


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

    def __init__(out self, sample_rate: UInt32) raises MaError:
        self.lib = ArcPointer(MaLib.default())
        self.engine = ArcPointer(Engine.create_offline(self.lib, channels=CHANNELS, sample_rate=sample_rate))
        var graph = ArcPointer(NodeGraph.of_engine(self.engine))
        self.tone = UserNode.create(graph, Tone(), channels=CHANNELS)
        self.tone.attach_to(EndpointNode.of_engine(self.engine))
        self.clip = List[Sound]()
        self.sample_rate = sample_rate

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
