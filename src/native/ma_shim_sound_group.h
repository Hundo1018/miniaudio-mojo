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

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_SOUND_GROUP_H */
