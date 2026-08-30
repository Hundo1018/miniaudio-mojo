"""Binding layer: raw 1:1 wrappers over the filter shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* out-param pairs. No lifecycle / error policy; that lives in filter.mojo.

Every filter in miniaudio's biquad-derived family has the same lifecycle and
differs only in what its config takes, so these wrappers are uniform by
construction: alloc / free, get_heap_size, init, init_preallocated, reinit,
uninit, process, get_latency, and clear_cache where miniaudio has one.

Covered here: ma_biquad, the first- and second-order blocks ma_lpf1 / ma_lpf2 /
ma_hpf1 / ma_hpf2, the compound ma_lpf / ma_hpf, and the three node-graph
variants, which take an engine handle to find the graph they attach to.

Frames are f32 here, matching the format the tests use; the shim takes a
ma_format code and is format-agnostic.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.device_raw import MaUInt

# ---- ma_biquad — raw biquad, configured by its six coefficients ----


def biquad_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_biquad_alloc", OpaquePointer[MutUntrackedOrigin]]()


def biquad_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_biquad_free", NoneType](f)


def biquad_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    b0: Float64,
    b1: Float64,
    b2: Float64,
    a0: Float64,
    a1: Float64,
    a2: Float64,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_biquad_get_heap_size", Int32](
            Int32(format), channels, b0, b1, b2, a0, a1, a2, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def biquad_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    b0: Float64,
    b1: Float64,
    b2: Float64,
    a0: Float64,
    a1: Float64,
    a2: Float64,
) -> Int:
    return Int(lib.handle.call["ma_shim_biquad_init", Int32](f, Int32(format), channels, b0, b1, b2, a0, a1, a2))


def biquad_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    b0: Float64,
    b1: Float64,
    b2: Float64,
    a0: Float64,
    a1: Float64,
    a2: Float64,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_biquad_init_preallocated", Int32](f, Int32(format), channels, b0, b1, b2, a0, a1, a2)
    )


def biquad_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    b0: Float64,
    b1: Float64,
    b2: Float64,
    a0: Float64,
    a1: Float64,
    a2: Float64,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_biquad_reinit", Int32](f, Int32(format), channels, b0, b1, b2, a0, a1, a2))


def biquad_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_biquad_uninit", Int32](f))


def biquad_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_biquad_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def biquad_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_biquad_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def biquad_clear_cache(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Drop the filter memory, leaving the tuning in place."""
    return Int(lib.handle.call["ma_shim_biquad_clear_cache", Int32](f))

# ---- ma_lpf1 — first-order low-pass building block ----


def lpf1_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_lpf1_alloc", OpaquePointer[MutUntrackedOrigin]]()


def lpf1_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_lpf1_free", NoneType](f)


def lpf1_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf1_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def lpf1_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    return Int(lib.handle.call["ma_shim_lpf1_init", Int32](f, Int32(format), channels, sample_rate, cutoff))


def lpf1_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_lpf1_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff)
    )


def lpf1_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_lpf1_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff))


def lpf1_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_lpf1_uninit", Int32](f))


def lpf1_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_lpf1_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def lpf1_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf1_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def lpf1_clear_cache(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Drop the filter memory, leaving the tuning in place."""
    return Int(lib.handle.call["ma_shim_lpf1_clear_cache", Int32](f))

# ---- ma_hpf1 — first-order high-pass building block ----


def hpf1_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_hpf1_alloc", OpaquePointer[MutUntrackedOrigin]]()


def hpf1_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_hpf1_free", NoneType](f)


def hpf1_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf1_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def hpf1_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    return Int(lib.handle.call["ma_shim_hpf1_init", Int32](f, Int32(format), channels, sample_rate, cutoff))


def hpf1_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_hpf1_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff)
    )


def hpf1_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_hpf1_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff))


def hpf1_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_hpf1_uninit", Int32](f))


def hpf1_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_hpf1_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def hpf1_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf1_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])

# ---- ma_lpf2 — second-order low-pass building block ----


def lpf2_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_lpf2_alloc", OpaquePointer[MutUntrackedOrigin]]()


def lpf2_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_lpf2_free", NoneType](f)


def lpf2_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf2_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, q, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def lpf2_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    return Int(lib.handle.call["ma_shim_lpf2_init", Int32](f, Int32(format), channels, sample_rate, cutoff, q))


def lpf2_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_lpf2_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff, q)
    )


def lpf2_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_lpf2_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff, q))


def lpf2_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_lpf2_uninit", Int32](f))


def lpf2_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_lpf2_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def lpf2_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf2_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def lpf2_clear_cache(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Drop the filter memory, leaving the tuning in place."""
    return Int(lib.handle.call["ma_shim_lpf2_clear_cache", Int32](f))

# ---- ma_hpf2 — second-order high-pass building block ----


def hpf2_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_hpf2_alloc", OpaquePointer[MutUntrackedOrigin]]()


def hpf2_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_hpf2_free", NoneType](f)


def hpf2_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf2_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, q, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def hpf2_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    return Int(lib.handle.call["ma_shim_hpf2_init", Int32](f, Int32(format), channels, sample_rate, cutoff, q))


def hpf2_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_hpf2_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff, q)
    )


def hpf2_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    q: Float64,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_hpf2_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff, q))


def hpf2_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_hpf2_uninit", Int32](f))


def hpf2_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_hpf2_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def hpf2_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf2_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])

