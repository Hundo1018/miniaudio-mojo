#include "ma_shim_filter.h"
#include "ma_shim_internal.h"
#include "miniaudio.h"

#include <stdlib.h>

/* Every filter here has the same handle shape and the same teardown, so those
 * are generated once per filter. The exported entry points are written out
 * individually rather than generated: each one carries the `@binds` annotation
 * the coverage checker reads, and that annotation has to sit next to a real
 * `ma_shim_<name>(` token to be seen. */
#define MA_SHIM_FILTER_HANDLE(NAME, TYPE)                                          \
    typedef struct ma_shim_##NAME##_state {                                        \
        TYPE  filter;                                                              \
        void* heap;   /* non-NULL when the preallocated path was used */           \
        int   initialized;                                                         \
    } ma_shim_##NAME##_state;                                                      \
                                                                                   \
    static void NAME##_teardown(ma_shim_##NAME##_state* h) {                       \
        if (h->initialized) {                                                      \
            ma_##NAME##_uninit(&h->filter, NULL);                                  \
            h->initialized = 0;                                                    \
        }                                                                          \
        free(h->heap);                                                             \
        h->heap = NULL;                                                            \
    }                                                                              \
                                                                                   \
    static ma_shim_##NAME##_state* NAME##_ready(void* handle) {                    \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL || !h->initialized) {                                        \
            return NULL;                                                           \
        }                                                                          \
        return h;                                                                  \
    }                                                                              \
                                                                                   \
    static void* NAME##_alloc_state(void) {                                        \
        return calloc(1, sizeof(ma_shim_##NAME##_state));                          \
    }                                                                              \
                                                                                   \
    static void NAME##_free_state(void* handle) {                                  \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL) { return; }                                                 \
        NAME##_teardown(h);                                                        \
        free(h);                                                                   \
    }                                                                              \
                                                                                   \
    static int NAME##_uninit_state(void* handle) {                                 \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL) { return MA_INVALID_ARGS; }                                 \
        NAME##_teardown(h);                                                        \
        return MA_SUCCESS;                                                         \
    }                                                                              \
                                                                                   \
    static int NAME##_process_state(                                               \
        void* handle, void* out, const void* in, unsigned long long frame_count    \
    ) {                                                                            \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                          \
        if (h == NULL || out == NULL || in == NULL) { return MA_INVALID_ARGS; }    \
        return (int)ma_##NAME##_process_pcm_frames(                                \
            &h->filter, out, in, (ma_uint64)frame_count);                          \
    }                                                                              \
                                                                                   \
    static int NAME##_latency_state(void* handle, unsigned int* out_latency) {     \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                          \
        if (out_latency != NULL) { *out_latency = 0; }                             \
        if (h == NULL || out_latency == NULL) { return MA_INVALID_ARGS; }          \
        *out_latency = (unsigned int)ma_##NAME##_get_latency(&h->filter);          \
        return MA_SUCCESS;                                                         \
    }

/* Shared body for "build the config, then init / init_preallocated / reinit".
 * CFG is an expression producing the filter's config struct. */
#define MA_SHIM_FILTER_INIT_BODY(NAME, CFGTYPE, CFG)                               \
    do {                                                                           \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        CFGTYPE   config;                                                          \
        ma_result result;                                                          \
        if (h == NULL) { return MA_INVALID_ARGS; }                                 \
        NAME##_teardown(h);                                                        \
        config = (CFG);                                                            \
        result = ma_##NAME##_init(&config, NULL, &h->filter);                      \
        if (result == MA_SUCCESS) { h->initialized = 1; }                          \
        return (int)result;                                                        \
    } while (0)

#define MA_SHIM_FILTER_PREALLOC_BODY(NAME, CFGTYPE, CFG)                           \
    do {                                                                           \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        CFGTYPE   config;                                                          \
        size_t    heap_size = 0;                                                   \
        void*     heap = NULL;                                                     \
        ma_result result;                                                          \
        if (h == NULL) { return MA_INVALID_ARGS; }                                 \
        NAME##_teardown(h);                                                        \
        config = (CFG);                                                            \
        result = ma_##NAME##_get_heap_size(&config, &heap_size);                   \
        if (result != MA_SUCCESS) { return (int)result; }                          \
        if (heap_size > 0) {                                                       \
            heap = calloc(1, heap_size);                                           \
            if (heap == NULL) { return MA_OUT_OF_MEMORY; }                         \
        }                                                                          \
        result = ma_##NAME##_init_preallocated(&config, heap, &h->filter);         \
        if (result == MA_SUCCESS) { h->heap = heap; h->initialized = 1; }          \
        else { free(heap); }                                                       \
        return (int)result;                                                        \
    } while (0)

#define MA_SHIM_FILTER_HEAPSIZE_BODY(NAME, CFGTYPE, CFG)                           \
    do {                                                                           \
        CFGTYPE   config;                                                          \
        size_t    size = 0;                                                        \
        ma_result result;                                                          \
        if (out_heap_size == NULL) { return MA_INVALID_ARGS; }                     \
        *out_heap_size = 0;                                                        \
        config = (CFG);                                                            \
        result = ma_##NAME##_get_heap_size(&config, &size);                        \
        *out_heap_size = (unsigned long long)size;                                 \
        return (int)result;                                                        \
    } while (0)

