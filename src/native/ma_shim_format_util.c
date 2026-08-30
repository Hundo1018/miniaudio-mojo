#include "ma_shim_format_util.h"
#include "miniaudio.h"

#include <string.h>

/* Exported by miniaudio but missing from its public header. */
MA_API ma_uint64 ma_calculate_frame_count_after_resampling(
    ma_uint32 sampleRateOut, ma_uint32 sampleRateIn, ma_uint64 frameCountIn);
MA_API ma_uint32 ma_get_format_priority_index(ma_format format);

/* Every entry point here is a plain call on caller memory: no handles, no
 * lifetime, just a NULL check and the forward. */
#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

/* ---- volume, applied in place ---- */

/* @binds ma_apply_volume_factor_u8 */
int ma_shim_apply_volume_factor_u8(void* samples, unsigned long long count, float factor) {
    MA_SHIM_REQUIRE(samples != NULL);
    ma_apply_volume_factor_u8((ma_uint8*)samples, (ma_uint64)count, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_s16 */
int ma_shim_apply_volume_factor_s16(void* samples, unsigned long long count, float factor) {
    MA_SHIM_REQUIRE(samples != NULL);
    ma_apply_volume_factor_s16((ma_int16*)samples, (ma_uint64)count, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_s24 */
int ma_shim_apply_volume_factor_s24(void* samples, unsigned long long count, float factor) {
    MA_SHIM_REQUIRE(samples != NULL);
    ma_apply_volume_factor_s24(samples, (ma_uint64)count, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_s32 */
int ma_shim_apply_volume_factor_s32(void* samples, unsigned long long count, float factor) {
    MA_SHIM_REQUIRE(samples != NULL);
    ma_apply_volume_factor_s32((ma_int32*)samples, (ma_uint64)count, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_f32 */
int ma_shim_apply_volume_factor_f32(void* samples, unsigned long long count, float factor) {
    MA_SHIM_REQUIRE(samples != NULL);
    ma_apply_volume_factor_f32((float*)samples, (ma_uint64)count, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames */
int ma_shim_apply_volume_factor_pcm_frames(
    void* frames, unsigned long long frame_count, int format, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames(
        frames, (ma_uint64)frame_count, (ma_format)format, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames_u8 */
int ma_shim_apply_volume_factor_pcm_frames_u8(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames_u8(
        (ma_uint8*)frames, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames_s16 */
int ma_shim_apply_volume_factor_pcm_frames_s16(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames_s16(
        (ma_int16*)frames, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames_s24 */
int ma_shim_apply_volume_factor_pcm_frames_s24(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames_s24(
        frames, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames_s32 */
int ma_shim_apply_volume_factor_pcm_frames_s32(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames_s32(
        (ma_int32*)frames, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_apply_volume_factor_pcm_frames_f32 */
int ma_shim_apply_volume_factor_pcm_frames_f32(
    void* frames, unsigned long long frame_count, unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(frames != NULL);
    ma_apply_volume_factor_pcm_frames_f32(
        (float*)frames, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* ---- clipping ---- */

/* @binds ma_clip_samples_u8 */
int ma_shim_clip_samples_u8(void* dst, const void* src_s16, unsigned long long count) {
    MA_SHIM_REQUIRE(dst != NULL && src_s16 != NULL);
    ma_clip_samples_u8((ma_uint8*)dst, (const ma_int16*)src_s16, (ma_uint64)count);
    return MA_SUCCESS;
}

/* @binds ma_clip_samples_s16 */
int ma_shim_clip_samples_s16(void* dst, const void* src_s32, unsigned long long count) {
    MA_SHIM_REQUIRE(dst != NULL && src_s32 != NULL);
    ma_clip_samples_s16((ma_int16*)dst, (const ma_int32*)src_s32, (ma_uint64)count);
    return MA_SUCCESS;
}

/* @binds ma_clip_samples_s24 */
int ma_shim_clip_samples_s24(void* dst, const void* src_s64, unsigned long long count) {
    MA_SHIM_REQUIRE(dst != NULL && src_s64 != NULL);
    ma_clip_samples_s24((ma_uint8*)dst, (const ma_int64*)src_s64, (ma_uint64)count);
    return MA_SUCCESS;
}

/* @binds ma_clip_samples_s32 */
int ma_shim_clip_samples_s32(void* dst, const void* src_s64, unsigned long long count) {
    MA_SHIM_REQUIRE(dst != NULL && src_s64 != NULL);
    ma_clip_samples_s32((ma_int32*)dst, (const ma_int64*)src_s64, (ma_uint64)count);
    return MA_SUCCESS;
}

/* @binds ma_clip_samples_f32 */
int ma_shim_clip_samples_f32(void* dst, const void* src, unsigned long long count) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL);
    ma_clip_samples_f32((float*)dst, (const float*)src, (ma_uint64)count);
    return MA_SUCCESS;
}

/* @binds ma_clip_pcm_frames */
int ma_shim_clip_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL);
    ma_clip_pcm_frames(
        dst, src, (ma_uint64)frame_count, (ma_format)format, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* ---- buffer-size arithmetic ---- */

/* @binds ma_calculate_buffer_size_in_frames_from_milliseconds */
int ma_shim_calculate_buffer_size_in_frames_from_milliseconds(
    unsigned int milliseconds, unsigned int sample_rate, unsigned int* out_frames
) {
    MA_SHIM_REQUIRE(out_frames != NULL);
    *out_frames = (unsigned int)ma_calculate_buffer_size_in_frames_from_milliseconds(
        (ma_uint32)milliseconds, (ma_uint32)sample_rate);
    return MA_SUCCESS;
}

/* @binds ma_calculate_buffer_size_in_milliseconds_from_frames */
int ma_shim_calculate_buffer_size_in_milliseconds_from_frames(
    unsigned int frames, unsigned int sample_rate, unsigned int* out_milliseconds
) {
    MA_SHIM_REQUIRE(out_milliseconds != NULL);
    *out_milliseconds =
        (unsigned int)ma_calculate_buffer_size_in_milliseconds_from_frames(
            (ma_uint32)frames, (ma_uint32)sample_rate);
    return MA_SUCCESS;
}

/* @binds ma_calculate_frame_count_after_resampling */
int ma_shim_calculate_frame_count_after_resampling(
    unsigned int sample_rate_out, unsigned int sample_rate_in,
    unsigned long long frame_count_in, unsigned long long* out_frame_count
) {
    MA_SHIM_REQUIRE(out_frame_count != NULL);
    *out_frame_count = (unsigned long long)ma_calculate_frame_count_after_resampling(
        (ma_uint32)sample_rate_out, (ma_uint32)sample_rate_in,
        (ma_uint64)frame_count_in);
    return MA_SUCCESS;
}

/* @binds ma_calculate_buffer_size_in_frames_from_descriptor */
int ma_shim_calculate_buffer_size_in_frames_from_descriptor(
    int           format,
    unsigned int  channels,
    unsigned int  sample_rate,
    unsigned int  period_size_in_frames,
    unsigned int  period_size_in_milliseconds,
    unsigned int  native_sample_rate,
    int           performance_profile,
    unsigned int* out_frames
) {
    ma_device_descriptor descriptor;

    MA_SHIM_REQUIRE(out_frames != NULL);
    memset(&descriptor, 0, sizeof(descriptor));
    descriptor.format = (ma_format)format;
    descriptor.channels = (ma_uint32)channels;
    descriptor.sampleRate = (ma_uint32)sample_rate;
    descriptor.periodSizeInFrames = (ma_uint32)period_size_in_frames;
    descriptor.periodSizeInMilliseconds = (ma_uint32)period_size_in_milliseconds;

    *out_frames = (unsigned int)ma_calculate_buffer_size_in_frames_from_descriptor(
        &descriptor, (ma_uint32)native_sample_rate,
        (ma_performance_profile)performance_profile);
    return MA_SUCCESS;
}

/* ---- name and priority tables ---- */

/* @binds ma_get_bytes_per_sample */
int ma_shim_get_bytes_per_sample(int format, unsigned int* out_bytes) {
    MA_SHIM_REQUIRE(out_bytes != NULL);
    *out_bytes = (unsigned int)ma_get_bytes_per_sample((ma_format)format);
    return MA_SUCCESS;
}

/* @binds ma_get_format_name */
int ma_shim_get_format_name(int format, char* out_text, unsigned int capacity) {
    const char* text;
    MA_SHIM_REQUIRE(out_text != NULL && capacity > 0);
    text = ma_get_format_name((ma_format)format);
    MA_SHIM_REQUIRE(text != NULL);
    strncpy(out_text, text, capacity - 1);
    out_text[capacity - 1] = '\0';
    return MA_SUCCESS;
}

/* @binds ma_get_format_priority_index */
int ma_shim_get_format_priority_index(int format, unsigned int* out_index) {
    MA_SHIM_REQUIRE(out_index != NULL);
    *out_index = (unsigned int)ma_get_format_priority_index((ma_format)format);
    return MA_SUCCESS;
}

/* @binds ma_get_backend_name */
int ma_shim_get_backend_name(int backend, char* out_text, unsigned int capacity) {
    const char* text;
    MA_SHIM_REQUIRE(out_text != NULL && capacity > 0);
    text = ma_get_backend_name((ma_backend)backend);
    MA_SHIM_REQUIRE(text != NULL);
    strncpy(out_text, text, capacity - 1);
    out_text[capacity - 1] = '\0';
    return MA_SUCCESS;
}

/* @binds ma_get_backend_from_name */
int ma_shim_get_backend_from_name(const char* name, int* out_backend) {
    ma_backend backend = ma_backend_null;
    ma_result  result;

    if (out_backend != NULL) { *out_backend = 0; }
    MA_SHIM_REQUIRE(name != NULL && out_backend != NULL);
    result = ma_get_backend_from_name(name, &backend);
    *out_backend = (int)backend;
    return (int)result;
}

/* @binds ma_get_enabled_backends */
int ma_shim_get_enabled_backends(
    int* out_backends, unsigned int capacity, unsigned int* out_count
) {
    ma_backend backends[MA_BACKEND_COUNT];
    size_t     count = 0;
    ma_result  result;
    size_t     i;

    if (out_count != NULL) { *out_count = 0; }
    MA_SHIM_REQUIRE(out_backends != NULL && out_count != NULL && capacity > 0);

    result = ma_get_enabled_backends(backends, MA_BACKEND_COUNT, &count);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (count > (size_t)capacity) {
        count = (size_t)capacity;
    }
    for (i = 0; i < count; i += 1) {
        out_backends[i] = (int)backends[i];
    }
    *out_count = (unsigned int)count;
    return MA_SUCCESS;
}
