"""Binding layer: raw 1:1 wrappers over the runtime-utility shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes,
errno-style ints or Ma* result/value pairs. No lifecycle / error policy; that
lives in util.mojo.

Six small families share this module, none of which needs a device or engine:

- alloc         `mem_*`        malloc / calloc / realloc / free and the aligned pair
- crt_util      `crt_*`        the safe C-string helpers, the wide-string ones, fopen
- dl            `dl_*`         dlopen / dlsym / dlclose
- spinlock      `spinlock_*`   lock / lock_noyield / unlock on a heap spinlock
- duplex_rb     `duplex_rb_*`  the ring buffer a duplex device uses
- runtime_info  `runtime_*`    library version, backend and loopback support

Strings are NUL-terminated `List[UInt8]` (see `c_bytes`), wide strings are
`List[UInt32]` (a Linux `wchar_t` is 4 bytes). An *empty* list stands for NULL,
which several miniaudio helpers define a result for. Sized buffers come with an
explicit capacity that is clamped to the list length, so a short list cannot be
overrun.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.spatializer_raw import MaU32, MaBool


# errno-style codes the *_s helpers return
comptime ERRNO_OK: Int = 0
comptime ERRNO_EINVAL: Int = 22
comptime ERRNO_ERANGE: Int = 34

# ma_result codes fopen can come back with (the rest are in miniaudio.result)
comptime MA_ACCESS_DENIED: Int = -6
comptime MA_IS_DIRECTORY: Int = -15

# ma_backend
comptime BACKEND_WASAPI: Int = 0
comptime BACKEND_DSOUND: Int = 1
comptime BACKEND_WINMM: Int = 2
comptime BACKEND_COREAUDIO: Int = 3
comptime BACKEND_SNDIO: Int = 4
comptime BACKEND_AUDIO4: Int = 5
comptime BACKEND_OSS: Int = 6
comptime BACKEND_PULSEAUDIO: Int = 7
comptime BACKEND_ALSA: Int = 8
comptime BACKEND_JACK: Int = 9
comptime BACKEND_AAUDIO: Int = 10
comptime BACKEND_OPENSL: Int = 11
comptime BACKEND_WEBAUDIO: Int = 12
comptime BACKEND_CUSTOM: Int = 13
comptime BACKEND_NULL: Int = 14


@fieldwise_init
struct MaF64(Copyable, Movable):
    """Raw (result_code, value) pair for a double out-param."""

    var result: Int
    var value: Float64


@fieldwise_init
struct MaVersion(Copyable, Movable):
    """Raw (result_code, major, minor, revision) from ma_version."""

    var result: Int
    var major: UInt32
    var minor: UInt32
    var revision: UInt32


# ---- helpers ---------------------------------------------------------------


def c_bytes(text: String) -> List[UInt8]:
    """The text as NUL-terminated bytes, the form the string wrappers take."""
    var out = List[UInt8]()
    for b in text.as_bytes():
        out.append(b)
    out.append(UInt8(0))
    return out^


def c_text(buf: List[UInt8]) -> String:
    """Reads a NUL-terminated buffer back up to the first NUL (or its end)."""
    var out = List[UInt8]()
    for b in buf:
        if b == 0:
            break
        out.append(b)
    return String(unsafe_from_utf8=out)


def _addr[T: Copyable](items: List[T]) -> Int:
    """The list's address, or 0 (NULL) for an empty list."""
    if len(items) == 0:
        return 0
    return Int(items.unsafe_ptr())


def _cap[T: Copyable](items: List[T], cap: Int) -> UInt64:
    """The capacity, clamped so it never exceeds what the list holds."""
    if cap < 0:
        return UInt64(0)
    if cap > len(items):
        return UInt64(len(items))
    return UInt64(cap)


# ---- alloc ------------------------------------------------------------------


def mem_malloc(lib: MaLib, size: UInt64) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_mem_malloc", OpaquePointer[MutUntrackedOrigin]](size)


def mem_calloc(lib: MaLib, size: UInt64) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_mem_calloc", OpaquePointer[MutUntrackedOrigin]](size)


def mem_realloc(
    lib: MaLib, p: OpaquePointer[MutUntrackedOrigin], size: UInt64
) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_mem_realloc", OpaquePointer[MutUntrackedOrigin]](p, size)


def mem_free(lib: MaLib, p: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_mem_free", NoneType](p)


def mem_aligned_malloc(
    lib: MaLib, size: UInt64, alignment: UInt64
) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_mem_aligned_malloc", OpaquePointer[MutUntrackedOrigin]](
        size, alignment
    )


def mem_aligned_free(lib: MaLib, p: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_mem_aligned_free", NoneType](p)


# ---- crt_util ---------------------------------------------------------------


def crt_strcpy_s(lib: MaLib, mut dst: List[UInt8], dst_cap: Int, src: List[UInt8]) -> Int:
    """errno-style: 0, 22 (NULL dst or src) or 34 (does not fit)."""
    return Int(
        lib.handle.call["ma_shim_crt_strcpy_s", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(src)
        )
    )


def crt_strncpy_s(
    lib: MaLib, mut dst: List[UInt8], dst_cap: Int, src: List[UInt8], count: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_strncpy_s", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(src), count
        )
    )


def crt_strcat_s(lib: MaLib, mut dst: List[UInt8], dst_cap: Int, src: List[UInt8]) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_strcat_s", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(src)
        )
    )


def crt_strncat_s(
    lib: MaLib, mut dst: List[UInt8], dst_cap: Int, src: List[UInt8], count: UInt64
) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_strncat_s", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(src), count
        )
    )


def crt_strappend(
    lib: MaLib, mut dst: List[UInt8], dst_cap: Int, a: List[UInt8], b: List[UInt8]
) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_strappend", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(a), _addr(b)
        )
    )


