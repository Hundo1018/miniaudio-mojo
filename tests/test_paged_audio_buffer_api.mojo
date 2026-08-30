"""TDD tests for the idiomatic paged audio buffer API (RAII PagedAudioBuffer).

L3 behavioral: verifies that a stream assembled from several pages reads back as
one contiguous sequence, that pages appended after the reader has drained are
picked up (the streaming property the type exists for), that the two append
shapes agree, that the cursor/length accounting holds across seeks, and that
multi-channel frames are counted as frames rather than samples.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.paged_audio_buffer import PagedAudioBuffer


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int, start: Int = 0) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(start + i))
    return out^


def test_new_buffer_is_empty() raises:
    """A fresh buffer has no pages and a zero-length reader."""
    var pab = PagedAudioBuffer.create(_lib())
    assert_true(pab.data_length() == UInt64(0))
    assert_true(pab.length() == UInt64(0))
    assert_true(pab.cursor() == UInt64(0))
    assert_true(pab.head().list_is_empty)
    assert_true(pab.tail().list_is_empty)


def test_appended_pages_read_back_as_one_stream() raises:
    """Three pages read back as a single contiguous frame sequence."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(3))
    pab.append(_ramp(3, start=3))
    pab.append(_ramp(2, start=6))
    assert_true(pab.data_length() == UInt64(8))
    assert_true(pab.length() == pab.data_length())

    var got = pab.read(UInt64(8))
    assert_equal(len(got), 8)
    for i in range(8):
        assert_equal(got[i], Float32(i))


def test_head_stays_a_dummy_and_tail_follows_the_last_page() raises:
    """The head page is always zero-length; the tail reports the newest page."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(4))
    pab.append(_ramp(7))

    assert_true(pab.head().frames == UInt64(0))
    assert_true(not pab.head().list_is_empty)
    assert_true(pab.tail().frames == UInt64(7))
    assert_true(not pab.tail().list_is_empty)


def test_reading_past_the_last_page_is_short_not_an_error() raises:
    """Asking for more than the list holds returns what there is."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(3))

    var got = pab.read(UInt64(10))
    assert_equal(len(got), 3)
    assert_true(pab.cursor() == UInt64(3))


def test_a_page_appended_after_draining_continues_the_stream() raises:
    """The reader is live — this is the streaming property the type exists for."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(2))
    assert_equal(len(pab.read(UInt64(2))), 2)

    var drained = pab.read(UInt64(2))
    assert_equal(len(drained), 0)

    pab.append(_ramp(2, start=90))
    var more = pab.read(UInt64(2))
    assert_equal(len(more), 2)
    assert_equal(more[0], Float32(90))
    assert_true(pab.length() == UInt64(4))


def test_allocate_then_append_matches_a_direct_append() raises:
    """The two-step append produces the same stream as the one-step one."""
    var staged = PagedAudioBuffer.create(_lib())
    var slot = staged.allocate_page(_ramp(4))
    assert_true(staged.data_length() == UInt64(0))
    staged.append_allocated(slot)

    var direct = PagedAudioBuffer.create(_lib())
    direct.append(_ramp(4))

    var a = staged.read(UInt64(4))
    var b = direct.read(UInt64(4))
    assert_equal(len(a), len(b))
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_freeing_a_staged_page_leaves_the_list_untouched() raises:
    """A page that is allocated and then discarded never joins the stream."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(2))
    var slot = pab.allocate_page(_ramp(5, start=200))
    pab.free_allocated(slot)

    assert_true(pab.data_length() == UInt64(2))
    var got = pab.read(UInt64(5))
    assert_equal(len(got), 2)
    assert_equal(got[0], Float32(0))


def test_seek_repositions_the_reader_across_pages() raises:
    """A seek lands mid-list and the next read continues from there."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(4))
    pab.append(_ramp(4, start=4))

    pab.seek(UInt64(5))
    assert_true(pab.cursor() == UInt64(5))
    var got = pab.read(UInt64(3))
    assert_equal(len(got), 3)
    assert_equal(got[0], Float32(5))


def test_frames_are_counted_per_channel() raises:
    """An 8-sample stereo page is 4 frames, and a read returns 2 samples per frame."""
    var pab = PagedAudioBuffer.create(_lib(), channels=2)
    pab.append(_ramp(8))
    assert_true(pab.data_length() == UInt64(4))

    var got = pab.read(UInt64(2))
    assert_equal(len(got), 4)
    assert_equal(got[3], Float32(3))


def test_clear_drops_every_page() raises:
    """Calling clear() empties the list; the reader must be rebuilt afterwards."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(4))
    pab.clear()

    with assert_raises():
        _ = pab.data_length()


def test_uninit_reader_leaves_the_pages_in_place() raises:
    """Releasing the reader early keeps the page list intact."""
    var pab = PagedAudioBuffer.create(_lib())
    pab.append(_ramp(4))
    pab.uninit_reader()

    assert_true(pab.data_length() == UInt64(4))
    with assert_raises():
        _ = pab.length()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
