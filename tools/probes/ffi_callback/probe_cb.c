#include <pthread.h>
#include <stddef.h>
/* Same shape as ma_decoder_read_proc: (ctx, buf, bytes, *bytes_read) -> ma_result */
typedef int (*read_fn)(void* user, void* buf, size_t n, size_t* got);
static read_fn g_fn; static void* g_user;
int call_now(read_fn fn, void* user, void* buf, size_t n, size_t* got) { return fn(user, buf, n, got); }
void store(read_fn fn, void* user) { g_fn = fn; g_user = user; }
int call_stored(void* buf, size_t n, size_t* got) { return g_fn ? g_fn(g_user, buf, n, got) : -99; }
struct targ { void* buf; size_t n; size_t got; int rc; };
static void* thr(void* p) { struct targ* a = p; a->rc = g_fn(g_user, a->buf, a->n, &a->got); return NULL; }
int call_stored_on_thread(void* buf, size_t n, size_t* got) {
    pthread_t t; struct targ a = {buf, n, 0, -99};
    if (!g_fn) return -99;
    pthread_create(&t, NULL, thr, &a); pthread_join(t, NULL); *got = a.got; return a.rc;
}
