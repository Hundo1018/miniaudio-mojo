#ifndef MINIAUDIO_MOJO_SHIM_H
#define MINIAUDIO_MOJO_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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
void mmj_engine_destroy(void* engine_handle);

void* mmj_sound_create(void);
int mmj_sound_init_from_file(
    void* sound_handle,
    void* engine_handle,
    const char* file_path
);
int mmj_sound_start(void* sound_handle);
int mmj_sound_stop(void* sound_handle);
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
int mmj_sound_uninit(void* sound_handle);
void mmj_sound_destroy(void* sound_handle);

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
int mmj_device_start(void* device_handle);
int mmj_device_stop(void* device_handle);
int mmj_device_is_started(void* device_handle);
int mmj_device_get_kind(void* device_handle);
int mmj_device_get_sample_rate(void* device_handle);
int mmj_device_get_channels(void* device_handle);
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

#ifdef __cplusplus
}
#endif

#endif
