"""Binding layer: raw 1:1 wrappers over the sync / job / log / slot shim.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in sync.mojo.

Four small families that miniaudio builds everything else out of: the sync
primitives (mutex, event, semaphore, fence, and the two async notification
shapes), the job queue, the logger, and the slot allocator. All in-memory, so
all deterministic.

The waiting calls are bound as they are. Signal before you wait: an unsignalled
`event_wait` blocks forever, and so does `semaphore_wait` at a count of zero.

Two things need C the shim has to supply: `ma_log_register_callback` takes a
function pointer, so the shim owns a callback that counts messages, and
`ma_log_postv` takes a va_list, which the shim builds in a variadic wrapper.
`ma_job` has no safe Mojo home either, so the queue uses a shim-owned job slot.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt, MaBool, MaText
from miniaudio._ffi.resource_manager_raw import MaResultCode


# ---- ma_mutex ----


def mutex_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_mutex_alloc", OpaquePointer[MutUntrackedOrigin]]()


def mutex_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_mutex_free", NoneType](h)


def mutex_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_mutex_init", Int32](h))


def mutex_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_mutex_uninit", Int32](h))


def mutex_lock(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_mutex_lock", Int32](h))


def mutex_unlock(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_mutex_unlock", Int32](h))


# ---- ma_event ----


def event_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_event_alloc", OpaquePointer[MutUntrackedOrigin]]()


def event_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_event_free", NoneType](h)


def event_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_event_init", Int32](h))


def event_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_event_uninit", Int32](h))


def event_signal(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_event_signal", Int32](h))


def event_wait(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Blocks until signalled — signal first or this never returns."""
    return Int(lib.handle.call["ma_shim_event_wait", Int32](h))


# ---- ma_semaphore ----


def semaphore_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_semaphore_alloc", OpaquePointer[MutUntrackedOrigin]]()


def semaphore_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_semaphore_free", NoneType](h)


def semaphore_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], initial_value: Int) -> Int:
    return Int(lib.handle.call["ma_shim_semaphore_init", Int32](h, Int32(initial_value)))


def semaphore_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_semaphore_uninit", Int32](h))


