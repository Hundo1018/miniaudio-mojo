"""Idiomatic paged audio buffer API (Layer 3).

`PagedAudioBuffer` is a RAII wrapper over miniaudio's expandable page list plus
the reader that walks it. Pages can be appended while the buffer is being read
— that is the point of the type — and the list is expandable but never shrinks.
It is purely in-memory, so no device, engine, or file is involved.

Appending is available in two shapes:

- `append` allocates a page and links it in one step (the common case).
- `allocate_page` parks a page in a slot on the handle without linking it, and
  `append_allocated` / `free_allocated` take that slot back. This mirrors
  miniaudio's split, where a page can be prepared ahead of the append.

A slot still holding a page when the buffer is dropped is released with it.
`__deinit__` uninits the reader and frees every page.

Reads are copy-out and may be short: running out of pages reports the frames
actually delivered rather than raising.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.result import MA_SUCCESS, MA_AT_END
import miniaudio._ffi.paged_audio_buffer_raw as raw


@fieldwise_init
struct PageInfo(Copyable, Movable):
    """What a page getter can say about a page without handing out its pointer."""

    var frames: UInt64
    var list_is_empty: Bool


struct PagedAudioBuffer(Movable):
    """Expandable list of PCM pages plus a reader over it (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """An empty page list with a reader attached. Append pages to fill it."""
        var ptr = raw.paged_audio_buffer_alloc(lib[])
        if ptr == null_handle():
            raise Error("paged_audio_buffer_alloc failed (out of memory)")

        var code = raw.paged_audio_buffer_data_init(lib[], ptr, format.code, channels)
        if code != MA_SUCCESS:
            raw.paged_audio_buffer_free(lib[], ptr)
            raise Error(lib[].describe("paged audio buffer data init failed", code))

        code = raw.paged_audio_buffer_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.paged_audio_buffer_free(lib[], ptr)
            raise Error(lib[].describe("paged audio buffer init failed", code))
        return Self(lib.copy(), ptr, channels)

    def _frames_of(self, frames: List[Float32]) -> UInt64:
        if self._channels == UInt32(0):
            return UInt64(0)
        return UInt64(len(frames)) // UInt64(self._channels)

    def append(mut self, frames: List[Float32]) raises:
        """Allocate a page holding `frames` and link it onto the end of the list."""
        var code = raw.paged_audio_buffer_data_allocate_and_append_page(
            self._lib[], self._ptr, frames, UInt32(self._frames_of(frames))
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("paged audio buffer append failed", code))

    def allocate_page(mut self, frames: List[Float32]) raises -> Int:
        """Prepare a page without linking it. Returns the slot holding it."""
        var rc = raw.paged_audio_buffer_data_allocate_page(
            self._lib[], self._ptr, frames, self._frames_of(frames)
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer allocate_page failed", rc.result)
            )
        return rc.value

    def append_allocated(mut self, slot: Int) raises:
        """Link the page parked in `slot`; the list owns it afterwards."""
        var code = raw.paged_audio_buffer_data_append_page(self._lib[], self._ptr, slot)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer append_page failed", code)
            )

    def free_allocated(mut self, slot: Int) raises:
        """Discard the page parked in `slot` without linking it."""
        var code = raw.paged_audio_buffer_data_free_page(self._lib[], self._ptr, slot)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer free_page failed", code)
            )

    def head(self) raises -> PageInfo:
        """miniaudio's zero-length head dummy, and whether anything follows it."""
        var rc = raw.paged_audio_buffer_data_get_head(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("paged audio buffer head failed", rc.result))
        return PageInfo(rc.frames, rc.list_is_empty)

    def tail(self) raises -> PageInfo:
        """The last appended page, or the head dummy while the list is empty."""
        var rc = raw.paged_audio_buffer_data_get_tail(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("paged audio buffer tail failed", rc.result))
        return PageInfo(rc.frames, rc.list_is_empty)

    def data_length(self) raises -> UInt64:
        """Total frames across every appended page."""
        var rc = raw.paged_audio_buffer_data_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer data length failed", rc.result)
            )
        return rc.value

    def read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read up to frame_count frames. Running out of pages is not an error."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))
        var rc = raw.paged_audio_buffer_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("paged audio buffer read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.paged_audio_buffer_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("paged audio buffer seek failed", code))

    def cursor(self) raises -> UInt64:
        var rc = raw.paged_audio_buffer_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer cursor failed", rc.result)
            )
        return rc.value

    def length(self) raises -> UInt64:
        """Length the reader sees — the same total the page list reports."""
        var rc = raw.paged_audio_buffer_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer length failed", rc.result)
            )
        return rc.value

    def uninit_reader(mut self) raises:
        """Release the reader early; the page list stays intact."""
        var code = raw.paged_audio_buffer_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer reader uninit failed", code)
            )

    def clear(mut self) raises:
        """Drop the reader and every page, leaving the handle empty."""
        var code = raw.paged_audio_buffer_data_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("paged audio buffer data uninit failed", code)
            )

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.paged_audio_buffer_free(self._lib[], self._ptr)
