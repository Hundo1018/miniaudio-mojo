#include "ma_shim_flac.h"
#include "miniaudio.h"
#include "ma_shim_stream.h"

#include <stdlib.h>
#include <string.h>

/* ======================================================================== */
/* ma_flac                                                                    */
/* ======================================================================== */

/*
 * ma_flac and its function prototypes are defined only inside miniaudio's
 * implementation section, so they are not visible here. The functions are
 * still exported (nm -D lists them), so declare them locally with an opaque
 * object pointer; the ABI is identical to ma_flac*.
 */
MA_API ma_result ma_flac_init_file(
    const char* pFilePath, const ma_decoding_backend_config* pConfig,
    const ma_allocation_callbacks* pAllocationCallbacks, void* pWav);
MA_API ma_result ma_flac_init_memory(
    const void* pData, size_t dataSize, const ma_decoding_backend_config* pConfig,
    const ma_allocation_callbacks* pAllocationCallbacks, void* pWav);
MA_API ma_result ma_flac_init(
    ma_read_proc onRead, ma_seek_proc onSeek, ma_tell_proc onTell, void* pReadSeekTellUserData,
    const ma_decoding_backend_config* pConfig, const ma_allocation_callbacks* pAllocationCallbacks,
    void* pFlac);
MA_API void ma_flac_uninit(void* pWav, const ma_allocation_callbacks* pAllocationCallbacks);
MA_API ma_result ma_flac_read_pcm_frames(
    void* pWav, void* pFramesOut, ma_uint64 frameCount, ma_uint64* pFramesRead);
MA_API ma_result ma_flac_seek_to_pcm_frame(void* pWav, ma_uint64 frameIndex);
MA_API ma_result ma_flac_get_data_format(
    void* pWav, ma_format* pFormat, ma_uint32* pChannels, ma_uint32* pSampleRate,
    ma_channel* pChannelMap, size_t channelMapCap);
MA_API ma_result ma_flac_get_cursor_in_pcm_frames(void* pWav, ma_uint64* pCursor);
MA_API ma_result ma_flac_get_length_in_pcm_frames(void* pWav, ma_uint64* pLength);

typedef struct ma_shim_flac {
    int initialized;
    shimint_stream stream; /* user-supplied I/O (init_stream); zeroed otherwise */
    union {
        max_align_t   align;
        unsigned char bytes[MA_SHIM_FLAC_STORAGE_BYTES];
    } flac; /* holds the ma_flac; see the layout guard */
} ma_shim_flac;

static ma_shim_flac* flac_ready(void* handle) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

/* Uninitialise the codec, if it is initialised. A user-supplied stream is left
 * alone: it stays reachable until the handle is freed or re-initialised. */
static void flac_uninit_object(ma_shim_flac* h) {
    if (h->initialized) {
        ma_flac_uninit(h->flac.bytes, NULL);
        h->initialized = 0;
    }
}

/* Full reset, for free and re-init: uninitialise, then release a user-supplied
 * stream (its destroy callback runs strictly after ma_flac_uninit, exactly
 * once). */
static void flac_teardown(ma_shim_flac* h) {
    flac_uninit_object(h);
    shimint_stream_release(&h->stream);
}

static ma_result flac_make_config(
    int preferred_format, unsigned int seek_point_count, ma_decoding_backend_config* out
) {
    if (preferred_format < 0 || preferred_format >= ma_format_count) {
        return MA_INVALID_ARGS;
    }
    *out = ma_decoding_backend_config_init((ma_format)preferred_format, seek_point_count);
    return MA_SUCCESS;
}

void* ma_shim_flac_alloc(void) {
    return calloc(1, sizeof(ma_shim_flac));
}

/* @binds ma_flac_uninit */
void ma_shim_flac_free(void* handle) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    if (h == NULL) {
        return;
    }
    flac_teardown(h);
    free(h);
}

