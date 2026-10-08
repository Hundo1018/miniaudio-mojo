"""Binding layer: the Mojo callbacks and ownership plumbing behind user streams.

The shim (src/native/ma_shim_stream.h) calls user streams through plain C
function pointers shaped `(user, ...)`. This module is what those pointers point
at: one generic trampoline per callback, instantiated for the user's stream type
`S` and handed to the shim at the init call. It also moves a stream onto the
heap (the C side keeps a raw pointer to it, so a stack value would be destroyed
too early) and back off it.

Trampolines never raise: whatever the stream does, the C caller gets a ma_result
code. A read or write always stores the byte count it reports, because
miniaudio's codecs read it even after a failure. They also complete short
transfers themselves (see `stream_read_tramp`), because miniaudio's parsers
take a short read for the end of the data.

Result codes (ma_result): 0 success; -17 MA_AT_END for a read that returns no
bytes; -20 MA_IO_ERROR for a stream method that raises or reports a count it
cannot have; -25 MA_BAD_SEEK for a seek that raises.
"""

from std.memory import Layout, Allocation, dealloc
from std.reflection import reflect

from miniaudio.stream import ReadSeekStream, ReadSeekTellStream, WriteSeekStream
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_IO_ERROR

comptime Opaque = OpaquePointer[MutUntrackedOrigin]
comptime StreamPtr[S: AnyType] = Pointer[S, MutUntrackedOrigin]

comptime MA_BAD_SEEK = Int(-25)


# ---- ownership --------------------------------------------------------------


def stream_tag[S: AnyType]() -> UInt64:
    """An identifier for the type `S`, handed to the shim with the stream so a
    typed view of it can be checked later."""
    return UInt64(hash(reflect[S].name()))


def stream_null_ptr[S: AnyType]() -> StreamPtr[S]:
    """A null typed stream pointer, to exercise the shim's argument checks."""
    return StreamPtr[S](unsafe_from_address=Int(0))


def stream_leak[S: Movable & Deinitable](var stream: S) -> StreamPtr[S]:
    """Moves `stream` to a fresh heap cell and returns the cell's address. The
    caller owns it from here: it must reach `stream_reclaim[S]` or be handed to
    the shim, whose destroy callback (`stream_destroy[S]`) does the same."""
    var allocation = alloc(Layout[S](count=1))
    var cell = allocation^.unsafe_leak()
    cell.unsafe_write(stream^)
    return StreamPtr[S](unsafe_from_address=Int(cell))


def stream_reclaim[S: Movable & Deinitable](cell: StreamPtr[S]):
    """Destroys the stream in a heap cell from `stream_leak` and frees the cell."""
    var value = cell.unsafe_take_pointee()
    _ = value^
    dealloc(Allocation[S](unsafe_owned_ptr=cell, layout=Layout[S](count=1)))


def stream_take[S: Movable & Deinitable](cell: StreamPtr[S]) -> S:
    """Moves the stream out of a heap cell from `stream_leak` and frees the cell."""
    var value = cell.unsafe_take_pointee()
    dealloc(Allocation[S](unsafe_owned_ptr=cell, layout=Layout[S](count=1)))
    return value^


def stream_destroy[S: Movable & Deinitable](user: Opaque):
    """The shim's destroy callback for a stream of type `S`."""
    stream_reclaim[S](user.unsafe_bitcast[S]())


# ---- callbacks (the shim calls these through function pointers) -------------


def stream_read_tramp[
    S: ReadSeekStream
](user: Opaque, buffer: Opaque, count: UInt, bytes_read: Opaque) -> Int32:
    """Fills `buffer` from the stream like fread: it keeps asking the stream until
    `count` bytes have arrived or the stream ends, so a stream may hand back
    short reads (miniaudio's parsers take any short read for the end of the data).

    Reports MA_SUCCESS with the bytes gathered if there are any, even when the
    stream then ended or failed (a persistent failure shows on the next call);
    with none, MA_AT_END at the end of the stream, MA_IO_ERROR for a stream that
    raised or returned a count it cannot have.
    """
    var want = Int(count)
    var base = buffer.unsafe_bitcast[UInt8]()
    var stream = user.unsafe_bitcast[S]()
    var total = 0
    var failed = False
    while total < want:
        try:
            var span = Span[UInt8, MutAnyOrigin](
                unsafe_ptr=base.unsafe_offset(total).unsafe_origin_cast[MutAnyOrigin](),
                length=want - total,
            )
            var got = stream[].read(span)
            if got < 0 or got > want - total:
                failed = True
                break
            if got == 0:
                break
            total += got
        except:
            failed = True
            break
    bytes_read.unsafe_bitcast[UInt]()[unsafe_offset=0] = UInt(total)
    if total > 0 or want == 0:
        return Int32(MA_SUCCESS)
    return Int32(MA_IO_ERROR) if failed else Int32(MA_AT_END)


def stream_seek_tramp[
    S: ReadSeekStream
](user: Opaque, offset: Int64, origin: Int32) -> Int32:
    try:
        user.unsafe_bitcast[S]()[].seek(offset, Int(origin))
        return Int32(MA_SUCCESS)
    except:
        return Int32(MA_BAD_SEEK)


def stream_tell_tramp[
    S: ReadSeekTellStream
](user: Opaque, cursor: Opaque) -> Int32:
    try:
        var position = user.unsafe_bitcast[S]()[].tell()
        cursor.unsafe_bitcast[Int64]()[unsafe_offset=0] = position
        return Int32(MA_SUCCESS)
    except:
        return Int32(MA_IO_ERROR)


def sink_write_tramp[
    S: WriteSeekStream
](user: Opaque, buffer: Opaque, count: UInt, bytes_written: Opaque) -> Int32:
    """Drains `buffer` into the sink like fwrite: it keeps offering the rest until
    all `count` bytes are taken, so a sink may take less than it is given.

    Reports MA_SUCCESS with the bytes taken if there are any, even when the sink
    then stalled or failed (miniaudio sees the short count; a persistent failure
    shows on the next call); with none, MA_IO_ERROR.
    """
    var want = Int(count)
    var base = buffer.unsafe_bitcast[UInt8]()
    var stream = user.unsafe_bitcast[S]()
    var total = 0
    while total < want:
        try:
            var span = Span[UInt8, ImmutAnyOrigin](
                unsafe_ptr=base.unsafe_offset(total).unsafe_origin_cast[MutAnyOrigin](),
                length=want - total,
            )
            var put = stream[].write(span)
            if put <= 0 or put > want - total:
                break
            total += put
        except:
            break
    bytes_written.unsafe_bitcast[UInt]()[unsafe_offset=0] = UInt(total)
    if total > 0 or want == 0:
        return Int32(MA_SUCCESS)
    return Int32(MA_IO_ERROR)


def sink_seek_tramp[
    S: WriteSeekStream
](user: Opaque, offset: Int64, origin: Int32) -> Int32:
    try:
        user.unsafe_bitcast[S]()[].seek(offset, Int(origin))
        return Int32(MA_SUCCESS)
    except:
        return Int32(MA_BAD_SEEK)
