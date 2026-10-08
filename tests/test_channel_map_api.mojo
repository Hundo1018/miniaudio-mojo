"""TDD tests for the idiomatic ChannelMap API (value type, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.channel_map import (
    ChannelMap,
    channel_position_name,
    StandardMapDefault,
    StandardMapAlsa,
    StandardMapFlac,
    StandardMapVorbis,
    ChannelNone,
    ChannelMono,
    ChannelFrontLeft,
    ChannelFrontRight,
    ChannelFrontCenter,
    ChannelLfe,
    ChannelBackCenter,
    ChannelSideLeft,
    ChannelSideRight,
    ChannelAux0,
)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _same(a: List[UInt8], b: List[UInt8]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def test_standard_maps_for_the_common_channel_counts() raises:
    var lib = _lib()
    var mono = ChannelMap.standard(lib, 1)
    assert_equal(mono.channel(0), ChannelMono)
    var stereo = ChannelMap.standard(lib, 2)
    assert_equal(stereo.channel(0), ChannelFrontLeft)
    assert_equal(stereo.channel(1), ChannelFrontRight)
    var five_one = ChannelMap.standard(lib, 6)
    var expected: List[UInt8] = [
        ChannelFrontLeft,
        ChannelFrontRight,
        ChannelFrontCenter,
        ChannelLfe,
        ChannelSideLeft,
        ChannelSideRight,
    ]
    assert_true(_same(five_one.positions(), expected))
    assert_equal(five_one.channels(), UInt32(6))


def test_standard_maps_follow_the_chosen_convention() raises:
    """Six channels: FLAC puts the back pair after the LFE, Vorbis puts centre second."""
    var lib = _lib()
    var vorbis = ChannelMap.standard(lib, 6, StandardMapVorbis)
    assert_equal(vorbis.channel(1), ChannelFrontCenter)
    var default = ChannelMap.standard(lib, 6, StandardMapDefault)
    assert_equal(default.channel(1), ChannelFrontRight)
    assert_false(vorbis.is_equal(default))
    var flac = ChannelMap.standard(lib, 6, StandardMapFlac)
    assert_equal(flac.channel(3), ChannelLfe)
    var alsa = ChannelMap.standard(lib, 4, StandardMapAlsa)
    assert_false(alsa.contains(ChannelFrontCenter))
    assert_true(ChannelMap.standard(lib, 4).contains(ChannelFrontCenter))


def test_standard_map_past_eight_channels_uses_aux_positions() raises:
    var lib = _lib()
    var ten = ChannelMap.standard(lib, 10)
    assert_equal(ten.channel(7), ChannelSideRight)
    assert_equal(ten.channel(8), ChannelAux0)
    assert_equal(ten.channel(9), ChannelAux0 + 1)
    var thirty_three = ChannelMap.standard(lib, 33)
    assert_equal(thirty_three.channel(31), ChannelAux0 + 23)
    assert_equal(thirty_three.channel(32), ChannelNone)  # nothing defined that far


def test_blank_map_is_blank_and_valid() raises:
    var lib = _lib()
    var blank = ChannelMap.blank(lib, 4)
    assert_true(blank.is_blank())
    assert_true(blank.is_valid())
    assert_equal(blank.channel(2), ChannelNone)
    assert_false(ChannelMap.standard(lib, 4).is_blank())


def test_validity_rules() raises:
    var lib = _lib()
    var mono_in_stereo: List[UInt8] = [ChannelMono, ChannelFrontLeft]
    assert_false(ChannelMap.from_positions(lib, mono_in_stereo).is_valid())
    var lone_mono: List[UInt8] = [ChannelMono]
    assert_true(ChannelMap.from_positions(lib, lone_mono).is_valid())
    # Repeated positions are not checked.
    var twice: List[UInt8] = [ChannelFrontLeft, ChannelFrontLeft]
    assert_true(ChannelMap.from_positions(lib, twice).is_valid())


def test_from_positions_copies_its_input() raises:
    var lib = _lib()
    var source: List[UInt8] = [ChannelFrontLeft, ChannelFrontRight]
    var m = ChannelMap.from_positions(lib, source)
    source[0] = ChannelLfe
    assert_equal(m.channel(0), ChannelFrontLeft)
    var c = m.clone()
    assert_true(c.is_equal(m))
    assert_true(_same(c.positions(), m.positions()))


def test_equality_is_position_by_position() raises:
    var lib = _lib()
    var a = ChannelMap.standard(lib, 2)
    var swapped_positions: List[UInt8] = [ChannelFrontRight, ChannelFrontLeft]
    var swapped = ChannelMap.from_positions(lib, swapped_positions)
    assert_true(a.is_equal(ChannelMap.standard(lib, 2)))
    assert_false(a.is_equal(swapped))


def test_copy_or_default() raises:
    var lib = _lib()
    var given: List[UInt8] = [ChannelSideLeft, ChannelSideRight]
    var copied = ChannelMap.copy_or_default(lib, 2, given)
    assert_true(_same(copied.positions(), given))
    var fallback = ChannelMap.copy_or_default(lib, 2)
    assert_true(fallback.is_equal(ChannelMap.standard(lib, 2)))


def test_lookup_contains_and_find() raises:
    var lib = _lib()
    var m = ChannelMap.standard(lib, 6)
    assert_true(m.contains(ChannelLfe))
    assert_false(m.contains(ChannelBackCenter))
    var lfe = m.find(ChannelLfe)
    assert_true(Bool(lfe))
    assert_equal(lfe.value(), UInt32(3))
    assert_false(Bool(m.find(ChannelBackCenter)))
    assert_equal(m.channel(9), ChannelNone)  # past the end


def test_to_string_and_position_names() raises:
    var lib = _lib()
    assert_equal(
        ChannelMap.standard(lib, 2).to_string(), "CHANNEL_FRONT_LEFT CHANNEL_FRONT_RIGHT"
    )
    assert_equal(ChannelMap.blank(lib, 2).to_string(), "CHANNEL_NONE CHANNEL_NONE")
    assert_equal(channel_position_name(lib, ChannelLfe), "CHANNEL_LFE")
    assert_equal(channel_position_name(lib, 200), "UNKNOWN")


def test_invalid_requests_raise() raises:
    var lib = _lib()
    with assert_raises():
        _ = ChannelMap.blank(lib, 0)
    with assert_raises():
        _ = ChannelMap.standard(lib, 0)
    with assert_raises():
        _ = ChannelMap.standard(lib, 2, 99)  # not a standard convention
    with assert_raises():
        _ = ChannelMap.from_positions(lib, List[UInt8]())  # nothing to copy


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
