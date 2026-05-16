#include "miniaudio_shim.h"

#include "miniaudio.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <time.h>
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
    int initialized;
} mmj_decoder_handle;

typedef struct mmj_engine_handle {
    ma_engine engine;
    int initialized;
} mmj_engine_handle;

typedef struct mmj_sound_handle {
    ma_sound sound;
    int initialized;
} mmj_sound_handle;

typedef struct mmj_lpf_node_handle {
    ma_lpf_node node;
    uint32_t channels;
    uint32_t sample_rate;
    uint32_t order;
    float cutoff_hz;
    int initialized;
} mmj_lpf_node_handle;

typedef struct mmj_delay_node_handle {
    ma_delay_node node;
    float decay;
    float wet;
    float dry;
    int initialized;
} mmj_delay_node_handle;

typedef struct mmj_resource_manager_handle {
    ma_resource_manager resource_manager;
    int initialized;
} mmj_resource_manager_handle;

typedef struct mmj_resource_data_source_handle {
    ma_resource_manager_data_source data_source;
    int initialized;
} mmj_resource_data_source_handle;

typedef struct mmj_device_state {
    uint32_t channels;
    int mode;
    int kind;
} mmj_device_state;

typedef struct mmj_device_handle {
    ma_device device;
    mmj_device_state state;
    int initialized;
    int started;
} mmj_device_handle;

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

static void mmj_device_callback(
    ma_device* device,
    void* output,
    const void* input,
    ma_uint32 frame_count
) {
    mmj_device_state* state = (mmj_device_state*)device->pUserData;
    ma_uint64 total_samples;
    float* out = (float*)output;
    const float* in = (const float*)input;
    ma_uint64 i;

    if (state == NULL || out == NULL) {
        return;
    }

    total_samples = (ma_uint64)frame_count * (ma_uint64)state->channels;

    if (state->mode == MMJ_DEVICE_MODE_LOOPBACK && in != NULL) {
        for (i = 0; i < total_samples; ++i) {
            out[i] = in[i];
        }
        return;
    }

    memset(out, 0, (size_t)total_samples * sizeof(float));
}

static int mmj_device_init_internal(
    void* device_handle,
    ma_device_type device_type,
    uint32_t sample_rate,
    uint32_t channels,
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
    handle->state.kind = MMJ_DEVICE_KIND_PLAYBACK;
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
        config.playback.format = ma_format_f32;
        config.playback.channels = channels;
    }

    if (device_type == ma_device_type_capture || device_type == ma_device_type_duplex) {
        config.capture.format = ma_format_f32;
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

void* mmj_sound_get_node(void* sound_handle) {
    mmj_sound_handle* handle = (mmj_sound_handle*)sound_handle;

    if (handle == NULL || !handle->initialized) {
        return NULL;
    }

    return (void*)&handle->sound.engineNode.baseNode;
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

void* mmj_device_create(void) {
    mmj_device_handle* handle = (mmj_device_handle*)calloc(1, sizeof(mmj_device_handle));
    return handle;
}

int mmj_device_init_playback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_internal(
        device_handle,
        ma_device_type_playback,
        sample_rate,
        channels,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_capture_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_internal(
        device_handle,
        ma_device_type_capture,
        sample_rate,
        channels,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_duplex_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_internal(
        device_handle,
        ma_device_type_duplex,
        sample_rate,
        channels,
        MMJ_DEVICE_MODE_SILENCE
    );
}

int mmj_device_init_duplex_loopback_f32(
    void* device_handle,
    uint32_t sample_rate,
    uint32_t channels
) {
    return mmj_device_init_internal(
        device_handle,
        ma_device_type_duplex,
        sample_rate,
        channels,
        MMJ_DEVICE_MODE_LOOPBACK
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

int mmj_decoder_init_file_f32(
    void* decoder_handle,
    const char* file_path,
    uint32_t output_channels,
    uint32_t output_sample_rate
) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_decoder_config config;
    ma_result result;

    if (handle == NULL || file_path == NULL || output_channels == 0) {
        return MA_INVALID_ARGS;
    }

    if (handle->initialized) {
        ma_decoder_uninit(&handle->decoder);
        handle->initialized = 0;
    }

    config = ma_decoder_config_init(ma_format_f32, output_channels, output_sample_rate);
    result = ma_decoder_init_file(file_path, &config, &handle->decoder);
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

int64_t mmj_decoder_read_probe_f32(void* decoder_handle, uint64_t frame_count) {
    mmj_decoder_handle* handle = (mmj_decoder_handle*)decoder_handle;
    ma_uint32 channels = 0;
    ma_uint64 local_frames_read = 0;
    ma_result result;
    float* buffer = NULL;

    if (handle == NULL || !handle->initialized || frame_count == 0) {
        return (int64_t)MA_INVALID_ARGS;
    }

    result = ma_decoder_get_data_format(
        &handle->decoder,
        NULL,
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

    buffer = (float*)malloc(sizeof(float) * (size_t)frame_count * (size_t)channels);
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
