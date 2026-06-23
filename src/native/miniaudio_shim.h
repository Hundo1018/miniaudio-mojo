#ifndef MINIAUDIO_MOJO_SHIM_H
#define MINIAUDIO_MOJO_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Callback function types for user-defined audio processing */
typedef void (*mmj_device_data_callback)(
    void* output,
    const void* input,
    uint32_t frame_count,
    void* user_data
);

typedef void (*mmj_device_stop_callback)(
    void* user_data
);

#define MMJ_WAVEFORM_TYPE_SINE      0
#define MMJ_WAVEFORM_TYPE_SQUARE    1
#define MMJ_WAVEFORM_TYPE_TRIANGLE  2
#define MMJ_WAVEFORM_TYPE_SAWTOOTH  3
#define MMJ_NOISE_TYPE_WHITE        0
#define MMJ_NOISE_TYPE_PINK         1
#define MMJ_NOISE_TYPE_BROWNIAN     2

const char* mmj_miniaudio_version(void);
const char* mmj_result_description(int result_code);
int mmj_play_sine_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double frequency_hz,
    double duration_seconds,
    float gain
);
int mmj_play_file_f32(
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
);
int mmj_capture_smoke_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
);
int mmj_capture_to_wav_f32(
    const char* output_path,
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
);
int mmj_duplex_smoke_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
);

void* mmj_context_create(void);
int mmj_context_init_default(void* context_handle);
int mmj_context_uninit(void* context_handle);
int64_t mmj_context_get_playback_device_count(void* context_handle);
int64_t mmj_context_get_capture_device_count(void* context_handle);
int mmj_context_get_playback_device_name(
    void* context_handle,
    uint32_t index,
    char* output,
    uint32_t output_capacity
);
int mmj_context_get_capture_device_name(
    void* context_handle,
    uint32_t index,
    char* output,
    uint32_t output_capacity
);
void mmj_context_destroy(void* context_handle);

void* mmj_engine_create(void);
int mmj_engine_init_default(void* engine_handle);
int mmj_engine_uninit(void* engine_handle);
int mmj_engine_play_sound(void* engine_handle, const char* file_path);
int mmj_engine_listener_set_position(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
);
int mmj_engine_listener_set_direction(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
);
int mmj_engine_listener_set_world_up(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
);
void* mmj_engine_get_endpoint(void* engine_handle);
void mmj_engine_destroy(void* engine_handle);

void* mmj_sound_create(void);
int mmj_sound_init_from_file(
    void* sound_handle,
    void* engine_handle,
    const char* file_path
);
int mmj_sound_init_from_file_in_group(
    void* sound_handle,
    void* engine_handle,
    void* sound_group_handle,
    const char* file_path
);
int mmj_sound_start(void* sound_handle);
int mmj_sound_stop(void* sound_handle);
int mmj_sound_pause(void* sound_handle);
int mmj_sound_seek_to_pcm_frame(void* sound_handle, uint64_t frame_index);
int mmj_sound_set_looping(void* sound_handle, int is_looping);
int mmj_sound_set_volume_f32(void* sound_handle, float volume);
int mmj_sound_set_spatialization_enabled(void* sound_handle, int is_enabled);
int mmj_sound_set_position(
    void* sound_handle,
    float x,
    float y,
    float z
);
int mmj_sound_set_rolloff(void* sound_handle, float rolloff);
int mmj_sound_set_min_distance(void* sound_handle, float min_distance);
int mmj_sound_set_max_distance(void* sound_handle, float max_distance);
int64_t mmj_sound_get_cursor_in_pcm_frames(void* sound_handle);
int64_t mmj_sound_get_time_in_milliseconds(void* sound_handle);
int mmj_sound_is_finished(void* sound_handle);
void* mmj_sound_get_node(void* sound_handle);
int mmj_sound_uninit(void* sound_handle);
void mmj_sound_destroy(void* sound_handle);

