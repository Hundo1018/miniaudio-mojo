#include "ma_shim_spatializer.h"
#include "miniaudio.h"

#include <stdlib.h>

/* ================= ma_spatializer_listener ================= */

typedef struct ma_shim_spatializer_listener_handle {
    ma_spatializer_listener listener;
    void*                   heap;        /* non-NULL when the preallocated path was used */
    unsigned int            channels_out;
    int                     initialized;
} ma_shim_spatializer_listener_handle;

static void listener_teardown(ma_shim_spatializer_listener_handle* h) {
    if (h->initialized) {
        ma_spatializer_listener_uninit(&h->listener, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_spatializer_listener* listener_ready(void* handle) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return &h->listener;
}

void* ma_shim_spatializer_listener_alloc(void) {
    return calloc(1, sizeof(ma_shim_spatializer_listener_handle));
}

/* @binds ma_spatializer_listener_uninit */
void ma_shim_spatializer_listener_free(void* handle) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    if (h == NULL) {
        return;
    }
    listener_teardown(h);
    free(h);
}

/* @binds ma_spatializer_listener_config_init, ma_spatializer_listener_get_heap_size */
int ma_shim_spatializer_listener_get_heap_size(
    unsigned int channels_out, unsigned long long* out_heap_size
) {
    ma_spatializer_listener_config config;
    size_t                         size = 0;
    ma_result                      result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_spatializer_listener_config_init((ma_uint32)channels_out);
    result = ma_spatializer_listener_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_spatializer_listener_config_init, ma_spatializer_listener_init */
int ma_shim_spatializer_listener_init(void* handle, unsigned int channels_out) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    ma_spatializer_listener_config       config;
    ma_result                            result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    listener_teardown(h);

    config = ma_spatializer_listener_config_init((ma_uint32)channels_out);
    result = ma_spatializer_listener_init(&config, NULL, &h->listener);
    if (result == MA_SUCCESS) {
        h->channels_out = channels_out;
        h->initialized  = 1;
    }
    return (int)result;
}

/* @binds ma_spatializer_listener_config_init, ma_spatializer_listener_get_heap_size, ma_spatializer_listener_init_preallocated */
int ma_shim_spatializer_listener_init_preallocated(void* handle, unsigned int channels_out) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    ma_spatializer_listener_config       config;
    size_t                               heap_size = 0;
    void*                                heap = NULL;
    ma_result                            result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    listener_teardown(h);

    config = ma_spatializer_listener_config_init((ma_uint32)channels_out);
    result = ma_spatializer_listener_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_spatializer_listener_init_preallocated(&config, heap, &h->listener);
    if (result == MA_SUCCESS) {
        h->heap         = heap;
        h->channels_out = channels_out;
        h->initialized  = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_spatializer_listener_uninit */
int ma_shim_spatializer_listener_uninit(void* handle) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    listener_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_channel_map */
int ma_shim_spatializer_listener_get_channel_map(
    void* handle, unsigned char* out_map, unsigned int capacity, unsigned int* out_count
) {
    ma_shim_spatializer_listener_handle* h = (ma_shim_spatializer_listener_handle*)handle;
    const ma_channel*                    map;
    unsigned int                         i;

    if (listener_ready(handle) == NULL || out_map == NULL || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    if (capacity < h->channels_out) {
        return MA_INVALID_ARGS;
    }
    map = ma_spatializer_listener_get_channel_map(&h->listener);
    if (map == NULL) {
        return MA_ERROR;
    }
    for (i = 0; i < h->channels_out; ++i) {
        out_map[i] = (unsigned char)map[i];
    }
    *out_count = h->channels_out;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_cone */
int ma_shim_spatializer_listener_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_cone(p, inner_angle, outer_angle, outer_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_cone */
int ma_shim_spatializer_listener_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL || out_inner == NULL || out_outer == NULL || out_gain == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_get_cone(p, out_inner, out_outer, out_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_position */
int ma_shim_spatializer_listener_set_position(void* handle, float x, float y, float z) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_position(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_position */
int ma_shim_spatializer_listener_get_position(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer_listener* p = listener_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_listener_get_position(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_direction */
int ma_shim_spatializer_listener_set_direction(void* handle, float x, float y, float z) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_direction(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_direction */
int ma_shim_spatializer_listener_get_direction(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer_listener* p = listener_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_listener_get_direction(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_velocity */
int ma_shim_spatializer_listener_set_velocity(void* handle, float x, float y, float z) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_velocity(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_velocity */
int ma_shim_spatializer_listener_get_velocity(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer_listener* p = listener_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_listener_get_velocity(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_speed_of_sound */
int ma_shim_spatializer_listener_set_speed_of_sound(void* handle, float speed) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_speed_of_sound(p, speed);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_speed_of_sound */
int ma_shim_spatializer_listener_get_speed_of_sound(void* handle, float* out_speed) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL || out_speed == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_speed = ma_spatializer_listener_get_speed_of_sound(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_world_up */
int ma_shim_spatializer_listener_set_world_up(void* handle, float x, float y, float z) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_world_up(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_get_world_up */
int ma_shim_spatializer_listener_get_world_up(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer_listener* p = listener_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_listener_get_world_up(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_set_enabled */
int ma_shim_spatializer_listener_set_enabled(void* handle, int enabled) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_listener_set_enabled(p, enabled ? MA_TRUE : MA_FALSE);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_listener_is_enabled */
int ma_shim_spatializer_listener_is_enabled(void* handle, int* out_enabled) {
    ma_spatializer_listener* p = listener_ready(handle);
    if (p == NULL || out_enabled == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_enabled = ma_spatializer_listener_is_enabled(p) ? 1 : 0;
    return MA_SUCCESS;
}

/* ================= ma_spatializer ================= */

typedef struct ma_shim_spatializer_handle {
    ma_spatializer spatializer;
    void*          heap;
    int            initialized;
} ma_shim_spatializer_handle;

static void spatializer_teardown(ma_shim_spatializer_handle* h) {
    if (h->initialized) {
        ma_spatializer_uninit(&h->spatializer, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_spatializer* spatializer_ready(void* handle) {
    ma_shim_spatializer_handle* h = (ma_shim_spatializer_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return &h->spatializer;
}

void* ma_shim_spatializer_alloc(void) {
    return calloc(1, sizeof(ma_shim_spatializer_handle));
}

/* @binds ma_spatializer_uninit */
void ma_shim_spatializer_free(void* handle) {
    ma_shim_spatializer_handle* h = (ma_shim_spatializer_handle*)handle;
    if (h == NULL) {
        return;
    }
    spatializer_teardown(h);
    free(h);
}

/* @binds ma_spatializer_config_init, ma_spatializer_get_heap_size */
int ma_shim_spatializer_get_heap_size(
    unsigned int channels_in, unsigned int channels_out, unsigned long long* out_heap_size
) {
    ma_spatializer_config config;
    size_t                size = 0;
    ma_result             result;

    if (out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_spatializer_config_init((ma_uint32)channels_in, (ma_uint32)channels_out);
    result = ma_spatializer_get_heap_size(&config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_spatializer_config_init, ma_spatializer_init */
int ma_shim_spatializer_init(void* handle, unsigned int channels_in, unsigned int channels_out) {
    ma_shim_spatializer_handle* h = (ma_shim_spatializer_handle*)handle;
    ma_spatializer_config       config;
    ma_result                   result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    spatializer_teardown(h);

    config = ma_spatializer_config_init((ma_uint32)channels_in, (ma_uint32)channels_out);
    result = ma_spatializer_init(&config, NULL, &h->spatializer);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_spatializer_config_init, ma_spatializer_get_heap_size, ma_spatializer_init_preallocated */
int ma_shim_spatializer_init_preallocated(
    void* handle, unsigned int channels_in, unsigned int channels_out
) {
    ma_shim_spatializer_handle* h = (ma_shim_spatializer_handle*)handle;
    ma_spatializer_config       config;
    size_t                      heap_size = 0;
    void*                       heap = NULL;
    ma_result                   result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    spatializer_teardown(h);

    config = ma_spatializer_config_init((ma_uint32)channels_in, (ma_uint32)channels_out);
    result = ma_spatializer_get_heap_size(&config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_spatializer_init_preallocated(&config, heap, &h->spatializer);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_spatializer_uninit */
int ma_shim_spatializer_uninit(void* handle) {
    ma_shim_spatializer_handle* h = (ma_shim_spatializer_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    spatializer_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_process_pcm_frames */
int ma_shim_spatializer_process(
    void*              handle,
    void*              listener_handle,
    float*             frames_out,
    const float*       frames_in,
    unsigned long long frame_count
) {
    ma_spatializer*          s = spatializer_ready(handle);
    ma_spatializer_listener* l = listener_ready(listener_handle);
    if (s == NULL || l == NULL || frames_out == NULL || frames_in == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_spatializer_process_pcm_frames(s, l, frames_out, frames_in, (ma_uint64)frame_count);
}

/* @binds ma_spatializer_set_master_volume */
int ma_shim_spatializer_set_master_volume(void* handle, float volume) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_spatializer_set_master_volume(p, volume);
}

/* @binds ma_spatializer_get_master_volume */
int ma_shim_spatializer_get_master_volume(void* handle, float* out_volume) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_volume == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_spatializer_get_master_volume(p, out_volume);
}

/* @binds ma_spatializer_get_input_channels */
int ma_shim_spatializer_get_input_channels(void* handle, unsigned int* out_channels) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_channels == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_channels = (unsigned int)ma_spatializer_get_input_channels(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_output_channels */
int ma_shim_spatializer_get_output_channels(void* handle, unsigned int* out_channels) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_channels == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_channels = (unsigned int)ma_spatializer_get_output_channels(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_attenuation_model */
int ma_shim_spatializer_set_attenuation_model(void* handle, unsigned int attenuation_model) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_attenuation_model(p, (ma_attenuation_model)attenuation_model);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_attenuation_model */
int ma_shim_spatializer_get_attenuation_model(void* handle, unsigned int* out_attenuation_model) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_attenuation_model == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_attenuation_model = (unsigned int)ma_spatializer_get_attenuation_model(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_positioning */
int ma_shim_spatializer_set_positioning(void* handle, unsigned int positioning) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_positioning(p, (ma_positioning)positioning);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_positioning */
int ma_shim_spatializer_get_positioning(void* handle, unsigned int* out_positioning) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_positioning == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_positioning = (unsigned int)ma_spatializer_get_positioning(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_rolloff */
int ma_shim_spatializer_set_rolloff(void* handle, float rolloff) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_rolloff(p, rolloff);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_rolloff */
int ma_shim_spatializer_get_rolloff(void* handle, float* out_rolloff) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_rolloff == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_rolloff = ma_spatializer_get_rolloff(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_min_gain */
int ma_shim_spatializer_set_min_gain(void* handle, float min_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_min_gain(p, min_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_min_gain */
int ma_shim_spatializer_get_min_gain(void* handle, float* out_min_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_min_gain == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_min_gain = ma_spatializer_get_min_gain(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_max_gain */
int ma_shim_spatializer_set_max_gain(void* handle, float max_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_max_gain(p, max_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_max_gain */
int ma_shim_spatializer_get_max_gain(void* handle, float* out_max_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_max_gain == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_max_gain = ma_spatializer_get_max_gain(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_min_distance */
int ma_shim_spatializer_set_min_distance(void* handle, float min_distance) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_min_distance(p, min_distance);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_min_distance */
int ma_shim_spatializer_get_min_distance(void* handle, float* out_min_distance) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_min_distance == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_min_distance = ma_spatializer_get_min_distance(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_max_distance */
int ma_shim_spatializer_set_max_distance(void* handle, float max_distance) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_max_distance(p, max_distance);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_max_distance */
int ma_shim_spatializer_get_max_distance(void* handle, float* out_max_distance) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_max_distance == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_max_distance = ma_spatializer_get_max_distance(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_cone */
int ma_shim_spatializer_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_cone(p, inner_angle, outer_angle, outer_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_cone */
int ma_shim_spatializer_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_inner == NULL || out_outer == NULL || out_gain == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_get_cone(p, out_inner, out_outer, out_gain);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_doppler_factor */
int ma_shim_spatializer_set_doppler_factor(void* handle, float factor) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_doppler_factor(p, factor);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_doppler_factor */
int ma_shim_spatializer_get_doppler_factor(void* handle, float* out_factor) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_factor == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_factor = ma_spatializer_get_doppler_factor(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_directional_attenuation_factor */
int ma_shim_spatializer_set_directional_attenuation_factor(void* handle, float factor) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_directional_attenuation_factor(p, factor);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_directional_attenuation_factor */
int ma_shim_spatializer_get_directional_attenuation_factor(void* handle, float* out_factor) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL || out_factor == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_factor = ma_spatializer_get_directional_attenuation_factor(p);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_position */
int ma_shim_spatializer_set_position(void* handle, float x, float y, float z) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_position(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_position */
int ma_shim_spatializer_get_position(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer* p = spatializer_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_get_position(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_direction */
int ma_shim_spatializer_set_direction(void* handle, float x, float y, float z) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_direction(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_direction */
int ma_shim_spatializer_get_direction(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer* p = spatializer_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_get_direction(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_set_velocity */
int ma_shim_spatializer_set_velocity(void* handle, float x, float y, float z) {
    ma_spatializer* p = spatializer_ready(handle);
    if (p == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_set_velocity(p, x, y, z);
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_velocity */
int ma_shim_spatializer_get_velocity(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_spatializer* p = spatializer_ready(handle);
    ma_vec3f v;
    if (p == NULL || out_x == NULL || out_y == NULL || out_z == NULL) {
        return MA_INVALID_ARGS;
    }
    v = ma_spatializer_get_velocity(p);
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_spatializer_get_relative_position_and_direction */
int ma_shim_spatializer_get_relative_position_and_direction(
    void* handle, void* listener_handle, float* out_pos, float* out_dir
) {
    ma_spatializer*          s = spatializer_ready(handle);
    ma_spatializer_listener* l = listener_ready(listener_handle);
    ma_vec3f                 pos;
    ma_vec3f                 dir;

    if (s == NULL || l == NULL || out_pos == NULL || out_dir == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_spatializer_get_relative_position_and_direction(s, l, &pos, &dir);
    out_pos[0] = pos.x;
    out_pos[1] = pos.y;
    out_pos[2] = pos.z;
    out_dir[0] = dir.x;
    out_dir[1] = dir.y;
    out_dir[2] = dir.z;
    return MA_SUCCESS;
}
