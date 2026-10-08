#include "ma_shim_stream.h"

#include <string.h>

/* Shared by the decoder, encoder and codec shims. See ma_shim_stream.h. */

void shimint_stream_release(shimint_stream* stream) {
    ma_shim_stream_destroy_fn destroy = stream->destroy;
    void* user = stream->user;

    /* Clear first: destroy may run arbitrary code, and a second release must
     * find nothing left to destroy. */
    memset(stream, 0, sizeof(*stream));
    if (destroy != NULL && user != NULL) {
        destroy(user);
    }
}

void* shimint_stream_user(const shimint_stream* stream, unsigned long long type_tag) {
    if (stream->user == NULL || stream->type_tag != type_tag) {
        return NULL;
    }
    return stream->user;
}
