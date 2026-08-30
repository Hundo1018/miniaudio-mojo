#ifndef MA_SHIM_PAGED_AUDIO_BUFFER_H
#define MA_SHIM_PAGED_AUDIO_BUFFER_H

/* ---- paged audio buffer (opaque handle over ma_paged_audio_buffer{,_data}) ----
 *
 * A linked list of PCM pages that can be appended to while it is being read —
 * expandable but not shrinkable, and purely in-memory, so no device, engine, or
 * file is involved.
 *
 * One shim handle owns both halves of the family: the `_data` list (the pages)
 * and the `ma_paged_audio_buffer` reader over it. They have separate lifetimes
 * in miniaudio, and the shim keeps that split — `data_init` / `data_uninit`
 * manage the pages, `init` / `uninit` manage the reader.
 *
 * Pages are `ma_paged_audio_buffer_page*` values, which have no safe Mojo home.
 * `data_allocate_page` therefore parks the page in a slot on the handle and
 * returns the slot index; `data_append_page` and `data_free_page` take that
 * index back. Slots still holding a page when the handle is freed are released
 * with it, so an allocate with no matching append/free cannot leak.
 *
 * `data_get_head` / `data_get_tail` return raw page pointers. They are bound as
 * the properties of those pages Mojo can assert on: the page's frame count, and
 * whether the list is still empty (miniaudio's head is a zero-length dummy and
 * the tail starts out pointing at it).
 *
 * Sample format codes match ma_format: unknown=0, u8=1, s16=2, s24=3, s32=4,
 * f32=5.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* Number of pages that can be allocated but not yet appended or freed. */
#define MA_SHIM_PAB_MAX_PENDING_PAGES 8

void* ma_shim_paged_audio_buffer_alloc(void);
void  ma_shim_paged_audio_buffer_free(void* handle);

/* ---- the page list (ma_paged_audio_buffer_data) ---- */

int ma_shim_paged_audio_buffer_data_init(void* handle, int format, unsigned int channels);
int ma_shim_paged_audio_buffer_data_uninit(void* handle);

int ma_shim_paged_audio_buffer_data_get_length(void* handle, unsigned long long* out_length);

/* head is miniaudio's zero-length dummy page; `out_has_pages` reports whether
 * anything has been appended behind it. */
int ma_shim_paged_audio_buffer_data_get_head(
    void*               handle,
    unsigned long long* out_size_in_frames,
    int*                out_has_pages
);

/* tail is the most recently appended page, or the head dummy while empty. */
int ma_shim_paged_audio_buffer_data_get_tail(
    void*               handle,
    unsigned long long* out_size_in_frames,
    int*                out_is_head
);

/* Allocates a page and parks it in a handle slot; `out_slot` indexes it. */
int ma_shim_paged_audio_buffer_data_allocate_page(
    void*              handle,
    unsigned long long page_size_in_frames,
    const void*        src,
    int*               out_slot
);

/* Appends the page parked in `slot` and empties the slot. */
int ma_shim_paged_audio_buffer_data_append_page(void* handle, int slot);

/* Frees the page parked in `slot` without appending it. */
int ma_shim_paged_audio_buffer_data_free_page(void* handle, int slot);

int ma_shim_paged_audio_buffer_data_allocate_and_append_page(
    void*        handle,
    unsigned int page_size_in_frames,
    const void*  src
);

/* ---- the reader (ma_paged_audio_buffer) ---- */

int ma_shim_paged_audio_buffer_init(void* handle);
int ma_shim_paged_audio_buffer_uninit(void* handle);

/* Returns MA_AT_END once the pages run out; that is a successful short read. */
int ma_shim_paged_audio_buffer_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);

int ma_shim_paged_audio_buffer_seek(void* handle, unsigned long long frame_index);
int ma_shim_paged_audio_buffer_get_cursor(void* handle, unsigned long long* out_cursor);
int ma_shim_paged_audio_buffer_get_length(void* handle, unsigned long long* out_length);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_PAGED_AUDIO_BUFFER_H */
