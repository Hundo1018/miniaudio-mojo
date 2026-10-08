#ifndef MA_SHIM_PCM_CONVERT_H
#define MA_SHIM_PCM_CONVERT_H

/* ---- PCM conversion ----
 *
 * miniaudio's stateless conversion helpers: the 25 format-pair converters, the
 * interleave / deinterleave pair, whole-frame conversion, and the volume /
 * blend / mix helpers that copy rather than work in place. No handles, no
 * lifetime: every entry point is a plain call on caller memory.
 *
 * miniaudio does not validate any of it, and several of these index a table or
 * a switch by `format`, so the shim rejects what would be undefined behaviour:
 * NULL buffers, a `format` outside u8..f32, a `dither_mode` outside
 * none..triangle, zero or more-than-MA_MAX_CHANNELS channels, a zero sample
 * rate, and a volume outside +-128 for the integer clipping variants (they
 * convert it to 8.8 fixed point, which overflows beyond that). It cannot see how long a caller's buffer is, so counts are the
 * caller's responsibility; the Mojo layer sizes every buffer from its list.
 *
 * Deinterleaving writes into one buffer per channel and interleaving reads from
 * one, so miniaudio takes an array of pointers. Mojo has no safe home for such
 * an array, so the shim builds it from a single flat buffer laid out channel
 * after channel: `channel_stride_in_bytes` says how far apart the planes are
 * and must be at least one plane long.
 *
 * `ma_convert_frames` and `ma_convert_frames_ex` accept a NULL `out`, which
 * miniaudio defines as "only report how many frames the conversion would
 * produce"; `out_frames_written` then holds that count and `in` is not read.
 *
 * `ma_copy_string` allocates with miniaudio's allocator and hands back the
 * pointer; the shim copies the result into a caller buffer and frees it, so no
 * allocation crosses into Mojo.
 *
 * Sample format codes match ma_format (u8=1 .. f32=5); dither modes match
 * ma_dither_mode (none=0, rectangle=1, triangle=2). s24 is packed, three bytes
 * per sample, little-endian.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ---- the 25 format-pair converters ---- */
int ma_shim_pcm_u8_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_u8_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_u8_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_u8_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_u8_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s16_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s16_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s16_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s16_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s16_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s24_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s24_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s24_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s24_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s24_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s32_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s32_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s32_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s32_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_s32_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_f32_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_f32_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_f32_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_f32_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode);
int ma_shim_pcm_f32_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode);

/* ---- interleave / deinterleave, over a flat multi-plane buffer ---- */
int ma_shim_pcm_deinterleave_u8(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_interleave_u8(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_deinterleave_s16(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_interleave_s16(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_deinterleave_s24(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_interleave_s24(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_deinterleave_s32(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_interleave_s32(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_deinterleave_f32(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels);
int ma_shim_pcm_interleave_f32(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels);

/* ---- whole-buffer conversion ---- */

int ma_shim_pcm_convert(
    void* out, int format_out, const void* in, int format_in,
    unsigned long long sample_count, int dither_mode);
int ma_shim_convert_pcm_frames_format(
    void* out, int format_out, const void* in, int format_in,
    unsigned long long frame_count, unsigned int channels, int dither_mode);
/* `out` may be NULL to ask only how many frames the conversion would produce. */
int ma_shim_convert_frames(
    void*              out,
    unsigned long long frame_count_out,
    int                format_out,
    unsigned int       channels_out,
    unsigned int       sample_rate_out,
    const void*        in,
    unsigned long long frame_count_in,
    int                format_in,
    unsigned int       channels_in,
    unsigned int       sample_rate_in,
    unsigned long long* out_frames_written
);
/* Builds the data converter config from these fields. `lpf_order` is the
 * resampler's low-pass order (0 disables it, at most MA_MAX_FILTER_ORDER).
 * `out` may be NULL to ask only how many frames would be produced. */
int ma_shim_convert_frames_ex(
    void*              out,
    unsigned long long frame_count_out,
    const void*        in,
    unsigned long long frame_count_in,
    int                format_in,
    int                format_out,
    unsigned int       channels_in,
    unsigned int       channels_out,
    unsigned int       sample_rate_in,
    unsigned int       sample_rate_out,
    int                dither_mode,
    unsigned int       lpf_order,
    unsigned long long* out_frames_written
);
int ma_shim_copy_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels);

/* ---- volume and mixing, copying rather than in place ---- */
int ma_shim_copy_and_apply_volume_factor_u8(
    void* out, const void* in, unsigned long long sample_count, float factor);
int ma_shim_copy_and_apply_volume_factor_s16(
    void* out, const void* in, unsigned long long sample_count, float factor);
int ma_shim_copy_and_apply_volume_factor_s24(
    void* out, const void* in, unsigned long long sample_count, float factor);
int ma_shim_copy_and_apply_volume_factor_s32(
    void* out, const void* in, unsigned long long sample_count, float factor);
int ma_shim_copy_and_apply_volume_factor_f32(
    void* out, const void* in, unsigned long long sample_count, float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames_u8(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s16(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s24(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames_f32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor);
int ma_shim_copy_and_apply_volume_factor_pcm_frames(
    void* out, const void* in, unsigned long long frame_count, int format,
    unsigned int channels, float factor);
int ma_shim_copy_and_apply_volume_factor_per_channel_f32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    const void* channel_gains);

/* Each clipping variant takes a *wider* source than its destination. */
int ma_shim_copy_and_apply_volume_and_clip_samples_u8(
    void* dst, const void* src, unsigned long long count, float volume);
int ma_shim_copy_and_apply_volume_and_clip_samples_s16(
    void* dst, const void* src, unsigned long long count, float volume);
int ma_shim_copy_and_apply_volume_and_clip_samples_s24(
    void* dst, const void* src, unsigned long long count, float volume);
int ma_shim_copy_and_apply_volume_and_clip_samples_s32(
    void* dst, const void* src, unsigned long long count, float volume);
int ma_shim_copy_and_apply_volume_and_clip_samples_f32(
    void* dst, const void* src, unsigned long long count, float volume);
int ma_shim_copy_and_apply_volume_and_clip_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels, float volume);

/* ---- blending, mixing, decibels and strings ---- */

/* One frame: `out[i] = in_a[i] + (in_b[i] - in_a[i]) * factor` for each channel. */
int ma_shim_blend_f32(
    void* out, const void* in_a, const void* in_b, float factor, unsigned int channels);
/* Adds `src` into `dst`, scaled by `volume`. */
int ma_shim_mix_pcm_frames_f32(
    void* dst, const void* src, unsigned long long frame_count, unsigned int channels,
    float volume);
int ma_shim_volume_linear_to_db(float factor, float* out_db);
int ma_shim_volume_db_to_linear(float gain, float* out_linear);
/* Copies miniaudio's allocated duplicate into the caller's buffer and frees it.
 * MA_NO_SPACE (and an empty `out_text`) when it does not fit in `capacity`
 * including the terminator. */
int ma_shim_copy_string(const char* src, char* out_text, unsigned int capacity);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_PCM_CONVERT_H */
