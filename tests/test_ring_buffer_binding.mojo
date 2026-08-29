"""TDD contract tests for the ring buffer BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: both ring buffers are pure in-memory
structures, so no device, engine, or file is involved. All 38 MA_API ring
buffer functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.ring_buffer_raw as raw


comptime FMT_F32: Int = 5
comptime RB_BYTES: UInt64 = 32


def _lib() raises -> MaLib:
    return MaLib.default()


def _ramp(n: Int) -> List[UInt8]:
    """Byte ramp 0,1,2,... used to verify ordering across the wrap point."""
    var out = List[UInt8](capacity=n)
    for i in range(n):
        out.append(UInt8(i & 0xFF))
    return out^


# ---- ma_rb — positive paths -------------------------------------------------


def test_rb_init_write_read_roundtrip() raises:
    """init + write + read returns the same bytes in order."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_true(rb != null_handle())
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    var src = _ramp(20)
    var wrc = raw.rb_write(lib, rb, src, UInt64(20))
    assert_equal(wrc.result, MA_SUCCESS)
    assert_true(wrc.value == UInt64(20))

    var dst = List[UInt8]()
    dst.resize(20, UInt8(0))
    var rrc = raw.rb_read(lib, rb, dst, UInt64(20))
    assert_equal(rrc.result, MA_SUCCESS)
    assert_true(rrc.value == UInt64(20))
    for i in range(20):
        assert_equal(dst[i], src[i])

    raw.rb_free(lib, rb)


def test_rb_available_and_pointer_distance() raises:
    """available_read / available_write / pointer_distance track the pointers."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    var empty_r = raw.rb_available_read(lib, rb)
    assert_equal(empty_r.result, MA_SUCCESS)
    assert_true(empty_r.value == UInt32(0))
    var empty_w = raw.rb_available_write(lib, rb)
    assert_equal(empty_w.result, MA_SUCCESS)
    assert_true(empty_w.value == UInt32(32))

    var src = _ramp(20)
    _ = raw.rb_write(lib, rb, src, UInt64(20))

    var full_r = raw.rb_available_read(lib, rb)
    assert_true(full_r.value == UInt32(20))
    var full_w = raw.rb_available_write(lib, rb)
    assert_true(full_w.value == UInt32(12))

    var dist = raw.rb_pointer_distance(lib, rb)
    assert_equal(dist.result, MA_SUCCESS)
    assert_equal(dist.value, 20)

    raw.rb_free(lib, rb)


def test_rb_write_is_capped_by_capacity() raises:
    """A write larger than the buffer is short, not an error."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    var src = _ramp(100)
    var wrc = raw.rb_write(lib, rb, src, UInt64(100))
    assert_equal(wrc.result, MA_SUCCESS)
    assert_true(wrc.value == UInt64(32))

    var avail = raw.rb_available_write(lib, rb)
    assert_true(avail.value == UInt32(0))
    raw.rb_free(lib, rb)


def test_rb_read_of_empty_buffer_is_short() raises:
    """Reading an empty buffer yields 0 bytes and MA_SUCCESS."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    var dst = List[UInt8]()
    dst.resize(16, UInt8(0))
    var rrc = raw.rb_read(lib, rb, dst, UInt64(16))
    assert_equal(rrc.result, MA_SUCCESS)
    assert_true(rrc.value == UInt64(0))
    raw.rb_free(lib, rb)


def test_rb_reset_discards_buffered_data() raises:
    """reset returns the buffer to empty."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    var src = _ramp(16)
    _ = raw.rb_write(lib, rb, src, UInt64(16))
    assert_true(raw.rb_available_read(lib, rb).value == UInt32(16))

    assert_equal(raw.rb_reset(lib, rb), MA_SUCCESS)
    assert_true(raw.rb_available_read(lib, rb).value == UInt32(0))
    raw.rb_free(lib, rb)


