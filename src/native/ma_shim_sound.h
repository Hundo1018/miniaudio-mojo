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
int   ma_shim_sound_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);
int   ma_shim_sound_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SOUND_H */
