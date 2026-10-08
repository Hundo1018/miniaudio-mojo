"""TDD contract tests for the crt_util BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the 11 bindable MA_API C-runtime
helpers run on caller buffers. The *_s helpers return errno-style codes (0 ok,
22 EINVAL, 34 ERANGE), which are asserted exactly. An empty list stands for
NULL; `dst_cap` is the capacity passed to miniaudio (clamped to the list).
"""

from std.os import listdir, remove
from std.os.path import exists
from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_DOES_NOT_EXIST
import miniaudio._ffi.util_raw as raw

comptime OK = raw.ERRNO_OK
comptime EINVAL = raw.ERRNO_EINVAL
comptime ERANGE = raw.ERRNO_ERANGE
comptime TRUNCATE = UInt64.MAX


def _lib() raises -> MaLib:
    return MaLib.default()


def _buf(n: Int) -> List[UInt8]:
    var b = List[UInt8]()
    b.resize(n, UInt8(0))
    return b^


def _holding(text: String, n: Int) -> List[UInt8]:
    """An n-byte buffer starting with `text` (no terminator added past the text)."""
    var b = _buf(n)
    var i = 0
    for ch in text.as_bytes():
        b[i] = ch
        i += 1
    return b^


def _wide(text: String) -> List[UInt32]:
    var w = List[UInt32]()
    for cp in text.codepoints():
        w.append(cp.to_u32())
    w.append(UInt32(0))
    return w^


def _wbuf(n: Int) -> List[UInt32]:
    var w = List[UInt32]()
    w.resize(n, UInt32(0))
    return w^


def test_c_bytes_and_c_text_round_trip() raises:
    var b = raw.c_bytes("abc")
    assert_equal(len(b), 4)
    assert_equal(b[3], UInt8(0))
    assert_equal(raw.c_text(b), "abc")
    assert_equal(raw.c_text(_holding("xy", 8)), "xy")  # stops at the first NUL


# ---- strcpy_s -----------------------------------------------------------------


def test_strcpy_s_copies_and_terminates() raises:
    var lib = _lib()
    var dst = _buf(16)
    assert_equal(raw.crt_strcpy_s(lib, dst, 16, raw.c_bytes("hello")), OK)
    assert_equal(raw.c_text(dst), "hello")
    var exact = _buf(6)
    assert_equal(raw.crt_strcpy_s(lib, exact, 6, raw.c_bytes("hello")), OK)  # fits with its NUL
    assert_equal(raw.c_text(exact), "hello")


def test_strcpy_s_reports_erange_when_the_text_does_not_fit() raises:
    var lib = _lib()
    var dst = _holding("zzzzz", 5)
    assert_equal(raw.crt_strcpy_s(lib, dst, 5, raw.c_bytes("hello")), ERANGE)
    assert_equal(dst[0], UInt8(0))  # the destination is cleared on failure
    var none = _holding("zz", 4)
    assert_equal(raw.crt_strcpy_s(lib, none, 0, raw.c_bytes("hi")), ERANGE)  # zero capacity
    assert_equal(none[0], UInt8(ord("z")))  # and left alone


def test_strcpy_s_reports_einval_for_null_arguments() raises:
    var lib = _lib()
    var dst = _holding("keep", 8)
    assert_equal(raw.crt_strcpy_s(lib, dst, 8, List[UInt8]()), EINVAL)  # NULL src
    assert_equal(dst[0], UInt8(0))  # the destination is cleared
    var no_dst = List[UInt8]()
    assert_equal(raw.crt_strcpy_s(lib, no_dst, 8, raw.c_bytes("x")), EINVAL)  # NULL dst


# ---- strncpy_s ----------------------------------------------------------------


def test_strncpy_s_copies_at_most_count_bytes() raises:
    var lib = _lib()
    var dst = _buf(16)
    assert_equal(raw.crt_strncpy_s(lib, dst, 16, raw.c_bytes("hello"), 2), OK)
    assert_equal(raw.c_text(dst), "he")
    var all = _buf(16)
    assert_equal(raw.crt_strncpy_s(lib, all, 16, raw.c_bytes("hello"), 5), OK)
    assert_equal(raw.c_text(all), "hello")
    var generous = _buf(16)
    assert_equal(raw.crt_strncpy_s(lib, generous, 16, raw.c_bytes("hello"), 100), OK)
    assert_equal(raw.c_text(generous), "hello")


