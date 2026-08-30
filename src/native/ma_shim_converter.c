#include "ma_shim_converter.h"
#include "miniaudio.h"

#include <stdlib.h>

/* ================= ma_resampler ================= */

typedef struct ma_shim_resampler_handle {
    ma_resampler resampler;
    void*        heap;        /* non-NULL when the preallocated path was used */
    int          initialized;
} ma_shim_resampler_handle;

static void resampler_teardown(ma_shim_resampler_handle* h) {
    if (h->initialized) {
        ma_resampler_uninit(&h->resampler, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_shim_resampler_handle* resampler_ready(void* handle) {
    ma_shim_resampler_handle* h = (ma_shim_resampler_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static ma_resampler_config resampler_config(
    int format, unsigned int channels, unsigned int rate_in, unsigned int rate_out, int algorithm
) {
    return ma_resampler_config_init(
        (ma_format)format,
        (ma_uint32)channels,
        (ma_uint32)rate_in,
        (ma_uint32)rate_out,
        (ma_resample_algorithm)algorithm);
}

void* ma_shim_resampler_alloc(void) {
    return calloc(1, sizeof(ma_shim_resampler_handle));
}

/* @binds ma_resampler_uninit */
void ma_shim_resampler_free(void* handle) {
    ma_shim_resampler_handle* h = (ma_shim_resampler_handle*)handle;
    if (h == NULL) {
        return;
    }
    resampler_teardown(h);
    free(h);
}

/* @binds ma_resampler_config_init, ma_resampler_get_heap_size */
int ma_shim_resampler_get_heap_size(
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate_in,
    unsigned int        sample_rate_out,
    int                 algorithm,
    unsigned long long* out_heap_size
) {
    ma_resampler_config config;
    size_t              size = 0;
    ma_result           result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_heap_size = 0;
    config = resampler_config(format, channels, sample_rate_in, sample_rate_out, algorithm);
    result = ma_resampler_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_resampler_config_init, ma_resampler_init */
int ma_shim_resampler_init(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out,
    int          algorithm
) {
    ma_shim_resampler_handle* h = (ma_shim_resampler_handle*)handle;
    ma_resampler_config       config;
    ma_result                 result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    resampler_teardown(h);

    config = resampler_config(format, channels, sample_rate_in, sample_rate_out, algorithm);
    result = ma_resampler_init(&config, NULL, &h->resampler);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_resampler_config_init, ma_resampler_get_heap_size, ma_resampler_init_preallocated */
int ma_shim_resampler_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out,
    int          algorithm
) {
    ma_shim_resampler_handle* h = (ma_shim_resampler_handle*)handle;
    ma_resampler_config       config;
    size_t                    heap_size = 0;
    void*                     heap = NULL;
    ma_result                 result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    resampler_teardown(h);

    config = resampler_config(format, channels, sample_rate_in, sample_rate_out, algorithm);
    result = ma_resampler_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_resampler_init_preallocated(&config, heap, &h->resampler);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_resampler_uninit */
int ma_shim_resampler_uninit(void* handle) {
    ma_shim_resampler_handle* h = (ma_shim_resampler_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    resampler_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_resampler_process_pcm_frames */
int ma_shim_resampler_process(
    void*               handle,
    const void*         frames_in,
    unsigned long long* frame_count_in,
    void*               frames_out,
    unsigned long long* frame_count_out
) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    ma_uint64                 in_count;
    ma_uint64                 out_count;
    ma_result                 result;

    if (h == NULL || frame_count_in == NULL || frame_count_out == NULL) {
        return MA_INVALID_ARGS;
    }
    in_count = (ma_uint64)*frame_count_in;
    out_count = (ma_uint64)*frame_count_out;

    result = ma_resampler_process_pcm_frames(
        &h->resampler, frames_in, &in_count, frames_out, &out_count);

    *frame_count_in = (unsigned long long)in_count;
    *frame_count_out = (unsigned long long)out_count;
    return (int)result;
}

/* @binds ma_resampler_set_rate */
int ma_shim_resampler_set_rate(void* handle, unsigned int rate_in, unsigned int rate_out) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resampler_set_rate(&h->resampler, (ma_uint32)rate_in, (ma_uint32)rate_out);
}

/* @binds ma_resampler_set_rate_ratio */
int ma_shim_resampler_set_rate_ratio(void* handle, float ratio) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resampler_set_rate_ratio(&h->resampler, ratio);
}

/* @binds ma_resampler_get_input_latency */
int ma_shim_resampler_get_input_latency(void* handle, unsigned long long* out_latency) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    if (out_latency != NULL) { *out_latency = 0; }
    if (h == NULL || out_latency == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_latency = (unsigned long long)ma_resampler_get_input_latency(&h->resampler);
    return MA_SUCCESS;
}

/* @binds ma_resampler_get_output_latency */
int ma_shim_resampler_get_output_latency(void* handle, unsigned long long* out_latency) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    if (out_latency != NULL) { *out_latency = 0; }
    if (h == NULL || out_latency == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_latency = (unsigned long long)ma_resampler_get_output_latency(&h->resampler);
    return MA_SUCCESS;
}

/* @binds ma_resampler_get_required_input_frame_count */
int ma_shim_resampler_get_required_input_frame_count(
    void*               handle,
    unsigned long long  output_frame_count,
    unsigned long long* out_input_frame_count
) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    ma_uint64                 count = 0;
    ma_result                 result;

    if (out_input_frame_count != NULL) { *out_input_frame_count = 0; }
    if (h == NULL || out_input_frame_count == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_resampler_get_required_input_frame_count(
        &h->resampler, (ma_uint64)output_frame_count, &count);
    *out_input_frame_count = (unsigned long long)count;
    return (int)result;
}

/* @binds ma_resampler_get_expected_output_frame_count */
int ma_shim_resampler_get_expected_output_frame_count(
    void*               handle,
    unsigned long long  input_frame_count,
    unsigned long long* out_output_frame_count
) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    ma_uint64                 count = 0;
    ma_result                 result;

    if (out_output_frame_count != NULL) { *out_output_frame_count = 0; }
    if (h == NULL || out_output_frame_count == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_resampler_get_expected_output_frame_count(
        &h->resampler, (ma_uint64)input_frame_count, &count);
    *out_output_frame_count = (unsigned long long)count;
    return (int)result;
}

/* @binds ma_resampler_reset */
int ma_shim_resampler_reset(void* handle) {
    ma_shim_resampler_handle* h = resampler_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_resampler_reset(&h->resampler);
}

/* ================= ma_channel_converter ================= */

typedef struct ma_shim_channel_converter_handle {
    ma_channel_converter converter;
    void*                heap;
    int                  initialized;
} ma_shim_channel_converter_handle;

static void channel_converter_teardown(ma_shim_channel_converter_handle* h) {
    if (h->initialized) {
        ma_channel_converter_uninit(&h->converter, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_shim_channel_converter_handle* channel_converter_ready(void* handle) {
    ma_shim_channel_converter_handle* h = (ma_shim_channel_converter_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

/* NULL channel maps ask miniaudio for the default map for that channel count. */
static ma_channel_converter_config channel_converter_config(
    int format, unsigned int channels_in, unsigned int channels_out, int mix_mode
) {
    return ma_channel_converter_config_init(
        (ma_format)format,
        (ma_uint32)channels_in,
        NULL,
        (ma_uint32)channels_out,
        NULL,
        (ma_channel_mix_mode)mix_mode);
}

void* ma_shim_channel_converter_alloc(void) {
    return calloc(1, sizeof(ma_shim_channel_converter_handle));
}

/* @binds ma_channel_converter_uninit */
void ma_shim_channel_converter_free(void* handle) {
    ma_shim_channel_converter_handle* h = (ma_shim_channel_converter_handle*)handle;
    if (h == NULL) {
        return;
    }
    channel_converter_teardown(h);
    free(h);
}

/* @binds ma_channel_converter_config_init, ma_channel_converter_get_heap_size */
int ma_shim_channel_converter_get_heap_size(
    int                 format,
    unsigned int        channels_in,
    unsigned int        channels_out,
    int                 mix_mode,
    unsigned long long* out_heap_size
) {
    ma_channel_converter_config config;
    size_t                      size = 0;
    ma_result                   result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_heap_size = 0;
    config = channel_converter_config(format, channels_in, channels_out, mix_mode);
    result = ma_channel_converter_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_channel_converter_config_init, ma_channel_converter_init */
int ma_shim_channel_converter_init(
    void*        handle,
    int          format,
    unsigned int channels_in,
    unsigned int channels_out,
    int          mix_mode
) {
    ma_shim_channel_converter_handle* h = (ma_shim_channel_converter_handle*)handle;
    ma_channel_converter_config       config;
    ma_result                         result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    channel_converter_teardown(h);

    config = channel_converter_config(format, channels_in, channels_out, mix_mode);
    result = ma_channel_converter_init(&config, NULL, &h->converter);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_channel_converter_config_init, ma_channel_converter_get_heap_size, ma_channel_converter_init_preallocated */
int ma_shim_channel_converter_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels_in,
    unsigned int channels_out,
    int          mix_mode
) {
    ma_shim_channel_converter_handle* h = (ma_shim_channel_converter_handle*)handle;
    ma_channel_converter_config       config;
    size_t                            heap_size = 0;
    void*                             heap = NULL;
    ma_result                         result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    channel_converter_teardown(h);

    config = channel_converter_config(format, channels_in, channels_out, mix_mode);
    result = ma_channel_converter_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_channel_converter_init_preallocated(&config, heap, &h->converter);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_channel_converter_uninit */
int ma_shim_channel_converter_uninit(void* handle) {
    ma_shim_channel_converter_handle* h = (ma_shim_channel_converter_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    channel_converter_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_channel_converter_process_pcm_frames */
int ma_shim_channel_converter_process(
    void*              handle,
    void*              frames_out,
    const void*        frames_in,
    unsigned long long frame_count
) {
    ma_shim_channel_converter_handle* h = channel_converter_ready(handle);
    if (h == NULL || frames_out == NULL || frames_in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_channel_converter_process_pcm_frames(
        &h->converter, frames_out, frames_in, (ma_uint64)frame_count);
}

/* @binds ma_channel_converter_get_input_channel_map */
int ma_shim_channel_converter_get_input_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
) {
    ma_shim_channel_converter_handle* h = channel_converter_ready(handle);
    if (h == NULL || out_map == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_channel_converter_get_input_channel_map(
        &h->converter, (ma_channel*)out_map, (size_t)capacity);
}

/* @binds ma_channel_converter_get_output_channel_map */
int ma_shim_channel_converter_get_output_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
) {
    ma_shim_channel_converter_handle* h = channel_converter_ready(handle);
    if (h == NULL || out_map == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_channel_converter_get_output_channel_map(
        &h->converter, (ma_channel*)out_map, (size_t)capacity);
}

/* ================= ma_data_converter ================= */

typedef struct ma_shim_data_converter_handle {
    ma_data_converter converter;
    void*             heap;
    int               initialized;
} ma_shim_data_converter_handle;

static void data_converter_teardown(ma_shim_data_converter_handle* h) {
    if (h->initialized) {
        ma_data_converter_uninit(&h->converter, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_shim_data_converter_handle* data_converter_ready(void* handle) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static ma_data_converter_config data_converter_config(
    int          format_in,
    int          format_out,
    unsigned int channels_in,
    unsigned int channels_out,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
) {
    return ma_data_converter_config_init(
        (ma_format)format_in,
        (ma_format)format_out,
        (ma_uint32)channels_in,
        (ma_uint32)channels_out,
        (ma_uint32)sample_rate_in,
        (ma_uint32)sample_rate_out);
}

void* ma_shim_data_converter_alloc(void) {
    return calloc(1, sizeof(ma_shim_data_converter_handle));
}

/* @binds ma_data_converter_uninit */
void ma_shim_data_converter_free(void* handle) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    if (h == NULL) {
        return;
    }
    data_converter_teardown(h);
    free(h);
}

/* @binds ma_data_converter_config_init, ma_data_converter_get_heap_size */
int ma_shim_data_converter_get_heap_size(
    int                 format_in,
    int                 format_out,
    unsigned int        channels_in,
    unsigned int        channels_out,
    unsigned int        sample_rate_in,
    unsigned int        sample_rate_out,
    unsigned long long* out_heap_size
) {
    ma_data_converter_config config;
    size_t                   size = 0;
    ma_result                result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_heap_size = 0;
    config = data_converter_config(
        format_in, format_out, channels_in, channels_out, sample_rate_in, sample_rate_out);
    result = ma_data_converter_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_data_converter_config_init, ma_data_converter_init */
int ma_shim_data_converter_init(
    void*        handle,
    int          format_in,
    int          format_out,
    unsigned int channels_in,
    unsigned int channels_out,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    ma_data_converter_config       config;
    ma_result                      result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    data_converter_teardown(h);

    config = data_converter_config(
        format_in, format_out, channels_in, channels_out, sample_rate_in, sample_rate_out);
    result = ma_data_converter_init(&config, NULL, &h->converter);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_data_converter_config_init_default, ma_data_converter_init */
int ma_shim_data_converter_init_default(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate
) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    ma_data_converter_config       config;
    ma_result                      result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    data_converter_teardown(h);

    /* Everything except the pass-through shape is left at miniaudio's defaults. */
    config = ma_data_converter_config_init_default();
    config.formatIn = (ma_format)format;
    config.formatOut = (ma_format)format;
    config.channelsIn = (ma_uint32)channels;
    config.channelsOut = (ma_uint32)channels;
    config.sampleRateIn = (ma_uint32)sample_rate;
    config.sampleRateOut = (ma_uint32)sample_rate;

    result = ma_data_converter_init(&config, NULL, &h->converter);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_data_converter_config_init, ma_data_converter_get_heap_size, ma_data_converter_init_preallocated */
int ma_shim_data_converter_init_preallocated(
    void*        handle,
    int          format_in,
    int          format_out,
    unsigned int channels_in,
    unsigned int channels_out,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    ma_data_converter_config       config;
    size_t                         heap_size = 0;
    void*                          heap = NULL;
    ma_result                      result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    data_converter_teardown(h);

    config = data_converter_config(
        format_in, format_out, channels_in, channels_out, sample_rate_in, sample_rate_out);
    result = ma_data_converter_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_data_converter_init_preallocated(&config, heap, &h->converter);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_data_converter_uninit */
int ma_shim_data_converter_uninit(void* handle) {
    ma_shim_data_converter_handle* h = (ma_shim_data_converter_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    data_converter_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_data_converter_process_pcm_frames */
int ma_shim_data_converter_process(
    void*               handle,
    const void*         frames_in,
    unsigned long long* frame_count_in,
    void*               frames_out,
    unsigned long long* frame_count_out
) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    ma_uint64                      in_count;
    ma_uint64                      out_count;
    ma_result                      result;

    if (h == NULL || frame_count_in == NULL || frame_count_out == NULL) {
        return MA_INVALID_ARGS;
    }
    in_count = (ma_uint64)*frame_count_in;
    out_count = (ma_uint64)*frame_count_out;

    result = ma_data_converter_process_pcm_frames(
        &h->converter, frames_in, &in_count, frames_out, &out_count);

    *frame_count_in = (unsigned long long)in_count;
    *frame_count_out = (unsigned long long)out_count;
    return (int)result;
}

/* @binds ma_data_converter_set_rate */
int ma_shim_data_converter_set_rate(void* handle, unsigned int rate_in, unsigned int rate_out) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_converter_set_rate(&h->converter, (ma_uint32)rate_in, (ma_uint32)rate_out);
}

/* @binds ma_data_converter_set_rate_ratio */
int ma_shim_data_converter_set_rate_ratio(void* handle, float ratio) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_converter_set_rate_ratio(&h->converter, ratio);
}

/* @binds ma_data_converter_get_input_latency */
int ma_shim_data_converter_get_input_latency(void* handle, unsigned long long* out_latency) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (out_latency != NULL) { *out_latency = 0; }
    if (h == NULL || out_latency == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_latency = (unsigned long long)ma_data_converter_get_input_latency(&h->converter);
    return MA_SUCCESS;
}

/* @binds ma_data_converter_get_output_latency */
int ma_shim_data_converter_get_output_latency(void* handle, unsigned long long* out_latency) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (out_latency != NULL) { *out_latency = 0; }
    if (h == NULL || out_latency == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_latency = (unsigned long long)ma_data_converter_get_output_latency(&h->converter);
    return MA_SUCCESS;
}

/* @binds ma_data_converter_get_required_input_frame_count */
int ma_shim_data_converter_get_required_input_frame_count(
    void*               handle,
    unsigned long long  output_frame_count,
    unsigned long long* out_input_frame_count
) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    ma_uint64                      count = 0;
    ma_result                      result;

    if (out_input_frame_count != NULL) { *out_input_frame_count = 0; }
    if (h == NULL || out_input_frame_count == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_data_converter_get_required_input_frame_count(
        &h->converter, (ma_uint64)output_frame_count, &count);
    *out_input_frame_count = (unsigned long long)count;
    return (int)result;
}

/* @binds ma_data_converter_get_expected_output_frame_count */
int ma_shim_data_converter_get_expected_output_frame_count(
    void*               handle,
    unsigned long long  input_frame_count,
    unsigned long long* out_output_frame_count
) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    ma_uint64                      count = 0;
    ma_result                      result;

    if (out_output_frame_count != NULL) { *out_output_frame_count = 0; }
    if (h == NULL || out_output_frame_count == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_data_converter_get_expected_output_frame_count(
        &h->converter, (ma_uint64)input_frame_count, &count);
    *out_output_frame_count = (unsigned long long)count;
    return (int)result;
}

/* @binds ma_data_converter_get_input_channel_map */
int ma_shim_data_converter_get_input_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (h == NULL || out_map == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_converter_get_input_channel_map(
        &h->converter, (ma_channel*)out_map, (size_t)capacity);
}

/* @binds ma_data_converter_get_output_channel_map */
int ma_shim_data_converter_get_output_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (h == NULL || out_map == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_converter_get_output_channel_map(
        &h->converter, (ma_channel*)out_map, (size_t)capacity);
}

/* @binds ma_data_converter_reset */
int ma_shim_data_converter_reset(void* handle) {
    ma_shim_data_converter_handle* h = data_converter_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_converter_reset(&h->converter);
}
