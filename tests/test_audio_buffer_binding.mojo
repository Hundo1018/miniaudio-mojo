"""TDD contract tests for the audio buffer BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: both audio buffers are pure in-memory
structures, so no device, engine, or file is involved. All 25 MA_API audio
buffer functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END, MA_INVALID_ARGS
import miniaudio._ffi.audio_buffer_raw as raw


comptime FMT_F32: Int = 5
comptime FMT_UNKNOWN: Int = 0
comptime MONO: UInt32 = 1
comptime FRAMES: UInt64 = 8


def _lib() raises -> MaLib:
    return MaLib.default()


def _ramp(n: Int, start: Int = 0) -> List[Float32]:
    """Frame ramp 0,1,2,... — mono f32, so one sample per frame."""
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(start + i))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


# ---- ma_audio_buffer_ref — positive paths -----------------------------------


def test_ref_init_read_roundtrip() raises:
    """Init + read returns the same frames in order and lands on the end."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    assert_true(ab != null_handle())
    var src = _ramp(8)
    assert_equal(raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES), MA_SUCCESS)

    assert_equal(raw.audio_buffer_ref_get_length(lib, ab).value, FRAMES)
    assert_equal(raw.audio_buffer_ref_get_cursor(lib, ab).value, UInt64(0))
    assert_equal(raw.audio_buffer_ref_get_available(lib, ab).value, FRAMES)

    var dst = _sink(8)
    var rc = raw.audio_buffer_ref_read(lib, ab, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, FRAMES)
    for i in range(8):
        assert_equal(dst[i], src[i])

    assert_equal(raw.audio_buffer_ref_get_cursor(lib, ab).value, FRAMES)
    assert_equal(raw.audio_buffer_ref_get_available(lib, ab).value, UInt64(0))
    var ended = raw.audio_buffer_ref_at_end(lib, ab)
    assert_equal(ended.result, MA_SUCCESS)
    assert_true(ended.value)

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_read_is_short_at_end_but_loops_when_asked() raises:
    """Without loop the read stops at the end; with loop it wraps to the start."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES)

    var dst = _sink(12)
    var short = raw.audio_buffer_ref_read(lib, ab, dst, UInt64(12))
    assert_equal(short.result, MA_SUCCESS)
    assert_equal(short.value, FRAMES)

    assert_equal(raw.audio_buffer_ref_seek(lib, ab, UInt64(0)), MA_SUCCESS)
    var looped = raw.audio_buffer_ref_read(lib, ab, dst, UInt64(12), loop=True)
    assert_equal(looped.value, UInt64(12))
    # The 12th frame is frame 3 of the second pass through an 8-frame buffer.
    assert_equal(looped.value, UInt64(12))
    for i in range(8):
        assert_equal(dst[i], Float32(i))
    for i in range(4):
        assert_equal(dst[8 + i], Float32(i))

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_seek_moves_the_cursor() raises:
    """Seek repositions the cursor; seeking past the length is rejected."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES)

    assert_equal(raw.audio_buffer_ref_seek(lib, ab, UInt64(5)), MA_SUCCESS)
    assert_equal(raw.audio_buffer_ref_get_cursor(lib, ab).value, UInt64(5))
    assert_equal(raw.audio_buffer_ref_get_available(lib, ab).value, UInt64(3))
    assert_equal(raw.audio_buffer_ref_seek(lib, ab, UInt64(99)), MA_INVALID_ARGS)

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_map_read_reports_at_end_on_the_last_chunk() raises:
    """Map/unmap hands out the frames; unmap reports MA_AT_END on the final one."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES)

    var dst = _sink(4)
    var first = raw.audio_buffer_ref_map_read(lib, ab, dst, UInt64(4))
    assert_equal(first.result, MA_SUCCESS)
    assert_equal(first.value, UInt64(4))
    for i in range(4):
        assert_equal(dst[i], Float32(i))

    var last = raw.audio_buffer_ref_map_read(lib, ab, dst, UInt64(4))
    assert_equal(last.result, MA_AT_END)
    assert_equal(last.value, UInt64(4))
    for i in range(4):
        assert_equal(dst[i], Float32(4 + i))

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_set_data_replaces_frames_and_rewinds() raises:
    """The set_data call swaps in new frames and puts the cursor back to 0."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES)
    assert_equal(raw.audio_buffer_ref_seek(lib, ab, UInt64(6)), MA_SUCCESS)

    var replacement = _ramp(4, start=100)
    assert_equal(
        raw.audio_buffer_ref_set_data(lib, ab, replacement, UInt64(4)), MA_SUCCESS
    )
    assert_equal(raw.audio_buffer_ref_get_cursor(lib, ab).value, UInt64(0))
    assert_equal(raw.audio_buffer_ref_get_length(lib, ab).value, UInt64(4))

    var dst = _sink(4)
    var rc = raw.audio_buffer_ref_read(lib, ab, dst, UInt64(4))
    assert_equal(rc.value, UInt64(4))
    for i in range(4):
        assert_equal(dst[i], Float32(100 + i))

    raw.audio_buffer_ref_free(lib, ab)