def semaphore_release(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_semaphore_release", Int32](h))


def semaphore_wait(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Blocks until signalled — signal first or this never returns."""
    return Int(lib.handle.call["ma_shim_semaphore_wait", Int32](h))


# ---- ma_fence ----


def fence_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_fence_alloc", OpaquePointer[MutUntrackedOrigin]]()


def fence_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_fence_free", NoneType](h)


def fence_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_fence_init", Int32](h))


def fence_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_fence_uninit", Int32](h))


def fence_acquire(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_fence_acquire", Int32](h))


def fence_release(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_fence_release", Int32](h))


def fence_wait(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Blocks until signalled — signal first or this never returns."""
    return Int(lib.handle.call["ma_shim_fence_wait", Int32](h))


# ---- ma_async_notification_event ----


def async_event_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_async_event_alloc", OpaquePointer[MutUntrackedOrigin]]()


def async_event_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_async_event_free", NoneType](h)


def async_event_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_async_event_init", Int32](h))


def async_event_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_async_event_uninit", Int32](h))


def async_event_signal(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_async_event_signal", Int32](h))


def async_event_wait(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Blocks until signalled — signal first or this never returns."""
    return Int(lib.handle.call["ma_shim_async_event_wait", Int32](h))


# ---- ma_async_notification_poll ----


def async_poll_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_async_poll_alloc", OpaquePointer[MutUntrackedOrigin]]()


def async_poll_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_async_poll_free", NoneType](h)


def async_poll_init(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_async_poll_init", Int32](h))


def async_poll_is_signalled(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_async_poll_is_signalled", Int32](
            h, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != Int32(0))


def async_poll_signal(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Signals through the generic notification entry point."""
    return Int(lib.handle.call["ma_shim_async_poll_signal", Int32](h))


# ================= job queue =================


def job_queue_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_job_queue_alloc", OpaquePointer[MutUntrackedOrigin]]()


def job_queue_free(lib: MaLib, q: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_job_queue_free", NoneType](q)


def job_queue_get_heap_size(
    lib: MaLib, flags: UInt32 = 0, capacity: UInt32 = 16
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_job_queue_get_heap_size", Int32](
            flags, capacity, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def job_queue_init(
    lib: MaLib, q: OpaquePointer[MutUntrackedOrigin], flags: UInt32 = 0, capacity: UInt32 = 16
) -> Int:
    return Int(
        lib.handle.call["ma_shim_job_queue_init", Int32](q, flags, capacity)
    )


def job_queue_init_preallocated(
    lib: MaLib, q: OpaquePointer[MutUntrackedOrigin], flags: UInt32 = 0, capacity: UInt32 = 16
) -> Int:
    return Int(
        lib.handle.call["ma_shim_job_queue_init_preallocated", Int32](
            q, flags, capacity
        )
    )


def job_queue_uninit(lib: MaLib, q: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_job_queue_uninit", Int32](q))


def job_queue_post(lib: MaLib, q: OpaquePointer[MutUntrackedOrigin], job_code: UInt32) -> Int:
    """Builds a job of that type code and posts it."""
    return Int(lib.handle.call["ma_shim_job_queue_post", Int32](q, job_code))


def job_queue_next(lib: MaLib, q: OpaquePointer[MutUntrackedOrigin]) -> MaResultCode:
    """Pops a job into the shim's slot; the value is the job's type code."""
    var holder = [Int32(-1)]
    var code = Int(
        lib.handle.call["ma_shim_job_queue_next", Int32](q, holder.unsafe_ptr())
    )
    return MaResultCode(code, Int(holder[0]))


def job_queue_process(lib: MaLib, q: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Runs the job in the shim's slot."""
    return Int(lib.handle.call["ma_shim_job_queue_process", Int32](q))


# ================= log =================


def log_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_log_alloc", OpaquePointer[MutUntrackedOrigin]]()


def log_free(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_log_free", NoneType](lg)


def log_init(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_log_init", Int32](lg))


def log_uninit(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_log_uninit", Int32](lg))


def log_post(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin], level: UInt32, message: String) -> Int:
    var message_c = message + "\x00"
    return Int(
        lib.handle.call["ma_shim_log_post", Int32](
            lg, level, message_c.as_bytes().unsafe_ptr()
        )
    )


def log_postf(
    lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin], level: UInt32, format: String, arg: String
) -> Int:
    """`format` takes exactly one %s, filled with `arg`."""
    var format_c = format + "\x00"
    var arg_c = arg + "\x00"
    return Int(
        lib.handle.call["ma_shim_log_postf", Int32](
            lg, level, format_c.as_bytes().unsafe_ptr(), arg_c.as_bytes().unsafe_ptr()
        )
    )


def log_postv(
    lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin], level: UInt32, format: String, arg: String
) -> Int:
    """The va_list form, which the shim builds on this side of the boundary."""
    var format_c = format + "\x00"
    var arg_c = arg + "\x00"
    return Int(
        lib.handle.call["ma_shim_log_postv", Int32](
            lg, level, format_c.as_bytes().unsafe_ptr(), arg_c.as_bytes().unsafe_ptr()
        )
    )


def log_register_callback(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Registers the shim's counting callback."""
    return Int(lib.handle.call["ma_shim_log_register_callback", Int32](lg))


def log_unregister_callback(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_log_unregister_callback", Int32](lg))


def log_message_count(lib: MaLib, lg: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    """How many messages the registered callback has seen."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_log_message_count", Int32](
            lg, holder.unsafe_ptr()
        )
    )
    return MaUInt(code, holder[0])


def log_level_to_string(lib: MaLib, level: UInt32) -> MaText:
    var buf = List[UInt8](capacity=32)
    buf.resize(32, UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_log_level_to_string", Int32](
            level, buf.unsafe_ptr(), UInt32(32)
        )
    )
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


# ================= slot allocator =================


def slot_allocator_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_slot_allocator_alloc", OpaquePointer[MutUntrackedOrigin]]()


def slot_allocator_free(lib: MaLib, a: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_slot_allocator_free", NoneType](a)


def slot_allocator_get_heap_size(lib: MaLib, capacity: UInt32) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_slot_allocator_get_heap_size", Int32](
            capacity, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def slot_allocator_init(lib: MaLib, a: OpaquePointer[MutUntrackedOrigin], capacity: UInt32) -> Int:
    return Int(
        lib.handle.call["ma_shim_slot_allocator_init", Int32](a, capacity)
    )


def slot_allocator_init_preallocated(
    lib: MaLib, a: OpaquePointer[MutUntrackedOrigin], capacity: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_slot_allocator_init_preallocated", Int32](
            a, capacity
        )
    )


def slot_allocator_uninit(lib: MaLib, a: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_slot_allocator_uninit", Int32](a))


def slot_allocator_alloc_slot(lib: MaLib, a: OpaquePointer[MutUntrackedOrigin]) -> MaCount:
    """Claims a slot; the value is its index."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_slot_allocator_alloc_slot", Int32](
            a, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def slot_allocator_free_slot(lib: MaLib, a: OpaquePointer[MutUntrackedOrigin], slot: UInt64) -> Int:
    return Int(
        lib.handle.call["ma_shim_slot_allocator_free_slot", Int32](a, slot)
    )
