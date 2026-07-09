"""Binding layer: raw 1:1 wrappers over the engine shim functions.

Mirrors decoder_raw.mojo: thin, policy-free marshalling over the shim. The
engine owns its device internally (no data callback to marshal). All
lifecycle/error policy lives in the API layer (engine.mojo).
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.sound_raw import Vec3, MaCone
from miniaudio._ffi.decoder_raw import MaCount


def engine_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_engine_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def engine_free(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_engine_free", NoneType](eng)


def engine_init(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], use_null_backend: Bool
) -> Int:
    return Int(
        lib.handle.call["ma_shim_engine_init", Int32](
            eng, Int32(1) if use_null_backend else Int32(0)
        )
    )


def engine_uninit(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_engine_uninit", Int32](eng))


def engine_start(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_engine_start", Int32](eng))


def engine_stop(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_engine_stop", Int32](eng))


def engine_play_sound(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], path: String
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_engine_play_sound", Int32](
            eng, path_c.as_bytes().unsafe_ptr()
        )
    )


def engine_get_sample_rate(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_engine_get_sample_rate", UInt32](eng)


def engine_get_channels(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_engine_get_channels", UInt32](eng)


def engine_set_volume(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], volume: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_engine_set_volume", Int32](eng, volume))


def engine_get_volume(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_engine_get_volume", Float32](eng)


def engine_set_gain_db(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], gain_db: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_engine_set_gain_db", Int32](eng, gain_db))


def engine_get_gain_db(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_engine_get_gain_db", Float32](eng)


def engine_play_sound_ex(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], path: String
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_engine_play_sound_ex", Int32](
            eng, path_c.as_bytes().unsafe_ptr()
        )
    )


def engine_read_pcm_frames(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count frames from the engine node graph into `out`.

    Caller pre-sizes `out` (frame_count * channels). Returns
    MaCount(result_code, frames_read).
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_engine_read_pcm_frames", Int32](
            eng, out.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


# ---- global clock ----


def engine_get_time_in_pcm_frames(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_engine_get_time_in_pcm_frames", UInt64](eng)


def engine_get_time_in_milliseconds(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_engine_get_time_in_milliseconds", UInt64](eng)


def engine_set_time_in_pcm_frames(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], global_time: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_engine_set_time_in_pcm_frames", Int32](
            eng, global_time
        )
    )


def engine_set_time_in_milliseconds(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], global_time: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_engine_set_time_in_milliseconds", Int32](
            eng, global_time
        )
    )


# ---- listeners (index-based spatialization) ----


def engine_get_listener_count(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_engine_get_listener_count", UInt32](eng)


def engine_find_closest_listener(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    x: Float32,
    y: Float32,
    z: Float32,
) -> UInt32:
    return lib.handle.call["ma_shim_engine_find_closest_listener", UInt32](
        eng, x, y, z
    )


def engine_listener_set_position(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    x: Float32,
    y: Float32,
    z: Float32,
):
    lib.handle.call["ma_shim_engine_listener_set_position", NoneType](
        eng, index, x, y, z
    )


def engine_listener_get_position(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_engine_listener_get_position", NoneType](
        eng, index, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def engine_listener_set_direction(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    x: Float32,
    y: Float32,
    z: Float32,
):
    lib.handle.call["ma_shim_engine_listener_set_direction", NoneType](
        eng, index, x, y, z
    )


def engine_listener_get_direction(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_engine_listener_get_direction", NoneType](
        eng, index, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def engine_listener_set_velocity(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    x: Float32,
    y: Float32,
    z: Float32,
):
    lib.handle.call["ma_shim_engine_listener_set_velocity", NoneType](
        eng, index, x, y, z
    )


def engine_listener_get_velocity(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_engine_listener_get_velocity", NoneType](
        eng, index, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def engine_listener_set_world_up(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    x: Float32,
    y: Float32,
    z: Float32,
):
    lib.handle.call["ma_shim_engine_listener_set_world_up", NoneType](
        eng, index, x, y, z
    )


def engine_listener_get_world_up(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_engine_listener_get_world_up", NoneType](
        eng, index, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def engine_listener_set_cone(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    inner_angle: Float32,
    outer_angle: Float32,
    outer_gain: Float32,
):
    lib.handle.call["ma_shim_engine_listener_set_cone", NoneType](
        eng, index, inner_angle, outer_angle, outer_gain
    )


def engine_listener_get_cone(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> MaCone:
    var inner = [Float32(0)]
    var outer = [Float32(0)]
    var gain = [Float32(0)]
    lib.handle.call["ma_shim_engine_listener_get_cone", NoneType](
        eng, index, inner.unsafe_ptr(), outer.unsafe_ptr(), gain.unsafe_ptr()
    )
    return MaCone(inner[0], outer[0], gain[0])


def engine_listener_set_enabled(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    index: UInt32,
    enabled: Bool,
):
    lib.handle.call["ma_shim_engine_listener_set_enabled", NoneType](
        eng, index, Int32(1) if enabled else Int32(0)
    )


def engine_listener_is_enabled(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_engine_listener_is_enabled", Int32](eng, index)
    )
