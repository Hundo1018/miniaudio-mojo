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

/* @binds ma_sound_seek_to_second */
int ma_shim_sound_seek_to_second(void* handle, float seek_point) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_seek_to_second(&h->sound, seek_point);
}

/* @binds ma_sound_get_cursor_in_seconds */
int ma_shim_sound_get_cursor_in_seconds(void* handle, float* out_cursor) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    float cursor = 0.0f;
    ma_result result;
    if (out_cursor != NULL) {
        *out_cursor = 0.0f;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_sound_get_cursor_in_seconds(&h->sound, &cursor);
    if (result == MA_SUCCESS && out_cursor != NULL) {
        *out_cursor = cursor;
    }
    return (int)result;
}

/* @binds ma_sound_get_length_in_seconds */
int ma_shim_sound_get_length_in_seconds(void* handle, float* out_length) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    float length = 0.0f;
    ma_result result;
    if (out_length != NULL) {
        *out_length = 0.0f;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_sound_get_length_in_seconds(&h->sound, &length);
    if (result == MA_SUCCESS && out_length != NULL) {
        *out_length = length;
    }
    return (int)result;
}

/* @binds ma_sound_get_data_format */
int ma_shim_sound_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    ma_result result;
    if (out_format != NULL) {
        *out_format = 0;
    }
    if (out_channels != NULL) {
        *out_channels = 0;
    }
    if (out_sample_rate != NULL) {
        *out_sample_rate = 0;
    }
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    result = ma_sound_get_data_format(
        &h->sound, &format, &channels, &sample_rate, NULL, 0);
    if (result == MA_SUCCESS) {
        if (out_format != NULL) {
            *out_format = (int)format;
        }
        if (out_channels != NULL) {
            *out_channels = (unsigned int)channels;
        }
        if (out_sample_rate != NULL) {
            *out_sample_rate = (unsigned int)sample_rate;
        }
    }
    return (int)result;
}

/* ---- spatialization property accessors ----
 * The setters/getters return void in miniaudio; guard against null/uninit and
 * expose ma_vec3f via out-params (avoids returning a struct by value over FFI).
 */

/* @binds ma_sound_set_position */
void ma_shim_sound_set_position(void* handle, float x, float y, float z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_position(&h->sound, x, y, z);
}

/* @binds ma_sound_get_position */
void ma_shim_sound_get_position(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_get_position(&h->sound);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_set_direction */
void ma_shim_sound_set_direction(void* handle, float x, float y, float z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_direction(&h->sound, x, y, z);
}

/* @binds ma_sound_get_direction */
void ma_shim_sound_get_direction(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_get_direction(&h->sound);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_get_direction_to_listener */
void ma_shim_sound_get_direction_to_listener(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_get_direction_to_listener(&h->sound);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_set_velocity */
void ma_shim_sound_set_velocity(void* handle, float x, float y, float z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_velocity(&h->sound, x, y, z);
}

/* @binds ma_sound_get_velocity */
void ma_shim_sound_get_velocity(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_vec3f v;
    if (out_x != NULL) { *out_x = 0.0f; }
    if (out_y != NULL) { *out_y = 0.0f; }
    if (out_z != NULL) { *out_z = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    v = ma_sound_get_velocity(&h->sound);
    if (out_x != NULL) { *out_x = v.x; }
    if (out_y != NULL) { *out_y = v.y; }
    if (out_z != NULL) { *out_z = v.z; }
}

/* @binds ma_sound_set_attenuation_model */
void ma_shim_sound_set_attenuation_model(void* handle, unsigned int model) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_attenuation_model(&h->sound, (ma_attenuation_model)model);
}

/* @binds ma_sound_get_attenuation_model */
unsigned int ma_shim_sound_get_attenuation_model(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_get_attenuation_model(&h->sound);
}

/* @binds ma_sound_set_positioning */
void ma_shim_sound_set_positioning(void* handle, unsigned int positioning) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_positioning(&h->sound, (ma_positioning)positioning);
}

/* @binds ma_sound_get_positioning */
unsigned int ma_shim_sound_get_positioning(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_get_positioning(&h->sound);
}

/* @binds ma_sound_set_rolloff */
void ma_shim_sound_set_rolloff(void* handle, float rolloff) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_rolloff(&h->sound, rolloff);
}

/* @binds ma_sound_get_rolloff */
float ma_shim_sound_get_rolloff(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_rolloff(&h->sound);
}

/* @binds ma_sound_set_min_gain */
void ma_shim_sound_set_min_gain(void* handle, float min_gain) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_min_gain(&h->sound, min_gain);
}

