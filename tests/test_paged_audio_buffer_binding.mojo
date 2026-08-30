"""TDD contract tests for the paged audio buffer BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the page list is a plain in-memory
linked list, so no device, engine, or file is involved. All 16 MA_API paged
audio buffer functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_INVALID_ARGS
import miniaudio._ffi.paged_audio_buffer_raw as raw


comptime FMT_F32: Int = 5
comptime FMT_UNKNOWN: Int = 0
comptime MONO: UInt32 = 1


def _lib() raises -> MaLib:
    return MaLib.default()


def _ramp(n: Int, start: Int = 0) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(start + i))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _ready(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A handle with an initialised page list and reader."""
    var pab = raw.paged_audio_buffer_alloc(lib)
    assert_equal(raw.paged_audio_buffer_data_init(lib, pab, FMT_F32, MONO), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_init(lib, pab), MA_SUCCESS)
    return pab


# ---- the page list — positive paths -----------------------------------------


def test_data_length_grows_with_each_appended_page() raises:
    """Appending pages accumulates their frames into the list length."""
    var lib = _lib()
    var pab = _ready(lib)

    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(0))
    assert_equal(
        raw.paged_audio_buffer_data_allocate_and_append_page(
            lib, pab, _ramp(4), UInt32(4)
        ),
        MA_SUCCESS,
    )
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(4))
    assert_equal(
        raw.paged_audio_buffer_data_allocate_and_append_page(
            lib, pab, _ramp(3, start=100), UInt32(3)
        ),
        MA_SUCCESS,
    )
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(7))

    raw.paged_audio_buffer_free(lib, pab)


def test_head_and_tail_track_the_list_state() raises:
    """The head dummy stays 0 frames; the tail follows the last appended page."""
    var lib = _lib()
    var pab = _ready(lib)

    var head = raw.paged_audio_buffer_data_get_head(lib, pab)
    assert_equal(head.result, MA_SUCCESS)
    assert_equal(head.frames, UInt64(0))
    assert_true(head.list_is_empty)

    var tail = raw.paged_audio_buffer_data_get_tail(lib, pab)
    assert_equal(tail.result, MA_SUCCESS)
    assert_true(tail.list_is_empty)

    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(5), UInt32(5))
    head = raw.paged_audio_buffer_data_get_head(lib, pab)
    assert_equal(head.frames, UInt64(0))
    assert_true(not head.list_is_empty)

    tail = raw.paged_audio_buffer_data_get_tail(lib, pab)
    assert_equal(tail.frames, UInt64(5))
    assert_true(not tail.list_is_empty)

    raw.paged_audio_buffer_free(lib, pab)


def test_allocate_then_append_links_the_parked_page() raises:
    """A page allocated into a slot only counts once it is appended."""
    var lib = _lib()
    var pab = _ready(lib)

    var slot = raw.paged_audio_buffer_data_allocate_page(lib, pab, _ramp(6), UInt64(6))
    assert_equal(slot.result, MA_SUCCESS)
    assert_equal(slot.value, 0)
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(0))

    assert_equal(
        raw.paged_audio_buffer_data_append_page(lib, pab, slot.value), MA_SUCCESS
    )
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(6))
    # The slot is empty again, so re-appending it is rejected.
    assert_equal(
        raw.paged_audio_buffer_data_append_page(lib, pab, slot.value), MA_INVALID_ARGS
    )

    raw.paged_audio_buffer_free(lib, pab)


def test_allocate_then_free_discards_the_parked_page() raises:
    """Freeing a parked page leaves the list untouched and reopens the slot."""
    var lib = _lib()
    var pab = _ready(lib)

    var slot = raw.paged_audio_buffer_data_allocate_page_silent(lib, pab, UInt64(4))
    assert_equal(slot.result, MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_data_free_page(lib, pab, slot.value), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(0))
    assert_equal(
        raw.paged_audio_buffer_data_free_page(lib, pab, slot.value), MA_INVALID_ARGS
    )

    var again = raw.paged_audio_buffer_data_allocate_page(lib, pab, _ramp(2), UInt64(2))
    assert_equal(again.value, 0)

    raw.paged_audio_buffer_free(lib, pab)


# ---- the reader — positive paths --------------------------------------------


def test_reader_reads_across_page_boundaries() raises:
    """Frames from consecutive pages come back as one contiguous stream."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(4), UInt32(4))
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(
        lib, pab, _ramp(4, start=4), UInt32(4)
    )

    assert_equal(raw.paged_audio_buffer_get_length(lib, pab).value, UInt64(8))

    # Six frames spans the 4-frame page boundary and stops short of the end.
    var dst = _sink(8)
    var rc = raw.paged_audio_buffer_read(lib, pab, dst, UInt64(6))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(6))
    for i in range(6):
        assert_equal(dst[i], Float32(i))
    assert_equal(raw.paged_audio_buffer_get_cursor(lib, pab).value, UInt64(6))

    # Consuming the last page reports MA_AT_END even though every frame arrived.
    var tail_read = raw.paged_audio_buffer_read(lib, pab, dst, UInt64(2))
    assert_equal(tail_read.result, MA_AT_END)
    assert_equal(tail_read.value, UInt64(2))
    assert_equal(dst[0], Float32(6))
    assert_equal(dst[1], Float32(7))
    assert_equal(raw.paged_audio_buffer_get_cursor(lib, pab).value, UInt64(8))

    raw.paged_audio_buffer_free(lib, pab)


def test_reader_reports_at_end_when_the_pages_run_out() raises:
    """A read past the last page is short and reports MA_AT_END."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(3), UInt32(3))

    var dst = _sink(8)
    var rc = raw.paged_audio_buffer_read(lib, pab, dst, UInt64(8))
    assert_equal(rc.result, MA_AT_END)
    assert_equal(rc.value, UInt64(3))

    raw.paged_audio_buffer_free(lib, pab)


