#include "ma_shim_paged_audio_buffer.h"
#include "miniaudio.h"

#include <stdlib.h>

typedef struct ma_shim_paged_audio_buffer_handle {
    ma_paged_audio_buffer_data  data;
    ma_paged_audio_buffer       buf;
    ma_paged_audio_buffer_page* pending[MA_SHIM_PAB_MAX_PENDING_PAGES];
    int                         data_initialized;
    int                         buf_initialized;
} ma_shim_paged_audio_buffer_handle;

static void pab_release_pending(ma_shim_paged_audio_buffer_handle* h) {
    int i;
    for (i = 0; i < MA_SHIM_PAB_MAX_PENDING_PAGES; i += 1) {
        if (h->pending[i] != NULL) {
            ma_paged_audio_buffer_data_free_page(&h->data, h->pending[i], NULL);
            h->pending[i] = NULL;
        }
    }
}

static void pab_teardown(ma_shim_paged_audio_buffer_handle* h) {
    if (h->buf_initialized) {
        ma_paged_audio_buffer_uninit(&h->buf);
        h->buf_initialized = 0;
    }
    if (h->data_initialized) {
        pab_release_pending(h);
        ma_paged_audio_buffer_data_uninit(&h->data, NULL);
        h->data_initialized = 0;
    }
}

/* Returns the handle only when its page list is initialised. */
static ma_shim_paged_audio_buffer_handle* pab_data_ready(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    if (h == NULL || !h->data_initialized) {
        return NULL;
    }
    return h;
}

/* Returns the handle only when its reader is initialised. */
static ma_shim_paged_audio_buffer_handle* pab_reader_ready(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    if (h == NULL || !h->buf_initialized) {
        return NULL;
    }
    return h;
}

static int pab_slot_valid(int slot) {
    return slot >= 0 && slot < MA_SHIM_PAB_MAX_PENDING_PAGES;
}

void* ma_shim_paged_audio_buffer_alloc(void) {
    return calloc(1, sizeof(ma_shim_paged_audio_buffer_handle));
}

/* @binds ma_paged_audio_buffer_uninit, ma_paged_audio_buffer_data_uninit */
void ma_shim_paged_audio_buffer_free(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    if (h == NULL) {
        return;
    }
    pab_teardown(h);
    free(h);
}

/* ---- the page list ---- */

/* @binds ma_paged_audio_buffer_data_init */
int ma_shim_paged_audio_buffer_data_init(void* handle, int format, unsigned int channels) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    ma_result                          result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (ma_get_bytes_per_frame((ma_format)format, (ma_uint32)channels) == 0) {
        return MA_INVALID_ARGS;
    }
    pab_teardown(h);

    result = ma_paged_audio_buffer_data_init((ma_format)format, (ma_uint32)channels, &h->data);
    if (result == MA_SUCCESS) {
        h->data_initialized = 1;
    }
    return (int)result;
}

