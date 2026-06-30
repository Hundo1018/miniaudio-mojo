#ifndef MA_SHIM_NOISE_H
#define MA_SHIM_NOISE_H

/* ---- noise (opaque handle; PCM generator) ----
 *
 * Generates white, pink, or Brownian noise in any miniaudio format.
 * No audio device or engine needed — purely in-memory computation.
 * Noise type codes match ma_noise_type: white=0, pink=1, brownian=2.
 * Sample format codes match ma_format: unknown=0, u8=1, s16=2, s24=3,
 * s32=4, f32=5.
 */

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_noise_alloc(void);
void  ma_shim_noise_free(void* handle);

int ma_shim_noise_init(
    void*         handle,
    int           format,
    unsigned int  channels,
    int           noise_type,
    int           seed,
    double        amplitude
);
int ma_shim_noise_uninit(void* handle);

int ma_shim_noise_read_pcm_frames(
    void*               handle,
    void*               output,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);

int ma_shim_noise_set_amplitude(void* handle, double amplitude);
int ma_shim_noise_set_seed(void* handle, int seed);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_NOISE_H */
