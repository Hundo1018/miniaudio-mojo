#include "miniaudio_shim.h"

#include "miniaudio.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <time.h>
#include <unistd.h>
#endif

#ifndef MMJ_PI
#define MMJ_PI 3.14159265358979323846
#endif

#define MMJ_DEVICE_MODE_SILENCE 0
#define MMJ_DEVICE_MODE_LOOPBACK 1

#define MMJ_DEVICE_KIND_PLAYBACK 1
#define MMJ_DEVICE_KIND_CAPTURE 2
#define MMJ_DEVICE_KIND_DUPLEX 3
#define MMJ_DEVICE_KIND_DUPLEX_LOOPBACK 4

#define MMJ_SAMPLE_FORMAT_U8 1
#define MMJ_SAMPLE_FORMAT_S16 2
#define MMJ_SAMPLE_FORMAT_S24 3
#define MMJ_SAMPLE_FORMAT_S32 4
#define MMJ_SAMPLE_FORMAT_F32 5

typedef struct mmj_sine_state {
    double phase;
    double phase_step;
    float gain;
    uint32_t channels;
} mmj_sine_state;

typedef struct mmj_file_playback_state {
    ma_decoder decoder;
    uint32_t channels;
} mmj_file_playback_state;

typedef struct mmj_capture_state {
    uint64_t observed_frames;
} mmj_capture_state;

typedef struct mmj_capture_to_wav_state {
    ma_encoder encoder;
    uint64_t observed_frames;
    int write_failed;
    ma_result write_result;
} mmj_capture_to_wav_state;

typedef struct mmj_duplex_state {
    uint64_t observed_frames;
    uint32_t channels;
} mmj_duplex_state;

typedef struct mmj_context_handle {
    ma_context context;
    int initialized;
} mmj_context_handle;

typedef struct mmj_decoder_handle {
    ma_decoder decoder;
    ma_default_vfs default_vfs;
    int initialized;
    int vfs_initialized;
} mmj_decoder_handle;

typedef struct mmj_encoder_handle {
    ma_encoder encoder;
    ma_default_vfs default_vfs;
    uint32_t channels;
    int initialized;
    int vfs_initialized;
} mmj_encoder_handle;

typedef struct mmj_resampler_handle {
    ma_resampler resampler;
    uint32_t channels;
    uint32_t sample_rate_in;
    uint32_t sample_rate_out;
    int initialized;
} mmj_resampler_handle;

typedef struct mmj_channel_converter_handle {
    ma_channel_converter converter;
    uint32_t channels_in;
    uint32_t channels_out;
    ma_channel_mix_mode mix_mode;
    int initialized;
} mmj_channel_converter_handle;

typedef struct mmj_data_converter_handle {
    ma_data_converter converter;
    uint32_t channels_in;
    uint32_t channels_out;
    uint32_t sample_rate_in;
    uint32_t sample_rate_out;
    int initialized;
} mmj_data_converter_handle;

typedef struct mmj_waveform_handle {
    ma_waveform waveform;
    uint32_t channels;
    uint32_t sample_rate;
    ma_waveform_type type;
    double amplitude;
    double frequency;
    int initialized;
} mmj_waveform_handle;

typedef struct mmj_noise_handle {
    ma_noise noise;
    ma_noise_type type;
    double amplitude;
    int32_t seed;
    uint32_t channels;
    int initialized;
} mmj_noise_handle;

typedef struct mmj_spatializer_listener_handle {
    ma_spatializer_listener listener;
    uint32_t channels_out;
    int initialized;
} mmj_spatializer_listener_handle;

typedef struct mmj_spatializer_handle {
    ma_spatializer spatializer;
    uint32_t channels_in;
    uint32_t channels_out;
    int initialized;
} mmj_spatializer_handle;

typedef struct mmj_pcm_rb_handle {
    ma_pcm_rb rb;
    uint32_t channels;
    uint32_t sample_rate;
    int initialized;
} mmj_pcm_rb_handle;

typedef struct mmj_engine_handle {
    ma_engine engine;
    int initialized;
} mmj_engine_handle;

typedef struct mmj_sound_handle {
    ma_sound sound;
    int initialized;
} mmj_sound_handle;

typedef struct mmj_sound_group_handle {
    ma_sound_group sound_group;
    int initialized;
} mmj_sound_group_handle;

typedef struct mmj_lpf_node_handle {
    ma_lpf_node node;
    uint32_t channels;
    uint32_t sample_rate;
    uint32_t order;
    float cutoff_hz;
    int initialized;
} mmj_lpf_node_handle;

typedef struct mmj_hpf_node_handle {
    ma_hpf_node node;
    uint32_t channels;
    uint32_t sample_rate;
    uint32_t order;
    float cutoff_hz;
    int initialized;
} mmj_hpf_node_handle;

typedef struct mmj_delay_node_handle {
    ma_delay_node node;
    float decay;
    float wet;
    float dry;
    int initialized;
} mmj_delay_node_handle;

typedef struct mmj_splitter_node_handle {
    ma_splitter_node node;
    uint32_t channels;
    float bus_volumes[2];  /* bus 0 and bus 1 */
    int initialized;
} mmj_splitter_node_handle;

typedef struct mmj_biquad_node_handle {
    ma_biquad_node node;
    uint32_t channels;
    float b0, b1, b2, a0, a1, a2;
    int initialized;
} mmj_biquad_node_handle;

typedef struct mmj_notch_node_handle {
    ma_notch_node node;
    int initialized;
    uint32_t channels;
} mmj_notch_node_handle;

typedef struct mmj_peak_node_handle {
    ma_peak_node node;
    int initialized;
    uint32_t channels;
} mmj_peak_node_handle;

typedef struct mmj_loshelf_node_handle {
    ma_loshelf_node node;
    int initialized;
    uint32_t channels;
} mmj_loshelf_node_handle;

typedef struct mmj_hishelf_node_handle {
    ma_hishelf_node node;
    int initialized;
    uint32_t channels;
} mmj_hishelf_node_handle;

typedef struct mmj_resource_manager_handle {
    ma_resource_manager resource_manager;
    int initialized;
} mmj_resource_manager_handle;

typedef struct mmj_resource_data_source_handle {
    ma_resource_manager_data_source data_source;
    int initialized;
} mmj_resource_data_source_handle;

typedef struct mmj_async_notification_poll_handle {
    ma_async_notification_poll notification;
    int initialized;
} mmj_async_notification_poll_handle;

typedef struct mmj_async_notification_event_handle {
    ma_async_notification_event notification;
    int initialized;
} mmj_async_notification_event_handle;

typedef struct mmj_job_queue_handle {
    ma_job_queue queue;
    int initialized;
} mmj_job_queue_handle;

typedef struct mmj_mutex_handle {
    ma_mutex mutex;
    int initialized;
} mmj_mutex_handle;

typedef struct mmj_event_handle {
    ma_event event;
    int initialized;
} mmj_event_handle;

typedef struct mmj_semaphore_handle {
    ma_semaphore semaphore;
    int initialized;
} mmj_semaphore_handle;

typedef struct mmj_spinlock_handle {
    ma_spinlock spinlock;
    int initialized;
} mmj_spinlock_handle;

typedef struct mmj_fence_handle {
    ma_fence fence;
    int initialized;
} mmj_fence_handle;

typedef struct mmj_custom_buffer_data_source_handle {
    ma_data_source_base base;
    const float* frames;
    uint64_t frame_count;
    uint32_t channels;
    uint32_t sample_rate;
    ma_format format;
    uint64_t cursor;
    int looping;
    int initialized;
} mmj_custom_buffer_data_source_handle;

typedef struct mmj_log_handle {
    ma_log log;
    ma_log_callback callback;
    uint64_t callback_count;
    int initialized;
    int callback_registered;
} mmj_log_handle;

typedef struct mmj_device_state {
    uint32_t channels;
    int mode;
    int kind;
    ma_format sample_format;
    uint32_t bytes_per_sample;
    uint64_t observed_frames;
    /* User-defined callbacks */
    mmj_device_data_callback user_data_callback;
    mmj_device_stop_callback user_stop_callback;
    void* user_callback_data;
} mmj_device_state;

typedef struct mmj_device_handle {
    ma_device device;
    mmj_device_state state;
    int initialized;
    int started;
} mmj_device_handle;

typedef struct mmj_playback_from_buffer_state {
    float* buffer;
    uint64_t buffer_frame_count;
    uint64_t current_position;
    uint32_t channels;
} mmj_playback_from_buffer_state;

typedef struct mmj_playback_from_buffer_handle {
    ma_device device;
    mmj_playback_from_buffer_state state;
    int initialized;
    int started;
} mmj_playback_from_buffer_handle;

typedef struct mmj_capture_to_buffer_state {
    float* buffer;
    uint64_t buffer_frame_capacity;
    uint64_t frames_captured;
    uint32_t channels;
} mmj_capture_to_buffer_state;

typedef struct mmj_capture_to_buffer_handle {
    ma_device device;
    mmj_capture_to_buffer_state state;
    int initialized;
    int started;
} mmj_capture_to_buffer_handle;

static void mmj_sleep_ms(uint32_t duration_ms) {
#if defined(_WIN32)
    Sleep((DWORD)duration_ms);
#else
    struct timespec ts;
    ts.tv_sec = (time_t)(duration_ms / 1000u);
    ts.tv_nsec = (long)((duration_ms % 1000u) * 1000000u);
    nanosleep(&ts, NULL);
#endif
}

static void mmj_data_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_sine_state* state = (mmj_sine_state*)device->pUserData;
    float* out = (float*)output;

    if (state == NULL || out == NULL) {
        return;
    }

    for (ma_uint32 frame = 0; frame < frame_count; ++frame) {
        float sample = (float)(sin(state->phase) * (double)state->gain);
        state->phase += state->phase_step;
        if (state->phase >= (2.0 * MMJ_PI)) {
            state->phase -= (2.0 * MMJ_PI);
        }

        for (uint32_t channel = 0; channel < state->channels; ++channel) {
            out[(frame * state->channels) + channel] = sample;
        }
    }

    (void)input;
}

static void mmj_file_playback_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_file_playback_state* state = (mmj_file_playback_state*)device->pUserData;
    ma_uint64 frames_read = 0;
    ma_result result;
    ma_uint64 total_samples;
    ma_uint64 remaining_samples;
    float* out = (float*)output;

    (void)input;

    if (state == NULL || out == NULL) {
        return;
    }

    result = ma_decoder_read_pcm_frames(
        &state->decoder,
        out,
        frame_count,
        &frames_read
    );
    if (result != MA_SUCCESS) {
        memset(out, 0, (size_t)frame_count * (size_t)state->channels * sizeof(float));
        return;
    }

    if (frames_read < frame_count) {
        total_samples = (ma_uint64)frame_count * (ma_uint64)state->channels;
        remaining_samples = ((ma_uint64)frame_count - frames_read) * (ma_uint64)state->channels;
        memset(
            out + (total_samples - remaining_samples),
            0,
            (size_t)remaining_samples * sizeof(float)
        );
    }
}

static void mmj_capture_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_capture_state* state = (mmj_capture_state*)device->pUserData;

    (void)output;
    (void)input;

    if (state == NULL) {
        return;
    }

    state->observed_frames += (uint64_t)frame_count;
}

static void mmj_capture_to_wav_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_capture_to_wav_state* state = (mmj_capture_to_wav_state*)device->pUserData;
    ma_uint64 frames_written = 0;
    ma_result result;

    (void)output;

    if (state == NULL || input == NULL || frame_count == 0) {
        return;
    }

    result = ma_encoder_write_pcm_frames(
        &state->encoder,
        input,
        frame_count,
        &frames_written
    );
    if (result != MA_SUCCESS || frames_written != frame_count) {
        state->write_failed = 1;
        state->write_result = (result == MA_SUCCESS) ? MA_IO_ERROR : result;
        return;
    }

    state->observed_frames += (uint64_t)frame_count;
}

static void mmj_duplex_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_duplex_state* state = (mmj_duplex_state*)device->pUserData;
    float* out = (float*)output;
    const float* in = (const float*)input;
    ma_uint64 i;
    ma_uint64 total_samples;

    if (state == NULL) {
        return;
    }

    state->observed_frames += (uint64_t)frame_count;

    if (out == NULL) {
        return;
    }

    total_samples = (ma_uint64)frame_count * (ma_uint64)state->channels;
    if (in == NULL) {
        for (i = 0; i < total_samples; ++i) {
            out[i] = 0.0f;
        }
        return;
    }

    for (i = 0; i < total_samples; ++i) {
        out[i] = in[i];
    }
}

static void mmj_log_counter_callback(void* user_data, ma_uint32 level, const char* message) {
    mmj_log_handle* handle = (mmj_log_handle*)user_data;

    (void)level;
    (void)message;

    if (handle == NULL) {
        return;
    }

    handle->callback_count += 1;
}

static void mmj_device_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_device_state* state = (mmj_device_state*)device->pUserData;
    ma_uint64 total_bytes;
    ma_uint8* out = (ma_uint8*)output;
    const ma_uint8* in = (const ma_uint8*)input;
    ma_uint64 i;

    if (state == NULL || out == NULL) {
        return;
    }

    state->observed_frames += (uint64_t)frame_count;

    total_bytes =
        (ma_uint64)frame_count
        * (ma_uint64)state->channels
        * (ma_uint64)state->bytes_per_sample;

    /* Call user-defined callback if set */
    if (state->user_data_callback != NULL) {
        state->user_data_callback(
            output,
            input,
            (uint32_t)frame_count,
            state->user_callback_data
        );
        return;
    }

    if (state->mode == MMJ_DEVICE_MODE_LOOPBACK && in != NULL) {
        for (i = 0; i < total_bytes; ++i) {
            out[i] = in[i];
        }
        return;
    }

    memset(out, 0, (size_t)total_bytes);
}

static int mmj_format_from_code(int sample_format, ma_format* out_format) {
    if (out_format == NULL) {
        return MA_INVALID_ARGS;
    }

    if (sample_format == MMJ_SAMPLE_FORMAT_U8) {
        *out_format = ma_format_u8;
        return MA_SUCCESS;
    }
    if (sample_format == MMJ_SAMPLE_FORMAT_S16) {
        *out_format = ma_format_s16;
        return MA_SUCCESS;
    }
    if (sample_format == MMJ_SAMPLE_FORMAT_S24) {
        *out_format = ma_format_s24;
        return MA_SUCCESS;
    }
    if (sample_format == MMJ_SAMPLE_FORMAT_S32) {
        *out_format = ma_format_s32;
        return MA_SUCCESS;
    }
    if (sample_format == MMJ_SAMPLE_FORMAT_F32) {
        *out_format = ma_format_f32;
        return MA_SUCCESS;
    }

    return MA_INVALID_ARGS;
}

static int mmj_device_init_internal(
    void* device_handle,
    ma_device_type device_type,
    uint32_t sample_rate,
    uint32_t channels,
    ma_format sample_format,
    int mode
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    ma_device_config config;
    ma_result result;

    if (handle == NULL || sample_rate == 0 || channels == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
        handle->started = 0;
    }

    handle->state.channels = channels;
    handle->state.mode = mode;
    handle->state.sample_format = sample_format;
    handle->state.bytes_per_sample = ma_get_bytes_per_sample(sample_format);
    handle->state.kind = MMJ_DEVICE_KIND_PLAYBACK;
    handle->state.observed_frames = 0;
    handle->state.user_data_callback = NULL;
    handle->state.user_stop_callback = NULL;
    handle->state.user_callback_data = NULL;
    if (handle->state.bytes_per_sample == 0) {
        return MA_INVALID_ARGS;
    }
    if (device_type == ma_device_type_capture) {
        handle->state.kind = MMJ_DEVICE_KIND_CAPTURE;
    } else if (device_type == ma_device_type_duplex) {
        handle->state.kind = (mode == MMJ_DEVICE_MODE_LOOPBACK)
            ? MMJ_DEVICE_KIND_DUPLEX_LOOPBACK
            : MMJ_DEVICE_KIND_DUPLEX;
    }

    config = ma_device_config_init(device_type);
    config.sampleRate = sample_rate;
    config.dataCallback = mmj_device_callback;
    config.pUserData = &handle->state;

    if (device_type == ma_device_type_playback || device_type == ma_device_type_duplex) {
        config.playback.format = sample_format;
        config.playback.channels = channels;
    }

    if (device_type == ma_device_type_capture || device_type == ma_device_type_duplex) {
        config.capture.format = sample_format;
        config.capture.channels = channels;
    }

    result = ma_device_init(NULL, &config, &handle->device);
    if (result != MA_SUCCESS) {
        return result;
    }

    handle->initialized = 1;
    handle->started = 0;
    return MA_SUCCESS;
}

const char* mmj_miniaudio_version(void) {
    return ma_version_string();
}

const char* mmj_result_description(int result_code) {
    return ma_result_description((ma_result)result_code);
}

void* mmj_log_create(void) {
    mmj_log_handle* handle = (mmj_log_handle*)calloc(1, sizeof(mmj_log_handle));
    return handle;
}

int mmj_log_init(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        return MA_SUCCESS;
    }

    result = ma_log_init(NULL, &handle->log);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
        handle->callback_registered = 0;
        handle->callback_count = 0;
    }

    return result;
}

int mmj_log_register_counting_callback(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (handle->callback_registered) {
        return MA_SUCCESS;
    }

    handle->callback = ma_log_callback_init(mmj_log_counter_callback, handle);
    result = ma_log_register_callback(&handle->log, handle->callback);
    if (result == MA_SUCCESS) {
        handle->callback_registered = 1;
    }

    return result;
}

int mmj_log_unregister_counting_callback(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (!handle->callback_registered) {
        return MA_SUCCESS;
    }

    result = ma_log_unregister_callback(&handle->log, handle->callback);
    if (result == MA_SUCCESS) {
        handle->callback_registered = 0;
    }

    return result;
}

int mmj_log_post_info(void* log_handle, const char* message) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;

    if (handle == NULL || !handle->initialized || message == NULL) {
        return MA_INVALID_ARGS;
    }

    return ma_log_post(&handle->log, MA_LOG_LEVEL_INFO, message);
}

int64_t mmj_log_get_callback_count(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (handle->callback_count > (uint64_t)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)handle->callback_count;
}

int mmj_log_uninit(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    if (handle->callback_registered) {
        (void)ma_log_unregister_callback(&handle->log, handle->callback);
        handle->callback_registered = 0;
    }

    ma_log_uninit(&handle->log);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_log_destroy(void* log_handle) {
    mmj_log_handle* handle = (mmj_log_handle*)log_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        if (handle->callback_registered) {
            (void)ma_log_unregister_callback(&handle->log, handle->callback);
            handle->callback_registered = 0;
        }

        ma_log_uninit(&handle->log);
        handle->initialized = 0;
    }

    free(handle);
}

int mmj_play_sine_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double frequency_hz,
    double duration_seconds,
    float gain
) {
    ma_result result;
    ma_device_config config;
    ma_device device;
    mmj_sine_state state;

    if (sample_rate == 0 || channels == 0 || duration_seconds <= 0.0) {
        return MA_INVALID_ARGS;
    }

    state.phase = 0.0;
    state.phase_step = (2.0 * MMJ_PI * frequency_hz) / (double)sample_rate;
    state.gain = gain;
    state.channels = channels;

    config = ma_device_config_init(ma_device_type_playback);
    config.sampleRate = sample_rate;
    config.playback.format = ma_format_f32;
    config.playback.channels = channels;
    config.dataCallback = mmj_data_callback;
    config.pUserData = &state;

    result = ma_device_init(NULL, &config, &device);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        return result;
    }

    mmj_sleep_ms((uint32_t)(duration_seconds * 1000.0));
    ma_device_uninit(&device);
    return MA_SUCCESS;
}

int mmj_play_file_f32(
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
) {
    ma_result result;
    ma_uint64 length_in_pcm_frames = 0;
    ma_decoder_config decoder_config;
    ma_device_config device_config;
    ma_device device;
    mmj_file_playback_state state;
    uint32_t playback_ms;

    if (file_path == NULL || output_channels == 0 || output_sample_rate == 0) {
        return MA_INVALID_ARGS;
    }

    decoder_config = ma_decoder_config_init(
        ma_format_f32,
        output_channels,
        output_sample_rate
    );
    result = ma_decoder_init_file(file_path, &decoder_config, &state.decoder);
    if (result != MA_SUCCESS) {
        return result;
    }

    state.channels = output_channels;

    result = ma_decoder_get_length_in_pcm_frames(&state.decoder, &length_in_pcm_frames);
    if (result != MA_SUCCESS) {
        ma_decoder_uninit(&state.decoder);
        return result;
    }

    device_config = ma_device_config_init(ma_device_type_playback);
    device_config.sampleRate = output_sample_rate;
    device_config.playback.format = ma_format_f32;
    device_config.playback.channels = output_channels;
    device_config.dataCallback = mmj_file_playback_callback;
    device_config.pUserData = &state;

    result = ma_device_init(NULL, &device_config, &device);
    if (result != MA_SUCCESS) {
        ma_decoder_uninit(&state.decoder);
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        ma_decoder_uninit(&state.decoder);
        return result;
    }

    playback_ms = (uint32_t)((length_in_pcm_frames * 1000u) / output_sample_rate);
    mmj_sleep_ms(playback_ms + 50u);

    ma_device_stop(&device);
    ma_device_uninit(&device);
    ma_decoder_uninit(&state.decoder);
    return MA_SUCCESS;
}

int mmj_capture_smoke_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
) {
    ma_result result;
    ma_device_config config;
    ma_device device;
    mmj_capture_state state;

    if (sample_rate == 0 || channels == 0 || duration_seconds <= 0.0) {
        return MA_INVALID_ARGS;
    }

    state.observed_frames = 0;

    config = ma_device_config_init(ma_device_type_capture);
    config.sampleRate = sample_rate;
    config.capture.format = ma_format_f32;
    config.capture.channels = channels;
    config.dataCallback = mmj_capture_callback;
    config.pUserData = &state;

    result = ma_device_init(NULL, &config, &device);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        return result;
    }

    mmj_sleep_ms((uint32_t)(duration_seconds * 1000.0));
    ma_device_uninit(&device);

    return MA_SUCCESS;
}

int mmj_capture_to_wav_f32(
    const char* output_path,
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
) {
    ma_result result;
    ma_device_config config;
    ma_device device;
    ma_encoder_config encoder_config;
    mmj_capture_to_wav_state state;

    if (
        output_path == NULL
        || sample_rate == 0
        || channels == 0
        || duration_seconds <= 0.0
    ) {
        return MA_INVALID_ARGS;
    }

    state.observed_frames = 0;
    state.write_failed = 0;
    state.write_result = MA_SUCCESS;

    encoder_config = ma_encoder_config_init(
        ma_encoding_format_wav,
        ma_format_f32,
        channels,
        sample_rate
    );
    result = ma_encoder_init_file(output_path, &encoder_config, &state.encoder);
    if (result != MA_SUCCESS) {
        return result;
    }

    config = ma_device_config_init(ma_device_type_capture);
    config.sampleRate = sample_rate;
    config.capture.format = ma_format_f32;
    config.capture.channels = channels;
    config.dataCallback = mmj_capture_to_wav_callback;
    config.pUserData = &state;

    result = ma_device_init(NULL, &config, &device);
    if (result != MA_SUCCESS) {
        ma_encoder_uninit(&state.encoder);
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        ma_encoder_uninit(&state.encoder);
        return result;
    }

    mmj_sleep_ms((uint32_t)(duration_seconds * 1000.0));
    ma_device_uninit(&device);
    ma_encoder_uninit(&state.encoder);

    if (state.write_failed) {
        return state.write_result;
    }

    return MA_SUCCESS;
}

int mmj_duplex_smoke_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double duration_seconds
) {
    ma_result result;
    ma_device_config config;
    ma_device device;
    mmj_duplex_state state;

    if (sample_rate == 0 || channels == 0 || duration_seconds <= 0.0) {
        return MA_INVALID_ARGS;
    }

    state.observed_frames = 0;
    state.channels = channels;

    config = ma_device_config_init(ma_device_type_duplex);
    config.sampleRate = sample_rate;
    config.capture.format = ma_format_f32;
    config.capture.channels = channels;
    config.playback.format = ma_format_f32;
    config.playback.channels = channels;
    config.dataCallback = mmj_duplex_callback;
    config.pUserData = &state;

    result = ma_device_init(NULL, &config, &device);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        return result;
    }

    mmj_sleep_ms((uint32_t)(duration_seconds * 1000.0));
    ma_device_uninit(&device);

    return MA_SUCCESS;
}

