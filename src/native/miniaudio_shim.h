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

void* mmj_resource_data_source_create(void);
int mmj_resource_data_source_init_file(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags
);
int mmj_resource_data_source_result(void* data_source_handle);
int mmj_resource_data_source_wait_result(
    void* data_source_handle,
    uint32_t timeout_ms,
    uint32_t poll_interval_ms
);
int64_t mmj_resource_data_source_get_length_in_pcm_frames(void* data_source_handle);
int mmj_resource_data_source_uninit(void* data_source_handle);
void mmj_resource_data_source_destroy(void* data_source_handle);
uint32_t mmj_resource_data_source_flag_async(void);

void* mmj_device_create(void);
int mmj_device_init_playback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
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
int mmj_decoder_init_file_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
);
int mmj_decoder_read_pcm_frames_f32(
    void* decoder_handle,
    float* output,
    uint64_t frame_count,
    uint64_t* frames_read
);
int64_t mmj_decoder_read_probe_f32(void* decoder_handle, uint64_t frame_count);
int mmj_decoder_seek_to_pcm_frame(void* decoder_handle, uint64_t frame_index);
int mmj_decoder_uninit(void* decoder_handle);
void mmj_decoder_destroy(void* decoder_handle);

void* mmj_encoder_create(void);
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

#ifdef __cplusplus
}
#endif

#endif
