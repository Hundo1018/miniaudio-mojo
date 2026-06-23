"""miniaudio result codes (subset) and naming.

Mirrors the ma_result values from vendor/miniaudio/miniaudio.h. Human-readable
descriptions are delegated to the shim's ma_shim_result_description (see MaLib).
"""

comptime MA_SUCCESS = Int(0)
comptime MA_INVALID_ARGS = Int(-2)
comptime MA_INVALID_OPERATION = Int(-3)
comptime MA_OUT_OF_MEMORY = Int(-4)
comptime MA_OUT_OF_RANGE = Int(-5)
comptime MA_DOES_NOT_EXIST = Int(-7)
comptime MA_AT_END = Int(-17)
comptime MA_BUSY = Int(-19)
comptime MA_IO_ERROR = Int(-20)
comptime MA_INVALID_DATA = Int(-33)


def result_name(code: Int) -> String:
    if code == MA_SUCCESS:
        return "MA_SUCCESS"
    if code == MA_INVALID_ARGS:
        return "MA_INVALID_ARGS"
    if code == MA_INVALID_OPERATION:
        return "MA_INVALID_OPERATION"
    if code == MA_OUT_OF_MEMORY:
        return "MA_OUT_OF_MEMORY"
    if code == MA_OUT_OF_RANGE:
        return "MA_OUT_OF_RANGE"
    if code == MA_DOES_NOT_EXIST:
        return "MA_DOES_NOT_EXIST"
    if code == MA_AT_END:
        return "MA_AT_END"
    if code == MA_BUSY:
        return "MA_BUSY"
    if code == MA_IO_ERROR:
        return "MA_IO_ERROR"
    if code == MA_INVALID_DATA:
        return "MA_INVALID_DATA"
    return "MA_UNKNOWN(" + String(code) + ")"


def is_success(code: Int) -> Bool:
    return code == MA_SUCCESS
