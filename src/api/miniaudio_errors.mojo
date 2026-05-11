comptime MA_SUCCESS = Int(0)
comptime MA_INVALID_ARGS = Int(-2)
comptime MA_INVALID_OPERATION = Int(-3)
comptime MA_OUT_OF_MEMORY = Int(-4)
comptime MA_OUT_OF_RANGE = Int(-5)
comptime MA_DOES_NOT_EXIST = Int(-7)
comptime MA_BUSY = Int(-19)
comptime MA_IO_ERROR = Int(-20)
comptime MA_INVALID_DATA = Int(-33)
comptime MA_TIMEOUT = Int(-34)
comptime MA_NO_NETWORK = Int(-35)
comptime MA_NOT_IMPLEMENTED = Int(-29)


def is_success(code: Int) -> Bool:
    return code == MA_SUCCESS


def result_name(code: Int) -> String:
    if code == MA_SUCCESS:
        return "MA_SUCCESS"
    if code == MA_INVALID_ARGS:
        return "MA_INVALID_ARGS"
    if code == MA_OUT_OF_RANGE:
        return "MA_OUT_OF_RANGE"
    if code == MA_OUT_OF_MEMORY:
        return "MA_OUT_OF_MEMORY"
    if code == MA_DOES_NOT_EXIST:
        return "MA_DOES_NOT_EXIST"
    if code == MA_INVALID_DATA:
        return "MA_INVALID_DATA"
    if code == MA_BUSY:
        return "MA_BUSY"
    if code == MA_INVALID_OPERATION:
        return "MA_INVALID_OPERATION"
    if code == MA_NOT_IMPLEMENTED:
        return "MA_NOT_IMPLEMENTED"
    if code == MA_IO_ERROR:
        return "MA_IO_ERROR"
    if code == MA_NO_NETWORK:
        return "MA_NO_NETWORK"
    if code == MA_TIMEOUT:
        return "MA_TIMEOUT"
    return "MA_UNKNOWN"