void* mmj_sound_group_create(void);
int mmj_sound_group_init_default(void* sound_group_handle, void* engine_handle);
int mmj_sound_group_init_with_parent(
    void* sound_group_handle,
    void* engine_handle,
    void* parent_group_handle
);
int mmj_sound_group_start(void* sound_group_handle);
int mmj_sound_group_stop(void* sound_group_handle);
int mmj_sound_group_set_volume_f32(void* sound_group_handle, float volume);
float mmj_sound_group_get_volume_f32(void* sound_group_handle);
int mmj_sound_group_set_pan_f32(void* sound_group_handle, float pan);
float mmj_sound_group_get_pan_f32(void* sound_group_handle);
int mmj_sound_group_set_pitch_f32(void* sound_group_handle, float pitch);
float mmj_sound_group_get_pitch_f32(void* sound_group_handle);
int mmj_sound_group_set_spatialization_enabled(void* sound_group_handle, int is_enabled);
int mmj_sound_group_is_spatialization_enabled(void* sound_group_handle);
int mmj_sound_group_set_position(
    void* sound_group_handle,
    float x,
    float y,
    float z
);
int mmj_sound_group_set_direction(
    void* sound_group_handle,
    float x,
    float y,
    float z
);
int mmj_sound_group_set_velocity(
    void* sound_group_handle,
    float x,
    float y,
    float z
);
int mmj_sound_group_set_rolloff(void* sound_group_handle, float rolloff);
float mmj_sound_group_get_rolloff(void* sound_group_handle);
int mmj_sound_group_set_min_distance(void* sound_group_handle, float min_distance);
float mmj_sound_group_get_min_distance(void* sound_group_handle);
int mmj_sound_group_set_max_distance(void* sound_group_handle, float max_distance);
float mmj_sound_group_get_max_distance(void* sound_group_handle);
int mmj_sound_group_set_attenuation_model(void* sound_group_handle, int attenuation_model);
int mmj_sound_group_get_attenuation_model(void* sound_group_handle);
int mmj_sound_group_set_positioning(void* sound_group_handle, int positioning);
int mmj_sound_group_get_positioning(void* sound_group_handle);
int mmj_sound_group_set_pinned_listener_index(void* sound_group_handle, uint32_t listener_index);
int mmj_sound_group_get_pinned_listener_index(void* sound_group_handle);
int mmj_sound_group_set_cone(
    void* sound_group_handle,
    float inner_angle,
    float outer_angle,
    float outer_gain
);
float mmj_sound_group_get_cone_inner_angle(void* sound_group_handle);
float mmj_sound_group_get_cone_outer_angle(void* sound_group_handle);
float mmj_sound_group_get_cone_outer_gain(void* sound_group_handle);
int mmj_sound_group_set_doppler_factor(void* sound_group_handle, float doppler_factor);
float mmj_sound_group_get_doppler_factor(void* sound_group_handle);
int mmj_sound_group_set_directional_attenuation_factor(
    void* sound_group_handle,
    float directional_attenuation_factor
);
float mmj_sound_group_get_directional_attenuation_factor(void* sound_group_handle);
int mmj_sound_group_uninit(void* sound_group_handle);
void mmj_sound_group_destroy(void* sound_group_handle);

/* sound group timing / fade */
int mmj_sound_group_set_fade_in_pcm_frames(
    void* sound_group_handle,
    float vol_beg,
    float vol_end,
    uint64_t length_in_frames
);
int mmj_sound_group_set_fade_in_milliseconds(
    void* sound_group_handle,
    float vol_beg,
    float vol_end,
    uint64_t length_in_ms
);
float mmj_sound_group_get_current_fade_volume(void* sound_group_handle);
int mmj_sound_group_set_start_time_in_pcm_frames(void* sound_group_handle, uint64_t absolute_global_time_in_frames);
int mmj_sound_group_set_start_time_in_milliseconds(void* sound_group_handle, uint64_t absolute_global_time_in_ms);
int mmj_sound_group_set_stop_time_in_pcm_frames(void* sound_group_handle, uint64_t absolute_global_time_in_frames);
int mmj_sound_group_set_stop_time_in_milliseconds(void* sound_group_handle, uint64_t absolute_global_time_in_ms);
int64_t mmj_sound_group_get_time_in_pcm_frames(void* sound_group_handle);

int mmj_node_attach_output_bus(
    void* node_handle,
    uint32_t output_bus_index,
    void* other_node_handle,
    uint32_t other_node_input_bus_index
);
int mmj_node_detach_output_bus(void* node_handle, uint32_t output_bus_index);
int mmj_node_get_output_bus_count(void* node_handle);
int mmj_node_set_output_bus_volume(
    void* node_handle,
    uint32_t output_bus_index,
    float volume
);
float mmj_node_get_output_bus_volume(void* node_handle, uint32_t output_bus_index);