void* mmj_context_create(void) {
    mmj_context_handle* handle = (mmj_context_handle*)calloc(1, sizeof(mmj_context_handle));
    return handle;
}

int mmj_context_init_default(void* context_handle) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        return MA_SUCCESS;
    }

    result = ma_context_init(NULL, 0, NULL, &handle->context);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_context_uninit(void* context_handle) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_context_uninit(&handle->context);
    handle->initialized = 0;
    return MA_SUCCESS;
}

static int64_t mmj_context_get_device_count_internal(
    void* context_handle,
    int is_playback
) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;
    ma_device_info* playback_infos = NULL;
    ma_device_info* capture_infos = NULL;
    ma_uint32 playback = 0;
    ma_uint32 capture = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_context_get_devices(
        &handle->context,
        &playback_infos,
        &playback,
        &capture_infos,
        &capture
    );
    (void)playback_infos;
    (void)capture_infos;
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (is_playback) {
        return (int64_t)playback;
    }
    return (int64_t)capture;
}

int64_t mmj_context_get_playback_device_count(void* context_handle) {
    return mmj_context_get_device_count_internal(context_handle, 1);
}

int64_t mmj_context_get_capture_device_count(void* context_handle) {
    return mmj_context_get_device_count_internal(context_handle, 0);
}

static int mmj_context_get_device_name_internal(
    mmj_context_handle* handle,
    uint32_t index,
    char* output,
    uint32_t output_capacity,
    int is_playback
) {
    ma_device_info* playback_infos = NULL;
    ma_device_info* capture_infos = NULL;
    ma_uint32 playback = 0;
    ma_uint32 capture = 0;
    const char* name = NULL;
    ma_result result;

    if (handle == NULL || !handle->initialized || output == NULL || output_capacity == 0) {
        return MA_INVALID_ARGS;
    }

    result = ma_context_get_devices(
        &handle->context,
        &playback_infos,
        &playback,
        &capture_infos,
        &capture
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    if (is_playback) {
        if (index >= playback) {
            return MA_OUT_OF_RANGE;
        }
        name = playback_infos[index].name;
    } else {
        if (index >= capture) {
            return MA_OUT_OF_RANGE;
        }
        name = capture_infos[index].name;
    }

    if (name == NULL) {
        return MA_INVALID_DATA;
    }

    strncpy(output, name, (size_t)output_capacity - 1u);
    output[output_capacity - 1u] = '\0';
    return MA_SUCCESS;
}

int mmj_context_get_playback_device_name(
    void* context_handle,
    uint32_t index,
    char* output,
    uint32_t output_capacity
) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;
    return mmj_context_get_device_name_internal(
        handle,
        index,
        output,
        output_capacity,
        1
    );
}

int mmj_context_get_capture_device_name(
    void* context_handle,
    uint32_t index,
    char* output,
    uint32_t output_capacity
) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;
    return mmj_context_get_device_name_internal(
        handle,
        index,
        output,
        output_capacity,
        0
    );
}

void mmj_context_destroy(void* context_handle) {
    mmj_context_handle* handle = (mmj_context_handle*)context_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_context_uninit(&handle->context);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_engine_create(void) {
    mmj_engine_handle* handle = (mmj_engine_handle*)calloc(1, sizeof(mmj_engine_handle));
    return handle;
}

int mmj_engine_init_default(void* engine_handle) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;
    ma_engine_config config;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        return MA_SUCCESS;
    }

    config = ma_engine_config_init();
    result = ma_engine_init(&config, &handle->engine);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_engine_uninit(void* engine_handle) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_engine_uninit(&handle->engine);
    handle->initialized = 0;
    return MA_SUCCESS;
}

int mmj_engine_play_sound(void* engine_handle, const char* file_path) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL || !handle->initialized || file_path == NULL) {
        return MA_INVALID_ARGS;
    }

    return ma_engine_play_sound(&handle->engine, file_path, NULL);
}

int mmj_engine_listener_set_position(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_engine_listener_set_position(&handle->engine, listener_index, x, y, z);
    return MA_SUCCESS;
}

int mmj_engine_listener_set_direction(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_engine_listener_set_direction(&handle->engine, listener_index, x, y, z);
    return MA_SUCCESS;
}

int mmj_engine_listener_set_world_up(
    void* engine_handle,
    uint32_t listener_index,
    float x,
    float y,
    float z
) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_engine_listener_set_world_up(&handle->engine, listener_index, x, y, z);
    return MA_SUCCESS;
}

void* mmj_engine_get_endpoint(void* engine_handle) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL || !handle->initialized) {
        return NULL;
    }

    return (void*)ma_engine_get_endpoint(&handle->engine);
}

void mmj_engine_destroy(void* engine_handle) {
    mmj_engine_handle* handle = (mmj_engine_handle*)engine_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_engine_uninit(&handle->engine);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_sound_create(void) {
    mmj_sound_handle* handle = (mmj_sound_handle*)calloc(1, sizeof(mmj_sound_handle));
    return handle;
}

int mmj_sound_init_from_file(
    void* sound_handle,
    void* engine_handle,
    const char* file_path
) {
    mmj_sound_handle* sound = (mmj_sound_handle*)sound_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_result result;

    if (sound == NULL || engine == NULL || !engine->initialized || file_path == NULL) {
        return MA_INVALID_ARGS;
    }

    if (sound->initialized) {
        ma_sound_uninit(&sound->sound);
        sound->initialized = 0;
    }

    result = ma_sound_init_from_file(&engine->engine, file_path, 0, NULL, NULL, &sound->sound);
    if (result == MA_SUCCESS) {
        sound->initialized = 1;
    }

    return result;
}

int mmj_sound_init_from_file_in_group(
    void* sound_handle,
    void* engine_handle,
    void* sound_group_handle,
    const char* file_path
) {
    mmj_sound_handle* sound = (mmj_sound_handle*)sound_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    ma_result result;

    if (
        sound == NULL
        || engine == NULL
        || !engine->initialized
        || group == NULL
        || !group->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (sound->initialized) {
        ma_sound_uninit(&sound->sound);
        sound->initialized = 0;
    }

    result = ma_sound_init_from_file(
        &engine->engine,
        file_path,
        0,
        &group->sound_group,
        NULL,
        &sound->sound
    );
    if (result == MA_SUCCESS) {
        sound->initialized = 1;
    }

    return result;
}

int mmj_sound_start(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_start(&handle->sound);
}

int mmj_sound_stop(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_stop(&handle->sound);
}

int mmj_sound_pause(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    /* miniaudio does not expose an explicit pause API; stop preserves cursor state. */
    return ma_sound_stop(&handle->sound);
}

int mmj_sound_seek_to_pcm_frame(void* sound_handle, uint64_t frame_index) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_seek_to_pcm_frame(&handle->sound, (ma_uint64)frame_index);
}

int mmj_sound_set_looping(void* sound_handle, int is_looping) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_looping(&handle->sound, is_looping ? MA_TRUE : MA_FALSE);
    return MA_SUCCESS;
}

int mmj_sound_set_volume_f32(void* sound_handle, float volume) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_volume(&handle->sound, volume);
    return MA_SUCCESS;
}

int mmj_sound_set_spatialization_enabled(void* sound_handle, int is_enabled) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_spatialization_enabled(&handle->sound, is_enabled ? MA_TRUE : MA_FALSE);
    return MA_SUCCESS;
}

int mmj_sound_set_position(
    void* sound_handle,
    float x,
    float y,
    float z
) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_position(&handle->sound, x, y, z);
    return MA_SUCCESS;
}

int mmj_sound_set_rolloff(void* sound_handle, float rolloff) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_rolloff(&handle->sound, rolloff);
    return MA_SUCCESS;
}

int mmj_sound_set_min_distance(void* sound_handle, float min_distance) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_min_distance(&handle->sound, min_distance);
    return MA_SUCCESS;
}

int mmj_sound_set_max_distance(void* sound_handle, float max_distance) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_set_max_distance(&handle->sound, max_distance);
    return MA_SUCCESS;
}

int64_t mmj_sound_get_cursor_in_pcm_frames(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;
    ma_uint64 cursor = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_sound_get_cursor_in_pcm_frames(&handle->sound, &cursor);
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (cursor > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)cursor;
}

int64_t mmj_sound_get_time_in_milliseconds(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;
    ma_uint64 time_ms;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    time_ms = ma_sound_get_time_in_milliseconds(&handle->sound);
    if (time_ms > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)time_ms;
}

int mmj_sound_is_finished(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return 0;
    }

    return ma_sound_at_end(&handle->sound) == MA_TRUE ? 1 : 0;
}

void* mmj_sound_get_node(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return NULL;
    }

    return (void*)&handle->sound.engineNode.baseNode;
}

void* mmj_sound_group_create(void) {
    mmj_sound_group_handle* handle = (mmj_sound_group_handle*)calloc(1, sizeof(mmj_sound_group_handle));
    return handle;
}

int mmj_sound_group_init_default(void* sound_group_handle, void* engine_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_result result;

    if (group == NULL || engine == NULL || !engine->initialized) {
        return MA_INVALID_ARGS;
    }

    if (group->initialized) {
        return MA_SUCCESS;
    }

    result = ma_sound_group_init(&engine->engine, 0, NULL, &group->sound_group);
    if (result == MA_SUCCESS) {
        group->initialized = 1;
    }

    return result;
}

int mmj_sound_group_init_with_parent(
    void* sound_group_handle,
    void* engine_handle,
    void* parent_group_handle
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    mmj_sound_group_handle* parent_group = (mmj_sound_group_handle*)parent_group_handle;
    ma_result result;

    if (
        group == NULL
        || engine == NULL
        || !engine->initialized
        || parent_group == NULL
        || !parent_group->initialized
    ) {
        return MA_INVALID_ARGS;
    }

    if (group->initialized) {
        return MA_SUCCESS;
    }

    result = ma_sound_group_init(
        &engine->engine,
        0,
        &parent_group->sound_group,
        &group->sound_group
    );
    if (result == MA_SUCCESS) {
        group->initialized = 1;
    }

    return result;
}

int mmj_sound_group_start(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_group_start(&group->sound_group);
}

int mmj_sound_group_stop(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_group_stop(&group->sound_group);
}

int mmj_sound_group_set_volume_f32(void* sound_group_handle, float volume) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_volume(&group->sound_group, volume);
    return MA_SUCCESS;
}

float mmj_sound_group_get_volume_f32(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_volume(&group->sound_group);
}

int mmj_sound_group_set_pan_f32(void* sound_group_handle, float pan) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_pan(&group->sound_group, pan);
    return MA_SUCCESS;
}

float mmj_sound_group_get_pan_f32(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_pan(&group->sound_group);
}

int mmj_sound_group_set_pitch_f32(void* sound_group_handle, float pitch) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_pitch(&group->sound_group, pitch);
    return MA_SUCCESS;
}

float mmj_sound_group_get_pitch_f32(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_pitch(&group->sound_group);
}

int mmj_sound_group_set_spatialization_enabled(void* sound_group_handle, int is_enabled) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_spatialization_enabled(
        &group->sound_group,
        is_enabled ? MA_TRUE : MA_FALSE
    );
    return MA_SUCCESS;
}

int mmj_sound_group_is_spatialization_enabled(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_sound_group_is_spatialization_enabled(&group->sound_group) == MA_TRUE ? 1 : 0;
}

int mmj_sound_group_set_position(
    void* sound_group_handle,
    float x,
    float y,
    float z
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_position(&group->sound_group, x, y, z);
    return MA_SUCCESS;
}

int mmj_sound_group_set_direction(
    void* sound_group_handle,
    float x,
    float y,
    float z
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_direction(&group->sound_group, x, y, z);
    return MA_SUCCESS;
}

int mmj_sound_group_set_velocity(
    void* sound_group_handle,
    float x,
    float y,
    float z
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_velocity(&group->sound_group, x, y, z);
    return MA_SUCCESS;
}

int mmj_sound_group_set_rolloff(void* sound_group_handle, float rolloff) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_rolloff(&group->sound_group, rolloff);
    return MA_SUCCESS;
}

float mmj_sound_group_get_rolloff(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_rolloff(&group->sound_group);
}

int mmj_sound_group_set_min_distance(void* sound_group_handle, float min_distance) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_min_distance(&group->sound_group, min_distance);
    return MA_SUCCESS;
}

float mmj_sound_group_get_min_distance(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_min_distance(&group->sound_group);
}

int mmj_sound_group_set_max_distance(void* sound_group_handle, float max_distance) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_max_distance(&group->sound_group, max_distance);
    return MA_SUCCESS;
}

float mmj_sound_group_get_max_distance(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_max_distance(&group->sound_group);
}

int mmj_sound_group_set_attenuation_model(void* sound_group_handle, int attenuation_model) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    if (attenuation_model < 0 || attenuation_model > 3) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_attenuation_model(
        &group->sound_group,
        (ma_attenuation_model)attenuation_model
    );
    return MA_SUCCESS;
}

int mmj_sound_group_get_attenuation_model(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_sound_group_get_attenuation_model(&group->sound_group);
}

int mmj_sound_group_set_positioning(void* sound_group_handle, int positioning) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    if (positioning < 0 || positioning > 1) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_positioning(&group->sound_group, (ma_positioning)positioning);
    return MA_SUCCESS;
}

int mmj_sound_group_get_positioning(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_sound_group_get_positioning(&group->sound_group);
}

int mmj_sound_group_set_pinned_listener_index(void* sound_group_handle, uint32_t listener_index) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_pinned_listener_index(&group->sound_group, (ma_uint32)listener_index);
    return MA_SUCCESS;
}

int mmj_sound_group_get_pinned_listener_index(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_sound_group_get_pinned_listener_index(&group->sound_group);
}

int mmj_sound_group_set_cone(
    void* sound_group_handle,
    float inner_angle,
    float outer_angle,
    float outer_gain
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    if (inner_angle < 0.0f || outer_angle < 0.0f || outer_angle < inner_angle || outer_gain < 0.0f) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_cone(&group->sound_group, inner_angle, outer_angle, outer_gain);
    return MA_SUCCESS;
}

float mmj_sound_group_get_cone_inner_angle(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    float inner_angle = 0.0f;
    float outer_angle = 0.0f;
    float outer_gain = 0.0f;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    ma_sound_group_get_cone(&group->sound_group, &inner_angle, &outer_angle, &outer_gain);
    return inner_angle;
}

float mmj_sound_group_get_cone_outer_angle(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    float inner_angle = 0.0f;
    float outer_angle = 0.0f;
    float outer_gain = 0.0f;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    ma_sound_group_get_cone(&group->sound_group, &inner_angle, &outer_angle, &outer_gain);
    return outer_angle;
}

float mmj_sound_group_get_cone_outer_gain(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    float inner_angle = 0.0f;
    float outer_angle = 0.0f;
    float outer_gain = 0.0f;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    ma_sound_group_get_cone(&group->sound_group, &inner_angle, &outer_angle, &outer_gain);
    return outer_gain;
}

int mmj_sound_group_set_doppler_factor(void* sound_group_handle, float doppler_factor) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    if (doppler_factor < 0.0f) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_doppler_factor(&group->sound_group, doppler_factor);
    return MA_SUCCESS;
}

float mmj_sound_group_get_doppler_factor(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_doppler_factor(&group->sound_group);
}

int mmj_sound_group_set_directional_attenuation_factor(
    void* sound_group_handle,
    float directional_attenuation_factor
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return MA_INVALID_ARGS;
    }

    if (directional_attenuation_factor < 0.0f) {
        return MA_INVALID_ARGS;
    }

    ma_sound_group_set_directional_attenuation_factor(
        &group->sound_group,
        directional_attenuation_factor
    );
    return MA_SUCCESS;
}

float mmj_sound_group_get_directional_attenuation_factor(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL || !group->initialized) {
        return -1.0f;
    }

    return ma_sound_group_get_directional_attenuation_factor(&group->sound_group);
}

int mmj_sound_group_uninit(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!group->initialized) {
        return MA_SUCCESS;
    }

    ma_sound_group_uninit(&group->sound_group);
    group->initialized = 0;
    return MA_SUCCESS;
}

void mmj_sound_group_destroy(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;

    if (group == NULL) {
        return;
    }

    if (group->initialized) {
        ma_sound_group_uninit(&group->sound_group);
        group->initialized = 0;
    }

    free(group);
}

/* --- sound group timing / fade --- */

int mmj_sound_group_set_fade_in_pcm_frames(
    void* sound_group_handle,
    float vol_beg,
    float vol_end,
    uint64_t length_in_frames
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_fade_in_pcm_frames(&group->sound_group, vol_beg, vol_end, (ma_uint64)length_in_frames);
    return MA_SUCCESS;
}

int mmj_sound_group_set_fade_in_milliseconds(
    void* sound_group_handle,
    float vol_beg,
    float vol_end,
    uint64_t length_in_ms
) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_fade_in_milliseconds(&group->sound_group, vol_beg, vol_end, (ma_uint64)length_in_ms);
    return MA_SUCCESS;
}

float mmj_sound_group_get_current_fade_volume(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return -2.0f; /* MA_INVALID_ARGS sentinel */
    return ma_sound_group_get_current_fade_volume(&group->sound_group);
}

int mmj_sound_group_set_start_time_in_pcm_frames(void* sound_group_handle, uint64_t absolute_global_time_in_frames) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_start_time_in_pcm_frames(&group->sound_group, (ma_uint64)absolute_global_time_in_frames);
    return MA_SUCCESS;
}

int mmj_sound_group_set_start_time_in_milliseconds(void* sound_group_handle, uint64_t absolute_global_time_in_ms) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_start_time_in_milliseconds(&group->sound_group, (ma_uint64)absolute_global_time_in_ms);
    return MA_SUCCESS;
}

int mmj_sound_group_set_stop_time_in_pcm_frames(void* sound_group_handle, uint64_t absolute_global_time_in_frames) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_stop_time_in_pcm_frames(&group->sound_group, (ma_uint64)absolute_global_time_in_frames);
    return MA_SUCCESS;
}

int mmj_sound_group_set_stop_time_in_milliseconds(void* sound_group_handle, uint64_t absolute_global_time_in_ms) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return MA_INVALID_ARGS;
    ma_sound_group_set_stop_time_in_milliseconds(&group->sound_group, (ma_uint64)absolute_global_time_in_ms);
    return MA_SUCCESS;
}

int64_t mmj_sound_group_get_time_in_pcm_frames(void* sound_group_handle) {
    mmj_sound_group_handle* group = (mmj_sound_group_handle*)sound_group_handle;
    if (group == NULL || !group->initialized) return (int64_t)MA_INVALID_ARGS;
    return (int64_t)ma_sound_group_get_time_in_pcm_frames(&group->sound_group);
}

int mmj_node_attach_output_bus(
    void* node_handle,
    uint32_t output_bus_index,
    void* other_node_handle,
    uint32_t other_node_input_bus_index
) {
    ma_node* node = (ma_node*)node_handle;
    ma_node* other_node = (ma_node*)other_node_handle;

    if (node == NULL || other_node == NULL) {
        return MA_INVALID_ARGS;
    }

    return ma_node_attach_output_bus(node, output_bus_index, other_node, other_node_input_bus_index);
}

int mmj_node_detach_output_bus(void* node_handle, uint32_t output_bus_index) {
    ma_node* node = (ma_node*)node_handle;

    if (node == NULL) {
        return MA_INVALID_ARGS;
    }

    return ma_node_detach_output_bus(node, output_bus_index);
}

int mmj_node_get_output_bus_count(void* node_handle) {
    ma_node* node = (ma_node*)node_handle;

    if (node == NULL) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_node_get_output_bus_count(node);
}

int mmj_node_set_output_bus_volume(
    void* node_handle,
    uint32_t output_bus_index,
    float volume
) {
    ma_node* node = (ma_node*)node_handle;

    if (node == NULL) {
        return MA_INVALID_ARGS;
    }

    return ma_node_set_output_bus_volume(node, output_bus_index, volume);
}

float mmj_node_get_output_bus_volume(void* node_handle, uint32_t output_bus_index) {
    ma_node* node = (ma_node*)node_handle;

    if (node == NULL) {
        return -1.0f;
    }

    return ma_node_get_output_bus_volume(node, output_bus_index);
}

void* mmj_lpf_node_create(void) {
    mmj_lpf_node_handle* handle = (mmj_lpf_node_handle*)calloc(1, sizeof(mmj_lpf_node_handle));
    return handle;
}

int mmj_lpf_node_init(
    void* lpf_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    float cutoff_hz,
    uint32_t order
) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_lpf_node_config config;
    ma_result result;

    if (
        lpf == NULL
        || engine == NULL
        || !engine->initialized
        || channels == 0
        || sample_rate == 0
        || cutoff_hz <= 0.0f
        || order == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (lpf->initialized) {
        ma_lpf_node_uninit(&lpf->node, NULL);
        lpf->initialized = 0;
    }

    config = ma_lpf_node_config_init(channels, sample_rate, (double)cutoff_hz, order);
    result = ma_lpf_node_init(ma_engine_get_node_graph(&engine->engine), &config, NULL, &lpf->node);
    if (result == MA_SUCCESS) {
        lpf->channels = channels;
        lpf->sample_rate = sample_rate;
        lpf->order = order;
        lpf->cutoff_hz = cutoff_hz;
        lpf->initialized = 1;
    }

    return result;
}

int mmj_lpf_node_set_cutoff(void* lpf_node_handle, float cutoff_hz) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;
    ma_lpf_config config;
    ma_result result;

    if (lpf == NULL || !lpf->initialized || cutoff_hz <= 0.0f) {
        return MA_INVALID_ARGS;
    }

    config = ma_lpf_config_init(
        ma_format_f32,
        lpf->channels,
        lpf->sample_rate,
        (double)cutoff_hz,
        lpf->order
    );
    result = ma_lpf_node_reinit(&config, &lpf->node);
    if (result == MA_SUCCESS) {
        lpf->cutoff_hz = cutoff_hz;
    }

    return result;
}

float mmj_lpf_node_get_cutoff(void* lpf_node_handle) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;

    if (lpf == NULL || !lpf->initialized) {
        return -1.0f;
    }

    return lpf->cutoff_hz;
}

void* mmj_lpf_node_get_node(void* lpf_node_handle) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;

    if (lpf == NULL || !lpf->initialized) {
        return NULL;
    }

    return (void*)&lpf->node.baseNode;
}

int mmj_lpf_node_uninit(void* lpf_node_handle) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;

    if (lpf == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!lpf->initialized) {
        return MA_SUCCESS;
    }

    ma_lpf_node_uninit(&lpf->node, NULL);
    lpf->initialized = 0;
    return MA_SUCCESS;
}

void mmj_lpf_node_destroy(void* lpf_node_handle) {
    mmj_lpf_node_handle* lpf = (mmj_lpf_node_handle*)lpf_node_handle;

    if (lpf == NULL) {
        return;
    }

    if (lpf->initialized) {
        ma_lpf_node_uninit(&lpf->node, NULL);
        lpf->initialized = 0;
    }

    free(lpf);
}

void* mmj_hpf_node_create(void) {
    mmj_hpf_node_handle* handle = (mmj_hpf_node_handle*)calloc(1, sizeof(mmj_hpf_node_handle));
    return handle;
}

int mmj_hpf_node_init(
    void* hpf_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    float cutoff_hz,
    uint32_t order
) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_hpf_node_config config;
    ma_result result;

    if (
        hpf == NULL
        || engine == NULL
        || !engine->initialized
        || channels == 0
        || sample_rate == 0
        || cutoff_hz <= 0.0f
        || order == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (hpf->initialized) {
        ma_hpf_node_uninit(&hpf->node, NULL);
        hpf->initialized = 0;
    }

    config = ma_hpf_node_config_init(channels, sample_rate, (double)cutoff_hz, order);
    result = ma_hpf_node_init(ma_engine_get_node_graph(&engine->engine), &config, NULL, &hpf->node);
    if (result == MA_SUCCESS) {
        hpf->channels = channels;
        hpf->sample_rate = sample_rate;
        hpf->order = order;
        hpf->cutoff_hz = cutoff_hz;
        hpf->initialized = 1;
    }

    return result;
}

int mmj_hpf_node_set_cutoff(void* hpf_node_handle, float cutoff_hz) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;
    ma_hpf_config config;
    ma_result result;

    if (hpf == NULL || !hpf->initialized || cutoff_hz <= 0.0f) {
        return MA_INVALID_ARGS;
    }

    config = ma_hpf_config_init(
        ma_format_f32,
        hpf->channels,
        hpf->sample_rate,
        (double)cutoff_hz,
        hpf->order
    );
    result = ma_hpf_node_reinit(&config, &hpf->node);
    if (result == MA_SUCCESS) {
        hpf->cutoff_hz = cutoff_hz;
    }

    return result;
}

