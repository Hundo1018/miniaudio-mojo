"""TDD tests for the idiomatic channel converter API (RAII ChannelConverter).

L3 behavioral: verifies that narrowing folds channels together, that widening
fills every output channel, that the channel maps come back sized to their
respective channel counts, and that the two init paths agree.
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
from miniaudio.converter import (
    ChannelConverter,
    CHANNEL_MIX_MODE_RECTANGULAR,
    CHANNEL_MIX_MODE_SIMPLE,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _stereo(pairs: Int) -> List[Float32]:
    """Interleaved stereo where the right channel is the left plus one."""
    var out = List[Float32](capacity=pairs * 2)
    for i in range(pairs):
        out.append(Float32(i))
        out.append(Float32(i + 1))
    return out^


def _mono(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i + 1))
    return out^


def test_stereo_folds_down_to_the_channel_average() raises:
    """Narrowing to mono averages the pair."""
    var cc = ChannelConverter.create(_lib(), channels_in=2, channels_out=1)
    var got = cc.process(_stereo(4))
    assert_equal(len(got), 4)
    for i in range(4):
        assert_almost_equal(got[i], Float32(i) + Float32(0.5), atol=0.001)


def test_mono_widens_into_every_output_channel() raises:
    """Widening to stereo puts the same signal in both channels."""
    var cc = ChannelConverter.create(_lib(), channels_in=1, channels_out=2)
    var got = cc.process(_mono(4))
    assert_equal(len(got), 8)
    for i in range(4):
        assert_true(got[i * 2] != Float32(0))
        assert_equal(got[i * 2], got[i * 2 + 1])


def test_simple_mode_zero_fills_the_channels_it_cannot_source() raises:
    """Simple mixing copies the channels it has and zeroes the extras."""
    var cc = ChannelConverter.create(
        _lib(), channels_in=2, channels_out=4, mix_mode=CHANNEL_MIX_MODE_SIMPLE
    )
    var got = cc.process(_stereo(3))
    assert_equal(len(got), 12)
    for i in range(3):
        assert_almost_equal(got[i * 4 + 2], Float32(0), atol=0.001)
        assert_almost_equal(got[i * 4 + 3], Float32(0), atol=0.001)


def test_channel_maps_match_their_channel_counts() raises:
    """Each side's channel map is as long as that side's channel count."""
    var cc = ChannelConverter.create(_lib(), channels_in=2, channels_out=1)
    assert_equal(len(cc.input_channel_map()), 2)
    assert_equal(len(cc.output_channel_map()), 1)
    var in_map = cc.input_channel_map()
    assert_true(in_map[0] != in_map[1])


def test_heap_size_is_available_before_building_one() raises:
    """The static heap-size query answers without constructing a converter."""
    _ = ChannelConverter.heap_size(_lib(), channels_in=2, channels_out=1)


def test_preallocated_and_managed_heaps_convert_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = ChannelConverter.create(_lib(), channels_in=2, channels_out=1)
    var prealloc = ChannelConverter.create(
        _lib(), channels_in=2, channels_out=1, preallocated=True
    )

    var a = managed.process(_stereo(4))
    var b = prealloc.process(_stereo(4))
    assert_equal(len(a), len(b))
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_mix_mode_is_carried_through_to_miniaudio() raises:
    """Rectangular and simple modes are both accepted and build a converter."""
    var rect = ChannelConverter.create(
        _lib(), channels_in=2, channels_out=4, mix_mode=CHANNEL_MIX_MODE_RECTANGULAR
    )
    var simple = ChannelConverter.create(
        _lib(), channels_in=2, channels_out=4, mix_mode=CHANNEL_MIX_MODE_SIMPLE
    )
    assert_equal(len(rect.process(_stereo(2))), 8)
    assert_equal(len(simple.process(_stereo(2))), 8)


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var cc = ChannelConverter.create(_lib(), channels_in=2, channels_out=1)
    cc.uninit()
    with assert_raises():
        _ = cc.process(_stereo(2))
    with assert_raises():
        _ = cc.input_channel_map()


def test_a_zero_channel_count_raises() raises:
    """A converter with no channels on either side raises."""
    with assert_raises():
        _ = ChannelConverter.create(_lib(), channels_in=0, channels_out=1)
    with assert_raises():
        _ = ChannelConverter.create(_lib(), channels_in=2, channels_out=0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