void* mmj_lpf_node_create(void);
int mmj_lpf_node_init(
    void* lpf_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    float cutoff_hz,
    uint32_t order
);
int mmj_lpf_node_set_cutoff(void* lpf_node_handle, float cutoff_hz);
float mmj_lpf_node_get_cutoff(void* lpf_node_handle);
void* mmj_lpf_node_get_node(void* lpf_node_handle);
int mmj_lpf_node_uninit(void* lpf_node_handle);
void mmj_lpf_node_destroy(void* lpf_node_handle);

void* mmj_hpf_node_create(void);
int mmj_hpf_node_init(
    void* hpf_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    float cutoff_hz,
    uint32_t order
);
int mmj_hpf_node_set_cutoff(void* hpf_node_handle, float cutoff_hz);
float mmj_hpf_node_get_cutoff(void* hpf_node_handle);
void* mmj_hpf_node_get_node(void* hpf_node_handle);
int mmj_hpf_node_uninit(void* hpf_node_handle);
void mmj_hpf_node_destroy(void* hpf_node_handle);

void* mmj_delay_node_create(void);
int mmj_delay_node_init(
    void* delay_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    uint32_t delay_frames,
    float decay
);
int mmj_delay_node_set_wet(void* delay_node_handle, float wet);
float mmj_delay_node_get_wet(void* delay_node_handle);
int mmj_delay_node_set_dry(void* delay_node_handle, float dry);
float mmj_delay_node_get_dry(void* delay_node_handle);
int mmj_delay_node_set_decay(void* delay_node_handle, float decay);
float mmj_delay_node_get_decay(void* delay_node_handle);
void* mmj_delay_node_get_node(void* delay_node_handle);
int mmj_delay_node_uninit(void* delay_node_handle);
void mmj_delay_node_destroy(void* delay_node_handle);

void* mmj_splitter_node_create(void);
int mmj_splitter_node_init(void* splitter_node_handle, void* engine_handle, uint32_t channels);
int mmj_splitter_node_set_output_bus_volume(void* splitter_node_handle, uint32_t bus_index, float volume);
float mmj_splitter_node_get_output_bus_volume(void* splitter_node_handle, uint32_t bus_index);
void* mmj_splitter_node_get_node(void* splitter_node_handle);
int mmj_splitter_node_uninit(void* splitter_node_handle);
void mmj_splitter_node_destroy(void* splitter_node_handle);

void* mmj_resource_manager_create(void);
int mmj_resource_manager_init_default(void* resource_manager_handle);
int mmj_resource_manager_uninit(void* resource_manager_handle);
void mmj_resource_manager_destroy(void* resource_manager_handle);

/* Job queue primitives (MVP) */
void* mmj_job_queue_create(void);
int mmj_job_queue_init(void* queue_handle, uint32_t flags, uint32_t capacity);
int mmj_job_queue_post_custom(void* queue_handle, uint64_t data0, uint64_t data1);
int mmj_job_queue_post_quit(void* queue_handle);
int64_t mmj_job_queue_next_code(void* queue_handle);
int mmj_job_queue_uninit(void* queue_handle);
void mmj_job_queue_destroy(void* queue_handle);
uint32_t mmj_job_queue_flag_non_blocking(void);
uint32_t mmj_job_type_quit(void);
uint32_t mmj_job_type_custom(void);

int mmj_job_queue_smoke(void);
int mmj_job_queue_invalid_args_smoke(void);

/* Async notification primitives (poll/event MVP) */
void* mmj_async_notification_poll_create(void);
int mmj_async_notification_poll_init(void* notification_handle);
int mmj_async_notification_poll_signal(void* notification_handle);
int mmj_async_notification_poll_is_signalled(void* notification_handle);
int mmj_async_notification_poll_uninit(void* notification_handle);
void mmj_async_notification_poll_destroy(void* notification_handle);

void* mmj_async_notification_event_create(void);
int mmj_async_notification_event_init(void* notification_handle);
int mmj_async_notification_event_signal(void* notification_handle);
int mmj_async_notification_event_wait(void* notification_handle);
int mmj_async_notification_event_uninit(void* notification_handle);
void mmj_async_notification_event_destroy(void* notification_handle);

int mmj_async_notification_poll_smoke(void);
int mmj_async_notification_poll_invalid_args_smoke(void);
int mmj_async_notification_event_smoke(void);
int mmj_async_notification_event_invalid_args_smoke(void);

/* Fence primitives (resource-manager stage synchronization MVP) */
void* mmj_fence_create(void);
int mmj_fence_init(void* fence_handle);
int mmj_fence_wait(void* fence_handle);
int mmj_fence_uninit(void* fence_handle);
void mmj_fence_destroy(void* fence_handle);

