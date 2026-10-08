"""Idiomatic runtime-utility API (Layer 3).

miniaudio's small helpers that sit next to its audio code, none of which needs
a device or an engine:

- alloc         `MemoryBlock`, `AlignedBlock`: RAII over ma_malloc / calloc /
                realloc / free and ma_aligned_malloc / ma_aligned_free.
- crt_util      free functions over the safe C-string helpers (`strcpy_s`,
                `strncat_s`, `itoa_s` ...), the wide-string ones and `fopen`.
                These return errno-style codes (0, 22 = EINVAL, 34 = ERANGE)
                alongside the text, because a non-zero code is an answer here,
                not a failure.
- dl            `DynamicLibrary`: dlopen / dlsym / dlclose with RAII.
- spinlock      `Spinlock`: lock / lock_noyield / unlock.
- duplex_rb     `DuplexRingBuffer`: the buffer a duplex device uses to carry
                capture frames to playback (f32 frames here).
- runtime_info  `version`, `is_backend_enabled`, `is_loopback_supported`.

Quirks of miniaudio 0.11.25 that the shim or these wrappers account for:

- `ma_aligned_free(NULL)` reads before the pointer; the shim makes NULL a no-op.
- `ma_aligned_malloc` only aligns for a power-of-two alignment and adds to the
  size unchecked, so the shim refuses any other alignment and an overflowing size.
- `ma_wcscmp` compares the low 16 bits of the first differing wide character,
  so two characters that differ only above bit 15 compare equal.
- `ma_strncpy_s` with a count that is neither SIZE_MAX nor smaller than the
  buffer fails with ERANGE when the text does not fit, instead of truncating.
- `ma_strncat_s` with a NULL source returns EINVAL without touching the
  destination; `ma_strcat_s` clears it first.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.util_raw as raw

comptime ERRNO_EINVAL: Int = raw.ERRNO_EINVAL
comptime ERRNO_ERANGE: Int = raw.ERRNO_ERANGE

comptime BackendWasapi: Int = raw.BACKEND_WASAPI
comptime BackendPulseaudio: Int = raw.BACKEND_PULSEAUDIO
comptime BackendAlsa: Int = raw.BACKEND_ALSA
comptime BackendJack: Int = raw.BACKEND_JACK
comptime BackendCustom: Int = raw.BACKEND_CUSTOM
comptime BackendNull: Int = raw.BACKEND_NULL

comptime _FORMAT_F32: Int = 5
comptime _TRUNCATE: UInt64 = UInt64.MAX  # miniaudio's _TRUNCATE (size_t)-1


# ================= alloc =================


struct MemoryBlock(Movable):
    """A heap block from ma_malloc / ma_calloc, freed with ma_free on drop."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _size: UInt64

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        size: UInt64,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._size = size

    @staticmethod
    def allocate(lib: ArcPointer[MaLib], size: UInt64) raises -> Self:
        """Uninitialised bytes (ma_malloc). A zero size is refused."""
        var ptr = raw.mem_malloc(lib[], size)
        if ptr == null_handle():
            raise Error("ma_malloc failed (zero size or out of memory)")
        return Self(lib.copy(), ptr, size)

    @staticmethod
    def zeroed(lib: ArcPointer[MaLib], size: UInt64) raises -> Self:
        """Zero-filled bytes (ma_calloc)."""
        var ptr = raw.mem_calloc(lib[], size)
        if ptr == null_handle():
            raise Error("ma_calloc failed (zero size or out of memory)")
        return Self(lib.copy(), ptr, size)

    def size(self) -> UInt64:
        return self._size

    def address(self) -> Int:
        return Int(self._ptr)

    def load(self, index: Int) raises -> UInt8:
        if index < 0 or UInt64(index) >= self._size:
            raise Error("MemoryBlock.load: index out of range")
        return self._ptr.unsafe_bitcast[UInt8]()[unsafe_offset=index]

    def store(mut self, index: Int, value: UInt8) raises:
        if index < 0 or UInt64(index) >= self._size:
            raise Error("MemoryBlock.store: index out of range")
        self._ptr.unsafe_bitcast[UInt8]()[unsafe_offset=index] = value

    def resize(mut self, new_size: UInt64) raises:
        """Grows or shrinks the block (ma_realloc); the bytes that fit are kept.

        On failure the block is unchanged.
        """
        var ptr = raw.mem_realloc(self._lib[], self._ptr, new_size)
        if ptr == null_handle():
            raise Error("ma_realloc failed (zero size or out of memory)")
        self._ptr = ptr
        self._size = new_size

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.mem_free(self._lib[], self._ptr)


