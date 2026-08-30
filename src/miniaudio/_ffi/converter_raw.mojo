"""Binding layer: raw 1:1 wrappers over the converter shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
converter.mojo.

Three families share this module because they share a shape — `ma_resampler`
(rate), `ma_channel_converter` (channel count / map) and `ma_data_converter`
(all of it in one pipeline). Each has an `init` path where miniaudio owns its
working heap and an `init_preallocated` path where the shim owns it.

`process` passes the input and output frame counts by reference on the
resampler and the data converter: they go in as requests and come back as the
amounts actually consumed and produced. The channel converter converts a fixed
frame count instead.

Frames are f32 here, matching the format the tests use; the shim takes a
ma_format code and is format-agnostic.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount


@fieldwise_init
struct MaProcess(Copyable, Movable):
    """Raw (result_code, frames consumed, frames produced) triple for process."""

    var result: Int
    var frames_in: UInt64
    var frames_out: UInt64


@fieldwise_init
struct MaChannelMap(Movable):
    """Raw (result_code, channel map) pair for the channel-map getters."""

    var result: Int
    var value: List[UInt8]


# ================= ma_resampler =================


def resampler_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_resampler_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def resampler_free(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_resampler_free", NoneType](rs)


def resampler_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
    algorithm: Int,
) -> MaCount:
    """Working-heap size for this configuration, without initialising anything."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_resampler_get_heap_size", Int32](
            Int32(format),
            channels,
            sample_rate_in,
            sample_rate_out,
            Int32(algorithm),
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def resampler_init(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
    algorithm: Int,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_resampler_init", Int32](
            rs,
            Int32(format),
            channels,
            sample_rate_in,
            sample_rate_out,
            Int32(algorithm),
        )
    )


def resampler_init_preallocated(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
    algorithm: Int,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_resampler_init_preallocated", Int32](
            rs,
            Int32(format),
            channels,
            sample_rate_in,
            sample_rate_out,
            Int32(algorithm),
        )
    )


def resampler_uninit(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_resampler_uninit", Int32](rs))


def resampler_process(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    frame_count_in: UInt64,
    mut dst: List[Float32],
    frame_count_out: UInt64,
) -> MaProcess:
    """Converts up to frame_count_in frames into at most frame_count_out frames."""
    var in_holder = [frame_count_in]
    var out_holder = [frame_count_out]
    var code = Int(
        lib.handle.call["ma_shim_resampler_process", Int32](
            rs,
            src.unsafe_ptr(),
            in_holder.unsafe_ptr(),
            dst.unsafe_ptr(),
            out_holder.unsafe_ptr(),
        )
    )
    return MaProcess(code, in_holder[0], out_holder[0])


def resampler_set_rate(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    rate_in: UInt32,
    rate_out: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_resampler_set_rate", Int32](rs, rate_in, rate_out)
    )


def resampler_set_rate_ratio(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], ratio: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_resampler_set_rate_ratio", Int32](rs, ratio)
    )


