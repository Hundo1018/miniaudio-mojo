"""Idiomatic decoder API (Layer 3).

`Decoder` is an RAII wrapper: it owns the underlying ma_decoder, cleans up in
`__del__`, raises `Error` on failure (with rich messages), reads into
`List[Float32]`, and shares the loaded library via `ArcPointer[MaLib]` so no
`bridge` argument is ever threaded through.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END
import miniaudio._ffi.decoder_raw as raw


@fieldwise_init
struct SampleFormat(ImplicitlyCopyable, Movable, Equatable):
    """Output sample format. Codes match miniaudio's ma_format enum."""

    var code: Int

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime SAMPLE_FORMAT_UNKNOWN = SampleFormat(0)
comptime SAMPLE_FORMAT_U8 = SampleFormat(1)
comptime SAMPLE_FORMAT_S16 = SampleFormat(2)
comptime SAMPLE_FORMAT_S24 = SampleFormat(3)
comptime SAMPLE_FORMAT_S32 = SampleFormat(4)
comptime SAMPLE_FORMAT_F32 = SampleFormat(5)


struct Decoder(Movable):
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
        channels: UInt32 = 0,
        sample_rate: UInt32 = 0,
    ) raises -> Self:
        var ptr = raw.decoder_alloc(lib[])
        if ptr == null_handle():
            raise Error("decoder_alloc failed (out of memory)")
        var code = raw.decoder_init_file(
            lib[], ptr, path, format.code, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.decoder_free(lib[], ptr)
            raise Error(lib[].describe("decoder init from file failed", code))
        return Self(lib.copy(), ptr, List[UInt8]())

    @staticmethod
    def from_memory(
        lib: ArcPointer[MaLib],
        var data: List[UInt8],
        *,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        channels: UInt32 = 0,
        sample_rate: UInt32 = 0,
    ) raises -> Self:
        var ptr = raw.decoder_alloc(lib[])
        if ptr == null_handle():
            raise Error("decoder_alloc failed (out of memory)")
        var code = raw.decoder_init_memory(
            lib[], ptr, data, format.code, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.decoder_free(lib[], ptr)
            raise Error(lib[].describe("decoder init from memory failed", code))
        # `data` must outlive the decoder (miniaudio references, not copies it).
        return Self(lib.copy(), ptr, data^)

    def channels(self) -> UInt32:
        return raw.decoder_output_channels(self._lib[], self._ptr)

    def sample_rate(self) -> UInt32:
        return raw.decoder_output_sample_rate(self._lib[], self._ptr)

    def format(self) -> SampleFormat:
        return SampleFormat(raw.decoder_output_format(self._lib[], self._ptr))

    def length_in_frames(self) raises -> UInt64:
        var c = raw.decoder_get_length_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("decoder length query failed", c.result))
        return c.value

    def cursor(self) raises -> UInt64:
        var c = raw.decoder_get_cursor_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("decoder cursor query failed", c.result))
        return c.value

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.decoder_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("decoder seek failed", code))

    def read(mut self, mut out: List[Float32], frame_count: UInt64) raises -> UInt64:
        """Reads up to frame_count frames into `out`, sizing it to the result.

        `out` is resized to frames_read * channels (interleaved). Returns the
        number of frames actually read (0 at end of stream).
        """
        var ch = Int(self.channels())
        if ch == 0:
            raise Error("decoder has unknown channel count")
        out.resize(Int(frame_count) * ch, Float32(0))
        var c = raw.decoder_read_pcm_frames(self._lib[], self._ptr, out, frame_count)
        if c.result != MA_SUCCESS and c.result != MA_AT_END:
            out.resize(0, Float32(0))
            raise Error(self._lib[].describe("decoder read failed", c.result))
        out.resize(Int(c.value) * ch, Float32(0))
        return c.value

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.decoder_free(self._lib[], self._ptr)
