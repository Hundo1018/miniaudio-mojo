#ifndef MA_SHIM_STREAM_H
#define MA_SHIM_STREAM_H

/* ---- user-supplied I/O streams ----
 *
 * miniaudio's custom-I/O constructors (ma_decoder_init, ma_encoder_init and the
 * ma_wav / ma_flac / ma_mp3 init functions) take read / write / seek / tell
 * callbacks plus an opaque user pointer. Their callback signatures differ (a
 * decoder callback receives the ma_decoder, a codec callback receives the user
 * pointer, an encoder callback receives the ma_encoder), so the shim adapts all
 * of them to ONE uniform shape: the user pointer comes first, then the
 * arguments. The Mojo side (miniaudio.stream) supplies Mojo functions with
 * exactly these signatures.
 *
 * Every callback returns a ma_result code (0 = success). A read or write
 * callback must always store the number of bytes it transferred through the
 * out pointer (0 on failure or end of stream): miniaudio's codecs read that
 * value even after a failure. origin is a ma_seek_origin (start=0,
 * current=1, end=2).
 *
 * Ownership. The init_stream entry points of the decoder, encoder and codec
 * families take ownership of (user, destroy) and ALWAYS consume them, whether
 * the call succeeds or fails: destroy(user) runs exactly once, after the
 * miniaudio object has been uninitialised, when the handle is freed or
 * initialised again (uninit alone keeps the stream, so its final state can
 * still be inspected), or straight away when init fails, including for invalid
 * arguments. destroy may be NULL for a user pointer the caller keeps owning.
 * The user pointer must stay valid until then: miniaudio keeps it, and may call
 * the callbacks from whichever thread reads the object (never concurrently).
 *
 * type_tag is an opaque value the caller chooses to identify the type behind
 * the user pointer; the stream_user accessor of each family hands the pointer
 * back only when the tag matches, so a typed view of the stream can be checked.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int  (*ma_shim_stream_read_fn)(void* user, void* buffer, size_t byte_count, size_t* bytes_read);
typedef int  (*ma_shim_stream_write_fn)(void* user, const void* buffer, size_t byte_count, size_t* bytes_written);
typedef int  (*ma_shim_stream_seek_fn)(void* user, long long offset, int origin);
typedef int  (*ma_shim_stream_tell_fn)(void* user, long long* cursor);
typedef void (*ma_shim_stream_destroy_fn)(void* user);

/*
 * Shim-internal bookkeeping shared by the families (deliberately not prefixed
 * with the public shim prefix, so the coverage checker ignores it): the
 * callbacks and the user pointer one miniaudio object was initialised with.
 * Zeroed means "no user stream".
 */
typedef struct shimint_stream {
    ma_shim_stream_read_fn    read;
    ma_shim_stream_write_fn   write;
    ma_shim_stream_seek_fn    seek;
    ma_shim_stream_tell_fn    tell;
    ma_shim_stream_destroy_fn destroy;
    void*                     user;
    unsigned long long        type_tag;
} shimint_stream;

/* Zero the record, then run destroy(user) once if it had both. Idempotent. */
void shimint_stream_release(shimint_stream* stream);

/* The user pointer if one is held and type_tag matches, else NULL. */
void* shimint_stream_user(const shimint_stream* stream, unsigned long long type_tag);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_STREAM_H */
