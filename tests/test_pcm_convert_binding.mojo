"""TDD contract tests for the PCM conversion BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: these are stateless helpers operating on
caller memory. All 63 bindable MA_API conversion functions are exercised here
(positive and negative paths): the 25 format-pair converters, the five
interleave / deinterleave pairs, whole-buffer and whole-frame conversion, the
copying volume / clip / blend / mix helpers, the decibel conversions and
ma_copy_string.

The expected values in the converter tables were produced by running miniaudio
itself on the same inputs, so they pin what the shim passes through, quirks
included. The meaning of the numbers is asserted in test_pcm_convert_api.mojo.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.pcm_convert_raw as raw


comptime FMT_U8: Int = 1
comptime FMT_S16: Int = 2
comptime FMT_S24: Int = 3
comptime FMT_S32: Int = 4
comptime FMT_F32: Int = 5

comptime MA_NO_SPACE: Int = -18
comptime BAD_DITHER: Int = 9


def _lib() raises -> MaLib:
    return MaLib.default()


def _nan() -> Float32:
    var zero = Float32(0.0)
    return zero / zero


def _zeros_u8(n: Int) -> List[UInt8]:
    var out = List[UInt8](capacity=n)
    out.resize(n, UInt8(0))
    return out^


def _zeros_s16(n: Int) -> List[Int16]:
    var out = List[Int16](capacity=n)
    out.resize(n, Int16(0))
    return out^


def _zeros_s32(n: Int) -> List[Int32]:
    var out = List[Int32](capacity=n)
    out.resize(n, Int32(0))
    return out^


def _zeros_f32(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _same_u8(got: List[UInt8], want: List[UInt8]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_equal(got[i], want[i])


def _same_s16(got: List[Int16], want: List[Int16]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_equal(got[i], want[i])


def _same_s32(got: List[Int32], want: List[Int32]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_equal(got[i], want[i])


def _same_f32(got: List[Float32], want: List[Float32]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_almost_equal(got[i], want[i], atol=1e-6)


def _f32_bytes(values: List[Float32]) -> List[UInt8]:
    """Native-endian bytes of f32 samples, for the byte-typed dispatch wrappers."""
    var out = _zeros_u8(len(values) * 4)
    var dst = out.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def _s16_bytes(values: List[Int16]) -> List[UInt8]:
    var out = _zeros_u8(len(values) * 2)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int16]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def _s32_bytes(values: List[Int32]) -> List[UInt8]:
    var out = _zeros_u8(len(values) * 4)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int32]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


def _s16_of(data: List[UInt8]) -> List[Int16]:
    var out = _zeros_s16(len(data) // 2)
    var src = data.unsafe_ptr().unsafe_bitcast[Int16]()
    for i in range(len(out)):
        out[i] = src[unsafe_offset=i]
    return out^


def _f32_of(data: List[UInt8]) -> List[Float32]:
    var out = _zeros_f32(len(data) // 4)
    var src = data.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(len(out)):
        out[i] = src[unsafe_offset=i]
    return out^


def _s64_bytes(values: List[Int64]) -> List[UInt8]:
    var out = _zeros_u8(len(values) * 8)
    var dst = out.unsafe_ptr().unsafe_bitcast[Int64]()
    for i in range(len(values)):
        dst[unsafe_offset=i] = values[i]
    return out^


# ---- the 25 format-pair converters --------------------------------------------


def test_u8_source_converts_to_every_format() raises:
    """Converting u8 samples with each of the five u8_to_* converters matches
    miniaudio's own output; a dither mode outside the enum is refused without
    touching the output."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(0), UInt8(128), UInt8(255), UInt8(64)]

    var out_u8 = _zeros_u8(4)
    assert_equal(raw.pcm_u8_to_u8(lib, out_u8, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_u8, _zeros_u8(4))
    assert_equal(raw.pcm_u8_to_u8(lib, out_u8, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_u8, [UInt8(0), UInt8(128), UInt8(255), UInt8(64)])

    var out_s16 = _zeros_s16(4)
    assert_equal(raw.pcm_u8_to_s16(lib, out_s16, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s16(out_s16, _zeros_s16(4))
    assert_equal(raw.pcm_u8_to_s16(lib, out_s16, src, UInt64(4)), MA_SUCCESS)
    _same_s16(out_s16, [Int16(-32768), Int16(0), Int16(32512), Int16(-16384)])

    var out_s24 = _zeros_u8(12)
    assert_equal(raw.pcm_u8_to_s24(lib, out_s24, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_s24, _zeros_u8(12))
    assert_equal(raw.pcm_u8_to_s24(lib, out_s24, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_s24, [UInt8(0), UInt8(0), UInt8(128), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(127), UInt8(0), UInt8(0), UInt8(192)])

    var out_s32 = _zeros_s32(4)
    assert_equal(raw.pcm_u8_to_s32(lib, out_s32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s32(out_s32, _zeros_s32(4))
    assert_equal(raw.pcm_u8_to_s32(lib, out_s32, src, UInt64(4)), MA_SUCCESS)
    _same_s32(out_s32, [Int32(-2147483648), Int32(0), Int32(2130706432), Int32(-1073741824)])

    var out_f32 = _zeros_f32(4)
    assert_equal(raw.pcm_u8_to_f32(lib, out_f32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_f32(out_f32, _zeros_f32(4))
    assert_equal(raw.pcm_u8_to_f32(lib, out_f32, src, UInt64(4)), MA_SUCCESS)
    _same_f32(out_f32, [Float32(-1.0), Float32(0.003921628), Float32(1.0), Float32(-0.498039186)])


def test_s16_source_converts_to_every_format() raises:
    """Converting s16 samples with each of the five s16_to_* converters matches
    miniaudio's own output; a dither mode outside the enum is refused without
    touching the output."""
    var lib = _lib()
    var src: List[Int16] = [Int16(0), Int16(32767), Int16(-32768), Int16(1000)]

    var out_u8 = _zeros_u8(4)
    assert_equal(raw.pcm_s16_to_u8(lib, out_u8, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_u8, _zeros_u8(4))
    assert_equal(raw.pcm_s16_to_u8(lib, out_u8, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_u8, [UInt8(128), UInt8(255), UInt8(0), UInt8(131)])

    var out_s16 = _zeros_s16(4)
    assert_equal(raw.pcm_s16_to_s16(lib, out_s16, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s16(out_s16, _zeros_s16(4))
    assert_equal(raw.pcm_s16_to_s16(lib, out_s16, src, UInt64(4)), MA_SUCCESS)
    _same_s16(out_s16, [Int16(0), Int16(32767), Int16(-32768), Int16(1000)])

    var out_s24 = _zeros_u8(12)
    assert_equal(raw.pcm_s16_to_s24(lib, out_s24, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_s24, _zeros_u8(12))
    assert_equal(raw.pcm_s16_to_s24(lib, out_s24, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_s24, [UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(0), UInt8(232), UInt8(3)])

    var out_s32 = _zeros_s32(4)
    assert_equal(raw.pcm_s16_to_s32(lib, out_s32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s32(out_s32, _zeros_s32(4))
    assert_equal(raw.pcm_s16_to_s32(lib, out_s32, src, UInt64(4)), MA_SUCCESS)
    _same_s32(out_s32, [Int32(0), Int32(2147418112), Int32(-2147483648), Int32(65536000)])

    var out_f32 = _zeros_f32(4)
    assert_equal(raw.pcm_s16_to_f32(lib, out_f32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_f32(out_f32, _zeros_f32(4))
    assert_equal(raw.pcm_s16_to_f32(lib, out_f32, src, UInt64(4)), MA_SUCCESS)
    _same_f32(out_f32, [Float32(0.0), Float32(0.999969482), Float32(-1.0), Float32(0.0305175781)])


def test_s24_source_converts_to_every_format() raises:
    """Converting s24 samples with each of the five s24_to_* converters matches
    miniaudio's own output; a dither mode outside the enum is refused without
    touching the output."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(232), UInt8(3), UInt8(0)]

    var out_u8 = _zeros_u8(4)
    assert_equal(raw.pcm_s24_to_u8(lib, out_u8, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_u8, _zeros_u8(4))
    assert_equal(raw.pcm_s24_to_u8(lib, out_u8, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_u8, [UInt8(128), UInt8(255), UInt8(0), UInt8(128)])

    var out_s16 = _zeros_s16(4)
    assert_equal(raw.pcm_s24_to_s16(lib, out_s16, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s16(out_s16, _zeros_s16(4))
    assert_equal(raw.pcm_s24_to_s16(lib, out_s16, src, UInt64(4)), MA_SUCCESS)
    _same_s16(out_s16, [Int16(0), Int16(32767), Int16(-32768), Int16(3)])

    var out_s24 = _zeros_u8(12)
    assert_equal(raw.pcm_s24_to_s24(lib, out_s24, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_s24, _zeros_u8(12))
    assert_equal(raw.pcm_s24_to_s24(lib, out_s24, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_s24, [UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(232), UInt8(3), UInt8(0)])

    var out_s32 = _zeros_s32(4)
    assert_equal(raw.pcm_s24_to_s32(lib, out_s32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s32(out_s32, _zeros_s32(4))
    assert_equal(raw.pcm_s24_to_s32(lib, out_s32, src, UInt64(4)), MA_SUCCESS)
    _same_s32(out_s32, [Int32(0), Int32(2147483392), Int32(-2147483648), Int32(256000)])

    var out_f32 = _zeros_f32(4)
    assert_equal(raw.pcm_s24_to_f32(lib, out_f32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_f32(out_f32, _zeros_f32(4))
    assert_equal(raw.pcm_s24_to_f32(lib, out_f32, src, UInt64(4)), MA_SUCCESS)
    _same_f32(out_f32, [Float32(0.0), Float32(0.999999881), Float32(-1.0), Float32(0.00011920929)])


def test_s32_source_converts_to_every_format() raises:
    """Converting s32 samples with each of the five s32_to_* converters matches
    miniaudio's own output; a dither mode outside the enum is refused without
    touching the output."""
    var lib = _lib()
    var src: List[Int32] = [Int32(0), Int32(2147483647), Int32(-2147483648), Int32(65536000)]

    var out_u8 = _zeros_u8(4)
    assert_equal(raw.pcm_s32_to_u8(lib, out_u8, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_u8, _zeros_u8(4))
    assert_equal(raw.pcm_s32_to_u8(lib, out_u8, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_u8, [UInt8(128), UInt8(255), UInt8(0), UInt8(131)])

    var out_s16 = _zeros_s16(4)
    assert_equal(raw.pcm_s32_to_s16(lib, out_s16, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s16(out_s16, _zeros_s16(4))
    assert_equal(raw.pcm_s32_to_s16(lib, out_s16, src, UInt64(4)), MA_SUCCESS)
    _same_s16(out_s16, [Int16(0), Int16(32767), Int16(-32768), Int16(1000)])

    var out_s24 = _zeros_u8(12)
    assert_equal(raw.pcm_s32_to_s24(lib, out_s24, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_s24, _zeros_u8(12))
    assert_equal(raw.pcm_s32_to_s24(lib, out_s24, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_s24, [UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(0), UInt8(232), UInt8(3)])

    var out_s32 = _zeros_s32(4)
    assert_equal(raw.pcm_s32_to_s32(lib, out_s32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s32(out_s32, _zeros_s32(4))
    assert_equal(raw.pcm_s32_to_s32(lib, out_s32, src, UInt64(4)), MA_SUCCESS)
    _same_s32(out_s32, [Int32(0), Int32(2147483647), Int32(-2147483648), Int32(65536000)])

    var out_f32 = _zeros_f32(4)
    assert_equal(raw.pcm_s32_to_f32(lib, out_f32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_f32(out_f32, _zeros_f32(4))
    assert_equal(raw.pcm_s32_to_f32(lib, out_f32, src, UInt64(4)), MA_SUCCESS)
    _same_f32(out_f32, [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.0305175781)])


def test_f32_source_converts_to_every_format() raises:
    """Converting f32 samples with each of the five f32_to_* converters matches
    miniaudio's own output; a dither mode outside the enum is refused without
    touching the output."""
    var lib = _lib()
    var src: List[Float32] = [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)]

    var out_u8 = _zeros_u8(4)
    assert_equal(raw.pcm_f32_to_u8(lib, out_u8, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_u8, _zeros_u8(4))
    assert_equal(raw.pcm_f32_to_u8(lib, out_u8, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_u8, [UInt8(127), UInt8(255), UInt8(0), UInt8(191)])

    var out_s16 = _zeros_s16(4)
    assert_equal(raw.pcm_f32_to_s16(lib, out_s16, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s16(out_s16, _zeros_s16(4))
    assert_equal(raw.pcm_f32_to_s16(lib, out_s16, src, UInt64(4)), MA_SUCCESS)
    _same_s16(out_s16, [Int16(0), Int16(32767), Int16(-32767), Int16(16383)])

    var out_s24 = _zeros_u8(12)
    assert_equal(raw.pcm_f32_to_s24(lib, out_s24, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(out_s24, _zeros_u8(12))
    assert_equal(raw.pcm_f32_to_s24(lib, out_s24, src, UInt64(4)), MA_SUCCESS)
    _same_u8(out_s24, [UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(255), UInt8(127), UInt8(1), UInt8(0), UInt8(128), UInt8(255), UInt8(255), UInt8(63)])

    var out_s32 = _zeros_s32(4)
    assert_equal(raw.pcm_f32_to_s32(lib, out_s32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_s32(out_s32, _zeros_s32(4))
    assert_equal(raw.pcm_f32_to_s32(lib, out_s32, src, UInt64(4)), MA_SUCCESS)
    _same_s32(out_s32, [Int32(0), Int32(2147483647), Int32(-2147483647), Int32(1073741823)])

    var out_f32 = _zeros_f32(4)
    assert_equal(raw.pcm_f32_to_f32(lib, out_f32, src, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_f32(out_f32, _zeros_f32(4))
    assert_equal(raw.pcm_f32_to_f32(lib, out_f32, src, UInt64(4)), MA_SUCCESS)
    _same_f32(out_f32, [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)])


# ---- interleave / deinterleave, over a flat multi-plane buffer ------------------


def test_u8_planes_split_and_weave_back() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave
    restores the original. Zero channels, too many channels and a stride shorter
    than a plane are refused and write nothing."""
    var lib = _lib()
    var interleaved: List[UInt8] = [UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6)]
    var planes = _zeros_u8(6)

    assert_equal(raw.pcm_deinterleave_u8(lib, planes, UInt64(3), interleaved, UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_u8(lib, planes, UInt64(3), interleaved, UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_u8(lib, planes, UInt64(2), interleaved, UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_u8(planes, _zeros_u8(6))

    assert_equal(raw.pcm_deinterleave_u8(lib, planes, UInt64(3), interleaved, UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_u8(planes, [UInt8(1), UInt8(3), UInt8(5), UInt8(2), UInt8(4), UInt8(6)])

    var woven = _zeros_u8(6)
    assert_equal(raw.pcm_interleave_u8(lib, woven, planes, UInt64(3), UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_u8(lib, woven, planes, UInt64(3), UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_u8(lib, woven, planes, UInt64(2), UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_u8(woven, _zeros_u8(6))

    assert_equal(raw.pcm_interleave_u8(lib, woven, planes, UInt64(3), UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_u8(woven, interleaved)


def test_s16_planes_split_and_weave_back() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave
    restores the original. Zero channels, too many channels and a stride shorter
    than a plane are refused and write nothing."""
    var lib = _lib()
    var interleaved: List[Int16] = [Int16(10), Int16(-20), Int16(30), Int16(-40), Int16(50), Int16(-60)]
    var planes = _zeros_s16(6)

    assert_equal(raw.pcm_deinterleave_s16(lib, planes, UInt64(6), interleaved, UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s16(lib, planes, UInt64(6), interleaved, UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s16(lib, planes, UInt64(5), interleaved, UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_s16(planes, _zeros_s16(6))

    assert_equal(raw.pcm_deinterleave_s16(lib, planes, UInt64(6), interleaved, UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_s16(planes, [Int16(10), Int16(30), Int16(50), Int16(-20), Int16(-40), Int16(-60)])

    var woven = _zeros_s16(6)
    assert_equal(raw.pcm_interleave_s16(lib, woven, planes, UInt64(6), UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s16(lib, woven, planes, UInt64(6), UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s16(lib, woven, planes, UInt64(5), UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_s16(woven, _zeros_s16(6))

    assert_equal(raw.pcm_interleave_s16(lib, woven, planes, UInt64(6), UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_s16(woven, interleaved)


def test_s24_planes_split_and_weave_back() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave
    restores the original. Zero channels, too many channels and a stride shorter
    than a plane are refused and write nothing."""
    var lib = _lib()
    var interleaved: List[UInt8] = [UInt8(0), UInt8(10), UInt8(20), UInt8(1), UInt8(11), UInt8(21), UInt8(2), UInt8(12), UInt8(22), UInt8(3), UInt8(13), UInt8(23), UInt8(4), UInt8(14), UInt8(24), UInt8(5), UInt8(15), UInt8(25)]
    var planes = _zeros_u8(18)

    assert_equal(raw.pcm_deinterleave_s24(lib, planes, UInt64(9), interleaved, UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s24(lib, planes, UInt64(9), interleaved, UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s24(lib, planes, UInt64(8), interleaved, UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_u8(planes, _zeros_u8(18))

    assert_equal(raw.pcm_deinterleave_s24(lib, planes, UInt64(9), interleaved, UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_u8(planes, [UInt8(0), UInt8(10), UInt8(20), UInt8(2), UInt8(12), UInt8(22), UInt8(4), UInt8(14), UInt8(24), UInt8(1), UInt8(11), UInt8(21), UInt8(3), UInt8(13), UInt8(23), UInt8(5), UInt8(15), UInt8(25)])

    var woven = _zeros_u8(18)
    assert_equal(raw.pcm_interleave_s24(lib, woven, planes, UInt64(9), UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s24(lib, woven, planes, UInt64(9), UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s24(lib, woven, planes, UInt64(8), UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_u8(woven, _zeros_u8(18))

    assert_equal(raw.pcm_interleave_s24(lib, woven, planes, UInt64(9), UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_u8(woven, interleaved)


def test_s32_planes_split_and_weave_back() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave
    restores the original. Zero channels, too many channels and a stride shorter
    than a plane are refused and write nothing."""
    var lib = _lib()
    var interleaved: List[Int32] = [Int32(100000), Int32(-200000), Int32(300000), Int32(-400000), Int32(500000), Int32(-600000)]
    var planes = _zeros_s32(6)

    assert_equal(raw.pcm_deinterleave_s32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_s32(lib, planes, UInt64(11), interleaved, UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_s32(planes, _zeros_s32(6))

    assert_equal(raw.pcm_deinterleave_s32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_s32(planes, [Int32(100000), Int32(300000), Int32(500000), Int32(-200000), Int32(-400000), Int32(-600000)])

    var woven = _zeros_s32(6)
    assert_equal(raw.pcm_interleave_s32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_s32(lib, woven, planes, UInt64(11), UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_s32(woven, _zeros_s32(6))

    assert_equal(raw.pcm_interleave_s32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_s32(woven, interleaved)


def test_f32_planes_split_and_weave_back() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave
    restores the original. Zero channels, too many channels and a stride shorter
    than a plane are refused and write nothing."""
    var lib = _lib()
    var interleaved: List[Float32] = [Float32(0.125), Float32(-0.25), Float32(0.375), Float32(-0.5), Float32(0.625), Float32(-0.75)]
    var planes = _zeros_f32(6)

    assert_equal(raw.pcm_deinterleave_f32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_f32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_deinterleave_f32(lib, planes, UInt64(11), interleaved, UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_f32(planes, _zeros_f32(6))

    assert_equal(raw.pcm_deinterleave_f32(lib, planes, UInt64(12), interleaved, UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_f32(planes, [Float32(0.125), Float32(0.375), Float32(0.625), Float32(-0.25), Float32(-0.5), Float32(-0.75)])

    var woven = _zeros_f32(6)
    assert_equal(raw.pcm_interleave_f32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_f32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(255)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_interleave_f32(lib, woven, planes, UInt64(11), UInt64(3), UInt32(2)), MA_INVALID_ARGS)
    _same_f32(woven, _zeros_f32(6))

    assert_equal(raw.pcm_interleave_f32(lib, woven, planes, UInt64(12), UInt64(3), UInt32(2)), MA_SUCCESS)
    _same_f32(woven, interleaved)


def test_planes_may_be_spaced_wider_than_a_plane() raises:
    """A stride longer than a plane leaves a gap between channels untouched."""
    var lib = _lib()
    var interleaved: List[Int16] = [Int16(1), Int16(2), Int16(3), Int16(4)]
    var planes = _zeros_s16(8)
    # two frames per plane (4 bytes), planes 8 bytes apart
    assert_equal(raw.pcm_deinterleave_s16(lib, planes, UInt64(8), interleaved, UInt64(2), UInt32(2)), MA_SUCCESS)
    _same_s16(planes, [Int16(1), Int16(3), Int16(0), Int16(0), Int16(2), Int16(4), Int16(0), Int16(0)])


# ---- whole-buffer conversion ---------------------------------------------------


def test_pcm_convert_dispatches_on_the_format_codes() raises:
    """Dispatching f32 to s16 matches the typed converter; an unknown format, a
    dither mode outside the enum and a same-format call all behave."""
    var lib = _lib()
    var src = _f32_bytes([Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)])
    var dst = _zeros_u8(8)

    assert_equal(raw.pcm_convert(lib, dst, 0, src, FMT_F32, UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_convert(lib, dst, FMT_S16, src, 99, UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_convert(lib, dst, FMT_S16, src, FMT_F32, UInt64(4), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(dst, _zeros_u8(8))

    assert_equal(raw.pcm_convert(lib, dst, FMT_S16, src, FMT_F32, UInt64(4)), MA_SUCCESS)
    _same_s16(_s16_of(dst), [Int16(0), Int16(32767), Int16(-32767), Int16(16383)])

    var same_format = _zeros_u8(16)
    assert_equal(raw.pcm_convert(lib, same_format, FMT_F32, src, FMT_F32, UInt64(4)), MA_SUCCESS)
    _same_u8(same_format, src)


def test_convert_pcm_frames_format_counts_frames() raises:
    """Two stereo frames are four samples; the frame-counted converter agrees with
    the sample-counted one."""
    var lib = _lib()
    var src = _s16_bytes([Int16(0), Int16(32767), Int16(-32768), Int16(1000)])
    var dst = _zeros_u8(16)

    assert_equal(raw.convert_pcm_frames_format(lib, dst, FMT_F32, src, FMT_S16, UInt64(2), UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.convert_pcm_frames_format(lib, dst, FMT_F32, src, 0, UInt64(2), UInt32(2)), MA_INVALID_ARGS)
    assert_equal(raw.convert_pcm_frames_format(lib, dst, FMT_F32, src, FMT_S16, UInt64(2), UInt32(2), BAD_DITHER), MA_INVALID_ARGS)
    _same_u8(dst, _zeros_u8(16))

    assert_equal(raw.convert_pcm_frames_format(lib, dst, FMT_F32, src, FMT_S16, UInt64(2), UInt32(2)), MA_SUCCESS)
    var f = _f32_of(dst)
    assert_almost_equal(f[0], Float32(0.0), atol=1e-6)
    assert_almost_equal(f[1], Float32(0.99996948), atol=1e-6)
    assert_almost_equal(f[2], Float32(-1.0), atol=1e-6)
    assert_almost_equal(f[3], Float32(0.0305175781), atol=1e-6)


def test_convert_frames_resamples_and_reports_the_count() raises:
    """48 kHz to 24 kHz halves 100 frames to 50. A NULL output asks for the count
    without converting; bad formats, channels and rates are refused."""
    var lib = _lib()
    var ramp = _zeros_f32(100)
    for i in range(100):
        ramp[i] = Float32(i) / Float32(100)
    var src = _f32_bytes(ramp)

    var measured = raw.convert_frames_measure(
        lib, FMT_F32, UInt32(1), UInt32(24000), UInt64(100), FMT_F32, UInt32(1), UInt32(48000)
    )
    assert_equal(measured.result, MA_SUCCESS)
    assert_equal(measured.value, UInt64(50))

    var dst = _zeros_u8(50 * 4)
    var bad_format = raw.convert_frames(lib, dst, UInt64(50), 0, UInt32(1), UInt32(24000), src, UInt64(100), FMT_F32, UInt32(1), UInt32(48000))
    assert_equal(bad_format.result, MA_INVALID_ARGS)
    var bad_channels = raw.convert_frames(lib, dst, UInt64(50), FMT_F32, UInt32(0), UInt32(24000), src, UInt64(100), FMT_F32, UInt32(1), UInt32(48000))
    assert_equal(bad_channels.result, MA_INVALID_ARGS)
    var bad_rate = raw.convert_frames(lib, dst, UInt64(50), FMT_F32, UInt32(1), UInt32(0), src, UInt64(100), FMT_F32, UInt32(1), UInt32(48000))
    assert_equal(bad_rate.result, MA_INVALID_ARGS)
    assert_equal(bad_rate.value, UInt64(0))

    var done = raw.convert_frames(lib, dst, UInt64(50), FMT_F32, UInt32(1), UInt32(24000), src, UInt64(100), FMT_F32, UInt32(1), UInt32(48000))
    assert_equal(done.result, MA_SUCCESS)
    assert_equal(done.value, UInt64(50))
    var out = _f32_of(dst)
    assert_almost_equal(out[0], Float32(0.0), atol=1e-6)
    assert_true(out[40] > out[10])

    # No input frames: nothing to convert, and that is not an error.
    var empty = raw.convert_frames(lib, dst, UInt64(50), FMT_F32, UInt32(1), UInt32(24000), src, UInt64(0), FMT_F32, UInt32(1), UInt32(48000))
    assert_equal(empty.result, MA_SUCCESS)
    assert_equal(empty.value, UInt64(0))


def test_convert_frames_ex_takes_dither_and_filter_order() raises:
    """The config-driven variant converts the same way, and refuses a dither mode
    or low-pass order outside miniaudio's range."""
    var lib = _lib()
    var ramp = _zeros_f32(100)
    for i in range(100):
        ramp[i] = Float32(i) / Float32(100)
    var src = _f32_bytes(ramp)

    var measured = raw.convert_frames_ex_measure(
        lib, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1), UInt32(48000), UInt32(24000)
    )
    assert_equal(measured.result, MA_SUCCESS)
    assert_equal(measured.value, UInt64(50))

    var dst = _zeros_u8(50 * 4)
    assert_equal(raw.convert_frames_ex(lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1), UInt32(48000), UInt32(24000), BAD_DITHER).result, MA_INVALID_ARGS)
    assert_equal(raw.convert_frames_ex(lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1), UInt32(48000), UInt32(24000), 0, UInt32(9)).result, MA_INVALID_ARGS)
    assert_equal(raw.convert_frames_ex(lib, dst, UInt64(50), src, UInt64(100), 0, FMT_F32, UInt32(1), UInt32(1), UInt32(48000), UInt32(24000)).result, MA_INVALID_ARGS)
    assert_equal(raw.convert_frames_ex(lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(0), UInt32(48000), UInt32(24000)).result, MA_INVALID_ARGS)
    assert_equal(raw.convert_frames_ex(lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1), UInt32(0), UInt32(24000)).result, MA_INVALID_ARGS)

    var unfiltered = raw.convert_frames_ex(
        lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1),
        UInt32(48000), UInt32(24000), 0, UInt32(0),
    )
    assert_equal(unfiltered.result, MA_SUCCESS)
    assert_equal(unfiltered.value, UInt64(50))
    var out = _f32_of(dst)
    # With no low-pass the ramp is only interpolated. The linear resampler lags
    # the input by one frame, so output i is input 2i - 1 (after the first frame).
    assert_almost_equal(out[0], Float32(0.0), atol=1e-4)
    assert_almost_equal(out[1], Float32(0.01), atol=1e-4)
    assert_almost_equal(out[10], Float32(0.19), atol=1e-4)
    assert_almost_equal(out[25], Float32(0.49), atol=1e-4)

    var filtered = raw.convert_frames_ex(
        lib, dst, UInt64(50), src, UInt64(100), FMT_F32, FMT_F32, UInt32(1), UInt32(1),
        UInt32(48000), UInt32(24000),
    )
    assert_equal(filtered.result, MA_SUCCESS)
    assert_equal(filtered.value, UInt64(50))
    # The low-pass smears the ramp, so the same frame no longer matches the unfiltered one.
    assert_true(abs(_f32_of(dst)[1] - out[1]) > Float32(1e-3))


def test_copy_pcm_frames_copies_whole_frames() raises:
    var lib = _lib()
    var src = _s16_bytes([Int16(1), Int16(-2), Int16(3), Int16(-4)])
    var dst = _zeros_u8(8)
    assert_equal(raw.copy_pcm_frames(lib, dst, src, UInt64(2), 0, UInt32(2)), MA_INVALID_ARGS)
    assert_equal(raw.copy_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(0)), MA_INVALID_ARGS)
    _same_u8(dst, _zeros_u8(8))
    assert_equal(raw.copy_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(2)), MA_SUCCESS)
    _same_u8(dst, src)


# ---- volume, copying rather than in place ------------------------------------------


def test_u8_volume_factor_scales_samples_and_frames() raises:
    """Halving through the sample-counted and the frame-counted u8 copies gives the
    same result; a NULL-free call with zero channels is refused."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(100), UInt8(128), UInt8(200), UInt8(0)]
    var by_samples = _zeros_u8(4)
    assert_equal(raw.copy_and_apply_volume_factor_u8(lib, by_samples, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_u8(by_samples, [UInt8(50), UInt8(64), UInt8(100), UInt8(0)])

    var by_frames = _zeros_u8(4)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_u8(lib, by_frames, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_u8(by_frames, _zeros_u8(4))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_u8(lib, by_frames, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_u8(by_frames, [UInt8(50), UInt8(64), UInt8(100), UInt8(0)])


def test_s16_volume_factor_scales_samples_and_frames() raises:
    """Halving through the sample-counted and the frame-counted s16 copies gives the
    same result; a NULL-free call with zero channels is refused."""
    var lib = _lib()
    var src: List[Int16] = [Int16(1000), Int16(-1000), Int16(2000), Int16(0)]
    var by_samples = _zeros_s16(4)
    assert_equal(raw.copy_and_apply_volume_factor_s16(lib, by_samples, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_s16(by_samples, [Int16(500), Int16(-500), Int16(1000), Int16(0)])

    var by_frames = _zeros_s16(4)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s16(lib, by_frames, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_s16(by_frames, _zeros_s16(4))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s16(lib, by_frames, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_s16(by_frames, [Int16(500), Int16(-500), Int16(1000), Int16(0)])


def test_s24_volume_factor_scales_samples_and_frames() raises:
    """Halving through the sample-counted and the frame-counted s24 copies gives the
    same result; a NULL-free call with zero channels is refused."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(232), UInt8(3), UInt8(0), UInt8(24), UInt8(252), UInt8(255), UInt8(208), UInt8(7), UInt8(0), UInt8(0), UInt8(0), UInt8(0)]
    var by_samples = _zeros_u8(12)
    assert_equal(raw.copy_and_apply_volume_factor_s24(lib, by_samples, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_u8(by_samples, [UInt8(244), UInt8(1), UInt8(0), UInt8(12), UInt8(254), UInt8(255), UInt8(232), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)])

    var by_frames = _zeros_u8(12)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s24(lib, by_frames, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_u8(by_frames, _zeros_u8(12))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s24(lib, by_frames, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_u8(by_frames, [UInt8(244), UInt8(1), UInt8(0), UInt8(12), UInt8(254), UInt8(255), UInt8(232), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)])


def test_s32_volume_factor_scales_samples_and_frames() raises:
    """Halving through the sample-counted and the frame-counted s32 copies gives the
    same result; a NULL-free call with zero channels is refused."""
    var lib = _lib()
    var src: List[Int32] = [Int32(100000), Int32(-100000), Int32(200000), Int32(0)]
    var by_samples = _zeros_s32(4)
    assert_equal(raw.copy_and_apply_volume_factor_s32(lib, by_samples, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_s32(by_samples, [Int32(50000), Int32(-50000), Int32(100000), Int32(0)])

    var by_frames = _zeros_s32(4)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s32(lib, by_frames, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_s32(by_frames, _zeros_s32(4))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_s32(lib, by_frames, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_s32(by_frames, [Int32(50000), Int32(-50000), Int32(100000), Int32(0)])


def test_f32_volume_factor_scales_samples_and_frames() raises:
    """Halving through the sample-counted and the frame-counted f32 copies gives the
    same result; a NULL-free call with zero channels is refused."""
    var lib = _lib()
    var src: List[Float32] = [Float32(1.0), Float32(-1.0), Float32(0.5), Float32(0.0)]
    var by_samples = _zeros_f32(4)
    assert_equal(raw.copy_and_apply_volume_factor_f32(lib, by_samples, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_f32(by_samples, [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)])

    var by_frames = _zeros_f32(4)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_f32(lib, by_frames, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_f32(by_frames, _zeros_f32(4))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames_f32(lib, by_frames, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_f32(by_frames, [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)])


def test_volume_factor_dispatches_on_format_and_per_channel() raises:
    """The format-dispatching copy halves s16 frames; per-channel gains scale each
    channel on its own; an unknown format or zero channels is refused."""
    var lib = _lib()
    var src = _s16_bytes([Int16(1000), Int16(-1000), Int16(2000), Int16(0)])
    var dst = _zeros_u8(8)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames(lib, dst, src, UInt64(2), 0, UInt32(2), Float32(0.5)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_u8(dst, _zeros_u8(8))
    assert_equal(raw.copy_and_apply_volume_factor_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_s16(_s16_of(dst), [Int16(500), Int16(-500), Int16(1000), Int16(0)])

    var frames: List[Float32] = [Float32(1.0), Float32(1.0), Float32(0.5), Float32(-0.5)]
    var gains: List[Float32] = [Float32(0.5), Float32(2.0)]
    var scaled = _zeros_f32(4)
    assert_equal(raw.copy_and_apply_volume_factor_per_channel_f32(lib, scaled, frames, UInt64(2), UInt32(0), gains), MA_INVALID_ARGS)
    _same_f32(scaled, _zeros_f32(4))
    assert_equal(raw.copy_and_apply_volume_factor_per_channel_f32(lib, scaled, frames, UInt64(2), UInt32(2), gains), MA_SUCCESS)
    _same_f32(scaled, [Float32(0.5), Float32(2.0), Float32(0.25), Float32(-1.0)])


# ---- volume then clip, from a wider source ----------------------------------------


def test_volume_and_clip_u8_narrows_from_s16() raises:
    var lib = _lib()
    var src: List[Int16] = [Int16(200), Int16(-200), Int16(20), Int16(0)]
    var dst = _zeros_u8(4)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_u8(lib, dst, src, UInt64(4), Float32(200.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_u8(lib, dst, src, UInt64(4), Float32(-129.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_u8(lib, dst, src, UInt64(4), _nan()), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_u8(lib, dst, src, UInt64(4), Float32(1.0)), MA_SUCCESS)
    _same_u8(dst, [UInt8(255), UInt8(0), UInt8(148), UInt8(128)])


def test_volume_and_clip_s16_narrows_from_s32() raises:
    var lib = _lib()
    var src: List[Int32] = [Int32(40000), Int32(-40000), Int32(1000), Int32(0)]
    var dst = _zeros_s16(4)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s16(lib, dst, src, UInt64(4), Float32(200.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s16(lib, dst, src, UInt64(4), Float32(-129.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s16(lib, dst, src, UInt64(4), _nan()), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s16(lib, dst, src, UInt64(4), Float32(1.0)), MA_SUCCESS)
    _same_s16(dst, [Int16(32767), Int16(-32768), Int16(1000), Int16(0)])
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s16(lib, dst, src, UInt64(4), Float32(0.5)), MA_SUCCESS)
    _same_s16(dst, [Int16(20000), Int16(-20000), Int16(500), Int16(0)])


def test_volume_and_clip_s24_narrows_from_s64_into_packed_bytes() raises:
    var lib = _lib()
    var src: List[Int64] = [Int64(1) << 30, Int64(-1) << 30, Int64(1000), Int64(0)]
    var dst = _zeros_u8(12)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s24(lib, dst, src, UInt64(4), Float32(200.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s24(lib, dst, src, UInt64(4), Float32(-129.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s24(lib, dst, src, UInt64(4), _nan()), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s24(lib, dst, src, UInt64(4), Float32(1.0)), MA_SUCCESS)
    _same_u8(dst, [UInt8(255), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(232), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)])


def test_volume_and_clip_s32_narrows_from_s64() raises:
    var lib = _lib()
    var src: List[Int64] = [Int64(1) << 40, Int64(-1) << 40, Int64(1000), Int64(0)]
    var dst = _zeros_s32(4)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s32(lib, dst, src, UInt64(4), Float32(200.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s32(lib, dst, src, UInt64(4), Float32(-129.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s32(lib, dst, src, UInt64(4), _nan()), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_s32(lib, dst, src, UInt64(4), Float32(1.0)), MA_SUCCESS)
    _same_s32(dst, [Int32(2147483647), Int32(-2147483648), Int32(1000), Int32(0)])


def test_volume_and_clip_f32_clips_to_the_unit_range() raises:
    var lib = _lib()
    var src: List[Float32] = [Float32(2.0), Float32(-2.0), Float32(0.25), Float32(0.0)]
    var dst = _zeros_f32(4)
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_f32(lib, dst, src, UInt64(4), Float32(0.75)), MA_SUCCESS)
    _same_f32(dst, [Float32(1.0), Float32(-1.0), Float32(0.1875), Float32(0.0)])
    assert_equal(raw.copy_and_apply_volume_and_clip_samples_f32(lib, dst, src, UInt64(4), Float32(200.0)), MA_SUCCESS)
    _same_f32(dst, [Float32(1.0), Float32(-1.0), Float32(1.0), Float32(0.0)])


def test_volume_and_clip_frames_dispatches_on_format() raises:
    """Dispatched on s16, the source is s32; an unknown format or zero channels is refused."""
    var lib = _lib()
    var src = _s32_bytes([Int32(40000), Int32(-40000), Int32(1000), Int32(0)])
    var dst = _zeros_u8(8)
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, dst, src, UInt64(2), 0, UInt32(2), Float32(0.5)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_u8(dst, _zeros_u8(8))
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_s16(_s16_of(dst), [Int16(20000), Int16(-20000), Int16(500), Int16(0)])

    # Integer formats go through 8.8 fixed point, so a volume beyond +-128 is refused;
    # f32 has no such limit.
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(2), Float32(200.0)), MA_INVALID_ARGS)
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, dst, src, UInt64(2), FMT_S16, UInt32(2), _nan()), MA_INVALID_ARGS)
    var loud = _f32_bytes([Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)])
    var loud_out = _zeros_u8(16)
    assert_equal(raw.copy_and_apply_volume_and_clip_pcm_frames(lib, loud_out, loud, UInt64(2), FMT_F32, UInt32(2), Float32(200.0)), MA_SUCCESS)
    _same_f32(_f32_of(loud_out), [Float32(1.0), Float32(-1.0), Float32(1.0), Float32(0.0)])


# ---- blending, mixing, decibels and strings ------------------------------------------


def test_blend_interpolates_one_frame() raises:
    var lib = _lib()
    var a: List[Float32] = [Float32(1.0), Float32(0.0)]
    var b: List[Float32] = [Float32(0.0), Float32(1.0)]
    var out = _zeros_f32(2)
    assert_equal(raw.blend_f32(lib, out, a, b, Float32(0.25), UInt32(0)), MA_INVALID_ARGS)
    _same_f32(out, _zeros_f32(2))
    assert_equal(raw.blend_f32(lib, out, a, b, Float32(0.25), UInt32(2)), MA_SUCCESS)
    _same_f32(out, [Float32(0.75), Float32(0.25)])


def test_mix_adds_the_scaled_source_into_the_destination() raises:
    var lib = _lib()
    var dst: List[Float32] = [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)]
    var src: List[Float32] = [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)]
    assert_equal(raw.mix_pcm_frames_f32(lib, dst, src, UInt64(2), UInt32(0), Float32(0.5)), MA_INVALID_ARGS)
    _same_f32(dst, [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)])
    assert_equal(raw.mix_pcm_frames_f32(lib, dst, src, UInt64(2), UInt32(2), Float32(0.5)), MA_SUCCESS)
    _same_f32(dst, [Float32(1.25), Float32(0.75), Float32(1.125), Float32(1.0)])


def test_decibel_conversions_agree() raises:
    var lib = _lib()
    var unity = raw.volume_db_to_linear(lib, Float32(0.0))
    assert_equal(unity.result, MA_SUCCESS)
    assert_almost_equal(unity.value, Float32(1.0), atol=1e-6)
    var half = raw.volume_db_to_linear(lib, Float32(-6.0206))
    assert_almost_equal(half.value, Float32(0.5), atol=1e-5)

    var db = raw.volume_linear_to_db(lib, Float32(0.5))
    assert_equal(db.result, MA_SUCCESS)
    assert_almost_equal(db.value, Float32(-6.0206), atol=1e-3)
    assert_almost_equal(raw.volume_linear_to_db(lib, Float32(1.0)).value, Float32(0.0), atol=1e-6)


def test_copy_string_duplicates_into_the_buffer() raises:
    var lib = _lib()
    var copy = raw.copy_string(lib, "miniaudio")
    assert_equal(copy.result, MA_SUCCESS)
    assert_equal(copy.value, "miniaudio")
    assert_equal(raw.copy_string(lib, "").value, "")
    # "miniaudio" needs ten bytes with its terminator.
    assert_equal(raw.copy_string(lib, "miniaudio", UInt32(10)).result, MA_SUCCESS)
    var cramped = raw.copy_string(lib, "miniaudio", UInt32(9))
    assert_equal(cramped.result, MA_NO_SPACE)
    assert_equal(cramped.value, "")


# ---- NULL buffers and handles are refused by the shim, not passed to miniaudio ------


def test_null_buffers_are_refused() raises:
    """Every entry point that takes a buffer returns INVALID_ARGS for NULL."""
    var lib = _lib()
    assert_equal(Int(lib.handle.call["ma_shim_pcm_u8_to_u8", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_u8_to_s16", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_u8_to_s24", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_u8_to_s32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_u8_to_f32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s16_to_u8", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s16_to_s16", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s16_to_s24", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s16_to_s32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s16_to_f32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s24_to_u8", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s24_to_s16", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s24_to_s24", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s24_to_s32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s24_to_f32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s32_to_u8", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s32_to_s16", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s32_to_s24", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s32_to_s32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_s32_to_f32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_f32_to_u8", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_f32_to_s16", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_f32_to_s24", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_f32_to_s32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_f32_to_f32", Int32](Int(0), Int(0), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_deinterleave_u8", Int32](Int(0), UInt64(8), Int(0), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_interleave_u8", Int32](Int(0), Int(0), UInt64(8), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_u8", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_u8", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_u8", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_deinterleave_s16", Int32](Int(0), UInt64(8), Int(0), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_interleave_s16", Int32](Int(0), Int(0), UInt64(8), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_s16", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s16", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s16", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_deinterleave_s24", Int32](Int(0), UInt64(8), Int(0), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_interleave_s24", Int32](Int(0), Int(0), UInt64(8), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_s24", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s24", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s24", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_deinterleave_s32", Int32](Int(0), UInt64(8), Int(0), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_interleave_s32", Int32](Int(0), Int(0), UInt64(8), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_s32", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_s32", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_s32", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_deinterleave_f32", Int32](Int(0), UInt64(8), Int(0), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_interleave_f32", Int32](Int(0), Int(0), UInt64(8), UInt64(2), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_f32", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames_f32", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_samples_f32", Int32](Int(0), Int(0), UInt64(4), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_pcm_convert", Int32](Int(0), Int32(5), Int(0), Int32(2), UInt64(4), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_convert_pcm_frames_format", Int32](Int(0), Int32(5), Int(0), Int32(2), UInt64(2), UInt32(2), Int32(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_convert_frames", Int32](Int(0), UInt64(4), Int32(5), UInt32(1), UInt32(24000), Int(0), UInt64(4), Int32(5), UInt32(1), UInt32(48000), Int(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_convert_frames_ex", Int32](Int(0), UInt64(4), Int(0), UInt64(4), Int32(5), Int32(5), UInt32(1), UInt32(1), UInt32(48000), UInt32(24000), Int32(0), UInt32(1), Int(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_pcm_frames", Int32](Int(0), Int(0), UInt64(2), Int32(5), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_pcm_frames", Int32](Int(0), Int(0), UInt64(2), Int32(5), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_factor_per_channel_f32", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Int(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_and_apply_volume_and_clip_pcm_frames", Int32](Int(0), Int(0), UInt64(2), Int32(5), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_blend_f32", Int32](Int(0), Int(0), Int(0), Float32(0.5), UInt32(2))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_mix_pcm_frames_f32", Int32](Int(0), Int(0), UInt64(2), UInt32(2), Float32(0.5))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_volume_linear_to_db", Int32](Float32(0.5), Int(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_volume_db_to_linear", Int32](Float32(0.5), Int(0))), MA_INVALID_ARGS)
    assert_equal(Int(lib.handle.call["ma_shim_copy_string", Int32](Int(0), Int(0), UInt32(8))), MA_INVALID_ARGS)


def test_a_null_input_is_only_allowed_when_measuring() raises:
    """Converting frames reads no input when the output is NULL, and refuses a
    NULL input otherwise."""
    var lib = _lib()
    var holder = List[UInt64]()
    holder.append(UInt64(7))
    var dst = _zeros_u8(16)
    var rc = lib.handle.call["ma_shim_convert_frames", Int32](
        Int(0), UInt64(0), Int32(5), UInt32(1), UInt32(24000), Int(0), UInt64(100),
        Int32(5), UInt32(1), UInt32(48000), holder.unsafe_ptr(),
    )
    assert_equal(Int(rc), MA_SUCCESS)
    assert_equal(holder[0], UInt64(50))
    rc = lib.handle.call["ma_shim_convert_frames", Int32](
        dst.unsafe_ptr(), UInt64(4), Int32(5), UInt32(1), UInt32(24000), Int(0), UInt64(4),
        Int32(5), UInt32(1), UInt32(48000), holder.unsafe_ptr(),
    )
    assert_equal(Int(rc), MA_INVALID_ARGS)
    assert_equal(holder[0], UInt64(0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
