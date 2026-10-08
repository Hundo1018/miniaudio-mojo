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

/* ---- spatialization property accessors ----
 * The setters/getters return void in miniaudio; guard against null/uninit and
 * expose ma_vec3f via out-params (avoids returning a struct by value over FFI).
 */

/* @binds ma_sound_group_set_position */
void ma_shim_sound_group_set_position(void* handle, float x, float y, float z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_position(&h->group, x, y, z);
}

/* @binds ma_sound_group_get_position */
void ma_shim_sound_group_get_position(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_group_get_position(&h->group);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_group_set_direction */
void ma_shim_sound_group_set_direction(void* handle, float x, float y, float z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_direction(&h->group, x, y, z);
}

/* @binds ma_sound_group_get_direction */
void ma_shim_sound_group_get_direction(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_group_get_direction(&h->group);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_group_get_direction_to_listener */
void ma_shim_sound_group_get_direction_to_listener(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_group_get_direction_to_listener(&h->group);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_group_set_velocity */
void ma_shim_sound_group_set_velocity(void* handle, float x, float y, float z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_velocity(&h->group, x, y, z);
}

/* @binds ma_sound_group_get_velocity */
void ma_shim_sound_group_get_velocity(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_group_get_velocity(&h->group);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_group_set_attenuation_model */
void ma_shim_sound_group_set_attenuation_model(void* handle, unsigned int model) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_attenuation_model(&h->group, (ma_attenuation_model)model);
}

/* @binds ma_sound_group_get_attenuation_model */
unsigned int ma_shim_sound_group_get_attenuation_model(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_group_get_attenuation_model(&h->group);
}

/* @binds ma_sound_group_set_positioning */
void ma_shim_sound_group_set_positioning(void* handle, unsigned int positioning) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_positioning(&h->group, (ma_positioning)positioning);
}

/* @binds ma_sound_group_get_positioning */
unsigned int ma_shim_sound_group_get_positioning(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_group_get_positioning(&h->group);
}

/* @binds ma_sound_group_set_rolloff */
void ma_shim_sound_group_set_rolloff(void* handle, float rolloff) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_rolloff(&h->group, rolloff);
}

/* @binds ma_sound_group_get_rolloff */
float ma_shim_sound_group_get_rolloff(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_rolloff(&h->group);
}

/* @binds ma_sound_group_set_min_gain */
void ma_shim_sound_group_set_min_gain(void* handle, float min_gain) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_min_gain(&h->group, min_gain);
}

/* @binds ma_sound_group_get_min_gain */
float ma_shim_sound_group_get_min_gain(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_min_gain(&h->group);
}

/* @binds ma_sound_group_set_max_gain */
void ma_shim_sound_group_set_max_gain(void* handle, float max_gain) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_max_gain(&h->group, max_gain);
}

/* @binds ma_sound_group_get_max_gain */
float ma_shim_sound_group_get_max_gain(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_max_gain(&h->group);
}

/* @binds ma_sound_group_set_min_distance */
void ma_shim_sound_group_set_min_distance(void* handle, float min_distance) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_min_distance(&h->group, min_distance);
}

/* @binds ma_sound_group_get_min_distance */
float ma_shim_sound_group_get_min_distance(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_min_distance(&h->group);
}

/* @binds ma_sound_group_set_max_distance */
void ma_shim_sound_group_set_max_distance(void* handle, float max_distance) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_max_distance(&h->group, max_distance);
}

/* @binds ma_sound_group_get_max_distance */
float ma_shim_sound_group_get_max_distance(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_max_distance(&h->group);
}

/* @binds ma_sound_group_set_cone */
void ma_shim_sound_group_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_cone(&h->group, inner_angle, outer_angle, outer_gain);
}

/* @binds ma_sound_group_get_cone */
void ma_shim_sound_group_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    float inner = 0.0f, outer = 0.0f, gain = 0.0f;
    if (out_inner != NULL) { *out_inner = 0.0f; }
    if (out_outer != NULL) { *out_outer = 0.0f; }
    if (out_gain != NULL) { *out_gain = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_get_cone(&h->group, &inner, &outer, &gain);
    if (out_inner != NULL) { *out_inner = inner; }
    if (out_outer != NULL) { *out_outer = outer; }
    if (out_gain != NULL) { *out_gain = gain; }
}

