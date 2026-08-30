"""TDD tests for the idiomatic audio buffer API (RAII AudioBufferRef / AudioBuffer).

L3 behavioral: verifies that frames survive a round trip in order, that the
cursor / length / available accounting stays self-consistent across seeks and
short reads, that looping wraps back to the start, that the map/unmap path
delivers the same frames as the read path, and that multi-channel frames are
counted as frames rather than samples.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.audio_buffer import AudioBuffer, AudioBufferRef


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int, start: Int = 0) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(start + i))
    return out^


# ---- AudioBufferRef ---------------------------------------------------------


def test_ref_reads_frames_in_order() raises:
    """Frames come back out in the order they went in."""
    var src = _ramp(8)
    var ab = AudioBufferRef.create(_lib(), src)
    assert_true(ab.length() == UInt64(8))

    var got = ab.read(UInt64(8))
    assert_equal(len(got), 8)
    for i in range(8):
        assert_equal(got[i], src[i])
    assert_true(ab.at_end())


def test_ref_counts_frames_not_samples() raises:
    """An 8-sample stereo list is 4 frames, and a read returns 2 samples per frame."""
    var ab = AudioBufferRef.create(_lib(), _ramp(8), channels=2)
    assert_true(ab.length() == UInt64(4))

    var got = ab.read(UInt64(2))
    assert_equal(len(got), 4)
    assert_equal(got[0], Float32(0))
    assert_equal(got[3], Float32(3))
    assert_true(ab.cursor() == UInt64(2))


def test_ref_available_is_length_minus_cursor() raises:
    """The available/cursor/length invariant holds across a seek."""
    var ab = AudioBufferRef.create(_lib(), _ramp(8))
    ab.seek(UInt64(3))
    assert_true(ab.cursor() == UInt64(3))
    assert_true(ab.available() == ab.length() - ab.cursor())
    assert_true(not ab.at_end())

    var rest = ab.read(UInt64(100))
    assert_equal(len(rest), 5)
    assert_equal(rest[0], Float32(3))
    assert_true(ab.available() == UInt64(0))


def test_ref_looping_read_wraps_to_the_start() raises:
    """A looping read longer than the buffer repeats it instead of stopping."""
    var ab = AudioBufferRef.create(_lib(), _ramp(4))
    var got = ab.read(UInt64(10), loop=True)
    assert_equal(len(got), 10)
    for i in range(10):
        assert_equal(got[i], Float32(i % 4))


def test_ref_map_read_delivers_the_same_frames_as_read() raises:
    """The map/unmap path and the read path agree, chunk for chunk."""
    var src = _ramp(8, start=5)
    var mapped = AudioBufferRef.create(_lib(), src)
    var copied = AudioBufferRef.create(_lib(), src)

    var a = mapped.map_read(UInt64(5))
    var b = copied.read(UInt64(5))
    assert_equal(len(a), len(b))
    for i in range(len(a)):
        assert_equal(a[i], b[i])

    # The tail chunk reaches the end; that is a success, not an error.
    var tail = mapped.map_read(UInt64(5))
    assert_equal(len(tail), 3)
    assert_true(mapped.at_end())


def test_ref_set_data_replaces_the_view() raises:
    """The set_data call swaps the frames and rewinds the cursor."""
    var ab = AudioBufferRef.create(_lib(), _ramp(8))
    _ = ab.read(UInt64(6))
    ab.set_data(_ramp(3, start=50))

    assert_true(ab.length() == UInt64(3))
    assert_true(ab.cursor() == UInt64(0))
    var got = ab.read(UInt64(3))
    assert_equal(got[0], Float32(50))
    assert_equal(got[2], Float32(52))


def test_ref_rejects_an_empty_frame_list() raises:
    """A view over no frames raises rather than producing a dead buffer."""
    var empty = List[Float32]()
    with assert_raises():
        _ = AudioBufferRef.create(_lib(), empty)


# ---- AudioBuffer ------------------------------------------------------------


def test_ref_rejects_a_zero_channel_count() raises:
    """Zero channels is rejected rather than dividing the sample count by zero."""
    with assert_raises():
        _ = AudioBufferRef.create(_lib(), _ramp(8), channels=0)


def test_buffer_reads_frames_in_order() raises:
    """The owning buffer round-trips its frames."""
    var src = _ramp(8)
    var ab = AudioBuffer.create(_lib(), src)
    assert_true(ab.length() == UInt64(8))

    var got = ab.read(UInt64(8))
    assert_equal(len(got), 8)
    for i in range(8):
        assert_equal(got[i], src[i])


def test_buffer_create_copy_matches_create() raises:
    """The copying and non-copying inits deliver identical frames."""
    var src = _ramp(8, start=3)
    var referenced = AudioBuffer.create(_lib(), src)
    var copied = AudioBuffer.create_copy(_lib(), src)

    var a = referenced.read(UInt64(8))
    var b = copied.read(UInt64(8))
    for i in range(8):
        assert_equal(a[i], b[i])


def test_buffer_silent_is_zero_filled() raises:
    """The create_silent path yields the requested length, all zeros."""
    var ab = AudioBuffer.create_silent(_lib(), UInt64(6))
    assert_true(ab.length() == UInt64(6))
    var got = ab.read(UInt64(6))
    assert_equal(len(got), 6)
    for i in range(6):
        assert_equal(got[i], Float32(0))


def test_buffer_allocated_keeps_every_frame_but_the_first() raises:
    """The create_allocated path round-trips frames 1..N-1.

    Frame 0 is clipped by an upstream defect in miniaudio 0.11.25 — see
    `AudioBuffer.create_allocated` and the note in ma_shim_audio_buffer.h.
    """
    var src = _ramp(8, start=20)
    var ab = AudioBuffer.create_allocated(_lib(), src)
    assert_true(ab.length() == UInt64(8))

    var got = ab.read(UInt64(8))
    assert_equal(len(got), 8)
    for i in range(1, 8):
        assert_equal(got[i], src[i])


def test_buffer_seek_and_available_track_the_cursor() raises:
    """Seeking moves the cursor and available frames follow it."""
    var ab = AudioBuffer.create_copy(_lib(), _ramp(8))
    ab.seek(UInt64(5))
    assert_true(ab.cursor() == UInt64(5))
    assert_true(ab.available() == UInt64(3))

    var got = ab.read(UInt64(8))
    assert_equal(len(got), 3)
    assert_equal(got[0], Float32(5))
    assert_true(ab.at_end())

    with assert_raises():
        ab.seek(UInt64(99))


def test_buffer_map_read_reaches_the_end_without_raising() raises:
    """Reading via map_read drains the buffer in chunks; the last one does not raise."""
    var ab = AudioBuffer.create_copy(_lib(), _ramp(8))
    var first = ab.map_read(UInt64(6))
    assert_equal(len(first), 6)
    var rest = ab.map_read(UInt64(6))
    assert_equal(len(rest), 2)
    assert_equal(rest[0], Float32(6))
    assert_true(ab.at_end())


def test_buffer_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit the handle is empty and every accessor raises."""
    var ab = AudioBuffer.create_copy(_lib(), _ramp(8))
    ab.uninit()
    with assert_raises():
        _ = ab.length()
    with assert_raises():
        _ = ab.read(UInt64(1))


def test_buffer_rejects_an_empty_frame_list() raises:
    """A zero-frame buffer raises on every init path."""
    var empty = List[Float32]()
    with assert_raises():
        _ = AudioBuffer.create(_lib(), empty)
    with assert_raises():
        _ = AudioBuffer.create_copy(_lib(), empty)
    with assert_raises():
        _ = AudioBuffer.create_allocated(_lib(), empty)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
