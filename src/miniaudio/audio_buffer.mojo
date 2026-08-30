"""Idiomatic audio buffer API (Layer 3).

Two RAII wrappers over miniaudio's in-memory PCM buffers:

- `AudioBufferRef` over ma_audio_buffer_ref — a *view* onto frames it does not
  own. miniaudio keeps the caller's pointer verbatim, so the shim holds a copy
  of the frames for as long as the ref lives.
- `AudioBuffer` over ma_audio_buffer — the owning variant, built from a config.
  `create` keeps the shim's copy alive, `create_copy` lets miniaudio allocate
  and copy, `create_allocated` heap-allocates the buffer object itself, and
  `create_silent` produces a zero-filled buffer of the requested length.

Both are purely in-memory, so neither needs a device, engine, or file.
`__deinit__` uninits the buffer (and frees anything the shim or miniaudio
allocated for it) automatically.

Reads are copy-out and may be short: a read stops at the end of the buffer
unless `loop=True`, reporting the frame count actually delivered rather than
raising. `map_read` goes through miniaudio's map/unmap pair instead of the
read path; reaching the end there is likewise a success, not an error.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.result import MA_SUCCESS, MA_AT_END
import miniaudio._ffi.audio_buffer_raw as raw


def _frame_count(frames: List[Float32], channels: UInt32) -> UInt64:
    """Frames held by an interleaved sample list.

    A zero channel count yields 0 rather than dividing by zero; the init paths
    then reject it the same way they reject an empty frame list.
    """
    if channels == UInt32(0):
        return UInt64(0)
    return UInt64(len(frames)) // UInt64(channels)


struct AudioBufferRef(Movable):
    """Non-owning view over PCM frames (RAII). Uninits on drop."""

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
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """View `frames` (interleaved) as `channels`-channel audio."""
        var ptr = raw.audio_buffer_ref_alloc(lib[])
        if ptr == null_handle():
            raise Error("audio_buffer_ref_alloc failed (out of memory)")
        var code = raw.audio_buffer_ref_init(
            lib[], ptr, format.code, channels, frames, _frame_count(frames, channels)
        )
        if code != MA_SUCCESS:
            raw.audio_buffer_ref_free(lib[], ptr)
            raise Error(lib[].describe("audio buffer ref init failed", code))
        return Self(lib.copy(), ptr, channels)

    def set_data(mut self, frames: List[Float32]) raises:
        """Point the ref at new frames and rewind the cursor to 0."""
        var code = raw.audio_buffer_ref_set_data(
            self._lib[],
            self._ptr,
            frames,
            _frame_count(frames, self._channels),
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref set_data failed", code)
            )

    def read(mut self, frame_count: UInt64, loop: Bool = False) raises -> List[Float32]:
        """Read up to frame_count frames. The result is truncated to what was read."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))
        var rc = raw.audio_buffer_ref_read(
            self._lib[], self._ptr, buf, frame_count, loop
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref read failed", rc.result)
            )
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.audio_buffer_ref_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer ref seek failed", code))

    def map_read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read via miniaudio's map/unmap pair. Hitting the end is not an error."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))
        var rc = raw.audio_buffer_ref_map_read(
            self._lib[], self._ptr, buf, frame_count
        )
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(
                self._lib[].describe("audio buffer ref map_read failed", rc.result)
            )
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def at_end(self) raises -> Bool:
        var rc = raw.audio_buffer_ref_at_end(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref at_end failed", rc.result)
            )
        return rc.value

    def cursor(self) raises -> UInt64:
        var rc = raw.audio_buffer_ref_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref cursor failed", rc.result)
            )
        return rc.value

    def length(self) raises -> UInt64:
        var rc = raw.audio_buffer_ref_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref length failed", rc.result)
            )
        return rc.value

    def available(self) raises -> UInt64:
        """Frames left between the cursor and the end."""
        var rc = raw.audio_buffer_ref_get_available(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer ref available failed", rc.result)
            )
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.audio_buffer_ref_free(self._lib[], self._ptr)


