"""Binding layer: raw 1:1 wrappers over the data_source shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
data_source.mojo.

The underlying data source is the shim-owned buffer implementation (a concrete
ma_data_source with a C vtable), so every generic ma_data_source_* entry point
is reachable from Mojo without a device, engine, or file.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaFloat


@fieldwise_init
struct MaRange(Copyable, Movable):
    """Raw (result_code, beg, end) triple for the range / loop-point getters."""

    var result: Int
    var beg: UInt64
    var end: UInt64


@fieldwise_init
struct MaDataFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) from get_data_format."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


@fieldwise_init
struct MaFlag(Copyable, Movable):
    """Raw (result_code, flag) pair for shim calls with an int out-param."""

    var result: Int
    var value: Bool


# ---- lifecycle --------------------------------------------------------------


def data_source_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_data_source_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def data_source_free(lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_data_source_free", NoneType](ds)


def data_source_init_buffer(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    frames: List[Float32],
    frame_count: UInt64,
    channels: UInt32,
    sample_rate: UInt32,
) -> Int:
    """Initialises `ds` over a shim-owned copy of `frames` (interleaved f32)."""
    return Int(
        lib.handle.call["ma_shim_data_source_init_buffer", Int32](
            ds,
            frames.unsafe_ptr(),
            frame_count,
            channels,
            sample_rate,
        )
    )


def data_source_uninit(lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_data_source_uninit", Int32](ds))


# ---- read / seek ------------------------------------------------------------


def data_source_read_pcm_frames(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt64,
) -> MaCount:
    """Reads up to frame_count frames into `out` (caller pre-sizes the buffer).

    Returns MaCount(result_code, frames_read).
    """
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_read_pcm_frames", Int32](
            ds,
            out.unsafe_ptr(),
            frame_count,
            holder.unsafe_ptr(),
        )
    )
    return MaCount(code, holder[0])


def data_source_seek_pcm_frames(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin], frame_count: UInt64
) -> MaCount:
    """Forward-only seek. Returns MaCount(result_code, frames_seeked)."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_seek_pcm_frames", Int32](
            ds, frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def data_source_seek_to_pcm_frame(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_seek_to_pcm_frame", Int32](
            ds, frame_index
        )
    )


def data_source_seek_seconds(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin], second_count: Float32
) -> MaFloat:
    """Forward-only seek in seconds. Returns MaFloat(result_code, seconds_seeked)."""
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_seek_seconds", Int32](
            ds, second_count, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def data_source_seek_to_second(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin], seek_point: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_seek_to_second", Int32](ds, seek_point)
    )


# ---- queries ----------------------------------------------------------------


def data_source_get_data_format(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaDataFormat:
    var fmt = [Int32(0)]
    var channels = [UInt32(0)]
    var sample_rate = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_data_format", Int32](
            ds,
            fmt.unsafe_ptr(),
            channels.unsafe_ptr(),
            sample_rate.unsafe_ptr(),
        )
    )
    return MaDataFormat(code, Int(fmt[0]), channels[0], sample_rate[0])


def data_source_get_cursor_in_pcm_frames(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_cursor_in_pcm_frames", Int32](
            ds, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def data_source_get_length_in_pcm_frames(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_length_in_pcm_frames", Int32](
            ds, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def data_source_get_cursor_in_seconds(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_cursor_in_seconds", Int32](
            ds, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def data_source_get_length_in_seconds(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_length_in_seconds", Int32](
            ds, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


# ---- looping ----------------------------------------------------------------


def data_source_set_looping(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin], is_looping: Bool
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_set_looping", Int32](
            ds, Int32(1) if is_looping else Int32(0)
        )
    )


def data_source_is_looping(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> Bool:
    """Returns False for a null/uninitialised handle (documented sentinel)."""
    return Int(lib.handle.call["ma_shim_data_source_is_looping", Int32](ds)) != 0


# ---- range / loop point -----------------------------------------------------


def data_source_set_range_in_pcm_frames(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    range_beg: UInt64,
    range_end: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_set_range_in_pcm_frames", Int32](
            ds, range_beg, range_end
        )
    )


def data_source_get_range_in_pcm_frames(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaRange:
    var beg = [UInt64(0)]
    var end = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_range_in_pcm_frames", Int32](
            ds, beg.unsafe_ptr(), end.unsafe_ptr()
        )
    )
    return MaRange(code, beg[0], end[0])


def data_source_set_loop_point_in_pcm_frames(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    loop_beg: UInt64,
    loop_end: UInt64,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_set_loop_point_in_pcm_frames", Int32](
            ds, loop_beg, loop_end
        )
    )


