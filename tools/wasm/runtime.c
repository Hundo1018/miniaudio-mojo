/* Freestanding runtime for the wasm64 build (tools/wasm/build_wasm.py).
 *
 * Supplies what Mojo-emitted IR and the miniaudio C code import, with no libc:
 *   - the Mojo runtime: KGEN_CompilerRT_AlignedAlloc/Free, diagnostics, thread
 *     counts (one thread; AsyncRT traps, nothing here starts work items);
 *   - C malloc / calloc / realloc / free on the same allocator;
 *   - stdio for a module with no files: fopen fails (miniaudio then reports
 *     MA_DOES_NOT_EXIST), output goes to the host's `host_write` import;
 *   - assert, errno, a minimal vsnprintf (log text only), wide-string stubs.
 * Math and string functions come from musl (compiled from emscripten's copy).
 *
 * Allocator after ludens-engine's tools/wasm/poc/shim.c: power-of-two size
 * classes over memory.grow, every block 64-byte aligned, the class stored in the
 * 64 bytes before the payload. O(1) alloc / free; memory is never returned. */

typedef unsigned long size_t;
typedef long ssize_t;
typedef __builtin_va_list va_list;

#define IMPORT(name) __attribute__((import_module("env"), import_name(name)))
#define EXPORT(name) __attribute__((export_name(name)))

IMPORT("host_write") void host_write(int fd, const void* p, size_t n);

/* ---- allocator ---- */

extern unsigned char __heap_base;
static size_t heap_top;
static size_t live_bytes, peak_bytes;

static void* bump(size_t n) {
    size_t cur;
    if (!heap_top) heap_top = (size_t)&__heap_base;
    cur = __builtin_wasm_memory_size(0) * 65536UL;
    if (heap_top + n > cur) {
        size_t pages = (heap_top + n - cur + 65535) / 65536;
        if (__builtin_wasm_memory_grow(0, pages) == (size_t)-1) __builtin_trap();
    }
    void* p = (void*)heap_top;
    heap_top += n;
    return p;
}

typedef struct Hdr { size_t cls; struct Hdr* next; } Hdr;
static Hdr* bins[48];

static void* block_alloc(size_t size) {
    int c = 4;
    while (((size_t)1 << c) < size) c++;
    size_t sz = (size_t)1 << c;
    Hdr* h = bins[c];
    if (h) {
        bins[c] = h->next;
    } else {
        size_t base = (size_t)bump(0);
        size_t payload = (base + 64 + 63) & ~(size_t)63;
        bump(payload + sz - base);
        h = (Hdr*)payload - 1;
    }
    h->cls = (size_t)c;
    live_bytes += sz;
    if (live_bytes > peak_bytes) peak_bytes = live_bytes;
    return h + 1;
}

static void block_free(void* p) {
    if (!p) return;
    Hdr* h = (Hdr*)p - 1;
    live_bytes -= (size_t)1 << h->cls;
    h->next = bins[h->cls];
    bins[h->cls] = h;
}

static size_t block_size(void* p) { return (size_t)1 << (((Hdr*)p - 1)->cls); }

void* KGEN_CompilerRT_AlignedAlloc(size_t align, size_t size) {
    if (align > 64) __builtin_trap();
    return block_alloc(size);
}
void KGEN_CompilerRT_AlignedFree(void* p) { block_free(p); }

void* memcpy(void* dst, const void* src, size_t n);
void* memset(void* dst, int c, size_t n);

void* malloc(size_t n) { return block_alloc(n ? n : 1); }
void free(void* p) { block_free(p); }
void* calloc(size_t count, size_t size) {
    size_t n = count * size;
    void* p = block_alloc(n ? n : 1);
    memset(p, 0, n);
    return p;
}
void* realloc(void* p, size_t n) {
    if (!p) return malloc(n);
    if (n == 0) { block_free(p); return 0; }
    size_t have = block_size(p);
    if (n <= have) return p;
    void* q = block_alloc(n);
    memcpy(q, p, have);
    block_free(p);
    return q;
}

EXPORT("rt_live_bytes") size_t rt_live_bytes(void) { return live_bytes; }
EXPORT("rt_peak_bytes") size_t rt_peak_bytes(void) { return peak_bytes; }

/* ---- Mojo runtime: diagnostics and threads ---- */

size_t strlen(const char* s);

int KGEN_CompilerRT_fprintf(void* f, const char* fmt, ...) {
    size_t n = strlen(fmt);
    host_write(2, fmt, n);
    return (int)n;
}
long long KGEN_CompilerRT_GetStackTrace(void* p, long long n) { return 0; }
long long KGEN_CompilerRT_TracyIsEnabled(void) { return 0; }
long long KGEN_CompilerRT_TracyZoneBegin(void* s, long long n, int c) { return 0; }
void KGEN_CompilerRT_TracyZoneEnd(long long z) {}
long long KGEN_CompilerRT_NumPhysicalCores(void) { return 1; }
int KGEN_CompilerRT_AsyncRT_ParallelismLevel(void) { return 1; }

/* ---- stdio: no files ---- */

static int errno_value;
int* __errno_location(void) { return &errno_value; }
#define ENOENT 2

typedef struct FILE FILE;
ssize_t write(int fd, const void* p, size_t n) { host_write(fd, p, n); return (ssize_t)n; }
int dup(int fd) { return fd; }
FILE* fdopen(int fd, const char* mode) { return (FILE*)(size_t)(fd + 1); }
int fflush(FILE* f) { return 0; }
int fclose(FILE* f) { return 0; }
FILE* fopen(const char* path, const char* mode) { errno_value = ENOENT; return 0; }
size_t fread(void* p, size_t size, size_t n, FILE* f) { return 0; }
size_t fwrite(const void* p, size_t size, size_t n, FILE* f) {
    size_t fd = (size_t)f - 1;
    if (fd == 1 || fd == 2) host_write((int)fd, p, size * n);
    return n;
}
int fseek(FILE* f, long off, int whence) { return -1; }
long ftell(FILE* f) { return -1; }
int feof(FILE* f) { return 1; }
int ferror(FILE* f) { return 1; }
int fileno(FILE* f) { return -1; }
struct stat;
int fstat(int fd, struct stat* st) { return -1; }

/* ---- assert, text ---- */

void __assert_fail(const char* expr, const char* file, int line, const char* func) {
    host_write(2, "assertion failed: ", 18);
    host_write(2, expr, strlen(expr));
    host_write(2, "\n", 1);
    __builtin_trap();
}

/* Log messages only: copies the format text, arguments are not expanded. */
int vsnprintf(char* dst, size_t cap, const char* fmt, va_list ap) {
    size_t n = strlen(fmt);
    if (cap > 0) {
        size_t k = n < cap - 1 ? n : cap - 1;
        memcpy(dst, fmt, k);
        dst[k] = 0;
    }
    return (int)n;
}

typedef int wchar_t;
typedef struct { unsigned int s; } mbstate_t;
size_t wcsrtombs(char* dst, const wchar_t** src, size_t n, mbstate_t* st) {
    errno_value = 84; /* EILSEQ: wide paths are not supported here */
    return (size_t)-1;
}
