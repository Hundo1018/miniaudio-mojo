"""ma_result as a Mojo enum, and the typed error the RAII layer raises.

`MaResult` mirrors every value of miniaudio's `ma_result` (vendor/miniaudio/miniaudio.h);
`pixi run check-enum-values` fails if a case is missing or its code differs. The raw
binding layer returns `MaResult`, so a call site reads `if rc != MaResult.SUCCESS` or

    match rc:
        case .SUCCESS: ...
        case .AT_END | .NO_DATA_AVAILABLE: ...
        case _: ...

`MaError` is what every RAII type raises (`raises MaError`): it carries the result, so a
caller can branch on `e.result` instead of parsing the message. Errors that do not come from
miniaudio use the code miniaudio would have used (bad argument -> INVALID_ARGS, wrong state ->
INVALID_OPERATION).
"""

from std.builtin.variadics import TypeList

comptime _RESULT_COUNT = 71
comptime _RESULT_CODES: Array[Int32, _RESULT_COUNT] = [
    0,
    -1,
    -2,
    -3,
    -4,
    -5,
    -6,
    -7,
    -8,
    -9,
    -10,
    -11,
    -12,
    -13,
    -14,
    -15,
    -16,
    -17,
    -18,
    -19,
    -20,
    -21,
    -22,
    -23,
    -24,
    -25,
    -26,
    -27,
    -28,
    -29,
    -30,
    -31,
    -32,
    -33,
    -34,
    -35,
    -36,
    -37,
    -38,
    -39,
    -40,
    -41,
    -42,
    -43,
    -44,
    -45,
    -46,
    -47,
    -48,
    -49,
    -50,
    -51,
    -52,
    -100,
    -200,
    -201,
    -202,
    -203,
    -204,
    -205,
    -206,
    -207,
    -208,
    -300,
    -301,
    -302,
    -303,
    -400,
    -401,
    -402,
    -403,
]
comptime _RESULT_NAMES: Array[StaticString, _RESULT_COUNT] = [
    "MA_SUCCESS",
    "MA_ERROR",
    "MA_INVALID_ARGS",
    "MA_INVALID_OPERATION",
    "MA_OUT_OF_MEMORY",
    "MA_OUT_OF_RANGE",
    "MA_ACCESS_DENIED",
    "MA_DOES_NOT_EXIST",
    "MA_ALREADY_EXISTS",
    "MA_TOO_MANY_OPEN_FILES",
    "MA_INVALID_FILE",
    "MA_TOO_BIG",
    "MA_PATH_TOO_LONG",
    "MA_NAME_TOO_LONG",
    "MA_NOT_DIRECTORY",
    "MA_IS_DIRECTORY",
    "MA_DIRECTORY_NOT_EMPTY",
    "MA_AT_END",
    "MA_NO_SPACE",
    "MA_BUSY",
    "MA_IO_ERROR",
    "MA_INTERRUPT",
    "MA_UNAVAILABLE",
    "MA_ALREADY_IN_USE",
    "MA_BAD_ADDRESS",
    "MA_BAD_SEEK",
    "MA_BAD_PIPE",
    "MA_DEADLOCK",
    "MA_TOO_MANY_LINKS",
    "MA_NOT_IMPLEMENTED",
    "MA_NO_MESSAGE",
    "MA_BAD_MESSAGE",
    "MA_NO_DATA_AVAILABLE",
    "MA_INVALID_DATA",
    "MA_TIMEOUT",
    "MA_NO_NETWORK",
    "MA_NOT_UNIQUE",
    "MA_NOT_SOCKET",
    "MA_NO_ADDRESS",
    "MA_BAD_PROTOCOL",
    "MA_PROTOCOL_UNAVAILABLE",
    "MA_PROTOCOL_NOT_SUPPORTED",
    "MA_PROTOCOL_FAMILY_NOT_SUPPORTED",
    "MA_ADDRESS_FAMILY_NOT_SUPPORTED",
    "MA_SOCKET_NOT_SUPPORTED",
    "MA_CONNECTION_RESET",
    "MA_ALREADY_CONNECTED",
    "MA_NOT_CONNECTED",
    "MA_CONNECTION_REFUSED",
    "MA_NO_HOST",
    "MA_IN_PROGRESS",
    "MA_CANCELLED",
    "MA_MEMORY_ALREADY_MAPPED",
    "MA_CRC_MISMATCH",
    "MA_FORMAT_NOT_SUPPORTED",
    "MA_DEVICE_TYPE_NOT_SUPPORTED",
    "MA_SHARE_MODE_NOT_SUPPORTED",
    "MA_NO_BACKEND",
    "MA_NO_DEVICE",
    "MA_API_NOT_FOUND",
    "MA_INVALID_DEVICE_CONFIG",
    "MA_LOOP",
    "MA_BACKEND_NOT_ENABLED",
    "MA_DEVICE_NOT_INITIALIZED",
    "MA_DEVICE_ALREADY_INITIALIZED",
    "MA_DEVICE_NOT_STARTED",
    "MA_DEVICE_NOT_STOPPED",
    "MA_FAILED_TO_INIT_BACKEND",
    "MA_FAILED_TO_OPEN_BACKEND_DEVICE",
    "MA_FAILED_TO_START_BACKEND_DEVICE",
    "MA_FAILED_TO_STOP_BACKEND_DEVICE",
]


