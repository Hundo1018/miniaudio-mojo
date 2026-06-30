"""Binding layer: raw 1:1 wrappers over the noise shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or MaCount pairs. No lifecycle / error policy; that lives in noise.mojo.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


comptime NOISE_TYPE_WHITE: Int = 0
comptime NOISE_TYPE_PINK: Int = 1
comptime NOISE_TYPE_BROWNIAN: Int = 2


def noise_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_noise_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def noise_free(lib: MaLib, ns: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_noise_free", NoneType](ns)


def noise_init(
    lib: MaLib,
    ns: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    noise_type: Int,
    seed: Int32,
    amplitude: Float64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_noise_init", Int32](
            ns,
            Int32(format),
            channels,
            Int32(noise_type),
            seed,
            amplitude,
        )
    )


def noise_uninit(lib: MaLib, ns: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_noise_uninit", Int32](ns))


def noise_read_pcm_frames(
    lib: MaLib,
    ns: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_noise_read_pcm_frames", Int32](
            ns,
            out.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def noise_set_amplitude(
    lib: MaLib, ns: OpaquePointer[MutUntrackedOrigin], amplitude: Float64
) -> Int:
    return Int(lib.handle.call["ma_shim_noise_set_amplitude", Int32](ns, amplitude))


def noise_set_seed(
    lib: MaLib, ns: OpaquePointer[MutUntrackedOrigin], seed: Int32
) -> Int:
    return Int(lib.handle.call["ma_shim_noise_set_seed", Int32](ns, seed))


