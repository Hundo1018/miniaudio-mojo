"""Tests for DataSource.from_user: a data source implemented in Mojo (UserDataSource).

`Counting` yields frame n = n / 1000 on both channels for 1000 frames, so every
read, seek and render is checked exactly.
"""

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_raises, TestSuite

from miniaudio import MaLib, Engine
from miniaudio.data_source import DataSource
from miniaudio.decoder import SAMPLE_FORMAT_F32
from miniaudio.processor import UserDataSource
from miniaudio.sound import Sound, SOUND_FLAG_NO_SPATIALIZATION, SOUND_FLAG_NO_PITCH

comptime TOTAL = 1000
comptime Counters = UnsafePointer[Int, MutUntrackedOrigin]


struct Counting(UserDataSource):
    var pos: Int
    var dropped: Counters

    def __init__(out self, dropped: Counters):
        self.pos = 0
        self.dropped = dropped

    def read(mut self, output: Span[Float32, MutAnyOrigin], frame_count: Int, channels: Int) -> Int:
        var n = min(frame_count, TOTAL - self.pos)
        for i in range(n):
            for c in range(channels):
                output[i * channels + c] = Float32(self.pos + i) / 1000.0
        self.pos += n
        return n

    def seek(mut self, frame: UInt64) -> Bool:
        if Int(frame) > TOTAL:
            return False
        self.pos = Int(frame)
        return True

    def length(mut self) -> UInt64:
        return UInt64(TOTAL)

    def __del__(deinit self):
        self.dropped[] += 1


struct Endless(UserDataSource):
    """No known length, never ends."""

    def __init__(out self):
        pass

    def read(mut self, output: Span[Float32, MutAnyOrigin], frame_count: Int, channels: Int) -> Int:
        for i in range(frame_count * channels):
            output[i] = 0.5
        return frame_count

    def seek(mut self, frame: UInt64) -> Bool:
        return frame == 0

    def length(mut self) -> UInt64:
        return 0


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ptr(mut dropped: List[Int]) -> Counters:
    return dropped.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()


def test_reads_seeks_and_reports_its_format() raises:
    var dropped = List[Int](length=1, fill=0)
    var src = DataSource.from_user(_lib(), Counting(_ptr(dropped)), channels=2, sample_rate=44100)
    var f = src.data_format()
    assert_equal(f.format, SAMPLE_FORMAT_F32)
    assert_equal(f.channels, UInt32(2))
    assert_equal(f.sample_rate, UInt32(44100))
    assert_equal(src.length_frames(), UInt64(TOTAL))
    var a = src.read_frames(10)
    assert_equal(len(a), 20)
    assert_equal(a[18], Float32(0.009))
    assert_equal(src.cursor_frames(), UInt64(10))
    src.seek_to_frame(990)
    assert_equal(src.cursor_frames(), UInt64(990))
    var tail = src.read_frames(50)  # only 10 left: a short read, the end
    assert_equal(len(tail), 20)
    assert_equal(tail[0], Float32(0.99))
    assert_equal(len(src.read_frames(5)), 0)
    _ = src^
    assert_equal(dropped[0], 1)


def test_a_bad_seek_is_refused() raises:
    var dropped = List[Int](length=1, fill=0)
    var src = DataSource.from_user(_lib(), Counting(_ptr(dropped)))
    with assert_raises(contains="MA_BAD_SEEK"):
        src.seek_to_frame(TOTAL + 1)
    _ = src^
    assert_equal(dropped[0], 1)


def test_the_source_is_reachable_by_type() raises:
    var dropped = List[Int](length=1, fill=0)
    var src = DataSource.from_user(_lib(), Counting(_ptr(dropped)))
    _ = src.read_frames(7)
    assert_equal(src.user[Counting]().pos, 7)
    src.user[Counting]().pos = 500  # state changed through the accessor is what reads see
    assert_equal(src.read_frames(1)[0], Float32(0.5))
    with assert_raises(contains="no user source"):
        _ = src.user[Endless]()
    var buffer = DataSource.from_frames(_lib(), [Float32(0)], channels=1)
    with assert_raises(contains="no user source"):
        _ = buffer.user[Counting]()
    _ = src^
    assert_equal(dropped[0], 1)


def test_unknown_length_plays_on() raises:
    var src = DataSource.from_user(_lib(), Endless(), channels=1)
    assert_equal(len(src.read_frames(4096)), 4096)
    with assert_raises():
        _ = src.length_frames()  # MA_NOT_IMPLEMENTED: no length to report


def test_a_sound_plays_a_user_source_in_an_offline_engine() raises:
    var dropped = List[Int](length=1, fill=0)
    var lib = _lib()
    var engine = ArcPointer(Engine.create_offline(lib, channels=2, sample_rate=48000))
    var src = ArcPointer(DataSource.from_user(lib, Counting(_ptr(dropped)), channels=2, sample_rate=48000))
    # NO_PITCH: the pitch resampler would otherwise delay the output by a frame.
    var snd = Sound.from_data_source(engine, src, flags=SOUND_FLAG_NO_SPATIALIZATION | SOUND_FLAG_NO_PITCH)
    snd.start()
    var out = List[Float32]()
    engine[].render(out, 1200)  # 1000 frames of data, then silence
    for n in range(TOTAL):
        assert_equal(out[2 * n], Float32(n) / 1000.0)
    assert_equal(out[2 * TOTAL + 2], Float32(0))
    assert_true(snd.at_end())
    _ = snd^
    _ = src^
    assert_equal(dropped[0], 1)


def test_bad_arguments_destroy_the_source_once() raises:
    var dropped = List[Int](length=1, fill=0)
    with assert_raises(contains="MA_INVALID_ARGS"):
        _ = DataSource.from_user(_lib(), Counting(_ptr(dropped)), channels=0)
    with assert_raises(contains="MA_INVALID_ARGS"):
        _ = DataSource.from_user(_lib(), Counting(_ptr(dropped)), sample_rate=0)
    assert_equal(dropped[0], 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
