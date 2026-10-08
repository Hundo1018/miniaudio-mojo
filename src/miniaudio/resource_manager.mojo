"""Idiomatic resource manager API (Layer 3).

The resource manager loads and caches sounds. Four types cover it:

- `ResourceManager` — the cache and its job queue.
- `ResourceDataBuffer` — a whole sound decoded into memory.
- `ResourceDataStream` — a sound decoded a page at a time.
- `ResourceDataSource` — the unified front end, which becomes a buffer or a
  stream depending on the flags it is given.

Created with `job_thread_count=0` and `non_blocking=True` (the defaults here),
the manager never starts a thread and its job queue is pumped explicitly, which
is what makes a family built around asynchrony testable. Pass a thread count if
you would rather miniaudio load in the background.

**Streams need a job thread.** `ma_resource_manager_data_stream_uninit` always
posts a free job and waits for it, with no flag to opt out, so on a zero-thread
manager a stream can be created but never torn down — the calling thread is
blocked inside uninit and cannot pump the queue itself. Build the manager with
`job_thread_count=1` (or more) whenever streams are involved. Buffers are
unaffected: without `RESOURCE_FLAG_ASYNC` they load inline on the calling thread
and tear down without a job.

`ma_resource_manager_get_log` returns a log pointer and `ma_job` is a struct;
neither has a safe Mojo home. The log is exposed as `has_log`, and the job queue
through the shim's single job slot: `next_job` pops one and reports its type,
`repost_job` puts it back, `process_job` runs it.

Every data object keeps its manager alive for as long as it exists.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.engine import Engine
from miniaudio.result import MA_SUCCESS, MA_AT_END
import miniaudio._ffi.resource_manager_raw as raw


comptime RESOURCE_FLAG_STREAM = UInt32(1)
comptime RESOURCE_FLAG_DECODE = UInt32(2)
comptime RESOURCE_FLAG_ASYNC = UInt32(4)
comptime RESOURCE_FLAG_WAIT_INIT = UInt32(8)
comptime RESOURCE_FLAG_LOOPING = UInt32(16)


@fieldwise_init
struct DataFormat(Copyable, Movable):
    """The format a loaded sound decodes to."""

    var format: SampleFormat
    var channels: UInt32
    var sample_rate: UInt32


struct ResourceManager(Movable):
    """The sound cache and its job queue (RAII).

    `ResourceManager.of_engine` is a *borrowed* view of the manager an engine
    loads its sounds through (ma_engine_get_resource_manager): files registered
    on it are visible to the engine's sounds and data objects built against it
    share the engine's cache. Dropping the view leaves the manager alone. A view
    keeps the engine alive for as long as it exists, and so does everything built
    against it (they hold the view).
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _owner: Optional[ArcPointer[Engine]]  # set for a borrowed view of an engine's manager

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr
        self._owner = None

    @staticmethod
    def of_engine(engine: ArcPointer[Engine]) raises -> Self:
        """A non-owning view of the engine's resource manager."""
        var lib = engine[]._lib.copy()
        var ptr = raw.resource_manager_alloc(lib[])
        if ptr == null_handle():
            raise Error("resource_manager_alloc failed (out of memory)")
        var code = raw.resource_manager_borrow_engine(lib[], ptr, engine[]._ptr)
        if code != MA_SUCCESS:
            raw.resource_manager_free(lib[], ptr)
            raise Error(lib[].describe("engine resource manager borrow failed", code))
        var view = Self(lib^, ptr)
        view._owner = engine.copy()
        return view^

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        job_thread_count: UInt32 = 0,
        non_blocking: Bool = True,
    ) raises -> Self:
        """The defaults keep every job on the calling thread."""
        var ptr = raw.resource_manager_alloc(lib[])
        if ptr == null_handle():
            raise Error("resource_manager_alloc failed (out of memory)")
        var code = raw.resource_manager_init(
            lib[], ptr, job_thread_count, non_blocking
        )
        if code != MA_SUCCESS:
            raw.resource_manager_free(lib[], ptr)
            raise Error(lib[].describe("resource manager init failed", code))
        return Self(lib.copy(), ptr)

    def has_log(self) raises -> Bool:
        """Whether the manager has a log attached."""
        var rc = raw.resource_manager_has_log(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resource manager log failed", rc.result)
            )
        return rc.value

    def register_file(mut self, path: String, *, flags: UInt32 = 0) raises:
        """Preload a file into the cache under its own path."""
        var code = raw.resource_manager_register_file(
            self._lib[], self._ptr, path, flags
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("register_file failed", code))

    def unregister_file(mut self, path: String) raises:
        var code = raw.resource_manager_unregister_file(self._lib[], self._ptr, path)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("unregister_file failed", code))

    def register_decoded_data(
        mut self,
        name: String,
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        sample_rate: UInt32 = 48000,
        format: SampleFormat = SAMPLE_FORMAT_F32,
    ) raises:
        """Register already-decoded frames under `name`.

        miniaudio does *not* copy them, so `frames` has to outlive every data
        object that reads from this name.
        """
        var frame_count = UInt64(len(frames)) // UInt64(channels)
        var code = raw.resource_manager_register_decoded_data(
            self._lib[],
            self._ptr,
            name,
            frames,
            frame_count,
            format.code,
            channels,
            sample_rate,
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("register_decoded_data failed", code))

    def register_encoded_data(mut self, name: String, data: List[UInt8]) raises:
        """Register an encoded file image under `name`. Not copied either."""
        var code = raw.resource_manager_register_encoded_data(
            self._lib[], self._ptr, name, data
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("register_encoded_data failed", code))

    def unregister_data(mut self, name: String) raises:
        var code = raw.resource_manager_unregister_data(self._lib[], self._ptr, name)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("unregister_data failed", code))

    def post_quit_job(mut self) raises:
        """Put a quit job on the queue."""
        var code = raw.resource_manager_post_job_quit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("post_job_quit failed", code))

    def next_job(mut self) raises -> Int:
        """Pop a job into the shim's slot and return its type code."""
        var rc = raw.resource_manager_next_job(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("next_job failed", rc.result))
        return rc.value

    def repost_job(mut self) raises:
        """Put the job currently in the slot back on the queue."""
        var code = raw.resource_manager_post_job(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("post_job failed", code))

    def process_job(mut self) raises -> Int:
        """Run the job in the slot. Returns its raw ma_result."""
        return raw.resource_manager_process_job(self._lib[], self._ptr)

    def process_next_job(mut self) raises -> Int:
        """Pop and run one job.

        Returns the raw ma_result: MA_CANCELLED for a quit job, and
        MA_NO_DATA_AVAILABLE when the queue is empty in non-blocking mode.
        """
        return raw.resource_manager_process_next_job(self._lib[], self._ptr)

    def uninit(mut self) raises:
        """Release the manager early; the handle stays valid but empty."""
        var code = raw.resource_manager_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("resource manager uninit failed", code)
            )

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.resource_manager_free(self._lib[], self._ptr)


