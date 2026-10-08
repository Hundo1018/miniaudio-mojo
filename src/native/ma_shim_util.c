#include "ma_shim_util.h"
#include "miniaudio.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

/* Exported by miniaudio but with no prototype in its public header (they are
 * defined only inside the implementation section), so declare them here. */
MA_API int    ma_strcpy_s(char* dst, size_t dstSizeInBytes, const char* src);
MA_API int    ma_wcscpy_s(wchar_t* dst, size_t dstCap, const wchar_t* src);
MA_API int    ma_strncpy_s(char* dst, size_t dstSizeInBytes, const char* src, size_t count);
MA_API int    ma_strcat_s(char* dst, size_t dstSizeInBytes, const char* src);
MA_API int    ma_strncat_s(char* dst, size_t dstSizeInBytes, const char* src, size_t count);
MA_API int    ma_itoa_s(int value, char* dst, size_t dstSizeInBytes, int radix);
MA_API int    ma_strcmp(const char* str1, const char* str2);
MA_API int    ma_wcscmp(const wchar_t* str1, const wchar_t* str2);
MA_API int    ma_strappend(char* dst, size_t dstSize, const char* srcA, const char* srcB);
MA_API size_t ma_wcslen(const wchar_t* str);
MA_API ma_result ma_fopen(FILE** ppFile, const char* pFilePath, const char* pOpenMode);
MA_API ma_handle ma_dlopen(ma_log* pLog, const char* filename);
MA_API void      ma_dlclose(ma_log* pLog, ma_handle handle);
MA_API ma_proc   ma_dlsym(ma_log* pLog, ma_handle handle, const char* symbol);

/* ======================================================================== */
/* alloc                                                                     */
/* ======================================================================== */

/* @binds ma_malloc */
void* ma_shim_mem_malloc(unsigned long long size) {
    if (size == 0) {
        return NULL;
    }
    return ma_malloc((size_t)size, NULL);
}

/* @binds ma_calloc */
void* ma_shim_mem_calloc(unsigned long long size) {
    if (size == 0) {
        return NULL;
    }
    return ma_calloc((size_t)size, NULL);
}

/* @binds ma_realloc */
void* ma_shim_mem_realloc(void* p, unsigned long long size) {
    if (size == 0) {
        return NULL;
    }
    return ma_realloc(p, (size_t)size, NULL);
}

/* @binds ma_free */
void ma_shim_mem_free(void* p) {
    ma_free(p, NULL);
}

/* @binds ma_aligned_malloc */
void* ma_shim_mem_aligned_malloc(unsigned long long size, unsigned long long alignment) {
    size_t padding;

    /* miniaudio masks with (alignment - 1), which only aligns for a power of two,
     * and adds alignment - 1 + sizeof(void*) to the size without an overflow check. */
    if (size == 0 || alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return NULL;
    }
    padding = (size_t)(alignment - 1) + sizeof(void*);
    if (size > (unsigned long long)(SIZE_MAX - padding)) {
        return NULL;
    }
    return ma_aligned_malloc((size_t)size, (size_t)alignment, NULL);
}

/* @binds ma_aligned_free */
void ma_shim_mem_aligned_free(void* p) {
    if (p == NULL) {
        return;
    }
    ma_aligned_free(p, NULL);
}

/* ======================================================================== */
/* crt_util                                                                  */
/* ======================================================================== */

/* @binds ma_strcpy_s */
int ma_shim_crt_strcpy_s(char* dst, unsigned long long dst_cap, const char* src) {
    return ma_strcpy_s(dst, (size_t)dst_cap, src);
}

/* @binds ma_strncpy_s */
int ma_shim_crt_strncpy_s(
    char* dst, unsigned long long dst_cap, const char* src, unsigned long long count
) {
    return ma_strncpy_s(dst, (size_t)dst_cap, src, (size_t)count);
}

/* @binds ma_strcat_s */
int ma_shim_crt_strcat_s(char* dst, unsigned long long dst_cap, const char* src) {
    return ma_strcat_s(dst, (size_t)dst_cap, src);
}

