"""MaLib — the single owner of the miniaudio shim, shared via ArcPointer[MaLib].

Two link modes, picked at compile time:

- **dynamic** (default): `MaLib.default()` dlopens the shim (MINIAUDIO_MOJO_LIB env var, else
  build/libma_shim.so) and `call` looks each symbol up with dlsym.
- **static** (`mojo build -D MINIAUDIO_LINK=static -Xlinker build/libma_shim.a ...`): `call` is
  `external_call`, so the IR has plain `declare`s that the linker resolves against the shim
  object. Nothing is loaded and no dlopen / dlsym code is emitted, which is what a WebAssembly
  module (no dlopen) needs.

Binding code only ever writes `lib.call["ma_shim_x", R](args...)`, so it is the same in both.
"""

from std.ffi import external_call
from std.os import abort
from std.os.env import getenv
from std.sys.defines import get_defined_string

from miniaudio.result import MaResult, MaError


comptime LIB_PATH_ENV = "MINIAUDIO_MOJO_LIB"
comptime DEFAULT_LIB_PATH = "./build/libma_shim.so"
comptime LINK_MODE = get_defined_string["MINIAUDIO_LINK", "dynamic"]()
comptime LINK_STATIC = LINK_MODE == "static"
comptime _RTLD_NOW = Int32(2)

comptime _Opaque = OpaquePointer[MutUntrackedOrigin]


def null_handle() -> OpaquePointer[MutUntrackedOrigin]:
    # Runtime Int(0) selects the unconstrained `unsafe_from_address: Int`
    # overload (the IntLiteral overload rejects a literal 0 as non-nullable).
    return OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(0))


def _dl_error() -> String:
    var msg = external_call["dlerror", _Opaque]()
    if msg == null_handle():
        return String("unknown dlopen error")
    return String(unsafe_from_utf8_ptr=msg.unsafe_bitcast[UInt8]())


struct MaLib(Movable):
    var _dl: _Opaque  # dlopen handle in dynamic mode; null in static mode

    def __init__(out self, var path: String) raises MaError:
        """Load the shim at `path`. In static mode the shim is already linked in and
        `path` is ignored."""
        comptime if LINK_STATIC:
            self._dl = null_handle()
        else:
            self._dl = external_call["dlopen", _Opaque](
                path.as_c_string_slice().unsafe_ptr(), _RTLD_NOW
            )
            if self._dl == null_handle():
                raise MaError(MaResult.DOES_NOT_EXIST, String("cannot load ", path, ": ", _dl_error()))

    @staticmethod
    def default() raises MaError -> MaLib:
        comptime if LINK_STATIC:
            return MaLib(String(""))
        var path = getenv(LIB_PATH_ENV)
        if path == "":
            path = String(DEFAULT_LIB_PATH)
        return MaLib(path)

    def __del__(deinit self):
        comptime if not LINK_STATIC:
            # Also runs when dlopen failed in __init__ (the field was already set to null).
            if self._dl != null_handle():
                _ = external_call["dlclose", Int32](self._dl)

    def call[
        name: StaticString, R: RegisterPassable = NoneType, *Ts: AnyType
    ](self, *args: *Ts) -> R:
        """Call shim function `name` with C types `args`, returning `R`."""
        comptime if LINK_STATIC:
            return external_call[name, R](*args)
        else:
            var sym = external_call["dlsym", _Opaque](self._dl, name.unsafe_ptr())
            if sym == null_handle():
                abort(String("miniaudio shim has no symbol ", name))
            var f = UnsafePointer(to=sym).unsafe_bitcast[def(*args: *Ts) thin abi("C") -> R]()[]
            return f(*args)

    def version(self) raises MaError -> String:
        var raw = self.call["ma_shim_version", OpaquePointer[MutUntrackedOrigin]]()
        if raw == null_handle():
            raise MaError(MaResult.ERROR, "ma_shim_version returned null")
        return String(unsafe_from_utf8_ptr=raw.unsafe_bitcast[UInt8]())

    def result_description(self, result: MaResult) -> String:
        var raw = self.call[
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
