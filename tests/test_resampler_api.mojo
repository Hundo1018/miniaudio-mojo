"""TDD tests for the idiomatic resampler API (RAII Resampler).

L3 behavioral: verifies that the converted frame count matches what the
converter itself predicts, that both rate setters retarget it, that a reset
makes a repeat run identical, and that the two init paths (miniaudio-owned heap
vs shim-owned heap) produce the same audio.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.converter import Resampler


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i))
    return out^


def _halving(preallocated: Bool = False) raises -> Resampler:
    return Resampler.create(
        _lib(),
        sample_rate_in=UInt32(48000),
        sample_rate_out=UInt32(24000),
        preallocated=preallocated,
    )


def test_output_matches_the_converters_own_prediction() raises:
    """Process yields exactly the frames expected_output_frames promised."""
    var rs = _halving()
    var expected = rs.expected_output_frames(UInt64(16))

    var result = rs.process(_ramp(16), UInt64(32))
    assert_true(result.frames_consumed == UInt64(16))
    assert_equal(len(result.frames), Int(expected))


def test_downsampling_halves_the_frame_count() raises:
    """A 2:1 rate change produces about half as many frames as it consumes."""
    var rs = _halving()
    var result = rs.process(_ramp(32), UInt64(64))
    assert_true(len(result.frames) >= 15 and len(result.frames) <= 17)


def test_required_and_expected_frame_counts_agree_with_the_ratio() raises:
    """The two estimators bracket the 2:1 ratio from both directions."""
    var rs = _halving()
    assert_true(rs.required_input_frames(UInt64(10)) >= UInt64(19))
    assert_true(rs.required_input_frames(UInt64(10)) <= UInt64(21))
    assert_true(rs.expected_output_frames(UInt64(20)) >= UInt64(9))
    assert_true(rs.expected_output_frames(UInt64(20)) <= UInt64(11))


def test_heap_size_is_available_before_building_one() raises:
    """The static heap-size query answers without constructing a resampler."""
    var size = Resampler.heap_size(
        _lib(), sample_rate_in=UInt32(48000), sample_rate_out=UInt32(24000)
    )
    assert_true(size > UInt64(0))


def test_preallocated_and_managed_heaps_convert_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = _halving()
    var prealloc = _halving(preallocated=True)

    var a = managed.process(_ramp(16), UInt64(32))
    var b = prealloc.process(_ramp(16), UInt64(32))
    assert_equal(len(a.frames), len(b.frames))
    for i in range(len(a.frames)):
        assert_equal(a.frames[i], b.frames[i])


def test_both_rate_setters_retarget_the_conversion() raises:
    """Both set_rate and set_rate_ratio move the same underlying ratio."""
    var rs = _halving()
    rs.set_rate(UInt32(48000), UInt32(48000))
    assert_true(rs.expected_output_frames(UInt64(20)) >= UInt64(19))

    # miniaudio's ratio is input-over-output: 2.0 halves the rate.
    rs.set_rate_ratio(Float32(2.0))
    assert_true(rs.expected_output_frames(UInt64(20)) <= UInt64(11))

    with assert_raises():
        rs.set_rate_ratio(Float32(0.0))


def test_reset_makes_a_repeat_run_identical() raises:
    """After reset the same input produces the same output, sample for sample."""
    var rs = _halving()
    var first = rs.process(_ramp(16), UInt64(32))
    rs.reset()
    var second = rs.process(_ramp(16), UInt64(32))

    assert_equal(len(first.frames), len(second.frames))
    for i in range(len(first.frames)):
        assert_equal(first.frames[i], second.frames[i])


def test_latency_is_reported_on_both_sides() raises:
    """Both latency queries answer on a live resampler."""
    var rs = _halving()
    _ = rs.input_latency()
    _ = rs.output_latency()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var rs = _halving()
    rs.uninit()
    with assert_raises():
        _ = rs.process(_ramp(4), UInt64(8))
    with assert_raises():
        _ = rs.input_latency()


def test_an_unusable_format_raises() raises:
    """A format the resampler cannot handle raises rather than half-building."""
    from miniaudio.decoder import SAMPLE_FORMAT_UNKNOWN

    with assert_raises():
        _ = Resampler.create(
            _lib(),
            sample_rate_in=UInt32(48000),
            sample_rate_out=UInt32(24000),
            format=SAMPLE_FORMAT_UNKNOWN,
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
