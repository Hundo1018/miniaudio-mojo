"""Behavioural tests for the idiomatic data source API (Layer 3).

These assert observable audio behaviour — that samples survive the round trip,
that seeking really rewinds, that a range restricts what can be read, and that
the source owns its samples — rather than re-checking raw result codes (that is
test_data_source_binding.mojo's job).
"""

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite

from miniaudio._lib import MaLib
from miniaudio.data_source import DataSource, DataSourceNode
from miniaudio.engine import Engine


comptime CHANNELS: UInt32 = 2
comptime SAMPLE_RATE: UInt32 = 48000
comptime FRAMES: Int = 480


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp() -> List[Float32]:
    """A strictly increasing ramp, so any offset is identifiable."""
    var buf = List[Float32]()
    buf.resize(FRAMES * Int(CHANNELS), Float32(0))
    for i in range(len(buf)):
        buf[i] = Float32(i)
    return buf^


def _source(lib: ArcPointer[MaLib]) raises -> DataSource:
    return DataSource.from_frames(
        lib, _ramp(), channels=CHANNELS, sample_rate=SAMPLE_RATE
    )


def test_read_returns_the_original_samples() raises:
    """Samples come back verbatim and in order from the start of the buffer."""
    var lib = _lib()
    var ds = _source(lib)

    var got = ds.read_frames(UInt64(4))
    assert_equal(len(got), 4 * Int(CHANNELS))
    for i in range(len(got)):
        assert_equal(got[i], Float32(i))


def test_read_advances_cursor() raises:
    """Consecutive reads continue where the previous one stopped."""
    var lib = _lib()
    var ds = _source(lib)

    var first = ds.read_frames(UInt64(4))
    assert_equal(ds.cursor_frames(), UInt64(4))
    var second = ds.read_frames(UInt64(4))
    assert_equal(ds.cursor_frames(), UInt64(8))

    # The second block starts where the first ended (4 frames * 2 channels).
    assert_equal(first[0], Float32(0))
    assert_equal(second[0], Float32(8))


def test_seek_rewinds_to_identical_samples() raises:
    """Seeking back to a frame reproduces exactly the same samples."""
    var lib = _lib()
    var ds = _source(lib)

    var first = ds.read_frames(UInt64(16))
    ds.seek_to_frame(UInt64(0))
    assert_equal(ds.cursor_frames(), UInt64(0))
    var again = ds.read_frames(UInt64(16))

    assert_equal(len(first), len(again))
    for i in range(len(first)):
        assert_equal(first[i], again[i])


def test_read_past_end_returns_short_list() raises:
    """Reading more than remains yields a truncated list, not an error."""
    var lib = _lib()
    var ds = _source(lib)

    var got = ds.read_frames(UInt64(FRAMES + 64))
    assert_equal(len(got), FRAMES * Int(CHANNELS))

    # Exhausted: the next read comes back empty rather than raising.
    var empty = ds.read_frames(UInt64(8))
    assert_equal(len(empty), 0)


def test_length_in_frames_and_seconds_agree() raises:
    """length_seconds must equal length_frames / sample_rate."""
    var lib = _lib()
    var ds = _source(lib)

    assert_equal(ds.length_frames(), UInt64(FRAMES))
    var expected = Float32(FRAMES) / Float32(SAMPLE_RATE)
    var actual = ds.length_seconds()
    assert_true(actual > expected - Float32(0.0005))
    assert_true(actual < expected + Float32(0.0005))


def test_seek_to_second_positions_cursor() raises:
    """A seek in seconds lands on the matching PCM frame."""
    var lib = _lib()
    var ds = _source(lib)

    ds.seek_to_second(Float32(0.005))
    assert_equal(ds.cursor_frames(), UInt64(240))  # 0.005 s * 48000
    assert_true(ds.cursor_seconds() > Float32(0.004))


def test_range_restricts_readable_frames() raises:
    """A range caps the source at its own length, and reads stop at its end."""
    var lib = _lib()
    var ds = _source(lib)

    ds.set_range(0, 32)
    var r = ds.range()
    assert_equal(r.beg, UInt64(0))
    assert_equal(r.end, UInt64(32))
    assert_equal(ds.length_frames(), UInt64(32))

    var got = ds.read_frames(UInt64(FRAMES))
    assert_equal(len(got), 32 * Int(CHANNELS))


def test_range_offset_shifts_first_sample() raises:
    """A range beginning at frame N starts reads at that frame's samples."""
    var lib = _lib()
    var ds = _source(lib)

    ds.set_range(10, 20)
    var got = ds.read_frames(UInt64(4))
    assert_true(len(got) > 0)
    # Frame 10 of the ramp begins at sample index 10 * channels.
    assert_equal(got[0], Float32(10 * Int(CHANNELS)))


