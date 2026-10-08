"""User-supplied byte streams for the decoder, encoder and codec constructors.

miniaudio can decode from, and encode to, anything that can read, write and seek
bytes: ma_decoder_init, ma_encoder_init and ma_wav_init / ma_flac_init /
ma_mp3_init take callbacks instead of a path or a memory block. Here the
callbacks are a Mojo trait. Write a struct that implements it and hand an
instance to `Decoder.from_stream`, `Encoder.to_stream`, `WavDecoder.from_stream`,
`FlacDecoder.from_stream` or `Mp3Decoder.from_stream`:

    struct MyBytes(ReadSeekTellStream):
        var data: List[UInt8]
        var pos: Int

        def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
            var n = min(len(buffer), len(self.data) - self.pos)
            for i in range(n):
                buffer[i] = self.data[self.pos + i]
            self.pos += n
            return n  # 0 means end of stream

        def seek(mut self, offset: Int64, origin: Int) raises:
            self.pos = seek_target(origin, offset, self.pos, len(self.data))

        def tell(mut self) raises -> Int64:
            return Int64(self.pos)

    var dec = Decoder.from_stream(lib, MyBytes(...))

The stream moves into the decoder / encoder, which keeps it alive on the heap for
as long as miniaudio may call it and destroys it exactly once, right after the
miniaudio object has been uninitialised. `Decoder.stream[MyBytes]()` gives the
instance back (checked against its type). miniaudio may call the stream from
whatever thread reads the decoder; it never calls it from two threads at once.

A stream method that raises is reported to miniaudio as an I/O error (the
decoder fails to open, or a read returns an error); nothing crosses the C
boundary as an exception. `MemoryReader` and `MemoryWriter` are ready-made
in-memory streams.
"""

from miniaudio.context import (
    SEEK_ORIGIN_START,
    SEEK_ORIGIN_CURRENT,
    SEEK_ORIGIN_END,
)


trait ReadSeekStream(Movable, Deinitable):
    """A readable, seekable byte stream: enough for `Decoder.from_stream`.

    `Decoder` is the one constructor that needs no `tell`; the codec
    constructors (`WavDecoder`, `FlacDecoder`, `Mp3Decoder`) require
    `ReadSeekTellStream`.
    """

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        """Fills the front of `buffer` with the next bytes, returns how many.

        Returning fewer than `len(buffer)` is fine (the library asks again for
        the rest); returning 0 means the end of the stream. Raise to report an
        I/O error. Returning more than `len(buffer)`, or a negative count, is
        treated as an I/O error.
        """
        ...

    def seek(mut self, offset: Int64, origin: Int) raises:
        """Moves the read position: `origin` is `SEEK_ORIGIN_START` (absolute),
        `SEEK_ORIGIN_CURRENT` (relative) or `SEEK_ORIGIN_END` (relative to the
        end). Raise if the position is invalid or cannot be reached."""
        ...


trait ReadSeekTellStream(ReadSeekStream):
    """A `ReadSeekStream` that can also report its position, which the wav, flac
    and mp3 backends need (dr_mp3 calls it unconditionally)."""

    def tell(mut self) raises -> Int64:
        """The current read position in bytes from the start."""
        ...


trait WriteSeekStream(Movable, Deinitable):
    """A writable, seekable byte sink: what `Encoder.to_stream` writes into.

    The WAV encoder writes the file header first and seeks back to patch the
    sizes when it is finished, so the sink must support overwriting earlier
    bytes; its contents are complete only once the encoder has finished.
    """

    def write(mut self, data: Span[UInt8, ImmutAnyOrigin]) raises -> Int:
        """Writes `data` at the current position, returns how many bytes were
        taken (all of them, normally; the library offers the rest again after a
        short write, and gives up when you take none). Raise to report an I/O
        error."""
        ...

    def seek(mut self, offset: Int64, origin: Int) raises:
        """As `ReadSeekStream.seek`."""
        ...


def seek_target(origin: Int, offset: Int64, position: Int, size: Int) raises -> Int:
    """The absolute position a seek lands on, for stream implementors.

    `position` is the current position and `size` the stream length. Raises if
    `origin` is not one of the three seek origins, or the result is negative; the
    caller decides whether past-the-end is allowed.
    """
    var base: Int
    if origin == SEEK_ORIGIN_START:
        base = 0
    elif origin == SEEK_ORIGIN_CURRENT:
        base = position
    elif origin == SEEK_ORIGIN_END:
        base = size
    else:
        raise Error("seek: unknown origin " + String(origin))
    var target = base + Int(offset)
    if target < 0:
        raise Error("seek: position before the start of the stream")
    return target


struct MemoryReader(ReadSeekTellStream):
    """Reads from an in-memory copy of some bytes (the stream analogue of
    `Decoder.from_memory`). Seeking past the end is an error."""

    var _data: List[UInt8]
    var _pos: Int

    def __init__(out self, var data: List[UInt8]):
        self._data = data^
        self._pos = 0

    def read(mut self, buffer: Span[UInt8, MutAnyOrigin]) raises -> Int:
        var n = min(len(buffer), len(self._data) - self._pos)
        for i in range(n):
            buffer[i] = self._data[self._pos + i]
        self._pos += n
        return n

    def seek(mut self, offset: Int64, origin: Int) raises:
        var target = seek_target(origin, offset, self._pos, len(self._data))
        if target > len(self._data):
            raise Error("seek: position past the end of the stream")
        self._pos = target

    def tell(mut self) raises -> Int64:
        return Int64(self._pos)

    def position(self) -> Int:
        return self._pos

    def size(self) -> Int:
        return len(self._data)


struct MemoryWriter(WriteSeekStream):
    """Collects written bytes in memory; seeking back overwrites, seeking past
    the end and writing zero-fills the gap (like a file)."""

    var _data: List[UInt8]
    var _pos: Int

    def __init__(out self):
        self._data = List[UInt8]()
        self._pos = 0

    def write(mut self, data: Span[UInt8, ImmutAnyOrigin]) raises -> Int:
        var end = self._pos + len(data)
        if end > len(self._data):
            self._data.resize(end, UInt8(0))
        for i in range(len(data)):
            self._data[self._pos + i] = data[i]
        self._pos = end
        return len(data)

    def seek(mut self, offset: Int64, origin: Int) raises:
        self._pos = seek_target(origin, offset, self._pos, len(self._data))

    def position(self) -> Int:
        return self._pos

    def size(self) -> Int:
        return len(self._data)

    def bytes(self) -> List[UInt8]:
        """A copy of everything written so far."""
        return self._data.copy()
