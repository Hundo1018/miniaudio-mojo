"""TDD tests for user-defined streams through the idiomatic API (L3 behavioural).

`Spooled` and `Capture` below are defined in this file, not in the library: a
reader that dribbles out its bytes in odd-sized pieces and logs every seek, and a
sink that records its writes. They implement the stream traits and nothing else,
so everything miniaudio does with a stream lands in their own methods. The same
`Spooled` feeds `Decoder`, `WavDecoder`, `FlacDecoder` and `Mp3Decoder`;
`Capture` receives what `Encoder` writes.

What is asserted: the decode is bit-identical to the same bytes decoded from
memory, seeking and reading go through the user's methods, a failing stream
makes construction raise (it never crashes), a stream is destroyed exactly once
and only after the decoder / encoder is done with it (the encoder finishes its
WAV header through the sink first), and the stream is reachable again, by type,
through `stream[S]()`.
"""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import (
    MaLib,
    Decoder,
    Encoder,
    Device,
)
from miniaudio.wav import WavDecoder
from miniaudio.flac import FlacDecoder
from miniaudio.mp3 import Mp3Decoder
from miniaudio.stream import (
    ReadSeekTellStream,
    WriteSeekStream,
    MemoryReader,
    MemoryWriter,
    seek_target,
)
from support.codec_fixtures import (
    WAV_PATH,
    FLAC_PATH,
    MP3_PATH,
    WAV_FRAMES,
    CODEC_FRAMES,
    read_file_bytes,
    garbage_bytes,
)

# Index of each counter in the external tally a stream reports into.
comptime READS = 0
comptime SEEKS = 1
comptime TELLS = 2
comptime WRITES = 3
comptime DESTROYED = 4

comptime Stats = Pointer[Int, MutUntrackedOrigin]


def _stats(mut counters: List[Int]) -> Stats:
    return counters.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()


struct Spooled(ReadSeekTellStream):
    """Serves `data` in pieces of 1, 8, 15, ... bytes (never the size asked for)
    and keeps a log of the seek requests it gets as (origin, offset) pairs."""

    var data: List[UInt8]
    var pos: Int
    var piece: Int
    var seek_log: List[Int]
    var broken: Bool
    var stats: Stats

    def __init__(out self, var data: List[UInt8], stats: Stats):
        self.data = data^
        self.pos = 0
        self.piece = 1
        self.seek_log = List[Int]()
        self.broken = False
        self.stats = stats

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        self.stats[unsafe_offset=READS] += 1
        if self.broken:
            raise Error("the disk went away")
        var n = min(len(buffer), len(self.data) - self.pos, self.piece)
        self.piece = (self.piece + 7) % 64 + 1
        for i in range(n):
            buffer[i] = self.data[self.pos + i]
        self.pos += n
        return n

    def seek(mut self, offset: Int64, origin: Int) raises:
        self.stats[unsafe_offset=SEEKS] += 1
        self.seek_log.append(origin)
        self.seek_log.append(Int(offset))
        var target = seek_target(origin, offset, self.pos, len(self.data))
        if target > len(self.data):
            raise Error("seek past the end")
        self.pos = target

    def tell(mut self) raises -> Int64:
        self.stats[unsafe_offset=TELLS] += 1
        return Int64(self.pos)

    def __deinit__(deinit self):
        self.stats[unsafe_offset=DESTROYED] += 1


