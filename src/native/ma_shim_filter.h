#ifndef MA_SHIM_FILTER_H
#define MA_SHIM_FILTER_H

/* ---- filters (opaque handles over miniaudio's biquad-derived filter family) ----
 *
 * Every filter in this group has the same lifecycle — config_init,
 * get_heap_size, init / init_preallocated, reinit, process_pcm_frames,
 * get_latency, uninit — differing only in what its config takes. The shim keeps
 * that shape one-for-one, so each filter here reads the same way:
 *
 *   <f>_alloc / <f>_free        own the handle
 *   <f>_get_heap_size           heap this configuration needs, without building
 *   <f>_init                    miniaudio owns the working heap
 *   <f>_init_preallocated       the shim owns it (get_heap_size + a shim block)
 *   <f>_reinit                  retune in place, keeping the filter state
 *   <f>_process                 filter frame_count frames out-of-place
 *   <f>_get_latency             latency in frames
 *   <f>_clear_cache             drop the filter memory (where miniaudio has it)
 *   <f>_uninit                  release, leaving the handle reusable
 *
 * Covered here: ma_biquad (raw coefficients), the first- and second-order
 * building blocks ma_lpf1 / ma_lpf2 / ma_hpf1 / ma_hpf2, and the compound
 * ma_lpf / ma_hpf, which stack those blocks to reach an arbitrary order.
 *
 * Only ma_biquad, ma_lpf1, ma_lpf2 and ma_lpf expose clear_cache upstream; the
 * high-pass filters have no such entry point, so none is bound for them.
 *
 * The *_node variants wrap the same filters as node-graph nodes. They need a
 * graph to attach to, which they take as an engine handle from the engine shim
 * (the same route ma_shim_data_source_node uses).
 *
 * Sample format codes match ma_format (f32=5). Filters here are exercised in
 * f32; miniaudio also supports s16.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= ma_biquad — raw coefficients ================= */

void* ma_shim_biquad_alloc(void);
void  ma_shim_biquad_free(void* handle);

int ma_shim_biquad_get_heap_size(
    int                 format,
    unsigned int        channels,
    double              b0, double b1, double b2,
    double              a0, double a1, double a2,
    unsigned long long* out_heap_size
);
int ma_shim_biquad_init(
    void*        handle,
    int          format,
    unsigned int channels,
    double       b0, double b1, double b2,
    double       a0, double a1, double a2
);
int ma_shim_biquad_init_preallocated(
    void*        handle,
    int          format,
    unsigned int channels,
    double       b0, double b1, double b2,
    double       a0, double a1, double a2
);
int ma_shim_biquad_reinit(
    void*        handle,
    int          format,
    unsigned int channels,
    double       b0, double b1, double b2,
    double       a0, double a1, double a2
);
int ma_shim_biquad_uninit(void* handle);
int ma_shim_biquad_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_biquad_get_latency(void* handle, unsigned int* out_latency);
int ma_shim_biquad_clear_cache(void* handle);

/* ================= first-order building blocks ================= */

void* ma_shim_lpf1_alloc(void);
void  ma_shim_lpf1_free(void* handle);
int ma_shim_lpf1_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned long long* out_heap_size);
int ma_shim_lpf1_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_lpf1_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_lpf1_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_lpf1_uninit(void* handle);
int ma_shim_lpf1_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_lpf1_get_latency(void* handle, unsigned int* out_latency);
int ma_shim_lpf1_clear_cache(void* handle);

void* ma_shim_hpf1_alloc(void);
void  ma_shim_hpf1_free(void* handle);
int ma_shim_hpf1_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned long long* out_heap_size);
int ma_shim_hpf1_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_hpf1_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_hpf1_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff);
int ma_shim_hpf1_uninit(void* handle);
int ma_shim_hpf1_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_hpf1_get_latency(void* handle, unsigned int* out_latency);

/* ================= second-order building blocks ================= */

void* ma_shim_lpf2_alloc(void);
void  ma_shim_lpf2_free(void* handle);
int ma_shim_lpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q,
    unsigned long long* out_heap_size);
int ma_shim_lpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_lpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_lpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_lpf2_uninit(void* handle);
int ma_shim_lpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_lpf2_get_latency(void* handle, unsigned int* out_latency);
int ma_shim_lpf2_clear_cache(void* handle);

void* ma_shim_hpf2_alloc(void);
void  ma_shim_hpf2_free(void* handle);
int ma_shim_hpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q,
    unsigned long long* out_heap_size);
int ma_shim_hpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_hpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_hpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_hpf2_uninit(void* handle);
int ma_shim_hpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_hpf2_get_latency(void* handle, unsigned int* out_latency);

/* ================= compound (arbitrary order) ================= */

void* ma_shim_lpf_alloc(void);
void  ma_shim_lpf_free(void* handle);
int ma_shim_lpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned int order, unsigned long long* out_heap_size);
int ma_shim_lpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_lpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_lpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_lpf_uninit(void* handle);
int ma_shim_lpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_lpf_get_latency(void* handle, unsigned int* out_latency);
int ma_shim_lpf_clear_cache(void* handle);

void* ma_shim_hpf_alloc(void);
void  ma_shim_hpf_free(void* handle);
int ma_shim_hpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned int order, unsigned long long* out_heap_size);
int ma_shim_hpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_hpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_hpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_hpf_uninit(void* handle);
int ma_shim_hpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_hpf_get_latency(void* handle, unsigned int* out_latency);

