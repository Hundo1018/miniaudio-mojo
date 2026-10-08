"""TDD contract tests for the PCM frame utility BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: these are stateless helpers operating on
caller memory. All six MA_API frame utility functions are exercised here
(positive and negative paths): interleave and deinterleave, silence, the two
pointer-offset helpers and the debug sine fill. The helpers that take a `format`
work on raw bytes, so every format is driven through the same list type.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.frame_util_raw as raw


comptime FMT_U8: Int = 1
comptime FMT_S16: Int = 2
comptime FMT_S24: Int = 3
comptime FMT_S32: Int = 4
comptime FMT_F32: Int = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _bytes_per_sample(format: Int) -> Int:
    if format == FMT_U8:
        return 1
    if format == FMT_S16:
        return 2
    if format == FMT_S24:
        return 3
    return 4


def _filled(n: Int, value: UInt8) -> List[UInt8]:
    var out = List[UInt8](capacity=n)
    out.resize(n, value)
    return out^


def _same(got: List[UInt8], want: List[UInt8]) raises:
    assert_equal(len(got), len(want))
    for i in range(len(want)):
        assert_equal(got[i], want[i])


def _ramp(n: Int) -> List[UInt8]:
    """Bytes 1, 2, 3, ... so every sample of every format is distinct."""
    var out = List[UInt8](capacity=n)
    for i in range(n):
        out.append(UInt8(i + 1))
    return out^


def _planes_of(
    interleaved: List[UInt8], bytes_per_sample: Int, channels: Int, frames: Int
) -> List[UInt8]:
    """What deinterleaving must produce: channel 0's samples, then channel 1's."""
    var out = List[UInt8]()
    for c in range(channels):
        for f in range(frames):
            var start = (f * channels + c) * bytes_per_sample
            for b in range(bytes_per_sample):
                out.append(interleaved[start + b])
    return out^


def test_deinterleave_splits_s16_stereo_into_planes() raises:
    """Three stereo s16 frames: left samples first, then right, byte for byte."""
    var lib = _lib()
    # L0 R0 L1 R1 L2 R2, each a little-endian s16
    var interleaved: List[UInt8] = [
        UInt8(1), UInt8(0), UInt8(2), UInt8(0), UInt8(3), UInt8(0),
        UInt8(4), UInt8(0), UInt8(5), UInt8(0), UInt8(6), UInt8(0),
    ]
    var planes = _filled(12, UInt8(0))
    assert_equal(
        raw.deinterleave_pcm_frames(lib, FMT_S16, UInt32(2), UInt64(3), interleaved, planes, UInt64(6)),
        MA_SUCCESS,
    )
    _same(planes, [
        UInt8(1), UInt8(0), UInt8(3), UInt8(0), UInt8(5), UInt8(0),
        UInt8(2), UInt8(0), UInt8(4), UInt8(0), UInt8(6), UInt8(0),
    ])


def test_interleave_and_deinterleave_round_trip_every_format() raises:
    """For each of the five formats and 1, 2 and 3 channels, deinterleave matches
    the expected plane layout and interleave restores the original."""
    var lib = _lib()
    var formats: List[Int] = [FMT_U8, FMT_S16, FMT_S24, FMT_S32, FMT_F32]
    for fi in range(len(formats)):
        var format = formats[fi]
        var bps = _bytes_per_sample(format)
        for channels in range(1, 4):
            var frames = 5
            var total = frames * channels * bps
            var stride = UInt64(frames * bps)
            var interleaved = _ramp(total)

            var planes = _filled(total, UInt8(0))
            assert_equal(
                raw.deinterleave_pcm_frames(lib, format, UInt32(channels), UInt64(frames), interleaved, planes, stride),
                MA_SUCCESS,
            )
            _same(planes, _planes_of(interleaved, bps, channels, frames))

            var woven = _filled(total, UInt8(0))
            assert_equal(
                raw.interleave_pcm_frames(lib, format, UInt32(channels), UInt64(frames), planes, stride, woven),
                MA_SUCCESS,
            )
            _same(woven, interleaved)


def test_interleave_and_deinterleave_refuse_bad_arguments_and_write_nothing() raises:
    var lib = _lib()
    var interleaved = _ramp(12)
    var planes = _filled(12, UInt8(0))
    var woven = _filled(12, UInt8(0))

    # unknown formats
    assert_equal(raw.deinterleave_pcm_frames(lib, 0, UInt32(2), UInt64(3), interleaved, planes, UInt64(6)), MA_INVALID_ARGS)
    assert_equal(raw.deinterleave_pcm_frames(lib, 99, UInt32(2), UInt64(3), interleaved, planes, UInt64(6)), MA_INVALID_ARGS)
    assert_equal(raw.interleave_pcm_frames(lib, 0, UInt32(2), UInt64(3), planes, UInt64(6), woven), MA_INVALID_ARGS)
    # zero and too many channels
    assert_equal(raw.deinterleave_pcm_frames(lib, FMT_S16, UInt32(0), UInt64(3), interleaved, planes, UInt64(6)), MA_INVALID_ARGS)
    assert_equal(raw.deinterleave_pcm_frames(lib, FMT_S16, UInt32(255), UInt64(3), interleaved, planes, UInt64(6)), MA_INVALID_ARGS)
    assert_equal(raw.interleave_pcm_frames(lib, FMT_S16, UInt32(0), UInt64(3), planes, UInt64(6), woven), MA_INVALID_ARGS)
    assert_equal(raw.interleave_pcm_frames(lib, FMT_S16, UInt32(255), UInt64(3), planes, UInt64(6), woven), MA_INVALID_ARGS)
    # a stride shorter than one plane would overlap the planes
    assert_equal(raw.deinterleave_pcm_frames(lib, FMT_S16, UInt32(2), UInt64(3), interleaved, planes, UInt64(5)), MA_INVALID_ARGS)
    assert_equal(raw.interleave_pcm_frames(lib, FMT_S16, UInt32(2), UInt64(3), planes, UInt64(5), woven), MA_INVALID_ARGS)

    _same(planes, _filled(12, UInt8(0)))
    _same(woven, _filled(12, UInt8(0)))


def test_silence_zeroes_every_format_except_u8() raises:
    """Unsigned u8 silence is 128; every other format is zero."""
    var lib = _lib()
    var formats: List[Int] = [FMT_U8, FMT_S16, FMT_S24, FMT_S32, FMT_F32]
    for fi in range(len(formats)):
        var format = formats[fi]
        var bps = _bytes_per_sample(format)
        var frames = 4
        var buf = _filled(frames * 2 * bps, UInt8(0xAB))
        assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(frames), format, UInt32(2)), MA_SUCCESS)
        var want = UInt8(128) if format == FMT_U8 else UInt8(0)
        _same(buf, _filled(frames * 2 * bps, want))


def test_silence_only_touches_the_frames_it_is_asked_for() raises:
    var lib = _lib()
    var buf = _filled(16, UInt8(0xAB))
    # two stereo s16 frames = 8 bytes
    assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(2), FMT_S16, UInt32(2)), MA_SUCCESS)
    for i in range(8):
        assert_equal(buf[i], UInt8(0))
    for i in range(8, 16):
        assert_equal(buf[i], UInt8(0xAB))


def test_silence_refuses_bad_arguments() raises:
    var lib = _lib()
    var buf = _filled(8, UInt8(0xAB))
    assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(2), 0, UInt32(2)), MA_INVALID_ARGS)
    assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(2), 99, UInt32(2)), MA_INVALID_ARGS)
    assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(2), FMT_S16, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.silence_pcm_frames(lib, buf, UInt64(2), FMT_S16, UInt32(255)), MA_INVALID_ARGS)
    _same(buf, _filled(8, UInt8(0xAB)))


def test_offset_ptr_advances_by_frames_channels_and_sample_width() raises:
    """The returned address is frames * channels * bytes-per-sample past the base,
    for the mutable and the const helper, in every format."""
    var lib = _lib()
    var formats: List[Int] = [FMT_U8, FMT_S16, FMT_S24, FMT_S32, FMT_F32]
    for fi in range(len(formats)):
        var format = formats[fi]
        var bps = _bytes_per_sample(format)
        for channels in range(1, 4):
            var buf = _filled(10 * channels * bps, UInt8(0))
            var base = Int(buf.unsafe_ptr())
            for frames in range(0, 11, 5):
                var want = frames * channels * bps
                var mutable = raw.offset_pcm_frames_ptr(lib, buf, UInt64(frames), format, UInt32(channels))
                assert_equal(mutable.result, MA_SUCCESS)
                assert_equal(mutable.address - base, want)
                var readonly = raw.offset_pcm_frames_const_ptr(lib, buf, UInt64(frames), format, UInt32(channels))
                assert_equal(readonly.result, MA_SUCCESS)
                assert_equal(readonly.address - base, want)


def test_offset_ptr_refuses_bad_arguments_and_reports_no_address() raises:
    var lib = _lib()
    var buf = _filled(16, UInt8(0))
    var bad_format = raw.offset_pcm_frames_ptr(lib, buf, UInt64(1), 0, UInt32(2))
    assert_equal(bad_format.result, MA_INVALID_ARGS)
    assert_equal(bad_format.address, 0)
    assert_equal(raw.offset_pcm_frames_ptr(lib, buf, UInt64(1), 99, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.offset_pcm_frames_ptr(lib, buf, UInt64(1), FMT_S16, UInt32(0)).result, MA_INVALID_ARGS)
    assert_equal(raw.offset_pcm_frames_const_ptr(lib, buf, UInt64(1), 0, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.offset_pcm_frames_const_ptr(lib, buf, UInt64(1), FMT_S16, UInt32(0)).result, MA_INVALID_ARGS)
    var bad_const = raw.offset_pcm_frames_const_ptr(lib, buf, UInt64(1), 99, UInt32(2))
    assert_equal(bad_const.result, MA_INVALID_ARGS)
    assert_equal(bad_const.address, 0)


def test_sine_fill_writes_a_bounded_nonzero_signal_in_f32() raises:
    """48 kHz, 400 Hz: a period is 120 frames, so the peak lands at frame 30."""
    var lib = _lib()
    var buf = _filled(120 * 4, UInt8(0xAB))
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(120), FMT_F32, UInt32(1), UInt32(48000)), MA_SUCCESS)
    var samples = buf.unsafe_ptr().unsafe_bitcast[Float32]()
    var peak = Float32(0)
    var any_nonzero = False
    for i in range(120):
        var v = samples[unsafe_offset=i]
        assert_true(v >= Float32(-1.0) and v <= Float32(1.0))
        if v != Float32(0):
            any_nonzero = True
        if abs(v) > peak:
            peak = abs(v)
    assert_true(any_nonzero)
    assert_almost_equal(peak, Float32(1.0), atol=1e-5)
    assert_equal(samples[unsafe_offset=0], Float32(0.0))
    assert_almost_equal(samples[unsafe_offset=1], Float32(0.05233596), atol=1e-6)
    assert_almost_equal(samples[unsafe_offset=30], Float32(1.0), atol=1e-6)
    assert_almost_equal(samples[unsafe_offset=90], Float32(-1.0), atol=1e-6)


def test_sine_fill_writes_every_format() raises:
    """The same fill in each format starts at silence and leaves no byte untouched."""
    var lib = _lib()
    var formats: List[Int] = [FMT_U8, FMT_S16, FMT_S24, FMT_S32, FMT_F32]
    for fi in range(len(formats)):
        var format = formats[fi]
        var bps = _bytes_per_sample(format)
        var buf = _filled(240 * 2 * bps, UInt8(0xAB))
        assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(240), format, UInt32(2), UInt32(48000)), MA_SUCCESS)
        var changed = 0
        for i in range(len(buf)):
            if buf[i] != UInt8(0xAB):
                changed += 1
        # A sine crosses many byte values; a byte equal to the 0xAB sentinel is possible
        # but a mostly-untouched buffer is not.
        assert_true(changed > len(buf) // 2)


def test_sine_fill_refuses_bad_arguments() raises:
    var lib = _lib()
    var buf = _filled(64, UInt8(0xAB))
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(8), 0, UInt32(1), UInt32(48000)), MA_INVALID_ARGS)
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(8), 99, UInt32(1), UInt32(48000)), MA_INVALID_ARGS)
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(8), FMT_F32, UInt32(0), UInt32(48000)), MA_INVALID_ARGS)
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(8), FMT_F32, UInt32(255), UInt32(48000)), MA_INVALID_ARGS)
    assert_equal(raw.debug_fill_pcm_frames_with_sine_wave(lib, buf, UInt32(8), FMT_F32, UInt32(1), UInt32(0)), MA_INVALID_ARGS)
    _same(buf, _filled(64, UInt8(0xAB)))


def test_null_buffers_are_refused() raises:
    """Every entry point that takes a buffer returns INVALID_ARGS for NULL."""
    var lib = _lib()
    var holder = List[Int]()
    holder.append(7)

    assert_equal(
        Int(lib.handle.call["ma_shim_interleave_pcm_frames", Int32](
            Int32(FMT_S16), UInt32(2), UInt64(2), Int(0), UInt64(4), Int(0)
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_deinterleave_pcm_frames", Int32](
            Int32(FMT_S16), UInt32(2), UInt64(2), Int(0), Int(0), UInt64(4)
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_silence_pcm_frames", Int32](
            Int(0), UInt64(2), Int32(FMT_S16), UInt32(2)
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_offset_pcm_frames_ptr", Int32](
            Int(0), UInt64(2), Int32(FMT_S16), UInt32(2), holder.unsafe_ptr()
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(holder[0], 0)
    assert_equal(
        Int(lib.handle.call["ma_shim_offset_pcm_frames_const_ptr", Int32](
            Int(0), UInt64(2), Int32(FMT_S16), UInt32(2), holder.unsafe_ptr()
        )),
        MA_INVALID_ARGS,
    )
    # a real buffer but nowhere to put the address
    var buf = _filled(16, UInt8(0))
    assert_equal(
        Int(lib.handle.call["ma_shim_offset_pcm_frames_ptr", Int32](
            buf.unsafe_ptr(), UInt64(2), Int32(FMT_S16), UInt32(2), Int(0)
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_offset_pcm_frames_const_ptr", Int32](
            buf.unsafe_ptr(), UInt64(2), Int32(FMT_S16), UInt32(2), Int(0)
        )),
        MA_INVALID_ARGS,
    )
    assert_equal(
        Int(lib.handle.call["ma_shim_debug_fill_pcm_frames_with_sine_wave", Int32](
            Int(0), UInt32(8), Int32(FMT_F32), UInt32(1), UInt32(48000)
        )),
        MA_INVALID_ARGS,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
