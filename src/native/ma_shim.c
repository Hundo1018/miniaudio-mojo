#include "ma_shim.h"

#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

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

/* ma_decoder_config_init_copy is MA_API but defined only inside miniaudio's
 * MINIAUDIO_IMPLEMENTATION block, so no prototype reaches consumers of
 * miniaudio.h. The symbol is exported and stable, so declare it here rather
 * than leaving it unbindable (mirrors ma_device_info_add_native_data_format). */
MA_API ma_decoder_config ma_decoder_config_init_copy(const ma_decoder_config* pConfig);

/*
 * Init a decoder from a file using the DEFAULT decoder config: native output
 * format / channels / sample-rate are preserved (no conversion). Builds the
 * default config via ma_decoder_config_init_default, then round-trips it through
 * ma_decoder_config_init_copy (proving the copy constructor) before init_file.
 */
/* @binds ma_decoder_init_file, ma_decoder_config_init_default, ma_decoder_config_init_copy */
int ma_shim_decoder_init_file_default(void* handle, const char* file_path) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_decoder_config base;
    ma_decoder_config config;
    ma_result result;

    if (h == NULL || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_decoder_uninit(&h->decoder);
        h->initialized = 0;
    }

    base = ma_decoder_config_init_default();
    config = ma_decoder_config_init_copy(&base);
    result = ma_decoder_init_file(file_path, &config, &h->decoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/*
 * Init a decoder from a file path through the VFS API, passing a NULL ma_vfs so
 * miniaudio falls back to its default (stdio) VFS. The dedicated VFS family is
 * not yet modeled; this NULL-VFS path is the honest bindable slice and behaves
 * like init_file via the default filesystem.
 */
/* @binds ma_decoder_init_vfs, ma_decoder_config_init */
int ma_shim_decoder_init_file_vfs(
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
    result = ma_decoder_init_vfs(NULL, file_path, &config, &h->decoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_decoder_get_available_frames */
int ma_shim_decoder_get_available_frames(void* handle, unsigned long long* out_available) {
    ma_shim_decoder* h = (ma_shim_decoder*)handle;
    ma_uint64 available = 0;
    ma_result result;

    if (out_available != NULL) {
        *out_available = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_decoder_get_available_frames(&h->decoder, &available);
    if (result == MA_SUCCESS && out_available != NULL) {
        *out_available = (unsigned long long)available;
    }
    return (int)result;
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

/*
 * Init an encoder to a file path through the VFS API with a NULL ma_vfs so
 * miniaudio uses its default (stdio) VFS. Mirrors ma_shim_decoder_init_file_vfs;
 * the VFS family is not yet modeled, so the NULL-VFS path is the bindable slice.
 */
/* @binds ma_encoder_init_vfs, ma_encoder_config_init */
int ma_shim_encoder_init_file_vfs(
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
    result = ma_encoder_init_vfs(NULL, file_path, &config, &h->encoder);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* ---- device (playback pulling from a decoder) ---- */

/* miniaudio defines ma_device_info_add_native_data_format as MA_API (= extern)
 * but only inside its MINIAUDIO_IMPLEMENTATION block, so no prototype reaches
 * consumers of miniaudio.h. The symbol is exported and stable, so declare it
 * here rather than leaving the function unbindable. */
MA_API void ma_device_info_add_native_data_format(
    ma_device_info* pDeviceInfo,
    ma_format format,
    ma_uint32 channels,
    ma_uint32 sampleRate,
    ma_uint32 flags
);

typedef struct ma_shim_device {
    ma_device device;
    ma_context context;
    int has_context;                  /* whether a null-backend context was created */
    int initialized;
    ma_shim_decoder* source;          /* decoder to pull from; NOT owned by the device */
    unsigned int channels;
    unsigned long long frames_processed;  /* observable: frames pulled in the callback */
    ma_device_info info;              /* snapshot filled by ma_shim_device_info_load */
    int has_info;                     /* whether `info` holds a successful snapshot */
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
    h->has_info = 0;

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
    h->has_info = 0;
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

/* @binds ma_device_init_ex, ma_device_config_init, ma_context_config_init */
int ma_shim_device_init_ex_playback_from_decoder(
    void* handle,
    void* decoder_handle,
    const int* backends,
    unsigned int backend_count,
    unsigned int sample_rate_override
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    ma_shim_decoder* src = (ma_shim_decoder*)decoder_handle;
    ma_device_config config;
    ma_context_config context_config;
    ma_backend backend_list[MA_BACKEND_COUNT];
    ma_format format = ma_format_f32;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    ma_uint32 i;
    ma_result result;

    if (h == NULL || src == NULL || !src->initialized) {
        return MA_INVALID_ARGS;
    }
    if (backend_count > MA_BACKEND_COUNT || (backend_count > 0 && backends == NULL)) {
        return MA_INVALID_ARGS;
    }
    if (ma_decoder_get_data_format(&src->decoder, &format, &channels, &sample_rate, NULL, 0) != MA_SUCCESS) {
        return MA_INVALID_OPERATION;
    }
    if (sample_rate_override != 0) {
        sample_rate = sample_rate_override;
    }
    for (i = 0; i < backend_count; i++) {
        backend_list[i] = (ma_backend)backends[i];
    }

    if (h->initialized) {
        ma_device_uninit(&h->device);
        h->initialized = 0;
    }
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    h->has_info = 0;

    context_config = ma_context_config_init();

    config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = format;
    config.playback.channels = channels;
    config.sampleRate = sample_rate;
    config.dataCallback = ma_shim_device__on_data;
    config.pUserData = h;

    h->source = src;
    h->channels = channels;
    h->frames_processed = 0;

    /* ma_device_init_ex allocates a context internally and marks the device as
     * its owner, so ma_device_uninit frees it; has_context stays 0 here. */
    result = ma_device_init_ex(
        (backend_count > 0) ? backend_list : NULL,
        backend_count,
        &context_config,
        &config,
        &h->device
    );
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_device_get_state */
int ma_shim_device_get_state(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return (int)ma_device_state_uninitialized;
    }
    return (int)ma_device_get_state(&h->device);
}

/* @binds ma_device_is_started */
int ma_shim_device_is_started(void* handle) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return ma_device_is_started(&h->device) ? 1 : 0;
}

/* @binds ma_device_set_master_volume */
int ma_shim_device_set_master_volume(void* handle, float volume) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_set_master_volume(&h->device, volume);
}

/* @binds ma_device_get_master_volume */
int ma_shim_device_get_master_volume(void* handle, float* out_volume) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized || out_volume == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_get_master_volume(&h->device, out_volume);
}

/* @binds ma_device_set_master_volume_db */
int ma_shim_device_set_master_volume_db(void* handle, float gain_db) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_set_master_volume_db(&h->device, gain_db);
}

/* @binds ma_device_get_master_volume_db */
int ma_shim_device_get_master_volume_db(void* handle, float* out_gain_db) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized || out_gain_db == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_get_master_volume_db(&h->device, out_gain_db);
}

/* @binds ma_device_get_name */
int ma_shim_device_get_name(
    void* handle,
    int device_type,
    char* out_name,
    size_t name_cap,
    size_t* out_length
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_get_name(
        &h->device, (ma_device_type)device_type, out_name, name_cap, out_length
    );
}

/* @binds ma_device_get_info */
int ma_shim_device_info_load(void* handle, int device_type) {
    ma_shim_device* h = (ma_shim_device*)handle;
    ma_result result;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_device_get_info(&h->device, (ma_device_type)device_type, &h->info);
    h->has_info = (result == MA_SUCCESS) ? 1 : 0;
    return (int)result;
}

/* Copies the loaded snapshot's name out, always null-terminating and truncating
 * to name_cap. out_length excludes the null terminator. */
int ma_shim_device_info_name(
    void* handle,
    char* out_name,
    size_t name_cap,
    size_t* out_length
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    size_t len;
    if (h == NULL || !h->has_info || out_name == NULL || name_cap == 0) {
        return MA_INVALID_ARGS;
    }
    len = strlen(h->info.name);
    if (len >= name_cap) {
        len = name_cap - 1;
    }
    memcpy(out_name, h->info.name, len);
    out_name[len] = '\0';
    if (out_length != NULL) {
        *out_length = len;
    }
    return MA_SUCCESS;
}

int ma_shim_device_info_is_default(void* handle, int* out_is_default) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->has_info || out_is_default == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_is_default = (h->info.isDefault != 0) ? 1 : 0;
    return MA_SUCCESS;
}

int ma_shim_device_info_native_data_format_count(void* handle, unsigned int* out_count) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->has_info || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_count = (unsigned int)h->info.nativeDataFormatCount;
    return MA_SUCCESS;
}

