#ifndef MA_SHIM_H
#define MA_SHIM_H

/*
 * ma_shim — thin passthrough shim over miniaudio.
 *
 * Design contract (see docs/binding-architecture.md):
 *   - Opaque allocation only (malloc of an miniaudio handle + an `initialized`
 *     bookkeeping flag). No scenario logic, no smoke flows, no synthesis.
 *   - Config marshalling is limited to building the standard ma_*_config from
 *     primitive arguments and forwarding to the real ma_* function.
 *   - Field accessors use miniaudio's public query APIs (Mojo cannot read C
 *     struct layout directly).
 *   - Every entry point returns a raw ma_result int (or a documented sentinel),
 *     leaving all policy to the Mojo layers above.
 *
 * Sample-format codes match miniaudio's ma_format enum exactly:
 *   unknown=0, u8=1, s16=2, s24=3, s32=4, f32=5.
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- core ---- */
const char* ma_shim_version(void);
const char* ma_shim_result_description(int result_code);

/* ---- decoder (opaque handle) ---- */
void* ma_shim_decoder_alloc(void);
void  ma_shim_decoder_free(void* handle);

int ma_shim_decoder_init_file(
    void* handle,
    const char* file_path,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
);
int ma_shim_decoder_init_memory(
    void* handle,
    const void* data,
    size_t data_size,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
);
int ma_shim_decoder_uninit(void* handle);

int ma_shim_decoder_read_pcm_frames(
    void* handle,
    void* output,
    unsigned long long frame_count,
    unsigned long long* frames_read
);
int ma_shim_decoder_seek_to_pcm_frame(void* handle, unsigned long long frame_index);
int ma_shim_decoder_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);
int ma_shim_decoder_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);
int ma_shim_decoder_get_available_frames(void* handle, unsigned long long* out_available);

/* Init from file preserving the file's native format (default decoder config). */
int ma_shim_decoder_init_file_default(void* handle, const char* file_path);
/* Init from a file path through the VFS API (NULL ma_vfs -> default stdio VFS). */
int ma_shim_decoder_init_file_vfs(
    void* handle,
    const char* file_path,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
);

/* Field accessors via ma_decoder_get_data_format; return 0 on any error. */
unsigned int ma_shim_decoder_output_channels(void* handle);
unsigned int ma_shim_decoder_output_sample_rate(void* handle);
int          ma_shim_decoder_output_format(void* handle);

/* ---- encoder (opaque handle; WAV output) ---- */
void* ma_shim_encoder_alloc(void);
void  ma_shim_encoder_free(void* handle);

int ma_shim_encoder_init_file(
    void* handle,
    const char* file_path,
    int encoding_format,
    int format,
    unsigned int channels,
    unsigned int sample_rate
);
int ma_shim_encoder_uninit(void* handle);

int ma_shim_encoder_write_pcm_frames(
    void* handle,
    const void* input,
    unsigned long long frame_count,
    unsigned long long* frames_written
);
/* Init to a file path through the VFS API (NULL ma_vfs -> default stdio VFS). */
int ma_shim_encoder_init_file_vfs(
    void* handle,
    const char* file_path,
    int encoding_format,
    int format,
    unsigned int channels,
    unsigned int sample_rate
);

/* ---- device (opaque handle; playback pulling from a decoder) ----
 *
 * The device's data callback is owned by the shim (C); it pulls f32 PCM from a
 * decoder handle (an allocation from ma_shim_decoder_alloc that has been
 * initialised). No Mojo callback crosses the FFI boundary. `use_null_backend`
 * selects miniaudio's null backend for hardware-independent, deterministic
 * operation (tests); 0 uses the default backend (real audio output).
 */
void* ma_shim_device_alloc(void);
void  ma_shim_device_free(void* handle);

int ma_shim_device_init_playback_from_decoder(
    void* handle,
    void* decoder_handle,
    unsigned int sample_rate_override,
    int use_null_backend
);
/* Same device/callback wiring, but selects the backend via an explicit backend
 * priority list (ma_backend codes) instead of a pre-built context. An empty list
 * (backend_count 0) means miniaudio's default priority order. The device owns
 * the context it creates internally; ma_device_uninit frees it. */
