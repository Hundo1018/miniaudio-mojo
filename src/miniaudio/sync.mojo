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
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
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
    ) raises -> Self:
        var ptr = raw.mutex_alloc(lib[])
        if ptr == null_handle():
            raise Error("mutex_alloc failed (out of memory)")
        var code = raw.mutex_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.mutex_free(lib[], ptr)
            raise Error(lib[].describe("mutex init failed", code))
        return Self(lib.copy(), ptr)

    def lock(mut self) raises:
        """Take the lock."""
        var code = raw.mutex_lock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("mutex lock failed", code))

    def unlock(mut self) raises:
        """Release the lock."""
        var code = raw.mutex_unlock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("mutex unlock failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.mutex_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("mutex uninit failed", code))

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
    ) raises -> Self:
        var ptr = raw.event_alloc(lib[])
        if ptr == null_handle():
            raise Error("event_alloc failed (out of memory)")
        var code = raw.event_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.event_free(lib[], ptr)
            raise Error(lib[].describe("event init failed", code))
        return Self(lib.copy(), ptr)

    def signal(mut self) raises:
        """Wake anything waiting."""
        var code = raw.event_signal(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("event signal failed", code))

    def wait(mut self) raises:
        """Block until signalled. Signal first on a single thread."""
        var code = raw.event_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("event wait failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.event_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("event uninit failed", code))

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
    ) raises -> Self:
        var ptr = raw.semaphore_alloc(lib[])
        if ptr == null_handle():
            raise Error("semaphore_alloc failed (out of memory)")
        var code = raw.semaphore_init(lib[], ptr, initial_value)
        if code != MA_SUCCESS:
            raw.semaphore_free(lib[], ptr)
            raise Error(lib[].describe("semaphore init failed", code))
        return Self(lib.copy(), ptr)

    def release(mut self) raises:
        """Raise the count by one."""
        var code = raw.semaphore_release(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("semaphore release failed", code))

    def wait(mut self) raises:
        """Take one from the count, blocking while it is zero."""
        var code = raw.semaphore_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("semaphore wait failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.semaphore_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("semaphore uninit failed", code))

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
    ) raises -> Self:
        var ptr = raw.fence_alloc(lib[])
        if ptr == null_handle():
            raise Error("fence_alloc failed (out of memory)")
        var code = raw.fence_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.fence_free(lib[], ptr)
            raise Error(lib[].describe("fence init failed", code))
        return Self(lib.copy(), ptr)

    def acquire(mut self) raises:
        """Raise the counter by one."""
        var code = raw.fence_acquire(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fence acquire failed", code))

    def release(mut self) raises:
        """Lower the counter by one."""
        var code = raw.fence_release(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fence release failed", code))

    def wait(mut self) raises:
        """Return once the counter is back to zero."""
        var code = raw.fence_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fence wait failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.fence_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("fence uninit failed", code))

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
    ) raises -> Self:
        var ptr = raw.async_event_alloc(lib[])
        if ptr == null_handle():
            raise Error("async_event_alloc failed (out of memory)")
        var code = raw.async_event_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.async_event_free(lib[], ptr)
            raise Error(lib[].describe("async_event init failed", code))
        return Self(lib.copy(), ptr)

    def signal(mut self) raises:
        """Wake anything waiting."""
        var code = raw.async_event_signal(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("async_event signal failed", code))

    def wait(mut self) raises:
        """Block until signalled."""
        var code = raw.async_event_wait(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("async_event wait failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.async_event_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("async_event uninit failed", code))

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
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        var ptr = raw.async_poll_alloc(lib[])
        if ptr == null_handle():
            raise Error("async_poll_alloc failed (out of memory)")
        var code = raw.async_poll_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.async_poll_free(lib[], ptr)
            raise Error(lib[].describe("async poll init failed", code))
        return Self(lib.copy(), ptr)

    def signal(mut self) raises:
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
            raise Error(self._lib[].describe("async poll signal failed", code))

    def is_signalled(self) raises -> Bool:
        var rc = raw.async_poll_is_signalled(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("async poll is_signalled failed", rc.result)
            )
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
    ) raises -> UInt64:
        var rc = raw.job_queue_get_heap_size(lib[], flags, capacity)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("job queue heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        flags: UInt32 = 0,
        capacity: UInt32 = 16,
        preallocated: Bool = False,
    ) raises -> Self:
        var ptr = raw.job_queue_alloc(lib[])
        if ptr == null_handle():
            raise Error("job_queue_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.job_queue_init_preallocated(lib[], ptr, flags, capacity)
        else:
            code = raw.job_queue_init(lib[], ptr, flags, capacity)
        if code != MA_SUCCESS:
            raw.job_queue_free(lib[], ptr)
            raise Error(lib[].describe("job queue init failed", code))
        return Self(lib.copy(), ptr)

    def post(mut self, job_code: UInt32) raises:
        """Build a job of that type code and queue it."""
        var code = raw.job_queue_post(self._lib[], self._ptr, job_code)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("job queue post failed", code))

    def next_job(mut self) raises -> Int:
        """Pop a job into the slot and return the raw ma_result.

        MA_CANCELLED means the job is a quit job — a label, not a failure.
        """
        return raw.job_queue_next(self._lib[], self._ptr).result

    def next_job_type(mut self) raises -> Int:
        """The type code of the job just popped into the slot."""
        return raw.job_queue_next(self._lib[], self._ptr).value

    def process(mut self) raises -> Int:
        """Run the job in the slot; returns the raw ma_result."""
        return raw.job_queue_process(self._lib[], self._ptr)

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.job_queue_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("job queue uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.job_queue_free(self._lib[], self._ptr)


struct Log(Movable):
    """miniaudio's logger (RAII).

    A log callback has to be a C function, so the shim owns one that counts the
    messages it is handed. `message_count` is how a registered callback becomes
    observable from Mojo.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        var ptr = raw.log_alloc(lib[])
        if ptr == null_handle():
            raise Error("log_alloc failed (out of memory)")
        var code = raw.log_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.log_free(lib[], ptr)
            raise Error(lib[].describe("log init failed", code))
        return Self(lib.copy(), ptr)

    @staticmethod
    def level_name(lib: ArcPointer[MaLib], level: UInt32) raises -> String:
        """miniaudio's own name for a log level."""
        var rc = raw.log_level_to_string(lib[], level)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("log level_to_string failed", rc.result))
        return rc.value

    def post(mut self, message: String, *, level: UInt32 = LOG_LEVEL_INFO) raises:
        var code = raw.log_post(self._lib[], self._ptr, level, message)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("log post failed", code))

    def postf(
        mut self, format: String, arg: String, *, level: UInt32 = LOG_LEVEL_INFO
    ) raises:
        """`format` takes exactly one %s, filled with `arg`."""
        var code = raw.log_postf(self._lib[], self._ptr, level, format, arg)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("log postf failed", code))

    def postv(
        mut self, format: String, arg: String, *, level: UInt32 = LOG_LEVEL_INFO
    ) raises:
        """The va_list form; the shim builds the va_list on the C side."""
        var code = raw.log_postv(self._lib[], self._ptr, level, format, arg)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("log postv failed", code))

    def register_callback(mut self) raises:
        """Attach the shim's counting callback."""
        var code = raw.log_register_callback(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("log register_callback failed", code))

    def unregister_callback(mut self) raises:
        var code = raw.log_unregister_callback(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("log unregister_callback failed", code)
            )

    def message_count(self) raises -> UInt32:
        """How many messages the registered callback has seen."""
        var rc = raw.log_message_count(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("log message_count failed", rc.result))
        return rc.value

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.log_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("log uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.log_free(self._lib[], self._ptr)


struct SlotAllocator(Movable):
    """The lock-free slot allocator behind the job queue (RAII)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def heap_size(lib: ArcPointer[MaLib], *, capacity: UInt32 = 16) raises -> UInt64:
        var rc = raw.slot_allocator_get_heap_size(lib[], capacity)
        if rc.result != MA_SUCCESS:
            raise Error(lib[].describe("slot allocator heap size failed", rc.result))
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib], *, capacity: UInt32 = 16, preallocated: Bool = False
    ) raises -> Self:
        var ptr = raw.slot_allocator_alloc(lib[])
        if ptr == null_handle():
            raise Error("slot_allocator_alloc failed (out of memory)")

        var code: Int
        if preallocated:
            code = raw.slot_allocator_init_preallocated(lib[], ptr, capacity)
        else:
            code = raw.slot_allocator_init(lib[], ptr, capacity)
        if code != MA_SUCCESS:
            raw.slot_allocator_free(lib[], ptr)
            raise Error(lib[].describe("slot allocator init failed", code))
        return Self(lib.copy(), ptr)

    def claim(mut self) raises -> UInt64:
        """Claim a slot and return its index."""
        var rc = raw.slot_allocator_alloc_slot(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("slot allocator alloc failed", rc.result)
            )
        return rc.value

    def release(mut self, slot: UInt64) raises:
        """Give a slot back."""
        var code = raw.slot_allocator_free_slot(self._lib[], self._ptr, slot)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("slot allocator free failed", code))

    def uninit(mut self) raises:
        """Release early; the handle stays valid but empty."""
        var code = raw.slot_allocator_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("slot allocator uninit failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.slot_allocator_free(self._lib[], self._ptr)
