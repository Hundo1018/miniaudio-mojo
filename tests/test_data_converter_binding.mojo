"""TDD contract tests for the data converter BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the data converter is a pure DSP
pipeline, so no device, engine, or file is involved. All 16 MA_API data
converter functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.converter_raw as raw


comptime FMT_F32: Int = 5
comptime MONO: UInt32 = 1
comptime STEREO: UInt32 = 2
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


def _resampling(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A mono 48k -> 24k converter, so a resampler is present in the pipeline."""
    var dc = raw.data_converter_alloc(lib)
    assert_equal(
        raw.data_converter_init(
            lib, dc, FMT_F32, FMT_F32, MONO, MONO, RATE_IN, RATE_OUT
        ),
        MA_SUCCESS,
    )
    return dc


def test_heap_size_is_reported_without_initialising() raises:
    """The get_heap_size call answers from the config alone."""
    var lib = _lib()
    var rc = raw.data_converter_get_heap_size(
        lib, FMT_F32, FMT_F32, MONO, MONO, RATE_IN, RATE_OUT
    )
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_process_produces_the_expected_output_frame_count() raises:
    """The frames process yields match what get_expected_output_frame_count says."""
    var lib = _lib()
    var dc = _resampling(lib)

    var expected = raw.data_converter_get_expected_output_frame_count(lib, dc, UInt64(16))
    assert_equal(expected.result, MA_SUCCESS)

    var src = _ramp(16)
    var dst = _sink(32)
    var rc = raw.data_converter_process(lib, dc, src, UInt64(16), dst, UInt64(32))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.frames_in, UInt64(16))
    assert_equal(rc.frames_out, expected.value)

    raw.data_converter_free(lib, dc)


def test_default_config_gives_a_pass_through_converter() raises:
    """Built from miniaudio's defaults, frames come out unchanged."""
    var lib = _lib()
    var dc = raw.data_converter_alloc(lib)
    assert_equal(
        raw.data_converter_init_default(lib, dc, FMT_F32, MONO, UInt32(48000)),
        MA_SUCCESS,
    )

    var src = _ramp(8)
    var dst = _sink(8)
    var rc = raw.data_converter_process(lib, dc, src, UInt64(8), dst, UInt64(8))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.frames_in, UInt64(8))
    assert_equal(rc.frames_out, UInt64(8))
    for i in range(8):
        assert_almost_equal(dst[i], src[i], atol=0.001)

    raw.data_converter_free(lib, dc)


def test_channel_conversion_runs_in_the_same_pipeline() raises:
    """A mono source widened to stereo fills both output channels."""
    var lib = _lib()
    var dc = raw.data_converter_alloc(lib)
    assert_equal(
        raw.data_converter_init(
            lib, dc, FMT_F32, FMT_F32, MONO, STEREO, UInt32(48000), UInt32(48000)
        ),
        MA_SUCCESS,
    )

    var src = _ramp(4)
    var dst = _sink(8)
    var rc = raw.data_converter_process(lib, dc, src, UInt64(4), dst, UInt64(4))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.frames_out, UInt64(4))
    for i in range(4):
        assert_equal(dst[i * 2], dst[i * 2 + 1])

    raw.data_converter_free(lib, dc)


def test_required_input_and_latency_are_queryable() raises:
    """The estimators and both latencies answer on a live converter."""
    var lib = _lib()
    var dc = _resampling(lib)

    var required = raw.data_converter_get_required_input_frame_count(lib, dc, UInt64(10))
    assert_equal(required.result, MA_SUCCESS)
    assert_true(required.value >= UInt64(19) and required.value <= UInt64(21))

    assert_equal(raw.data_converter_get_input_latency(lib, dc).result, MA_SUCCESS)
    assert_equal(raw.data_converter_get_output_latency(lib, dc).result, MA_SUCCESS)

    raw.data_converter_free(lib, dc)


def test_rate_setters_retarget_the_pipeline() raises:
    """Both rate setters work once the pipeline contains a resampler."""
    var lib = _lib()
    var dc = _resampling(lib)

    assert_equal(
        raw.data_converter_set_rate(lib, dc, UInt32(48000), UInt32(48000)), MA_SUCCESS
    )
    var same = raw.data_converter_get_expected_output_frame_count(lib, dc, UInt64(20))
    assert_true(same.value >= UInt64(19) and same.value <= UInt64(21))

    # miniaudio's ratio is input-over-output, so 2.0 means "halve the rate".
    assert_equal(raw.data_converter_set_rate_ratio(lib, dc, Float32(2.0)), MA_SUCCESS)
    var halved = raw.data_converter_get_expected_output_frame_count(lib, dc, UInt64(20))
    assert_true(halved.value >= UInt64(9) and halved.value <= UInt64(11))

    raw.data_converter_free(lib, dc)