#define MA_SHIM_FILTER_REINIT_BODY(NAME, CFGTYPE, CFG)                             \
    do {                                                                           \
        ma_shim_##NAME##_state* h = NAME##_ready(handle);                          \
        CFGTYPE config;                                                            \
        if (h == NULL) { return MA_INVALID_ARGS; }                                 \
        config = (CFG);                                                            \
        return (int)ma_##NAME##_reinit(&config, &h->filter);                       \
    } while (0)

MA_SHIM_FILTER_HANDLE(biquad, ma_biquad)
MA_SHIM_FILTER_HANDLE(lpf1, ma_lpf1)
MA_SHIM_FILTER_HANDLE(lpf2, ma_lpf2)
MA_SHIM_FILTER_HANDLE(lpf, ma_lpf)
MA_SHIM_FILTER_HANDLE(hpf1, ma_hpf1)
MA_SHIM_FILTER_HANDLE(hpf2, ma_hpf2)
MA_SHIM_FILTER_HANDLE(hpf, ma_hpf)

/* ================= ma_biquad ================= */

void* ma_shim_biquad_alloc(void) { return biquad_alloc_state(); }

/* @binds ma_biquad_uninit */
void ma_shim_biquad_free(void* handle) { biquad_free_state(handle); }

/* @binds ma_biquad_config_init, ma_biquad_get_heap_size */
int ma_shim_biquad_get_heap_size(
    int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2,
    unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        biquad, ma_biquad_config,
        ma_biquad_config_init((ma_format)format, channels, b0, b1, b2, a0, a1, a2));
}

/* @binds ma_biquad_config_init, ma_biquad_init */
int ma_shim_biquad_init(
    void* handle, int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2
) {
    MA_SHIM_FILTER_INIT_BODY(
        biquad, ma_biquad_config,
        ma_biquad_config_init((ma_format)format, channels, b0, b1, b2, a0, a1, a2));
}

/* @binds ma_biquad_config_init, ma_biquad_get_heap_size, ma_biquad_init_preallocated */
int ma_shim_biquad_init_preallocated(
    void* handle, int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        biquad, ma_biquad_config,
        ma_biquad_config_init((ma_format)format, channels, b0, b1, b2, a0, a1, a2));
}

/* @binds ma_biquad_config_init, ma_biquad_reinit */
int ma_shim_biquad_reinit(
    void* handle, int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2
) {
    MA_SHIM_FILTER_REINIT_BODY(
        biquad, ma_biquad_config,
        ma_biquad_config_init((ma_format)format, channels, b0, b1, b2, a0, a1, a2));
}

/* @binds ma_biquad_uninit */
int ma_shim_biquad_uninit(void* handle) { return biquad_uninit_state(handle); }

/* @binds ma_biquad_process_pcm_frames */
int ma_shim_biquad_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return biquad_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_biquad_get_latency */
int ma_shim_biquad_get_latency(void* handle, unsigned int* out_latency) {
    return biquad_latency_state(handle, out_latency);
}

/* @binds ma_biquad_clear_cache */
int ma_shim_biquad_clear_cache(void* handle) {
    ma_shim_biquad_state* h = biquad_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_biquad_clear_cache(&h->filter);
}

/* ================= ma_lpf1 ================= */

void* ma_shim_lpf1_alloc(void) { return lpf1_alloc_state(); }

/* @binds ma_lpf1_uninit */
void ma_shim_lpf1_free(void* handle) { lpf1_free_state(handle); }

/* @binds ma_lpf1_config_init, ma_lpf1_get_heap_size */
int ma_shim_lpf1_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        lpf1, ma_lpf1_config,
        ma_lpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_lpf1_config_init, ma_lpf1_init */
