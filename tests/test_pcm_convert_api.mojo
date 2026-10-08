"""TDD tests for the idiomatic PCM conversion functions (Layer 3 free functions).

L3 behavioral: the converters turn real samples into the right numbers, in the
right layout. The values asserted here are the meaning of the numbers: s16
32767 is 0.99997 in f32 and -32768 is exactly -1.0; s24 is packed three bytes
little-endian; f32 beyond full scale clips; volume scales and clips; blend and
mix interpolate and add; decibels convert both ways. Dither is always set to
none where an exact value is asserted, because dither draws from a global
random generator.

A few upstream behaviours are pinned here on purpose (see the module docstring
of miniaudio.pcm_convert): u8 128 is 0 in s16 but 1/255 in f32, f32 -1.0 is
-32767 in s16, and the plain u8 volume copy scales the raw byte.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_raises,
    assert_almost_equal,
    TestSuite,
)
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.decoder import (
    SampleFormat,
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_U8,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S24,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
import miniaudio.pcm_convert as pc


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


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


# ---- what the numbers mean ------------------------------------------------------


def test_s16_extremes_are_just_under_and_exactly_full_scale_in_f32() raises:
    """32767 is 0.99997 (not 1.0), -32768 is exactly -1.0, and 16384 is exactly 0.5."""
    var lib = _lib()
    var got = pc.convert_s16_to_f32(lib, [Int16(32767), Int16(-32768), Int16(0), Int16(16384)])
    assert_almost_equal(got[0], Float32(0.99996948), atol=1e-7)
    assert_true(got[0] < Float32(1.0))
    assert_equal(got[1], Float32(-1.0))
    assert_equal(got[2], Float32(0.0))
    assert_equal(got[3], Float32(0.5))


def test_u8_128_is_zero_in_s16_but_one_255th_in_f32() raises:
    """Unsigned u8 centres on 128. s16 maps 128 to exactly 0; f32 maps it to 1/255."""
    var lib = _lib()
    var as_s16 = pc.convert_u8_to_s16(lib, [UInt8(0), UInt8(128), UInt8(255)])
    assert_equal(as_s16[0], Int16(-32768))
    assert_equal(as_s16[1], Int16(0))
    assert_equal(as_s16[2], Int16(32512))

    var as_f32 = pc.convert_u8_to_f32(lib, [UInt8(0), UInt8(128), UInt8(255)])
    assert_equal(as_f32[0], Float32(-1.0))
    assert_almost_equal(as_f32[1], Float32(1.0 / 255.0), atol=1e-7)
    assert_true(as_f32[1] > Float32(0.0))
    assert_equal(as_f32[2], Float32(1.0))


def test_f32_beyond_full_scale_is_clipped_in_s16() raises:
    """Values past +-1.0 clip to the s16 limits; exactly -1.0 stops at -32767."""
    var lib = _lib()
    var got = pc.convert_f32_to_s16(
        lib, [Float32(1.0), Float32(2.0), Float32(100.0), Float32(-2.0), Float32(-100.0)]
    )
    assert_equal(got[0], Int16(32767))
    assert_equal(got[1], Int16(32767))
    assert_equal(got[2], Int16(32767))
    # Which of -32767 / -32768 an overdriven negative sample lands on depends on
    # whether miniaudio's SIMD path or its scalar tail converted it, so only the
    # bound is pinned: it never wraps around to the positive side.
    assert_true(got[3] <= Int16(-32767))
    assert_true(got[4] <= Int16(-32767))

    var inside = pc.convert_f32_to_s16(lib, [Float32(0.0), Float32(0.5), Float32(-0.5), Float32(-1.0)])
    assert_equal(inside[0], Int16(0))
    assert_equal(inside[1], Int16(16383))
    assert_equal(inside[2], Int16(-16383))
    # Upstream quirk: -1.0 maps to -32767, one short of the s16 minimum.
    assert_equal(inside[3], Int16(-32767))


def test_f32_clips_in_every_integer_format() raises:
    var lib = _lib()
    var loud: List[Float32] = [Float32(3.0), Float32(-3.0)]
    var u8 = pc.convert_f32_to_u8(lib, loud)
    assert_equal(u8[0], UInt8(255))
    assert_equal(u8[1], UInt8(0))
    var s32 = pc.convert_f32_to_s32(lib, loud)
    assert_equal(s32[0], Int32(2147483647))
    assert_equal(s32[1], Int32(-2147483647))
    var s24 = pc.convert_f32_to_s24(lib, loud)
    _same_u8(s24, [UInt8(255), UInt8(255), UInt8(127), UInt8(1), UInt8(0), UInt8(128)])


def test_f32_to_u8_and_s32_hit_the_documented_points() raises:
    var lib = _lib()
    var src: List[Float32] = [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)]
    var u8 = pc.convert_f32_to_u8(lib, src)
    _same_u8(u8, [UInt8(127), UInt8(255), UInt8(0), UInt8(191)])
    var s32 = pc.convert_f32_to_s32(lib, src)
    _same_s32(s32, [Int32(0), Int32(2147483647), Int32(-2147483647), Int32(1073741823)])


def test_s24_is_packed_three_bytes_little_endian() raises:
    """Each s24 sample is three bytes, least significant first."""
    var lib = _lib()
    # s16 widens by 8 bits: 32767 is 0x7FFF00, -32768 is 0x800000, 1000 is 0x03E800.
    var from_s16 = pc.convert_s16_to_s24(lib, [Int16(32767), Int16(-32768), Int16(1000)])
    _same_u8(from_s16, [
        UInt8(0x00), UInt8(0xFF), UInt8(0x7F),
        UInt8(0x00), UInt8(0x00), UInt8(0x80),
        UInt8(0x00), UInt8(0xE8), UInt8(0x03),
    ])

    # f32 full scale is 0x7FFFFF, -1.0 is 0x800001, 0.5 is 0x3FFFFF.
    var from_f32 = pc.convert_f32_to_s24(lib, [Float32(1.0), Float32(-1.0), Float32(0.5)])
    _same_u8(from_f32, [
        UInt8(0xFF), UInt8(0xFF), UInt8(0x7F),
        UInt8(0x01), UInt8(0x00), UInt8(0x80),
        UInt8(0xFF), UInt8(0xFF), UInt8(0x3F),
    ])


def test_s24_reads_back_as_the_right_signed_values() raises:
    var lib = _lib()
    # 0x7FFFFF, 0x800000, 0x0003E8
    var s24: List[UInt8] = [
        UInt8(0xFF), UInt8(0xFF), UInt8(0x7F),
        UInt8(0x00), UInt8(0x00), UInt8(0x80),
        UInt8(0xE8), UInt8(0x03), UInt8(0x00),
    ]
    var s16 = pc.convert_s24_to_s16(lib, s24)
    _same_s16(s16, [Int16(32767), Int16(-32768), Int16(3)])
    var s32 = pc.convert_s24_to_s32(lib, s24)
    _same_s32(s32, [Int32(2147483392), Int32(-2147483648), Int32(256000)])
    var f32 = pc.convert_s24_to_f32(lib, s24)
    assert_almost_equal(f32[0], Float32(0.99999988), atol=1e-7)
    assert_equal(f32[1], Float32(-1.0))
    assert_almost_equal(f32[2], Float32(0.00011920929), atol=1e-8)
    var u8 = pc.convert_s24_to_u8(lib, s24)
    _same_u8(u8, [UInt8(255), UInt8(0), UInt8(128)])


def test_s32_narrows_by_dropping_low_bits() raises:
    var lib = _lib()
    var src: List[Int32] = [Int32(0), Int32(2147483647), Int32(-2147483648), Int32(65536000)]
    _same_s16(pc.convert_s32_to_s16(lib, src), [Int16(0), Int16(32767), Int16(-32768), Int16(1000)])
    _same_u8(pc.convert_s32_to_u8(lib, src), [UInt8(128), UInt8(255), UInt8(0), UInt8(131)])
    _same_f32(
        pc.convert_s32_to_f32(lib, src),
        [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.0305175781)],
    )


def test_same_format_conversion_copies() raises:
    var lib = _lib()
    _same_u8(pc.convert_u8_to_u8(lib, [UInt8(1), UInt8(200)]), [UInt8(1), UInt8(200)])
    _same_s16(pc.convert_s16_to_s16(lib, [Int16(-5), Int16(9)]), [Int16(-5), Int16(9)])
    _same_u8(
        pc.convert_s24_to_s24(lib, [UInt8(1), UInt8(2), UInt8(3)]),
        [UInt8(1), UInt8(2), UInt8(3)],
    )
    _same_s32(pc.convert_s32_to_s32(lib, [Int32(77), Int32(-77)]), [Int32(77), Int32(-77)])
    _same_f32(pc.convert_f32_to_f32(lib, [Float32(0.125)]), [Float32(0.125)])


def test_widening_conversions_round_trip_exactly() raises:
    """Conversions that lose nothing come back unchanged."""
    var lib = _lib()
    var s16: List[Int16] = [Int16(0), Int16(1), Int16(-1), Int16(32767), Int16(-32768), Int16(12345)]
    _same_s16(pc.convert_s32_to_s16(lib, pc.convert_s16_to_s32(lib, s16)), s16)
    _same_s16(pc.convert_s24_to_s16(lib, pc.convert_s16_to_s24(lib, s16)), s16)

    var u8: List[UInt8] = [UInt8(0), UInt8(1), UInt8(127), UInt8(128), UInt8(200), UInt8(255)]
    _same_u8(pc.convert_s16_to_u8(lib, pc.convert_u8_to_s16(lib, u8)), u8)
    _same_u8(pc.convert_s32_to_u8(lib, pc.convert_u8_to_s32(lib, u8)), u8)


def test_s16_survives_a_trip_through_f32_to_within_one_step() raises:
    var lib = _lib()
    var s16 = List[Int16]()
    for i in range(-32768, 32768, 997):
        s16.append(Int16(i))
    var back = pc.convert_f32_to_s16(lib, pc.convert_s16_to_f32(lib, s16))
    for i in range(len(s16)):
        assert_true(abs(Int(back[i]) - Int(s16[i])) <= 1)


def test_dither_none_is_deterministic_and_dither_stays_within_a_step() raises:
    """Without dither two runs agree exactly. Rectangle and triangle dither move a
    quantised sample by at most a couple of steps, and do move some of them."""
    var lib = _lib()
    var ramp = List[Float32]()
    for i in range(400):
        ramp.append(Float32(i - 200) / Float32(500.0))

    var first = pc.convert_f32_to_s16(lib, ramp)
    var second = pc.convert_f32_to_s16(lib, ramp)
    _same_s16(first, second)

    var rect = pc.convert_f32_to_s16(lib, ramp, dither_mode=pc.DITHER_MODE_RECTANGLE)
    var tri = pc.convert_f32_to_s16(lib, ramp, dither_mode=pc.DITHER_MODE_TRIANGLE)
    var rect_moved = 0
    var tri_moved = 0
    for i in range(400):
        assert_true(abs(Int(rect[i]) - Int(first[i])) <= 2)
        assert_true(abs(Int(tri[i]) - Int(first[i])) <= 2)
        if rect[i] != first[i]:
            rect_moved += 1
        if tri[i] != first[i]:
            tri_moved += 1
    assert_true(rect_moved > 0)
    assert_true(tri_moved > 0)

    # Narrowing to u8 quantises far more coarsely, so dither moves it too.
    var wide: List[Int16] = [Int16(1000), Int16(-2000), Int16(3000), Int16(0)]
    var plain_u8 = pc.convert_s16_to_u8(lib, wide)
    var dithered_u8 = pc.convert_s16_to_u8(lib, wide, dither_mode=pc.DITHER_MODE_TRIANGLE)
    for i in range(4):
        assert_true(abs(Int(dithered_u8[i]) - Int(plain_u8[i])) <= 2)


def test_dither_does_nothing_for_conversions_that_lose_nothing() raises:
    """Widening u8 to s16 is exact, so any dither mode gives the same answer."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(0), UInt8(64), UInt8(128), UInt8(255)]
    var none = pc.convert_u8_to_s16(lib, src)
    _same_s16(pc.convert_u8_to_s16(lib, src, dither_mode=pc.DITHER_MODE_RECTANGLE), none)
    _same_s16(pc.convert_u8_to_s16(lib, src, dither_mode=pc.DITHER_MODE_TRIANGLE), none)


