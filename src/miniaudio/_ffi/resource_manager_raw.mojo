"""Binding layer: raw 1:1 wrappers over the resource manager shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in
resource_manager.mojo.

The manager is driven with `job_thread_count = 0` and the non-blocking flag in
tests, so it never starts a thread and the job queue is pumped explicitly —
which is what makes a family built around asynchrony deterministic.

`ma_resource_manager_get_log` returns an ma_log* and `ma_job` is a struct, both
without a safe Mojo home. The log is bound as whether one is there; the job
queue is bound through a single job slot the shim keeps on the manager handle,
so `next_job` / `post_job` / `process_job` are all reachable without Mojo ever
holding an ma_job.
"""

from miniaudio._lib import MaLib
from miniaudio.result import MaResult
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaBool


@fieldwise_init
struct MaDataFormat(Copyable, Movable):
    """Raw (result_code, format, channels, sample_rate) for the format getters."""

    var result: MaResult
    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


@fieldwise_init
struct MaResultCode(Copyable, Movable):
    """Raw (result_code, value) pair: the call's ma_result plus an int it reported (a job type)."""

    var result: MaResult
    var value: Int


@fieldwise_init
struct MaLoadResult(Copyable, Movable):
    """Raw (result_code, reported ma_result) pair for the `result` accessors."""

    var result: MaResult
    var value: MaResult


# ================= the manager =================


def resource_manager_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.call["ma_shim_resource_manager_alloc", OpaquePointer[MutUntrackedOrigin]]()


def resource_manager_free(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]):
    lib.call["ma_shim_resource_manager_free", NoneType](rm)


def resource_manager_init(
    lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin], job_thread_count: UInt32 = 0, non_blocking: Bool = True
) -> MaResult:
    """Zero job threads plus non-blocking keeps every job on the calling thread."""
    return MaResult(
        lib.call["ma_shim_resource_manager_init", Int32](
            rm, job_thread_count, Int32(1) if non_blocking else Int32(0)
        )
    )


def resource_manager_uninit(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(lib.call["ma_shim_resource_manager_uninit", Int32](rm))


def resource_manager_has_log(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_resource_manager_has_log", Int32](
            rm, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def resource_manager_register_file(
    lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_resource_manager_register_file", Int32](
            rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def resource_manager_unregister_file(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin], path: String) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_resource_manager_unregister_file", Int32](
            rm, path_c.as_bytes().unsafe_ptr()
        )
    )


def resource_manager_register_decoded_data(
    lib: MaLib,
    rm: OpaquePointer[MutUntrackedOrigin],
    name: String,
    frames: List[Float32],
    frame_count: UInt64,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
) -> MaResult:
    """miniaudio does not copy the frames; the caller keeps them alive."""
    var name_c = name + "\x00"
    return MaResult(
        lib.call["ma_shim_resource_manager_register_decoded_data", Int32](
            rm,
            name_c.as_bytes().unsafe_ptr(),
            frames.unsafe_ptr(),
            frame_count,
            Int32(format),
            channels,
            sample_rate,
        )
    )


def resource_manager_register_encoded_data(
    lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin], name: String, data: List[UInt8]
) -> MaResult:
    var name_c = name + "\x00"
    return MaResult(
        lib.call["ma_shim_resource_manager_register_encoded_data", Int32](
            rm, name_c.as_bytes().unsafe_ptr(), data.unsafe_ptr(), UInt64(len(data))
        )
    )


def resource_manager_unregister_data(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin], name: String) -> MaResult:
    var name_c = name + "\x00"
    return MaResult(
        lib.call["ma_shim_resource_manager_unregister_data", Int32](
            rm, name_c.as_bytes().unsafe_ptr()
        )
    )


