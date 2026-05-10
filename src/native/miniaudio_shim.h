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

void* mmj_context_create(void);
int mmj_context_init_default(void* context_handle);
int mmj_context_uninit(void* context_handle);
void mmj_context_destroy(void* context_handle);

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
int mmj_decoder_seek_to_pcm_frame(void* decoder_handle, uint64_t frame_index);
int mmj_decoder_uninit(void* decoder_handle);
void mmj_decoder_destroy(void* decoder_handle);

#ifdef __cplusplus
}
#endif

#endif
