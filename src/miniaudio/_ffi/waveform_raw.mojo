"""Binding layer: raw 1:1 wrappers over the waveform shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or MaCount pairs. No lifecycle / error policy; that lives in waveform.mojo.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


comptime WAVEFORM_TYPE_SINE: Int = 0
comptime WAVEFORM_TYPE_SQUARE: Int = 1
comptime WAVEFORM_TYPE_TRIANGLE: Int = 2
comptime WAVEFORM_TYPE_SAWTOOTH: Int = 3


def waveform_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_waveform_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def waveform_free(lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_waveform_free", NoneType](wf)


def waveform_init(
    lib: MaLib,
    wf: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    waveform_type: Int,
    amplitude: Float64,
    frequency: Float64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_waveform_init", Int32](
            wf,
            Int32(format),
            channels,
            sample_rate,
            Int32(waveform_type),
            amplitude,
            frequency,
        )
    )


def waveform_uninit(lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_waveform_uninit", Int32](wf))


def waveform_read_pcm_frames(
    lib: MaLib,
    wf: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count frames into `out` (caller pre-sizes the buffer).

    Returns MaCount(result_code, frames_read).
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_waveform_read_pcm_frames", Int32](
            wf,
            out.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def waveform_seek_to_pcm_frame(
    lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_waveform_seek_to_pcm_frame", Int32](wf, frame_index)
    )


def waveform_set_amplitude(
    lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin], amplitude: Float64
) -> Int:
    return Int(lib.handle.call["ma_shim_waveform_set_amplitude", Int32](wf, amplitude))


def waveform_set_frequency(
    lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin], frequency: Float64
) -> Int:
    return Int(lib.handle.call["ma_shim_waveform_set_frequency", Int32](wf, frequency))


def waveform_set_type(
    lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin], waveform_type: Int
) -> Int:
    return Int(
        lib.handle.call["ma_shim_waveform_set_type", Int32](wf, Int32(waveform_type))
    )


def waveform_set_sample_rate(
    lib: MaLib, wf: OpaquePointer[MutUntrackedOrigin], sample_rate: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_waveform_set_sample_rate", Int32](wf, sample_rate)
    )