struct AlignedBlock(Movable):
    """A heap block whose address is a multiple of `alignment` (ma_aligned_malloc)."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _size: UInt64
    var _alignment: UInt64

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        size: UInt64,
        alignment: UInt64,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._size = size
        self._alignment = alignment

    @staticmethod
    def allocate(lib: ArcPointer[MaLib], size: UInt64, alignment: UInt64) raises -> Self:
        """`alignment` must be a power of two."""
        var ptr = raw.mem_aligned_malloc(lib[], size, alignment)
        if ptr == null_handle():
            raise Error(
                "ma_aligned_malloc failed (zero size, alignment not a power of two, or out of memory)"
            )
        return Self(lib.copy(), ptr, size, alignment)

    def size(self) -> UInt64:
        return self._size

    def alignment(self) -> UInt64:
        return self._alignment

    def address(self) -> Int:
        return Int(self._ptr)

    def is_aligned(self) -> Bool:
        return UInt64(Int(self._ptr)) % self._alignment == 0

    def load(self, index: Int) raises -> UInt8:
        if index < 0 or UInt64(index) >= self._size:
            raise Error("AlignedBlock.load: index out of range")
        return self._ptr.unsafe_bitcast[UInt8]()[unsafe_offset=index]

    def store(mut self, index: Int, value: UInt8) raises:
        if index < 0 or UInt64(index) >= self._size:
            raise Error("AlignedBlock.store: index out of range")
        self._ptr.unsafe_bitcast[UInt8]()[unsafe_offset=index] = value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.mem_aligned_free(self._lib[], self._ptr)


# ================= crt_util =================


struct CrtResult(Copyable, Movable):
    """An errno-style code and the text the destination buffer holds afterwards."""

    var code: Int
    var text: String

    def __init__(out self, code: Int, var text: String):
        self.code = code
        self.text = text^

    def ok(self) -> Bool:
        return self.code == 0


def _buffer(capacity: Int) -> List[UInt8]:
    var buf = List[UInt8]()
    buf.resize(capacity, UInt8(0))
    return buf^


def _buffer_holding(text: String, capacity: Int) -> List[UInt8]:
    """A buffer of `capacity` bytes starting with `text` and NUL-terminated if it fits."""
    var buf = _buffer(capacity)
    var n = 0
    for b in text.as_bytes():
        if n >= capacity:
            break
        buf[n] = b
        n += 1
    return buf^


def wide_text(text: String) -> List[UInt32]:
    """The text as NUL-terminated wide characters (a Linux wchar_t is 4 bytes)."""
    var out = List[UInt32]()
    for cp in text.codepoints():
        out.append(cp.to_u32())
    out.append(UInt32(0))
    return out^


def _text_of_wide(buf: List[UInt32]) -> String:
    var out = String()
    for cp in buf:
        if cp == 0:
            break
        out += chr(Int(cp))
    return out^


def strcpy_s(lib: ArcPointer[MaLib], src: String, capacity: Int) -> CrtResult:
    """Copies `src` into a `capacity`-byte buffer; ERANGE (34) when it does not fit."""
    var dst = _buffer(capacity)
    var code = raw.crt_strcpy_s(lib[], dst, capacity, raw.c_bytes(src))
    return CrtResult(code, raw.c_text(dst))


def strncpy_s(
    lib: ArcPointer[MaLib], src: String, capacity: Int, count: UInt64 = _TRUNCATE
) -> CrtResult:
    """Copies at most `count` bytes; count = UInt64.MAX truncates to fit instead of failing."""
    var dst = _buffer(capacity)
    var code = raw.crt_strncpy_s(lib[], dst, capacity, raw.c_bytes(src), count)
    return CrtResult(code, raw.c_text(dst))


def strcat_s(lib: ArcPointer[MaLib], dst_text: String, src: String, capacity: Int) -> CrtResult:
    """Appends `src` to `dst_text` inside a `capacity`-byte buffer."""
    var dst = _buffer_holding(dst_text, capacity)
    var code = raw.crt_strcat_s(lib[], dst, capacity, raw.c_bytes(src))
    return CrtResult(code, raw.c_text(dst))


def strncat_s(
    lib: ArcPointer[MaLib],
    dst_text: String,
    src: String,
    capacity: Int,
    count: UInt64 = _TRUNCATE,
) -> CrtResult:
    """Appends at most `count` bytes of `src`; count = UInt64.MAX truncates to fit."""
    var dst = _buffer_holding(dst_text, capacity)
    var code = raw.crt_strncat_s(lib[], dst, capacity, raw.c_bytes(src), count)
    return CrtResult(code, raw.c_text(dst))


def strappend(lib: ArcPointer[MaLib], a: String, b: String, capacity: Int) -> CrtResult:
    """`a` followed by `b` in a `capacity`-byte buffer."""
    var dst = _buffer(capacity)
    var code = raw.crt_strappend(lib[], dst, capacity, raw.c_bytes(a), raw.c_bytes(b))
    return CrtResult(code, raw.c_text(dst))


def itoa_s(lib: ArcPointer[MaLib], value: Int32, capacity: Int, radix: Int32 = 10) -> CrtResult:
    """`value` in the given radix (2..36); a sign appears only in base 10."""
    var dst = _buffer(capacity)
    var code = raw.crt_itoa_s(lib[], value, dst, capacity, radix)
    return CrtResult(code, raw.c_text(dst))


def strcmp(lib: ArcPointer[MaLib], a: String, b: String) -> Int:
    """Zero when equal, otherwise the difference of the first mismatching bytes."""
    return raw.crt_strcmp(lib[], raw.c_bytes(a), raw.c_bytes(b))


def wcslen(lib: ArcPointer[MaLib], text: String) -> UInt64:
    """Length in characters (code points), not counting the terminator."""
    return raw.crt_wcslen(lib[], wide_text(text))


def wcscmp(lib: ArcPointer[MaLib], a: String, b: String) -> Int:
    return raw.crt_wcscmp(lib[], wide_text(a), wide_text(b))


def wcscpy_s(lib: ArcPointer[MaLib], src: String, capacity: Int) -> CrtResult:
    """Copies `src` into a `capacity`-character wide buffer; ERANGE (34) if it does not fit."""
    var dst = List[UInt32]()
    dst.resize(capacity, UInt32(0))
    var code = raw.crt_wcscpy_s(lib[], dst, capacity, wide_text(src))
    return CrtResult(code, _text_of_wide(dst))


def fopen_result(lib: ArcPointer[MaLib], path: String, mode: String = "rb") -> Int:
    """The ma_result of opening `path` (the file is closed again): MA_SUCCESS,
    MA_DOES_NOT_EXIST for a missing file, MA_IS_DIRECTORY ... as miniaudio maps errno."""
    return raw.crt_fopen(lib[], raw.c_bytes(path), raw.c_bytes(mode))


def can_fopen(lib: ArcPointer[MaLib], path: String, mode: String = "rb") -> Bool:
    return fopen_result(lib, path, mode) == MA_SUCCESS


# ================= dl =================


struct DynamicLibrary(Movable):
    """A loaded shared library (dlopen), closed on drop."""

    var _lib: ArcPointer[MaLib]
    var _handle: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        handle: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._handle = handle

    @staticmethod
    def load(lib: ArcPointer[MaLib], filename: String) raises -> Self:
        """Raises when the library cannot be loaded (miniaudio does not log that as an error)."""
        var handle = raw.dl_open(lib[], raw.c_bytes(filename))
        if handle == null_handle():
            raise Error("ma_dlopen failed to load '" + filename + "'")
        return Self(lib.copy(), handle)

    def symbol(self, name: String) raises -> OpaquePointer[MutUntrackedOrigin]:
        """The address of the symbol; raises when the library does not export it."""
        var sym = raw.dl_sym(self._lib[], self._handle, raw.c_bytes(name))
        if sym == null_handle():
            raise Error("ma_dlsym: no symbol '" + name + "'")
        return sym

    def has_symbol(self, name: String) -> Bool:
        return raw.dl_sym(self._lib[], self._handle, raw.c_bytes(name)) != null_handle()

    def call_f64(self, name: String, arg: Float64) raises -> Float64:
        """Resolves a `double f(double)` symbol such as cos and calls it."""
        var rc = raw.dl_call_f64(self._lib[], self.symbol(name), arg)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("dl call failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._handle != null_handle():
            _ = raw.dl_close(self._lib[], self._handle)


# ================= spinlock =================


struct Spinlock(Movable):
    """A heap spinlock. Locking it twice from one thread without unlocking hangs."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        var ptr = raw.spinlock_alloc(lib[])
        if ptr == null_handle():
            raise Error("spinlock_alloc failed (out of memory)")
        return Self(lib.copy(), ptr)

    def lock(mut self) raises:
        """Spins, yielding the CPU while it waits."""
        var code = raw.spinlock_lock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("spinlock lock failed", code))

    def lock_noyield(mut self) raises:
        """Spins without yielding."""
        var code = raw.spinlock_lock_noyield(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("spinlock lock_noyield failed", code))

    def unlock(mut self) raises:
        var code = raw.spinlock_unlock(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("spinlock unlock failed", code))

    def is_locked(self) raises -> Bool:
        var rc = raw.spinlock_is_locked(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("spinlock is_locked failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.spinlock_free(self._lib[], self._ptr)


# ================= duplex_rb =================


struct DuplexRingBuffer(Movable):
    """The ring buffer a duplex device uses to carry capture frames to playback.

    It holds five capture periods (scaled to the playback rate) and starts with
    two periods of silence already queued, so reads trail writes by that much.
    Frames are interleaved f32.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32,
        sample_rate: UInt32,
        capture_internal_sample_rate: UInt32,
        capture_period_size_in_frames: UInt32,
    ) raises -> Self:
        """`sample_rate` is the playback rate; the capture side runs at the internal rate."""
        var ptr = raw.duplex_rb_alloc(lib[])
        if ptr == null_handle():
            raise Error("duplex_rb_alloc failed (out of memory)")
        var code = raw.duplex_rb_init(
            lib[],
            ptr,
            _FORMAT_F32,
            channels,
            sample_rate,
            capture_internal_sample_rate,
            capture_period_size_in_frames,
        )
        if code != MA_SUCCESS:
            raw.duplex_rb_free(lib[], ptr)
            raise Error(lib[].describe("duplex_rb init failed", code))
        return Self(lib.copy(), ptr, channels)

    def write(mut self, frames: List[Float32]) raises -> UInt32:
        """Queues as many whole frames of `frames` as fit; returns how many."""
        var frame_count = UInt32(len(frames) // Int(self._channels))
        var rc = raw.duplex_rb_write(self._lib[], self._ptr, frames, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("duplex_rb write failed", rc.result))
        return rc.value

    def read(mut self, frame_count: UInt32) raises -> List[Float32]:
        """Takes up to `frame_count` frames; the list holds only what was read."""
        var samples = Int(frame_count) * Int(self._channels)
        var buf = List[Float32]()
        buf.resize(samples, Float32(0))
        var rc = raw.duplex_rb_read(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("duplex_rb read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def available_read(self) raises -> UInt32:
        var rc = raw.duplex_rb_available_read(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("duplex_rb available_read failed", rc.result))
        return rc.value

    def available_write(self) raises -> UInt32:
        var rc = raw.duplex_rb_available_write(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("duplex_rb available_write failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.duplex_rb_free(self._lib[], self._ptr)


# ================= runtime_info =================


struct Version(Copyable, Movable):
    """The miniaudio version this library was built from."""

    var major: UInt32
    var minor: UInt32
    var revision: UInt32

    def __init__(out self, major: UInt32, minor: UInt32, revision: UInt32):
        self.major = major
        self.minor = minor
        self.revision = revision

    def to_string(self) -> String:
        return String(self.major) + "." + String(self.minor) + "." + String(self.revision)


def version(lib: ArcPointer[MaLib]) raises -> Version:
    var rc = raw.runtime_version(lib[])
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("runtime version failed", rc.result))
    return Version(rc.major, rc.minor, rc.revision)


def is_backend_enabled(lib: ArcPointer[MaLib], backend: Int) raises -> Bool:
    """Whether this build includes that backend (a ma_backend code, 0..14)."""
    var rc = raw.runtime_is_backend_enabled(lib[], backend)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("is_backend_enabled failed", rc.result))
    return rc.value


def is_loopback_supported(lib: ArcPointer[MaLib], backend: Int) raises -> Bool:
    """Whether that backend can capture what is being played. Only WASAPI can."""
    var rc = raw.runtime_is_loopback_supported(lib[], backend)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("is_loopback_supported failed", rc.result))
    return rc.value
