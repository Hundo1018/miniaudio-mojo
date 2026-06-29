#include "ma_shim_sound.h"
#include "ma_shim_internal.h"

#include "miniaudio.h"

#include <stdlib.h>

/*
 * Bookkeeping wrapper: the raw ma_sound plus an `initialized` flag (idempotent
 * free/uninit; ops-before-init fail with MA_INVALID_ARGS). The sound is owned by
 * an engine; the engine handle is resolved via shimint_engine_ptr.
 */
typedef struct ma_shim_sound {
    ma_sound sound;
    int initialized;
} ma_shim_sound;

void* ma_shim_sound_alloc(void) {
    return calloc(1, sizeof(ma_shim_sound));
}

/* @binds ma_sound_uninit */
void ma_shim_sound_free(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_sound_uninit(&h->sound);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_sound_init_from_file */
int ma_shim_sound_init_from_file(
    void* handle, void* engine_handle, const char* file_path, unsigned int flags
) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_result result;

    if (h == NULL || engine == NULL || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_uninit(&h->sound);
        h->initialized = 0;
    }
    result = ma_sound_init_from_file(engine, file_path, flags, NULL, NULL, &h->sound);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_sound_uninit */
int ma_shim_sound_uninit(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_sound_uninit(&h->sound);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_sound_start */
int ma_shim_sound_start(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_start(&h->sound);
}

/* @binds ma_sound_stop */
int ma_shim_sound_stop(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_stop(&h->sound);
}

/* @binds ma_sound_set_volume */
int ma_shim_sound_set_volume(void* handle, float volume) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_set_volume(&h->sound, volume);
    return MA_SUCCESS;
}

/* @binds ma_sound_get_volume */
float ma_shim_sound_get_volume(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_volume(&h->sound);
}

/* @binds ma_sound_set_pan */
int ma_shim_sound_set_pan(void* handle, float pan) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_set_pan(&h->sound, pan);
    return MA_SUCCESS;
}

/* @binds ma_sound_get_pan */
float ma_shim_sound_get_pan(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_pan(&h->sound);
}

/* @binds ma_sound_set_pitch */
int ma_shim_sound_set_pitch(void* handle, float pitch) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_set_pitch(&h->sound, pitch);
    return MA_SUCCESS;
}

/* @binds ma_sound_get_pitch */
float ma_shim_sound_get_pitch(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_pitch(&h->sound);
}

/* @binds ma_sound_set_looping */
int ma_shim_sound_set_looping(void* handle, int looping) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_set_looping(&h->sound, (ma_bool32)(looping ? MA_TRUE : MA_FALSE));
    return MA_SUCCESS;
}

/* @binds ma_sound_is_looping */
int ma_shim_sound_is_looping(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_is_looping(&h->sound);
}

/* @binds ma_sound_is_playing */
int ma_shim_sound_is_playing(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_is_playing(&h->sound);
}

/* @binds ma_sound_at_end */
int ma_shim_sound_at_end(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_at_end(&h->sound);
}

/* @binds ma_sound_set_spatialization_enabled */
int ma_shim_sound_set_spatialization_enabled(void* handle, int enabled) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    ma_sound_set_spatialization_enabled(&h->sound, (ma_bool32)(enabled ? MA_TRUE : MA_FALSE));
    return MA_SUCCESS;
}

/* @binds ma_sound_is_spatialization_enabled */
int ma_shim_sound_is_spatialization_enabled(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_sound_is_spatialization_enabled(&h->sound);
}

/* @binds ma_sound_seek_to_pcm_frame */
int ma_shim_sound_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_seek_to_pcm_frame(&h->sound, (ma_uint64)frame_index);
}

/* @binds ma_sound_get_cursor_in_pcm_frames */
int ma_shim_sound_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_uint64 cursor = 0;
    ma_result result;
    if (out_cursor != NULL) {
        *out_cursor = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_sound_get_cursor_in_pcm_frames(&h->sound, &cursor);
    if (result == MA_SUCCESS && out_cursor != NULL) {
        *out_cursor = (unsigned long long)cursor;
    }
    return (int)result;
}

/* @binds ma_sound_get_length_in_pcm_frames */
int ma_shim_sound_get_length_in_pcm_frames(void* handle, unsigned long long* out_length) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_uint64 length = 0;
    ma_result result;
    if (out_length != NULL) {
        *out_length = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_sound_get_length_in_pcm_frames(&h->sound, &length);
    if (result == MA_SUCCESS && out_length != NULL) {
        *out_length = (unsigned long long)length;
    }
    return (int)result;
}
