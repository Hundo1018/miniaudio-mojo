#include "ma_shim_context.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* The ma_vfs_or_default_* family is exported by miniaudio but absent from its
 * public header, so it is declared here rather than left unbound. */
MA_API ma_result ma_vfs_or_default_open(
    ma_vfs* pVFS, const char* pFilePath, ma_uint32 openMode, ma_vfs_file* pFile);
MA_API ma_result ma_vfs_or_default_close(ma_vfs* pVFS, ma_vfs_file file);
MA_API ma_result ma_vfs_or_default_read(
    ma_vfs* pVFS, ma_vfs_file file, void* pDst, size_t sizeInBytes, size_t* pBytesRead);
MA_API ma_result ma_vfs_or_default_write(
    ma_vfs* pVFS, ma_vfs_file file, const void* pSrc, size_t sizeInBytes,
    size_t* pBytesWritten);
MA_API ma_result ma_vfs_or_default_seek(
    ma_vfs* pVFS, ma_vfs_file file, ma_int64 offset, ma_seek_origin origin);
MA_API ma_result ma_vfs_or_default_tell(
    ma_vfs* pVFS, ma_vfs_file file, ma_int64* pCursor);
MA_API ma_result ma_vfs_or_default_info(
    ma_vfs* pVFS, ma_vfs_file file, ma_file_info* pInfo);

/* ================= context ================= */

typedef struct ma_shim_context_state {
    ma_context   ctx;
    unsigned int enumerated;   /* devices the shim's callback was offered */
    int          initialized;
} ma_shim_context_state;

