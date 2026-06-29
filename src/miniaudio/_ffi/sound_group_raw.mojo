"""Binding layer: raw 1:1 wrappers over the sound_group shim functions.

Mirrors sound_raw.mojo for a mixing-bus group (no file init / seek / cursor).
A group is initialised against an engine handle (resolved C-side). Policy-free.
"""

from miniaudio._lib import MaLib


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
