"""Idiomatic PCM conversion (Layer 3 free functions).

miniaudio's stateless conversion helpers. Nothing here owns anything, so this
module is free functions rather than RAII types, which is the shape of the API.

Each typed function takes and returns a list of the natural Mojo element type:
u8 as UInt8, s16 as Int16, s32 as Int32, f32 as Float32, and s24 as `List[UInt8]`
packed three bytes per sample (little-endian), which is how miniaudio stores it.
The functions that choose their format at run time (`convert_samples`,
`convert_frames`, `copy_frames`, ...) cannot be typed, so they work on raw
bytes; `f32_to_bytes` and friends convert at the edges.

Every function sizes its output from its input, so a call can never write past
a list: a list whose length is not a whole number of samples or frames for the
format and channel count is rejected rather than silently truncated.

Deinterleaving and interleaving move between one interleaved buffer and a flat
buffer holding one plane per channel, laid out end to end. miniaudio wants an
array of per-channel pointers, which Mojo cannot hold, so the shim builds that
array over the flat buffer.

Upstream behaviour worth knowing, pinned by tests/test_pcm_convert_api.mojo:
- u8 is unsigned with 128 as the midpoint, but u8 -> f32 maps 128 to 1/255
  rather than 0.
- f32 -> s16 maps +1.0 to 32767 and -1.0 to -32767. A sample overdriven past
  -1.0 lands on -32767 or -32768 depending on whether miniaudio's SIMD path or
  its scalar tail converted it.
- the plain volume-factor copies scale a u8 sample's raw byte, so u8 silence
  (128) at half volume is 64, not 128.
- dithering only changes the result for conversions that lose precision.
- the plain volume-factor copies (`scaled_*`) do not clip, so a result outside
  the sample range overflows; `scaled_and_clipped_*` clips, and takes a volume
  within +-128 for the integer formats.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib
from miniaudio.decoder import (
    SampleFormat,
    SAMPLE_FORMAT_U8,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S24,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.pcm_convert_raw as raw


comptime DITHER_MODE_NONE = Int(0)
comptime DITHER_MODE_RECTANGLE = Int(1)
comptime DITHER_MODE_TRIANGLE = Int(2)


# ---- helpers -------------------------------------------------------------------


def bytes_per_sample(format: SampleFormat) raises -> Int:
    """Bytes one sample of `format` occupies. Raises for an unknown format."""
    if format == SAMPLE_FORMAT_U8:
        return 1
    if format == SAMPLE_FORMAT_S16:
        return 2
    if format == SAMPLE_FORMAT_S24:
        return 3
    if format == SAMPLE_FORMAT_S32 or format == SAMPLE_FORMAT_F32:
        return 4
    raise Error("unknown sample format " + String(format.code))


def clip_source_bytes_per_sample(format: SampleFormat) raises -> Int:
    """Bytes per sample of the wider type that `format` is clipped from.

    u8 clips from s16, s16 from s32, s24 and s32 from s64, and f32 from f32.
    """
    if format == SAMPLE_FORMAT_U8:
        return 2
    if format == SAMPLE_FORMAT_S16:
        return 4
    if format == SAMPLE_FORMAT_S24 or format == SAMPLE_FORMAT_S32:
        return 8
    if format == SAMPLE_FORMAT_F32:
        return 4
    raise Error("unknown sample format " + String(format.code))


def _zeroed(count: Int) -> List[UInt8]:
    var out = List[UInt8](capacity=count)
    out.resize(count, UInt8(0))
    return out^


def _require_channels(channels: UInt32) raises:
    if channels == 0:
        raise Error("channels must be at least 1")


def _whole(length: Int, unit: Int, what: String) raises -> Int:
    """`length // unit`, raising when `length` is not a whole multiple of `unit`."""
    if length % unit != 0:
        raise Error(
            what + ": length " + String(length) + " is not a whole multiple of "
            + String(unit)
        )
    return length // unit


def f32_to_bytes(values: List[Float32]) -> List[UInt8]:
    """The native-endian bytes of each value, four per sample."""
    var out = _zeroed(len(values) * 4)
    var dst = out.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def bytes_to_f32(data: List[UInt8]) raises -> List[Float32]:
    """The inverse of `f32_to_bytes`."""
    var n = _whole(len(data), 4, "bytes_to_f32")
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    var src = data.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(n):
        out[i] = src[unsafe_offset=i]
    return out^


def s16_to_bytes(values: List[Int16]) -> List[UInt8]:
    """The native-endian bytes of each value, two per sample."""
    var out = _zeroed(len(values) * 2)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int16]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def bytes_to_s16(data: List[UInt8]) raises -> List[Int16]:
    """The inverse of `s16_to_bytes`."""
    var n = _whole(len(data), 2, "bytes_to_s16")
    var out = List[Int16](capacity=n)
    out.resize(n, Int16(0))
    var src = data.unsafe_ptr().unsafe_bitcast[Int16]()
    for i in range(n):
        out[i] = src[unsafe_offset=i]
    return out^


def s32_to_bytes(values: List[Int32]) -> List[UInt8]:
    """The native-endian bytes of each value, four per sample."""
    var out = _zeroed(len(values) * 4)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int32]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def bytes_to_s32(data: List[UInt8]) raises -> List[Int32]:
    """The inverse of `s32_to_bytes`."""
    var n = _whole(len(data), 4, "bytes_to_s32")
    var out = List[Int32](capacity=n)
    out.resize(n, Int32(0))
    var src = data.unsafe_ptr().unsafe_bitcast[Int32]()
    for i in range(n):
        out[i] = src[unsafe_offset=i]
    return out^


def s64_to_bytes(values: List[Int64]) -> List[UInt8]:
    """The native-endian bytes of each value, eight per sample."""
    var out = _zeroed(len(values) * 8)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int64]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


# ---- the 25 format-pair converters ---------------------------------------------


def convert_u8_to_u8(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert u8 samples to u8."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count)
    dst.resize(sample_count, UInt8(0))
    var code = raw.pcm_u8_to_u8(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_u8_to_u8 failed", code))
    return dst^


def convert_u8_to_s16(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int16]:
    """Convert u8 samples to s16."""
    var sample_count = len(src)
    var dst = List[Int16](capacity=sample_count)
    dst.resize(sample_count, Int16(0))
    var code = raw.pcm_u8_to_s16(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_u8_to_s16 failed", code))
    return dst^


def convert_u8_to_s24(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert u8 samples to s24."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count * 3)
    dst.resize(sample_count * 3, UInt8(0))
    var code = raw.pcm_u8_to_s24(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_u8_to_s24 failed", code))
    return dst^


def convert_u8_to_s32(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int32]:
    """Convert u8 samples to s32."""
    var sample_count = len(src)
    var dst = List[Int32](capacity=sample_count)
    dst.resize(sample_count, Int32(0))
    var code = raw.pcm_u8_to_s32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_u8_to_s32 failed", code))
    return dst^


def convert_u8_to_f32(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Float32]:
    """Convert u8 samples to f32."""
    var sample_count = len(src)
    var dst = List[Float32](capacity=sample_count)
    dst.resize(sample_count, Float32(0))
    var code = raw.pcm_u8_to_f32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_u8_to_f32 failed", code))
    return dst^


def convert_s16_to_u8(
    lib: ArcPointer[MaLib],
    src: List[Int16],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s16 samples to u8."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count)
    dst.resize(sample_count, UInt8(0))
    var code = raw.pcm_s16_to_u8(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s16_to_u8 failed", code))
    return dst^


def convert_s16_to_s16(
    lib: ArcPointer[MaLib],
    src: List[Int16],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int16]:
    """Convert s16 samples to s16."""
    var sample_count = len(src)
    var dst = List[Int16](capacity=sample_count)
    dst.resize(sample_count, Int16(0))
    var code = raw.pcm_s16_to_s16(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s16_to_s16 failed", code))
    return dst^


def convert_s16_to_s24(
    lib: ArcPointer[MaLib],
    src: List[Int16],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s16 samples to s24."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count * 3)
    dst.resize(sample_count * 3, UInt8(0))
    var code = raw.pcm_s16_to_s24(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s16_to_s24 failed", code))
    return dst^


def convert_s16_to_s32(
    lib: ArcPointer[MaLib],
    src: List[Int16],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int32]:
    """Convert s16 samples to s32."""
    var sample_count = len(src)
    var dst = List[Int32](capacity=sample_count)
    dst.resize(sample_count, Int32(0))
    var code = raw.pcm_s16_to_s32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s16_to_s32 failed", code))
    return dst^


def convert_s16_to_f32(
    lib: ArcPointer[MaLib],
    src: List[Int16],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Float32]:
    """Convert s16 samples to f32."""
    var sample_count = len(src)
    var dst = List[Float32](capacity=sample_count)
    dst.resize(sample_count, Float32(0))
    var code = raw.pcm_s16_to_f32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s16_to_f32 failed", code))
    return dst^


def convert_s24_to_u8(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s24 samples to u8."""
    var sample_count = _whole(len(src), 3, "convert_s24_to_u8")
    var dst = List[UInt8](capacity=sample_count)
    dst.resize(sample_count, UInt8(0))
    var code = raw.pcm_s24_to_u8(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s24_to_u8 failed", code))
    return dst^


def convert_s24_to_s16(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int16]:
    """Convert s24 samples to s16."""
    var sample_count = _whole(len(src), 3, "convert_s24_to_s16")
    var dst = List[Int16](capacity=sample_count)
    dst.resize(sample_count, Int16(0))
    var code = raw.pcm_s24_to_s16(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s24_to_s16 failed", code))
    return dst^


def convert_s24_to_s24(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s24 samples to s24."""
    var sample_count = _whole(len(src), 3, "convert_s24_to_s24")
    var dst = List[UInt8](capacity=sample_count * 3)
    dst.resize(sample_count * 3, UInt8(0))
    var code = raw.pcm_s24_to_s24(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s24_to_s24 failed", code))
    return dst^


def convert_s24_to_s32(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int32]:
    """Convert s24 samples to s32."""
    var sample_count = _whole(len(src), 3, "convert_s24_to_s32")
    var dst = List[Int32](capacity=sample_count)
    dst.resize(sample_count, Int32(0))
    var code = raw.pcm_s24_to_s32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s24_to_s32 failed", code))
    return dst^


def convert_s24_to_f32(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Float32]:
    """Convert s24 samples to f32."""
    var sample_count = _whole(len(src), 3, "convert_s24_to_f32")
    var dst = List[Float32](capacity=sample_count)
    dst.resize(sample_count, Float32(0))
    var code = raw.pcm_s24_to_f32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s24_to_f32 failed", code))
    return dst^


def convert_s32_to_u8(
    lib: ArcPointer[MaLib],
    src: List[Int32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s32 samples to u8."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count)
    dst.resize(sample_count, UInt8(0))
    var code = raw.pcm_s32_to_u8(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s32_to_u8 failed", code))
    return dst^


def convert_s32_to_s16(
    lib: ArcPointer[MaLib],
    src: List[Int32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int16]:
    """Convert s32 samples to s16."""
    var sample_count = len(src)
    var dst = List[Int16](capacity=sample_count)
    dst.resize(sample_count, Int16(0))
    var code = raw.pcm_s32_to_s16(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s32_to_s16 failed", code))
    return dst^


def convert_s32_to_s24(
    lib: ArcPointer[MaLib],
    src: List[Int32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert s32 samples to s24."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count * 3)
    dst.resize(sample_count * 3, UInt8(0))
    var code = raw.pcm_s32_to_s24(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s32_to_s24 failed", code))
    return dst^


def convert_s32_to_s32(
    lib: ArcPointer[MaLib],
    src: List[Int32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int32]:
    """Convert s32 samples to s32."""
    var sample_count = len(src)
    var dst = List[Int32](capacity=sample_count)
    dst.resize(sample_count, Int32(0))
    var code = raw.pcm_s32_to_s32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s32_to_s32 failed", code))
    return dst^


def convert_s32_to_f32(
    lib: ArcPointer[MaLib],
    src: List[Int32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Float32]:
    """Convert s32 samples to f32."""
    var sample_count = len(src)
    var dst = List[Float32](capacity=sample_count)
    dst.resize(sample_count, Float32(0))
    var code = raw.pcm_s32_to_f32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_s32_to_f32 failed", code))
    return dst^


def convert_f32_to_u8(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert f32 samples to u8."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count)
    dst.resize(sample_count, UInt8(0))
    var code = raw.pcm_f32_to_u8(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_f32_to_u8 failed", code))
    return dst^


def convert_f32_to_s16(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int16]:
    """Convert f32 samples to s16."""
    var sample_count = len(src)
    var dst = List[Int16](capacity=sample_count)
    dst.resize(sample_count, Int16(0))
    var code = raw.pcm_f32_to_s16(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_f32_to_s16 failed", code))
    return dst^


def convert_f32_to_s24(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert f32 samples to s24."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=sample_count * 3)
    dst.resize(sample_count * 3, UInt8(0))
    var code = raw.pcm_f32_to_s24(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_f32_to_s24 failed", code))
    return dst^


def convert_f32_to_s32(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Int32]:
    """Convert f32 samples to s32."""
    var sample_count = len(src)
    var dst = List[Int32](capacity=sample_count)
    dst.resize(sample_count, Int32(0))
    var code = raw.pcm_f32_to_s32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_f32_to_s32 failed", code))
    return dst^


def convert_f32_to_f32(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[Float32]:
    """Convert f32 samples to f32."""
    var sample_count = len(src)
    var dst = List[Float32](capacity=sample_count)
    dst.resize(sample_count, Float32(0))
    var code = raw.pcm_f32_to_f32(lib[], dst, src, UInt64(sample_count), dither_mode)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_f32_to_f32 failed", code))
    return dst^


# ---- interleave / deinterleave ---------------------------------------------------


def deinterleave_u8(
    lib: ArcPointer[MaLib], interleaved: List[UInt8], *, channels: UInt32
) raises -> List[UInt8]:
    """Split into one plane per channel, laid out end to end."""
    _require_channels(channels)
    var frame_count = _whole(len(interleaved), Int(channels) * 1, "deinterleave_u8")
    var planes = List[UInt8](capacity=len(interleaved))
    planes.resize(len(interleaved), UInt8(0))
    var stride = UInt64(frame_count * 1 * 1)
    var code = raw.pcm_deinterleave_u8(
        lib[], planes, stride, interleaved, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_deinterleave_u8 failed", code))
    return planes^


def interleave_u8(
    lib: ArcPointer[MaLib], planes: List[UInt8], *, channels: UInt32
) raises -> List[UInt8]:
    """The inverse of `deinterleave_u8`."""
    _require_channels(channels)
    var frame_count = _whole(len(planes), Int(channels) * 1, "interleave_u8")
    var interleaved = List[UInt8](capacity=len(planes))
    interleaved.resize(len(planes), UInt8(0))
    var stride = UInt64(frame_count * 1 * 1)
    var code = raw.pcm_interleave_u8(
        lib[], interleaved, planes, stride, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_interleave_u8 failed", code))
    return interleaved^


def deinterleave_s16(
    lib: ArcPointer[MaLib], interleaved: List[Int16], *, channels: UInt32
) raises -> List[Int16]:
    """Split into one plane per channel, laid out end to end."""
    _require_channels(channels)
    var frame_count = _whole(len(interleaved), Int(channels) * 1, "deinterleave_s16")
    var planes = List[Int16](capacity=len(interleaved))
    planes.resize(len(interleaved), Int16(0))
    var stride = UInt64(frame_count * 1 * 2)
    var code = raw.pcm_deinterleave_s16(
        lib[], planes, stride, interleaved, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_deinterleave_s16 failed", code))
    return planes^


def interleave_s16(
    lib: ArcPointer[MaLib], planes: List[Int16], *, channels: UInt32
) raises -> List[Int16]:
    """The inverse of `deinterleave_s16`."""
    _require_channels(channels)
    var frame_count = _whole(len(planes), Int(channels) * 1, "interleave_s16")
    var interleaved = List[Int16](capacity=len(planes))
    interleaved.resize(len(planes), Int16(0))
    var stride = UInt64(frame_count * 1 * 2)
    var code = raw.pcm_interleave_s16(
        lib[], interleaved, planes, stride, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_interleave_s16 failed", code))
    return interleaved^


def deinterleave_s24(
    lib: ArcPointer[MaLib], interleaved: List[UInt8], *, channels: UInt32
) raises -> List[UInt8]:
    """Split into one plane per channel, laid out end to end."""
    _require_channels(channels)
    var frame_count = _whole(len(interleaved), Int(channels) * 3, "deinterleave_s24")
    var planes = List[UInt8](capacity=len(interleaved))
    planes.resize(len(interleaved), UInt8(0))
    var stride = UInt64(frame_count * 3 * 1)
    var code = raw.pcm_deinterleave_s24(
        lib[], planes, stride, interleaved, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_deinterleave_s24 failed", code))
    return planes^


def interleave_s24(
    lib: ArcPointer[MaLib], planes: List[UInt8], *, channels: UInt32
) raises -> List[UInt8]:
    """The inverse of `deinterleave_s24`."""
    _require_channels(channels)
    var frame_count = _whole(len(planes), Int(channels) * 3, "interleave_s24")
    var interleaved = List[UInt8](capacity=len(planes))
    interleaved.resize(len(planes), UInt8(0))
    var stride = UInt64(frame_count * 3 * 1)
    var code = raw.pcm_interleave_s24(
        lib[], interleaved, planes, stride, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_interleave_s24 failed", code))
    return interleaved^


def deinterleave_s32(
    lib: ArcPointer[MaLib], interleaved: List[Int32], *, channels: UInt32
) raises -> List[Int32]:
    """Split into one plane per channel, laid out end to end."""
    _require_channels(channels)
    var frame_count = _whole(len(interleaved), Int(channels) * 1, "deinterleave_s32")
    var planes = List[Int32](capacity=len(interleaved))
    planes.resize(len(interleaved), Int32(0))
    var stride = UInt64(frame_count * 1 * 4)
    var code = raw.pcm_deinterleave_s32(
        lib[], planes, stride, interleaved, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_deinterleave_s32 failed", code))
    return planes^


def interleave_s32(
    lib: ArcPointer[MaLib], planes: List[Int32], *, channels: UInt32
) raises -> List[Int32]:
    """The inverse of `deinterleave_s32`."""
    _require_channels(channels)
    var frame_count = _whole(len(planes), Int(channels) * 1, "interleave_s32")
    var interleaved = List[Int32](capacity=len(planes))
    interleaved.resize(len(planes), Int32(0))
    var stride = UInt64(frame_count * 1 * 4)
    var code = raw.pcm_interleave_s32(
        lib[], interleaved, planes, stride, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_interleave_s32 failed", code))
    return interleaved^


def deinterleave_f32(
    lib: ArcPointer[MaLib], interleaved: List[Float32], *, channels: UInt32
) raises -> List[Float32]:
    """Split into one plane per channel, laid out end to end."""
    _require_channels(channels)
    var frame_count = _whole(len(interleaved), Int(channels) * 1, "deinterleave_f32")
    var planes = List[Float32](capacity=len(interleaved))
    planes.resize(len(interleaved), Float32(0))
    var stride = UInt64(frame_count * 1 * 4)
    var code = raw.pcm_deinterleave_f32(
        lib[], planes, stride, interleaved, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_deinterleave_f32 failed", code))
    return planes^


def interleave_f32(
    lib: ArcPointer[MaLib], planes: List[Float32], *, channels: UInt32
) raises -> List[Float32]:
    """The inverse of `deinterleave_f32`."""
    _require_channels(channels)
    var frame_count = _whole(len(planes), Int(channels) * 1, "interleave_f32")
    var interleaved = List[Float32](capacity=len(planes))
    interleaved.resize(len(planes), Float32(0))
    var stride = UInt64(frame_count * 1 * 4)
    var code = raw.pcm_interleave_f32(
        lib[], interleaved, planes, stride, UInt64(frame_count), channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_interleave_f32 failed", code))
    return interleaved^


# ---- conversion that chooses its format at run time (raw bytes) ------------------


def convert_samples(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    format_in: SampleFormat,
    format_out: SampleFormat,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """Convert a buffer of `format_in` samples to `format_out`; both are raw bytes."""
    var sample_count = _whole(len(src), bytes_per_sample(format_in), "convert_samples")
    var dst = _zeroed(sample_count * bytes_per_sample(format_out))
    var code = raw.pcm_convert(
        lib[], dst, format_out.code, src, format_in.code, UInt64(sample_count),
        dither_mode,
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("pcm_convert failed", code))
    return dst^


def convert_frames_format(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    channels: UInt32 = 1,
    format_in: SampleFormat,
    format_out: SampleFormat,
    dither_mode: Int = DITHER_MODE_NONE,
) raises -> List[UInt8]:
    """The same dispatch, counted in frames rather than samples."""
    _require_channels(channels)
    var frame_count = _whole(
        len(src), Int(channels) * bytes_per_sample(format_in), "convert_frames_format"
    )
    var dst = _zeroed(frame_count * Int(channels) * bytes_per_sample(format_out))
    var code = raw.convert_pcm_frames_format(
        lib[], dst, format_out.code, src, format_in.code, UInt64(frame_count),
        channels, dither_mode,
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("convert_pcm_frames_format failed", code))
    return dst^


@fieldwise_init
struct ConvertedFrames(Movable):
    """Converted frames, as raw bytes, plus how many frames miniaudio wrote."""

    var frames_written: UInt64
    var frames: List[UInt8]


def converted_frame_count(
    lib: ArcPointer[MaLib],
    frame_count_in: UInt64,
    *,
    format_in: SampleFormat,
    channels_in: UInt32,
    sample_rate_in: UInt32,
    format_out: SampleFormat,
    channels_out: UInt32,
    sample_rate_out: UInt32,
) raises -> UInt64:
    """How many frames `convert_frames` would produce, without converting anything."""
    var rc = raw.convert_frames_measure(
        lib[], format_out.code, channels_out, sample_rate_out, frame_count_in,
        format_in.code, channels_in, sample_rate_in,
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("convert_frames (measure) failed", rc.result))
    return rc.value


def convert_frames(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    format_in: SampleFormat,
    channels_in: UInt32,
    sample_rate_in: UInt32,
    format_out: SampleFormat,
    channels_out: UInt32,
    sample_rate_out: UInt32,
) raises -> ConvertedFrames:
    """Format, channel and rate conversion in one call.

    Asks miniaudio how many frames the conversion produces, sizes the output to
    that, and converts. `src` and the result are raw bytes.
    """
    _require_channels(channels_in)
    _require_channels(channels_out)
    var frame_count_in = UInt64(
        _whole(len(src), Int(channels_in) * bytes_per_sample(format_in), "convert_frames")
    )
    var capacity = converted_frame_count(
        lib, frame_count_in, format_in=format_in, channels_in=channels_in,
        sample_rate_in=sample_rate_in, format_out=format_out,
        channels_out=channels_out, sample_rate_out=sample_rate_out,
    )
    var bytes_per_frame = Int(channels_out) * bytes_per_sample(format_out)
    var dst = _zeroed(Int(capacity) * bytes_per_frame)
    var rc = raw.convert_frames(
        lib[], dst, capacity, format_out.code, channels_out, sample_rate_out, src,
        frame_count_in, format_in.code, channels_in, sample_rate_in,
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("convert_frames failed", rc.result))
    dst.resize(Int(rc.value) * bytes_per_frame, UInt8(0))
    return ConvertedFrames(rc.value, dst^)


def convert_frames_ex(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    format_in: SampleFormat,
    channels_in: UInt32,
    sample_rate_in: UInt32,
    format_out: SampleFormat,
    channels_out: UInt32,
    sample_rate_out: UInt32,
    dither_mode: Int = DITHER_MODE_NONE,
    lpf_order: UInt32 = 1,
) raises -> ConvertedFrames:
    """`convert_frames` through a data converter config, so dither and the
    resampler's low-pass order (0 turns it off) can be chosen."""
    _require_channels(channels_in)
    _require_channels(channels_out)
    var frame_count_in = UInt64(
        _whole(len(src), Int(channels_in) * bytes_per_sample(format_in), "convert_frames_ex")
    )
    var measured = raw.convert_frames_ex_measure(
        lib[], frame_count_in, format_in.code, format_out.code, channels_in,
        channels_out, sample_rate_in, sample_rate_out, dither_mode, lpf_order,
    )
    if measured.result != MA_SUCCESS:
        raise Error(lib[].describe("convert_frames_ex (measure) failed", measured.result))
    var bytes_per_frame = Int(channels_out) * bytes_per_sample(format_out)
    var dst = _zeroed(Int(measured.value) * bytes_per_frame)
    var rc = raw.convert_frames_ex(
        lib[], dst, measured.value, src, frame_count_in, format_in.code,
        format_out.code, channels_in, channels_out, sample_rate_in, sample_rate_out,
        dither_mode, lpf_order,
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("convert_frames_ex failed", rc.result))
    dst.resize(Int(rc.value) * bytes_per_frame, UInt8(0))
    return ConvertedFrames(rc.value, dst^)


def copy_frames(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> List[UInt8]:
    """A frame-aware copy of raw bytes."""
    _require_channels(channels)
    var frame_count = _whole(
        len(src), Int(channels) * bytes_per_sample(format), "copy_frames"
    )
    var dst = _zeroed(len(src))
    var code = raw.copy_pcm_frames(lib[], dst, src, UInt64(frame_count), format.code, channels)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_pcm_frames failed", code))
    return dst^


# ---- volume, copying rather than in place -----------------------------------------


def scaled_u8(
    lib: ArcPointer[MaLib], src: List[UInt8], factor: Float32
) raises -> List[UInt8]:
    """A copy of u8 samples with the volume applied, leaving `src` untouched."""
    var sample_count = len(src)
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.copy_and_apply_volume_factor_u8(
        lib[], dst, src, UInt64(sample_count), factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_and_apply_volume_factor_u8 failed", code))
    return dst^


def scaled_s16(
    lib: ArcPointer[MaLib], src: List[Int16], factor: Float32
) raises -> List[Int16]:
    """A copy of s16 samples with the volume applied, leaving `src` untouched."""
    var sample_count = len(src)
    var dst = List[Int16](capacity=len(src))
    dst.resize(len(src), Int16(0))
    var code = raw.copy_and_apply_volume_factor_s16(
        lib[], dst, src, UInt64(sample_count), factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_and_apply_volume_factor_s16 failed", code))
    return dst^


def scaled_s24(
    lib: ArcPointer[MaLib], src: List[UInt8], factor: Float32
) raises -> List[UInt8]:
    """A copy of s24 samples with the volume applied, leaving `src` untouched."""
    var sample_count = _whole(len(src), 3, "scaled_s24")
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.copy_and_apply_volume_factor_s24(
        lib[], dst, src, UInt64(sample_count), factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_and_apply_volume_factor_s24 failed", code))
    return dst^


def scaled_s32(
    lib: ArcPointer[MaLib], src: List[Int32], factor: Float32
) raises -> List[Int32]:
    """A copy of s32 samples with the volume applied, leaving `src` untouched."""
    var sample_count = len(src)
    var dst = List[Int32](capacity=len(src))
    dst.resize(len(src), Int32(0))
    var code = raw.copy_and_apply_volume_factor_s32(
        lib[], dst, src, UInt64(sample_count), factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_and_apply_volume_factor_s32 failed", code))
    return dst^


def scaled_f32(
    lib: ArcPointer[MaLib], src: List[Float32], factor: Float32
) raises -> List[Float32]:
    """A copy of f32 samples with the volume applied, leaving `src` untouched."""
    var sample_count = len(src)
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var code = raw.copy_and_apply_volume_factor_f32(
        lib[], dst, src, UInt64(sample_count), factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("copy_and_apply_volume_factor_f32 failed", code))
    return dst^


def scaled_frames_u8(
    lib: ArcPointer[MaLib], src: List[UInt8], factor: Float32, *, channels: UInt32 = 1
) raises -> List[UInt8]:
    """The frame-shaped version of `scaled_u8`."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels) * 1, "scaled_frames_u8")
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.copy_and_apply_volume_factor_pcm_frames_u8(
        lib[], dst, src, UInt64(frame_count), channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames_u8 failed", code)
        )
    return dst^


def scaled_frames_s16(
    lib: ArcPointer[MaLib], src: List[Int16], factor: Float32, *, channels: UInt32 = 1
) raises -> List[Int16]:
    """The frame-shaped version of `scaled_s16`."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels) * 1, "scaled_frames_s16")
    var dst = List[Int16](capacity=len(src))
    dst.resize(len(src), Int16(0))
    var code = raw.copy_and_apply_volume_factor_pcm_frames_s16(
        lib[], dst, src, UInt64(frame_count), channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames_s16 failed", code)
        )
    return dst^


def scaled_frames_s24(
    lib: ArcPointer[MaLib], src: List[UInt8], factor: Float32, *, channels: UInt32 = 1
) raises -> List[UInt8]:
    """The frame-shaped version of `scaled_s24`."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels) * 3, "scaled_frames_s24")
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.copy_and_apply_volume_factor_pcm_frames_s24(
        lib[], dst, src, UInt64(frame_count), channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames_s24 failed", code)
        )
    return dst^


def scaled_frames_s32(
    lib: ArcPointer[MaLib], src: List[Int32], factor: Float32, *, channels: UInt32 = 1
) raises -> List[Int32]:
    """The frame-shaped version of `scaled_s32`."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels) * 1, "scaled_frames_s32")
    var dst = List[Int32](capacity=len(src))
    dst.resize(len(src), Int32(0))
    var code = raw.copy_and_apply_volume_factor_pcm_frames_s32(
        lib[], dst, src, UInt64(frame_count), channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames_s32 failed", code)
        )
    return dst^


def scaled_frames_f32(
    lib: ArcPointer[MaLib], src: List[Float32], factor: Float32, *, channels: UInt32 = 1
) raises -> List[Float32]:
    """The frame-shaped version of `scaled_f32`."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels) * 1, "scaled_frames_f32")
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var code = raw.copy_and_apply_volume_factor_pcm_frames_f32(
        lib[], dst, src, UInt64(frame_count), channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames_f32 failed", code)
        )
    return dst^


def scaled_frames(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    factor: Float32,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> List[UInt8]:
    """The format-dispatching version of `scaled_frames_<format>`, on raw bytes."""
    _require_channels(channels)
    var frame_count = _whole(
        len(src), Int(channels) * bytes_per_sample(format), "scaled_frames"
    )
    var dst = _zeroed(len(src))
    var code = raw.copy_and_apply_volume_factor_pcm_frames(
        lib[], dst, src, UInt64(frame_count), format.code, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_pcm_frames failed", code)
        )
    return dst^


def scaled_per_channel(
    lib: ArcPointer[MaLib], src: List[Float32], channel_gains: List[Float32]
) raises -> List[Float32]:
    """Scale f32 frames with one gain per channel; the channel count is the
    number of gains."""
    var channels = len(channel_gains)
    if channels == 0:
        raise Error("channel_gains must not be empty")
    var frame_count = _whole(len(src), channels, "scaled_per_channel")
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var code = raw.copy_and_apply_volume_factor_per_channel_f32(
        lib[], dst, src, UInt64(frame_count), UInt32(channels), channel_gains
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_factor_per_channel_f32 failed", code)
        )
    return dst^


# ---- volume then clip, from a wider source ------------------------------------------


def scaled_and_clipped_u8(
    lib: ArcPointer[MaLib], src: List[Int16], volume: Float32
) raises -> List[UInt8]:
    """Apply the volume to a Int16 buffer and clip it down into u8."""
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.copy_and_apply_volume_and_clip_samples_u8(
        lib[], dst, src, UInt64(len(src)), volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_samples_u8 failed", code)
        )
    return dst^


def scaled_and_clipped_s16(
    lib: ArcPointer[MaLib], src: List[Int32], volume: Float32
) raises -> List[Int16]:
    """Apply the volume to a Int32 buffer and clip it down into s16."""
    var dst = List[Int16](capacity=len(src))
    dst.resize(len(src), Int16(0))
    var code = raw.copy_and_apply_volume_and_clip_samples_s16(
        lib[], dst, src, UInt64(len(src)), volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_samples_s16 failed", code)
        )
    return dst^


def scaled_and_clipped_s24(
    lib: ArcPointer[MaLib], src: List[Int64], volume: Float32
) raises -> List[UInt8]:
    """Apply the volume to a Int64 buffer and clip it down into s24."""
    var dst = List[UInt8](capacity=len(src) * 3)
    dst.resize(len(src) * 3, UInt8(0))
    var code = raw.copy_and_apply_volume_and_clip_samples_s24(
        lib[], dst, src, UInt64(len(src)), volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_samples_s24 failed", code)
        )
    return dst^


def scaled_and_clipped_s32(
    lib: ArcPointer[MaLib], src: List[Int64], volume: Float32
) raises -> List[Int32]:
    """Apply the volume to a Int64 buffer and clip it down into s32."""
    var dst = List[Int32](capacity=len(src))
    dst.resize(len(src), Int32(0))
    var code = raw.copy_and_apply_volume_and_clip_samples_s32(
        lib[], dst, src, UInt64(len(src)), volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_samples_s32 failed", code)
        )
    return dst^


def scaled_and_clipped_f32(
    lib: ArcPointer[MaLib], src: List[Float32], volume: Float32
) raises -> List[Float32]:
    """Apply the volume to a Float32 buffer and clip it down into f32."""
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var code = raw.copy_and_apply_volume_and_clip_samples_f32(
        lib[], dst, src, UInt64(len(src)), volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_samples_f32 failed", code)
        )
    return dst^


def scaled_and_clipped_frames(
    lib: ArcPointer[MaLib],
    src: List[UInt8],
    volume: Float32,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> List[UInt8]:
    """The format-dispatching version of `scaled_and_clipped_<format>`.

    `src` holds the wider type `format` clips from (see
    `clip_source_bytes_per_sample`); the result holds samples of `format`.
    """
    _require_channels(channels)
    var frame_count = _whole(
        len(src), Int(channels) * clip_source_bytes_per_sample(format),
        "scaled_and_clipped_frames",
    )
    var dst = _zeroed(frame_count * Int(channels) * bytes_per_sample(format))
    var code = raw.copy_and_apply_volume_and_clip_pcm_frames(
        lib[], dst, src, UInt64(frame_count), format.code, channels, volume
    )
    if code != MA_SUCCESS:
        raise Error(
            lib[].describe("copy_and_apply_volume_and_clip_pcm_frames failed", code)
        )
    return dst^


# ---- blending, mixing, decibels and strings --------------------------------------------


def blend(
    lib: ArcPointer[MaLib], a: List[Float32], b: List[Float32], factor: Float32
) raises -> List[Float32]:
    """Cross-fade one frame between two inputs; 0 gives `a`, 1 gives `b`.

    The frame is as wide as the lists, which must match. A factor outside [0, 1]
    extrapolates rather than clamping.
    """
    if len(a) != len(b):
        raise Error("blend needs two frames of the same width")
    var channels = len(a)
    _require_channels(UInt32(channels))
    var dst = List[Float32](capacity=channels)
    dst.resize(channels, Float32(0))
    var code = raw.blend_f32(lib[], dst, a, b, factor, UInt32(channels))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("blend_f32 failed", code))
    return dst^


def mix_into(
    lib: ArcPointer[MaLib],
    mut dst: List[Float32],
    src: List[Float32],
    volume: Float32,
    *,
    channels: UInt32 = 1,
) raises:
    """Add `src` into `dst` at the given volume. `dst` must be at least as long."""
    _require_channels(channels)
    var frame_count = _whole(len(src), Int(channels), "mix_into")
    if len(dst) < len(src):
        raise Error("mix_into: dst is shorter than src")
    var code = raw.mix_pcm_frames_f32(
        lib[], dst, src, UInt64(frame_count), channels, volume
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("mix_pcm_frames_f32 failed", code))


def linear_to_db(lib: ArcPointer[MaLib], factor: Float32) raises -> Float32:
    """A linear gain in decibels. 0 is -inf and a negative factor is NaN."""
    var rc = raw.volume_linear_to_db(lib[], factor)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("volume_linear_to_db failed", rc.result))
    return rc.value


def db_to_linear(lib: ArcPointer[MaLib], gain: Float32) raises -> Float32:
    """A gain in decibels as a linear factor."""
    var rc = raw.volume_db_to_linear(lib[], gain)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("volume_db_to_linear failed", rc.result))
    return rc.value


def duplicate_string(
    lib: ArcPointer[MaLib], text: String, *, capacity: UInt32 = 256
) raises -> String:
    """miniaudio duplicates the string; the shim copies it out and frees it.

    Raises when the text does not fit in `capacity` bytes including the terminator.
    """
    var rc = raw.copy_string(lib[], text, capacity)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("copy_string failed", rc.result))
    return rc.value