def crt_itoa_s(lib: MaLib, value: Int32, mut dst: List[UInt8], dst_cap: Int, radix: Int32) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_itoa_s", Int32](
            value, _addr(dst), _cap(dst, dst_cap), radix
        )
    )


def crt_strcmp(lib: MaLib, a: List[UInt8], b: List[UInt8]) -> Int:
    """Difference of the first mismatching bytes; an empty list is NULL (sorts first)."""
    return Int(lib.handle.call["ma_shim_crt_strcmp", Int32](_addr(a), _addr(b)))


def crt_wcscpy_s(lib: MaLib, mut dst: List[UInt32], dst_cap: Int, src: List[UInt32]) -> Int:
    return Int(
        lib.handle.call["ma_shim_crt_wcscpy_s", Int32](
            _addr(dst), _cap(dst, dst_cap), _addr(src)
        )
    )


def crt_wcscmp(lib: MaLib, a: List[UInt32], b: List[UInt32]) -> Int:
    return Int(lib.handle.call["ma_shim_crt_wcscmp", Int32](_addr(a), _addr(b)))


def crt_wcslen(lib: MaLib, s: List[UInt32]) -> UInt64:
    """Length in wide characters, not counting the NUL; NULL (empty list) is 0."""
    return lib.handle.call["ma_shim_crt_wcslen", UInt64](_addr(s))


def crt_fopen(lib: MaLib, path: List[UInt8], mode: List[UInt8]) -> Int:
    """MA_SUCCESS when the open worked (the file is closed again), else ma_result."""
    return Int(lib.handle.call["ma_shim_crt_fopen", Int32](_addr(path), _addr(mode)))


# ---- dl ---------------------------------------------------------------------


def dl_open(lib: MaLib, filename: List[UInt8]) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_dl_open", OpaquePointer[MutUntrackedOrigin]](_addr(filename))


def dl_sym(
    lib: MaLib, library: OpaquePointer[MutUntrackedOrigin], symbol: List[UInt8]
) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_dl_sym", OpaquePointer[MutUntrackedOrigin]](
        library, _addr(symbol)
    )


def dl_close(lib: MaLib, library: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_dl_close", Int32](library))


def dl_call_f64(lib: MaLib, proc: OpaquePointer[MutUntrackedOrigin], arg: Float64) -> MaF64:
    """Calls a resolved `double f(double)` such as cos or sqrt."""
    var holder = [Float64(0)]
    var code = Int(
        lib.handle.call["ma_shim_dl_call_f64", Int32](proc, arg, holder.unsafe_ptr())
    )
    return MaF64(code, holder[0])


# ---- spinlock ---------------------------------------------------------------


def spinlock_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_spinlock_alloc", OpaquePointer[MutUntrackedOrigin]]()


def spinlock_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_spinlock_free", NoneType](h)


def spinlock_lock(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Spins (yielding) until the lock is held. Locking twice from one thread hangs."""
    return Int(lib.handle.call["ma_shim_spinlock_lock", Int32](h))


def spinlock_lock_noyield(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_spinlock_lock_noyield", Int32](h))


def spinlock_unlock(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_spinlock_unlock", Int32](h))


def spinlock_is_locked(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(lib.handle.call["ma_shim_spinlock_is_locked", Int32](h, holder.unsafe_ptr()))
    return MaBool(code, holder[0] != 0)


# ---- duplex_rb --------------------------------------------------------------


def duplex_rb_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_duplex_rb_alloc", OpaquePointer[MutUntrackedOrigin]]()


def duplex_rb_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_duplex_rb_free", NoneType](h)


def duplex_rb_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    capture_format: Int,
    capture_channels: UInt32,
    sample_rate: UInt32,
    capture_internal_sample_rate: UInt32,
    capture_internal_period_size_in_frames: UInt32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_duplex_rb_init", Int32](
            h,
            Int32(capture_format),
            capture_channels,
            sample_rate,
            capture_internal_sample_rate,
            capture_internal_period_size_in_frames,
        )
    )


def duplex_rb_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_duplex_rb_uninit", Int32](h))


def duplex_rb_write(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], src: List[Float32], frame_count: UInt32
) -> MaU32:
    """Copies up to frame_count frames from `src`; `src` must hold that many frames
    of the buffer's format (f32 samples here). Returns (code, frames_written)."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_duplex_rb_write", Int32](
            h, _addr(src), frame_count, holder.unsafe_ptr()
        )
    )
    return MaU32(code, holder[0])


def duplex_rb_read(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], mut dst: List[Float32], frame_count: UInt32
) -> MaU32:
    """Copies up to frame_count frames into `dst`. Returns (code, frames_read)."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_duplex_rb_read", Int32](
            h, _addr(dst), frame_count, holder.unsafe_ptr()
        )
    )
    return MaU32(code, holder[0])


def duplex_rb_available_read(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_duplex_rb_available_read", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])


def duplex_rb_available_write(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_duplex_rb_available_write", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])


# ---- runtime_info -----------------------------------------------------------


def runtime_version(lib: MaLib) -> MaVersion:
    var major = [UInt32(0)]
    var minor = [UInt32(0)]
    var revision = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_runtime_version", Int32](
            major.unsafe_ptr(), minor.unsafe_ptr(), revision.unsafe_ptr()
        )
    )
    return MaVersion(code, major[0], minor[0], revision[0])


def runtime_is_backend_enabled(lib: MaLib, backend: Int) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_runtime_is_backend_enabled", Int32](
            Int32(backend), holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)


def runtime_is_loopback_supported(lib: MaLib, backend: Int) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_runtime_is_loopback_supported", Int32](
            Int32(backend), holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)
