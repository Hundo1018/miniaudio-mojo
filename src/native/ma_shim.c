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