def test_pages_appended_after_init_are_picked_up_by_the_reader() raises:
    """The reader is live: a page appended after it drained is read next."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(2), UInt32(2))

    var dst = _sink(2)
    assert_equal(raw.paged_audio_buffer_read(lib, pab, dst, UInt64(2)).value, UInt64(2))

    _ = raw.paged_audio_buffer_data_allocate_and_append_page(
        lib, pab, _ramp(2, start=50), UInt32(2)
    )
    var more = raw.paged_audio_buffer_read(lib, pab, dst, UInt64(2))
    assert_equal(more.value, UInt64(2))
    assert_equal(dst[0], Float32(50))

    raw.paged_audio_buffer_free(lib, pab)


def test_reader_seek_moves_the_cursor() raises:
    """Seeking repositions the cursor across the page list."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(4), UInt32(4))
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(
        lib, pab, _ramp(4, start=4), UInt32(4)
    )

    assert_equal(raw.paged_audio_buffer_seek(lib, pab, UInt64(6)), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_get_cursor(lib, pab).value, UInt64(6))

    var dst = _sink(2)
    assert_equal(raw.paged_audio_buffer_read(lib, pab, dst, UInt64(2)).value, UInt64(2))
    assert_equal(dst[0], Float32(6))

    raw.paged_audio_buffer_free(lib, pab)


def test_reader_uninit_is_idempotent() raises:
    """Uninit releases the reader but leaves the page list readable."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(4), UInt32(4))

    assert_equal(raw.paged_audio_buffer_uninit(lib, pab), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_uninit(lib, pab), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_get_length(lib, pab).result, MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).value, UInt64(4))

    raw.paged_audio_buffer_free(lib, pab)


# ---- negative paths ----------------------------------------------------------


def test_data_init_rejects_an_unknown_format() raises:
    """A format/channel pair with no frame size is rejected."""
    var lib = _lib()
    var pab = raw.paged_audio_buffer_alloc(lib)
    assert_true(pab != null_handle())
    assert_equal(
        raw.paged_audio_buffer_data_init(lib, pab, FMT_UNKNOWN, MONO), MA_INVALID_ARGS
    )
    assert_equal(
        raw.paged_audio_buffer_data_init(lib, pab, FMT_F32, UInt32(0)), MA_INVALID_ARGS
    )
    raw.paged_audio_buffer_free(lib, pab)


def test_operations_before_data_init_are_invalid() raises:
    """Every list and reader entry point rejects an uninitialised handle."""
    var lib = _lib()
    var pab = raw.paged_audio_buffer_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).result, MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_data_get_head(lib, pab).result, MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_data_get_tail(lib, pab).result, MA_INVALID_ARGS)
    assert_equal(
        raw.paged_audio_buffer_data_allocate_page(lib, pab, _ramp(2), UInt64(2)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.paged_audio_buffer_data_append_page(lib, pab, 0), MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_data_free_page(lib, pab, 0), MA_INVALID_ARGS)
    assert_equal(
        raw.paged_audio_buffer_data_allocate_and_append_page(
            lib, pab, _ramp(2), UInt32(2)
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.paged_audio_buffer_init(lib, pab), MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_read(lib, pab, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_seek(lib, pab, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_get_cursor(lib, pab).result, MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_get_length(lib, pab).result, MA_INVALID_ARGS)

    raw.paged_audio_buffer_free(lib, pab)


def test_out_of_range_slots_are_rejected() raises:
    """Slot indices outside the handle's parking space are rejected."""
    var lib = _lib()
    var pab = _ready(lib)
    assert_equal(raw.paged_audio_buffer_data_append_page(lib, pab, -1), MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_data_free_page(lib, pab, 99), MA_INVALID_ARGS)
    raw.paged_audio_buffer_free(lib, pab)


def test_data_uninit_drops_the_pages_and_null_handles_are_safe() raises:
    """The data_uninit call clears the list; null handles rejected, free(null) a noop."""
    var lib = _lib()
    var pab = _ready(lib)
    _ = raw.paged_audio_buffer_data_allocate_and_append_page(lib, pab, _ramp(4), UInt32(4))
    # A page parked but never appended is released along with the list.
    _ = raw.paged_audio_buffer_data_allocate_page(lib, pab, _ramp(2), UInt64(2))

    assert_equal(raw.paged_audio_buffer_data_uninit(lib, pab), MA_SUCCESS)
    assert_equal(raw.paged_audio_buffer_data_get_length(lib, pab).result, MA_INVALID_ARGS)
    raw.paged_audio_buffer_free(lib, pab)

    assert_equal(
        raw.paged_audio_buffer_data_init(lib, null_handle(), FMT_F32, MONO),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.paged_audio_buffer_data_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.paged_audio_buffer_uninit(lib, null_handle()), MA_INVALID_ARGS)
    raw.paged_audio_buffer_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
