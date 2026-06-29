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

/* ---- encoder (opaque handle; WAV output) ---- */
void* ma_shim_encoder_alloc(void);
void  ma_shim_encoder_free(void* handle);

int ma_shim_encoder_init_file(
    void* handle,
    const char* file_path,
    int encoding_format,
    int format,
    unsigned int channels,
    unsigned int sample_rate
);
int ma_shim_encoder_uninit(void* handle);

int ma_shim_encoder_write_pcm_frames(
    void* handle,
    const void* input,
    unsigned long long frame_count,
    unsigned long long* frames_written
);

/* ---- device (opaque handle; playback pulling from a decoder) ----
 *
 * The device's data callback is owned by the shim (C); it pulls f32 PCM from a
 * decoder handle (an allocation from ma_shim_decoder_alloc that has been
 * initialised). No Mojo callback crosses the FFI boundary. `use_null_backend`
 * selects miniaudio's null backend for hardware-independent, deterministic
 * operation (tests); 0 uses the default backend (real audio output).
 */
void* ma_shim_device_alloc(void);
void  ma_shim_device_free(void* handle);

int ma_shim_device_init_playback_from_decoder(
    void* handle,
    void* decoder_handle,
    unsigned int sample_rate_override,
    int use_null_backend
);
int ma_shim_device_start(void* handle);
int ma_shim_device_stop(void* handle);
int ma_shim_device_uninit(void* handle);

unsigned int       ma_shim_device_get_channels(void* handle);
unsigned int       ma_shim_device_get_sample_rate(void* handle);
unsigned long long ma_shim_device_get_frames_processed(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_H */
