#include "ma_shim_decode_util.h"
#include "miniaudio.h"

/*
 * Defined in ma_shim_context.c: resolves a Vfs handle (ma_shim_vfs_alloc +
 * ma_shim_vfs_init) to its ma_vfs*, or NULL if the handle is null or not yet
 * initialised. Declared here rather than in ma_shim_internal.h to keep this
 * family's footprint out of the shared header.
 */
ma_vfs* shimint_vfs_ptr(void* vfs_handle);

static ma_result decode_make_config(
    int format, unsigned int channels, unsigned int sample_rate, ma_decoder_config* out
) {
    if (format < 0 || format >= ma_format_count) {
        return MA_INVALID_ARGS;
    }
    *out = ma_decoder_config_init((ma_format)format, channels, sample_rate);
    return MA_SUCCESS;
}

/* On success publishes the buffer and the resolved output description; on failure
 * leaves the outputs at the values decode_reset gave them (frames NULL). */
static int decode_finish(
    ma_result                 result,
    const ma_decoder_config*  config,
    ma_uint64                 frame_count,
    void*                     frames,
    unsigned long long*       out_frame_count,
    void**                    out_frames,
    int*                      out_format,
    unsigned int*             out_channels,
    unsigned int*             out_sample_rate
) {
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    *out_frame_count = (unsigned long long)frame_count;
    *out_frames = frames;
    if (out_format != NULL) { *out_format = (int)config->format; }
    if (out_channels != NULL) { *out_channels = (unsigned int)config->channels; }
    if (out_sample_rate != NULL) { *out_sample_rate = (unsigned int)config->sampleRate; }
    return MA_SUCCESS;
}

/* Clears the outputs before any work so every error path leaves them defined. */
static void decode_reset(
    unsigned long long* out_frame_count,
    void**              out_frames,
    int*                out_format,
    unsigned int*       out_channels,
    unsigned int*       out_sample_rate
) {
    if (out_frame_count != NULL) { *out_frame_count = 0; }
    if (out_frames != NULL) { *out_frames = NULL; }
    if (out_format != NULL) { *out_format = 0; }
    if (out_channels != NULL) { *out_channels = 0; }
    if (out_sample_rate != NULL) { *out_sample_rate = 0; }
}

/* @binds ma_decoding_backend_config_init */
int ma_shim_decoding_backend_config_init(
    int           preferred_format,
    unsigned int  seek_point_count,
    int*          out_preferred_format,
    unsigned int* out_seek_point_count
) {
    ma_decoding_backend_config config;

    if (out_preferred_format != NULL) { *out_preferred_format = 0; }
    if (out_seek_point_count != NULL) { *out_seek_point_count = 0; }
    if (preferred_format < 0 || preferred_format >= ma_format_count) {
        return MA_INVALID_ARGS;
    }
    config = ma_decoding_backend_config_init((ma_format)preferred_format, seek_point_count);
    if (out_preferred_format != NULL) { *out_preferred_format = (int)config.preferredFormat; }
    if (out_seek_point_count != NULL) { *out_seek_point_count = (unsigned int)config.seekPointCount; }
    return MA_SUCCESS;
}

/* @binds ma_decode_file, ma_decoder_config_init */
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
) {
    ma_decoder_config config;
    ma_uint64 frame_count = 0;
    void* frames = NULL;
    ma_result result;

    decode_reset(out_frame_count, out_frames, out_format, out_channels, out_sample_rate);
    if (file_path == NULL || out_frame_count == NULL || out_frames == NULL) {
        return MA_INVALID_ARGS;
    }
    result = decode_make_config(format, channels, sample_rate, &config);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    result = ma_decode_file(file_path, &config, &frame_count, &frames);
    return decode_finish(result, &config, frame_count, frames, out_frame_count, out_frames,
                         out_format, out_channels, out_sample_rate);
}

/* @binds ma_decode_memory, ma_decoder_config_init */
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
) {
    ma_decoder_config config;
    ma_uint64 frame_count = 0;
    void* frames = NULL;
    ma_result result;

    decode_reset(out_frame_count, out_frames, out_format, out_channels, out_sample_rate);
    if (data == NULL || data_size == 0 || out_frame_count == NULL || out_frames == NULL) {
        return MA_INVALID_ARGS;
    }
    result = decode_make_config(format, channels, sample_rate, &config);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    result = ma_decode_memory(data, data_size, &config, &frame_count, &frames);
    return decode_finish(result, &config, frame_count, frames, out_frame_count, out_frames,
                         out_format, out_channels, out_sample_rate);
}

/* @binds ma_decode_from_vfs, ma_decoder_config_init */
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
) {
    ma_decoder_config config;
    ma_vfs* vfs = NULL;
    ma_uint64 frame_count = 0;
    void* frames = NULL;
    ma_result result;

    decode_reset(out_frame_count, out_frames, out_format, out_channels, out_sample_rate);
    if (file_path == NULL || out_frame_count == NULL || out_frames == NULL) {
        return MA_INVALID_ARGS;
    }
    if (vfs_handle != NULL) {
        vfs = shimint_vfs_ptr(vfs_handle);
        if (vfs == NULL) {
            return MA_INVALID_ARGS; /* handle not initialised */
        }
    }
    result = decode_make_config(format, channels, sample_rate, &config);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    result = ma_decode_from_vfs(vfs, file_path, &config, &frame_count, &frames);
    return decode_finish(result, &config, frame_count, frames, out_frame_count, out_frames,
                         out_format, out_channels, out_sample_rate);
}

void ma_shim_decode_free(void* frames) {
    ma_free(frames, NULL);
}
