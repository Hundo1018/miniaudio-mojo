#ifndef MA_SHIM_FORMAT_UTIL_H
#define MA_SHIM_FORMAT_UTIL_H

/* ---- format utilities ----
 *
 * miniaudio's stateless helpers: volume scaling, clipping, buffer-size
 * arithmetic and the format / backend name tables. Nothing here owns anything,
 * so there are no handles — every entry point is a plain call on caller memory.
 *
 * The clipping functions take a *wider* source than destination, which is the
 * point of them: s32 clips down into s16, s64 into s32 and s24, s16 into u8,
 * and f32 clips in place to [-1, 1]. The shim keeps those widths as miniaudio
 * declares them rather than flattening them to void*.
 *
 * Two of these are exported by miniaudio without a public prototype
 * (`ma_calculate_frame_count_after_resampling` and
 * `ma_get_format_priority_index`), so the shim declares them rather than
 * leaving them unbound.
 *
 * Sample format codes match ma_format; backend codes match ma_backend.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ---- volume, applied in place ---- */

int ma_shim_apply_volume_factor_u8(void* samples, unsigned long long count, float factor);
int ma_shim_apply_volume_factor_s16(void* samples, unsigned long long count, float factor);
int ma_shim_apply_volume_factor_s24(void* samples, unsigned long long count, float factor);
int ma_shim_apply_volume_factor_s32(void* samples, unsigned long long count, float factor);
int ma_shim_apply_volume_factor_f32(void* samples, unsigned long long count, float factor);

int ma_shim_apply_volume_factor_pcm_frames(
    void* frames, unsigned long long frame_count, int format, unsigned int channels,
    float factor);
int ma_shim_apply_volume_factor_pcm_frames_u8(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor);
int ma_shim_apply_volume_factor_pcm_frames_s16(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor);
int ma_shim_apply_volume_factor_pcm_frames_s24(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor);
int ma_shim_apply_volume_factor_pcm_frames_s32(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor);
int ma_shim_apply_volume_factor_pcm_frames_f32(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor);

/* ---- clipping: each takes a wider source than its destination ---- */

int ma_shim_clip_samples_u8(void* dst, const void* src_s16, unsigned long long count);
int ma_shim_clip_samples_s16(void* dst, const void* src_s32, unsigned long long count);
int ma_shim_clip_samples_s24(void* dst, const void* src_s64, unsigned long long count);
int ma_shim_clip_samples_s32(void* dst, const void* src_s64, unsigned long long count);
int ma_shim_clip_samples_f32(void* dst, const void* src, unsigned long long count);
int ma_shim_clip_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels);

/* ---- buffer-size arithmetic ---- */

int ma_shim_calculate_buffer_size_in_frames_from_milliseconds(
    unsigned int milliseconds, unsigned int sample_rate, unsigned int* out_frames);
int ma_shim_calculate_buffer_size_in_milliseconds_from_frames(
    unsigned int frames, unsigned int sample_rate, unsigned int* out_milliseconds);
int ma_shim_calculate_frame_count_after_resampling(
    unsigned int sample_rate_out, unsigned int sample_rate_in,
    unsigned long long frame_count_in, unsigned long long* out_frame_count);
/* Builds a descriptor from these fields and asks miniaudio to size it. */
int ma_shim_calculate_buffer_size_in_frames_from_descriptor(
    int           format,
    unsigned int  channels,
    unsigned int  sample_rate,
    unsigned int  period_size_in_frames,
    unsigned int  period_size_in_milliseconds,
    unsigned int  native_sample_rate,
    int           performance_profile,
    unsigned int* out_frames
);

/* ---- name and priority tables ---- */

int ma_shim_get_bytes_per_sample(int format, unsigned int* out_bytes);
int ma_shim_get_format_name(int format, char* out_text, unsigned int capacity);
int ma_shim_get_format_priority_index(int format, unsigned int* out_index);
int ma_shim_get_backend_name(int backend, char* out_text, unsigned int capacity);
int ma_shim_get_backend_from_name(const char* name, int* out_backend);
int ma_shim_get_enabled_backends(
    int* out_backends, unsigned int capacity, unsigned int* out_count);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_FORMAT_UTIL_H */