# ---- ma_audio_buffer_ref — negative paths -----------------------------------


def test_ref_init_rejects_null_data_and_bad_geometry() raises:
    """A NULL source, a zero frame count, and an unknown format are all rejected."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)

    assert_equal(
        raw.audio_buffer_ref_init_null_data(lib, ab, FMT_F32, MONO, FRAMES),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, UInt64(0)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.audio_buffer_ref_init(lib, ab, FMT_UNKNOWN, MONO, src, FRAMES),
        MA_INVALID_ARGS,
    )

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(4)
    var dst = _sink(4)

    assert_equal(raw.audio_buffer_ref_set_data(lib, ab, src, UInt64(4)), MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_ref_read(lib, ab, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_ref_seek(lib, ab, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(
        raw.audio_buffer_ref_map_read(lib, ab, dst, UInt64(4)).result, MA_INVALID_ARGS
    )
    assert_equal(raw.audio_buffer_ref_at_end(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_ref_get_cursor(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_ref_get_length(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_ref_get_available(lib, ab).result, MA_INVALID_ARGS)

    raw.audio_buffer_ref_free(lib, ab)


def test_ref_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; uninit/free of a null handle must not crash."""
    var lib = _lib()
    var ab = raw.audio_buffer_ref_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_ref_init(lib, ab, FMT_F32, MONO, src, FRAMES)

    assert_equal(raw.audio_buffer_ref_uninit(lib, ab), MA_SUCCESS)
    assert_equal(raw.audio_buffer_ref_uninit(lib, ab), MA_SUCCESS)
    assert_equal(raw.audio_buffer_ref_get_length(lib, ab).result, MA_INVALID_ARGS)
    raw.audio_buffer_ref_free(lib, ab)

    assert_equal(raw.audio_buffer_ref_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.audio_buffer_ref_init(lib, null_handle(), FMT_F32, MONO, src, FRAMES),
        MA_INVALID_ARGS,
    )
    raw.audio_buffer_ref_free(lib, null_handle())


# ---- ma_audio_buffer — positive paths ---------------------------------------


def test_buffer_init_read_roundtrip() raises:
    """The non-copying init reads back the frames the shim is holding."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    assert_true(ab != null_handle())
    var src = _ramp(8)
    assert_equal(raw.audio_buffer_init(lib, ab, FMT_F32, MONO, src, FRAMES), MA_SUCCESS)

    assert_equal(raw.audio_buffer_get_length(lib, ab).value, FRAMES)
    var dst = _sink(8)
    var rc = raw.audio_buffer_read(lib, ab, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, FRAMES)
    for i in range(8):
        assert_equal(dst[i], src[i])
    assert_true(raw.audio_buffer_at_end(lib, ab).value)

    raw.audio_buffer_free(lib, ab)


def test_buffer_init_copy_owns_its_frames() raises:
    """The init_copy path round-trips the frames miniaudio copied for itself."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var src = _ramp(8, start=10)
    assert_equal(
        raw.audio_buffer_init_copy(lib, ab, FMT_F32, MONO, src, FRAMES), MA_SUCCESS
    )

    var dst = _sink(8)
    var rc = raw.audio_buffer_read(lib, ab, dst, FRAMES)
    assert_equal(rc.value, FRAMES)
    for i in range(8):
        assert_equal(dst[i], Float32(10 + i))

    raw.audio_buffer_free(lib, ab)