/* @binds ma_sound_group_set_doppler_factor */
void ma_shim_sound_group_set_doppler_factor(void* handle, float factor) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_doppler_factor(&h->group, factor);
}

/* @binds ma_sound_group_get_doppler_factor */
float ma_shim_sound_group_get_doppler_factor(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_doppler_factor(&h->group);
}

/* @binds ma_sound_group_set_directional_attenuation_factor */
void ma_shim_sound_group_set_directional_attenuation_factor(void* handle, float factor) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_directional_attenuation_factor(&h->group, factor);
}

/* @binds ma_sound_group_get_directional_attenuation_factor */
float ma_shim_sound_group_get_directional_attenuation_factor(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_directional_attenuation_factor(&h->group);
}

/* @binds ma_sound_group_set_pan_mode */
void ma_shim_sound_group_set_pan_mode(void* handle, unsigned int pan_mode) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_pan_mode(&h->group, (ma_pan_mode)pan_mode);
}

/* @binds ma_sound_group_get_pan_mode */
unsigned int ma_shim_sound_group_get_pan_mode(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_group_get_pan_mode(&h->group);
}

/* @binds ma_sound_group_set_pinned_listener_index */
void ma_shim_sound_group_set_pinned_listener_index(void* handle, unsigned int index) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_pinned_listener_index(&h->group, (ma_uint32)index);
}

/* @binds ma_sound_group_get_pinned_listener_index */
unsigned int ma_shim_sound_group_get_pinned_listener_index(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_group_get_pinned_listener_index(&h->group);
}

/* @binds ma_sound_group_get_listener_index */
unsigned int ma_shim_sound_group_get_listener_index(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_group_get_listener_index(&h->group);
}

/* ---- fade ---- */

/* @binds ma_sound_group_set_fade_in_pcm_frames */
void ma_shim_sound_group_set_fade_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_fade_in_pcm_frames(&h->group, vol_beg, vol_end, (ma_uint64)len_frames);
}

/* @binds ma_sound_group_set_fade_in_milliseconds */
void ma_shim_sound_group_set_fade_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_fade_in_milliseconds(&h->group, vol_beg, vol_end, (ma_uint64)len_ms);
}

/* @binds ma_sound_group_get_current_fade_volume */
float ma_shim_sound_group_get_current_fade_volume(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_group_get_current_fade_volume(&h->group);
}

/* ---- start/stop time scheduling ---- */

/* @binds ma_sound_group_set_start_time_in_pcm_frames */
void ma_shim_sound_group_set_start_time_in_pcm_frames(void* handle, unsigned long long abs_time) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_start_time_in_pcm_frames(&h->group, (ma_uint64)abs_time);
}

/* @binds ma_sound_group_set_start_time_in_milliseconds */
void ma_shim_sound_group_set_start_time_in_milliseconds(void* handle, unsigned long long abs_time) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_start_time_in_milliseconds(&h->group, (ma_uint64)abs_time);
}

/* @binds ma_sound_group_set_stop_time_in_pcm_frames */
void ma_shim_sound_group_set_stop_time_in_pcm_frames(void* handle, unsigned long long abs_time) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_stop_time_in_pcm_frames(&h->group, (ma_uint64)abs_time);
}

/* @binds ma_sound_group_set_stop_time_in_milliseconds */
void ma_shim_sound_group_set_stop_time_in_milliseconds(void* handle, unsigned long long abs_time) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_group_set_stop_time_in_milliseconds(&h->group, (ma_uint64)abs_time);
}

/* ---- internal cross-family accessor ---- */

/* A group is a ma_sound whose first member is its engine node, whose first
 * member is a ma_node_base: the group's address IS its ma_node*. */
ma_node* shimint_sound_group_node(void* group_handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)group_handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return (ma_node*)&h->group;
}

