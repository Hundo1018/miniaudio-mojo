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

unsigned int       ma_shim_engine_get_sample_rate(void* handle);
unsigned int       ma_shim_engine_get_channels(void* handle);
int                ma_shim_engine_set_volume(void* handle, float volume);
float              ma_shim_engine_get_volume(void* handle);
int                ma_shim_engine_set_gain_db(void* handle, float gain_db);
float              ma_shim_engine_get_gain_db(void* handle);
unsigned long long ma_shim_engine_get_time_in_pcm_frames(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_ENGINE_H */
