#include "ma_shim_resource_manager.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* Exported by miniaudio but missing from its public header, so declared here
 * rather than left unbound. */
MA_API ma_result ma_resource_manager_data_source_map(
    ma_resource_manager_data_source* pDataSource, void** ppFramesOut, ma_uint64* pFrameCount);
MA_API ma_result ma_resource_manager_data_source_unmap(
    ma_resource_manager_data_source* pDataSource, ma_uint64 frameCount);

/* ================= the manager ================= */

typedef struct ma_shim_rm_state {
    ma_resource_manager rm;
    ma_job              job;        /* the one job slot next_job/post_job/process_job share */
    int                 has_job;
    int                 initialized;
} ma_shim_rm_state;

static void rm_teardown(ma_shim_rm_state* h) {
    if (h->initialized) {
        ma_resource_manager_uninit(&h->rm);
        h->initialized = 0;
    }
    h->has_job = 0;
}

static ma_shim_rm_state* rm_ready(void* handle) {
    ma_shim_rm_state* h = (ma_shim_rm_state*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_resource_manager_alloc(void) {
    return calloc(1, sizeof(ma_shim_rm_state));
}

/* @binds ma_resource_manager_uninit */
void ma_shim_resource_manager_free(void* handle) {
    ma_shim_rm_state* h = (ma_shim_rm_state*)handle;
    if (h == NULL) {
        return;
    }
    rm_teardown(h);
    free(h);
}

/* @binds ma_resource_manager_config_init, ma_resource_manager_init */
int ma_shim_resource_manager_init(
    void* handle, unsigned int job_thread_count, int non_blocking
) {
    ma_shim_rm_state*          h = (ma_shim_rm_state*)handle;
    ma_resource_manager_config config;
    ma_result                  result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    rm_teardown(h);

    config = ma_resource_manager_config_init();
    config.jobThreadCount = (ma_uint32)job_thread_count;
    if (non_blocking) {
        config.flags |= MA_RESOURCE_MANAGER_FLAG_NON_BLOCKING;
    }

    result = ma_resource_manager_init(&config, &h->rm);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_uninit */
int ma_shim_resource_manager_uninit(void* handle) {
    ma_shim_rm_state* h = (ma_shim_rm_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    rm_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_resource_manager_get_log */
int ma_shim_resource_manager_has_log(void* handle, int* out_has_log) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (out_has_log != NULL) { *out_has_log = 0; }
    if (h == NULL || out_has_log == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_has_log = ma_resource_manager_get_log(&h->rm) != NULL ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_resource_manager_register_file */
int ma_shim_resource_manager_register_file(
    void* handle, const char* path, unsigned int flags
) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_register_file(&h->rm, path, (ma_uint32)flags);
}

/* @binds ma_resource_manager_unregister_file */
int ma_shim_resource_manager_unregister_file(void* handle, const char* path) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_unregister_file(&h->rm, path);
}

/* @binds ma_resource_manager_register_decoded_data */
int ma_shim_resource_manager_register_decoded_data(
    void*              handle,
    const char*        name,
    const void*        frames,
    unsigned long long frame_count,
    int                format,
    unsigned int       channels,
    unsigned int       sample_rate
) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || name == NULL || frames == NULL) {
        return MA_INVALID_ARGS;
    }
    /* miniaudio does not copy the frames; the caller keeps them alive. */
    return (int)ma_resource_manager_register_decoded_data(
        &h->rm, name, frames, (ma_uint64)frame_count,
        (ma_format)format, (ma_uint32)channels, (ma_uint32)sample_rate);
}

/* @binds ma_resource_manager_register_encoded_data */
int ma_shim_resource_manager_register_encoded_data(
    void* handle, const char* name, const void* data, unsigned long long size_in_bytes
) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || name == NULL || data == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_register_encoded_data(
        &h->rm, name, data, (size_t)size_in_bytes);
}

/* @binds ma_resource_manager_unregister_data */
int ma_shim_resource_manager_unregister_data(void* handle, const char* name) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || name == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_unregister_data(&h->rm, name);
}

/* @binds ma_resource_manager_post_job_quit */
int ma_shim_resource_manager_post_job_quit(void* handle) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_post_job_quit(&h->rm);
}

