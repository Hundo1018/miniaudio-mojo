"""Tests for MaResult (ma_result as an EnumLike) and the typed MaError.

`pixi run check-enum-values` already proves every case equals miniaudio.h's value and
that no ma_result value is missing. This file covers the Mojo side: the sparse
discriminant drives `match`, printing gives the C name, and RAII types raise a
`MaError` whose `.result` a caller can branch on.
"""

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite

from miniaudio import MaLib, MaResult, MaError
from miniaudio._lib import LINK_STATIC
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_CRC_MISMATCH, MA_FAILED_TO_STOP_BACKEND_DEVICE
from miniaudio.noise import Noise
from miniaudio.frame_util import silent_frames
from miniaudio.decoder import SAMPLE_FORMAT_F32


def _lib() raises MaError -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _kind(result: MaResult) -> String:
    match result:
        case .SUCCESS:
            return "ok"
        case .AT_END | .NO_DATA_AVAILABLE:
            return "drained"
        case .CRC_MISMATCH:
            return "crc"
        case .FAILED_TO_STOP_BACKEND_DEVICE:
            return "last"
        case _:
            return "other"


def test_codes_at_the_gaps() raises:
    # The C enum jumps 0, -1..-52, -100, -200.., -300.., -400..; pin both sides of each jump.
    assert_equal(MaResult.SUCCESS.code, 0)
    assert_equal(MaResult.MEMORY_ALREADY_MAPPED.code, -52)
    assert_equal(MaResult.CRC_MISMATCH.code, -100)
    assert_equal(MaResult.FORMAT_NOT_SUPPORTED.code, -200)
    assert_equal(MaResult.BACKEND_NOT_ENABLED.code, -208)
    assert_equal(MaResult.DEVICE_NOT_INITIALIZED.code, -300)
    assert_equal(MaResult.FAILED_TO_STOP_BACKEND_DEVICE.code, -403)
    assert_equal(MA_AT_END, MaResult.AT_END)
    assert_equal(MaResult(-17), MaResult.AT_END)


def test_match_on_sparse_codes() raises:
    assert_equal(_kind(MA_SUCCESS), "ok")
    assert_equal(_kind(MaResult(-17)), "drained")
    assert_equal(_kind(MaResult.NO_DATA_AVAILABLE), "drained")
    assert_equal(_kind(MA_CRC_MISMATCH), "crc")
    assert_equal(_kind(MA_FAILED_TO_STOP_BACKEND_DEVICE), "last")
    assert_equal(_kind(MaResult.INVALID_ARGS), "other")
    # Codes miniaudio.h does not define (inside a gap, and past the end) take `case _`.
    assert_equal(_kind(MaResult(-60)), "other")
    assert_equal(_kind(MaResult(-999)), "other")
    assert_equal(_kind(MaResult(7)), "other")


def test_prints_c_name() raises:
    assert_equal(String(MaResult.SUCCESS), "MA_SUCCESS")
    assert_equal(String(MaResult.INVALID_ARGS), "MA_INVALID_ARGS")
    assert_equal(String(MaResult.CRC_MISMATCH), "MA_CRC_MISMATCH")
    assert_equal(String(MaResult.FAILED_TO_STOP_BACKEND_DEVICE), "MA_FAILED_TO_STOP_BACKEND_DEVICE")
    assert_equal(String(MaResult(-60)), "MA_RESULT(-60)")


def test_is_success_and_inequality() raises:
    assert_true(MaResult.SUCCESS.is_success())
    assert_false(MaResult.AT_END.is_success())
    assert_true(MaResult.AT_END != MaResult.BUSY)


def test_lib_error_message() raises:
    var lib = _lib()
    var e = lib[].error("probe", MaResult.INVALID_ARGS)
    assert_equal(e.result, MaResult.INVALID_ARGS)
    assert_equal(String(e), "probe: MA_INVALID_ARGS - Invalid argument (-2)")
    lib[].check("probe", MaResult.SUCCESS)
    with assert_raises(contains="probe: MA_BUSY"):
        lib[].check("probe", MaResult.BUSY)


def _result_of_loading(path: String) -> MaResult:
    try:
        _ = MaLib(path)
        return MaResult.SUCCESS
    except e:
        return e.result


def test_missing_library_is_does_not_exist() raises:
    comptime if LINK_STATIC:
        # Statically linked: the shim is already in the binary and the path is ignored.
        assert_equal(_result_of_loading("./build/no_such_library.so"), MaResult.SUCCESS)
    else:
        assert_equal(_result_of_loading("./build/no_such_library.so"), MaResult.DOES_NOT_EXIST)


def _silent_frames_error(lib: ArcPointer[MaLib]) -> MaError:
    try:
        _ = silent_frames(lib, 4, format=SAMPLE_FORMAT_F32, channels=0)
    except e:
        return e^
    return MaError(MaResult.SUCCESS, "did not raise")


def _noise_error(lib: ArcPointer[MaLib]) -> MaError:
    try:
        _ = Noise.create(lib, channels=0)
    except e:
        return e^
    return MaError(MaResult.SUCCESS, "did not raise")


def test_raii_raises_typed_error() raises:
    # Every call in each `try` above raises MaError, so `e` is typed. A wrapper-side
    # validation error carries the code miniaudio would have used...
    var lib = _lib()
    assert_equal(_silent_frames_error(lib).result, MaResult.INVALID_ARGS)
    # ...and a failed C call carries miniaudio's own result.
    var e = _noise_error(lib)
    assert_equal(e.result, MaResult.INVALID_ARGS)
    assert_true("MA_INVALID_ARGS" in String(e), String(e))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
