#include "ma_shim_sound_group.h"
#include "ma_shim_internal.h"

#include "miniaudio.h"

#include <stdlib.h>

/* Bookkeeping wrapper: the raw ma_sound_group plus an `initialized` flag. Owned
 * by an engine (resolved via shimint_engine_ptr); attaches to the engine
 * endpoint (parent group = NULL). */
typedef struct ma_shim_sound_group {
    ma_sound_group group;
    int initialized;
} ma_shim_sound_group;

void* ma_shim_sound_group_alloc(void) {
    return calloc(1, sizeof(ma_shim_sound_group));
}

/* @binds ma_sound_group_uninit */
void ma_shim_sound_group_free(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_sound_group_uninit(&h->group);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_sound_group_init */
int ma_shim_sound_group_init(void* handle, void* engine_handle, unsigned int flags) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_result result;

    if (h == NULL || engine == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_group_uninit(&h->group);
        h->initialized = 0;
    }
    result = ma_sound_group_init(engine, flags, NULL, &h->group);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_sound_group_uninit */
int ma_shim_sound_group_uninit(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_sound_group_uninit(&h->group);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_sound_group_start */
int ma_shim_sound_group_start(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_group_start(&h->group);
}

/* @binds ma_sound_group_stop */
int ma_shim_sound_group_stop(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_group_stop(&h->group);
}

/* @binds ma_sound_group_set_volume */
int ma_shim_sound_group_set_volume(void* handle, float volume) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_group_set_volume(&h->group, volume);
    return MA_SUCCESS;
}

/* @binds ma_sound_group_get_volume */
float ma_shim_sound_group_get_volume(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_volume(&h->group);
}

/* @binds ma_sound_group_set_pan */
int ma_shim_sound_group_set_pan(void* handle, float pan) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_group_set_pan(&h->group, pan);
    return MA_SUCCESS;
}

/* @binds ma_sound_group_get_pan */
float ma_shim_sound_group_get_pan(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_pan(&h->group);
}

/* @binds ma_sound_group_set_pitch */
int ma_shim_sound_group_set_pitch(void* handle, float pitch) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_group_set_pitch(&h->group, pitch);
    return MA_SUCCESS;
}

/* @binds ma_sound_group_get_pitch */
float ma_shim_sound_group_get_pitch(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_pitch(&h->group);
}

/* @binds ma_sound_group_set_spatialization_enabled */
int ma_shim_sound_group_set_spatialization_enabled(void* handle, int enabled) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_group_set_spatialization_enabled(&h->group, (ma_bool32)(enabled ? MA_TRUE : MA_FALSE));
    return MA_SUCCESS;
}

/* @binds ma_sound_group_is_spatialization_enabled */
int ma_shim_sound_group_is_spatialization_enabled(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_group_is_spatialization_enabled(&h->group);
}

/* @binds ma_sound_group_is_playing */
int ma_shim_sound_group_is_playing(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_group_is_playing(&h->group);
}

/* @binds ma_sound_group_get_time_in_pcm_frames */
unsigned long long ma_shim_sound_group_get_time_in_pcm_frames(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned long long)ma_sound_group_get_time_in_pcm_frames(&h->group);
}
