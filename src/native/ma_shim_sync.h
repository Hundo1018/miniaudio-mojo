#ifndef MA_SHIM_SYNC_H
#define MA_SHIM_SYNC_H

/* ---- synchronisation, jobs, logging and slot allocation ----
 *
 * Four small families that miniaudio builds everything else out of:
 *
 *   sync            — mutex, event, semaphore, fence and the two async
 *                     notification shapes (poll and event)
 *   job_queue       — the queue the resource manager and device use
 *   log             — the logger and its callbacks
 *   slot_allocator  — the lock-free slot allocator behind the job queue
 *
 * All of them are in-memory, so the whole group is deterministic. The waiting
 * calls are all bound, and the tests always signal before they wait so nothing
 * blocks: `ma_event_wait` after a signal, `ma_semaphore_wait` after a release,
 * `ma_fence_wait` on a fence whose counter is already back at zero.
 *
 * Two places need a C function that Mojo cannot supply:
 *   - `ma_log_register_callback` takes a callback. The shim owns one that
 *     counts the messages it sees, so registering, posting and unregistering
 *     are all observable from Mojo as a count.
 *   - `ma_log_postv` takes a va_list. The shim wraps it in a variadic function
 *     that forwards a single string argument, so the format path is reachable.
 *
 * `ma_job` has no safe Mojo home either, so the job queue uses the same single
 * job slot the resource manager shim does: post builds a job, next pops one
 * into the slot and reports its type, and process runs what is in the slot.
 *
 * Log levels match ma_log_level: debug=4, info=3, warning=2, error=1.
 *
 * NOTE on ma_async_notification_signal (miniaudio 0.11.25): it fires the
 * notification's callback and then returns MA_INVALID_ARGS — the success path
 * returns an error code. The signal lands regardless. The shim passes the code
 * through unchanged; the Mojo API layer is where that quirk is absorbed.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= sync primitives ================= */

void* ma_shim_mutex_alloc(void);
void  ma_shim_mutex_free(void* handle);
int   ma_shim_mutex_init(void* handle);
int   ma_shim_mutex_uninit(void* handle);
int   ma_shim_mutex_lock(void* handle);
int   ma_shim_mutex_unlock(void* handle);

void* ma_shim_event_alloc(void);
void  ma_shim_event_free(void* handle);
int   ma_shim_event_init(void* handle);
int   ma_shim_event_uninit(void* handle);
int   ma_shim_event_signal(void* handle);
/* Only safe after a signal; an unsignalled event blocks forever. */
int   ma_shim_event_wait(void* handle);

void* ma_shim_semaphore_alloc(void);
void  ma_shim_semaphore_free(void* handle);
int   ma_shim_semaphore_init(void* handle, int initial_value);
int   ma_shim_semaphore_uninit(void* handle);
int   ma_shim_semaphore_release(void* handle);
/* Only safe while the count is above zero. */
int   ma_shim_semaphore_wait(void* handle);

void* ma_shim_fence_alloc(void);
void  ma_shim_fence_free(void* handle);
int   ma_shim_fence_init(void* handle);
int   ma_shim_fence_uninit(void* handle);
int   ma_shim_fence_acquire(void* handle);
int   ma_shim_fence_release(void* handle);
/* Returns once the counter is back to zero. */
int   ma_shim_fence_wait(void* handle);

void* ma_shim_async_poll_alloc(void);
void  ma_shim_async_poll_free(void* handle);
int   ma_shim_async_poll_init(void* handle);
int   ma_shim_async_poll_is_signalled(void* handle, int* out_signalled);
/* Signals the poll notification through the generic notification entry point. */
int   ma_shim_async_poll_signal(void* handle);

void* ma_shim_async_event_alloc(void);
void  ma_shim_async_event_free(void* handle);
int   ma_shim_async_event_init(void* handle);
int   ma_shim_async_event_uninit(void* handle);
int   ma_shim_async_event_signal(void* handle);
int   ma_shim_async_event_wait(void* handle);

/* ================= job queue ================= */

void* ma_shim_job_queue_alloc(void);
void  ma_shim_job_queue_free(void* handle);

int ma_shim_job_queue_get_heap_size(
    unsigned int flags, unsigned int capacity, unsigned long long* out_heap_size);
int ma_shim_job_queue_init(void* handle, unsigned int flags, unsigned int capacity);
int ma_shim_job_queue_init_preallocated(
    void* handle, unsigned int flags, unsigned int capacity);
int ma_shim_job_queue_uninit(void* handle);

/* Builds a job of the given type code and posts it. */
int ma_shim_job_queue_post(void* handle, unsigned int job_code);
/* Pops the next job into the handle's slot and reports its type. */
int ma_shim_job_queue_next(void* handle, int* out_job_type);
/* Runs the job currently in the slot. */
int ma_shim_job_queue_process(void* handle);

/* ================= log ================= */

void* ma_shim_log_alloc(void);
void  ma_shim_log_free(void* handle);
int   ma_shim_log_init(void* handle);
int   ma_shim_log_uninit(void* handle);

/* Make a log handle (ma_shim_log_alloc) a non-owning view of the engine's own
 * log. Posting and callbacks then act on that log; freeing or uninitialising the
 * view unregisters its callback and leaves the log alone. The engine must
 * outlive the view. Fails if the engine has no log. */
int   ma_shim_log_borrow_engine(void* handle, void* engine_handle);

int ma_shim_log_post(void* handle, unsigned int level, const char* message);
int ma_shim_log_postf(void* handle, unsigned int level, const char* format, const char* arg);
int ma_shim_log_postv(void* handle, unsigned int level, const char* format, const char* arg);

/* Registers the shim's counting callback; the count is what Mojo observes. */
int ma_shim_log_register_callback(void* handle);
int ma_shim_log_unregister_callback(void* handle);
int ma_shim_log_message_count(void* handle, unsigned int* out_count);

int ma_shim_log_level_to_string(unsigned int level, char* out_text, unsigned int capacity);

/* ================= slot allocator ================= */

void* ma_shim_slot_allocator_alloc(void);
void  ma_shim_slot_allocator_free(void* handle);

int ma_shim_slot_allocator_get_heap_size(
    unsigned int capacity, unsigned long long* out_heap_size);
int ma_shim_slot_allocator_init(void* handle, unsigned int capacity);
int ma_shim_slot_allocator_init_preallocated(void* handle, unsigned int capacity);
int ma_shim_slot_allocator_uninit(void* handle);
int ma_shim_slot_allocator_alloc_slot(void* handle, unsigned long long* out_slot);
int ma_shim_slot_allocator_free_slot(void* handle, unsigned long long slot);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SYNC_H */