int ma_shim_lpf1_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_INIT_BODY(
        lpf1, ma_lpf1_config,
        ma_lpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_lpf1_config_init, ma_lpf1_get_heap_size, ma_lpf1_init_preallocated */
int ma_shim_lpf1_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        lpf1, ma_lpf1_config,
        ma_lpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_lpf1_config_init, ma_lpf1_reinit */
int ma_shim_lpf1_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_REINIT_BODY(
        lpf1, ma_lpf1_config,
        ma_lpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_lpf1_uninit */
int ma_shim_lpf1_uninit(void* handle) { return lpf1_uninit_state(handle); }

/* @binds ma_lpf1_process_pcm_frames */
int ma_shim_lpf1_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return lpf1_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_lpf1_get_latency */
int ma_shim_lpf1_get_latency(void* handle, unsigned int* out_latency) {
    return lpf1_latency_state(handle, out_latency);
}

/* @binds ma_lpf1_clear_cache */
int ma_shim_lpf1_clear_cache(void* handle) {
    ma_shim_lpf1_state* h = lpf1_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_lpf1_clear_cache(&h->filter);
}

/* ================= ma_hpf1 ================= */

void* ma_shim_hpf1_alloc(void) { return hpf1_alloc_state(); }

/* @binds ma_hpf1_uninit */
void ma_shim_hpf1_free(void* handle) { hpf1_free_state(handle); }

/* @binds ma_hpf1_config_init, ma_hpf1_get_heap_size */
int ma_shim_hpf1_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        hpf1, ma_hpf1_config,
        ma_hpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_hpf1_config_init, ma_hpf1_init */
int ma_shim_hpf1_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_INIT_BODY(
        hpf1, ma_hpf1_config,
        ma_hpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_hpf1_config_init, ma_hpf1_get_heap_size, ma_hpf1_init_preallocated */
int ma_shim_hpf1_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        hpf1, ma_hpf1_config,
        ma_hpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_hpf1_config_init, ma_hpf1_reinit */
int ma_shim_hpf1_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff
) {
    MA_SHIM_FILTER_REINIT_BODY(
        hpf1, ma_hpf1_config,
        ma_hpf1_config_init((ma_format)format, channels, sample_rate, cutoff));
}

/* @binds ma_hpf1_uninit */
int ma_shim_hpf1_uninit(void* handle) { return hpf1_uninit_state(handle); }

/* @binds ma_hpf1_process_pcm_frames */
int ma_shim_hpf1_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return hpf1_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_hpf1_get_latency */
int ma_shim_hpf1_get_latency(void* handle, unsigned int* out_latency) {
    return hpf1_latency_state(handle, out_latency);
}

/* ================= ma_lpf2 ================= */

void* ma_shim_lpf2_alloc(void) { return lpf2_alloc_state(); }

/* @binds ma_lpf2_uninit */
void ma_shim_lpf2_free(void* handle) { lpf2_free_state(handle); }

/* @binds ma_lpf2_config_init, ma_lpf2_get_heap_size */
int ma_shim_lpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q,
    unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        lpf2, ma_lpf2_config,
        ma_lpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_lpf2_config_init, ma_lpf2_init */
int ma_shim_lpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_INIT_BODY(
        lpf2, ma_lpf2_config,
        ma_lpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_lpf2_config_init, ma_lpf2_get_heap_size, ma_lpf2_init_preallocated */
int ma_shim_lpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        lpf2, ma_lpf2_config,
        ma_lpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_lpf2_config_init, ma_lpf2_reinit */
int ma_shim_lpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_REINIT_BODY(
        lpf2, ma_lpf2_config,
        ma_lpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_lpf2_uninit */
int ma_shim_lpf2_uninit(void* handle) { return lpf2_uninit_state(handle); }

/* @binds ma_lpf2_process_pcm_frames */
int ma_shim_lpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return lpf2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_lpf2_get_latency */
int ma_shim_lpf2_get_latency(void* handle, unsigned int* out_latency) {
    return lpf2_latency_state(handle, out_latency);
}

/* @binds ma_lpf2_clear_cache */
int ma_shim_lpf2_clear_cache(void* handle) {
    ma_shim_lpf2_state* h = lpf2_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_lpf2_clear_cache(&h->filter);
}

/* ================= ma_hpf2 ================= */

void* ma_shim_hpf2_alloc(void) { return hpf2_alloc_state(); }

/* @binds ma_hpf2_uninit */
void ma_shim_hpf2_free(void* handle) { hpf2_free_state(handle); }

/* @binds ma_hpf2_config_init, ma_hpf2_get_heap_size */
int ma_shim_hpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q,
    unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        hpf2, ma_hpf2_config,
        ma_hpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_hpf2_config_init, ma_hpf2_init */
int ma_shim_hpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_INIT_BODY(
        hpf2, ma_hpf2_config,
        ma_hpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_hpf2_config_init, ma_hpf2_get_heap_size, ma_hpf2_init_preallocated */
int ma_shim_hpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        hpf2, ma_hpf2_config,
        ma_hpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_hpf2_config_init, ma_hpf2_reinit */
int ma_shim_hpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, double q
) {
    MA_SHIM_FILTER_REINIT_BODY(
        hpf2, ma_hpf2_config,
        ma_hpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_hpf2_uninit */
int ma_shim_hpf2_uninit(void* handle) { return hpf2_uninit_state(handle); }

/* @binds ma_hpf2_process_pcm_frames */
int ma_shim_hpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return hpf2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_hpf2_get_latency */
int ma_shim_hpf2_get_latency(void* handle, unsigned int* out_latency) {
    return hpf2_latency_state(handle, out_latency);
}

/* ================= ma_lpf (compound) ================= */

void* ma_shim_lpf_alloc(void) { return lpf_alloc_state(); }

/* @binds ma_lpf_uninit */
void ma_shim_lpf_free(void* handle) { lpf_free_state(handle); }

/* @binds ma_lpf_config_init, ma_lpf_get_heap_size */
int ma_shim_lpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned int order, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        lpf, ma_lpf_config,
        ma_lpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_lpf_config_init, ma_lpf_init */
int ma_shim_lpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_INIT_BODY(
        lpf, ma_lpf_config,
        ma_lpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_lpf_config_init, ma_lpf_get_heap_size, ma_lpf_init_preallocated */
int ma_shim_lpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        lpf, ma_lpf_config,
        ma_lpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_lpf_config_init, ma_lpf_reinit */
int ma_shim_lpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_REINIT_BODY(
        lpf, ma_lpf_config,
        ma_lpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_lpf_uninit */
int ma_shim_lpf_uninit(void* handle) { return lpf_uninit_state(handle); }

/* @binds ma_lpf_process_pcm_frames */
int ma_shim_lpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return lpf_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_lpf_get_latency */
int ma_shim_lpf_get_latency(void* handle, unsigned int* out_latency) {
    return lpf_latency_state(handle, out_latency);
}

/* @binds ma_lpf_clear_cache */
int ma_shim_lpf_clear_cache(void* handle) {
    ma_shim_lpf_state* h = lpf_ready(handle);
    if (h == NULL) { return MA_INVALID_ARGS; }
    return (int)ma_lpf_clear_cache(&h->filter);
}

/* ================= ma_hpf (compound) ================= */

void* ma_shim_hpf_alloc(void) { return hpf_alloc_state(); }

/* @binds ma_hpf_uninit */
void ma_shim_hpf_free(void* handle) { hpf_free_state(handle); }

/* @binds ma_hpf_config_init, ma_hpf_get_heap_size */
int ma_shim_hpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff,
    unsigned int order, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(
        hpf, ma_hpf_config,
        ma_hpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_hpf_config_init, ma_hpf_init */
int ma_shim_hpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_INIT_BODY(
        hpf, ma_hpf_config,
        ma_hpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_hpf_config_init, ma_hpf_get_heap_size, ma_hpf_init_preallocated */
int ma_shim_hpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_PREALLOC_BODY(
        hpf, ma_hpf_config,
        ma_hpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_hpf_config_init, ma_hpf_reinit */
int ma_shim_hpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_REINIT_BODY(
        hpf, ma_hpf_config,
        ma_hpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_hpf_uninit */
int ma_shim_hpf_uninit(void* handle) { return hpf_uninit_state(handle); }

/* @binds ma_hpf_process_pcm_frames */
int ma_shim_hpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return hpf_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_hpf_get_latency */
int ma_shim_hpf_get_latency(void* handle, unsigned int* out_latency) {
    return hpf_latency_state(handle, out_latency);
}

/* ================= node-graph variants ================= */

#define MA_SHIM_FILTER_NODE_HANDLE(NAME, TYPE)                                     \
    typedef struct ma_shim_##NAME##_state {                                        \
        TYPE node;                                                                 \
        int  initialized;                                                          \
    } ma_shim_##NAME##_state;                                                      \
                                                                                   \
    static void NAME##_teardown(ma_shim_##NAME##_state* h) {                       \
        if (h->initialized) {                                                      \
            ma_##NAME##_uninit(&h->node, NULL);                                    \
            h->initialized = 0;                                                    \
        }                                                                          \
    }                                                                              \
                                                                                   \
    static ma_shim_##NAME##_state* NAME##_ready(void* handle) {                    \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL || !h->initialized) { return NULL; }                         \
        return h;                                                                  \
    }                                                                              \
                                                                                   \
    static void* NAME##_alloc_state(void) {                                        \
        return calloc(1, sizeof(ma_shim_##NAME##_state));                          \
    }                                                                              \
                                                                                   \
    static void NAME##_free_state(void* handle) {                                  \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL) { return; }                                                 \
        NAME##_teardown(h);                                                        \
        free(h);                                                                   \
    }                                                                              \
                                                                                   \
    static int NAME##_uninit_state(void* handle) {                                 \
        ma_shim_##NAME##_state* h = (ma_shim_##NAME##_state*)handle;               \
        if (h == NULL) { return MA_INVALID_ARGS; }                                 \
        NAME##_teardown(h);                                                        \
        return MA_SUCCESS;                                                         \
    }

MA_SHIM_FILTER_NODE_HANDLE(biquad_node, ma_biquad_node)
MA_SHIM_FILTER_NODE_HANDLE(lpf_node, ma_lpf_node)
MA_SHIM_FILTER_NODE_HANDLE(hpf_node, ma_hpf_node)

/* Resolves the engine handle to the node graph the node will live in. */
static ma_node_graph* filter_node_graph(void* engine_handle) {
    ma_engine* engine = shimint_engine_ptr(engine_handle);
    if (engine == NULL) {
        return NULL;
    }
    return ma_engine_get_node_graph(engine);
}

void* ma_shim_biquad_node_alloc(void) { return biquad_node_alloc_state(); }

/* @binds ma_biquad_node_uninit */
void ma_shim_biquad_node_free(void* handle) { biquad_node_free_state(handle); }

/* @binds ma_biquad_node_config_init, ma_biquad_node_init */
int ma_shim_biquad_node_init(
    void* handle, void* engine_handle, unsigned int channels,
    float b0, float b1, float b2, float a0, float a1, float a2
) {
    ma_shim_biquad_node_state* h = (ma_shim_biquad_node_state*)handle;
    ma_node_graph*             graph = filter_node_graph(engine_handle);
    ma_biquad_node_config      config;
    ma_result                  result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    biquad_node_teardown(h);

    config = ma_biquad_node_config_init(channels, b0, b1, b2, a0, a1, a2);
    result = ma_biquad_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_biquad_config_init, ma_biquad_node_reinit */
int ma_shim_biquad_node_reinit(
    void* handle, int format, unsigned int channels,
    double b0, double b1, double b2, double a0, double a1, double a2
) {
    ma_shim_biquad_node_state* h = biquad_node_ready(handle);
    ma_biquad_config           config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_biquad_config_init((ma_format)format, channels, b0, b1, b2, a0, a1, a2);
    return (int)ma_biquad_node_reinit(&config, &h->node);
}

/* @binds ma_biquad_node_uninit */
int ma_shim_biquad_node_uninit(void* handle) { return biquad_node_uninit_state(handle); }

void* ma_shim_lpf_node_alloc(void) { return lpf_node_alloc_state(); }

/* @binds ma_lpf_node_uninit */
void ma_shim_lpf_node_free(void* handle) { lpf_node_free_state(handle); }

/* @binds ma_lpf_node_config_init, ma_lpf_node_init */
int ma_shim_lpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    ma_shim_lpf_node_state* h = (ma_shim_lpf_node_state*)handle;
    ma_node_graph*          graph = filter_node_graph(engine_handle);
    ma_lpf_node_config      config;
    ma_result               result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    lpf_node_teardown(h);

    config = ma_lpf_node_config_init(channels, sample_rate, cutoff, order);
    result = ma_lpf_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_lpf_config_init, ma_lpf_node_reinit */
int ma_shim_lpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    ma_shim_lpf_node_state* h = lpf_node_ready(handle);
    ma_lpf_config           config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_lpf_config_init((ma_format)format, channels, sample_rate, cutoff, order);
    return (int)ma_lpf_node_reinit(&config, &h->node);
}

/* @binds ma_lpf_node_uninit */
int ma_shim_lpf_node_uninit(void* handle) { return lpf_node_uninit_state(handle); }

void* ma_shim_hpf_node_alloc(void) { return hpf_node_alloc_state(); }

/* @binds ma_hpf_node_uninit */
void ma_shim_hpf_node_free(void* handle) { hpf_node_free_state(handle); }

/* @binds ma_hpf_node_config_init, ma_hpf_node_init */
int ma_shim_hpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    ma_shim_hpf_node_state* h = (ma_shim_hpf_node_state*)handle;
    ma_node_graph*          graph = filter_node_graph(engine_handle);
    ma_hpf_node_config      config;
    ma_result               result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    hpf_node_teardown(h);

    config = ma_hpf_node_config_init(channels, sample_rate, cutoff, order);
    result = ma_hpf_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_hpf_config_init, ma_hpf_node_reinit */
int ma_shim_hpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate,
    double cutoff, unsigned int order
) {
    ma_shim_hpf_node_state* h = hpf_node_ready(handle);
    ma_hpf_config           config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_hpf_config_init((ma_format)format, channels, sample_rate, cutoff, order);
    return (int)ma_hpf_node_reinit(&config, &h->node);
}

/* @binds ma_hpf_node_uninit */
int ma_shim_hpf_node_uninit(void* handle) { return hpf_node_uninit_state(handle); }

/* ================= band-pass, notch and the shelving/peaking filters =================
 *
 * Same lifecycle as the filters above, generated the same way; only the
 * tuning parameters differ. None of these has a clear_cache upstream. */

MA_SHIM_FILTER_HANDLE(bpf2, ma_bpf2)

MA_SHIM_FILTER_HANDLE(bpf, ma_bpf)

MA_SHIM_FILTER_HANDLE(notch2, ma_notch2)

MA_SHIM_FILTER_HANDLE(peak2, ma_peak2)

MA_SHIM_FILTER_HANDLE(loshelf2, ma_loshelf2)

MA_SHIM_FILTER_HANDLE(hishelf2, ma_hishelf2)

/* ---- ma_bpf2 ---- */

void* ma_shim_bpf2_alloc(void) { return bpf2_alloc_state(); }

/* @binds ma_bpf2_uninit */
void ma_shim_bpf2_free(void* handle) { bpf2_free_state(handle); }

/* @binds ma_bpf2_config_init, ma_bpf2_get_heap_size */
int ma_shim_bpf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(bpf2, ma_bpf2_config, ma_bpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_bpf2_config_init, ma_bpf2_init */
int ma_shim_bpf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q
) {
    MA_SHIM_FILTER_INIT_BODY(bpf2, ma_bpf2_config, ma_bpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_bpf2_config_init, ma_bpf2_get_heap_size, ma_bpf2_init_preallocated */
int ma_shim_bpf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q
) {
    MA_SHIM_FILTER_PREALLOC_BODY(bpf2, ma_bpf2_config, ma_bpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_bpf2_config_init, ma_bpf2_reinit */
int ma_shim_bpf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, double q
) {
    MA_SHIM_FILTER_REINIT_BODY(bpf2, ma_bpf2_config, ma_bpf2_config_init((ma_format)format, channels, sample_rate, cutoff, q));
}

/* @binds ma_bpf2_uninit */
int ma_shim_bpf2_uninit(void* handle) { return bpf2_uninit_state(handle); }

/* @binds ma_bpf2_process_pcm_frames */
int ma_shim_bpf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return bpf2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_bpf2_get_latency */
int ma_shim_bpf2_get_latency(void* handle, unsigned int* out_latency) {
    return bpf2_latency_state(handle, out_latency);
}

/* ---- ma_bpf ---- */

void* ma_shim_bpf_alloc(void) { return bpf_alloc_state(); }

/* @binds ma_bpf_uninit */
void ma_shim_bpf_free(void* handle) { bpf_free_state(handle); }

/* @binds ma_bpf_config_init, ma_bpf_get_heap_size */
int ma_shim_bpf_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(bpf, ma_bpf_config, ma_bpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_bpf_config_init, ma_bpf_init */
int ma_shim_bpf_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_INIT_BODY(bpf, ma_bpf_config, ma_bpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_bpf_config_init, ma_bpf_get_heap_size, ma_bpf_init_preallocated */
int ma_shim_bpf_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_PREALLOC_BODY(bpf, ma_bpf_config, ma_bpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_bpf_config_init, ma_bpf_reinit */
int ma_shim_bpf_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order
) {
    MA_SHIM_FILTER_REINIT_BODY(bpf, ma_bpf_config, ma_bpf_config_init((ma_format)format, channels, sample_rate, cutoff, order));
}

/* @binds ma_bpf_uninit */
int ma_shim_bpf_uninit(void* handle) { return bpf_uninit_state(handle); }

/* @binds ma_bpf_process_pcm_frames */
int ma_shim_bpf_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return bpf_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_bpf_get_latency */
int ma_shim_bpf_get_latency(void* handle, unsigned int* out_latency) {
    return bpf_latency_state(handle, out_latency);
}

/* ---- ma_notch2 ---- */

void* ma_shim_notch2_alloc(void) { return notch2_alloc_state(); }

/* @binds ma_notch2_uninit */
void ma_shim_notch2_free(void* handle) { notch2_free_state(handle); }

/* @binds ma_notch2_config_init, ma_notch2_get_heap_size */
int ma_shim_notch2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double q, double frequency, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(notch2, ma_notch2_config, ma_notch2_config_init((ma_format)format, channels, sample_rate, q, frequency));
}

/* @binds ma_notch2_config_init, ma_notch2_init */
int ma_shim_notch2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double q, double frequency
) {
    MA_SHIM_FILTER_INIT_BODY(notch2, ma_notch2_config, ma_notch2_config_init((ma_format)format, channels, sample_rate, q, frequency));
}

/* @binds ma_notch2_config_init, ma_notch2_get_heap_size, ma_notch2_init_preallocated */
int ma_shim_notch2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double q, double frequency
) {
    MA_SHIM_FILTER_PREALLOC_BODY(notch2, ma_notch2_config, ma_notch2_config_init((ma_format)format, channels, sample_rate, q, frequency));
}

/* @binds ma_notch2_config_init, ma_notch2_reinit */
int ma_shim_notch2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double q, double frequency
) {
    MA_SHIM_FILTER_REINIT_BODY(notch2, ma_notch2_config, ma_notch2_config_init((ma_format)format, channels, sample_rate, q, frequency));
}

/* @binds ma_notch2_uninit */
int ma_shim_notch2_uninit(void* handle) { return notch2_uninit_state(handle); }

/* @binds ma_notch2_process_pcm_frames */
int ma_shim_notch2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return notch2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_notch2_get_latency */
int ma_shim_notch2_get_latency(void* handle, unsigned int* out_latency) {
    return notch2_latency_state(handle, out_latency);
}

/* ---- ma_peak2 ---- */

void* ma_shim_peak2_alloc(void) { return peak2_alloc_state(); }

/* @binds ma_peak2_uninit */
void ma_shim_peak2_free(void* handle) { peak2_free_state(handle); }

/* @binds ma_peak2_config_init, ma_peak2_get_heap_size */
int ma_shim_peak2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(peak2, ma_peak2_config, ma_peak2_config_init((ma_format)format, channels, sample_rate, gain_db, q, frequency));
}

/* @binds ma_peak2_config_init, ma_peak2_init */
int ma_shim_peak2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    MA_SHIM_FILTER_INIT_BODY(peak2, ma_peak2_config, ma_peak2_config_init((ma_format)format, channels, sample_rate, gain_db, q, frequency));
}

/* @binds ma_peak2_config_init, ma_peak2_get_heap_size, ma_peak2_init_preallocated */
int ma_shim_peak2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    MA_SHIM_FILTER_PREALLOC_BODY(peak2, ma_peak2_config, ma_peak2_config_init((ma_format)format, channels, sample_rate, gain_db, q, frequency));
}

/* @binds ma_peak2_config_init, ma_peak2_reinit */
int ma_shim_peak2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    MA_SHIM_FILTER_REINIT_BODY(peak2, ma_peak2_config, ma_peak2_config_init((ma_format)format, channels, sample_rate, gain_db, q, frequency));
}

/* @binds ma_peak2_uninit */
int ma_shim_peak2_uninit(void* handle) { return peak2_uninit_state(handle); }

/* @binds ma_peak2_process_pcm_frames */
int ma_shim_peak2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return peak2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_peak2_get_latency */
int ma_shim_peak2_get_latency(void* handle, unsigned int* out_latency) {
    return peak2_latency_state(handle, out_latency);
}

/* ---- ma_loshelf2 ---- */

void* ma_shim_loshelf2_alloc(void) { return loshelf2_alloc_state(); }

/* @binds ma_loshelf2_uninit */
void ma_shim_loshelf2_free(void* handle) { loshelf2_free_state(handle); }

/* @binds ma_loshelf2_config_init, ma_loshelf2_get_heap_size */
int ma_shim_loshelf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(loshelf2, ma_loshelf2_config, ma_loshelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_loshelf2_config_init, ma_loshelf2_init */
int ma_shim_loshelf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_INIT_BODY(loshelf2, ma_loshelf2_config, ma_loshelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_loshelf2_config_init, ma_loshelf2_get_heap_size, ma_loshelf2_init_preallocated */
int ma_shim_loshelf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_PREALLOC_BODY(loshelf2, ma_loshelf2_config, ma_loshelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_loshelf2_config_init, ma_loshelf2_reinit */
int ma_shim_loshelf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_REINIT_BODY(loshelf2, ma_loshelf2_config, ma_loshelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_loshelf2_uninit */
int ma_shim_loshelf2_uninit(void* handle) { return loshelf2_uninit_state(handle); }

/* @binds ma_loshelf2_process_pcm_frames */
int ma_shim_loshelf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return loshelf2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_loshelf2_get_latency */
int ma_shim_loshelf2_get_latency(void* handle, unsigned int* out_latency) {
    return loshelf2_latency_state(handle, out_latency);
}

/* ---- ma_hishelf2 ---- */

void* ma_shim_hishelf2_alloc(void) { return hishelf2_alloc_state(); }

/* @binds ma_hishelf2_uninit */
void ma_shim_hishelf2_free(void* handle) { hishelf2_free_state(handle); }

/* @binds ma_hishelf2_config_init, ma_hishelf2_get_heap_size */
int ma_shim_hishelf2_get_heap_size(
    int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency, unsigned long long* out_heap_size
) {
    MA_SHIM_FILTER_HEAPSIZE_BODY(hishelf2, ma_hishelf2_config, ma_hishelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_hishelf2_config_init, ma_hishelf2_init */
int ma_shim_hishelf2_init(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_INIT_BODY(hishelf2, ma_hishelf2_config, ma_hishelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_hishelf2_config_init, ma_hishelf2_get_heap_size, ma_hishelf2_init_preallocated */
int ma_shim_hishelf2_init_preallocated(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_PREALLOC_BODY(hishelf2, ma_hishelf2_config, ma_hishelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_hishelf2_config_init, ma_hishelf2_reinit */
int ma_shim_hishelf2_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    MA_SHIM_FILTER_REINIT_BODY(hishelf2, ma_hishelf2_config, ma_hishelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency));
}

/* @binds ma_hishelf2_uninit */
int ma_shim_hishelf2_uninit(void* handle) { return hishelf2_uninit_state(handle); }

/* @binds ma_hishelf2_process_pcm_frames */
int ma_shim_hishelf2_process(
    void* handle, void* frames_out, const void* frames_in, unsigned long long frame_count
) {
    return hishelf2_process_state(handle, frames_out, frames_in, frame_count);
}

/* @binds ma_hishelf2_get_latency */
int ma_shim_hishelf2_get_latency(void* handle, unsigned int* out_latency) {
    return hishelf2_latency_state(handle, out_latency);
}

/* ---- their node-graph variants ---- */

MA_SHIM_FILTER_NODE_HANDLE(bpf_node, ma_bpf_node)

MA_SHIM_FILTER_NODE_HANDLE(notch_node, ma_notch_node)

MA_SHIM_FILTER_NODE_HANDLE(peak_node, ma_peak_node)

MA_SHIM_FILTER_NODE_HANDLE(loshelf_node, ma_loshelf_node)

MA_SHIM_FILTER_NODE_HANDLE(hishelf_node, ma_hishelf_node)

void* ma_shim_bpf_node_alloc(void) { return bpf_node_alloc_state(); }

/* @binds ma_bpf_node_uninit */
void ma_shim_bpf_node_free(void* handle) { bpf_node_free_state(handle); }

/* @binds ma_bpf_node_config_init, ma_bpf_node_init */
int ma_shim_bpf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order
) {
    ma_shim_bpf_node_state* h = (ma_shim_bpf_node_state*)handle;
    ma_node_graph*     graph = filter_node_graph(engine_handle);
    ma_bpf_node_config      config;
    ma_result          result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    bpf_node_teardown(h);

    config = ma_bpf_node_config_init(channels, sample_rate, cutoff, order);
    result = ma_bpf_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_bpf_config_init, ma_bpf_node_reinit */
int ma_shim_bpf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double cutoff, unsigned int order
) {
    ma_shim_bpf_node_state* h = bpf_node_ready(handle);
    ma_bpf_config             config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_bpf_config_init((ma_format)format, channels, sample_rate, cutoff, order);
    return (int)ma_bpf_node_reinit(&config, &h->node);
}

/* @binds ma_bpf_node_uninit */
int ma_shim_bpf_node_uninit(void* handle) { return bpf_node_uninit_state(handle); }

void* ma_shim_notch_node_alloc(void) { return notch_node_alloc_state(); }

/* @binds ma_notch_node_uninit */
void ma_shim_notch_node_free(void* handle) { notch_node_free_state(handle); }

/* @binds ma_notch_node_config_init, ma_notch_node_init */
int ma_shim_notch_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate, double q, double frequency
) {
    ma_shim_notch_node_state* h = (ma_shim_notch_node_state*)handle;
    ma_node_graph*     graph = filter_node_graph(engine_handle);
    ma_notch_node_config      config;
    ma_result          result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    notch_node_teardown(h);

    config = ma_notch_node_config_init(channels, sample_rate, q, frequency);
    result = ma_notch_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_notch2_config_init, ma_notch_node_reinit */
int ma_shim_notch_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double q, double frequency
) {
    ma_shim_notch_node_state* h = notch_node_ready(handle);
    ma_notch_config             config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_notch2_config_init((ma_format)format, channels, sample_rate, q, frequency);
    return (int)ma_notch_node_reinit(&config, &h->node);
}

/* @binds ma_notch_node_uninit */
int ma_shim_notch_node_uninit(void* handle) { return notch_node_uninit_state(handle); }

void* ma_shim_peak_node_alloc(void) { return peak_node_alloc_state(); }

/* @binds ma_peak_node_uninit */
void ma_shim_peak_node_free(void* handle) { peak_node_free_state(handle); }

/* @binds ma_peak_node_config_init, ma_peak_node_init */
int ma_shim_peak_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    ma_shim_peak_node_state* h = (ma_shim_peak_node_state*)handle;
    ma_node_graph*     graph = filter_node_graph(engine_handle);
    ma_peak_node_config      config;
    ma_result          result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    peak_node_teardown(h);

    config = ma_peak_node_config_init(channels, sample_rate, gain_db, q, frequency);
    result = ma_peak_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_peak2_config_init, ma_peak_node_reinit */
int ma_shim_peak_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    ma_shim_peak_node_state* h = peak_node_ready(handle);
    ma_peak_config             config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_peak2_config_init((ma_format)format, channels, sample_rate, gain_db, q, frequency);
    return (int)ma_peak_node_reinit(&config, &h->node);
}

/* @binds ma_peak_node_uninit */
int ma_shim_peak_node_uninit(void* handle) { return peak_node_uninit_state(handle); }

void* ma_shim_loshelf_node_alloc(void) { return loshelf_node_alloc_state(); }

/* @binds ma_loshelf_node_uninit */
void ma_shim_loshelf_node_free(void* handle) { loshelf_node_free_state(handle); }

/* @binds ma_loshelf_node_config_init, ma_loshelf_node_init */
int ma_shim_loshelf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    ma_shim_loshelf_node_state* h = (ma_shim_loshelf_node_state*)handle;
    ma_node_graph*     graph = filter_node_graph(engine_handle);
    ma_loshelf_node_config      config;
    ma_result          result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    loshelf_node_teardown(h);

    config = ma_loshelf_node_config_init(channels, sample_rate, gain_db, q, frequency);
    result = ma_loshelf_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_loshelf2_config_init, ma_loshelf_node_reinit */
int ma_shim_loshelf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    ma_shim_loshelf_node_state* h = loshelf_node_ready(handle);
    ma_loshelf_config             config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_loshelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency);
    return (int)ma_loshelf_node_reinit(&config, &h->node);
}

/* @binds ma_loshelf_node_uninit */
int ma_shim_loshelf_node_uninit(void* handle) { return loshelf_node_uninit_state(handle); }

void* ma_shim_hishelf_node_alloc(void) { return hishelf_node_alloc_state(); }

/* @binds ma_hishelf_node_uninit */
void ma_shim_hishelf_node_free(void* handle) { hishelf_node_free_state(handle); }

/* @binds ma_hishelf_node_config_init, ma_hishelf_node_init */
int ma_shim_hishelf_node_init(
    void* handle, void* engine_handle, unsigned int channels, unsigned int sample_rate, double gain_db, double q, double frequency
) {
    ma_shim_hishelf_node_state* h = (ma_shim_hishelf_node_state*)handle;
    ma_node_graph*     graph = filter_node_graph(engine_handle);
    ma_hishelf_node_config      config;
    ma_result          result;

    if (h == NULL || graph == NULL) {
        return MA_INVALID_ARGS;
    }
    hishelf_node_teardown(h);

    config = ma_hishelf_node_config_init(channels, sample_rate, gain_db, q, frequency);
    result = ma_hishelf_node_init(graph, &config, NULL, &h->node);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_hishelf2_config_init, ma_hishelf_node_reinit */
int ma_shim_hishelf_node_reinit(
    void* handle, int format, unsigned int channels, unsigned int sample_rate, double gain_db, double shelf_slope, double frequency
) {
    ma_shim_hishelf_node_state* h = hishelf_node_ready(handle);
    ma_hishelf_config             config;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    config = ma_hishelf2_config_init((ma_format)format, channels, sample_rate, gain_db, shelf_slope, frequency);
    return (int)ma_hishelf_node_reinit(&config, &h->node);
}

/* @binds ma_hishelf_node_uninit */
int ma_shim_hishelf_node_uninit(void* handle) { return hishelf_node_uninit_state(handle); }
