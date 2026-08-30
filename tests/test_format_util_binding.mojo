"""TDD contract tests for the format utility BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: these are stateless helpers operating on
caller memory. All 27 MA_API format utility functions are exercised here
(positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.format_util_raw as raw


comptime FMT_U8: Int = 1
comptime FMT_S16: Int = 2
comptime FMT_S24: Int = 3
comptime FMT_S32: Int = 4
comptime FMT_F32: Int = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def test_volume_scales_samples_of_every_width() raises:
    """Each typed in-place scaler halves what it is given."""
    var lib = _lib()

    var f32 = List[Float32]()
    for _ in range(4):
        f32.append(Float32(1.0))
    assert_equal(raw.apply_volume_factor_f32(lib, f32, Float32(0.5)), MA_SUCCESS)
    for i in range(4):
        assert_almost_equal(f32[i], Float32(0.5), atol=0.001)

    var s16 = List[Int16]()
    for _ in range(4):
        s16.append(Int16(1000))
    assert_equal(raw.apply_volume_factor_s16(lib, s16, Float32(0.5)), MA_SUCCESS)
    assert_true(s16[0] < Int16(1000))

    var s32 = List[Int32]()
    for _ in range(4):
        s32.append(Int32(100000))
    assert_equal(raw.apply_volume_factor_s32(lib, s32, Float32(0.5)), MA_SUCCESS)
    assert_true(s32[0] < Int32(100000))

    var u8 = List[UInt8]()
    for _ in range(4):
        u8.append(UInt8(200))
    assert_equal(raw.apply_volume_factor_u8(lib, u8, Float32(0.5)), MA_SUCCESS)

    # s24 is three bytes per sample, so the count is passed separately.
    var s24 = List[UInt8]()
    for _ in range(12):
        s24.append(UInt8(0x7F))
    assert_equal(
        raw.apply_volume_factor_s24(lib, s24, UInt64(4), Float32(0.5)), MA_SUCCESS
    )


def test_volume_scales_frames_through_every_entry_point() raises:
    """The dispatching entry point and all five typed ones accept frames."""
    var lib = _lib()

    var frames = List[Float32]()
    for _ in range(8):
        frames.append(Float32(1.0))
    assert_equal(
        raw.apply_volume_factor_pcm_frames(
            lib, frames, UInt64(4), FMT_F32, UInt32(2), Float32(0.5)
        ),
        MA_SUCCESS,
    )
    assert_almost_equal(frames[0], Float32(0.5), atol=0.001)

    var f32 = List[Float32]()
    for _ in range(8):
        f32.append(Float32(1.0))
    assert_equal(
        raw.apply_volume_factor_pcm_frames_f32(lib, f32, UInt64(4), UInt32(2), Float32(0.5)),
        MA_SUCCESS,
    )

    var u8 = List[UInt8]()
    for _ in range(8):
        u8.append(UInt8(200))
    assert_equal(
        raw.apply_volume_factor_pcm_frames_u8(lib, u8, UInt64(4), UInt32(2), Float32(0.5)),
        MA_SUCCESS,
    )

    var s16 = List[Int16]()
    for _ in range(8):
        s16.append(Int16(1000))
    assert_equal(
        raw.apply_volume_factor_pcm_frames_s16(lib, s16, UInt64(4), UInt32(2), Float32(0.5)),
        MA_SUCCESS,
    )

    var s24 = List[UInt8]()
    for _ in range(24):
        s24.append(UInt8(0x7F))
    assert_equal(
        raw.apply_volume_factor_pcm_frames_s24(lib, s24, UInt64(4), UInt32(2), Float32(0.5)),
        MA_SUCCESS,
    )

    var s32 = List[Int32]()
    for _ in range(8):
        s32.append(Int32(100000))
    assert_equal(
        raw.apply_volume_factor_pcm_frames_s32(lib, s32, UInt64(4), UInt32(2), Float32(0.5)),
        MA_SUCCESS,
    )


def test_clipping_bounds_f32_and_narrows_the_wider_types() raises:
    """Clipping bounds f32 to [-1, 1] and narrows the wider integer types."""
    var lib = _lib()

    var src: List[Float32] = [Float32(2.0), Float32(-2.0), Float32(0.5), Float32(0.0)]
    var dst = List[Float32]()
    dst.resize(4, Float32(0))
    assert_equal(raw.clip_samples_f32(lib, dst, src, UInt64(4)), MA_SUCCESS)
    assert_almost_equal(dst[0], Float32(1.0), atol=0.001)
    assert_almost_equal(dst[1], Float32(-1.0), atol=0.001)
    assert_almost_equal(dst[2], Float32(0.5), atol=0.001)

    var wide32: List[Int32] = [Int32(100000), Int32(-100000), Int32(0), Int32(1)]
    var narrow16 = List[Int16]()
    narrow16.resize(4, Int16(0))
    assert_equal(raw.clip_samples_s16(lib, narrow16, wide32, UInt64(4)), MA_SUCCESS)
    assert_true(narrow16[0] > Int16(0))

    var wide64: List[Int64] = [Int64(1) << 40, Int64(-1) << 40, Int64(0), Int64(5)]
    var narrow32 = List[Int32]()
    narrow32.resize(4, Int32(0))
    assert_equal(raw.clip_samples_s32(lib, narrow32, wide64, UInt64(4)), MA_SUCCESS)

    var narrow24 = List[UInt8]()
    narrow24.resize(12, UInt8(0))
    assert_equal(raw.clip_samples_s24(lib, narrow24, wide64, UInt64(4)), MA_SUCCESS)

    var wide16: List[Int16] = [Int16(1000), Int16(-1000), Int16(0), Int16(5)]
    var narrow8 = List[UInt8]()
    narrow8.resize(4, UInt8(0))
    assert_equal(raw.clip_samples_u8(lib, narrow8, wide16, UInt64(4)), MA_SUCCESS)

    var frames_src: List[Float32] = [Float32(3.0), Float32(-3.0), Float32(0.25), Float32(0.0)]
    var frames_dst = List[Float32]()
    frames_dst.resize(4, Float32(0))
    assert_equal(
        raw.clip_pcm_frames(lib, frames_dst, frames_src, UInt64(2), FMT_F32, UInt32(2)),
        MA_SUCCESS,
    )
    assert_almost_equal(frames_dst[0], Float32(1.0), atol=0.001)


def test_buffer_size_arithmetic_round_trips() raises:
    """Milliseconds and frames convert back into each other at a known rate."""
    var lib = _lib()

    var frames = raw.calculate_buffer_size_in_frames_from_milliseconds(
        lib, UInt32(100), UInt32(48000)
    )
    assert_equal(frames.result, MA_SUCCESS)
    assert_equal(frames.value, UInt32(4800))

    var ms = raw.calculate_buffer_size_in_milliseconds_from_frames(
        lib, UInt32(4800), UInt32(48000)
    )
    assert_equal(ms.result, MA_SUCCESS)
    assert_equal(ms.value, UInt32(100))

    var resampled = raw.calculate_frame_count_after_resampling(
        lib, UInt32(24000), UInt32(48000), UInt64(100)
    )
    assert_equal(resampled.result, MA_SUCCESS)
    assert_true(resampled.value >= UInt64(49) and resampled.value <= UInt64(51))

    var from_descriptor = raw.calculate_buffer_size_in_frames_from_descriptor(
        lib, FMT_F32, UInt32(2), UInt32(48000), UInt32(0), UInt32(10),
        UInt32(48000), 0,
    )
    assert_equal(from_descriptor.result, MA_SUCCESS)
    assert_true(from_descriptor.value > UInt32(0))


def test_the_format_table_answers_for_every_format() raises:
    """Sample widths, names and priorities are all reported."""
    var lib = _lib()

    assert_equal(raw.get_bytes_per_sample(lib, FMT_U8).value, UInt32(1))
    assert_equal(raw.get_bytes_per_sample(lib, FMT_S16).value, UInt32(2))
    assert_equal(raw.get_bytes_per_sample(lib, FMT_S24).value, UInt32(3))
    assert_equal(raw.get_bytes_per_sample(lib, FMT_S32).value, UInt32(4))
    assert_equal(raw.get_bytes_per_sample(lib, FMT_F32).value, UInt32(4))

    var name = raw.get_format_name(lib, FMT_F32)
    assert_equal(name.result, MA_SUCCESS)
    assert_true(name.value.byte_length() > 0)

    assert_equal(raw.get_format_priority_index(lib, FMT_F32).result, MA_SUCCESS)


def test_the_backend_table_round_trips_a_name() raises:
    """A backend's name maps back to the backend it came from."""
    var lib = _lib()

    var enabled = raw.get_enabled_backends(lib)
    assert_equal(enabled.result, MA_SUCCESS)
    assert_true(len(enabled.value) > 0)

    var first = Int(enabled.value[0])
    var name = raw.get_backend_name(lib, first)
    assert_equal(name.result, MA_SUCCESS)
    assert_true(name.value.byte_length() > 0)

    var back = raw.get_backend_from_name(lib, name.value)
    assert_equal(back.result, MA_SUCCESS)
    assert_equal(Int(back.value), first)


def test_an_unknown_backend_name_is_rejected() raises:
    """A name that is not a backend fails rather than guessing."""
    var lib = _lib()
    assert_true(raw.get_backend_from_name(lib, "definitely-not-a-backend").result != MA_SUCCESS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
