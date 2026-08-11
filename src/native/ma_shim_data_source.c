#include "ma_shim_data_source.h"
#include "ma_shim_internal.h"

#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* Bookkeeping wrapper. `base` MUST stay first: every ma_data_source_* call
 * casts the handle straight to ma_data_source*, and the chaining getters
 * compare handle pointers against ma_data_source pointers. */
typedef struct ma_shim_data_source {
    ma_data_source_base base;
    float*       frames;        /* shim-owned copy of the caller's samples */
    ma_uint64    frame_count;
    ma_uint32    channels;
    ma_uint32    sample_rate;
    ma_format    format;
    ma_uint64    cursor;
    int          looping;
    ma_data_source* callback_next; /* what the shim-owned onGetNext returns */
    int          initialized;
} ma_shim_data_source;

typedef struct ma_shim_data_source_node {
    ma_data_source_node node;
    int initialized;
} ma_shim_data_source_node;

/* ---- shim-owned vtable ---------------------------------------------------- */

static ma_result shimds_on_read(
    ma_data_source* pDataSource,
    void* pFramesOut,
    ma_uint64 frameCount,
    ma_uint64* pFramesRead
) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;
    ma_uint64 frames_remaining;
    ma_uint64 frames_to_read;

    if (h == NULL || pFramesRead == NULL) {
        return MA_INVALID_ARGS;
    }

    *pFramesRead = 0;

    if (!h->initialized) {
        return MA_INVALID_ARGS;
    }
    if (frameCount == 0) {
        return MA_SUCCESS;
    }
    if (h->cursor >= h->frame_count) {
        return MA_AT_END;
    }

    frames_remaining = h->frame_count - h->cursor;
    frames_to_read = (frameCount < frames_remaining) ? frameCount : frames_remaining;

    if (pFramesOut != NULL && h->frames != NULL) {
        memcpy(
            pFramesOut,
            h->frames + (h->cursor * (ma_uint64)h->channels),
            (size_t)(frames_to_read * (ma_uint64)h->channels) * sizeof(float)
        );
    }

    h->cursor += frames_to_read;
    *pFramesRead = frames_to_read;

    return (frames_to_read == frameCount) ? MA_SUCCESS : MA_AT_END;
}

static ma_result shimds_on_seek(ma_data_source* pDataSource, ma_uint64 frameIndex) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;

    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    if (frameIndex > h->frame_count) {
        return MA_INVALID_ARGS;
    }

    h->cursor = frameIndex;
    return MA_SUCCESS;
}

static ma_result shimds_on_get_data_format(
    ma_data_source* pDataSource,
    ma_format* pFormat,
    ma_uint32* pChannels,
    ma_uint32* pSampleRate,
    ma_channel* pChannelMap,
    size_t channelMapCap
) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;

    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }

    if (pFormat != NULL) {
        *pFormat = h->format;
    }
    if (pChannels != NULL) {
        *pChannels = h->channels;
    }
    if (pSampleRate != NULL) {
        *pSampleRate = h->sample_rate;
    }
    if (pChannelMap != NULL && channelMapCap > 0) {
        ma_channel_map_init_standard(
            ma_standard_channel_map_default,
            pChannelMap,
            channelMapCap,
            h->channels
        );
    }

    return MA_SUCCESS;
}

static ma_result shimds_on_get_cursor(ma_data_source* pDataSource, ma_uint64* pCursor) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;

    if (h == NULL || pCursor == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }

    *pCursor = h->cursor;
    return MA_SUCCESS;
}

static ma_result shimds_on_get_length(ma_data_source* pDataSource, ma_uint64* pLength) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;

    if (h == NULL || pLength == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }

    *pLength = h->frame_count;
    return MA_SUCCESS;
}

static ma_result shimds_on_set_looping(ma_data_source* pDataSource, ma_bool32 isLooping) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;

    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }

    h->looping = (isLooping != MA_FALSE) ? 1 : 0;
    return MA_SUCCESS;
}

