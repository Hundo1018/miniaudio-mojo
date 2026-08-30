"""TDD contract tests for the delay node BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: a standalone graph, fed by the shim's
offset node so the delay has something to work on. All 9 MA_API ma_delay_node
functions are exercised here (positive and negative paths).
"""

from std.testing import assert_equal, assert_true, assert_almost_equal, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.node_raw as raw


comptime STEREO: UInt32 = 2
comptime RATE: UInt32 = 48000
comptime FRAMES: UInt64 = 64


def _lib() raises -> MaLib:
    return MaLib.default()


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _graph(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var g = raw.node_graph_alloc(lib)
    assert_equal(raw.node_graph_init(lib, g, STEREO), MA_SUCCESS)
    return g


def _delay(
    lib: MaLib, g: OpaquePointer[MutUntrackedOrigin]
) raises -> OpaquePointer[MutUntrackedOrigin]:
    var d = raw.delay_node_alloc(lib)
    assert_equal(
        raw.delay_node_init(lib, d, g, STEREO, RATE, UInt32(16), Float32(0.5)),
        MA_SUCCESS,
    )
    return d


def test_a_delay_node_passes_its_dry_signal_through() raises:
    """Fed by the offset node, the delay delivers the input on the first frames."""
    var lib = _lib()
    var g = _graph(lib)
    var d = _delay(lib, g)
    var src = raw.node_alloc(lib)
    assert_equal(raw.node_init(lib, src, g, STEREO, Float32(0.25)), MA_SUCCESS)

    assert_equal(
        raw.node_attach_output_bus(lib, src, UInt32(0), d, UInt32(0)), MA_SUCCESS
    )
    assert_equal(raw.delay_node_attach_to_endpoint(lib, d, g), MA_SUCCESS)

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, FRAMES)
    # The first frames are dry only — the echo has not come back yet.
    assert_almost_equal(dst[0], Float32(0.25), atol=0.0001)

    raw.node_free(lib, src)
    raw.delay_node_free(lib, d)
    raw.node_graph_free(lib, g)


def test_wet_dry_and_decay_round_trip() raises:
    """Each mix control reads back what was written."""
    var lib = _lib()
    var g = _graph(lib)
    var d = _delay(lib, g)

    assert_equal(raw.delay_node_set_wet(lib, d, Float32(0.25)), MA_SUCCESS)
    var wet = raw.delay_node_get_wet(lib, d)
    assert_equal(wet.result, MA_SUCCESS)
    assert_almost_equal(wet.value, Float32(0.25), atol=0.0001)

    assert_equal(raw.delay_node_set_dry(lib, d, Float32(0.75)), MA_SUCCESS)
    assert_almost_equal(raw.delay_node_get_dry(lib, d).value, Float32(0.75), atol=0.0001)

    assert_equal(raw.delay_node_set_decay(lib, d, Float32(0.3)), MA_SUCCESS)
    assert_almost_equal(
        raw.delay_node_get_decay(lib, d).value, Float32(0.3), atol=0.0001
    )

    raw.delay_node_free(lib, d)
    raw.node_graph_free(lib, g)


def _through_delay(
    lib: MaLib, dry: Float32, wet: Float32
) raises -> List[Float32]:
    """A 0.4 signal pushed through a delay node with the given dry/wet."""
    var g = _graph(lib)
    var d = _delay(lib, g)
    var src = raw.node_alloc(lib)
    assert_equal(raw.node_init(lib, src, g, STEREO, Float32(0.4)), MA_SUCCESS)

    assert_equal(raw.delay_node_set_dry(lib, d, dry), MA_SUCCESS)
    assert_equal(raw.delay_node_set_wet(lib, d, wet), MA_SUCCESS)
    _ = raw.node_attach_output_bus(lib, src, UInt32(0), d, UInt32(0))
    _ = raw.delay_node_attach_to_endpoint(lib, d, g)

    var dst = _sink(Int(FRAMES) * 2)
    var rc = raw.node_graph_read(lib, g, dst, FRAMES)
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, FRAMES)

    raw.node_free(lib, src)
    raw.delay_node_free(lib, d)
    raw.node_graph_free(lib, g)
    return dst^


def test_dry_and_wet_are_input_and_output_gains_not_a_mix() raises:
    """Pins what miniaudio's delay actually does with `dry` and `wet`.

    The names suggest an effects-mixer blend between an untouched and a delayed
    path, but the implementation is:

        buffer[i] = buffer[i] * decay + in * dry
        out       = buffer[i] * wet

    so `dry` is the gain going *into* the delay line and `wet` is the gain of
    the whole node's output. There is no separate un-delayed path: wet = 0
    silences the node no matter what dry is, and the immediate signal comes out
    scaled by dry * wet.

    Asserted below on a 0.4 input: 1x1 gives 0.4, 0.5x0.5 gives 0.1, and
    anything with wet = 0 gives silence.
    """
    var lib = _lib()

    var silenced = _through_delay(lib, Float32(1.0), Float32(0.0))
    for i in range(len(silenced)):
        assert_equal(silenced[i], Float32(0))

    var unity = _through_delay(lib, Float32(1.0), Float32(1.0))
    assert_almost_equal(unity[0], Float32(0.4), atol=0.0001)

    var quartered = _through_delay(lib, Float32(0.5), Float32(0.5))
    assert_almost_equal(quartered[0], Float32(0.1), atol=0.0001)


def test_operations_on_an_uninitialised_delay_node_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var g = _graph(lib)
    var d = raw.delay_node_alloc(lib)
    assert_true(d != null_handle())

    assert_equal(raw.delay_node_attach_to_endpoint(lib, d, g), MA_INVALID_ARGS)
    assert_equal(raw.delay_node_set_wet(lib, d, Float32(0.5)), MA_INVALID_ARGS)
    assert_equal(raw.delay_node_get_wet(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.delay_node_set_dry(lib, d, Float32(0.5)), MA_INVALID_ARGS)
    assert_equal(raw.delay_node_get_dry(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.delay_node_set_decay(lib, d, Float32(0.5)), MA_INVALID_ARGS)
    assert_equal(raw.delay_node_get_decay(lib, d).result, MA_INVALID_ARGS)

    raw.delay_node_free(lib, d)
    raw.node_graph_free(lib, g)


def test_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var g = _graph(lib)
    var d = _delay(lib, g)

    assert_equal(raw.delay_node_uninit(lib, d), MA_SUCCESS)
    assert_equal(raw.delay_node_uninit(lib, d), MA_SUCCESS)
    raw.delay_node_free(lib, d)

    assert_equal(raw.delay_node_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.delay_node_init(
            lib, null_handle(), g, STEREO, RATE, UInt32(16), Float32(0.5)
        ),
        MA_INVALID_ARGS,
    )
    raw.delay_node_free(lib, null_handle())
    raw.node_graph_free(lib, g)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