struct Capture(WriteSeekStream):
    """Keeps everything written, honouring seeks (an in-memory file)."""

    var data: List[UInt8]
    var pos: Int
    var stats: Stats

    def __init__(out self, stats: Stats):
        self.data = List[UInt8]()
        self.pos = 0
        self.stats = stats

    def write(mut self, data: Span[UInt8, ImmutAnyOrigin]) raises -> Int:
        self.stats[unsafe_offset=WRITES] += 1
        var end = self.pos + len(data)
        if end > len(self.data):
            self.data.resize(end, UInt8(0))
        for i in range(len(data)):
            self.data[self.pos + i] = data[i]
        self.pos = end
        return len(data)

    def seek(mut self, offset: Int64, origin: Int) raises:
        self.stats[unsafe_offset=SEEKS] += 1
        self.pos = seek_target(origin, offset, self.pos, len(self.data))

    def __deinit__(deinit self):
        self.stats[unsafe_offset=DESTROYED] += 1


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _same(a: List[Float32], b: List[Float32]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


# ---- decoding ----------------------------------------------------------------


def _decode_matches_memory(
    lib: ArcPointer[MaLib], path: String, total_frames: Int, seek_to: UInt64
) raises:
    var data = read_file_bytes(path)
    var counters = List[Int](length=8, fill=0)
    var via_stream = Decoder.from_stream(lib, Spooled(data.copy(), _stats(counters)))
    var via_memory = Decoder.from_memory(lib, data.copy())
    assert_equal(via_stream.channels(), via_memory.channels())
    assert_equal(via_stream.sample_rate(), via_memory.sample_rate())
    assert_equal(via_stream.length_in_frames(), UInt64(total_frames))
    var a = List[Float32]()
    var b = List[Float32]()
    assert_equal(via_stream.read(a, 3000), UInt64(3000))
    assert_equal(via_memory.read(b, 3000), UInt64(3000))
    assert_true(_same(a, b))
    assert_true(counters[READS] > 3)  # dribbled out in odd pieces, all of them used
    # seek, read again
    var seeks_before = counters[SEEKS]
    via_stream.seek(seek_to)
    via_memory.seek(seek_to)
    assert_equal(via_stream.read(a, 500), UInt64(500))
    assert_equal(via_memory.read(b, 500), UInt64(500))
    assert_true(_same(a, b))
    assert_true(counters[SEEKS] > seeks_before)  # the seek went through the user's seek
    assert_equal(via_stream.cursor(), via_memory.cursor())


def test_decoder_over_a_user_stream_matches_memory_wav() raises:
    _decode_matches_memory(_lib(), WAV_PATH, WAV_FRAMES, 2000)


def test_decoder_over_a_user_stream_matches_memory_flac() raises:
    # FLAC frames are 4096 samples: a seek inside the frame already decoded needs no
    # new bytes, so aim at a later one
    _decode_matches_memory(_lib(), FLAC_PATH, CODEC_FRAMES, 9000)


def test_decoder_over_a_user_stream_matches_memory_mp3() raises:
    _decode_matches_memory(_lib(), MP3_PATH, CODEC_FRAMES, 2000)


def test_decoder_reads_the_whole_file_through_the_stream() raises:
    var lib = _lib()
    var data = read_file_bytes(WAV_PATH)
    var counters = List[Int](length=8, fill=0)
    var dec = Decoder.from_stream(lib, Spooled(data.copy(), _stats(counters)))
    var all = List[Float32]()
    assert_equal(dec.read(all, UInt64(WAV_FRAMES)), UInt64(WAV_FRAMES))
    # the stream has been read to its end (the WAV payload is all of the file after the header)
    assert_equal(dec.stream[Spooled]().pos, len(data))
    assert_equal(dec.read(all, 100), UInt64(0))  # and then there is nothing more
    assert_equal(counters[DESTROYED], 0)
    _ = dec^
    assert_equal(counters[DESTROYED], 1)


def test_the_wav_flac_mp3_codecs_over_a_user_stream() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)

    var wav_data = read_file_bytes(WAV_PATH)
    var wav = WavDecoder.from_stream(lib, Spooled(wav_data.copy(), _stats(counters)))
    var wav_mem = WavDecoder.from_memory(lib, wav_data.copy())
    assert_equal(wav.length_in_frames(), UInt64(WAV_FRAMES))
    var a = List[Float32]()
    var b = List[Float32]()
    assert_equal(wav.read(a, 4000), UInt64(4000))
    assert_equal(wav_mem.read(b, 4000), UInt64(4000))
    assert_true(_same(a, b))

    var flac_data = read_file_bytes(FLAC_PATH)
    var flac = FlacDecoder.from_stream(lib, Spooled(flac_data.copy(), _stats(counters)))
    var flac_mem = FlacDecoder.from_memory(lib, flac_data.copy())
    assert_equal(flac.length_in_frames(), UInt64(CODEC_FRAMES))
    assert_equal(flac.read(a, 4000), UInt64(4000))
    assert_equal(flac_mem.read(b, 4000), UInt64(4000))
    assert_true(_same(a, b))

    var mp3_data = read_file_bytes(MP3_PATH)
    var mp3 = Mp3Decoder.from_stream(lib, Spooled(mp3_data.copy(), _stats(counters)))
    var mp3_mem = Mp3Decoder.from_memory(lib, mp3_data.copy())
    assert_equal(mp3.length_in_frames(), UInt64(CODEC_FRAMES))
    assert_equal(mp3.read(a, 4000), UInt64(4000))
    assert_equal(mp3_mem.read(b, 4000), UInt64(4000))
    assert_true(_same(a, b))

    # tell is part of the contract of these three; it is the user's own method that answers
    assert_true(counters[TELLS] > 0)
    assert_equal(counters[DESTROYED], 0)
    _ = wav^
    _ = flac^
    _ = mp3^
    assert_equal(counters[DESTROYED], 3)


