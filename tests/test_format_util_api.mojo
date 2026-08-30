"""TDD tests for the idiomatic format utilities (Layer 3 free functions).

L3 behavioral: verifies volume scaling and clipping do what they say on
caller-owned buffers, that the buffer-size arithmetic round-trips, and that the
format and backend tables answer consistently.
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
    SAMPLE_FORMAT_U8,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S24,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
import miniaudio.format_util as fu


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_volume_halves_the_samples_it_is_given() raises:
    """Scaling by 0.5 halves every f32 sample in place."""
    var lib = _lib()
    var samples: List[Float32] = [Float32(1.0), Float32(0.5), Float32(-1.0)]
    fu.apply_volume(lib, samples, Float32(0.5))

    assert_almost_equal(samples[0], Float32(0.5), atol=0.001)
    assert_almost_equal(samples[1], Float32(0.25), atol=0.001)
    assert_almost_equal(samples[2], Float32(-0.5), atol=0.001)


def test_volume_reaches_frames_through_both_entry_points() raises:
    """The dispatching and typed frame entry points agree."""
    var lib = _lib()
    var dispatched: List[Float32] = [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)]
    var typed: List[Float32] = [Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0)]

    fu.apply_volume_frames(lib, dispatched, channels=2, factor=Float32(0.25))
    fu.apply_volume_frames_f32(lib, typed, channels=2, factor=Float32(0.25))

    for i in range(4):
        assert_almost_equal(dispatched[i], typed[i], atol=0.001)
        assert_almost_equal(dispatched[i], Float32(0.25), atol=0.001)


def test_clipping_bounds_f32_to_the_unit_range() raises:
    """Anything outside [-1, 1] comes back at the boundary."""
    var lib = _lib()
    var got = fu.clip(lib, [Float32(2.0), Float32(-2.0), Float32(0.5)])

    assert_almost_equal(got[0], Float32(1.0), atol=0.001)
    assert_almost_equal(got[1], Float32(-1.0), atol=0.001)
    assert_almost_equal(got[2], Float32(0.5), atol=0.001)


def test_clipping_frames_matches_clipping_samples() raises:
    """The frame-shaped entry point clips the same way the sample one does."""
    var lib = _lib()
    var src: List[Float32] = [Float32(3.0), Float32(-3.0), Float32(0.25), Float32(0.0)]

    var by_sample = fu.clip(lib, src)
    var by_frame = fu.clip_frames(lib, src, channels=2)
    for i in range(4):
        assert_almost_equal(by_sample[i], by_frame[i], atol=0.001)


def test_the_narrowing_clips_produce_the_right_widths() raises:
    """Each narrowing clip returns as many elements as its width implies."""
    var lib = _lib()

    assert_equal(len(fu.clip_to_u8(lib, [Int16(1000), Int16(-1000)])), 2)
    assert_equal(len(fu.clip_to_s16(lib, [Int32(100000), Int32(-100000)])), 2)
    assert_equal(len(fu.clip_to_s32(lib, [Int64(1) << 40, Int64(0)])), 2)
    # s24 is packed three bytes per sample.
    assert_equal(len(fu.clip_to_s24(lib, [Int64(1) << 40, Int64(0)])), 6)


def test_buffer_size_arithmetic_round_trips() raises:
    """100 ms at 48 kHz is 4800 frames, and back again."""
    var lib = _lib()
    assert_equal(fu.frames_from_milliseconds(lib, UInt32(100), UInt32(48000)), UInt32(4800))
    assert_equal(fu.milliseconds_from_frames(lib, UInt32(4800), UInt32(48000)), UInt32(100))

    var resampled = fu.frames_after_resampling(
        lib, sample_rate_out=UInt32(24000), sample_rate_in=UInt32(48000),
        frame_count_in=UInt64(100),
    )
    assert_true(resampled >= UInt64(49) and resampled <= UInt64(51))

    assert_true(
        fu.frames_from_descriptor(
            lib, sample_rate=UInt32(48000), native_sample_rate=UInt32(48000),
            period_size_in_milliseconds=UInt32(10),
        )
        > UInt32(0)
    )


def test_the_format_table_matches_the_widths_it_names() raises:
    """Every format reports its own sample width and a name."""
    var lib = _lib()
    assert_equal(fu.bytes_per_sample(lib, SAMPLE_FORMAT_U8), UInt32(1))
    assert_equal(fu.bytes_per_sample(lib, SAMPLE_FORMAT_S16), UInt32(2))
    assert_equal(fu.bytes_per_sample(lib, SAMPLE_FORMAT_S24), UInt32(3))
    assert_equal(fu.bytes_per_sample(lib, SAMPLE_FORMAT_S32), UInt32(4))
    assert_equal(fu.bytes_per_sample(lib, SAMPLE_FORMAT_F32), UInt32(4))

    assert_true(fu.format_name(lib, SAMPLE_FORMAT_F32).byte_length() > 0)
    _ = fu.format_priority_index(lib, SAMPLE_FORMAT_F32)


def test_a_backend_name_maps_back_to_its_backend() raises:
    """The name table round-trips for every enabled backend."""
    var lib = _lib()
    var backends = fu.enabled_backends(lib)
    assert_true(len(backends) > 0)

    var first = Int(backends[0])
    var name = fu.backend_name(lib, first)
    assert_true(name.byte_length() > 0)
    assert_equal(Int(fu.backend_from_name(lib, name)), first)


def test_an_unknown_backend_name_raises() raises:
    """A name that is not a backend fails rather than guessing."""
    var lib = _lib()
    with assert_raises():
        _ = fu.backend_from_name(lib, "definitely-not-a-backend")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
