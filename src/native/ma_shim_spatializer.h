#ifndef MA_SHIM_SPATIALIZER_H
#define MA_SHIM_SPATIALIZER_H

/*
 * Spatializer family shim: ma_spatializer_listener and ma_spatializer.
 *
 * These are the standalone 3D-audio DSP objects the engine drives underneath
 * every sound; here they are bound in their own right. A listener describes the
 * ear (position, facing, cone, speed of sound); a spatializer describes one
 * source and, given a listener, attenuates and pans f32 frames.
 *
 * Both are opaque handles (alloc/free) with miniaudio-owned (`init`) and
 * shim-owned (`init_preallocated`) heaps. Every entry point returns an
 * ma_result code and rejects a null or never-initialised handle with
 * MA_INVALID_ARGS, including the getters, which report through out-params.
 * ma_vec3f values cross the ABI as three floats.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= ma_spatializer_listener ================= */

void* ma_shim_spatializer_listener_alloc(void);
void  ma_shim_spatializer_listener_free(void* handle);

int ma_shim_spatializer_listener_get_heap_size(
    unsigned int channels_out, unsigned long long* out_heap_size);
int ma_shim_spatializer_listener_init(void* handle, unsigned int channels_out);
int ma_shim_spatializer_listener_init_preallocated(void* handle, unsigned int channels_out);
int ma_shim_spatializer_listener_uninit(void* handle);

int ma_shim_spatializer_listener_get_channel_map(
    void* handle, unsigned char* out_map, unsigned int capacity, unsigned int* out_count);

int ma_shim_spatializer_listener_set_cone(
    void* handle, float inner_angle, float outer_angle, float outer_gain);
int ma_shim_spatializer_listener_get_cone(
    void* handle, float* out_inner, float* out_outer, float* out_gain);
int ma_shim_spatializer_listener_set_position(void* handle, float x, float y, float z);
int ma_shim_spatializer_listener_get_position(
    void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_listener_set_direction(void* handle, float x, float y, float z);
int ma_shim_spatializer_listener_get_direction(
    void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_listener_set_velocity(void* handle, float x, float y, float z);
int ma_shim_spatializer_listener_get_velocity(
    void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_listener_set_speed_of_sound(void* handle, float speed);
int ma_shim_spatializer_listener_get_speed_of_sound(void* handle, float* out_speed);
int ma_shim_spatializer_listener_set_world_up(void* handle, float x, float y, float z);
int ma_shim_spatializer_listener_get_world_up(
    void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_listener_set_enabled(void* handle, int enabled);
int ma_shim_spatializer_listener_is_enabled(void* handle, int* out_enabled);

/* ================= ma_spatializer ================= */

void* ma_shim_spatializer_alloc(void);
void  ma_shim_spatializer_free(void* handle);

int ma_shim_spatializer_get_heap_size(
    unsigned int channels_in, unsigned int channels_out, unsigned long long* out_heap_size);
int ma_shim_spatializer_init(void* handle, unsigned int channels_in, unsigned int channels_out);
int ma_shim_spatializer_init_preallocated(
    void* handle, unsigned int channels_in, unsigned int channels_out);
int ma_shim_spatializer_uninit(void* handle);

/* f32 only: miniaudio's spatializer supports no other format. */
int ma_shim_spatializer_process(
    void*              handle,
    void*              listener_handle,
    float*             frames_out,
    const float*       frames_in,
    unsigned long long frame_count
);

int ma_shim_spatializer_set_master_volume(void* handle, float volume);
int ma_shim_spatializer_get_master_volume(void* handle, float* out_volume);
int ma_shim_spatializer_get_input_channels(void* handle, unsigned int* out_channels);
int ma_shim_spatializer_get_output_channels(void* handle, unsigned int* out_channels);
int ma_shim_spatializer_set_attenuation_model(void* handle, unsigned int model);
int ma_shim_spatializer_get_attenuation_model(void* handle, unsigned int* out_model);
int ma_shim_spatializer_set_positioning(void* handle, unsigned int positioning);
int ma_shim_spatializer_get_positioning(void* handle, unsigned int* out_positioning);
int ma_shim_spatializer_set_rolloff(void* handle, float rolloff);
int ma_shim_spatializer_get_rolloff(void* handle, float* out_rolloff);
int ma_shim_spatializer_set_min_gain(void* handle, float min_gain);
int ma_shim_spatializer_get_min_gain(void* handle, float* out_min_gain);
int ma_shim_spatializer_set_max_gain(void* handle, float max_gain);
int ma_shim_spatializer_get_max_gain(void* handle, float* out_max_gain);
int ma_shim_spatializer_set_min_distance(void* handle, float min_distance);
int ma_shim_spatializer_get_min_distance(void* handle, float* out_min_distance);
int ma_shim_spatializer_set_max_distance(void* handle, float max_distance);
int ma_shim_spatializer_get_max_distance(void* handle, float* out_max_distance);
int ma_shim_spatializer_set_cone(
    void* handle, float inner_angle, float outer_angle, float outer_gain);
int ma_shim_spatializer_get_cone(
    void* handle, float* out_inner, float* out_outer, float* out_gain);
int ma_shim_spatializer_set_doppler_factor(void* handle, float factor);
int ma_shim_spatializer_get_doppler_factor(void* handle, float* out_factor);
int ma_shim_spatializer_set_directional_attenuation_factor(void* handle, float factor);
int ma_shim_spatializer_get_directional_attenuation_factor(void* handle, float* out_factor);
int ma_shim_spatializer_set_position(void* handle, float x, float y, float z);
int ma_shim_spatializer_get_position(void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_set_direction(void* handle, float x, float y, float z);
int ma_shim_spatializer_get_direction(void* handle, float* out_x, float* out_y, float* out_z);
int ma_shim_spatializer_set_velocity(void* handle, float x, float y, float z);
int ma_shim_spatializer_get_velocity(void* handle, float* out_x, float* out_y, float* out_z);

/* out_pos / out_dir each point at three floats (x, y, z). */
int ma_shim_spatializer_get_relative_position_and_direction(
    void* handle, void* listener_handle, float* out_pos, float* out_dir);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SPATIALIZER_H */
