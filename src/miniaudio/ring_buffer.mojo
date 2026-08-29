"""Idiomatic ring buffer API (Layer 3).

Two RAII wrappers over miniaudio's lock-free single-producer/single-consumer
ring buffers:

- `RingBuffer` over ma_rb — untyped, sized in bytes.
- `PcmRingBuffer` over ma_pcm_rb — PCM-aware, sized in frames, carrying a
  format / channel count / sample rate.

Both are purely in-memory, so neither needs a device, engine, or file.
`__deinit__` uninits the buffer (and releases any shim-owned preallocated backing
store) automatically.

Writes and reads are copy-in / copy-out and may be short: a write stops when the
buffer is full and a read stops when it runs empty, both reporting the count
actually transferred rather than raising.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.ring_buffer_raw as raw


@fieldwise_init
struct PcmRingBufferFormat(Copyable, Movable):
    """The (format, channels, sample_rate) a PcmRingBuffer was configured with."""

    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


struct RingBuffer(Movable):
    """Byte-oriented ring buffer (RAII). Owns its shim handle; uninits on drop."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib], buffer_size_in_bytes: UInt64) raises -> Self:
        """Create a single-subbuffer ring buffer of `buffer_size_in_bytes` bytes."""
        var ptr = raw.rb_alloc(lib[])
        if ptr == null_handle():
            raise Error("rb_alloc failed (out of memory)")
        var code = raw.rb_init(lib[], ptr, buffer_size_in_bytes)
        if code != MA_SUCCESS:
            raw.rb_free(lib[], ptr)
            raise Error(lib[].describe("ring buffer init failed", code))
        return Self(lib.copy(), ptr)

    @staticmethod
    def create_ex(
        lib: ArcPointer[MaLib],
        *,
        subbuffer_size_in_bytes: UInt64,
        subbuffer_count: UInt64 = 1,
        subbuffer_stride_in_bytes: UInt64 = 0,
        use_preallocated: Bool = False,
    ) raises -> Self:
        """Create a multi-subbuffer ring buffer.

        A stride of 0 lets miniaudio pick one (the sub-buffer size rounded up for
        SIMD alignment). `use_preallocated` routes init through miniaudio's
        preallocated-buffer path with a shim-owned backing store.
        """
        var ptr = raw.rb_alloc(lib[])
        if ptr == null_handle():
            raise Error("rb_alloc failed (out of memory)")
        var code = raw.rb_init_ex(
            lib[],
            ptr,
            subbuffer_size_in_bytes,
            subbuffer_count,
            subbuffer_stride_in_bytes,
            use_preallocated,
        )
        if code != MA_SUCCESS:
            raw.rb_free(lib[], ptr)
            raise Error(lib[].describe("ring buffer init_ex failed", code))
        return Self(lib.copy(), ptr)

    def write(mut self, src: List[UInt8]) raises -> UInt64:
        """Write as much of `src` as fits. Returns the byte count actually written."""
        var rc = raw.rb_write(self._lib[], self._ptr, src, UInt64(len(src)))
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("ring buffer write failed", rc.result))
        return rc.value

    def read(mut self, size_in_bytes: UInt64) raises -> List[UInt8]:
        """Read up to size_in_bytes. The returned list is truncated to what was read."""
        var buf = List[UInt8](capacity=Int(size_in_bytes))
        buf.resize(Int(size_in_bytes), UInt8(0))
        var rc = raw.rb_read(self._lib[], self._ptr, buf, size_in_bytes)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("ring buffer read failed", rc.result))
        buf.resize(Int(rc.value), UInt8(0))
        return buf^

    def reset(mut self) raises:
        """Reset both pointers, discarding any buffered data."""
        var code = raw.rb_reset(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("ring buffer reset failed", code))

    def seek_read(mut self, offset_in_bytes: UInt64) raises:
        var code = raw.rb_seek_read(self._lib[], self._ptr, offset_in_bytes)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("ring buffer seek_read failed", code))

    def seek_write(mut self, offset_in_bytes: UInt64) raises:
        var code = raw.rb_seek_write(self._lib[], self._ptr, offset_in_bytes)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("ring buffer seek_write failed", code))

    def pointer_distance(self) raises -> Int:
        """Bytes between the write and read pointers (readable without blocking)."""
        var rc = raw.rb_pointer_distance(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer pointer_distance failed", rc.result)
            )
        return rc.value

    def available_read(self) raises -> UInt32:
        var rc = raw.rb_available_read(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer available_read failed", rc.result)
            )
        return rc.value

    def available_write(self) raises -> UInt32:
        var rc = raw.rb_available_write(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer available_write failed", rc.result)
            )
        return rc.value

    def subbuffer_size(self) raises -> UInt64:
        var rc = raw.rb_get_subbuffer_size(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer subbuffer_size failed", rc.result)
            )
        return rc.value

    def subbuffer_stride(self) raises -> UInt64:
        var rc = raw.rb_get_subbuffer_stride(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer subbuffer_stride failed", rc.result)
            )
        return rc.value

    def subbuffer_offset(self, subbuffer_index: UInt64) raises -> UInt64:
        """Byte offset of subbuffer N from the start of the backing store."""
        var rc = raw.rb_get_subbuffer_offset(self._lib[], self._ptr, subbuffer_index)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("ring buffer subbuffer_offset failed", rc.result)
            )
        return rc.value

    def subbuffer_ptr_offset(self, subbuffer_index: UInt64) raises -> UInt64:
        """Byte offset of subbuffer N's pointer — the address, expressed safely."""
        var rc = raw.rb_get_subbuffer_ptr_offset(
            self._lib[], self._ptr, subbuffer_index
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "ring buffer subbuffer_ptr_offset failed", rc.result
                )
            )
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.rb_free(self._lib[], self._ptr)