def test_strncpy_s_truncate_count_clips_instead_of_failing() raises:
    var lib = _lib()
    var dst = _buf(4)
    assert_equal(raw.crt_strncpy_s(lib, dst, 4, raw.c_bytes("hello"), TRUNCATE), OK)
    assert_equal(raw.c_text(dst), "hel")


def test_strncpy_s_with_a_count_past_the_buffer_fails_instead_of_clipping() raises:
    """Quirk: only a count of SIZE_MAX clips; any other count >= capacity is ERANGE."""
    var lib = _lib()
    var dst = _holding("zzz", 4)
    assert_equal(raw.crt_strncpy_s(lib, dst, 4, raw.c_bytes("hello"), 100), ERANGE)
    assert_equal(dst[0], UInt8(0))
    var within = _buf(4)
    assert_equal(raw.crt_strncpy_s(lib, within, 4, raw.c_bytes("hello"), 3), OK)
    assert_equal(raw.c_text(within), "hel")


def test_strncpy_s_null_and_zero_capacity() raises:
    var lib = _lib()
    var dst = _holding("keep", 8)
    assert_equal(raw.crt_strncpy_s(lib, dst, 8, List[UInt8](), 3), EINVAL)
    assert_equal(dst[0], UInt8(0))
    var no_dst = List[UInt8]()
    assert_equal(raw.crt_strncpy_s(lib, no_dst, 8, raw.c_bytes("x"), 1), EINVAL)
    var other = _buf(4)
    assert_equal(raw.crt_strncpy_s(lib, other, 0, raw.c_bytes("x"), 1), ERANGE)


# ---- strcat_s -----------------------------------------------------------------


def test_strcat_s_appends() raises:
    var lib = _lib()
    var dst = _holding("foo", 16)
    assert_equal(raw.crt_strcat_s(lib, dst, 16, raw.c_bytes("bar")), OK)
    assert_equal(raw.c_text(dst), "foobar")
    var exact = _holding("foo", 7)
    assert_equal(raw.crt_strcat_s(lib, exact, 7, raw.c_bytes("bar")), OK)  # exactly fits
    assert_equal(raw.c_text(exact), "foobar")


def test_strcat_s_erange_clears_the_destination() raises:
    var lib = _lib()
    var dst = _holding("foo", 6)
    assert_equal(raw.crt_strcat_s(lib, dst, 6, raw.c_bytes("bar")), ERANGE)  # needs 7
    assert_equal(dst[0], UInt8(0))


def test_strcat_s_einval_cases() raises:
    var lib = _lib()
    var unterminated = _holding("foo", 3)  # no room for the NUL: not a string
    assert_equal(raw.crt_strcat_s(lib, unterminated, 3, raw.c_bytes("x")), EINVAL)
    var dst = _holding("foo", 8)
    assert_equal(raw.crt_strcat_s(lib, dst, 8, List[UInt8]()), EINVAL)  # NULL src clears dst
    assert_equal(dst[0], UInt8(0))
    var no_dst = List[UInt8]()
    assert_equal(raw.crt_strcat_s(lib, no_dst, 8, raw.c_bytes("x")), EINVAL)
    var other = _holding("a", 4)
    assert_equal(raw.crt_strcat_s(lib, other, 0, raw.c_bytes("x")), ERANGE)


# ---- strncat_s ----------------------------------------------------------------


def test_strncat_s_appends_at_most_count_bytes() raises:
    var lib = _lib()
    var dst = _holding("foo", 16)
    assert_equal(raw.crt_strncat_s(lib, dst, 16, raw.c_bytes("bar"), 2), OK)
    assert_equal(raw.c_text(dst), "fooba")
    var all = _holding("foo", 16)
    assert_equal(raw.crt_strncat_s(lib, all, 16, raw.c_bytes("bar"), 10), OK)
    assert_equal(raw.c_text(all), "foobar")


