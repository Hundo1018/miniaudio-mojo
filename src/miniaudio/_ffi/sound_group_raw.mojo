"""Binding layer: raw 1:1 wrappers over the sound_group shim functions.

Mirrors sound_raw.mojo for a mixing-bus group (no file init / seek / cursor).
A group is initialised against an engine handle (resolved C-side). Policy-free.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.sound_raw import Vec3, MaCone


def sound_group_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_sound_group_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def sound_group_free(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_sound_group_free", NoneType](grp)


def sound_group_init(
    lib: MaLib,
    grp: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    flags: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_group_init", Int32](grp, engine, flags)
    )


def sound_group_uninit(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_uninit", Int32](grp))


def sound_group_start(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_start", Int32](grp))


def sound_group_stop(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_stop", Int32](grp))


def sound_group_set_volume(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], volume: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_set_volume", Int32](grp, volume))


def sound_group_get_volume(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_volume", Float32](grp)


def sound_group_set_pan(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], pan: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_set_pan", Int32](grp, pan))


def sound_group_get_pan(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_pan", Float32](grp)


def sound_group_set_pitch(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], pitch: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_set_pitch", Int32](grp, pitch))


def sound_group_get_pitch(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_pitch", Float32](grp)


def sound_group_set_spatialization_enabled(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], enabled: Bool
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_group_set_spatialization_enabled", Int32](
            grp, Int32(1) if enabled else Int32(0)
        )
    )


def sound_group_is_spatialization_enabled(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_is_spatialization_enabled", Int32](grp))


def sound_group_is_playing(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_group_is_playing", Int32](grp))


def sound_group_get_time_in_pcm_frames(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_sound_group_get_time_in_pcm_frames", UInt64](grp)


# ---- spatialization property accessors ----


def sound_group_set_position(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_group_set_position", NoneType](grp, x, y, z)


def sound_group_get_position(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_group_get_position", NoneType](
        grp, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_group_set_direction(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_group_set_direction", NoneType](grp, x, y, z)


def sound_group_get_direction(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_group_get_direction", NoneType](
        grp, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_group_get_direction_to_listener(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_group_get_direction_to_listener", NoneType](
        grp, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_group_set_velocity(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_group_set_velocity", NoneType](grp, x, y, z)


def sound_group_get_velocity(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_group_get_velocity", NoneType](
        grp, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_group_set_attenuation_model(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], model: UInt32
):
    lib.handle.call["ma_shim_sound_group_set_attenuation_model", NoneType](grp, model)


def sound_group_get_attenuation_model(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_group_get_attenuation_model", UInt32](grp)


def sound_group_set_positioning(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], positioning: UInt32
):
    lib.handle.call["ma_shim_sound_group_set_positioning", NoneType](grp, positioning)


def sound_group_get_positioning(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_group_get_positioning", UInt32](grp)


def sound_group_set_rolloff(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], rolloff: Float32
):
    lib.handle.call["ma_shim_sound_group_set_rolloff", NoneType](grp, rolloff)


def sound_group_get_rolloff(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_rolloff", Float32](grp)


def sound_group_set_min_gain(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], min_gain: Float32
):
    lib.handle.call["ma_shim_sound_group_set_min_gain", NoneType](grp, min_gain)


def sound_group_get_min_gain(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_min_gain", Float32](grp)


def sound_group_set_max_gain(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], max_gain: Float32
):
    lib.handle.call["ma_shim_sound_group_set_max_gain", NoneType](grp, max_gain)


def sound_group_get_max_gain(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_max_gain", Float32](grp)


def sound_group_set_min_distance(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], min_distance: Float32
):
    lib.handle.call["ma_shim_sound_group_set_min_distance", NoneType](grp, min_distance)


def sound_group_get_min_distance(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_min_distance", Float32](grp)


def sound_group_set_max_distance(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], max_distance: Float32
):
    lib.handle.call["ma_shim_sound_group_set_max_distance", NoneType](grp, max_distance)


def sound_group_get_max_distance(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_max_distance", Float32](grp)


def sound_group_set_cone(
    lib: MaLib,
    grp: OpaquePointer[MutUntrackedOrigin],
    inner_angle: Float32,
    outer_angle: Float32,
    outer_gain: Float32,
):
    lib.handle.call["ma_shim_sound_group_set_cone", NoneType](
        grp, inner_angle, outer_angle, outer_gain
    )


def sound_group_get_cone(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> MaCone:
    var inner = [Float32(0)]
    var outer = [Float32(0)]
    var gain = [Float32(0)]
    lib.handle.call["ma_shim_sound_group_get_cone", NoneType](
        grp, inner.unsafe_ptr(), outer.unsafe_ptr(), gain.unsafe_ptr()
    )
    return MaCone(inner[0], outer[0], gain[0])


def sound_group_set_doppler_factor(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], factor: Float32
):
    lib.handle.call["ma_shim_sound_group_set_doppler_factor", NoneType](grp, factor)


def sound_group_get_doppler_factor(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_doppler_factor", Float32](grp)


def sound_group_set_directional_attenuation_factor(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], factor: Float32
):
    lib.handle.call["ma_shim_sound_group_set_directional_attenuation_factor", NoneType](
        grp, factor
    )


def sound_group_get_directional_attenuation_factor(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call[
        "ma_shim_sound_group_get_directional_attenuation_factor", Float32
    ](grp)


def sound_group_set_pan_mode(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], pan_mode: UInt32
):
    lib.handle.call["ma_shim_sound_group_set_pan_mode", NoneType](grp, pan_mode)


def sound_group_get_pan_mode(lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]) -> UInt32:
    return lib.handle.call["ma_shim_sound_group_get_pan_mode", UInt32](grp)


def sound_group_set_pinned_listener_index(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], index: UInt32
):
    lib.handle.call["ma_shim_sound_group_set_pinned_listener_index", NoneType](grp, index)


def sound_group_get_pinned_listener_index(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_group_get_pinned_listener_index", UInt32](grp)


def sound_group_get_listener_index(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_group_get_listener_index", UInt32](grp)


# ---- fade ----


def sound_group_set_fade_in_pcm_frames(
    lib: MaLib,
    grp: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_frames: UInt64,
):
    lib.handle.call["ma_shim_sound_group_set_fade_in_pcm_frames", NoneType](
        grp, vol_beg, vol_end, len_frames
    )


def sound_group_set_fade_in_milliseconds(
    lib: MaLib,
    grp: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_ms: UInt64,
):
    lib.handle.call["ma_shim_sound_group_set_fade_in_milliseconds", NoneType](
        grp, vol_beg, vol_end, len_ms
    )


def sound_group_get_current_fade_volume(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_group_get_current_fade_volume", Float32](grp)


# ---- start/stop time scheduling ----


def sound_group_set_start_time_in_pcm_frames(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_group_set_start_time_in_pcm_frames", NoneType](
        grp, abs_time
    )


def sound_group_set_start_time_in_milliseconds(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_group_set_start_time_in_milliseconds", NoneType](
        grp, abs_time
    )


def sound_group_set_stop_time_in_pcm_frames(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_group_set_stop_time_in_pcm_frames", NoneType](
        grp, abs_time
    )


def sound_group_set_stop_time_in_milliseconds(
    lib: MaLib, grp: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_group_set_stop_time_in_milliseconds", NoneType](
        grp, abs_time
    )
