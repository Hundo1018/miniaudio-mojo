"""TDD contract tests for the user-stream plumbing (src/miniaudio/_ffi/stream_raw.mojo).

The trampolines are what the C shim calls through function pointers; they are
also plain Mojo functions, so they are driven here directly, with the same C ABI
arguments the shim passes. What is pinned: the byte count a read or write stores
(always, zero on every failure: miniaudio's codecs read it even after one), the
ma_result mapping (success, end of stream, I/O error, bad seek), that nothing a
stream does escapes as an exception, and the heap cell that carries a stream
across the FFI (moved in once, destroyed or taken back exactly once).
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_IO_ERROR
from miniaudio.stream import (
    ReadSeekStream,
    ReadSeekTellStream,
    WriteSeekStream,
    MemoryReader,
    SEEK_ORIGIN_START,
    SEEK_ORIGIN_CURRENT,
    SEEK_ORIGIN_END,
)
from miniaudio._ffi.stream_raw import (
    Opaque,
    StreamPtr,
    MA_BAD_SEEK,
    stream_tag,
    stream_null_ptr,
    stream_leak,
    stream_reclaim,
    stream_take,
    stream_destroy,
    stream_read_tramp,
    stream_seek_tramp,
    stream_tell_tramp,
    sink_write_tramp,
    sink_seek_tramp,
)
from support.stream_fixtures import (
    T_READS,
    T_SEEKS,
    T_TELLS,
    T_WRITES,
    T_DESTROYED,
    T_BYTES,
    TallyBytes,
    TallySink,
    new_tally,
    tally_ptr,
)


def _bytes(n: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(n):
        out.append(UInt8(i % 251))
    return out^


def _op[T: AnyType](p: Pointer[T, ...]) -> Opaque:
    return Opaque(unsafe_from_address=Int(p))


# The trampolines get bare addresses, which Mojo cannot see through: the buffers
# must be borrowed into these helpers so they are certainly alive for the call
# (a list whose last use is `list.unsafe_ptr()` is freed before the call runs).
def _read[
    S: ReadSeekStream
](cell: StreamPtr[S], mut buf: List[UInt8], count: Int, mut got: List[UInt]) -> Int:
    return Int(
        stream_read_tramp[S](_op(cell), _op(buf.unsafe_ptr()), UInt(count), _op(got.unsafe_ptr()))
    )


def _tell[S: ReadSeekTellStream](cell: StreamPtr[S], mut at: List[Int64]) -> Int:
    return Int(stream_tell_tramp[S](_op(cell), _op(at.unsafe_ptr())))


def _write[
    S: WriteSeekStream
](cell: StreamPtr[S], mut src: List[UInt8], count: Int, mut put: List[UInt]) -> Int:
    return Int(
        sink_write_tramp[S](_op(cell), _op(src.unsafe_ptr()), UInt(count), _op(put.unsafe_ptr()))
    )


# A user-defined stream that lies about how much it moved, defined here rather
# than imported: reports whatever count it is told to, whatever it really did.
struct Liar(ReadSeekStream, WriteSeekStream):
    var claim: Int

    def __init__(out self, claim: Int):
        self.claim = claim

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        return self.claim

    def write(mut self, data: Span[UInt8, ImmutAnyOrigin]) raises -> Int:
        return self.claim

    def seek(mut self, offset: Int64, origin: Int) raises:
        pass


# A user-defined stream with no state: always at its end.
struct Silence(ReadSeekStream):
    def __init__(out self):
        pass

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        return 0

    def seek(mut self, offset: Int64, origin: Int) raises:
        pass


# ---- the heap cell -----------------------------------------------------------


def test_leak_then_reclaim_destroys_the_stream_once() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(8), tally_ptr(tally)))
    assert_equal(tally[T_DESTROYED], 0)  # moved onto the heap, not destroyed
    assert_equal(cell[].pos, 0)  # reachable through the cell
    stream_reclaim(cell)
    assert_equal(tally[T_DESTROYED], 1)


def test_stream_destroy_is_the_callback_the_shim_runs() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    stream_destroy[TallySink](_op(cell))
    assert_equal(tally[T_DESTROYED], 1)


def test_take_hands_the_stream_back_alive() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(8), tally_ptr(tally)))
    cell[].pos = 5
    var back = stream_take(cell)
    assert_equal(back.pos, 5)  # the same instance, state intact
    assert_equal(tally[T_DESTROYED], 0)  # freeing the cell does not destroy it
    _ = back^
    assert_equal(tally[T_DESTROYED], 1)


def test_a_zero_sized_stream_survives_the_round_trip() raises:
    # A stream with no state at all is legal; the heap cell must cope.
    var cell = stream_leak(Silence())
    var buf = List[UInt8](length=4, fill=9)
    var got: List[UInt] = [UInt(7)]
    assert_equal(_read(cell, buf, 4, got), MA_AT_END)
    assert_equal(got[0], UInt(0))
    stream_reclaim(cell)


def test_type_tags_tell_stream_types_apart() raises:
    assert_equal(stream_tag[TallyBytes](), stream_tag[TallyBytes]())
    assert_true(stream_tag[TallyBytes]() != stream_tag[TallySink]())
    assert_true(stream_tag[TallyBytes]() != stream_tag[MemoryReader]())
    assert_true(stream_tag[TallyBytes]() != 0)


def test_null_stream_pointer_helper_is_null() raises:
    assert_equal(Int(stream_null_ptr[TallyBytes]()), 0)


# ---- read --------------------------------------------------------------------


def test_read_reports_count_and_success() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally)))
    var buf = List[UInt8](length=40, fill=0)
    var got: List[UInt] = [UInt(999)]
    var rc = _read(cell, buf, 40, got)
    assert_equal(rc, MA_SUCCESS)
    assert_equal(got[0], UInt(40))
    for i in range(40):
        assert_equal(Int(buf[i]), i % 251)
    assert_equal(tally[T_READS], 1)
    stream_reclaim(cell)


def test_short_reads_are_completed_by_asking_again() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally), chunk=7))
    var buf = List[UInt8](length=40, fill=0)
    var got: List[UInt] = [UInt(0)]
    var rc = _read(cell, buf, 40, got)
    assert_equal(rc, MA_SUCCESS)
    assert_equal(got[0], UInt(40))  # the stream only gave 7 at a time
    for i in range(40):
        assert_equal(Int(buf[i]), i % 251)
    assert_equal(tally[T_READS], 6)  # 5 x 7 + 5
    stream_reclaim(cell)


def test_a_failure_after_partial_data_returns_the_data_and_the_error_comes_next() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally), chunk=7, fail_read_at=3))
    var buf = List[UInt8](length=40, fill=0)
    var got: List[UInt] = [UInt(0)]
    assert_equal(_read(cell, buf, 40, got), MA_SUCCESS)  # two reads' worth arrived
    assert_equal(got[0], UInt(14))
    assert_equal(_read(cell, buf, 40, got), MA_IO_ERROR)  # a persistent failure surfaces now
    assert_equal(got[0], UInt(0))
    stream_reclaim(cell)
    assert_equal(tally[T_READS], 4)


def test_end_of_stream_is_at_end_with_zero_bytes() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(10), tally_ptr(tally)))
    var buf = List[UInt8](length=16, fill=0)
    var got: List[UInt] = [UInt(0)]
    assert_equal(
        _read(cell, buf, 16, got),
        MA_SUCCESS,
    )
    assert_equal(got[0], UInt(10))
    got[0] = 555
    var rc = _read(cell, buf, 16, got)
    assert_equal(rc, MA_AT_END)
    assert_equal(got[0], UInt(0))
    stream_reclaim(cell)


def test_zero_byte_read_is_success_and_skips_the_stream() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(10), tally_ptr(tally)))
    var buf = List[UInt8](length=4, fill=0)
    var got: List[UInt] = [UInt(321)]
    var rc = _read(cell, buf, 0, got)
    assert_equal(rc, MA_SUCCESS)
    assert_equal(got[0], UInt(0))
    assert_equal(tally[T_READS], 0)
    stream_reclaim(cell)


def test_raising_read_is_an_io_error_and_clears_the_count() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(10), tally_ptr(tally), fail_read_at=1))
    var buf = List[UInt8](length=4, fill=0)
    var got: List[UInt] = [UInt(321)]
    var rc = _read(cell, buf, 4, got)
    assert_equal(rc, MA_IO_ERROR)
    assert_equal(got[0], UInt(0))  # miniaudio reads this even after a failure
    stream_reclaim(cell)
    assert_equal(tally[T_READS], 1)  # also keeps the tally alive past the stream


def test_impossible_read_counts_are_io_errors() raises:
    var buf = List[UInt8](length=4, fill=0)
    var got: List[UInt] = [UInt(321)]
    var too_many = stream_leak(Liar(5))  # more than the 4 asked for
    assert_equal(
        _read(too_many, buf, 4, got),
        MA_IO_ERROR,
    )
    assert_equal(got[0], UInt(0))
    stream_reclaim(too_many)
    got[0] = 321
    var negative = stream_leak(Liar(-1))
    assert_equal(
        _read(negative, buf, 4, got),
        MA_IO_ERROR,
    )
    assert_equal(got[0], UInt(0))
    stream_reclaim(negative)


# ---- seek and tell -----------------------------------------------------------


def test_seek_passes_offset_and_origin_through() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally)))
    var user = _op(cell)
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, 30, Int32(SEEK_ORIGIN_START))), MA_SUCCESS)
    assert_equal(cell[].pos, 30)
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, 10, Int32(SEEK_ORIGIN_CURRENT))), MA_SUCCESS)
    assert_equal(cell[].pos, 40)
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, -5, Int32(SEEK_ORIGIN_END))), MA_SUCCESS)
    assert_equal(cell[].pos, 95)
    assert_equal(tally[T_SEEKS], 3)
    stream_reclaim(cell)


def test_failing_seek_is_a_bad_seek() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally)))
    var user = _op(cell)
    # past the end: the stream refuses; a negative target: seek_target refuses
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, 101, Int32(SEEK_ORIGIN_START))), MA_BAD_SEEK)
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, -1, Int32(SEEK_ORIGIN_START))), MA_BAD_SEEK)
    assert_equal(Int(stream_seek_tramp[TallyBytes](user, 0, Int32(9))), MA_BAD_SEEK)  # unknown origin
    assert_equal(cell[].pos, 0)  # a refused seek moves nothing
    stream_reclaim(cell)
    assert_equal(tally[T_SEEKS], 3)


def test_tell_stores_the_position() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally)))
    cell[].pos = 64
    var at: List[Int64] = [Int64(-1)]
    assert_equal(_tell(cell, at), MA_SUCCESS)
    assert_equal(at[0], Int64(64))
    assert_equal(tally[T_TELLS], 1)
    stream_reclaim(cell)


def test_failing_tell_is_an_io_error() raises:
    var tally = new_tally()
    var cell = stream_leak(TallyBytes(_bytes(100), tally_ptr(tally), fail_tell=True))
    var at: List[Int64] = [Int64(-1)]
    assert_equal(_tell(cell, at), MA_IO_ERROR)
    assert_equal(at[0], Int64(-1))  # nothing stored
    stream_reclaim(cell)
    assert_equal(tally[T_TELLS], 1)


# ---- write and sink seek -----------------------------------------------------


def test_write_reports_count_and_stores_the_bytes() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    var src = _bytes(12)
    var put: List[UInt] = [UInt(999)]
    var rc = _write(cell, src, 12, put)
    assert_equal(rc, MA_SUCCESS)
    assert_equal(put[0], UInt(12))
    assert_equal(len(cell[].data), 12)
    for i in range(12):
        assert_equal(Int(cell[].data[i]), i % 251)
    assert_equal(tally[T_WRITES], 1)
    assert_equal(tally[T_BYTES], 12)
    stream_reclaim(cell)


def test_short_writes_are_completed_by_offering_the_rest() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally), chunk=5))
    var src = _bytes(12)
    var put: List[UInt] = [UInt(0)]
    assert_equal(_write(cell, src, 12, put), MA_SUCCESS)
    assert_equal(put[0], UInt(12))  # the sink only took 5 at a time
    assert_equal(len(cell[].data), 12)
    for i in range(12):
        assert_equal(Int(cell[].data[i]), i % 251)
    assert_equal(tally[T_WRITES], 3)
    stream_reclaim(cell)


def test_a_sink_failing_after_partial_data_gives_a_short_count_then_the_error() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally), chunk=5, fail_write_at=2))
    var src = _bytes(12)
    var put: List[UInt] = [UInt(0)]
    assert_equal(_write(cell, src, 12, put), MA_SUCCESS)
    assert_equal(put[0], UInt(5))  # miniaudio sees the short count
    assert_equal(_write(cell, src, 12, put), MA_IO_ERROR)
    assert_equal(put[0], UInt(0))
    stream_reclaim(cell)
    assert_equal(tally[T_WRITES], 3)


def test_zero_byte_write_is_success_and_skips_the_sink() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    var src = _bytes(4)
    var put: List[UInt] = [UInt(321)]
    assert_equal(
        _write(cell, src, 0, put),
        MA_SUCCESS,
    )
    assert_equal(put[0], UInt(0))
    assert_equal(tally[T_WRITES], 0)
    stream_reclaim(cell)


def test_raising_write_is_an_io_error_and_clears_the_count() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally), fail_write_at=1))
    var src = _bytes(4)
    var put: List[UInt] = [UInt(321)]
    assert_equal(
        _write(cell, src, 4, put),
        MA_IO_ERROR,
    )
    assert_equal(put[0], UInt(0))
    stream_reclaim(cell)
    assert_equal(tally[T_WRITES], 1)


def test_impossible_write_counts_and_stalled_sinks_are_io_errors() raises:
    var src = _bytes(4)
    var put: List[UInt] = [UInt(321)]
    for claim in [5, -1, 0]:  # too many, negative, nothing written
        put[0] = 321
        var cell = stream_leak(Liar(claim))
        assert_equal(
            _write(cell, src, 4, put),
            MA_IO_ERROR,
        )
        assert_equal(put[0], UInt(0))
        stream_reclaim(cell)


def test_sink_seek_passes_through_and_failures_are_bad_seeks() raises:
    var tally = new_tally()
    var cell = stream_leak(TallySink(tally_ptr(tally)))
    var src = _bytes(10)
    var put: List[UInt] = [UInt(0)]
    _ = _write(cell, src, 10, put)
    var user = _op(cell)
    assert_equal(Int(sink_seek_tramp[TallySink](user, 2, Int32(SEEK_ORIGIN_START))), MA_SUCCESS)
    assert_equal(cell[].pos, 2)
    assert_equal(Int(sink_seek_tramp[TallySink](user, 3, Int32(SEEK_ORIGIN_CURRENT))), MA_SUCCESS)
    assert_equal(cell[].pos, 5)
    assert_equal(Int(sink_seek_tramp[TallySink](user, -1, Int32(SEEK_ORIGIN_END))), MA_SUCCESS)
    assert_equal(cell[].pos, 9)
    assert_equal(Int(sink_seek_tramp[TallySink](user, -50, Int32(SEEK_ORIGIN_START))), MA_BAD_SEEK)
    assert_equal(tally[T_SEEKS], 4)
    stream_reclaim(cell)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