def test_strncat_s_truncate_count_clips_instead_of_failing() raises:
    var lib = _lib()
    var dst = _holding("foo", 6)
    assert_equal(raw.crt_strncat_s(lib, dst, 6, raw.c_bytes("barbaz"), TRUNCATE), OK)
    assert_equal(raw.c_text(dst), "fooba")


def test_strncat_s_erange_when_a_finite_count_overflows() raises:
    var lib = _lib()
    var dst = _holding("foo", 6)
    assert_equal(raw.crt_strncat_s(lib, dst, 6, raw.c_bytes("barbaz"), 10), ERANGE)
    assert_equal(dst[0], UInt8(0))


def test_strncat_s_null_source_leaves_the_destination_alone() raises:
    """Quirk: unlike strcat_s, a NULL source does not clear the destination."""
    var lib = _lib()
    var dst = _holding("foo", 8)
    assert_equal(raw.crt_strncat_s(lib, dst, 8, List[UInt8](), 2), EINVAL)
    assert_equal(raw.c_text(dst), "foo")
    var unterminated = _holding("foo", 3)
    assert_equal(raw.crt_strncat_s(lib, unterminated, 3, raw.c_bytes("x"), 1), EINVAL)
    var no_dst = List[UInt8]()
    assert_equal(raw.crt_strncat_s(lib, no_dst, 8, raw.c_bytes("x"), 1), EINVAL)
    var other = _holding("a", 4)
    assert_equal(raw.crt_strncat_s(lib, other, 0, raw.c_bytes("x"), 1), ERANGE)


# ---- strappend ----------------------------------------------------------------


def test_strappend_joins_two_strings() raises:
    var lib = _lib()
    var dst = _buf(16)
    assert_equal(raw.crt_strappend(lib, dst, 16, raw.c_bytes("foo"), raw.c_bytes("bar")), OK)
    assert_equal(raw.c_text(dst), "foobar")


def test_strappend_truncates_to_the_buffer() raises:
    var lib = _lib()
    var dst = _buf(6)
    assert_equal(raw.crt_strappend(lib, dst, 6, raw.c_bytes("foo"), raw.c_bytes("bar")), OK)
    assert_equal(raw.c_text(dst), "fooba")
    var first_only = _buf(4)
    assert_equal(
        raw.crt_strappend(lib, first_only, 4, raw.c_bytes("foobar"), raw.c_bytes("baz")), OK
    )
    assert_equal(raw.c_text(first_only), "foo")


def test_strappend_null_arguments() raises:
    var lib = _lib()
    var dst = _holding("zz", 8)
    assert_equal(raw.crt_strappend(lib, dst, 8, List[UInt8](), raw.c_bytes("x")), EINVAL)
    assert_equal(dst[0], UInt8(0))
    var second = _buf(8)
    assert_equal(raw.crt_strappend(lib, second, 8, raw.c_bytes("foo"), List[UInt8]()), EINVAL)
    assert_equal(raw.c_text(second), "foo")  # the first half was already copied


# ---- itoa_s -------------------------------------------------------------------


def test_itoa_s_formats_in_several_radixes() raises:
    var lib = _lib()
    var d = _buf(16)
    assert_equal(raw.crt_itoa_s(lib, 0, d, 16, 10), OK)
    assert_equal(raw.c_text(d), "0")
    assert_equal(raw.crt_itoa_s(lib, 255, d, 16, 10), OK)
    assert_equal(raw.c_text(d), "255")
    assert_equal(raw.crt_itoa_s(lib, -42, d, 16, 10), OK)
    assert_equal(raw.c_text(d), "-42")
    assert_equal(raw.crt_itoa_s(lib, 255, d, 16, 16), OK)
    assert_equal(raw.c_text(d), "ff")
    assert_equal(raw.crt_itoa_s(lib, 255, d, 16, 2), OK)
    assert_equal(raw.c_text(d), "11111111")
    assert_equal(raw.crt_itoa_s(lib, 35, d, 16, 36), OK)
    assert_equal(raw.c_text(d), "z")