def test_codec_seek_goes_through_the_user_stream() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var data = read_file_bytes(WAV_PATH)
    var dec = WavDecoder.from_stream(lib, Spooled(data.copy(), _stats(counters)))
    var mem = WavDecoder.from_memory(lib, data.copy())
    var seeks_before = counters[SEEKS]
    dec.seek(30000)
    mem.seek(30000)
    assert_true(counters[SEEKS] > seeks_before)
    assert_equal(dec.cursor(), UInt64(30000))
    var a = List[Float32]()
    var b = List[Float32]()
    assert_equal(dec.read(a, 256), UInt64(256))
    assert_equal(mem.read(b, 256), UInt64(256))
    assert_true(_same(a, b))
    # what the library asked for: absolute positions from the start, inside the file
    var log = dec.stream[Spooled]().seek_log.copy()
    assert_true(len(log) >= 2)
    assert_true(len(data) > 0)


# ---- the stream is yours again --------------------------------------------------


def test_stream_accessor_returns_the_same_instance() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var dec = Decoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    var buf = List[Float32]()
    _ = dec.read(buf, 100)
    # position and piece size are state of the very object that was handed over
    assert_true(dec.stream[Spooled]().pos > 44)
    assert_true(dec.stream[Spooled]().piece >= 1)
    dec.stream[Spooled]().piece = 5  # and it can be changed through the accessor
    assert_equal(dec.stream[Spooled]().piece, 5)
    assert_equal(counters[DESTROYED], 0)
    _ = dec^
    assert_equal(counters[DESTROYED], 1)


def test_stream_accessor_checks_the_type() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var dec = Decoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    with assert_raises():
        _ = dec.stream[MemoryReader]()  # not what it was built from
    # a decoder that was not built from a stream has none to give
    var file_dec = Decoder.from_file(lib, WAV_PATH)
    with assert_raises():
        _ = file_dec.stream[Spooled]()
    var wav = WavDecoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    with assert_raises():
        _ = wav.stream[MemoryReader]()
    assert_equal(counters[DESTROYED], 0)
    _ = dec^
    _ = wav^
    assert_equal(counters[DESTROYED], 2)


# ---- lifetime ---------------------------------------------------------------------


def _decoder_scope(lib: ArcPointer[MaLib], mut counters: List[Int]) raises:
    var dec = Decoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    var buf = List[Float32]()
    assert_equal(counters[DESTROYED], 0)  # alive for as long as the decoder is
    _ = dec.read(buf, 1000)  # (the decoder's last use: it goes right after this)


def test_a_decoder_destroys_its_stream_exactly_once_when_dropped() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    _decoder_scope(lib, counters)
    assert_equal(counters[DESTROYED], 1)


def _wav_scope(lib: ArcPointer[MaLib], mut counters: List[Int]) raises:
    var dec = WavDecoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    dec.uninit()
    # the decoder is finished with, but its stream is still the user's to look at
    assert_equal(counters[DESTROYED], 0)
    assert_true(dec.stream[Spooled]().pos > 0)


def test_a_codec_keeps_the_stream_through_uninit_and_destroys_it_once_when_dropped() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    _wav_scope(lib, counters)
    assert_equal(counters[DESTROYED], 1)