static ma_shim_context_state* context_ready(void* handle) {
    ma_shim_context_state* h = (ma_shim_context_state*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_context_alloc(void) {
    return calloc(1, sizeof(ma_shim_context_state));
}

/* @binds ma_context_uninit */
void ma_shim_context_free(void* handle) {
    ma_shim_context_state* h = (ma_shim_context_state*)handle;
    if (h == NULL) {
        return;
    }
    if (h->initialized) {
        ma_context_uninit(&h->ctx);
    }
    free(h);
}

/* @binds ma_context_config_init, ma_context_init */
int ma_shim_context_init(void* handle) {
    ma_shim_context_state* h = (ma_shim_context_state*)handle;
    ma_backend             backends[1];
    ma_context_config      config;
    ma_result              result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_context_uninit(&h->ctx);
        h->initialized = 0;
    }

    backends[0] = ma_backend_null;
    config = ma_context_config_init();
    result = ma_context_init(backends, 1, &config, &h->ctx);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_context_uninit */
int ma_shim_context_uninit(void* handle) {
    ma_shim_context_state* h = (ma_shim_context_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->initialized) {
        ma_context_uninit(&h->ctx);
        h->initialized = 0;
    }
    return MA_SUCCESS;
}

/* @binds ma_context_sizeof */
int ma_shim_context_sizeof(unsigned long long* out_size) {
    if (out_size == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_size = (unsigned long long)ma_context_sizeof();
    return MA_SUCCESS;
}

/* @binds ma_context_get_log */
int ma_shim_context_has_log(void* handle, int* out_has_log) {
    ma_shim_context_state* h = context_ready(handle);
    if (out_has_log != NULL) { *out_has_log = 0; }
    if (h == NULL || out_has_log == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_has_log = ma_context_get_log(&h->ctx) != NULL ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_context_is_loopback_supported */
int ma_shim_context_is_loopback_supported(void* handle, int* out_supported) {
    ma_shim_context_state* h = context_ready(handle);
    if (out_supported != NULL) { *out_supported = 0; }
    if (h == NULL || out_supported == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_supported = ma_context_is_loopback_supported(&h->ctx) ? 1 : 0;
    return MA_SUCCESS;
}

/* Counts what miniaudio offers; returning MA_TRUE keeps the enumeration going. */
static ma_bool32 shim_enum_callback(
    ma_context*          pContext,
    ma_device_type       deviceType,
    const ma_device_info* pInfo,
    void*                pUserData
) {
    ma_shim_context_state* h = (ma_shim_context_state*)pUserData;
    (void)pContext;
    (void)deviceType;
    (void)pInfo;
    if (h != NULL) {
        h->enumerated += 1;
    }
    return MA_TRUE;
}

/* @binds ma_context_enumerate_devices */
int ma_shim_context_enumerate_devices(void* handle, unsigned int* out_count) {
    ma_shim_context_state* h = context_ready(handle);
    ma_result              result;

    if (out_count != NULL) { *out_count = 0; }
    if (h == NULL || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    h->enumerated = 0;
    result = ma_context_enumerate_devices(&h->ctx, shim_enum_callback, h);
    *out_count = h->enumerated;
    return (int)result;
}

/* @binds ma_context_get_devices */
int ma_shim_context_get_devices(
    void* handle, unsigned int* out_playback_count, unsigned int* out_capture_count
) {
    ma_shim_context_state* h = context_ready(handle);
    ma_device_info*        playback = NULL;
    ma_device_info*        capture = NULL;
    ma_uint32              playback_count = 0;
    ma_uint32              capture_count = 0;
    ma_result              result;

    if (out_playback_count != NULL) { *out_playback_count = 0; }
    if (out_capture_count != NULL) { *out_capture_count = 0; }
    if (h == NULL || out_playback_count == NULL || out_capture_count == NULL) {
        return MA_INVALID_ARGS;
    }

    /* The arrays belong to the context; only their lengths cross into Mojo. */
    result = ma_context_get_devices(
        &h->ctx, &playback, &playback_count, &capture, &capture_count);
    *out_playback_count = (unsigned int)playback_count;
    *out_capture_count = (unsigned int)capture_count;
    return (int)result;
}

/* @binds ma_context_get_device_info */
int ma_shim_context_get_device_info(
    void*         handle,
    int           device_type,
    unsigned int* out_name_length,
    unsigned int* out_native_format_count
) {
    ma_shim_context_state* h = context_ready(handle);
    ma_device_info         info;
    ma_result              result;

    if (out_name_length != NULL) { *out_name_length = 0; }
    if (out_native_format_count != NULL) { *out_native_format_count = 0; }
    if (h == NULL || out_name_length == NULL || out_native_format_count == NULL) {
        return MA_INVALID_ARGS;
    }

    memset(&info, 0, sizeof(info));
    /* A NULL device id asks for the backend's default device. */
    result = ma_context_get_device_info(
        &h->ctx, (ma_device_type)device_type, NULL, &info);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    *out_name_length = (unsigned int)strlen(info.name);
    *out_native_format_count = (unsigned int)info.nativeDataFormatCount;
    return MA_SUCCESS;
}

/* ================= VFS ================= */

typedef struct ma_shim_vfs_state {
    ma_default_vfs vfs;
    ma_vfs_file    file;            /* opened through the shim's own VFS */
    ma_vfs_file    default_file;    /* opened through the _or_default path */
    int            has_file;
    int            has_default_file;
    int            initialized;
} ma_shim_vfs_state;

static ma_shim_vfs_state* vfs_ready(void* handle) {
    ma_shim_vfs_state* h = (ma_shim_vfs_state*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_vfs_alloc(void) { return calloc(1, sizeof(ma_shim_vfs_state)); }

/* @binds ma_vfs_close, ma_vfs_or_default_close */
void ma_shim_vfs_free(void* handle) {
    ma_shim_vfs_state* h = (ma_shim_vfs_state*)handle;
    if (h == NULL) {
        return;
    }
    if (h->has_file) {
        ma_vfs_close((ma_vfs*)&h->vfs, h->file);
    }
    if (h->has_default_file) {
        ma_vfs_or_default_close(NULL, h->default_file);
    }
    free(h);
}

/* @binds ma_default_vfs_init */
int ma_shim_vfs_init(void* handle) {
    ma_shim_vfs_state* h = (ma_shim_vfs_state*)handle;
    ma_result          result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_default_vfs_init(&h->vfs, NULL);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_vfs_open */
int ma_shim_vfs_open(void* handle, const char* path, unsigned int open_mode) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_result          result;

    if (h == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->has_file) {
        ma_vfs_close((ma_vfs*)&h->vfs, h->file);
        h->has_file = 0;
    }
    result = ma_vfs_open((ma_vfs*)&h->vfs, path, (ma_uint32)open_mode, &h->file);
    if (result == MA_SUCCESS) {
        h->has_file = 1;
    }
    return (int)result;
}

/* @binds ma_vfs_close */
int ma_shim_vfs_close(void* handle) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_result          result;

    if (h == NULL || !h->has_file) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_close((ma_vfs*)&h->vfs, h->file);
    h->has_file = 0;
    return (int)result;
}

/* @binds ma_vfs_read */
int ma_shim_vfs_read(
    void* handle, void* dst, unsigned long long size, unsigned long long* out_read
) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    size_t             read = 0;
    ma_result          result;

    if (out_read != NULL) { *out_read = 0; }
    if (h == NULL || !h->has_file || dst == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_read((ma_vfs*)&h->vfs, h->file, dst, (size_t)size, &read);
    if (out_read != NULL) { *out_read = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_vfs_write */
int ma_shim_vfs_write(
    void* handle, const void* src, unsigned long long size, unsigned long long* out_written
) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    size_t             written = 0;
    ma_result          result;

    if (out_written != NULL) { *out_written = 0; }
    if (h == NULL || !h->has_file || src == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_write((ma_vfs*)&h->vfs, h->file, src, (size_t)size, &written);
    if (out_written != NULL) { *out_written = (unsigned long long)written; }
    return (int)result;
}

/* @binds ma_vfs_seek */
int ma_shim_vfs_seek(void* handle, long long offset, int origin) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    if (h == NULL || !h->has_file) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_vfs_seek(
        (ma_vfs*)&h->vfs, h->file, (ma_int64)offset, (ma_seek_origin)origin);
}

/* @binds ma_vfs_tell */
int ma_shim_vfs_tell(void* handle, long long* out_cursor) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_int64           cursor = 0;
    ma_result          result;

    if (out_cursor != NULL) { *out_cursor = 0; }
    if (h == NULL || !h->has_file || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_tell((ma_vfs*)&h->vfs, h->file, &cursor);
    *out_cursor = (long long)cursor;
    return (int)result;
}

/* @binds ma_vfs_info */
int ma_shim_vfs_info(void* handle, unsigned long long* out_size_in_bytes) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_file_info       info;
    ma_result          result;

    if (out_size_in_bytes != NULL) { *out_size_in_bytes = 0; }
    if (h == NULL || !h->has_file || out_size_in_bytes == NULL) {
        return MA_INVALID_ARGS;
    }
    memset(&info, 0, sizeof(info));
    result = ma_vfs_info((ma_vfs*)&h->vfs, h->file, &info);
    *out_size_in_bytes = (unsigned long long)info.sizeInBytes;
    return (int)result;
}

/* @binds ma_vfs_open_and_read_file */
int ma_shim_vfs_open_and_read_file(
    void* handle, const char* path, unsigned long long* out_size
) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    void*              data = NULL;
    size_t             size = 0;
    ma_result          result;

    if (out_size != NULL) { *out_size = 0; }
    if (h == NULL || path == NULL || out_size == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_open_and_read_file((ma_vfs*)&h->vfs, path, &data, &size, NULL);
    if (result == MA_SUCCESS) {
        *out_size = (unsigned long long)size;
        /* The block belongs to the caller; Mojo only needs its size. */
        ma_free(data, NULL);
    }
    return (int)result;
}

/* ---- the _or_default entry points, exercised with a NULL VFS ---- */

/* @binds ma_vfs_or_default_open */
int ma_shim_vfs_or_default_open(void* handle, const char* path, unsigned int open_mode) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_result          result;

    if (h == NULL || path == NULL) {
        return MA_INVALID_ARGS;
    }
    if (h->has_default_file) {
        ma_vfs_or_default_close(NULL, h->default_file);
        h->has_default_file = 0;
    }
    result = ma_vfs_or_default_open(NULL, path, (ma_uint32)open_mode, &h->default_file);
    if (result == MA_SUCCESS) {
        h->has_default_file = 1;
    }
    return (int)result;
}

/* @binds ma_vfs_or_default_close */
int ma_shim_vfs_or_default_close(void* handle) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_result          result;

    if (h == NULL || !h->has_default_file) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_or_default_close(NULL, h->default_file);
    h->has_default_file = 0;
    return (int)result;
}

/* @binds ma_vfs_or_default_read */
int ma_shim_vfs_or_default_read(
    void* handle, void* dst, unsigned long long size, unsigned long long* out_read
) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    size_t             read = 0;
    ma_result          result;

    if (out_read != NULL) { *out_read = 0; }
    if (h == NULL || !h->has_default_file || dst == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_or_default_read(NULL, h->default_file, dst, (size_t)size, &read);
    if (out_read != NULL) { *out_read = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_vfs_or_default_write */
int ma_shim_vfs_or_default_write(
    void* handle, const void* src, unsigned long long size, unsigned long long* out_written
) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    size_t             written = 0;
    ma_result          result;

    if (out_written != NULL) { *out_written = 0; }
    if (h == NULL || !h->has_default_file || src == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_or_default_write(
        NULL, h->default_file, src, (size_t)size, &written);
    if (out_written != NULL) { *out_written = (unsigned long long)written; }
    return (int)result;
}

/* @binds ma_vfs_or_default_seek */
int ma_shim_vfs_or_default_seek(void* handle, long long offset, int origin) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    if (h == NULL || !h->has_default_file) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_vfs_or_default_seek(
        NULL, h->default_file, (ma_int64)offset, (ma_seek_origin)origin);
}

/* @binds ma_vfs_or_default_tell */
int ma_shim_vfs_or_default_tell(void* handle, long long* out_cursor) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_int64           cursor = 0;
    ma_result          result;

    if (out_cursor != NULL) { *out_cursor = 0; }
    if (h == NULL || !h->has_default_file || out_cursor == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_vfs_or_default_tell(NULL, h->default_file, &cursor);
    *out_cursor = (long long)cursor;
    return (int)result;
}

/* @binds ma_vfs_or_default_info */
int ma_shim_vfs_or_default_info(void* handle, unsigned long long* out_size_in_bytes) {
    ma_shim_vfs_state* h = vfs_ready(handle);
    ma_file_info       info;
    ma_result          result;

    if (out_size_in_bytes != NULL) { *out_size_in_bytes = 0; }
    if (h == NULL || !h->has_default_file || out_size_in_bytes == NULL) {
        return MA_INVALID_ARGS;
    }
    memset(&info, 0, sizeof(info));
    result = ma_vfs_or_default_info(NULL, h->default_file, &info);
    *out_size_in_bytes = (unsigned long long)info.sizeInBytes;
    return (int)result;
}

/* Cross-family helper (no ma_shim_ prefix, so it is not a public binding):
 * resolves a Vfs handle to its ma_vfs*, or NULL if the handle is null or not
 * yet initialised. Consumed by ma_shim_decode_util.c (ma_decode_from_vfs). */
ma_vfs* shimint_vfs_ptr(void* vfs_handle) {
    ma_shim_vfs_state* h = vfs_ready(vfs_handle);
    return h != NULL ? (ma_vfs*)&h->vfs : NULL;
}
