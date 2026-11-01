"""MaLib — the single owner of the loaded miniaudio shim (libma_shim.so).

Loaded once and shared via ArcPointer[MaLib] into the high-level wrapper types,
so binding/API methods never thread a `bridge` argument. The library path is
resolved centrally (MINIAUDIO_MOJO_LIB env var, else build/libma_shim.so) rather
than hardcoded at every call site.
"""

from std.ffi import OwnedDLHandle
from std.os.env import getenv

from miniaudio.result import MaResult, MaError


comptime LIB_PATH_ENV = "MINIAUDIO_MOJO_LIB"
comptime DEFAULT_LIB_PATH = "./build/libma_shim.so"


def null_handle() -> OpaquePointer[MutUntrackedOrigin]:
    # Runtime Int(0) selects the unconstrained `unsafe_from_address: Int`
    # overload (the IntLiteral overload rejects a literal 0 as non-nullable).
    return OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(0))


def _open(path: String) raises MaError -> OwnedDLHandle:
    try:
        return OwnedDLHandle(path)
    except e:
        raise MaError(MaResult.DOES_NOT_EXIST, String("cannot load ", path, ": ", e))


struct MaLib(Movable):
    var handle: OwnedDLHandle

    def __init__(out self, var path: String) raises MaError:
        self.handle = _open(path)

    @staticmethod
    def default() raises MaError -> MaLib:
        var path = getenv(LIB_PATH_ENV)
        if path == "":
            path = String(DEFAULT_LIB_PATH)
        return MaLib(path)

    def version(self) raises MaError -> String:
        var raw = self.handle.call[
            "ma_shim_version", OpaquePointer[MutUntrackedOrigin]
        ]()
        if raw == null_handle():
            raise MaError(MaResult.ERROR, "ma_shim_version returned null")
        return String(unsafe_from_utf8_ptr=raw.unsafe_bitcast[UInt8]())

    def result_description(self, result: MaResult) -> String:
        var raw = self.handle.call[
            "ma_shim_result_description", OpaquePointer[MutUntrackedOrigin]
        ](result.code)
        if raw == null_handle():
            return String(result)
        return String(unsafe_from_utf8_ptr=raw.unsafe_bitcast[UInt8]())

    def error(self, action: String, result: MaResult) -> MaError:
        """The MaError for a failed call: `<action>: MA_X - <description> (<code>)`."""
        return MaError(
            result,
            String(
                action, ": ", result, " - ", self.result_description(result), " (", result.code, ")"
            ),
        )

    def check(self, action: String, result: MaResult) raises MaError:
        """Raise `error(action, result)` unless `result` is MA_SUCCESS."""
        if result != MaResult.SUCCESS:
            raise self.error(action, result)
