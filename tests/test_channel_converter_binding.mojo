"""TDD contract tests for the channel converter BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: the channel converter is a pure DSP
object, so no device, engine, or file is involved. All 8 MA_API channel
converter functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.converter_raw as raw


comptime FMT_F32: Int = 5
comptime RECTANGULAR: Int = 0
comptime SIMPLE: Int = 1


def _lib() raises -> MaLib:
    return MaLib.default()


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _stereo(pairs: Int) -> List[Float32]:
    """Interleaved stereo where the right channel is the left plus one."""
    var out = List[Float32](capacity=pairs * 2)
    for i in range(pairs):
        out.append(Float32(i))
        out.append(Float32(i + 1))
    return out^


def test_heap_size_is_reported_without_initialising() raises:
    """The get_heap_size call answers from the config alone."""
    var lib = _lib()
    var rc = raw.channel_converter_get_heap_size(
        lib, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR
    )
    assert_equal(rc.result, MA_SUCCESS)


def test_stereo_to_mono_averages_the_channels() raises:
    """Rectangular mixing folds a stereo pair into their average."""
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_true(cc != null_handle())
    assert_equal(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR),
        MA_SUCCESS,
    )

    var src = _stereo(4)
    var dst = _sink(4)
    assert_equal(
        raw.channel_converter_process(lib, cc, dst, src, UInt64(4)), MA_SUCCESS
    )
    for i in range(4):
        assert_almost_equal(dst[i], Float32(i) + Float32(0.5), atol=0.001)

    raw.channel_converter_free(lib, cc)


def test_mono_to_stereo_fills_both_channels() raises:
    """A mono source reaches both output channels."""
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_equal(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(1), UInt32(2), RECTANGULAR),
        MA_SUCCESS,
    )

    var src = List[Float32]()
    for i in range(4):
        src.append(Float32(i + 1))
    var dst = _sink(8)
    assert_equal(
        raw.channel_converter_process(lib, cc, dst, src, UInt64(4)), MA_SUCCESS
    )
    for i in range(4):
        assert_true(dst[i * 2] != Float32(0))
        assert_equal(dst[i * 2], dst[i * 2 + 1])

    raw.channel_converter_free(lib, cc)


def test_channel_maps_are_readable_on_both_sides() raises:
    """The input and output channel maps come back sized to their channel counts."""
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_equal(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR),
        MA_SUCCESS,
    )

    var in_map = raw.channel_converter_get_input_channel_map(lib, cc, UInt32(2))
    assert_equal(in_map.result, MA_SUCCESS)
    assert_equal(len(in_map.value), 2)
    # A stereo map is two distinct channel positions.
    assert_true(in_map.value[0] != in_map.value[1])

    var out_map = raw.channel_converter_get_output_channel_map(lib, cc, UInt32(1))
    assert_equal(out_map.result, MA_SUCCESS)
    assert_equal(len(out_map.value), 1)

    raw.channel_converter_free(lib, cc)


def test_simple_mix_mode_keeps_leading_channels_and_zeroes_the_rest() raises:
    """Simple mixing copies the channels it has and zero-fills the extra ones.

    Widening rather than narrowing, because a mono *output* takes miniaudio's
    averaging fast path whatever the mix mode says — see the test below.
    """
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_equal(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(4), SIMPLE),
        MA_SUCCESS,
    )

    var src = _stereo(3)
    var dst = _sink(12)
    assert_equal(
        raw.channel_converter_process(lib, cc, dst, src, UInt64(3)), MA_SUCCESS
    )
    for i in range(3):
        assert_almost_equal(dst[i * 4], Float32(i), atol=0.001)
        assert_almost_equal(dst[i * 4 + 1], Float32(i + 1), atol=0.001)
        assert_almost_equal(dst[i * 4 + 2], Float32(0), atol=0.001)
        assert_almost_equal(dst[i * 4 + 3], Float32(0), atol=0.001)

    raw.channel_converter_free(lib, cc)


def test_mono_output_averages_whatever_the_mix_mode() raises:
    """A mono output takes miniaudio's averaging path even in simple mode.

    Pins the behaviour: the mix mode selects between conversion paths, but
    ma_channel_converter has a dedicated mono-out path that always averages.
    """
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_equal(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(1), SIMPLE),
        MA_SUCCESS,
    )

    var src = _stereo(4)
    var dst = _sink(4)
    assert_equal(
        raw.channel_converter_process(lib, cc, dst, src, UInt64(4)), MA_SUCCESS
    )
    for i in range(4):
        assert_almost_equal(dst[i], Float32(i) + Float32(0.5), atol=0.001)

    raw.channel_converter_free(lib, cc)


def test_preallocated_init_matches_the_managed_one() raises:
    """The shim-owned-heap path converts identically to the miniaudio-owned one."""
    var lib = _lib()
    var managed = raw.channel_converter_alloc(lib)
    var prealloc = raw.channel_converter_alloc(lib)
    assert_equal(
        raw.channel_converter_init(lib, managed, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR),
        MA_SUCCESS,
    )
    assert_equal(
        raw.channel_converter_init_preallocated(
            lib, prealloc, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR
        ),
        MA_SUCCESS,
    )

    var src = _stereo(4)
    var a = _sink(4)
    var b = _sink(4)
    _ = raw.channel_converter_process(lib, managed, a, src, UInt64(4))
    _ = raw.channel_converter_process(lib, prealloc, b, src, UInt64(4))
    for i in range(4):
        assert_equal(a[i], b[i])

    raw.channel_converter_free(lib, managed)
    raw.channel_converter_free(lib, prealloc)


def test_init_rejects_a_zero_channel_count() raises:
    """A converter with no channels on either side is rejected.

    Note that an *unknown format* is not rejected here — the channel converter
    validates channel counts, not the sample format.
    """
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    assert_true(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(0), UInt32(1), RECTANGULAR)
        != MA_SUCCESS
    )
    assert_true(
        raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(0), RECTANGULAR)
        != MA_SUCCESS
    )
    raw.channel_converter_free(lib, cc)


def test_operations_on_an_uninitialised_handle_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    var src = _stereo(2)
    var dst = _sink(2)

    assert_equal(
        raw.channel_converter_process(lib, cc, dst, src, UInt64(2)), MA_INVALID_ARGS
    )
    assert_equal(
        raw.channel_converter_get_input_channel_map(lib, cc, UInt32(2)).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.channel_converter_get_output_channel_map(lib, cc, UInt32(1)).result,
        MA_INVALID_ARGS,
    )

    raw.channel_converter_free(lib, cc)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var cc = raw.channel_converter_alloc(lib)
    _ = raw.channel_converter_init(lib, cc, FMT_F32, UInt32(2), UInt32(1), RECTANGULAR)

    assert_equal(raw.channel_converter_uninit(lib, cc), MA_SUCCESS)
    assert_equal(raw.channel_converter_uninit(lib, cc), MA_SUCCESS)
    raw.channel_converter_free(lib, cc)

    assert_equal(raw.channel_converter_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.channel_converter_init(
            lib, null_handle(), FMT_F32, UInt32(2), UInt32(1), RECTANGULAR
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.channel_converter_init_preallocated(
            lib, null_handle(), FMT_F32, UInt32(2), UInt32(1), RECTANGULAR
        ),
        MA_INVALID_ARGS,
    )
    raw.channel_converter_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