/* Synchronization primitives (mutex/event/semaphore/spinlock MVP) */
void* mmj_mutex_create(void);
int mmj_mutex_init(void* mutex_handle);
int mmj_mutex_lock(void* mutex_handle);
int mmj_mutex_unlock(void* mutex_handle);
int mmj_mutex_uninit(void* mutex_handle);
void mmj_mutex_destroy(void* mutex_handle);

void* mmj_event_create(void);
int mmj_event_init(void* event_handle);
int mmj_event_signal(void* event_handle);
int mmj_event_wait(void* event_handle);
int mmj_event_uninit(void* event_handle);
void mmj_event_destroy(void* event_handle);

void* mmj_semaphore_create(void);
int mmj_semaphore_init(void* semaphore_handle, uint32_t initial_count);
int mmj_semaphore_release(void* semaphore_handle);
int mmj_semaphore_wait(void* semaphore_handle);
int mmj_semaphore_uninit(void* semaphore_handle);
void mmj_semaphore_destroy(void* semaphore_handle);

void* mmj_spinlock_create(void);
int mmj_spinlock_init(void* spinlock_handle);
int mmj_spinlock_lock(void* spinlock_handle);
int mmj_spinlock_unlock(void* spinlock_handle);
int mmj_spinlock_uninit(void* spinlock_handle);
void mmj_spinlock_destroy(void* spinlock_handle);

int mmj_sync_primitives_smoke(void);
int mmj_sync_primitives_invalid_args_smoke(void);

void* mmj_resource_data_source_create(void);
int mmj_resource_data_source_init_file(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags
);
int mmj_resource_data_source_init_file_w(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags
);
int mmj_resource_data_source_init_ex(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    uint64_t initial_seek_point_in_pcm_frames,
    uint64_t range_beg_in_pcm_frames,
    uint64_t range_end_in_pcm_frames,
    uint64_t loop_point_beg_in_pcm_frames,
    uint64_t loop_point_end_in_pcm_frames,
    int is_looping
);
int mmj_resource_data_source_init_ex_w(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    uint64_t initial_seek_point_in_pcm_frames,
    uint64_t range_beg_in_pcm_frames,
    uint64_t range_end_in_pcm_frames,
    uint64_t loop_point_beg_in_pcm_frames,
    uint64_t loop_point_end_in_pcm_frames,
    int is_looping
);
int mmj_resource_data_source_init_copy(
    void* data_source_handle,
    void* resource_manager_handle,
    void* existing_data_source_handle
);
int mmj_resource_data_source_init_file_with_notifications(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle
);
int mmj_resource_data_source_init_file_w_with_notifications(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle
);
int mmj_resource_data_source_init_file_with_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_fence_handle,
    void* done_fence_handle
);
int mmj_resource_data_source_init_file_with_notifications_and_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle,
    void* init_fence_handle,
    void* done_fence_handle
);
int mmj_resource_data_source_init_file_w_with_notifications_and_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle,
    void* init_fence_handle,
    void* done_fence_handle
);
int mmj_resource_data_source_result(void* data_source_handle);
int mmj_resource_data_source_wait_result(
    void* data_source_handle,
    uint32_t timeout_ms,
    uint32_t poll_interval_ms
);
int64_t mmj_resource_data_source_get_length_in_pcm_frames(void* data_source_handle);
int64_t mmj_resource_data_source_get_available_frames(void* data_source_handle);
int mmj_resource_data_source_uninit(void* data_source_handle);
void mmj_resource_data_source_destroy(void* data_source_handle);
uint32_t mmj_resource_data_source_flag_async(void);
uint32_t mmj_resource_data_source_flag_stream(void);
uint32_t mmj_resource_data_source_flag_decode(void);
uint32_t mmj_resource_data_source_flag_wait_init(void);

/* resource data source extended operations */
int mmj_resource_data_source_seek_to_pcm_frame(void* data_source_handle, uint64_t frame_index);
int mmj_resource_data_source_seek_pcm_frames(void* data_source_handle, uint64_t frame_count);
int64_t mmj_resource_data_source_get_cursor_in_pcm_frames(void* data_source_handle);
float mmj_resource_data_source_get_cursor_in_seconds(void* data_source_handle);
float mmj_resource_data_source_get_length_in_seconds(void* data_source_handle);
int mmj_resource_data_source_get_format(void* data_source_handle);
int mmj_resource_data_source_get_channels(void* data_source_handle);
int mmj_resource_data_source_get_sample_rate(void* data_source_handle);
int mmj_resource_data_source_set_looping(void* data_source_handle, int is_looping);
int mmj_resource_data_source_is_looping(void* data_source_handle);
int mmj_resource_data_source_set_range_in_pcm_frames(void* data_source_handle, uint64_t range_beg, uint64_t range_end);
int64_t mmj_resource_data_source_get_range_beg_in_pcm_frames(void* data_source_handle);
int64_t mmj_resource_data_source_get_range_end_in_pcm_frames(void* data_source_handle);

