#include "ma_shim_sound.h"
#include "ma_shim_internal.h"

#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/*
 * Bookkeeping wrapper: the raw ma_sound plus an `initialized` flag (idempotent
 * free/uninit; ops-before-init fail with MA_INVALID_ARGS). The sound is owned by
 * an engine; the engine handle is resolved via shimint_engine_ptr.
 *
 * `refs` counts who is holding the wrapper: the owner (one reference, dropped by
 * ma_shim_sound_free) plus any borrowed data-source view. The ma_sound is torn
 * down when the owner lets go, whatever the count; the wrapper itself is freed
 * only once the last view has gone, so a view outliving its sound finds an empty
 * shell and fails cleanly instead of dangling.
 */
typedef struct ma_shim_sound {
    ma_sound sound;
    int initialized;
    int refs;
} ma_shim_sound;

/* Internal cross-family accessors (see ma_shim_internal.h). */
ma_sound* shimint_sound_ptr(void* sound_handle) {
    ma_shim_sound* h = (ma_shim_sound*)sound_handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return &h->sound;
}

void shimint_sound_retain(void* sound_handle) {
    ma_shim_sound* h = (ma_shim_sound*)sound_handle;
    if (h != NULL) {
        h->refs += 1;
    }
}

void shimint_sound_release(void* sound_handle) {
    ma_shim_sound* h = (ma_shim_sound*)sound_handle;
    if (h == NULL) {
        return;
    }
    h->refs -= 1;
    if (h->refs <= 0) {
        free(h);
    }
}

void* ma_shim_sound_alloc(void) {
    ma_shim_sound* h = (ma_shim_sound*)calloc(1, sizeof(ma_shim_sound));
    if (h != NULL) {
        h->refs = 1;
    }
    return h;
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
    shimint_sound_release(h);
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

/* ---- init from a data source / borrowed accessors ---- */

/* @binds ma_sound_init_from_data_source */
int ma_shim_sound_init_from_data_source(
    void* handle, void* engine_handle, void* data_source_handle, unsigned int flags
) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    /* The sound keeps this pointer for its whole life, so a borrowed view (which
     * owns nothing) is not acceptable here -- and neither is NULL, which would
     * quietly build the equivalent of a group rather than a sound. */
    ma_data_source* ds = shimint_data_source_ptr_owned(data_source_handle);
    ma_result result;

    if (h == NULL || engine == NULL || ds == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_uninit(&h->sound);
        h->initialized = 0;
    }
    result = ma_sound_init_from_data_source(engine, ds, flags, NULL, &h->sound);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* Returns the shim handle of the engine this sound belongs to (NULL when the
 * sound is not initialised). It is the same handle the sound was created with. */
/* @binds ma_sound_get_engine */
void* ma_shim_sound_get_engine(void* handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return shimint_engine_handle(ma_sound_get_engine(&h->sound));
}

/* ---- ma_sound_config ----
 *
 * miniaudio hands the config around by value; the shim keeps one on the heap
 * behind a handle and exposes setters. A config is only meaningful after
 * config_init / config_init_for_engine, which fill in miniaudio's defaults
 * (an all-zero ma_sound_config is NOT a valid one: the range and loop-point ends
 * default to "the whole source", not 0).
 */
typedef struct ma_shim_sound_config {
    ma_sound_config config;
    char*           file_path;     /* shim-owned copy; config.pFilePath points here */
    int             initialized;
} ma_shim_sound_config;

static ma_shim_sound_config* sound_config_ready(void* handle) {
    ma_shim_sound_config* c = (ma_shim_sound_config*)handle;
    if (c == NULL || !c->initialized) {
        return NULL;
    }
    return c;
}

static void sound_config_clear_path(ma_shim_sound_config* c) {
    free(c->file_path);
    c->file_path = NULL;
    c->config.pFilePath = NULL;
}

void* ma_shim_sound_config_alloc(void) {
    return calloc(1, sizeof(ma_shim_sound_config));
}

void ma_shim_sound_config_free(void* handle) {
    ma_shim_sound_config* c = (ma_shim_sound_config*)handle;
    if (c == NULL) {
        return;
    }
    free(c->file_path);
    free(c);
}

/* @binds ma_sound_config_init */
int ma_shim_sound_config_init(void* handle) {
    ma_shim_sound_config* c = (ma_shim_sound_config*)handle;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    sound_config_clear_path(c);
    c->config = ma_sound_config_init();
    c->initialized = 1;
    return MA_SUCCESS;
}

/* @binds ma_sound_config_init_2 */
int ma_shim_sound_config_init_for_engine(void* handle, void* engine_handle) {
    ma_shim_sound_config* c = (ma_shim_sound_config*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    if (c == NULL || engine == NULL) {
        return MA_INVALID_ARGS;
    }
    sound_config_clear_path(c);
    c->config = ma_sound_config_init_2(engine);
    c->initialized = 1;
    return MA_SUCCESS;
}

/* A NULL path clears it. The shim keeps its own copy of the text. */
int ma_shim_sound_config_set_file_path(void* handle, const char* path) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    char* copy = NULL;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (path != NULL) {
        size_t n = strlen(path) + 1;
        copy = (char*)malloc(n);
        if (copy == NULL) {
            return MA_OUT_OF_MEMORY;
        }
        memcpy(copy, path, n);
    }
    sound_config_clear_path(c);
    c->file_path = copy;
    c->config.pFilePath = copy;
    return MA_SUCCESS;
}

/* A NULL handle clears the data source. A borrowed view is refused: the sound
 * built from this config would hold the pointer past the view's lifetime. */
int ma_shim_sound_config_set_data_source(void* handle, void* data_source_handle) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    ma_data_source* ds = NULL;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (data_source_handle != NULL) {
        ds = shimint_data_source_ptr_owned(data_source_handle);
        if (ds == NULL) {
            return MA_INVALID_ARGS;
        }
    }
    c->config.pDataSource = ds;
    return MA_SUCCESS;
}

