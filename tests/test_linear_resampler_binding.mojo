"""TDD contract tests for the linear resampler BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a pure DSP object. All 13 MA_API
ma_linear_resampler functions are exercised here (positive and negative paths).

This is the algorithm ma_resampler drives underneath when set to linear, so the
two are compared directly below — at the same rates they must agree frame for
frame.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.converter_raw as raw


comptime FMT_F32: Int = 5
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
    var rs = raw.linear_resampler_alloc(lib)
    assert_true(rs != null_handle())
    assert_equal(
        raw.linear_resampler_init(lib, rs, FMT_F32, MONO, RATE_IN, RATE_OUT),
        MA_SUCCESS,
    )
    return rs


def test_heap_size_is_reported_without_initialising() raises:
    """The get_heap_size call answers from the config alone."""
    var lib = _lib()
    var rc = raw.linear_resampler_get_heap_size(lib, FMT_F32, MONO, RATE_IN, RATE_OUT)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_process_produces_the_expected_output_frame_count() raises:
    """The frames process yields match what get_expected_output_frame_count says."""
    var lib = _lib()
    var rs = _ready(lib)

    var expected = raw.linear_resampler_get_expected_output_frame_count(
        lib, rs, UInt64(16)
    )
    assert_equal(expected.result, MA_SUCCESS)

    var dst = _sink(32)
    var rc = raw.linear_resampler_process(lib, rs, _ramp(16), UInt64(16), dst, UInt64(32))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.frames_in, UInt64(16))
    assert_equal(rc.frames_out, expected.value)

    raw.linear_resampler_free(lib, rs)


def test_it_matches_the_resampler_driving_the_same_algorithm() raises:
    """Both ma_resampler on linear and ma_linear_resampler produce the same frames."""
    var lib = _lib()
    var direct = _ready(lib)
    var wrapped = raw.resampler_alloc(lib)
    assert_equal(
        raw.resampler_init(lib, wrapped, FMT_F32, MONO, RATE_IN, RATE_OUT, LINEAR),
        MA_SUCCESS,
    )

    var a = _sink(32)
    var b = _sink(32)
    var ra = raw.linear_resampler_process(lib, direct, _ramp(16), UInt64(16), a, UInt64(32))
    var rb = raw.resampler_process(lib, wrapped, _ramp(16), UInt64(16), b, UInt64(32))
    assert_equal(ra.frames_out, rb.frames_out)
    for i in range(Int(ra.frames_out)):
        assert_equal(a[i], b[i])

    raw.linear_resampler_free(lib, direct)
    raw.resampler_free(lib, wrapped)


def test_required_input_and_latency_are_queryable() raises:
    """The estimators bracket the 2:1 ratio and both latencies answer."""
    var lib = _lib()
    var rs = _ready(lib)

    var required = raw.linear_resampler_get_required_input_frame_count(lib, rs, UInt64(10))
    assert_equal(required.result, MA_SUCCESS)
    assert_true(required.value >= UInt64(19) and required.value <= UInt64(21))

    assert_equal(raw.linear_resampler_get_input_latency(lib, rs).result, MA_SUCCESS)
    assert_equal(raw.linear_resampler_get_output_latency(lib, rs).result, MA_SUCCESS)

    raw.linear_resampler_free(lib, rs)


def test_both_rate_setters_retarget_the_conversion() raises:
    """Both set_rate and set_rate_ratio move the same underlying ratio."""
    var lib = _lib()
    var rs = _ready(lib)

    assert_equal(
        raw.linear_resampler_set_rate(lib, rs, UInt32(48000), UInt32(48000)), MA_SUCCESS
    )
    var same = raw.linear_resampler_get_expected_output_frame_count(lib, rs, UInt64(20))
    assert_true(same.value >= UInt64(19) and same.value <= UInt64(21))

    # Input-over-output, so 2.0 halves the rate.
    assert_equal(raw.linear_resampler_set_rate_ratio(lib, rs, Float32(2.0)), MA_SUCCESS)
    var halved = raw.linear_resampler_get_expected_output_frame_count(lib, rs, UInt64(20))
    assert_true(halved.value >= UInt64(9) and halved.value <= UInt64(11))

    assert_equal(
        raw.linear_resampler_set_rate_ratio(lib, rs, Float32(0.0)), MA_INVALID_ARGS
    )

    raw.linear_resampler_free(lib, rs)


def test_reset_makes_a_repeat_run_identical() raises:
    """After reset the same input produces the same output."""
    var lib = _lib()
    var rs = _ready(lib)

    var first = _sink(32)
    var rc1 = raw.linear_resampler_process(lib, rs, _ramp(16), UInt64(16), first, UInt64(32))
    assert_equal(raw.linear_resampler_reset(lib, rs), MA_SUCCESS)

    var second = _sink(32)
    var rc2 = raw.linear_resampler_process(lib, rs, _ramp(16), UInt64(16), second, UInt64(32))
    assert_equal(rc2.frames_out, rc1.frames_out)
    for i in range(Int(rc1.frames_out)):
        assert_equal(second[i], first[i])

    raw.linear_resampler_free(lib, rs)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path converts identically to the miniaudio-owned one."""
    var lib = _lib()
    var managed = _ready(lib)
    var prealloc = raw.linear_resampler_alloc(lib)
    assert_equal(
        raw.linear_resampler_init_preallocated(
            lib, prealloc, FMT_F32, MONO, RATE_IN, RATE_OUT
        ),
        MA_SUCCESS,
    )

    var a = _sink(32)
    var b = _sink(32)
    var ra = raw.linear_resampler_process(lib, managed, _ramp(16), UInt64(16), a, UInt64(32))
    var rb = raw.linear_resampler_process(lib, prealloc, _ramp(16), UInt64(16), b, UInt64(32))
    assert_equal(ra.frames_out, rb.frames_out)
    for i in range(Int(ra.frames_out)):
        assert_equal(a[i], b[i])

    raw.linear_resampler_free(lib, managed)
    raw.linear_resampler_free(lib, prealloc)


def test_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var rs = raw.linear_resampler_alloc(lib)
    var dst = _sink(4)

    assert_equal(
        raw.linear_resampler_process(lib, rs, _ramp(4), UInt64(4), dst, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.linear_resampler_set_rate(lib, rs, RATE_IN, RATE_OUT), MA_INVALID_ARGS
    )
    assert_equal(
        raw.linear_resampler_set_rate_ratio(lib, rs, Float32(1.0)), MA_INVALID_ARGS
    )
    assert_equal(raw.linear_resampler_get_input_latency(lib, rs).result, MA_INVALID_ARGS)
    assert_equal(raw.linear_resampler_get_output_latency(lib, rs).result, MA_INVALID_ARGS)
    assert_equal(
        raw.linear_resampler_get_required_input_frame_count(lib, rs, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.linear_resampler_get_expected_output_frame_count(lib, rs, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.linear_resampler_reset(lib, rs), MA_INVALID_ARGS)
    assert_equal(raw.linear_resampler_uninit(lib, rs), MA_SUCCESS)

    raw.linear_resampler_free(lib, rs)
    assert_equal(raw.linear_resampler_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.linear_resampler_init(lib, null_handle(), FMT_F32, MONO, RATE_IN, RATE_OUT),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.linear_resampler_init_preallocated(
            lib, null_handle(), FMT_F32, MONO, RATE_IN, RATE_OUT
        ),
        MA_INVALID_ARGS,
    )
    raw.linear_resampler_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
