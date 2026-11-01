"""Idiomatic synchronisation, job, log and slot-allocator API (Layer 3).

The small building blocks miniaudio uses internally, wrapped as RAII types:

- `Mutex`, `Event`, `Semaphore`, `Fence` — the sync primitives.
- `AsyncPoll` / `AsyncEvent` — the two notification shapes, one polled and one
  waited on.
- `JobQueue` — the queue behind the resource manager and the device.
- `Log` — the logger, with the shim's counting callback standing in for one
  Mojo cannot provide.
- `SlotAllocator` — the lock-free slot allocator behind the job queue.

All of them are in-memory, so none needs a device or a file.

**The waiting calls really wait.** `Event.wait` on an unsignalled event and
`Semaphore.wait` at a count of zero both block forever on the calling thread.
Signal or release first — that is how the tests here use them.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.engine import Engine
from miniaudio.result import MaResult, MaError, MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.sync_raw as raw


comptime LOG_LEVEL_ERROR = UInt32(1)
comptime LOG_LEVEL_WARNING = UInt32(2)
comptime LOG_LEVEL_INFO = UInt32(3)
comptime LOG_LEVEL_DEBUG = UInt32(4)


struct Mutex(Movable):
    """A mutual-exclusion lock (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib]
    ) raises MaError -> Self:
        var ptr = raw.mutex_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "mutex_alloc failed (out of memory)")
        var code = raw.mutex_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.mutex_free(lib[], ptr)
            raise lib[].error("mutex init failed", code)
        return Self(lib.copy(), ptr)

    def lock(mut self) raises MaError:
        """Take the lock."""
        var code = raw.mutex_lock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("mutex lock failed", code)

    def unlock(mut self) raises MaError:
        """Release the lock."""
        var code = raw.mutex_unlock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("mutex unlock failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.mutex_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("mutex uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.mutex_free(self._lib[], self._ptr)


struct Event(Movable):
    """A one-shot signal other threads can wait on (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib]
    ) raises MaError -> Self:
        var ptr = raw.event_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "event_alloc failed (out of memory)")
        var code = raw.event_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.event_free(lib[], ptr)
            raise lib[].error("event init failed", code)
        return Self(lib.copy(), ptr)

    def signal(mut self) raises MaError:
        """Wake anything waiting."""
        var code = raw.event_signal(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("event signal failed", code)

    def wait(mut self) raises MaError:
        """Block until signalled. Signal first on a single thread."""
        var code = raw.event_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("event wait failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.event_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("event uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.event_free(self._lib[], self._ptr)


struct Semaphore(Movable):
    """A counting semaphore (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        initial_value: Int = 0
    ) raises MaError -> Self:
        var ptr = raw.semaphore_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "semaphore_alloc failed (out of memory)")
        var code = raw.semaphore_init(lib[], ptr, initial_value)
        if code != MA_SUCCESS:
            raw.semaphore_free(lib[], ptr)
            raise lib[].error("semaphore init failed", code)
        return Self(lib.copy(), ptr)

    def release(mut self) raises MaError:
        """Raise the count by one."""
        var code = raw.semaphore_release(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("semaphore release failed", code)

    def wait(mut self) raises MaError:
        """Take one from the count, blocking while it is zero."""
        var code = raw.semaphore_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("semaphore wait failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.semaphore_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("semaphore uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.semaphore_free(self._lib[], self._ptr)


struct Fence(Movable):
    """A counter other work can wait to reach zero (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib]
    ) raises MaError -> Self:
        var ptr = raw.fence_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "fence_alloc failed (out of memory)")
        var code = raw.fence_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.fence_free(lib[], ptr)
            raise lib[].error("fence init failed", code)
        return Self(lib.copy(), ptr)

    def acquire(mut self) raises MaError:
        """Raise the counter by one."""
        var code = raw.fence_acquire(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("fence acquire failed", code)

    def release(mut self) raises MaError:
        """Lower the counter by one."""
        var code = raw.fence_release(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("fence release failed", code)

    def wait(mut self) raises MaError:
        """Return once the counter is back to zero."""
        var code = raw.fence_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("fence wait failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.fence_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("fence uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.fence_free(self._lib[], self._ptr)


struct AsyncEvent(Movable):
    """A notification that can be waited on (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib]
    ) raises MaError -> Self:
        var ptr = raw.async_event_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "async_event_alloc failed (out of memory)")
        var code = raw.async_event_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.async_event_free(lib[], ptr)
            raise lib[].error("async_event init failed", code)
        return Self(lib.copy(), ptr)

    def signal(mut self) raises MaError:
        """Wake anything waiting."""
        var code = raw.async_event_signal(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("async_event signal failed", code)

    def wait(mut self) raises MaError:
        """Block until signalled."""
        var code = raw.async_event_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("async_event wait failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.async_event_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("async_event uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.async_event_free(self._lib[], self._ptr)


struct AsyncPoll(Movable):
    """A notification you check rather than wait on (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises MaError -> Self:
        var ptr = raw.async_poll_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "async_poll_alloc failed (out of memory)")
        var code = raw.async_poll_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.async_poll_free(lib[], ptr)
            raise lib[].error("async poll init failed", code)
        return Self(lib.copy(), ptr)

    def signal(mut self) raises MaError:
        """Signal through miniaudio's generic notification entry point.

        Upstream bug (miniaudio 0.11.25): ma_async_notification_signal fires the
        callback and *then* returns MA_INVALID_ARGS — its success path returns an
        error code. The signal really does land, so this deliberately does not
        raise on MA_INVALID_ARGS; raising would make the call unusable for the
        one thing it does. The raw layer still reports the code unchanged, and
        the binding tests pin it. Remove this once upstream returns MA_SUCCESS.
        """
        var code = raw.async_poll_signal(self._lib[], self._ptr)
        if code != MA_SUCCESS and code != MA_INVALID_ARGS:
            raise self._lib[].error("async poll signal failed", code)

    def is_signalled(self) raises MaError -> Bool:
        var rc = raw.async_poll_is_signalled(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("async poll is_signalled failed", rc.result)
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.async_poll_free(self._lib[], self._ptr)


struct JobQueue(Movable):
    """The job queue miniaudio's asynchronous work runs through (RAII).

    `ma_job` has no safe Mojo home, so the queue works through a slot the shim
    keeps: `post` builds and queues a job of a given type, `next` pops one into
    the slot and reports its type, `process` runs what is in the slot.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib], *, flags: UInt32 = 0, capacity: UInt32 = 16
    ) raises MaError -> UInt64:
        var rc = raw.job_queue_get_heap_size(lib[], flags, capacity)
        if rc.result != MA_SUCCESS:
            raise lib[].error("job queue heap size failed", rc.result)
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        flags: UInt32 = 0,
        capacity: UInt32 = 16,
        preallocated: Bool = False,
    ) raises MaError -> Self:
        var ptr = raw.job_queue_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "job_queue_alloc failed (out of memory)")

        var code: MaResult
        if preallocated:
            code = raw.job_queue_init_preallocated(lib[], ptr, flags, capacity)
        else:
            code = raw.job_queue_init(lib[], ptr, flags, capacity)
        if code != MA_SUCCESS:
            raw.job_queue_free(lib[], ptr)
            raise lib[].error("job queue init failed", code)
        return Self(lib.copy(), ptr)

    def post(mut self, job_code: UInt32) raises MaError:
        """Build a job of that type code and queue it."""
        var code = raw.job_queue_post(self._lib[], self._ptr, job_code)
        if code != MA_SUCCESS:
            raise self._lib[].error("job queue post failed", code)

    def next_job(mut self) raises MaError -> MaResult:
        """Pop a job into the slot and return the raw ma_result.

        MA_CANCELLED means the job is a quit job — a label, not a failure.
        """
        return raw.job_queue_next(self._lib[], self._ptr).result

    def next_job_type(mut self) raises MaError -> Int:
        """The type code of the job just popped into the slot."""
        return raw.job_queue_next(self._lib[], self._ptr).value

    def process(mut self) raises MaError -> MaResult:
        """Run the job in the slot; returns the raw ma_result."""
        return raw.job_queue_process(self._lib[], self._ptr)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.job_queue_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("job queue uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.job_queue_free(self._lib[], self._ptr)


struct Log(Movable):
    """miniaudio's logger (RAII).

    A log callback has to be a C function, so the shim owns one that counts the
    messages it is handed. `message_count` is how a registered callback becomes
    observable from Mojo.

    `Log.of_engine` is a *borrowed* view of the log an engine uses: it posts to,
    and registers its callback on, the engine's own log, and dropping it takes
    the callback back off and leaves the log alone. It keeps the engine alive for
    as long as it exists.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _owner: Optional[ArcPointer[Engine]]  # set for a borrowed view of an engine's log

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr
        self._owner = None

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises MaError -> Self:
        var ptr = raw.log_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "log_alloc failed (out of memory)")
        var code = raw.log_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.log_free(lib[], ptr)
            raise lib[].error("log init failed", code)
        return Self(lib.copy(), ptr)

    @staticmethod
    def of_engine(engine: ArcPointer[Engine]) raises MaError -> Self:
        """A non-owning view of the log the engine uses (ma_engine_get_log)."""
        var lib = engine[]._lib.copy()
        var ptr = raw.log_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "log_alloc failed (out of memory)")
        var code = raw.log_borrow_engine(lib[], ptr, engine[]._ptr)
        if code != MA_SUCCESS:
            raw.log_free(lib[], ptr)
            raise lib[].error("engine log borrow failed", code)
        var view = Self(lib^, ptr)
        view._owner = engine.copy()
        return view^

    @staticmethod
    def level_name(lib: ArcPointer[MaLib], level: UInt32) raises MaError -> String:
        """miniaudio's own name for a log level."""
        var rc = raw.log_level_to_string(lib[], level)
        if rc.result != MA_SUCCESS:
            raise lib[].error("log level_to_string failed", rc.result)
        return rc.value

    def post(mut self, message: String, *, level: UInt32 = LOG_LEVEL_INFO) raises MaError:
        var code = raw.log_post(self._lib[], self._ptr, level, message)
        if code != MA_SUCCESS:
            raise self._lib[].error("log post failed", code)

    def postf(
        mut self, format: String, arg: String, *, level: UInt32 = LOG_LEVEL_INFO
    ) raises MaError:
        """`format` takes exactly one %s, filled with `arg`."""
        var code = raw.log_postf(self._lib[], self._ptr, level, format, arg)
        if code != MA_SUCCESS:
            raise self._lib[].error("log postf failed", code)

    def postv(
        mut self, format: String, arg: String, *, level: UInt32 = LOG_LEVEL_INFO
    ) raises MaError:
        """The va_list form; the shim builds the va_list on the C side."""
        var code = raw.log_postv(self._lib[], self._ptr, level, format, arg)
        if code != MA_SUCCESS:
            raise self._lib[].error("log postv failed", code)

    def register_callback(mut self) raises MaError:
        """Attach the shim's counting callback."""
        var code = raw.log_register_callback(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("log register_callback failed", code)

    def unregister_callback(mut self) raises MaError:
        var code = raw.log_unregister_callback(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("log unregister_callback failed", code)

    def message_count(self) raises MaError -> UInt32:
        """How many messages the registered callback has seen."""
        var rc = raw.log_message_count(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("log message_count failed", rc.result)
        return rc.value

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.log_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("log uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.log_free(self._lib[], self._ptr)
        # Fields not named above are dropped before the body runs; release the
        # keep-alive references only after the handle is freed.
        _ = self._owner^


struct SlotAllocator(Movable):
    """The lock-free slot allocator behind the job queue (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def heap_size(lib: ArcPointer[MaLib], *, capacity: UInt32 = 16) raises MaError -> UInt64:
        var rc = raw.slot_allocator_get_heap_size(lib[], capacity)
        if rc.result != MA_SUCCESS:
            raise lib[].error("slot allocator heap size failed", rc.result)
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib], *, capacity: UInt32 = 16, preallocated: Bool = False
    ) raises MaError -> Self:
        var ptr = raw.slot_allocator_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "slot_allocator_alloc failed (out of memory)")

        var code: MaResult
        if preallocated:
            code = raw.slot_allocator_init_preallocated(lib[], ptr, capacity)
        else:
            code = raw.slot_allocator_init(lib[], ptr, capacity)
        if code != MA_SUCCESS:
            raw.slot_allocator_free(lib[], ptr)
            raise lib[].error("slot allocator init failed", code)
        return Self(lib.copy(), ptr)

    def claim(mut self) raises MaError -> UInt64:
        """Claim a slot and return its index."""
        var rc = raw.slot_allocator_alloc_slot(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("slot allocator alloc failed", rc.result)
        return rc.value

    def release(mut self, slot: UInt64) raises MaError:
        """Give a slot back."""
        var code = raw.slot_allocator_free_slot(self._lib[], self._ptr, slot)
        if code != MA_SUCCESS:
            raise self._lib[].error("slot allocator free failed", code)

    def uninit(mut self) raises MaError:
        """Release early; the handle stays valid but empty."""
        var code = raw.slot_allocator_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("slot allocator uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.slot_allocator_free(self._lib[], self._ptr)
