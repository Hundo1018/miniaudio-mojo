"""TDD tests for the idiomatic linear resampler API (RAII LinearResampler).

L3 behavioral: verifies the converted frame count matches the converter's own
prediction, that both rate setters retarget it, that reset makes a repeat run
identical, and that it agrees with `Resampler` driving the same algorithm.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.converter import (
    LinearResampler,
    Resampler,
    RESAMPLE_ALGORITHM_LINEAR,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i))
    return out^


def _halving(preallocated: Bool = False) raises -> LinearResampler:
    return LinearResampler.create(
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


def test_it_agrees_with_the_resampler_on_the_same_algorithm() raises:
    """`Resampler` on linear and `LinearResampler` produce the same frames."""
    var direct = _halving()
    var wrapped = Resampler.create(
        _lib(),
        sample_rate_in=UInt32(48000),
        sample_rate_out=UInt32(24000),
        algorithm=RESAMPLE_ALGORITHM_LINEAR,
    )

    var a = direct.process(_ramp(16), UInt64(32))
    var b = wrapped.process(_ramp(16), UInt64(32))
    assert_equal(len(a.frames), len(b.frames))
    for i in range(len(a.frames)):
        assert_equal(a.frames[i], b.frames[i])


def test_both_rate_setters_retarget_the_conversion() raises:
    """Both set_rate and set_rate_ratio move the same underlying ratio."""
    var rs = _halving()
    rs.set_rate(UInt32(48000), UInt32(48000))
    assert_true(rs.expected_output_frames(UInt64(20)) >= UInt64(19))

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


def test_heap_size_latency_and_estimators_answer() raises:
    """The static heap-size query, both latencies and the input estimator."""
    assert_true(
        LinearResampler.heap_size(
            _lib(), sample_rate_in=UInt32(48000), sample_rate_out=UInt32(24000)
        )
        > UInt64(0)
    )
    var rs = _halving()
    _ = rs.input_latency()
    _ = rs.output_latency()
    assert_true(rs.required_input_frames(UInt64(10)) >= UInt64(19))


def test_preallocated_and_managed_heaps_convert_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = _halving()
    var prealloc = _halving(preallocated=True)

    var a = managed.process(_ramp(16), UInt64(32))
    var b = prealloc.process(_ramp(16), UInt64(32))
    assert_equal(len(a.frames), len(b.frames))
    for i in range(len(a.frames)):
        assert_equal(a.frames[i], b.frames[i])


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var rs = _halving()
    rs.uninit()
    with assert_raises():
        _ = rs.process(_ramp(4), UInt64(8))
    with assert_raises():
        _ = rs.input_latency()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