def test_itoa_s_signs_only_appear_in_base_ten() raises:
    var lib = _lib()
    var d = _buf(16)
    assert_equal(raw.crt_itoa_s(lib, -255, d, 16, 16), OK)
    assert_equal(raw.c_text(d), "ff")  # magnitude only


def test_itoa_s_capacity_must_hold_the_digits_the_sign_and_the_nul() raises:
    var lib = _lib()
    var fits = _buf(3)
    assert_equal(raw.crt_itoa_s(lib, 99, fits, 3, 10), OK)
    assert_equal(raw.c_text(fits), "99")
    var no_nul = _buf(2)
    assert_equal(raw.crt_itoa_s(lib, 99, no_nul, 2, 10), EINVAL)
    assert_equal(no_nul[0], UInt8(0))
    var no_sign = _buf(2)
    assert_equal(raw.crt_itoa_s(lib, -5, no_sign, 2, 10), EINVAL)
    assert_equal(no_sign[0], UInt8(0))
    var too_long = _buf(3)
    assert_equal(raw.crt_itoa_s(lib, 12345, too_long, 3, 10), EINVAL)


def test_itoa_s_rejects_bad_radix_and_null() raises:
    var lib = _lib()
    var d = _holding("zz", 8)
    assert_equal(raw.crt_itoa_s(lib, 5, d, 8, 1), EINVAL)
    assert_equal(d[0], UInt8(0))
    var e = _holding("zz", 8)
    assert_equal(raw.crt_itoa_s(lib, 5, e, 8, 37), EINVAL)
    var no_dst = List[UInt8]()
    assert_equal(raw.crt_itoa_s(lib, 5, no_dst, 8, 10), EINVAL)
    var zero_cap = _buf(4)
    assert_equal(raw.crt_itoa_s(lib, 5, zero_cap, 0, 10), EINVAL)


# ---- strcmp -------------------------------------------------------------------


def test_strcmp_orders_strings() raises:
    var lib = _lib()
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("abc"), raw.c_bytes("abc")), 0)
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("a"), raw.c_bytes("b")), -1)
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("b"), raw.c_bytes("a")), 1)
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("abc"), raw.c_bytes("abd")), -1)
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("abc"), raw.c_bytes("ab")), 99)  # 'c' - NUL
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("ab"), raw.c_bytes("abc")), -99)


def test_strcmp_compares_bytes_as_unsigned() raises:
    var lib = _lib()
    var high: List[UInt8] = [UInt8(255), UInt8(0)]
    assert_equal(raw.crt_strcmp(lib, high, raw.c_bytes("a")), 255 - 97)


def test_strcmp_null_sorts_first() raises:
    var lib = _lib()
    var empty = List[UInt8]()
    assert_equal(raw.crt_strcmp(lib, empty, raw.c_bytes("a")), -1)
    assert_equal(raw.crt_strcmp(lib, raw.c_bytes("a"), empty), 1)
    assert_equal(raw.crt_strcmp(lib, empty, empty), 0)


# ---- wide strings -------------------------------------------------------------


def test_wcslen_counts_wide_characters() raises:
    var lib = _lib()
    assert_equal(raw.crt_wcslen(lib, _wide("hello")), UInt64(5))
    assert_equal(raw.crt_wcslen(lib, _wide("")), UInt64(0))
    assert_equal(raw.crt_wcslen(lib, _wide("héllo 😀")), UInt64(7))  # one wchar_t per code point
    assert_equal(raw.crt_wcslen(lib, List[UInt32]()), UInt64(0))  # NULL


def test_wcscmp_orders_wide_strings() raises:
    var lib = _lib()
    assert_equal(raw.crt_wcscmp(lib, _wide("abc"), _wide("abc")), 0)
    assert_equal(raw.crt_wcscmp(lib, _wide("a"), _wide("b")), -1)
    assert_equal(raw.crt_wcscmp(lib, _wide("b"), _wide("a")), 1)
    assert_equal(raw.crt_wcscmp(lib, _wide("abc"), _wide("ab")), 99)
    var empty = List[UInt32]()
    assert_equal(raw.crt_wcscmp(lib, empty, _wide("a")), -1)
    assert_equal(raw.crt_wcscmp(lib, _wide("a"), empty), 1)
    assert_equal(raw.crt_wcscmp(lib, empty, empty), 0)


