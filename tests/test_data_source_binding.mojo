"""TDD contract tests for the data_source BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the data source is the shim-owned
buffer implementation, so reads, seeks, ranges and chaining need no device or
file. The data_source_node slice needs a node graph, which comes from an engine
on the null backend.

All 30 MA_API data_source functions are exercised here (positive and negative
paths).
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_AT_END
import miniaudio._ffi.data_source_raw as raw
import miniaudio._ffi.engine_raw as eraw


comptime CHANNELS: UInt32 = 2
comptime SAMPLE_RATE: UInt32 = 48000
comptime FRAMES: UInt64 = 480  # 10 ms at 48 kHz
comptime FMT_F32: Int = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _samples() -> List[Float32]:
    """A ramp so reads at different offsets are distinguishable."""
    var buf = List[Float32]()
    buf.resize(Int(FRAMES) * Int(CHANNELS), Float32(0))
    for i in range(len(buf)):
        buf[i] = Float32(i) / Float32(len(buf))
    return buf^


def _make(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """alloc + init_buffer; caller frees."""
    var ds = raw.data_source_alloc(lib)
    assert_true(ds != null_handle())
    var frames = _samples()
    assert_equal(
        raw.data_source_init_buffer(lib, ds, frames, FRAMES, CHANNELS, SAMPLE_RATE),
        MA_SUCCESS,
    )
    return ds


# ---- positive paths ---------------------------------------------------------


def test_init_read_seek() raises:
    """init_buffer + read_pcm_frames + seek_to_pcm_frame + cursor."""
    var lib = _lib()
    var ds = _make(lib)

    var out = List[Float32]()
    out.resize(64 * Int(CHANNELS), Float32(0))
    var rc = raw.data_source_read_pcm_frames(lib, ds, out, UInt64(64))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(64))

    var cursor = raw.data_source_get_cursor_in_pcm_frames(lib, ds)
    assert_equal(cursor.result, MA_SUCCESS)
    assert_equal(cursor.value, UInt64(64))

    assert_equal(raw.data_source_seek_to_pcm_frame(lib, ds, UInt64(0)), MA_SUCCESS)
    var rewound = raw.data_source_get_cursor_in_pcm_frames(lib, ds)
    assert_equal(rewound.value, UInt64(0))

    raw.data_source_free(lib, ds)


def test_seek_variants() raises:
    """seek_pcm_frames / seek_seconds / seek_to_second — forward-only seeks."""
    var lib = _lib()
    var ds = _make(lib)

    var skipped = raw.data_source_seek_pcm_frames(lib, ds, UInt64(48))
    assert_equal(skipped.result, MA_SUCCESS)
    assert_equal(skipped.value, UInt64(48))

    assert_equal(raw.data_source_seek_to_pcm_frame(lib, ds, UInt64(0)), MA_SUCCESS)

    var secs = raw.data_source_seek_seconds(lib, ds, Float32(0.001))
    assert_equal(secs.result, MA_SUCCESS)
    assert_true(secs.value > Float32(0))

    assert_equal(
        raw.data_source_seek_to_second(lib, ds, Float32(0.005)), MA_SUCCESS
    )
    var cursor = raw.data_source_get_cursor_in_pcm_frames(lib, ds)
    assert_equal(cursor.result, MA_SUCCESS)
    assert_equal(cursor.value, UInt64(240))  # 0.005 s * 48000

    raw.data_source_free(lib, ds)


def test_format_and_length_queries() raises:
    """get_data_format / length+cursor in frames and seconds."""
    var lib = _lib()
    var ds = _make(lib)

    var fmt = raw.data_source_get_data_format(lib, ds)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_equal(fmt.format, FMT_F32)
    assert_equal(fmt.channels, CHANNELS)
    assert_equal(fmt.sample_rate, SAMPLE_RATE)

    var length = raw.data_source_get_length_in_pcm_frames(lib, ds)
    assert_equal(length.result, MA_SUCCESS)
    assert_equal(length.value, FRAMES)

    var length_s = raw.data_source_get_length_in_seconds(lib, ds)
    assert_equal(length_s.result, MA_SUCCESS)
    assert_true(length_s.value > Float32(0.009))
    assert_true(length_s.value < Float32(0.011))

    assert_equal(raw.data_source_seek_to_pcm_frame(lib, ds, UInt64(240)), MA_SUCCESS)
    var cursor_s = raw.data_source_get_cursor_in_seconds(lib, ds)
    assert_equal(cursor_s.result, MA_SUCCESS)
    assert_true(cursor_s.value > Float32(0.004))
    assert_true(cursor_s.value < Float32(0.006))

    raw.data_source_free(lib, ds)


def test_looping_roundtrip() raises:
    """set_looping / is_looping round-trip."""
    var lib = _lib()
    var ds = _make(lib)

    assert_false(raw.data_source_is_looping(lib, ds))
    assert_equal(raw.data_source_set_looping(lib, ds, True), MA_SUCCESS)
    assert_true(raw.data_source_is_looping(lib, ds))
    assert_equal(raw.data_source_set_looping(lib, ds, False), MA_SUCCESS)
    assert_false(raw.data_source_is_looping(lib, ds))

    raw.data_source_free(lib, ds)


def test_range_and_loop_point_roundtrip() raises:
    """set/get range and loop point in PCM frames."""
    var lib = _lib()
    var ds = _make(lib)

    # Defaults: full range, default loop point (both "unbounded" sentinels).
    var default_range = raw.data_source_get_range_in_pcm_frames(lib, ds)
    assert_equal(default_range.result, MA_SUCCESS)
    assert_equal(default_range.beg, UInt64(0))

    assert_equal(
        raw.data_source_set_range_in_pcm_frames(lib, ds, UInt64(10), UInt64(100)),
        MA_SUCCESS,
    )
    var got_range = raw.data_source_get_range_in_pcm_frames(lib, ds)
    assert_equal(got_range.result, MA_SUCCESS)
    assert_equal(got_range.beg, UInt64(10))
    assert_equal(got_range.end, UInt64(100))

    assert_equal(
        raw.data_source_set_loop_point_in_pcm_frames(lib, ds, UInt64(5), UInt64(50)),
        MA_SUCCESS,
    )
    var loop = raw.data_source_get_loop_point_in_pcm_frames(lib, ds)
    assert_equal(loop.result, MA_SUCCESS)
    assert_equal(loop.beg, UInt64(5))
    assert_equal(loop.end, UInt64(50))

    raw.data_source_free(lib, ds)


def test_chaining_current_and_next() raises:
    """set_current/get_current and set_next/get_next identity round-trips."""
    var lib = _lib()
    var first = _make(lib)
    var second = _make(lib)

    # A fresh source reads from itself and has no next.
    var self_current = raw.data_source_current_is(lib, first, first)
    assert_equal(self_current.result, MA_SUCCESS)
    assert_true(self_current.value)

    var no_next = raw.data_source_next_is(lib, first, null_handle())
    assert_equal(no_next.result, MA_SUCCESS)
    assert_true(no_next.value)

    assert_equal(raw.data_source_set_next(lib, first, second), MA_SUCCESS)
    var chained = raw.data_source_next_is(lib, first, second)
    assert_equal(chained.result, MA_SUCCESS)
    assert_true(chained.value)

    assert_equal(raw.data_source_set_current(lib, first, second), MA_SUCCESS)
    var current_second = raw.data_source_current_is(lib, first, second)
    assert_equal(current_second.result, MA_SUCCESS)
    assert_true(current_second.value)

    # Clearing the chain restores the null next.
    assert_equal(raw.data_source_set_next(lib, first, null_handle()), MA_SUCCESS)
    var cleared = raw.data_source_next_is(lib, first, null_handle())
    assert_true(cleared.value)

    raw.data_source_free(lib, second)
    raw.data_source_free(lib, first)


def test_next_callback_roundtrip() raises:
    """set_next_callback installs the shim callback; get_next_callback sees it."""
    var lib = _lib()
    var first = _make(lib)
    var second = _make(lib)

    var none_yet = raw.data_source_has_next_callback(lib, first)
    assert_equal(none_yet.result, MA_SUCCESS)
    assert_false(none_yet.value)

    assert_equal(
        raw.data_source_set_next_callback(lib, first, second), MA_SUCCESS
    )
    var installed = raw.data_source_has_next_callback(lib, first)
    assert_equal(installed.result, MA_SUCCESS)
    assert_true(installed.value)

    assert_equal(
        raw.data_source_set_next_callback(lib, first, null_handle()), MA_SUCCESS
    )
    var cleared = raw.data_source_has_next_callback(lib, first)
    assert_equal(cleared.result, MA_SUCCESS)
    assert_false(cleared.value)

    raw.data_source_free(lib, second)
    raw.data_source_free(lib, first)


def test_node_lifecycle() raises:
    """data_source_node init/looping/uninit against an engine node graph."""
    var lib = _lib()
    var eng = eraw.engine_alloc(lib)
    assert_equal(eraw.engine_init(lib, eng, True), MA_SUCCESS)
    var ds = _make(lib)

    var node = raw.data_source_node_alloc(lib)
    assert_true(node != null_handle())
    assert_equal(raw.data_source_node_init(lib, node, eng, ds), MA_SUCCESS)

    assert_equal(raw.data_source_node_set_looping(lib, node, True), MA_SUCCESS)
    assert_true(raw.data_source_node_is_looping(lib, node))
    assert_equal(raw.data_source_node_set_looping(lib, node, False), MA_SUCCESS)
    assert_false(raw.data_source_node_is_looping(lib, node))

    assert_equal(raw.data_source_node_uninit(lib, node), MA_SUCCESS)
    raw.data_source_node_free(lib, node)
    raw.data_source_free(lib, ds)
    eraw.engine_free(lib, eng)


def test_read_to_end_reports_at_end() raises:
    """Over-long read succeeds short; only a read at the end is MA_AT_END.

    miniaudio reports MA_SUCCESS whenever at least one frame was produced, so
    exhaustion surfaces on the *following* read, not the partial one.
    """
    var lib = _lib()
    var ds = _make(lib)

    var out = List[Float32]()
    out.resize(Int(FRAMES + 32) * Int(CHANNELS), Float32(0))
    var partial = raw.data_source_read_pcm_frames(lib, ds, out, FRAMES + 32)
    assert_equal(partial.result, MA_SUCCESS)
    assert_equal(partial.value, FRAMES)

    var at_end = raw.data_source_read_pcm_frames(lib, ds, out, FRAMES)
    assert_equal(at_end.result, MA_AT_END)
    assert_equal(at_end.value, UInt64(0))

    raw.data_source_free(lib, ds)


def test_reinit_same_handle() raises:
    """Re-initialising an initialised handle resets state cleanly."""
    var lib = _lib()
    var ds = _make(lib)
    var frames = _samples()
    assert_equal(
        raw.data_source_init_buffer(lib, ds, frames, UInt64(120), 1, 44100),
        MA_SUCCESS,
    )
    var fmt = raw.data_source_get_data_format(lib, ds)
    assert_equal(fmt.channels, UInt32(1))
    assert_equal(fmt.sample_rate, UInt32(44100))
    raw.data_source_free(lib, ds)


# ---- negative paths ---------------------------------------------------------


def test_null_handle_ops_invalid_args() raises:
    """Every op on a null handle returns MA_INVALID_ARGS (or a False sentinel)."""
    var lib = _lib()
    var frames = _samples()
    var out = List[Float32]()
    out.resize(8, Float32(0))

    assert_equal(
        raw.data_source_init_buffer(
            lib, null_handle(), frames, FRAMES, CHANNELS, SAMPLE_RATE
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.data_source_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.data_source_read_pcm_frames(lib, null_handle(), out, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_seek_pcm_frames(lib, null_handle(), UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_seek_to_pcm_frame(lib, null_handle(), UInt64(0)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_seek_seconds(lib, null_handle(), Float32(1.0)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_seek_to_second(lib, null_handle(), Float32(1.0)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_data_format(lib, null_handle()).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.data_source_get_cursor_in_pcm_frames(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_length_in_pcm_frames(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_cursor_in_seconds(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_length_in_seconds(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_set_looping(lib, null_handle(), True), MA_INVALID_ARGS
    )
    assert_false(raw.data_source_is_looping(lib, null_handle()))
    assert_equal(
        raw.data_source_set_range_in_pcm_frames(
            lib, null_handle(), UInt64(0), UInt64(1)
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_range_in_pcm_frames(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_set_loop_point_in_pcm_frames(
            lib, null_handle(), UInt64(0), UInt64(1)
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_get_loop_point_in_pcm_frames(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_set_current(lib, null_handle(), null_handle()),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_current_is(lib, null_handle(), null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_set_next(lib, null_handle(), null_handle()), MA_INVALID_ARGS
    )
    assert_equal(
        raw.data_source_next_is(lib, null_handle(), null_handle()).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_set_next_callback(lib, null_handle(), null_handle()),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_has_next_callback(lib, null_handle()).result,
        MA_INVALID_ARGS,
    )


def test_node_null_handle_ops_invalid_args() raises:
    """data_source_node ops on a null handle return MA_INVALID_ARGS."""
    var lib = _lib()
    assert_equal(
        raw.data_source_node_init(lib, null_handle(), null_handle(), null_handle()),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.data_source_node_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.data_source_node_set_looping(lib, null_handle(), True), MA_INVALID_ARGS
    )
    assert_false(raw.data_source_node_is_looping(lib, null_handle()))
    raw.data_source_node_free(lib, null_handle())  # must not crash


def test_ops_before_init_invalid_args() raises:
    """Ops on an allocated-but-uninitialised handle return MA_INVALID_ARGS."""
    var lib = _lib()
    var ds = raw.data_source_alloc(lib)
    assert_true(ds != null_handle())

    assert_equal(
        raw.data_source_seek_to_pcm_frame(lib, ds, UInt64(0)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.data_source_get_length_in_pcm_frames(lib, ds).result, MA_INVALID_ARGS
    )
    assert_equal(raw.data_source_set_looping(lib, ds, True), MA_INVALID_ARGS)
    assert_false(raw.data_source_is_looping(lib, ds))
    assert_equal(
        raw.data_source_get_data_format(lib, ds).result, MA_INVALID_ARGS
    )

    raw.data_source_free(lib, ds)


def test_init_invalid_args() raises:
    """Zero frame count / zero channels / zero sample rate are rejected."""
    var lib = _lib()
    var ds = raw.data_source_alloc(lib)
    var frames = _samples()

    assert_equal(
        raw.data_source_init_buffer(lib, ds, frames, UInt64(0), CHANNELS, SAMPLE_RATE),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_init_buffer(lib, ds, frames, FRAMES, 0, SAMPLE_RATE),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_source_init_buffer(lib, ds, frames, FRAMES, CHANNELS, 0),
        MA_INVALID_ARGS,
    )

    raw.data_source_free(lib, ds)


def test_invalid_range_rejected() raises:
    """A range whose end precedes its beginning is rejected."""
    var lib = _lib()
    var ds = _make(lib)
    assert_equal(
        raw.data_source_set_range_in_pcm_frames(lib, ds, UInt64(100), UInt64(10)),
        MA_INVALID_ARGS,
    )
    raw.data_source_free(lib, ds)


def test_uninit_uninitialized_is_success() raises:
    """uninit on an allocated-but-uninitialised handle is a no-op success."""
    var lib = _lib()
    var ds = raw.data_source_alloc(lib)
    assert_equal(raw.data_source_uninit(lib, ds), MA_SUCCESS)
    raw.data_source_free(lib, ds)


def test_free_null_handle_is_noop() raises:
    """free(null) must not crash."""
    var lib = _lib()
    raw.data_source_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