static const ma_data_source_vtable g_shimds_vtable = {
    shimds_on_read,
    shimds_on_seek,
    shimds_on_get_data_format,
    shimds_on_get_cursor,
    shimds_on_get_length,
    shimds_on_set_looping,
    0
};

/* The shim-owned next callback. Returns whatever handle was registered via
 * ma_shim_data_source_set_next_callback. */
static ma_data_source* shimds_on_get_next(ma_data_source* pDataSource) {
    ma_shim_data_source* h = (ma_shim_data_source*)pDataSource;
    if (h == NULL) {
        return NULL;
    }
    return h->callback_next;
}

/* ---- helpers -------------------------------------------------------------- */

/* Resolve a handle to its ma_data_source*, or NULL if null/uninitialised. */
static ma_data_source* shimds_ptr(void* handle) {
    ma_shim_data_source* h = (ma_shim_data_source*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return (ma_data_source*)&h->base;
}

static void shimds_release_buffer(ma_shim_data_source* h) {
    if (h->frames != NULL) {
        free(h->frames);
        h->frames = NULL;
    }
    h->frame_count = 0;
}

/* ---- lifecycle ------------------------------------------------------------ */

void* ma_shim_data_source_alloc(void) {
    return calloc(1, sizeof(ma_shim_data_source));
}

/* @binds ma_data_source_uninit */
void ma_shim_data_source_free(void* handle) {
    ma_shim_data_source* h = (ma_shim_data_source*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_data_source_uninit((ma_data_source*)&h->base);
        h->initialized = 0;
    }
    shimds_release_buffer(h);
    free(h);
}

/* @binds ma_data_source_config_init, ma_data_source_init */
int ma_shim_data_source_init_buffer(
    void* handle,
    const float* frames,
    unsigned long long frame_count,
    unsigned int channels,
    unsigned int sample_rate
) {
    ma_shim_data_source* h = (ma_shim_data_source*)handle;
    ma_data_source_config config;
    ma_result result;
    size_t sample_bytes;

    if (h == NULL || frames == NULL || frame_count == 0 || channels == 0 || sample_rate == 0) {
        return MA_INVALID_ARGS;
    }

    if (h->initialized) {
        ma_data_source_uninit((ma_data_source*)&h->base);
        h->initialized = 0;
    }
    shimds_release_buffer(h);

    config = ma_data_source_config_init();
    config.vtable = &g_shimds_vtable;
    result = ma_data_source_init(&config, (ma_data_source*)&h->base);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    /* Own a copy so the caller's Mojo buffer need not outlive the source. */
    sample_bytes = (size_t)(frame_count * (ma_uint64)channels) * sizeof(float);
    h->frames = (float*)malloc(sample_bytes);
    if (h->frames == NULL) {
        ma_data_source_uninit((ma_data_source*)&h->base);
        return MA_OUT_OF_MEMORY;
    }
    memcpy(h->frames, frames, sample_bytes);

    h->frame_count   = (ma_uint64)frame_count;
    h->channels      = (ma_uint32)channels;
    h->sample_rate   = (ma_uint32)sample_rate;
    h->format        = ma_format_f32;
    h->cursor        = 0;
    h->looping       = 0;
    h->callback_next = NULL;
    h->initialized   = 1;

    return MA_SUCCESS;
}

/* @binds ma_data_source_uninit */
int ma_shim_data_source_uninit(void* handle) {
    ma_shim_data_source* h = (ma_shim_data_source*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_data_source_uninit((ma_data_source*)&h->base);
    shimds_release_buffer(h);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* ---- read / seek ---------------------------------------------------------- */

/* @binds ma_data_source_read_pcm_frames */
int ma_shim_data_source_read_pcm_frames(
    void* handle,
    void* output,
    unsigned long long frame_count,
    unsigned long long* frames_read
) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 read = 0;
    ma_result result;

    if (frames_read != NULL) {
        *frames_read = 0;
    }
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_read_pcm_frames(ds, output, (ma_uint64)frame_count, &read);
    if (frames_read != NULL) {
        *frames_read = (unsigned long long)read;
    }
    return (int)result;
}

/* @binds ma_data_source_seek_pcm_frames */
int ma_shim_data_source_seek_pcm_frames(
    void* handle,
    unsigned long long frame_count,
    unsigned long long* frames_seeked
) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 seeked = 0;
    ma_result result;

    if (frames_seeked != NULL) {
        *frames_seeked = 0;
    }
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_seek_pcm_frames(ds, (ma_uint64)frame_count, &seeked);
    if (frames_seeked != NULL) {
        *frames_seeked = (unsigned long long)seeked;
    }
    return (int)result;
}

/* @binds ma_data_source_seek_to_pcm_frame */
int ma_shim_data_source_seek_to_pcm_frame(void* handle, unsigned long long frame_index) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_seek_to_pcm_frame(ds, (ma_uint64)frame_index);
}

