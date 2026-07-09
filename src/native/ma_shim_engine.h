#ifndef MA_SHIM_ENGINE_H
#define MA_SHIM_ENGINE_H

/* ---- engine (opaque handle; high-level playback) ----
 *
 * The engine owns its own device internally. `use_null_backend` selects
 * miniaudio's null backend (no hardware) for deterministic tests; 0 uses the
 * default backend (real audio output). Per the per-family shim convention, the
 * declarations live here and the definitions in ma_shim_engine.c.
 */

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_engine_alloc(void);
void  ma_shim_engine_free(void* handle);

int   ma_shim_engine_init(void* handle, int use_null_backend);
int   ma_shim_engine_uninit(void* handle);
int   ma_shim_engine_start(void* handle);
int   ma_shim_engine_stop(void* handle);

int   ma_shim_engine_play_sound(void* handle, const char* file_path);
int   ma_shim_engine_play_sound_ex(void* handle, const char* file_path);

unsigned int       ma_shim_engine_get_sample_rate(void* handle);
unsigned int       ma_shim_engine_get_channels(void* handle);
int                ma_shim_engine_set_volume(void* handle, float volume);
float              ma_shim_engine_get_volume(void* handle);
int                ma_shim_engine_set_gain_db(void* handle, float gain_db);
float              ma_shim_engine_get_gain_db(void* handle);

int   ma_shim_engine_read_pcm_frames(
    void* handle, void* output,
    unsigned long long frame_count, unsigned long long* frames_read_out);

/* ---- global clock ---- */
unsigned long long ma_shim_engine_get_time_in_pcm_frames(void* handle);
unsigned long long ma_shim_engine_get_time_in_milliseconds(void* handle);
int                ma_shim_engine_set_time_in_pcm_frames(void* handle, unsigned long long global_time);
int                ma_shim_engine_set_time_in_milliseconds(void* handle, unsigned long long global_time);

/* ---- listeners (index-based spatialization) ---- */
unsigned int ma_shim_engine_get_listener_count(void* handle);
unsigned int ma_shim_engine_find_closest_listener(void* handle, float x, float y, float z);

void ma_shim_engine_listener_set_position(void* handle, unsigned int index, float x, float y, float z);
void ma_shim_engine_listener_get_position(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z);
void ma_shim_engine_listener_set_direction(void* handle, unsigned int index, float x, float y, float z);
void ma_shim_engine_listener_get_direction(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z);
void ma_shim_engine_listener_set_velocity(void* handle, unsigned int index, float x, float y, float z);
void ma_shim_engine_listener_get_velocity(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z);
void ma_shim_engine_listener_set_world_up(void* handle, unsigned int index, float x, float y, float z);
void ma_shim_engine_listener_get_world_up(void* handle, unsigned int index, float* out_x, float* out_y, float* out_z);

void ma_shim_engine_listener_set_cone(void* handle, unsigned int index, float inner_angle, float outer_angle, float outer_gain);
void ma_shim_engine_listener_get_cone(void* handle, unsigned int index, float* out_inner, float* out_outer, float* out_gain);

void ma_shim_engine_listener_set_enabled(void* handle, unsigned int index, int enabled);
int  ma_shim_engine_listener_is_enabled(void* handle, unsigned int index);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_ENGINE_H */
