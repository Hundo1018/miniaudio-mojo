"""Binding layer: raw 1:1 wrappers over the device shim functions.

Mirrors decoder_raw.mojo: thin, policy-free marshalling over the shim. The
device's data callback is owned by the C shim and pulls from a decoder handle,
so no Mojo callback crosses the FFI boundary. All lifecycle/error policy lives
in the API layer (device.mojo).
"""

from miniaudio._lib import MaLib


def device_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_device_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def device_free(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_device_free", NoneType](dev)


def device_init_playback_from_decoder(
    lib: MaLib,
    dev: OpaquePointer[MutUntrackedOrigin],
    decoder: OpaquePointer[MutUntrackedOrigin],
    sample_rate_override: UInt32,
    use_null_backend: Bool,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_init_playback_from_decoder", Int32](
            dev,
            decoder,
            sample_rate_override,
            Int32(1) if use_null_backend else Int32(0),
        )
    )


def device_start(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_device_start", Int32](dev))


def device_stop(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_device_stop", Int32](dev))


def device_uninit(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_device_uninit", Int32](dev))


def device_get_channels(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_device_get_channels", UInt32](dev)


def device_get_sample_rate(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> UInt32:
    return lib.handle.call["ma_shim_device_get_sample_rate", UInt32](dev)


def device_get_frames_processed(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> UInt64:
    return lib.handle.call["ma_shim_device_get_frames_processed", UInt64](dev)
