#ifndef MA_SHIM_EFFECT_H
#define MA_SHIM_EFFECT_H

/* ---- standalone effects (opaque handles; in-memory DSP) ----
 *
 * The four non-node effect objects miniaudio exposes directly: ma_delay
 * (echo / delay line), ma_gainer (smoothed per-channel gain), ma_panner
 * (stereo balance / pan) and ma_fader (linear volume ramp). None needs a
 * device or engine. Frames are interleaved; ma_delay, ma_gainer and ma_fader
 * process f32 only, ma_panner follows its configured format.
 *
 * Codes: sample format matches ma_format (f32 = 5); pan mode matches
 * ma_pan_mode (balance = 0, pan = 1).
 *
 * Every entry point returns a ma_result code; getters write through an out
 * pointer so an uninitialised handle is observable as MA_INVALID_ARGS.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ---- ma_delay ---- */
void* ma_shim_delay_alloc(void);
void  ma_shim_delay_free(void* handle);
int   ma_shim_delay_init(
    void*        handle,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int delay_in_frames,
    float        decay
);
int   ma_shim_delay_uninit(void* handle);
int   ma_shim_delay_process(void* handle, void* out, const void* in, unsigned int frame_count);
int   ma_shim_delay_set_wet(void* handle, float value);
int   ma_shim_delay_get_wet(void* handle, float* out_value);
int   ma_shim_delay_set_dry(void* handle, float value);
int   ma_shim_delay_get_dry(void* handle, float* out_value);
int   ma_shim_delay_set_decay(void* handle, float value);
int   ma_shim_delay_get_decay(void* handle, float* out_value);

/* ---- ma_gainer ---- */
void* ma_shim_gainer_alloc(void);
void  ma_shim_gainer_free(void* handle);
int   ma_shim_gainer_get_heap_size(
    unsigned int        channels,
    unsigned int        smooth_time_in_frames,
    unsigned long long* out_heap_size
);
int   ma_shim_gainer_init(void* handle, unsigned int channels, unsigned int smooth_time_in_frames);
int   ma_shim_gainer_init_preallocated(
    void*        handle,
    unsigned int channels,
    unsigned int smooth_time_in_frames
);
int   ma_shim_gainer_uninit(void* handle);
int   ma_shim_gainer_process(void* handle, void* out, const void* in, unsigned long long frame_count);
int   ma_shim_gainer_set_gain(void* handle, float gain);
int   ma_shim_gainer_set_gains(void* handle, const float* gains, unsigned int gain_count);
int   ma_shim_gainer_set_master_volume(void* handle, float volume);
int   ma_shim_gainer_get_master_volume(void* handle, float* out_volume);

/* ---- ma_panner ---- */
void* ma_shim_panner_alloc(void);
void  ma_shim_panner_free(void* handle);
int   ma_shim_panner_init(void* handle, int format, unsigned int channels, int mode, float pan);
int   ma_shim_panner_uninit(void* handle);
int   ma_shim_panner_process(void* handle, void* out, const void* in, unsigned long long frame_count);
int   ma_shim_panner_set_mode(void* handle, int mode);
int   ma_shim_panner_get_mode(void* handle, int* out_mode);
int   ma_shim_panner_set_pan(void* handle, float pan);
int   ma_shim_panner_get_pan(void* handle, float* out_pan);

/* ---- ma_fader ---- */
void* ma_shim_fader_alloc(void);
void  ma_shim_fader_free(void* handle);
int   ma_shim_fader_init(void* handle, int format, unsigned int channels, unsigned int sample_rate);
int   ma_shim_fader_uninit(void* handle);
int   ma_shim_fader_process(void* handle, void* out, const void* in, unsigned long long frame_count);
int   ma_shim_fader_get_data_format(
    void*         handle,
    int*          out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
);
int   ma_shim_fader_set_fade(void* handle, float volume_beg, float volume_end, unsigned long long length_in_frames);
int   ma_shim_fader_set_fade_ex(
    void*              handle,
    float              volume_beg,
    float              volume_end,
    unsigned long long length_in_frames,
    long long          start_offset_in_frames
);
int   ma_shim_fader_get_current_volume(void* handle, float* out_volume);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_EFFECT_H */
