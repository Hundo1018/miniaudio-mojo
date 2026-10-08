"""TDD tests for the idiomatic Vec3f / AtomicVec3f API (L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.vec3f import Vec3f, AtomicVec3f


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_arithmetic_matches_hand_computation() raises:
    var lib = _lib()
    var a = Vec3f.create(lib, 1, 2, 3)
    var b = Vec3f.create(lib, 4, 5, 6)
    var diff = b.sub(a)
    assert_equal(diff.x, Float32(3.0))
    assert_equal(diff.y, Float32(3.0))
    assert_equal(diff.z, Float32(3.0))
    var n = a.neg()
    assert_equal(n.x, Float32(-1.0))
    assert_equal(n.z, Float32(-3.0))
    assert_equal(a.dot(b), Float32(32.0))


def test_cross_is_perpendicular_to_both_inputs() raises:
    var lib = _lib()
    var a = Vec3f.create(lib, 2, -3, 5)
    var b = Vec3f.create(lib, -1, 4, 7)
    var c = a.cross(b)
    assert_equal(c.x, Float32(-41.0))
    assert_equal(c.y, Float32(-19.0))
    assert_equal(c.z, Float32(5.0))
    assert_equal(c.dot(a), Float32(0.0))
    assert_equal(c.dot(b), Float32(0.0))
    # a x b = -(b x a)
    var back = b.cross(a)
    assert_equal(back.x, -c.x)
    assert_equal(back.y, -c.y)
    assert_equal(back.z, -c.z)


def test_length_distance_and_squared_length_agree() raises:
    var lib = _lib()
    var a = Vec3f.create(lib, 1, 1, 1)
    var b = Vec3f.create(lib, 4, 5, 1)
    assert_equal(a.dist(b), Float32(5.0))
    assert_equal(a.sub(b).length(), a.dist(b))
    assert_equal(a.dist(a), Float32(0.0))
    var v = Vec3f.create(lib, 2, 3, 6)
    assert_equal(v.len2(), Float32(49.0))
    assert_equal(v.length(), Float32(7.0))
    assert_equal(v.dot(v), v.len2())


def test_normalized_is_close_to_unit_length_and_keeps_direction() raises:
    var lib = _lib()
    var v = Vec3f.create(lib, 10, -20, 20)
    var u = v.normalized()
    assert_almost_equal(u.length(), Float32(1.0), atol=0.001)
    assert_almost_equal(u.x, Float32(1.0 / 3.0), atol=0.001)
    assert_almost_equal(u.y, Float32(-2.0 / 3.0), atol=0.001)
    assert_almost_equal(u.z, Float32(2.0 / 3.0), atol=0.001)
    assert_almost_equal(u.dot(v) / v.length(), Float32(1.0), atol=0.001)  # parallel to v


def test_zero_vector_normalizes_to_zero() raises:
    var lib = _lib()
    var z = Vec3f.create(lib, 0, 0, 0).normalized()
    assert_equal(z.x, Float32(0.0))
    assert_equal(z.y, Float32(0.0))
    assert_equal(z.z, Float32(0.0))


def test_atomic_vector_holds_the_last_value_set() raises:
    var lib = _lib()
    var at = AtomicVec3f.create(lib, Vec3f.create(lib, 1, 2, 3))
    var first = at.get()
    assert_equal(first.x, Float32(1.0))
    assert_equal(first.z, Float32(3.0))
    for i in range(1, 101):
        at.set(Vec3f.create(lib, Float32(i), Float32(i), Float32(i)))
    var last = at.get()
    assert_equal(last.x, Float32(100.0))
    assert_equal(last.y, Float32(100.0))
    assert_equal(last.z, Float32(100.0))
    # The stored value is independent of the vector it was built from.
    var source = Vec3f.create(lib, 7, 8, 9)
    at.set(source)
    assert_equal(at.get().y, Float32(8.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