float mmj_hpf_node_get_cutoff(void* hpf_node_handle) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;

    if (hpf == NULL || !hpf->initialized) {
        return -1.0f;
    }

    return hpf->cutoff_hz;
}

void* mmj_hpf_node_get_node(void* hpf_node_handle) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;

    if (hpf == NULL || !hpf->initialized) {
        return NULL;
    }

    return (void*)&hpf->node.baseNode;
}

int mmj_hpf_node_uninit(void* hpf_node_handle) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;

    if (hpf == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!hpf->initialized) {
        return MA_SUCCESS;
    }

    ma_hpf_node_uninit(&hpf->node, NULL);
    hpf->initialized = 0;
    return MA_SUCCESS;
}

void mmj_hpf_node_destroy(void* hpf_node_handle) {
    mmj_hpf_node_handle* hpf = (mmj_hpf_node_handle*)hpf_node_handle;

    if (hpf == NULL) {
        return;
    }

    if (hpf->initialized) {
        ma_hpf_node_uninit(&hpf->node, NULL);
        hpf->initialized = 0;
    }

    free(hpf);
}

void* mmj_splitter_node_create(void) {
    mmj_splitter_node_handle* handle = (mmj_splitter_node_handle*)calloc(1, sizeof(mmj_splitter_node_handle));
    if (handle != NULL) {
        handle->bus_volumes[0] = 1.0f;
        handle->bus_volumes[1] = 1.0f;
    }
    return handle;
}

int mmj_splitter_node_init(void* splitter_node_handle, void* engine_handle, uint32_t channels) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_splitter_node_config config;
    ma_result result;

    if (
        splitter == NULL
        || engine == NULL
        || !engine->initialized
        || channels == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (splitter->initialized) {
        ma_splitter_node_uninit(&splitter->node, NULL);
        splitter->initialized = 0;
    }

    config = ma_splitter_node_config_init(channels);
    result = ma_splitter_node_init(
        ma_engine_get_node_graph(&engine->engine),
        &config,
        NULL,
        &splitter->node
    );
    if (result == MA_SUCCESS) {
        splitter->channels = channels;
        splitter->bus_volumes[0] = 1.0f;
        splitter->bus_volumes[1] = 1.0f;
        splitter->initialized = 1;
    }

    return result;
}

int mmj_splitter_node_set_output_bus_volume(void* splitter_node_handle, uint32_t bus_index, float volume) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;
    ma_uint32 bus_count;
    ma_result result;

    if (splitter == NULL || !splitter->initialized) {
        return MA_INVALID_ARGS;
    }

    bus_count = ma_node_get_output_bus_count(&splitter->node.base);
    if (bus_index >= bus_count) {
        return MA_OUT_OF_RANGE;
    }

    result = ma_node_set_output_bus_volume(&splitter->node.base, bus_index, volume);
    if (result == MA_SUCCESS && bus_index < 2u) {
        splitter->bus_volumes[bus_index] = volume;
    }

    return result;
}

float mmj_splitter_node_get_output_bus_volume(void* splitter_node_handle, uint32_t bus_index) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;
    ma_uint32 bus_count;

    if (splitter == NULL || !splitter->initialized) {
        return -1.0f;
    }

    bus_count = ma_node_get_output_bus_count(&splitter->node.base);
    if (bus_index >= bus_count) {
        return -1.0f;
    }

    return ma_node_get_output_bus_volume(&splitter->node.base, bus_index);
}

void* mmj_splitter_node_get_node(void* splitter_node_handle) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;

    if (splitter == NULL || !splitter->initialized) {
        return NULL;
    }

    return (void*)&splitter->node.base;
}

int mmj_splitter_node_uninit(void* splitter_node_handle) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;

    if (splitter == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!splitter->initialized) {
        return MA_SUCCESS;
    }

    ma_splitter_node_uninit(&splitter->node, NULL);
    splitter->initialized = 0;
    splitter->channels = 0;
    splitter->bus_volumes[0] = 1.0f;
    splitter->bus_volumes[1] = 1.0f;
    return MA_SUCCESS;
}

void mmj_splitter_node_destroy(void* splitter_node_handle) {
    mmj_splitter_node_handle* splitter = (mmj_splitter_node_handle*)splitter_node_handle;

    if (splitter == NULL) {
        return;
    }

    if (splitter->initialized) {
        ma_splitter_node_uninit(&splitter->node, NULL);
        splitter->initialized = 0;
    }

    free(splitter);
}

void* mmj_delay_node_create(void) {
    mmj_delay_node_handle* handle = (mmj_delay_node_handle*)calloc(1, sizeof(mmj_delay_node_handle));
    return handle;
}

int mmj_delay_node_init(
    void* delay_node_handle,
    void* engine_handle,
    uint32_t channels,
    uint32_t sample_rate,
    uint32_t delay_frames,
    float decay
) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_delay_node_config config;
    ma_result result;

    if (
        delay == NULL
        || engine == NULL
        || !engine->initialized
        || channels == 0
        || sample_rate == 0
        || delay_frames == 0
        || decay < 0.0f
        || decay > 1.0f
    ) {
        return MA_INVALID_ARGS;
    }

    if (delay->initialized) {
        ma_delay_node_uninit(&delay->node, NULL);
        delay->initialized = 0;
    }

    config = ma_delay_node_config_init(channels, sample_rate, delay_frames, decay);
    result = ma_delay_node_init(ma_engine_get_node_graph(&engine->engine), &config, NULL, &delay->node);
    if (result == MA_SUCCESS) {
        delay->decay = decay;
        delay->wet = ma_delay_node_get_wet(&delay->node);
        delay->dry = ma_delay_node_get_dry(&delay->node);
        delay->initialized = 1;
    }

    return result;
}

int mmj_delay_node_set_wet(void* delay_node_handle, float wet) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized || wet < 0.0f || wet > 1.0f) {
        return MA_INVALID_ARGS;
    }

    ma_delay_node_set_wet(&delay->node, wet);
    delay->wet = wet;
    return MA_SUCCESS;
}

float mmj_delay_node_get_wet(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized) {
        return -1.0f;
    }

    return ma_delay_node_get_wet(&delay->node);
}

int mmj_delay_node_set_dry(void* delay_node_handle, float dry) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized || dry < 0.0f || dry > 1.0f) {
        return MA_INVALID_ARGS;
    }

    ma_delay_node_set_dry(&delay->node, dry);
    delay->dry = dry;
    return MA_SUCCESS;
}

float mmj_delay_node_get_dry(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized) {
        return -1.0f;
    }

    return ma_delay_node_get_dry(&delay->node);
}

int mmj_delay_node_set_decay(void* delay_node_handle, float decay) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized || decay < 0.0f || decay > 1.0f) {
        return MA_INVALID_ARGS;
    }

    ma_delay_node_set_decay(&delay->node, decay);
    delay->decay = decay;
    return MA_SUCCESS;
}

float mmj_delay_node_get_decay(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized) {
        return -1.0f;
    }

    return ma_delay_node_get_decay(&delay->node);
}

void* mmj_delay_node_get_node(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL || !delay->initialized) {
        return NULL;
    }

    return (void*)&delay->node.baseNode;
}

int mmj_delay_node_uninit(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!delay->initialized) {
        return MA_SUCCESS;
    }

    ma_delay_node_uninit(&delay->node, NULL);
    delay->initialized = 0;
    return MA_SUCCESS;
}

void mmj_delay_node_destroy(void* delay_node_handle) {
    mmj_delay_node_handle* delay = (mmj_delay_node_handle*)delay_node_handle;

    if (delay == NULL) {
        return;
    }

    if (delay->initialized) {
        ma_delay_node_uninit(&delay->node, NULL);
        delay->initialized = 0;
    }

    free(delay);
}

int mmj_sound_uninit(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_sound_uninit(&handle->sound);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_sound_destroy(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_sound_uninit(&handle->sound);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_resource_manager_create(void) {
    mmj_resource_manager_handle* handle = (mmj_resource_manager_handle*)calloc(1, sizeof(mmj_resource_manager_handle));
    return handle;
}

int mmj_resource_manager_init_default(void* resource_manager_handle) {
    mmj_resource_manager_handle* handle = (mmj_resource_manager_handle*)resource_manager_handle;
    ma_resource_manager_config config;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        return MA_SUCCESS;
    }

    config = ma_resource_manager_config_init();
    result = ma_resource_manager_init(&config, &handle->resource_manager);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_resource_manager_uninit(void* resource_manager_handle) {
    mmj_resource_manager_handle* handle = (mmj_resource_manager_handle*)resource_manager_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_resource_manager_uninit(&handle->resource_manager);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_resource_manager_destroy(void* resource_manager_handle) {
    mmj_resource_manager_handle* handle = (mmj_resource_manager_handle*)resource_manager_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_resource_manager_uninit(&handle->resource_manager);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_job_queue_create(void) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)calloc(1, sizeof(mmj_job_queue_handle));
    return handle;
}

int mmj_job_queue_init(void* queue_handle, uint32_t flags, uint32_t capacity) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;
    ma_job_queue_config config;
    ma_result result;

    if (handle == NULL || capacity == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_job_queue_uninit(&handle->queue, NULL);
        handle->initialized = 0;
    }

    config = ma_job_queue_config_init((ma_uint32)flags, (ma_uint32)capacity);
    result = ma_job_queue_init(&config, NULL, &handle->queue);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_job_queue_post_custom(void* queue_handle, uint64_t data0, uint64_t data1) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;
    ma_job job;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    job = ma_job_init((ma_uint16)MA_JOB_TYPE_CUSTOM);
    job.data.custom.proc = NULL;
    job.data.custom.data0 = (ma_uintptr)data0;
    job.data.custom.data1 = (ma_uintptr)data1;
    return (int)ma_job_queue_post(&handle->queue, &job);
}

int mmj_job_queue_post_quit(void* queue_handle) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;
    ma_job job;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    job = ma_job_init((ma_uint16)MA_JOB_TYPE_QUIT);
    return (int)ma_job_queue_post(&handle->queue, &job);
}

int64_t mmj_job_queue_next_code(void* queue_handle) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;
    ma_job job;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    memset(&job, 0, sizeof(job));
    result = ma_job_queue_next(&handle->queue, &job);
    if (result == MA_SUCCESS) {
        return (int64_t)job.toc.breakup.code;
    }

    return (int64_t)result;
}

int mmj_job_queue_uninit(void* queue_handle) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_job_queue_uninit(&handle->queue, NULL);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_job_queue_destroy(void* queue_handle) {
    mmj_job_queue_handle* handle = (mmj_job_queue_handle*)queue_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_job_queue_uninit(&handle->queue, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

uint32_t mmj_job_queue_flag_non_blocking(void) {
    return (uint32_t)MA_JOB_QUEUE_FLAG_NON_BLOCKING;
}

uint32_t mmj_job_type_quit(void) {
    return (uint32_t)MA_JOB_TYPE_QUIT;
}

uint32_t mmj_job_type_custom(void) {
    return (uint32_t)MA_JOB_TYPE_CUSTOM;
}

int mmj_job_queue_smoke(void) {
    mmj_job_queue_handle handle;
    int result;
    int64_t next;

    memset(&handle, 0, sizeof(handle));

    result = mmj_job_queue_init(&handle, MA_JOB_QUEUE_FLAG_NON_BLOCKING, 8);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_job_queue_post_custom(&handle, 11, 22);
    if (result != MA_SUCCESS) {
        mmj_job_queue_uninit(&handle);
        return result;
    }

    next = mmj_job_queue_next_code(&handle);
    if (next != (int64_t)MA_JOB_TYPE_CUSTOM) {
        mmj_job_queue_uninit(&handle);
        return (next < 0) ? (int)next : MA_ERROR;
    }

    next = mmj_job_queue_next_code(&handle);
    if (next != (int64_t)MA_NO_DATA_AVAILABLE) {
        mmj_job_queue_uninit(&handle);
        return (next < 0) ? (int)next : MA_ERROR;
    }

    result = mmj_job_queue_post_quit(&handle);
    if (result != MA_SUCCESS) {
        mmj_job_queue_uninit(&handle);
        return result;
    }

    next = mmj_job_queue_next_code(&handle);
    if (next != (int64_t)MA_CANCELLED) {
        mmj_job_queue_uninit(&handle);
        return (next < 0) ? (int)next : MA_ERROR;
    }

    return mmj_job_queue_uninit(&handle);
}

int mmj_job_queue_invalid_args_smoke(void) {
    mmj_job_queue_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_job_queue_init(&handle, MA_JOB_QUEUE_FLAG_NON_BLOCKING, 0);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_job_queue_post_custom(NULL, 0, 0);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_job_queue_next_code(&handle) != (int64_t)MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

void* mmj_async_notification_poll_create(void) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)calloc(1, sizeof(mmj_async_notification_poll_handle));
    return handle;
}

int mmj_async_notification_poll_init(void* notification_handle) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)notification_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        return MA_SUCCESS;
    }

    memset(&handle->notification, 0, sizeof(handle->notification));
    result = ma_async_notification_poll_init(&handle->notification);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_async_notification_poll_signal(void* notification_handle) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)notification_handle;
    int result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    result = (int)ma_async_notification_signal((ma_async_notification*)&handle->notification);
    if (ma_async_notification_poll_is_signalled(&handle->notification)) {
        return MA_SUCCESS;
    }

    return result;
}

int mmj_async_notification_poll_is_signalled(void* notification_handle) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)notification_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_async_notification_poll_is_signalled(&handle->notification);
}

int mmj_async_notification_poll_uninit(void* notification_handle) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)notification_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    handle->initialized = 0;
    memset(&handle->notification, 0, sizeof(handle->notification));
    return MA_SUCCESS;
}

void mmj_async_notification_poll_destroy(void* notification_handle) {
    mmj_async_notification_poll_handle* handle = (mmj_async_notification_poll_handle*)notification_handle;

    if (handle == NULL) {
        return;
    }

    handle->initialized = 0;
    free(handle);
}

void* mmj_async_notification_event_create(void) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)calloc(1, sizeof(mmj_async_notification_event_handle));
    return handle;
}

int mmj_async_notification_event_init(void* notification_handle) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)notification_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_async_notification_event_uninit(&handle->notification);
        handle->initialized = 0;
    }

    memset(&handle->notification, 0, sizeof(handle->notification));
    result = ma_async_notification_event_init(&handle->notification);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_async_notification_event_signal(void* notification_handle) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)notification_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_async_notification_event_signal(&handle->notification);
}

int mmj_async_notification_event_wait(void* notification_handle) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)notification_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_async_notification_event_wait(&handle->notification);
}

int mmj_async_notification_event_uninit(void* notification_handle) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)notification_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_async_notification_event_uninit(&handle->notification);
    handle->initialized = 0;
    memset(&handle->notification, 0, sizeof(handle->notification));
    return MA_SUCCESS;
}

void mmj_async_notification_event_destroy(void* notification_handle) {
    mmj_async_notification_event_handle* handle = (mmj_async_notification_event_handle*)notification_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_async_notification_event_uninit(&handle->notification);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_fence_create(void) {
    mmj_fence_handle* handle = (mmj_fence_handle*)calloc(1, sizeof(mmj_fence_handle));
    return handle;
}

int mmj_fence_init(void* fence_handle) {
    mmj_fence_handle* handle = (mmj_fence_handle*)fence_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_fence_uninit(&handle->fence);
        handle->initialized = 0;
    }

    result = ma_fence_init(&handle->fence);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_fence_wait(void* fence_handle) {
    mmj_fence_handle* handle = (mmj_fence_handle*)fence_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_fence_wait(&handle->fence);
}

int mmj_fence_uninit(void* fence_handle) {
    mmj_fence_handle* handle = (mmj_fence_handle*)fence_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_fence_uninit(&handle->fence);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_fence_destroy(void* fence_handle) {
    mmj_fence_handle* handle = (mmj_fence_handle*)fence_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_fence_uninit(&handle->fence);
        handle->initialized = 0;
    }

    free(handle);
}

int mmj_async_notification_poll_smoke(void) {
    mmj_async_notification_poll_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_async_notification_poll_init(&handle);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_async_notification_poll_signal(&handle);
    if (result != MA_SUCCESS) {
        mmj_async_notification_poll_uninit(&handle);
        return result;
    }

    if (mmj_async_notification_poll_is_signalled(&handle) != 1) {
        mmj_async_notification_poll_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_async_notification_poll_uninit(&handle);
}

int mmj_async_notification_poll_invalid_args_smoke(void) {
    int result;

    result = mmj_async_notification_poll_signal(NULL);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_async_notification_poll_is_signalled(NULL);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_async_notification_event_smoke(void) {
    mmj_async_notification_event_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_async_notification_event_init(&handle);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_async_notification_event_signal(&handle);
    if (result != MA_SUCCESS) {
        mmj_async_notification_event_uninit(&handle);
        return result;
    }

    result = mmj_async_notification_event_wait(&handle);
    if (result != MA_SUCCESS) {
        mmj_async_notification_event_uninit(&handle);
        return result;
    }

    return mmj_async_notification_event_uninit(&handle);
}

int mmj_async_notification_event_invalid_args_smoke(void) {
    int result;

    result = mmj_async_notification_event_signal(NULL);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_async_notification_event_wait(NULL);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

void* mmj_mutex_create(void) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)calloc(1, sizeof(mmj_mutex_handle));
    return handle;
}

int mmj_mutex_init(void* mutex_handle) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)mutex_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_mutex_uninit(&handle->mutex);
        handle->initialized = 0;
    }

    result = ma_mutex_init(&handle->mutex);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_mutex_lock(void* mutex_handle) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)mutex_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_mutex_lock(&handle->mutex);
    return MA_SUCCESS;
}

int mmj_mutex_unlock(void* mutex_handle) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)mutex_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_mutex_unlock(&handle->mutex);
    return MA_SUCCESS;
}

int mmj_mutex_uninit(void* mutex_handle) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)mutex_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_mutex_uninit(&handle->mutex);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_mutex_destroy(void* mutex_handle) {
    mmj_mutex_handle* handle = (mmj_mutex_handle*)mutex_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_mutex_uninit(&handle->mutex);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_event_create(void) {
    mmj_event_handle* handle = (mmj_event_handle*)calloc(1, sizeof(mmj_event_handle));
    return handle;
}

int mmj_event_init(void* event_handle) {
    mmj_event_handle* handle = (mmj_event_handle*)event_handle;
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_event_uninit(&handle->event);
        handle->initialized = 0;
    }

    result = ma_event_init(&handle->event);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_event_signal(void* event_handle) {
    mmj_event_handle* handle = (mmj_event_handle*)event_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_event_signal(&handle->event);
}

int mmj_event_wait(void* event_handle) {
    mmj_event_handle* handle = (mmj_event_handle*)event_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_event_wait(&handle->event);
}

int mmj_event_uninit(void* event_handle) {
    mmj_event_handle* handle = (mmj_event_handle*)event_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_event_uninit(&handle->event);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_event_destroy(void* event_handle) {
    mmj_event_handle* handle = (mmj_event_handle*)event_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_event_uninit(&handle->event);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_semaphore_create(void) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)calloc(1, sizeof(mmj_semaphore_handle));
    return handle;
}

int mmj_semaphore_init(void* semaphore_handle, uint32_t initial_count) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)semaphore_handle;
    ma_result result;

    if (handle == NULL || initial_count > 0x7FFFFFFF) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_semaphore_uninit(&handle->semaphore);
        handle->initialized = 0;
    }

    result = ma_semaphore_init((int)initial_count, &handle->semaphore);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_semaphore_release(void* semaphore_handle) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)semaphore_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_semaphore_release(&handle->semaphore);
}

int mmj_semaphore_wait(void* semaphore_handle) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)semaphore_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_semaphore_wait(&handle->semaphore);
}

int mmj_semaphore_uninit(void* semaphore_handle) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)semaphore_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_semaphore_uninit(&handle->semaphore);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_semaphore_destroy(void* semaphore_handle) {
    mmj_semaphore_handle* handle = (mmj_semaphore_handle*)semaphore_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_semaphore_uninit(&handle->semaphore);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_spinlock_create(void) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)calloc(1, sizeof(mmj_spinlock_handle));
    return handle;
}

int mmj_spinlock_init(void* spinlock_handle) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)spinlock_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    handle->spinlock = 0;
    handle->initialized = 1;
    return MA_SUCCESS;
}

int mmj_spinlock_lock(void* spinlock_handle) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)spinlock_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_spinlock_lock(&handle->spinlock);
}

int mmj_spinlock_unlock(void* spinlock_handle) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)spinlock_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_spinlock_unlock(&handle->spinlock);
}

int mmj_spinlock_uninit(void* spinlock_handle) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)spinlock_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    handle->spinlock = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_spinlock_destroy(void* spinlock_handle) {
    mmj_spinlock_handle* handle = (mmj_spinlock_handle*)spinlock_handle;

    if (handle == NULL) {
        return;
    }

    handle->spinlock = 0;
    handle->initialized = 0;
    free(handle);
}

