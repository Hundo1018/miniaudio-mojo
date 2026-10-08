"""Binding layer: raw 1:1 wrappers over the ma_vec3f shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in
vec3f.mojo.

miniaudio passes `ma_vec3f` by value, which a C-FFI call cannot do portably,
so each vector crosses the ABI as three floats and comes back through three
out pointers. The vector type itself is the `Vec3` the sound and engine
bindings already return. `ma_atomic_vec3f` (a vector behind a spinlock) is an
opaque shim handle.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.sound_raw import Vec3
from miniaudio._ffi.spatializer_raw import MaFloat, MaVec3


def vec3f_init_3f(lib: MaLib, x: Float32, y: Float32, z: Float32) -> MaVec3:
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_init_3f", Int32](
            x, y, z, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))


def vec3f_sub(lib: MaLib, a: Vec3, b: Vec3) -> MaVec3:
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_sub", Int32](
            a.x, a.y, a.z, b.x, b.y, b.z, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))


def vec3f_neg(lib: MaLib, a: Vec3) -> MaVec3:
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_neg", Int32](
            a.x, a.y, a.z, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))


def vec3f_dot(lib: MaLib, a: Vec3, b: Vec3) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_dot", Int32](
            a.x, a.y, a.z, b.x, b.y, b.z, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def vec3f_cross(lib: MaLib, a: Vec3, b: Vec3) -> MaVec3:
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_cross", Int32](
            a.x, a.y, a.z, b.x, b.y, b.z, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))


def vec3f_len2(lib: MaLib, v: Vec3) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_len2", Int32](v.x, v.y, v.z, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])


def vec3f_len(lib: MaLib, v: Vec3) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_len", Int32](v.x, v.y, v.z, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])


def vec3f_dist(lib: MaLib, a: Vec3, b: Vec3) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_dist", Int32](
            a.x, a.y, a.z, b.x, b.y, b.z, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def vec3f_normalize(lib: MaLib, v: Vec3) -> MaVec3:
    """The zero vector normalises to the zero vector."""
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_vec3f_normalize", Int32](
            v.x, v.y, v.z, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))


# ---- ma_atomic_vec3f --------------------------------------------------------


def atomic_vec3f_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_atomic_vec3f_alloc", OpaquePointer[MutUntrackedOrigin]]()


def atomic_vec3f_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_atomic_vec3f_free", NoneType](h)


def atomic_vec3f_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], v: Vec3) -> Int:
    return Int(lib.handle.call["ma_shim_atomic_vec3f_init", Int32](h, v.x, v.y, v.z))


def atomic_vec3f_set(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], v: Vec3) -> Int:
    return Int(lib.handle.call["ma_shim_atomic_vec3f_set", Int32](h, v.x, v.y, v.z))


def atomic_vec3f_get(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var ox = [Float32(0)]
    var oy = [Float32(0)]
    var oz = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_atomic_vec3f_get", Int32](
            h, ox.unsafe_ptr(), oy.unsafe_ptr(), oz.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(ox[0], oy[0], oz[0]))
