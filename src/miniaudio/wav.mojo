"""Idiomatic ma_wav API (Layer 3).

`WavDecoder` is an RAII wrapper over miniaudio's built-in WAV decoder backend
(`ma_wav`), used directly rather than through `Decoder`: there is no output
conversion, so frames come back with the file's own channel count and sample
rate. It owns the underlying object, cleans up in `__deinit__`, raises `Error`
on failure and shares the loaded library via `ArcPointer[MaLib]`.

The sample format defaults to f32 (so `read` works out of the box); pass
`SAMPLE_FORMAT_UNKNOWN` to keep the file's native format, or s16 / s32. `read`
is for f32 streams and `read_s16` for s16 ones; a mismatch raises.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32, SAMPLE_FORMAT_S16
from miniaudio.data_source import DataFormat
import miniaudio._ffi.wav_raw as raw


struct WavDecoder(Movable):
    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _memory: List[UInt8]  # keeps init_memory backing alive; empty for files

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        var memory: List[UInt8],
    ):
        self._lib = lib^
        self._ptr = ptr
        self._memory = memory^

    @staticmethod
    def from_file(
        lib: ArcPointer[MaLib],
        path: String,
        *,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        seek_points: UInt32 = 0,
    ) raises -> Self:
        var ptr = raw.wav_alloc(lib[])
        if ptr == null_handle():
            raise Error("wav_alloc failed (out of memory)")
        var code = raw.wav_init_file(lib[], ptr, path, format.code, seek_points)
        if code != MA_SUCCESS:
            raw.wav_free(lib[], ptr)
            raise Error(lib[].describe("wav init from file failed", code))
        return Self(lib.copy(), ptr, List[UInt8]())

    @staticmethod
    def from_memory(
        lib: ArcPointer[MaLib],
        var data: List[UInt8],
        *,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        seek_points: UInt32 = 0,
    ) raises -> Self:
        var ptr = raw.wav_alloc(lib[])
        if ptr == null_handle():
            raise Error("wav_alloc failed (out of memory)")
        var code = raw.wav_init_memory(lib[], ptr, data, format.code, seek_points)
        if code != MA_SUCCESS:
            raw.wav_free(lib[], ptr)
            raise Error(lib[].describe("wav init from memory failed", code))
        # `data` must outlive the decoder (miniaudio references, not copies it).
        return Self(lib.copy(), ptr, data^)

    def data_format(self) raises -> DataFormat:
        var f = raw.wav_get_data_format(self._lib[], self._ptr)
        if f.result != MA_SUCCESS:
            raise Error(self._lib[].describe("wav data format query failed", f.result))
        return DataFormat(f.format, f.channels, f.sample_rate)

    def format(self) raises -> SampleFormat:
        return SampleFormat(self.data_format().format)

    def channels(self) raises -> UInt32:
        return self.data_format().channels

    def sample_rate(self) raises -> UInt32:
        return self.data_format().sample_rate

    def channel_map(self) raises -> List[UInt8]:
        """The miniaudio channel map (one ma_channel code per channel)."""
        var n = self.data_format().channels
        var m = raw.wav_get_channel_map(self._lib[], self._ptr, n)
        if m.result != MA_SUCCESS:
            raise Error(self._lib[].describe("wav channel map query failed", m.result))
        return m.value.copy()

    def length_in_frames(self) raises -> UInt64:
        var c = raw.wav_get_length_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("wav length query failed", c.result))
        return c.value

    def cursor(self) raises -> UInt64:
        var c = raw.wav_get_cursor_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("wav cursor query failed", c.result))
        return c.value

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.wav_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("wav seek failed", code))

    def read(mut self, mut out: List[Float32], frame_count: UInt64) raises -> UInt64:
        """Reads up to frame_count f32 frames into `out`, sizing it to the result.

        `out` is resized to frames_read * channels (interleaved). Returns the
        number of frames actually read (0 at end of stream). Raises if the
        stream's format is not f32 (use `read_s16`, or open with f32).
        """
        var f = self.data_format()
        if f.format != SAMPLE_FORMAT_F32.code:
            raise Error("wav read: stream format is not f32; open with format=f32 or use read_s16")
        var ch = Int(f.channels)
        out.resize(Int(frame_count) * ch, Float32(0))
        var c = raw.wav_read_pcm_frames(self._lib[], self._ptr, out, frame_count)
        if c.result != MA_SUCCESS and c.result != MA_AT_END:
            out.resize(0, Float32(0))
            raise Error(self._lib[].describe("wav read failed", c.result))
        out.resize(Int(c.value) * ch, Float32(0))
        return c.value

    def read_s16(mut self, mut out: List[Int16], frame_count: UInt64) raises -> UInt64:
        """As `read`, for a stream opened with format=s16."""
        var f = self.data_format()
        if f.format != SAMPLE_FORMAT_S16.code:
            raise Error("wav read_s16: stream format is not s16; open with format=s16")
        var ch = Int(f.channels)
        out.resize(Int(frame_count) * ch, Int16(0))
        var c = raw.wav_read_pcm_frames_s16(self._lib[], self._ptr, out, frame_count)
        if c.result != MA_SUCCESS and c.result != MA_AT_END:
            out.resize(0, Int16(0))
            raise Error(self._lib[].describe("wav read failed", c.result))
        out.resize(Int(c.value) * ch, Int16(0))
        return c.value

    def uninit(mut self) raises:
        """Release the decoder early; the handle stays valid but unusable."""
        var code = raw.wav_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("wav uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.wav_free(self._lib[], self._ptr)