int ma_shim_device_info_native_data_format(
    void* handle,
    unsigned int index,
    int* out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate,
    unsigned int* out_flags
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->has_info) {
        return MA_INVALID_ARGS;
    }
    if (index >= h->info.nativeDataFormatCount) {
        return MA_INVALID_ARGS;
    }
    if (out_format != NULL) {
        *out_format = (int)h->info.nativeDataFormats[index].format;
    }
    if (out_channels != NULL) {
        *out_channels = (unsigned int)h->info.nativeDataFormats[index].channels;
    }
    if (out_sample_rate != NULL) {
        *out_sample_rate = (unsigned int)h->info.nativeDataFormats[index].sampleRate;
    }
    if (out_flags != NULL) {
        *out_flags = (unsigned int)h->info.nativeDataFormats[index].flags;
    }
    return MA_SUCCESS;
}

/* @binds ma_device_info_add_native_data_format */
int ma_shim_device_info_add_native_data_format(
    void* handle,
    int format,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int flags
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->has_info) {
        return MA_INVALID_ARGS;
    }
    /* miniaudio silently ignores the append once the array is full; report that
     * to the caller instead of pretending it landed. */
    if (h->info.nativeDataFormatCount
        >= (ma_uint32)(sizeof(h->info.nativeDataFormats) / sizeof(h->info.nativeDataFormats[0]))) {
        return MA_OUT_OF_RANGE;
    }
    ma_device_info_add_native_data_format(
        &h->info, (ma_format)format, (ma_uint32)channels, (ma_uint32)sample_rate, (ma_uint32)flags
    );
    return MA_SUCCESS;
}

