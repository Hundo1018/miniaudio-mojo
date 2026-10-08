"""Idiomatic one-shot decode API (Layer 3).

`decode_file`, `decode_memory` and `decode_from_vfs` decode a whole stream in
one call and return a `DecodedAudio`. The decoded buffer is allocated by
miniaudio; `DecodedAudio` owns it and releases it in `__deinit__`, so callers
never see a raw pointer to free. Read the samples with `samples_f32` /
`samples_s16` (according to `format`).

`format`, `channels` and `sample_rate` ask for output conversion; leave them at
their defaults (f32, 0, 0) to keep the stream's native channel count and sample
rate (0 means "native"; pass `SAMPLE_FORMAT_UNKNOWN` to keep the native format
too). The `DecodedAudio` fields report what the buffer actually holds.

`decoding_backend_config` exposes the small config struct the built-in
wav / flac / mp3 backends take (preferred format and seek-table size).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32, SAMPLE_FORMAT_S16
from miniaudio.context import Vfs
import miniaudio._ffi.decode_util_raw as raw


@fieldwise_init
struct DecodingBackendConfig(Copyable, Movable):
    """The ma_decoding_backend_config struct: preferred sample format + seek-table size."""

    var preferred_format: SampleFormat
    var seek_point_count: UInt32


def decoding_backend_config(
    lib: ArcPointer[MaLib],
    preferred_format: SampleFormat,
    seek_point_count: UInt32 = 0,
) raises -> DecodingBackendConfig:
    var c = raw.decoding_backend_config_init(
        lib[], preferred_format.code, seek_point_count
    )
    if c.result != MA_SUCCESS:
        raise Error(lib[].describe("decoding backend config init failed", c.result))
    return DecodingBackendConfig(SampleFormat(c.preferred_format), c.seek_point_count)


struct DecodedAudio(Movable):
    """A fully decoded stream (RAII): owns the buffer miniaudio allocated."""

    var _lib: ArcPointer[MaLib]
    var _frames: OpaquePointer[MutUntrackedOrigin]
    var frame_count: UInt64
    var format: SampleFormat
    var channels: UInt32
    var sample_rate: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        frames: OpaquePointer[MutUntrackedOrigin],
        frame_count: UInt64,
        format: SampleFormat,
        channels: UInt32,
        sample_rate: UInt32,
    ):
        self._lib = lib^
        self._frames = frames
        self.frame_count = frame_count
        self.format = format
        self.channels = channels
        self.sample_rate = sample_rate

    def sample_count(self) -> Int:
        """Interleaved samples in the buffer (frame_count * channels)."""
        return Int(self.frame_count) * Int(self.channels)

    def samples_f32(self) raises -> List[Float32]:
        if self.format != SAMPLE_FORMAT_F32:
            raise Error("decoded audio is not f32; decode with format=f32")
        var n = self.sample_count()
        var out = List[Float32]()
        out.resize(n, Float32(0))
        var src = self._frames.unsafe_bitcast[Float32]()
        for i in range(n):
            out[i] = src[unsafe_offset=i]
        return out^

    def samples_s16(self) raises -> List[Int16]:
        if self.format != SAMPLE_FORMAT_S16:
            raise Error("decoded audio is not s16; decode with format=s16")
        var n = self.sample_count()
        var out = List[Int16]()
        out.resize(n, Int16(0))
        var src = self._frames.unsafe_bitcast[Int16]()
        for i in range(n):
            out[i] = src[unsafe_offset=i]
        return out^

    def __deinit__(deinit self):
        if self._frames != null_handle():
            raw.decode_free(self._lib[], self._frames)


def _wrap(
    lib: ArcPointer[MaLib], d: raw.MaDecoded, what: String
) raises -> DecodedAudio:
    if d.result != MA_SUCCESS:
        raise Error(lib[].describe(what, d.result))
    return DecodedAudio(
        lib.copy(), d.frames, d.frame_count, SampleFormat(d.format), d.channels, d.sample_rate
    )


def decode_file(
    lib: ArcPointer[MaLib],
    path: String,
    *,
    format: SampleFormat = SAMPLE_FORMAT_F32,
    channels: UInt32 = 0,
    sample_rate: UInt32 = 0,
) raises -> DecodedAudio:
    var d = raw.decode_file(lib[], path, format.code, channels, sample_rate)
    return _wrap(lib, d, "decode file failed")


def decode_memory(
    lib: ArcPointer[MaLib],
    data: List[UInt8],
    *,
    format: SampleFormat = SAMPLE_FORMAT_F32,
    channels: UInt32 = 0,
    sample_rate: UInt32 = 0,
) raises -> DecodedAudio:
    """Decodes an in-memory file image; `data` need only live for the call."""
    var d = raw.decode_memory(lib[], data, format.code, channels, sample_rate)
    return _wrap(lib, d, "decode memory failed")


def decode_from_vfs(
    lib: ArcPointer[MaLib],
    vfs: Vfs,
    path: String,
    *,
    format: SampleFormat = SAMPLE_FORMAT_F32,
    channels: UInt32 = 0,
    sample_rate: UInt32 = 0,
) raises -> DecodedAudio:
    """Decodes a file through an initialised `Vfs`."""
    var d = raw.decode_from_vfs(lib[], vfs._ptr, path, format.code, channels, sample_rate)
    return _wrap(lib, d, "decode from vfs failed")


def decode_from_default_vfs(
    lib: ArcPointer[MaLib],
    path: String,
    *,
    format: SampleFormat = SAMPLE_FORMAT_F32,
    channels: UInt32 = 0,
    sample_rate: UInt32 = 0,
) raises -> DecodedAudio:
    """Decodes a file through miniaudio's default (stdio) file system."""
    var d = raw.decode_from_vfs(lib[], null_handle(), path, format.code, channels, sample_rate)
    return _wrap(lib, d, "decode from default vfs failed")