/* ================= node-graph variants ================= */

void* ma_shim_biquad_node_alloc(void);
void  ma_shim_biquad_node_free(void* handle);
/* `engine_handle` comes from the engine shim; its node graph hosts the node. */
int ma_shim_biquad_node_init(
    void* handle, void* engine_handle, unsigned int channels,
    float b0, float b1, float b2, float a0, float a1, float a2);
int ma_shim_biquad_node_reinit(
    void* handle, int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2);
int ma_shim_biquad_node_uninit(void* handle);

void* ma_shim_lpf_node_alloc(void);
void  ma_shim_lpf_node_free(void* handle);
int ma_shim_lpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_lpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_lpf_node_uninit(void* handle);

void* ma_shim_hpf_node_alloc(void);
void  ma_shim_hpf_node_free(void* handle);
int ma_shim_hpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_hpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_hpf_node_uninit(void* handle);

/* ================= band-pass, notch and the shelving/peaking filters ================= */

/* Same lifecycle as above; only the tuning differs.
 *   bpf2 / bpf   — band-pass, second order and compound
 *   notch2       — a notch at `frequency`, width set by `q`
 *   peak2        — a peaking EQ band: `gain_db` at `frequency`, width by `q`
 *   loshelf2 / hishelf2 — shelving filters: `gain_db` below / above `frequency`,
 *                  with `shelf_slope` setting how steeply the shelf turns
 * None of these has a clear_cache entry point upstream. */

void* ma_shim_bpf2_alloc(void);
void  ma_shim_bpf2_free(void* handle);
int ma_shim_bpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q,
    unsigned long long* out_heap_size);
int ma_shim_bpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_bpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_bpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q);
int ma_shim_bpf2_uninit(void* handle);
int ma_shim_bpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_bpf2_get_latency(void* handle, unsigned int* out_latency);

void* ma_shim_bpf_alloc(void);
void  ma_shim_bpf_free(void* handle);
int ma_shim_bpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned int order, unsigned long long* out_heap_size);
int ma_shim_bpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_bpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_bpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_bpf_uninit(void* handle);
int ma_shim_bpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_bpf_get_latency(void* handle, unsigned int* out_latency);

void* ma_shim_notch2_alloc(void);
void  ma_shim_notch2_free(void* handle);
int ma_shim_notch2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double q, double frequency,
    unsigned long long* out_heap_size);
int ma_shim_notch2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double q, double frequency);
int ma_shim_notch2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double q, double frequency);
int ma_shim_notch2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double q, double frequency);
int ma_shim_notch2_uninit(void* handle);
int ma_shim_notch2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_notch2_get_latency(void* handle, unsigned int* out_latency);

void* ma_shim_peak2_alloc(void);
void  ma_shim_peak2_free(void* handle);
int ma_shim_peak2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency, unsigned long long* out_heap_size);
int ma_shim_peak2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_peak2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_peak2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_peak2_uninit(void* handle);
int ma_shim_peak2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_peak2_get_latency(void* handle, unsigned int* out_latency);

void* ma_shim_loshelf2_alloc(void);
void  ma_shim_loshelf2_free(void* handle);
int ma_shim_loshelf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency, unsigned long long* out_heap_size);
int ma_shim_loshelf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_loshelf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_loshelf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_loshelf2_uninit(void* handle);
int ma_shim_loshelf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_loshelf2_get_latency(void* handle, unsigned int* out_latency);

void* ma_shim_hishelf2_alloc(void);
void  ma_shim_hishelf2_free(void* handle);
int ma_shim_hishelf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency, unsigned long long* out_heap_size);
int ma_shim_hishelf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_hishelf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_hishelf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_hishelf2_uninit(void* handle);
int ma_shim_hishelf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count);
int ma_shim_hishelf2_get_latency(void* handle, unsigned int* out_latency);

/* ---- their node-graph variants ---- */

void* ma_shim_bpf_node_alloc(void);
void  ma_shim_bpf_node_free(void* handle);
int ma_shim_bpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_bpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order);
int ma_shim_bpf_node_uninit(void* handle);

void* ma_shim_notch_node_alloc(void);
void  ma_shim_notch_node_free(void* handle);
int ma_shim_notch_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double q, double frequency);
int ma_shim_notch_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double q, double frequency);
int ma_shim_notch_node_uninit(void* handle);

void* ma_shim_peak_node_alloc(void);
void  ma_shim_peak_node_free(void* handle);
int ma_shim_peak_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_peak_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_peak_node_uninit(void* handle);

/* The shelf *nodes* take a q where the standalone shelf filters take a shelf
 * slope; that is miniaudio's own asymmetry, kept as-is. */
void* ma_shim_loshelf_node_alloc(void);
void  ma_shim_loshelf_node_free(void* handle);
int ma_shim_loshelf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_loshelf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_loshelf_node_uninit(void* handle);

void* ma_shim_hishelf_node_alloc(void);
void  ma_shim_hishelf_node_free(void* handle);
int ma_shim_hishelf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double gain_db, double q, double frequency);
int ma_shim_hishelf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double gain_db, double shelf_slope, double frequency);
int ma_shim_hishelf_node_uninit(void* handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_FILTER_H */
