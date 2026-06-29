"""Binding layer: raw 1:1 wrappers over the sound shim functions.

Mirrors decoder_raw.mojo. A sound is initialised against an engine handle
(resolved C-side via shimint_engine_ptr). Policy-free; all lifecycle/error
policy lives in the API layer (sound.mojo).
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


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
