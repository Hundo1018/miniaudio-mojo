#include "ma_shim_noise.h"
#include "miniaudio.h"

#include <stdlib.h>

typedef struct ma_shim_noise {
    ma_noise noise;
    void*    heap;   /* non-NULL when the preallocated path was used */
    int      initialized;
} ma_shim_noise;

/* Uninit if live, then release a preallocated heap (miniaudio does not own it). */
static void noise_teardown(ma_shim_noise* h) {
    if (h->initialized) {
        ma_noise_uninit(&h->noise, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

void* ma_shim_noise_alloc(void) {
    return calloc(1, sizeof(ma_shim_noise));
}

/* @binds ma_noise_uninit */
void ma_shim_noise_free(void* handle) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL) {
        return;
    }
    noise_teardown(h);
    free(h);
}

/* @binds ma_noise_config_init, ma_noise_init */
int ma_shim_noise_init(
    void*         handle,
    int           format,
    unsigned int  channels,
    int           noise_type,
    int           seed,
    double        amplitude
) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    ma_noise_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    noise_teardown(h);
    cfg = ma_noise_config_init(
        (ma_format)format,
        channels,
        (ma_noise_type)noise_type,
        (ma_int32)seed,
        amplitude
    );
    result = ma_noise_init(&cfg, NULL, &h->noise);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_noise_config_init, ma_noise_get_heap_size */
int ma_shim_noise_get_heap_size(
    int format, unsigned int channels, int noise_type, unsigned long long* out_heap_size
) {
    ma_noise_config cfg;
    size_t          size = 0;
    ma_result       result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    cfg = ma_noise_config_init((ma_format)format, channels, (ma_noise_type)noise_type, 0, 1.0);
    result = ma_noise_get_heap_size(&cfg, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_noise_config_init, ma_noise_get_heap_size, ma_noise_init_preallocated */
int ma_shim_noise_init_preallocated(
    void*         handle,
    int           format,
    unsigned int  channels,
    int           noise_type,
    int           seed,
    double        amplitude
) {
    ma_shim_noise*  h = (ma_shim_noise*)handle;
    ma_noise_config cfg;
    size_t          heap_size = 0;
    void*           heap = NULL;
    ma_result       result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    noise_teardown(h);
    cfg = ma_noise_config_init(
        (ma_format)format, channels, (ma_noise_type)noise_type, (ma_int32)seed, amplitude);

    result = ma_noise_get_heap_size(&cfg, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    /* White noise needs no heap at all; only allocate when there is something to hold. */
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }
    result = ma_noise_init_preallocated(&cfg, heap, &h->noise);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_noise_uninit */
int ma_shim_noise_uninit(void* handle) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    noise_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_noise_read_pcm_frames */
int ma_shim_noise_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    ma_uint64 read = 0;
    ma_result result;

    if (h == NULL || !h->initialized || output == NULL) {
        if (frames_read_out != NULL) { *frames_read_out = 0; }
        return MA_INVALID_ARGS;
    }
    result = ma_noise_read_pcm_frames(&h->noise, output, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_noise_set_amplitude */
int ma_shim_noise_set_amplitude(void* handle, double amplitude) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_noise_set_amplitude(&h->noise, amplitude);
}

/* @binds ma_noise_set_seed */
int ma_shim_noise_set_seed(void* handle, int seed) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_noise_set_seed(&h->noise, (ma_int32)seed);
}

