#include "ma_shim_audio_buffer.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* Byte size of `frames` frames, or 0 when the format/channel pair is invalid. */
static size_t ab_frames_to_bytes(int format, unsigned int channels, unsigned long long frames) {
    ma_uint32 bpf = ma_get_bytes_per_frame((ma_format)format, (ma_uint32)channels);
    if (bpf == 0) {
        return 0;
    }
    return (size_t)frames * (size_t)bpf;
}

/* Replace *slot with a fresh copy of `frames` frames read from `src`. */
static ma_result ab_copy_frames(
    void**             slot,
    const void*        src,
    int                format,
    unsigned int       channels,
    unsigned long long frames
) {
    size_t bytes = ab_frames_to_bytes(format, channels, frames);
    void*  copy;

    if (src == NULL || frames == 0 || bytes == 0) {
        return MA_INVALID_ARGS;
    }
    copy = malloc(bytes);
    if (copy == NULL) {
        return MA_OUT_OF_MEMORY;
    }
    memcpy(copy, src, bytes);

    free(*slot);
    *slot = copy;
    return MA_SUCCESS;
}

/* ================= ma_audio_buffer_ref — non-owning view ================= */

typedef struct ma_shim_audio_buffer_ref_handle {
    ma_audio_buffer_ref ref;
    void*               data;     /* shim-owned frames the ref points at */
    int                 format;
    unsigned int        channels;
    int                 initialized;
} ma_shim_audio_buffer_ref_handle;

static void ab_ref_teardown(ma_shim_audio_buffer_ref_handle* h) {
    if (h->initialized) {
        ma_audio_buffer_ref_uninit(&h->ref);
        h->initialized = 0;
    }
    free(h->data);
    h->data = NULL;
}

/* Returns the handle only when it is allocated AND initialised. */
static ma_shim_audio_buffer_ref_handle* ab_ref_ready(void* handle) {
    ma_shim_audio_buffer_ref_handle* h = (ma_shim_audio_buffer_ref_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_audio_buffer_ref_alloc(void) {
    return calloc(1, sizeof(ma_shim_audio_buffer_ref_handle));
}

/* @binds ma_audio_buffer_ref_uninit */
void ma_shim_audio_buffer_ref_free(void* handle) {
    ma_shim_audio_buffer_ref_handle* h = (ma_shim_audio_buffer_ref_handle*)handle;
    if (h == NULL) {
        return;
    }
    ab_ref_teardown(h);
    free(h);
}

/* @binds ma_audio_buffer_ref_init */
int ma_shim_audio_buffer_ref_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
) {
    ma_shim_audio_buffer_ref_handle* h = (ma_shim_audio_buffer_ref_handle*)handle;
    ma_result                        result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_ref_teardown(h);

    result = ab_copy_frames(&h->data, src, format, channels, frame_count);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    result = ma_audio_buffer_ref_init(
        (ma_format)format, (ma_uint32)channels, h->data, (ma_uint64)frame_count, &h->ref);
    if (result == MA_SUCCESS) {
        h->format = format;
        h->channels = channels;
        h->initialized = 1;
    }
    /* On failure the copy stays owned by the handle and is freed by the next
     * teardown (uninit / free), so there is nothing to unwind here. */
    return (int)result;
}

/* @binds ma_audio_buffer_ref_uninit */
int ma_shim_audio_buffer_ref_uninit(void* handle) {
    ma_shim_audio_buffer_ref_handle* h = (ma_shim_audio_buffer_ref_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_ref_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_ref_set_data */
int ma_shim_audio_buffer_ref_set_data(
    void*              handle,
    const void*        src,
    unsigned long long frame_count
) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_result                        result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ab_copy_frames(&h->data, src, h->format, h->channels, frame_count);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    return (int)ma_audio_buffer_ref_set_data(&h->ref, h->data, (ma_uint64)frame_count);
}

/* @binds ma_audio_buffer_ref_read_pcm_frames */
int ma_shim_audio_buffer_ref_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    int                 loop,
    unsigned long long* frames_read_out
) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_uint64                        read;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    read = ma_audio_buffer_ref_read_pcm_frames(
        &h->ref, dst, (ma_uint64)frame_count, (ma_bool32)(loop != 0));
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_ref_seek_to_pcm_frame */
int ma_shim_audio_buffer_ref_seek(void* handle, unsigned long long frame_index) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_audio_buffer_ref_seek_to_pcm_frame(&h->ref, (ma_uint64)frame_index);
}

