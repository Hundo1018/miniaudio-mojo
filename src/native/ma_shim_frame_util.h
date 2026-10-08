#ifndef MA_SHIM_FRAME_UTIL_H
#define MA_SHIM_FRAME_UTIL_H

/* ---- PCM frame utilities ----
 *
 * miniaudio's format-dispatching frame helpers: interleave / deinterleave,
 * silence, pointer offsetting and the debug sine-wave fill. Nothing here owns
 * anything, so there are no handles: every entry point is a plain call on caller
 * memory.
 *
 * miniaudio validates none of it and indexes a table by `format`, so the shim
 * rejects NULL buffers, a `format` outside u8..f32, zero or more than
 * MA_MAX_CHANNELS channels, and a zero sample rate. It cannot see how long a
 * caller's buffer is, so frame counts are the caller's responsibility.
 *
 * Deinterleaving writes into one buffer per channel and interleaving reads from
 * one, so miniaudio takes an array of pointers. Mojo has no safe home for such an
 * array, so the shim builds it over a single flat buffer laid out channel after
 * channel: `channel_stride_in_bytes` says how far apart the planes are and must
 * be at least one plane long.
 *
 * `ma_offset_pcm_frames_ptr` returns a pointer; the shim hands it back through
 * `out_ptr`, which receives the address (a plain 64-bit value on this platform).
 *
 * Sample format codes match ma_format (u8=1 .. f32=5). s24 is packed, three
 * bytes per sample, little-endian. u8 silence is 128, not 0.
 */

#ifdef __cplusplus
extern "C" {
#endif

int ma_shim_interleave_pcm_frames(
    int format, unsigned int channels, unsigned long long frame_count,
    const void* planes_base, unsigned long long channel_stride_in_bytes,
    void* interleaved);
int ma_shim_deinterleave_pcm_frames(
    int format, unsigned int channels, unsigned long long frame_count,
    const void* interleaved,
    void* planes_base, unsigned long long channel_stride_in_bytes);

int ma_shim_silence_pcm_frames(
    void* frames, unsigned long long frame_count, int format, unsigned int channels);

int ma_shim_offset_pcm_frames_ptr(
    void* frames, unsigned long long offset_in_frames, int format,
    unsigned int channels, void** out_ptr);
int ma_shim_offset_pcm_frames_const_ptr(
    const void* frames, unsigned long long offset_in_frames, int format,
    unsigned int channels, const void** out_ptr);

/* Fills `frame_count` frames of `format` with a 400 Hz sine at full scale. */
int ma_shim_debug_fill_pcm_frames_with_sine_wave(
    void* frames, unsigned int frame_count, int format, unsigned int channels,
    unsigned int sample_rate);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_FRAME_UTIL_H */