/* @binds ma_strncat_s */
int ma_shim_crt_strncat_s(
    char* dst, unsigned long long dst_cap, const char* src, unsigned long long count
) {
    return ma_strncat_s(dst, (size_t)dst_cap, src, (size_t)count);
}

/* @binds ma_strappend */
int ma_shim_crt_strappend(char* dst, unsigned long long dst_cap, const char* a, const char* b) {
    return ma_strappend(dst, (size_t)dst_cap, a, b);
}

/* @binds ma_itoa_s */
int ma_shim_crt_itoa_s(int value, char* dst, unsigned long long dst_cap, int radix) {
    return ma_itoa_s(value, dst, (size_t)dst_cap, radix);
}

/* @binds ma_strcmp */
int ma_shim_crt_strcmp(const char* a, const char* b) {
    return ma_strcmp(a, b);
}

/* @binds ma_wcscpy_s */
int ma_shim_crt_wcscpy_s(wchar_t* dst, unsigned long long dst_cap, const wchar_t* src) {
    return ma_wcscpy_s(dst, (size_t)dst_cap, src);
}

/* @binds ma_wcscmp */
int ma_shim_crt_wcscmp(const wchar_t* a, const wchar_t* b) {
    return ma_wcscmp(a, b);
}

/* @binds ma_wcslen */
unsigned long long ma_shim_crt_wcslen(const wchar_t* str) {
    return (unsigned long long)ma_wcslen(str);
}

/* @binds ma_fopen */
int ma_shim_crt_fopen(const char* path, const char* mode) {
    FILE*     file = NULL;
    ma_result result = ma_fopen(&file, path, mode);

    if (file != NULL) {
        fclose(file);
    }
    return (int)result;
}

/* ======================================================================== */
/* dl                                                                        */
/* ======================================================================== */

/* @binds ma_dlopen */
void* ma_shim_dl_open(const char* filename) {
    if (filename == NULL) {
        return NULL;
    }
    return (void*)ma_dlopen(NULL, filename);
}

/* @binds ma_dlsym */
void* ma_shim_dl_sym(void* library, const char* symbol) {
    if (library == NULL || symbol == NULL) {
        return NULL;
    }
    return (void*)ma_dlsym(NULL, (ma_handle)library, symbol);
}

/* @binds ma_dlclose */
int ma_shim_dl_close(void* library) {
    MA_SHIM_REQUIRE(library != NULL);
    ma_dlclose(NULL, (ma_handle)library);
    return MA_SUCCESS;
}

int ma_shim_dl_call_f64(void* fn, double arg, double* out_result) {
    double (*f)(double);

    MA_SHIM_REQUIRE(fn != NULL && out_result != NULL);
    f = (double (*)(double))fn;
    *out_result = f(arg);
    return MA_SUCCESS;
}

/* ======================================================================== */
/* spinlock                                                                  */
/* ======================================================================== */

void* ma_shim_spinlock_alloc(void) {
    return calloc(1, sizeof(ma_spinlock));
}

void ma_shim_spinlock_free(void* handle) {
    free(handle);
}

/* @binds ma_spinlock_lock */
int ma_shim_spinlock_lock(void* handle) {
    MA_SHIM_REQUIRE(handle != NULL);
    return (int)ma_spinlock_lock((volatile ma_spinlock*)handle);
}

/* @binds ma_spinlock_lock_noyield */
int ma_shim_spinlock_lock_noyield(void* handle) {
    MA_SHIM_REQUIRE(handle != NULL);
    return (int)ma_spinlock_lock_noyield((volatile ma_spinlock*)handle);
}

/* @binds ma_spinlock_unlock */
int ma_shim_spinlock_unlock(void* handle) {
    MA_SHIM_REQUIRE(handle != NULL);
    return (int)ma_spinlock_unlock((volatile ma_spinlock*)handle);
}

int ma_shim_spinlock_is_locked(void* handle, int* out_locked) {
    if (out_locked != NULL) { *out_locked = 0; }
    MA_SHIM_REQUIRE(handle != NULL && out_locked != NULL);
    *out_locked = (*(volatile ma_spinlock*)handle != 0) ? 1 : 0;
    return MA_SUCCESS;
}

/* ======================================================================== */
/* duplex_rb                                                                 */
/* ======================================================================== */

