#ifndef MA_SHIM_CONTEXT_H
#define MA_SHIM_CONTEXT_H

/* ---- context and VFS ----
 *
 * The context is miniaudio's backend handle — the thing that knows which audio
 * devices exist. Everything here runs on the null backend, so device
 * enumeration returns miniaudio's synthetic devices and no hardware is touched.
 *
 * `ma_context_enumerate_devices` takes a callback, which Mojo cannot supply, so
 * the shim owns one that counts the devices it is offered; the count is what
 * Mojo sees. `ma_context_get_devices` hands back arrays owned by the context —
 * the shim reports their lengths rather than the pointers.
 *
 * The VFS half wraps miniaudio's default (stdio) VFS. Files are opened into
 * slots on the handle, because `ma_vfs_file` is an opaque pointer with no safe
 * Mojo home. There are two slots: one for files opened through the shim's own
 * default VFS, and one for files opened through the `_or_default` entry points
 * with a NULL VFS, which is the fallback path those functions exist to provide.
 *
 * Open modes match miniaudio: read=1, write=2. Seek origins match ma_seek_origin.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= context ================= */

void* ma_shim_context_alloc(void);
void  ma_shim_context_free(void* handle);

/* Initialises on the null backend so enumeration is deterministic. */
int ma_shim_context_init(void* handle);
int ma_shim_context_uninit(void* handle);

int ma_shim_context_sizeof(unsigned long long* out_size);
int ma_shim_context_has_log(void* handle, int* out_has_log);
int ma_shim_context_is_loopback_supported(void* handle, int* out_supported);

/* Runs miniaudio's enumeration with a shim callback and reports how many
 * devices it was offered. */
int ma_shim_context_enumerate_devices(void* handle, unsigned int* out_count);
int ma_shim_context_get_devices(
    void* handle, unsigned int* out_playback_count, unsigned int* out_capture_count);
/* Default playback device: reports its name length and native format count. */
int ma_shim_context_get_device_info(
    void*         handle,
    int           device_type,
    unsigned int* out_name_length,
    unsigned int* out_native_format_count
);

/* ================= VFS ================= */

void* ma_shim_vfs_alloc(void);
void  ma_shim_vfs_free(void* handle);

int ma_shim_vfs_init(void* handle);

/* ---- through the shim's own default VFS ---- */

int ma_shim_vfs_open(void* handle, const char* path, unsigned int open_mode);
int ma_shim_vfs_close(void* handle);
int ma_shim_vfs_read(
    void* handle, void* dst, unsigned long long size, unsigned long long* out_read);
int ma_shim_vfs_write(
    void* handle, const void* src, unsigned long long size, unsigned long long* out_written);
int ma_shim_vfs_seek(void* handle, long long offset, int origin);
int ma_shim_vfs_tell(void* handle, long long* out_cursor);
int ma_shim_vfs_info(void* handle, unsigned long long* out_size_in_bytes);

/* Reads a whole file in one call; the shim frees the block and reports its size. */
int ma_shim_vfs_open_and_read_file(
    void* handle, const char* path, unsigned long long* out_size);

/* ---- through the *_or_default entry points, with a NULL VFS ---- */

int ma_shim_vfs_or_default_open(void* handle, const char* path, unsigned int open_mode);
int ma_shim_vfs_or_default_close(void* handle);
int ma_shim_vfs_or_default_read(
    void* handle, void* dst, unsigned long long size, unsigned long long* out_read);
int ma_shim_vfs_or_default_write(
    void* handle, const void* src, unsigned long long size, unsigned long long* out_written);
int ma_shim_vfs_or_default_seek(void* handle, long long offset, int origin);
int ma_shim_vfs_or_default_tell(void* handle, long long* out_cursor);
int ma_shim_vfs_or_default_info(void* handle, unsigned long long* out_size_in_bytes);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_CONTEXT_H */
