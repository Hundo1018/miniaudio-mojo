"""TDD tests for the idiomatic PCM frame utilities (Layer 3 free functions).

L3 behavioral: interleave and deinterleave move real samples between layouts and
round-trip in every format; silence zeroes (and silences u8 to 128); the offset
helpers advance by exactly frames * channels * bytes-per-sample; and the debug
sine fill produces a bounded 400 Hz wave with the shape a sine must have. Bad
formats, lengths that are not whole frames, and offsets outside the buffer raise
instead of reaching miniaudio.
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
import miniaudio.frame_util as fu
import miniaudio.pcm_convert as pc


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int) -> List[UInt8]:
    var out = List[UInt8](capacity=n)
    for i in range(n):
        out.append(UInt8(i + 1))
    return out^


def _same(got: List[UInt8], want: List[UInt8]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_equal(got[i], want[i])


def test_deinterleave_puts_each_channel_in_its_own_plane() raises:
    """Stereo f32 L0 R0 L1 R1 L2 R2 comes out as L0 L1 L2 R0 R1 R2."""
    var lib = _lib()
    var interleaved = pc.f32_to_bytes([
        Float32(0.1), Float32(-0.1), Float32(0.2), Float32(-0.2), Float32(0.3), Float32(-0.3)
    ])
    var planes = pc.bytes_to_f32(
        fu.deinterleave(lib, interleaved, format=SAMPLE_FORMAT_F32, channels=2)
    )
    var want: List[Float32] = [
        Float32(0.1), Float32(0.2), Float32(0.3), Float32(-0.1), Float32(-0.2), Float32(-0.3)
    ]
    assert_equal(len(planes), 6)
    for i in range(6):
        assert_equal(planes[i], want[i])


def test_interleave_weaves_planes_back_into_frames() raises:
    """Left plane then right plane becomes alternating left / right s16 frames."""
    var lib = _lib()
    var planes = pc.s16_to_bytes([Int16(1), Int16(2), Int16(3), Int16(-1), Int16(-2), Int16(-3)])
    var woven = pc.bytes_to_s16(
        fu.interleave(lib, planes, format=SAMPLE_FORMAT_S16, channels=2)
    )
    var want: List[Int16] = [Int16(1), Int16(-1), Int16(2), Int16(-2), Int16(3), Int16(-3)]
    assert_equal(len(woven), 6)
    for i in range(6):
        assert_equal(woven[i], want[i])


def test_round_trip_restores_the_original_in_every_format() raises:
    """Deinterleave then interleave is the identity for each format and 1..4 channels."""
    var lib = _lib()
    var formats: List[SampleFormat] = [
        SAMPLE_FORMAT_U8, SAMPLE_FORMAT_S16, SAMPLE_FORMAT_S24, SAMPLE_FORMAT_S32,
        SAMPLE_FORMAT_F32,
    ]
    for fi in range(len(formats)):
        var format = formats[fi]
        for channels in range(1, 5):
            var total = 7 * channels * pc.bytes_per_sample(format)
            var original = _ramp(total)
            var planes = fu.deinterleave(lib, original, format=format, channels=UInt32(channels))
            var back = fu.interleave(lib, planes, format=format, channels=UInt32(channels))
            _same(back, original)
            if channels > 1:
                # a real layout change, not an accidental copy
                var differs = False
                for i in range(total):
                    if planes[i] != original[i]:
                        differs = True
                assert_true(differs)


def test_s24_samples_stay_three_bytes_wide() raises:
    """Mono s24 is untouched; stereo s24 moves whole three-byte samples."""
    var lib = _lib()
    var stereo: List[UInt8] = [
        UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6),
        UInt8(7), UInt8(8), UInt8(9), UInt8(10), UInt8(11), UInt8(12),
    ]
    var planes = fu.deinterleave(lib, stereo, format=SAMPLE_FORMAT_S24, channels=2)
    _same(planes, [
        UInt8(1), UInt8(2), UInt8(3), UInt8(7), UInt8(8), UInt8(9),
        UInt8(4), UInt8(5), UInt8(6), UInt8(10), UInt8(11), UInt8(12),
    ])


def test_silence_zeroes_signed_formats_and_centres_u8() raises:
    """Unsigned u8 silence is 128; s16, s24, s32 and f32 silence is all-zero bytes."""
    var lib = _lib()
    var u8 = fu.silent_frames(lib, 6, format=SAMPLE_FORMAT_U8, channels=2)
    assert_equal(len(u8), 12)
    for i in range(12):
        assert_equal(u8[i], UInt8(128))

    var s16 = fu.silent_frames(lib, 6, format=SAMPLE_FORMAT_S16, channels=2)
    assert_equal(len(s16), 24)
    for i in range(24):
        assert_equal(s16[i], UInt8(0))

    var s24 = fu.silent_frames(lib, 3, format=SAMPLE_FORMAT_S24, channels=2)
    assert_equal(len(s24), 18)
    var f32 = pc.bytes_to_f32(fu.silent_frames(lib, 4, format=SAMPLE_FORMAT_F32, channels=2))
    for i in range(8):
        assert_equal(f32[i], Float32(0.0))


def test_silence_overwrites_existing_audio_in_place() raises:
    """A buffer of loud s16 samples is silenced; a buffer of loud u8 goes to 128."""
    var lib = _lib()
    var loud = pc.s16_to_bytes([Int16(32767), Int16(-32768), Int16(1000), Int16(-1000)])
    fu.silence(lib, loud, format=SAMPLE_FORMAT_S16, channels=2)
    for s in pc.bytes_to_s16(loud):
        assert_equal(s, Int16(0))

    var bytes: List[UInt8] = [UInt8(0), UInt8(255), UInt8(7), UInt8(200)]
    fu.silence(lib, bytes, format=SAMPLE_FORMAT_U8, channels=2)
    _same(bytes, [UInt8(128), UInt8(128), UInt8(128), UInt8(128)])


def test_offset_is_frames_times_channels_times_sample_width() raises:
    """Moving N frames in advances N * channels * bytes-per-sample bytes."""
    var lib = _lib()
    var s16 = List[UInt8]()
    s16.resize(10 * 2 * 2, UInt8(0))
    assert_equal(fu.offset_frames(lib, s16, 0, format=SAMPLE_FORMAT_S16, channels=2), 0)
    assert_equal(fu.offset_frames(lib, s16, 3, format=SAMPLE_FORMAT_S16, channels=2), 12)
    assert_equal(fu.offset_frames(lib, s16, 10, format=SAMPLE_FORMAT_S16, channels=2), 40)

    var s24 = List[UInt8]()
    s24.resize(10 * 3 * 3, UInt8(0))
    assert_equal(fu.offset_frames(lib, s24, 4, format=SAMPLE_FORMAT_S24, channels=3), 36)

    var f32 = List[UInt8]()
    f32.resize(10 * 4, UInt8(0))
    assert_equal(fu.offset_frames(lib, f32, 7, format=SAMPLE_FORMAT_F32, channels=1), 28)

    var u8 = List[UInt8]()
    u8.resize(10 * 5, UInt8(0))
    assert_equal(fu.offset_frames(lib, u8, 9, format=SAMPLE_FORMAT_U8, channels=5), 45)


def test_const_offset_agrees_with_the_mutable_one() raises:
    var lib = _lib()
    var buffer = List[UInt8]()
    buffer.resize(8 * 2 * 4, UInt8(0))
    for frames in range(0, 9):
        var mutable = fu.offset_frames(lib, buffer, frames, format=SAMPLE_FORMAT_S32, channels=2)
        var readonly = fu.offset_frames_const(lib, buffer, frames, format=SAMPLE_FORMAT_S32, channels=2)
        assert_equal(mutable, readonly)
        assert_equal(mutable, frames * 2 * 4)


def test_offsets_outside_the_buffer_raise() raises:
    var lib = _lib()
    var buffer = List[UInt8]()
    buffer.resize(4 * 2 * 2, UInt8(0))
    with assert_raises():
        _ = fu.offset_frames(lib, buffer, 5, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.offset_frames(lib, buffer, -1, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.offset_frames_const(lib, buffer, 5, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.offset_frames_const(lib, buffer, -1, format=SAMPLE_FORMAT_S16, channels=2)


def test_the_sine_starts_at_zero_peaks_at_one_and_is_odd() raises:
    """400 Hz at 48 kHz is a 120-frame period: 0 at frame 0, +1 at 30, -1 at 90."""
    var lib = _lib()
    var wave = fu.sine_wave_f32(lib, UInt32(240), sample_rate=UInt32(48000))
    assert_equal(len(wave), 240)
    assert_equal(wave[0], Float32(0.0))
    assert_almost_equal(wave[1], Float32(0.05233596), atol=1e-6)
    assert_almost_equal(wave[30], Float32(1.0), atol=1e-6)
    assert_almost_equal(wave[90], Float32(-1.0), atol=1e-6)
    var peak = Float32(0)
    for i in range(240):
        assert_true(wave[i] >= Float32(-1.0) and wave[i] <= Float32(1.0))
        if abs(wave[i]) > peak:
            peak = abs(wave[i])
        # half a period later the wave is the negative of itself
        if i < 120:
            assert_almost_equal(wave[i + 60], -wave[i], atol=1e-4)
        # and a whole period later it repeats
        if i + 120 < 240:
            assert_almost_equal(wave[i + 120], wave[i], atol=1e-4)
    assert_almost_equal(peak, Float32(1.0), atol=1e-6)


def test_every_channel_carries_the_same_signal() raises:
    var lib = _lib()
    var wave = fu.sine_wave_f32(lib, UInt32(100), channels=2)
    assert_equal(len(wave), 200)
    for i in range(100):
        assert_equal(wave[2 * i], wave[2 * i + 1])
    assert_true(wave[2 * 30] > Float32(0.99))


def test_the_frequency_is_fixed_but_the_sample_rate_moves_the_period() raises:
    """At 24 kHz the same 400 Hz sine has a 60-frame period, so frame 15 peaks."""
    var lib = _lib()
    var wave = fu.sine_wave_f32(lib, UInt32(120), sample_rate=UInt32(24000))
    assert_almost_equal(wave[15], Float32(1.0), atol=1e-6)
    assert_almost_equal(wave[45], Float32(-1.0), atol=1e-6)


def test_s16_sine_is_the_f32_sine_at_full_scale() raises:
    """The s16 fill is the f32 one times 32767, truncated toward zero."""
    var lib = _lib()
    var f = fu.sine_wave_f32(lib, UInt32(240))
    var s = fu.sine_wave_s16(lib, UInt32(240))
    assert_equal(len(s), 240)
    for i in range(240):
        assert_true(abs(Float32(Int(s[i])) - f[i] * Float32(32767.0)) < Float32(1.0))
    assert_equal(s[30], Int16(32767))
    assert_equal(s[90], Int16(-32767))


def test_other_formats_carry_the_same_wave() raises:
    """The u8 wave centres on 127/128; s24 spans +-8388607 and s32 +-2147483647."""
    var lib = _lib()
    var u8 = fu.sine_wave(lib, UInt32(120), format=SAMPLE_FORMAT_U8)
    assert_equal(len(u8), 120)
    assert_equal(u8[0], UInt8(127))
    assert_equal(u8[30], UInt8(255))
    assert_equal(u8[90], UInt8(0))

    var s24 = fu.sine_wave(lib, UInt32(120), format=SAMPLE_FORMAT_S24)
    assert_equal(len(s24), 360)
    # frame 30 is the positive peak: 0x7FFFFF, little-endian
    assert_equal(s24[30 * 3 + 0], UInt8(0xFF))
    assert_equal(s24[30 * 3 + 1], UInt8(0xFF))
    assert_equal(s24[30 * 3 + 2], UInt8(0x7F))

    var s32 = pc.bytes_to_s32(fu.sine_wave(lib, UInt32(120), format=SAMPLE_FORMAT_S32))
    assert_equal(len(s32), 120)
    assert_equal(s32[0], Int32(0))
    assert_equal(s32[30], Int32(2147483647))
    assert_true(s32[90] <= Int32(-2147483646))


def test_an_unknown_format_raises() raises:
    var lib = _lib()
    var buffer = List[UInt8]()
    buffer.resize(16, UInt8(0))
    with assert_raises():
        _ = fu.deinterleave(lib, buffer, format=SAMPLE_FORMAT_UNKNOWN, channels=2)
    with assert_raises():
        _ = fu.interleave(lib, buffer, format=SAMPLE_FORMAT_UNKNOWN, channels=2)
    with assert_raises():
        fu.silence(lib, buffer, format=SAMPLE_FORMAT_UNKNOWN, channels=2)
    with assert_raises():
        _ = fu.silent_frames(lib, 4, format=SAMPLE_FORMAT_UNKNOWN, channels=2)
    with assert_raises():
        _ = fu.sine_wave(lib, UInt32(8), format=SAMPLE_FORMAT_UNKNOWN)
    with assert_raises():
        _ = fu.offset_frames(lib, buffer, 1, format=SAMPLE_FORMAT_UNKNOWN, channels=2)


def test_partial_frames_and_zero_channels_raise() raises:
    """A length that is not a whole number of frames is rejected, not truncated."""
    var lib = _lib()
    var seven = List[UInt8]()
    seven.resize(7, UInt8(0))
    with assert_raises():
        _ = fu.deinterleave(lib, seven, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.interleave(lib, seven, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        fu.silence(lib, seven, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.offset_frames(lib, seven, 1, format=SAMPLE_FORMAT_S16, channels=2)
    with assert_raises():
        _ = fu.offset_frames_const(lib, seven, 1, format=SAMPLE_FORMAT_S16, channels=2)

    var eight = List[UInt8]()
    eight.resize(8, UInt8(0))
    with assert_raises():
        _ = fu.deinterleave(lib, eight, format=SAMPLE_FORMAT_S16, channels=0)
    with assert_raises():
        _ = fu.silent_frames(lib, 4, format=SAMPLE_FORMAT_S16, channels=0)
    with assert_raises():
        _ = fu.sine_wave(lib, UInt32(8), format=SAMPLE_FORMAT_S16, channels=0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