struct PcmRingBuffer(Movable):
    """Frame-oriented ring buffer (RAII). Owns its shim handle; uninits on drop."""

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
        format: Int = 5,
        channels: UInt32 = 1,
        buffer_size_in_frames: UInt32,
    ) raises -> Self:
        """Create a single-subbuffer PCM ring buffer. format 5 = f32."""
        var ptr = raw.pcm_rb_alloc(lib[])
        if ptr == null_handle():
            raise Error("pcm_rb_alloc failed (out of memory)")
        var code = raw.pcm_rb_init(
            lib[], ptr, format, channels, buffer_size_in_frames
        )
        if code != MA_SUCCESS:
            raw.pcm_rb_free(lib[], ptr)
            raise Error(lib[].describe("pcm ring buffer init failed", code))
        return Self(lib.copy(), ptr, channels)

    @staticmethod
    def create_ex(
        lib: ArcPointer[MaLib],
        *,
        format: Int = 5,
        channels: UInt32 = 1,
        subbuffer_size_in_frames: UInt32,
        subbuffer_count: UInt32 = 1,
        subbuffer_stride_in_frames: UInt32 = 0,
        use_preallocated: Bool = False,
    ) raises -> Self:
        """Create a multi-subbuffer PCM ring buffer (see RingBuffer.create_ex)."""
        var ptr = raw.pcm_rb_alloc(lib[])
        if ptr == null_handle():
            raise Error("pcm_rb_alloc failed (out of memory)")
        var code = raw.pcm_rb_init_ex(
            lib[],
            ptr,
            format,
            channels,
            subbuffer_size_in_frames,
            subbuffer_count,
            subbuffer_stride_in_frames,
            use_preallocated,
        )
        if code != MA_SUCCESS:
            raw.pcm_rb_free(lib[], ptr)
            raise Error(lib[].describe("pcm ring buffer init_ex failed", code))
        return Self(lib.copy(), ptr, channels)

    def write_frames(mut self, src: List[Float32]) raises -> UInt32:
        """Write interleaved f32 frames. Returns the frame count actually written."""
        var frames = UInt32(len(src) // Int(self._channels))
        var rc = raw.pcm_rb_write(self._lib[], self._ptr, src, frames)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("pcm ring buffer write failed", rc.result)
            )
        return rc.value

    def read_frames(mut self, frame_count: UInt32) raises -> List[Float32]:
        """Read up to frame_count frames as interleaved f32 samples."""
        var n = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=n)
        buf.resize(n, Float32(0))
        var rc = raw.pcm_rb_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("pcm ring buffer read failed", rc.result)
            )
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def reset(mut self) raises:
        var code = raw.pcm_rb_reset(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pcm ring buffer reset failed", code))

    def seek_read(mut self, offset_in_frames: UInt32) raises:
        var code = raw.pcm_rb_seek_read(self._lib[], self._ptr, offset_in_frames)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("pcm ring buffer seek_read failed", code)
            )

    def seek_write(mut self, offset_in_frames: UInt32) raises:
        var code = raw.pcm_rb_seek_write(self._lib[], self._ptr, offset_in_frames)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("pcm ring buffer seek_write failed", code)
            )

    def pointer_distance(self) raises -> Int:
        """Frames between the write and read pointers."""
        var rc = raw.pcm_rb_pointer_distance(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer pointer_distance failed", rc.result
                )
            )
        return rc.value

    def available_read(self) raises -> UInt32:
        var rc = raw.pcm_rb_available_read(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer available_read failed", rc.result
                )
            )
        return rc.value

    def available_write(self) raises -> UInt32:
        var rc = raw.pcm_rb_available_write(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer available_write failed", rc.result
                )
            )
        return rc.value

    def subbuffer_size(self) raises -> UInt32:
        var rc = raw.pcm_rb_get_subbuffer_size(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer subbuffer_size failed", rc.result
                )
            )
        return rc.value

    def subbuffer_stride(self) raises -> UInt32:
        var rc = raw.pcm_rb_get_subbuffer_stride(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer subbuffer_stride failed", rc.result
                )
            )
        return rc.value

    def subbuffer_offset(self, subbuffer_index: UInt32) raises -> UInt32:
        """Frame offset of subbuffer N (frames, unlike the byte-valued ptr offset)."""
        var rc = raw.pcm_rb_get_subbuffer_offset(
            self._lib[], self._ptr, subbuffer_index
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer subbuffer_offset failed", rc.result
                )
            )
        return rc.value

    def subbuffer_ptr_offset(self, subbuffer_index: UInt32) raises -> UInt64:
        """Byte offset of subbuffer N's pointer from the backing store."""
        var rc = raw.pcm_rb_get_subbuffer_ptr_offset(
            self._lib[], self._ptr, subbuffer_index
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer subbuffer_ptr_offset failed", rc.result
                )
            )
        return rc.value

    def data_format(self) raises -> PcmRingBufferFormat:
        var rc = raw.pcm_rb_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "pcm ring buffer data_format failed", rc.result
                )
            )
        return PcmRingBufferFormat(rc.format, rc.channels, rc.sample_rate)

    def set_sample_rate(mut self, sample_rate: UInt32) raises:
        var code = raw.pcm_rb_set_sample_rate(self._lib[], self._ptr, sample_rate)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("pcm ring buffer set_sample_rate failed", code)
            )

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.pcm_rb_free(self._lib[], self._ptr)
