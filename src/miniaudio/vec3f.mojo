"""Idiomatic 3D vector API (Layer 3).

`Vec3f` is a value type over miniaudio's `ma_vec3f`: every operation is computed
by miniaudio, so the results (including its approximations) are the ones the
spatializer itself sees. `AtomicVec3f` is `ma_atomic_vec3f`, a vector behind a
spinlock that one thread can set while another reads it, with RAII over the
shim handle.

Note (miniaudio 0.11.25): `normalized()` uses a fast reciprocal square root
(`rsqrtss` on x86-64), so the result is unit length only to about 4 decimal
places. The zero vector normalises to the zero vector.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio._ffi.sound_raw import Vec3
import miniaudio._ffi.vec3f_raw as raw


struct Vec3f(Copyable, Movable):
    """A 3-component float vector; arithmetic is miniaudio's."""

    var _lib: ArcPointer[MaLib]
    var x: Float32
    var y: Float32
    var z: Float32

    def __init__(out self, var lib: ArcPointer[MaLib], x: Float32, y: Float32, z: Float32):
        self._lib = lib^
        self.x = x
        self.y = y
        self.z = z

    @staticmethod
    def create(lib: ArcPointer[MaLib], x: Float32, y: Float32, z: Float32) raises -> Self:
        """Builds the vector through ma_vec3f_init_3f."""
        var rc = raw.vec3f_init_3f(lib[], x, y, z)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("vec3f init_3f failed", rc.result))
        return Self(lib.copy(), rc.value.x, rc.value.y, rc.value.z)

    @staticmethod
    def from_raw(lib: ArcPointer[MaLib], v: Vec3) -> Self:
        return Self(lib.copy(), v.x, v.y, v.z)

    def raw_value(self) -> Vec3:
        return Vec3(self.x, self.y, self.z)

    def sub(self, other: Self) raises -> Self:
        var rc = raw.vec3f_sub(self._lib[], self.raw_value(), other.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f sub failed", rc.result))
        return Self.from_raw(self._lib, rc.value)

    def neg(self) raises -> Self:
        var rc = raw.vec3f_neg(self._lib[], self.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f neg failed", rc.result))
        return Self.from_raw(self._lib, rc.value)

    def dot(self, other: Self) raises -> Float32:
        var rc = raw.vec3f_dot(self._lib[], self.raw_value(), other.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f dot failed", rc.result))
        return rc.value

    def cross(self, other: Self) raises -> Self:
        var rc = raw.vec3f_cross(self._lib[], self.raw_value(), other.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f cross failed", rc.result))
        return Self.from_raw(self._lib, rc.value)

    def len2(self) raises -> Float32:
        """The squared length."""
        var rc = raw.vec3f_len2(self._lib[], self.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f len2 failed", rc.result))
        return rc.value

    def length(self) raises -> Float32:
        var rc = raw.vec3f_len(self._lib[], self.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f len failed", rc.result))
        return rc.value

    def dist(self, other: Self) raises -> Float32:
        """The distance to `other`."""
        var rc = raw.vec3f_dist(self._lib[], self.raw_value(), other.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f dist failed", rc.result))
        return rc.value

    def normalized(self) raises -> Self:
        """The unit vector in this direction (approximately; the zero vector stays zero)."""
        var rc = raw.vec3f_normalize(self._lib[], self.raw_value())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("vec3f normalize failed", rc.result))
        return Self.from_raw(self._lib, rc.value)


struct AtomicVec3f(Movable):
    """A vector that can be set and read from different threads (RAII over ma_atomic_vec3f)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib], initial: Vec3f) raises -> Self:
        var ptr = raw.atomic_vec3f_alloc(lib[])
        if ptr == null_handle():
            raise Error("atomic_vec3f_alloc failed (out of memory)")
        var code = raw.atomic_vec3f_init(lib[], ptr, initial.raw_value())
        if code != MA_SUCCESS:
            raw.atomic_vec3f_free(lib[], ptr)
            raise Error(lib[].describe("atomic_vec3f init failed", code))
        return Self(lib.copy(), ptr)

    def set(mut self, value: Vec3f) raises:
        var code = raw.atomic_vec3f_set(self._lib[], self._ptr, value.raw_value())
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("atomic_vec3f set failed", code))

    def get(self) raises -> Vec3f:
        var rc = raw.atomic_vec3f_get(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("atomic_vec3f get failed", rc.result))
        return Vec3f.from_raw(self._lib, rc.value)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.atomic_vec3f_free(self._lib[], self._ptr)
