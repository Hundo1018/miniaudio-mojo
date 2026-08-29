"""TDD tests for the idiomatic ring buffer API (RAII RingBuffer / PcmRingBuffer).

L3 behavioral: verifies that data survives a round trip in order, that requests
crossing the ring's wrap point are stitched back together correctly, that the
capacity accounting invariants hold, and that a producer/consumer stream longer
than the buffer drains and refills without losing or reordering frames.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.ring_buffer import RingBuffer, PcmRingBuffer


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int, start: Int = 0) -> List[UInt8]:
    var out = List[UInt8](capacity=n)
    for i in range(n):
        out.append(UInt8((start + i) & 0xFF))
    return out^


# ---- RingBuffer (bytes) -----------------------------------------------------


def test_write_read_roundtrip_preserves_bytes() raises:
    """Bytes come back out in the order they went in."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    var src = _ramp(20)
    assert_true(rb.write(src) == UInt64(20))

    var got = rb.read(UInt64(20))
    assert_equal(len(got), 20)
    for i in range(20):
        assert_equal(got[i], src[i])


def test_read_across_wrap_point_is_contiguous() raises:
    """A write/read pair spanning the ring's wrap point keeps byte order.

    The second 24-byte write starts 24 bytes into a 32-byte ring, so it is split
    into an 8-byte tail and a 16-byte head by miniaudio's acquire/commit pair.
    """
    var rb = RingBuffer.create(_lib(), UInt64(32))
    var first = _ramp(24)
    assert_true(rb.write(first) == UInt64(24))
    _ = rb.read(UInt64(24))

    var second = _ramp(24, start=100)
    assert_true(rb.write(second) == UInt64(24))
    var got = rb.read(UInt64(24))

    assert_equal(len(got), 24)
    for i in range(24):
        assert_equal(got[i], second[i])


def test_write_beyond_capacity_is_short() raises:
    """Writing more than fits stops at the capacity instead of raising."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    var src = _ramp(40)
    assert_true(rb.write(src) == UInt64(32))
    assert_true(rb.available_write() == UInt32(0))


def test_read_of_empty_buffer_returns_empty_list() raises:
    """Reading an empty ring yields an empty list, not an error."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    var got = rb.read(UInt64(16))
    assert_equal(len(got), 0)


def test_capacity_accounting_invariant() raises:
    """available_read + available_write == subbuffer_size, and distance == readable."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    var size = rb.subbuffer_size()
    assert_true(size == UInt64(32))
    assert_true(UInt64(rb.available_read() + rb.available_write()) == size)

    _ = rb.write(_ramp(12))
    assert_true(rb.available_read() == UInt32(12))
    assert_true(UInt64(rb.available_read() + rb.available_write()) == size)
    assert_equal(rb.pointer_distance(), 12)


def test_reset_discards_buffered_data() raises:
    """reset returns the ring to empty."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    _ = rb.write(_ramp(16))
    assert_true(rb.available_read() == UInt32(16))
    rb.reset()
    assert_true(rb.available_read() == UInt32(0))
    assert_true(rb.available_write() == UInt32(32))


def test_seek_write_then_seek_read() raises:
    """seek_write publishes bytes without copying; seek_read consumes them."""
    var rb = RingBuffer.create(_lib(), UInt64(32))
    rb.seek_write(UInt64(8))
    assert_true(rb.available_read() == UInt32(8))
    rb.seek_read(UInt64(5))
    assert_true(rb.available_read() == UInt32(3))


def test_create_ex_subbuffer_geometry() raises:
    """A preallocated multi-subbuffer ring reports the stride it was given."""
    var rb = RingBuffer.create_ex(
        _lib(),
        subbuffer_size_in_bytes=UInt64(32),
        subbuffer_count=UInt64(2),
        subbuffer_stride_in_bytes=UInt64(64),
        use_preallocated=True,
    )
    assert_true(rb.subbuffer_size() == UInt64(32))
    assert_true(rb.subbuffer_stride() == UInt64(64))
    assert_true(rb.subbuffer_offset(UInt64(0)) == UInt64(0))
    assert_true(rb.subbuffer_offset(UInt64(1)) == UInt64(64))
    assert_true(rb.subbuffer_ptr_offset(UInt64(1)) == UInt64(64))


def test_create_rejects_zero_size() raises:
    """A zero-byte ring buffer raises rather than returning a dead handle."""
    with assert_raises():
        _ = RingBuffer.create(_lib(), UInt64(0))


def test_repeated_create_and_drop() raises:
    """RAII: many create/drop cycles neither leak nor reuse a freed handle."""
    var lib = _lib()
    for i in range(32):
        var rb = RingBuffer.create(lib, UInt64(64))
        _ = rb.write(_ramp(8, start=i))
        assert_true(rb.available_read() == UInt32(8))


