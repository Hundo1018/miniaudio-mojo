#ifndef MA_SHIM_DATA_SOURCE_H
#define MA_SHIM_DATA_SOURCE_H

/* ---- data_source (opaque handle; a shim-owned custom ma_data_source) ----
 *
 * ma_data_source is miniaudio's *abstract base*: every concrete source
 * (decoder, waveform, noise, audio buffer) embeds an ma_data_source_base and
 * supplies a vtable of C function pointers. Mojo cannot author that vtable, so
 * the shim owns a concrete implementation -- a buffer data source reading from
 * an f32 PCM buffer copied into the handle -- and exposes the generic
 * ma_data_source_* operations against it. This keeps the family fully
 * exercisable from Mojo with no device, engine, or file dependency.
 *
 * The handle owns its sample buffer (copied at init), so the caller's Mojo
 * buffer need not outlive the data source.
 *
 * Chaining note: set_current/set_next take another data-source handle (or NULL).
 * The getters deliberately report an *identity comparison* against a caller
 * supplied handle rather than returning the raw non-owning ma_data_source*,
 * which the RAII model above has no safe home for.
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void* ma_shim_data_source_alloc(void);
void  ma_shim_data_source_free(void* handle);

/* Initialise as a buffer data source over a copy of `frames`
 * (frame_count * channels interleaved f32 samples). */
int ma_shim_data_source_init_buffer(
    void* handle,
    const float* frames,
    unsigned long long frame_count,
    unsigned int channels,
    unsigned int sample_rate
);
int ma_shim_data_source_uninit(void* handle);

/* read/seek */
int ma_shim_data_source_read_pcm_frames(
    void* handle,
    void* output,
    unsigned long long frame_count,
    unsigned long long* frames_read
);
int ma_shim_data_source_seek_pcm_frames(
    void* handle,
    unsigned long long frame_count,
    unsigned long long* frames_seeked
);
int ma_shim_data_source_seek_to_pcm_frame(void* handle, unsigned long long frame_index);
int ma_shim_data_source_seek_seconds(
    void* handle,
    float second_count,
    float* seconds_seeked
);
int ma_shim_data_source_seek_to_second(void* handle, float seek_point_in_seconds);

/* format / position / length queries */
int ma_shim_data_source_get_data_format(
    void* handle,
    int* out_format,
    unsigned int* out_channels,
    unsigned int* out_sample_rate
);
int ma_shim_data_source_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);
int ma_shim_data_source_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);
int ma_shim_data_source_get_cursor_in_seconds(void* handle, float* out_cursor);
int ma_shim_data_source_get_length_in_seconds(void* handle, float* out_length);

/* looping */
int ma_shim_data_source_set_looping(void* handle, int is_looping);
int ma_shim_data_source_is_looping(void* handle);

/* range / loop point */
int ma_shim_data_source_set_range_in_pcm_frames(
    void* handle,
    unsigned long long range_beg,
    unsigned long long range_end
);
int ma_shim_data_source_get_range_in_pcm_frames(
    void* handle,
    unsigned long long* out_beg,
    unsigned long long* out_end
);
int ma_shim_data_source_set_loop_point_in_pcm_frames(
    void* handle,
    unsigned long long loop_beg,
    unsigned long long loop_end
);
int ma_shim_data_source_get_loop_point_in_pcm_frames(
    void* handle,
    unsigned long long* out_beg,
    unsigned long long* out_end
);

/* chaining. `expected` may be NULL to test for "no current/next". Passing a
 * NULL current/next handle clears it -- for set_current that means "no current
 * source", not "read from self" (pass the handle itself to restore that). */
int ma_shim_data_source_set_current(void* handle, void* current_handle);
int ma_shim_data_source_current_is(void* handle, void* expected_handle, int* out_is);
int ma_shim_data_source_set_next(void* handle, void* next_handle);
int ma_shim_data_source_next_is(void* handle, void* expected_handle, int* out_is);

/* next-callback. The callback itself is shim-owned (C); it returns the handle
 * registered by `set_next_callback`. Pass a NULL next_handle to clear it. */
int ma_shim_data_source_set_next_callback(void* handle, void* next_handle);
int ma_shim_data_source_has_next_callback(void* handle, int* out_has_callback);

/* ---- data_source_node (a node-graph node that pulls from a data source) ----
 *
 * Initialised against an engine handle's node graph; attaches to the graph
 * endpoint by default. Must not outlive its engine or its data source.
 */
void* ma_shim_data_source_node_alloc(void);
void  ma_shim_data_source_node_free(void* handle);

int ma_shim_data_source_node_init(
    void* handle,
    void* engine_handle,
    void* data_source_handle
);
int ma_shim_data_source_node_uninit(void* handle);
int ma_shim_data_source_node_set_looping(void* handle, int is_looping);
int ma_shim_data_source_node_is_looping(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_DATA_SOURCE_H */