/* @binds ma_data_source_seek_seconds */
int ma_shim_data_source_seek_seconds(
    void* handle,
    float second_count,
    float* seconds_seeked
) {
    ma_data_source* ds = shimds_ptr(handle);
    float seeked = 0.0f;
    ma_result result;

    if (seconds_seeked != NULL) {
        *seconds_seeked = 0.0f;
    }
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_seek_seconds(ds, second_count, &seeked);
    if (seconds_seeked != NULL) {
        *seconds_seeked = seeked;
    }
    return (int)result;
}

/* @binds ma_data_source_seek_to_second */
int ma_shim_data_source_seek_to_second(void* handle, float seek_point_in_seconds) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_seek_to_second(ds, seek_point_in_seconds);
}

/* ---- queries -------------------------------------------------------------- */

/* @binds ma_data_source_get_data_format */
int ma_shim_data_source_get_data_format(
    void* handle,
    int* out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_format format = ma_format_unknown;
    ma_uint32 channels = 0;
    ma_uint32 sample_rate = 0;
    ma_result result;

    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_get_data_format(ds, &format, &channels, &sample_rate, NULL, 0);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    if (out_format != NULL) {
        *out_format = (int)format;
    }
    if (out_channels != NULL) {
        *out_channels = (unsigned int)channels;
    }
    if (out_sample_rate != NULL) {
        *out_sample_rate = (unsigned int)sample_rate;
    }
    return MA_SUCCESS;
}

/* @binds ma_data_source_get_cursor_in_pcm_frames */
int ma_shim_data_source_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 cursor = 0;
    ma_result result;

    if (out_cursor != NULL) {
        *out_cursor = 0;
    }
    if (ds == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_get_cursor_in_pcm_frames(ds, &cursor);
    if (result == MA_SUCCESS) {
        *out_cursor = (unsigned long long)cursor;
    }
    return (int)result;
}

/* @binds ma_data_source_get_length_in_pcm_frames */
int ma_shim_data_source_get_length_in_pcm_frames(void* handle, unsigned long long* out_length) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 length = 0;
    ma_result result;

    if (out_length != NULL) {
        *out_length = 0;
    }
    if (ds == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_get_length_in_pcm_frames(ds, &length);
    if (result == MA_SUCCESS) {
        *out_length = (unsigned long long)length;
    }
    return (int)result;
}

/* @binds ma_data_source_get_cursor_in_seconds */
int ma_shim_data_source_get_cursor_in_seconds(void* handle, float* out_cursor) {
    ma_data_source* ds = shimds_ptr(handle);
    float cursor = 0.0f;
    ma_result result;

    if (out_cursor != NULL) {
        *out_cursor = 0.0f;
    }
    if (ds == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_get_cursor_in_seconds(ds, &cursor);
    if (result == MA_SUCCESS) {
        *out_cursor = cursor;
    }
    return (int)result;
}

/* @binds ma_data_source_get_length_in_seconds */
int ma_shim_data_source_get_length_in_seconds(void* handle, float* out_length) {
    ma_data_source* ds = shimds_ptr(handle);
    float length = 0.0f;
    ma_result result;

    if (out_length != NULL) {
        *out_length = 0.0f;
    }
    if (ds == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_data_source_get_length_in_seconds(ds, &length);
    if (result == MA_SUCCESS) {
        *out_length = length;
    }
    return (int)result;
}

/* ---- looping -------------------------------------------------------------- */

/* @binds ma_data_source_set_looping */
int ma_shim_data_source_set_looping(void* handle, int is_looping) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_set_looping(ds, (is_looping != 0) ? MA_TRUE : MA_FALSE);
}

/* Returns 1/0; 0 also for a null/uninitialised handle. */
/* @binds ma_data_source_is_looping */
int ma_shim_data_source_is_looping(void* handle) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return 0;
    }
    return (ma_data_source_is_looping(ds) != MA_FALSE) ? 1 : 0;
}