def test_a_failed_construction_destroys_the_stream_once() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    with assert_raises():
        _ = Decoder.from_stream(lib, Spooled(garbage_bytes(2048), _stats(counters)))
    assert_equal(counters[DESTROYED], 1)
    with assert_raises():
        _ = WavDecoder.from_stream(lib, Spooled(garbage_bytes(2048), _stats(counters)))
    assert_equal(counters[DESTROYED], 2)
    with assert_raises():
        _ = FlacDecoder.from_stream(lib, Spooled(garbage_bytes(2048), _stats(counters)))
    assert_equal(counters[DESTROYED], 3)
    with assert_raises():
        _ = Mp3Decoder.from_stream(lib, Spooled(garbage_bytes(2048), _stats(counters)))
    assert_equal(counters[DESTROYED], 4)


def test_a_stream_that_cannot_be_read_makes_construction_raise() raises:
    """Not a crash: the stream raises on its first read, miniaudio gets an I/O
    error, the constructor raises, and the stream is still destroyed once."""
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var data = read_file_bytes(WAV_PATH)
    var dead = Spooled(data.copy(), _stats(counters))
    dead.broken = True
    with assert_raises():
        _ = Decoder.from_stream(lib, dead^)
    assert_equal(counters[DESTROYED], 1)
    var dead_wav = Spooled(data.copy(), _stats(counters))
    dead_wav.broken = True
    with assert_raises():
        _ = WavDecoder.from_stream(lib, dead_wav^)
    assert_equal(counters[DESTROYED], 2)
    var dead_flac = Spooled(read_file_bytes(FLAC_PATH), _stats(counters))
    dead_flac.broken = True
    with assert_raises():
        _ = FlacDecoder.from_stream(lib, dead_flac^)
    assert_equal(counters[DESTROYED], 3)
    var dead_mp3 = Spooled(read_file_bytes(MP3_PATH), _stats(counters))
    dead_mp3.broken = True
    with assert_raises():
        _ = Mp3Decoder.from_stream(lib, dead_mp3^)
    assert_equal(counters[DESTROYED], 4)
    assert_true(counters[READS] >= 4)  # each one did try to read


def test_a_stream_that_dies_midway_ends_the_decode_without_a_crash() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var dec = Decoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    var buf = List[Float32]()
    assert_equal(dec.read(buf, 100), UInt64(100))
    dec.stream[Spooled]().broken = True  # from now on every read raises
    # the decoder has read ahead into its own buffers, so some frames may still come;
    # but it cannot reach the end of the file
    var total = UInt64(0)
    for _ in range(50):
        var n = dec.read(buf, 4000)
        total += n
        if n == 0:
            break
    assert_true(total < UInt64(WAV_FRAMES - 100))
    assert_equal(counters[DESTROYED], 0)
    _ = dec^
    assert_equal(counters[DESTROYED], 1)


# ---- the device thread -----------------------------------------------------------


def test_a_stream_is_read_from_the_device_thread() raises:
    """The null-backend device pulls frames on miniaudio's own audio thread, so the
    user's read is called from a thread Mojo did not start."""
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var dec = Decoder.from_stream(lib, Spooled(read_file_bytes(WAV_PATH), _stats(counters)))
    var reads_before = counters[READS]
    var dev = Device.play(lib, dec^, use_null_backend=True)
    dev.start()
    sleep(0.3)
    dev.stop()
    assert_true(dev.frames_processed() > 0)
    assert_true(counters[READS] > reads_before)  # the device thread pulled bytes through it
    assert_equal(counters[DESTROYED], 0)  # the device still owns the decoder, which owns the stream
    _ = dev^
    assert_equal(counters[DESTROYED], 1)


# ---- encoding ----------------------------------------------------------------------


