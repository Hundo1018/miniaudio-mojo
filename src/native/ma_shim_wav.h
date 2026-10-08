#ifndef MA_SHIM_WAV_H
#define MA_SHIM_WAV_H

/* ---- ma_wav: miniaudio's built-in WAV decoder backend (opaque handle) ----
 *
 * ma_wav is a standalone data source: it opens a WAV from a file path or a
 * caller-owned memory block and reads/seeks PCM frames without going through
 * ma_decoder (so no output conversion: the data comes back in the codec's own
 * channel count and sample rate, in either the file's native sample format or
 * the `preferred_format` the caller asks for).
 *
 * ma_wav (like ma_flac and ma_mp3) is defined only inside miniaudio's
 * implementation section, so the shim cannot take sizeof() it. The handle
 * therefore embeds fixed-size aligned storage; the layout guard
 * tools/check_codec_layout.c (pixi run check-codec-layout) fails the build if
 * miniaudio ever outgrows MA_SHIM_WAV_STORAGE_BYTES.
 *
 * preferred_format is an ma_format code: 0 (unknown) keeps the file's native
 * format; f32 (5), s16 (2) and s32 (4) are honoured; any other valid ma_format
 * is silently ignored by miniaudio (native format kept); a code outside the
 * enum is rejected with MA_INVALID_ARGS. Memory init does not copy: the caller
 * must keep the buffer alive until uninit.
 *
 * Every entry point returns a ma_result code; getters write through out
 * pointers so an uninitialised handle is observable as MA_INVALID_ARGS.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* sizeof(ma_wav) is 520 on linux-64 / miniaudio 0.11.25. */
#define MA_SHIM_WAV_STORAGE_BYTES 1024

void* ma_shim_wav_alloc(void);
void  ma_shim_wav_free(void* handle);

int ma_shim_wav_init_file(
    void*        handle,
    const char*  file_path,
    int          preferred_format,
    unsigned int seek_point_count
);
int ma_shim_wav_init_memory(
    void*        handle,
    const void*  data,
    size_t       data_size,
    int          preferred_format,
    unsigned int seek_point_count
);
int ma_shim_wav_uninit(void* handle);

/* Reads up to frame_count frames into `out`, which is out_capacity_bytes long.
 * The shim rejects a request that would overflow the buffer (miniaudio does not
 * know its size). Returns MA_AT_END once the stream is exhausted. */
int ma_shim_wav_read_pcm_frames(
    void*               handle,
    void*               out,
    unsigned long long  out_capacity_bytes,
    unsigned long long  frame_count,
    unsigned long long* out_frames_read
);
int ma_shim_wav_seek_to_pcm_frame(void* handle, unsigned long long frame_index);

/* out_channel_map may be NULL (channel_map_capacity is then ignored). */
int ma_shim_wav_get_data_format(
    void*          handle,
    int*           out_format,
    unsigned int*  out_channels,
    unsigned int*  out_sample_rate,
    unsigned char* out_channel_map,
    unsigned int   channel_map_capacity
);
int ma_shim_wav_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);
int ma_shim_wav_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_WAV_H */