def test_wcscmp_only_looks_at_the_low_16_bits_of_the_differing_character() raises:
    """Quirk: characters that differ only above bit 15 compare equal."""
    var lib = _lib()
    var a: List[UInt32] = [UInt32(0x10061), UInt32(0)]
    var b: List[UInt32] = [UInt32(0x20061), UInt32(0)]
    assert_equal(raw.crt_wcscmp(lib, a, b), 0)
    var c: List[UInt32] = [UInt32(0x10062), UInt32(0)]
    assert_equal(raw.crt_wcscmp(lib, a, c), -1)  # differ in the low bits: ordered by them


def test_wcscpy_s_copies_and_reports_erange_and_einval() raises:
    var lib = _lib()
    var dst = _wbuf(8)
    assert_equal(raw.crt_wcscpy_s(lib, dst, 8, _wide("hello")), OK)
    assert_equal(raw.crt_wcslen(lib, dst), UInt64(5))
    assert_equal(raw.crt_wcscmp(lib, dst, _wide("hello")), 0)
    var exact = _wbuf(6)
    assert_equal(raw.crt_wcscpy_s(lib, exact, 6, _wide("hello")), OK)
    var small = _wbuf(5)
    small[0] = UInt32(0x7a)
    assert_equal(raw.crt_wcscpy_s(lib, small, 5, _wide("hello")), ERANGE)
    assert_equal(small[0], UInt32(0))  # cleared
    var d2 = _wbuf(4)
    d2[0] = UInt32(0x7a)
    assert_equal(raw.crt_wcscpy_s(lib, d2, 4, List[UInt32]()), EINVAL)  # NULL src clears dst
    assert_equal(d2[0], UInt32(0))
    var no_dst = List[UInt32]()
    assert_equal(raw.crt_wcscpy_s(lib, no_dst, 4, _wide("x")), EINVAL)  # NULL dst
    var d3 = _wbuf(4)
    assert_equal(raw.crt_wcscpy_s(lib, d3, 0, _wide("x")), ERANGE)  # zero capacity


# ---- fopen --------------------------------------------------------------------


def test_fopen_succeeds_on_an_existing_file_and_closes_it() raises:
    var lib = _lib()
    var before = len(listdir("/proc/self/fd"))
    for _ in range(50):
        assert_equal(raw.crt_fopen(lib, raw.c_bytes("pixi.toml"), raw.c_bytes("rb")), MA_SUCCESS)
    # The shim closes the FILE* it opens: no descriptor is left behind.
    assert_equal(len(listdir("/proc/self/fd")), before)


def test_fopen_reports_a_missing_file() raises:
    var lib = _lib()
    var rc = raw.crt_fopen(lib, raw.c_bytes("build/no_such_file_for_crt_util.bin"), raw.c_bytes("rb"))
    assert_equal(rc, MA_DOES_NOT_EXIST)


def test_fopen_write_mode_creates_the_file() raises:
    var lib = _lib()
    var path = "build/crt_util_fopen_probe.tmp"
    if exists(path):
        remove(path)
    assert_false(exists(path))
    assert_equal(raw.crt_fopen(lib, raw.c_bytes(path), raw.c_bytes("wb")), MA_SUCCESS)
    assert_true(exists(path))
    remove(path)


def test_fopen_maps_other_errno_values() raises:
    var lib = _lib()
    assert_equal(raw.crt_fopen(lib, raw.c_bytes("build"), raw.c_bytes("wb")), raw.MA_IS_DIRECTORY)
    assert_equal(
        raw.crt_fopen(lib, raw.c_bytes("pixi.toml"), raw.c_bytes("not-a-mode")), MA_INVALID_ARGS
    )


def test_fopen_null_arguments_are_invalid() raises:
    var lib = _lib()
    assert_equal(raw.crt_fopen(lib, List[UInt8](), raw.c_bytes("rb")), MA_INVALID_ARGS)
    assert_equal(raw.crt_fopen(lib, raw.c_bytes("pixi.toml"), List[UInt8]()), MA_INVALID_ARGS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