def test_empty_input_gives_empty_output() raises:
    var lib = _lib()
    assert_equal(len(pc.convert_s16_to_f32(lib, List[Int16]())), 0)
    assert_equal(len(pc.convert_s24_to_s16(lib, List[UInt8]())), 0)
    assert_equal(len(pc.convert_f32_to_s24(lib, List[Float32]())), 0)


def test_a_bad_dither_mode_or_a_partial_s24_sample_raises() raises:
    var lib = _lib()
    with assert_raises():
        _ = pc.convert_s16_to_f32(lib, [Int16(1)], dither_mode=7)
    with assert_raises():
        _ = pc.convert_s24_to_s16(lib, [UInt8(1), UInt8(2), UInt8(3), UInt8(4)])
    with assert_raises():
        _ = pc.convert_samples(
            lib, [UInt8(1), UInt8(2), UInt8(3), UInt8(4)],
            format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_S16,
        )


# ---- every typed converter agrees with the dispatching one --------------------------


def test_typed_u8_converters_agree_with_convert_samples() raises:
    """All five u8_to_* converters give exactly what the dispatcher gives for the same input."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(0), UInt8(128), UInt8(255), UInt8(64)]
    var src_bytes = src.copy()

    var typed_u8 = pc.convert_u8_to_u8(lib, src)
    var via_u8 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_U8, format_out=SAMPLE_FORMAT_U8
    )
    _same_u8(typed_u8.copy(), via_u8)

    var typed_s16 = pc.convert_u8_to_s16(lib, src)
    var via_s16 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_U8, format_out=SAMPLE_FORMAT_S16
    )
    _same_u8(pc.s16_to_bytes(typed_s16), via_s16)

    var typed_s24 = pc.convert_u8_to_s24(lib, src)
    var via_s24 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_U8, format_out=SAMPLE_FORMAT_S24
    )
    _same_u8(typed_s24.copy(), via_s24)

    var typed_s32 = pc.convert_u8_to_s32(lib, src)
    var via_s32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_U8, format_out=SAMPLE_FORMAT_S32
    )
    _same_u8(pc.s32_to_bytes(typed_s32), via_s32)

    var typed_f32 = pc.convert_u8_to_f32(lib, src)
    var via_f32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_U8, format_out=SAMPLE_FORMAT_F32
    )
    _same_u8(pc.f32_to_bytes(typed_f32), via_f32)


def test_typed_s16_converters_agree_with_convert_samples() raises:
    """All five s16_to_* converters give exactly what the dispatcher gives for the same input."""
    var lib = _lib()
    var src: List[Int16] = [Int16(0), Int16(32767), Int16(-32768), Int16(1000)]
    var src_bytes = pc.s16_to_bytes(src)

    var typed_u8 = pc.convert_s16_to_u8(lib, src)
    var via_u8 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_U8
    )
    _same_u8(typed_u8.copy(), via_u8)

    var typed_s16 = pc.convert_s16_to_s16(lib, src)
    var via_s16 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_S16
    )
    _same_u8(pc.s16_to_bytes(typed_s16), via_s16)

    var typed_s24 = pc.convert_s16_to_s24(lib, src)
    var via_s24 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_S24
    )
    _same_u8(typed_s24.copy(), via_s24)

    var typed_s32 = pc.convert_s16_to_s32(lib, src)
    var via_s32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_S32
    )
    _same_u8(pc.s32_to_bytes(typed_s32), via_s32)

    var typed_f32 = pc.convert_s16_to_f32(lib, src)
    var via_f32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_F32
    )
    _same_u8(pc.f32_to_bytes(typed_f32), via_f32)


def test_typed_s24_converters_agree_with_convert_samples() raises:
    """All five s24_to_* converters give exactly what the dispatcher gives for the same input."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(0), UInt8(0), UInt8(0), UInt8(255), UInt8(255), UInt8(127), UInt8(0), UInt8(0), UInt8(128), UInt8(232), UInt8(3), UInt8(0)]
    var src_bytes = src.copy()

    var typed_u8 = pc.convert_s24_to_u8(lib, src)
    var via_u8 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_U8
    )
    _same_u8(typed_u8.copy(), via_u8)

    var typed_s16 = pc.convert_s24_to_s16(lib, src)
    var via_s16 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_S16
    )
    _same_u8(pc.s16_to_bytes(typed_s16), via_s16)

    var typed_s24 = pc.convert_s24_to_s24(lib, src)
    var via_s24 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_S24
    )
    _same_u8(typed_s24.copy(), via_s24)

    var typed_s32 = pc.convert_s24_to_s32(lib, src)
    var via_s32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_S32
    )
    _same_u8(pc.s32_to_bytes(typed_s32), via_s32)

    var typed_f32 = pc.convert_s24_to_f32(lib, src)
    var via_f32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S24, format_out=SAMPLE_FORMAT_F32
    )
    _same_u8(pc.f32_to_bytes(typed_f32), via_f32)