def resampler_get_input_latency(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_resampler_get_input_latency", Int32](
            rs, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def resampler_get_output_latency(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_resampler_get_output_latency", Int32](
            rs, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def resampler_get_required_input_frame_count(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], output_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_resampler_get_required_input_frame_count", Int32](
            rs, output_frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def resampler_get_expected_output_frame_count(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], input_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_resampler_get_expected_output_frame_count", Int32](
            rs, input_frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def resampler_reset(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_resampler_reset", Int32](rs))


# ================= ma_channel_converter =================


def channel_converter_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_channel_converter_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def channel_converter_free(lib: MaLib, cc: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_channel_converter_free", NoneType](cc)


def channel_converter_get_heap_size(
    lib: MaLib,
    format: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    mix_mode: Int,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_converter_get_heap_size", Int32](
            Int32(format), channels_in, channels_out, Int32(mix_mode),
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def channel_converter_init(
    lib: MaLib,
    cc: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    mix_mode: Int,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_channel_converter_init", Int32](
            cc, Int32(format), channels_in, channels_out, Int32(mix_mode)
        )
    )


def channel_converter_init_preallocated(
    lib: MaLib,
    cc: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    mix_mode: Int,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_channel_converter_init_preallocated", Int32](
            cc, Int32(format), channels_in, channels_out, Int32(mix_mode)
        )
    )


def channel_converter_uninit(
    lib: MaLib, cc: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_channel_converter_uninit", Int32](cc))


def channel_converter_process(
    lib: MaLib,
    cc: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Converts exactly frame_count frames; the frame rate is unchanged."""
    return Int(
        lib.handle.call["ma_shim_channel_converter_process", Int32](
            cc, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def channel_converter_get_input_channel_map(
    lib: MaLib, cc: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> MaChannelMap:
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_channel_converter_get_input_channel_map", Int32](
            cc, buf.unsafe_ptr(), capacity
        )
    )
    return MaChannelMap(code, buf^)


def channel_converter_get_output_channel_map(
    lib: MaLib, cc: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> MaChannelMap:
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_channel_converter_get_output_channel_map", Int32](
            cc, buf.unsafe_ptr(), capacity
        )
    )
    return MaChannelMap(code, buf^)


# ================= ma_data_converter =================


def data_converter_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_data_converter_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def data_converter_free(lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_data_converter_free", NoneType](dc)


def data_converter_get_heap_size(
    lib: MaLib,
    format_in: Int,
    format_out: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_converter_get_heap_size", Int32](
            Int32(format_in),
            Int32(format_out),
            channels_in,
            channels_out,
            sample_rate_in,
            sample_rate_out,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def data_converter_init(
    lib: MaLib,
    dc: OpaquePointer[MutUntrackedOrigin],
    format_in: Int,
    format_out: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_converter_init", Int32](
            dc,
            Int32(format_in),
            Int32(format_out),
            channels_in,
            channels_out,
            sample_rate_in,
            sample_rate_out,
        )
    )


def data_converter_init_default(
    lib: MaLib,
    dc: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """Init from miniaudio's default config with only the pass-through shape set."""
    return Int(
        lib.handle.call["ma_shim_data_converter_init_default", Int32](
            dc, Int32(format), channels, sample_rate
        )
    )


def data_converter_init_preallocated(
    lib: MaLib,
    dc: OpaquePointer[MutUntrackedOrigin],
    format_in: Int,
    format_out: Int,
    channels_in: UInt32,
    channels_out: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_converter_init_preallocated", Int32](
            dc,
            Int32(format_in),
            Int32(format_out),
            channels_in,
            channels_out,
            sample_rate_in,
            sample_rate_out,
        )
    )


def data_converter_uninit(lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_data_converter_uninit", Int32](dc))


def data_converter_process(
    lib: MaLib,
    dc: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    frame_count_in: UInt64,
    mut dst: List[Float32],
    frame_count_out: UInt64,
) -> MaProcess:
    var in_holder = [frame_count_in]
    var out_holder = [frame_count_out]
    var code = Int(
        lib.handle.call["ma_shim_data_converter_process", Int32](
            dc,
            src.unsafe_ptr(),
            in_holder.unsafe_ptr(),
            dst.unsafe_ptr(),
            out_holder.unsafe_ptr(),
        )
    )
    return MaProcess(code, in_holder[0], out_holder[0])


def data_converter_set_rate(
    lib: MaLib,
    dc: OpaquePointer[MutUntrackedOrigin],
    rate_in: UInt32,
    rate_out: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_converter_set_rate", Int32](
            dc, rate_in, rate_out
        )
    )


def data_converter_set_rate_ratio(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin], ratio: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_converter_set_rate_ratio", Int32](dc, ratio)
    )


def data_converter_get_input_latency(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_converter_get_input_latency", Int32](
            dc, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def data_converter_get_output_latency(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_converter_get_output_latency", Int32](
            dc, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def data_converter_get_required_input_frame_count(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin], output_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_data_converter_get_required_input_frame_count", Int32
        ](dc, output_frame_count, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def data_converter_get_expected_output_frame_count(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin], input_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_data_converter_get_expected_output_frame_count", Int32
        ](dc, input_frame_count, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def data_converter_get_input_channel_map(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> MaChannelMap:
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_data_converter_get_input_channel_map", Int32](
            dc, buf.unsafe_ptr(), capacity
        )
    )
    return MaChannelMap(code, buf^)


def data_converter_get_output_channel_map(
    lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> MaChannelMap:
    var buf = List[UInt8](capacity=Int(capacity))
    buf.resize(Int(capacity), UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_data_converter_get_output_channel_map", Int32](
            dc, buf.unsafe_ptr(), capacity
        )
    )
    return MaChannelMap(code, buf^)


def data_converter_reset(lib: MaLib, dc: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_data_converter_reset", Int32](dc))


# ================= ma_linear_resampler =================

# The algorithm ma_resampler drives underneath when set to linear, bound in its
# own right too. Same shape as the resampler, minus the algorithm selector.


def linear_resampler_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_linear_resampler_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def linear_resampler_free(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_linear_resampler_free", NoneType](rs)


def linear_resampler_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_linear_resampler_get_heap_size", Int32](
            Int32(format), channels, sample_rate_in, sample_rate_out,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def linear_resampler_init(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_linear_resampler_init", Int32](
            rs, Int32(format), channels, sample_rate_in, sample_rate_out
        )
    )


def linear_resampler_init_preallocated(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate_in: UInt32,
    sample_rate_out: UInt32,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_linear_resampler_init_preallocated", Int32](
            rs, Int32(format), channels, sample_rate_in, sample_rate_out
        )
    )


def linear_resampler_uninit(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_linear_resampler_uninit", Int32](rs))


def linear_resampler_process(
    lib: MaLib,
    rs: OpaquePointer[MutUntrackedOrigin],
    src: List[Float32],
    frame_count_in: UInt64,
    mut dst: List[Float32],
    frame_count_out: UInt64,
) -> MaProcess:
    var in_holder = [frame_count_in]
    var out_holder = [frame_count_out]
    var code = Int(
        lib.handle.call["ma_shim_linear_resampler_process", Int32](
            rs,
            src.unsafe_ptr(),
            in_holder.unsafe_ptr(),
            dst.unsafe_ptr(),
            out_holder.unsafe_ptr(),
        )
    )
    return MaProcess(code, in_holder[0], out_holder[0])


def linear_resampler_set_rate(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], rate_in: UInt32, rate_out: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_linear_resampler_set_rate", Int32](
            rs, rate_in, rate_out
        )
    )


def linear_resampler_set_rate_ratio(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], ratio: Float32) -> Int:
    """miniaudio's ratio is input-over-output, so 2.0 halves the rate."""
    return Int(
        lib.handle.call["ma_shim_linear_resampler_set_rate_ratio", Int32](rs, ratio)
    )


def linear_resampler_get_input_latency(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_linear_resampler_get_input_latency", Int32](
            rs, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def linear_resampler_get_output_latency(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_linear_resampler_get_output_latency", Int32](
            rs, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def linear_resampler_get_required_input_frame_count(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], output_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_linear_resampler_get_required_input_frame_count", Int32
        ](rs, output_frame_count, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def linear_resampler_get_expected_output_frame_count(
    lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin], input_frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call[
            "ma_shim_linear_resampler_get_expected_output_frame_count", Int32
        ](rs, input_frame_count, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def linear_resampler_reset(lib: MaLib, rs: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_linear_resampler_reset", Int32](rs))
