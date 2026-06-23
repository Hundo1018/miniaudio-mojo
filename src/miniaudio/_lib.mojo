"""MaLib — the single owner of the loaded miniaudio shim (libma_shim.so).

Loaded once and shared via ArcPointer[MaLib] into the high-level wrapper types,
so binding/API methods never thread a `bridge` argument. The library path is
resolved centrally (MINIAUDIO_MOJO_LIB env var, else build/libma_shim.so) rather
than hardcoded at every call site.
"""

from std.ffi import OwnedDLHandle
from std.os.env import getenv

from miniaudio.result import result_name


comptime LIB_PATH_ENV = "MINIAUDIO_MOJO_LIB"
comptime DEFAULT_LIB_PATH = "./build/libma_shim.so"


def null_handle() -> OpaquePointer[MutUntrackedOrigin]:
    # Runtime Int(0) selects the unconstrained `unsafe_from_address: Int`
    # overload (the IntLiteral overload rejects a literal 0 as non-nullable).
    return OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(0))


struct MaLib(Movable):
    var handle: OwnedDLHandle

    def __init__(out self, var path: String) raises:
        self.handle = OwnedDLHandle(path)

    @staticmethod
    def default() raises -> MaLib:
        var path = getenv(LIB_PATH_ENV)
        if path == "":
            path = String(DEFAULT_LIB_PATH)
        return MaLib(path)

    def version(self) raises -> String:
        var raw = self.handle.call[
            "ma_shim_version", OpaquePointer[MutUntrackedOrigin]
        ]()
        if raw == null_handle():
            raise Error("ma_shim_version returned null")
        return String(unsafe_from_utf8_ptr=raw.bitcast[UInt8]())

    def result_description(self, code: Int) -> String:
        var raw = self.handle.call[
            "ma_shim_result_description", OpaquePointer[MutUntrackedOrigin]
        ](Int32(code))
        if raw == null_handle():
            return result_name(code)
        return String(unsafe_from_utf8_ptr=raw.bitcast[UInt8]())

    def describe(self, action: String, code: Int) -> String:
        return (
            action
            + ": "
            + result_name(code)
            + " - "
            + self.result_description(code)
            + " ("
            + String(code)
            + ")"
        )