# ---- PcmRingBuffer (frames) -------------------------------------------------


def _ramp_f32(n: Int, start: Int = 0) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(start + i) * 0.25)
    return out^


def test_pcm_stereo_roundtrip_preserves_interleaving() raises:
    """Stereo frames come back with their sample interleaving intact."""
    var rb = PcmRingBuffer.create(_lib(), channels=2, buffer_size_in_frames=UInt32(16))
    var src = _ramp_f32(20)  # 10 stereo frames
    assert_true(rb.write_frames(src) == UInt32(10))

    var got = rb.read_frames(UInt32(10))
    assert_equal(len(got), 20)
    for i in range(20):
        assert_equal(got[i], src[i])


def test_pcm_read_returns_only_available_frames() raises:
    """Asking for more frames than are buffered returns just what is there."""
    var rb = PcmRingBuffer.create(_lib(), channels=1, buffer_size_in_frames=UInt32(16))
    _ = rb.write_frames(_ramp_f32(4))
    var got = rb.read_frames(UInt32(16))
    assert_equal(len(got), 4)


def test_pcm_data_format_and_sample_rate() raises:
    """data_format reports the configured layout; set_sample_rate round-trips."""
    var rb = PcmRingBuffer.create(_lib(), channels=2, buffer_size_in_frames=UInt32(16))
    var fmt = rb.data_format()
    assert_equal(fmt.format, 5)  # f32
    assert_true(fmt.channels == UInt32(2))
    assert_true(fmt.sample_rate == UInt32(0))

    rb.set_sample_rate(UInt32(48000))
    assert_true(rb.data_format().sample_rate == UInt32(48000))


def test_pcm_streaming_longer_than_capacity() raises:
    """A producer/consumer stream longer than the ring loses and reorders nothing."""
    var rb = PcmRingBuffer.create(_lib(), channels=1, buffer_size_in_frames=UInt32(16))
    var total = 100
    var chunk = 6
    var produced = 0
    var consumed = List[Float32]()

    while produced < total:
        var n = chunk if produced + chunk <= total else total - produced
        var written = rb.write_frames(_ramp_f32(n, start=produced))
        produced += Int(written)
        var got = rb.read_frames(UInt32(chunk))
        for i in range(len(got)):
            consumed.append(got[i])

    # Drain whatever is still buffered.
    while rb.available_read() > UInt32(0):
        var tail = rb.read_frames(rb.available_read())
        for i in range(len(tail)):
            consumed.append(tail[i])

    assert_equal(len(consumed), total)
    for i in range(total):
        assert_equal(consumed[i], Float32(i) * 0.25)


def test_pcm_capacity_accounting_and_reset() raises:
    """Frame-denominated accounting invariants, and reset clears the ring."""
    var rb = PcmRingBuffer.create(_lib(), channels=2, buffer_size_in_frames=UInt32(16))
    assert_true(rb.subbuffer_size() == UInt32(16))
    assert_true(rb.available_write() == UInt32(16))

    _ = rb.write_frames(_ramp_f32(12))  # 6 stereo frames
    assert_true(rb.available_read() == UInt32(6))
    assert_true(rb.available_read() + rb.available_write() == rb.subbuffer_size())
    assert_equal(rb.pointer_distance(), 6)

    rb.reset()
    assert_true(rb.available_read() == UInt32(0))


def test_pcm_seek_write_then_seek_read() raises:
    """Frame-denominated seek_write / seek_read move the pointers."""
    var rb = PcmRingBuffer.create(_lib(), channels=1, buffer_size_in_frames=UInt32(16))
    rb.seek_write(UInt32(8))
    assert_true(rb.available_read() == UInt32(8))
    rb.seek_read(UInt32(3))
    assert_true(rb.available_read() == UInt32(5))


def test_pcm_create_ex_subbuffer_geometry() raises:
    """Sub-buffer offsets are frame-valued; the pointer offset is byte-valued."""
    var rb = PcmRingBuffer.create_ex(
        _lib(),
        channels=1,
        subbuffer_size_in_frames=UInt32(8),
        subbuffer_count=UInt32(2),
        use_preallocated=True,
    )
    assert_true(rb.subbuffer_size() == UInt32(8))
    assert_true(rb.subbuffer_stride() == UInt32(8))
    assert_true(rb.subbuffer_offset(UInt32(1)) == UInt32(8))
    # 8 frames * 1 channel * 4 bytes per f32 sample.
    assert_true(rb.subbuffer_ptr_offset(UInt32(1)) == UInt64(32))


def test_pcm_create_rejects_zero_frames() raises:
    """A zero-frame PCM ring buffer raises."""
    with assert_raises():
        _ = PcmRingBuffer.create(_lib(), channels=1, buffer_size_in_frames=UInt32(0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