/* @binds ma_flac_init_file, ma_decoding_backend_config_init */
int ma_shim_flac_init_file(
    void*        handle,
    const char*  file_path,
    int          preferred_format,
    unsigned int seek_point_count
) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    ma_decoding_backend_config config;
    ma_result result;

    if (h == NULL || file_path == NULL) {
        return MA_INVALID_ARGS;
    }
    result = flac_make_config(preferred_format, seek_point_count, &config);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    flac_teardown(h);
    result = ma_flac_init_file(file_path, &config, NULL, h->flac.bytes);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_flac_init_memory, ma_decoding_backend_config_init */
int ma_shim_flac_init_memory(
    void*        handle,
    const void*  data,
    size_t       data_size,
    int          preferred_format,
    unsigned int seek_point_count
) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    ma_decoding_backend_config config;
    ma_result result;

    if (h == NULL || data == NULL || data_size == 0) {
        return MA_INVALID_ARGS;
    }
    result = flac_make_config(preferred_format, seek_point_count, &config);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    flac_teardown(h);
    result = ma_flac_init_memory(data, data_size, &config, NULL, h->flac.bytes);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* The user stream's callbacks, adapted to miniaudio's ma_read_proc / ma_seek_proc /
 * ma_tell_proc: miniaudio hands back the user pointer it was given, which here is
 * the shim handle that carries the stream. */
static ma_result flac_stream_on_read(void* pUserData, void* pBufferOut, size_t bytesToRead, size_t* pBytesRead) {
    ma_shim_flac* h = (ma_shim_flac*)pUserData;
    size_t bytes_read = 0;
    int result = h->stream.read(h->stream.user, pBufferOut, bytesToRead, &bytes_read);
    if (pBytesRead != NULL) {
        *pBytesRead = bytes_read;
    }
    return (ma_result)result;
}

static ma_result flac_stream_on_seek(void* pUserData, ma_int64 offset, ma_seek_origin origin) {
    ma_shim_flac* h = (ma_shim_flac*)pUserData;
    return (ma_result)h->stream.seek(h->stream.user, (long long)offset, (int)origin);
}

static ma_result flac_stream_on_tell(void* pUserData, ma_int64* pCursor) {
    ma_shim_flac* h = (ma_shim_flac*)pUserData;
    long long cursor = 0;
    int result = h->stream.tell(h->stream.user, &cursor);
    *pCursor = (ma_int64)cursor;
    return (ma_result)result;
}

/* @binds ma_flac_init, ma_decoding_backend_config_init */
int ma_shim_flac_init_stream(
    void*                     handle,
    ma_shim_stream_read_fn    on_read,
    ma_shim_stream_seek_fn    on_seek,
    ma_shim_stream_tell_fn    on_tell,
    ma_shim_stream_destroy_fn on_destroy,
    void*                     user,
    unsigned long long        type_tag,
    int                       preferred_format,
    unsigned int              seek_point_count
) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    shimint_stream incoming;
    ma_decoding_backend_config config;
    ma_result result = MA_INVALID_ARGS;

    memset(&incoming, 0, sizeof(incoming));
    incoming.read = on_read;
    incoming.seek = on_seek;
    incoming.tell = on_tell;
    incoming.destroy = on_destroy;
    incoming.user = user;
    incoming.type_tag = type_tag;

    if (h != NULL && on_read != NULL && on_seek != NULL && on_tell != NULL && user != NULL) {
        result = flac_make_config(preferred_format, seek_point_count, &config);
    }
    if (result != MA_SUCCESS) {
        shimint_stream_release(&incoming);
        return (int)result;
    }
    flac_teardown(h);
    h->stream = incoming;
    result = ma_flac_init(
        flac_stream_on_read, flac_stream_on_seek, flac_stream_on_tell, h, &config, NULL, h->flac.bytes);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    } else {
        shimint_stream_release(&h->stream);
    }
    return (int)result;
}

