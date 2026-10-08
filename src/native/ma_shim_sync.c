#include "ma_shim_sync.h"
#include "ma_shim_internal.h"
#include "miniaudio.h"

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/* Every handle in this file is "an object plus an initialised flag", so the
 * plumbing is generated once per type and the exported entry points are still
 * written out individually to carry their `@binds`. */
#define MA_SHIM_SYNC_HANDLE(NAME, TYPE)                                           \
    typedef struct ma_shim_##NAME##_state {                                       \
        TYPE obj;                                                                 \
        int  initialized;                                                         \
    } ma_shim_##NAME##_state;                                                     \
                                                                                  \
    static ma_shim_##NAME##_state* NAME##_ready(void* handle) {                   \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;              \
        if (h == NULL || !h->initialized) {                                       \
            return NULL;                                                          \
        }                                                                         \
        return h;                                                                 \
    }                                                                             \
                                                                                  \
    static void* NAME##_alloc_state(void) {                                       \
        return calloc(1, sizeof(ma_shim_##NAME##_state));                         \
    }

MA_SHIM_SYNC_HANDLE(mutex, ma_mutex)
MA_SHIM_SYNC_HANDLE(event, ma_event)
MA_SHIM_SYNC_HANDLE(semaphore, ma_semaphore)
MA_SHIM_SYNC_HANDLE(fence, ma_fence)
MA_SHIM_SYNC_HANDLE(async_poll, ma_async_notification_poll)
MA_SHIM_SYNC_HANDLE(async_event, ma_async_notification_event)
MA_SHIM_SYNC_HANDLE(slot_allocator, ma_slot_allocator)

/* ---- mutex ---- */

void* ma_shim_mutex_alloc(void) { return mutex_alloc_state(); }

/* @binds ma_mutex_uninit */
void ma_shim_mutex_free(void* handle) {
    ma_shim_mutex_state* h = (ma_shim_mutex_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_mutex_uninit(&h->obj); }
    free(h);
}

/* @binds ma_mutex_init */
int ma_shim_mutex_init(void* handle) {
    ma_shim_mutex_state* h = (ma_shim_mutex_state*)handle;
    ma_result            result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_mutex_uninit(&h->obj); h->initialized = 0; }
    result = ma_mutex_init(&h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_mutex_uninit */
int ma_shim_mutex_uninit(void* handle) {
    ma_shim_mutex_state* h = (ma_shim_mutex_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_mutex_uninit(&h->obj); h->initialized = 0; }
    return MA_SUCCESS;
}

/* @binds ma_mutex_lock */
int ma_shim_mutex_lock(void* handle) {
    ma_shim_mutex_state* h = mutex_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    ma_mutex_lock(&h->obj);
    return MA_SUCCESS;
}

/* @binds ma_mutex_unlock */
int ma_shim_mutex_unlock(void* handle) {
    ma_shim_mutex_state* h = mutex_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    ma_mutex_unlock(&h->obj);
    return MA_SUCCESS;
}

/* ---- event ---- */

void* ma_shim_event_alloc(void) { return event_alloc_state(); }

/* @binds ma_event_uninit */
void ma_shim_event_free(void* handle) {
    ma_shim_event_state* h = (ma_shim_event_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_event_uninit(&h->obj); }
    free(h);
}

/* @binds ma_event_init */
int ma_shim_event_init(void* handle) {
    ma_shim_event_state* h = (ma_shim_event_state*)handle;
    ma_result            result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_event_uninit(&h->obj); h->initialized = 0; }
    result = ma_event_init(&h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_event_uninit */
int ma_shim_event_uninit(void* handle) {
    ma_shim_event_state* h = (ma_shim_event_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_event_uninit(&h->obj); h->initialized = 0; }
    return MA_SUCCESS;
}

/* @binds ma_event_signal */
int ma_shim_event_signal(void* handle) {
    ma_shim_event_state* h = event_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_event_signal(&h->obj);
}

/* @binds ma_event_wait */
int ma_shim_event_wait(void* handle) {
    ma_shim_event_state* h = event_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_event_wait(&h->obj);
}

/* ---- semaphore ---- */

void* ma_shim_semaphore_alloc(void) { return semaphore_alloc_state(); }

/* @binds ma_semaphore_uninit */
void ma_shim_semaphore_free(void* handle) {
    ma_shim_semaphore_state* h = (ma_shim_semaphore_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_semaphore_uninit(&h->obj); }
    free(h);
}

/* @binds ma_semaphore_init */
int ma_shim_semaphore_init(void* handle, int initial_value) {
    ma_shim_semaphore_state* h = (ma_shim_semaphore_state*)handle;
    ma_result                result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_semaphore_uninit(&h->obj); h->initialized = 0; }
    result = ma_semaphore_init(initial_value, &h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_semaphore_uninit */
int ma_shim_semaphore_uninit(void* handle) {
    ma_shim_semaphore_state* h = (ma_shim_semaphore_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_semaphore_uninit(&h->obj); h->initialized = 0; }
    return MA_SUCCESS;
}

/* @binds ma_semaphore_release */
int ma_shim_semaphore_release(void* handle) {
    ma_shim_semaphore_state* h = semaphore_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_semaphore_release(&h->obj);
}

/* @binds ma_semaphore_wait */
int ma_shim_semaphore_wait(void* handle) {
    ma_shim_semaphore_state* h = semaphore_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_semaphore_wait(&h->obj);
}

/* ---- fence ---- */

void* ma_shim_fence_alloc(void) { return fence_alloc_state(); }

/* @binds ma_fence_uninit */
void ma_shim_fence_free(void* handle) {
    ma_shim_fence_state* h = (ma_shim_fence_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_fence_uninit(&h->obj); }
    free(h);
}

/* @binds ma_fence_init */
int ma_shim_fence_init(void* handle) {
    ma_shim_fence_state* h = (ma_shim_fence_state*)handle;
    ma_result            result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_fence_uninit(&h->obj); h->initialized = 0; }
    result = ma_fence_init(&h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_fence_uninit */
int ma_shim_fence_uninit(void* handle) {
    ma_shim_fence_state* h = (ma_shim_fence_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_fence_uninit(&h->obj); h->initialized = 0; }
    return MA_SUCCESS;
}

/* @binds ma_fence_acquire */
int ma_shim_fence_acquire(void* handle) {
    ma_shim_fence_state* h = fence_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_fence_acquire(&h->obj);
}

/* @binds ma_fence_release */
int ma_shim_fence_release(void* handle) {
    ma_shim_fence_state* h = fence_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_fence_release(&h->obj);
}

/* @binds ma_fence_wait */
int ma_shim_fence_wait(void* handle) {
    ma_shim_fence_state* h = fence_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_fence_wait(&h->obj);
}

/* ---- async notification: poll ---- */

void* ma_shim_async_poll_alloc(void) { return async_poll_alloc_state(); }

void ma_shim_async_poll_free(void* handle) { free(handle); }

/* @binds ma_async_notification_poll_init */
int ma_shim_async_poll_init(void* handle) {
    ma_shim_async_poll_state* h = (ma_shim_async_poll_state*)handle;
    ma_result                 result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    result = ma_async_notification_poll_init(&h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_async_notification_poll_is_signalled */
int ma_shim_async_poll_is_signalled(void* handle, int* out_signalled) {
    ma_shim_async_poll_state* h = async_poll_ready(handle);
    if (out_signalled != NULL) { *out_signalled = 0; }
    if (h == NULL || out_signalled == NULL) { return MA_INVALID_ARGS; }
    *out_signalled = ma_async_notification_poll_is_signalled(&h->obj) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_async_notification_signal */
int ma_shim_async_poll_signal(void* handle) {
    ma_shim_async_poll_state* h = async_poll_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    /* The generic entry point, which dispatches on the notification's vtable. */
    return (int)ma_async_notification_signal(&h->obj);
}

/* ---- async notification: event ---- */

void* ma_shim_async_event_alloc(void) { return async_event_alloc_state(); }

/* @binds ma_async_notification_event_uninit */
void ma_shim_async_event_free(void* handle) {
    ma_shim_async_event_state* h = (ma_shim_async_event_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_async_notification_event_uninit(&h->obj); }
    free(h);
}

/* @binds ma_async_notification_event_init */
int ma_shim_async_event_init(void* handle) {
    ma_shim_async_event_state* h = (ma_shim_async_event_state*)handle;
    ma_result                  result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) {
        ma_async_notification_event_uninit(&h->obj);
        h->initialized = 0;
    }
    result = ma_async_notification_event_init(&h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_async_notification_event_uninit */
int ma_shim_async_event_uninit(void* handle) {
    ma_shim_async_event_state* h = (ma_shim_async_event_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) {
        ma_async_notification_event_uninit(&h->obj);
        h->initialized = 0;
    }
    return MA_SUCCESS;
}

/* @binds ma_async_notification_event_signal */
int ma_shim_async_event_signal(void* handle) {
    ma_shim_async_event_state* h = async_event_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_async_notification_event_signal(&h->obj);
}

/* @binds ma_async_notification_event_wait */
int ma_shim_async_event_wait(void* handle) {
    ma_shim_async_event_state* h = async_event_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_async_notification_event_wait(&h->obj);
}

/* ================= job queue ================= */

typedef struct ma_shim_job_queue_state {
    ma_job_queue queue;
    ma_job       job;
    void*        heap;
    int          has_job;
    int          initialized;
} ma_shim_job_queue_state;

static void job_queue_teardown(ma_shim_job_queue_state* h) {
    if (h->initialized) {
        ma_job_queue_uninit(&h->queue, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
    h->has_job = 0;
}

static ma_shim_job_queue_state* job_queue_ready(void* handle) {
    ma_shim_job_queue_state* h = (ma_shim_job_queue_state*)handle;
    if (h == NULL || !h->initialized) { return NULL; }
    return h;
}

void* ma_shim_job_queue_alloc(void) {
    return calloc(1, sizeof(ma_shim_job_queue_state));
}

/* @binds ma_job_queue_uninit */
void ma_shim_job_queue_free(void* handle) {
    ma_shim_job_queue_state* h = (ma_shim_job_queue_state*)handle;
    if (h == NULL) { return; }
    job_queue_teardown(h);
    free(h);
}

/* @binds ma_job_queue_config_init, ma_job_queue_get_heap_size */
int ma_shim_job_queue_get_heap_size(
    unsigned int flags, unsigned int capacity, unsigned long long* out_heap_size
) {
    ma_job_queue_config config;
    size_t              size = 0;
    ma_result           result;

    if (out_heap_size == NULL) { return MA_INVALID_ARGS; }
    *out_heap_size = 0;
    config = ma_job_queue_config_init((ma_uint32)flags, (ma_uint32)capacity);
    result = ma_job_queue_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_job_queue_config_init, ma_job_queue_init */
int ma_shim_job_queue_init(void* handle, unsigned int flags, unsigned int capacity) {
    ma_shim_job_queue_state* h = (ma_shim_job_queue_state*)handle;
    ma_job_queue_config      config;
    ma_result                result;

    if (h == NULL) { return MA_INVALID_ARGS; }
    job_queue_teardown(h);

    config = ma_job_queue_config_init((ma_uint32)flags, (ma_uint32)capacity);
    result = ma_job_queue_init(&config, NULL, &h->queue);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_job_queue_config_init, ma_job_queue_get_heap_size, ma_job_queue_init_preallocated */
int ma_shim_job_queue_init_preallocated(
    void* handle, unsigned int flags, unsigned int capacity
) {
    ma_shim_job_queue_state* h = (ma_shim_job_queue_state*)handle;
    ma_job_queue_config      config;
    size_t                   heap_size = 0;
    void*                    heap = NULL;
    ma_result                result;

    if (h == NULL) { return MA_INVALID_ARGS; }
    job_queue_teardown(h);

    config = ma_job_queue_config_init((ma_uint32)flags, (ma_uint32)capacity);
    result = ma_job_queue_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) { return (int)result; }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) { return MA_OUT_OF_MEMORY; }
    }

    result = ma_job_queue_init_preallocated(&config, heap, &h->queue);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_job_queue_uninit */
int ma_shim_job_queue_uninit(void* handle) {
    ma_shim_job_queue_state* h = (ma_shim_job_queue_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    job_queue_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_job_init, ma_job_queue_post */
int ma_shim_job_queue_post(void* handle, unsigned int job_code) {
    ma_shim_job_queue_state* h = job_queue_ready(handle);
    ma_job                   job;

    if (h == NULL) { return MA_INVALID_ARGS; }
    job = ma_job_init((ma_uint16)job_code);
    return (int)ma_job_queue_post(&h->queue, &job);
}

/* @binds ma_job_queue_next */
int ma_shim_job_queue_next(void* handle, int* out_job_type) {
    ma_shim_job_queue_state* h = job_queue_ready(handle);
    ma_result                result;

    if (out_job_type != NULL) { *out_job_type = -1; }
    if (h == NULL || out_job_type == NULL) { return MA_INVALID_ARGS; }

    result = ma_job_queue_next(&h->queue, &h->job);
    /* MA_CANCELLED labels a quit job; the job is filled in either way. */
    if (result == MA_SUCCESS || result == MA_CANCELLED) {
        h->has_job = 1;
        *out_job_type = (int)h->job.toc.breakup.code;
    }
    return (int)result;
}

/* @binds ma_job_process */
int ma_shim_job_queue_process(void* handle) {
    ma_shim_job_queue_state* h = job_queue_ready(handle);
    if (h == NULL || !h->has_job) { return MA_INVALID_ARGS; }
    h->has_job = 0;
    return (int)ma_job_process(&h->job);
}

/* ================= log ================= */

/* A log handle is either a log the shim built (`log`) or a borrowed view of an
 * engine's log (`engine` set). A view does not own the log, so it is never
 * uninitialised from here, and it resolves the engine's log afresh on every use.
 * The one thing a view does leave behind is a registered callback, which holds a
 * pointer to this handle; teardown unregisters it. */
typedef struct ma_shim_log_state {
    ma_log          log;
    ma_log_callback callback;   /* what register/unregister were given */
    unsigned int    message_count;
    int             registered;
    int             initialized;
    void*           engine;     /* non-NULL: borrowed view of this engine's log */
} ma_shim_log_state;

/* The shim's own callback: counts what it is handed so Mojo can observe that
 * registration, posting and unregistration actually took effect. */
static void shim_log_callback(void* pUserData, ma_uint32 level, const char* pMessage) {
    ma_shim_log_state* h = (ma_shim_log_state*)pUserData;
    (void)level;
    (void)pMessage;
    if (h != NULL) {
        h->message_count += 1;
    }
}

/* The ma_log this handle stands for, or NULL if it is not ready (an engine can
 * also have no log at all). */
static ma_log* log_ptr(ma_shim_log_state* h) {
    if (h == NULL || !h->initialized) { return NULL; }
    if (h->engine != NULL) {
        ma_engine* engine = shimint_engine_ptr(h->engine);
        return (engine != NULL) ? ma_engine_get_log(engine) : NULL;
    }
    return &h->log;
}

static ma_shim_log_state* log_ready(void* handle) {
    ma_shim_log_state* h = (ma_shim_log_state*)handle;
    if (log_ptr(h) == NULL) { return NULL; }
    return h;
}

/* Release whatever the handle holds: uninitialise a log it owns, or hand a
 * borrowed one back (taking our callback off it first). */
static void log_teardown(ma_shim_log_state* h) {
    if (h->initialized) {
        if (h->engine == NULL) {
            ma_log_uninit(&h->log);
        } else if (h->registered) {
            ma_log* log = log_ptr(h);
            if (log != NULL) { ma_log_unregister_callback(log, h->callback); }
        }
    }
    h->engine = NULL;
    h->registered = 0;
    h->initialized = 0;
}

void* ma_shim_log_alloc(void) { return calloc(1, sizeof(ma_shim_log_state)); }

/* @binds ma_log_uninit */
void ma_shim_log_free(void* handle) {
    ma_shim_log_state* h = (ma_shim_log_state*)handle;
    if (h == NULL) { return; }
    log_teardown(h);
    free(h);
}

/* @binds ma_log_init */
int ma_shim_log_init(void* handle) {
    ma_shim_log_state* h = (ma_shim_log_state*)handle;
    ma_result          result;
    if (h == NULL) { return MA_INVALID_ARGS; }
    log_teardown(h);
    h->message_count = 0;
    result = ma_log_init(NULL, &h->log);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_log_uninit */
int ma_shim_log_uninit(void* handle) {
    ma_shim_log_state* h = (ma_shim_log_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    log_teardown(h);
    return MA_SUCCESS;
}

/* Turn a log handle into a non-owning view of the engine's log
 * (ma_engine_get_log). Posting, callbacks and the message count then act on the
 * engine's own log. The engine must outlive the view. */
/* @binds ma_engine_get_log */
int ma_shim_log_borrow_engine(void* handle, void* engine_handle) {
    ma_shim_log_state* h = (ma_shim_log_state*)handle;
    ma_engine*         engine = shimint_engine_ptr(engine_handle);
    if (h == NULL || engine == NULL || ma_engine_get_log(engine) == NULL) {
        return MA_INVALID_ARGS;
    }
    log_teardown(h);
    h->message_count = 0;
    h->engine = engine_handle;
    h->initialized = 1;
    return MA_SUCCESS;
}

/* @binds ma_log_post */
int ma_shim_log_post(void* handle, unsigned int level, const char* message) {
    ma_shim_log_state* h = log_ready(handle);
    if (h == NULL || message == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_log_post(log_ptr(h), (ma_uint32)level, message);
}

/* @binds ma_log_postf */
int ma_shim_log_postf(
    void* handle, unsigned int level, const char* format, const char* arg
) {
    ma_shim_log_state* h = log_ready(handle);
    if (h == NULL || format == NULL || arg == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_log_postf(log_ptr(h), (ma_uint32)level, format, arg);
}

/* Wraps the va_list form: Mojo cannot build one, so the shim makes it here. */
static int log_postv_forward(ma_log* log, ma_uint32 level, const char* format, ...) {
    va_list   args;
    ma_result result;

    va_start(args, format);
    result = ma_log_postv(log, level, format, args);
    va_end(args);
    return (int)result;
}

/* @binds ma_log_postv */
int ma_shim_log_postv(
    void* handle, unsigned int level, const char* format, const char* arg
) {
    ma_shim_log_state* h = log_ready(handle);
    if (h == NULL || format == NULL || arg == NULL) { return MA_INVALID_ARGS; }
    return log_postv_forward(log_ptr(h), (ma_uint32)level, format, arg);
}

/* @binds ma_log_callback_init, ma_log_register_callback */
int ma_shim_log_register_callback(void* handle) {
    ma_shim_log_state* h = log_ready(handle);
    ma_result          result;

    if (h == NULL) { return MA_INVALID_ARGS; }
    h->callback = ma_log_callback_init(shim_log_callback, h);
    result = ma_log_register_callback(log_ptr(h), h->callback);
    if (result == MA_SUCCESS) { h->registered = 1; }
    return (int)result;
}

/* @binds ma_log_unregister_callback */
int ma_shim_log_unregister_callback(void* handle) {
    ma_shim_log_state* h = log_ready(handle);
    ma_result          result;

    if (h == NULL || !h->registered) { return MA_INVALID_ARGS; }
    result = ma_log_unregister_callback(log_ptr(h), h->callback);
    if (result == MA_SUCCESS) { h->registered = 0; }
    return (int)result;
}

int ma_shim_log_message_count(void* handle, unsigned int* out_count) {
    ma_shim_log_state* h = log_ready(handle);
    if (out_count != NULL) { *out_count = 0; }
    if (h == NULL || out_count == NULL) { return MA_INVALID_ARGS; }
    *out_count = h->message_count;
    return MA_SUCCESS;
}

/* @binds ma_log_level_to_string */
int ma_shim_log_level_to_string(unsigned int level, char* out_text, unsigned int capacity) {
    const char* text;
    if (out_text == NULL || capacity == 0) { return MA_INVALID_ARGS; }
    text = ma_log_level_to_string((ma_uint32)level);
    if (text == NULL) { return MA_INVALID_ARGS; }
    strncpy(out_text, text, capacity - 1);
    out_text[capacity - 1] = '\0';
    return MA_SUCCESS;
}

/* ================= slot allocator ================= */

/* @binds ma_slot_allocator_config_init, ma_slot_allocator_get_heap_size */
int ma_shim_slot_allocator_get_heap_size(
    unsigned int capacity, unsigned long long* out_heap_size
) {
    ma_slot_allocator_config config;
    size_t                   size = 0;
    ma_result                result;

    if (out_heap_size == NULL) { return MA_INVALID_ARGS; }
    *out_heap_size = 0;
    config = ma_slot_allocator_config_init((ma_uint32)capacity);
    result = ma_slot_allocator_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

void* ma_shim_slot_allocator_alloc(void) { return slot_allocator_alloc_state(); }

/* @binds ma_slot_allocator_uninit */
void ma_shim_slot_allocator_free(void* handle) {
    ma_shim_slot_allocator_state* h = (ma_shim_slot_allocator_state*)handle;
    if (h == NULL) { return; }
    if (h->initialized) { ma_slot_allocator_uninit(&h->obj, NULL); }
    free(h);
}

/* @binds ma_slot_allocator_config_init, ma_slot_allocator_init */
int ma_shim_slot_allocator_init(void* handle, unsigned int capacity) {
    ma_shim_slot_allocator_state* h = (ma_shim_slot_allocator_state*)handle;
    ma_slot_allocator_config      config;
    ma_result                     result;

    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_slot_allocator_uninit(&h->obj, NULL); h->initialized = 0; }

    config = ma_slot_allocator_config_init((ma_uint32)capacity);
    result = ma_slot_allocator_init(&config, NULL, &h->obj);
    if (result == MA_SUCCESS) { h->initialized = 1; }
    return (int)result;
}

/* @binds ma_slot_allocator_config_init, ma_slot_allocator_init_preallocated */
int ma_shim_slot_allocator_init_preallocated(void* handle, unsigned int capacity) {
    ma_shim_slot_allocator_state* h = (ma_shim_slot_allocator_state*)handle;
    ma_slot_allocator_config      config;
    size_t                        heap_size = 0;
    void*                         heap = NULL;
    ma_result                     result;

    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_slot_allocator_uninit(&h->obj, NULL); h->initialized = 0; }

    config = ma_slot_allocator_config_init((ma_uint32)capacity);
    result = ma_slot_allocator_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) { return (int)result; }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) { return MA_OUT_OF_MEMORY; }
    }
    /* miniaudio keeps the block for the allocator's lifetime; it is released
     * with the handle rather than tracked separately, since the allocator has
     * no other owner here. */
    result = ma_slot_allocator_init_preallocated(&config, heap, &h->obj);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_slot_allocator_uninit */
int ma_shim_slot_allocator_uninit(void* handle) {
    ma_shim_slot_allocator_state* h = (ma_shim_slot_allocator_state*)handle;
    if (h == NULL) { return MA_INVALID_ARGS; }
    if (h->initialized) { ma_slot_allocator_uninit(&h->obj, NULL); h->initialized = 0; }
    return MA_SUCCESS;
}

/* @binds ma_slot_allocator_alloc */
int ma_shim_slot_allocator_alloc_slot(void* handle, unsigned long long* out_slot) {
    ma_shim_slot_allocator_state* h = slot_allocator_ready(handle);
    ma_uint64                     slot = 0;
    ma_result                     result;

    if (out_slot != NULL) { *out_slot = 0; }
    if (h == NULL || out_slot == NULL) { return MA_INVALID_ARGS; }
    result = ma_slot_allocator_alloc(&h->obj, &slot);
    *out_slot = (unsigned long long)slot;
    return (int)result;
}

/* @binds ma_slot_allocator_free */
int ma_shim_slot_allocator_free_slot(void* handle, unsigned long long slot) {
    ma_shim_slot_allocator_state* h = slot_allocator_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_slot_allocator_free(&h->obj, (ma_uint64)slot);
}