/* @binds ma_device_id_equal, ma_device_get_info */
int ma_shim_device_id_equal(
    void* handle_a,
    void* handle_b,
    int device_type,
    int* out_equal
) {
    ma_shim_device* a = (ma_shim_device*)handle_a;
    ma_shim_device* b = (ma_shim_device*)handle_b;
    ma_device_info info_a;
    ma_device_info info_b;

    if (a == NULL || b == NULL || !a->initialized || !b->initialized || out_equal == NULL) {
        return MA_INVALID_ARGS;
    }
    if (ma_device_get_info(&a->device, (ma_device_type)device_type, &info_a) != MA_SUCCESS) {
        return MA_INVALID_OPERATION;
    }
    if (ma_device_get_info(&b->device, (ma_device_type)device_type, &info_b) != MA_SUCCESS) {
        return MA_INVALID_OPERATION;
    }
    *out_equal = ma_device_id_equal(&info_a.id, &info_b.id) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_device_get_context */
int ma_shim_device_get_context_backend(void* handle, int* out_backend) {
    ma_shim_device* h = (ma_shim_device*)handle;
    ma_context* pContext;
    if (h == NULL || !h->initialized || out_backend == NULL) {
        return MA_INVALID_ARGS;
    }
    pContext = ma_device_get_context(&h->device);
    if (pContext == NULL) {
        return MA_INVALID_OPERATION;
    }
    *out_backend = (int)pContext->backend;
    return MA_SUCCESS;
}

/* @binds ma_device_get_log */
int ma_shim_device_has_log(void* handle, int* out_has_log) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized || out_has_log == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_has_log = (ma_device_get_log(&h->device) != NULL) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_device_handle_backend_data_callback */
int ma_shim_device_handle_backend_data_callback(
    void* handle,
    void* output,
    const void* input,
    unsigned int frame_count
) {
    ma_shim_device* h = (ma_shim_device*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_device_handle_backend_data_callback(
        &h->device, output, input, (ma_uint32)frame_count
    );
}

/* ---- device job thread ---- */

typedef struct ma_shim_device_job_thread {
    ma_device_job_thread job_thread;
    int initialized;
} ma_shim_device_job_thread;

void* ma_shim_device_job_thread_alloc(void) {
    return calloc(1, sizeof(ma_shim_device_job_thread));
}

/* @binds ma_device_job_thread_uninit */
void ma_shim_device_job_thread_free(void* handle) {
    ma_shim_device_job_thread* h = (ma_shim_device_job_thread*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_device_job_thread_uninit(&h->job_thread, NULL);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_device_job_thread_init, ma_device_job_thread_config_init */
int ma_shim_device_job_thread_init(
    void* handle,
    int no_thread,
    unsigned int job_queue_capacity,
    unsigned int job_queue_flags
) {
    ma_shim_device_job_thread* h = (ma_shim_device_job_thread*)handle;
    ma_device_job_thread_config config;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_device_job_thread_uninit(&h->job_thread, NULL);
        h->initialized = 0;
    }
    config = ma_device_job_thread_config_init();
    config.noThread = no_thread ? MA_TRUE : MA_FALSE;
    if (job_queue_capacity != 0) {
        config.jobQueueCapacity = (ma_uint32)job_queue_capacity;
    }
    config.jobQueueFlags = (ma_uint32)job_queue_flags;

    result = ma_device_job_thread_init(&config, NULL, &h->job_thread);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_device_job_thread_uninit */
int ma_shim_device_job_thread_uninit(void* handle) {
    ma_shim_device_job_thread* h = (ma_shim_device_job_thread*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_device_job_thread_uninit(&h->job_thread, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_device_job_thread_post, ma_job_init */
int ma_shim_device_job_thread_post(void* handle, unsigned short job_code) {
    ma_shim_device_job_thread* h = (ma_shim_device_job_thread*)handle;
    ma_job job;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    job = ma_job_init((ma_uint16)job_code);
    return (int)ma_device_job_thread_post(&h->job_thread, &job);
}

/* @binds ma_device_job_thread_next */
int ma_shim_device_job_thread_next(void* handle, unsigned short* out_job_code) {
    ma_shim_device_job_thread* h = (ma_shim_device_job_thread*)handle;
    ma_job job;
    ma_result result;
    if (h == NULL || !h->initialized || out_job_code == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_device_job_thread_next(&h->job_thread, &job);
    if (result == MA_SUCCESS) {
        *out_job_code = (unsigned short)job.toc.breakup.code;
    }
    return (int)result;
}