def test_typed_s32_converters_agree_with_convert_samples() raises:
    """All five s32_to_* converters give exactly what the dispatcher gives for the same input."""
    var lib = _lib()
    var src: List[Int32] = [Int32(0), Int32(2147483647), Int32(-2147483648), Int32(65536000)]
    var src_bytes = pc.s32_to_bytes(src)

    var typed_u8 = pc.convert_s32_to_u8(lib, src)
    var via_u8 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S32, format_out=SAMPLE_FORMAT_U8
    )
    _same_u8(typed_u8.copy(), via_u8)

    var typed_s16 = pc.convert_s32_to_s16(lib, src)
    var via_s16 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S32, format_out=SAMPLE_FORMAT_S16
    )
    _same_u8(pc.s16_to_bytes(typed_s16), via_s16)

    var typed_s24 = pc.convert_s32_to_s24(lib, src)
    var via_s24 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S32, format_out=SAMPLE_FORMAT_S24
    )
    _same_u8(typed_s24.copy(), via_s24)

    var typed_s32 = pc.convert_s32_to_s32(lib, src)
    var via_s32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S32, format_out=SAMPLE_FORMAT_S32
    )
    _same_u8(pc.s32_to_bytes(typed_s32), via_s32)

    var typed_f32 = pc.convert_s32_to_f32(lib, src)
    var via_f32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_S32, format_out=SAMPLE_FORMAT_F32
    )
    _same_u8(pc.f32_to_bytes(typed_f32), via_f32)


def test_typed_f32_converters_agree_with_convert_samples() raises:
    """All five f32_to_* converters give exactly what the dispatcher gives for the same input."""
    var lib = _lib()
    var src: List[Float32] = [Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)]
    var src_bytes = pc.f32_to_bytes(src)

    var typed_u8 = pc.convert_f32_to_u8(lib, src)
    var via_u8 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_U8
    )
    _same_u8(typed_u8.copy(), via_u8)

    var typed_s16 = pc.convert_f32_to_s16(lib, src)
    var via_s16 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_S16
    )
    _same_u8(pc.s16_to_bytes(typed_s16), via_s16)

    var typed_s24 = pc.convert_f32_to_s24(lib, src)
    var via_s24 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_S24
    )
    _same_u8(typed_s24.copy(), via_s24)

    var typed_s32 = pc.convert_f32_to_s32(lib, src)
    var via_s32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_S32
    )
    _same_u8(pc.s32_to_bytes(typed_s32), via_s32)

    var typed_f32 = pc.convert_f32_to_f32(lib, src)
    var via_f32 = pc.convert_samples(
        lib, src_bytes, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_F32
    )
    _same_u8(pc.f32_to_bytes(typed_f32), via_f32)


# ---- interleave / deinterleave, typed ---------------------------------------------


def test_u8_planes_round_trip_through_the_typed_pair() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave restores them."""
    var lib = _lib()
    var interleaved: List[UInt8] = [UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6)]
    var planes = pc.deinterleave_u8(lib, interleaved, channels=2)
    _same_u8(planes, [UInt8(1), UInt8(3), UInt8(5), UInt8(2), UInt8(4), UInt8(6)])
    _same_u8(pc.interleave_u8(lib, planes, channels=2), interleaved)


def test_s16_planes_round_trip_through_the_typed_pair() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave restores them."""
    var lib = _lib()
    var interleaved: List[Int16] = [Int16(10), Int16(-20), Int16(30), Int16(-40), Int16(50), Int16(-60)]
    var planes = pc.deinterleave_s16(lib, interleaved, channels=2)
    _same_s16(planes, [Int16(10), Int16(30), Int16(50), Int16(-20), Int16(-40), Int16(-60)])
    _same_s16(pc.interleave_s16(lib, planes, channels=2), interleaved)


