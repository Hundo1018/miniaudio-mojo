"""TDD tests for the idiomatic biquad API (RAII Biquad / BiquadNode).

L3 behavioral: verifies that the identity coefficients pass audio through, that
retuning takes effect on a live filter, that both init paths agree, and that the
node variant attaches to an engine's graph and outlives nothing it shouldn't.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_raises,
    assert_almost_equal,
    TestSuite,
)
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.engine import Engine
from miniaudio.filter import Biquad, BiquadNode


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _ramp(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    for i in range(n):
        out.append(Float32(i + 1))
    return out^


def _identity() raises -> Biquad:
    return Biquad.create(_lib(), b0=1.0, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0)


def test_identity_coefficients_pass_audio_through() raises:
    """Coefficient b0=1 with no feedback leaves every frame untouched."""
    var bq = _identity()
    var src = _ramp(8)
    var got = bq.process(src)

    assert_equal(len(got), 8)
    for i in range(8):
        assert_almost_equal(got[i], src[i], atol=0.001)


def test_a_gain_biquad_scales_every_frame() raises:
    """Halving b0 halves the output."""
    var bq = Biquad.create(_lib(), b0=0.5, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0)
    var src = _ramp(8)
    var got = bq.process(src)
    for i in range(8):
        assert_almost_equal(got[i], src[i] * Float32(0.5), atol=0.001)


def test_retune_changes_a_live_filter() raises:
    """Retuning swaps the coefficients without rebuilding the filter."""
    var bq = _identity()
    bq.retune(b0=0.5, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0)

    var src = _ramp(4)
    var got = bq.process(src)
    assert_almost_equal(got[0], src[0] * Float32(0.5), atol=0.001)


def test_preallocated_and_managed_heaps_filter_identically() raises:
    """Where the working heap lives makes no difference to the audio."""
    var managed = _identity()
    var prealloc = Biquad.create(
        _lib(), b0=1.0, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0, preallocated=True
    )

    var a = managed.process(_ramp(8))
    var b = prealloc.process(_ramp(8))
    for i in range(8):
        assert_equal(a[i], b[i])


def test_heap_size_is_available_before_building_one() raises:
    """The static heap-size query answers without constructing a filter."""
    _ = Biquad.heap_size(_lib(), b0=1.0, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0)


def test_latency_and_clear_cache_are_available() raises:
    """Latency is queryable and clear_cache drops the running state."""
    var bq = _identity()
    _ = bq.process(_ramp(4))
    _ = bq.latency()
    bq.clear_cache()

    # A biquad's clear_cache zeroes its delay registers, so the tuning survives.
    var got = bq.process(_ramp(4))
    assert_almost_equal(got[0], Float32(1.0), atol=0.001)


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var bq = _identity()
    bq.uninit()
    with assert_raises():
        _ = bq.process(_ramp(4))
    with assert_raises():
        _ = bq.latency()


def test_node_attaches_to_an_engine_graph() raises:
    """The node variant lives in an engine's node graph and can be retuned."""
    var engine = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    var node = BiquadNode.create(
        engine,
        b0=Float32(1.0), b1=Float32(0.0), b2=Float32(0.0),
        a0=Float32(1.0), a1=Float32(0.0), a2=Float32(0.0),
    )
    node.retune(b0=0.5, b1=0.0, b2=0.0, a0=1.0, a1=0.0, a2=0.0)
    node.uninit()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
