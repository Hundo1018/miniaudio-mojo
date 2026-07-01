#ifndef MA_SHIM_SOUND_H
#define MA_SHIM_SOUND_H

/* ---- sound (opaque handle; a playable sound owned by an engine) ----
 *
 * A sound is initialised from a file against an engine handle (from
 * ma_shim_engine_alloc + ma_shim_engine_init). The sound must not outlive its
 * engine. `flags` is the ma_sound flags bitfield (0 for the default).
 */

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_sound_alloc(void);
void  ma_shim_sound_free(void* handle);

int   ma_shim_sound_init_from_file(
    void* handle, void* engine_handle, const char* file_path, unsigned int flags);
int   ma_shim_sound_uninit(void* handle);

int   ma_shim_sound_start(void* handle);
int   ma_shim_sound_stop(void* handle);

int   ma_shim_sound_set_volume(void* handle, float volume);
float ma_shim_sound_get_volume(void* handle);
int   ma_shim_sound_set_pan(void* handle, float pan);
float ma_shim_sound_get_pan(void* handle);
int   ma_shim_sound_set_pitch(void* handle, float pitch);
float ma_shim_sound_get_pitch(void* handle);

int   ma_shim_sound_set_looping(void* handle, int looping);
int   ma_shim_sound_is_looping(void* handle);
int   ma_shim_sound_is_playing(void* handle);
int   ma_shim_sound_at_end(void* handle);

int   ma_shim_sound_set_spatialization_enabled(void* handle, int enabled);
int   ma_shim_sound_is_spatialization_enabled(void* handle);

int   ma_shim_sound_seek_to_pcm_frame(void* handle, unsigned long long frame_index);
int   ma_shim_sound_seek_to_second(void* handle, float seek_point);
int   ma_shim_sound_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);
int   ma_shim_sound_get_cursor_in_seconds(void* handle, float* out_cursor);
int   ma_shim_sound_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);
int   ma_shim_sound_get_length_in_seconds(void* handle, float* out_length);

int   ma_shim_sound_get_data_format(
    void* handle, int* out_format, unsigned int* out_channels,
    unsigned int* out_sample_rate);

/* spatialization property accessors */
void  ma_shim_sound_set_position(void* handle, float x, float y, float z);
void  ma_shim_sound_get_position(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_set_direction(void* handle, float x, float y, float z);
void  ma_shim_sound_get_direction(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_get_direction_to_listener(void* handle, float* out_x, float* out_y, float* out_z);
void  ma_shim_sound_set_velocity(void* handle, float x, float y, float z);
void  ma_shim_sound_get_velocity(void* handle, float* out_x, float* out_y, float* out_z);

void  ma_shim_sound_set_attenuation_model(void* handle, unsigned int model);
unsigned int ma_shim_sound_get_attenuation_model(void* handle);
void  ma_shim_sound_set_positioning(void* handle, unsigned int positioning);
unsigned int ma_shim_sound_get_positioning(void* handle);
void  ma_shim_sound_set_rolloff(void* handle, float rolloff);
float ma_shim_sound_get_rolloff(void* handle);
void  ma_shim_sound_set_min_gain(void* handle, float min_gain);
float ma_shim_sound_get_min_gain(void* handle);
void  ma_shim_sound_set_max_gain(void* handle, float max_gain);
float ma_shim_sound_get_max_gain(void* handle);
void  ma_shim_sound_set_min_distance(void* handle, float min_distance);
float ma_shim_sound_get_min_distance(void* handle);
void  ma_shim_sound_set_max_distance(void* handle, float max_distance);
float ma_shim_sound_get_max_distance(void* handle);
void  ma_shim_sound_set_cone(void* handle, float inner_angle, float outer_angle, float outer_gain);
void  ma_shim_sound_get_cone(void* handle, float* out_inner, float* out_outer, float* out_gain);
void  ma_shim_sound_set_doppler_factor(void* handle, float factor);
float ma_shim_sound_get_doppler_factor(void* handle);
void  ma_shim_sound_set_directional_attenuation_factor(void* handle, float factor);
float ma_shim_sound_get_directional_attenuation_factor(void* handle);

void  ma_shim_sound_set_pan_mode(void* handle, unsigned int pan_mode);
unsigned int ma_shim_sound_get_pan_mode(void* handle);
void  ma_shim_sound_set_pinned_listener_index(void* handle, unsigned int index);
unsigned int ma_shim_sound_get_pinned_listener_index(void* handle);
unsigned int ma_shim_sound_get_listener_index(void* handle);

/* fade */
void  ma_shim_sound_set_fade_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames);
void  ma_shim_sound_set_fade_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms);
void  ma_shim_sound_set_fade_start_in_pcm_frames(void* handle, float vol_beg, float vol_end, unsigned long long len_frames, unsigned long long abs_time_frames);
void  ma_shim_sound_set_fade_start_in_milliseconds(void* handle, float vol_beg, float vol_end, unsigned long long len_ms, unsigned long long abs_time_ms);
float ma_shim_sound_get_current_fade_volume(void* handle);
void  ma_shim_sound_reset_fade(void* handle);

/* start/stop time scheduling */
void  ma_shim_sound_set_start_time_in_pcm_frames(void* handle, unsigned long long abs_time);
void  ma_shim_sound_set_start_time_in_milliseconds(void* handle, unsigned long long abs_time);
void  ma_shim_sound_set_stop_time_in_pcm_frames(void* handle, unsigned long long abs_time);
void  ma_shim_sound_set_stop_time_in_milliseconds(void* handle, unsigned long long abs_time);
void  ma_shim_sound_set_stop_time_with_fade_in_pcm_frames(void* handle, unsigned long long stop_time, unsigned long long fade_len);
void  ma_shim_sound_set_stop_time_with_fade_in_milliseconds(void* handle, unsigned long long stop_time, unsigned long long fade_len);
int   ma_shim_sound_stop_with_fade_in_pcm_frames(void* handle, unsigned long long fade_len);
int   ma_shim_sound_stop_with_fade_in_milliseconds(void* handle, unsigned long long fade_len);
void  ma_shim_sound_reset_start_time(void* handle);
void  ma_shim_sound_reset_stop_time(void* handle);
void  ma_shim_sound_reset_stop_time_and_fade(void* handle);

unsigned long long ma_shim_sound_get_time_in_pcm_frames(void* handle);
unsigned long long ma_shim_sound_get_time_in_milliseconds(void* handle);

/* init_copy */
int   ma_shim_sound_init_copy(void* handle, void* engine_handle, void* existing_handle, unsigned int flags);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SOUND_H */
