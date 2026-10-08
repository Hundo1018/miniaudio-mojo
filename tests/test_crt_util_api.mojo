"""TDD tests for the idiomatic C-runtime helper API (free functions, L3 behavioural).

Each call returns the errno-style code with the text the buffer ends up
holding, so a refusal and its effect on the destination are both visible.
"""

from std.os import remove
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.result import MA_SUCCESS, MA_DOES_NOT_EXIST
import miniaudio.util as u


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_strcpy_fits_or_reports_erange() raises:
    var lib = _lib()
    var ok = u.strcpy_s(lib, "hello", 6)
    assert_true(ok.ok())
    assert_equal(ok.text, "hello")
    var too_small = u.strcpy_s(lib, "hello", 5)
    assert_equal(too_small.code, u.ERRNO_ERANGE)
    assert_equal(too_small.text, "")


def test_strncpy_truncates_only_for_the_truncate_count() raises:
    var lib = _lib()
    var clipped = u.strncpy_s(lib, "hello world", 6)
    assert_true(clipped.ok())
    assert_equal(clipped.text, "hello")
    var counted = u.strncpy_s(lib, "hello world", 16, 5)
    assert_equal(counted.text, "hello")
    var refused = u.strncpy_s(lib, "hello world", 6, 100)
    assert_equal(refused.code, u.ERRNO_ERANGE)


def test_strcat_builds_a_path_in_a_fixed_buffer() raises:
    var lib = _lib()
    var dir = u.strcat_s(lib, "/usr", "/lib", 16)
    assert_equal(dir.text, "/usr/lib")
    var full = u.strcat_s(lib, dir.text, "/libm.so", 12)
    assert_equal(full.code, u.ERRNO_ERANGE)  # 12 bytes cannot hold all 16
    assert_equal(full.text, "")
    var unterminated = u.strcat_s(lib, "/usr", "/lib", 4)  # the buffer has no room for a NUL
    assert_equal(unterminated.code, u.ERRNO_EINVAL)


def test_strncat_limits_the_appended_bytes() raises:
    var lib = _lib()
    assert_equal(u.strncat_s(lib, "foo", "barbaz", 16, 3).text, "foobar")
    assert_equal(u.strncat_s(lib, "foo", "barbaz", 6).text, "fooba")  # truncate to fit
    assert_equal(u.strncat_s(lib, "foo", "barbaz", 6, 6).code, u.ERRNO_ERANGE)


def test_strappend_joins_and_clips() raises:
    var lib = _lib()
    assert_equal(u.strappend(lib, "foo", "bar", 16).text, "foobar")
    assert_equal(u.strappend(lib, "foo", "bar", 6).text, "fooba")
    assert_equal(u.strappend(lib, "foobar", "baz", 4).text, "foo")


def test_itoa_formats_numbers() raises:
    var lib = _lib()
    assert_equal(u.itoa_s(lib, 1234, 16).text, "1234")
    assert_equal(u.itoa_s(lib, -1234, 16).text, "-1234")
    assert_equal(u.itoa_s(lib, 48879, 16, 16).text, "beef")
    assert_equal(u.itoa_s(lib, 10, 16, 2).text, "1010")
    assert_equal(u.itoa_s(lib, 12345, 3).code, u.ERRNO_EINVAL)
    assert_equal(u.itoa_s(lib, 5, 8, 99).code, u.ERRNO_EINVAL)


def test_strcmp_gives_an_ordering() raises:
    var lib = _lib()
    assert_equal(u.strcmp(lib, "same", "same"), 0)
    assert_true(u.strcmp(lib, "apple", "banana") < 0)
    assert_true(u.strcmp(lib, "banana", "apple") > 0)
    assert_true(u.strcmp(lib, "app", "apple") < 0)


def test_wide_helpers_count_code_points() raises:
    var lib = _lib()
    assert_equal(u.wcslen(lib, "audio"), UInt64(5))
    assert_equal(u.wcslen(lib, "音訊 🎧"), UInt64(4))
    assert_equal(u.wcscmp(lib, "音訊", "音訊"), 0)
    assert_true(u.wcscmp(lib, "a", "b") < 0)
    var copy = u.wcscpy_s(lib, "音訊 🎧", 8)
    assert_true(copy.ok())
    assert_equal(copy.text, "音訊 🎧")
    var small = u.wcscpy_s(lib, "音訊 🎧", 4)
    assert_equal(small.code, u.ERRNO_ERANGE)
    assert_equal(small.text, "")


def test_fopen_reports_whether_a_file_can_be_opened() raises:
    var lib = _lib()
    assert_true(u.can_fopen(lib, "pixi.toml"))
    assert_false(u.can_fopen(lib, "build/not_a_real_file.bin"))
    assert_equal(u.fopen_result(lib, "build/not_a_real_file.bin"), MA_DOES_NOT_EXIST)
    assert_equal(u.fopen_result(lib, "pixi.toml"), MA_SUCCESS)
    var path = "build/crt_util_api_probe.tmp"
    assert_true(u.can_fopen(lib, path, "wb"))  # creates it
    assert_true(u.can_fopen(lib, path, "rb"))
    remove(path)
    assert_false(u.can_fopen(lib, path, "rb"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