def test_s24_planes_round_trip_through_the_typed_pair() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave restores them."""
    var lib = _lib()
    var interleaved: List[UInt8] = [UInt8(0), UInt8(10), UInt8(20), UInt8(1), UInt8(11), UInt8(21), UInt8(2), UInt8(12), UInt8(22), UInt8(3), UInt8(13), UInt8(23), UInt8(4), UInt8(14), UInt8(24), UInt8(5), UInt8(15), UInt8(25)]
    var planes = pc.deinterleave_s24(lib, interleaved, channels=2)
    _same_u8(planes, [UInt8(0), UInt8(10), UInt8(20), UInt8(2), UInt8(12), UInt8(22), UInt8(4), UInt8(14), UInt8(24), UInt8(1), UInt8(11), UInt8(21), UInt8(3), UInt8(13), UInt8(23), UInt8(5), UInt8(15), UInt8(25)])
    _same_u8(pc.interleave_s24(lib, planes, channels=2), interleaved)


def test_s32_planes_round_trip_through_the_typed_pair() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave restores them."""
    var lib = _lib()
    var interleaved: List[Int32] = [Int32(100000), Int32(-200000), Int32(300000), Int32(-400000), Int32(500000), Int32(-600000)]
    var planes = pc.deinterleave_s32(lib, interleaved, channels=2)
    _same_s32(planes, [Int32(100000), Int32(300000), Int32(500000), Int32(-200000), Int32(-400000), Int32(-600000)])
    _same_s32(pc.interleave_s32(lib, planes, channels=2), interleaved)


def test_f32_planes_round_trip_through_the_typed_pair() raises:
    """Stereo, three frames: deinterleave lays the channels end to end, interleave restores them."""
    var lib = _lib()
    var interleaved: List[Float32] = [Float32(0.125), Float32(-0.25), Float32(0.375), Float32(-0.5), Float32(0.625), Float32(-0.75)]
    var planes = pc.deinterleave_f32(lib, interleaved, channels=2)
    _same_f32(planes, [Float32(0.125), Float32(0.375), Float32(0.625), Float32(-0.25), Float32(-0.5), Float32(-0.75)])
    _same_f32(pc.interleave_f32(lib, planes, channels=2), interleaved)


def test_planes_reject_zero_channels_and_partial_frames() raises:
    var lib = _lib()
    with assert_raises():
        _ = pc.deinterleave_s16(lib, [Int16(1), Int16(2)], channels=0)
    with assert_raises():
        _ = pc.interleave_f32(lib, [Float32(1.0), Float32(2.0)], channels=0)
    # five samples cannot be whole stereo frames
    with assert_raises():
        _ = pc.deinterleave_s16(lib, [Int16(1), Int16(2), Int16(3), Int16(4), Int16(5)], channels=2)
    with assert_raises():
        _ = pc.interleave_u8(lib, [UInt8(1), UInt8(2), UInt8(3)], channels=2)
    # four s24 bytes are not whole stereo s24 frames either
    with assert_raises():
        _ = pc.deinterleave_s24(lib, [UInt8(1), UInt8(2), UInt8(3), UInt8(4)], channels=2)


# ---- conversion that chooses its format at run time -------------------------------


def test_convert_samples_turns_f32_bytes_into_s16_bytes() raises:
    var lib = _lib()
    var src = pc.f32_to_bytes([Float32(0.0), Float32(1.0), Float32(-1.0), Float32(0.5)])
    var out = pc.convert_samples(lib, src, format_in=SAMPLE_FORMAT_F32, format_out=SAMPLE_FORMAT_S16)
    _same_s16(pc.bytes_to_s16(out), [Int16(0), Int16(32767), Int16(-32767), Int16(16383)])


def test_convert_frames_format_counts_whole_frames() raises:
    """Two stereo s16 frames to f32; a length that is not whole frames raises."""
    var lib = _lib()
    var src = pc.s16_to_bytes([Int16(0), Int16(32767), Int16(-32768), Int16(1000)])
    var out = pc.convert_frames_format(
        lib, src, channels=2, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_F32
    )
    _same_f32(
        pc.bytes_to_f32(out),
        [Float32(0.0), Float32(0.99996948), Float32(-1.0), Float32(0.0305175781)],
    )
    with assert_raises():
        _ = pc.convert_frames_format(
            lib, pc.s16_to_bytes([Int16(1), Int16(2), Int16(3)]), channels=2,
            format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_F32,
        )


