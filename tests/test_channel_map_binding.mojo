"""TDD contract tests for the channel-map BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a channel map is a byte list, so every
one of the 12 MA_API channel-map functions runs on caller memory. Each raw
function gets a positive and a negative path; an empty list stands for NULL.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.channel_map_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def _filled(n: Int, value: UInt8) -> List[UInt8]:
    var buf = List[UInt8]()
    buf.resize(n, value)
    return buf^


def _map(*values: UInt8) -> List[UInt8]:
    var buf = List[UInt8]()
    for v in values:
        buf.append(v)
    return buf^


def _same(a: List[UInt8], b: List[UInt8]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def test_init_blank_clears_only_the_requested_channels() raises:
    var lib = _lib()
    var buf = _filled(8, 9)
    assert_equal(raw.channel_map_init_blank(lib, buf, 6), MA_SUCCESS)
    for i in range(6):
        assert_equal(buf[i], UInt8(0))
    assert_equal(buf[6], UInt8(9))
    assert_equal(buf[7], UInt8(9))


def test_init_blank_rejects_bad_args() raises:
    var lib = _lib()
    var empty = List[UInt8]()
    var buf = _filled(4, 9)
    assert_equal(raw.channel_map_init_blank(lib, empty, 2), MA_INVALID_ARGS)  # NULL map
    assert_equal(raw.channel_map_init_blank(lib, buf, 0), MA_INVALID_ARGS)  # zero channels
    assert_equal(raw.channel_map_init_blank(lib, buf, 5), MA_INVALID_ARGS)  # buffer too short
    assert_equal(buf[0], UInt8(9))  # a refused call leaves the buffer alone


def test_init_standard_microsoft_layouts() raises:
    var lib = _lib()
    var mono = _filled(1, 9)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_DEFAULT, mono, 1), MA_SUCCESS)
    assert_true(_same(mono, _map(raw.CHANNEL_MONO)))

    var stereo = _filled(2, 9)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_MICROSOFT, stereo, 2), MA_SUCCESS)
    assert_true(_same(stereo, _map(raw.CHANNEL_FRONT_LEFT, raw.CHANNEL_FRONT_RIGHT)))

    var surround = _filled(6, 9)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_DEFAULT, surround, 6), MA_SUCCESS)
    assert_true(
        _same(
            surround,
            _map(
                raw.CHANNEL_FRONT_LEFT,
                raw.CHANNEL_FRONT_RIGHT,
                raw.CHANNEL_FRONT_CENTER,
                raw.CHANNEL_LFE,
                raw.CHANNEL_SIDE_LEFT,
                raw.CHANNEL_SIDE_RIGHT,
            ),
        )
    )


def test_standard_layouts_differ_between_conventions() raises:
    """Four channels: Microsoft is front + centre + back-centre, ALSA is a quad."""
    var lib = _lib()
    var ms = _filled(4, 0)
    var alsa = _filled(4, 0)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_MICROSOFT, ms, 4), MA_SUCCESS)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_ALSA, alsa, 4), MA_SUCCESS)
    assert_true(
        _same(
            ms,
            _map(
                raw.CHANNEL_FRONT_LEFT,
                raw.CHANNEL_FRONT_RIGHT,
                raw.CHANNEL_FRONT_CENTER,
                raw.CHANNEL_BACK_CENTER,
            ),
        )
    )
    assert_true(
        _same(
            alsa,
            _map(
                raw.CHANNEL_FRONT_LEFT,
                raw.CHANNEL_FRONT_RIGHT,
                raw.CHANNEL_BACK_LEFT,
                raw.CHANNEL_BACK_RIGHT,
            ),
        )
    )
    for standard in range(raw.STANDARD_MAP_SNDIO + 1):  # every convention initialises
        var buf = _filled(4, 0)
        assert_equal(raw.channel_map_init_standard(lib, standard, buf, 4), MA_SUCCESS)


def test_init_standard_fills_no_more_than_the_buffer_holds() raises:
    """Six channels into a three-entry buffer writes the first three, no further."""
    var lib = _lib()
    var buf = _filled(3, 9)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_DEFAULT, buf, 6), MA_SUCCESS)
    assert_true(_same(buf, _map(raw.CHANNEL_FRONT_LEFT, raw.CHANNEL_FRONT_RIGHT, raw.CHANNEL_FRONT_CENTER)))


def test_init_standard_rejects_bad_args() raises:
    var lib = _lib()
    var empty = List[UInt8]()
    var buf = _filled(2, 9)
    assert_equal(raw.channel_map_init_standard(lib, -1, buf, 2), MA_INVALID_ARGS)  # bad enum
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_SNDIO + 1, buf, 2), MA_INVALID_ARGS)
    assert_equal(raw.channel_map_init_standard(lib, 0, empty, 2), MA_INVALID_ARGS)  # NULL / zero cap
    assert_equal(raw.channel_map_init_standard(lib, 0, buf, 0), MA_INVALID_ARGS)  # zero channels
    assert_equal(buf[0], UInt8(9))


def test_copy_copies_the_requested_channels() raises:
    var lib = _lib()
    var src = _map(4, 5, 6, 7)
    var dst = _filled(6, 9)
    assert_equal(raw.channel_map_copy(lib, dst, src, 4), MA_SUCCESS)
    assert_true(_same(dst, _map(4, 5, 6, 7, 9, 9)))


def test_copy_rejects_bad_args() raises:
    var lib = _lib()
    var src = _map(4, 5, 6)
    var dst = _filled(3, 9)
    var empty = List[UInt8]()
    assert_equal(raw.channel_map_copy(lib, empty, src, 3), MA_INVALID_ARGS)  # NULL out
    assert_equal(raw.channel_map_copy(lib, dst, empty, 3), MA_INVALID_ARGS)  # NULL in
    assert_equal(raw.channel_map_copy(lib, dst, src, 0), MA_INVALID_ARGS)  # zero channels
    assert_equal(raw.channel_map_copy(lib, dst, src, 4), MA_INVALID_ARGS)  # both too short
    assert_true(_same(dst, _filled(3, 9)))


def test_copy_or_default_copies_when_given_a_map() raises:
    var lib = _lib()
    var src = _map(11, 12)
    var dst = _filled(2, 9)
    assert_equal(raw.channel_map_copy_or_default(lib, dst, src, 2), MA_SUCCESS)
    assert_true(_same(dst, src))


def test_copy_or_default_falls_back_to_the_default_map() raises:
    var lib = _lib()
    var dst = _filled(6, 9)
    assert_equal(raw.channel_map_copy_or_default(lib, dst, List[UInt8](), 6), MA_SUCCESS)
    var expected = _filled(6, 0)
    assert_equal(raw.channel_map_init_standard(lib, raw.STANDARD_MAP_DEFAULT, expected, 6), MA_SUCCESS)
    assert_true(_same(dst, expected))


def test_copy_or_default_rejects_bad_args() raises:
    var lib = _lib()
    var src = _map(2, 3)
    var dst = _filled(2, 9)
    var empty = List[UInt8]()
    assert_equal(raw.channel_map_copy_or_default(lib, empty, src, 2), MA_INVALID_ARGS)  # NULL out
    assert_equal(raw.channel_map_copy_or_default(lib, dst, src, 0), MA_INVALID_ARGS)  # zero channels
    assert_equal(raw.channel_map_copy_or_default(lib, dst, src, 3), MA_INVALID_ARGS)  # in too short
    assert_equal(raw.channel_map_copy_or_default(lib, dst, _map(2, 3, 4), 3), MA_INVALID_ARGS)  # out too short
    assert_true(_same(dst, _filled(2, 9)))


def test_get_channel_reads_the_map_and_clamps_the_index() raises:
    var lib = _lib()
    var m = _map(2, 3, 4)
    var second = raw.channel_map_get_channel(lib, m, 3, 1)
    assert_equal(second.result, MA_SUCCESS)
    assert_equal(second.value, UInt32(3))
    var past = raw.channel_map_get_channel(lib, m, 3, 3)
    assert_equal(past.result, MA_SUCCESS)
    assert_equal(past.value, UInt32(raw.CHANNEL_NONE))


def test_get_channel_on_a_null_map_reads_the_default() raises:
    var lib = _lib()
    var first = raw.channel_map_get_channel(lib, List[UInt8](), 2, 0)
    var second = raw.channel_map_get_channel(lib, List[UInt8](), 2, 1)
    assert_equal(first.value, UInt32(raw.CHANNEL_FRONT_LEFT))
    assert_equal(second.value, UInt32(raw.CHANNEL_FRONT_RIGHT))
    assert_equal(raw.channel_map_get_channel(lib, List[UInt8](), 1, 0).value, UInt32(raw.CHANNEL_MONO))


def test_get_channel_rejects_a_map_shorter_than_its_count() raises:
    var lib = _lib()
    var rc = raw.channel_map_get_channel(lib, _map(2, 3), 3, 0)
    assert_equal(rc.result, MA_INVALID_ARGS)
    assert_equal(rc.value, UInt32(0))


def test_is_valid_accepts_ordinary_maps_and_blank_maps() raises:
    var lib = _lib()
    assert_true(raw.channel_map_is_valid(lib, _map(2, 3), 2).value)
    assert_true(raw.channel_map_is_valid(lib, _map(1), 1).value)  # mono alone is fine
    assert_true(raw.channel_map_is_valid(lib, _filled(4, 0), 4).value)  # blank is valid
    assert_true(raw.channel_map_is_valid(lib, List[UInt8](), 2).value)  # default map


def test_is_valid_rejects_zero_channels_and_mono_among_many() raises:
    var lib = _lib()
    var zero = raw.channel_map_is_valid(lib, List[UInt8](), 0)
    assert_equal(zero.result, MA_SUCCESS)
    assert_false(zero.value)
    assert_false(raw.channel_map_is_valid(lib, _map(1, 2), 2).value)  # mono + front left
    assert_equal(raw.channel_map_is_valid(lib, _map(2), 2).result, MA_INVALID_ARGS)  # short buffer


def test_is_equal_compares_position_by_position() raises:
    var lib = _lib()
    assert_true(raw.channel_map_is_equal(lib, _map(2, 3), _map(2, 3), 2).value)
    assert_false(raw.channel_map_is_equal(lib, _map(2, 3), _map(3, 2), 2).value)
    assert_true(raw.channel_map_is_equal(lib, List[UInt8](), List[UInt8](), 2).value)
    # NULL is the default map, so it equals the explicit default and nothing else.
    assert_true(raw.channel_map_is_equal(lib, List[UInt8](), _map(2, 3), 2).value)
    assert_false(raw.channel_map_is_equal(lib, _map(3, 2), List[UInt8](), 2).value)
    assert_equal(raw.channel_map_is_equal(lib, _map(2), _map(2, 3), 2).result, MA_INVALID_ARGS)


def test_is_blank_means_every_position_is_none() raises:
    var lib = _lib()
    assert_true(raw.channel_map_is_blank(lib, _filled(3, 0), 3).value)
    assert_false(raw.channel_map_is_blank(lib, _map(0, 0, 2), 3).value)
    var null_map = raw.channel_map_is_blank(lib, List[UInt8](), 3)  # NULL = default, never blank
    assert_equal(null_map.result, MA_SUCCESS)
    assert_false(null_map.value)
    assert_equal(raw.channel_map_is_blank(lib, _map(0), 3).result, MA_INVALID_ARGS)


def test_contains_channel_position() raises:
    var lib = _lib()
    var m = _map(2, 3, 4, 5)
    assert_true(raw.channel_map_contains_channel_position(lib, 4, m, 4).value)
    assert_false(raw.channel_map_contains_channel_position(lib, 4, m, 11).value)
    assert_true(raw.channel_map_contains_channel_position(lib, 2, List[UInt8](), 3).value)  # default stereo
    assert_equal(
        raw.channel_map_contains_channel_position(lib, 4, m, 256).result, MA_INVALID_ARGS
    )  # not a ma_channel
    assert_equal(raw.channel_map_contains_channel_position(lib, 5, m, 4).result, MA_INVALID_ARGS)


def test_find_channel_position_reports_the_first_index() raises:
    var lib = _lib()
    var m = _map(2, 3, 4, 3)
    var found = raw.channel_map_find_channel_position(lib, 4, m, 3)
    assert_equal(found.result, MA_SUCCESS)
    assert_true(found.found)
    assert_equal(found.index, UInt32(1))  # first of the two
    var missing = raw.channel_map_find_channel_position(lib, 4, m, 11)
    assert_equal(missing.result, MA_SUCCESS)
    assert_false(missing.found)
    assert_equal(missing.index, UInt32(0xFFFFFFFF))
    assert_equal(raw.channel_map_find_channel_position(lib, 4, m, 300).result, MA_INVALID_ARGS)
    assert_equal(raw.channel_map_find_channel_position(lib, 5, m, 3).result, MA_INVALID_ARGS)


def test_to_string_names_every_channel() raises:
    var lib = _lib()
    var rc = raw.channel_map_to_string(lib, _map(2, 3), 2)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.text, "CHANNEL_FRONT_LEFT CHANNEL_FRONT_RIGHT")
    assert_equal(rc.length, UInt32(38))
    var default_stereo = raw.channel_map_to_string(lib, List[UInt8](), 2)
    assert_equal(default_stereo.text, "CHANNEL_FRONT_LEFT CHANNEL_FRONT_RIGHT")
    var none = raw.channel_map_to_string(lib, List[UInt8](), 0)
    assert_equal(none.text, "")
    assert_equal(none.length, UInt32(0))


def test_to_string_drops_whole_names_that_do_not_fit() raises:
    """A short buffer loses whole names, not characters; the length stays the full one."""
    var lib = _lib()
    var tight = raw.channel_map_to_string(lib, _map(2, 3), 2, 25)
    assert_equal(tight.result, MA_SUCCESS)
    assert_equal(tight.text, "CHANNEL_FRONT_LEFT ")
    assert_equal(tight.length, UInt32(38))
    var tiny = raw.channel_map_to_string(lib, _map(2, 3), 2, 10)
    assert_equal(tiny.text, "")
    assert_equal(tiny.length, UInt32(38))


def test_length_only_query_and_bad_args() raises:
    var lib = _lib()
    var length = raw.channel_map_length(lib, _map(2, 3), 2)
    assert_equal(length.result, MA_SUCCESS)
    assert_equal(length.value, UInt32(38))
    assert_equal(raw.channel_map_to_string(lib, _map(2), 2).result, MA_INVALID_ARGS)  # short map
    assert_equal(raw.channel_map_length(lib, _map(2), 2).result, MA_INVALID_ARGS)


def test_position_to_string() raises:
    var lib = _lib()
    assert_equal(raw.channel_position_to_string(lib, 0).value, "CHANNEL_NONE")
    assert_equal(raw.channel_position_to_string(lib, 2).value, "CHANNEL_FRONT_LEFT")
    assert_equal(raw.channel_position_to_string(lib, 5).value, "CHANNEL_LFE")
    assert_equal(raw.channel_position_to_string(lib, 51).value, "CHANNEL_AUX_31")
    assert_equal(raw.channel_position_to_string(lib, 52).value, "UNKNOWN")  # past the table
    assert_equal(raw.channel_position_to_string(lib, 255).value, "UNKNOWN")
    var bad = raw.channel_position_to_string(lib, 256)  # not a ma_channel
    assert_equal(bad.result, MA_INVALID_ARGS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
