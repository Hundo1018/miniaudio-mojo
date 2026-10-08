#include <stdlib.h>
#include "miniaudio.h"
/* Mojo-side callbacks get the user state first, like ma_read_proc / ma_seek_proc. */
typedef int (*mj_read)(void* user, void* buf, size_t n, size_t* got);
typedef int (*mj_seek)(void* user, long long off, int origin);
typedef struct { mj_read r; mj_seek s; void* user; ma_decoder dec; } probe_dec;
static ma_result tr_read(ma_decoder* d, void* buf, size_t n, size_t* got) { probe_dec* p = (probe_dec*)d->pUserData; return (ma_result)p->r(p->user, buf, n, got); }
static ma_result tr_seek(ma_decoder* d, ma_int64 off, ma_seek_origin o) { probe_dec* p = (probe_dec*)d->pUserData; return (ma_result)p->s(p->user, off, (int)o); }
void* probe_decoder_init(mj_read r, mj_seek s, void* user, int* rc) {
    probe_dec* p = calloc(1, sizeof *p); ma_decoder_config c = ma_decoder_config_init(ma_format_f32, 0, 0);
    p->r = r; p->s = s; p->user = user;
    *rc = ma_decoder_init(tr_read, tr_seek, p, &c, &p->dec);
    if (*rc != MA_SUCCESS) { free(p); return NULL; } return p;
}
int probe_decoder_info(void* h, unsigned* ch, unsigned* sr, unsigned long long* len) {
    probe_dec* p = h; ma_format f; ma_result r = ma_decoder_get_data_format(&p->dec, &f, ch, sr, NULL, 0);
    return r != MA_SUCCESS ? r : ma_decoder_get_length_in_pcm_frames(&p->dec, len);
}
int probe_decoder_seek(void* h, unsigned long long frame) { return ma_decoder_seek_to_pcm_frame(&((probe_dec*)h)->dec, frame); }
int probe_decoder_read(void* h, float* out, unsigned long long frames, unsigned long long* got) { return ma_decoder_read_pcm_frames(&((probe_dec*)h)->dec, out, frames, got); }
void probe_decoder_uninit(void* h) { ma_decoder_uninit(&((probe_dec*)h)->dec); free(h); }
/* Reference path: the already-bound file decoder. */
int probe_ref_read(const char* path, unsigned long long seek, float* out, unsigned long long frames, unsigned long long* got) {
    ma_decoder d; ma_decoder_config c = ma_decoder_config_init(ma_format_f32, 0, 0);
    ma_result r = ma_decoder_init_file(path, &c, &d); if (r) return r;
    if (seek) ma_decoder_seek_to_pcm_frame(&d, seek);
    r = ma_decoder_read_pcm_frames(&d, out, frames, got); ma_decoder_uninit(&d); return r;
}
