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

/* ======================================================================== */
/* ma_pulsewave                                                              */
/* ======================================================================== */

typedef struct ma_shim_pulsewave {
    ma_pulsewave pulsewave;
    int          initialized;
} ma_shim_pulsewave;

static ma_shim_pulsewave* pulsewave_ready(void* handle) {
    ma_shim_pulsewave* h = (ma_shim_pulsewave*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static void pulsewave_teardown(ma_shim_pulsewave* h) {
    if (h->initialized) {
        ma_pulsewave_uninit(&h->pulsewave);
        h->initialized = 0;
    }
}

void* ma_shim_pulsewave_alloc(void) {
    return calloc(1, sizeof(ma_shim_pulsewave));
}

/* @binds ma_pulsewave_uninit */
void ma_shim_pulsewave_free(void* handle) {
    ma_shim_pulsewave* h = (ma_shim_pulsewave*)handle;
    if (h == NULL) {
        return;
    }
    pulsewave_teardown(h);
    free(h);
}

/* @binds ma_pulsewave_config_init, ma_pulsewave_init */
int ma_shim_pulsewave_init(
    void*         handle,
    int           format,
    unsigned int  channels,
    unsigned int  sample_rate,
    double        duty_cycle,
    double        amplitude,
    double        frequency
) {
    ma_shim_pulsewave* h = (ma_shim_pulsewave*)handle;
    ma_pulsewave_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    pulsewave_teardown(h);
    cfg = ma_pulsewave_config_init(
        (ma_format)format, channels, sample_rate, duty_cycle, amplitude, frequency
    );
    result = ma_pulsewave_init(&cfg, &h->pulsewave);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_pulsewave_uninit */
int ma_shim_pulsewave_uninit(void* handle) {
    ma_shim_pulsewave* h = (ma_shim_pulsewave*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    pulsewave_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_pulsewave_read_pcm_frames */
int ma_shim_pulsewave_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    ma_uint64 read = 0;
    ma_result result;

    if (h == NULL || output == NULL) {
        if (frames_read_out != NULL) { *frames_read_out = 0; }
        return MA_INVALID_ARGS;
    }
    result = ma_pulsewave_read_pcm_frames(&h->pulsewave, output, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_pulsewave_seek_to_pcm_frame */
int ma_shim_pulsewave_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pulsewave_seek_to_pcm_frame(&h->pulsewave, (ma_uint64)frame_index);
}

/* @binds ma_pulsewave_set_amplitude */
int ma_shim_pulsewave_set_amplitude(void* handle, double amplitude) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pulsewave_set_amplitude(&h->pulsewave, amplitude);
}

/* @binds ma_pulsewave_set_frequency */
int ma_shim_pulsewave_set_frequency(void* handle, double frequency) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pulsewave_set_frequency(&h->pulsewave, frequency);
}

/* @binds ma_pulsewave_set_sample_rate */
int ma_shim_pulsewave_set_sample_rate(void* handle, unsigned int sample_rate) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pulsewave_set_sample_rate(&h->pulsewave, sample_rate);
}

/* @binds ma_pulsewave_set_duty_cycle */
int ma_shim_pulsewave_set_duty_cycle(void* handle, double duty_cycle) {
    ma_shim_pulsewave* h = pulsewave_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pulsewave_set_duty_cycle(&h->pulsewave, duty_cycle);
}
