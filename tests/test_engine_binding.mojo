"""TDD contract tests for the engine BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: every engine runs on the NULL backend
(use_null_backend=True). The engine auto-starts and its clock advances, so we
assert observable progress via get_time_in_pcm_frames.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.engine_raw as raw


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_play_query() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_true(eng != null_handle())
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)

    assert_true(raw.engine_get_sample_rate(lib, eng) > 0)
    assert_true(raw.engine_get_channels(lib, eng) > 0)
    assert_equal(raw.engine_set_volume(lib, eng, 0.5), MA_SUCCESS)
    assert_true(raw.engine_get_volume(lib, eng) > 0.0)
    assert_equal(raw.engine_set_gain_db(lib, eng, -6.0), MA_SUCCESS)
    _ = raw.engine_get_gain_db(lib, eng)

    assert_equal(raw.engine_start(lib, eng), MA_SUCCESS)
    assert_equal(raw.engine_play_sound(lib, eng, WAV_PATH), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_true(raw.engine_get_time_in_pcm_frames(lib, eng) > 0)
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)

    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)
    raw.engine_free(lib, eng)


def test_play_sound_ex_positive() raises:
    """Fire-and-forget play_sound_ex (NULL node) advances the clock."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_play_sound_ex(lib, eng, WAV_PATH), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_true(raw.engine_get_time_in_pcm_frames(lib, eng) > 0)
    raw.engine_free(lib, eng)


def test_clock_set_get() raises:
    """With the device stopped the clock is frozen; set/get round-trips exactly."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)  # freeze the clock

    assert_equal(raw.engine_set_time_in_pcm_frames(lib, eng, 4800), MA_SUCCESS)
    assert_equal(raw.engine_get_time_in_pcm_frames(lib, eng), UInt64(4800))
    assert_true(raw.engine_get_time_in_milliseconds(lib, eng) > 0)

    assert_equal(raw.engine_set_time_in_milliseconds(lib, eng, 50), MA_SUCCESS)
    assert_true(raw.engine_get_time_in_pcm_frames(lib, eng) > 0)
    raw.engine_free(lib, eng)


def test_read_pcm_frames_offline() raises:
    """A playing sound feeds the graph; manual read pulls it (device stopped, single reader)."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_play_sound(lib, eng, WAV_PATH), MA_SUCCESS)
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)  # single reader

    var ch = Int(raw.engine_get_channels(lib, eng))
    assert_true(ch > 0)
    comptime FRAMES = 128
    var buf = List[Float32]()
    buf.resize(FRAMES * ch, Float32(0))
    var c = raw.engine_read_pcm_frames(lib, eng, buf, UInt64(FRAMES))
    assert_equal(c.result, MA_SUCCESS)
    assert_true(c.value > UInt64(0))
    raw.engine_free(lib, eng)


def test_listener_accessors() raises:
    """Positive: listener spatialization getters/setters round-trip."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)

    assert_true(raw.engine_get_listener_count(lib, eng) >= UInt32(1))

    raw.engine_listener_set_position(lib, eng, 0, 1.0, 2.0, 3.0)
    var p = raw.engine_listener_get_position(lib, eng, 0)
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    raw.engine_listener_set_direction(lib, eng, 0, 0.0, 0.0, -1.0)
    assert_true(raw.engine_listener_get_direction(lib, eng, 0).z == -1.0)

    raw.engine_listener_set_velocity(lib, eng, 0, 0.5, 0.0, 0.0)
    assert_true(raw.engine_listener_get_velocity(lib, eng, 0).x == 0.5)

    raw.engine_listener_set_world_up(lib, eng, 0, 0.0, 1.0, 0.0)
    assert_true(raw.engine_listener_get_world_up(lib, eng, 0).y == 1.0)

    raw.engine_listener_set_cone(lib, eng, 0, 0.5, 1.0, 0.25)
    var cone = raw.engine_listener_get_cone(lib, eng, 0)
    assert_true(cone.inner_angle == 0.5 and cone.outer_angle == 1.0)
    assert_true(cone.outer_gain == 0.25)

    raw.engine_listener_set_enabled(lib, eng, 0, False)
    assert_equal(raw.engine_listener_is_enabled(lib, eng, 0), 0)
    raw.engine_listener_set_enabled(lib, eng, 0, True)
    assert_equal(raw.engine_listener_is_enabled(lib, eng, 0), 1)

    # A single enabled listener is always the closest.
    assert_true(
        raw.engine_find_closest_listener(lib, eng, 1.0, 0.0, 0.0)
        < raw.engine_get_listener_count(lib, eng)
    )
    raw.engine_free(lib, eng)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    assert_equal(raw.engine_init(lib, null_handle(), True), MA_INVALID_ARGS)
    assert_equal(raw.engine_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.engine_play_sound(lib, null_handle(), WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_sample_rate(lib, null_handle()), UInt32(0))
    assert_equal(raw.engine_get_channels(lib, null_handle()), UInt32(0))
    assert_equal(raw.engine_set_volume(lib, null_handle(), 1.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_volume(lib, null_handle()), Float32(0))
    assert_equal(raw.engine_set_gain_db(lib, null_handle(), 0.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_gain_db(lib, null_handle()), Float32(0))
    assert_equal(raw.engine_get_time_in_pcm_frames(lib, null_handle()), UInt64(0))
    assert_equal(raw.engine_play_sound_ex(lib, null_handle(), WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_time_in_milliseconds(lib, null_handle()), UInt64(0))
    assert_equal(raw.engine_set_time_in_pcm_frames(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(raw.engine_set_time_in_milliseconds(lib, null_handle(), 0), MA_INVALID_ARGS)
    assert_equal(raw.engine_get_listener_count(lib, null_handle()), UInt32(0))
    assert_equal(
        raw.engine_find_closest_listener(lib, null_handle(), 0.0, 0.0, 0.0), UInt32(0)
    )
    assert_equal(raw.engine_listener_is_enabled(lib, null_handle(), 0), 0)

    # read on a null handle: MA_INVALID_ARGS, frames_read stays 0
    var nbuf = List[Float32]()
    nbuf.resize(4, Float32(0))
    var nc = raw.engine_read_pcm_frames(lib, null_handle(), nbuf, UInt64(2))
    assert_equal(nc.result, MA_INVALID_ARGS)
    assert_equal(nc.value, UInt64(0))

    # listener getters on a null handle return a zeroed Vec3 (no crash)
    var np = raw.engine_listener_get_position(lib, null_handle(), 0)
    assert_true(np.x == 0.0 and np.y == 0.0 and np.z == 0.0)
    # void setters on a null handle are a safe no-op
    raw.engine_listener_set_position(lib, null_handle(), 0, 1.0, 2.0, 3.0)


def test_ops_before_init_invalid() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_start(lib, eng), MA_INVALID_ARGS)
    assert_equal(raw.engine_stop(lib, eng), MA_INVALID_ARGS)
    assert_equal(raw.engine_play_sound(lib, eng, WAV_PATH), MA_INVALID_ARGS)
    assert_equal(raw.engine_set_volume(lib, eng, 1.0), MA_INVALID_ARGS)
    assert_equal(raw.engine_set_gain_db(lib, eng, 0.0), MA_INVALID_ARGS)
    raw.engine_free(lib, eng)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_true(eng != null_handle())
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)
    raw.engine_free(lib, eng)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.engine_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    """Re-init auto-uninits the previous engine + context; then free initialized."""
    var lib = _lib()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)  # reinit branch
    raw.engine_free(lib, eng)  # free initialized (+ context) branch


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
