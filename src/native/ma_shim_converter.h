#ifndef MA_SHIM_CONVERTER_H
#define MA_SHIM_CONVERTER_H

/* ---- converters (opaque handles over the three conversion families) ----
 *
 *   - ma_resampler         — sample-rate conversion
 *   - ma_channel_converter — channel-count / channel-map conversion
 *   - ma_data_converter    — format + channels + rate in one pipeline
 *
 * All three are pure DSP objects: no device, engine, or file is involved, so
 * the whole group is deterministic and hardware-independent.
 *
 * Each family exposes two init paths. `init` lets miniaudio allocate its own
 * working heap; `init_preallocated` asks miniaudio how big that heap needs to
 * be (`get_heap_size`) and hands it a shim-owned block instead. The shim owns
 * that block and frees it on uninit, so both paths look the same from Mojo.
 *
 * `process` takes an input and an output frame count *by reference* on the
 * resampler and the data converter — miniaudio writes back how many of each it
 * actually consumed and produced. The shim keeps that shape: the counts go in
 * as requests and come back as actuals. The channel converter converts a fixed
 * frame count instead, since it never changes the frame rate.
 *
 * Channel maps are ma_channel (ma_uint8) arrays; the getters fill a caller
 * buffer capped at the converter's channel count.
 *
 * Sample format codes match ma_format (f32=5, s16=2). Resample algorithm codes
 * match ma_resample_algorithm: linear=0, custom=1. Channel mix modes match
 * ma_channel_mix_mode: rectangular=0, simple=1, custom_weights=2.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= ma_resampler ================= */

void* ma_shim_resampler_alloc(void);
void  ma_shim_resampler_free(void* handle);

/* Heap size miniaudio needs for this configuration, without initialising. */
int ma_shim_resampler_get_heap_size(
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate_in,
    unsigned int        sample_rate_out,
    int                 algorithm,
    unsigned long long* out_heap_size
);

int ma_shim_resampler_init(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out,
    int          algorithm
);

/* Same, but through miniaudio's preallocated-heap path with a shim-owned block. */
int ma_shim_resampler_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out,
    int          algorithm
);

int ma_shim_resampler_uninit(void* handle);

/* frame_count_in / frame_count_out go in as requests, come back as actuals. */
int ma_shim_resampler_process(
    void*               handle,
    const void*         frames_in,
    unsigned long long* frame_count_in,
    void*               frames_out,
    unsigned long long* frame_count_out
);

int ma_shim_resampler_set_rate(void* handle, unsigned int rate_in, unsigned int rate_out);
int ma_shim_resampler_set_rate_ratio(void* handle, float ratio);
int ma_shim_resampler_get_input_latency(void* handle, unsigned long long* out_latency);
int ma_shim_resampler_get_output_latency(void* handle, unsigned long long* out_latency);
int ma_shim_resampler_get_required_input_frame_count(
    void*               handle,
    unsigned long long  output_frame_count,
    unsigned long long* out_input_frame_count
);
int ma_shim_resampler_get_expected_output_frame_count(
    void*               handle,
    unsigned long long  input_frame_count,
    unsigned long long* out_output_frame_count
);
int ma_shim_resampler_reset(void* handle);

/* ================= ma_channel_converter ================= */

void* ma_shim_channel_converter_alloc(void);
void  ma_shim_channel_converter_free(void* handle);

int ma_shim_channel_converter_get_heap_size(
    int                 format,
    unsigned int        channels_in,
    unsigned int        channels_out,
    int                 mix_mode,
    unsigned long long* out_heap_size
);

int ma_shim_channel_converter_init(
    void*        handle,
    int          format,
    unsigned int channels_in,
    unsigned int channels_out,
    int          mix_mode
);

int ma_shim_channel_converter_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels_in,
    unsigned int channels_out,
    int          mix_mode
);

int ma_shim_channel_converter_uninit(void* handle);

/* Converts exactly frame_count frames; the frame rate is unchanged. */
int ma_shim_channel_converter_process(
    void*              handle,
    void*              frames_out,
    const void*        frames_in,
    unsigned long long frame_count
);

