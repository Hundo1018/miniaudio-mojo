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
