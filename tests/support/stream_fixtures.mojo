"""Instrumented user-defined streams for the custom-I/O tests.

`TallyBytes` (a read / seek / tell stream over some bytes) and `TallySink` (a
write / seek sink) are ordinary user types: they implement the stream traits and
nothing else, so every call miniaudio makes lands in their own methods. Each
counts its calls into a tally the test owns (a `List[Int]` the stream holds a
pointer into, so the numbers survive the stream: once a decoder owns the stream
the test can no longer reach the struct, only the tally). The destructor counts
too, which is how the tests prove a stream is destroyed exactly once and when.

The streams hold a bare pointer into the tally, and Mojo destroys a value after its
last use: a test must use its `tally` again after the last call that can reach a
stream (an assertion on a counter does), or the list may be freed under it.

Failure injection: `fail_read_at` / `fail_write_at` make the N-th (1-based) read /
write call and every one after it raise (0 = never; the field can be set later
through the stream's pointer to start failing midway); `fail_seek` / `fail_tell`
make every seek / tell raise. `chunk` caps the bytes one read hands back / one
write takes, so the library has to ask again.
"""

from miniaudio.stream import ReadSeekTellStream, WriteSeekStream, seek_target

comptime T_READS = 0
comptime T_SEEKS = 1
comptime T_TELLS = 2
comptime T_WRITES = 3
comptime T_DESTROYED = 4
comptime T_BYTES = 5  # bytes handed to miniaudio (reads) or taken from it (writes)
comptime T_SIZE = 8

comptime TallyPtr = Pointer[Int, MutUntrackedOrigin]


def new_tally() -> List[Int]:
    return List[Int](length=T_SIZE, fill=0)


def tally_ptr(mut tally: List[Int]) -> TallyPtr:
    """The counters' address; `tally` must not be resized while a stream uses it."""
    return tally.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()


struct TallyBytes(ReadSeekTellStream):
    var data: List[UInt8]
    var pos: Int
    var tally: TallyPtr
    var chunk: Int
    var fail_read_at: Int
    var fail_seek: Bool
    var fail_tell: Bool

    def __init__(
        out self,
        var data: List[UInt8],
        tally: TallyPtr,
        *,
        chunk: Int = 0,
        fail_read_at: Int = 0,
        fail_seek: Bool = False,
        fail_tell: Bool = False,
    ):
        self.data = data^
        self.pos = 0
        self.tally = tally
        self.chunk = chunk
        self.fail_read_at = fail_read_at
        self.fail_seek = fail_seek
        self.fail_tell = fail_tell

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        self.tally[unsafe_offset=T_READS] += 1
        if self.fail_read_at > 0 and self.tally[unsafe_offset=T_READS] >= self.fail_read_at:
            raise Error("injected read failure")
        var n = min(len(buffer), len(self.data) - self.pos)
        if self.chunk > 0:
            n = min(n, self.chunk)
        for i in range(n):
            buffer[i] = self.data[self.pos + i]
        self.pos += n
        self.tally[unsafe_offset=T_BYTES] += n
        return n

    def seek(mut self, offset: Int64, origin: Int) raises:
        self.tally[unsafe_offset=T_SEEKS] += 1
        if self.fail_seek:
            raise Error("injected seek failure")
        var target = seek_target(origin, offset, self.pos, len(self.data))
        if target > len(self.data):
            raise Error("seek past the end")
        self.pos = target

    def tell(mut self) raises -> Int64:
        self.tally[unsafe_offset=T_TELLS] += 1
        if self.fail_tell:
            raise Error("injected tell failure")
        return Int64(self.pos)

    def __deinit__(deinit self):
        self.tally[unsafe_offset=T_DESTROYED] += 1


struct TallySink(WriteSeekStream):
    var data: List[UInt8]
    var pos: Int
    var tally: TallyPtr
    var chunk: Int
    var fail_write_at: Int

    def __init__(out self, tally: TallyPtr, *, chunk: Int = 0, fail_write_at: Int = 0):
        self.data = List[UInt8]()
        self.pos = 0
        self.tally = tally
        self.chunk = chunk
        self.fail_write_at = fail_write_at

    def write(mut self, data: Span[UInt8, ImmutAnyOrigin]) raises -> Int:
        self.tally[unsafe_offset=T_WRITES] += 1
        if self.fail_write_at > 0 and self.tally[unsafe_offset=T_WRITES] >= self.fail_write_at:
            raise Error("injected write failure")
        var n = len(data)
        if self.chunk > 0:
            n = min(n, self.chunk)
        var end = self.pos + n
        if end > len(self.data):
            self.data.resize(end, UInt8(0))
        for i in range(n):
            self.data[self.pos + i] = data[i]
        self.pos = end
        self.tally[unsafe_offset=T_BYTES] += n
        return n

    def seek(mut self, offset: Int64, origin: Int) raises:
        self.tally[unsafe_offset=T_SEEKS] += 1
        self.pos = seek_target(origin, offset, self.pos, len(self.data))

    def __deinit__(deinit self):
        self.tally[unsafe_offset=T_DESTROYED] += 1