def test_reset_succeeds_but_does_not_restore_the_cold_filter_state() raises:
    """Pins an upstream limitation of ma_data_converter_reset in miniaudio 0.11.25.

    A freshly built converter and a reset one are *not* equivalent: the cold
    pipeline low-passes the first frames (0, 0.7921, 2.7399, ...) while the same
    converter after a reset returns the unfiltered linear interpolation
    (0, 1.0, 3.0, ...). Confirmed against raw miniaudio with a standalone C
    probe, so it is not a shim artifact. The bare ma_resampler does not show
    this — its reset reproduces a cold run exactly (see the resampler tests).

    Rebuild the converter rather than resetting it when bit-identical restarts
    matter. If a future miniaudio fixes this, the divergence assertion below
    fails and this note should go away.
    """
    var lib = _lib()
    var dc = _resampling(lib)

    var src = _ramp(16)
    var first = _sink(32)
    var rc1 = raw.data_converter_process(lib, dc, src, UInt64(16), first, UInt64(32))
    assert_equal(raw.data_converter_reset(lib, dc), MA_SUCCESS)

    var second = _sink(32)
    var rc2 = raw.data_converter_process(lib, dc, src, UInt64(16), second, UInt64(32))
    assert_equal(rc2.frames_out, rc1.frames_out)
    assert_true(second[1] != first[1])

    # A brand new converter *does* reproduce the cold run exactly.
    var fresh = _resampling(lib)
    var third = _sink(32)
    var rc3 = raw.data_converter_process(lib, fresh, src, UInt64(16), third, UInt64(32))
    assert_equal(rc3.frames_out, rc1.frames_out)
    for i in range(Int(rc1.frames_out)):
        assert_equal(third[i], first[i])

    raw.data_converter_free(lib, fresh)
    raw.data_converter_free(lib, dc)


def test_channel_maps_are_readable_on_both_sides() raises:
    """The input and output channel maps come back sized to their channel counts."""
    var lib = _lib()
    var dc = raw.data_converter_alloc(lib)
    assert_equal(
        raw.data_converter_init(
            lib, dc, FMT_F32, FMT_F32, STEREO, MONO, UInt32(48000), UInt32(48000)
        ),
        MA_SUCCESS,
    )

    var in_map = raw.data_converter_get_input_channel_map(lib, dc, STEREO)
    assert_equal(in_map.result, MA_SUCCESS)
    assert_equal(len(in_map.value), 2)
    assert_true(in_map.value[0] != in_map.value[1])

    var out_map = raw.data_converter_get_output_channel_map(lib, dc, MONO)
    assert_equal(out_map.result, MA_SUCCESS)
    assert_equal(len(out_map.value), 1)

    raw.data_converter_free(lib, dc)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path converts identically to the miniaudio-owned one."""
    var lib = _lib()
    var managed = _resampling(lib)
    var prealloc = raw.data_converter_alloc(lib)
    assert_equal(
        raw.data_converter_init_preallocated(
            lib, prealloc, FMT_F32, FMT_F32, MONO, MONO, RATE_IN, RATE_OUT
        ),
        MA_SUCCESS,
    )

    var src = _ramp(16)
    var a = _sink(32)
    var b = _sink(32)
    var ra = raw.data_converter_process(lib, managed, src, UInt64(16), a, UInt64(32))
    var rb = raw.data_converter_process(lib, prealloc, src, UInt64(16), b, UInt64(32))
    assert_equal(ra.frames_out, rb.frames_out)
    for i in range(Int(ra.frames_out)):
        assert_equal(a[i], b[i])

    raw.data_converter_free(lib, managed)
    raw.data_converter_free(lib, prealloc)


def test_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var dc = raw.data_converter_alloc(lib)
    var src = _ramp(4)
    var dst = _sink(4)

    assert_equal(
        raw.data_converter_process(lib, dc, src, UInt64(4), dst, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(raw.data_converter_set_rate(lib, dc, RATE_IN, RATE_OUT), MA_INVALID_ARGS)
    assert_equal(raw.data_converter_set_rate_ratio(lib, dc, Float32(1.0)), MA_INVALID_ARGS)
    assert_equal(raw.data_converter_get_input_latency(lib, dc).result, MA_INVALID_ARGS)
    assert_equal(raw.data_converter_get_output_latency(lib, dc).result, MA_INVALID_ARGS)
    assert_equal(
        raw.data_converter_get_required_input_frame_count(lib, dc, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_converter_get_expected_output_frame_count(lib, dc, UInt64(4)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_converter_get_input_channel_map(lib, dc, MONO).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.data_converter_get_output_channel_map(lib, dc, MONO).result, MA_INVALID_ARGS
    )
    assert_equal(raw.data_converter_reset(lib, dc), MA_INVALID_ARGS)

    raw.data_converter_free(lib, dc)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var dc = _resampling(lib)
    assert_equal(raw.data_converter_uninit(lib, dc), MA_SUCCESS)
    assert_equal(raw.data_converter_uninit(lib, dc), MA_SUCCESS)
    raw.data_converter_free(lib, dc)

    assert_equal(raw.data_converter_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.data_converter_init(
            lib, null_handle(), FMT_F32, FMT_F32, MONO, MONO, RATE_IN, RATE_OUT
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_converter_init_default(lib, null_handle(), FMT_F32, MONO, RATE_IN),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.data_converter_init_preallocated(
            lib, null_handle(), FMT_F32, FMT_F32, MONO, MONO, RATE_IN, RATE_OUT
        ),
        MA_INVALID_ARGS,
    )
    raw.data_converter_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