/* ---- range / loop point --------------------------------------------------- */

/* @binds ma_data_source_set_range_in_pcm_frames */
int ma_shim_data_source_set_range_in_pcm_frames(
    void* handle,
    unsigned long long range_beg,
    unsigned long long range_end
) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_set_range_in_pcm_frames(
        ds, (ma_uint64)range_beg, (ma_uint64)range_end
    );
}

/* @binds ma_data_source_get_range_in_pcm_frames */
int ma_shim_data_source_get_range_in_pcm_frames(
    void* handle,
    unsigned long long* out_beg,
    unsigned long long* out_end
) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 beg = 0;
    ma_uint64 end = 0;

    if (out_beg != NULL) {
        *out_beg = 0;
    }
    if (out_end != NULL) {
        *out_end = 0;
    }
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    ma_data_source_get_range_in_pcm_frames(ds, &beg, &end);
    if (out_beg != NULL) {
        *out_beg = (unsigned long long)beg;
    }
    if (out_end != NULL) {
        *out_end = (unsigned long long)end;
    }
    return MA_SUCCESS;
}

/* @binds ma_data_source_set_loop_point_in_pcm_frames */
int ma_shim_data_source_set_loop_point_in_pcm_frames(
    void* handle,
    unsigned long long loop_beg,
    unsigned long long loop_end
) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_set_loop_point_in_pcm_frames(
        ds, (ma_uint64)loop_beg, (ma_uint64)loop_end
    );
}

/* @binds ma_data_source_get_loop_point_in_pcm_frames */
int ma_shim_data_source_get_loop_point_in_pcm_frames(
    void* handle,
    unsigned long long* out_beg,
    unsigned long long* out_end
) {
    ma_data_source* ds = shimds_ptr(handle);
    ma_uint64 beg = 0;
    ma_uint64 end = 0;

    if (out_beg != NULL) {
        *out_beg = 0;
    }
    if (out_end != NULL) {
        *out_end = 0;
    }
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    ma_data_source_get_loop_point_in_pcm_frames(ds, &beg, &end);
    if (out_beg != NULL) {
        *out_beg = (unsigned long long)beg;
    }
    if (out_end != NULL) {
        *out_end = (unsigned long long)end;
    }
    return MA_SUCCESS;
}

/* ---- chaining ------------------------------------------------------------- */

/* @binds ma_data_source_set_current */
int ma_shim_data_source_set_current(void* handle, void* current_handle) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    /* A NULL current_handle is legal and means "no current source"; it does
     * NOT restore reading from self -- pass the handle itself for that. */
    return (int)ma_data_source_set_current(ds, shimds_ptr(current_handle));
}

/* @binds ma_data_source_get_current */
int ma_shim_data_source_current_is(void* handle, void* expected_handle, int* out_is) {
    ma_data_source* ds = shimds_ptr(handle);

    if (out_is != NULL) {
        *out_is = 0;
    }
    if (ds == NULL || out_is == NULL) {
        return MA_INVALID_ARGS;
    }

    *out_is = (ma_data_source_get_current(ds) == shimds_ptr(expected_handle)) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_data_source_set_next */
int ma_shim_data_source_set_next(void* handle, void* next_handle) {
    ma_data_source* ds = shimds_ptr(handle);
    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }
    /* A NULL next_handle is legal: it clears the chain. */
    return (int)ma_data_source_set_next(ds, shimds_ptr(next_handle));
}