@fieldwise_init
struct MaResult(EnumLike, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A miniaudio result code. Prints as its C name (`MA_AT_END`), or `MA_RESULT(<code>)`
    for a code miniaudio.h does not define."""

    var code: Int32

    comptime SUCCESS = Self(0)
    comptime ERROR = Self(-1)
    comptime INVALID_ARGS = Self(-2)
    comptime INVALID_OPERATION = Self(-3)
    comptime OUT_OF_MEMORY = Self(-4)
    comptime OUT_OF_RANGE = Self(-5)
    comptime ACCESS_DENIED = Self(-6)
    comptime DOES_NOT_EXIST = Self(-7)
    comptime ALREADY_EXISTS = Self(-8)
    comptime TOO_MANY_OPEN_FILES = Self(-9)
    comptime INVALID_FILE = Self(-10)
    comptime TOO_BIG = Self(-11)
    comptime PATH_TOO_LONG = Self(-12)
    comptime NAME_TOO_LONG = Self(-13)
    comptime NOT_DIRECTORY = Self(-14)
    comptime IS_DIRECTORY = Self(-15)
    comptime DIRECTORY_NOT_EMPTY = Self(-16)
    comptime AT_END = Self(-17)
    comptime NO_SPACE = Self(-18)
    comptime BUSY = Self(-19)
    comptime IO_ERROR = Self(-20)
    comptime INTERRUPT = Self(-21)
    comptime UNAVAILABLE = Self(-22)
    comptime ALREADY_IN_USE = Self(-23)
    comptime BAD_ADDRESS = Self(-24)
    comptime BAD_SEEK = Self(-25)
    comptime BAD_PIPE = Self(-26)
    comptime DEADLOCK = Self(-27)
    comptime TOO_MANY_LINKS = Self(-28)
    comptime NOT_IMPLEMENTED = Self(-29)
    comptime NO_MESSAGE = Self(-30)
    comptime BAD_MESSAGE = Self(-31)
    comptime NO_DATA_AVAILABLE = Self(-32)
    comptime INVALID_DATA = Self(-33)
    comptime TIMEOUT = Self(-34)
    comptime NO_NETWORK = Self(-35)
    comptime NOT_UNIQUE = Self(-36)
    comptime NOT_SOCKET = Self(-37)
    comptime NO_ADDRESS = Self(-38)
    comptime BAD_PROTOCOL = Self(-39)
    comptime PROTOCOL_UNAVAILABLE = Self(-40)
    comptime PROTOCOL_NOT_SUPPORTED = Self(-41)
    comptime PROTOCOL_FAMILY_NOT_SUPPORTED = Self(-42)
    comptime ADDRESS_FAMILY_NOT_SUPPORTED = Self(-43)
    comptime SOCKET_NOT_SUPPORTED = Self(-44)
    comptime CONNECTION_RESET = Self(-45)
    comptime ALREADY_CONNECTED = Self(-46)
    comptime NOT_CONNECTED = Self(-47)
    comptime CONNECTION_REFUSED = Self(-48)
    comptime NO_HOST = Self(-49)
    comptime IN_PROGRESS = Self(-50)
    comptime CANCELLED = Self(-51)
    comptime MEMORY_ALREADY_MAPPED = Self(-52)
    comptime CRC_MISMATCH = Self(-100)
    comptime FORMAT_NOT_SUPPORTED = Self(-200)
    comptime DEVICE_TYPE_NOT_SUPPORTED = Self(-201)
    comptime SHARE_MODE_NOT_SUPPORTED = Self(-202)
    comptime NO_BACKEND = Self(-203)
    comptime NO_DEVICE = Self(-204)
    comptime API_NOT_FOUND = Self(-205)
    comptime INVALID_DEVICE_CONFIG = Self(-206)
    comptime LOOP = Self(-207)
    comptime BACKEND_NOT_ENABLED = Self(-208)
    comptime DEVICE_NOT_INITIALIZED = Self(-300)
    comptime DEVICE_ALREADY_INITIALIZED = Self(-301)
    comptime DEVICE_NOT_STARTED = Self(-302)
    comptime DEVICE_NOT_STOPPED = Self(-303)
    comptime FAILED_TO_INIT_BACKEND = Self(-400)
    comptime FAILED_TO_OPEN_BACKEND_DEVICE = Self(-401)
    comptime FAILED_TO_START_BACKEND_DEVICE = Self(-402)
    comptime FAILED_TO_STOP_BACKEND_DEVICE = Self(-403)

    # EnumLike: codes are sparse (0, -1..-52, -100, -200..), so the discriminant is the
    # case's index in _RESULT_CODES. Not exhaustive: a `match` needs a `case _`.
    comptime _enum_case_names = ParameterList.of[
        "SUCCESS".value,
        "ERROR".value,
        "INVALID_ARGS".value,
        "INVALID_OPERATION".value,
        "OUT_OF_MEMORY".value,
        "OUT_OF_RANGE".value,
        "ACCESS_DENIED".value,
        "DOES_NOT_EXIST".value,
        "ALREADY_EXISTS".value,
        "TOO_MANY_OPEN_FILES".value,
        "INVALID_FILE".value,
        "TOO_BIG".value,
        "PATH_TOO_LONG".value,
        "NAME_TOO_LONG".value,
        "NOT_DIRECTORY".value,
        "IS_DIRECTORY".value,
        "DIRECTORY_NOT_EMPTY".value,
        "AT_END".value,
        "NO_SPACE".value,
        "BUSY".value,
        "IO_ERROR".value,
        "INTERRUPT".value,
        "UNAVAILABLE".value,
        "ALREADY_IN_USE".value,
        "BAD_ADDRESS".value,
        "BAD_SEEK".value,
        "BAD_PIPE".value,
        "DEADLOCK".value,
        "TOO_MANY_LINKS".value,
        "NOT_IMPLEMENTED".value,
        "NO_MESSAGE".value,
        "BAD_MESSAGE".value,
        "NO_DATA_AVAILABLE".value,
        "INVALID_DATA".value,
        "TIMEOUT".value,
        "NO_NETWORK".value,
        "NOT_UNIQUE".value,
        "NOT_SOCKET".value,
        "NO_ADDRESS".value,
        "BAD_PROTOCOL".value,
        "PROTOCOL_UNAVAILABLE".value,
        "PROTOCOL_NOT_SUPPORTED".value,
        "PROTOCOL_FAMILY_NOT_SUPPORTED".value,
        "ADDRESS_FAMILY_NOT_SUPPORTED".value,
        "SOCKET_NOT_SUPPORTED".value,
        "CONNECTION_RESET".value,
        "ALREADY_CONNECTED".value,
        "NOT_CONNECTED".value,
        "CONNECTION_REFUSED".value,
        "NO_HOST".value,
        "IN_PROGRESS".value,
        "CANCELLED".value,
        "MEMORY_ALREADY_MAPPED".value,
        "CRC_MISMATCH".value,
        "FORMAT_NOT_SUPPORTED".value,
        "DEVICE_TYPE_NOT_SUPPORTED".value,
        "SHARE_MODE_NOT_SUPPORTED".value,
        "NO_BACKEND".value,
        "NO_DEVICE".value,
        "API_NOT_FOUND".value,
        "INVALID_DEVICE_CONFIG".value,
        "LOOP".value,
        "BACKEND_NOT_ENABLED".value,
        "DEVICE_NOT_INITIALIZED".value,
        "DEVICE_ALREADY_INITIALIZED".value,
        "DEVICE_NOT_STARTED".value,
        "DEVICE_NOT_STOPPED".value,
        "FAILED_TO_INIT_BACKEND".value,
        "FAILED_TO_OPEN_BACKEND_DEVICE".value,
        "FAILED_TO_START_BACKEND_DEVICE".value,
        "FAILED_TO_STOP_BACKEND_DEVICE".value,
    ].values
    comptime _enum_case_types = TypeList.splat[
        ParameterList[Self._enum_case_names].size, NoneType
    ].values
    comptime _enum_is_exhaustive = False

    def __init__(out self, code: Int):
        self.code = Int32(code)

    def _get_enum_discriminant(self) -> Int:
        comptime for i in range(_RESULT_COUNT):
            comptime c = _RESULT_CODES[i]
            if self.code == c:
                return i
        return -1

    def _unsafe_get_enum_payload[
        id: Int
    ](ref self) -> ref[self] TypeList[Trait=AnyType, Self._enum_case_types]()[id]:
        comptime assert False, "MaResult cases have no payload"

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def is_success(self) -> Bool:
        return self.code == 0

    def write_to(self, mut writer: Some[Writer]):
        var index = self._get_enum_discriminant()
        comptime for i in range(_RESULT_COUNT):
            if index == i:
                comptime name = _RESULT_NAMES[i]
                writer.write(name)
                return
        writer.write("MA_RESULT(", self.code, ")")


struct MaError(Copyable, Movable, Writable):
    """The error every RAII type raises. `result` is the miniaudio code; the message reads
    `<action>: MA_X - <miniaudio description> (<code>)` for a failed C call."""

    var result: MaResult
    var message: String

    def __init__(out self, result: MaResult, var message: String):
        self.result = result
        self.message = message^

    @staticmethod
    def invalid_args(var message: String) -> MaError:
        return MaError(MaResult.INVALID_ARGS, message^)

    @staticmethod
    def invalid_operation(var message: String) -> MaError:
        return MaError(MaResult.INVALID_OPERATION, message^)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.message)


# C-style names, one per case, for code that mirrors miniaudio's own spelling.

comptime MA_SUCCESS = MaResult.SUCCESS
comptime MA_ERROR = MaResult.ERROR
comptime MA_INVALID_ARGS = MaResult.INVALID_ARGS
comptime MA_INVALID_OPERATION = MaResult.INVALID_OPERATION
comptime MA_OUT_OF_MEMORY = MaResult.OUT_OF_MEMORY
comptime MA_OUT_OF_RANGE = MaResult.OUT_OF_RANGE
comptime MA_ACCESS_DENIED = MaResult.ACCESS_DENIED
comptime MA_DOES_NOT_EXIST = MaResult.DOES_NOT_EXIST
comptime MA_ALREADY_EXISTS = MaResult.ALREADY_EXISTS
comptime MA_TOO_MANY_OPEN_FILES = MaResult.TOO_MANY_OPEN_FILES
comptime MA_INVALID_FILE = MaResult.INVALID_FILE
comptime MA_TOO_BIG = MaResult.TOO_BIG
comptime MA_PATH_TOO_LONG = MaResult.PATH_TOO_LONG
comptime MA_NAME_TOO_LONG = MaResult.NAME_TOO_LONG
comptime MA_NOT_DIRECTORY = MaResult.NOT_DIRECTORY
comptime MA_IS_DIRECTORY = MaResult.IS_DIRECTORY
comptime MA_DIRECTORY_NOT_EMPTY = MaResult.DIRECTORY_NOT_EMPTY
comptime MA_AT_END = MaResult.AT_END
comptime MA_NO_SPACE = MaResult.NO_SPACE
comptime MA_BUSY = MaResult.BUSY
comptime MA_IO_ERROR = MaResult.IO_ERROR
comptime MA_INTERRUPT = MaResult.INTERRUPT
comptime MA_UNAVAILABLE = MaResult.UNAVAILABLE
comptime MA_ALREADY_IN_USE = MaResult.ALREADY_IN_USE
comptime MA_BAD_ADDRESS = MaResult.BAD_ADDRESS
comptime MA_BAD_SEEK = MaResult.BAD_SEEK
comptime MA_BAD_PIPE = MaResult.BAD_PIPE
comptime MA_DEADLOCK = MaResult.DEADLOCK
comptime MA_TOO_MANY_LINKS = MaResult.TOO_MANY_LINKS
comptime MA_NOT_IMPLEMENTED = MaResult.NOT_IMPLEMENTED
comptime MA_NO_MESSAGE = MaResult.NO_MESSAGE
comptime MA_BAD_MESSAGE = MaResult.BAD_MESSAGE
comptime MA_NO_DATA_AVAILABLE = MaResult.NO_DATA_AVAILABLE
comptime MA_INVALID_DATA = MaResult.INVALID_DATA
comptime MA_TIMEOUT = MaResult.TIMEOUT
comptime MA_NO_NETWORK = MaResult.NO_NETWORK
comptime MA_NOT_UNIQUE = MaResult.NOT_UNIQUE
comptime MA_NOT_SOCKET = MaResult.NOT_SOCKET
comptime MA_NO_ADDRESS = MaResult.NO_ADDRESS
comptime MA_BAD_PROTOCOL = MaResult.BAD_PROTOCOL
comptime MA_PROTOCOL_UNAVAILABLE = MaResult.PROTOCOL_UNAVAILABLE
comptime MA_PROTOCOL_NOT_SUPPORTED = MaResult.PROTOCOL_NOT_SUPPORTED
comptime MA_PROTOCOL_FAMILY_NOT_SUPPORTED = MaResult.PROTOCOL_FAMILY_NOT_SUPPORTED
comptime MA_ADDRESS_FAMILY_NOT_SUPPORTED = MaResult.ADDRESS_FAMILY_NOT_SUPPORTED
comptime MA_SOCKET_NOT_SUPPORTED = MaResult.SOCKET_NOT_SUPPORTED
comptime MA_CONNECTION_RESET = MaResult.CONNECTION_RESET
comptime MA_ALREADY_CONNECTED = MaResult.ALREADY_CONNECTED
comptime MA_NOT_CONNECTED = MaResult.NOT_CONNECTED
comptime MA_CONNECTION_REFUSED = MaResult.CONNECTION_REFUSED
comptime MA_NO_HOST = MaResult.NO_HOST
comptime MA_IN_PROGRESS = MaResult.IN_PROGRESS
comptime MA_CANCELLED = MaResult.CANCELLED
comptime MA_MEMORY_ALREADY_MAPPED = MaResult.MEMORY_ALREADY_MAPPED
comptime MA_CRC_MISMATCH = MaResult.CRC_MISMATCH
comptime MA_FORMAT_NOT_SUPPORTED = MaResult.FORMAT_NOT_SUPPORTED
comptime MA_DEVICE_TYPE_NOT_SUPPORTED = MaResult.DEVICE_TYPE_NOT_SUPPORTED
comptime MA_SHARE_MODE_NOT_SUPPORTED = MaResult.SHARE_MODE_NOT_SUPPORTED
comptime MA_NO_BACKEND = MaResult.NO_BACKEND
comptime MA_NO_DEVICE = MaResult.NO_DEVICE
comptime MA_API_NOT_FOUND = MaResult.API_NOT_FOUND
comptime MA_INVALID_DEVICE_CONFIG = MaResult.INVALID_DEVICE_CONFIG
comptime MA_LOOP = MaResult.LOOP
comptime MA_BACKEND_NOT_ENABLED = MaResult.BACKEND_NOT_ENABLED
comptime MA_DEVICE_NOT_INITIALIZED = MaResult.DEVICE_NOT_INITIALIZED
comptime MA_DEVICE_ALREADY_INITIALIZED = MaResult.DEVICE_ALREADY_INITIALIZED
comptime MA_DEVICE_NOT_STARTED = MaResult.DEVICE_NOT_STARTED
comptime MA_DEVICE_NOT_STOPPED = MaResult.DEVICE_NOT_STOPPED
comptime MA_FAILED_TO_INIT_BACKEND = MaResult.FAILED_TO_INIT_BACKEND
comptime MA_FAILED_TO_OPEN_BACKEND_DEVICE = MaResult.FAILED_TO_OPEN_BACKEND_DEVICE
comptime MA_FAILED_TO_START_BACKEND_DEVICE = MaResult.FAILED_TO_START_BACKEND_DEVICE
comptime MA_FAILED_TO_STOP_BACKEND_DEVICE = MaResult.FAILED_TO_STOP_BACKEND_DEVICE