def test_loop_point_roundtrip() raises:
    """The loop point is stored and read back unchanged."""
    var lib = _lib()
    var ds = _source(lib)

    ds.set_loop_point(8, 64)
    var lp = ds.loop_point()
    assert_equal(lp.beg, UInt64(8))
    assert_equal(lp.end, UInt64(64))


def test_looping_toggles() raises:
    """Looping defaults off and round-trips."""
    var lib = _lib()
    var ds = _source(lib)

    assert_false(ds.is_looping())
    ds.set_looping(True)
    assert_true(ds.is_looping())
    ds.set_looping(False)
    assert_false(ds.is_looping())


def test_data_format_reports_construction_parameters() raises:
    """data_format echoes the channels/sample rate the source was built with."""
    var lib = _lib()
    var ds = _source(lib)

    var fmt = ds.data_format()
    assert_equal(fmt.channels, CHANNELS)
    assert_equal(fmt.sample_rate, SAMPLE_RATE)
    assert_equal(fmt.format, 5)  # ma_format_f32


def test_source_owns_its_samples() raises:
    """The source keeps reading correctly after the caller's buffer is gone.

    The shim copies the samples at init, so a caller may drop or reuse its
    List immediately. This is the ownership contract the API documents.
    """
    var lib = _lib()
    var ds: DataSource

    if True:
        var scratch = _ramp()
        ds = DataSource.from_frames(
            lib, scratch, channels=CHANNELS, sample_rate=SAMPLE_RATE
        )
        # Overwrite the caller's buffer; the source must be unaffected.
        for i in range(len(scratch)):
            scratch[i] = Float32(-1)

    var got = ds.read_frames(UInt64(4))
    for i in range(len(got)):
        assert_equal(got[i], Float32(i))


def test_chaining_next_and_current() raises:
    """set_next / set_current round-trip through the identity comparisons."""
    var lib = _lib()
    var first = _source(lib)
    var second = _source(lib)

    assert_true(first.current_is_self())
    assert_false(first.has_next())

    first.set_next(second)
    assert_true(first.next_is(second))
    assert_true(first.has_next())

    first.clear_next()
    assert_false(first.has_next())

    first.set_current(second)
    assert_true(first.current_is(second))
    first.reset_current()
    assert_true(first.current_is_self())


def test_next_callback_roundtrip() raises:
    """The shim-owned next callback installs and clears."""
    var lib = _lib()
    var first = _source(lib)
    var second = _source(lib)

    assert_false(first.has_next_callback())
    first.set_next_callback(second)
    assert_true(first.has_next_callback())
    first.clear_next_callback()
    assert_false(first.has_next_callback())


def test_node_attaches_to_engine_graph() raises:
    """A data source node initialises against an engine and toggles looping."""
    var lib = _lib()
    var engine = ArcPointer(Engine.create(lib, use_null_backend=True))
    var source = ArcPointer(_source(lib))

    var node = DataSourceNode.create(engine, source)
    assert_false(node.is_looping())
    node.set_looping(True)
    assert_true(node.is_looping())
    node.set_looping(False)
    assert_false(node.is_looping())


def test_from_frames_rejects_empty_buffer() raises:
    """An empty sample list is rejected before touching the shim."""
    var lib = _lib()
    var empty = List[Float32]()
    with assert_raises():
        _ = DataSource.from_frames(lib, empty, channels=1, sample_rate=48000)


def test_from_frames_rejects_zero_channels() raises:
    """Zero channels is rejected."""
    var lib = _lib()
    with assert_raises():
        _ = DataSource.from_frames(lib, _ramp(), channels=0, sample_rate=48000)


def test_from_frames_rejects_partial_frame() raises:
    """A buffer shorter than one full frame is rejected."""
    var lib = _lib()
    var tiny = List[Float32]()
    tiny.resize(1, Float32(0))
    with assert_raises():
        _ = DataSource.from_frames(lib, tiny, channels=4, sample_rate=48000)


def test_invalid_range_raises() raises:
    """A range whose end precedes its beginning raises."""
    var lib = _lib()
    var ds = _source(lib)
    with assert_raises():
        ds.set_range(100, 10)


def test_next_callback_continues_a_read_past_the_end() raises:
    """When a source runs out mid-read, its next-callback supplies the rest."""
    var lib = _lib()
    var ones = List[Float32]()
    ones.resize(4, Float32(1))
    var twos = List[Float32]()
    twos.resize(4, Float32(2))
    var first = DataSource.from_frames(lib, ones, channels=1, sample_rate=SAMPLE_RATE)
    var second = DataSource.from_frames(lib, twos, channels=1, sample_rate=SAMPLE_RATE)

    first.set_next_callback(second)
    var got = first.read_frames(UInt64(8))
    assert_equal(len(got), 8)
    for i in range(4):
        assert_equal(got[i], Float32(1))
        assert_equal(got[4 + i], Float32(2))
    # `second` was read by the chain, so it has been consumed too.
    assert_equal(second.cursor_frames(), UInt64(4))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