/* @binds ma_data_source_get_next */
int ma_shim_data_source_next_is(void* handle, void* expected_handle, int* out_is) {
    ma_data_source* ds = shimds_ptr(handle);

    if (out_is != NULL) {
        *out_is = 0;
    }
    if (ds == NULL || out_is == NULL) {
        return MA_INVALID_ARGS;
    }

    *out_is = (ma_data_source_get_next(ds) == shimds_ptr(expected_handle)) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_data_source_set_next_callback */
int ma_shim_data_source_set_next_callback(void* handle, void* next_handle) {
    ma_shim_data_source* h = (ma_shim_data_source*)handle;
    ma_data_source* ds = shimds_ptr(handle);

    if (ds == NULL) {
        return MA_INVALID_ARGS;
    }

    h->callback_next = shimds_ptr(next_handle);
    if (next_handle == NULL) {
        return (int)ma_data_source_set_next_callback(ds, NULL);
    }
    return (int)ma_data_source_set_next_callback(ds, shimds_on_get_next);
}

/* @binds ma_data_source_get_next_callback */
int ma_shim_data_source_has_next_callback(void* handle, int* out_has_callback) {
    ma_data_source* ds = shimds_ptr(handle);

    if (out_has_callback != NULL) {
        *out_has_callback = 0;
    }
    if (ds == NULL || out_has_callback == NULL) {
        return MA_INVALID_ARGS;
    }

    *out_has_callback = (ma_data_source_get_next_callback(ds) != NULL) ? 1 : 0;
    return MA_SUCCESS;
}

/* ---- data_source_node ----------------------------------------------------- */

void* ma_shim_data_source_node_alloc(void) {
    return calloc(1, sizeof(ma_shim_data_source_node));
}

/* @binds ma_data_source_node_uninit */
void ma_shim_data_source_node_free(void* handle) {
    ma_shim_data_source_node* h = (ma_shim_data_source_node*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_data_source_node_uninit(&h->node, NULL);
        h->initialized = 0;
    }
    free(h);
}

/* @binds ma_data_source_node_config_init, ma_data_source_node_init */
int ma_shim_data_source_node_init(
    void* handle,
    void* engine_handle,
    void* data_source_handle
) {
    ma_shim_data_source_node* h = (ma_shim_data_source_node*)handle;
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    ma_data_source* ds = shimds_ptr(data_source_handle);
    ma_data_source_node_config config;
    ma_result result;

    if (h == NULL || engine == NULL || ds == NULL) {
        return MA_INVALID_ARGS;
    }

    if (h->initialized) {
        ma_data_source_node_uninit(&h->node, NULL);
        h->initialized = 0;
    }

    config = ma_data_source_node_config_init(ds);
    result = ma_data_source_node_init(
        ma_engine_get_node_graph(engine), &config, NULL, &h->node
    );
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_data_source_node_uninit */
int ma_shim_data_source_node_uninit(void* handle) {
    ma_shim_data_source_node* h = (ma_shim_data_source_node*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    ma_data_source_node_uninit(&h->node, NULL);
    h->initialized = 0;
    return MA_SUCCESS;
}

/* @binds ma_data_source_node_set_looping */
int ma_shim_data_source_node_set_looping(void* handle, int is_looping) {
    ma_shim_data_source_node* h = (ma_shim_data_source_node*)handle;
    if (h == NULL || !h->initialized) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_data_source_node_set_looping(
        &h->node, (is_looping != 0) ? MA_TRUE : MA_FALSE
    );
}

/* Returns 1/0; 0 also for a null/uninitialised handle. */
/* @binds ma_data_source_node_is_looping */
int ma_shim_data_source_node_is_looping(void* handle) {
    ma_shim_data_source_node* h = (ma_shim_data_source_node*)handle;
    if (h == NULL || !h->initialized) {
        return 0;
    }
    return (ma_data_source_node_is_looping(&h->node) != MA_FALSE) ? 1 : 0;
}