/* @binds ma_audio_buffer_ref_map, ma_audio_buffer_ref_unmap */
int ma_shim_audio_buffer_ref_map_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_mapped_out
) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_uint64                        mapped = (ma_uint64)frame_count;
    void*                            frames = NULL;
    ma_result                        result;

    if (frames_mapped_out != NULL) { *frames_mapped_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_audio_buffer_ref_map(&h->ref, &frames, &mapped);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (mapped > 0) {
        memcpy(dst, frames, ab_frames_to_bytes(h->format, h->channels, mapped));
    }
    if (frames_mapped_out != NULL) { *frames_mapped_out = (unsigned long long)mapped; }

    /* MA_AT_END here means "the cursor is now on the end", which is a success. */
    return (int)ma_audio_buffer_ref_unmap(&h->ref, mapped);
}

/* @binds ma_audio_buffer_ref_at_end */
int ma_shim_audio_buffer_ref_at_end(void* handle, int* out_at_end) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    if (out_at_end != NULL) { *out_at_end = 0; }
    if (h == NULL || out_at_end == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_at_end = ma_audio_buffer_ref_at_end(&h->ref) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_ref_get_cursor_in_pcm_frames */
int ma_shim_audio_buffer_ref_get_cursor(void* handle, unsigned long long* out_cursor) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_uint64                        cursor = 0;
    ma_result                        result;

    if (out_cursor != NULL) { *out_cursor = 0; }
    if (h == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_ref_get_cursor_in_pcm_frames(&h->ref, &cursor);
    *out_cursor = (unsigned long long)cursor;
    return (int)result;
}

/* @binds ma_audio_buffer_ref_get_length_in_pcm_frames */
int ma_shim_audio_buffer_ref_get_length(void* handle, unsigned long long* out_length) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_uint64                        length = 0;
    ma_result                        result;

    if (out_length != NULL) { *out_length = 0; }
    if (h == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_ref_get_length_in_pcm_frames(&h->ref, &length);
    *out_length = (unsigned long long)length;
    return (int)result;
}

/* @binds ma_audio_buffer_ref_get_available_frames */
int ma_shim_audio_buffer_ref_get_available(void* handle, unsigned long long* out_available) {
    ma_shim_audio_buffer_ref_handle* h = ab_ref_ready(handle);
    ma_uint64                        available = 0;
    ma_result                        result;

    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_ref_get_available_frames(&h->ref, &available);
    *out_available = (unsigned long long)available;
    return (int)result;
}

/* ================= ma_audio_buffer — owning buffer ================= */

typedef struct ma_shim_audio_buffer_handle {
    ma_audio_buffer  buf;        /* used by the init / init_copy paths */
    ma_audio_buffer* allocated;  /* non-NULL for the alloc_and_init path */
    void*            data;       /* shim-owned frames for the non-copying init */
    int              format;
    unsigned int     channels;
    int              initialized;
} ma_shim_audio_buffer_handle;

static void ab_teardown(ma_shim_audio_buffer_handle* h) {
    if (h->initialized) {
        if (h->allocated != NULL) {
            ma_audio_buffer_uninit_and_free(h->allocated);
            h->allocated = NULL;
        } else {
            ma_audio_buffer_uninit(&h->buf);
        }
        h->initialized = 0;
    }
    free(h->data);
    h->data = NULL;
}

static ma_shim_audio_buffer_handle* ab_ready(void* handle) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

/* The buffer the API calls operate on: heap-allocated when alloc_and_init was
 * used, otherwise the one embedded in the handle. */
static ma_audio_buffer* ab_buffer(ma_shim_audio_buffer_handle* h) {
    return h->allocated != NULL ? h->allocated : &h->buf;
}

void* ma_shim_audio_buffer_alloc(void) {
    return calloc(1, sizeof(ma_shim_audio_buffer_handle));
}

/* @binds ma_audio_buffer_uninit, ma_audio_buffer_uninit_and_free */
void ma_shim_audio_buffer_free(void* handle) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    if (h == NULL) {
        return;
    }
    ab_teardown(h);
    free(h);
}

/* @binds ma_audio_buffer_config_init, ma_audio_buffer_init */
int ma_shim_audio_buffer_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    ma_audio_buffer_config       config;
    ma_result                    result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_teardown(h);

    /* ma_audio_buffer_init stores the config's pointer verbatim, so the frames
     * have to outlive the call — hence the shim-owned copy. */
    result = ab_copy_frames(&h->data, src, format, channels, frame_count);
    if (result != MA_SUCCESS) {
        return (int)result;
    }

    config = ma_audio_buffer_config_init(
        (ma_format)format, (ma_uint32)channels, (ma_uint64)frame_count, h->data, NULL);
    result = ma_audio_buffer_init(&config, &h->buf);
    if (result == MA_SUCCESS) {
        h->format = format;
        h->channels = channels;
        h->initialized = 1;
    }
    /* As above: a failed init leaves the copy to the next teardown. */
    return (int)result;
}

