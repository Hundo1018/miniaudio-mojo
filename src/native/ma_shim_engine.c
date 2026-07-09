#include "ma_shim_engine.h"
#include "ma_shim_internal.h"

#include "miniaudio.h"

#include <stdlib.h>

/*
 * Bookkeeping wrapper: the raw ma_engine plus an optional null-backend context
 * and an `initialized` flag (idempotent free/uninit; ops-before-init fail with
 * MA_INVALID_ARGS). The engine owns its device internally — no data callback to
 * marshal. Thin lifecycle bookkeeping, not scenario logic.
 */
typedef struct ma_shim_engine {
    ma_engine engine;
    ma_context context;
    int has_context;
    int initialized;
} ma_shim_engine;

/* Internal cross-family accessor (see ma_shim_internal.h). */
ma_engine* shimint_engine_ptr(void* engine_handle) {
    ma_shim_engine* h = (ma_shim_engine*)engine_handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return &h->engine;
}

void* ma_shim_engine_alloc(void) {
    return calloc(1, sizeof(ma_shim_engine));
}

/* @binds ma_engine_uninit */
void ma_shim_engine_free(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_engine_uninit(&h->engine);
        h->initialized = 0;
    }
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    free(h);
}

/* @binds ma_engine_init, ma_engine_config_init, ma_context_init, ma_context_config_init */
int ma_shim_engine_init(void* handle, int use_null_backend) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_engine_config config;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_engine_uninit(&h->engine);
        h->initialized = 0;
    }
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }

    config = ma_engine_config_init();
    if (use_null_backend) {
        ma_backend backends[1];
        ma_context_config context_config = ma_context_config_init();
        backends[0] = ma_backend_null;
        result = ma_context_init(backends, 1, &context_config, &h->context);
        if (result != MA_SUCCESS) {
            return (int)result;
        }
        h->has_context = 1;
        config.pContext = &h->context;
    }

    result = ma_engine_init(&config, &h->engine);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    } else if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    return (int)result;
}

/* @binds ma_engine_uninit */
int ma_shim_engine_uninit(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_engine_uninit(&h->engine);
    h->initialized = 0;
    if (h->has_context) {
        ma_context_uninit(&h->context);
        h->has_context = 0;
    }
    return MA_SUCCESS;
}

/* @binds ma_engine_start */
int ma_shim_engine_start(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_start(&h->engine);
}

/* @binds ma_engine_stop */
int ma_shim_engine_stop(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_stop(&h->engine);
}

/* @binds ma_engine_play_sound */
int ma_shim_engine_play_sound(void* handle, const char* file_path) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_play_sound(&h->engine, file_path, NULL);
}

/* @binds ma_engine_get_sample_rate */
unsigned int ma_shim_engine_get_sample_rate(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_engine_get_sample_rate(&h->engine);
}

/* @binds ma_engine_get_channels */
unsigned int ma_shim_engine_get_channels(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_engine_get_channels(&h->engine);
}

/* @binds ma_engine_set_volume */
int ma_shim_engine_set_volume(void* handle, float volume) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_set_volume(&h->engine, volume);
}

/* @binds ma_engine_get_volume */
float ma_shim_engine_get_volume(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_engine_get_volume(&h->engine);
}

/* @binds ma_engine_set_gain_db */
int ma_shim_engine_set_gain_db(void* handle, float gain_db) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_set_gain_db(&h->engine, gain_db);
}

/* @binds ma_engine_get_gain_db */
float ma_shim_engine_get_gain_db(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_engine_get_gain_db(&h->engine);
}

/* @binds ma_engine_play_sound_ex */
int ma_shim_engine_play_sound_ex(void* handle, const char* file_path) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    /* pNode == NULL attaches the sound to the engine endpoint (docs); the
     * node-graph node family is not yet modeled, so nodeInputBusIndex is 0. */
    return (int)ma_engine_play_sound_ex(&h->engine, file_path, NULL, 0);
}

/* @binds ma_engine_read_pcm_frames */
int ma_shim_engine_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_uint64 read = 0;
    ma_result result;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || !h->initialized || output == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_engine_read_pcm_frames(&h->engine, output, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_engine_get_time_in_pcm_frames */
unsigned long long ma_shim_engine_get_time_in_pcm_frames(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned long long)ma_engine_get_time_in_pcm_frames(&h->engine);
}

