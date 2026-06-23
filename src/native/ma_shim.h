#ifndef MA_SHIM_H
#define MA_SHIM_H

/*
 * ma_shim — thin passthrough shim over miniaudio.
 *
 * Design contract (see docs/binding-architecture.md):
 *   - Opaque allocation only (malloc of an miniaudio handle + an `initialized`
 *     bookkeeping flag). No scenario logic, no smoke flows, no synthesis.
 *   - Config marshalling is limited to building the standard ma_*_config from
 *     primitive arguments and forwarding to the real ma_* function.
 *   - Field accessors use miniaudio's public query APIs (Mojo cannot read C
 *     struct layout directly).
 *   - Every entry point returns a raw ma_result int (or a documented sentinel),
 *     leaving all policy to the Mojo layers above.
 *
 * Sample-format codes match miniaudio's ma_format enum exactly:
 *   unknown=0, u8=1, s16=2, s24=3, s32=4, f32=5.
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- core ---- */
const char* ma_shim_version(void);
const char* ma_shim_result_description(int result_code);

/* ---- decoder (opaque handle) ---- */
void* ma_shim_decoder_alloc(void);
void  ma_shim_decoder_free(void* handle);

int ma_shim_decoder_init_file(
    void* handle,
    const char* file_path,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
);
int ma_shim_decoder_init_memory(
    void* handle,
    const void* data,
    size_t data_size,
    int output_format,
    unsigned int output_channels,
    unsigned int output_sample_rate
);
int ma_shim_decoder_uninit(void* handle);

int ma_shim_decoder_read_pcm_frames(
    void* handle,
    void* output,
    unsigned long long frame_count,
    unsigned long long* frames_read
);
int ma_shim_decoder_seek_to_pcm_frame(void* handle, unsigned long long frame_index);
int ma_shim_decoder_get_length_in_pcm_frames(void* handle, unsigned long long* out_length);
int ma_shim_decoder_get_cursor_in_pcm_frames(void* handle, unsigned long long* out_cursor);

/* Field accessors via ma_decoder_get_data_format; return 0 on any error. */
unsigned int ma_shim_decoder_output_channels(void* handle);
unsigned int ma_shim_decoder_output_sample_rate(void* handle);
int          ma_shim_decoder_output_format(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_H */
