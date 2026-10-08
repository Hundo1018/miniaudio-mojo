#ifndef MA_SHIM_UTIL_H
#define MA_SHIM_UTIL_H

/* ---- runtime utilities ----
 *
 * The small helpers miniaudio ships next to its audio code, grouped by family:
 *
 *   alloc         malloc / calloc / realloc / free and the aligned pair
 *   crt_util      the safe C-string helpers (strcpy_s, strncat_s, itoa_s ...),
 *                 the wide-string ones, and fopen
 *   dl            dlopen / dlsym / dlclose
 *   spinlock      lock / lock_noyield / unlock on a heap spinlock
 *   duplex_rb     the ring buffer a duplex device uses to bridge capture to
 *                 playback
 *   runtime_info  the library version and which backends this build has
 *
 * None of them needs a device or an engine. The allocation callbacks (and the
 * log that dl takes) are optional in miniaudio; the shim passes NULL for both,
 * which selects the default allocator and no logging.
 *
 * Return conventions:
 *   - the *_s string helpers and strcmp / wcscmp return what miniaudio does:
 *     errno-style ints (0 = ok, 22 = EINVAL, 34 = ERANGE) or a comparison,
 *     not a ma_result;
 *   - everything else returns a ma_result code, with answers through out
 *     pointers (booleans as int 0 / 1).
 *
 * wchar_t is whatever the platform makes it (4 bytes on Linux).
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ================= alloc ================= */

/* A zero size is refused (NULL) so the result never depends on what the C
 * library does for malloc(0). */
void* ma_shim_mem_malloc(unsigned long long size);
void* ma_shim_mem_calloc(unsigned long long size);
/* A NULL `p` allocates; a zero size returns NULL and leaves `p` untouched. */
void* ma_shim_mem_realloc(void* p, unsigned long long size);
/* NULL is a no-op. */
void  ma_shim_mem_free(void* p);
/* `alignment` must be a non-zero power of two and the padded size must not
 * overflow; otherwise NULL. */
void* ma_shim_mem_aligned_malloc(unsigned long long size, unsigned long long alignment);
/* NULL is a no-op (miniaudio itself would read before the pointer). */
void  ma_shim_mem_aligned_free(void* p);

/* ================= crt_util ================= */

int ma_shim_crt_strcpy_s(char* dst, unsigned long long dst_cap, const char* src);
int ma_shim_crt_strncpy_s(
    char* dst, unsigned long long dst_cap, const char* src, unsigned long long count);
int ma_shim_crt_strcat_s(char* dst, unsigned long long dst_cap, const char* src);
int ma_shim_crt_strncat_s(
    char* dst, unsigned long long dst_cap, const char* src, unsigned long long count);
int ma_shim_crt_strappend(char* dst, unsigned long long dst_cap, const char* a, const char* b);
int ma_shim_crt_itoa_s(int value, char* dst, unsigned long long dst_cap, int radix);
int ma_shim_crt_strcmp(const char* a, const char* b);
int ma_shim_crt_wcscpy_s(wchar_t* dst, unsigned long long dst_cap, const wchar_t* src);
int ma_shim_crt_wcscmp(const wchar_t* a, const wchar_t* b);
unsigned long long ma_shim_crt_wcslen(const wchar_t* str);
/* Opens, then closes, the file: MA_SUCCESS when the open worked, otherwise the
 * ma_result miniaudio maps errno to. */
int ma_shim_crt_fopen(const char* path, const char* mode);

/* ================= dl ================= */

/* NULL on failure. */
void* ma_shim_dl_open(const char* filename);
/* NULL when the symbol is missing. */
void* ma_shim_dl_sym(void* library, const char* symbol);
int   ma_shim_dl_close(void* library);
/* Calls a resolved `double f(double)` (cos, sqrt ...) to prove it is real. */
int   ma_shim_dl_call_f64(void* fn, double arg, double* out_result);

/* ================= spinlock ================= */

void* ma_shim_spinlock_alloc(void);
void  ma_shim_spinlock_free(void* handle);
int   ma_shim_spinlock_lock(void* handle);
int   ma_shim_spinlock_lock_noyield(void* handle);
int   ma_shim_spinlock_unlock(void* handle);
/* Reads the lock word: 1 while held. */
int   ma_shim_spinlock_is_locked(void* handle, int* out_locked);

/* ================= duplex_rb ================= */

void* ma_shim_duplex_rb_alloc(void);
void  ma_shim_duplex_rb_free(void* handle);
/* Refuses a zero rate / channel count / period, an unknown format, and a
 * configuration whose buffer would be shorter than the two periods miniaudio
 * primes it with (miniaudio itself returns success and corrupts the cursors). */
int   ma_shim_duplex_rb_init(
    void*        handle,
    int          capture_format,
    unsigned int capture_channels,
    unsigned int sample_rate,
    unsigned int capture_internal_sample_rate,
    unsigned int capture_internal_period_size_in_frames
);
int   ma_shim_duplex_rb_uninit(void* handle);
/* The buffer inside the duplex rb, so a test can fill and drain it. */
int   ma_shim_duplex_rb_write(void* handle, const void* frames, unsigned int frame_count, unsigned int* out_written);
int   ma_shim_duplex_rb_read(void* handle, void* frames, unsigned int frame_count, unsigned int* out_read);
int   ma_shim_duplex_rb_available_read(void* handle, unsigned int* out_frames);
int   ma_shim_duplex_rb_available_write(void* handle, unsigned int* out_frames);

/* ================= runtime_info ================= */

int ma_shim_runtime_version(unsigned int* out_major, unsigned int* out_minor, unsigned int* out_revision);
/* backend is a ma_backend code, 0 (wasapi) .. 14 (null). */
int ma_shim_runtime_is_backend_enabled(int backend, int* out_enabled);
int ma_shim_runtime_is_loopback_supported(int backend, int* out_supported);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_UTIL_H */
