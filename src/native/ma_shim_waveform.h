#ifndef MA_SHIM_WAVEFORM_H
#define MA_SHIM_WAVEFORM_H

/* ---- waveform (opaque handle; PCM generator) ----
 *
 * Generates PCM audio (sine, square, triangle, sawtooth) in any miniaudio
 * format. No audio device or engine needed — purely in-memory computation.
 * Waveform type codes match ma_waveform_type: sine=0, square=1, triangle=2,
 * sawtooth=3. Sample format codes match ma_format: unknown=0, u8=1, s16=2,
 * s24=3, s32=4, f32=5.
 */

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_waveform_alloc(void);
void  ma_shim_waveform_free(void* handle);

int ma_shim_waveform_init(
    void*         handle,
    int           format,
    unsigned int  channels,
    unsigned int  sample_rate,
    int           waveform_type,
    double        amplitude,
    double        frequency
);
int ma_shim_waveform_uninit(void* handle);

int ma_shim_waveform_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);
int ma_shim_waveform_seek_to_pcm_frame(void* handle, unsigned long long frame_index);

int ma_shim_waveform_set_amplitude(void* handle, double amplitude);
int ma_shim_waveform_set_frequency(void* handle, double frequency);
int ma_shim_waveform_set_type(void* handle, int waveform_type);
int ma_shim_waveform_set_sample_rate(void* handle, unsigned int sample_rate);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_WAVEFORM_H */