int ma_shim_channel_converter_get_input_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
);
int ma_shim_channel_converter_get_output_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
);

/* ================= ma_data_converter ================= */

void* ma_shim_data_converter_alloc(void);
void  ma_shim_data_converter_free(void* handle);

int ma_shim_data_converter_get_heap_size(
    int                 format_in,
    int                 format_out,
    unsigned int        channels_in,
    unsigned int        channels_out,
    unsigned int        sample_rate_in,
    unsigned int        sample_rate_out,
    unsigned long long* out_heap_size
);

int ma_shim_data_converter_init(
    void*        handle,
    int          format_in,
    int          format_out,
    unsigned int channels_in,
    unsigned int channels_out,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
);

/* Starts from miniaudio's default config and only overrides the pass-through
 * format / channels / rate, so the defaults themselves stay observable. */
int ma_shim_data_converter_init_default(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate
);

int ma_shim_data_converter_init_preallocated(
    void*        handle,
    int          format_in,
    int          format_out,
    unsigned int channels_in,
    unsigned int channels_out,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
);

int ma_shim_data_converter_uninit(void* handle);

int ma_shim_data_converter_process(
    void*               handle,
    const void*         frames_in,
    unsigned long long* frame_count_in,
    void*               frames_out,
    unsigned long long* frame_count_out
);

int ma_shim_data_converter_set_rate(void* handle, unsigned int rate_in, unsigned int rate_out);
int ma_shim_data_converter_set_rate_ratio(void* handle, float ratio);
int ma_shim_data_converter_get_input_latency(void* handle, unsigned long long* out_latency);
int ma_shim_data_converter_get_output_latency(void* handle, unsigned long long* out_latency);
int ma_shim_data_converter_get_required_input_frame_count(
    void*               handle,
    unsigned long long  output_frame_count,
    unsigned long long* out_input_frame_count
);
int ma_shim_data_converter_get_expected_output_frame_count(
    void*               handle,
    unsigned long long  input_frame_count,
    unsigned long long* out_output_frame_count
);
int ma_shim_data_converter_get_input_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
);
int ma_shim_data_converter_get_output_channel_map(
    void*          handle,
    unsigned char* out_map,
    unsigned int   capacity
);
int ma_shim_data_converter_reset(void* handle);

/* ================= ma_linear_resampler ================= */

/* miniaudio's linear resampler is what ma_resampler drives underneath when the
 * algorithm is linear. It is bound in its own right too, with the same shape as
 * ma_resampler minus the algorithm selector. */

void* ma_shim_linear_resampler_alloc(void);
void  ma_shim_linear_resampler_free(void* handle);

int ma_shim_linear_resampler_get_heap_size(
    int                 format,
    unsigned int        channels,
    unsigned int        sample_rate_in,
    unsigned int        sample_rate_out,
    unsigned long long* out_heap_size
);
int ma_shim_linear_resampler_init(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
);
int ma_shim_linear_resampler_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels,
    unsigned int sample_rate_in,
    unsigned int sample_rate_out
);
int ma_shim_linear_resampler_uninit(void* handle);
int ma_shim_linear_resampler_process(
    void*               handle,
    const void*         frames_in,
    unsigned long long* frame_count_in,
    void*               frames_out,
    unsigned long long* frame_count_out
);
int ma_shim_linear_resampler_set_rate(
    void* handle, unsigned int rate_in, unsigned int rate_out);
int ma_shim_linear_resampler_set_rate_ratio(void* handle, float ratio);
int ma_shim_linear_resampler_get_input_latency(void* handle, unsigned long long* out_latency);
int ma_shim_linear_resampler_get_output_latency(void* handle, unsigned long long* out_latency);
int ma_shim_linear_resampler_get_required_input_frame_count(
    void* handle, unsigned long long output_frame_count, unsigned long long* out_count);
int ma_shim_linear_resampler_get_expected_output_frame_count(
    void* handle, unsigned long long input_frame_count, unsigned long long* out_count);
int ma_shim_linear_resampler_reset(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_CONVERTER_H */
