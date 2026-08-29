#include "ma_shim_ring_buffer.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* ================= ma_rb — byte-oriented ring buffer ================= */

typedef struct ma_shim_rb {
    ma_rb rb;
    void* preallocated; /* non-NULL when the caller asked for the preallocated path */
    int   initialized;
} ma_shim_rb;

static void rb_teardown(ma_shim_rb* h) {
    if (h->initialized) {
        ma_rb_uninit(&h->rb);
        h->initialized = 0;
    }
    if (h->preallocated != NULL) {
        free(h->preallocated);
        h->preallocated = NULL;
    }
}

/* Returns the handle only when it is allocated AND initialised. */
static ma_shim_rb* rb_ready(void* handle) {
    ma_shim_rb* h = (ma_shim_rb*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_rb_alloc(void) {
    return calloc(1, sizeof(ma_shim_rb));
}

/* @binds ma_rb_uninit */
void ma_shim_rb_free(void* handle) {
    ma_shim_rb* h = (ma_shim_rb*)handle;
    if (h == NULL) {
        return;
    }
    rb_teardown(h);
    free(h);
}

/* @binds ma_rb_init */
int ma_shim_rb_init(void* handle, unsigned long long buffer_size_in_bytes) {
    ma_shim_rb* h = (ma_shim_rb*)handle;
    ma_result result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    rb_teardown(h);
    result = ma_rb_init((size_t)buffer_size_in_bytes, NULL, NULL, &h->rb);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_rb_init_ex */
int ma_shim_rb_init_ex(
    void*              handle,
    unsigned long long subbuffer_size_in_bytes,
    unsigned long long subbuffer_count,
    unsigned long long subbuffer_stride_in_bytes,
    int                use_preallocated
) {
    ma_shim_rb* h = (ma_shim_rb*)handle;
    void*       prealloc = NULL;
    ma_result   result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    rb_teardown(h);

    if (use_preallocated) {
        size_t stride = (size_t)(subbuffer_stride_in_bytes != 0
                                     ? subbuffer_stride_in_bytes
                                     : subbuffer_size_in_bytes);
        if (stride == 0 || subbuffer_count == 0) {
            return MA_INVALID_ARGS;
        }
        prealloc = calloc((size_t)subbuffer_count, stride);
        if (prealloc == NULL) { return MA_OUT_OF_MEMORY; }
    }

    result = ma_rb_init_ex(
        (size_t)subbuffer_size_in_bytes,
        (size_t)subbuffer_count,
        (size_t)subbuffer_stride_in_bytes,
        prealloc,
        NULL,
        &h->rb
    );
    if (result == MA_SUCCESS) {
        h->initialized = 1;
        h->preallocated = prealloc;
    } else if (prealloc != NULL) {
        free(prealloc);
    }
    return (int)result;
}

/* @binds ma_rb_uninit */
int ma_shim_rb_uninit(void* handle) {
    ma_shim_rb* h = (ma_shim_rb*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    rb_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_rb_reset */
int ma_shim_rb_reset(void* handle) {
    ma_shim_rb* h = rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_rb_reset(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_acquire_write, ma_rb_commit_write */
int ma_shim_rb_write(
    void*               handle,
    const void*         src,
    unsigned long long  size_in_bytes,
    unsigned long long* bytes_written_out
) {
    ma_shim_rb*          h = rb_ready(handle);
    const unsigned char* in = (const unsigned char*)src;
    size_t               written = 0;
    ma_result            result = MA_SUCCESS;

    if (bytes_written_out != NULL) { *bytes_written_out = 0; }
    if (h == NULL || src == NULL) {
        return MA_INVALID_ARGS;
    }

    /* acquire_write never spans the wrap point, so loop until satisfied. */
    while (written < (size_t)size_in_bytes) {
        size_t chunk = (size_t)size_in_bytes - written;
        void*  dst = NULL;

        result = ma_rb_acquire_write(&h->rb, &chunk, &dst);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is full */
        }
        memcpy(dst, in + written, chunk);
        result = ma_rb_commit_write(&h->rb, chunk);
        if (result != MA_SUCCESS) { break; }
        written += chunk;
    }

    if (bytes_written_out != NULL) { *bytes_written_out = (unsigned long long)written; }
    return (int)result;
}

/* @binds ma_rb_acquire_read, ma_rb_commit_read */
int ma_shim_rb_read(
    void*               handle,
    void*               dst,
    unsigned long long  size_in_bytes,
    unsigned long long* bytes_read_out
) {
    ma_shim_rb*    h = rb_ready(handle);
    unsigned char* out = (unsigned char*)dst;
    size_t         readed = 0;
    ma_result      result = MA_SUCCESS;

    if (bytes_read_out != NULL) { *bytes_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    while (readed < (size_t)size_in_bytes) {
        size_t chunk = (size_t)size_in_bytes - readed;
        void*  src = NULL;

        result = ma_rb_acquire_read(&h->rb, &chunk, &src);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is empty */
        }
        memcpy(out + readed, src, chunk);
        result = ma_rb_commit_read(&h->rb, chunk);
        if (result != MA_SUCCESS) { break; }
        readed += chunk;
    }

    if (bytes_read_out != NULL) { *bytes_read_out = (unsigned long long)readed; }
    return (int)result;
}

/* @binds ma_rb_seek_read */
int ma_shim_rb_seek_read(void* handle, unsigned long long offset_in_bytes) {
    ma_shim_rb* h = rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_rb_seek_read(&h->rb, (size_t)offset_in_bytes);
}

/* @binds ma_rb_seek_write */
int ma_shim_rb_seek_write(void* handle, unsigned long long offset_in_bytes) {
    ma_shim_rb* h = rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_rb_seek_write(&h->rb, (size_t)offset_in_bytes);
}

/* @binds ma_rb_pointer_distance */
int ma_shim_rb_pointer_distance(void* handle, int* out_distance) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_distance != NULL) { *out_distance = 0; }
    if (h == NULL || out_distance == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_distance = (int)ma_rb_pointer_distance(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_available_read */
int ma_shim_rb_available_read(void* handle, unsigned int* out_available) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_available = (unsigned int)ma_rb_available_read(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_available_write */
int ma_shim_rb_available_write(void* handle, unsigned int* out_available) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_available = (unsigned int)ma_rb_available_write(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_get_subbuffer_size */
int ma_shim_rb_get_subbuffer_size(void* handle, unsigned long long* out_size) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_size != NULL) { *out_size = 0; }
    if (h == NULL || out_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_size = (unsigned long long)ma_rb_get_subbuffer_size(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_get_subbuffer_stride */
int ma_shim_rb_get_subbuffer_stride(void* handle, unsigned long long* out_stride) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_stride != NULL) { *out_stride = 0; }
    if (h == NULL || out_stride == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_stride = (unsigned long long)ma_rb_get_subbuffer_stride(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_rb_get_subbuffer_offset */
int ma_shim_rb_get_subbuffer_offset(
    void*               handle,
    unsigned long long  subbuffer_index,
    unsigned long long* out_offset
) {
    ma_shim_rb* h = rb_ready(handle);
    if (out_offset != NULL) { *out_offset = 0; }
    if (h == NULL || out_offset == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_offset = (unsigned long long)ma_rb_get_subbuffer_offset(&h->rb, (size_t)subbuffer_index);
    return MA_SUCCESS;
}

/* @binds ma_rb_get_subbuffer_ptr */
int ma_shim_rb_get_subbuffer_ptr_offset(
    void*               handle,
    unsigned long long  subbuffer_index,
    unsigned long long* out_offset
) {
    ma_shim_rb* h = rb_ready(handle);
    const unsigned char* base;
    const unsigned char* p;

    if (out_offset != NULL) { *out_offset = 0; }
    if (h == NULL || out_offset == NULL) {
        return MA_INVALID_ARGS;
    }
    /* The raw pointer has no safe Mojo representation; report its byte offset
     * from the ring buffer's own backing store instead. */
    base = (const unsigned char*)h->rb.pBuffer;
    p = (const unsigned char*)ma_rb_get_subbuffer_ptr(&h->rb, (size_t)subbuffer_index, h->rb.pBuffer);
    *out_offset = (unsigned long long)(p - base);
    return MA_SUCCESS;
}

/* ================= ma_pcm_rb — frame-oriented ring buffer ================= */

typedef struct ma_shim_pcm_rb {
    ma_pcm_rb rb;
    void*     preallocated;
    int       initialized;
} ma_shim_pcm_rb;

static void pcm_rb_teardown(ma_shim_pcm_rb* h) {
    if (h->initialized) {
        ma_pcm_rb_uninit(&h->rb);
        h->initialized = 0;
    }
    if (h->preallocated != NULL) {
        free(h->preallocated);
        h->preallocated = NULL;
    }
}

static ma_shim_pcm_rb* pcm_rb_ready(void* handle) {
    ma_shim_pcm_rb* h = (ma_shim_pcm_rb*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_pcm_rb_alloc(void) {
    return calloc(1, sizeof(ma_shim_pcm_rb));
}

/* @binds ma_pcm_rb_uninit */
void ma_shim_pcm_rb_free(void* handle) {
    ma_shim_pcm_rb* h = (ma_shim_pcm_rb*)handle;
    if (h == NULL) {
        return;
    }
    pcm_rb_teardown(h);
    free(h);
}

/* @binds ma_pcm_rb_init */
int ma_shim_pcm_rb_init(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int buffer_size_in_frames
) {
    ma_shim_pcm_rb* h = (ma_shim_pcm_rb*)handle;
    ma_result       result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    pcm_rb_teardown(h);
    result = ma_pcm_rb_init((ma_format)format, channels, buffer_size_in_frames, NULL, NULL, &h->rb);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_pcm_rb_init_ex */
int ma_shim_pcm_rb_init_ex(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int subbuffer_size_in_frames,
    unsigned int subbuffer_count,
    unsigned int subbuffer_stride_in_frames,
    int          use_preallocated
) {
    ma_shim_pcm_rb* h = (ma_shim_pcm_rb*)handle;
    void*           prealloc = NULL;
    ma_result       result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    pcm_rb_teardown(h);

    if (use_preallocated) {
        ma_uint32 stride = (subbuffer_stride_in_frames != 0 ? subbuffer_stride_in_frames
                                                            : subbuffer_size_in_frames);
        size_t bpf = (size_t)ma_get_bytes_per_frame((ma_format)format, channels);
        if (stride == 0 || subbuffer_count == 0 || bpf == 0) {
            return MA_INVALID_ARGS;
        }
        prealloc = calloc((size_t)subbuffer_count * (size_t)stride, bpf);
        if (prealloc == NULL) { return MA_OUT_OF_MEMORY; }
    }

    result = ma_pcm_rb_init_ex(
        (ma_format)format,
        channels,
        subbuffer_size_in_frames,
        subbuffer_count,
        subbuffer_stride_in_frames,
        prealloc,
        NULL,
        &h->rb
    );
    if (result == MA_SUCCESS) {
        h->initialized = 1;
        h->preallocated = prealloc;
    } else if (prealloc != NULL) {
        free(prealloc);
    }
    return (int)result;
}

/* @binds ma_pcm_rb_uninit */
int ma_shim_pcm_rb_uninit(void* handle) {
    ma_shim_pcm_rb* h = (ma_shim_pcm_rb*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (!h->initialized) {
        return MA_SUCCESS;
    }
    pcm_rb_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_reset */
int ma_shim_pcm_rb_reset(void* handle) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_pcm_rb_reset(&h->rb);
    return MA_SUCCESS;
}

/* Bytes per frame of an initialised handle, via miniaudio's own accessors. */
static size_t pcm_rb_bpf(ma_shim_pcm_rb* h) {
    return (size_t)ma_get_bytes_per_frame(ma_pcm_rb_get_format(&h->rb),
                                          ma_pcm_rb_get_channels(&h->rb));
}

/* @binds ma_pcm_rb_acquire_write, ma_pcm_rb_commit_write */
int ma_shim_pcm_rb_write(
    void*         handle,
    const void*   src,
    unsigned int  frame_count,
    unsigned int* frames_written_out
) {
    ma_shim_pcm_rb*      h = pcm_rb_ready(handle);
    const unsigned char* in = (const unsigned char*)src;
    ma_uint32            written = 0;
    ma_result            result = MA_SUCCESS;
    size_t               bpf;

    if (frames_written_out != NULL) { *frames_written_out = 0; }
    if (h == NULL || src == NULL) {
        return MA_INVALID_ARGS;
    }

    bpf = pcm_rb_bpf(h);
    while (written < frame_count) {
        ma_uint32 chunk = frame_count - written;
        void*     dst = NULL;

        result = ma_pcm_rb_acquire_write(&h->rb, &chunk, &dst);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is full */
        }
        memcpy(dst, in + ((size_t)written * bpf), (size_t)chunk * bpf);
        result = ma_pcm_rb_commit_write(&h->rb, chunk);
        if (result != MA_SUCCESS) { break; }
        written += chunk;
    }

    if (frames_written_out != NULL) { *frames_written_out = (unsigned int)written; }
    return (int)result;
}

/* @binds ma_pcm_rb_acquire_read, ma_pcm_rb_commit_read */
int ma_shim_pcm_rb_read(
    void*         handle,
    void*         dst,
    unsigned int  frame_count,
    unsigned int* frames_read_out
) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    unsigned char*  out = (unsigned char*)dst;
    ma_uint32       readed = 0;
    ma_result       result = MA_SUCCESS;
    size_t          bpf;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }

    bpf = pcm_rb_bpf(h);
    while (readed < frame_count) {
        ma_uint32 chunk = frame_count - readed;
        void*     src = NULL;

        result = ma_pcm_rb_acquire_read(&h->rb, &chunk, &src);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is empty */
        }
        memcpy(out + ((size_t)readed * bpf), src, (size_t)chunk * bpf);
        result = ma_pcm_rb_commit_read(&h->rb, chunk);
        if (result != MA_SUCCESS) { break; }
        readed += chunk;
    }

    if (frames_read_out != NULL) { *frames_read_out = (unsigned int)readed; }
    return (int)result;
}

/* @binds ma_pcm_rb_seek_read */
int ma_shim_pcm_rb_seek_read(void* handle, unsigned int offset_in_frames) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pcm_rb_seek_read(&h->rb, offset_in_frames);
}

/* @binds ma_pcm_rb_seek_write */
int ma_shim_pcm_rb_seek_write(void* handle, unsigned int offset_in_frames) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_pcm_rb_seek_write(&h->rb, offset_in_frames);
}

/* @binds ma_pcm_rb_pointer_distance */
int ma_shim_pcm_rb_pointer_distance(void* handle, int* out_distance) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_distance != NULL) { *out_distance = 0; }
    if (h == NULL || out_distance == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_distance = (int)ma_pcm_rb_pointer_distance(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_available_read */
int ma_shim_pcm_rb_available_read(void* handle, unsigned int* out_available) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_available = (unsigned int)ma_pcm_rb_available_read(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_available_write */
int ma_shim_pcm_rb_available_write(void* handle, unsigned int* out_available) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_available != NULL) { *out_available = 0; }
    if (h == NULL || out_available == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_available = (unsigned int)ma_pcm_rb_available_write(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_get_subbuffer_size */
int ma_shim_pcm_rb_get_subbuffer_size(void* handle, unsigned int* out_size) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_size != NULL) { *out_size = 0; }
    if (h == NULL || out_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_size = (unsigned int)ma_pcm_rb_get_subbuffer_size(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_get_subbuffer_stride */
int ma_shim_pcm_rb_get_subbuffer_stride(void* handle, unsigned int* out_stride) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_stride != NULL) { *out_stride = 0; }
    if (h == NULL || out_stride == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_stride = (unsigned int)ma_pcm_rb_get_subbuffer_stride(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_get_subbuffer_offset */
int ma_shim_pcm_rb_get_subbuffer_offset(
    void*         handle,
    unsigned int  subbuffer_index,
    unsigned int* out_offset
) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_offset != NULL) { *out_offset = 0; }
    if (h == NULL || out_offset == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_offset = (unsigned int)ma_pcm_rb_get_subbuffer_offset(&h->rb, subbuffer_index);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_get_subbuffer_ptr */
int ma_shim_pcm_rb_get_subbuffer_ptr_offset(
    void*               handle,
    unsigned int        subbuffer_index,
    unsigned long long* out_offset
) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    const unsigned char* base;
    const unsigned char* p;

    if (out_offset != NULL) { *out_offset = 0; }
    if (h == NULL || out_offset == NULL) {
        return MA_INVALID_ARGS;
    }
    base = (const unsigned char*)h->rb.rb.pBuffer;
    p = (const unsigned char*)ma_pcm_rb_get_subbuffer_ptr(&h->rb, subbuffer_index, h->rb.rb.pBuffer);
    *out_offset = (unsigned long long)(p - base);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_get_format, ma_pcm_rb_get_channels, ma_pcm_rb_get_sample_rate */
int ma_shim_pcm_rb_get_data_format(
    void*         handle,
    int*          out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (out_format != NULL) { *out_format = 0; }
    if (out_channels != NULL) { *out_channels = 0; }
    if (out_sample_rate != NULL) { *out_sample_rate = 0; }
    if (h == NULL || out_format == NULL || out_channels == NULL || out_sample_rate == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_format = (int)ma_pcm_rb_get_format(&h->rb);
    *out_channels = (unsigned int)ma_pcm_rb_get_channels(&h->rb);
    *out_sample_rate = (unsigned int)ma_pcm_rb_get_sample_rate(&h->rb);
    return MA_SUCCESS;
}

/* @binds ma_pcm_rb_set_sample_rate */
int ma_shim_pcm_rb_set_sample_rate(void* handle, unsigned int sample_rate) {
    ma_shim_pcm_rb* h = pcm_rb_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_pcm_rb_set_sample_rate(&h->rb, sample_rate);
    return MA_SUCCESS;
}