/* @binds ma_resource_manager_next_job */
int ma_shim_resource_manager_next_job(void* handle, int* out_job_type) {
    ma_shim_rm_state* h = rm_ready(handle);
    ma_result         result;

    if (out_job_type != NULL) { *out_job_type = -1; }
    if (h == NULL || out_job_type == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_resource_manager_next_job(&h->rm, &h->job);
    /* MA_CANCELLED means "the job you just got is a quit job" — the job struct
     * is filled in either case, so the slot is valid for both. */
    if (result == MA_SUCCESS || result == MA_CANCELLED) {
        h->has_job = 1;
        *out_job_type = (int)h->job.toc.breakup.code;
    }
    return (int)result;
}

/* @binds ma_resource_manager_post_job */
int ma_shim_resource_manager_post_job(void* handle) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || !h->has_job) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_post_job(&h->rm, &h->job);
}

/* @binds ma_resource_manager_process_job */
int ma_shim_resource_manager_process_job(void* handle) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL || !h->has_job) {
        return MA_INVALID_ARGS;
    }
    h->has_job = 0;
    return (int)ma_resource_manager_process_job(&h->rm, &h->job);
}

/* @binds ma_resource_manager_process_next_job */
int ma_shim_resource_manager_process_next_job(void* handle) {
    ma_shim_rm_state* h = rm_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resource_manager_process_next_job(&h->rm);
}

/* ================= shared helpers for the three data types ================= */

/* Each of data_buffer / data_stream / data_source has the same accessor set, so
 * the handle shape and the accessor bodies are generated once per type. The
 * exported entry points are still written out individually so each can carry
 * its own `@binds`. */