def test_rb_seek_read_and_write() raises:
    """seek_write advances the write pointer; seek_read consumes without copying."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)

    assert_equal(raw.rb_seek_write(lib, rb, UInt64(8)), MA_SUCCESS)
    assert_true(raw.rb_available_read(lib, rb).value == UInt32(8))

    assert_equal(raw.rb_seek_read(lib, rb, UInt64(4)), MA_SUCCESS)
    assert_true(raw.rb_available_read(lib, rb).value == UInt32(4))
    raw.rb_free(lib, rb)


def test_rb_init_ex_subbuffer_geometry() raises:
    """init_ex reports size / stride / offsets consistently.

    With miniaudio owning the allocation the requested stride is ignored: it
    picks its own, the sub-buffer size rounded up for SIMD alignment.
    """
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(
        raw.rb_init_ex(lib, rb, UInt64(32), UInt64(2), UInt64(64), False),
        MA_SUCCESS,
    )

    var size = raw.rb_get_subbuffer_size(lib, rb)
    assert_equal(size.result, MA_SUCCESS)
    assert_true(size.value == UInt64(32))

    var stride = raw.rb_get_subbuffer_stride(lib, rb)
    assert_equal(stride.result, MA_SUCCESS)
    assert_true(stride.value == UInt64(32))

    var off0 = raw.rb_get_subbuffer_offset(lib, rb, UInt64(0))
    assert_equal(off0.result, MA_SUCCESS)
    assert_true(off0.value == UInt64(0))
    var off1 = raw.rb_get_subbuffer_offset(lib, rb, UInt64(1))
    assert_true(off1.value == stride.value)

    # get_subbuffer_ptr's address, expressed as an offset, must agree.
    var ptr1 = raw.rb_get_subbuffer_ptr_offset(lib, rb, UInt64(1))
    assert_equal(ptr1.result, MA_SUCCESS)
    assert_true(ptr1.value == off1.value)

    raw.rb_free(lib, rb)


def test_rb_init_ex_preallocated_backing_store() raises:
    """The preallocated path honours the requested stride and is usable for I/O."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(
        raw.rb_init_ex(lib, rb, UInt64(32), UInt64(2), UInt64(64), True),
        MA_SUCCESS,
    )

    # Unlike the miniaudio-owned path above, the explicit stride is kept.
    var stride = raw.rb_get_subbuffer_stride(lib, rb)
    assert_true(stride.value == UInt64(64))
    var off1 = raw.rb_get_subbuffer_offset(lib, rb, UInt64(1))
    assert_true(off1.value == UInt64(64))
    var ptr1 = raw.rb_get_subbuffer_ptr_offset(lib, rb, UInt64(1))
    assert_true(ptr1.value == off1.value)

    var src = _ramp(16)
    var wrc = raw.rb_write(lib, rb, src, UInt64(16))
    assert_equal(wrc.result, MA_SUCCESS)
    assert_true(wrc.value == UInt64(16))

    var dst = List[UInt8]()
    dst.resize(16, UInt8(0))
    var rrc = raw.rb_read(lib, rb, dst, UInt64(16))
    assert_true(rrc.value == UInt64(16))
    for i in range(16):
        assert_equal(dst[i], src[i])

    raw.rb_free(lib, rb)


