#ifndef MA_SHIM_AUDIO_BUFFER_H
#define MA_SHIM_AUDIO_BUFFER_H

/* ---- audio buffer (opaque handles over ma_audio_buffer_ref and ma_audio_buffer) ----
 *
 * Two in-memory PCM buffers that are also data sources:
 *   - ma_audio_buffer_ref — a non-owning *view* over frames the caller keeps alive
 *   - ma_audio_buffer     — the owning variant, initialised from a config
 *
 * Neither needs a device, engine, or file, so the whole family is deterministic.
 *
 * Data ownership: `ma_audio_buffer_ref_init` / `_set_data` and the non-copying
 * `ma_audio_buffer_init` all store the caller's pointer verbatim, which no Mojo
 * value can safely outlive across FFI calls. The shim therefore copies the
 * frames into its own allocation and hands miniaudio *that* pointer, freeing it
 * on uninit. `ma_audio_buffer_init_copy` and `ma_audio_buffer_alloc_and_init`
 * copy internally, so they read straight from the caller's frames.
 *
 * map/unmap hand out a pointer into the buffer's interior, which again has no
 * safe Mojo home, so the shim owns the map -> memcpy -> unmap sequence and
 * exposes it as `*_map_read`. That entry point returns MA_AT_END (successful,
 * per miniaudio) when the unmap leaves the cursor exactly at the end.
 *
 * Sample format codes match ma_format: unknown=0, u8=1, s16=2, s24=3, s32=4,
 * f32=5.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ---- ma_audio_buffer_ref — non-owning view ---- */

void* ma_shim_audio_buffer_ref_alloc(void);
void  ma_shim_audio_buffer_ref_free(void* handle);

/* Copies frame_count frames from `src` into shim-owned memory and points the
 * ref at that copy. A NULL `src` or a zero frame count is rejected. */
int ma_shim_audio_buffer_ref_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
);

int ma_shim_audio_buffer_ref_uninit(void* handle);

/* Replaces the shim-owned copy with `frame_count` frames from `src` and rewinds
 * the cursor to 0. */
int ma_shim_audio_buffer_ref_set_data(
    void*              handle,
    const void*        src,
    unsigned long long frame_count
);

int ma_shim_audio_buffer_ref_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    int                 loop,
    unsigned long long* frames_read_out
);

int ma_shim_audio_buffer_ref_seek(void* handle, unsigned long long frame_index);

/* map -> memcpy -> unmap. Returns MA_AT_END when the unmap lands the cursor on
 * the end of the buffer; that is a success, not an error. */
int ma_shim_audio_buffer_ref_map_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_mapped_out
);

int ma_shim_audio_buffer_ref_at_end(void* handle, int* out_at_end);
int ma_shim_audio_buffer_ref_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_audio_buffer_ref_get_length(void* handle, unsigned long long* out_length);
int ma_shim_audio_buffer_ref_get_available(void* handle, unsigned long long* out_available);

/* ---- ma_audio_buffer — owning buffer ---- */

void* ma_shim_audio_buffer_alloc(void);
void  ma_shim_audio_buffer_free(void* handle);

/* Non-copying init: miniaudio keeps the config's data pointer, so the shim
 * keeps its own copy of the frames alive for the buffer's lifetime. */
int ma_shim_audio_buffer_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
);

/* Copying init: miniaudio allocates and copies, so `src` is only read during
 * the call. A NULL `src` yields a silent buffer. */
int ma_shim_audio_buffer_init_copy(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
);

/* Heap-allocates the ma_audio_buffer itself (frames live in its trailing extra
 * data) and tears it down with ma_audio_buffer_uninit_and_free.
 *
 * UPSTREAM DEFECT (miniaudio 0.11.25): ma_audio_buffer_alloc_and_init copies the
 * frames into `_pExtraData` and *then* calls ma_audio_buffer_init_ex, whose
 * `MA_ZERO_MEMORY(p, sizeof(*p) - sizeof(p->_pExtraData))` overshoots by the
 * struct's trailing padding — `_pExtraData` is declared `ma_uint8[1]`, so the
 * zeroing runs 3 bytes into the audio data on a 4-byte-aligned layout. The
 * first frame therefore comes back with its low 3 bytes cleared (an f32 20.0
 * reads back as 8.0). The shim binds the function as-is rather than papering
 * over it; use ma_audio_buffer_init_copy when the first frame matters. */
int ma_shim_audio_buffer_alloc_and_init(
    void*              handle,
    int                format,
    unsigned int       channels,
    const void*        src,
    unsigned long long frame_count
);

int ma_shim_audio_buffer_uninit(void* handle);

int ma_shim_audio_buffer_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    int                 loop,
    unsigned long long* frames_read_out
);

int ma_shim_audio_buffer_seek(void* handle, unsigned long long frame_index);

int ma_shim_audio_buffer_map_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_mapped_out
);

int ma_shim_audio_buffer_at_end(void* handle, int* out_at_end);
int ma_shim_audio_buffer_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_audio_buffer_get_length(void* handle, unsigned long long* out_length);
int ma_shim_audio_buffer_get_available(void* handle, unsigned long long* out_available);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_AUDIO_BUFFER_H */