void* ma_shim_flac_stream_user(void* handle, unsigned long long type_tag) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    if (h == NULL) {
        return NULL;
    }
    return shimint_stream_user(&h->stream, type_tag);
}

/* @binds ma_flac_uninit */
int ma_shim_flac_uninit(void* handle) {
    ma_shim_flac* h = (ma_shim_flac*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    flac_uninit_object(h);
    return MA_SUCCESS;
}

/* @binds ma_flac_read_pcm_frames, ma_flac_get_data_format */
int ma_shim_flac_read_pcm_frames(
    void*               handle,
    void*               out,
    unsigned long long  out_capacity_bytes,
    unsigned long long  frame_count,
    unsigned long long* out_frames_read
) {
    ma_shim_flac* h = flac_ready(handle);
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint64 bytes_per_frame;
    ma_uint64 frames_read = 0;
    ma_result result;

    if (out_frames_read != NULL) {
        *out_frames_read = 0;
    }
    if (h == NULL || out == NULL) {
        return MA_INVALID_ARGS;
    }
    /* miniaudio cannot know the buffer size: refuse a read that would overflow.
     * (An initialised handle always reports a format; unknown -> 0 bytes -> refused.) */
    (void)ma_flac_get_data_format(h->flac.bytes, &format, &channels, NULL, NULL, 0);
    bytes_per_frame = ma_get_bytes_per_frame(format, channels);
    if (bytes_per_frame == 0 || frame_count > out_capacity_bytes / bytes_per_frame) {
        return MA_INVALID_ARGS;
    }
    result = ma_flac_read_pcm_frames(h->flac.bytes, out, frame_count, &frames_read);
    if (out_frames_read != NULL) {
        *out_frames_read = frames_read;
    }
    return (int)result;
}

/* @binds ma_flac_seek_to_pcm_frame */
int ma_shim_flac_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_shim_flac* h = flac_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_flac_seek_to_pcm_frame(h->flac.bytes, frame_index);
}

/* @binds ma_flac_get_data_format */
int ma_shim_flac_get_data_format(
    void*          handle,
    int*           out_format,
    unsigned int*  out_channels,
    unsigned int*  out_sample_rate,
    unsigned char* out_channel_map,
    unsigned int   channel_map_capacity
) {
    ma_shim_flac* h = flac_ready(handle);
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    ma_result result;

    if (out_format != NULL) { *out_format = 0; }
    if (out_channels != NULL) { *out_channels = 0; }
    if (out_sample_rate != NULL) { *out_sample_rate = 0; }
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_flac_get_data_format(
        h->flac.bytes, &format, &channels, &sample_rate,
        (ma_channel*)out_channel_map, out_channel_map != NULL ? (size_t)channel_map_capacity : 0);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (out_format != NULL) { *out_format = (int)format; }
    if (out_channels != NULL) { *out_channels = (unsigned int)channels; }
    if (out_sample_rate != NULL) { *out_sample_rate = (unsigned int)sample_rate; }
    return MA_SUCCESS;
}

/* @binds ma_flac_get_cursor_in_pcm_frames */
int ma_shim_flac_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor) {
    ma_shim_flac* h = flac_ready(handle);
    ma_uint64 cursor = 0;
    ma_result result;

    if (out_cursor != NULL) {
        *out_cursor = 0;
    }
    if (h == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_flac_get_cursor_in_pcm_frames(h->flac.bytes, &cursor);
    *out_cursor = cursor;
    return (int)result;
}

/* @binds ma_flac_get_length_in_pcm_frames */
int ma_shim_flac_get_length_in_pcm_frames(void* handle, unsigned long long* out_length) {
    ma_shim_flac* h = flac_ready(handle);
    ma_uint64 length = 0;
    ma_result result;

    if (out_length != NULL) {
        *out_length = 0;
    }
    if (h == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_flac_get_length_in_pcm_frames(h->flac.bytes, &length);
    *out_length = length;
    return (int)result;
}