typedef struct ma_shim_duplex_rb {
    ma_duplex_rb rb;
    int          initialized;
} ma_shim_duplex_rb;

static ma_shim_duplex_rb* duplex_rb_ready(void* handle) {
    ma_shim_duplex_rb* h = (ma_shim_duplex_rb*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

static void duplex_rb_teardown(ma_shim_duplex_rb* h) {
    if (h->initialized) {
        ma_duplex_rb_uninit(&h->rb);
        h->initialized = 0;
    }
}

void* ma_shim_duplex_rb_alloc(void) {
    return calloc(1, sizeof(ma_shim_duplex_rb));
}

/* @binds ma_duplex_rb_uninit */
void ma_shim_duplex_rb_free(void* handle) {
    ma_shim_duplex_rb* h = (ma_shim_duplex_rb*)handle;
    if (h == NULL) {
        return;
    }
    duplex_rb_teardown(h);
    free(h);
}

/* @binds ma_duplex_rb_init */
int ma_shim_duplex_rb_init(
    void*        handle,
    int          capture_format,
    unsigned int capture_channels,
    unsigned int sample_rate,
    unsigned int capture_internal_sample_rate,
    unsigned int capture_internal_period_size_in_frames
) {
    ma_shim_duplex_rb* h = (ma_shim_duplex_rb*)handle;
    ma_result result;

    MA_SHIM_REQUIRE(h != NULL);
    duplex_rb_teardown(h);
    /* miniaudio divides by the internal rate and sizes the buffer from the
     * period, and does not validate the format or channel count (the latter
     * would leave a zero-width frame). */
    MA_SHIM_REQUIRE(capture_format > (int)ma_format_unknown && capture_format < (int)ma_format_count);
    MA_SHIM_REQUIRE(capture_channels > 0 && sample_rate > 0 && capture_internal_sample_rate > 0);
    result = ma_duplex_rb_init(
        (ma_format)capture_format, (ma_uint32)capture_channels, (ma_uint32)sample_rate,
        (ma_uint32)capture_internal_sample_rate,
        (ma_uint32)capture_internal_period_size_in_frames, NULL, &h->rb);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    /* miniaudio primes the buffer by seeking the write cursor two periods ahead
     * and ignores the result. When the buffer holds less than two periods (the
     * playback rate under 40% of the capture rate) that seek runs past the end
     * and leaves the cursors inconsistent, so reads and writes would overrun. */
    if ((ma_uint64)capture_internal_period_size_in_frames * 2 > (ma_uint64)ma_pcm_rb_get_subbuffer_size(&h->rb.rb)) {
        ma_duplex_rb_uninit(&h->rb);
        return MA_INVALID_ARGS;
    }
    h->initialized = 1;
    return MA_SUCCESS;
}

/* @binds ma_duplex_rb_uninit */
int ma_shim_duplex_rb_uninit(void* handle) {
    ma_shim_duplex_rb* h = (ma_shim_duplex_rb*)handle;
    MA_SHIM_REQUIRE(h != NULL);
    duplex_rb_teardown(h);
    return MA_SUCCESS;
}

int ma_shim_duplex_rb_write(
    void* handle, const void* frames, unsigned int frame_count, unsigned int* out_written
) {
    ma_shim_duplex_rb*   h = duplex_rb_ready(handle);
    const unsigned char* in = (const unsigned char*)frames;
    ma_uint32            written = 0;
    ma_result            result = MA_SUCCESS;
    size_t               bpf;

    if (out_written != NULL) { *out_written = 0; }
    MA_SHIM_REQUIRE(h != NULL && frames != NULL && out_written != NULL);

    bpf = (size_t)ma_get_bytes_per_frame(ma_pcm_rb_get_format(&h->rb.rb), ma_pcm_rb_get_channels(&h->rb.rb));
    while (written < frame_count) {
        ma_uint32 chunk = frame_count - written;
        void*     dst = NULL;

        result = ma_pcm_rb_acquire_write(&h->rb.rb, &chunk, &dst);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is full */
        }
        memcpy(dst, in + ((size_t)written * bpf), (size_t)chunk * bpf);
        result = ma_pcm_rb_commit_write(&h->rb.rb, chunk);
        if (result != MA_SUCCESS) { break; }
        written += chunk;
    }

    *out_written = (unsigned int)written;
    return (int)result;
}

int ma_shim_duplex_rb_read(
    void* handle, void* frames, unsigned int frame_count, unsigned int* out_read
) {
    ma_shim_duplex_rb* h = duplex_rb_ready(handle);
    unsigned char*     out = (unsigned char*)frames;
    ma_uint32          done = 0;
    ma_result          result = MA_SUCCESS;
    size_t             bpf;

    if (out_read != NULL) { *out_read = 0; }
    MA_SHIM_REQUIRE(h != NULL && frames != NULL && out_read != NULL);

    bpf = (size_t)ma_get_bytes_per_frame(ma_pcm_rb_get_format(&h->rb.rb), ma_pcm_rb_get_channels(&h->rb.rb));
    while (done < frame_count) {
        ma_uint32 chunk = frame_count - done;
        void*     src = NULL;

        result = ma_pcm_rb_acquire_read(&h->rb.rb, &chunk, &src);
        if (result != MA_SUCCESS || chunk == 0) {
            break; /* error, or the buffer is empty */
        }
        memcpy(out + ((size_t)done * bpf), src, (size_t)chunk * bpf);
        result = ma_pcm_rb_commit_read(&h->rb.rb, chunk);
        if (result != MA_SUCCESS) { break; }
        done += chunk;
    }

    *out_read = (unsigned int)done;
    return (int)result;
}

int ma_shim_duplex_rb_available_read(void* handle, unsigned int* out_frames) {
    ma_shim_duplex_rb* h = duplex_rb_ready(handle);
    if (out_frames != NULL) { *out_frames = 0; }
    MA_SHIM_REQUIRE(h != NULL && out_frames != NULL);
    *out_frames = (unsigned int)ma_pcm_rb_available_read(&h->rb.rb);
    return MA_SUCCESS;
}

int ma_shim_duplex_rb_available_write(void* handle, unsigned int* out_frames) {
    ma_shim_duplex_rb* h = duplex_rb_ready(handle);
    if (out_frames != NULL) { *out_frames = 0; }
    MA_SHIM_REQUIRE(h != NULL && out_frames != NULL);
    *out_frames = (unsigned int)ma_pcm_rb_available_write(&h->rb.rb);
    return MA_SUCCESS;
}

/* ======================================================================== */
/* runtime_info                                                              */
/* ======================================================================== */

/* @binds ma_version */
int ma_shim_runtime_version(
    unsigned int* out_major, unsigned int* out_minor, unsigned int* out_revision
) {
    ma_uint32 major = 0;
    ma_uint32 minor = 0;
    ma_uint32 revision = 0;

    if (out_major != NULL) { *out_major = 0; }
    if (out_minor != NULL) { *out_minor = 0; }
    if (out_revision != NULL) { *out_revision = 0; }
    MA_SHIM_REQUIRE(out_major != NULL && out_minor != NULL && out_revision != NULL);
    ma_version(&major, &minor, &revision);
    *out_major = (unsigned int)major;
    *out_minor = (unsigned int)minor;
    *out_revision = (unsigned int)revision;
    return MA_SUCCESS;
}

/* miniaudio answers FALSE for a code outside ma_backend; the shim calls it
 * invalid instead. */
static int backend_valid(int backend) {
    return backend >= 0 && backend <= (int)ma_backend_null;
}

/* @binds ma_is_backend_enabled */
int ma_shim_runtime_is_backend_enabled(int backend, int* out_enabled) {
    if (out_enabled != NULL) { *out_enabled = 0; }
    MA_SHIM_REQUIRE(out_enabled != NULL && backend_valid(backend));
    *out_enabled = ma_is_backend_enabled((ma_backend)backend) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_is_loopback_supported */
int ma_shim_runtime_is_loopback_supported(int backend, int* out_supported) {
    if (out_supported != NULL) { *out_supported = 0; }
    MA_SHIM_REQUIRE(out_supported != NULL && backend_valid(backend));
    *out_supported = ma_is_loopback_supported((ma_backend)backend) ? 1 : 0;
    return MA_SUCCESS;
}