/* resource data source loop point + seek by seconds */
int mmj_resource_data_source_set_loop_point_in_pcm_frames(void* data_source_handle, uint64_t loop_beg, uint64_t loop_end);
int64_t mmj_resource_data_source_get_loop_point_beg_in_pcm_frames(void* data_source_handle);
int64_t mmj_resource_data_source_get_loop_point_end_in_pcm_frames(void* data_source_handle);
int mmj_resource_data_source_seek_to_second(void* data_source_handle, float seconds);
int mmj_resource_data_source_seek_seconds(void* data_source_handle, float seconds);

void* mmj_device_create(void);
int mmj_device_init_playback_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
);
int mmj_device_init_capture_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
);
int mmj_device_init_duplex_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
);
int mmj_device_init_duplex_loopback_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
);
int mmj_device_init_playback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_playback_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
);
int mmj_device_init_capture_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
);
int mmj_device_init_duplex_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
);
int mmj_device_init_capture_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_duplex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_duplex_loopback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_f32(
    void* device_handle,
    int device_kind,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_playback_f32_by_index(
    void* device_handle,
    void* context_handle,
    uint32_t device_index,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_init_capture_f32_by_index(
    void* device_handle,
    void* context_handle,
    uint32_t device_index,
    uint32_t sample_rate,
    uint32_t channels
);
int mmj_device_start(void* device_handle);
int mmj_device_stop(void* device_handle);
int mmj_device_is_started(void* device_handle);
int mmj_device_get_kind(void* device_handle);
int mmj_device_get_sample_rate(void* device_handle);
int mmj_device_get_channels(void* device_handle);
int mmj_device_set_callback_mode(void* device_handle, int mode);
int mmj_device_get_callback_mode(void* device_handle);
int64_t mmj_device_get_observed_frames(void* device_handle);
int mmj_device_reset_observed_frames(void* device_handle);
int mmj_device_wait_for_observed_frames(
    void* device_handle,
    uint64_t min_frames,
    uint32_t timeout_ms,
    uint32_t poll_interval_ms
);
int mmj_device_set_master_volume_f32(void* device_handle, float volume);
int mmj_device_get_master_volume_milli(void* device_handle);
int mmj_device_uninit(void* device_handle);
void mmj_device_destroy(void* device_handle);

void* mmj_decoder_create(void);
int mmj_decoder_init_file_format(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
);
int mmj_decoder_init_file_vfs_format(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
);
int mmj_decoder_init_file_vfs_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
);
int mmj_decoder_init_file_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
);
int mmj_decoder_init_memory_format(
    void* decoder_handle,
    const void* data,
    uint64_t data_size,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
);
int mmj_decoder_init_memory_f32(
    void* decoder_handle,
    const void* data,
    uint64_t data_size,
    uint32_t output_channels,
    uint32_t output_sample_rate
);
int mmj_decoder_read_pcm_frames_f32(
    void* decoder_handle,
    float* output,
    uint64_t frame_count,
    uint64_t* frames_read
);
int64_t mmj_decoder_read_pcm_frames_f32_count(
    void* decoder_handle,
    float* output,
    uint64_t frame_count
);
int64_t mmj_decoder_read_probe_f32(void* decoder_handle, uint64_t frame_count);
int mmj_decoder_seek_to_pcm_frame(void* decoder_handle, uint64_t frame_index);
int mmj_decoder_uninit(void* decoder_handle);
void mmj_decoder_destroy(void* decoder_handle);

void* mmj_encoder_create(void);
int mmj_encoder_init_wav_file_format(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate,
    int sample_format
);
int mmj_encoder_init_wav_file_vfs_format(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate,
    int sample_format
);
int mmj_encoder_init_wav_file_vfs_f32(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate
);
int mmj_encoder_init_wav_file_f32(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate
);
int mmj_encoder_write_silence_f32(void* encoder_handle, uint64_t frame_count);
int64_t mmj_encoder_write_pcm_frames_f32(
    void* encoder_handle,
    const float* frames,
    uint64_t frame_count
);
int mmj_encoder_uninit(void* encoder_handle);
void mmj_encoder_destroy(void* encoder_handle);