def test_an_unknown_format_raises_everywhere_it_is_taken() raises:
    var lib = _lib()
    var bytes = List[UInt8]()
    bytes.resize(8, UInt8(0))
    with assert_raises():
        _ = pc.convert_samples(lib, bytes, format_in=SAMPLE_FORMAT_UNKNOWN, format_out=SAMPLE_FORMAT_S16)
    with assert_raises():
        _ = pc.convert_samples(lib, bytes, format_in=SAMPLE_FORMAT_S16, format_out=SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = pc.convert_frames_format(lib, bytes, format_in=SAMPLE_FORMAT_UNKNOWN, format_out=SAMPLE_FORMAT_S16)
    with assert_raises():
        _ = pc.copy_frames(lib, bytes, format=SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = pc.scaled_frames(lib, bytes, Float32(0.5), format=SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = pc.scaled_and_clipped_frames(lib, bytes, Float32(0.5), format=SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = pc.bytes_per_sample(SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_UNKNOWN)


def test_copy_frames_copies_every_byte() raises:
    var lib = _lib()
    var s24 = List[UInt8]()
    for i in range(18):
        s24.append(UInt8(i * 7))
    _same_u8(pc.copy_frames(lib, s24, format=SAMPLE_FORMAT_S24, channels=2), s24)
    var f32 = pc.f32_to_bytes([Float32(0.25), Float32(-0.5), Float32(0.75), Float32(1.0)])
    _same_u8(pc.copy_frames(lib, f32, format=SAMPLE_FORMAT_F32, channels=2), f32)
    with assert_raises():
        _ = pc.copy_frames(lib, s24, format=SAMPLE_FORMAT_S24, channels=0)
    with assert_raises():
        _ = pc.copy_frames(lib, s24, format=SAMPLE_FORMAT_S32, channels=2)


# ---- format, channel and rate conversion ------------------------------------------


def _ramp_bytes() -> List[UInt8]:
    var ramp = List[Float32]()
    for i in range(100):
        ramp.append(Float32(i) / Float32(100))
    return pc.f32_to_bytes(ramp)


def test_halving_the_sample_rate_halves_the_frame_count() raises:
    """100 frames at 48 kHz become 50 at 24 kHz; the count is known before converting."""
    var lib = _lib()
    var src = _ramp_bytes()
    var expected = pc.converted_frame_count(
        lib, UInt64(100), format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000,
    )
    assert_equal(expected, UInt64(50))

    var done = pc.convert_frames(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000,
    )
    assert_equal(done.frames_written, UInt64(50))
    assert_equal(len(done.frames), 50 * 4)
    var out = pc.bytes_to_f32(done.frames)
    assert_equal(out[0], Float32(0.0))
    # a rising ramp stays rising, and ends near where it started ending
    for i in range(1, 50):
        assert_true(out[i] > out[i - 1])
    assert_true(out[49] > Float32(0.9))


def test_doubling_the_sample_rate_doubles_the_frame_count() raises:
    var lib = _lib()
    var done = pc.convert_frames(
        lib, _ramp_bytes(), format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=24000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=48000,
    )
    assert_equal(done.frames_written, UInt64(200))
    assert_equal(len(done.frames), 200 * 4)


def test_mono_becomes_stereo_by_copying_and_stereo_becomes_mono_by_averaging() raises:
    var lib = _lib()
    var mono = pc.f32_to_bytes([Float32(0.25), Float32(-0.5)])
    var stereo = pc.convert_frames(
        lib, mono, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=2, sample_rate_out=48000,
    )
    assert_equal(stereo.frames_written, UInt64(2))
    _same_f32(
        pc.bytes_to_f32(stereo.frames),
        [Float32(0.25), Float32(0.25), Float32(-0.5), Float32(-0.5)],
    )

    var two = pc.f32_to_bytes([Float32(0.25), Float32(0.75), Float32(-0.5), Float32(0.5)])
    var down = pc.convert_frames(
        lib, two, format_in=SAMPLE_FORMAT_F32, channels_in=2, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=48000,
    )
    assert_equal(down.frames_written, UInt64(2))
    _same_f32(pc.bytes_to_f32(down.frames), [Float32(0.5), Float32(0.0)])


def test_format_channels_and_rate_change_in_one_call() raises:
    """Mono f32 to stereo s16 at the same rate."""
    var lib = _lib()
    var done = pc.convert_frames(
        lib, pc.f32_to_bytes([Float32(0.5), Float32(-1.0)]),
        format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_S16, channels_out=2, sample_rate_out=48000,
    )
    assert_equal(done.frames_written, UInt64(2))
    _same_s16(
        pc.bytes_to_s16(done.frames),
        [Int16(16383), Int16(16383), Int16(-32767), Int16(-32767)],
    )


def test_convert_frames_ex_matches_the_plain_call_at_equal_rates_and_filters_at_unequal() raises:
    """With no rate change the config-driven call is the plain call. With one, the
    low-pass order is the only difference: order 0 is pure interpolation."""
    var lib = _lib()
    var src = _ramp_bytes()
    var plain = pc.convert_frames(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_S16, channels_out=1, sample_rate_out=48000,
    )
    var ex = pc.convert_frames_ex(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_S16, channels_out=1, sample_rate_out=48000,
    )
    assert_equal(plain.frames_written, UInt64(100))
    assert_equal(ex.frames_written, UInt64(100))
    _same_u8(plain.frames, ex.frames)

    var unfiltered = pc.bytes_to_f32(pc.convert_frames_ex(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000, lpf_order=0,
    ).frames)
    var filtered = pc.bytes_to_f32(pc.convert_frames_ex(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000, lpf_order=4,
    ).frames)
    assert_equal(len(unfiltered), 50)
    assert_equal(len(filtered), 50)
    assert_almost_equal(unfiltered[10], Float32(0.19), atol=1e-4)
    assert_almost_equal(unfiltered[25], Float32(0.49), atol=1e-4)
    assert_true(abs(filtered[10] - unfiltered[10]) > Float32(1e-3))


def test_convert_frames_ex_accepts_a_dither_mode() raises:
    """Dithering f32 down to u8 keeps the frame count and stays near the plain result."""
    var lib = _lib()
    var src = _ramp_bytes()
    var plain = pc.convert_frames_ex(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_U8, channels_out=1, sample_rate_out=48000,
    )
    var dithered = pc.convert_frames_ex(
        lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
        format_out=SAMPLE_FORMAT_U8, channels_out=1, sample_rate_out=48000,
        dither_mode=pc.DITHER_MODE_TRIANGLE,
    )
    assert_equal(dithered.frames_written, UInt64(100))
    for i in range(100):
        assert_true(abs(Int(dithered.frames[i]) - Int(plain.frames[i])) <= 2)


def test_conversion_arguments_miniaudio_cannot_handle_raise() raises:
    var lib = _lib()
    var src = _ramp_bytes()
    with assert_raises():
        _ = pc.convert_frames(
            lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=0,
        )
    with assert_raises():
        _ = pc.convert_frames(
            lib, src, format_in=SAMPLE_FORMAT_UNKNOWN, channels_in=1, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=48000,
        )
    with assert_raises():
        _ = pc.convert_frames(
            lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=0, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=48000,
        )
    with assert_raises():
        _ = pc.convert_frames_ex(
            lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000, lpf_order=99,
        )
    with assert_raises():
        _ = pc.convert_frames_ex(
            lib, src, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000, dither_mode=5,
        )
    # 99 bytes are not whole f32 frames
    var odd = List[UInt8]()
    odd.resize(99, UInt8(0))
    with assert_raises():
        _ = pc.convert_frames(
            lib, odd, format_in=SAMPLE_FORMAT_F32, channels_in=1, sample_rate_in=48000,
            format_out=SAMPLE_FORMAT_F32, channels_out=1, sample_rate_out=24000,
        )


# ---- volume, copying rather than in place -----------------------------------------


def test_scaling_leaves_the_source_untouched_and_halves_the_copy() raises:
    var lib = _lib()
    var src: List[Float32] = [Float32(1.0), Float32(0.5), Float32(-1.0)]
    var got = pc.scaled_f32(lib, src, Float32(0.5))
    _same_f32(got, [Float32(0.5), Float32(0.25), Float32(-0.5)])
    _same_f32(src, [Float32(1.0), Float32(0.5), Float32(-1.0)])


def test_a_volume_above_one_amplifies_without_clipping_f32() raises:
    var lib = _lib()
    var got = pc.scaled_f32(lib, [Float32(0.75), Float32(-0.5)], Float32(2.0))
    _same_f32(got, [Float32(1.5), Float32(-1.0)])


def test_u8_volume_scales_the_raw_byte_so_silence_is_not_preserved() raises:
    """Upstream quirk: the plain u8 volume copy multiplies the unsigned byte, so
    128 (silence) at half volume is 64, a DC offset."""
    var lib = _lib()
    var got = pc.scaled_u8(lib, [UInt8(100), UInt8(128), UInt8(200), UInt8(0)], Float32(0.5))
    _same_u8(got, [UInt8(50), UInt8(64), UInt8(100), UInt8(0)])


def test_u8_volume_by_samples_and_by_frames_agree() raises:
    """Halving u8 samples gives the same answer counted in samples, in stereo frames and
    through the format-dispatching entry point."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(100), UInt8(128), UInt8(200), UInt8(0)]
    var by_samples = pc.scaled_u8(lib, src, Float32(0.5))
    _same_u8(by_samples, [UInt8(50), UInt8(64), UInt8(100), UInt8(0)])
    var by_frames = pc.scaled_frames_u8(lib, src, Float32(0.5), channels=2)
    _same_u8(by_frames, [UInt8(50), UInt8(64), UInt8(100), UInt8(0)])
    var dispatched = pc.scaled_frames(
        lib, src.copy(), Float32(0.5), format=SAMPLE_FORMAT_U8, channels=2
    )
    _same_u8(dispatched, by_frames.copy())


def test_s16_volume_by_samples_and_by_frames_agree() raises:
    """Halving s16 samples gives the same answer counted in samples, in stereo frames and
    through the format-dispatching entry point."""
    var lib = _lib()
    var src: List[Int16] = [Int16(1000), Int16(-1000), Int16(2000), Int16(0)]
    var by_samples = pc.scaled_s16(lib, src, Float32(0.5))
    _same_s16(by_samples, [Int16(500), Int16(-500), Int16(1000), Int16(0)])
    var by_frames = pc.scaled_frames_s16(lib, src, Float32(0.5), channels=2)
    _same_s16(by_frames, [Int16(500), Int16(-500), Int16(1000), Int16(0)])
    var dispatched = pc.scaled_frames(
        lib, pc.s16_to_bytes(src), Float32(0.5), format=SAMPLE_FORMAT_S16, channels=2
    )
    _same_u8(dispatched, pc.s16_to_bytes(by_frames))


def test_s24_volume_by_samples_and_by_frames_agree() raises:
    """Halving s24 samples gives the same answer counted in samples, in stereo frames and
    through the format-dispatching entry point."""
    var lib = _lib()
    var src: List[UInt8] = [UInt8(232), UInt8(3), UInt8(0), UInt8(24), UInt8(252), UInt8(255), UInt8(208), UInt8(7), UInt8(0), UInt8(0), UInt8(0), UInt8(0)]
    var by_samples = pc.scaled_s24(lib, src, Float32(0.5))
    _same_u8(by_samples, [UInt8(244), UInt8(1), UInt8(0), UInt8(12), UInt8(254), UInt8(255), UInt8(232), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    var by_frames = pc.scaled_frames_s24(lib, src, Float32(0.5), channels=2)
    _same_u8(by_frames, [UInt8(244), UInt8(1), UInt8(0), UInt8(12), UInt8(254), UInt8(255), UInt8(232), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    var dispatched = pc.scaled_frames(
        lib, src.copy(), Float32(0.5), format=SAMPLE_FORMAT_S24, channels=2
    )
    _same_u8(dispatched, by_frames.copy())


def test_s32_volume_by_samples_and_by_frames_agree() raises:
    """Halving s32 samples gives the same answer counted in samples, in stereo frames and
    through the format-dispatching entry point."""
    var lib = _lib()
    var src: List[Int32] = [Int32(100000), Int32(-100000), Int32(200000), Int32(0)]
    var by_samples = pc.scaled_s32(lib, src, Float32(0.5))
    _same_s32(by_samples, [Int32(50000), Int32(-50000), Int32(100000), Int32(0)])
    var by_frames = pc.scaled_frames_s32(lib, src, Float32(0.5), channels=2)
    _same_s32(by_frames, [Int32(50000), Int32(-50000), Int32(100000), Int32(0)])
    var dispatched = pc.scaled_frames(
        lib, pc.s32_to_bytes(src), Float32(0.5), format=SAMPLE_FORMAT_S32, channels=2
    )
    _same_u8(dispatched, pc.s32_to_bytes(by_frames))


def test_f32_volume_by_samples_and_by_frames_agree() raises:
    """Halving f32 samples gives the same answer counted in samples, in stereo frames and
    through the format-dispatching entry point."""
    var lib = _lib()
    var src: List[Float32] = [Float32(1.0), Float32(-1.0), Float32(0.5), Float32(0.0)]
    var by_samples = pc.scaled_f32(lib, src, Float32(0.5))
    _same_f32(by_samples, [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)])
    var by_frames = pc.scaled_frames_f32(lib, src, Float32(0.5), channels=2)
    _same_f32(by_frames, [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)])
    var dispatched = pc.scaled_frames(
        lib, pc.f32_to_bytes(src), Float32(0.5), format=SAMPLE_FORMAT_F32, channels=2
    )
    _same_u8(dispatched, pc.f32_to_bytes(by_frames))


def test_per_channel_gains_scale_each_channel_on_its_own() raises:
    var lib = _lib()
    var frames: List[Float32] = [
        Float32(1.0), Float32(1.0), Float32(0.5), Float32(-0.5), Float32(-1.0), Float32(0.25)
    ]
    var got = pc.scaled_per_channel(lib, frames, [Float32(0.5), Float32(2.0)])
    _same_f32(got, [
        Float32(0.5), Float32(2.0), Float32(0.25), Float32(-1.0), Float32(-0.5), Float32(0.5)
    ])
    with assert_raises():
        _ = pc.scaled_per_channel(lib, frames, List[Float32]())
    with assert_raises():
        _ = pc.scaled_per_channel(lib, frames, [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)])


def test_scaled_frames_rejects_partial_frames() raises:
    var lib = _lib()
    with assert_raises():
        _ = pc.scaled_frames_f32(lib, [Float32(1.0), Float32(1.0), Float32(1.0)], Float32(0.5), channels=2)
    with assert_raises():
        _ = pc.scaled_frames_s16(lib, [Int16(1)], Float32(0.5), channels=0)
    with assert_raises():
        _ = pc.scaled_s24(lib, [UInt8(1), UInt8(2)], Float32(0.5))


# ---- volume then clip, from a wider source ----------------------------------------


def test_volume_then_clip_narrows_s32_to_s16() raises:
    var lib = _lib()
    var src: List[Int32] = [Int32(40000), Int32(-40000), Int32(1000), Int32(0)]
    _same_s16(
        pc.scaled_and_clipped_s16(lib, src, Float32(1.0)),
        [Int16(32767), Int16(-32768), Int16(1000), Int16(0)],
    )
    _same_s16(
        pc.scaled_and_clipped_s16(lib, src, Float32(0.5)),
        [Int16(20000), Int16(-20000), Int16(500), Int16(0)],
    )
    _same_s16(
        pc.scaled_and_clipped_s16(lib, src, Float32(2.0)),
        [Int16(32767), Int16(-32768), Int16(2000), Int16(0)],
    )


def test_volume_then_clip_narrows_s16_to_u8() raises:
    var lib = _lib()
    var src: List[Int16] = [Int16(200), Int16(-200), Int16(20), Int16(0)]
    _same_u8(
        pc.scaled_and_clipped_u8(lib, src, Float32(1.0)),
        [UInt8(255), UInt8(0), UInt8(148), UInt8(128)],
    )


def test_volume_then_clip_narrows_s64_to_packed_s24() raises:
    var lib = _lib()
    var src: List[Int64] = [Int64(1) << 30, Int64(-1) << 30, Int64(1000), Int64(0)]
    var got = pc.scaled_and_clipped_s24(lib, src, Float32(1.0))
    _same_u8(got, [
        UInt8(0xFF), UInt8(0xFF), UInt8(0x7F),
        UInt8(0x00), UInt8(0x00), UInt8(0x80),
        UInt8(0xE8), UInt8(0x03), UInt8(0x00),
        UInt8(0x00), UInt8(0x00), UInt8(0x00),
    ])


def test_volume_then_clip_narrows_s64_to_s32() raises:
    var lib = _lib()
    var src: List[Int64] = [Int64(1) << 40, Int64(-1) << 40, Int64(1000), Int64(0)]
    _same_s32(
        pc.scaled_and_clipped_s32(lib, src, Float32(1.0)),
        [Int32(2147483647), Int32(-2147483648), Int32(1000), Int32(0)],
    )


def test_volume_then_clip_bounds_f32_to_one() raises:
    var lib = _lib()
    var src: List[Float32] = [Float32(2.0), Float32(-2.0), Float32(0.25), Float32(0.0)]
    _same_f32(
        pc.scaled_and_clipped_f32(lib, src, Float32(0.75)),
        [Float32(1.0), Float32(-1.0), Float32(0.1875), Float32(0.0)],
    )
    _same_f32(
        pc.scaled_and_clipped_f32(lib, src, Float32(0.25)),
        [Float32(0.5), Float32(-0.5), Float32(0.0625), Float32(0.0)],
    )


def test_volume_then_clip_dispatches_with_the_wider_source() raises:
    """Dispatched on s16 the source is s32 (four bytes per sample); on f32 it is f32."""
    var lib = _lib()
    var wide = pc.s32_to_bytes([Int32(40000), Int32(-40000), Int32(1000), Int32(0)])
    var got = pc.scaled_and_clipped_frames(
        lib, wide, Float32(0.5), format=SAMPLE_FORMAT_S16, channels=2
    )
    _same_s16(pc.bytes_to_s16(got), [Int16(20000), Int16(-20000), Int16(500), Int16(0)])

    var f32 = pc.f32_to_bytes([Float32(2.0), Float32(-2.0), Float32(0.25), Float32(0.0)])
    var got_f32 = pc.scaled_and_clipped_frames(
        lib, f32, Float32(0.75), format=SAMPLE_FORMAT_F32, channels=2
    )
    _same_f32(pc.bytes_to_f32(got_f32), [Float32(1.0), Float32(-1.0), Float32(0.1875), Float32(0.0)])

    assert_equal(pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_U8), 2)
    assert_equal(pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_S16), 4)
    assert_equal(pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_S24), 8)
    assert_equal(pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_S32), 8)
    assert_equal(pc.clip_source_bytes_per_sample(SAMPLE_FORMAT_F32), 4)

    # three s32 samples are not whole stereo frames
    with assert_raises():
        _ = pc.scaled_and_clipped_frames(
            lib, pc.s32_to_bytes([Int32(1), Int32(2), Int32(3)]), Float32(1.0),
            format=SAMPLE_FORMAT_S16, channels=2,
        )


def test_integer_volumes_beyond_128_raise_but_f32_takes_any() raises:
    """Integer clipping uses 8.8 fixed point, which overflows past +-128, so
    miniaudio's result would have the wrong sign; the shim refuses it. f32 has no such limit."""
    var lib = _lib()
    with assert_raises():
        _ = pc.scaled_and_clipped_s16(lib, [Int32(1000)], Float32(200.0))
    with assert_raises():
        _ = pc.scaled_and_clipped_u8(lib, [Int16(10)], Float32(-129.0))
    with assert_raises():
        _ = pc.scaled_and_clipped_s24(lib, [Int64(10)], Float32(1000.0))
    with assert_raises():
        _ = pc.scaled_and_clipped_s32(lib, [Int64(10)], Float32(1000.0))
    with assert_raises():
        _ = pc.scaled_and_clipped_frames(
            lib, pc.s32_to_bytes([Int32(1), Int32(2)]), Float32(200.0),
            format=SAMPLE_FORMAT_S16, channels=2,
        )
    # 127.5 is the largest kind of gain 8.8 fixed point can hold; it is accepted
    var ok = pc.scaled_and_clipped_s16(lib, [Int32(100), Int32(-100)], Float32(127.5))
    _same_s16(ok, [Int16(12750), Int16(-12750)])
    var f32 = pc.scaled_and_clipped_f32(lib, [Float32(0.5), Float32(-0.5)], Float32(1000.0))
    _same_f32(f32, [Float32(1.0), Float32(-1.0)])


def test_volume_one_clips_and_volume_zero_silences_through_the_dispatcher() raises:
    """The frame entry point short-cuts volume 1 (clip only) and volume 0 (silence)."""
    var lib = _lib()
    var wide = pc.s32_to_bytes([Int32(40000), Int32(-40000), Int32(1000), Int32(0)])
    var unity = pc.scaled_and_clipped_frames(
        lib, wide, Float32(1.0), format=SAMPLE_FORMAT_S16, channels=2
    )
    _same_s16(pc.bytes_to_s16(unity), [Int16(32767), Int16(-32768), Int16(1000), Int16(0)])
    var muted = pc.scaled_and_clipped_frames(
        lib, wide, Float32(0.0), format=SAMPLE_FORMAT_S16, channels=2
    )
    _same_s16(pc.bytes_to_s16(muted), [Int16(0), Int16(0), Int16(0), Int16(0)])


# ---- blending, mixing, decibels and strings ----------------------------------------


def test_blend_interpolates_between_two_frames() raises:
    var lib = _lib()
    var a: List[Float32] = [Float32(1.0), Float32(0.0)]
    var b: List[Float32] = [Float32(0.0), Float32(1.0)]
    _same_f32(pc.blend(lib, a, b, Float32(0.0)), [Float32(1.0), Float32(0.0)])
    _same_f32(pc.blend(lib, a, b, Float32(0.25)), [Float32(0.75), Float32(0.25)])
    _same_f32(pc.blend(lib, a, b, Float32(0.5)), [Float32(0.5), Float32(0.5)])
    _same_f32(pc.blend(lib, a, b, Float32(1.0)), [Float32(0.0), Float32(1.0)])


def test_blend_extrapolates_outside_zero_to_one() raises:
    var lib = _lib()
    var a: List[Float32] = [Float32(1.0), Float32(0.0)]
    var b: List[Float32] = [Float32(0.0), Float32(1.0)]
    _same_f32(pc.blend(lib, a, b, Float32(2.0)), [Float32(-1.0), Float32(2.0)])


def test_blend_needs_matching_non_empty_frames() raises:
    var lib = _lib()
    with assert_raises():
        _ = pc.blend(lib, [Float32(1.0)], [Float32(1.0), Float32(2.0)], Float32(0.5))
    with assert_raises():
        _ = pc.blend(lib, List[Float32](), List[Float32](), Float32(0.5))


def test_mix_adds_the_source_at_the_given_volume() raises:
    var lib = _lib()
    var dst: List[Float32] = [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)]
    var src: List[Float32] = [Float32(0.5), Float32(-0.5), Float32(0.25), Float32(0.0)]
    pc.mix_into(lib, dst, src, Float32(0.5), channels=2)
    _same_f32(dst, [Float32(1.25), Float32(0.75), Float32(1.125), Float32(1.0)])
    # volume 1 adds as-is
    pc.mix_into(lib, dst, src, Float32(1.0), channels=2)
    _same_f32(dst, [Float32(1.75), Float32(0.25), Float32(1.375), Float32(1.0)])
    # volume 0 changes nothing
    pc.mix_into(lib, dst, src, Float32(0.0), channels=2)
    _same_f32(dst, [Float32(1.75), Float32(0.25), Float32(1.375), Float32(1.0)])


def test_mix_does_not_clip_and_leaves_the_tail_alone() raises:
    var lib = _lib()
    var dst: List[Float32] = [Float32(0.9), Float32(0.9), Float32(0.7)]
    pc.mix_into(lib, dst, [Float32(0.9), Float32(0.9)], Float32(1.0), channels=1)
    _same_f32(dst, [Float32(1.8), Float32(1.8), Float32(0.7)])


def test_mix_rejects_a_short_destination_and_partial_frames() raises:
    var lib = _lib()
    var dst: List[Float32] = [Float32(0.0), Float32(0.0)]
    with assert_raises():
        pc.mix_into(lib, dst, [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)], Float32(1.0), channels=2)
    with assert_raises():
        pc.mix_into(lib, dst, [Float32(1.0), Float32(1.0), Float32(1.0)], Float32(1.0), channels=2)
    with assert_raises():
        pc.mix_into(lib, dst, [Float32(1.0)], Float32(1.0), channels=0)


def test_decibels_convert_to_linear_gain() raises:
    """0 dB is unity, -6.0206 dB is half, +6.0206 dB is double, -20 dB is a tenth."""
    var lib = _lib()
    assert_almost_equal(pc.db_to_linear(lib, Float32(0.0)), Float32(1.0), atol=1e-6)
    assert_almost_equal(pc.db_to_linear(lib, Float32(-6.0206)), Float32(0.5), atol=1e-5)
    assert_almost_equal(pc.db_to_linear(lib, Float32(6.0206)), Float32(2.0), atol=1e-5)
    assert_almost_equal(pc.db_to_linear(lib, Float32(-20.0)), Float32(0.1), atol=1e-6)


def test_linear_gain_converts_to_decibels() raises:
    var lib = _lib()
    assert_almost_equal(pc.linear_to_db(lib, Float32(1.0)), Float32(0.0), atol=1e-6)
    assert_almost_equal(pc.linear_to_db(lib, Float32(0.5)), Float32(-6.0206), atol=1e-3)
    assert_almost_equal(pc.linear_to_db(lib, Float32(2.0)), Float32(6.0206), atol=1e-3)
    assert_almost_equal(pc.linear_to_db(lib, Float32(0.1)), Float32(-20.0), atol=1e-4)


def test_decibel_edges_are_minus_infinity_and_nan() raises:
    """Silence has no decibel value (-inf), and a negative gain is not a number."""
    var lib = _lib()
    var silence = pc.linear_to_db(lib, Float32(0.0))
    assert_true(silence < Float32(-1.0e30))
    var negative = pc.linear_to_db(lib, Float32(-1.0))
    assert_true(negative != negative)


def test_decibels_round_trip() raises:
    var lib = _lib()
    for db in range(-60, 13, 6):
        var linear = pc.db_to_linear(lib, Float32(db))
        assert_almost_equal(pc.linear_to_db(lib, linear), Float32(db), atol=1e-3)


def test_duplicate_string_returns_an_equal_copy() raises:
    var lib = _lib()
    assert_equal(pc.duplicate_string(lib, "miniaudio"), "miniaudio")
    assert_equal(pc.duplicate_string(lib, ""), "")
    assert_equal(pc.duplicate_string(lib, "a longer sentence, with punctuation."), "a longer sentence, with punctuation.")


def test_duplicate_string_raises_when_the_buffer_is_too_small() raises:
    """Nine characters need ten bytes with the terminator."""
    var lib = _lib()
    assert_equal(pc.duplicate_string(lib, "miniaudio", capacity=UInt32(10)), "miniaudio")
    with assert_raises():
        _ = pc.duplicate_string(lib, "miniaudio", capacity=UInt32(9))
    with assert_raises():
        _ = pc.duplicate_string(lib, "miniaudio", capacity=UInt32(0))


# ---- byte helpers ----------------------------------------------------------------------


def test_the_byte_helpers_round_trip_and_reject_partial_samples() raises:
    var lib = _lib()
    var f: List[Float32] = [Float32(0.5), Float32(-1.0), Float32(0.125)]
    _same_f32(pc.bytes_to_f32(pc.f32_to_bytes(f)), f)
    assert_equal(len(pc.f32_to_bytes(f)), 12)
    var s: List[Int16] = [Int16(-32768), Int16(32767), Int16(1)]
    _same_s16(pc.bytes_to_s16(pc.s16_to_bytes(s)), s)
    assert_equal(len(pc.s16_to_bytes(s)), 6)
    var w: List[Int32] = [Int32(-2147483648), Int32(2147483647), Int32(7)]
    _same_s32(pc.bytes_to_s32(pc.s32_to_bytes(w)), w)
    assert_equal(len(pc.s64_to_bytes([Int64(1), Int64(2)])), 16)
    with assert_raises():
        _ = pc.bytes_to_f32([UInt8(1), UInt8(2), UInt8(3)])
    with assert_raises():
        _ = pc.bytes_to_s16([UInt8(1)])
    with assert_raises():
        _ = pc.bytes_to_s32([UInt8(1), UInt8(2)])
    assert_equal(pc.bytes_per_sample(SAMPLE_FORMAT_U8), 1)
    assert_equal(pc.bytes_per_sample(SAMPLE_FORMAT_S16), 2)
    assert_equal(pc.bytes_per_sample(SAMPLE_FORMAT_S24), 3)
    assert_equal(pc.bytes_per_sample(SAMPLE_FORMAT_S32), 4)
    assert_equal(pc.bytes_per_sample(SAMPLE_FORMAT_F32), 4)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
