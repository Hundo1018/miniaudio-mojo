"""TDD contract tests for the vec3f BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: ma_vec3f is plain float math, and
ma_atomic_vec3f is a vector behind a spinlock. All 12 MA_API vec3f functions
are exercised (positive and negative). Vectors cross the ABI as three floats.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
from miniaudio._ffi.sound_raw import Vec3
import miniaudio._ffi.vec3f_raw as raw


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_3f_round_trips_the_components() raises:
    var lib = _lib()
    var rc = raw.vec3f_init_3f(lib, 1.5, -2.0, 3.25)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value.x, Float32(1.5))
    assert_equal(rc.value.y, Float32(-2.0))
    assert_equal(rc.value.z, Float32(3.25))


def test_sub_is_componentwise() raises:
    var lib = _lib()
    var rc = raw.vec3f_sub(lib, Vec3(3, 2, 1), Vec3(1, 1, 1))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value.x, Float32(2.0))
    assert_equal(rc.value.y, Float32(1.0))
    assert_equal(rc.value.z, Float32(0.0))


def test_neg_flips_every_sign() raises:
    var lib = _lib()
    var rc = raw.vec3f_neg(lib, Vec3(1, -2, 0))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value.x, Float32(-1.0))
    assert_equal(rc.value.y, Float32(2.0))
    assert_equal(rc.value.z, Float32(-0.0))


def test_dot_product() raises:
    var lib = _lib()
    var rc = raw.vec3f_dot(lib, Vec3(1, 2, 3), Vec3(4, 5, 6))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, Float32(32.0))
    assert_equal(raw.vec3f_dot(lib, Vec3(1, 0, 0), Vec3(0, 1, 0)).value, Float32(0.0))


def test_cross_product_follows_the_right_hand_rule() raises:
    var lib = _lib()
    var xy = raw.vec3f_cross(lib, Vec3(1, 0, 0), Vec3(0, 1, 0))
    assert_equal(xy.result, MA_SUCCESS)
    assert_equal(xy.value.z, Float32(1.0))
    assert_equal(xy.value.x, Float32(0.0))
    var yx = raw.vec3f_cross(lib, Vec3(0, 1, 0), Vec3(1, 0, 0))
    assert_equal(yx.value.z, Float32(-1.0))


def test_len2_and_len() raises:
    var lib = _lib()
    var sq = raw.vec3f_len2(lib, Vec3(2, 3, 6))
    assert_equal(sq.result, MA_SUCCESS)
    assert_equal(sq.value, Float32(49.0))
    var l = raw.vec3f_len(lib, Vec3(2, 3, 6))
    assert_equal(l.result, MA_SUCCESS)
    assert_equal(l.value, Float32(7.0))
    assert_equal(raw.vec3f_len(lib, Vec3(0, 0, 0)).value, Float32(0.0))


def test_dist_is_the_length_of_the_difference() raises:
    var lib = _lib()
    var rc = raw.vec3f_dist(lib, Vec3(1, 1, 1), Vec3(4, 5, 1))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, Float32(5.0))
    assert_equal(raw.vec3f_dist(lib, Vec3(2, 2, 2), Vec3(2, 2, 2)).value, Float32(0.0))


def test_normalize_gives_a_near_unit_vector() raises:
    """Normalising uses a fast reciprocal sqrt, so unit length is approximate."""
    var lib = _lib()
    var rc = raw.vec3f_normalize(lib, Vec3(3, 0, 4))
    assert_equal(rc.result, MA_SUCCESS)
    assert_almost_equal(rc.value.x, Float32(0.6), atol=0.001)
    assert_equal(rc.value.y, Float32(0.0))
    assert_almost_equal(rc.value.z, Float32(0.8), atol=0.001)


def test_normalize_zero_stays_zero() raises:
    var lib = _lib()
    var rc = raw.vec3f_normalize(lib, Vec3(0, 0, 0))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value.x, Float32(0.0))
    assert_equal(rc.value.y, Float32(0.0))
    assert_equal(rc.value.z, Float32(0.0))


def test_atomic_set_get_round_trip() raises:
    var lib = _lib()
    var h = raw.atomic_vec3f_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.atomic_vec3f_init(lib, h, Vec3(1, 2, 3)), MA_SUCCESS)
    var first = raw.atomic_vec3f_get(lib, h)
    assert_equal(first.result, MA_SUCCESS)
    assert_equal(first.value.x, Float32(1.0))
    assert_equal(first.value.y, Float32(2.0))
    assert_equal(first.value.z, Float32(3.0))
    assert_equal(raw.atomic_vec3f_set(lib, h, Vec3(-4, 5, -6)), MA_SUCCESS)
    var second = raw.atomic_vec3f_get(lib, h)
    assert_equal(second.value.x, Float32(-4.0))
    assert_equal(second.value.y, Float32(5.0))
    assert_equal(second.value.z, Float32(-6.0))
    assert_equal(raw.atomic_vec3f_init(lib, h, Vec3(9, 9, 9)), MA_SUCCESS)  # re-init overwrites
    assert_equal(raw.atomic_vec3f_get(lib, h).value.z, Float32(9.0))
    raw.atomic_vec3f_free(lib, h)


def test_atomic_before_init_is_invalid_args() raises:
    var lib = _lib()
    var h = raw.atomic_vec3f_alloc(lib)
    assert_equal(raw.atomic_vec3f_set(lib, h, Vec3(1, 1, 1)), MA_INVALID_ARGS)
    var rc = raw.atomic_vec3f_get(lib, h)
    assert_equal(rc.result, MA_INVALID_ARGS)
    assert_equal(rc.value.x, Float32(0.0))
    raw.atomic_vec3f_free(lib, h)


def test_atomic_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    assert_equal(raw.atomic_vec3f_init(lib, n, Vec3(1, 1, 1)), MA_INVALID_ARGS)
    assert_equal(raw.atomic_vec3f_set(lib, n, Vec3(1, 1, 1)), MA_INVALID_ARGS)
    assert_equal(raw.atomic_vec3f_get(lib, n).result, MA_INVALID_ARGS)
    raw.atomic_vec3f_free(lib, n)  # freeing NULL is a no-op


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