#define MA_SHIM_RM_DATA_HANDLE(NAME, TYPE)                                        \
    typedef struct ma_shim_##NAME##_state {                                       \
        TYPE              data;                                                   \
        ma_shim_rm_state* manager;                                                \
        int               initialized;                                            \
    } ma_shim_##NAME##_state;                                                     \
                                                                                  \
    static void NAME##_teardown(ma_shim_##NAME##_state* h) {                      \
        if (h->initialized) {                                                     \
            ma_resource_manager_##NAME##_uninit(&h->data);                        \
            h->initialized = 0;                                                   \
            h->manager = NULL;                                                    \
        }                                                                         \
    }                                                                             \
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
    }                                                                             \
                                                                                  \
    static void NAME##_free_state(void* handle) {                                 \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;              \
        if (h == NULL) { return; }                                                \
        NAME##_teardown(h);                                                       \
        free(h);                                                                  \
    }                                                                             \
                                                                                  \
    static int NAME##_uninit_state(void* handle) {                                \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;              \
        if (h == NULL) { return MA_INVALID_ARGS; }                                \
        NAME##_teardown(h);                                                       \
        return MA_SUCCESS;                                                        \
    }                                                                             \
                                                                                  \
    static int NAME##_read_state(                                                 \
        void* handle, void* dst, unsigned long long frame_count,                  \
        unsigned long long* frames_read_out                                       \
    ) {                                                                           \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        ma_uint64 read = 0;                                                       \
        ma_result result;                                                         \
        if (frames_read_out != NULL) { *frames_read_out = 0; }                    \
        if (h == NULL || dst == NULL) { return MA_INVALID_ARGS; }                 \
        result = ma_resource_manager_##NAME##_read_pcm_frames(                    \
            &h->data, dst, (ma_uint64)frame_count, &read);                        \
        if (frames_read_out != NULL) {                                            \
            *frames_read_out = (unsigned long long)read;                          \
        }                                                                         \
        return (int)result;                                                       \
    }                                                                             \
                                                                                  \
    static int NAME##_seek_state(void* handle, unsigned long long frame_index) {  \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        if (h == NULL) { return MA_INVALID_ARGS; }                                \
        return (int)ma_resource_manager_##NAME##_seek_to_pcm_frame(               \
            &h->data, (ma_uint64)frame_index);                                    \
    }                                                                             \
                                                                                  \
    static int NAME##_format_state(                                               \
        void* handle, int* out_format, unsigned int* out_channels,                \
        unsigned int* out_sample_rate                                             \
    ) {                                                                           \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        ma_format format = ma_format_unknown;                                     \
        ma_uint32 channels = 0;                                                   \
        ma_uint32 rate = 0;                                                       \
        ma_result result;                                                         \
        if (out_format != NULL) { *out_format = 0; }                              \
        if (out_channels != NULL) { *out_channels = 0; }                          \
        if (out_sample_rate != NULL) { *out_sample_rate = 0; }                    \
        if (h == NULL || out_format == NULL || out_channels == NULL ||            \
            out_sample_rate == NULL) {                                            \
            return MA_INVALID_ARGS;                                               \
        }                                                                         \
        result = ma_resource_manager_##NAME##_get_data_format(                    \
            &h->data, &format, &channels, &rate, NULL, 0);                        \
        *out_format = (int)format;                                                \
        *out_channels = (unsigned int)channels;                                   \
        *out_sample_rate = (unsigned int)rate;                                    \
        return (int)result;                                                       \
    }                                                                             \
                                                                                  \
    static int NAME##_cursor_state(void* handle, unsigned long long* out_cursor) {\
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        ma_uint64 cursor = 0;                                                     \
        ma_result result;                                                         \
        if (out_cursor != NULL) { *out_cursor = 0; }                              \
        if (h == NULL || out_cursor == NULL) { return MA_INVALID_ARGS; }          \
        result = ma_resource_manager_##NAME##_get_cursor_in_pcm_frames(           \
            &h->data, &cursor);                                                   \
        *out_cursor = (unsigned long long)cursor;                                 \
        return (int)result;                                                       \
    }                                                                             \
                                                                                  \
    static int NAME##_length_state(void* handle, unsigned long long* out_length) {\
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        ma_uint64 length = 0;                                                     \
        ma_result result;                                                         \
        if (out_length != NULL) { *out_length = 0; }                              \
        if (h == NULL || out_length == NULL) { return MA_INVALID_ARGS; }          \
        result = ma_resource_manager_##NAME##_get_length_in_pcm_frames(           \
            &h->data, &length);                                                   \
        *out_length = (unsigned long long)length;                                 \
        return (int)result;                                                       \
    }                                                                             \
                                                                                  \
    static int NAME##_available_state(                                            \
        void* handle, unsigned long long* out_available                           \
    ) {                                                                           \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        ma_uint64 available = 0;                                                  \
        ma_result result;                                                         \
        if (out_available != NULL) { *out_available = 0; }                        \
        if (h == NULL || out_available == NULL) { return MA_INVALID_ARGS; }       \
        result = ma_resource_manager_##NAME##_get_available_frames(               \
            &h->data, &available);                                                \
        *out_available = (unsigned long long)available;                           \
        return (int)result;                                                       \
    }                                                                             \
                                                                                  \
    static int NAME##_result_state(void* handle, int* out_result) {               \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        if (out_result != NULL) { *out_result = 0; }                              \
        if (h == NULL || out_result == NULL) { return MA_INVALID_ARGS; }          \
        *out_result = (int)ma_resource_manager_##NAME##_result(&h->data);         \
        return MA_SUCCESS;                                                        \
    }                                                                             \
                                                                                  \
    static int NAME##_set_looping_state(void* handle, int is_looping) {           \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        if (h == NULL) { return MA_INVALID_ARGS; }                                \
        return (int)ma_resource_manager_##NAME##_set_looping(                     \
            &h->data, (ma_bool32)(is_looping != 0));                              \
    }                                                                             \
                                                                                  \
    static int NAME##_is_looping_state(void* handle, int* out_is_looping) {       \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                         \
        if (out_is_looping != NULL) { *out_is_looping = 0; }                      \
        if (h == NULL || out_is_looping == NULL) { return MA_INVALID_ARGS; }      \
        *out_is_looping =                                                         \
            ma_resource_manager_##NAME##_is_looping(&h->data) ? 1 : 0;            \
        return MA_SUCCESS;                                                        \
    }

MA_SHIM_RM_DATA_HANDLE(data_buffer, ma_resource_manager_data_buffer)
MA_SHIM_RM_DATA_HANDLE(data_stream, ma_resource_manager_data_stream)
MA_SHIM_RM_DATA_HANDLE(data_source, ma_resource_manager_data_source)

/* The config shared by the *_init_ex paths: a name, flags, and a notifications
 * struct so the pipeline-notifications constructor is exercised too. */
static ma_resource_manager_data_source_config rm_data_source_config(
    const char* path, unsigned int flags,
    ma_resource_manager_pipeline_notifications* notifications
) {
    ma_resource_manager_data_source_config config =
        ma_resource_manager_data_source_config_init();
    *notifications = ma_resource_manager_pipeline_notifications_init();
    config.pFilePath = path;
    config.flags = (ma_uint32)flags;
    config.pNotifications = notifications;  /* caller keeps it alive for the init */
    return config;
}