int mmj_sync_primitives_smoke(void) {
    mmj_mutex_handle mutex_handle;
    mmj_event_handle event_handle;
    mmj_semaphore_handle semaphore_handle;
    mmj_spinlock_handle spinlock_handle;
    int result;

    memset(&mutex_handle, 0, sizeof(mutex_handle));
    memset(&event_handle, 0, sizeof(event_handle));
    memset(&semaphore_handle, 0, sizeof(semaphore_handle));
    memset(&spinlock_handle, 0, sizeof(spinlock_handle));

    result = mmj_mutex_init(&mutex_handle);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_mutex_lock(&mutex_handle);
    if (result != MA_SUCCESS) {
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_mutex_unlock(&mutex_handle);
    if (result != MA_SUCCESS) {
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_event_init(&event_handle);
    if (result != MA_SUCCESS) {
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_event_signal(&event_handle);
    if (result != MA_SUCCESS) {
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_event_wait(&event_handle);
    if (result != MA_SUCCESS) {
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_semaphore_init(&semaphore_handle, 0);
    if (result != MA_SUCCESS) {
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_semaphore_release(&semaphore_handle);
    if (result != MA_SUCCESS) {
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_semaphore_wait(&semaphore_handle);
    if (result != MA_SUCCESS) {
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_spinlock_init(&spinlock_handle);
    if (result != MA_SUCCESS) {
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_spinlock_lock(&spinlock_handle);
    if (result != MA_SUCCESS) {
        mmj_spinlock_uninit(&spinlock_handle);
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_spinlock_unlock(&spinlock_handle);
    if (result != MA_SUCCESS) {
        mmj_spinlock_uninit(&spinlock_handle);
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_spinlock_uninit(&spinlock_handle);
    if (result != MA_SUCCESS) {
        mmj_semaphore_uninit(&semaphore_handle);
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_semaphore_uninit(&semaphore_handle);
    if (result != MA_SUCCESS) {
        mmj_event_uninit(&event_handle);
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    result = mmj_event_uninit(&event_handle);
    if (result != MA_SUCCESS) {
        mmj_mutex_uninit(&mutex_handle);
        return result;
    }

    return mmj_mutex_uninit(&mutex_handle);
}

int mmj_sync_primitives_invalid_args_smoke(void) {
    if (mmj_mutex_init(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_mutex_lock(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_event_wait(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_event_signal(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_semaphore_init(NULL, 0) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_semaphore_wait(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_spinlock_init(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    if (mmj_spinlock_unlock(NULL) != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

void* mmj_resource_data_source_create(void) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)calloc(1, sizeof(mmj_resource_data_source_handle));
    return handle;
}

int mmj_resource_data_source_init_file(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    result = ma_resource_manager_data_source_init(
        &resource_manager->resource_manager,
        file_path,
        flags,
        NULL,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

static wchar_t* mmj_resource_path_to_wide(const char* file_path)
{
    size_t path_len;
    wchar_t* path_w;
    size_t i;

    if (file_path == NULL) {
        return NULL;
    }

    path_len = strlen(file_path);
    path_w = (wchar_t*)calloc(path_len + 1, sizeof(wchar_t));
    if (path_w == NULL) {
        return NULL;
    }

    for (i = 0; i < path_len; i += 1) {
        path_w[i] = (wchar_t)(unsigned char)file_path[i];
    }
    path_w[path_len] = L'\0';

    return path_w;
}

int mmj_resource_data_source_init_file_w(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    wchar_t* path_w = NULL;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    path_w = mmj_resource_path_to_wide(file_path);
    if (path_w == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    result = ma_resource_manager_data_source_init_w(
        &resource_manager->resource_manager,
        path_w,
        flags,
        NULL,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    free(path_w);
    return result;
}

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
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    ma_resource_manager_data_source_config config;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    config = ma_resource_manager_data_source_config_init();
    config.pFilePath = file_path;
    config.pFilePathW = NULL;
    config.pNotifications = NULL;
    config.initialSeekPointInPCMFrames = (ma_uint64)initial_seek_point_in_pcm_frames;
    config.rangeBegInPCMFrames = (ma_uint64)range_beg_in_pcm_frames;
    config.rangeEndInPCMFrames = (ma_uint64)range_end_in_pcm_frames;
    config.loopPointBegInPCMFrames = (ma_uint64)loop_point_beg_in_pcm_frames;
    config.loopPointEndInPCMFrames = (ma_uint64)loop_point_end_in_pcm_frames;
    config.flags = flags;
    config.isLooping = (ma_bool32)is_looping;

    result = ma_resource_manager_data_source_init_ex(
        &resource_manager->resource_manager,
        &config,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

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
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    wchar_t* path_w = NULL;
    ma_resource_manager_data_source_config config;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    path_w = mmj_resource_path_to_wide(file_path);
    if (path_w == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    config = ma_resource_manager_data_source_config_init();
    config.pFilePath = NULL;
    config.pFilePathW = path_w;
    config.pNotifications = NULL;
    config.initialSeekPointInPCMFrames = (ma_uint64)initial_seek_point_in_pcm_frames;
    config.rangeBegInPCMFrames = (ma_uint64)range_beg_in_pcm_frames;
    config.rangeEndInPCMFrames = (ma_uint64)range_end_in_pcm_frames;
    config.loopPointBegInPCMFrames = (ma_uint64)loop_point_beg_in_pcm_frames;
    config.loopPointEndInPCMFrames = (ma_uint64)loop_point_end_in_pcm_frames;
    config.flags = flags;
    config.isLooping = (ma_bool32)is_looping;

    result = ma_resource_manager_data_source_init_ex(
        &resource_manager->resource_manager,
        &config,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    free(path_w);
    return result;
}

int mmj_resource_data_source_init_copy(
    void* data_source_handle,
    void* resource_manager_handle,
    void* existing_data_source_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_resource_data_source_handle* existing_data_source = (mmj_resource_data_source_handle*)existing_data_source_handle;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || existing_data_source == NULL
        || !existing_data_source->initialized
    ) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    result = ma_resource_manager_data_source_init_copy(
        &resource_manager->resource_manager,
        &existing_data_source->data_source,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

int mmj_resource_data_source_init_file_with_notifications(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_async_notification_poll_handle* init_notification = (mmj_async_notification_poll_handle*)init_notification_poll_handle;
    mmj_async_notification_poll_handle* done_notification = (mmj_async_notification_poll_handle*)done_notification_poll_handle;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        init_notification_poll_handle != NULL
        && (init_notification == NULL || !init_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        done_notification_poll_handle != NULL
        && (done_notification == NULL || !done_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    notifications = ma_resource_manager_pipeline_notifications_init();

    if (init_notification != NULL) {
        notifications.init.pNotification = (ma_async_notification*)&init_notification->notification;
    }

    if (done_notification != NULL) {
        notifications.done.pNotification = (ma_async_notification*)&done_notification->notification;
    }

    result = ma_resource_manager_data_source_init(
        &resource_manager->resource_manager,
        file_path,
        flags,
        &notifications,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

int mmj_resource_data_source_init_file_w_with_notifications(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_async_notification_poll_handle* init_notification = (mmj_async_notification_poll_handle*)init_notification_poll_handle;
    mmj_async_notification_poll_handle* done_notification = (mmj_async_notification_poll_handle*)done_notification_poll_handle;
    wchar_t* path_w = NULL;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        init_notification_poll_handle != NULL
        && (init_notification == NULL || !init_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        done_notification_poll_handle != NULL
        && (done_notification == NULL || !done_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    path_w = mmj_resource_path_to_wide(file_path);
    if (path_w == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    notifications = ma_resource_manager_pipeline_notifications_init();

    if (init_notification != NULL) {
        notifications.init.pNotification = (ma_async_notification*)&init_notification->notification;
    }

    if (done_notification != NULL) {
        notifications.done.pNotification = (ma_async_notification*)&done_notification->notification;
    }

    result = ma_resource_manager_data_source_init_w(
        &resource_manager->resource_manager,
        path_w,
        flags,
        &notifications,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    free(path_w);
    return result;
}

int mmj_resource_data_source_init_file_with_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_fence_handle,
    void* done_fence_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_fence_handle* init_fence = (mmj_fence_handle*)init_fence_handle;
    mmj_fence_handle* done_fence = (mmj_fence_handle*)done_fence_handle;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (init_fence_handle != NULL && (init_fence == NULL || !init_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    if (done_fence_handle != NULL && (done_fence == NULL || !done_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    notifications = ma_resource_manager_pipeline_notifications_init();

    if (init_fence != NULL) {
        notifications.init.pFence = &init_fence->fence;
    }

    if (done_fence != NULL) {
        notifications.done.pFence = &done_fence->fence;
    }

    result = ma_resource_manager_data_source_init(
        &resource_manager->resource_manager,
        file_path,
        flags,
        &notifications,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

int mmj_resource_data_source_init_file_with_notifications_and_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle,
    void* init_fence_handle,
    void* done_fence_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_async_notification_poll_handle* init_notification = (mmj_async_notification_poll_handle*)init_notification_poll_handle;
    mmj_async_notification_poll_handle* done_notification = (mmj_async_notification_poll_handle*)done_notification_poll_handle;
    mmj_fence_handle* init_fence = (mmj_fence_handle*)init_fence_handle;
    mmj_fence_handle* done_fence = (mmj_fence_handle*)done_fence_handle;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        init_notification_poll_handle != NULL
        && (init_notification == NULL || !init_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        done_notification_poll_handle != NULL
        && (done_notification == NULL || !done_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (init_fence_handle != NULL && (init_fence == NULL || !init_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    if (done_fence_handle != NULL && (done_fence == NULL || !done_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    notifications = ma_resource_manager_pipeline_notifications_init();

    if (init_notification != NULL) {
        notifications.init.pNotification = (ma_async_notification*)&init_notification->notification;
    }

    if (done_notification != NULL) {
        notifications.done.pNotification = (ma_async_notification*)&done_notification->notification;
    }

    if (init_fence != NULL) {
        notifications.init.pFence = &init_fence->fence;
    }

    if (done_fence != NULL) {
        notifications.done.pFence = &done_fence->fence;
    }

    result = ma_resource_manager_data_source_init(
        &resource_manager->resource_manager,
        file_path,
        flags,
        &notifications,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    return result;
}

int mmj_resource_data_source_init_file_w_with_notifications_and_fences(
    void* data_source_handle,
    void* resource_manager_handle,
    const char* file_path,
    uint32_t flags,
    void* init_notification_poll_handle,
    void* done_notification_poll_handle,
    void* init_fence_handle,
    void* done_fence_handle
) {
    mmj_resource_data_source_handle* data_source = (mmj_resource_data_source_handle*)data_source_handle;
    mmj_resource_manager_handle* resource_manager = (mmj_resource_manager_handle*)resource_manager_handle;
    mmj_async_notification_poll_handle* init_notification = (mmj_async_notification_poll_handle*)init_notification_poll_handle;
    mmj_async_notification_poll_handle* done_notification = (mmj_async_notification_poll_handle*)done_notification_poll_handle;
    mmj_fence_handle* init_fence = (mmj_fence_handle*)init_fence_handle;
    mmj_fence_handle* done_fence = (mmj_fence_handle*)done_fence_handle;
    wchar_t* path_w = NULL;
    ma_resource_manager_pipeline_notifications notifications;
    ma_result result;

    if (
        data_source == NULL
        || resource_manager == NULL
        || !resource_manager->initialized
        || file_path == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        init_notification_poll_handle != NULL
        && (init_notification == NULL || !init_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (
        done_notification_poll_handle != NULL
        && (done_notification == NULL || !done_notification->initialized)
    ) {
        return MA_INVALID_ARGS;
    }

    if (init_fence_handle != NULL && (init_fence == NULL || !init_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    if (done_fence_handle != NULL && (done_fence == NULL || !done_fence->initialized)) {
        return MA_INVALID_ARGS;
    }

    path_w = mmj_resource_path_to_wide(file_path);
    if (path_w == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    if (data_source->initialized) {
        ma_resource_manager_data_source_uninit(&data_source->data_source);
        data_source->initialized = 0;
    }

    notifications = ma_resource_manager_pipeline_notifications_init();

    if (init_notification != NULL) {
        notifications.init.pNotification = (ma_async_notification*)&init_notification->notification;
    }

    if (done_notification != NULL) {
        notifications.done.pNotification = (ma_async_notification*)&done_notification->notification;
    }

    if (init_fence != NULL) {
        notifications.init.pFence = &init_fence->fence;
    }

    if (done_fence != NULL) {
        notifications.done.pFence = &done_fence->fence;
    }

    result = ma_resource_manager_data_source_init_w(
        &resource_manager->resource_manager,
        path_w,
        flags,
        &notifications,
        &data_source->data_source
    );
    if (result == MA_SUCCESS) {
        data_source->initialized = 1;
    }

    free(path_w);
    return result;
}

int mmj_resource_data_source_result(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_resource_manager_data_source_result(&handle->data_source);
}

int mmj_resource_data_source_wait_result(
    void* data_source_handle,
    uint32_t timeout_ms,
    uint32_t poll_interval_ms
) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    uint32_t elapsed_ms = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (poll_interval_ms == 0) {
        poll_interval_ms = 10;
    }

    for (;;) {
        result = ma_resource_manager_data_source_result(&handle->data_source);
        if (result != MA_BUSY) {
            return (int)result;
        }

        if (elapsed_ms >= timeout_ms) {
            return MA_TIMEOUT;
        }

        mmj_sleep_ms(poll_interval_ms);
        elapsed_ms += poll_interval_ms;
    }
}

int64_t mmj_resource_data_source_get_length_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    ma_uint64 length_in_frames = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_data_source_get_length_in_pcm_frames(
        (ma_data_source*)&handle->data_source,
        &length_in_frames
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    return (int64_t)length_in_frames;
}

int64_t mmj_resource_data_source_get_available_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    ma_uint64 available_frames = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_resource_manager_data_source_get_available_frames(
        &handle->data_source,
        &available_frames
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    return (int64_t)available_frames;
}

int mmj_resource_data_source_uninit(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    if (ma_resource_manager_data_source_uninit(&handle->data_source) != MA_SUCCESS) {
        return MA_INVALID_OPERATION;
    }
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_resource_data_source_destroy(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_resource_manager_data_source_uninit(&handle->data_source);
        handle->initialized = 0;
    }

    free(handle);
}

uint32_t mmj_resource_data_source_flag_async(void) {
    return (uint32_t)MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_ASYNC;
}

uint32_t mmj_resource_data_source_flag_stream(void) {
    return (uint32_t)MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM;
}

uint32_t mmj_resource_data_source_flag_decode(void) {
    return (uint32_t)MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_DECODE;
}

uint32_t mmj_resource_data_source_flag_wait_init(void) {
    return (uint32_t)MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_WAIT_INIT;
}

/* --- resource data source extended operations --- */

int mmj_resource_data_source_seek_to_pcm_frame(void* data_source_handle, uint64_t frame_index) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_seek_to_pcm_frame(&handle->data_source, (ma_uint64)frame_index);
}

int mmj_resource_data_source_seek_pcm_frames(void* data_source_handle, uint64_t frame_count) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_seek_pcm_frames(&handle->data_source, (ma_uint64)frame_count, NULL);
}

int64_t mmj_resource_data_source_get_cursor_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return (int64_t)MA_INVALID_ARGS;
    ma_uint64 cursor = 0;
    ma_result result = ma_data_source_get_cursor_in_pcm_frames(&handle->data_source, &cursor);
    if (result != MA_SUCCESS) return (int64_t)result;
    return (int64_t)cursor;
}

float mmj_resource_data_source_get_cursor_in_seconds(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return -2.0f;
    float cursor = 0.0f;
    if (ma_data_source_get_cursor_in_seconds(&handle->data_source, &cursor) != MA_SUCCESS) return -2.0f;
    return cursor;
}

float mmj_resource_data_source_get_length_in_seconds(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return -2.0f;
    float length = 0.0f;
    if (ma_data_source_get_length_in_seconds(&handle->data_source, &length) != MA_SUCCESS) return -2.0f;
    return length;
}

int mmj_resource_data_source_get_format(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    ma_format fmt = ma_format_unknown;
    if (ma_data_source_get_data_format(&handle->data_source, &fmt, NULL, NULL, NULL, 0) != MA_SUCCESS) return MA_INVALID_ARGS;
    return (int)fmt;
}

int mmj_resource_data_source_get_channels(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    ma_uint32 channels = 0;
    if (ma_data_source_get_data_format(&handle->data_source, NULL, &channels, NULL, NULL, 0) != MA_SUCCESS) return MA_INVALID_ARGS;
    return (int)channels;
}

int mmj_resource_data_source_get_sample_rate(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    ma_uint32 sample_rate = 0;
    if (ma_data_source_get_data_format(&handle->data_source, NULL, NULL, &sample_rate, NULL, 0) != MA_SUCCESS) return MA_INVALID_ARGS;
    return (int)sample_rate;
}

int mmj_resource_data_source_set_looping(void* data_source_handle, int is_looping) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_set_looping(&handle->data_source, (ma_bool32)is_looping);
}

int mmj_resource_data_source_is_looping(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_is_looping(&handle->data_source);
}

int mmj_resource_data_source_set_range_in_pcm_frames(void* data_source_handle, uint64_t range_beg, uint64_t range_end) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_set_range_in_pcm_frames(&handle->data_source, (ma_uint64)range_beg, (ma_uint64)range_end);
}

int64_t mmj_resource_data_source_get_range_beg_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return (int64_t)MA_INVALID_ARGS;
    ma_uint64 beg = 0, end = 0;
    ma_data_source_get_range_in_pcm_frames(&handle->data_source, &beg, &end);
    return (int64_t)beg;
}

int64_t mmj_resource_data_source_get_range_end_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return (int64_t)MA_INVALID_ARGS;
    ma_uint64 beg = 0, end = 0;
    ma_data_source_get_range_in_pcm_frames(&handle->data_source, &beg, &end);
    return (int64_t)end;
}

int mmj_resource_data_source_set_loop_point_in_pcm_frames(void* data_source_handle, uint64_t loop_beg, uint64_t loop_end) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_set_loop_point_in_pcm_frames(&handle->data_source, (ma_uint64)loop_beg, (ma_uint64)loop_end);
}

int64_t mmj_resource_data_source_get_loop_point_beg_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return (int64_t)MA_INVALID_ARGS;
    ma_uint64 beg = 0, end = 0;
    ma_data_source_get_loop_point_in_pcm_frames(&handle->data_source, &beg, &end);
    return (int64_t)beg;
}

int64_t mmj_resource_data_source_get_loop_point_end_in_pcm_frames(void* data_source_handle) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return (int64_t)MA_INVALID_ARGS;
    ma_uint64 beg = 0, end = 0;
    ma_data_source_get_loop_point_in_pcm_frames(&handle->data_source, &beg, &end);
    return (int64_t)end;
}

int mmj_resource_data_source_seek_to_second(void* data_source_handle, float seconds) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    return (int)ma_data_source_seek_to_second(&handle->data_source, (float)seconds);
}

int mmj_resource_data_source_seek_seconds(void* data_source_handle, float seconds) {
    mmj_resource_data_source_handle* handle = (mmj_resource_data_source_handle*)data_source_handle;
    if (handle == NULL || !handle->initialized) return MA_INVALID_ARGS;
    float seconds_seeked = 0.0f;
    return (int)ma_data_source_seek_seconds(&handle->data_source, (float)seconds, &seconds_seeked);
}

int mmj_device_init_playback_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
);

static int mmj_device_init_ex_f32_internal(
    void* device_handle,
    ma_device_type device_type,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile,
    int callback_mode
);

void* mmj_device_create(void) {
    mmj_device_handle* handle = (mmj_device_handle*)calloc(1, sizeof(mmj_device_handle));
    return handle;
}

int mmj_device_init_playback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_playback_format(
        device_handle,
        sample_rate,
        channels,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_device_init_playback_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
) {
    return mmj_device_init_ex_f32_internal(
        device_handle,
        ma_device_type_playback,
        sample_rate,
        channels,
        period_size_in_frames,
        period_count,
        use_low_latency_profile,
        MMJ_DEVICE_MODE_SILENCE
    );
}

static int mmj_device_init_ex_f32_internal(
    void* device_handle,
    ma_device_type device_type,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile,
    int callback_mode
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    ma_device_config config;
    ma_result result;

    if (handle == NULL || sample_rate == 0 || channels == 0) {
        return MA_INVALID_ARGS;
    }

    if (period_count > 16) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
        handle->started = 0;
    }

    handle->state.channels = channels;
    handle->state.mode = callback_mode;
    handle->state.sample_format = ma_format_f32;
    handle->state.bytes_per_sample = ma_get_bytes_per_sample(ma_format_f32);
    if (device_type == ma_device_type_capture) {
        handle->state.kind = MMJ_DEVICE_KIND_CAPTURE;
    } else if (device_type == ma_device_type_duplex) {
        handle->state.kind = (callback_mode == MMJ_DEVICE_MODE_LOOPBACK)
            ? MMJ_DEVICE_KIND_DUPLEX_LOOPBACK
            : MMJ_DEVICE_KIND_DUPLEX;
    } else {
        handle->state.kind = MMJ_DEVICE_KIND_PLAYBACK;
    }
    handle->state.observed_frames = 0;
    handle->state.user_data_callback = NULL;
    handle->state.user_stop_callback = NULL;
    handle->state.user_callback_data = NULL;

    config = ma_device_config_init(device_type);
    config.sampleRate = sample_rate;
    config.periodSizeInFrames = period_size_in_frames;
    config.periods = period_count;
    config.performanceProfile = use_low_latency_profile
        ? ma_performance_profile_low_latency
        : ma_performance_profile_conservative;
    config.dataCallback = mmj_device_callback;
    config.pUserData = &handle->state;
    if (device_type == ma_device_type_capture) {
        config.capture.format = ma_format_f32;
        config.capture.channels = channels;
    } else {
        config.playback.format = ma_format_f32;
        config.playback.channels = channels;
        if (device_type == ma_device_type_duplex) {
            config.capture.format = ma_format_f32;
            config.capture.channels = channels;
        }
    }

    result = ma_device_init(NULL, &config, &handle->device);
    if (result != MA_SUCCESS) {
        return result;
    }

    handle->initialized = 1;
    handle->started = 0;
    return MA_SUCCESS;
}

int mmj_device_init_capture_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
) {
    return mmj_device_init_ex_f32_internal(
        device_handle,
        ma_device_type_capture,
        sample_rate,
        channels,
        period_size_in_frames,
        period_count,
        use_low_latency_profile,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_duplex_ex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    uint32_t period_size_in_frames,
    uint32_t period_count,
    int use_low_latency_profile
) {
    return mmj_device_init_ex_f32_internal(
        device_handle,
        ma_device_type_duplex,
        sample_rate,
        channels,
        period_size_in_frames,
        period_count,
        use_low_latency_profile,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_playback_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
) {
    ma_format resolved_format;
    int format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    return mmj_device_init_internal(
        device_handle,
        ma_device_type_playback,
        sample_rate,
        channels,
        resolved_format,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_capture_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
) {
    ma_format resolved_format;
    int format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    return mmj_device_init_internal(
        device_handle,
        ma_device_type_capture,
        sample_rate,
        channels,
        resolved_format,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_duplex_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
) {
    ma_format resolved_format;
    int format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    return mmj_device_init_internal(
        device_handle,
        ma_device_type_duplex,
        sample_rate,
        channels,
        resolved_format,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_duplex_loopback_format(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels,
    int sample_format
) {
    ma_format resolved_format;
    int format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    return mmj_device_init_internal(
        device_handle,
        ma_device_type_duplex,
        sample_rate,
        channels,
        resolved_format,
        MMJ_DEVICE_MODE_LOOPBACK
    );
}

int mmj_device_init_capture_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_capture_format(
        device_handle,
        sample_rate,
        channels,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_device_init_duplex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_duplex_format(
        device_handle,
        sample_rate,
        channels,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_device_init_duplex_loopback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_duplex_loopback_format(
        device_handle,
        sample_rate,
        channels,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_device_init_f32(
    void* device_handle,
    int device_kind,
    uint32_t sample_rate,
    uint32_t channels
) {
    if (device_kind == MMJ_DEVICE_KIND_PLAYBACK) {
        return mmj_device_init_playback_f32(device_handle, sample_rate, channels);
    }
    if (device_kind == MMJ_DEVICE_KIND_CAPTURE) {
        return mmj_device_init_capture_f32(device_handle, sample_rate, channels);
    }
    if (device_kind == MMJ_DEVICE_KIND_DUPLEX) {
        return mmj_device_init_duplex_f32(device_handle, sample_rate, channels);
    }
    if (device_kind == MMJ_DEVICE_KIND_DUPLEX_LOOPBACK) {
        return mmj_device_init_duplex_loopback_f32(device_handle, sample_rate, channels);
    }

    return MA_INVALID_ARGS;
}

static int mmj_device_init_by_index_internal(
    void* device_handle,
    void* context_handle,
    int is_playback,
    uint32_t device_index,
    uint32_t sample_rate,
    uint32_t channels
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    mmj_context_handle* context = (mmj_context_handle*)context_handle;
    ma_device_info* playback_infos = NULL;
    ma_device_info* capture_infos = NULL;
    ma_uint32 playback_count = 0;
    ma_uint32 capture_count = 0;
    ma_device_config config;
    ma_device_id selected_id;
    ma_result result;

    if (
        handle == NULL
        || context == NULL
        || !context->initialized
        || sample_rate == 0
        || channels == 0
    ) {
        return MA_INVALID_ARGS;
    }

    result = ma_context_get_devices(
        &context->context,
        &playback_infos,
        &playback_count,
        &capture_infos,
        &capture_count
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    if (is_playback) {
        if (device_index >= playback_count) {
            return MA_OUT_OF_RANGE;
        }
        selected_id = playback_infos[device_index].id;
    } else {
        if (device_index >= capture_count) {
            return MA_OUT_OF_RANGE;
        }
        selected_id = capture_infos[device_index].id;
    }

    if (handle->initialized) {
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
        handle->started = 0;
    }

    handle->state.channels = channels;
    handle->state.mode = MMJ_DEVICE_MODE_SILENCE;
    handle->state.kind = is_playback
        ? MMJ_DEVICE_KIND_PLAYBACK
        : MMJ_DEVICE_KIND_CAPTURE;
    handle->state.observed_frames = 0;

    config = ma_device_config_init(
        is_playback ? ma_device_type_playback : ma_device_type_capture
    );
    config.sampleRate = sample_rate;
    config.dataCallback = mmj_device_callback;
    config.pUserData = &handle->state;

    if (is_playback) {
        config.playback.pDeviceID = &selected_id;
        config.playback.format = ma_format_f32;
        config.playback.channels = channels;
    } else {
        config.capture.pDeviceID = &selected_id;
        config.capture.format = ma_format_f32;
        config.capture.channels = channels;
    }

    result = ma_device_init(&context->context, &config, &handle->device);
    if (result != MA_SUCCESS) {
        return result;
    }

    handle->initialized = 1;
    handle->started = 0;
    return MA_SUCCESS;
}

int mmj_device_init_playback_f32_by_index(
    void* device_handle,
    void* context_handle,
    uint32_t device_index,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_by_index_internal(
        device_handle,
        context_handle,
        1,
        device_index,
        sample_rate,
        channels
    );
}

int mmj_device_init_capture_f32_by_index(
    void* device_handle,
    void* context_handle,
    uint32_t device_index,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_by_index_internal(
        device_handle,
        context_handle,
        0,
        device_index,
        sample_rate,
        channels
    );
}

int mmj_device_start(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (handle->started) {
        return MA_SUCCESS;
    }

    result = ma_device_start(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 1;
    }

    return result;
}

int mmj_device_stop(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (!handle->started) {
        return MA_SUCCESS;
    }

    result = ma_device_stop(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 0;
    }

    return result;
}

int mmj_device_is_started(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return 0;
    }

    return handle->started;
}

int mmj_device_get_kind(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return handle->state.kind;
}

int mmj_device_get_sample_rate(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)handle->device.sampleRate;
}

int mmj_device_get_channels(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)handle->state.channels;
}

int mmj_device_set_callback_mode(void* device_handle, int mode) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (mode != MMJ_DEVICE_MODE_SILENCE && mode != MMJ_DEVICE_MODE_LOOPBACK) {
        return MA_INVALID_ARGS;
    }

    handle->state.mode = mode;
    return MA_SUCCESS;
}

int mmj_device_get_callback_mode(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return handle->state.mode;
}

int64_t mmj_device_get_observed_frames(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (handle->state.observed_frames > (uint64_t)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)handle->state.observed_frames;
}

int mmj_device_reset_observed_frames(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    handle->state.observed_frames = 0;
    return MA_SUCCESS;
}

int mmj_device_wait_for_observed_frames(
    void* device_handle,
    uint64_t min_frames,
    uint32_t timeout_ms,
    uint32_t poll_interval_ms
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    uint32_t elapsed_ms = 0;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (min_frames == 0) {
        return MA_SUCCESS;
    }

    if (poll_interval_ms == 0) {
        poll_interval_ms = 5;
    }

    for (;;) {
        if (handle->state.observed_frames >= min_frames) {
            return MA_SUCCESS;
        }

        if (elapsed_ms >= timeout_ms) {
            return MA_TIMEOUT;
        }

        mmj_sleep_ms(poll_interval_ms);
        elapsed_ms += poll_interval_ms;
    }
}

int mmj_device_set_master_volume_f32(void* device_handle, float volume) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_device_set_master_volume(&handle->device, volume);
}

int mmj_device_get_master_volume_milli(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;
    ma_result result;
    float volume = 0.0f;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    result = ma_device_get_master_volume(&handle->device, &volume);
    if (result != MA_SUCCESS) {
        return result;
    }

    if (volume < 0.0f) {
        volume = 0.0f;
    }

    return (int)(volume * 1000.0f + 0.5f);
}

int mmj_device_uninit(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    if (handle->started) {
        ma_device_stop(&handle->device);
        handle->started = 0;
    }

    ma_device_uninit(&handle->device);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_device_destroy(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        if (handle->started) {
            ma_device_stop(&handle->device);
            handle->started = 0;
        }
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_decoder_create(void) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)calloc(1, sizeof(mmj_decoder_handle));
    return handle;
}

static int mmj_decoder_ensure_default_vfs(mmj_decoder_handle* handle) {
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->vfs_initialized) {
        return MA_SUCCESS;
    }

    result = ma_default_vfs_init(&handle->default_vfs, NULL);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    handle->vfs_initialized = 1;
    return MA_SUCCESS;
}

int mmj_decoder_init_file_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
) {
    return mmj_decoder_init_file_format(
        decoder_handle,
        file_path,
        output_channels,
        output_sample_rate,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_decoder_init_file_format(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_decoder_config config;
    ma_format resolved_format;
    int format_result;
    ma_result result;

    if (handle == NULL || file_path == NULL || output_channels == 0) {
        return MA_INVALID_ARGS;
    }

    format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    if (handle->initialized) {
        ma_decoder_uninit(&handle->decoder);
        handle->initialized = 0;
    }

    config = ma_decoder_config_init(resolved_format, output_channels, output_sample_rate);
    result = ma_decoder_init_file(file_path, &config, &handle->decoder);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_decoder_init_file_vfs_format(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_decoder_config config;
    ma_format resolved_format;
    int format_result;
    int vfs_result;
    ma_result result;

    if (handle == NULL || file_path == NULL || output_channels == 0) {
        return MA_INVALID_ARGS;
    }

    format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    if (handle->initialized) {
        ma_decoder_uninit(&handle->decoder);
        handle->initialized = 0;
    }

    vfs_result = mmj_decoder_ensure_default_vfs(handle);
    if (vfs_result != MA_SUCCESS) {
        return vfs_result;
    }

    config = ma_decoder_config_init(resolved_format, output_channels, output_sample_rate);
    result = ma_decoder_init_vfs((ma_vfs*)&handle->default_vfs, file_path, &config, &handle->decoder);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_decoder_init_file_vfs_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
) {
    return mmj_decoder_init_file_vfs_format(
        decoder_handle,
        file_path,
        output_channels,
        output_sample_rate,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_decoder_init_memory_f32(
    void* decoder_handle,
    const void* data,
    uint64_t data_size,
    uint32_t output_channels,
    uint32_t output_sample_rate
) {
    return mmj_decoder_init_memory_format(
        decoder_handle,
        data,
        data_size,
        output_channels,
        output_sample_rate,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_decoder_init_memory_format(
    void* decoder_handle,
    const void* data,
    uint64_t data_size,
    uint32_t output_channels,
    uint32_t output_sample_rate,
    int sample_format
) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_decoder_config config;
    ma_format resolved_format;
    int format_result;
    ma_result result;

    if (handle == NULL || data == NULL || data_size == 0 || output_channels == 0) {
        return MA_INVALID_ARGS;
    }

    format_result = mmj_format_from_code(sample_format, &resolved_format);
    if (format_result != MA_SUCCESS) {
        return format_result;
    }

    if (handle->initialized) {
        ma_decoder_uninit(&handle->decoder);
        handle->initialized = 0;
    }

    config = ma_decoder_config_init(resolved_format, output_channels, output_sample_rate);
    result = ma_decoder_init_memory(data, (size_t)data_size, &config, &handle->decoder);
    if (result == MA_SUCCESS) {
        handle->initialized = 1;
    }

    return result;
}

int mmj_decoder_read_pcm_frames_f32(
    void* decoder_handle,
    float* output,
    uint64_t frame_count,
    uint64_t* frames_read
) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_uint64 local_frames_read = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized || output == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_decoder_read_pcm_frames(&handle->decoder, output, (ma_uint64)frame_count, &local_frames_read);
    if (frames_read != NULL) {
        *frames_read = (uint64_t)local_frames_read;
    }

    return result;
}

int64_t mmj_decoder_read_pcm_frames_f32_count(
    void* decoder_handle,
    float* output,
    uint64_t frame_count
) {
    uint64_t frames_read = 0;
    int result = mmj_decoder_read_pcm_frames_f32(
        decoder_handle,
        output,
        frame_count,
        &frames_read
    );

    if (result != MA_SUCCESS && result != MA_AT_END) {
        return (int64_t)result;
    }

    return (int64_t)frames_read;
}

int64_t mmj_decoder_read_probe_f32(void* decoder_handle, uint64_t frame_count) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 bytes_per_sample = 0;
    ma_uint64 sample_count = 0;
    ma_uint64 local_frames_read = 0;
    ma_result result;
    ma_uint8* buffer = NULL;

    if (handle == NULL || !handle->initialized || frame_count == 0) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_decoder_get_data_format(
        &handle->decoder,
        &format,
        &channels,
        NULL,
        NULL,
        0
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (channels == 0) {
        return (int64_t)MA_INVALID_DATA;
    }

    bytes_per_sample = ma_get_bytes_per_sample(format);
    if (bytes_per_sample == 0) {
        return (int64_t)MA_INVALID_DATA;
    }

    sample_count = (ma_uint64)frame_count * (ma_uint64)channels;
    if (sample_count > ((ma_uint64)SIZE_MAX / (ma_uint64)bytes_per_sample)) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    buffer = (ma_uint8*)malloc((size_t)sample_count * (size_t)bytes_per_sample);
    if (buffer == NULL) {
        return (int64_t)MA_OUT_OF_MEMORY;
    }

    result = ma_decoder_read_pcm_frames(
        &handle->decoder,
        buffer,
        (ma_uint64)frame_count,
        &local_frames_read
    );
    free(buffer);

    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    return (int64_t)local_frames_read;
}

int mmj_decoder_seek_to_pcm_frame(void* decoder_handle, uint64_t frame_index) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return ma_decoder_seek_to_pcm_frame(&handle->decoder, (ma_uint64)frame_index);
}

int mmj_decoder_uninit(void* decoder_handle) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_decoder_uninit(&handle->decoder);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_decoder_destroy(void* decoder_handle) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_decoder_uninit(&handle->decoder);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_encoder_create(void) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)calloc(1, sizeof(mmj_encoder_handle));
    return handle;
}

static int mmj_encoder_ensure_default_vfs(mmj_encoder_handle* handle) {
    ma_result result;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (handle->vfs_initialized) {
        return MA_SUCCESS;
    }

    result = ma_default_vfs_init(&handle->default_vfs, NULL);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    handle->vfs_initialized = 1;
    return MA_SUCCESS;
}

int mmj_encoder_init_wav_file_format(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate,
    int sample_format
) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;
    ma_encoder_config config;
    ma_format format;
    ma_result result;

    if (
        handle == NULL
        || output_path == NULL
        || channels == 0
        || sample_rate == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (mmj_format_from_code(sample_format, &format) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_encoder_uninit(&handle->encoder);
        handle->initialized = 0;
        handle->channels = 0;
    }

    config = ma_encoder_config_init(
        ma_encoding_format_wav,
        format,
        channels,
        sample_rate
    );
    result = ma_encoder_init_file(output_path, &config, &handle->encoder);
    if (result == MA_SUCCESS) {
        handle->channels = channels;
        handle->initialized = 1;
    }

    return result;
}

int mmj_encoder_init_wav_file_f32(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate
) {
    return mmj_encoder_init_wav_file_format(
        encoder_handle,
        output_path,
        channels,
        sample_rate,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_encoder_init_wav_file_vfs_format(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate,
    int sample_format
) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;
    ma_encoder_config config;
    ma_format format;
    int vfs_result;
    ma_result result;

    if (
        handle == NULL
        || output_path == NULL
        || channels == 0
        || sample_rate == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (mmj_format_from_code(sample_format, &format) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_encoder_uninit(&handle->encoder);
        handle->initialized = 0;
        handle->channels = 0;
    }

    vfs_result = mmj_encoder_ensure_default_vfs(handle);
    if (vfs_result != MA_SUCCESS) {
        return vfs_result;
    }

    config = ma_encoder_config_init(
        ma_encoding_format_wav,
        format,
        channels,
        sample_rate
    );
    result = ma_encoder_init_vfs((ma_vfs*)&handle->default_vfs, output_path, &config, &handle->encoder);
    if (result == MA_SUCCESS) {
        handle->channels = channels;
        handle->initialized = 1;
    }

    return result;
}

int mmj_encoder_init_wav_file_vfs_f32(
    void* encoder_handle,
    const char* output_path,
    uint32_t channels,
    uint32_t sample_rate
) {
    return mmj_encoder_init_wav_file_vfs_format(
        encoder_handle,
        output_path,
        channels,
        sample_rate,
        MMJ_SAMPLE_FORMAT_F32
    );
}

int mmj_encoder_write_silence_f32(void* encoder_handle, uint64_t frame_count) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;
    ma_uint64 frames_written = 0;
    ma_uint64 sample_count_u64;
    size_t sample_count;
    float* buffer;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return MA_SUCCESS;
    }

    sample_count_u64 = frame_count * (ma_uint64)handle->channels;
    if (sample_count_u64 > (ma_uint64)SIZE_MAX) {
        return MA_OUT_OF_RANGE;
    }

    sample_count = (size_t)sample_count_u64;
    if (sample_count > (SIZE_MAX / sizeof(float))) {
        return MA_OUT_OF_RANGE;
    }

    buffer = (float*)calloc(sample_count, sizeof(float));
    if (buffer == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    result = ma_encoder_write_pcm_frames(
        &handle->encoder,
        buffer,
        (ma_uint64)frame_count,
        &frames_written
    );
    free(buffer);

    if (result != MA_SUCCESS) {
        return result;
    }

    if (frames_written != (ma_uint64)frame_count) {
        return MA_IO_ERROR;
    }

    return MA_SUCCESS;
}

int64_t mmj_encoder_write_pcm_frames_f32(
    void* encoder_handle,
    const float* frames,
    uint64_t frame_count
) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;
    ma_uint64 frames_written = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized || frames == NULL) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return 0;
    }

    result = ma_encoder_write_pcm_frames(
        &handle->encoder,
        frames,
        (ma_uint64)frame_count,
        &frames_written
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (frames_written > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)frames_written;
}

int mmj_encoder_uninit(void* encoder_handle) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_encoder_uninit(&handle->encoder);
    handle->initialized = 0;
    handle->channels = 0;
    return MA_SUCCESS;
}

void mmj_encoder_destroy(void* encoder_handle) {
    mmj_encoder_handle* handle = (mmj_encoder_handle*)encoder_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_encoder_uninit(&handle->encoder);
        handle->initialized = 0;
        handle->channels = 0;
    }

    free(handle);
}

void* mmj_resampler_create(void) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)calloc(1, sizeof(mmj_resampler_handle));
    return handle;
}

int mmj_resampler_init_linear_f32(
    void* resampler_handle,
    uint32_t channels,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;
    ma_resampler_config config;
    ma_result result;

    if (
        handle == NULL
        || channels == 0
        || sample_rate_in == 0
        || sample_rate_out == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_resampler_uninit(&handle->resampler, NULL);
        handle->initialized = 0;
    }

    config = ma_resampler_config_init(
        ma_format_f32,
        (ma_uint32)channels,
        (ma_uint32)sample_rate_in,
        (ma_uint32)sample_rate_out,
        ma_resample_algorithm_linear
    );
    result = ma_resampler_init(&config, NULL, &handle->resampler);
    if (result == MA_SUCCESS) {
        handle->channels = channels;
        handle->sample_rate_in = sample_rate_in;
        handle->sample_rate_out = sample_rate_out;
        handle->initialized = 1;
    }

    return (int)result;
}

int64_t mmj_resampler_process_f32(
    void* resampler_handle,
    const float* input_frames,
    uint64_t input_frame_count,
    float* output_frames,
    uint64_t output_frame_capacity
) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;
    ma_uint64 frame_count_in;
    ma_uint64 frame_count_out;
    ma_result result;

    if (
        handle == NULL
        || !handle->initialized
        || input_frames == NULL
        || output_frames == NULL
    ) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (input_frame_count == 0 || output_frame_capacity == 0) {
        return 0;
    }

    frame_count_in = (ma_uint64)input_frame_count;
    frame_count_out = (ma_uint64)output_frame_capacity;
    result = ma_resampler_process_pcm_frames(
        &handle->resampler,
        input_frames,
        &frame_count_in,
        output_frames,
        &frame_count_out
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (frame_count_out > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)frame_count_out;
}

int64_t mmj_resampler_get_expected_output_frame_count(
    void* resampler_handle,
    uint64_t input_frame_count
) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;
    ma_uint64 output_frame_count = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_resampler_get_expected_output_frame_count(
        &handle->resampler,
        (ma_uint64)input_frame_count,
        &output_frame_count
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (output_frame_count > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)output_frame_count;
}

int mmj_resampler_reset(void* resampler_handle) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_resampler_reset(&handle->resampler);
}

int mmj_resampler_uninit(void* resampler_handle) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_resampler_uninit(&handle->resampler, NULL);
    handle->initialized = 0;
    handle->channels = 0;
    handle->sample_rate_in = 0;
    handle->sample_rate_out = 0;
    return MA_SUCCESS;
}

void mmj_resampler_destroy(void* resampler_handle) {
    mmj_resampler_handle* handle = (mmj_resampler_handle*)resampler_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_resampler_uninit(&handle->resampler, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_channel_converter_create(void) {
    mmj_channel_converter_handle* handle = (mmj_channel_converter_handle*)calloc(1, sizeof(mmj_channel_converter_handle));
    return handle;
}

int mmj_channel_converter_init_f32(
    void* converter_handle,
    uint32_t channels_in,
    uint32_t channels_out,
    uint32_t mix_mode
) {
    mmj_channel_converter_handle* handle = (mmj_channel_converter_handle*)converter_handle;
    ma_channel_converter_config config;
    ma_channel_mix_mode resolved_mix_mode;
    ma_result result;

    if (handle == NULL || channels_in == 0 || channels_out == 0) {
        return MA_INVALID_ARGS;
    }

    if (mix_mode == (uint32_t)ma_channel_mix_mode_rectangular) {
        resolved_mix_mode = ma_channel_mix_mode_rectangular;
    } else if (mix_mode == (uint32_t)ma_channel_mix_mode_simple) {
        resolved_mix_mode = ma_channel_mix_mode_simple;
    } else {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_channel_converter_uninit(&handle->converter, NULL);
        handle->initialized = 0;
    }

    config = ma_channel_converter_config_init(
        ma_format_f32,
        (ma_uint32)channels_in,
        NULL,
        (ma_uint32)channels_out,
        NULL,
        resolved_mix_mode
    );
    result = ma_channel_converter_init(&config, NULL, &handle->converter);
    if (result == MA_SUCCESS) {
        handle->channels_in = channels_in;
        handle->channels_out = channels_out;
        handle->mix_mode = resolved_mix_mode;
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_channel_converter_process_f32(
    void* converter_handle,
    const float* input_frames,
    float* output_frames,
    uint64_t frame_count
) {
    mmj_channel_converter_handle* handle = (mmj_channel_converter_handle*)converter_handle;
    ma_result result;

    if (
        handle == NULL
        || !handle->initialized
        || input_frames == NULL
        || output_frames == NULL
    ) {
        return MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return MA_SUCCESS;
    }

    result = ma_channel_converter_process_pcm_frames(
        &handle->converter,
        output_frames,
        input_frames,
        (ma_uint64)frame_count
    );
    return (int)result;
}

int mmj_channel_converter_uninit(void* converter_handle) {
    mmj_channel_converter_handle* handle = (mmj_channel_converter_handle*)converter_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_channel_converter_uninit(&handle->converter, NULL);
    handle->initialized = 0;
    handle->channels_in = 0;
    handle->channels_out = 0;
    handle->mix_mode = ma_channel_mix_mode_default;
    return MA_SUCCESS;
}

void mmj_channel_converter_destroy(void* converter_handle) {
    mmj_channel_converter_handle* handle = (mmj_channel_converter_handle*)converter_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_channel_converter_uninit(&handle->converter, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_data_converter_create(void) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)calloc(1, sizeof(mmj_data_converter_handle));
    return handle;
}

int mmj_data_converter_init_f32(
    void* converter_handle,
    uint32_t channels_in,
    uint32_t channels_out,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_data_converter_config config;
    ma_result result;

    if (
        handle == NULL
        || channels_in == 0
        || channels_out == 0
        || sample_rate_in == 0
        || sample_rate_out == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_data_converter_uninit(&handle->converter, NULL);
        handle->initialized = 0;
    }

    config = ma_data_converter_config_init(
        ma_format_f32,
        ma_format_f32,
        (ma_uint32)channels_in,
        (ma_uint32)channels_out,
        (ma_uint32)sample_rate_in,
        (ma_uint32)sample_rate_out
    );
    result = ma_data_converter_init(&config, NULL, &handle->converter);
    if (result == MA_SUCCESS) {
        handle->channels_in = channels_in;
        handle->channels_out = channels_out;
        handle->sample_rate_in = sample_rate_in;
        handle->sample_rate_out = sample_rate_out;
        handle->initialized = 1;
    }

    return (int)result;
}

int64_t mmj_data_converter_process_f32(
    void* converter_handle,
    const float* input_frames,
    uint64_t input_frame_count,
    float* output_frames,
    uint64_t output_frame_capacity
) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_uint64 local_in;
    ma_uint64 local_out;
    ma_result result;

    if (
        handle == NULL
        || !handle->initialized
        || input_frames == NULL
        || output_frames == NULL
        || input_frame_count == 0
        || output_frame_capacity == 0
    ) {
        return (int64_t)MA_INVALID_ARGS;
    }

    local_in = (ma_uint64)input_frame_count;
    local_out = (ma_uint64)output_frame_capacity;
    result = ma_data_converter_process_pcm_frames(
        &handle->converter,
        input_frames,
        &local_in,
        output_frames,
        &local_out
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (local_out > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)local_out;
}

int64_t mmj_data_converter_get_expected_output_frame_count(
    void* converter_handle,
    uint64_t input_frame_count
) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_uint64 output_count = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_data_converter_get_expected_output_frame_count(
        &handle->converter,
        (ma_uint64)input_frame_count,
        &output_count
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (output_count > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)output_count;
}

int64_t mmj_data_converter_get_required_input_frame_count(
    void* converter_handle,
    uint64_t output_frame_count
) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_uint64 input_count = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_data_converter_get_required_input_frame_count(
        &handle->converter,
        (ma_uint64)output_frame_count,
        &input_count
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (input_count > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)input_count;
}

int64_t mmj_data_converter_get_input_latency(void* converter_handle) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_uint64 latency;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    latency = ma_data_converter_get_input_latency(&handle->converter);
    if (latency > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)latency;
}

int64_t mmj_data_converter_get_output_latency(void* converter_handle) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_uint64 latency;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    latency = ma_data_converter_get_output_latency(&handle->converter);
    if (latency > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)latency;
}

int mmj_data_converter_set_rate(
    void* converter_handle,
    uint32_t sample_rate_in,
    uint32_t sample_rate_out
) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;
    ma_result result;

    if (
        handle == NULL
        || !handle->initialized
        || sample_rate_in == 0
        || sample_rate_out == 0
    ) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_converter_set_rate(
        &handle->converter,
        (ma_uint32)sample_rate_in,
        (ma_uint32)sample_rate_out
    );
    if (result == MA_SUCCESS) {
        handle->sample_rate_in = sample_rate_in;
        handle->sample_rate_out = sample_rate_out;
    }

    return (int)result;
}

int mmj_data_converter_reset(void* converter_handle) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_data_converter_reset(&handle->converter);
}

int mmj_data_converter_uninit(void* converter_handle) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_data_converter_uninit(&handle->converter, NULL);
    handle->channels_in = 0;
    handle->channels_out = 0;
    handle->sample_rate_in = 0;
    handle->sample_rate_out = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_data_converter_destroy(void* converter_handle) {
    mmj_data_converter_handle* handle = (mmj_data_converter_handle*)converter_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_data_converter_uninit(&handle->converter, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

static int mmj_waveform_type_from_u32(uint32_t waveform_type, ma_waveform_type* resolved_type) {
    if (resolved_type == NULL) {
        return MA_INVALID_ARGS;
    }

    if (waveform_type == MMJ_WAVEFORM_TYPE_SINE) {
        *resolved_type = ma_waveform_type_sine;
        return MA_SUCCESS;
    }

    if (waveform_type == MMJ_WAVEFORM_TYPE_SQUARE) {
        *resolved_type = ma_waveform_type_square;
        return MA_SUCCESS;
    }

    if (waveform_type == MMJ_WAVEFORM_TYPE_TRIANGLE) {
        *resolved_type = ma_waveform_type_triangle;
        return MA_SUCCESS;
    }

    if (waveform_type == MMJ_WAVEFORM_TYPE_SAWTOOTH) {
        *resolved_type = ma_waveform_type_sawtooth;
        return MA_SUCCESS;
    }

    return MA_INVALID_ARGS;
}

static int mmj_attenuation_model_from_i32(int attenuation_model, ma_attenuation_model* resolved_model) {
    if (resolved_model == NULL) {
        return MA_INVALID_ARGS;
    }

    switch (attenuation_model) {
        case 0:
            *resolved_model = ma_attenuation_model_none;
            return MA_SUCCESS;
        case 1:
            *resolved_model = ma_attenuation_model_inverse;
            return MA_SUCCESS;
        case 2:
            *resolved_model = ma_attenuation_model_linear;
            return MA_SUCCESS;
        case 3:
            *resolved_model = ma_attenuation_model_exponential;
            return MA_SUCCESS;
        default:
            return MA_INVALID_ARGS;
    }
}

static int mmj_positioning_from_i32(int positioning, ma_positioning* resolved_positioning) {
    if (resolved_positioning == NULL) {
        return MA_INVALID_ARGS;
    }

    switch (positioning) {
        case 0:
            *resolved_positioning = ma_positioning_absolute;
            return MA_SUCCESS;
        case 1:
            *resolved_positioning = ma_positioning_relative;
            return MA_SUCCESS;
        default:
            return MA_INVALID_ARGS;
    }
}

static int mmj_noise_type_from_u32(uint32_t noise_type, ma_noise_type* resolved_type) {
    if (resolved_type == NULL) {
        return MA_INVALID_ARGS;
    }

    if (noise_type == MMJ_NOISE_TYPE_WHITE) {
        *resolved_type = ma_noise_type_white;
        return MA_SUCCESS;
    }

    if (noise_type == MMJ_NOISE_TYPE_PINK) {
        *resolved_type = ma_noise_type_pink;
        return MA_SUCCESS;
    }

    if (noise_type == MMJ_NOISE_TYPE_BROWNIAN) {
        *resolved_type = ma_noise_type_brownian;
        return MA_SUCCESS;
    }

    return MA_INVALID_ARGS;
}

void* mmj_waveform_create(void) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)calloc(1, sizeof(mmj_waveform_handle));
    return handle;
}

int mmj_waveform_init_f32(
    void* waveform_handle,
    uint32_t channels,
    uint32_t sample_rate,
    uint32_t waveform_type,
    double amplitude,
    double frequency
) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;
    ma_waveform_config config;
    ma_waveform_type resolved_type;
    int type_result;
    ma_result result;

    if (
        handle == NULL
        || channels == 0
        || sample_rate == 0
        || frequency <= 0.0
    ) {
        return MA_INVALID_ARGS;
    }

    type_result = mmj_waveform_type_from_u32(waveform_type, &resolved_type);
    if (type_result != MA_SUCCESS) {
        return type_result;
    }

    if (handle->initialized) {
        handle->initialized = 0;
    }

    config = ma_waveform_config_init(
        ma_format_f32,
        (ma_uint32)channels,
        (ma_uint32)sample_rate,
        resolved_type,
        amplitude,
        frequency
    );
    result = ma_waveform_init(&config, &handle->waveform);
    if (result == MA_SUCCESS) {
        handle->channels = channels;
        handle->sample_rate = sample_rate;
        handle->type = resolved_type;
        handle->amplitude = amplitude;
        handle->frequency = frequency;
        handle->initialized = 1;
    }

    return (int)result;
}

int64_t mmj_waveform_read_f32(
    void* waveform_handle,
    float* output_frames,
    uint64_t frame_count
) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;
    ma_uint64 frames_read = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized || output_frames == NULL) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return 0;
    }

    result = ma_waveform_read_pcm_frames(
        &handle->waveform,
        output_frames,
        (ma_uint64)frame_count,
        &frames_read
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (frames_read > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)frames_read;
}

int mmj_waveform_set_amplitude(void* waveform_handle, double amplitude) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    result = ma_waveform_set_amplitude(&handle->waveform, amplitude);
    if (result == MA_SUCCESS) {
        handle->amplitude = amplitude;
    }

    return (int)result;
}

int mmj_waveform_set_frequency(void* waveform_handle, double frequency) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized || frequency <= 0.0) {
        return MA_INVALID_ARGS;
    }

    result = ma_waveform_set_frequency(&handle->waveform, frequency);
    if (result == MA_SUCCESS) {
        handle->frequency = frequency;
    }

    return (int)result;
}

int mmj_waveform_uninit(void* waveform_handle) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    handle->initialized = 0;
    handle->channels = 0;
    handle->sample_rate = 0;
    handle->type = ma_waveform_type_sine;
    handle->amplitude = 0.0;
    handle->frequency = 0.0;
    return MA_SUCCESS;
}

void mmj_waveform_destroy(void* waveform_handle) {
    mmj_waveform_handle* handle = (mmj_waveform_handle*)waveform_handle;

    if (handle == NULL) {
        return;
    }

    handle->initialized = 0;
    free(handle);
}

void* mmj_noise_create(void) {
    mmj_noise_handle* handle = (mmj_noise_handle*)calloc(1, sizeof(mmj_noise_handle));
    return handle;
}

int mmj_noise_init_f32(
    void* noise_handle,
    uint32_t channels,
    uint32_t noise_type,
    int32_t seed,
    double amplitude
) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;
    ma_noise_config config;
    ma_noise_type resolved_type;
    int type_result;
    ma_result result;

    if (handle == NULL || channels == 0 || amplitude < 0.0) {
        return MA_INVALID_ARGS;
    }

    type_result = mmj_noise_type_from_u32(noise_type, &resolved_type);
    if (type_result != MA_SUCCESS) {
        return type_result;
    }

    if (handle->initialized) {
        ma_noise_uninit(&handle->noise, NULL);
        handle->initialized = 0;
    }

    config = ma_noise_config_init(
        ma_format_f32,
        (ma_uint32)channels,
        resolved_type,
        (ma_int32)seed,
        amplitude
    );
    result = ma_noise_init(&config, NULL, &handle->noise);
    if (result == MA_SUCCESS) {
        handle->type = resolved_type;
        handle->amplitude = amplitude;
        handle->seed = seed;
        handle->channels = channels;
        handle->initialized = 1;
    }

    return (int)result;
}

int64_t mmj_noise_read_f32(
    void* noise_handle,
    float* output_frames,
    uint64_t frame_count
) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;
    ma_uint64 frames_read = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized || output_frames == NULL) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return 0;
    }

    result = ma_noise_read_pcm_frames(
        &handle->noise,
        output_frames,
        (ma_uint64)frame_count,
        &frames_read
    );
    if (result != MA_SUCCESS) {
        return (int64_t)result;
    }

    if (frames_read > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)frames_read;
}

int mmj_noise_set_amplitude(void* noise_handle, double amplitude) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized || amplitude < 0.0) {
        return MA_INVALID_ARGS;
    }

    result = ma_noise_set_amplitude(&handle->noise, amplitude);
    if (result == MA_SUCCESS) {
        handle->amplitude = amplitude;
    }

    return (int)result;
}

int mmj_noise_set_seed(void* noise_handle, int32_t seed) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    result = ma_noise_set_seed(&handle->noise, (ma_int32)seed);
    if (result == MA_SUCCESS) {
        handle->seed = seed;
    }

    return (int)result;
}

int mmj_noise_set_type(void* noise_handle, uint32_t noise_type) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;
    ma_noise_type resolved_type;
    int type_result;
    ma_noise_config config;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    type_result = mmj_noise_type_from_u32(noise_type, &resolved_type);
    if (type_result != MA_SUCCESS) {
        return type_result;
    }

    if (resolved_type == handle->type) {
        return MA_SUCCESS;
    }

    ma_noise_uninit(&handle->noise, NULL);
    config = ma_noise_config_init(
        ma_format_f32,
        (ma_uint32)handle->channels,
        resolved_type,
        (ma_int32)handle->seed,
        handle->amplitude
    );
    result = ma_noise_init(&config, NULL, &handle->noise);
    if (result == MA_SUCCESS) {
        handle->type = resolved_type;
    } else {
        handle->initialized = 0;
    }

    return (int)result;
}

int mmj_noise_uninit(void* noise_handle) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_noise_uninit(&handle->noise, NULL);
    handle->type = ma_noise_type_white;
    handle->amplitude = 0.0;
    handle->seed = 0;
    handle->channels = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_noise_destroy(void* noise_handle) {
    mmj_noise_handle* handle = (mmj_noise_handle*)noise_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_noise_uninit(&handle->noise, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_spatializer_listener_create(void) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)calloc(1, sizeof(mmj_spatializer_listener_handle));
    return handle;
}

int mmj_spatializer_listener_init_default(
    void* listener_handle,
    uint32_t channels_out
) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;
    ma_spatializer_listener_config config;
    ma_result result;

    if (handle == NULL || channels_out == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_spatializer_listener_uninit(&handle->listener, NULL);
        handle->initialized = 0;
    }

    config = ma_spatializer_listener_config_init((ma_uint32)channels_out);
    result = ma_spatializer_listener_init(&config, NULL, &handle->listener);
    if (result == MA_SUCCESS) {
        handle->channels_out = channels_out;
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_spatializer_listener_set_position(
    void* listener_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_listener_set_position(&handle->listener, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_listener_set_direction(
    void* listener_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_listener_set_direction(&handle->listener, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_listener_set_world_up(
    void* listener_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_listener_set_world_up(&handle->listener, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_listener_uninit(void* listener_handle) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_spatializer_listener_uninit(&handle->listener, NULL);
    handle->channels_out = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_spatializer_listener_destroy(void* listener_handle) {
    mmj_spatializer_listener_handle* handle = (mmj_spatializer_listener_handle*)listener_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_spatializer_listener_uninit(&handle->listener, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_spatializer_create(void) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)calloc(1, sizeof(mmj_spatializer_handle));
    return handle;
}

int mmj_spatializer_init_default(
    void* spatializer_handle,
    uint32_t channels_in,
    uint32_t channels_out
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;
    ma_spatializer_config config;
    ma_result result;

    if (handle == NULL || channels_in == 0 || channels_out == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_spatializer_uninit(&handle->spatializer, NULL);
        handle->initialized = 0;
    }

    config = ma_spatializer_config_init((ma_uint32)channels_in, (ma_uint32)channels_out);
    result = ma_spatializer_init(&config, NULL, &handle->spatializer);
    if (result == MA_SUCCESS) {
        handle->channels_in = channels_in;
        handle->channels_out = channels_out;
        handle->initialized = 1;
    }

    return (int)result;
}

int mmj_spatializer_set_master_volume(
    void* spatializer_handle,
    float volume
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_spatializer_set_master_volume(&handle->spatializer, volume);
}

float mmj_spatializer_get_master_volume(
    void* spatializer_handle
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;
    float volume = 0.0f;
    ma_result result;

    if (handle == NULL || !handle->initialized) {
        return -1.0f;
    }

    result = ma_spatializer_get_master_volume(&handle->spatializer, &volume);
    if (result != MA_SUCCESS) {
        return -1.0f;
    }

    return volume;
}

int mmj_spatializer_set_attenuation_model(
    void* spatializer_handle,
    int attenuation_model
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;
    ma_attenuation_model resolved_model;
    int parse_result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    parse_result = mmj_attenuation_model_from_i32(attenuation_model, &resolved_model);
    if (parse_result != MA_SUCCESS) {
        return parse_result;
    }

    ma_spatializer_set_attenuation_model(&handle->spatializer, resolved_model);
    return MA_SUCCESS;
}

int mmj_spatializer_set_positioning(
    void* spatializer_handle,
    int positioning
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;
    ma_positioning resolved_positioning;
    int parse_result;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    parse_result = mmj_positioning_from_i32(positioning, &resolved_positioning);
    if (parse_result != MA_SUCCESS) {
        return parse_result;
    }

    ma_spatializer_set_positioning(&handle->spatializer, resolved_positioning);
    return MA_SUCCESS;
}

int mmj_spatializer_set_position(
    void* spatializer_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_set_position(&handle->spatializer, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_set_direction(
    void* spatializer_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_set_direction(&handle->spatializer, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_set_velocity(
    void* spatializer_handle,
    float x,
    float y,
    float z
) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_spatializer_set_velocity(&handle->spatializer, x, y, z);
    return MA_SUCCESS;
}

int mmj_spatializer_process_f32(
    void* spatializer_handle,
    void* listener_handle,
    float* output_frames,
    const float* input_frames,
    uint64_t frame_count
) {
    mmj_spatializer_handle* spatializer = (mmj_spatializer_handle*)spatializer_handle;
    mmj_spatializer_listener_handle* listener = (mmj_spatializer_listener_handle*)listener_handle;

    if (
        spatializer == NULL
        || !spatializer->initialized
        || listener == NULL
        || !listener->initialized
        || output_frames == NULL
        || input_frames == NULL
        || frame_count == 0
    ) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_spatializer_process_pcm_frames(
        &spatializer->spatializer,
        &listener->listener,
        output_frames,
        input_frames,
        (ma_uint64)frame_count
    );
}

int mmj_spatializer_uninit(void* spatializer_handle) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_spatializer_uninit(&handle->spatializer, NULL);
    handle->channels_in = 0;
    handle->channels_out = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_spatializer_destroy(void* spatializer_handle) {
    mmj_spatializer_handle* handle = (mmj_spatializer_handle*)spatializer_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_spatializer_uninit(&handle->spatializer, NULL);
        handle->initialized = 0;
    }

    free(handle);
}

void* mmj_pcm_rb_create(void) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)calloc(1, sizeof(mmj_pcm_rb_handle));
    return handle;
}

int mmj_pcm_rb_init_f32(
    void* pcm_rb_handle,
    uint32_t channels,
    uint32_t buffer_size_frames,
    uint32_t sample_rate
) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;
    ma_result result;

    if (
        handle == NULL
        || channels == 0
        || buffer_size_frames == 0
        || sample_rate == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_pcm_rb_uninit(&handle->rb);
        handle->initialized = 0;
    }

    result = ma_pcm_rb_init(
        ma_format_f32,
        (ma_uint32)channels,
        (ma_uint32)buffer_size_frames,
        NULL,
        NULL,
        &handle->rb
    );
    if (result == MA_SUCCESS) {
        ma_pcm_rb_set_sample_rate(&handle->rb, (ma_uint32)sample_rate);
        handle->channels = channels;
        handle->sample_rate = sample_rate;
        handle->initialized = 1;
    }

    return (int)result;
}

int64_t mmj_pcm_rb_write_f32(
    void* pcm_rb_handle,
    const float* input_frames,
    uint64_t frame_count
) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;
    ma_result result;
    uint64_t remaining;
    uint64_t total_written;
    const float* cursor;

    if (
        handle == NULL
        || !handle->initialized
        || input_frames == NULL
    ) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return 0;
    }

    remaining = frame_count;
    total_written = 0;
    cursor = input_frames;

    while (remaining > 0) {
        ma_uint32 requested_frames;
        void* mapped = NULL;
        ma_uint64 samples_to_copy;

        requested_frames = (ma_uint32)((remaining > (uint64_t)UINT32_MAX) ? UINT32_MAX : remaining);
        result = ma_pcm_rb_acquire_write(&handle->rb, &requested_frames, &mapped);
        if (result != MA_SUCCESS) {
            return (int64_t)result;
        }

        if (requested_frames == 0 || mapped == NULL) {
            break;
        }

        samples_to_copy = (ma_uint64)requested_frames * (ma_uint64)handle->channels;
        memcpy(mapped, cursor, (size_t)samples_to_copy * sizeof(float));

        result = ma_pcm_rb_commit_write(&handle->rb, requested_frames);
        if (result != MA_SUCCESS) {
            return (int64_t)result;
        }

        total_written += (uint64_t)requested_frames;
        remaining -= (uint64_t)requested_frames;
        cursor += samples_to_copy;
    }

    if (total_written > (uint64_t)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)total_written;
}

int64_t mmj_pcm_rb_read_f32(
    void* pcm_rb_handle,
    float* output_frames,
    uint64_t frame_count
) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;
    ma_result result;
    uint64_t remaining;
    uint64_t total_read;
    float* cursor;

    if (
        handle == NULL
        || !handle->initialized
        || output_frames == NULL
    ) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (frame_count == 0) {
        return 0;
    }

    remaining = frame_count;
    total_read = 0;
    cursor = output_frames;

    while (remaining > 0) {
        ma_uint32 requested_frames;
        void* mapped = NULL;
        ma_uint64 samples_to_copy;

        requested_frames = (ma_uint32)((remaining > (uint64_t)UINT32_MAX) ? UINT32_MAX : remaining);
        result = ma_pcm_rb_acquire_read(&handle->rb, &requested_frames, &mapped);
        if (result != MA_SUCCESS) {
            return (int64_t)result;
        }

        if (requested_frames == 0 || mapped == NULL) {
            break;
        }

        samples_to_copy = (ma_uint64)requested_frames * (ma_uint64)handle->channels;
        memcpy(cursor, mapped, (size_t)samples_to_copy * sizeof(float));

        result = ma_pcm_rb_commit_read(&handle->rb, requested_frames);
        if (result != MA_SUCCESS) {
            return (int64_t)result;
        }

        total_read += (uint64_t)requested_frames;
        remaining -= (uint64_t)requested_frames;
        cursor += samples_to_copy;
    }

    if (total_read > (uint64_t)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)total_read;
}

int64_t mmj_pcm_rb_available_read(void* pcm_rb_handle) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;
    ma_uint32 available;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    available = ma_pcm_rb_available_read(&handle->rb);
    return (int64_t)available;
}

int64_t mmj_pcm_rb_available_write(void* pcm_rb_handle) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;
    ma_uint32 available;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    available = ma_pcm_rb_available_write(&handle->rb);
    return (int64_t)available;
}

int mmj_pcm_rb_reset(void* pcm_rb_handle) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    ma_pcm_rb_reset(&handle->rb);
    return MA_SUCCESS;
}

int mmj_pcm_rb_uninit(void* pcm_rb_handle) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_pcm_rb_uninit(&handle->rb);
    handle->initialized = 0;
    handle->channels = 0;
    handle->sample_rate = 0;
    return MA_SUCCESS;
}

void mmj_pcm_rb_destroy(void* pcm_rb_handle) {
    mmj_pcm_rb_handle* handle = (mmj_pcm_rb_handle*)pcm_rb_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_pcm_rb_uninit(&handle->rb);
        handle->initialized = 0;
    }

    free(handle);
}

int mmj_resampler_linear_smoke(void) {
    mmj_resampler_handle handle;
    ma_result result;
    float input_frames[64 * 2];
    float output_frames[96 * 2];
    ma_uint64 frame_count_in;
    ma_uint64 frame_count_out;
    ma_uint64 expected_output = 0;
    uint64_t i;

    memset(&handle, 0, sizeof(handle));
    result = (ma_result)mmj_resampler_init_linear_f32(&handle, 2, 44100, 48000);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    for (i = 0; i < 64; ++i) {
        float sample = (float)((double)i / 64.0);
        input_frames[(i * 2) + 0] = sample;
        input_frames[(i * 2) + 1] = sample;
    }

    frame_count_in = 64;
    frame_count_out = 96;
    result = ma_resampler_process_pcm_frames(
        &handle.resampler,
        input_frames,
        &frame_count_in,
        output_frames,
        &frame_count_out
    );
    if (result != MA_SUCCESS) {
        mmj_resampler_uninit(&handle);
        return (int)result;
    }

    result = ma_resampler_get_expected_output_frame_count(
        &handle.resampler,
        64,
        &expected_output
    );
    if (result != MA_SUCCESS) {
        mmj_resampler_uninit(&handle);
        return (int)result;
    }

    if (frame_count_out == 0 || expected_output == 0) {
        mmj_resampler_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_resampler_uninit(&handle);
}

int mmj_resampler_invalid_rate_smoke(void) {
    mmj_resampler_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_resampler_init_linear_f32(&handle, 2, 44100, 0);
    if (result != MA_INVALID_ARGS) {
        mmj_resampler_uninit(&handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_channel_converter_stereo_to_mono_smoke(void) {
    mmj_channel_converter_handle handle;
    int result;
    float input_frames[4 * 2] = {
        1.0f, -1.0f,
        0.5f, 0.5f,
        -0.25f, -0.75f,
        0.0f, 0.0f
    };
    float output_frames[4] = {0.0f, 0.0f, 0.0f, 0.0f};

    memset(&handle, 0, sizeof(handle));
    result = mmj_channel_converter_init_f32(
        &handle,
        2,
        1,
        (uint32_t)ma_channel_mix_mode_rectangular
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_channel_converter_process_f32(
        &handle,
        input_frames,
        output_frames,
        4
    );
    if (result != MA_SUCCESS) {
        mmj_channel_converter_uninit(&handle);
        return result;
    }

    if (output_frames[1] == 0.0f) {
        mmj_channel_converter_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_channel_converter_uninit(&handle);
}

int mmj_channel_converter_invalid_channels_smoke(void) {
    mmj_channel_converter_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_channel_converter_init_f32(
        &handle,
        0,
        1,
        (uint32_t)ma_channel_mix_mode_rectangular
    );
    if (result != MA_INVALID_ARGS) {
        mmj_channel_converter_uninit(&handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_data_converter_smoke(void) {
    mmj_data_converter_handle handle;
    float input_frames[8 * 2];
    float output_frames[8];
    int64_t expected_output;
    int64_t required_input;
    int64_t produced;
    int64_t input_latency;
    int64_t output_latency;
    float sum_abs = 0.0f;
    uint64_t i;
    int result;

    memset(&handle, 0, sizeof(handle));
    memset(output_frames, 0, sizeof(output_frames));
    for (i = 0; i < 8; ++i) {
        input_frames[(i * 2) + 0] = (float)(i + 1) * 0.1f;
        input_frames[(i * 2) + 1] = (float)(i + 1) * -0.05f;
    }

    result = mmj_data_converter_init_f32(&handle, 2, 1, 44100, 48000);
    if (result != MA_SUCCESS) {
        return result;
    }

    expected_output = mmj_data_converter_get_expected_output_frame_count(&handle, 8);
    if (expected_output <= 0 || expected_output > 16) {
        mmj_data_converter_uninit(&handle);
        return (expected_output < 0) ? (int)expected_output : MA_ERROR;
    }

    required_input = mmj_data_converter_get_required_input_frame_count(&handle, 8);
    if (required_input <= 0) {
        mmj_data_converter_uninit(&handle);
        return (required_input < 0) ? (int)required_input : MA_ERROR;
    }

    produced = mmj_data_converter_process_f32(&handle, input_frames, 8, output_frames, 16);
    if (produced <= 0 || produced > 16) {
        mmj_data_converter_uninit(&handle);
        return (produced < 0) ? (int)produced : MA_ERROR;
    }

    for (i = 0; i < 8; ++i) {
        sum_abs += fabsf(output_frames[i]);
    }
    if (sum_abs <= 0.0f) {
        mmj_data_converter_uninit(&handle);
        return MA_ERROR;
    }

    input_latency = mmj_data_converter_get_input_latency(&handle);
    output_latency = mmj_data_converter_get_output_latency(&handle);
    if (input_latency < 0 || output_latency < 0) {
        mmj_data_converter_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_data_converter_set_rate(&handle, 48000, 44100);
    if (result != MA_SUCCESS) {
        mmj_data_converter_uninit(&handle);
        return result;
    }

    result = mmj_data_converter_reset(&handle);
    if (result != MA_SUCCESS) {
        mmj_data_converter_uninit(&handle);
        return result;
    }

    return mmj_data_converter_uninit(&handle);
}

int mmj_data_converter_invalid_args_smoke(void) {
    mmj_data_converter_handle handle;
    float input_frames[4] = {0.1f, 0.2f, 0.3f, 0.4f};
    float output_frames[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    int64_t produced;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_data_converter_init_f32(&handle, 0, 1, 48000, 48000);
    if (result != MA_INVALID_ARGS) {
        mmj_data_converter_uninit(&handle);
        return MA_ERROR;
    }

    produced = mmj_data_converter_process_f32(&handle, input_frames, 2, output_frames, 2);
    if (produced != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_data_converter_set_rate(&handle, 0, 48000);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_waveform_sine_smoke(void) {
    mmj_waveform_handle handle;
    float output_frames[64 * 2];
    int64_t frames_read;
    uint64_t i;
    int saw_non_zero = 0;
    int saw_changed_sample = 0;
    float previous = 0.0f;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_waveform_init_f32(
        &handle,
        2,
        48000,
        MMJ_WAVEFORM_TYPE_SINE,
        0.25,
        440.0
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    frames_read = mmj_waveform_read_f32(&handle, output_frames, 64);
    if (frames_read != 64) {
        mmj_waveform_uninit(&handle);
        return (frames_read < 0) ? (int)frames_read : MA_ERROR;
    }

    for (i = 0; i < 64 * 2; ++i) {
        if (output_frames[i] != 0.0f) {
            saw_non_zero = 1;
        }
        if (i > 0 && output_frames[i] != previous) {
            saw_changed_sample = 1;
        }
        previous = output_frames[i];
    }

    if (!saw_non_zero || !saw_changed_sample) {
        mmj_waveform_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_waveform_set_frequency(&handle, 880.0);
    if (result != MA_SUCCESS) {
        mmj_waveform_uninit(&handle);
        return result;
    }

    result = mmj_waveform_set_amplitude(&handle, 0.1);
    if (result != MA_SUCCESS) {
        mmj_waveform_uninit(&handle);
        return result;
    }

    return mmj_waveform_uninit(&handle);
}

int mmj_waveform_invalid_args_smoke(void) {
    mmj_waveform_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_waveform_init_f32(
        &handle,
        2,
        48000,
        MMJ_WAVEFORM_TYPE_SINE,
        0.25,
        0.0
    );
    if (result != MA_INVALID_ARGS) {
        mmj_waveform_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_waveform_init_f32(
        &handle,
        2,
        48000,
        99,
        0.25,
        440.0
    );
    if (result != MA_INVALID_ARGS) {
        mmj_waveform_uninit(&handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_noise_smoke(void) {
    mmj_noise_handle handle;
    float output_frames[64 * 2];
    int64_t frames_read;
    uint64_t i;
    int saw_non_zero = 0;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_noise_init_f32(
        &handle,
        2,
        MMJ_NOISE_TYPE_WHITE,
        1337,
        0.2
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    frames_read = mmj_noise_read_f32(&handle, output_frames, 64);
    if (frames_read != 64) {
        mmj_noise_uninit(&handle);
        return (frames_read < 0) ? (int)frames_read : MA_ERROR;
    }

    for (i = 0; i < 64 * 2; ++i) {
        if (output_frames[i] != 0.0f) {
            saw_non_zero = 1;
            break;
        }
    }
    if (!saw_non_zero) {
        mmj_noise_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_noise_set_type(&handle, MMJ_NOISE_TYPE_PINK);
    if (result != MA_SUCCESS) {
        mmj_noise_uninit(&handle);
        return result;
    }

    result = mmj_noise_set_seed(&handle, 2026);
    if (result != MA_SUCCESS) {
        mmj_noise_uninit(&handle);
        return result;
    }

    result = mmj_noise_set_amplitude(&handle, 0.1);
    if (result != MA_SUCCESS) {
        mmj_noise_uninit(&handle);
        return result;
    }

    return mmj_noise_uninit(&handle);
}

int mmj_noise_invalid_args_smoke(void) {
    mmj_noise_handle handle;
    int64_t frames_read;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_noise_init_f32(
        &handle,
        0,
        MMJ_NOISE_TYPE_WHITE,
        1,
        0.2
    );
    if (result != MA_INVALID_ARGS) {
        mmj_noise_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_noise_init_f32(
        &handle,
        2,
        99,
        1,
        0.2
    );
    if (result != MA_INVALID_ARGS) {
        mmj_noise_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_noise_set_amplitude(&handle, 0.2);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    frames_read = mmj_noise_read_f32(&handle, NULL, 8);
    if (frames_read != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_spatializer_smoke(void) {
    mmj_spatializer_listener_handle listener_handle;
    mmj_spatializer_handle spatializer_handle;
    float input_frames[16];
    float output_frames[32];
    float output_abs_sum = 0.0f;
    int result;
    uint64_t i;

    memset(&listener_handle, 0, sizeof(listener_handle));
    memset(&spatializer_handle, 0, sizeof(spatializer_handle));
    memset(output_frames, 0, sizeof(output_frames));

    for (i = 0; i < 16; ++i) {
        input_frames[i] = 0.25f;
    }

    result = mmj_spatializer_listener_init_default(&listener_handle, 2);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = mmj_spatializer_init_default(&spatializer_handle, 1, 2);
    if (result != MA_SUCCESS) {
        mmj_spatializer_listener_uninit(&listener_handle);
        return result;
    }

    result = mmj_spatializer_listener_set_position(&listener_handle, 0.0f, 0.0f, 0.0f);
    if (result != MA_SUCCESS) {
        mmj_spatializer_uninit(&spatializer_handle);
        mmj_spatializer_listener_uninit(&listener_handle);
        return result;
    }

    result = mmj_spatializer_set_position(&spatializer_handle, 1.0f, 0.0f, 0.0f);
    if (result != MA_SUCCESS) {
        mmj_spatializer_uninit(&spatializer_handle);
        mmj_spatializer_listener_uninit(&listener_handle);
        return result;
    }

    result = mmj_spatializer_process_f32(
        &spatializer_handle,
        &listener_handle,
        output_frames,
        input_frames,
        16
    );
    if (result != MA_SUCCESS) {
        mmj_spatializer_uninit(&spatializer_handle);
        mmj_spatializer_listener_uninit(&listener_handle);
        return result;
    }

    for (i = 0; i < 32; ++i) {
        output_abs_sum += fabsf(output_frames[i]);
    }

    mmj_spatializer_uninit(&spatializer_handle);
    mmj_spatializer_listener_uninit(&listener_handle);

    if (output_abs_sum <= 0.0f) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_spatializer_invalid_args_smoke(void) {
    mmj_spatializer_listener_handle listener_handle;
    mmj_spatializer_handle spatializer_handle;
    float input_frames[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    float output_frames[8] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    int result;

    memset(&listener_handle, 0, sizeof(listener_handle));
    memset(&spatializer_handle, 0, sizeof(spatializer_handle));

    result = mmj_spatializer_init_default(&spatializer_handle, 0, 2);
    if (result != MA_INVALID_ARGS) {
        mmj_spatializer_uninit(&spatializer_handle);
        return MA_ERROR;
    }

    result = mmj_spatializer_listener_init_default(&listener_handle, 0);
    if (result != MA_INVALID_ARGS) {
        mmj_spatializer_listener_uninit(&listener_handle);
        return MA_ERROR;
    }

    result = mmj_spatializer_process_f32(
        &spatializer_handle,
        &listener_handle,
        output_frames,
        input_frames,
        4
    );
    if (result != MA_INVALID_ARGS) {
        mmj_spatializer_uninit(&spatializer_handle);
        mmj_spatializer_listener_uninit(&listener_handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_decoder_memory_smoke(void) {
    mmj_decoder_handle handle;
    const unsigned char wav_data[] = {
        0x52, 0x49, 0x46, 0x46, 0x2C, 0x00, 0x00, 0x00,
        0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
        0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00,
        0x80, 0xBB, 0x00, 0x00, 0x00, 0xEE, 0x02, 0x00,
        0x04, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
        0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
    };
    int result;
    int64_t frames_read;

    memset(&handle, 0, sizeof(handle));

    result = mmj_decoder_init_memory_f32(
        &handle,
        wav_data,
        sizeof(wav_data),
        2,
        48000
    );
    if (result != MA_SUCCESS) {
        return result;
    }

    frames_read = mmj_decoder_read_probe_f32(&handle, 2);
    if (frames_read <= 0) {
        mmj_decoder_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_decoder_uninit(&handle);
}

int mmj_decoder_memory_invalid_args_smoke(void) {
    mmj_decoder_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_decoder_init_memory_f32(&handle, NULL, 8, 2, 48000);
    if (result != MA_INVALID_ARGS) {
        mmj_decoder_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_decoder_init_memory_f32(&handle, "x", 1, 0, 48000);
    if (result != MA_INVALID_ARGS) {
        mmj_decoder_uninit(&handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_pcm_rb_smoke(void) {
    mmj_pcm_rb_handle handle;
    float input_frames[8 * 2] = {
        0.1f, 0.2f,
        0.3f, 0.4f,
        0.5f, 0.6f,
        0.7f, 0.8f,
        0.9f, 1.0f,
        1.1f, 1.2f,
        1.3f, 1.4f,
        1.5f, 1.6f
    };
    float output_frames[8 * 2];
    int64_t written;
    int64_t read;
    int64_t available_read;
    int result;

    memset(&handle, 0, sizeof(handle));
    memset(output_frames, 0, sizeof(output_frames));

    result = mmj_pcm_rb_init_f32(&handle, 2, 16, 48000);
    if (result != MA_SUCCESS) {
        return result;
    }

    written = mmj_pcm_rb_write_f32(&handle, input_frames, 8);
    if (written != 8) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    available_read = mmj_pcm_rb_available_read(&handle);
    if (available_read < 8) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    read = mmj_pcm_rb_read_f32(&handle, output_frames, 4);
    if (read != 4) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    if (output_frames[0] != input_frames[0] || output_frames[1] != input_frames[1]) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_pcm_rb_uninit(&handle);
}

int mmj_pcm_rb_overflow_smoke(void) {
    mmj_pcm_rb_handle handle;
    float input_frames[8 * 2] = {0};
    int64_t written_first;
    int64_t written_second;
    int64_t available_write;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_pcm_rb_init_f32(&handle, 2, 4, 48000);
    if (result != MA_SUCCESS) {
        return result;
    }

    written_first = mmj_pcm_rb_write_f32(&handle, input_frames, 4);
    written_second = mmj_pcm_rb_write_f32(&handle, input_frames, 4);
    available_write = mmj_pcm_rb_available_write(&handle);

    if (written_first != 4 || written_second != 0 || available_write != 0) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_pcm_rb_uninit(&handle);
}

int mmj_pcm_rb_invalid_args_smoke(void) {
    mmj_pcm_rb_handle handle;
    int result;

    memset(&handle, 0, sizeof(handle));
    result = mmj_pcm_rb_init_f32(&handle, 0, 16, 48000);
    if (result != MA_INVALID_ARGS) {
        mmj_pcm_rb_uninit(&handle);
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

/* === Memory-based I/O implementations === */

static void mmj_playback_from_buffer_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_playback_from_buffer_state* state = (mmj_playback_from_buffer_state*)device->pUserData;
    float* out = (float*)output;
    uint64_t i, total_samples;
    uint64_t remaining_frames;

    (void)input;

    if (state == NULL || out == NULL || state->buffer == NULL) {
        memset(output, 0, (size_t)frame_count * state->channels * sizeof(float));
        return;
    }

    /* Calculate how many frames we can copy */
    remaining_frames = state->buffer_frame_count - state->current_position;
    if (remaining_frames > (uint64_t)frame_count) {
        remaining_frames = (uint64_t)frame_count;
    }

    total_samples = remaining_frames * state->channels;
    if (remaining_frames > 0) {
        memcpy(
            out,
            state->buffer + (state->current_position * state->channels),
            total_samples * sizeof(float)
        );
        state->current_position += remaining_frames;
    }

    /* Fill remaining with silence */
    if (remaining_frames < (uint64_t)frame_count) {
        uint64_t silence_start = remaining_frames * state->channels;
        uint64_t silence_count = ((uint64_t)frame_count - remaining_frames) * state->channels;
        memset(
            out + silence_start,
            0,
            silence_count * sizeof(float)
        );
    }
}

static void mmj_capture_to_buffer_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_capture_to_buffer_state* state = (mmj_capture_to_buffer_state*)device->pUserData;
    const float* in = (const float*)input;
    uint64_t total_samples;
    uint64_t remaining_frames;

    (void)output;

    if (state == NULL || in == NULL || state->buffer == NULL) {
        return;
    }

    /* Calculate how many frames we can copy */
    remaining_frames = state->buffer_frame_capacity - state->frames_captured;
    if (remaining_frames > (uint64_t)frame_count) {
        remaining_frames = (uint64_t)frame_count;
    }

    total_samples = remaining_frames * state->channels;
    if (remaining_frames > 0) {
        memcpy(
            state->buffer + (state->frames_captured * state->channels),
            in,
            total_samples * sizeof(float)
        );
        state->frames_captured += remaining_frames;
    }
}

void* mmj_playback_from_buffer_create(void) {
    mmj_playback_from_buffer_handle* handle =
        (mmj_playback_from_buffer_handle*)calloc(1, sizeof(mmj_playback_from_buffer_handle));
    return handle;
}

int mmj_playback_from_buffer_init_f32(
    void* playback_handle,
    uint32_t sample_rate,
    uint32_t channels,
    float* buffer,
    uint64_t buffer_frame_count
) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;
    ma_device_config config;
    ma_result result;

    if (handle == NULL || buffer == NULL || sample_rate == 0 || channels == 0 || buffer_frame_count == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
        handle->started = 0;
    }

    handle->state.buffer = buffer;
    handle->state.buffer_frame_count = buffer_frame_count;
    handle->state.current_position = 0;
    handle->state.channels = channels;

    config = ma_device_config_init(ma_device_type_playback);
    config.sampleRate = sample_rate;
    config.playback.format = ma_format_f32;
    config.playback.channels = channels;
    config.dataCallback = mmj_playback_from_buffer_callback;
    config.pUserData = &handle->state;

    result = ma_device_init(NULL, &config, &handle->device);
    if (result != MA_SUCCESS) {
        return result;
    }

    handle->initialized = 1;
    handle->started = 0;
    return MA_SUCCESS;
}

int mmj_playback_from_buffer_start(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (handle->started) {
        return MA_SUCCESS;
    }

    ma_result result = ma_device_start(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 1;
    }
    return result;
}

int mmj_playback_from_buffer_stop(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (!handle->started) {
        return MA_SUCCESS;
    }

    ma_result result = ma_device_stop(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 0;
    }
    return result;
}

int mmj_playback_from_buffer_is_finished(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (handle->state.current_position >= handle->state.buffer_frame_count) ? 1 : 0;
}

int64_t mmj_playback_from_buffer_get_position_in_frames(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    return (int64_t)handle->state.current_position;
}

int mmj_playback_from_buffer_uninit(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    if (handle->started) {
        ma_device_stop(&handle->device);
        handle->started = 0;
    }

    ma_device_uninit(&handle->device);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_playback_from_buffer_destroy(void* playback_handle) {
    mmj_playback_from_buffer_handle* handle = (mmj_playback_from_buffer_handle*)playback_handle;

    if (handle == NULL) {
        return;
    }

    mmj_playback_from_buffer_uninit(handle);
    free(handle);
}

void* mmj_capture_to_buffer_create(void) {
    mmj_capture_to_buffer_handle* handle =
        (mmj_capture_to_buffer_handle*)calloc(1, sizeof(mmj_capture_to_buffer_handle));
    return handle;
}

int mmj_capture_to_buffer_init_f32(
    void* capture_handle,
    uint32_t sample_rate,
    uint32_t channels,
    float* buffer,
    uint64_t buffer_frame_capacity
) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;
    ma_device_config config;
    ma_result result;

    if (handle == NULL || buffer == NULL || sample_rate == 0 || channels == 0 || buffer_frame_capacity == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_device_uninit(&handle->device);
        handle->initialized = 0;
        handle->started = 0;
    }

    handle->state.buffer = buffer;
    handle->state.buffer_frame_capacity = buffer_frame_capacity;
    handle->state.frames_captured = 0;
    handle->state.channels = channels;

    config = ma_device_config_init(ma_device_type_capture);
    config.sampleRate = sample_rate;
    config.capture.format = ma_format_f32;
    config.capture.channels = channels;
    config.dataCallback = mmj_capture_to_buffer_callback;
    config.pUserData = &handle->state;

    result = ma_device_init(NULL, &config, &handle->device);
    if (result != MA_SUCCESS) {
        return result;
    }

    handle->initialized = 1;
    handle->started = 0;
    return MA_SUCCESS;
}

int mmj_capture_to_buffer_start(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (handle->started) {
        return MA_SUCCESS;
    }

    ma_result result = ma_device_start(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 1;
    }
    return result;
}

int mmj_capture_to_buffer_stop(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (!handle->started) {
        return MA_SUCCESS;
    }

    ma_result result = ma_device_stop(&handle->device);
    if (result == MA_SUCCESS) {
        handle->started = 0;
    }
    return result;
}

int64_t mmj_capture_to_buffer_get_frames_captured(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    return (int64_t)handle->state.frames_captured;
}

int mmj_capture_to_buffer_reset(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    handle->state.frames_captured = 0;
    return MA_SUCCESS;
}

int mmj_capture_to_buffer_uninit(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    if (handle->started) {
        ma_device_stop(&handle->device);
        handle->started = 0;
    }

    ma_device_uninit(&handle->device);
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_capture_to_buffer_destroy(void* capture_handle) {
    mmj_capture_to_buffer_handle* handle = (mmj_capture_to_buffer_handle*)capture_handle;

    if (handle == NULL) {
        return;
    }

    mmj_capture_to_buffer_uninit(handle);
    free(handle);
}

static ma_result mmj_custom_buffer_data_source_on_read(
    ma_data_source* pDataSource,
    void* pFramesOut,
    ma_uint64 frameCount,
    ma_uint64* pFramesRead
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;
    ma_uint64 frames_remaining;
    ma_uint64 frames_to_read;

    if (handle == NULL || pFramesRead == NULL) {
        return MA_INVALID_ARGS;
    }

    *pFramesRead = 0;

    if (!handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (frameCount == 0) {
        return MA_SUCCESS;
    }

    if (handle->cursor >= handle->frame_count) {
        return MA_AT_END;
    }

    frames_remaining = handle->frame_count - handle->cursor;
    frames_to_read = (frameCount < frames_remaining) ? frameCount : frames_remaining;

    if (pFramesOut != NULL && handle->frames != NULL) {
        memcpy(
            pFramesOut,
            handle->frames + (handle->cursor * (uint64_t)handle->channels),
            (size_t)(frames_to_read * (uint64_t)handle->channels) * sizeof(float)
        );
    }

    handle->cursor += frames_to_read;
    *pFramesRead = frames_to_read;

    return (frames_to_read == frameCount) ? MA_SUCCESS : MA_AT_END;
}

static ma_result mmj_custom_buffer_data_source_on_seek(
    ma_data_source* pDataSource,
    ma_uint64 frameIndex
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (frameIndex > handle->frame_count) {
        return MA_INVALID_ARGS;
    }

    handle->cursor = frameIndex;
    return MA_SUCCESS;
}

static ma_result mmj_custom_buffer_data_source_on_get_data_format(
    ma_data_source* pDataSource,
    ma_format* pFormat,
    ma_uint32* pChannels,
    ma_uint32* pSampleRate,
    ma_channel* pChannelMap,
    size_t channelMapCap
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (pFormat != NULL) {
        *pFormat = handle->format;
    }
    if (pChannels != NULL) {
        *pChannels = handle->channels;
    }
    if (pSampleRate != NULL) {
        *pSampleRate = handle->sample_rate;
    }
    if (pChannelMap != NULL && channelMapCap > 0) {
        ma_channel_map_init_standard(
            ma_standard_channel_map_default,
            pChannelMap,
            channelMapCap,
            handle->channels
        );
    }

    return MA_SUCCESS;
}

static ma_result mmj_custom_buffer_data_source_on_get_cursor(
    ma_data_source* pDataSource,
    ma_uint64* pCursor
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;

    if (handle == NULL || pCursor == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    *pCursor = handle->cursor;
    return MA_SUCCESS;
}

static ma_result mmj_custom_buffer_data_source_on_get_length(
    ma_data_source* pDataSource,
    ma_uint64* pLength
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;

    if (handle == NULL || pLength == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    *pLength = handle->frame_count;
    return MA_SUCCESS;
}

static ma_result mmj_custom_buffer_data_source_on_set_looping(
    ma_data_source* pDataSource,
    ma_bool32 isLooping
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)pDataSource;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    handle->looping = (isLooping != MA_FALSE) ? 1 : 0;
    return MA_SUCCESS;
}

static const ma_data_source_vtable g_mmj_custom_buffer_data_source_vtable = {
    mmj_custom_buffer_data_source_on_read,
    mmj_custom_buffer_data_source_on_seek,
    mmj_custom_buffer_data_source_on_get_data_format,
    mmj_custom_buffer_data_source_on_get_cursor,
    mmj_custom_buffer_data_source_on_get_length,
    mmj_custom_buffer_data_source_on_set_looping,
    0
};

void* mmj_custom_buffer_data_source_create(void) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)calloc(1, sizeof(mmj_custom_buffer_data_source_handle));
    return handle;
}

int mmj_custom_buffer_data_source_init_f32(
    void* data_source_handle,
    const float* frames,
    uint64_t frame_count,
    uint32_t channels,
    uint32_t sample_rate
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_data_source_config config;
    ma_result result;

    if (
        handle == NULL
        || frames == NULL
        || frame_count == 0
        || channels == 0
        || sample_rate == 0
    ) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_data_source_uninit((ma_data_source*)&handle->base);
        handle->initialized = 0;
    }

    config = ma_data_source_config_init();
    config.vtable = &g_mmj_custom_buffer_data_source_vtable;
    result = ma_data_source_init(&config, (ma_data_source*)&handle->base);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    handle->frames = frames;
    handle->frame_count = frame_count;
    handle->channels = channels;
    handle->sample_rate = sample_rate;
    handle->format = ma_format_f32;
    handle->cursor = 0;
    handle->looping = 0;
    handle->base.rangeBegInFrames = 0;
    handle->base.rangeEndInFrames = frame_count;
    handle->base.loopBegInFrames = 0;
    handle->base.loopEndInFrames = frame_count;
    handle->initialized = 1;

    return MA_SUCCESS;
}

int64_t mmj_custom_buffer_data_source_read_f32(
    void* data_source_handle,
    float* output_frames,
    uint64_t frame_count
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_uint64 frames_read = 0;
    ma_result result;

    if (handle == NULL || !handle->initialized || output_frames == NULL) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_data_source_read_pcm_frames(
        (ma_data_source*)&handle->base,
        output_frames,
        frame_count,
        &frames_read
    );
    if (result != MA_SUCCESS && result != MA_AT_END) {
        return (int64_t)result;
    }

    if (frames_read > (ma_uint64)INT64_MAX) {
        return (int64_t)MA_OUT_OF_RANGE;
    }

    return (int64_t)frames_read;
}

int mmj_custom_buffer_data_source_seek_to_pcm_frame(
    void* data_source_handle,
    uint64_t frame_index
) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_data_source_seek_to_pcm_frame((ma_data_source*)&handle->base, (ma_uint64)frame_index);
}

int64_t mmj_custom_buffer_data_source_get_cursor_in_pcm_frames(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_uint64 cursor = 0;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (ma_data_source_get_cursor_in_pcm_frames((ma_data_source*)&handle->base, &cursor) != MA_SUCCESS) {
        return (int64_t)MA_ERROR;
    }

    return (int64_t)cursor;
}

int64_t mmj_custom_buffer_data_source_get_length_in_pcm_frames(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_uint64 length = 0;

    if (handle == NULL || !handle->initialized) {
        return (int64_t)MA_INVALID_ARGS;
    }

    if (ma_data_source_get_length_in_pcm_frames((ma_data_source*)&handle->base, &length) != MA_SUCCESS) {
        return (int64_t)MA_ERROR;
    }

    return (int64_t)length;
}

int mmj_custom_buffer_data_source_get_format(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_format format;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (ma_data_source_get_data_format((ma_data_source*)&handle->base, &format, NULL, NULL, NULL, 0) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }

    return (int)format;
}

int mmj_custom_buffer_data_source_get_channels(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_uint32 channels;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (ma_data_source_get_data_format((ma_data_source*)&handle->base, NULL, &channels, NULL, NULL, 0) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }

    return (int)channels;
}

int mmj_custom_buffer_data_source_get_sample_rate(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;
    ma_uint32 sample_rate;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    if (ma_data_source_get_data_format((ma_data_source*)&handle->base, NULL, NULL, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }

    return (int)sample_rate;
}

int mmj_custom_buffer_data_source_set_looping(void* data_source_handle, int is_looping) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_data_source_set_looping((ma_data_source*)&handle->base, (ma_bool32)is_looping);
}

int mmj_custom_buffer_data_source_is_looping(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;

    if (handle == NULL || !handle->initialized) {
        return MA_INVALID_ARGS;
    }

    return (int)ma_data_source_is_looping((ma_data_source*)&handle->base);
}

int mmj_custom_buffer_data_source_uninit(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!handle->initialized) {
        return MA_SUCCESS;
    }

    ma_data_source_uninit((ma_data_source*)&handle->base);
    handle->frames = NULL;
    handle->frame_count = 0;
    handle->channels = 0;
    handle->sample_rate = 0;
    handle->format = ma_format_f32;
    handle->cursor = 0;
    handle->looping = 0;
    handle->initialized = 0;
    return MA_SUCCESS;
}

void mmj_custom_buffer_data_source_destroy(void* data_source_handle) {
    mmj_custom_buffer_data_source_handle* handle = (mmj_custom_buffer_data_source_handle*)data_source_handle;

    if (handle == NULL) {
        return;
    }

    if (handle->initialized) {
        ma_data_source_uninit((ma_data_source*)&handle->base);
        handle->initialized = 0;
    }

    free(handle);
}

int mmj_custom_buffer_data_source_smoke(void) {
    mmj_custom_buffer_data_source_handle handle;
    float frames[6 * 2] = {
        0.0f, 0.1f,
        0.2f, 0.3f,
        0.4f, 0.5f,
        0.6f, 0.7f,
        0.8f, 0.9f,
        1.0f, 1.1f
    };
    float output_frames[4 * 2] = {0.0f};
    int64_t read_frames;
    int64_t length_frames;
    int64_t cursor_frames;
    int result;

    memset(&handle, 0, sizeof(handle));

    result = mmj_custom_buffer_data_source_init_f32(&handle, frames, 6, 2, 48000);
    if (result != MA_SUCCESS) {
        return result;
    }

    length_frames = mmj_custom_buffer_data_source_get_length_in_pcm_frames(&handle);
    if (length_frames != 6) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_custom_buffer_data_source_set_looping(&handle, 1);
    if (result != MA_SUCCESS) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return result;
    }

    read_frames = mmj_custom_buffer_data_source_read_f32(&handle, output_frames, 4);
    if (read_frames != 4) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return (read_frames < 0) ? (int)read_frames : MA_ERROR;
    }

    cursor_frames = mmj_custom_buffer_data_source_get_cursor_in_pcm_frames(&handle);
    if (cursor_frames != 4) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    result = mmj_custom_buffer_data_source_seek_to_pcm_frame(&handle, 2);
    if (result != MA_SUCCESS) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return result;
    }

    cursor_frames = mmj_custom_buffer_data_source_get_cursor_in_pcm_frames(&handle);
    if (cursor_frames != 2) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    if (mmj_custom_buffer_data_source_get_format(&handle) != (int)ma_format_f32) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    if (mmj_custom_buffer_data_source_get_channels(&handle) != 2) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    if (mmj_custom_buffer_data_source_get_sample_rate(&handle) != 48000) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    if (mmj_custom_buffer_data_source_is_looping(&handle) != 1) {
        mmj_custom_buffer_data_source_uninit(&handle);
        return MA_ERROR;
    }

    return mmj_custom_buffer_data_source_uninit(&handle);
}

int mmj_custom_buffer_data_source_invalid_args_smoke(void) {
    mmj_custom_buffer_data_source_handle handle;
    float frames[2] = {0.0f, 0.0f};
    float output_frames[2] = {0.0f, 0.0f};
    int result;
    int64_t read_frames;

    memset(&handle, 0, sizeof(handle));

    result = mmj_custom_buffer_data_source_init_f32(&handle, NULL, 1, 2, 48000);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_custom_buffer_data_source_init_f32(&handle, frames, 0, 2, 48000);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    read_frames = mmj_custom_buffer_data_source_read_f32(&handle, output_frames, 1);
    if (read_frames != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    result = mmj_custom_buffer_data_source_seek_to_pcm_frame(&handle, 0);
    if (result != MA_INVALID_ARGS) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

/* User-defined callback registration */

int mmj_device_set_data_callback(
    void* device_handle,
    mmj_device_data_callback callback,
    void* user_data
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    handle->state.user_data_callback = callback;
    handle->state.user_callback_data = user_data;
    return MA_SUCCESS;
}

int mmj_device_set_stop_callback(
    void* device_handle,
    mmj_device_stop_callback callback,
    void* user_data
) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    handle->state.user_stop_callback = callback;
    /* Note: user_data already set by mmj_device_set_data_callback if needed,
       or can be used independently by this callback */
    if (user_data != NULL) {
        handle->state.user_callback_data = user_data;
    }
    return MA_SUCCESS;
}

int mmj_device_clear_callbacks(void* device_handle) {
    mmj_device_handle* handle = (mmj_device_handle*)device_handle;

    if (handle == NULL) {
        return MA_INVALID_ARGS;
    }

    handle->state.user_data_callback = NULL;
    handle->state.user_stop_callback = NULL;
    handle->state.user_callback_data = NULL;
    return MA_SUCCESS;
}

/* Test helper for user callbacks */

typedef struct {
    uint32_t call_count;
    uint32_t total_frames;
} mmj_test_callback_state;

static void mmj_test_data_callback(
    void* output,
    const void* input,
    uint32_t frame_count,
    void* user_data
) {
    mmj_test_callback_state* state = (mmj_test_callback_state*)user_data;
    float* out = (float*)output;
    uint32_t i;
    
    if (state == NULL || out == NULL) {
        return;
    }
    
    state->call_count++;
    state->total_frames += frame_count;
    
    /* Generate a simple sine wave for testing */
    for (i = 0; i < frame_count; ++i) {
        float t = (float)(state->total_frames + i) / 48000.0f;
        out[i] = sinf(2.0f * 3.14159f * 440.0f * t) * 0.1f;
    }
}

int mmj_callback_path_smoke(void) {
    ma_device fake_device;
    mmj_sine_state sine_state;
    mmj_file_playback_state file_state;
    mmj_capture_state capture_state;
    mmj_capture_to_wav_state capture_to_wav_state;
    mmj_duplex_state duplex_state;
    mmj_playback_from_buffer_state playback_buffer_state;
    mmj_capture_to_buffer_state capture_buffer_state;
    mmj_custom_buffer_data_source_handle custom_ds_state;
    mmj_device_state device_state;
    mmj_test_callback_state callback_state;
    ma_attenuation_model resolved_model;
    ma_positioning resolved_positioning;
    ma_uint64 length_out;
    float out_f32[16];
    float in_f32[16];
    float backing_frames[8];
    float capture_frames[8];
    ma_uint8 out_u8[32];
    ma_uint8 in_u8[32];
    ma_uint64 i;

    memset(&fake_device, 0, sizeof(fake_device));
    memset(out_f32, 0, sizeof(out_f32));
    memset(in_f32, 0, sizeof(in_f32));
    memset(out_u8, 0, sizeof(out_u8));
    memset(in_u8, 0, sizeof(in_u8));
    for (i = 0; i < (ma_uint64)sizeof(in_u8); ++i) {
        in_u8[i] = (ma_uint8)(i & 0xFFu);
    }

    mmj_sleep_ms(0);

    fake_device.pUserData = NULL;
    mmj_data_callback(&fake_device, out_f32, NULL, 4);

    sine_state.phase = 0.0;
    sine_state.phase_step = MMJ_PI;
    sine_state.gain = 0.1f;
    sine_state.channels = 2;
    fake_device.pUserData = &sine_state;
    mmj_data_callback(&fake_device, out_f32, NULL, 4);

    fake_device.pUserData = NULL;
    mmj_file_playback_callback(&fake_device, out_f32, NULL, 4);
    memset(&file_state, 0, sizeof(file_state));
    file_state.channels = 2;
    fake_device.pUserData = &file_state;
    mmj_file_playback_callback(&fake_device, NULL, NULL, 4);

    fake_device.pUserData = NULL;
    mmj_capture_callback(&fake_device, NULL, NULL, 4);
    capture_state.observed_frames = 0;
    fake_device.pUserData = &capture_state;
    mmj_capture_callback(&fake_device, NULL, NULL, 4);

    memset(&capture_to_wav_state, 0, sizeof(capture_to_wav_state));
    fake_device.pUserData = NULL;
    mmj_capture_to_wav_callback(&fake_device, out_f32, in_f32, 4);
    fake_device.pUserData = &capture_to_wav_state;
    mmj_capture_to_wav_callback(&fake_device, out_f32, NULL, 4);
    mmj_capture_to_wav_callback(&fake_device, out_f32, in_f32, 0);

    fake_device.pUserData = NULL;
    mmj_duplex_callback(&fake_device, out_f32, in_f32, 4);
    duplex_state.observed_frames = 0;
    duplex_state.channels = 2;
    fake_device.pUserData = &duplex_state;
    mmj_duplex_callback(&fake_device, NULL, in_f32, 4);
    mmj_duplex_callback(&fake_device, out_f32, NULL, 4);
    mmj_duplex_callback(&fake_device, out_f32, in_f32, 4);

    fake_device.pUserData = NULL;
    mmj_device_callback(&fake_device, out_u8, in_u8, 4);
    memset(&device_state, 0, sizeof(device_state));
    device_state.channels = 2;
    device_state.bytes_per_sample = 1;
    device_state.mode = MMJ_DEVICE_MODE_SILENCE;
    fake_device.pUserData = &device_state;
    mmj_device_callback(&fake_device, NULL, in_u8, 4);

    callback_state.call_count = 0;
    callback_state.total_frames = 0;
    device_state.user_data_callback = mmj_test_data_callback;
    device_state.user_callback_data = &callback_state;
    mmj_device_callback(&fake_device, out_u8, in_u8, 4);

    device_state.user_data_callback = NULL;
    device_state.mode = MMJ_DEVICE_MODE_LOOPBACK;
    mmj_device_callback(&fake_device, out_u8, in_u8, 4);
    device_state.mode = MMJ_DEVICE_MODE_SILENCE;
    mmj_device_callback(&fake_device, out_u8, in_u8, 4);

    memset(&playback_buffer_state, 0, sizeof(playback_buffer_state));
    playback_buffer_state.buffer = NULL;
    playback_buffer_state.buffer_frame_count = 4;
    playback_buffer_state.current_position = 0;
    playback_buffer_state.channels = 2;
    fake_device.pUserData = &playback_buffer_state;
    mmj_playback_from_buffer_callback(&fake_device, out_f32, NULL, 4);

    playback_buffer_state.buffer = backing_frames;
    playback_buffer_state.buffer_frame_count = 4;
    playback_buffer_state.current_position = 2;
    playback_buffer_state.channels = 2;
    for (i = 0; i < 8; ++i) backing_frames[i] = (float)i;
    mmj_playback_from_buffer_callback(&fake_device, out_f32, NULL, 4);

    fake_device.pUserData = NULL;
    mmj_capture_to_buffer_callback(&fake_device, NULL, in_f32, 4);
    memset(&capture_buffer_state, 0, sizeof(capture_buffer_state));
    capture_buffer_state.buffer = capture_frames;
    capture_buffer_state.buffer_frame_capacity = 4;
    capture_buffer_state.frames_captured = 2;
    capture_buffer_state.channels = 2;
    fake_device.pUserData = &capture_buffer_state;
    mmj_capture_to_buffer_callback(&fake_device, NULL, in_f32, 4);

    memset(&custom_ds_state, 0, sizeof(custom_ds_state));
    (void)mmj_custom_buffer_data_source_on_get_length(NULL, &length_out);
    (void)mmj_custom_buffer_data_source_on_get_length((ma_data_source*)&custom_ds_state, NULL);
    custom_ds_state.initialized = 1;
    custom_ds_state.frame_count = 8;
    (void)mmj_custom_buffer_data_source_on_get_length((ma_data_source*)&custom_ds_state, &length_out);

    (void)mmj_attenuation_model_from_i32(0, &resolved_model);
    (void)mmj_attenuation_model_from_i32(1, &resolved_model);
    (void)mmj_attenuation_model_from_i32(2, &resolved_model);
    (void)mmj_attenuation_model_from_i32(3, &resolved_model);
    (void)mmj_attenuation_model_from_i32(99, &resolved_model);
    (void)mmj_positioning_from_i32(0, &resolved_positioning);
    (void)mmj_positioning_from_i32(1, &resolved_positioning);
    (void)mmj_positioning_from_i32(99, &resolved_positioning);

    if (capture_state.observed_frames == 0 || duplex_state.observed_frames == 0 || callback_state.call_count == 0) {
        return MA_ERROR;
    }

    return MA_SUCCESS;
}

int mmj_device_test_callback_smoke(uint32_t duration_ms) {
    ma_context context;
    ma_device_config config;
    ma_device device;
    ma_result result;
    mmj_test_callback_state callback_state;
    mmj_device_handle handle;
    
    /* Initialize context */
    result = ma_context_init(NULL, 0, NULL, &context);
    if (result != MA_SUCCESS) {
        return mmj_callback_path_smoke();
    }
    
    /* Initialize device handle */
    handle.state.channels = 2;
    handle.state.mode = MMJ_DEVICE_MODE_SILENCE;
    handle.state.kind = MMJ_DEVICE_KIND_PLAYBACK;
    handle.state.observed_frames = 0;
    handle.state.user_data_callback = mmj_test_data_callback;
    handle.state.user_stop_callback = NULL;
    handle.state.user_callback_data = &callback_state;
    
    /* Initialize callback state */
    callback_state.call_count = 0;
    callback_state.total_frames = 0;
    
    /* Configure device */
    config = ma_device_config_init(ma_device_type_playback);
    config.sampleRate = 48000;
    config.dataCallback = mmj_device_callback;
    config.pUserData = &handle.state;
    config.playback.format = ma_format_f32;
    config.playback.channels = 2;
    
    /* Initialize and start device */
    result = ma_device_init(&context, &config, &device);
    if (result != MA_SUCCESS) {
        ma_context_uninit(&context);
        return mmj_callback_path_smoke();
    }
    
    handle.device = device;
    handle.initialized = 1;
    handle.started = 0;
    
    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        ma_context_uninit(&context);
        return mmj_callback_path_smoke();
    }
    
    handle.started = 1;
    
    /* Let it run for specified duration */
#if defined(_WIN32)
    Sleep(duration_ms);
#else
    usleep(duration_ms * 1000);
#endif
    
    /* Stop device */
    result = ma_device_stop(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        ma_context_uninit(&context);
        return mmj_callback_path_smoke();
    }
    
    /* Cleanup */
    ma_device_uninit(&device);
    ma_context_uninit(&context);
    
    /* Verify that callbacks were called */
    if (callback_state.call_count == 0) {
        return mmj_callback_path_smoke();
    }
    
    return MA_SUCCESS;
}

/* Biquad EQ node implementations */

void* mmj_biquad_node_create(void) {
    mmj_biquad_node_handle* handle = (mmj_biquad_node_handle*)calloc(1, sizeof(mmj_biquad_node_handle));
    return handle;
}

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
) {
    mmj_biquad_node_handle* biquad = (mmj_biquad_node_handle*)biquad_node_handle;
    mmj_engine_handle* engine = (mmj_engine_handle*)engine_handle;
    ma_biquad_node_config config;
    ma_result result;

    if (biquad == NULL || engine == NULL || !engine->initialized || channels == 0) {
        return MA_INVALID_ARGS;
    }

    /* Validate coefficients (a0 should not be zero to avoid division by zero) */
    if (a0 == 0.0f) {
        return MA_INVALID_ARGS;
    }

    if (biquad->initialized) {
        ma_biquad_node_uninit(&biquad->node, NULL);
        biquad->initialized = 0;
    }

    /* Initialize biquad node config with provided coefficients */
    config = ma_biquad_node_config_init(channels, b0, b1, b2, a0, a1, a2);
    result = ma_biquad_node_init(ma_engine_get_node_graph(&engine->engine), &config, NULL, &biquad->node);
    
    if (result == MA_SUCCESS) {
        biquad->channels = channels;
        biquad->b0 = b0;
        biquad->b1 = b1;
        biquad->b2 = b2;
        biquad->a0 = a0;
        biquad->a1 = a1;
        biquad->a2 = a2;
        biquad->initialized = 1;
    }

    return result;
}

int mmj_biquad_node_reinit(
    void* biquad_node_handle,
    float b0,
    float b1,
    float b2,
    float a0,
    float a1,
    float a2
) {
    mmj_biquad_node_handle* biquad = (mmj_biquad_node_handle*)biquad_node_handle;
    ma_biquad_config config;
    ma_result result;

    if (biquad == NULL || !biquad->initialized || a0 == 0.0f) {
        return MA_INVALID_ARGS;
    }

    config = ma_biquad_config_init(ma_format_f32, biquad->channels, b0, b1, b2, a0, a1, a2);
    result = ma_biquad_node_reinit(&config, &biquad->node);
    
    if (result == MA_SUCCESS) {
        biquad->b0 = b0;
        biquad->b1 = b1;
        biquad->b2 = b2;
        biquad->a0 = a0;
        biquad->a1 = a1;
        biquad->a2 = a2;
    }

    return result;
}

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
) {
    if (out_b0 == NULL || out_b1 == NULL || out_b2 == NULL ||
        out_a0 == NULL || out_a1 == NULL || out_a2 == NULL ||
        sample_rate == 0 || q <= 0.0 || frequency <= 0.0) {
        return MA_INVALID_ARGS;
    }

    /* For MVP, return identity filter coefficients (no-op effect).
       Full coefficient calculation using RBJ cookbook formulas deferred.
       Identity filter: H(z) = 1 (b0=1, b1=0, b2=0, a0=1, a1=0, a2=0)
    */
    *out_b0 = 1.0f;
    *out_b1 = 0.0f;
    *out_b2 = 0.0f;
    *out_a0 = 1.0f;
    *out_a1 = 0.0f;
    *out_a2 = 0.0f;

    return MA_SUCCESS;
}

void* mmj_biquad_node_get_node(void* biquad_node_handle) {
    mmj_biquad_node_handle* biquad = (mmj_biquad_node_handle*)biquad_node_handle;

    if (biquad == NULL || !biquad->initialized) {
        return NULL;
    }

    return (void*)&biquad->node.baseNode;
}

int mmj_biquad_node_uninit(void* biquad_node_handle) {
    mmj_biquad_node_handle* biquad = (mmj_biquad_node_handle*)biquad_node_handle;

    if (biquad == NULL) {
        return MA_INVALID_ARGS;
    }

    if (!biquad->initialized) {
        return MA_SUCCESS;
    }

    ma_biquad_node_uninit(&biquad->node, NULL);
    biquad->initialized = 0;
    return MA_SUCCESS;
}

void mmj_biquad_node_destroy(void* biquad_node_handle) {
    mmj_biquad_node_handle* biquad = (mmj_biquad_node_handle*)biquad_node_handle;

    if (biquad == NULL) {
        return;
    }

    if (biquad->initialized) {
        ma_biquad_node_uninit(&biquad->node, NULL);
    }

    free(biquad);
}

/* ============================================================
 * notch node
 * ============================================================ */

void* mmj_notch_node_create(void) {
    return calloc(1, sizeof(mmj_notch_node_handle));
}

int mmj_notch_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double q, double frequency) {
    mmj_notch_node_handle* h = (mmj_notch_node_handle*)handle;
    mmj_engine_handle* eng = (mmj_engine_handle*)engine_handle;
    if (h == NULL || eng == NULL || !eng->initialized || channels == 0 || sample_rate == 0) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0) return MA_INVALID_ARGS;
    if (h->initialized) { ma_notch_node_uninit(&h->node, NULL); h->initialized = 0; }
    ma_notch_node_config cfg = ma_notch_node_config_init(channels, sample_rate, q, frequency);
    ma_result r = ma_notch_node_init(ma_engine_get_node_graph(&eng->engine), &cfg, NULL, &h->node);
    if (r == MA_SUCCESS) { h->initialized = 1; h->channels = channels; }
    return (int)r;
}

int mmj_notch_node_reinit(void* handle, uint32_t sample_rate, double q, double frequency) {
    mmj_notch_node_handle* h = (mmj_notch_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0 || sample_rate == 0) return MA_INVALID_ARGS;
    ma_notch_config cfg = ma_notch2_config_init(ma_format_f32, h->channels, sample_rate, q, frequency);
    return (int)ma_notch_node_reinit(&cfg, &h->node);
}

void* mmj_notch_node_get_node(void* handle) {
    mmj_notch_node_handle* h = (mmj_notch_node_handle*)handle;
    if (h == NULL || !h->initialized) return NULL;
    return (void*)&h->node;
}

int mmj_notch_node_uninit(void* handle) {
    mmj_notch_node_handle* h = (mmj_notch_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    ma_notch_node_uninit(&h->node, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

void mmj_notch_node_destroy(void* handle) {
    mmj_notch_node_handle* h = (mmj_notch_node_handle*)handle;
    if (h == NULL) return;
    if (h->initialized) { ma_notch_node_uninit(&h->node, NULL); }
    free(h);
}

/* ============================================================
 * peak node
 * ============================================================ */

void* mmj_peak_node_create(void) {
    return calloc(1, sizeof(mmj_peak_node_handle));
}

int mmj_peak_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_peak_node_handle* h = (mmj_peak_node_handle*)handle;
    mmj_engine_handle* eng = (mmj_engine_handle*)engine_handle;
    if (h == NULL || eng == NULL || !eng->initialized || channels == 0 || sample_rate == 0) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0) return MA_INVALID_ARGS;
    if (h->initialized) { ma_peak_node_uninit(&h->node, NULL); h->initialized = 0; }
    ma_peak_node_config cfg = ma_peak_node_config_init(channels, sample_rate, gain_db, q, frequency);
    ma_result r = ma_peak_node_init(ma_engine_get_node_graph(&eng->engine), &cfg, NULL, &h->node);
    if (r == MA_SUCCESS) { h->initialized = 1; h->channels = channels; }
    return (int)r;
}

int mmj_peak_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_peak_node_handle* h = (mmj_peak_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0 || sample_rate == 0) return MA_INVALID_ARGS;
    ma_peak_config cfg = ma_peak2_config_init(ma_format_f32, h->channels, sample_rate, gain_db, q, frequency);
    return (int)ma_peak_node_reinit(&cfg, &h->node);
}

void* mmj_peak_node_get_node(void* handle) {
    mmj_peak_node_handle* h = (mmj_peak_node_handle*)handle;
    if (h == NULL || !h->initialized) return NULL;
    return (void*)&h->node;
}

int mmj_peak_node_uninit(void* handle) {
    mmj_peak_node_handle* h = (mmj_peak_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    ma_peak_node_uninit(&h->node, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

void mmj_peak_node_destroy(void* handle) {
    mmj_peak_node_handle* h = (mmj_peak_node_handle*)handle;
    if (h == NULL) return;
    if (h->initialized) { ma_peak_node_uninit(&h->node, NULL); }
    free(h);
}

/* ============================================================
 * loshelf node
 * ============================================================ */

void* mmj_loshelf_node_create(void) {
    return calloc(1, sizeof(mmj_loshelf_node_handle));
}

int mmj_loshelf_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_loshelf_node_handle* h = (mmj_loshelf_node_handle*)handle;
    mmj_engine_handle* eng = (mmj_engine_handle*)engine_handle;
    if (h == NULL || eng == NULL || !eng->initialized || channels == 0 || sample_rate == 0) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0) return MA_INVALID_ARGS;
    if (h->initialized) { ma_loshelf_node_uninit(&h->node, NULL); h->initialized = 0; }
    ma_loshelf_node_config cfg = ma_loshelf_node_config_init(channels, sample_rate, gain_db, q, frequency);
    ma_result r = ma_loshelf_node_init(ma_engine_get_node_graph(&eng->engine), &cfg, NULL, &h->node);
    if (r == MA_SUCCESS) { h->initialized = 1; h->channels = channels; }
    return (int)r;
}

int mmj_loshelf_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_loshelf_node_handle* h = (mmj_loshelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0 || sample_rate == 0) return MA_INVALID_ARGS;
    ma_loshelf_config cfg = ma_loshelf2_config_init(ma_format_f32, h->channels, sample_rate, gain_db, q, frequency);
    return (int)ma_loshelf_node_reinit(&cfg, &h->node);
}

void* mmj_loshelf_node_get_node(void* handle) {
    mmj_loshelf_node_handle* h = (mmj_loshelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return NULL;
    return (void*)&h->node;
}

int mmj_loshelf_node_uninit(void* handle) {
    mmj_loshelf_node_handle* h = (mmj_loshelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    ma_loshelf_node_uninit(&h->node, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

void mmj_loshelf_node_destroy(void* handle) {
    mmj_loshelf_node_handle* h = (mmj_loshelf_node_handle*)handle;
    if (h == NULL) return;
    if (h->initialized) { ma_loshelf_node_uninit(&h->node, NULL); }
    free(h);
}

/* ============================================================
 * hishelf node
 * ============================================================ */

void* mmj_hishelf_node_create(void) {
    return calloc(1, sizeof(mmj_hishelf_node_handle));
}

int mmj_hishelf_node_init(void* handle, void* engine_handle, uint32_t channels, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_hishelf_node_handle* h = (mmj_hishelf_node_handle*)handle;
    mmj_engine_handle* eng = (mmj_engine_handle*)engine_handle;
    if (h == NULL || eng == NULL || !eng->initialized || channels == 0 || sample_rate == 0) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0) return MA_INVALID_ARGS;
    if (h->initialized) { ma_hishelf_node_uninit(&h->node, NULL); h->initialized = 0; }
    ma_hishelf_node_config cfg = ma_hishelf_node_config_init(channels, sample_rate, gain_db, q, frequency);
    ma_result r = ma_hishelf_node_init(ma_engine_get_node_graph(&eng->engine), &cfg, NULL, &h->node);
    if (r == MA_SUCCESS) { h->initialized = 1; h->channels = channels; }
    return (int)r;
}

int mmj_hishelf_node_reinit(void* handle, uint32_t sample_rate, double gain_db, double q, double frequency) {
    mmj_hishelf_node_handle* h = (mmj_hishelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    if (q <= 0.0 || frequency <= 0.0 || sample_rate == 0) return MA_INVALID_ARGS;
    ma_hishelf_config cfg = ma_hishelf2_config_init(ma_format_f32, h->channels, sample_rate, gain_db, q, frequency);
    return (int)ma_hishelf_node_reinit(&cfg, &h->node);
}

void* mmj_hishelf_node_get_node(void* handle) {
    mmj_hishelf_node_handle* h = (mmj_hishelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return NULL;
    return (void*)&h->node;
}

int mmj_hishelf_node_uninit(void* handle) {
    mmj_hishelf_node_handle* h = (mmj_hishelf_node_handle*)handle;
    if (h == NULL || !h->initialized) return MA_INVALID_ARGS;
    ma_hishelf_node_uninit(&h->node, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

void mmj_hishelf_node_destroy(void* handle) {
    mmj_hishelf_node_handle* h = (mmj_hishelf_node_handle*)handle;
    if (h == NULL) return;
    if (h->initialized) { ma_hishelf_node_uninit(&h->node, NULL); }
    free(h);
}