/* Attach the new sound to a sound group's input bus. NULL clears the attachment
 * (back to the engine endpoint). */
int ma_shim_sound_config_set_initial_attachment_group(
    void* handle, void* group_handle, unsigned int input_bus
) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    ma_node* node = NULL;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (group_handle != NULL) {
        node = shimint_sound_group_node(group_handle);
        if (node == NULL) {
            return MA_INVALID_ARGS;
        }
    }
    c->config.pInitialAttachment = node;
    c->config.initialAttachmentInputBusIndex = (ma_uint32)input_bus;
    return MA_SUCCESS;
}

/* Attach the new sound to any shim node's input bus. NULL clears it. */
int ma_shim_sound_config_set_initial_attachment_node(
    void* handle, void* node_handle, unsigned int input_bus
) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    ma_node* node = NULL;
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (node_handle != NULL) {
        node = shimint_node_ptr(node_handle);
        if (node == NULL) {
            return MA_INVALID_ARGS;
        }
    }
    c->config.pInitialAttachment = node;
    c->config.initialAttachmentInputBusIndex = (ma_uint32)input_bus;
    return MA_SUCCESS;
}

int ma_shim_sound_config_set_flags(void* handle, unsigned int flags) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.flags = (ma_uint32)flags;
    return MA_SUCCESS;
}

/* 0 means "the engine's channel count" for both; channels_out may also be
 * MA_SOUND_SOURCE_CHANNEL_COUNT (0xFFFFFFFF) to follow the data source. */
int ma_shim_sound_config_set_channels(void* handle, unsigned int channels_in, unsigned int channels_out) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    /* A bus wider than MA_MAX_CHANNELS would trip an assert (abort) inside miniaudio. */
    if (channels_in > MA_MAX_CHANNELS
        || (channels_out > MA_MAX_CHANNELS && channels_out != MA_SOUND_SOURCE_CHANNEL_COUNT)) {
        return MA_INVALID_ARGS;
    }
    c->config.channelsIn = (ma_uint32)channels_in;
    c->config.channelsOut = (ma_uint32)channels_out;
    return MA_SUCCESS;
}

int ma_shim_sound_config_set_volume_smooth_time(void* handle, unsigned int frames) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.volumeSmoothTimeInPCMFrames = (ma_uint32)frames;
    return MA_SUCCESS;
}

int ma_shim_sound_config_set_mono_expansion_mode(void* handle, int mode) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.monoExpansionMode = (ma_mono_expansion_mode)mode;
    return MA_SUCCESS;
}

int ma_shim_sound_config_set_initial_seek_point(void* handle, unsigned long long frame) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.initialSeekPointInPCMFrames = (ma_uint64)frame;
    return MA_SUCCESS;
}

/* The slice of the source the sound plays. end = ~0 means "to the end". */
int ma_shim_sound_config_set_range(void* handle, unsigned long long beg, unsigned long long end) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.rangeBegInPCMFrames = (ma_uint64)beg;
    c->config.rangeEndInPCMFrames = (ma_uint64)end;
    return MA_SUCCESS;
}

int ma_shim_sound_config_set_loop_point(void* handle, unsigned long long beg, unsigned long long end) {
    ma_shim_sound_config* c = sound_config_ready(handle);
    if (c == NULL) {
        return MA_INVALID_ARGS;
    }
    c->config.loopPointBegInPCMFrames = (ma_uint64)beg;
    c->config.loopPointEndInPCMFrames = (ma_uint64)end;
    return MA_SUCCESS;
}

/* @binds ma_sound_init_ex */
int ma_shim_sound_init_ex(void* handle, void* engine_handle, void* config_handle) {
    ma_shim_sound* h = (ma_shim_sound*)handle;
    ma_shim_sound_config* c = sound_config_ready(config_handle);
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_result result;

    if (h == NULL || engine == NULL || c == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_sound_uninit(&h->sound);
        h->initialized = 0;
    }
    result = ma_sound_init_ex(engine, &c->config, &h->sound);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}