/* ================= the three data types' entry points ================= */

/* ---- data_buffer ---- */

void* ma_shim_rm_data_buffer_alloc(void) { return data_buffer_alloc_state(); }

/* @binds ma_resource_manager_data_buffer_uninit */
void ma_shim_rm_data_buffer_free(void* handle) { data_buffer_free_state(handle); }

/* @binds ma_resource_manager_data_buffer_init */
int ma_shim_rm_data_buffer_init(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_buffer_state* h = (ma_shim_data_buffer_state*)handle;
    ma_shim_rm_state*     m = rm_ready(manager_handle);
    ma_result             result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_buffer_teardown(h);

    result = ma_resource_manager_data_buffer_init(
        &m->rm, path, (ma_uint32)flags, NULL, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_source_config_init, ma_resource_manager_pipeline_notifications_init, ma_resource_manager_data_buffer_init_ex */
int ma_shim_rm_data_buffer_init_ex(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_buffer_state*                      h = (ma_shim_data_buffer_state*)handle;
    ma_shim_rm_state*                          m = rm_ready(manager_handle);
    ma_resource_manager_data_source_config     config;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result                                  result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_buffer_teardown(h);

    config = rm_data_source_config(path, flags, &notifications);
    result = ma_resource_manager_data_buffer_init_ex(&m->rm, &config, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_buffer_init_copy */
int ma_shim_rm_data_buffer_init_copy(void* handle, void* manager_handle, void* existing_handle) {
    ma_shim_data_buffer_state* h = (ma_shim_data_buffer_state*)handle;
    ma_shim_rm_state*     m = rm_ready(manager_handle);
    ma_shim_data_buffer_state* existing = data_buffer_ready(existing_handle);
    ma_result             result;

    if (h == NULL || m == NULL || existing == NULL) {
        return MA_INVALID_ARGS;
    }
    data_buffer_teardown(h);

    result = ma_resource_manager_data_buffer_init_copy(&m->rm, &existing->data, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_buffer_uninit */
int ma_shim_rm_data_buffer_uninit(void* handle) { return data_buffer_uninit_state(handle); }

/* @binds ma_resource_manager_data_buffer_read_pcm_frames */
int ma_shim_rm_data_buffer_read(
    void* handle, void* dst, unsigned long long frame_count,
    unsigned long long* frames_read_out
) {
    return data_buffer_read_state(handle, dst, frame_count, frames_read_out);
}

/* @binds ma_resource_manager_data_buffer_seek_to_pcm_frame */
int ma_shim_rm_data_buffer_seek(void* handle, unsigned long long frame_index) {
    return data_buffer_seek_state(handle, frame_index);
}

/* @binds ma_resource_manager_data_buffer_get_data_format */
int ma_shim_rm_data_buffer_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    return data_buffer_format_state(handle, out_format, out_channels, out_sample_rate);
}

/* @binds ma_resource_manager_data_buffer_get_cursor_in_pcm_frames */
int ma_shim_rm_data_buffer_get_cursor(void* handle, unsigned long long* out_cursor) {
    return data_buffer_cursor_state(handle, out_cursor);
}

/* @binds ma_resource_manager_data_buffer_get_length_in_pcm_frames */
int ma_shim_rm_data_buffer_get_length(void* handle, unsigned long long* out_length) {
    return data_buffer_length_state(handle, out_length);
}

/* @binds ma_resource_manager_data_buffer_get_available_frames */
int ma_shim_rm_data_buffer_get_available(void* handle, unsigned long long* out_available) {
    return data_buffer_available_state(handle, out_available);
}

/* @binds ma_resource_manager_data_buffer_result */
int ma_shim_rm_data_buffer_result(void* handle, int* out_result) {
    return data_buffer_result_state(handle, out_result);
}

/* @binds ma_resource_manager_data_buffer_set_looping */
int ma_shim_rm_data_buffer_set_looping(void* handle, int is_looping) {
    return data_buffer_set_looping_state(handle, is_looping);
}

/* @binds ma_resource_manager_data_buffer_is_looping */
int ma_shim_rm_data_buffer_is_looping(void* handle, int* out_is_looping) {
    return data_buffer_is_looping_state(handle, out_is_looping);
}

/* ---- data_stream ---- */

void* ma_shim_rm_data_stream_alloc(void) { return data_stream_alloc_state(); }

/* @binds ma_resource_manager_data_stream_uninit */
void ma_shim_rm_data_stream_free(void* handle) { data_stream_free_state(handle); }

/* @binds ma_resource_manager_data_stream_init */
int ma_shim_rm_data_stream_init(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_stream_state* h = (ma_shim_data_stream_state*)handle;
    ma_shim_rm_state*     m = rm_ready(manager_handle);
    ma_result             result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_stream_teardown(h);

    result = ma_resource_manager_data_stream_init(
        &m->rm, path, (ma_uint32)flags, NULL, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_source_config_init, ma_resource_manager_pipeline_notifications_init, ma_resource_manager_data_stream_init_ex */
int ma_shim_rm_data_stream_init_ex(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_stream_state*                      h = (ma_shim_data_stream_state*)handle;
    ma_shim_rm_state*                          m = rm_ready(manager_handle);
    ma_resource_manager_data_source_config     config;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result                                  result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_stream_teardown(h);

    config = rm_data_source_config(path, flags, &notifications);
    result = ma_resource_manager_data_stream_init_ex(&m->rm, &config, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_stream_uninit */
int ma_shim_rm_data_stream_uninit(void* handle) { return data_stream_uninit_state(handle); }

/* @binds ma_resource_manager_data_stream_read_pcm_frames */
int ma_shim_rm_data_stream_read(
    void* handle, void* dst, unsigned long long frame_count,
    unsigned long long* frames_read_out
) {
    return data_stream_read_state(handle, dst, frame_count, frames_read_out);
}

/* @binds ma_resource_manager_data_stream_seek_to_pcm_frame */
int ma_shim_rm_data_stream_seek(void* handle, unsigned long long frame_index) {
    return data_stream_seek_state(handle, frame_index);
}

/* @binds ma_resource_manager_data_stream_get_data_format */
int ma_shim_rm_data_stream_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    return data_stream_format_state(handle, out_format, out_channels, out_sample_rate);
}

/* @binds ma_resource_manager_data_stream_get_cursor_in_pcm_frames */
int ma_shim_rm_data_stream_get_cursor(void* handle, unsigned long long* out_cursor) {
    return data_stream_cursor_state(handle, out_cursor);
}

/* @binds ma_resource_manager_data_stream_get_length_in_pcm_frames */
int ma_shim_rm_data_stream_get_length(void* handle, unsigned long long* out_length) {
    return data_stream_length_state(handle, out_length);
}

/* @binds ma_resource_manager_data_stream_get_available_frames */
int ma_shim_rm_data_stream_get_available(void* handle, unsigned long long* out_available) {
    return data_stream_available_state(handle, out_available);
}

/* @binds ma_resource_manager_data_stream_result */
int ma_shim_rm_data_stream_result(void* handle, int* out_result) {
    return data_stream_result_state(handle, out_result);
}

/* @binds ma_resource_manager_data_stream_set_looping */
int ma_shim_rm_data_stream_set_looping(void* handle, int is_looping) {
    return data_stream_set_looping_state(handle, is_looping);
}

/* @binds ma_resource_manager_data_stream_is_looping */
int ma_shim_rm_data_stream_is_looping(void* handle, int* out_is_looping) {
    return data_stream_is_looping_state(handle, out_is_looping);
}

/* ---- data_source ---- */

void* ma_shim_rm_data_source_alloc(void) { return data_source_alloc_state(); }

/* @binds ma_resource_manager_data_source_uninit */
void ma_shim_rm_data_source_free(void* handle) { data_source_free_state(handle); }

/* @binds ma_resource_manager_data_source_init */
int ma_shim_rm_data_source_init(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_source_state* h = (ma_shim_data_source_state*)handle;
    ma_shim_rm_state*     m = rm_ready(manager_handle);
    ma_result             result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_source_teardown(h);

    result = ma_resource_manager_data_source_init(
        &m->rm, path, (ma_uint32)flags, NULL, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_source_config_init, ma_resource_manager_pipeline_notifications_init, ma_resource_manager_data_source_init_ex */
int ma_shim_rm_data_source_init_ex(
    void* handle, void* manager_handle, const char* path, unsigned int flags
) {
    ma_shim_data_source_state*                      h = (ma_shim_data_source_state*)handle;
    ma_shim_rm_state*                          m = rm_ready(manager_handle);
    ma_resource_manager_data_source_config     config;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result                                  result;

    if (h == NULL || m == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    data_source_teardown(h);

    config = rm_data_source_config(path, flags, &notifications);
    result = ma_resource_manager_data_source_init_ex(&m->rm, &config, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_source_init_copy */
int ma_shim_rm_data_source_init_copy(void* handle, void* manager_handle, void* existing_handle) {
    ma_shim_data_source_state* h = (ma_shim_data_source_state*)handle;
    ma_shim_rm_state*     m = rm_ready(manager_handle);
    ma_shim_data_source_state* existing = data_source_ready(existing_handle);
    ma_result             result;

    if (h == NULL || m == NULL || existing == NULL) {
        return MA_INVALID_ARGS;
    }
    data_source_teardown(h);

    result = ma_resource_manager_data_source_init_copy(&m->rm, &existing->data, &h->data);
    if (result == MA_SUCCESS) {
        h->manager = m;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resource_manager_data_source_uninit */
int ma_shim_rm_data_source_uninit(void* handle) { return data_source_uninit_state(handle); }

/* @binds ma_resource_manager_data_source_read_pcm_frames */
int ma_shim_rm_data_source_read(
    void* handle, void* dst, unsigned long long frame_count,
    unsigned long long* frames_read_out
) {
    return data_source_read_state(handle, dst, frame_count, frames_read_out);
}

/* @binds ma_resource_manager_data_source_seek_to_pcm_frame */
int ma_shim_rm_data_source_seek(void* handle, unsigned long long frame_index) {
    return data_source_seek_state(handle, frame_index);
}

/* @binds ma_resource_manager_data_source_get_data_format */
int ma_shim_rm_data_source_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    return data_source_format_state(handle, out_format, out_channels, out_sample_rate);
}

/* @binds ma_resource_manager_data_source_get_cursor_in_pcm_frames */
int ma_shim_rm_data_source_get_cursor(void* handle, unsigned long long* out_cursor) {
    return data_source_cursor_state(handle, out_cursor);
}

/* @binds ma_resource_manager_data_source_get_length_in_pcm_frames */
int ma_shim_rm_data_source_get_length(void* handle, unsigned long long* out_length) {
    return data_source_length_state(handle, out_length);
}

/* @binds ma_resource_manager_data_source_get_available_frames */
int ma_shim_rm_data_source_get_available(void* handle, unsigned long long* out_available) {
    return data_source_available_state(handle, out_available);
}

/* @binds ma_resource_manager_data_source_result */
int ma_shim_rm_data_source_result(void* handle, int* out_result) {
    return data_source_result_state(handle, out_result);
}

/* @binds ma_resource_manager_data_source_set_looping */
int ma_shim_rm_data_source_set_looping(void* handle, int is_looping) {
    return data_source_set_looping_state(handle, is_looping);
}

/* @binds ma_resource_manager_data_source_is_looping */
int ma_shim_rm_data_source_is_looping(void* handle, int* out_is_looping) {
    return data_source_is_looping_state(handle, out_is_looping);
}

/* @binds ma_resource_manager_data_source_map, ma_resource_manager_data_source_unmap */
int ma_shim_rm_data_source_map_read(
    void* handle, void* dst, unsigned long long frame_count,
    unsigned long long* frames_mapped_out
) {
    ma_shim_data_source_state* h = data_source_ready(handle);
    ma_uint64             mapped = (ma_uint64)frame_count;
    void*                 frames = NULL;
    ma_format             format = ma_format_unknown;
    ma_uint32             channels = 0;
    ma_uint32             rate = 0;
    ma_result             result;

    if (frames_mapped_out != NULL) { *frames_mapped_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_resource_manager_data_source_map(&h->data, &frames, &mapped);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (mapped > 0 && frames != NULL) {
        result = ma_resource_manager_data_source_get_data_format(
            &h->data, &format, &channels, &rate, NULL, 0);
        if (result == MA_SUCCESS) {
            memcpy(dst, frames,
                   (size_t)(mapped * ma_get_bytes_per_frame(format, channels)));
        }
    }
    if (frames_mapped_out != NULL) {
        *frames_mapped_out = (unsigned long long)mapped;
    }
    return (int)ma_resource_manager_data_source_unmap(&h->data, mapped);
}