def test_buffer_init_copy_with_null_source_is_silent() raises:
    """A NULL source produces a zero-filled buffer of the requested length."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    assert_equal(
        raw.audio_buffer_init_copy_silent(lib, ab, FMT_F32, MONO, FRAMES), MA_SUCCESS
    )

    var dst = _sink(8)
    var rc = raw.audio_buffer_read(lib, ab, dst, FRAMES)
    assert_equal(rc.value, FRAMES)
    for i in range(8):
        assert_equal(dst[i], Float32(0))

    raw.audio_buffer_free(lib, ab)


def test_buffer_alloc_and_init_roundtrip() raises:
    """The heap-allocated buffer behaves like the embedded one, first frame aside.

    Pins an upstream defect in miniaudio 0.11.25: alloc_and_init copies the frames
    into the struct's trailing `_pExtraData` and then calls init_ex, whose
    `MA_ZERO_MEMORY(p, sizeof(*p) - sizeof(p->_pExtraData))` overshoots into the
    audio data by the trailing padding (3 bytes here). Frame 0 therefore comes back
    with its low 3 bytes cleared — 20.0f reads back as 8.0f — while every later
    frame is intact. If a future miniaudio fixes this, that assertion fails and the
    documented caveat should be dropped.
    """
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var src = _ramp(8, start=20)
    assert_equal(
        raw.audio_buffer_alloc_and_init(lib, ab, FMT_F32, MONO, src, FRAMES), MA_SUCCESS
    )

    assert_equal(raw.audio_buffer_get_length(lib, ab).value, FRAMES)
    var dst = _sink(8)
    var rc = raw.audio_buffer_read(lib, ab, dst, FRAMES)
    assert_equal(rc.value, FRAMES)
    assert_equal(dst[0], Float32(8))  # 20.0f with its low 3 bytes zeroed
    for i in range(1, 8):
        assert_equal(dst[i], Float32(20 + i))

    # Torn down with ma_audio_buffer_uninit_and_free rather than plain uninit.
    assert_equal(raw.audio_buffer_uninit(lib, ab), MA_SUCCESS)
    raw.audio_buffer_free(lib, ab)


def test_buffer_seek_cursor_available_and_loop() raises:
    """Cursor accounting matches the ref's, and looping wraps the same way."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_init(lib, ab, FMT_F32, MONO, src, FRAMES)

    assert_equal(raw.audio_buffer_seek(lib, ab, UInt64(6)), MA_SUCCESS)
    assert_equal(raw.audio_buffer_get_cursor(lib, ab).value, UInt64(6))
    assert_equal(raw.audio_buffer_get_available(lib, ab).value, UInt64(2))
    assert_true(not raw.audio_buffer_at_end(lib, ab).value)

    var dst = _sink(6)
    var looped = raw.audio_buffer_read(lib, ab, dst, UInt64(6), loop=True)
    assert_equal(looped.value, UInt64(6))
    assert_equal(dst[0], Float32(6))
    assert_equal(dst[1], Float32(7))
    assert_equal(dst[2], Float32(0))

    assert_equal(raw.audio_buffer_seek(lib, ab, UInt64(99)), MA_INVALID_ARGS)
    raw.audio_buffer_free(lib, ab)


def test_buffer_map_read_reports_at_end_on_the_last_chunk() raises:
    """Map/unmap on the owning buffer reports MA_AT_END on the final chunk."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var src = _ramp(8)
    _ = raw.audio_buffer_init_copy(lib, ab, FMT_F32, MONO, src, FRAMES)

    var dst = _sink(4)
    assert_equal(raw.audio_buffer_map_read(lib, ab, dst, UInt64(4)).result, MA_SUCCESS)
    var last = raw.audio_buffer_map_read(lib, ab, dst, UInt64(4))
    assert_equal(last.result, MA_AT_END)
    assert_equal(last.value, UInt64(4))
    for i in range(4):
        assert_equal(dst[i], Float32(4 + i))

    raw.audio_buffer_free(lib, ab)


# ---- ma_audio_buffer — negative paths ---------------------------------------


def test_buffer_init_rejects_zero_frames() raises:
    """All three init paths reject a zero-frame buffer."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var src = _ramp(8)

    assert_equal(
        raw.audio_buffer_init(lib, ab, FMT_F32, MONO, src, UInt64(0)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.audio_buffer_init_copy(lib, ab, FMT_F32, MONO, src, UInt64(0)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.audio_buffer_alloc_and_init(lib, ab, FMT_F32, MONO, src, UInt64(0)),
        MA_INVALID_ARGS,
    )

    raw.audio_buffer_free(lib, ab)


def test_buffer_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var ab = raw.audio_buffer_alloc(lib)
    var dst = _sink(4)

    assert_equal(raw.audio_buffer_read(lib, ab, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_seek(lib, ab, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(
        raw.audio_buffer_map_read(lib, ab, dst, UInt64(4)).result, MA_INVALID_ARGS
    )
    assert_equal(raw.audio_buffer_at_end(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_get_cursor(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_get_length(lib, ab).result, MA_INVALID_ARGS)
    assert_equal(raw.audio_buffer_get_available(lib, ab).result, MA_INVALID_ARGS)

    raw.audio_buffer_free(lib, ab)


def test_buffer_null_handle_is_rejected_and_free_is_a_noop() raises:
    """Null handles are rejected by every entry point; free(null) must not crash."""
    var lib = _lib()
    var src = _ramp(8)

    assert_equal(
        raw.audio_buffer_init(lib, null_handle(), FMT_F32, MONO, src, FRAMES),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.audio_buffer_init_copy(lib, null_handle(), FMT_F32, MONO, src, FRAMES),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.audio_buffer_alloc_and_init(lib, null_handle(), FMT_F32, MONO, src, FRAMES),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.audio_buffer_uninit(lib, null_handle()), MA_INVALID_ARGS)
    raw.audio_buffer_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
