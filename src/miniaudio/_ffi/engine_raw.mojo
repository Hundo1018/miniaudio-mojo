"""Binding layer: raw 1:1 wrappers over the engine shim functions.

Mirrors decoder_raw.mojo: thin, policy-free marshalling over the shim. The
engine owns its device internally (no data callback to marshal). All
lifecycle/error policy lives in the API layer (engine.mojo).
"""

from miniaudio._lib import MaLib


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


def engine_get_time_in_pcm_frames(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_engine_get_time_in_pcm_frames", UInt64](eng)