struct ResourceDataBuffer(Movable):
    """A whole sound decoded into memory (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _manager: ArcPointer[ResourceManager]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var manager: ArcPointer[ResourceManager],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._manager = manager^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        manager: ArcPointer[ResourceManager],
        path: String,
        *,
        flags: UInt32 = 0,
        through_config: Bool = False,
    ) raises -> Self:
        """`through_config` takes miniaudio's config + notifications init path."""
        var lib = manager[]._lib.copy()
        var ptr = raw.rm_data_buffer_alloc(lib[])
        if ptr == null_handle():
            raise Error("rm_data_buffer_alloc failed (out of memory)")

        var code: Int
        if through_config:
            code = raw.rm_data_buffer_init_ex(lib[], ptr, manager[]._ptr, path, flags)
        else:
            code = raw.rm_data_buffer_init(lib[], ptr, manager[]._ptr, path, flags)
        if code != MA_SUCCESS:
            raw.rm_data_buffer_free(lib[], ptr)
            raise Error(lib[].describe("rm_data_buffer init failed", code))

        var channels = raw.rm_data_buffer_get_data_format(lib[], ptr).channels
        return Self(lib^, manager.copy(), ptr, channels if channels > 0 else 1)

    @staticmethod
    def create_copy(
        manager: ArcPointer[ResourceManager], existing: Self
    ) raises -> Self:
        """A second reader over the same cached sound."""
        var lib = manager[]._lib.copy()
        var ptr = raw.rm_data_buffer_alloc(lib[])
        if ptr == null_handle():
            raise Error("rm_data_buffer_alloc failed (out of memory)")

        var code = raw.rm_data_buffer_init_copy(lib[], ptr, manager[]._ptr, existing._ptr)
        if code != MA_SUCCESS:
            raw.rm_data_buffer_free(lib[], ptr)
            raise Error(lib[].describe("rm_data_buffer init_copy failed", code))
        return Self(lib^, manager.copy(), ptr, existing._channels)

    def read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read up to frame_count frames; a short read means the end."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.rm_data_buffer_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("rm_data_buffer read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.rm_data_buffer_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer seek failed", code))

    def data_format(self) raises -> DataFormat:
        var rc = raw.rm_data_buffer_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer data format failed", rc.result))
        return DataFormat(SampleFormat(rc.format), rc.channels, rc.sample_rate)

    def cursor(self) raises -> UInt64:
        var rc = raw.rm_data_buffer_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer cursor failed", rc.result))
        return rc.value

    def length(self) raises -> UInt64:
        var rc = raw.rm_data_buffer_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer length failed", rc.result))
        return rc.value

    def available(self) raises -> UInt64:
        """Frames ready to read right now — the whole remainder once loaded."""
        var rc = raw.rm_data_buffer_get_available(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer available failed", rc.result))
        return rc.value

    def load_result(self) raises -> Int:
        """The raw ma_result the manager recorded for this object's load."""
        var rc = raw.rm_data_buffer_result(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer result failed", rc.result))
        return rc.value

    def set_looping(mut self, is_looping: Bool) raises:
        var code = raw.rm_data_buffer_set_looping(self._lib[], self._ptr, is_looping)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer set_looping failed", code))

    def is_looping(self) raises -> Bool:
        var rc = raw.rm_data_buffer_is_looping(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer is_looping failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.rm_data_buffer_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_buffer uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.rm_data_buffer_free(self._lib[], self._ptr)


struct ResourceDataStream(Movable):
    """A sound decoded a page at a time while it plays (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _manager: ArcPointer[ResourceManager]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var manager: ArcPointer[ResourceManager],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._manager = manager^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        manager: ArcPointer[ResourceManager],
        path: String,
        *,
        flags: UInt32 = 0,
        through_config: Bool = False,
    ) raises -> Self:
        """`through_config` takes miniaudio's config + notifications init path."""
        var lib = manager[]._lib.copy()
        var ptr = raw.rm_data_stream_alloc(lib[])
        if ptr == null_handle():
            raise Error("rm_data_stream_alloc failed (out of memory)")

        var code: Int
        if through_config:
            code = raw.rm_data_stream_init_ex(lib[], ptr, manager[]._ptr, path, flags)
        else:
            code = raw.rm_data_stream_init(lib[], ptr, manager[]._ptr, path, flags)
        if code != MA_SUCCESS:
            raw.rm_data_stream_free(lib[], ptr)
            raise Error(lib[].describe("rm_data_stream init failed", code))

        var channels = raw.rm_data_stream_get_data_format(lib[], ptr).channels
        return Self(lib^, manager.copy(), ptr, channels if channels > 0 else 1)

    def read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read up to frame_count frames; a short read means the end."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.rm_data_stream_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("rm_data_stream read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.rm_data_stream_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream seek failed", code))

    def data_format(self) raises -> DataFormat:
        var rc = raw.rm_data_stream_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream data format failed", rc.result))
        return DataFormat(SampleFormat(rc.format), rc.channels, rc.sample_rate)

    def cursor(self) raises -> UInt64:
        var rc = raw.rm_data_stream_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream cursor failed", rc.result))
        return rc.value

    def length(self) raises -> UInt64:
        var rc = raw.rm_data_stream_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream length failed", rc.result))
        return rc.value

    def available(self) raises -> UInt64:
        """Frames ready to read right now — the whole remainder once loaded."""
        var rc = raw.rm_data_stream_get_available(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream available failed", rc.result))
        return rc.value

    def load_result(self) raises -> Int:
        """The raw ma_result the manager recorded for this object's load."""
        var rc = raw.rm_data_stream_result(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream result failed", rc.result))
        return rc.value

    def set_looping(mut self, is_looping: Bool) raises:
        var code = raw.rm_data_stream_set_looping(self._lib[], self._ptr, is_looping)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream set_looping failed", code))

    def is_looping(self) raises -> Bool:
        var rc = raw.rm_data_stream_is_looping(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream is_looping failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.rm_data_stream_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_stream uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.rm_data_stream_free(self._lib[], self._ptr)


struct ResourceDataSource(Movable):
    """The unified front end: a buffer or a stream depending on the flags (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _manager: ArcPointer[ResourceManager]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var manager: ArcPointer[ResourceManager],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._manager = manager^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        manager: ArcPointer[ResourceManager],
        path: String,
        *,
        flags: UInt32 = 0,
        through_config: Bool = False,
    ) raises -> Self:
        """`through_config` takes miniaudio's config + notifications init path."""
        var lib = manager[]._lib.copy()
        var ptr = raw.rm_data_source_alloc(lib[])
        if ptr == null_handle():
            raise Error("rm_data_source_alloc failed (out of memory)")

        var code: Int
        if through_config:
            code = raw.rm_data_source_init_ex(lib[], ptr, manager[]._ptr, path, flags)
        else:
            code = raw.rm_data_source_init(lib[], ptr, manager[]._ptr, path, flags)
        if code != MA_SUCCESS:
            raw.rm_data_source_free(lib[], ptr)
            raise Error(lib[].describe("rm_data_source init failed", code))

        var channels = raw.rm_data_source_get_data_format(lib[], ptr).channels
        return Self(lib^, manager.copy(), ptr, channels if channels > 0 else 1)

    @staticmethod
    def create_copy(
        manager: ArcPointer[ResourceManager], existing: Self
    ) raises -> Self:
        """A second reader over the same cached sound."""
        var lib = manager[]._lib.copy()
        var ptr = raw.rm_data_source_alloc(lib[])
        if ptr == null_handle():
            raise Error("rm_data_source_alloc failed (out of memory)")

        var code = raw.rm_data_source_init_copy(lib[], ptr, manager[]._ptr, existing._ptr)
        if code != MA_SUCCESS:
            raw.rm_data_source_free(lib[], ptr)
            raise Error(lib[].describe("rm_data_source init_copy failed", code))
        return Self(lib^, manager.copy(), ptr, existing._channels)

    def read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read up to frame_count frames; a short read means the end."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.rm_data_source_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("rm_data_source read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.rm_data_source_seek(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source seek failed", code))

    def data_format(self) raises -> DataFormat:
        var rc = raw.rm_data_source_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source data format failed", rc.result))
        return DataFormat(SampleFormat(rc.format), rc.channels, rc.sample_rate)

    def cursor(self) raises -> UInt64:
        var rc = raw.rm_data_source_get_cursor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source cursor failed", rc.result))
        return rc.value

    def length(self) raises -> UInt64:
        var rc = raw.rm_data_source_get_length(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source length failed", rc.result))
        return rc.value

    def available(self) raises -> UInt64:
        """Frames ready to read right now — the whole remainder once loaded."""
        var rc = raw.rm_data_source_get_available(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source available failed", rc.result))
        return rc.value

    def load_result(self) raises -> Int:
        """The raw ma_result the manager recorded for this object's load."""
        var rc = raw.rm_data_source_result(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source result failed", rc.result))
        return rc.value

    def set_looping(mut self, is_looping: Bool) raises:
        var code = raw.rm_data_source_set_looping(self._lib[], self._ptr, is_looping)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source set_looping failed", code))

    def is_looping(self) raises -> Bool:
        var rc = raw.rm_data_source_is_looping(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source is_looping failed", rc.result))
        return rc.value

    def map_read(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read through miniaudio's map/unmap pair instead of the read path."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=samples)
        buf.resize(samples, Float32(0))

        var rc = raw.rm_data_source_map_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("rm_data_source map_read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.rm_data_source_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("rm_data_source uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.rm_data_source_free(self._lib[], self._ptr)
