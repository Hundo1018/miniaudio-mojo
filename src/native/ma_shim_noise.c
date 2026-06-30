#include "ma_shim_noise.h"
#include "miniaudio.h"

#include <stdlib.h>

typedef struct ma_shim_noise {
    ma_noise noise;
    int      initialized;
} ma_shim_noise;

void* ma_shim_noise_alloc(void) {
    return calloc(1, sizeof(ma_shim_noise));
}

/* @binds ma_noise_uninit */
void ma_shim_noise_free(void* handle) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_noise_uninit(&h->noise, NULL);
        h->initialized = 0;
    }
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
    if (h->initialized) {
        ma_noise_uninit(&h->noise, NULL);
        h->initialized = 0;
    }
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

/* @binds ma_noise_uninit */
int ma_shim_noise_uninit(void* handle) {
    ma_shim_noise* h = (ma_shim_noise*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_noise_uninit(&h->noise, NULL);
    h->initialized = 0;
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