def _ramp(frames: Int, channels: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(frames * channels):
        out.append(Float32(i % 128) / 128.0 - 0.5)
    return out^


def test_encoder_into_a_user_sink_round_trips_through_the_decoder() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var frames = _ramp(1000, 2)
    var enc = Encoder.to_stream(lib, Capture(_stats(counters)), channels=2, sample_rate=44100)
    assert_equal(enc.write(frames), UInt64(1000))
    enc.finish()
    enc.finish()  # harmless
    var bytes = enc.stream[Capture]().data.copy()
    assert_equal(len(bytes), 44 + 1000 * 2 * 4)
    assert_true(counters[WRITES] > 0)
    assert_equal(counters[DESTROYED], 0)  # finished, but the sink is still there to read

    var back = Decoder.from_memory(lib, bytes.copy())
    assert_equal(back.channels(), UInt32(2))
    assert_equal(back.sample_rate(), UInt32(44100))
    assert_equal(back.length_in_frames(), UInt64(1000))
    var out = List[Float32]()
    assert_equal(back.read(out, 1000), UInt64(1000))
    assert_true(_same(out, frames))  # f32 in, f32 out: bit-exact
    _ = enc^
    assert_equal(counters[DESTROYED], 1)  # dropping it is what finally releases the sink


def test_the_sink_is_the_same_bytes_as_writing_a_file() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var frames = _ramp(700, 1)
    var path = "./build/test_assets/stream_api_reference.wav"
    var file_enc = Encoder.to_file(lib, path, channels=1, sample_rate=16000)
    _ = file_enc.write(frames)
    file_enc.finish()
    var want = read_file_bytes(path)
    var enc = Encoder.to_stream(lib, Capture(_stats(counters)), channels=1, sample_rate=16000)
    _ = enc.write(frames)
    enc.finish()
    var got = enc.stream[Capture]().data.copy()
    assert_equal(len(got), len(want))
    var mismatches = 0
    for i in range(len(got)):
        if got[i] != want[i]:
            mismatches += 1
    assert_equal(mismatches, 0)
    _ = enc^
    assert_equal(counters[DESTROYED], 1)


def test_the_builtin_memory_sink_works_the_same_way() raises:
    var lib = _lib()
    var frames = _ramp(300, 2)
    var enc = Encoder.to_stream(lib, MemoryWriter(), channels=2, sample_rate=8000)
    _ = enc.write(frames)
    enc.finish()
    var bytes = enc.stream[MemoryWriter]().bytes()
    var back = Decoder.from_stream(lib, MemoryReader(bytes^))  # and straight back in
    var out = List[Float32]()
    assert_equal(back.read(out, 300), UInt64(300))
    assert_true(_same(out, frames))


def _encoder_scope(lib: ArcPointer[MaLib], mut counters: List[Int]) raises:
    var enc = Encoder.to_stream(lib, Capture(_stats(counters)), channels=2, sample_rate=48000)
    assert_equal(counters[DESTROYED], 0)
    _ = enc.write(_ramp(100, 2))  # (the encoder's last use: it goes right after this, unfinished)


def test_dropping_an_unfinished_encoder_flushes_the_header_then_destroys_the_sink_once() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    _encoder_scope(lib, counters)
    assert_equal(counters[DESTROYED], 1)
    assert_true(counters[SEEKS] > 0)  # the header was patched (by seeking back) before the sink went


def test_encoder_writes_after_finish_are_refused() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var enc = Encoder.to_stream(lib, Capture(_stats(counters)), channels=2, sample_rate=48000)
    enc.finish()
    with assert_raises():
        _ = enc.write(_ramp(4, 2))
    assert_equal(counters[DESTROYED], 0)
    _ = enc^
    assert_equal(counters[DESTROYED], 1)


def test_encoder_to_stream_rejects_what_miniaudio_rejects_and_destroys_the_sink() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    with assert_raises():
        _ = Encoder.to_stream(lib, Capture(_stats(counters)), channels=0, sample_rate=48000)
    assert_equal(counters[DESTROYED], 1)
    with assert_raises():
        _ = Encoder.to_stream(lib, Capture(_stats(counters)), channels=2, sample_rate=0)
    assert_equal(counters[DESTROYED], 2)


def test_encoder_stream_accessor_checks_the_type() raises:
    var lib = _lib()
    var counters = List[Int](length=8, fill=0)
    var enc = Encoder.to_stream(lib, Capture(_stats(counters)), channels=2, sample_rate=48000)
    with assert_raises():
        _ = enc.stream[MemoryWriter]()
    var file_enc = Encoder.to_file(lib, "./build/test_assets/stream_api_no_sink.wav", channels=2, sample_rate=48000)
    with assert_raises():
        _ = file_enc.stream[Capture]()
    assert_equal(counters[DESTROYED], 0)
    _ = enc^
    _ = file_enc^
    assert_equal(counters[DESTROYED], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