/* @binds ma_sound_get_min_gain */
float ma_shim_sound_get_min_gain(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_min_gain(&h->sound);
}

/* @binds ma_sound_set_max_gain */
void ma_shim_sound_set_max_gain(void* handle, float max_gain) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_max_gain(&h->sound, max_gain);
}

/* @binds ma_sound_get_max_gain */
float ma_shim_sound_get_max_gain(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_max_gain(&h->sound);
}

/* @binds ma_sound_set_min_distance */
void ma_shim_sound_set_min_distance(void* handle, float min_distance) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_min_distance(&h->sound, min_distance);
}

/* @binds ma_sound_get_min_distance */
float ma_shim_sound_get_min_distance(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_min_distance(&h->sound);
}

/* @binds ma_sound_set_max_distance */
void ma_shim_sound_set_max_distance(void* handle, float max_distance) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_max_distance(&h->sound, max_distance);
}

/* @binds ma_sound_get_max_distance */
float ma_shim_sound_get_max_distance(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_max_distance(&h->sound);
}

/* @binds ma_sound_set_cone */
void ma_shim_sound_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_cone(&h->sound, inner_angle, outer_angle, outer_gain);
}

/* @binds ma_sound_get_cone */
void ma_shim_sound_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    float inner = 0.0f, outer = 0.0f, gain = 0.0f;
    if (out_inner != NULL) { *out_inner = 0.0f; }
    if (out_outer != NULL) { *out_outer = 0.0f; }
    if (out_gain != NULL) { *out_gain = 0.0f; }
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_get_cone(&h->sound, &inner, &outer, &gain);
    if (out_inner != NULL) { *out_inner = inner; }
    if (out_outer != NULL) { *out_outer = outer; }
    if (out_gain != NULL) { *out_gain = gain; }
}

/* @binds ma_sound_set_doppler_factor */
void ma_shim_sound_set_doppler_factor(void* handle, float factor) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_doppler_factor(&h->sound, factor);
}

/* @binds ma_sound_get_doppler_factor */
float ma_shim_sound_get_doppler_factor(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_doppler_factor(&h->sound);
}

/* @binds ma_sound_set_directional_attenuation_factor */
void ma_shim_sound_set_directional_attenuation_factor(void* handle, float factor) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_directional_attenuation_factor(&h->sound, factor);
}

/* @binds ma_sound_get_directional_attenuation_factor */
float ma_shim_sound_get_directional_attenuation_factor(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_directional_attenuation_factor(&h->sound);
}

/* @binds ma_sound_set_pan_mode */
void ma_shim_sound_set_pan_mode(void* handle, unsigned int pan_mode) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_pan_mode(&h->sound, (ma_pan_mode)pan_mode);
}

/* @binds ma_sound_get_pan_mode */
unsigned int ma_shim_sound_get_pan_mode(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_get_pan_mode(&h->sound);
}

/* @binds ma_sound_set_pinned_listener_index */
void ma_shim_sound_set_pinned_listener_index(void* handle, unsigned int index) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_pinned_listener_index(&h->sound, (ma_uint32)index);
}

/* @binds ma_sound_get_pinned_listener_index */
unsigned int ma_shim_sound_get_pinned_listener_index(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_get_pinned_listener_index(&h->sound);
}

/* @binds ma_sound_get_listener_index */
unsigned int ma_shim_sound_get_listener_index(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned int)ma_sound_get_listener_index(&h->sound);
}

/* ---- fade ---- */

/* @binds ma_sound_set_fade_in_pcm_frames */
void ma_shim_sound_set_fade_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_fade_in_pcm_frames(&h->sound, vol_beg, vol_end, (ma_uint64)len_frames);
}

/* @binds ma_sound_set_fade_in_milliseconds */
void ma_shim_sound_set_fade_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_fade_in_milliseconds(&h->sound, vol_beg, vol_end, (ma_uint64)len_ms);
}

/* @binds ma_sound_set_fade_start_in_pcm_frames */
void ma_shim_sound_set_fade_start_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames, unsigned long long abs_time_frames) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_fade_start_in_pcm_frames(&h->sound, vol_beg, vol_end, (ma_uint64)len_frames, (ma_uint64)abs_time_frames);
}