/* @binds ma_engine_get_time_in_milliseconds */
unsigned long long ma_shim_engine_get_time_in_milliseconds(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned long long)ma_engine_get_time_in_milliseconds(&h->engine);
}

/* @binds ma_engine_set_time_in_pcm_frames */
int ma_shim_engine_set_time_in_pcm_frames(void* handle, unsigned long long global_time) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_set_time_in_pcm_frames(&h->engine, (ma_uint64)global_time);
}

/* @binds ma_engine_set_time_in_milliseconds */
int ma_shim_engine_set_time_in_milliseconds(void* handle, unsigned long long global_time) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_engine_set_time_in_milliseconds(&h->engine, (ma_uint64)global_time);
}

/* ---- listeners ---- */

/* @binds ma_engine_get_listener_count */
unsigned int ma_shim_engine_get_listener_count(void* handle) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_engine_get_listener_count(&h->engine);
}

/* @binds ma_engine_find_closest_listener */
unsigned int ma_shim_engine_find_closest_listener(void* handle, float x, float y, float z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_engine_find_closest_listener(&h->engine, x, y, z);
}

/* @binds ma_engine_listener_set_position */
void ma_shim_engine_listener_set_position(void* handle, unsigned int index, float x, float y, float z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_position(&h->engine, index, x, y, z);
}

/* @binds ma_engine_listener_get_position */
void ma_shim_engine_listener_get_position(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_engine_listener_get_position(&h->engine, index);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_engine_listener_set_direction */
void ma_shim_engine_listener_set_direction(void* handle, unsigned int index, float x, float y, float z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_direction(&h->engine, index, x, y, z);
}

/* @binds ma_engine_listener_get_direction */
void ma_shim_engine_listener_get_direction(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_engine_listener_get_direction(&h->engine, index);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_engine_listener_set_velocity */
void ma_shim_engine_listener_set_velocity(void* handle, unsigned int index, float x, float y, float z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_velocity(&h->engine, index, x, y, z);
}

/* @binds ma_engine_listener_get_velocity */
void ma_shim_engine_listener_get_velocity(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_engine_listener_get_velocity(&h->engine, index);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_engine_listener_set_world_up */
void ma_shim_engine_listener_set_world_up(void* handle, unsigned int index, float x, float y, float z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_world_up(&h->engine, index, x, y, z);
}

/* @binds ma_engine_listener_get_world_up */
void ma_shim_engine_listener_get_world_up(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_engine_listener_get_world_up(&h->engine, index);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_engine_listener_set_cone */
void ma_shim_engine_listener_set_cone(void* handle, unsigned int index, float inner_angle, float outer_angle, float outer_gain) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_cone(&h->engine, index, inner_angle, outer_angle, outer_gain);
}

/* @binds ma_engine_listener_get_cone */
void ma_shim_engine_listener_get_cone(void* handle, unsigned int index, float* out_inner, float* out_outer, float* out_gain) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    float inner = 0.0f, outer = 0.0f, gain = 0.0f;
    if (out_inner != NULL) { *out_inner = 0.0f; }
    if (out_outer != NULL) { *out_outer = 0.0f; }
    if (out_gain != NULL) { *out_gain = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_get_cone(&h->engine, index, &inner, &outer, &gain);
    if (out_inner != NULL) { *out_inner = inner; }
    if (out_outer != NULL) { *out_outer = outer; }
    if (out_gain != NULL) { *out_gain = gain; }
}

/* @binds ma_engine_listener_set_enabled */
void ma_shim_engine_listener_set_enabled(void* handle, unsigned int index, int enabled) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_engine_listener_set_enabled(&h->engine, index, (ma_bool32)(enabled ? MA_TRUE : MA_FALSE));
}

/* @binds ma_engine_listener_is_enabled */
int ma_shim_engine_listener_is_enabled(void* handle, unsigned int index) {
    ma_shim_engine* h = (ma_shim_engine*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (int)ma_engine_listener_is_enabled(&h->engine, index);
}
