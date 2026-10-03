#include "ma_shim_effect.h"
#include "miniaudio.h"

#include <stdlib.h>

/* ======================================================================== */
/* ma_delay                                                                  */
/* ======================================================================== */

typedef struct ma_shim_delay {
    ma_delay delay;
    int      initialized;
} ma_shim_delay;

static ma_shim_delay* delay_ready(void* handle) {
    ma_shim_delay* h = (ma_shim_delay*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static void delay_teardown(ma_shim_delay* h) {
    if (h->initialized) {
        ma_delay_uninit(&h->delay, NULL);
        h->initialized = 0;
    }
}

void* ma_shim_delay_alloc(void) {
    return calloc(1, sizeof(ma_shim_delay));
}

/* @binds ma_delay_uninit */
void ma_shim_delay_free(void* handle) {
    ma_shim_delay* h = (ma_shim_delay*)handle;
    if (h == NULL) {
        return;
    }
    delay_teardown(h);
    free(h);
}

/* @binds ma_delay_config_init, ma_delay_init */
int ma_shim_delay_init(
    void*        handle,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int delay_in_frames,
    float        decay
) {
    ma_shim_delay* h = (ma_shim_delay*)handle;
    ma_delay_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    delay_teardown(h);
    /* miniaudio does not validate these: channels == 0 makes every process call
     * a no-op and delay_in_frames == 0 divides by zero on the cursor wrap. */
    if (channels == 0 || delay_in_frames == 0) {
        return MA_INVALID_ARGS;
    }
    cfg = ma_delay_config_init(channels, sample_rate, delay_in_frames, decay);
    result = ma_delay_init(&cfg, NULL, &h->delay);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_delay_uninit */
int ma_shim_delay_uninit(void* handle) {
    ma_shim_delay* h = (ma_shim_delay*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    delay_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_delay_process_pcm_frames */
int ma_shim_delay_process(void* handle, void* out, const void* in, unsigned int frame_count) {
    ma_shim_delay* h = delay_ready(handle);
    if (h == NULL || out == NULL || in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_delay_process_pcm_frames(&h->delay, out, in, (ma_uint32)frame_count);
}

/* @binds ma_delay_set_wet */
int ma_shim_delay_set_wet(void* handle, float value) {
    ma_shim_delay* h = delay_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_set_wet(&h->delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_get_wet */
int ma_shim_delay_get_wet(void* handle, float* out_value) {
    ma_shim_delay* h = delay_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_get_wet(&h->delay);
    return MA_SUCCESS;
}

/* @binds ma_delay_set_dry */
int ma_shim_delay_set_dry(void* handle, float value) {
    ma_shim_delay* h = delay_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_set_dry(&h->delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_get_dry */
int ma_shim_delay_get_dry(void* handle, float* out_value) {
    ma_shim_delay* h = delay_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_get_dry(&h->delay);
    return MA_SUCCESS;
}

/* @binds ma_delay_set_decay */
int ma_shim_delay_set_decay(void* handle, float value) {
    ma_shim_delay* h = delay_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_set_decay(&h->delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_get_decay */
int ma_shim_delay_get_decay(void* handle, float* out_value) {
    ma_shim_delay* h = delay_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_get_decay(&h->delay);
    return MA_SUCCESS;
}

/* ======================================================================== */
/* ma_gainer                                                                 */
/* ======================================================================== */

typedef struct ma_shim_gainer {
    ma_gainer gainer;
    void*     heap;   /* non-NULL when the preallocated path was used */
    int       initialized;
} ma_shim_gainer;

static ma_shim_gainer* gainer_ready(void* handle) {
    ma_shim_gainer* h = (ma_shim_gainer*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static void gainer_teardown(ma_shim_gainer* h) {
    if (h->initialized) {
        ma_gainer_uninit(&h->gainer, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

void* ma_shim_gainer_alloc(void) {
    return calloc(1, sizeof(ma_shim_gainer));
}

/* @binds ma_gainer_uninit */
void ma_shim_gainer_free(void* handle) {
    ma_shim_gainer* h = (ma_shim_gainer*)handle;
    if (h == NULL) {
        return;
    }
    gainer_teardown(h);
    free(h);
}

/* @binds ma_gainer_config_init, ma_gainer_get_heap_size */
int ma_shim_gainer_get_heap_size(
    unsigned int        channels,
    unsigned int        smooth_time_in_frames,
    unsigned long long* out_heap_size
) {
    ma_gainer_config cfg;
    size_t size = 0;
    ma_result result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    cfg = ma_gainer_config_init(channels, smooth_time_in_frames);
    result = ma_gainer_get_heap_size(&cfg, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_gainer_config_init, ma_gainer_init */
int ma_shim_gainer_init(void* handle, unsigned int channels, unsigned int smooth_time_in_frames) {
    ma_shim_gainer* h = (ma_shim_gainer*)handle;
    ma_gainer_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    gainer_teardown(h);
    cfg = ma_gainer_config_init(channels, smooth_time_in_frames);
    result = ma_gainer_init(&cfg, NULL, &h->gainer);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_gainer_config_init, ma_gainer_get_heap_size, ma_gainer_init_preallocated */
int ma_shim_gainer_init_preallocated(
    void*        handle,
    unsigned int channels,
    unsigned int smooth_time_in_frames
) {
    ma_shim_gainer* h = (ma_shim_gainer*)handle;
    ma_gainer_config cfg;
    size_t heap_size = 0;
    void* heap = NULL;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    gainer_teardown(h);
    cfg = ma_gainer_config_init(channels, smooth_time_in_frames);
    result = ma_gainer_get_heap_size(&cfg, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    /* ma_gainer_init_preallocated rejects a NULL heap, so always hand it one. */
    heap = calloc(1, heap_size > 0 ? heap_size : 1);
    if (heap == NULL) {
        return MA_OUT_OF_MEMORY;
    }
    result = ma_gainer_init_preallocated(&cfg, heap, &h->gainer);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_gainer_uninit */
int ma_shim_gainer_uninit(void* handle) {
    ma_shim_gainer* h = (ma_shim_gainer*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    gainer_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_gainer_process_pcm_frames */
int ma_shim_gainer_process(void* handle, void* out, const void* in, unsigned long long frame_count) {
    ma_shim_gainer* h = gainer_ready(handle);
    if (h == NULL || out == NULL || in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_gainer_process_pcm_frames(&h->gainer, out, in, (ma_uint64)frame_count);
}

/* @binds ma_gainer_set_gain */
int ma_shim_gainer_set_gain(void* handle, float gain) {
    ma_shim_gainer* h = gainer_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_gainer_set_gain(&h->gainer, gain);
}

/* @binds ma_gainer_set_gains */
int ma_shim_gainer_set_gains(void* handle, const float* gains, unsigned int gain_count) {
    ma_shim_gainer* h = gainer_ready(handle);
    /* miniaudio reads exactly `channels` floats; require the caller to say so. */
    if (h == NULL || gains == NULL || gain_count != h->gainer.config.channels) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_gainer_set_gains(&h->gainer, (float*)gains);
}

/* @binds ma_gainer_set_master_volume */
int ma_shim_gainer_set_master_volume(void* handle, float volume) {
    ma_shim_gainer* h = gainer_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_gainer_set_master_volume(&h->gainer, volume);
}

/* @binds ma_gainer_get_master_volume */
int ma_shim_gainer_get_master_volume(void* handle, float* out_volume) {
    ma_shim_gainer* h = gainer_ready(handle);
    if (out_volume != NULL) { *out_volume = 0; }
    if (h == NULL || out_volume == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_gainer_get_master_volume(&h->gainer, out_volume);
}

/* ======================================================================== */
/* ma_panner (no heap, no uninit in miniaudio)                               */
/* ======================================================================== */

typedef struct ma_shim_panner {
    ma_panner panner;
    int       initialized;
} ma_shim_panner;

static ma_shim_panner* panner_ready(void* handle) {
    ma_shim_panner* h = (ma_shim_panner*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_panner_alloc(void) {
    return calloc(1, sizeof(ma_shim_panner));
}

void ma_shim_panner_free(void* handle) {
    free(handle);
}

/* @binds ma_panner_config_init, ma_panner_init */
int ma_shim_panner_init(void* handle, int format, unsigned int channels, int mode, float pan) {
    ma_shim_panner* h = (ma_shim_panner*)handle;
    ma_panner_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    h->initialized = 0;
    if (mode != ma_pan_mode_balance && mode != ma_pan_mode_pan) {
        return MA_INVALID_ARGS;
    }
    cfg = ma_panner_config_init((ma_format)format, channels);
    cfg.mode = (ma_pan_mode)mode;
    cfg.pan  = pan;
    result = ma_panner_init(&cfg, &h->panner);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

int ma_shim_panner_uninit(void* handle) {
    ma_shim_panner* h = (ma_shim_panner*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_panner_process_pcm_frames */
int ma_shim_panner_process(void* handle, void* out, const void* in, unsigned long long frame_count) {
    ma_shim_panner* h = panner_ready(handle);
    if (h == NULL || out == NULL || in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_panner_process_pcm_frames(&h->panner, out, in, (ma_uint64)frame_count);
}

/* @binds ma_panner_set_mode */
int ma_shim_panner_set_mode(void* handle, int mode) {
    ma_shim_panner* h = panner_ready(handle);
    if (h == NULL || (mode != ma_pan_mode_balance && mode != ma_pan_mode_pan)) {
        return MA_INVALID_ARGS;
    }
    ma_panner_set_mode(&h->panner, (ma_pan_mode)mode);
    return MA_SUCCESS;
}

/* @binds ma_panner_get_mode */
int ma_shim_panner_get_mode(void* handle, int* out_mode) {
    ma_shim_panner* h = panner_ready(handle);
    if (out_mode != NULL) { *out_mode = 0; }
    if (h == NULL || out_mode == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_mode = (int)ma_panner_get_mode(&h->panner);
    return MA_SUCCESS;
}

/* @binds ma_panner_set_pan */
int ma_shim_panner_set_pan(void* handle, float pan) {
    ma_shim_panner* h = panner_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_panner_set_pan(&h->panner, pan);
    return MA_SUCCESS;
}

/* @binds ma_panner_get_pan */
int ma_shim_panner_get_pan(void* handle, float* out_pan) {
    ma_shim_panner* h = panner_ready(handle);
    if (out_pan != NULL) { *out_pan = 0; }
    if (h == NULL || out_pan == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_pan = ma_panner_get_pan(&h->panner);
    return MA_SUCCESS;
}

/* ======================================================================== */
/* ma_fader (no heap, no uninit in miniaudio)                                */
/* ======================================================================== */

typedef struct ma_shim_fader {
    ma_fader fader;
    int      initialized;
} ma_shim_fader;

static ma_shim_fader* fader_ready(void* handle) {
    ma_shim_fader* h = (ma_shim_fader*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_fader_alloc(void) {
    return calloc(1, sizeof(ma_shim_fader));
}

void ma_shim_fader_free(void* handle) {
    free(handle);
}

/* @binds ma_fader_config_init, ma_fader_init */
int ma_shim_fader_init(void* handle, int format, unsigned int channels, unsigned int sample_rate) {
    ma_shim_fader* h = (ma_shim_fader*)handle;
    ma_fader_config cfg;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    h->initialized = 0;
    cfg = ma_fader_config_init((ma_format)format, channels, sample_rate);
    result = ma_fader_init(&cfg, &h->fader);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

int ma_shim_fader_uninit(void* handle) {
    ma_shim_fader* h = (ma_shim_fader*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_fader_process_pcm_frames */
int ma_shim_fader_process(void* handle, void* out, const void* in, unsigned long long frame_count) {
    ma_shim_fader* h = fader_ready(handle);
    if (h == NULL || out == NULL || in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_fader_process_pcm_frames(&h->fader, out, in, (ma_uint64)frame_count);
}

/* @binds ma_fader_get_data_format */
int ma_shim_fader_get_data_format(
    void*         handle,
    int*          out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    ma_shim_fader* h = fader_ready(handle);
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;

    if (h != NULL) {
        ma_fader_get_data_format(&h->fader, &format, &channels, &sample_rate);
    }
    if (out_format != NULL) { *out_format = (int)format; }
    if (out_channels != NULL) { *out_channels = (unsigned int)channels; }
    if (out_sample_rate != NULL) { *out_sample_rate = (unsigned int)sample_rate; }
    return h == NULL ? MA_INVALID_ARGS : MA_SUCCESS;
}

/* @binds ma_fader_set_fade */
int ma_shim_fader_set_fade(void* handle, float volume_beg, float volume_end, unsigned long long length_in_frames) {
    ma_shim_fader* h = fader_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_fader_set_fade(&h->fader, volume_beg, volume_end, (ma_uint64)length_in_frames);
    return MA_SUCCESS;
}

/* @binds ma_fader_set_fade_ex */
int ma_shim_fader_set_fade_ex(
    void*              handle,
    float              volume_beg,
    float              volume_end,
    unsigned long long length_in_frames,
    long long          start_offset_in_frames
) {
    ma_shim_fader* h = fader_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_fader_set_fade_ex(
        &h->fader, volume_beg, volume_end, (ma_uint64)length_in_frames, (ma_int64)start_offset_in_frames
    );
    return MA_SUCCESS;
}

/* @binds ma_fader_get_current_volume */
int ma_shim_fader_get_current_volume(void* handle, float* out_volume) {
    ma_shim_fader* h = fader_ready(handle);
    if (out_volume != NULL) { *out_volume = 0; }
    if (h == NULL || out_volume == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_volume = ma_fader_get_current_volume(&h->fader);
    return MA_SUCCESS;
}