def data_source_get_loop_point_in_pcm_frames(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaRange:
    var beg = [UInt64(0)]
    var end = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_get_loop_point_in_pcm_frames", Int32](
            ds, beg.unsafe_ptr(), end.unsafe_ptr()
        )
    )
    return MaRange(code, beg[0], end[0])


# ---- chaining ---------------------------------------------------------------


def data_source_set_current(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    current: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    """Sets the source reads are routed through.

    A null `current` means "no current source" — it does NOT restore reading
    from self; pass `ds` itself for that.
    """
    return Int(
        lib.handle.call["ma_shim_data_source_set_current", Int32](ds, current)
    )


def data_source_current_is(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    expected: OpaquePointer[MutUntrackedOrigin],
) -> MaFlag:
    """Identity comparison against `expected` (the raw ptr is never exposed)."""
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_current_is", Int32](
            ds, expected, holder.unsafe_ptr()
        )
    )
    return MaFlag(code, Int(holder[0]) != 0)


def data_source_set_next(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    next_ds: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    """A null `next` clears the chain."""
    return Int(
        lib.handle.call["ma_shim_data_source_set_next", Int32](ds, next_ds)
    )


def data_source_next_is(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    expected: OpaquePointer[MutUntrackedOrigin],
) -> MaFlag:
    """Identity comparison against `expected` (the raw ptr is never exposed)."""
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_next_is", Int32](
            ds, expected, holder.unsafe_ptr()
        )
    )
    return MaFlag(code, Int(holder[0]) != 0)


def data_source_set_next_callback(
    lib: MaLib,
    ds: OpaquePointer[MutUntrackedOrigin],
    next_ds: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    """Installs the shim-owned next-callback returning `next`; null clears it."""
    return Int(
        lib.handle.call["ma_shim_data_source_set_next_callback", Int32](ds, next_ds)
    )


def data_source_has_next_callback(
    lib: MaLib, ds: OpaquePointer[MutUntrackedOrigin]
) -> MaFlag:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_data_source_has_next_callback", Int32](
            ds, holder.unsafe_ptr()
        )
    )
    return MaFlag(code, Int(holder[0]) != 0)


# ---- data_source_node -------------------------------------------------------


def data_source_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_data_source_node_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def data_source_node_free(lib: MaLib, node: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_data_source_node_free", NoneType](node)


def data_source_node_init(
    lib: MaLib,
    node: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    ds: OpaquePointer[MutUntrackedOrigin],
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_node_init", Int32](node, engine, ds)
    )


def data_source_node_uninit(
    lib: MaLib, node: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_data_source_node_uninit", Int32](node))


def data_source_node_set_looping(
    lib: MaLib, node: OpaquePointer[MutUntrackedOrigin], is_looping: Bool
) -> Int:
    return Int(
        lib.handle.call["ma_shim_data_source_node_set_looping", Int32](
            node, Int32(1) if is_looping else Int32(0)
        )
    )


def data_source_node_is_looping(
    lib: MaLib, node: OpaquePointer[MutUntrackedOrigin]
) -> Bool:
    """Returns False for a null/uninitialised handle (documented sentinel)."""
    return (
        Int(lib.handle.call["ma_shim_data_source_node_is_looping", Int32](node)) != 0
    )