#ifndef MA_SHIM_DECODE_UTIL_H
#define MA_SHIM_DECODE_UTIL_H

/* ---- one-shot decode helpers + decoding-backend config ----
 *
 * ma_decode_file / ma_decode_memory / ma_decode_from_vfs decode a whole
 * stream in one call and hand back a buffer that miniaudio allocated with its
 * own allocator. The shim owns that buffer's release: every successful decode
 * must be paired with ma_shim_decode_free (the Mojo API wraps this in an RAII
 * type). A failed decode returns MA_* and leaves *out_frames NULL.
 *
 * `format` is an ma_format code and `channels` / `sample_rate` are the wanted
 * output; 0 for any of them keeps the stream's native value. The out_format /
 * out_channels / out_sample_rate parameters report what the buffer actually
 * holds (miniaudio writes it back into the config), so the caller can size and
 * interpret it. out_frame_count counts frames, not samples.
 *
 * ma_shim_decode_from_vfs takes the handle of an initialised Vfs (the context
 * family's ma_shim_vfs_alloc + ma_shim_vfs_init), or NULL for miniaudio's
 * default stdio file system.
 *
 * ma_shim_decoding_backend_config_init validates and echoes the two fields of
 * the by-value ma_decoding_backend_config miniaudio returns; the built-in
 * wav / flac / mp3 backends build the same struct from their init arguments.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int ma_shim_decoding_backend_config_init(
    int           preferred_format,
    unsigned int  seek_point_count,
    int*          out_preferred_format,
    unsigned int* out_seek_point_count
);

int ma_shim_decode_file(
    const char*         file_path,
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate,
    unsigned long long* out_frame_count,
    void**              out_frames,
    int*                out_format,
    unsigned int*       out_channels,
    unsigned int*       out_sample_rate
);
int ma_shim_decode_memory(
    const void*         data,
    size_t              data_size,
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate,
    unsigned long long* out_frame_count,
    void**              out_frames,
    int*                out_format,
    unsigned int*       out_channels,
    unsigned int*       out_sample_rate
);
int ma_shim_decode_from_vfs(
    void*               vfs_handle,
    const char*         file_path,
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate,
    unsigned long long* out_frame_count,
    void**              out_frames,
    int*                out_format,
    unsigned int*       out_channels,
    unsigned int*       out_sample_rate
);

/* Releases a buffer returned by one of the decode calls. NULL is a no-op. */
void ma_shim_decode_free(void* frames);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_DECODE_UTIL_H */
