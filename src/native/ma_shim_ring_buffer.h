#ifndef MA_SHIM_RING_BUFFER_H
#define MA_SHIM_RING_BUFFER_H

/* ---- ring buffer (opaque handles over ma_rb and ma_pcm_rb) ----
 *
 * Two lock-free single-producer/single-consumer ring buffers:
 *   - ma_rb     — untyped, sized in bytes
 *   - ma_pcm_rb — PCM-aware, sized in frames, carries format/channels/sample-rate
 *
 * Both are purely in-memory: no device, engine, or file is involved, so the
 * whole family is deterministic and hardware-independent.
 *
 * miniaudio moves data through an acquire/commit pair that hands out a direct
 * pointer into the buffer's interior, bounded by the sub-buffer wrap point.
 * Mojo has no safe home for such an interior pointer, so the shim owns the
 * acquire -> memcpy -> commit loop and exposes copy-in / copy-out entry points
 * (`write` / `read`) instead. They loop until the request is satisfied or the
 * buffer runs full/empty, so a request spanning the wrap point still succeeds.
 *
 * `ma_rb_get_subbuffer_ptr` returns an absolute address; it is bound as the
 * byte offset of that address from the ring buffer's own backing store, which
 * is the only part of it Mojo can meaningfully assert on.
 *
 * Sample format codes match ma_format: unknown=0, u8=1, s16=2, s24=3, s32=4,
 * f32=5.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ---- ma_rb — byte-oriented ring buffer ---- */

void* ma_shim_rb_alloc(void);
void  ma_shim_rb_free(void* handle);

int ma_shim_rb_init(void* handle, unsigned long long buffer_size_in_bytes);

/* `use_preallocated` != 0 makes the shim allocate the backing store itself and
 * hand it to miniaudio (the pOptionalPreallocatedBuffer path); the shim then
 * owns that memory and frees it on uninit/free. */
int ma_shim_rb_init_ex(
    void*              handle,
    unsigned long long subbuffer_size_in_bytes,
    unsigned long long subbuffer_count,
    unsigned long long subbuffer_stride_in_bytes,
    int                use_preallocated
);

int ma_shim_rb_uninit(void* handle);
int ma_shim_rb_reset(void* handle);

int ma_shim_rb_write(
    void*               handle,
    const void*         src,
    unsigned long long  size_in_bytes,
    unsigned long long* bytes_written_out
);
int ma_shim_rb_read(
    void*               handle,
    void*               dst,
    unsigned long long  size_in_bytes,
    unsigned long long* bytes_read_out
);

int ma_shim_rb_seek_read(void* handle, unsigned long long offset_in_bytes);
int ma_shim_rb_seek_write(void* handle, unsigned long long offset_in_bytes);

int ma_shim_rb_pointer_distance(void* handle, int* out_distance);
int ma_shim_rb_available_read(void* handle, unsigned int* out_available);
int ma_shim_rb_available_write(void* handle, unsigned int* out_available);

int ma_shim_rb_get_subbuffer_size(void* handle, unsigned long long* out_size);
int ma_shim_rb_get_subbuffer_stride(void* handle, unsigned long long* out_stride);
int ma_shim_rb_get_subbuffer_offset(
    void*               handle,
    unsigned long long  subbuffer_index,
    unsigned long long* out_offset
);
int ma_shim_rb_get_subbuffer_ptr_offset(
    void*               handle,
    unsigned long long  subbuffer_index,
    unsigned long long* out_offset
);

/* ---- ma_pcm_rb — frame-oriented ring buffer ---- */

void* ma_shim_pcm_rb_alloc(void);
void  ma_shim_pcm_rb_free(void* handle);

int ma_shim_pcm_rb_init(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int buffer_size_in_frames
);
int ma_shim_pcm_rb_init_ex(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int subbuffer_size_in_frames,
    unsigned int subbuffer_count,
    unsigned int subbuffer_stride_in_frames,
    int          use_preallocated
);

int ma_shim_pcm_rb_uninit(void* handle);
int ma_shim_pcm_rb_reset(void* handle);

int ma_shim_pcm_rb_write(
    void*         handle,
    const void*   src,
    unsigned int  frame_count,
    unsigned int* frames_written_out
);
int ma_shim_pcm_rb_read(
    void*         handle,
    void*         dst,
    unsigned int  frame_count,
    unsigned int* frames_read_out
);

int ma_shim_pcm_rb_seek_read(void* handle, unsigned int offset_in_frames);
int ma_shim_pcm_rb_seek_write(void* handle, unsigned int offset_in_frames);

int ma_shim_pcm_rb_pointer_distance(void* handle, int* out_distance);
int ma_shim_pcm_rb_available_read(void* handle, unsigned int* out_available);
int ma_shim_pcm_rb_available_write(void* handle, unsigned int* out_available);

int ma_shim_pcm_rb_get_subbuffer_size(void* handle, unsigned int* out_size);
int ma_shim_pcm_rb_get_subbuffer_stride(void* handle, unsigned int* out_stride);
int ma_shim_pcm_rb_get_subbuffer_offset(
    void*         handle,
    unsigned int  subbuffer_index,
    unsigned int* out_offset
);
int ma_shim_pcm_rb_get_subbuffer_ptr_offset(
    void*               handle,
    unsigned int        subbuffer_index,
    unsigned long long* out_offset
);

int ma_shim_pcm_rb_get_data_format(
    void*         handle,
    int*          out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
);
int ma_shim_pcm_rb_set_sample_rate(void* handle, unsigned int sample_rate);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_RING_BUFFER_H */
