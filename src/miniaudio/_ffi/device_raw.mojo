"""Binding layer: raw 1:1 wrappers over the device shim functions.

Mirrors decoder_raw.mojo: thin, policy-free marshalling over the shim. The
device's data callback is owned by the C shim and pulls from a decoder handle,
so no Mojo callback crosses the FFI boundary. All lifecycle/error policy lives
in the API layer (device.mojo).
"""

from miniaudio._lib import MaLib, null_handle


comptime NAME_CAP = 256
"""Matches MA_MAX_DEVICE_NAME_LENGTH + 1; the shim truncates and null-terminates."""


@fieldwise_init
struct MaFloat(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a float out-param."""

    var result: Int
    var value: Float32


@fieldwise_init
struct MaUInt(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with a uint32 out-param."""

    var result: Int
    var value: UInt32


@fieldwise_init
struct MaBool(Copyable, Movable):
    """Raw (result_code, value) pair for shim calls with an int 0/1 out-param."""

    var result: Int
    var value: Bool


@fieldwise_init
struct MaText(Copyable, Movable):
    """Raw (result_code, text) pair for shim calls with a char-buffer out-param."""

    var result: Int
    var value: String


@fieldwise_init
struct MaNativeDataFormat(Copyable, Movable):
    """Raw (result_code, fields) for one ma_device_info native data format entry."""

    var result: Int
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32
    var flags: UInt32


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


def device_init_ex_playback_from_decoder(
    lib: MaLib,
    dev: OpaquePointer[MutUntrackedOrigin],
    decoder: OpaquePointer[MutUntrackedOrigin],
    backends: List[Int32],
    sample_rate_override: UInt32,
) -> Int:
    """Inits a playback device, picking the backend from an explicit priority list.

    An empty `backends` means miniaudio's default priority order.
    """
    return Int(
        lib.handle.call["ma_shim_device_init_ex_playback_from_decoder", Int32](
            dev,
            decoder,
            backends.unsafe_ptr(),
            UInt32(len(backends)),
            sample_rate_override,
        )
    )


def device_get_state(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Returns an ma_device_state code; 0 (uninitialized) for a null handle."""
    return Int(lib.handle.call["ma_shim_device_get_state", Int32](dev))


def device_is_started(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> Bool:
    return lib.handle.call["ma_shim_device_is_started", Int32](dev) != Int32(0)


def device_set_master_volume(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin], volume: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_set_master_volume", Int32](dev, volume)
    )


def device_get_master_volume(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_get_master_volume", Int32](
            dev, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def device_set_master_volume_db(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin], gain_db: Float32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_set_master_volume_db", Int32](dev, gain_db)
    )


def device_get_master_volume_db(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_get_master_volume_db", Int32](
            dev, holder.unsafe_ptr()
        )
    )
    return MaFloat(code, holder[0])


def device_get_name(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin], device_type: Int
) -> MaText:
    var buf = List[UInt8]()
    buf.resize(NAME_CAP, UInt8(0))
    var len_holder = [UInt(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_get_name", Int32](
            dev,
            Int32(device_type),
            buf.unsafe_ptr(),
            UInt(NAME_CAP),
            len_holder.unsafe_ptr(),
        )
    )
    if code != 0:
        return MaText(code, String(""))
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


def device_info_load(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin], device_type: Int
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_info_load", Int32](dev, Int32(device_type))
    )


def device_info_name(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> MaText:
    var buf = List[UInt8]()
    buf.resize(NAME_CAP, UInt8(0))
    var len_holder = [UInt(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_info_name", Int32](
            dev,
            buf.unsafe_ptr(),
            UInt(NAME_CAP),
            len_holder.unsafe_ptr(),
        )
    )
    if code != 0:
        return MaText(code, String(""))
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


def device_info_is_default(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_info_is_default", Int32](
            dev, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def device_info_native_data_format_count(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_info_native_data_format_count", Int32](
            dev, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def device_info_native_data_format(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin], index: UInt32
) -> MaNativeDataFormat:
    var fmt = [Int32(0)]
    var channels = [UInt32(0)]
    var sample_rate = [UInt32(0)]
    var flags = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_info_native_data_format", Int32](
            dev,
            index,
            fmt.unsafe_ptr(),
            channels.unsafe_ptr(),
            sample_rate.unsafe_ptr(),
            flags.unsafe_ptr(),
        )
    )
    return MaNativeDataFormat(
        code, Int(fmt[0]), channels[0], sample_rate[0], flags[0]
    )


def device_info_add_native_data_format(
    lib: MaLib,
    dev: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    flags: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_info_add_native_data_format", Int32](
            dev, Int32(format), channels, sample_rate, flags
        )
    )


def device_id_equal(
    lib: MaLib,
    dev_a: OpaquePointer[MutUntrackedOrigin],
    dev_b: OpaquePointer[MutUntrackedOrigin],
    device_type: Int,
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_id_equal", Int32](
            dev_a, dev_b, Int32(device_type), holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def device_get_context_backend(
    lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    """Returns the ma_backend code of the context the device is running on."""
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_get_context_backend", Int32](
            dev, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, UInt32(holder[0]))


def device_has_log(lib: MaLib, dev: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_has_log", Int32](dev, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != Int32(0))


def device_handle_backend_data_callback(
    lib: MaLib,
    dev: OpaquePointer[MutUntrackedOrigin],
    mut out: List[Float32],
    frame_count: UInt32,
) -> Int:
    """Drives the data callback synchronously (caller pre-sizes `out`)."""
    return Int(
        lib.handle.call["ma_shim_device_handle_backend_data_callback", Int32](
            dev,
            out.unsafe_ptr(),
            null_handle(),
            frame_count,
        )
    )


# ---- device job thread ----


def device_job_thread_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call[
        "ma_shim_device_job_thread_alloc", OpaquePointer[MutUntrackedOrigin]
    ]()


def device_job_thread_free(lib: MaLib, jt: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_device_job_thread_free", NoneType](jt)


def device_job_thread_init(
    lib: MaLib,
    jt: OpaquePointer[MutUntrackedOrigin],
    no_thread: Bool,
    job_queue_capacity: UInt32,
    job_queue_flags: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_job_thread_init", Int32](
            jt,
            Int32(1) if no_thread else Int32(0),
            job_queue_capacity,
            job_queue_flags,
        )
    )


def device_job_thread_uninit(
    lib: MaLib, jt: OpaquePointer[MutUntrackedOrigin]
) -> Int:
    return Int(lib.handle.call["ma_shim_device_job_thread_uninit", Int32](jt))


def device_job_thread_post(
    lib: MaLib, jt: OpaquePointer[MutUntrackedOrigin], job_code: UInt16
) -> Int:
    return Int(
        lib.handle.call["ma_shim_device_job_thread_post", Int32](jt, job_code)
    )


def device_job_thread_next(
    lib: MaLib, jt: OpaquePointer[MutUntrackedOrigin]
) -> MaUInt:
    """Returns MaUInt(result, job_code). Blocks on an empty queue unless the
    queue was created with MA_JOB_QUEUE_FLAG_NON_BLOCKING."""
    var holder = [UInt16(0)]
    var code = Int(
        lib.handle.call["ma_shim_device_job_thread_next", Int32](
            jt, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, UInt32(holder[0]))
