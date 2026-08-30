"""TDD contract tests for the resampler BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the resampler is a pure DSP object, so
no device, engine, or file is involved. All 13 MA_API resampler functions are
exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.converter_raw as raw


comptime FMT_F32: Int = 5
comptime FMT_UNKNOWN: Int = 0
comptime LINEAR: Int = 0
comptime MONO: UInt32 = 1
comptime RATE_IN: UInt32 = 48000
comptime RATE_OUT: UInt32 = 24000


def _lib() raises -> MaLib:
    return MaLib.default()


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i))
    return out^


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _ready(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var rs = raw.resampler_alloc(lib)
    assert_equal(
        raw.resampler_init(lib, rs, FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR),
        MA_SUCCESS,
    )
    return rs


def test_heap_size_is_reported_without_initialising() raises:
    """The get_heap_size call answers from the config alone."""
    var lib = _lib()
    var rc = raw.resampler_get_heap_size(lib, FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_process_produces_the_expected_output_frame_count() raises:
    """The frames process yields match what get_expected_output_frame_count says."""
    var lib = _lib()
    var rs = _ready(lib)

    var expected = raw.resampler_get_expected_output_frame_count(lib, rs, UInt64(16))
    assert_equal(expected.result, MA_SUCCESS)

    var src = _ramp(16)
    var dst = _sink(32)
    var rc = raw.resampler_process(lib, rs, src, UInt64(16), dst, UInt64(32))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.frames_in, UInt64(16))
    assert_equal(rc.frames_out, expected.value)

    raw.resampler_free(lib, rs)


def test_required_input_matches_expected_output() raises:
    """The two frame-count estimators are consistent with the 2:1 ratio."""
    var lib = _lib()
    var rs = _ready(lib)

    var required = raw.resampler_get_required_input_frame_count(lib, rs, UInt64(10))
    assert_equal(required.result, MA_SUCCESS)
    assert_true(required.value >= UInt64(19) and required.value <= UInt64(21))

    var expected = raw.resampler_get_expected_output_frame_count(lib, rs, UInt64(20))
    assert_equal(expected.result, MA_SUCCESS)
    assert_true(expected.value >= UInt64(9) and expected.value <= UInt64(11))

    raw.resampler_free(lib, rs)


def test_latency_is_reported_on_both_sides() raises:
    """Input and output latency are queryable on a live resampler."""
    var lib = _lib()
    var rs = _ready(lib)

    var in_latency = raw.resampler_get_input_latency(lib, rs)
    assert_equal(in_latency.result, MA_SUCCESS)
    var out_latency = raw.resampler_get_output_latency(lib, rs)
    assert_equal(out_latency.result, MA_SUCCESS)

    raw.resampler_free(lib, rs)


def test_set_rate_and_ratio_change_the_conversion() raises:
    """Both rate setters retarget the resampler; the estimators follow."""
    var lib = _lib()
    var rs = _ready(lib)

    assert_equal(raw.resampler_set_rate(lib, rs, UInt32(48000), UInt32(48000)), MA_SUCCESS)
    var same = raw.resampler_get_expected_output_frame_count(lib, rs, UInt64(20))
    assert_true(same.value >= UInt64(19) and same.value <= UInt64(21))

    # miniaudio's ratio is input-over-output, so 2.0 means "halve the rate".
    assert_equal(raw.resampler_set_rate_ratio(lib, rs, Float32(2.0)), MA_SUCCESS)
    var halved = raw.resampler_get_expected_output_frame_count(lib, rs, UInt64(20))
    assert_true(halved.value >= UInt64(9) and halved.value <= UInt64(11))

    assert_equal(raw.resampler_set_rate_ratio(lib, rs, Float32(0.0)), MA_INVALID_ARGS)

    raw.resampler_free(lib, rs)


def test_reset_clears_the_filter_state() raises:
    """Reset returns the resampler to its initial state."""
    var lib = _lib()
    var rs = _ready(lib)

    var src = _ramp(16)
    var dst = _sink(32)
    _ = raw.resampler_process(lib, rs, src, UInt64(16), dst, UInt64(32))
    assert_equal(raw.resampler_reset(lib, rs), MA_SUCCESS)

    var after = _sink(32)
    var rc = raw.resampler_process(lib, rs, src, UInt64(16), after, UInt64(32))
    assert_equal(rc.result, MA_SUCCESS)
    for i in range(Int(rc.frames_out)):
        assert_equal(after[i], dst[i])

    raw.resampler_free(lib, rs)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path converts identically to the miniaudio-owned one."""
    var lib = _lib()
    var managed = _ready(lib)
    var prealloc = raw.resampler_alloc(lib)
    assert_equal(
        raw.resampler_init_preallocated(
            lib, prealloc, FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR
        ),
        MA_SUCCESS,
    )

    var src = _ramp(16)
    var a = _sink(32)
    var b = _sink(32)
    var ra = raw.resampler_process(lib, managed, src, UInt64(16), a, UInt64(32))
    var rb = raw.resampler_process(lib, prealloc, src, UInt64(16), b, UInt64(32))
    assert_equal(ra.frames_out, rb.frames_out)
    for i in range(Int(ra.frames_out)):
        assert_equal(a[i], b[i])

    raw.resampler_free(lib, managed)
    raw.resampler_free(lib, prealloc)


def test_init_rejects_an_unknown_format() raises:
    """A format the resampler cannot handle is rejected."""
    var lib = _lib()
    var rs = raw.resampler_alloc(lib)
    assert_true(rs != null_handle())
    assert_true(
        raw.resampler_init(lib, rs, FMT_UNKNOWN, MONO, RATE_IN, RATE_OUT, LINEAR)
        != MA_SUCCESS
    )
    raw.resampler_free(lib, rs)


def test_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var rs = raw.resampler_alloc(lib)
    var src = _ramp(4)
    var dst = _sink(4)

    assert_equal(
        raw.resampler_process(lib, rs, src, UInt64(4), dst, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.resampler_set_rate(lib, rs, RATE_IN, RATE_OUT), MA_INVALID_ARGS)
    assert_equal(raw.resampler_set_rate_ratio(lib, rs, Float32(1.0)), MA_INVALID_ARGS)
    assert_equal(raw.resampler_get_input_latency(lib, rs).result, MA_INVALID_ARGS)
    assert_equal(raw.resampler_get_output_latency(lib, rs).result, MA_INVALID_ARGS)
    assert_equal(
        raw.resampler_get_required_input_frame_count(lib, rs, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.resampler_get_expected_output_frame_count(lib, rs, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.resampler_reset(lib, rs), MA_INVALID_ARGS)

    raw.resampler_free(lib, rs)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var rs = _ready(lib)
    assert_equal(raw.resampler_uninit(lib, rs), MA_SUCCESS)
    assert_equal(raw.resampler_uninit(lib, rs), MA_SUCCESS)
    raw.resampler_free(lib, rs)

    assert_equal(raw.resampler_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.resampler_init(lib, null_handle(), FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.resampler_init_preallocated(
            lib, null_handle(), FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR
        ),
        MA_INVALID_ARGS,
    )
    raw.resampler_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
