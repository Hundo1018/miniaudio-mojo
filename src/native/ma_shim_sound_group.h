#ifndef MA_SHIM_SOUND_GROUP_H
#define MA_SHIM_SOUND_GROUP_H

/* ---- sound_group (opaque handle; a mixing bus owned by an engine) ----
 *
 * A sound group is initialised against an engine handle and attaches to the
 * engine endpoint (parent group = NULL). Sounds can be routed through it for
 * shared volume/pan/pitch/spatialization. Must not outlive its engine.
 */

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_sound_group_alloc(void);
void  ma_shim_sound_group_free(void* handle);

int   ma_shim_sound_group_init(void* handle, void* engine_handle, unsigned int flags);
int   ma_shim_sound_group_uninit(void* handle);

int   ma_shim_sound_group_start(void* handle);
int   ma_shim_sound_group_stop(void* handle);

int   ma_shim_sound_group_set_volume(void* handle, float volume);
float ma_shim_sound_group_get_volume(void* handle);
int   ma_shim_sound_group_set_pan(void* handle, float pan);
float ma_shim_sound_group_get_pan(void* handle);
int   ma_shim_sound_group_set_pitch(void* handle, float pitch);
float ma_shim_sound_group_get_pitch(void* handle);

int   ma_shim_sound_group_set_spatialization_enabled(void* handle, int enabled);
int   ma_shim_sound_group_is_spatialization_enabled(void* handle);
int   ma_shim_sound_group_is_playing(void* handle);

unsigned long long ma_shim_sound_group_get_time_in_pcm_frames(void* handle);

/* spatialization property accessors */
void  ma_shim_sound_group_set_position(void* handle, float x, float y, float z);
void  ma_shim_sound_group_get_position(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_group_set_direction(void* handle, float x, float y, float z);
void  ma_shim_sound_group_get_direction(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_group_get_direction_to_listener(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_group_set_velocity(void* handle, float x, float y, float z);
void  ma_shim_sound_group_get_velocity(void* handle, float* out_x, float* out_y, float* out_z);

void  ma_shim_sound_group_set_attenuation_model(void* handle, unsigned int model);
unsigned int ma_shim_sound_group_get_attenuation_model(void* handle);
void  ma_shim_sound_group_set_positioning(void* handle, unsigned int positioning);
unsigned int ma_shim_sound_group_get_positioning(void* handle);
void  ma_shim_sound_group_set_rolloff(void* handle, float rolloff);
float ma_shim_sound_group_get_rolloff(void* handle);
void  ma_shim_sound_group_set_min_gain(void* handle, float min_gain);
float ma_shim_sound_group_get_min_gain(void* handle);
void  ma_shim_sound_group_set_max_gain(void* handle, float max_gain);
float ma_shim_sound_group_get_max_gain(void* handle);
void  ma_shim_sound_group_set_min_distance(void* handle, float min_distance);
float ma_shim_sound_group_get_min_distance(void* handle);
void  ma_shim_sound_group_set_max_distance(void* handle, float max_distance);
float ma_shim_sound_group_get_max_distance(void* handle);
void  ma_shim_sound_group_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain);
void  ma_shim_sound_group_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain);
void  ma_shim_sound_group_set_doppler_factor(void* handle, float factor);
float ma_shim_sound_group_get_doppler_factor(void* handle);
void  ma_shim_sound_group_set_directional_attenuation_factor(void* handle, float factor);
float ma_shim_sound_group_get_directional_attenuation_factor(void* handle);

void  ma_shim_sound_group_set_pan_mode(void* handle, unsigned int pan_mode);
unsigned int ma_shim_sound_group_get_pan_mode(void* handle);
void  ma_shim_sound_group_set_pinned_listener_index(void* handle, unsigned int index);
unsigned int ma_shim_sound_group_get_pinned_listener_index(void* handle);
unsigned int ma_shim_sound_group_get_listener_index(void* handle);

/* fade */
void  ma_shim_sound_group_set_fade_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames);
void  ma_shim_sound_group_set_fade_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms);
float ma_shim_sound_group_get_current_fade_volume(void* handle);

/* start/stop time scheduling */
void  ma_shim_sound_group_set_start_time_in_pcm_frames(void* handle, unsigned long long abs_time);
void  ma_shim_sound_group_set_start_time_in_milliseconds(void* handle, unsigned long long abs_time);
void  ma_shim_sound_group_set_stop_time_in_pcm_frames(void* handle, unsigned long long abs_time);
void  ma_shim_sound_group_set_stop_time_in_milliseconds(void* handle, unsigned long long abs_time);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SOUND_GROUP_H */