# ---- ma_lpf — compound low-pass: first- and second-order blocks stacked to `order` ----


def lpf_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_lpf_alloc", OpaquePointer[MutUntrackedOrigin]]()


def lpf_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_lpf_free", NoneType](f)


def lpf_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, order, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def lpf_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    return Int(lib.handle.call["ma_shim_lpf_init", Int32](f, Int32(format), channels, sample_rate, cutoff, order))


def lpf_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_lpf_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff, order)
    )


def lpf_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_lpf_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff, order))


def lpf_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_lpf_uninit", Int32](f))


def lpf_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_lpf_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def lpf_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_lpf_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])


def lpf_clear_cache(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    """Drop the filter memory, leaving the tuning in place."""
    return Int(lib.handle.call["ma_shim_lpf_clear_cache", Int32](f))

# ---- ma_hpf — compound high-pass: first- and second-order blocks stacked to `order` ----


def hpf_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_hpf_alloc", OpaquePointer[MutUntrackedOrigin]]()


def hpf_free(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_hpf_free", NoneType](f)


def hpf_get_heap_size(
    lib: MaLib,
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> MaCount:
    """Working-heap size for this configuration, without building the filter."""
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf_get_heap_size", Int32](
            Int32(format), channels, sample_rate, cutoff, order, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def hpf_init(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    return Int(lib.handle.call["ma_shim_hpf_init", Int32](f, Int32(format), channels, sample_rate, cutoff, order))


def hpf_init_preallocated(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_hpf_init_preallocated", Int32](f, Int32(format), channels, sample_rate, cutoff, order)
    )


def hpf_reinit(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Retune in place, keeping the filter's running state."""
    return Int(lib.handle.call["ma_shim_hpf_reinit", Int32](f, Int32(format), channels, sample_rate, cutoff, order))


def hpf_uninit(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_hpf_uninit", Int32](f))


def hpf_process(
    lib: MaLib,
    f: OpaquePointer[MutUntrackedOrigin],
    mut dst: List[Float32],
    src: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Filters frame_count frames out-of-place; the frame count is unchanged."""
    return Int(
        lib.handle.call["ma_shim_hpf_process", Int32](
            f, dst.unsafe_ptr(), src.unsafe_ptr(), frame_count
        )
    )


def hpf_get_latency(lib: MaLib, f: OpaquePointer[MutUntrackedOrigin]) -> MaUInt:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_hpf_get_latency", Int32](f, holder.unsafe_ptr())
    )
    return MaUInt(code, holder[0])

# ---- ma_biquad_node — biquad as a node-graph node ----


def biquad_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_biquad_node_alloc", OpaquePointer[MutUntrackedOrigin]]()


def biquad_node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_biquad_node_free", NoneType](n)


def biquad_node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    b0: Float32,
    b1: Float32,
    b2: Float32,
    a0: Float32,
    a1: Float32,
    a2: Float32,
) -> Int:
    """Attaches the node to the graph belonging to `engine`."""
    return Int(lib.handle.call["ma_shim_biquad_node_init", Int32](n, engine, channels, b0, b1, b2, a0, a1, a2))


def biquad_node_reinit(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    b0: Float64,
    b1: Float64,
    b2: Float64,
    a0: Float64,
    a1: Float64,
    a2: Float64,
) -> Int:
    """Retune the node's filter in place, keeping it attached."""
    return Int(lib.handle.call["ma_shim_biquad_node_reinit", Int32](n, Int32(format), channels, b0, b1, b2, a0, a1, a2))


def biquad_node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_biquad_node_uninit", Int32](n))

# ---- ma_lpf_node — compound low-pass as a node-graph node ----


def lpf_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_lpf_node_alloc", OpaquePointer[MutUntrackedOrigin]]()


def lpf_node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_lpf_node_free", NoneType](n)


def lpf_node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Attaches the node to the graph belonging to `engine`."""
    return Int(lib.handle.call["ma_shim_lpf_node_init", Int32](n, engine, channels, sample_rate, cutoff, order))


def lpf_node_reinit(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Retune the node's filter in place, keeping it attached."""
    return Int(lib.handle.call["ma_shim_lpf_node_reinit", Int32](n, Int32(format), channels, sample_rate, cutoff, order))


def lpf_node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_lpf_node_uninit", Int32](n))

# ---- ma_hpf_node — compound high-pass as a node-graph node ----


def hpf_node_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_hpf_node_alloc", OpaquePointer[MutUntrackedOrigin]]()


def hpf_node_free(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_hpf_node_free", NoneType](n)


def hpf_node_init(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    engine: OpaquePointer[MutUntrackedOrigin],
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Attaches the node to the graph belonging to `engine`."""
    return Int(lib.handle.call["ma_shim_hpf_node_init", Int32](n, engine, channels, sample_rate, cutoff, order))


def hpf_node_reinit(
    lib: MaLib,
    n: OpaquePointer[MutUntrackedOrigin],
    format: Int,
    channels: UInt32,
    sample_rate: UInt32,
    cutoff: Float64,
    order: UInt32,
) -> Int:
    """Retune the node's filter in place, keeping it attached."""
    return Int(lib.handle.call["ma_shim_hpf_node_reinit", Int32](n, Int32(format), channels, sample_rate, cutoff, order))


def hpf_node_uninit(lib: MaLib, n: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_hpf_node_uninit", Int32](n))