def test_rb_uninit_then_reinit() raises:
    """uninit releases the buffer; the same handle can be re-initialised."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, RB_BYTES), MA_SUCCESS)
    assert_equal(raw.rb_uninit(lib, rb), MA_SUCCESS)
    assert_equal(raw.rb_init(lib, rb, UInt64(64)), MA_SUCCESS)
    assert_true(raw.rb_get_subbuffer_size(lib, rb).value == UInt64(64))
    raw.rb_free(lib, rb)


# ---- ma_rb — negative paths -------------------------------------------------


def test_rb_null_handle_ops_invalid_args() raises:
    """Every rb op on a null handle returns MA_INVALID_ARGS."""
    var lib = _lib()
    var nil = null_handle()
    var src = _ramp(4)
    var dst = List[UInt8]()
    dst.resize(4, UInt8(0))

    assert_equal(raw.rb_init(lib, nil, RB_BYTES), MA_INVALID_ARGS)
    assert_equal(
        raw.rb_init_ex(lib, nil, UInt64(32), UInt64(1), UInt64(0), False),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.rb_uninit(lib, nil), MA_INVALID_ARGS)
    assert_equal(raw.rb_reset(lib, nil), MA_INVALID_ARGS)
    assert_equal(raw.rb_write(lib, nil, src, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_read(lib, nil, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_seek_read(lib, nil, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rb_seek_write(lib, nil, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rb_pointer_distance(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_available_read(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_available_write(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_get_subbuffer_size(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_get_subbuffer_stride(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(
        raw.rb_get_subbuffer_offset(lib, nil, UInt64(0)).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.rb_get_subbuffer_ptr_offset(lib, nil, UInt64(0)).result, MA_INVALID_ARGS
    )


def test_rb_ops_before_init_invalid_args() raises:
    """Ops on an allocated-but-uninitialised handle return MA_INVALID_ARGS."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    var src = _ramp(4)
    var dst = List[UInt8]()
    dst.resize(4, UInt8(0))

    assert_equal(raw.rb_reset(lib, rb), MA_INVALID_ARGS)
    assert_equal(raw.rb_write(lib, rb, src, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_read(lib, rb, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_seek_read(lib, rb, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rb_seek_write(lib, rb, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rb_pointer_distance(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_available_read(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_available_write(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_get_subbuffer_size(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.rb_get_subbuffer_stride(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(
        raw.rb_get_subbuffer_offset(lib, rb, UInt64(0)).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.rb_get_subbuffer_ptr_offset(lib, rb, UInt64(0)).result, MA_INVALID_ARGS
    )
    # uninit on a never-initialised handle is a documented no-op success.
    assert_equal(raw.rb_uninit(lib, rb), MA_SUCCESS)
    raw.rb_free(lib, rb)


def test_rb_init_rejects_zero_size() raises:
    """A zero-byte ring buffer is rejected by miniaudio."""
    var lib = _lib()
    var rb = raw.rb_alloc(lib)
    assert_equal(raw.rb_init(lib, rb, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(
        raw.rb_init_ex(lib, rb, UInt64(0), UInt64(1), UInt64(0), False),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.rb_init_ex(lib, rb, UInt64(32), UInt64(0), UInt64(0), True),
        MA_INVALID_ARGS,
    )
    raw.rb_free(lib, rb)


def test_rb_free_null_handle_is_noop() raises:
    """free(null) must not crash."""
    var lib = _lib()
    raw.rb_free(lib, null_handle())


# ---- ma_pcm_rb — positive paths ---------------------------------------------


def _ramp_f32(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i) * 0.25)
    return out^


def test_pcm_rb_init_write_read_roundtrip() raises:
    """init + write + read returns the same f32 samples in order."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_true(rb != null_handle())
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(2), UInt32(16)), MA_SUCCESS)

    var src = _ramp_f32(20)  # 10 stereo frames
    var wrc = raw.pcm_rb_write(lib, rb, src, UInt32(10))
    assert_equal(wrc.result, MA_SUCCESS)
    assert_true(wrc.value == UInt32(10))

    var dst = List[Float32]()
    dst.resize(20, Float32(0))
    var rrc = raw.pcm_rb_read(lib, rb, dst, UInt32(10))
    assert_equal(rrc.result, MA_SUCCESS)
    assert_true(rrc.value == UInt32(10))
    for i in range(20):
        assert_equal(dst[i], src[i])

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_data_format_and_sample_rate() raises:
    """get_data_format reports the configured format; set_sample_rate round-trips."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(2), UInt32(16)), MA_SUCCESS)

    var fmt = raw.pcm_rb_get_data_format(lib, rb)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_equal(fmt.format, FMT_F32)
    assert_true(fmt.channels == UInt32(2))
    assert_true(fmt.sample_rate == UInt32(0))

    assert_equal(raw.pcm_rb_set_sample_rate(lib, rb, UInt32(48000)), MA_SUCCESS)
    var fmt2 = raw.pcm_rb_get_data_format(lib, rb)
    assert_true(fmt2.sample_rate == UInt32(48000))

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_available_and_pointer_distance() raises:
    """Frame-denominated available_read / available_write / pointer_distance."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(2), UInt32(16)), MA_SUCCESS)

    var empty_w = raw.pcm_rb_available_write(lib, rb)
    assert_equal(empty_w.result, MA_SUCCESS)
    assert_true(empty_w.value == UInt32(16))

    var src = _ramp_f32(20)
    _ = raw.pcm_rb_write(lib, rb, src, UInt32(10))

    var avail_r = raw.pcm_rb_available_read(lib, rb)
    assert_equal(avail_r.result, MA_SUCCESS)
    assert_true(avail_r.value == UInt32(10))
    assert_true(raw.pcm_rb_available_write(lib, rb).value == UInt32(6))

    var dist = raw.pcm_rb_pointer_distance(lib, rb)
    assert_equal(dist.result, MA_SUCCESS)
    assert_equal(dist.value, 10)

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_write_is_capped_and_reset_clears() raises:
    """An over-long write is short; reset returns the buffer to empty."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(2), UInt32(16)), MA_SUCCESS)

    var src = _ramp_f32(200)
    var wrc = raw.pcm_rb_write(lib, rb, src, UInt32(100))
    assert_equal(wrc.result, MA_SUCCESS)
    assert_true(wrc.value == UInt32(16))

    assert_equal(raw.pcm_rb_reset(lib, rb), MA_SUCCESS)
    assert_true(raw.pcm_rb_available_read(lib, rb).value == UInt32(0))

    var dst = List[Float32]()
    dst.resize(8, Float32(0))
    var rrc = raw.pcm_rb_read(lib, rb, dst, UInt32(4))
    assert_equal(rrc.result, MA_SUCCESS)
    assert_true(rrc.value == UInt32(0))

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_seek_read_and_write() raises:
    """Frame-denominated seek_write / seek_read move the pointers."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(1), UInt32(16)), MA_SUCCESS)

    assert_equal(raw.pcm_rb_seek_write(lib, rb, UInt32(8)), MA_SUCCESS)
    assert_true(raw.pcm_rb_available_read(lib, rb).value == UInt32(8))
    assert_equal(raw.pcm_rb_seek_read(lib, rb, UInt32(3)), MA_SUCCESS)
    assert_true(raw.pcm_rb_available_read(lib, rb).value == UInt32(5))

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_init_ex_subbuffer_geometry() raises:
    """init_ex geometry: frame-valued offset vs byte-valued pointer offset."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(
        raw.pcm_rb_init_ex(
            lib, rb, FMT_F32, UInt32(1), UInt32(8), UInt32(2), UInt32(0), True
        ),
        MA_SUCCESS,
    )

    var size = raw.pcm_rb_get_subbuffer_size(lib, rb)
    assert_equal(size.result, MA_SUCCESS)
    assert_true(size.value == UInt32(8))

    var stride = raw.pcm_rb_get_subbuffer_stride(lib, rb)
    assert_equal(stride.result, MA_SUCCESS)
    assert_true(stride.value == UInt32(8))

    var off1 = raw.pcm_rb_get_subbuffer_offset(lib, rb, UInt32(1))
    assert_equal(off1.result, MA_SUCCESS)
    assert_true(off1.value == UInt32(8))  # frames

    # 8 frames * 1 channel * 4 bytes per f32 sample = 32 bytes.
    var ptr1 = raw.pcm_rb_get_subbuffer_ptr_offset(lib, rb, UInt32(1))
    assert_equal(ptr1.result, MA_SUCCESS)
    assert_true(ptr1.value == UInt64(32))

    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_uninit_then_reinit() raises:
    """uninit releases the buffer; the same handle can be re-initialised."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(2), UInt32(16)), MA_SUCCESS)
    assert_equal(raw.pcm_rb_uninit(lib, rb), MA_SUCCESS)
    assert_equal(raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(1), UInt32(32)), MA_SUCCESS)
    assert_true(raw.pcm_rb_get_subbuffer_size(lib, rb).value == UInt32(32))
    raw.pcm_rb_free(lib, rb)


# ---- ma_pcm_rb — negative paths ---------------------------------------------


def test_pcm_rb_null_handle_ops_invalid_args() raises:
    """Every pcm_rb op on a null handle returns MA_INVALID_ARGS."""
    var lib = _lib()
    var nil = null_handle()
    var src = _ramp_f32(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))

    assert_equal(
        raw.pcm_rb_init(lib, nil, FMT_F32, UInt32(1), UInt32(16)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.pcm_rb_init_ex(
            lib, nil, FMT_F32, UInt32(1), UInt32(8), UInt32(1), UInt32(0), False
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.pcm_rb_uninit(lib, nil), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_reset(lib, nil), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_write(lib, nil, src, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_read(lib, nil, dst, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_seek_read(lib, nil, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_seek_write(lib, nil, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_pointer_distance(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_available_read(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_available_write(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_get_subbuffer_size(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_get_subbuffer_stride(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(
        raw.pcm_rb_get_subbuffer_offset(lib, nil, UInt32(0)).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.pcm_rb_get_subbuffer_ptr_offset(lib, nil, UInt32(0)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.pcm_rb_get_data_format(lib, nil).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_set_sample_rate(lib, nil, UInt32(44100)), MA_INVALID_ARGS)


def test_pcm_rb_ops_before_init_invalid_args() raises:
    """Ops on an allocated-but-uninitialised pcm handle return MA_INVALID_ARGS."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    var src = _ramp_f32(4)
    var dst = List[Float32]()
    dst.resize(4, Float32(0))

    assert_equal(raw.pcm_rb_reset(lib, rb), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_write(lib, rb, src, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_read(lib, rb, dst, UInt32(2)).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_seek_read(lib, rb, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_seek_write(lib, rb, UInt32(0)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_pointer_distance(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_available_read(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_available_write(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_get_subbuffer_size(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_get_subbuffer_stride(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(
        raw.pcm_rb_get_subbuffer_offset(lib, rb, UInt32(0)).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.pcm_rb_get_subbuffer_ptr_offset(lib, rb, UInt32(0)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.pcm_rb_get_data_format(lib, rb).result, MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_set_sample_rate(lib, rb, UInt32(44100)), MA_INVALID_ARGS)
    assert_equal(raw.pcm_rb_uninit(lib, rb), MA_SUCCESS)
    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_init_rejects_invalid_geometry() raises:
    """Zero frames / zero channels are rejected."""
    var lib = _lib()
    var rb = raw.pcm_rb_alloc(lib)
    assert_equal(
        raw.pcm_rb_init(lib, rb, FMT_F32, UInt32(1), UInt32(0)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.pcm_rb_init_ex(
            lib, rb, FMT_F32, UInt32(1), UInt32(8), UInt32(0), UInt32(0), True
        ),
        MA_INVALID_ARGS,
    )
    raw.pcm_rb_free(lib, rb)


def test_pcm_rb_free_null_handle_is_noop() raises:
    """free(null) must not crash."""
    var lib = _lib()
    raw.pcm_rb_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
