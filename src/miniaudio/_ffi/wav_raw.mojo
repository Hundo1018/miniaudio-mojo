"""Binding layer: raw 1:1 wrappers over the ma_wav shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in wav.mojo.

`ma_wav` is miniaudio's built-in WAV decoder backend used directly (no
ma_decoder in between), so there is no output conversion: frames come back in
the file's own channel count and sample rate. `preferred_format` is an
ma_format code; 0 keeps the file's native format. The read wrappers take the
caller's pre-sized buffer and pass its byte length so the shim can refuse a
read that would overflow it.

Memory init does not copy: the caller must keep `data` alive until uninit.
"""

from miniaudio._lib import MaLib, null_handle
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.converter_raw import MaChannelMap


@fieldwise_init
struct MaCodecFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) from *_get_data_format."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


def wav_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_wav_alloc", OpaquePointer[MutUntrackedOrigin]]()


def wav_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_wav_free", NoneType](h)


def wav_init_file(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    path: String,
    preferred_format: Int,
    seek_point_count: UInt32,
) -> Int:
    var path_c = path + "\x00"
    return Int(
        lib.handle.call["ma_shim_wav_init_file", Int32](
            h,
            path_c.as_bytes().unsafe_ptr(),
            Int32(preferred_format),
            seek_point_count,
        )
    )


def wav_init_memory(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    data: List[UInt8],
    preferred_format: Int,
    seek_point_count: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_wav_init_memory", Int32](
            h,
            data.unsafe_ptr(),
            len(data),
            Int32(preferred_format),
            seek_point_count,
        )
    )


def wav_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_wav_uninit", Int32](h))


def wav_read_pcm_frames(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count interleaved f32 frames into `out` (pre-sized).

    Only valid while the handle's format is f32. Returns MaCount(result,
    frames_read); frames_read is meaningful for MA_SUCCESS and MA_AT_END.
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_wav_read_pcm_frames", Int32](
            h,
            out.unsafe_ptr(),
            UInt64(len(out) * 4),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def wav_read_pcm_frames_s16(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Int16],
    frame_count: UInt64,
) -> MaCount:
    """As wav_read_pcm_frames, for a handle whose format is s16."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_wav_read_pcm_frames", Int32](
            h,
            out.unsafe_ptr(),
            UInt64(len(out) * 2),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def wav_seek_to_pcm_frame(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(lib.handle.call["ma_shim_wav_seek_to_pcm_frame", Int32](h, frame_index))


def wav_get_data_format(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]
) -> MaCodecFormat:
    var fmt = [Int32(0)]
    var channels = [UInt32(0)]
    var rate = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_wav_get_data_format", Int32](
            h,
            fmt.unsafe_ptr(),
            channels.unsafe_ptr(),
            rate.unsafe_ptr(),
            null_handle(),
            UInt32(0),
        )
    )
    return MaCodecFormat(code, Int(fmt[0]), channels[0], rate[0])


def wav_get_channel_map(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> MaChannelMap:
    """The channel map miniaudio reports for the stream, `capacity` entries long."""
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_wav_get_data_format", Int32](
            h,
            null_handle(),
            null_handle(),
            null_handle(),
            buf.unsafe_ptr(),
            capacity,
        )
    )
    return MaChannelMap(code, buf^)


def wav_get_cursor_in_pcm_frames(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_wav_get_cursor_in_pcm_frames", Int32](
            h, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def wav_get_length_in_pcm_frames(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_wav_get_length_in_pcm_frames", Int32](
            h, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])
