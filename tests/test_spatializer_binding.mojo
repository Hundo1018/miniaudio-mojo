"""TDD contract tests for the spatializer BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a listener and a spatializer are pure
DSP objects. All 57 MA_API ma_spatializer / ma_spatializer_listener functions
are exercised here (positive and negative paths).

Gain changes are smoothed by miniaudio's ma_gainer, and in the vendored
0.11.25 that ramp overshoots the target for the whole first block after a
change (the smoothing frame count underflows). Every loudness comparison below
therefore runs one warm-up block and measures the second, which is settled.

A stereo listener's default output map is SIDE_LEFT / SIDE_RIGHT, not
FRONT_LEFT / FRONT_RIGHT: miniaudio picks side speakers so a hard pan reaches
full left or right.
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.spatializer_raw as raw


comptime MONO: UInt32 = 1
comptime STEREO: UInt32 = 2
comptime FRAMES: Int = 1024
comptime ATTENUATION_NONE: UInt32 = 0
comptime ATTENUATION_INVERSE: UInt32 = 1
comptime ATTENUATION_LINEAR: UInt32 = 2
comptime POSITIONING_ABSOLUTE: UInt32 = 0
comptime POSITIONING_RELATIVE: UInt32 = 1
comptime CHANNEL_SIDE_LEFT: UInt8 = 11
comptime CHANNEL_SIDE_RIGHT: UInt8 = 12


def _lib() raises -> MaLib:
    return MaLib.default()


def _ones(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(1))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _listener(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var l = raw.spatializer_listener_alloc(lib)
    assert_true(l != null_handle())
    assert_equal(raw.spatializer_listener_init(lib, l, STEREO), MA_SUCCESS)
    return l


def _source(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var s = raw.spatializer_alloc(lib)
    assert_true(s != null_handle())
    assert_equal(raw.spatializer_init(lib, s, MONO, STEREO), MA_SUCCESS)
    return s


def _tail(
    lib: MaLib,
    s: OpaquePointer[MutUntrackedOrigin],
    l: OpaquePointer[MutUntrackedOrigin],
) raises -> List[Float32]:
    """Process mono ones twice (warm-up, then settled); return the last frame (L, R)."""
    var out = _sink(FRAMES * 2)
    assert_equal(
        raw.spatializer_process(lib, s, l, out, _ones(FRAMES), UInt64(FRAMES)),
        MA_SUCCESS,
    )
    assert_equal(
        raw.spatializer_process(lib, s, l, out, _ones(FRAMES), UInt64(FRAMES)),
        MA_SUCCESS,
    )
    var last: List[Float32] = [out[FRAMES * 2 - 2], out[FRAMES * 2 - 1]]
    return last^


# ---------------- listener ----------------


def test_listener_heap_size_is_reported_without_initialising() raises:
    var lib = _lib()
    var rc = raw.spatializer_listener_get_heap_size(lib, STEREO)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_listener_starts_with_miniaudio_defaults() raises:
    """Origin, facing -Z, +Y up, 343.3 m/s, enabled, full-circle cone."""
    var lib = _lib()
    var l = _listener(lib)

    var pos = raw.spatializer_listener_get_position(lib, l)
    assert_equal(pos.result, MA_SUCCESS)
    assert_equal(pos.value.x, Float32(0))
    assert_equal(pos.value.z, Float32(0))
    var dir = raw.spatializer_listener_get_direction(lib, l)
    assert_equal(dir.value.z, Float32(-1))
    var up = raw.spatializer_listener_get_world_up(lib, l)
    assert_equal(up.result, MA_SUCCESS)
    assert_equal(up.value.y, Float32(1))
    var speed = raw.spatializer_listener_get_speed_of_sound(lib, l)
    assert_equal(speed.result, MA_SUCCESS)
    assert_almost_equal(speed.value, Float32(343.3), atol=0.01)
    var enabled = raw.spatializer_listener_is_enabled(lib, l)
    assert_equal(enabled.result, MA_SUCCESS)
    assert_true(enabled.value)
    var cone = raw.spatializer_listener_get_cone(lib, l)
    assert_equal(cone.result, MA_SUCCESS)
    assert_almost_equal(cone.value.inner_angle, Float32(6.283185), atol=0.001)

    raw.spatializer_listener_free(lib, l)


def test_listener_channel_map_is_side_left_side_right() raises:
    var lib = _lib()
    var l = _listener(lib)
    var map = raw.spatializer_listener_get_channel_map(lib, l)
    assert_equal(map.result, MA_SUCCESS)
    assert_equal(len(map.value), 2)
    assert_equal(map.value[0], CHANNEL_SIDE_LEFT)
    assert_equal(map.value[1], CHANNEL_SIDE_RIGHT)
    raw.spatializer_listener_free(lib, l)


def test_listener_setters_round_trip() raises:
    var lib = _lib()
    var l = _listener(lib)

    assert_equal(
        raw.spatializer_listener_set_position(lib, l, 1.0, 2.0, 3.0), MA_SUCCESS
    )
    var pos = raw.spatializer_listener_get_position(lib, l).value.copy()
    assert_equal(pos.x, Float32(1.0))
    assert_equal(pos.y, Float32(2.0))
    assert_equal(pos.z, Float32(3.0))

    assert_equal(
        raw.spatializer_listener_set_direction(lib, l, 1.0, 0.0, 0.0), MA_SUCCESS
    )
    assert_equal(raw.spatializer_listener_get_direction(lib, l).value.x, Float32(1.0))

    assert_equal(
        raw.spatializer_listener_set_velocity(lib, l, 0.0, 0.0, 4.0), MA_SUCCESS
    )
    var vel = raw.spatializer_listener_get_velocity(lib, l)
    assert_equal(vel.result, MA_SUCCESS)
    assert_equal(vel.value.z, Float32(4.0))

    assert_equal(
        raw.spatializer_listener_set_world_up(lib, l, 0.0, 0.0, 1.0), MA_SUCCESS
    )
    assert_equal(raw.spatializer_listener_get_world_up(lib, l).value.z, Float32(1.0))

    assert_equal(
        raw.spatializer_listener_set_speed_of_sound(lib, l, 300.0), MA_SUCCESS
    )
    assert_equal(
        raw.spatializer_listener_get_speed_of_sound(lib, l).value, Float32(300.0)
    )

    assert_equal(raw.spatializer_listener_set_cone(lib, l, 1.0, 2.0, 0.5), MA_SUCCESS)
    var cone = raw.spatializer_listener_get_cone(lib, l).value.copy()
    assert_equal(cone.inner_angle, Float32(1.0))
    assert_equal(cone.outer_angle, Float32(2.0))
    assert_equal(cone.outer_gain, Float32(0.5))

    assert_equal(raw.spatializer_listener_set_enabled(lib, l, False), MA_SUCCESS)
    assert_true(not raw.spatializer_listener_is_enabled(lib, l).value)

    raw.spatializer_listener_free(lib, l)


def test_listener_preallocated_init_behaves_like_the_managed_one() raises:
    var lib = _lib()
    var l = raw.spatializer_listener_alloc(lib)
    assert_equal(raw.spatializer_listener_init_preallocated(lib, l, STEREO), MA_SUCCESS)
    var map = raw.spatializer_listener_get_channel_map(lib, l)
    assert_equal(map.result, MA_SUCCESS)
    assert_equal(len(map.value), 2)
    assert_equal(raw.spatializer_listener_uninit(lib, l), MA_SUCCESS)
    # After uninit the handle is empty again.
    assert_equal(raw.spatializer_listener_get_position(lib, l).result, MA_INVALID_ARGS)
    raw.spatializer_listener_free(lib, l)


def test_listener_operations_on_an_uninitialised_handle_are_invalid() raises:
    var lib = _lib()
    var l = raw.spatializer_listener_alloc(lib)

    assert_equal(raw.spatializer_listener_get_channel_map(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_cone(lib, l, 1.0, 1.0, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_get_cone(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_position(lib, l, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_get_position(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_direction(lib, l, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_get_direction(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_velocity(lib, l, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_get_velocity(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_speed_of_sound(lib, l, 1.0), MA_INVALID_ARGS)
    assert_equal(
        raw.spatializer_listener_get_speed_of_sound(lib, l).result, MA_INVALID_ARGS
    )
    assert_equal(raw.spatializer_listener_set_world_up(lib, l, 0, 1, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_get_world_up(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_set_enabled(lib, l, True), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_is_enabled(lib, l).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_uninit(lib, l), MA_SUCCESS)
    raw.spatializer_listener_free(lib, l)

    assert_equal(raw.spatializer_listener_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_listener_init(lib, null_handle(), STEREO), MA_INVALID_ARGS)
    assert_equal(
        raw.spatializer_listener_init_preallocated(lib, null_handle(), STEREO),
        MA_INVALID_ARGS,
    )
    raw.spatializer_listener_free(lib, null_handle())


def test_listener_rejects_zero_output_channels() raises:
    var lib = _lib()
    var l = raw.spatializer_listener_alloc(lib)
    assert_true(raw.spatializer_listener_init(lib, l, UInt32(0)) != MA_SUCCESS)
    assert_true(raw.spatializer_listener_get_heap_size(lib, UInt32(0)).result != MA_SUCCESS)
    raw.spatializer_listener_free(lib, l)


# ---------------- spatializer ----------------


def test_spatializer_heap_size_is_reported_without_initialising() raises:
    var lib = _lib()
    var rc = raw.spatializer_get_heap_size(lib, MONO, STEREO)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_spatializer_starts_with_miniaudio_defaults() raises:
    var lib = _lib()
    var s = _source(lib)

    assert_equal(raw.spatializer_get_input_channels(lib, s).value, MONO)
    assert_equal(raw.spatializer_get_output_channels(lib, s).value, STEREO)
    var model = raw.spatializer_get_attenuation_model(lib, s)
    assert_equal(model.result, MA_SUCCESS)
    assert_equal(model.value, ATTENUATION_INVERSE)
    var positioning = raw.spatializer_get_positioning(lib, s)
    assert_equal(positioning.result, MA_SUCCESS)
    assert_equal(positioning.value, POSITIONING_ABSOLUTE)
    assert_equal(raw.spatializer_get_rolloff(lib, s).value, Float32(1))
    assert_equal(raw.spatializer_get_min_gain(lib, s).value, Float32(0))
    assert_equal(raw.spatializer_get_max_gain(lib, s).value, Float32(1))
    assert_equal(raw.spatializer_get_min_distance(lib, s).value, Float32(1))
    assert_true(raw.spatializer_get_max_distance(lib, s).value > Float32(1e30))
    assert_equal(raw.spatializer_get_doppler_factor(lib, s).value, Float32(1))
    assert_equal(
        raw.spatializer_get_directional_attenuation_factor(lib, s).value, Float32(1)
    )
    var vol = raw.spatializer_get_master_volume(lib, s)
    assert_equal(vol.result, MA_SUCCESS)
    assert_equal(vol.value, Float32(1))

    raw.spatializer_free(lib, s)


def test_spatializer_setters_round_trip() raises:
    var lib = _lib()
    var s = _source(lib)

    assert_equal(raw.spatializer_set_master_volume(lib, s, 0.5), MA_SUCCESS)
    assert_equal(raw.spatializer_get_master_volume(lib, s).value, Float32(0.5))
    assert_equal(
        raw.spatializer_set_attenuation_model(lib, s, ATTENUATION_LINEAR), MA_SUCCESS
    )
    assert_equal(raw.spatializer_get_attenuation_model(lib, s).value, ATTENUATION_LINEAR)
    assert_equal(
        raw.spatializer_set_positioning(lib, s, POSITIONING_RELATIVE), MA_SUCCESS
    )
    assert_equal(raw.spatializer_get_positioning(lib, s).value, POSITIONING_RELATIVE)
    assert_equal(raw.spatializer_set_rolloff(lib, s, 2.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_rolloff(lib, s).value, Float32(2.0))
    assert_equal(raw.spatializer_set_min_gain(lib, s, 0.1), MA_SUCCESS)
    assert_equal(raw.spatializer_get_min_gain(lib, s).value, Float32(0.1))
    assert_equal(raw.spatializer_set_max_gain(lib, s, 0.9), MA_SUCCESS)
    assert_equal(raw.spatializer_get_max_gain(lib, s).value, Float32(0.9))
    assert_equal(raw.spatializer_set_min_distance(lib, s, 2.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_min_distance(lib, s).value, Float32(2.0))
    assert_equal(raw.spatializer_set_max_distance(lib, s, 50.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_max_distance(lib, s).value, Float32(50.0))
    assert_equal(raw.spatializer_set_doppler_factor(lib, s, 0.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_doppler_factor(lib, s).value, Float32(0.0))
    assert_equal(
        raw.spatializer_set_directional_attenuation_factor(lib, s, 0.5), MA_SUCCESS
    )
    assert_equal(
        raw.spatializer_get_directional_attenuation_factor(lib, s).value, Float32(0.5)
    )
    assert_equal(raw.spatializer_set_cone(lib, s, 1.0, 2.0, 0.25), MA_SUCCESS)
    var cone = raw.spatializer_get_cone(lib, s)
    assert_equal(cone.result, MA_SUCCESS)
    assert_equal(cone.value.outer_gain, Float32(0.25))
    assert_equal(raw.spatializer_set_position(lib, s, 1.0, 2.0, 3.0), MA_SUCCESS)
    var pos = raw.spatializer_get_position(lib, s)
    assert_equal(pos.result, MA_SUCCESS)
    assert_equal(pos.value.y, Float32(2.0))
    assert_equal(raw.spatializer_set_direction(lib, s, 0.0, 0.0, 1.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_direction(lib, s).value.z, Float32(1.0))
    assert_equal(raw.spatializer_set_velocity(lib, s, 5.0, 0.0, 0.0), MA_SUCCESS)
    assert_equal(raw.spatializer_get_velocity(lib, s).value.x, Float32(5.0))

    raw.spatializer_free(lib, s)


def test_relative_position_is_measured_from_the_listener() raises:
    """Listener at (1,0,0) facing -Z; source at (1,0,-3) is 3 units straight ahead."""
    var lib = _lib()
    var l = _listener(lib)
    var s = _source(lib)
    _ = raw.spatializer_listener_set_position(lib, l, 1.0, 0.0, 0.0)
    _ = raw.spatializer_set_position(lib, s, 1.0, 0.0, -3.0)

    var rel = raw.spatializer_get_relative_position_and_direction(lib, s, l)
    assert_equal(rel.result, MA_SUCCESS)
    assert_almost_equal(rel.position.x, Float32(0), atol=1e-2)
    assert_almost_equal(rel.position.y, Float32(0), atol=1e-2)
    assert_almost_equal(rel.position.z, Float32(-3), atol=1e-2)

    raw.spatializer_free(lib, s)
    raw.spatializer_listener_free(lib, l)


def test_a_source_on_the_right_is_louder_in_the_right_channel() raises:
    var lib = _lib()
    var l = _listener(lib)
    var s = _source(lib)
    _ = raw.spatializer_set_position(lib, s, 5.0, 0.0, 0.0)

    var frame = _tail(lib, s, l)
    assert_true(frame[1] > frame[0])

    _ = raw.spatializer_set_position(lib, s, -5.0, 0.0, 0.0)
    frame = _tail(lib, s, l)
    assert_true(frame[0] > frame[1])

    raw.spatializer_free(lib, s)
    raw.spatializer_listener_free(lib, l)


def test_inverse_attenuation_follows_distance() raises:
    """Straight ahead at distance 5 with min distance 1: gain 1/(1+4) = 0.2 per ear."""
    var lib = _lib()
    var l = _listener(lib)
    var s = _source(lib)
    _ = raw.spatializer_set_position(lib, s, 0.0, 0.0, -1.0)
    var near = _tail(lib, s, l)
    _ = raw.spatializer_set_position(lib, s, 0.0, 0.0, -5.0)
    var far = _tail(lib, s, l)

    assert_true(far[0] < near[0])
    assert_almost_equal(far[0] / near[0], Float32(0.2), atol=0.01)

    raw.spatializer_free(lib, s)
    raw.spatializer_listener_free(lib, l)


def test_a_disabled_listener_hears_silence() raises:
    var lib = _lib()
    var l = _listener(lib)
    var s = _source(lib)
    _ = raw.spatializer_set_attenuation_model(lib, s, ATTENUATION_NONE)
    var on = _tail(lib, s, l)
    assert_true(on[0] > Float32(0))

    _ = raw.spatializer_listener_set_enabled(lib, l, False)
    var off = _tail(lib, s, l)
    assert_equal(off[0], Float32(0))
    assert_equal(off[1], Float32(0))

    raw.spatializer_free(lib, s)
    raw.spatializer_listener_free(lib, l)


def test_preallocated_init_matches_the_managed_one() raises:
    var lib = _lib()
    var l = _listener(lib)
    var managed = _source(lib)
    var prealloc = raw.spatializer_alloc(lib)
    assert_equal(raw.spatializer_init_preallocated(lib, prealloc, MONO, STEREO), MA_SUCCESS)
    _ = raw.spatializer_set_position(lib, managed, 3.0, 0.0, -2.0)
    _ = raw.spatializer_set_position(lib, prealloc, 3.0, 0.0, -2.0)

    var a = _tail(lib, managed, l)
    var b = _tail(lib, prealloc, l)
    assert_equal(a[0], b[0])
    assert_equal(a[1], b[1])

    raw.spatializer_free(lib, managed)
    raw.spatializer_free(lib, prealloc)
    raw.spatializer_listener_free(lib, l)


def test_spatializer_operations_on_an_uninitialised_handle_are_invalid() raises:
    var lib = _lib()
    var l = _listener(lib)
    var s = raw.spatializer_alloc(lib)
    var out = _sink(8)

    assert_equal(
        raw.spatializer_process(lib, s, l, out, _ones(4), UInt64(4)), MA_INVALID_ARGS
    )
    assert_equal(raw.spatializer_set_master_volume(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_master_volume(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_input_channels(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_output_channels(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_attenuation_model(lib, s, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_attenuation_model(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_positioning(lib, s, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_positioning(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_rolloff(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_rolloff(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_min_gain(lib, s, 0.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_min_gain(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_max_gain(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_max_gain(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_min_distance(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_min_distance(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_max_distance(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_max_distance(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_cone(lib, s, 1.0, 1.0, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_cone(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_doppler_factor(lib, s, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_doppler_factor(lib, s).result, MA_INVALID_ARGS)
    assert_equal(
        raw.spatializer_set_directional_attenuation_factor(lib, s, 1.0), MA_INVALID_ARGS
    )
    assert_equal(
        raw.spatializer_get_directional_attenuation_factor(lib, s).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.spatializer_set_position(lib, s, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_position(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_direction(lib, s, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_direction(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.spatializer_set_velocity(lib, s, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_get_velocity(lib, s).result, MA_INVALID_ARGS)
    assert_equal(
        raw.spatializer_get_relative_position_and_direction(lib, s, l).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.spatializer_uninit(lib, s), MA_SUCCESS)
    raw.spatializer_free(lib, s)

    # An initialised source with an unusable listener is rejected too.
    var ready = _source(lib)
    assert_equal(
        raw.spatializer_process(lib, ready, null_handle(), out, _ones(4), UInt64(4)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.spatializer_get_relative_position_and_direction(
            lib, ready, null_handle()
        ).result,
        MA_INVALID_ARGS,
    )
    raw.spatializer_free(lib, ready)
    raw.spatializer_listener_free(lib, l)

    assert_equal(raw.spatializer_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.spatializer_init(lib, null_handle(), MONO, STEREO), MA_INVALID_ARGS)
    assert_equal(
        raw.spatializer_init_preallocated(lib, null_handle(), MONO, STEREO),
        MA_INVALID_ARGS,
    )
    raw.spatializer_free(lib, null_handle())


def test_spatializer_rejects_zero_channels() raises:
    var lib = _lib()
    var s = raw.spatializer_alloc(lib)
    assert_true(raw.spatializer_init(lib, s, UInt32(0), STEREO) != MA_SUCCESS)
    assert_true(raw.spatializer_get_heap_size(lib, MONO, UInt32(0)).result != MA_SUCCESS)
    raw.spatializer_free(lib, s)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
