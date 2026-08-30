"""TDD tests for the idiomatic data converter API (RAII DataConverter).

L3 behavioral: verifies that a default-config converter passes frames through
untouched, that rate and channel conversion happen in one pipeline, that the
converted frame count matches the converter's own prediction, and that the two
init paths agree.
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
from miniaudio.converter import DataConverter


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i))
    return out^


def _halving(preallocated: Bool = False) raises -> DataConverter:
    return DataConverter.create(
        _lib(),
        sample_rate_in=UInt32(48000),
        sample_rate_out=UInt32(24000),
        preallocated=preallocated,
    )


def test_default_config_passes_frames_through_untouched() raises:
    """A converter built from miniaudio's defaults changes nothing."""
    var dc = DataConverter.create_default(_lib(), sample_rate=UInt32(48000))
    var result = dc.process(_ramp(8), UInt64(8))

    assert_true(result.frames_consumed == UInt64(8))
    assert_equal(len(result.frames), 8)
    for i in range(8):
        assert_almost_equal(result.frames[i], Float32(i), atol=0.001)


def test_output_matches_the_converters_own_prediction() raises:
    """Process yields exactly the frames expected_output_frames promised."""
    var dc = _halving()
    var expected = dc.expected_output_frames(UInt64(16))

    var result = dc.process(_ramp(16), UInt64(32))
    assert_true(result.frames_consumed == UInt64(16))
    assert_equal(len(result.frames), Int(expected))


def test_rate_and_channel_conversion_happen_together() raises:
    """One pipeline both halves the rate and widens mono to stereo."""
    var dc = DataConverter.create(
        _lib(),
        sample_rate_in=UInt32(48000),
        sample_rate_out=UInt32(24000),
        channels_in=1,
        channels_out=2,
    )
    var result = dc.process(_ramp(16), UInt64(32))

    # Half the frames, two samples each.
    assert_true(len(result.frames) >= 14 and len(result.frames) <= 18)
    assert_equal(len(result.frames) % 2, 0)
    for i in range(len(result.frames) // 2):
        assert_equal(result.frames[i * 2], result.frames[i * 2 + 1])


def test_required_input_brackets_the_ratio() raises:
    """The input estimator reflects the 2:1 rate change."""
    var dc = _halving()
    assert_true(dc.required_input_frames(UInt64(10)) >= UInt64(19))
    assert_true(dc.required_input_frames(UInt64(10)) <= UInt64(21))


def test_channel_maps_match_their_channel_counts() raises:
    """Each side's channel map is as long as that side's channel count."""
    var dc = DataConverter.create(
        _lib(),
        sample_rate_in=UInt32(48000),
        sample_rate_out=UInt32(48000),
        channels_in=2,
        channels_out=1,
    )
    assert_equal(len(dc.input_channel_map()), 2)
    assert_equal(len(dc.output_channel_map()), 1)


def test_heap_size_is_available_before_building_one() raises:
    """The static heap-size query answers without constructing a converter."""
    var size = DataConverter.heap_size(
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


def test_rate_setters_retarget_the_pipeline() raises:
    """Both rate setters work once the pipeline contains a resampler."""
    var dc = _halving()
    dc.set_rate(UInt32(48000), UInt32(48000))
    assert_true(dc.expected_output_frames(UInt64(20)) >= UInt64(19))

    # miniaudio's ratio is input-over-output: 2.0 halves the rate.
    dc.set_rate_ratio(Float32(2.0))
    assert_true(dc.expected_output_frames(UInt64(20)) <= UInt64(11))


def test_reset_is_accepted_but_is_not_a_cold_restart() raises:
    """Reset succeeds; see the binding tests for the upstream caveat it carries."""
    var dc = _halving()
    var first = dc.process(_ramp(16), UInt64(32))
    dc.reset()
    var second = dc.process(_ramp(16), UInt64(32))
    assert_equal(len(first.frames), len(second.frames))


def test_latency_is_reported_on_both_sides() raises:
    """Both latency queries answer on a live converter."""
    var dc = _halving()
    _ = dc.input_latency()
    _ = dc.output_latency()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var dc = _halving()
    dc.uninit()
    with assert_raises():
        _ = dc.process(_ramp(4), UInt64(8))
    with assert_raises():
        _ = dc.output_latency()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
