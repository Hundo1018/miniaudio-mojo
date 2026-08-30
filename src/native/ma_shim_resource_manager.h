#ifndef MA_SHIM_RESOURCE_MANAGER_H
#define MA_SHIM_RESOURCE_MANAGER_H

/* ---- resource manager (opaque handles over ma_resource_manager and friends) ----
 *
 * The resource manager loads and caches sounds. It has four moving parts, all
 * bound here:
 *
 *   manager      — the cache itself, plus its job queue
 *   data_buffer  — a whole sound decoded into memory
 *   data_stream  — a sound decoded a page at a time while it plays
 *   data_source  — the unified front end, which is a buffer or a stream
 *                  depending on the flags it is given
 *
 * Tests drive it with `job_thread_count = 0` and the non-blocking flag, so the
 * manager never starts a thread and the job queue is pumped explicitly. That
 * keeps a family built around asynchrony fully deterministic.
 *
 * Streams are the exception, and they need a job thread. Two places wait on the
 * queue: `ma_resource_manager_data_stream_init` waits for its first load job
 * unless the ASYNC flag is set, and `ma_resource_manager_data_stream_uninit`
 * *always* posts a free job and waits for it, with no flag to opt out. On a
 * zero-thread manager the second one deadlocks — the calling thread is blocked
 * inside uninit, so it cannot pump the queue itself. Give the manager at least
 * one job thread when using streams. Buffers are unaffected: without ASYNC they
 * load inline on the calling thread and tear down without a job.
 *
 * `ma_resource_manager_get_log` returns an ma_log* with no safe Mojo home, so
 * it is bound the way the device family binds its log: as whether one is there.
 *
 * `ma_job` is likewise a struct Mojo has no home for. The shim keeps one job
 * slot on the manager handle: `next_job` pops a job into it and reports its
 * type, `post_job` puts that same job back, and `process_job` runs it. That
 * makes the whole job round-trip reachable without Mojo ever holding an ma_job.
 *
 * Sample format codes match ma_format (f32=5). Data-source flags match
 * MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_*: stream=1, decode=2, async=4,
 * wait_init=8, looping=16.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= the manager ================= */

void* ma_shim_resource_manager_alloc(void);
void  ma_shim_resource_manager_free(void* handle);

/* `job_thread_count` of 0 plus `non_blocking` keeps everything on this thread. */
int ma_shim_resource_manager_init(
    void* handle, unsigned int job_thread_count, int non_blocking);
int ma_shim_resource_manager_uninit(void* handle);

int ma_shim_resource_manager_has_log(void* handle, int* out_has_log);

int ma_shim_resource_manager_register_file(
    void* handle, const char* path, unsigned int flags);
int ma_shim_resource_manager_unregister_file(void* handle, const char* path);

int ma_shim_resource_manager_register_decoded_data(
    void*              handle,
    const char*        name,
    const void*        frames,
    unsigned long long frame_count,
    int                format,
    unsigned int       channels,
    unsigned int       sample_rate
);
int ma_shim_resource_manager_register_encoded_data(
    void* handle, const char* name, const void* data, unsigned long long size_in_bytes);
int ma_shim_resource_manager_unregister_data(void* handle, const char* name);

/* ---- the job queue ---- */

int ma_shim_resource_manager_post_job_quit(void* handle);
/* Pops the next job into the handle's slot and reports its type. */
int ma_shim_resource_manager_next_job(void* handle, int* out_job_type);
/* Puts the job currently in the slot back on the queue. */
int ma_shim_resource_manager_post_job(void* handle);
/* Runs the job currently in the slot. */
int ma_shim_resource_manager_process_job(void* handle);
int ma_shim_resource_manager_process_next_job(void* handle);

/* ================= data buffer ================= */

void* ma_shim_rm_data_buffer_alloc(void);
void  ma_shim_rm_data_buffer_free(void* handle);

int ma_shim_rm_data_buffer_init(
    void* handle, void* manager_handle, const char* path, unsigned int flags);
/* Same, but through the config struct and with a notifications struct attached. */
int ma_shim_rm_data_buffer_init_ex(
    void* handle, void* manager_handle, const char* path, unsigned int flags);
int ma_shim_rm_data_buffer_init_copy(
    void* handle, void* manager_handle, void* existing_handle);
int ma_shim_rm_data_buffer_uninit(void* handle);

int ma_shim_rm_data_buffer_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);
int ma_shim_rm_data_buffer_seek(void* handle, unsigned long long frame_index);
int ma_shim_rm_data_buffer_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels, unsigned int* out_sample_rate);
int ma_shim_rm_data_buffer_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_rm_data_buffer_get_length(void* handle, unsigned long long* out_length);
int ma_shim_rm_data_buffer_get_available(void* handle, unsigned long long* out_available);
int ma_shim_rm_data_buffer_result(void* handle, int* out_result);
int ma_shim_rm_data_buffer_set_looping(void* handle, int is_looping);
int ma_shim_rm_data_buffer_is_looping(void* handle, int* out_is_looping);

/* ================= data stream ================= */

void* ma_shim_rm_data_stream_alloc(void);
void  ma_shim_rm_data_stream_free(void* handle);

int ma_shim_rm_data_stream_init(
    void* handle, void* manager_handle, const char* path, unsigned int flags);
int ma_shim_rm_data_stream_init_ex(
    void* handle, void* manager_handle, const char* path, unsigned int flags);
int ma_shim_rm_data_stream_uninit(void* handle);

int ma_shim_rm_data_stream_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);
int ma_shim_rm_data_stream_seek(void* handle, unsigned long long frame_index);
int ma_shim_rm_data_stream_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels, unsigned int* out_sample_rate);
int ma_shim_rm_data_stream_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_rm_data_stream_get_length(void* handle, unsigned long long* out_length);
int ma_shim_rm_data_stream_get_available(void* handle, unsigned long long* out_available);
int ma_shim_rm_data_stream_result(void* handle, int* out_result);
int ma_shim_rm_data_stream_set_looping(void* handle, int is_looping);
int ma_shim_rm_data_stream_is_looping(void* handle, int* out_is_looping);

/* ================= the unified data source ================= */

void* ma_shim_rm_data_source_alloc(void);
void  ma_shim_rm_data_source_free(void* handle);

int ma_shim_rm_data_source_init(
    void* handle, void* manager_handle, const char* name, unsigned int flags);
int ma_shim_rm_data_source_init_ex(
    void* handle, void* manager_handle, const char* name, unsigned int flags);
int ma_shim_rm_data_source_init_copy(
    void* handle, void* manager_handle, void* existing_handle);
int ma_shim_rm_data_source_uninit(void* handle);

int ma_shim_rm_data_source_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);
int ma_shim_rm_data_source_seek(void* handle, unsigned long long frame_index);
/* map/unmap hand out an interior pointer, so the shim owns the copy out. */
int ma_shim_rm_data_source_map_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_mapped_out
);
int ma_shim_rm_data_source_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels, unsigned int* out_sample_rate);
int ma_shim_rm_data_source_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_rm_data_source_get_length(void* handle, unsigned long long* out_length);
int ma_shim_rm_data_source_get_available(void* handle, unsigned long long* out_available);
int ma_shim_rm_data_source_result(void* handle, int* out_result);
int ma_shim_rm_data_source_set_looping(void* handle, int is_looping);
int ma_shim_rm_data_source_is_looping(void* handle, int* out_is_looping);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_RESOURCE_MANAGER_H */