/* @binds ma_paged_audio_buffer_data_uninit */
int ma_shim_paged_audio_buffer_data_uninit(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    pab_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_paged_audio_buffer_data_get_length_in_pcm_frames */
int ma_shim_paged_audio_buffer_data_get_length(void* handle, unsigned long long* out_length) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_uint64                          length = 0;
    ma_result                          result;

    if (out_length != NULL) { *out_length = 0; }
    if (h == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_data_get_length_in_pcm_frames(&h->data, &length);
    *out_length = (unsigned long long)length;
    return (int)result;
}

/* @binds ma_paged_audio_buffer_data_get_head */
int ma_shim_paged_audio_buffer_data_get_head(
    void*               handle,
    unsigned long long* out_size_in_frames,
    int*                out_has_pages
) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_paged_audio_buffer_page*        head;

    if (out_size_in_frames != NULL) { *out_size_in_frames = 0; }
    if (out_has_pages != NULL) { *out_has_pages = 0; }
    if (h == NULL || out_size_in_frames == NULL || out_has_pages == NULL) {
        return MA_INVALID_ARGS;
    }

    head = ma_paged_audio_buffer_data_get_head(&h->data);
    if (head == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_size_in_frames = (unsigned long long)head->sizeInFrames;
    *out_has_pages = head->pNext != NULL ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_paged_audio_buffer_data_get_tail, ma_paged_audio_buffer_data_get_head */
int ma_shim_paged_audio_buffer_data_get_tail(
    void*               handle,
    unsigned long long* out_size_in_frames,
    int*                out_is_head
) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_paged_audio_buffer_page*        tail;

    if (out_size_in_frames != NULL) { *out_size_in_frames = 0; }
    if (out_is_head != NULL) { *out_is_head = 0; }
    if (h == NULL || out_size_in_frames == NULL || out_is_head == NULL) {
        return MA_INVALID_ARGS;
    }

    tail = ma_paged_audio_buffer_data_get_tail(&h->data);
    if (tail == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_size_in_frames = (unsigned long long)tail->sizeInFrames;
    *out_is_head = tail == ma_paged_audio_buffer_data_get_head(&h->data) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_paged_audio_buffer_data_allocate_page */
int ma_shim_paged_audio_buffer_data_allocate_page(
    void*              handle,
    unsigned long long page_size_in_frames,
    const void*        src,
    int*               out_slot
) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_paged_audio_buffer_page*        page = NULL;
    ma_result                          result;
    int                                slot;

    if (out_slot != NULL) { *out_slot = -1; }
    if (h == NULL || out_slot == NULL) {
        return MA_INVALID_ARGS;
    }

    for (slot = 0; slot < MA_SHIM_PAB_MAX_PENDING_PAGES; slot += 1) {
        if (h->pending[slot] == NULL) {
            break;
        }
    }
    if (slot == MA_SHIM_PAB_MAX_PENDING_PAGES) {
        return MA_OUT_OF_MEMORY; /* every slot is holding an un-appended page */
    }

    result = ma_paged_audio_buffer_data_allocate_page(
        &h->data, (ma_uint64)page_size_in_frames, src, NULL, &page);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    h->pending[slot] = page;
    *out_slot = slot;
    return MA_SUCCESS;
}

/* @binds ma_paged_audio_buffer_data_append_page */
int ma_shim_paged_audio_buffer_data_append_page(void* handle, int slot) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_result                          result;

    if (h == NULL || !pab_slot_valid(slot) || h->pending[slot] == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_data_append_page(&h->data, h->pending[slot]);
    if (result == MA_SUCCESS) {
        h->pending[slot] = NULL; /* the list owns it now */
    }
    return (int)result;
}

/* @binds ma_paged_audio_buffer_data_free_page */
int ma_shim_paged_audio_buffer_data_free_page(void* handle, int slot) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_result                          result;

    if (h == NULL || !pab_slot_valid(slot) || h->pending[slot] == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_data_free_page(&h->data, h->pending[slot], NULL);
    if (result == MA_SUCCESS) {
        h->pending[slot] = NULL;
    }
    return (int)result;
}

/* @binds ma_paged_audio_buffer_data_allocate_and_append_page */
int ma_shim_paged_audio_buffer_data_allocate_and_append_page(
    void*        handle,
    unsigned int page_size_in_frames,
    const void*  src
) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_paged_audio_buffer_data_allocate_and_append_page(
        &h->data, (ma_uint32)page_size_in_frames, src, NULL);
}

/* ---- the reader ---- */

/* @binds ma_paged_audio_buffer_config_init, ma_paged_audio_buffer_init */
int ma_shim_paged_audio_buffer_init(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = pab_data_ready(handle);
    ma_paged_audio_buffer_config       config;
    ma_result                          result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->buf_initialized) {
        ma_paged_audio_buffer_uninit(&h->buf);
        h->buf_initialized = 0;
    }

    config = ma_paged_audio_buffer_config_init(&h->data);
    result = ma_paged_audio_buffer_init(&config, &h->buf);
    if (result == MA_SUCCESS) {
        h->buf_initialized = 1;
    }
    return (int)result;
}

/* @binds ma_paged_audio_buffer_uninit */
int ma_shim_paged_audio_buffer_uninit(void* handle) {
    ma_shim_paged_audio_buffer_handle* h = (ma_shim_paged_audio_buffer_handle*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->buf_initialized) {
        ma_paged_audio_buffer_uninit(&h->buf);
        h->buf_initialized = 0;
    }
    return MA_SUCCESS;
}

/* @binds ma_paged_audio_buffer_read_pcm_frames */
int ma_shim_paged_audio_buffer_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_paged_audio_buffer_handle* h = pab_reader_ready(handle);
    ma_uint64                          read = 0;
    ma_result                          result;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_read_pcm_frames(
        &h->buf, dst, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_paged_audio_buffer_seek_to_pcm_frame */
int ma_shim_paged_audio_buffer_seek(void* handle, unsigned long long frame_index) {
    ma_shim_paged_audio_buffer_handle* h = pab_reader_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_paged_audio_buffer_seek_to_pcm_frame(&h->buf, (ma_uint64)frame_index);
}

/* @binds ma_paged_audio_buffer_get_cursor_in_pcm_frames */
int ma_shim_paged_audio_buffer_get_cursor(void* handle, unsigned long long* out_cursor) {
    ma_shim_paged_audio_buffer_handle* h = pab_reader_ready(handle);
    ma_uint64                          cursor = 0;
    ma_result                          result;

    if (out_cursor != NULL) { *out_cursor = 0; }
    if (h == NULL || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_get_cursor_in_pcm_frames(&h->buf, &cursor);
    *out_cursor = (unsigned long long)cursor;
    return (int)result;
}

/* @binds ma_paged_audio_buffer_get_length_in_pcm_frames */
int ma_shim_paged_audio_buffer_get_length(void* handle, unsigned long long* out_length) {
    ma_shim_paged_audio_buffer_handle* h = pab_reader_ready(handle);
    ma_uint64                          length = 0;
    ma_result                          result;

    if (out_length != NULL) { *out_length = 0; }
    if (h == NULL || out_length == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_paged_audio_buffer_get_length_in_pcm_frames(&h->buf, &length);
    *out_length = (unsigned long long)length;
    return (int)result;
}
