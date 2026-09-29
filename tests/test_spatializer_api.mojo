"""TDD tests for the idiomatic spatializer API (RAII Spatializer + SpatializerListener).

L3 behavioral: a source to the listener's right is louder on the right, distance
attenuates by the inverse model, turning the listener swaps the ears, a
disabled listener hears silence, relative positioning ignores the listener,
the preallocated path renders identically, and the typed getters round-trip.

Every loudness reading runs one warm-up block first: miniaudio 0.11.25's gainer
overshoots for the whole first block after a gain change (see the binding test).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib, Spatializer, SpatializerListener
from miniaudio.sound import (
    ATTENUATION_NONE,
    ATTENUATION_INVERSE,
    ATTENUATION_LINEAR,
    POSITIONING_ABSOLUTE,
    POSITIONING_RELATIVE,
)


comptime FRAMES: Int = 1024


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ones(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(1))
    return out^


def _settled(mut src: Spatializer, ear: SpatializerListener) raises -> List[Float32]:
    """Last stereo frame (L, R) of a second, settled block of mono ones."""
    _ = src.process(ear, _ones(FRAMES))
    var out = src.process(ear, _ones(FRAMES))
    var last: List[Float32] = [out[len(out) - 2], out[len(out) - 1]]
    return last^


def test_process_turns_mono_into_stereo_frames() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    assert_equal(src.input_channels(), UInt32(1))
    assert_equal(src.output_channels(), UInt32(2))
    var out = src.process(ear, _ones(64))
    assert_equal(len(out), 128)


def test_a_source_on_the_right_is_louder_on_the_right() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)

    src.set_position(4.0, 0.0, 0.0)
    var right = _settled(src, ear)
    assert_true(right[1] > right[0])

    src.set_position(-4.0, 0.0, 0.0)
    var left = _settled(src, ear)
    assert_true(left[0] > left[1])


def test_turning_the_listener_around_swaps_the_ears() raises:
    """Facing +Z instead of -Z puts a +X source on the listener's left."""
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    src.set_position(4.0, 0.0, 0.0)

    ear.set_direction(0.0, 0.0, 1.0)
    var frame = _settled(src, ear)
    assert_true(frame[0] > frame[1])


def test_inverse_attenuation_scales_with_distance() raises:
    """Straight ahead, min distance 1: distance 5 gives 1/(1+4) of distance 1."""
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    assert_true(src.attenuation_model() == ATTENUATION_INVERSE)

    src.set_position(0.0, 0.0, -1.0)
    var near = _settled(src, ear)
    src.set_position(0.0, 0.0, -5.0)
    var far = _settled(src, ear)
    assert_almost_equal(far[0] / near[0], Float32(0.2), atol=0.01)

    # With attenuation off, distance no longer matters.
    src.set_attenuation_model(ATTENUATION_NONE)
    var flat = _settled(src, ear)
    assert_true(flat[0] > far[0])


def test_master_volume_scales_the_output() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    src.set_position(0.0, 0.0, -1.0)
    var full = _settled(src, ear)
    src.set_master_volume(0.5)
    assert_equal(src.master_volume(), Float32(0.5))
    var half = _settled(src, ear)
    assert_almost_equal(half[0], full[0] * 0.5, atol=1e-4)


def test_a_disabled_listener_hears_silence() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    src.set_attenuation_model(ATTENUATION_NONE)
    assert_true(ear.is_enabled())

    ear.set_enabled(False)
    assert_true(not ear.is_enabled())
    var out = src.process(ear, _ones(64))
    for i in range(len(out)):
        assert_equal(out[i], Float32(0))


def test_relative_positioning_ignores_where_the_listener_is() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    src.set_position(0.0, 0.0, -2.0)
    ear.set_position(10.0, 0.0, 0.0)

    var absolute = src.relative_to(ear)
    assert_almost_equal(absolute.position.x, Float32(-10.0), atol=1e-2)

    src.set_positioning(POSITIONING_RELATIVE)
    assert_true(src.positioning() == POSITIONING_RELATIVE)
    var relative = src.relative_to(ear)
    assert_equal(relative.position.x, Float32(0.0))
    assert_equal(relative.position.z, Float32(-2.0))
    src.set_positioning(POSITIONING_ABSOLUTE)