/* @binds ma_audio_buffer_config_init, ma_audio_buffer_init_copy */
int ma_shim_audio_buffer_init_copy(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    ma_audio_buffer_config       config;
    ma_result                    result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_teardown(h);

    /* miniaudio allocates and copies here, so `src` only has to survive the call
     * and a NULL `src` is legal — it produces a silent buffer. */
    config = ma_audio_buffer_config_init(
        (ma_format)format, (ma_uint32)channels, (ma_uint64)frame_count, src, NULL);
    result = ma_audio_buffer_init_copy(&config, &h->buf);
    if (result == MA_SUCCESS) {
        h->format = format;
        h->channels = channels;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_audio_buffer_config_init, ma_audio_buffer_alloc_and_init */
int ma_shim_audio_buffer_alloc_and_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    ma_audio_buffer_config       config;
    ma_result                    result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_teardown(h);

    config = ma_audio_buffer_config_init(
        (ma_format)format, (ma_uint32)channels, (ma_uint64)frame_count, src, NULL);
    result = ma_audio_buffer_alloc_and_init(&config, &h->allocated);
    if (result == MA_SUCCESS) {
        h->format = format;
        h->channels = channels;
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_audio_buffer_uninit, ma_audio_buffer_uninit_and_free */
int ma_shim_audio_buffer_uninit(void* handle) {
    ma_shim_audio_buffer_handle* h = (ma_shim_audio_buffer_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ab_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_read_pcm_frames */
int ma_shim_audio_buffer_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    int                 loop,
    unsigned long long* frames_read_out
) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    ma_uint64                    read;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    read = ma_audio_buffer_read_pcm_frames(
        ab_buffer(h), dst, (ma_uint64)frame_count, (ma_bool32)(loop != 0));
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_seek_to_pcm_frame */
int ma_shim_audio_buffer_seek(void* handle, unsigned long long frame_index) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_audio_buffer_seek_to_pcm_frame(ab_buffer(h), (ma_uint64)frame_index);
}

/* @binds ma_audio_buffer_map, ma_audio_buffer_unmap */
int ma_shim_audio_buffer_map_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_mapped_out
) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    ma_uint64                    mapped = (ma_uint64)frame_count;
    void*                        frames = NULL;
    ma_result                    result;

    if (frames_mapped_out != NULL) { *frames_mapped_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    result = ma_audio_buffer_map(ab_buffer(h), &frames, &mapped);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (mapped > 0) {
        memcpy(dst, frames, ab_frames_to_bytes(h->format, h->channels, mapped));
    }
    if (frames_mapped_out != NULL) { *frames_mapped_out = (unsigned long long)mapped; }

    return (int)ma_audio_buffer_unmap(ab_buffer(h), mapped);
}

/* @binds ma_audio_buffer_at_end */
int ma_shim_audio_buffer_at_end(void* handle, int* out_at_end) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    if (out_at_end != NULL) { *out_at_end = 0; }
    if (h == NULL || out_at_end == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_at_end = ma_audio_buffer_at_end(ab_buffer(h)) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_audio_buffer_get_cursor_in_pcm_frames */
int ma_shim_audio_buffer_get_cursor(void* handle, unsigned long long* out_cursor) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    ma_uint64                    cursor = 0;
    ma_result                    result;

    if (out_cursor != NULL) { *out_cursor = 0; }
    if (h == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_get_cursor_in_pcm_frames(ab_buffer(h), &cursor);
    *out_cursor = (unsigned long long)cursor;
    return (int)result;
}

/* @binds ma_audio_buffer_get_length_in_pcm_frames */
int ma_shim_audio_buffer_get_length(void* handle, unsigned long long* out_length) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    ma_uint64                    length = 0;
    ma_result                    result;

    if (out_length != NULL) { *out_length = 0; }
    if (h == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_get_length_in_pcm_frames(ab_buffer(h), &length);
    *out_length = (unsigned long long)length;
    return (int)result;
}

/* @binds ma_audio_buffer_get_available_frames */
int ma_shim_audio_buffer_get_available(void* handle, unsigned long long* out_available) {
    ma_shim_audio_buffer_handle* h = ab_ready(handle);
    ma_uint64                    available = 0;
    ma_result                    result;

    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_audio_buffer_get_available_frames(ab_buffer(h), &available);
    *out_available = (unsigned long long)available;
    return (int)result;
}
