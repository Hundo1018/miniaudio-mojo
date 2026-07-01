"""Binding layer: raw 1:1 wrappers over the sound shim functions.

Mirrors decoder_raw.mojo. A sound is initialised against an engine handle
(resolved C-side via shimint_engine_ptr). Policy-free; all lifecycle/error
policy lives in the API layer (sound.mojo).
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


@fieldwise_init
struct Vec3(Copyable, Movable):
    """Raw (x, y, z) triple for shim getters returning an ma_vec3f."""

    var x: Float32
    var y: Float32
    var z: Float32


@fieldwise_init
struct MaSeconds(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a float out-param."""

    var result: Int
    var value: Float32


@fieldwise_init
struct MaDataFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) tuple for get_data_format."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


@fieldwise_init
struct MaCone(Copyable, Movable):
    """Raw (inner_angle, outer_angle, outer_gain) triple for get_cone."""

    var inner_angle: Float32
    var outer_angle: Float32
    var outer_gain: Float32


def sound_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_sound_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def sound_free(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_sound_free", NoneType](snd)


def sound_init_from_file(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    path: String,
    flags: UInt32,
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_sound_init_from_file", Int32](
            snd, engine, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def sound_uninit(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_uninit", Int32](snd))


def sound_start(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_start", Int32](snd))


def sound_stop(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_stop", Int32](snd))


def sound_set_volume(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], volume: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_set_volume", Int32](snd, volume))


def sound_get_volume(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_volume", Float32](snd)


def sound_set_pan(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], pan: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_set_pan", Int32](snd, pan))


def sound_get_pan(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_pan", Float32](snd)


def sound_set_pitch(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], pitch: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_sound_set_pitch", Int32](snd, pitch))


def sound_get_pitch(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_pitch", Float32](snd)


def sound_set_looping(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], looping: Bool) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_set_looping", Int32](
            snd, Int32(1) if looping else Int32(0)
        )
    )


def sound_is_looping(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_is_looping", Int32](snd))


def sound_is_playing(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_is_playing", Int32](snd))


def sound_at_end(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_sound_at_end", Int32](snd))


def sound_set_spatialization_enabled(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], enabled: Bool
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_set_spatialization_enabled", Int32](
            snd, Int32(1) if enabled else Int32(0)
        )
    )


def sound_is_spatialization_enabled(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_sound_is_spatialization_enabled", Int32](snd))


def sound_seek_to_pcm_frame(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_seek_to_pcm_frame", Int32](snd, frame_index)
    )


def sound_get_cursor_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_sound_get_cursor_in_pcm_frames", Int32](
            snd, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def sound_get_length_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_sound_get_length_in_pcm_frames", Int32](
            snd, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def sound_seek_to_second(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], seek_point: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_seek_to_second", Int32](snd, seek_point)
    )


def sound_get_cursor_in_seconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> MaSeconds:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_sound_get_cursor_in_seconds", Int32](
            snd, holder.unsafe_ptr()
        )
    )
    return MaSeconds(code, holder[0])


def sound_get_length_in_seconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> MaSeconds:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_sound_get_length_in_seconds", Int32](
            snd, holder.unsafe_ptr()
        )
    )
    return MaSeconds(code, holder[0])


def sound_get_data_format(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> MaDataFormat:
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var sr = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_sound_get_data_format", Int32](
            snd, fmt.unsafe_ptr(), ch.unsafe_ptr(), sr.unsafe_ptr()
        )
    )
    return MaDataFormat(code, Int(fmt[0]), ch[0], sr[0])


# ---- spatialization property accessors ----


def sound_set_position(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_set_position", NoneType](snd, x, y, z)


def sound_get_position(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_get_position", NoneType](
        snd, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_set_direction(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_set_direction", NoneType](snd, x, y, z)


def sound_get_direction(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_get_direction", NoneType](
        snd, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_get_direction_to_listener(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_get_direction_to_listener", NoneType](
        snd, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_set_velocity(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
):
    lib.handle.call["ma_shim_sound_set_velocity", NoneType](snd, x, y, z)


def sound_get_velocity(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Vec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    lib.handle.call["ma_shim_sound_get_velocity", NoneType](
        snd, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
    )
    return Vec3(xs[0], ys[0], zs[0])


def sound_set_attenuation_model(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], model: UInt32
):
    lib.handle.call["ma_shim_sound_set_attenuation_model", NoneType](snd, model)


def sound_get_attenuation_model(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_get_attenuation_model", UInt32](snd)


def sound_set_positioning(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], positioning: UInt32
):
    lib.handle.call["ma_shim_sound_set_positioning", NoneType](snd, positioning)


def sound_get_positioning(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_get_positioning", UInt32](snd)


def sound_set_rolloff(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], rolloff: Float32
):
    lib.handle.call["ma_shim_sound_set_rolloff", NoneType](snd, rolloff)


def sound_get_rolloff(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_rolloff", Float32](snd)


def sound_set_min_gain(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], min_gain: Float32
):
    lib.handle.call["ma_shim_sound_set_min_gain", NoneType](snd, min_gain)


def sound_get_min_gain(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_min_gain", Float32](snd)


def sound_set_max_gain(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], max_gain: Float32
):
    lib.handle.call["ma_shim_sound_set_max_gain", NoneType](snd, max_gain)


def sound_get_max_gain(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> Float32:
    return lib.handle.call["ma_shim_sound_get_max_gain", Float32](snd)


def sound_set_min_distance(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], min_distance: Float32
):
    lib.handle.call["ma_shim_sound_set_min_distance", NoneType](snd, min_distance)


def sound_get_min_distance(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_get_min_distance", Float32](snd)


def sound_set_max_distance(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], max_distance: Float32
):
    lib.handle.call["ma_shim_sound_set_max_distance", NoneType](snd, max_distance)


def sound_get_max_distance(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_get_max_distance", Float32](snd)


def sound_set_cone(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    inner_angle: Float32,
    outer_angle: Float32,
    outer_gain: Float32,
):
    lib.handle.call["ma_shim_sound_set_cone", NoneType](
        snd, inner_angle, outer_angle, outer_gain
    )


def sound_get_cone(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> MaCone:
    var inner = [Float32(0)]
    var outer = [Float32(0)]
    var gain = [Float32(0)]
    lib.handle.call["ma_shim_sound_get_cone", NoneType](
        snd, inner.unsafe_ptr(), outer.unsafe_ptr(), gain.unsafe_ptr()
    )
    return MaCone(inner[0], outer[0], gain[0])


def sound_set_doppler_factor(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], factor: Float32
):
    lib.handle.call["ma_shim_sound_set_doppler_factor", NoneType](snd, factor)


def sound_get_doppler_factor(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_get_doppler_factor", Float32](snd)


def sound_set_directional_attenuation_factor(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], factor: Float32
):
    lib.handle.call["ma_shim_sound_set_directional_attenuation_factor", NoneType](
        snd, factor
    )


def sound_get_directional_attenuation_factor(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call[
        "ma_shim_sound_get_directional_attenuation_factor", Float32
    ](snd)


def sound_set_pan_mode(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], pan_mode: UInt32
):
    lib.handle.call["ma_shim_sound_set_pan_mode", NoneType](snd, pan_mode)


def sound_get_pan_mode(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]) -> UInt32:
    return lib.handle.call["ma_shim_sound_get_pan_mode", UInt32](snd)


def sound_set_pinned_listener_index(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], index: UInt32
):
    lib.handle.call["ma_shim_sound_set_pinned_listener_index", NoneType](snd, index)


def sound_get_pinned_listener_index(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_get_pinned_listener_index", UInt32](snd)


def sound_get_listener_index(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_sound_get_listener_index", UInt32](snd)


# ---- fade ----


def sound_set_fade_in_pcm_frames(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_frames: UInt64,
):
    lib.handle.call["ma_shim_sound_set_fade_in_pcm_frames", NoneType](
        snd, vol_beg, vol_end, len_frames
    )


def sound_set_fade_in_milliseconds(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_ms: UInt64,
):
    lib.handle.call["ma_shim_sound_set_fade_in_milliseconds", NoneType](
        snd, vol_beg, vol_end, len_ms
    )


def sound_set_fade_start_in_pcm_frames(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_frames: UInt64,
    abs_time_frames: UInt64,
):
    lib.handle.call["ma_shim_sound_set_fade_start_in_pcm_frames", NoneType](
        snd, vol_beg, vol_end, len_frames, abs_time_frames
    )


def sound_set_fade_start_in_milliseconds(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    vol_beg: Float32,
    vol_end: Float32,
    len_ms: UInt64,
    abs_time_ms: UInt64,
):
    lib.handle.call["ma_shim_sound_set_fade_start_in_milliseconds", NoneType](
        snd, vol_beg, vol_end, len_ms, abs_time_ms
    )


def sound_get_current_fade_volume(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> Float32:
    return lib.handle.call["ma_shim_sound_get_current_fade_volume", Float32](snd)


def sound_reset_fade(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_sound_reset_fade", NoneType](snd)


# ---- start/stop time scheduling ----


def sound_set_start_time_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_set_start_time_in_pcm_frames", NoneType](
        snd, abs_time
    )


def sound_set_start_time_in_milliseconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_set_start_time_in_milliseconds", NoneType](
        snd, abs_time
    )


def sound_set_stop_time_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_set_stop_time_in_pcm_frames", NoneType](
        snd, abs_time
    )


def sound_set_stop_time_in_milliseconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], abs_time: UInt64
):
    lib.handle.call["ma_shim_sound_set_stop_time_in_milliseconds", NoneType](
        snd, abs_time
    )


def sound_set_stop_time_with_fade_in_pcm_frames(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    stop_time: UInt64,
    fade_len: UInt64,
):
    lib.handle.call["ma_shim_sound_set_stop_time_with_fade_in_pcm_frames", NoneType](
        snd, stop_time, fade_len
    )


def sound_set_stop_time_with_fade_in_milliseconds(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    stop_time: UInt64,
    fade_len: UInt64,
):
    lib.handle.call[
        "ma_shim_sound_set_stop_time_with_fade_in_milliseconds", NoneType
    ](snd, stop_time, fade_len)


def sound_stop_with_fade_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], fade_len: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_stop_with_fade_in_pcm_frames", Int32](
            snd, fade_len
        )
    )


def sound_stop_with_fade_in_milliseconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin], fade_len: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_stop_with_fade_in_milliseconds", Int32](
            snd, fade_len
        )
    )


def sound_reset_start_time(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_sound_reset_start_time", NoneType](snd)


def sound_reset_stop_time(lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_sound_reset_stop_time", NoneType](snd)


def sound_reset_stop_time_and_fade(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
):
    lib.handle.call["ma_shim_sound_reset_stop_time_and_fade", NoneType](snd)


def sound_get_time_in_pcm_frames(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_sound_get_time_in_pcm_frames", UInt64](snd)


def sound_get_time_in_milliseconds(
    lib: MaLib, snd: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_sound_get_time_in_milliseconds", UInt64](snd)


def sound_init_copy(
    lib: MaLib,
    snd: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    existing: OpaquePointer[MutUntrackedOrigin],
    flags: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_sound_init_copy", Int32](
            snd, engine, existing, flags
        )
    )
