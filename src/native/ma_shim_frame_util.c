#include "ma_shim_frame_util.h"
#include "miniaudio.h"

/* Exported by miniaudio but declared only inside its implementation section. The
 * first parameter is really a buffer of `format` samples; miniaudio spells it
 * float*. */
MA_API void ma_debug_fill_pcm_frames_with_sine_wave(
    float* pFramesOut, ma_uint32 frameCount, ma_format format, ma_uint32 channels,
    ma_uint32 sampleRate);

#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

/* miniaudio indexes a table by format without checking. */
static int format_ok(int format) {
    return format >= (int)ma_format_u8 && format <= (int)ma_format_f32;
}

static int channels_ok(unsigned int channels) {
    return channels >= 1 && channels <= MA_MAX_CHANNELS;
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
    int format
) {
    unsigned int c;
    unsigned int bytes_per_sample;
    if (!format_ok(format) || !channels_ok(channels)) { return 0; }
    bytes_per_sample = ma_get_bytes_per_sample((ma_format)format);
    if (frame_count > channel_stride_in_bytes / bytes_per_sample) { return 0; }
    for (c = 0; c < channels; c += 1) {
        planes[c] = (unsigned char*)base + (size_t)((unsigned long long)c * channel_stride_in_bytes);
    }
    return 1;
}

/* @binds ma_interleave_pcm_frames */
int ma_shim_interleave_pcm_frames(
    int format, unsigned int channels, unsigned long long frame_count,
    const void* planes_base, unsigned long long channel_stride_in_bytes,
    void* interleaved
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(planes_base != NULL && interleaved != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, (void*)planes_base, channels, channel_stride_in_bytes, frame_count, format));
    ma_interleave_pcm_frames(
        (ma_format)format, (ma_uint32)channels, (ma_uint64)frame_count,
        (const void**)planes, interleaved);
    return MA_SUCCESS;
}

/* @binds ma_deinterleave_pcm_frames */
int ma_shim_deinterleave_pcm_frames(
    int format, unsigned int channels, unsigned long long frame_count,
    const void* interleaved,
    void* planes_base, unsigned long long channel_stride_in_bytes
) {
    void* planes[MA_MAX_CHANNELS];
    MA_SHIM_REQUIRE(interleaved != NULL && planes_base != NULL);
    MA_SHIM_REQUIRE(build_planes(
        planes, planes_base, channels, channel_stride_in_bytes, frame_count, format));
    ma_deinterleave_pcm_frames(
        (ma_format)format, (ma_uint32)channels, (ma_uint64)frame_count,
        interleaved, planes);
    return MA_SUCCESS;
}

/* @binds ma_silence_pcm_frames */
int ma_shim_silence_pcm_frames(
    void* frames, unsigned long long frame_count, int format, unsigned int channels
) {
    MA_SHIM_REQUIRE(frames != NULL && format_ok(format) && channels_ok(channels));
    ma_silence_pcm_frames(frames, (ma_uint64)frame_count, (ma_format)format,
                          (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_offset_pcm_frames_ptr */
int ma_shim_offset_pcm_frames_ptr(
    void* frames, unsigned long long offset_in_frames, int format,
    unsigned int channels, void** out_ptr
) {
    if (out_ptr != NULL) { *out_ptr = NULL; }
    MA_SHIM_REQUIRE(frames != NULL && out_ptr != NULL);
    MA_SHIM_REQUIRE(format_ok(format) && channels_ok(channels));
    *out_ptr = ma_offset_pcm_frames_ptr(
        frames, (ma_uint64)offset_in_frames, (ma_format)format, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_offset_pcm_frames_const_ptr */
int ma_shim_offset_pcm_frames_const_ptr(
    const void* frames, unsigned long long offset_in_frames, int format,
    unsigned int channels, const void** out_ptr
) {
    if (out_ptr != NULL) { *out_ptr = NULL; }
    MA_SHIM_REQUIRE(frames != NULL && out_ptr != NULL);
    MA_SHIM_REQUIRE(format_ok(format) && channels_ok(channels));
    *out_ptr = ma_offset_pcm_frames_const_ptr(
        frames, (ma_uint64)offset_in_frames, (ma_format)format, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_debug_fill_pcm_frames_with_sine_wave */
int ma_shim_debug_fill_pcm_frames_with_sine_wave(
    void* frames, unsigned int frame_count, int format, unsigned int channels,
    unsigned int sample_rate
) {
    MA_SHIM_REQUIRE(frames != NULL && format_ok(format) && channels_ok(channels));
    MA_SHIM_REQUIRE(sample_rate > 0);
    ma_debug_fill_pcm_frames_with_sine_wave(
        (float*)frames, (ma_uint32)frame_count, (ma_format)format, (ma_uint32)channels,
        (ma_uint32)sample_rate);
    return MA_SUCCESS;
}