/* Resampler primitives (f32 + linear algorithm MVP) */
void* mmj_resampler_create(void);
int mmj_resampler_init_linear_f32(
    void* resampler_handle,
    uint32_t channels,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
);
int64_t mmj_resampler_process_f32(
    void* resampler_handle,
    const float* input_frames,
    uint64_t input_frame_count,
    float* output_frames,
    uint64_t output_frame_capacity
);
int64_t mmj_resampler_get_expected_output_frame_count(
    void* resampler_handle,
    uint64_t input_frame_count
);
int mmj_resampler_reset(void* resampler_handle);
int mmj_resampler_uninit(void* resampler_handle);
void mmj_resampler_destroy(void* resampler_handle);

/* Channel converter primitives (f32 + default channel map MVP) */
void* mmj_channel_converter_create(void);
int mmj_channel_converter_init_f32(
    void* converter_handle,
    uint32_t channels_in,
    uint32_t channels_out,
    uint32_t mix_mode
);
int mmj_channel_converter_process_f32(
    void* converter_handle,
    const float* input_frames,
    float* output_frames,
    uint64_t frame_count
);
int mmj_channel_converter_uninit(void* converter_handle);
void mmj_channel_converter_destroy(void* converter_handle);

/* Data converter primitives (f32 MVP bridge) */
void* mmj_data_converter_create(void);
int mmj_data_converter_init_f32(
    void* converter_handle,
    uint32_t channels_in,
    uint32_t channels_out,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
);
int64_t mmj_data_converter_process_f32(
    void* converter_handle,
    const float* input_frames,
    uint64_t input_frame_count,
    float* output_frames,
    uint64_t output_frame_capacity
);
int64_t mmj_data_converter_get_expected_output_frame_count(
    void* converter_handle,
    uint64_t input_frame_count
);
int64_t mmj_data_converter_get_required_input_frame_count(
    void* converter_handle,
    uint64_t output_frame_count
);
int64_t mmj_data_converter_get_input_latency(void* converter_handle);
int64_t mmj_data_converter_get_output_latency(void* converter_handle);
int mmj_data_converter_set_rate(
    void* converter_handle,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
);
int mmj_data_converter_reset(void* converter_handle);
int mmj_data_converter_uninit(void* converter_handle);
void mmj_data_converter_destroy(void* converter_handle);

/* Waveform primitives (f32 MVP) */
void* mmj_waveform_create(void);
int mmj_waveform_init_f32(
    void* waveform_handle,
    uint32_t channels,
    uint32_t sample_rate,
    uint32_t waveform_type,
    double amplitude,
    double frequency
);
int64_t mmj_waveform_read_f32(
    void* waveform_handle,
    float* output_frames,
    uint64_t frame_count
);
int mmj_waveform_set_amplitude(void* waveform_handle, double amplitude);
int mmj_waveform_set_frequency(void* waveform_handle, double frequency);
int mmj_waveform_uninit(void* waveform_handle);
void mmj_waveform_destroy(void* waveform_handle);

/* Noise primitives (f32 MVP) */
void* mmj_noise_create(void);
int mmj_noise_init_f32(
    void* noise_handle,
    uint32_t channels,
    uint32_t noise_type,
    int32_t seed,
    double amplitude
);
int64_t mmj_noise_read_f32(
    void* noise_handle,
    float* output_frames,
    uint64_t frame_count
);
int mmj_noise_set_amplitude(void* noise_handle, double amplitude);
int mmj_noise_set_seed(void* noise_handle, int32_t seed);
int mmj_noise_set_type(void* noise_handle, uint32_t noise_type);
int mmj_noise_uninit(void* noise_handle);
void mmj_noise_destroy(void* noise_handle);