def resource_manager_post_job_quit(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(
        lib.call["ma_shim_resource_manager_post_job_quit", Int32](rm)
    )


def resource_manager_next_job(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResultCode:
    """Pops a job into the shim's slot; the value is the job's type code."""
    var holder = [Int32(-1)]
    var code = MaResult(
        lib.call["ma_shim_resource_manager_next_job", Int32](
            rm, holder.unsafe_ptr()
        )
    )
    return MaResultCode(code, Int(holder[0]))


def resource_manager_post_job(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    """Puts the job in the shim's slot back on the queue."""
    return MaResult(lib.call["ma_shim_resource_manager_post_job", Int32](rm))


def resource_manager_process_job(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    """Runs the job in the shim's slot."""
    return MaResult(
        lib.call["ma_shim_resource_manager_process_job", Int32](rm)
    )


def resource_manager_process_next_job(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(
        lib.call["ma_shim_resource_manager_process_next_job", Int32](rm)
    )


# ================= data buffer =================


def rm_data_buffer_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.call["ma_shim_rm_data_buffer_alloc", OpaquePointer[MutUntrackedOrigin]]()


def rm_data_buffer_free(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]):
    lib.call["ma_shim_rm_data_buffer_free", NoneType](d)


def rm_data_buffer_init(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_buffer_init", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_buffer_init_ex(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    """Through the config struct, with a pipeline-notifications struct attached."""
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_buffer_init_ex", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_buffer_init_copy(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], existing: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(
        lib.call["ma_shim_rm_data_buffer_init_copy", Int32](d, rm, existing)
    )


def rm_data_buffer_uninit(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_buffer_uninit", Int32](d))


def rm_data_buffer_read(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], mut dst: List[Float32], frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_read", Int32](
            d, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_buffer_seek(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_buffer_seek", Int32](d, frame_index))


def rm_data_buffer_get_data_format(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaDataFormat:
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var rate = [UInt32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_get_data_format", Int32](
            d, fmt.unsafe_ptr(), ch.unsafe_ptr(), rate.unsafe_ptr()
        )
    )
    return MaDataFormat(code, Int(fmt[0]), ch[0], rate[0])


def rm_data_buffer_get_cursor(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_get_cursor", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_buffer_get_length(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_get_length", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_buffer_get_available(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_get_available", Int32](
            d, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_buffer_result(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaLoadResult:
    """The load result the manager recorded for this object."""
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_result", Int32](d, holder.unsafe_ptr())
    )
    return MaLoadResult(code, MaResult(holder[0]))


def rm_data_buffer_set_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], is_looping: Bool) -> MaResult:
    return MaResult(
        lib.call["ma_shim_rm_data_buffer_set_looping", Int32](
            d, Int32(1) if is_looping else Int32(0)
        )
    )


def rm_data_buffer_is_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_buffer_is_looping", Int32](d, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != Int32(0))


# ================= data stream =================


def rm_data_stream_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.call["ma_shim_rm_data_stream_alloc", OpaquePointer[MutUntrackedOrigin]]()


def rm_data_stream_free(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]):
    lib.call["ma_shim_rm_data_stream_free", NoneType](d)


def rm_data_stream_init(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_stream_init", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_stream_init_ex(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    """Through the config struct, with a pipeline-notifications struct attached."""
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_stream_init_ex", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_stream_uninit(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_stream_uninit", Int32](d))


def rm_data_stream_read(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], mut dst: List[Float32], frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_read", Int32](
            d, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_stream_seek(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_stream_seek", Int32](d, frame_index))


def rm_data_stream_get_data_format(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaDataFormat:
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var rate = [UInt32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_get_data_format", Int32](
            d, fmt.unsafe_ptr(), ch.unsafe_ptr(), rate.unsafe_ptr()
        )
    )
    return MaDataFormat(code, Int(fmt[0]), ch[0], rate[0])


def rm_data_stream_get_cursor(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_get_cursor", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_stream_get_length(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_get_length", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_stream_get_available(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_get_available", Int32](
            d, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_stream_result(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaLoadResult:
    """The load result the manager recorded for this object."""
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_result", Int32](d, holder.unsafe_ptr())
    )
    return MaLoadResult(code, MaResult(holder[0]))


def rm_data_stream_set_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], is_looping: Bool) -> MaResult:
    return MaResult(
        lib.call["ma_shim_rm_data_stream_set_looping", Int32](
            d, Int32(1) if is_looping else Int32(0)
        )
    )


def rm_data_stream_is_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_stream_is_looping", Int32](d, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != Int32(0))


# ================= data source =================


def rm_data_source_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.call["ma_shim_rm_data_source_alloc", OpaquePointer[MutUntrackedOrigin]]()


def rm_data_source_free(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]):
    lib.call["ma_shim_rm_data_source_free", NoneType](d)


def rm_data_source_init(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_source_init", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_source_init_ex(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], path: String, flags: UInt32 = 0
) -> MaResult:
    """Through the config struct, with a pipeline-notifications struct attached."""
    var path_c = path + "\x00"
    return MaResult(
        lib.call["ma_shim_rm_data_source_init_ex", Int32](
            d, rm, path_c.as_bytes().unsafe_ptr(), flags
        )
    )


def rm_data_source_init_copy(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], rm: OpaquePointer[MutUntrackedOrigin], existing: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(
        lib.call["ma_shim_rm_data_source_init_copy", Int32](d, rm, existing)
    )


def rm_data_source_uninit(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_source_uninit", Int32](d))


def rm_data_source_read(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], mut dst: List[Float32], frame_count: UInt64
) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_read", Int32](
            d, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_source_seek(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], frame_index: UInt64) -> MaResult:
    return MaResult(lib.call["ma_shim_rm_data_source_seek", Int32](d, frame_index))


def rm_data_source_get_data_format(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaDataFormat:
    var fmt = [Int32(0)]
    var ch = [UInt32(0)]
    var rate = [UInt32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_get_data_format", Int32](
            d, fmt.unsafe_ptr(), ch.unsafe_ptr(), rate.unsafe_ptr()
        )
    )
    return MaDataFormat(code, Int(fmt[0]), ch[0], rate[0])


def rm_data_source_get_cursor(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_get_cursor", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_source_get_length(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_get_length", Int32](d, holder.unsafe_ptr())
    )
    return MaCount(code, holder[0])


def rm_data_source_get_available(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_get_available", Int32](
            d, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def rm_data_source_result(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaLoadResult:
    """The load result the manager recorded for this object."""
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_result", Int32](d, holder.unsafe_ptr())
    )
    return MaLoadResult(code, MaResult(holder[0]))


def rm_data_source_set_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], is_looping: Bool) -> MaResult:
    return MaResult(
        lib.call["ma_shim_rm_data_source_set_looping", Int32](
            d, Int32(1) if is_looping else Int32(0)
        )
    )


def rm_data_source_is_looping(lib: MaLib, d: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_is_looping", Int32](d, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != Int32(0))


def rm_data_source_map_read(
    lib: MaLib, d: OpaquePointer[MutUntrackedOrigin], mut dst: List[Float32], frame_count: UInt64
) -> MaCount:
    """map -> copy -> unmap; the shim owns the interior pointer."""
    var holder = [UInt64(0)]
    var code = MaResult(
        lib.call["ma_shim_rm_data_source_map_read", Int32](
            d, dst.unsafe_ptr(), frame_count, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def resource_manager_borrow_engine(
    lib: MaLib,
    rm: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
) -> MaResult:
    """Make `rm` a non-owning view of the engine's resource manager."""
    return MaResult(
        lib.call["ma_shim_resource_manager_borrow_engine", Int32](rm, engine)
    )
