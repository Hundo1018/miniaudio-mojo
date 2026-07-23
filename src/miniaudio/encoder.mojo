"""Idiomatic encoder API (Layer 3).

`Encoder` is an RAII wrapper around ma_encoder (WAV output): it owns the
underlying handle, cleans up in `__del__` (which flushes/finalises the file),
raises `Error` on failure, and writes interleaved `List[Float32]` frames. The
loaded library is shared via `ArcPointer[MaLib]` — no `bridge` argument is
threaded through. Mirrors the decoder slice (decoder.mojo).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
import miniaudio._ffi.encoder_raw as raw


@fieldwise_init
struct EncodingFormat(ImplicitlyCopyable, Movable, Equatable):
    """Container encoding format. Codes match miniaudio's ma_encoding_format."""

    var code: Int

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime ENCODING_FORMAT_UNKNOWN = EncodingFormat(0)
comptime ENCODING_FORMAT_WAV = EncodingFormat(1)


struct Encoder(Movable):
    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32  # needed to derive frame_count from interleaved input

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
    def to_file(
        lib: ArcPointer[MaLib],
        path: String,
        *,
        channels: UInt32,
        sample_rate: UInt32,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        encoding_format: EncodingFormat = ENCODING_FORMAT_WAV,
    ) raises -> Self:
        var ptr = raw.encoder_alloc(lib[])
        if ptr == null_handle():
            raise Error("encoder_alloc failed (out of memory)")
        var code = raw.encoder_init_file(
            lib[], ptr, path, encoding_format.code, format.code, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.encoder_free(lib[], ptr)
            raise Error(lib[].describe("encoder init to file failed", code))
        return Self(lib.copy(), ptr, channels)

    @staticmethod
    def to_file_vfs(
        lib: ArcPointer[MaLib],
        path: String,
        *,
        channels: UInt32,
        sample_rate: UInt32,
        format: SampleFormat = SAMPLE_FORMAT_F32,
        encoding_format: EncodingFormat = ENCODING_FORMAT_WAV,
    ) raises -> Self:
        """Open an output file through miniaudio's default (stdio) VFS.

        Behaves like `to_file` but routes I/O through the VFS abstraction with a
        NULL ma_vfs (default filesystem). The dedicated VFS family is not yet
        modeled; this is the bindable slice of ma_encoder_init_vfs.
        """
        var ptr = raw.encoder_alloc(lib[])
        if ptr == null_handle():
            raise Error("encoder_alloc failed (out of memory)")
        var code = raw.encoder_init_file_vfs(
            lib[], ptr, path, encoding_format.code, format.code, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.encoder_free(lib[], ptr)
            raise Error(lib[].describe("encoder init to file (vfs) failed", code))
        return Self(lib.copy(), ptr, channels)

    def channels(self) -> UInt32:
        return self._channels

    def write(mut self, frames: List[Float32]) raises -> UInt64:
        """Writes interleaved frames; returns the number of frames written.

        `frames` is interleaved (len == frame_count * channels). The frame
        count is derived from the channel count fixed at `to_file`.
        """
        var ch = Int(self._channels)
        if ch == 0:
            raise Error("encoder has unknown channel count")
        var frame_count = UInt64(len(frames) // ch)
        var c = raw.encoder_write_pcm_frames(self._lib[], self._ptr, frames, frame_count)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("encoder write failed", c.result))
        return c.value

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.encoder_free(self._lib[], self._ptr)