/* Standalone spatializer/listener primitives (engine-independent 3D processing MVP) */
void* mmj_spatializer_listener_create(void);
int mmj_spatializer_listener_init_default(
    void* listener_handle,
    uint32_t channels_out
);
int mmj_spatializer_listener_set_position(
    void* listener_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_listener_set_direction(
    void* listener_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_listener_set_world_up(
    void* listener_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_listener_uninit(void* listener_handle);
void mmj_spatializer_listener_destroy(void* listener_handle);

void* mmj_spatializer_create(void);
int mmj_spatializer_init_default(
    void* spatializer_handle,
    uint32_t channels_in,
    uint32_t channels_out
);
int mmj_spatializer_set_master_volume(
    void* spatializer_handle,
    float volume
);
float mmj_spatializer_get_master_volume(
    void* spatializer_handle
);
int mmj_spatializer_set_attenuation_model(
    void* spatializer_handle,
    int attenuation_model
);
int mmj_spatializer_set_positioning(
    void* spatializer_handle,
    int positioning
);
int mmj_spatializer_set_position(
    void* spatializer_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_set_direction(
    void* spatializer_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_set_velocity(
    void* spatializer_handle,
    float x,
    float y,
    float z
);
int mmj_spatializer_process_f32(
    void* spatializer_handle,
    void* listener_handle,
    float* output_frames,
    const float* input_frames,
    uint64_t frame_count
);
int mmj_spatializer_uninit(void* spatializer_handle);
void mmj_spatializer_destroy(void* spatializer_handle);

/* PCM ring buffer primitives (f32 interleaved MVP) */
void* mmj_pcm_rb_create(void);
int mmj_pcm_rb_init_f32(
    void* pcm_rb_handle,
    uint32_t channels,
    uint32_t buffer_size_frames,
    uint32_t sample_rate
);
int64_t mmj_pcm_rb_write_f32(
    void* pcm_rb_handle,
    const float* input_frames,
    uint64_t frame_count
);
int64_t mmj_pcm_rb_read_f32(
    void* pcm_rb_handle,
    float* output_frames,
    uint64_t frame_count
);
int64_t mmj_pcm_rb_available_read(void* pcm_rb_handle);
int64_t mmj_pcm_rb_available_write(void* pcm_rb_handle);
int mmj_pcm_rb_reset(void* pcm_rb_handle);
int mmj_pcm_rb_uninit(void* pcm_rb_handle);
void mmj_pcm_rb_destroy(void* pcm_rb_handle);

/* Resampler/channel-converter smoke helpers */
int mmj_resampler_linear_smoke(void);
int mmj_resampler_invalid_rate_smoke(void);
int mmj_channel_converter_stereo_to_mono_smoke(void);
int mmj_channel_converter_invalid_channels_smoke(void);
int mmj_data_converter_smoke(void);
int mmj_data_converter_invalid_args_smoke(void);
int mmj_waveform_sine_smoke(void);
int mmj_waveform_invalid_args_smoke(void);
int mmj_noise_smoke(void);
int mmj_noise_invalid_args_smoke(void);
int mmj_spatializer_smoke(void);
int mmj_spatializer_invalid_args_smoke(void);
int mmj_decoder_memory_smoke(void);
int mmj_decoder_memory_invalid_args_smoke(void);
int mmj_pcm_rb_smoke(void);
int mmj_pcm_rb_overflow_smoke(void);
int mmj_pcm_rb_invalid_args_smoke(void);

/* Logging primitives for smoke-level observability checks */
void* mmj_log_create(void);
int mmj_log_init(void* log_handle);
int mmj_log_register_counting_callback(void* log_handle);
int mmj_log_unregister_counting_callback(void* log_handle);
int mmj_log_post_info(void* log_handle, const char* message);
int64_t mmj_log_get_callback_count(void* log_handle);
int mmj_log_uninit(void* log_handle);
void mmj_log_destroy(void* log_handle);

/* Memory-based I/O for playback and capture without files */
void* mmj_playback_from_buffer_create(void);
int mmj_playback_from_buffer_init_f32(
    void* playback_handle,
    uint32_t sample_rate,
    uint32_t channels,
    float* buffer,
    uint64_t buffer_frame_count
);
int mmj_playback_from_buffer_start(void* playback_handle);
int mmj_playback_from_buffer_stop(void* playback_handle);
int mmj_playback_from_buffer_is_finished(void* playback_handle);
int64_t mmj_playback_from_buffer_get_position_in_frames(void* playback_handle);
int mmj_playback_from_buffer_uninit(void* playback_handle);
void mmj_playback_from_buffer_destroy(void* playback_handle);

void* mmj_capture_to_buffer_create(void);
int mmj_capture_to_buffer_init_f32(
    void* capture_handle,
    uint32_t sample_rate,
    uint32_t channels,
    float* buffer,
    uint64_t buffer_frame_capacity
);
int mmj_capture_to_buffer_start(void* capture_handle);
int mmj_capture_to_buffer_stop(void* capture_handle);
int64_t mmj_capture_to_buffer_get_frames_captured(void* capture_handle);
int mmj_capture_to_buffer_reset(void* capture_handle);
int mmj_capture_to_buffer_uninit(void* capture_handle);
void mmj_capture_to_buffer_destroy(void* capture_handle);

/* Custom data-source primitives (PCM buffer-backed MVP) */
void* mmj_custom_buffer_data_source_create(void);
int mmj_custom_buffer_data_source_init_f32(
    void* data_source_handle,
    const float* frames,
    uint64_t frame_count,
    uint32_t channels,
    uint32_t sample_rate
);
int64_t mmj_custom_buffer_data_source_read_f32(
    void* data_source_handle,
    float* output_frames,
    uint64_t frame_count
);
int mmj_custom_buffer_data_source_seek_to_pcm_frame(
    void* data_source_handle,
    uint64_t frame_index
);
int64_t mmj_custom_buffer_data_source_get_cursor_in_pcm_frames(void* data_source_handle);
int64_t mmj_custom_buffer_data_source_get_length_in_pcm_frames(void* data_source_handle);
int mmj_custom_buffer_data_source_get_format(void* data_source_handle);
int mmj_custom_buffer_data_source_get_channels(void* data_source_handle);
int mmj_custom_buffer_data_source_get_sample_rate(void* data_source_handle);
int mmj_custom_buffer_data_source_set_looping(void* data_source_handle, int is_looping);
int mmj_custom_buffer_data_source_is_looping(void* data_source_handle);
int mmj_custom_buffer_data_source_uninit(void* data_source_handle);
void mmj_custom_buffer_data_source_destroy(void* data_source_handle);

int mmj_custom_buffer_data_source_smoke(void);
int mmj_custom_buffer_data_source_invalid_args_smoke(void);

/* User-defined callback registration for device I/O */
int mmj_device_set_data_callback(
    void* device_handle,
    mmj_device_data_callback callback,
    void* user_data
);
int mmj_device_set_stop_callback(
    void* device_handle,
    mmj_device_stop_callback callback,
    void* user_data
);
int mmj_device_clear_callbacks(void* device_handle);

/* Test helper for user callbacks */
int mmj_device_test_callback_smoke(uint32_t duration_ms);
int mmj_callback_path_smoke(void);

/* Biquad EQ node APIs (for node graph-based effect processing) */
void* mmj_biquad_node_create(void);
int mmj_biquad_node_init(
    void* biquad_node_handle,
    void* engine_handle,
    uint32_t channels,
    float b0,
    float b1,
    float b2,
    float a0,
    float a1,
    float a2
);
int mmj_biquad_node_reinit(
    void* biquad_node_handle,
    float b0,
    float b1,
    float b2,
    float a0,
    float a1,
    float a2
);
int mmj_biquad_peaking_eq_coefficients(
    uint32_t sample_rate,
    double gain_db,
    double q,
    double frequency,
    float* out_b0,
    float* out_b1,
    float* out_b2,
    float* out_a0,
    float* out_a1,
    float* out_a2
);
void* mmj_biquad_node_get_node(void* biquad_node_handle);
int mmj_biquad_node_uninit(void* biquad_node_handle);
void mmj_biquad_node_destroy(void* biquad_node_handle);

/* --- notch node --- */
void* mmj_notch_node_create(void);
int mmj_notch_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double q, double frequency);
int mmj_notch_node_reinit(void* handle, uint32_t sample_rate, double q, double frequency);
void* mmj_notch_node_get_node(void* handle);
int mmj_notch_node_uninit(void* handle);
void mmj_notch_node_destroy(void* handle);

/* --- peak node --- */
void* mmj_peak_node_create(void);
int mmj_peak_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency);
int mmj_peak_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency);
void* mmj_peak_node_get_node(void* handle);
int mmj_peak_node_uninit(void* handle);
void mmj_peak_node_destroy(void* handle);

/* --- loshelf node --- */
void* mmj_loshelf_node_create(void);
int mmj_loshelf_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency);
int mmj_loshelf_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency);
void* mmj_loshelf_node_get_node(void* handle);
int mmj_loshelf_node_uninit(void* handle);
void mmj_loshelf_node_destroy(void* handle);

/* --- hishelf node --- */
void* mmj_hishelf_node_create(void);
int mmj_hishelf_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency);
int mmj_hishelf_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency);
void* mmj_hishelf_node_get_node(void* handle);
int mmj_hishelf_node_uninit(void* handle);
void mmj_hishelf_node_destroy(void* handle);

#ifdef __cplusplus
}
#endif

#endif
