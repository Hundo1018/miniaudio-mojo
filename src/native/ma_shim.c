#include "ma_shim.h"

#include "miniaudio.h"

#include <stdlib.h>

/*
 * Bookkeeping wrapper: the raw ma_decoder plus an `initialized` flag so that
 * uninit is idempotent and read/seek before init fail deterministically with
 * MA_INVALID_ARGS. This is thin lifecycle bookkeeping, not scenario logic.
 */
typedef struct ma_shim_decoder {
    ma_decoder decoder;
    int initialized;
} ma_shim_decoder;

/* ---- core ---- */

/* @binds ma_version_string */
const char* ma_shim_version(void) {
    return ma_version_string();
}

/* @binds ma_result_description */
const char* ma_shim_result_description(int result_code) {
    return ma_result_description((ma_result)result_code);
}

/* ---- decoder ---- */

/* Shim-managed allocation (no direct ma_* counterpart; miniaudio does not
 * export a heap-allocator for ma_decoder). */
void* ma_shim_decoder_alloc(void) {
    return calloc(1, sizeof(ma_shim_decoder));
}

/* @binds ma_decoder_uninit */
void ma_shim_decoder_free(void* handle) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_decoder_uninit(&h->decoder);
        h->initialized = 0;
    }
    free(h);
}

static int ma_shim_resolve_format(int code, ma_format* out_format) {
    if (code < 0 || code >= ma_format_count) {
        return MA_INVALID_ARGS;
    }
    *out_format = (ma_format)code;
    return MA_SUCCESS;
}