/* @binds ma_sound_set_fade_start_in_milliseconds */
void ma_shim_sound_set_fade_start_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms, unsigned long long abs_time_ms) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_fade_start_in_milliseconds(&h->sound, vol_beg, vol_end, (ma_uint64)len_ms, (ma_uint64)abs_time_ms);
}

/* @binds ma_sound_get_current_fade_volume */
float ma_shim_sound_get_current_fade_volume(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0.0f;
    }
    return ma_sound_get_current_fade_volume(&h->sound);
}

/* @binds ma_sound_reset_fade */
void ma_shim_sound_reset_fade(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_reset_fade(&h->sound);
}

/* ---- start/stop time scheduling ---- */

/* @binds ma_sound_set_start_time_in_pcm_frames */
void ma_shim_sound_set_start_time_in_pcm_frames(void* handle, unsigned long long abs_time) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_start_time_in_pcm_frames(&h->sound, (ma_uint64)abs_time);
}

/* @binds ma_sound_set_start_time_in_milliseconds */
void ma_shim_sound_set_start_time_in_milliseconds(void* handle, unsigned long long abs_time) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_start_time_in_milliseconds(&h->sound, (ma_uint64)abs_time);
}

/* @binds ma_sound_set_stop_time_in_pcm_frames */
void ma_shim_sound_set_stop_time_in_pcm_frames(void* handle, unsigned long long abs_time) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_stop_time_in_pcm_frames(&h->sound, (ma_uint64)abs_time);
}

/* @binds ma_sound_set_stop_time_in_milliseconds */
void ma_shim_sound_set_stop_time_in_milliseconds(void* handle, unsigned long long abs_time) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_stop_time_in_milliseconds(&h->sound, (ma_uint64)abs_time);
}

/* @binds ma_sound_set_stop_time_with_fade_in_pcm_frames */
void ma_shim_sound_set_stop_time_with_fade_in_pcm_frames(void* handle, unsigned long long stop_time, unsigned long long fade_len) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_stop_time_with_fade_in_pcm_frames(&h->sound, (ma_uint64)stop_time, (ma_uint64)fade_len);
}

/* @binds ma_sound_set_stop_time_with_fade_in_milliseconds */
void ma_shim_sound_set_stop_time_with_fade_in_milliseconds(void* handle, unsigned long long stop_time, unsigned long long fade_len) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_set_stop_time_with_fade_in_milliseconds(&h->sound, (ma_uint64)stop_time, (ma_uint64)fade_len);
}

/* @binds ma_sound_stop_with_fade_in_pcm_frames */
int ma_shim_sound_stop_with_fade_in_pcm_frames(void* handle, unsigned long long fade_len) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_stop_with_fade_in_pcm_frames(&h->sound, (ma_uint64)fade_len);
}

/* @binds ma_sound_stop_with_fade_in_milliseconds */
int ma_shim_sound_stop_with_fade_in_milliseconds(void* handle, unsigned long long fade_len) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_sound_stop_with_fade_in_milliseconds(&h->sound, (ma_uint64)fade_len);
}

/* @binds ma_sound_reset_start_time */
void ma_shim_sound_reset_start_time(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_reset_start_time(&h->sound);
}

/* @binds ma_sound_reset_stop_time */
void ma_shim_sound_reset_stop_time(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_reset_stop_time(&h->sound);
}

/* @binds ma_sound_reset_stop_time_and_fade */
void ma_shim_sound_reset_stop_time_and_fade(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return;
    }
    ma_sound_reset_stop_time_and_fade(&h->sound);
}

/* @binds ma_sound_get_time_in_pcm_frames */
unsigned long long ma_shim_sound_get_time_in_pcm_frames(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned long long)ma_sound_get_time_in_pcm_frames(&h->sound);
}

/* @binds ma_sound_get_time_in_milliseconds */
unsigned long long ma_shim_sound_get_time_in_milliseconds(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (unsigned long long)ma_sound_get_time_in_milliseconds(&h->sound);
}

/* @binds ma_sound_init_copy */
int ma_shim_sound_init_copy(void* handle, void* engine_handle, void* existing_handle, unsigned int flags) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_shim_sound* existing = (ma_shim_sound*)existing_handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_result result;

    if (h == NULL || engine == NULL || existing == NULL || !existing->initialized) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_uninit(&h->sound);
        h->initialized = 0;
    }
    result = ma_sound_init_copy(engine, &existing->sound, flags, NULL, &h->sound);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}