int ma_shim_device_init_ex_playback_from_decoder(
    void* handle,
    void* decoder_handle,
    const int* backends,
    unsigned int backend_count,
    unsigned int sample_rate_override
);
int ma_shim_device_start(void* handle);
int ma_shim_device_stop(void* handle);
int ma_shim_device_uninit(void* handle);

unsigned int       ma_shim_device_get_channels(void* handle);
unsigned int       ma_shim_device_get_sample_rate(void* handle);
unsigned long long ma_shim_device_get_frames_processed(void* handle);

/* Device state. get_state returns an ma_device_state code (0 = uninitialized,
 * which is also the sentinel for a null/uninitialised handle). is_started
 * returns 1/0, and 0 for a null/uninitialised handle. */
int ma_shim_device_get_state(void* handle);
int ma_shim_device_is_started(void* handle);

/* Master volume. Both getters use an out-param rather than a sentinel return
 * because 0.0 is a legitimate value on both scales (silence / unity gain). */
int ma_shim_device_set_master_volume(void* handle, float volume);
int ma_shim_device_get_master_volume(void* handle, float* out_volume);
int ma_shim_device_set_master_volume_db(void* handle, float gain_db);
int ma_shim_device_get_master_volume_db(void* handle, float* out_gain_db);

/* Device name for the given ma_device_type. */
int ma_shim_device_get_name(
    void* handle,
    int device_type,
    char* out_name,
    size_t name_cap,
    size_t* out_length
);

/* Device info. `info_load` snapshots the device's ma_device_info into the
 * handle; the accessors then read that snapshot (Mojo cannot read C struct
 * layout directly). Accessors fail with MA_INVALID_ARGS until a successful
 * load. `info_add_native_data_format` appends to the loaded snapshot. */
int ma_shim_device_info_load(void* handle, int device_type);
int ma_shim_device_info_name(
    void* handle,
    char* out_name,
    size_t name_cap,
    size_t* out_length
);
int ma_shim_device_info_is_default(void* handle, int* out_is_default);
int ma_shim_device_info_native_data_format_count(void* handle, unsigned int* out_count);
int ma_shim_device_info_native_data_format(
    void* handle,
    unsigned int index,
    int* out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate,
    unsigned int* out_flags
);
int ma_shim_device_info_add_native_data_format(
    void* handle,
    int format,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int flags
);

/* Compares the ma_device_id of two devices for the given device type. */
int ma_shim_device_id_equal(
    void* handle_a,
    void* handle_b,
    int device_type,
    int* out_equal
);

/* Context/log queries. These deliberately expose a *property* of the borrowed
 * ma_context / ma_log rather than the raw non-owning pointer itself, which the
 * RAII model has no safe home for. */
int ma_shim_device_get_context_backend(void* handle, int* out_backend);
int ma_shim_device_has_log(void* handle, int* out_has_log);

/* Drives the device's data callback synchronously, as a backend would. Lets a
 * caller pull frames without starting the device (no timer thread). */
int ma_shim_device_handle_backend_data_callback(
    void* handle,
    void* output,
    const void* input,
    unsigned int frame_count
);

/* ---- device job thread (opaque handle) ----
 *
 * A job queue plus an optional worker thread. With no_thread=1 no worker is
 * spawned and the caller drains the queue itself via `next`, which is what
 * makes this deterministically testable. Pass job_queue_flags=1
 * (MA_JOB_QUEUE_FLAG_NON_BLOCKING) to make `next` return MA_NO_DATA_AVAILABLE
 * on an empty queue instead of blocking.
 */
void* ma_shim_device_job_thread_alloc(void);
void  ma_shim_device_job_thread_free(void* handle);

int ma_shim_device_job_thread_init(
    void* handle,
    int no_thread,
    unsigned int job_queue_capacity,
    unsigned int job_queue_flags
);
int ma_shim_device_job_thread_uninit(void* handle);
int ma_shim_device_job_thread_post(void* handle, unsigned short job_code);
int ma_shim_device_job_thread_next(void* handle, unsigned short* out_job_code);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_H */
