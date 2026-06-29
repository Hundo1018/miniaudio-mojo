#include "ma_shim_waveform.h"
#include "miniaudio.h"

#include <stdlib.h>

typedef struct ma_shim_waveform {
    ma_waveform waveform;
    int         initialized;
} ma_shim_waveform;

void* ma_shim_waveform_alloc(void) {
    return calloc(1, sizeof(ma_shim_waveform));
}

/* @binds ma_waveform_uninit */
void ma_shim_waveform_free(void* handle) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_waveform_uninit(&h->waveform);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_waveform_config_init, ma_waveform_init */
int ma_shim_waveform_init(
    void*         handle,
    int           format,
    unsigned int  channels,
    unsigned int  sample_rate,
    int           waveform_type,
    double        amplitude,
    double        frequency
) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    ma_waveform_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_waveform_uninit(&h->waveform);
        h->initialized = 0;
    }
    cfg = ma_waveform_config_init(
        (ma_format)format,
        channels,
        sample_rate,
        (ma_waveform_type)waveform_type,
        amplitude,
        frequency
    );
    result = ma_waveform_init(&cfg, &h->waveform);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_waveform_uninit */
int ma_shim_waveform_uninit(void* handle) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_waveform_uninit(&h->waveform);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_waveform_read_pcm_frames */
int ma_shim_waveform_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    ma_uint64 read = 0;
    ma_result result;

    if (h == NULL || !h->initialized || output == NULL) {
        if (frames_read_out != NULL) { *frames_read_out = 0; }
        return MA_INVALID_ARGS;
    }
    result = ma_waveform_read_pcm_frames(&h->waveform, output, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_waveform_seek_to_pcm_frame */
int ma_shim_waveform_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_waveform_seek_to_pcm_frame(&h->waveform, (ma_uint64)frame_index);
}

/* @binds ma_waveform_set_amplitude */
int ma_shim_waveform_set_amplitude(void* handle, double amplitude) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_waveform_set_amplitude(&h->waveform, amplitude);
}

/* @binds ma_waveform_set_frequency */
int ma_shim_waveform_set_frequency(void* handle, double frequency) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_waveform_set_frequency(&h->waveform, frequency);
}

/* @binds ma_waveform_set_type */
int ma_shim_waveform_set_type(void* handle, int waveform_type) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_waveform_set_type(&h->waveform, (ma_waveform_type)waveform_type);
}

/* @binds ma_waveform_set_sample_rate */
int ma_shim_waveform_set_sample_rate(void* handle, unsigned int sample_rate) {
    ma_shim_waveform* h = (ma_shim_waveform*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_waveform_set_sample_rate(&h->waveform, sample_rate);
}