/* @binds ma_decoder_init_file, ma_decoder_config_init */
int ma_shim_decoder_init_file(
    void* handle,
    const char* file_path,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_decoder_config config;
    ma_format format;
    ma_result result;

    if (h == NULL || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (ma_shim_resolve_format(output_format, &format) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_decoder_uninit(&h->decoder);
        h->initialized = 0;
    }

    config = ma_decoder_config_init(format, output_channels, output_sample_rate);
    result = ma_decoder_init_file(file_path, &config, &h->decoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_decoder_init_memory, ma_decoder_config_init */
int ma_shim_decoder_init_memory(
    void* handle,
    const void* data,
    size_t data_size,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_decoder_config config;
    ma_format format;
    ma_result result;

    if (h == NULL || data == NULL || data_size == 0) {
        return MA_INVALID_ARGS;
    }
    if (ma_shim_resolve_format(output_format, &format) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_decoder_uninit(&h->decoder);
        h->initialized = 0;
    }

    config = ma_decoder_config_init(format, output_channels, output_sample_rate);
    /* NOTE: miniaudio references `data` for the decoder's lifetime; it does not
     * copy. The Mojo API layer owns and keeps the buffer alive. */
    result = ma_decoder_init_memory(data, data_size, &config, &h->decoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_decoder_uninit */
int ma_shim_decoder_uninit(void* handle) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_decoder_uninit(&h->decoder);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_decoder_read_pcm_frames */
int ma_shim_decoder_read_pcm_frames(
    void* handle,
    void* output,
    unsigned long long frame_count,
    unsigned long long* frames_read
) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_uint64 local_read = 0;
    ma_result result;

    if (frames_read != NULL) {
        *frames_read = 0;
    }
    if (h == NULL || !h->initialized || output == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_decoder_read_pcm_frames(&h->decoder, output, (ma_uint64)frame_count, &local_read);
    if (frames_read != NULL) {
        *frames_read = (unsigned long long)local_read;
    }
    return (int)result;
}

/* @binds ma_decoder_seek_to_pcm_frame */
int ma_shim_decoder_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_decoder_seek_to_pcm_frame(&h->decoder, (ma_uint64)frame_index);
}

/* @binds ma_decoder_get_length_in_pcm_frames */
int ma_shim_decoder_get_length_in_pcm_frames(void* handle, unsigned long long* out_length) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_uint64 length = 0;
    ma_result result;

    if (out_length != NULL) {
        *out_length = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_decoder_get_length_in_pcm_frames(&h->decoder, &length);
    if (result == MA_SUCCESS && out_length != NULL) {
        *out_length = (unsigned long long)length;
    }
    return (int)result;
}

/* @binds ma_decoder_get_cursor_in_pcm_frames */
int ma_shim_decoder_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_uint64 cursor = 0;
    ma_result result;

    if (out_cursor != NULL) {
        *out_cursor = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_decoder_get_cursor_in_pcm_frames(&h->decoder, &cursor);
    if (result == MA_SUCCESS && out_cursor != NULL) {
        *out_cursor = (unsigned long long)cursor;
    }
    return (int)result;
}

/* @binds ma_decoder_get_data_format */
unsigned int ma_shim_decoder_output_channels(void* handle) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    if (ma_decoder_get_data_format(&h->decoder, &format, &channels, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return 0;
    }
    return (unsigned int)channels;
}

/* @binds ma_decoder_get_data_format */
unsigned int ma_shim_decoder_output_sample_rate(void* handle) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    if (ma_decoder_get_data_format(&h->decoder, &format, &channels, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return 0;
    }
    return (unsigned int)sample_rate;
}

/* @binds ma_decoder_get_data_format */
int ma_shim_decoder_output_format(void* handle) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    if (h == NULL || !h->initialized) {
        return (int)ma_format_unknown;
    }
    if (ma_decoder_get_data_format(&h->decoder, &format, &channels, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return (int)ma_format_unknown;
    }
    return (int)format;
}

/* ---- encoder ---- */

/*
 * Same bookkeeping pattern as ma_shim_decoder: the raw ma_encoder plus an
 * `initialized` flag so free/uninit are idempotent and write-before-init fails
 * deterministically with MA_INVALID_ARGS.
 */
typedef struct ma_shim_encoder {
    ma_encoder encoder;
    int initialized;
} ma_shim_encoder;

/* Shim-managed allocation (no direct ma_* counterpart; miniaudio does not
 * export a heap-allocator for ma_encoder). */
void* ma_shim_encoder_alloc(void) {
    return calloc(1, sizeof(ma_shim_encoder));
}

/* @binds ma_encoder_uninit */
void ma_shim_encoder_free(void* handle) {
    ma_shim_encoder* h = (ma_shim_encoder*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_encoder_uninit(&h->encoder);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_encoder_init_file, ma_encoder_config_init */
int ma_shim_encoder_init_file(
    void* handle,
    const char* file_path,
    int encoding_format,
    int format,
    unsigned int channels,
    unsigned int sample_rate
) {
    ma_shim_encoder* h = (ma_shim_encoder*)handle;
    ma_encoder_config config;
    ma_format ma_fmt;
    ma_result result;

    if (h == NULL || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (encoding_format < 0 || encoding_format > ma_encoding_format_vorbis) {
        return MA_INVALID_ARGS;
    }
    if (ma_shim_resolve_format(format, &ma_fmt) != MA_SUCCESS) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_encoder_uninit(&h->encoder);
        h->initialized = 0;
    }

    config = ma_encoder_config_init(
        (ma_encoding_format)encoding_format, ma_fmt, channels, sample_rate);
    result = ma_encoder_init_file(file_path, &config, &h->encoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_encoder_uninit */
int ma_shim_encoder_uninit(void* handle) {
    ma_shim_encoder* h = (ma_shim_encoder*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_encoder_uninit(&h->encoder);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_encoder_write_pcm_frames */
int ma_shim_encoder_write_pcm_frames(
    void* handle,
    const void* input,
    unsigned long long frame_count,
    unsigned long long* frames_written
) {
    ma_shim_encoder* h = (ma_shim_encoder*)handle;
    ma_uint64 local_written = 0;
    ma_result result;

    if (frames_written != NULL) {
        *frames_written = 0;
    }
    if (h == NULL || !h->initialized || input == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_encoder_write_pcm_frames(&h->encoder, input, (ma_uint64)frame_count, &local_written);
    if (frames_written != NULL) {
        *frames_written = (unsigned long long)local_written;
    }
    return (int)result;
}

/* ---- device (playback pulling from a decoder) ---- */

typedef struct ma_shim_device {
    ma_device device;
    ma_context context;
    int has_context;                  /* whether a null-backend context was created */
    int initialized;
    ma_shim_decoder* source;          /* decoder to pull from; NOT owned by the device */
    unsigned int channels;
    unsigned long long frames_processed;  /* observable: frames pulled in the callback */
} ma_shim_device;

/* Shim-owned data callback: pull f32 frames from the source decoder into the
 * output buffer, zero-fill the tail at end-of-stream, and count frames. Runs on
 * miniaudio's audio thread. */
static void ma_shim_device__on_data(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    ma_shim_device* h = (ma_shim_device*)pDevice->pUserData;
    ma_uint64 framesRead = 0;
    (void)pInput;
    if (h == NULL || h->source == NULL || !h->source->initialized || pOutput == NULL) {
        return;
    }
    ma_decoder_read_pcm_frames(&h->source->decoder, pOutput, (ma_uint64)frameCount, &framesRead);
    if (framesRead < (ma_uint64)frameCount) {
        float* out = (float*)pOutput;
        ma_uint64 i;
        for (i = framesRead * h->channels; i < (ma_uint64)frameCount * h->channels; i++) {
            out[i] = 0.0f;
        }
    }
    h->frames_processed += framesRead;
}

void* ma_shim_device_alloc(void) {
    return calloc(1, sizeof(ma_shim_device));
}

/* @binds ma_device_uninit */
void ma_shim_device_free(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_device_uninit(&h->device);
        h->initialized = 0;
    }
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    free(h);
}

/* @binds ma_device_init, ma_device_config_init, ma_context_init, ma_context_config_init */
int ma_shim_device_init_playback_from_decoder(
    void* handle,
    void* decoder_handle,
    unsigned int sample_rate_override,
    int use_null_backend
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    ma_shim_decoder* src = (ma_shim_decoder*)decoder_handle;
    ma_device_config config;
    ma_format format = ma_format_f32;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    ma_context* pContext = NULL;
    ma_result result;

    if (h == NULL || src == NULL || !src->initialized) {
        return MA_INVALID_ARGS;
    }
    if (ma_decoder_get_data_format(&src->decoder, &format, &channels, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return MA_INVALID_OPERATION;
    }
    if (sample_rate_override != 0) {
        sample_rate = sample_rate_override;
    }

    if (h->initialized) {
        ma_device_uninit(&h->device);
        h->initialized = 0;
    }
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }

    if (use_null_backend) {
        ma_backend backends[1];
        ma_context_config context_config = ma_context_config_init();
        backends[0] = ma_backend_null;
        result = ma_context_init(backends, 1, &context_config, &h->context);
        if (result != MA_SUCCESS) {
            return (int)result;
        }
        h->has_context = 1;
        pContext = &h->context;
    }

    config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = format;
    config.playback.channels = channels;
    config.sampleRate = sample_rate;
    config.dataCallback = ma_shim_device__on_data;
    config.pUserData = h;

    h->source = src;
    h->channels = channels;
    h->frames_processed = 0;

    result = ma_device_init(pContext, &config, &h->device);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    } else if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    return (int)result;
}

/* @binds ma_device_start */
int ma_shim_device_start(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_start(&h->device);
}

/* @binds ma_device_stop */
int ma_shim_device_stop(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_stop(&h->device);
}

/* @binds ma_device_uninit */
int ma_shim_device_uninit(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_device_uninit(&h->device);
    h->initialized = 0;
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    return MA_SUCCESS;
}

unsigned int ma_shim_device_get_channels(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)h->device.playback.channels;
}

unsigned int ma_shim_device_get_sample_rate(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)h->device.sampleRate;
}

unsigned long long ma_shim_device_get_frames_processed(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return h->frames_processed;
}
