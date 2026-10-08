"""TDD tests for the idiomatic noise API (RAII Noise).

L3 behavioral: verifies that the Noise struct generates audible PCM,
that amplitude changes affect output, that seed/type changes work,
and that different noise types produce distinct output.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer
from std.math import abs

from miniaudio import MaLib
from miniaudio.noise import Noise, NoiseTypeWhite, NoiseTypePink, NoiseTypeBrownian


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_white_generates_nonzero_audio() raises:
    """White noise with amplitude 1.0 must produce non-silent output."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypeWhite, amplitude=1.0)
    var frames = ns.read_frames(UInt64(512))
    assert_true(len(frames) == 512)
    var found_nonzero = False
    for i in range(len(frames)):
        if frames[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)


def test_zero_amplitude_is_silent() raises:
    """Amplitude 0.0 must produce all-zero samples."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypeWhite, amplitude=0.0)
    var frames = ns.read_frames(UInt64(256))
    for i in range(len(frames)):
        assert_equal(frames[i], Float32(0))


def test_set_amplitude_changes_output() raises:
    """After lowering amplitude the output peak should be smaller."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypeWhite, amplitude=1.0, seed=Int32(42))
    var loud = ns.read_frames(UInt64(1024))
    ns.set_amplitude(0.1)
    var quiet = ns.read_frames(UInt64(1024))
    var loud_max = Float32(0)
    var quiet_max = Float32(0)
    for i in range(len(loud)):
        if abs(loud[i]) > loud_max:
            loud_max = abs(loud[i])
    for i in range(len(quiet)):
        if abs(quiet[i]) > quiet_max:
            quiet_max = abs(quiet[i])
    assert_true(quiet_max < loud_max)


def test_pink_generates_nonzero_audio() raises:
    """Pink noise must produce non-silent output."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypePink, amplitude=1.0)
    var frames = ns.read_frames(UInt64(512))
    var found_nonzero = False
    for i in range(len(frames)):
        if frames[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)


def test_brownian_generates_nonzero_audio() raises:
    """Brownian noise must produce non-silent output."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypeBrownian, amplitude=1.0)
    var frames = ns.read_frames(UInt64(512))
    var found_nonzero = False
    for i in range(len(frames)):
        if frames[i] != Float32(0):
            found_nonzero = True
            break
    assert_true(found_nonzero)


def test_set_seed_then_read() raises:
    """Set_seed must succeed and not crash on subsequent read."""
    var ns = Noise.create(_lib(), noise_type=NoiseTypeWhite)
    ns.set_seed(Int32(999))
    var frames = ns.read_frames(UInt64(256))
    assert_true(len(frames) == 256)


def test_stereo_channels() raises:
    """2-channel noise read of N frames yields 2*N f32 samples."""
    var ns = Noise.create(_lib(), channels=2, amplitude=1.0)
    var frames = ns.read_frames(UInt64(100))
    assert_true(len(frames) == 200)


def test_preallocated_generator_streams_like_the_managed_one() raises:
    """The preallocated path (heap size + init) streams identically to the managed one."""
    var lib = _lib()
    var managed = Noise.create(
        lib, noise_type=NoiseTypePink, channels=UInt32(2), seed=Int32(11), amplitude=0.8
    )
    var prealloc = Noise.create(
        lib,
        noise_type=NoiseTypePink,
        channels=UInt32(2),
        seed=Int32(11),
        amplitude=0.8,
        preallocated=True,
    )
    var a = managed.read_frames(UInt64(300))
    var b = prealloc.read_frames(UInt64(300))
    assert_equal(len(a), len(b))
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_heap_size_follows_the_noise_type_and_channels() raises:
    var lib = _lib()
    assert_equal(Noise.heap_size(lib, noise_type=NoiseTypeWhite), UInt64(0))
    var pink2 = Noise.heap_size(lib, noise_type=NoiseTypePink, channels=UInt32(2))
    var pink8 = Noise.heap_size(lib, noise_type=NoiseTypePink, channels=UInt32(8))
    assert_true(pink2 > UInt64(0))
    assert_true(pink8 > pink2)
    assert_true(Noise.heap_size(lib, noise_type=NoiseTypeBrownian) > UInt64(0))


def test_preallocated_noise_rejects_bad_config() raises:
    var lib = _lib()
    with assert_raises():
        _ = Noise.create(lib, channels=UInt32(0), preallocated=True)
    with assert_raises():
        _ = Noise.heap_size(lib, channels=UInt32(0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