/* Returns the shim handle of the engine this group belongs to (NULL when the
 * group is not initialised). It is the same handle the group was created with. */
/* @binds ma_sound_group_get_engine */
void* ma_shim_sound_group_get_engine(void* handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return shimint_engine_handle(ma_sound_group_get_engine(&h->group));
}

/* ---- ma_sound_group_config ----
 *
 * Same idea as the sound config: miniaudio passes the struct by value, so the
 * shim keeps one behind a handle with setters. A group ignores the file-path and
 * data-source fields (it is a sound without a data source), so only what a group
 * can use is settable. */
typedef struct ma_shim_sound_group_config {
    ma_sound_group_config config;
    int                   initialized;
} ma_shim_sound_group_config;

static ma_shim_sound_group_config* group_config_ready(void* handle) {
    ma_shim_sound_group_config* c = (ma_shim_sound_group_config*)handle;
    if (c == NULL || !c->initialized) {
        return NULL;
    }
    return c;
}

void* ma_shim_sound_group_config_alloc(void) {
    return calloc(1, sizeof(ma_shim_sound_group_config));
}

void ma_shim_sound_group_config_free(void* handle) {
    free(handle);
}

/* @binds ma_sound_group_config_init */
int ma_shim_sound_group_config_init(void* handle) {
    ma_shim_sound_group_config* c = (ma_shim_sound_group_config*)handle;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config = ma_sound_group_config_init();
    c->initialized = 1;
    return MA_SUCCESS;
}

/* @binds ma_sound_group_config_init_2 */
int ma_shim_sound_group_config_init_for_engine(void* handle, void* engine_handle) {
    ma_shim_sound_group_config* c = (ma_shim_sound_group_config*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    if (c == NULL || engine == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config = ma_sound_group_config_init_2(engine);
    c->initialized = 1;
    return MA_SUCCESS;
}

int ma_shim_sound_group_config_set_flags(void* handle, unsigned int flags) {
    ma_shim_sound_group_config* c = group_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.flags = (ma_uint32)flags;
    return MA_SUCCESS;
}

/* Attach the new group to a parent group's input bus. NULL clears it (back to
 * the engine endpoint). */
int ma_shim_sound_group_config_set_parent(
    void* handle, void* parent_handle, unsigned int input_bus
) {
    ma_shim_sound_group_config* c = group_config_ready(handle);
    ma_node* node = NULL;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (parent_handle != NULL) {
        node = shimint_sound_group_node(parent_handle);
        if (node == NULL) {
            return MA_INVALID_ARGS;
        }
    }
    c->config.pInitialAttachment = node;
    c->config.initialAttachmentInputBusIndex = (ma_uint32)input_bus;
    return MA_SUCCESS;
}

int ma_shim_sound_group_config_set_channels(
    void* handle, unsigned int channels_in, unsigned int channels_out
) {
    ma_shim_sound_group_config* c = group_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    /* A bus wider than MA_MAX_CHANNELS would trip an assert (abort) inside miniaudio. */
    if (channels_in > MA_MAX_CHANNELS || channels_out > MA_MAX_CHANNELS) {
        return MA_INVALID_ARGS;
    }
    c->config.channelsIn = (ma_uint32)channels_in;
    c->config.channelsOut = (ma_uint32)channels_out;
    return MA_SUCCESS;
}

int ma_shim_sound_group_config_set_volume_smooth_time(void* handle, unsigned int frames) {
    ma_shim_sound_group_config* c = group_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.volumeSmoothTimeInPCMFrames = (ma_uint32)frames;
    return MA_SUCCESS;
}

/* @binds ma_sound_group_init_ex */
int ma_shim_sound_group_init_ex(void* handle, void* engine_handle, void* config_handle) {
    ma_shim_sound_group* h = (ma_shim_sound_group*)handle;
    ma_shim_sound_group_config* c = group_config_ready(config_handle);
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_result result;

    if (h == NULL || engine == NULL || c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_group_uninit(&h->group);
        h->initialized = 0;
    }
    result = ma_sound_group_init_ex(engine, &c->config, &h->group);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}