def test_preallocated_objects_render_identically() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var ear2 = SpatializerListener.create(lib, preallocated=True)
    var src = Spatializer.create(lib)
    var src2 = Spatializer.create(lib, preallocated=True)
    src.set_position(2.0, 1.0, -3.0)
    src2.set_position(2.0, 1.0, -3.0)

    var a = _settled(src, ear)
    var b = _settled(src2, ear2)
    assert_equal(a[0], b[0])
    assert_equal(a[1], b[1])
    assert_true(Spatializer.heap_size(lib) > UInt64(0))
    assert_true(SpatializerListener.heap_size(lib) > UInt64(0))


def test_listener_properties_round_trip() raises:
    var lib = _lib()
    var ear = SpatializerListener.create(lib)
    var map = ear.channel_map()
    assert_equal(len(map), 2)

    ear.set_position(1.0, 2.0, 3.0)
    assert_equal(ear.position().y, Float32(2.0))
    assert_equal(ear.direction().z, Float32(-1.0))
    ear.set_velocity(0.0, 0.0, -3.0)
    assert_equal(ear.velocity().z, Float32(-3.0))
    ear.set_world_up(0.0, 0.0, 1.0)
    assert_equal(ear.world_up().z, Float32(1.0))
    ear.set_speed_of_sound(340.0)
    assert_equal(ear.speed_of_sound(), Float32(340.0))
    ear.set_cone(1.0, 2.0, 0.5)
    assert_equal(ear.cone().outer_gain, Float32(0.5))


def test_source_properties_round_trip() raises:
    var lib = _lib()
    var src = Spatializer.create(lib, channels_in=UInt32(2), channels_out=UInt32(2))
    assert_equal(src.input_channels(), UInt32(2))

    src.set_attenuation_model(ATTENUATION_LINEAR)
    assert_true(src.attenuation_model() == ATTENUATION_LINEAR)
    src.set_rolloff(2.0)
    assert_equal(src.rolloff(), Float32(2.0))
    src.set_min_gain(0.1)
    assert_equal(src.min_gain(), Float32(0.1))
    src.set_max_gain(0.8)
    assert_equal(src.max_gain(), Float32(0.8))
    src.set_min_distance(2.0)
    assert_equal(src.min_distance(), Float32(2.0))
    src.set_max_distance(40.0)
    assert_equal(src.max_distance(), Float32(40.0))
    src.set_cone(0.5, 1.0, 0.25)
    assert_equal(src.cone().inner_angle, Float32(0.5))
    src.set_doppler_factor(0.5)
    assert_equal(src.doppler_factor(), Float32(0.5))
    src.set_directional_attenuation_factor(0.0)
    assert_equal(src.directional_attenuation_factor(), Float32(0.0))
    src.set_direction(1.0, 0.0, 0.0)
    assert_equal(src.direction().x, Float32(1.0))
    src.set_velocity(0.0, 2.0, 0.0)
    assert_equal(src.velocity().y, Float32(2.0))


def test_invalid_configs_and_use_after_uninit_raise() raises:
    var lib = _lib()
    with assert_raises():
        _ = Spatializer.create(lib, channels_in=UInt32(0))
    with assert_raises():
        _ = SpatializerListener.create(lib, channels_out=UInt32(0))
    with assert_raises():
        _ = Spatializer.heap_size(lib, channels_out=UInt32(0))

    var ear = SpatializerListener.create(lib)
    var src = Spatializer.create(lib)
    src.uninit()
    with assert_raises():
        _ = src.position()
    with assert_raises():
        _ = src.process(ear, _ones(8))

    ear.uninit()
    with assert_raises():
        ear.set_enabled(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