struct AudioBuffer(Movable):
    """Owning in-memory PCM buffer (RAII). Uninits on drop."""

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
    def _finish(
        lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
        code: Int,
        action: String,
    ) raises -> Self:
        if code != MA_SUCCESS:
            raw.audio_buffer_free(lib[], ptr)
            raise Error(lib[].describe(action, code))
        return Self(lib.copy(), ptr, channels)

    @staticmethod
    def _new_handle(lib: ArcPointer[MaLib]) raises -> OpaquePointer[MutUntrackedOrigin]:
        var ptr = raw.audio_buffer_alloc(lib[])
        if ptr == null_handle():
            raise Error("audio_buffer_alloc failed (out of memory)")
        return ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """Non-copying init — the shim keeps the frames alive for miniaudio."""
        var ptr = Self._new_handle(lib)
        var code = raw.audio_buffer_init(
            lib[], ptr, format.code, channels, frames, _frame_count(frames, channels)
        )
        return Self._finish(lib, ptr, channels, code, "audio buffer init failed")

    @staticmethod
    def create_copy(
        lib: ArcPointer[MaLib],
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """Copying init — miniaudio allocates and owns its own copy of the frames."""
        var ptr = Self._new_handle(lib)
        var code = raw.audio_buffer_init_copy(
            lib[], ptr, format.code, channels, frames, _frame_count(frames, channels)
        )
        return Self._finish(lib, ptr, channels, code, "audio buffer init_copy failed")

    @staticmethod
    def create_silent(
        lib: ArcPointer[MaLib],
        frame_count: UInt64,
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """A zero-filled buffer of frame_count frames."""
        var ptr = Self._new_handle(lib)
        var code = raw.audio_buffer_init_copy_silent(
            lib[], ptr, format.code, channels, frame_count
        )
        return Self._finish(lib, ptr, channels, code, "audio buffer init_copy failed")

    @staticmethod
    def create_allocated(
        lib: ArcPointer[MaLib],
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises -> Self:
        """Heap-allocate the buffer object itself, frames in its trailing storage.

        Upstream defect (miniaudio 0.11.25): this path clears the low 3 bytes of
        the first frame — see the note in ma_shim_audio_buffer.h. Prefer
        `create_copy` when the first frame matters.
        """
        var ptr = Self._new_handle(lib)
        var code = raw.audio_buffer_alloc_and_init(
            lib[], ptr, format.code, channels, frames, _frame_count(frames, channels)
        )
        return Self._finish(
            lib, ptr, channels, code, "audio buffer alloc_and_init failed"
        )

    def read(mut self, frame_count: UInt64, loop: Bool = False) raises -> List[Float32]:
        """Read up to frame_count frames. The result is truncated to what was read."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))
        var rc = raw.audio_buffer_read(self._lib[], self._ptr, buf, frame_count, loop)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.audio_buffer_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer seek failed", code))

    def map_read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read via miniaudio's map/unmap pair. Hitting the end is not an error."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))
        var rc = raw.audio_buffer_map_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(
                self._lib[].describe("audio buffer map_read failed", rc.result)
            )
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def at_end(self) raises -> Bool:
        var rc = raw.audio_buffer_at_end(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer at_end failed", rc.result))
        return rc.value

    def cursor(self) raises -> UInt64:
        var rc = raw.audio_buffer_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer cursor failed", rc.result))
        return rc.value

    def length(self) raises -> UInt64:
        var rc = raw.audio_buffer_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer length failed", rc.result))
        return rc.value

    def available(self) raises -> UInt64:
        """Frames left between the cursor and the end."""
        var rc = raw.audio_buffer_get_available(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("audio buffer available failed", rc.result)
            )
        return rc.value

    def uninit(mut self) raises:
        """Release the underlying buffer early; the handle stays valid but empty."""
        var code = raw.audio_buffer_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("audio buffer uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.audio_buffer_free(self._lib[], self._ptr)
