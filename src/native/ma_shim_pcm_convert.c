#include "ma_shim_pcm_convert.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>


/* These are exported by miniaudio but missing from its public header: the
 * five identity converters, and the whole interleave / deinterleave family.
 * Declared here rather than left unbound; ma_copy_string is the same case. */
MA_API char* ma_copy_string(const char* src, const ma_allocation_callbacks* pAllocationCallbacks);
MA_API void ma_pcm_u8_to_u8(
    void* pOut, const void* pIn, ma_uint64 count, ma_dither_mode ditherMode);
MA_API void ma_pcm_s16_to_s16(
    void* pOut, const void* pIn, ma_uint64 count, ma_dither_mode ditherMode);
MA_API void ma_pcm_s24_to_s24(
    void* pOut, const void* pIn, ma_uint64 count, ma_dither_mode ditherMode);
MA_API void ma_pcm_s32_to_s32(
    void* pOut, const void* pIn, ma_uint64 count, ma_dither_mode ditherMode);
MA_API void ma_pcm_f32_to_f32(
    void* pOut, const void* pIn, ma_uint64 count, ma_dither_mode ditherMode);
MA_API void ma_pcm_deinterleave_u8(
    void** ppDeinterleavedPCMFrames, const void* pInterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_interleave_u8(
    void* pInterleavedPCMFrames, const void** ppDeinterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_deinterleave_s16(
    void** ppDeinterleavedPCMFrames, const void* pInterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_interleave_s16(
    void* pInterleavedPCMFrames, const void** ppDeinterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_deinterleave_s24(
    void** ppDeinterleavedPCMFrames, const void* pInterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_interleave_s24(
    void* pInterleavedPCMFrames, const void** ppDeinterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_deinterleave_s32(
    void** ppDeinterleavedPCMFrames, const void* pInterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_interleave_s32(
    void* pInterleavedPCMFrames, const void** ppDeinterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_deinterleave_f32(
    void** ppDeinterleavedPCMFrames, const void* pInterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);
MA_API void ma_pcm_interleave_f32(
    void* pInterleavedPCMFrames, const void** ppDeinterleavedPCMFrames,
    ma_uint64 frameCount, ma_uint32 channels);

#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

/* miniaudio indexes a table by format and by dither mode without checking, so
 * anything outside the enum is rejected here. */
static int format_ok(int format) {
    return format >= (int)ma_format_u8 && format <= (int)ma_format_f32;
}

static int dither_ok(int dither_mode) {
    return dither_mode >= (int)ma_dither_mode_none &&
           dither_mode <= (int)ma_dither_mode_triangle;
}

static int channels_ok(unsigned int channels) {
    return channels >= 1 && channels <= MA_MAX_CHANNELS;
}

/* The integer clipping variants turn the volume into 8.8 fixed point with a
 * plain cast to a 16-bit integer. Outside +-128 (or for NaN) that cast is
 * undefined behaviour and in practice flips the sign of the gain. */
static int fixed_volume_ok(float volume) {
    return volume >= -128.0f && volume < 128.0f;
}

/* Deinterleaved audio is an array of per-channel pointers. Mojo cannot hold
 * one, so the caller passes a single flat buffer with the planes laid out one
 * after another and the shim builds the pointer array over it. A stride shorter
 * than a plane would make the planes overlap, so that is refused. */
static int build_planes(
    void* planes[MA_MAX_CHANNELS],
    void* base,
    unsigned int channels,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count,
    unsigned int bytes_per_sample
) {
    unsigned int c;
    if (!channels_ok(channels)) { return 0; }
    if (frame_count > channel_stride_in_bytes / bytes_per_sample) { return 0; }
    for (c = 0; c < channels; c += 1) {
        planes[c] = (unsigned char*)base + (size_t)((unsigned long long)c * channel_stride_in_bytes);
    }
    return 1;
}

/* ---- the 25 format-pair converters ---- */

/* @binds ma_pcm_u8_to_u8 */
int ma_shim_pcm_u8_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_u8_to_u8(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_u8_to_s16 */
int ma_shim_pcm_u8_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_u8_to_s16(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_u8_to_s24 */
int ma_shim_pcm_u8_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_u8_to_s24(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_u8_to_s32 */
int ma_shim_pcm_u8_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_u8_to_s32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_u8_to_f32 */
int ma_shim_pcm_u8_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_u8_to_f32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s16_to_u8 */
int ma_shim_pcm_s16_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s16_to_u8(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s16_to_s16 */
int ma_shim_pcm_s16_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s16_to_s16(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s16_to_s24 */
int ma_shim_pcm_s16_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s16_to_s24(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s16_to_s32 */
int ma_shim_pcm_s16_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s16_to_s32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s16_to_f32 */
int ma_shim_pcm_s16_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s16_to_f32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s24_to_u8 */
int ma_shim_pcm_s24_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s24_to_u8(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s24_to_s16 */
int ma_shim_pcm_s24_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s24_to_s16(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s24_to_s24 */
int ma_shim_pcm_s24_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s24_to_s24(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s24_to_s32 */
int ma_shim_pcm_s24_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s24_to_s32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s24_to_f32 */
int ma_shim_pcm_s24_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s24_to_f32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s32_to_u8 */
int ma_shim_pcm_s32_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s32_to_u8(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s32_to_s16 */
int ma_shim_pcm_s32_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s32_to_s16(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s32_to_s24 */
int ma_shim_pcm_s32_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s32_to_s24(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s32_to_s32 */
int ma_shim_pcm_s32_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s32_to_s32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_s32_to_f32 */
int ma_shim_pcm_s32_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_s32_to_f32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_f32_to_u8 */
int ma_shim_pcm_f32_to_u8(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_f32_to_u8(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_f32_to_s16 */
int ma_shim_pcm_f32_to_s16(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_f32_to_s16(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_f32_to_s24 */
int ma_shim_pcm_f32_to_s24(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_f32_to_s24(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_f32_to_s32 */
int ma_shim_pcm_f32_to_s32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_f32_to_s32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_pcm_f32_to_f32 */
int ma_shim_pcm_f32_to_f32(
    void* out, const void* in, unsigned long long count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    ma_pcm_f32_to_f32(out, in, (ma_uint64)count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* ---- interleave / deinterleave ---- */

/* @binds ma_pcm_deinterleave_u8 */
int ma_shim_pcm_deinterleave_u8(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, 1));
    ma_pcm_deinterleave_u8(
        planes, interleaved, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_interleave_u8 */
int ma_shim_pcm_interleave_u8(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, 1));
    ma_pcm_interleave_u8(
        interleaved, (const void**)planes, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_deinterleave_s16 */
int ma_shim_pcm_deinterleave_s16(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, 2));
    ma_pcm_deinterleave_s16(
        planes, interleaved, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_interleave_s16 */
int ma_shim_pcm_interleave_s16(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, 2));
    ma_pcm_interleave_s16(
        interleaved, (const void**)planes, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_deinterleave_s24 */
int ma_shim_pcm_deinterleave_s24(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, 3));
    ma_pcm_deinterleave_s24(
        planes, interleaved, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_interleave_s24 */
int ma_shim_pcm_interleave_s24(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, 3));
    ma_pcm_interleave_s24(
        interleaved, (const void**)planes, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_deinterleave_s32 */
int ma_shim_pcm_deinterleave_s32(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, 4));
    ma_pcm_deinterleave_s32(
        planes, interleaved, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_interleave_s32 */
int ma_shim_pcm_interleave_s32(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, 4));
    ma_pcm_interleave_s32(
        interleaved, (const void**)planes, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_deinterleave_f32 */
int ma_shim_pcm_deinterleave_f32(
    void* planes_base, unsigned long long channel_stride_in_bytes,
    const void* interleaved, unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, 4));
    ma_pcm_deinterleave_f32(
        planes, interleaved, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_pcm_interleave_f32 */
int ma_shim_pcm_interleave_f32(
    void* interleaved, const void* planes_base,
    unsigned long long channel_stride_in_bytes,
    unsigned long long frame_count, unsigned int channels
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, 4));
    ma_pcm_interleave_f32(
        interleaved, (const void**)planes, (ma_uint64)frame_count, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* ---- whole-buffer conversion ---- */

/* @binds ma_pcm_convert */
int ma_shim_pcm_convert(
    void* out, int format_out, const void* in, int format_in,
    unsigned long long sample_count, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    MA_SHIM_REQUIRE(format_ok(format_out) && format_ok(format_in));
    ma_pcm_convert(out, (ma_format)format_out, in, (ma_format)format_in,
                   (ma_uint64)sample_count, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_convert_pcm_frames_format */
int ma_shim_convert_pcm_frames_format(
    void* out, int format_out, const void* in, int format_in,
    unsigned long long frame_count, unsigned int channels, int dither_mode
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && dither_ok(dither_mode));
    MA_SHIM_REQUIRE(format_ok(format_out) && format_ok(format_in) && channels_ok(channels));
    ma_convert_pcm_frames_format(
        out, (ma_format)format_out, in, (ma_format)format_in,
        (ma_uint64)frame_count, (ma_uint32)channels, (ma_dither_mode)dither_mode);
    return MA_SUCCESS;
}

/* @binds ma_convert_frames */
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
) {
    if (out_frames_written != NULL) { *out_frames_written = 0; }
    MA_SHIM_REQUIRE(out_frames_written != NULL && (in != NULL || out == NULL));
    MA_SHIM_REQUIRE(format_ok(format_out) && format_ok(format_in));
    MA_SHIM_REQUIRE(channels_ok(channels_out) && channels_ok(channels_in));
    MA_SHIM_REQUIRE(sample_rate_out > 0 && sample_rate_in > 0);
    *out_frames_written = (unsigned long long)ma_convert_frames(
        out, (ma_uint64)frame_count_out, (ma_format)format_out,
        (ma_uint32)channels_out, (ma_uint32)sample_rate_out,
        in, (ma_uint64)frame_count_in, (ma_format)format_in,
        (ma_uint32)channels_in, (ma_uint32)sample_rate_in);
    return MA_SUCCESS;
}

/* @binds ma_convert_frames_ex, ma_data_converter_config_init */
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
) {
    ma_data_converter_config config;

    if (out_frames_written != NULL) { *out_frames_written = 0; }
    MA_SHIM_REQUIRE(out_frames_written != NULL && (in != NULL || out == NULL));
    MA_SHIM_REQUIRE(dither_ok(dither_mode));
    MA_SHIM_REQUIRE(format_ok(format_out) && format_ok(format_in));
    MA_SHIM_REQUIRE(channels_ok(channels_out) && channels_ok(channels_in));
    MA_SHIM_REQUIRE(sample_rate_out > 0 && sample_rate_in > 0);
    MA_SHIM_REQUIRE(lpf_order <= MA_MAX_FILTER_ORDER);

    config = ma_data_converter_config_init(
        (ma_format)format_in, (ma_format)format_out,
        (ma_uint32)channels_in, (ma_uint32)channels_out,
        (ma_uint32)sample_rate_in, (ma_uint32)sample_rate_out);
    config.ditherMode = (ma_dither_mode)dither_mode;
    config.resampling.linear.lpfOrder = (ma_uint32)lpf_order;
    *out_frames_written = (unsigned long long)ma_convert_frames_ex(
        out, (ma_uint64)frame_count_out, in, (ma_uint64)frame_count_in, &config);
    return MA_SUCCESS;
}

/* @binds ma_copy_pcm_frames */
int ma_shim_copy_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL);
    MA_SHIM_REQUIRE(format_ok(format) && channels_ok(channels));
    ma_copy_pcm_frames(dst, src, (ma_uint64)frame_count, (ma_format)format,
                       (ma_uint32)channels);
    return MA_SUCCESS;
}

/* ---- volume and mixing, copying rather than in place ---- */

/* @binds ma_copy_and_apply_volume_factor_u8 */
int ma_shim_copy_and_apply_volume_factor_u8(
    void* out, const void* in, unsigned long long sample_count, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    ma_copy_and_apply_volume_factor_u8(
        (ma_uint8*)out, (const ma_uint8*)in, (ma_uint64)sample_count, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_s16 */
int ma_shim_copy_and_apply_volume_factor_s16(
    void* out, const void* in, unsigned long long sample_count, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    ma_copy_and_apply_volume_factor_s16(
        (ma_int16*)out, (const ma_int16*)in, (ma_uint64)sample_count, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_s24 */
int ma_shim_copy_and_apply_volume_factor_s24(
    void* out, const void* in, unsigned long long sample_count, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    ma_copy_and_apply_volume_factor_s24(
        (void*)out, (const void*)in, (ma_uint64)sample_count, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_s32 */
int ma_shim_copy_and_apply_volume_factor_s32(
    void* out, const void* in, unsigned long long sample_count, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    ma_copy_and_apply_volume_factor_s32(
        (ma_int32*)out, (const ma_int32*)in, (ma_uint64)sample_count, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_f32 */
int ma_shim_copy_and_apply_volume_factor_f32(
    void* out, const void* in, unsigned long long sample_count, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    ma_copy_and_apply_volume_factor_f32(
        (float*)out, (const float*)in, (ma_uint64)sample_count, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames_u8 */
int ma_shim_copy_and_apply_volume_factor_pcm_frames_u8(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames_u8(
        (ma_uint8*)out, (const ma_uint8*)in, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames_s16 */
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s16(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames_s16(
        (ma_int16*)out, (const ma_int16*)in, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames_s24 */
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s24(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames_s24(
        (void*)out, (const void*)in, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames_s32 */
int ma_shim_copy_and_apply_volume_factor_pcm_frames_s32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames_s32(
        (ma_int32*)out, (const ma_int32*)in, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames_f32 */
int ma_shim_copy_and_apply_volume_factor_pcm_frames_f32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames_f32(
        (float*)out, (const float*)in, (ma_uint64)frame_count, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_pcm_frames */
int ma_shim_copy_and_apply_volume_factor_pcm_frames(
    void* out, const void* in, unsigned long long frame_count, int format,
    unsigned int channels, float factor
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL);
    MA_SHIM_REQUIRE(format_ok(format) && channels_ok(channels));
    ma_copy_and_apply_volume_factor_pcm_frames(
        out, in, (ma_uint64)frame_count, (ma_format)format, (ma_uint32)channels, factor);
    return MA_SUCCESS;
}

/* @binds ma_copy_and_apply_volume_factor_per_channel_f32 */
int ma_shim_copy_and_apply_volume_factor_per_channel_f32(
    void* out, const void* in, unsigned long long frame_count, unsigned int channels,
    const void* channel_gains
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channel_gains != NULL);
    MA_SHIM_REQUIRE(channels_ok(channels));
    ma_copy_and_apply_volume_factor_per_channel_f32(
        (float*)out, (const float*)in, (ma_uint64)frame_count, (ma_uint32)channels,
        (float*)channel_gains);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination. */
/* @binds ma_copy_and_apply_volume_and_clip_samples_u8 */
int ma_shim_copy_and_apply_volume_and_clip_samples_u8(
    void* dst, const void* src, unsigned long long count, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL && fixed_volume_ok(volume));
    ma_copy_and_apply_volume_and_clip_samples_u8(
        (ma_uint8*)dst, (const ma_int16*)src, (ma_uint64)count, volume);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination. */
/* @binds ma_copy_and_apply_volume_and_clip_samples_s16 */
int ma_shim_copy_and_apply_volume_and_clip_samples_s16(
    void* dst, const void* src, unsigned long long count, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL && fixed_volume_ok(volume));
    ma_copy_and_apply_volume_and_clip_samples_s16(
        (ma_int16*)dst, (const ma_int32*)src, (ma_uint64)count, volume);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination. */
/* @binds ma_copy_and_apply_volume_and_clip_samples_s24 */
int ma_shim_copy_and_apply_volume_and_clip_samples_s24(
    void* dst, const void* src, unsigned long long count, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL && fixed_volume_ok(volume));
    ma_copy_and_apply_volume_and_clip_samples_s24(
        (ma_uint8*)dst, (const ma_int64*)src, (ma_uint64)count, volume);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination. */
/* @binds ma_copy_and_apply_volume_and_clip_samples_s32 */
int ma_shim_copy_and_apply_volume_and_clip_samples_s32(
    void* dst, const void* src, unsigned long long count, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL && fixed_volume_ok(volume));
    ma_copy_and_apply_volume_and_clip_samples_s32(
        (ma_int32*)dst, (const ma_int64*)src, (ma_uint64)count, volume);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination. */
/* @binds ma_copy_and_apply_volume_and_clip_samples_f32 */
int ma_shim_copy_and_apply_volume_and_clip_samples_f32(
    void* dst, const void* src, unsigned long long count, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL);
    ma_copy_and_apply_volume_and_clip_samples_f32(
        (float*)dst, (const float*)src, (ma_uint64)count, volume);
    return MA_SUCCESS;
}

/* Takes a wider source than its destination: u8 from s16, s16 from s32, s24 and
 * s32 from s64, f32 from f32. */
/* @binds ma_copy_and_apply_volume_and_clip_pcm_frames */
int ma_shim_copy_and_apply_volume_and_clip_pcm_frames(
    void* dst, const void* src, unsigned long long frame_count, int format,
    unsigned int channels, float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL);
    MA_SHIM_REQUIRE(format_ok(format) && channels_ok(channels));
    MA_SHIM_REQUIRE(format == (int)ma_format_f32 || fixed_volume_ok(volume));
    ma_copy_and_apply_volume_and_clip_pcm_frames(
        dst, src, (ma_uint64)frame_count, (ma_format)format, (ma_uint32)channels, volume);
    return MA_SUCCESS;
}

/* @binds ma_blend_f32 */
int ma_shim_blend_f32(
    void* out, const void* in_a, const void* in_b, float factor, unsigned int channels
) {
    MA_SHIM_REQUIRE(out != NULL && in_a != NULL && in_b != NULL && channels_ok(channels));
    ma_blend_f32((float*)out, (float*)in_a, (float*)in_b, factor, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_mix_pcm_frames_f32 */
int ma_shim_mix_pcm_frames_f32(
    void* dst, const void* src, unsigned long long frame_count, unsigned int channels,
    float volume
) {
    MA_SHIM_REQUIRE(dst != NULL && src != NULL && channels_ok(channels));
    return (int)ma_mix_pcm_frames_f32(
        (float*)dst, (const float*)src, (ma_uint64)frame_count, (ma_uint32)channels,
        volume);
}

/* @binds ma_volume_linear_to_db */
int ma_shim_volume_linear_to_db(float factor, float* out_db) {
    MA_SHIM_REQUIRE(out_db != NULL);
    *out_db = ma_volume_linear_to_db(factor);
    return MA_SUCCESS;
}

/* @binds ma_volume_db_to_linear */
int ma_shim_volume_db_to_linear(float gain, float* out_linear) {
    MA_SHIM_REQUIRE(out_linear != NULL);
    *out_linear = ma_volume_db_to_linear(gain);
    return MA_SUCCESS;
}

/* @binds ma_copy_string */
int ma_shim_copy_string(const char* src, char* out_text, unsigned int capacity) {
    char* duplicate;
    size_t length;

    MA_SHIM_REQUIRE(src != NULL && out_text != NULL && capacity > 0);
    out_text[0] = '\0';
    duplicate = ma_copy_string(src, NULL);
    if (duplicate == NULL) { return MA_OUT_OF_MEMORY; }

    length = strlen(duplicate);
    if (length >= (size_t)capacity) { ma_free(duplicate, NULL); return MA_NO_SPACE; }
    memcpy(out_text, duplicate, length + 1);
    /* miniaudio allocated it, so it is freed here rather than crossing over. */
    ma_free(duplicate, NULL);
    return MA_SUCCESS;
}
