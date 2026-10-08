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
import miniaudio._ffi.node_raw as nraw
import miniaudio._ffi.sound_raw as sraw
import miniaudio._ffi.sync_raw as syraw
import miniaudio._ffi.device_raw as draw
import miniaudio._ffi.resource_manager_raw as rraw


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


# ---------------------------------------------------------------------------
# borrowed views of what the engine owns: node graph, endpoint, log, device,
# resource manager
# ---------------------------------------------------------------------------

comptime PERIOD: Int = 480  # frames the engine renders per pass (10 ms at 48 kHz)
comptime FLAGS_PASS_THROUGH: UInt32 = 0x2000 | 0x4000  # NO_PITCH | NO_SPATIALIZATION
comptime STATE_STOPPED: Int = 1
comptime STATE_STARTED: Int = 2


def _stopped_engine(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A null-backend engine with its device stopped, so the test is the only reader."""
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)
    return eng


def _pull(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) raises -> List[Float32]:
    """One engine period of stereo frames (the engine renders whole periods)."""
    var buf = List[Float32]()
    buf.resize(PERIOD * 2, Float32(0))
    var rc = raw.engine_read_pcm_frames(lib, eng, buf, UInt64(PERIOD))
    assert_equal(rc.result, MA_SUCCESS)
    buf.resize(Int(rc.value) * 2, Float32(0))
    return buf^


def _all_equal(samples: List[Float32], value: Float32) -> Bool:
    for i in range(len(samples)):
        if samples[i] != value:
            return False
    return True


def _graph_view(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]
) raises -> OpaquePointer[MutUntrackedOrigin]:
    var g = nraw.node_graph_alloc(lib)
    assert_equal(nraw.node_graph_borrow_engine(lib, g, eng), MA_SUCCESS)
    return g


# ---- ma_engine_get_node_graph ----


def test_node_graph_view_reports_the_engines_own_graph() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)

    var channels = nraw.node_graph_get_channels(lib, g)
    assert_equal(channels.result, MA_SUCCESS)
    assert_equal(channels.value, raw.engine_get_channels(lib, eng))
    assert_equal(nraw.node_graph_endpoint_input_bus_count(lib, g).value, UInt32(1))

    # Same clock: the engine's time is the graph's time, in step.
    var t_graph = nraw.node_graph_get_time(lib, g)
    assert_equal(t_graph.value, raw.engine_get_time_in_pcm_frames(lib, eng))
    assert_equal(nraw.node_graph_set_time(lib, g, 4800), MA_SUCCESS)
    assert_equal(raw.engine_get_time_in_pcm_frames(lib, eng), UInt64(4800))
    assert_equal(raw.engine_set_time_in_pcm_frames(lib, eng, 960), MA_SUCCESS)
    assert_equal(nraw.node_graph_get_time(lib, g).value, UInt64(960))
    assert_true(nraw.node_graph_get_processing_size(lib, g).value > UInt32(0))

    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_a_node_built_into_the_engines_graph_is_heard_from_the_engine() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)

    var node = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, node, g, 2, 0.25), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, node, 0, g, 0), MA_SUCCESS)
    assert_true(nraw.node_belongs_to_graph(lib, node, g).value)

    # Read through the engine, not the view: it is one graph.
    assert_true(_all_equal(_pull(lib, eng), Float32(0.25)))
    # ...and the engine's own volume scales it, since the endpoint is shared.
    assert_equal(raw.engine_set_volume(lib, eng, 0.5), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.125)))

    nraw.node_free(lib, node)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_node_graph_view_reads_the_same_frames_the_engine_would() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var node = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, node, g, 2, 0.5), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, node, 0, g, 0), MA_SUCCESS)

    var buf = List[Float32]()
    buf.resize(PERIOD * 2, Float32(0))
    var rc = nraw.node_graph_read(lib, g, buf, UInt64(PERIOD))
    assert_equal(rc.result, MA_SUCCESS)
    assert_equal(rc.value, UInt64(PERIOD))
    assert_true(_all_equal(buf, Float32(0.5)))

    nraw.node_free(lib, node)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_node_graph_view_hand_back_leaves_the_engines_graph_alone() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)

    # Uninit on a view detaches it; it must not tear the engine's graph down.
    assert_equal(nraw.node_graph_uninit(lib, g), MA_SUCCESS)
    assert_equal(nraw.node_graph_get_channels(lib, g).result, MA_INVALID_ARGS)
    assert_equal(raw.engine_get_channels(lib, eng), UInt32(2))
    var node = nraw.node_alloc(lib)
    var g2 = _graph_view(lib, eng)
    assert_equal(nraw.node_init(lib, node, g2, 2, 0.5), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, node, 0, g2, 0), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.5)))

    # Freeing a view does the same.
    nraw.node_graph_free(lib, g)
    nraw.node_graph_free(lib, g2)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.5)))
    nraw.node_free(lib, node)
    raw.engine_free(lib, eng)


def test_node_graph_view_notices_when_the_engine_is_uninitialised() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)

    assert_equal(nraw.node_graph_get_channels(lib, g).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_get_time(lib, g).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_set_time(lib, g, 0), MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_endpoint_input_bus_count(lib, g).result, MA_INVALID_ARGS)

    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_node_graph_borrow_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = nraw.node_graph_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(nraw.node_graph_borrow_engine(lib, null_handle(), eng), MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_borrow_engine(lib, g, null_handle()), MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_borrow_engine(lib, g, cold), MA_INVALID_ARGS)
    # A failed borrow leaves the handle empty.
    assert_equal(nraw.node_graph_get_channels(lib, g).result, MA_INVALID_ARGS)

    # A graph handle that owned a graph can be turned into a view of the engine's.
    assert_equal(nraw.node_graph_init(lib, g, 1), MA_SUCCESS)
    assert_equal(nraw.node_graph_get_channels(lib, g).value, UInt32(1))
    assert_equal(nraw.node_graph_borrow_engine(lib, g, eng), MA_SUCCESS)
    assert_equal(nraw.node_graph_get_channels(lib, g).value, UInt32(2))

    raw.engine_free(lib, cold)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


# ---- ma_engine_get_endpoint ----


def test_endpoint_view_is_the_endpoint_of_the_engines_graph() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var ep = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)

    var same = nraw.node_is_graph_endpoint(lib, ep, g)
    assert_equal(same.result, MA_SUCCESS)
    assert_true(same.value)
    assert_true(nraw.node_belongs_to_graph(lib, ep, g).value)
    assert_equal(nraw.node_get_input_bus_count(lib, ep).value, UInt32(1))
    assert_equal(nraw.node_get_input_channels(lib, ep, 0).value, raw.engine_get_channels(lib, eng))

    # An ordinary node is not the endpoint.
    var other = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, other, g, 2, 0.0), MA_SUCCESS)
    assert_true(not nraw.node_is_graph_endpoint(lib, other, g).value)
    # And a different engine's endpoint is not this graph's.
    var eng2 = _stopped_engine(lib)
    var ep2 = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep2, eng2), MA_SUCCESS)
    assert_true(not nraw.node_is_graph_endpoint(lib, ep2, g).value)

    nraw.node_free(lib, ep2)
    raw.engine_free(lib, eng2)
    nraw.node_free(lib, other)
    nraw.node_free(lib, ep)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_endpoint_view_volume_is_the_engines_volume() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var ep = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)

    assert_equal(nraw.node_get_output_bus_volume(lib, ep, 0).value, raw.engine_get_volume(lib, eng))
    assert_equal(nraw.node_set_output_bus_volume(lib, ep, 0, 0.5), MA_SUCCESS)
    assert_equal(raw.engine_get_volume(lib, eng), Float32(0.5))
    assert_equal(raw.engine_set_volume(lib, eng, 0.25), MA_SUCCESS)
    assert_equal(nraw.node_get_output_bus_volume(lib, ep, 0).value, Float32(0.25))

    nraw.node_free(lib, ep)
    raw.engine_free(lib, eng)


def test_a_node_can_be_attached_to_the_endpoint_view() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var ep = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)

    var node = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, node, g, 2, 0.75), MA_SUCCESS)
    assert_equal(nraw.node_attach_output_bus(lib, node, 0, ep, 0), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.75)))

    # Queries on the view answer about the real endpoint.
    var state = nraw.node_get_state(lib, ep)
    assert_equal(state.result, MA_SUCCESS)
    assert_equal(state.value, 0)    # started
    assert_true(nraw.node_get_time(lib, ep).value > UInt64(0))

    nraw.node_free(lib, node)
    nraw.node_free(lib, ep)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_endpoint_view_uninit_and_free_leave_the_endpoint_alone() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var ep = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)

    assert_equal(nraw.node_uninit(lib, ep), MA_SUCCESS)
    assert_equal(nraw.node_get_input_bus_count(lib, ep).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_graph_endpoint_input_bus_count(lib, g).value, UInt32(1))

    # The same handle can become an ordinary node afterwards.
    assert_equal(nraw.node_init(lib, ep, g, 2, 0.5), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, ep, 0, g, 0), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.5)))

    # And back to a view; freeing a view (not a node) must not uninit the endpoint.
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)
    nraw.node_free(lib, ep)
    assert_equal(nraw.node_graph_endpoint_input_bus_count(lib, g).value, UInt32(1))

    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_endpoint_view_notices_when_the_engine_is_uninitialised() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var ep = nraw.node_alloc(lib)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)

    assert_equal(nraw.node_get_input_bus_count(lib, ep).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_get_time(lib, ep).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_attach_to_endpoint(lib, ep, 0, null_handle(), 0), MA_INVALID_ARGS)
    # As an attach *target* it resolves to nothing, too.
    var src = nraw.node_alloc(lib)
    assert_equal(nraw.node_attach_output_bus(lib, src, 0, ep, 0), MA_INVALID_ARGS)

    nraw.node_free(lib, src)
    nraw.node_free(lib, ep)
    raw.engine_free(lib, eng)


def test_endpoint_borrow_and_identity_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var ep = nraw.node_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(nraw.node_borrow_engine_endpoint(lib, null_handle(), eng), MA_INVALID_ARGS)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, null_handle()), MA_INVALID_ARGS)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, cold), MA_INVALID_ARGS)

    # Identity needs two ready handles.
    assert_equal(nraw.node_is_graph_endpoint(lib, ep, g).result, MA_INVALID_ARGS)  # never borrowed
    assert_equal(nraw.node_is_graph_endpoint(lib, null_handle(), g).result, MA_INVALID_ARGS)
    assert_equal(nraw.node_borrow_engine_endpoint(lib, ep, eng), MA_SUCCESS)
    assert_equal(nraw.node_is_graph_endpoint(lib, ep, null_handle()).result, MA_INVALID_ARGS)

    raw.engine_free(lib, cold)
    nraw.node_free(lib, ep)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


# ---- ma_engine_get_log ----


def test_log_view_posts_to_the_engines_own_log() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var lg = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, lg, eng), MA_SUCCESS)

    assert_equal(syraw.log_register_callback(lib, lg), MA_SUCCESS)
    var before = syraw.log_message_count(lib, lg)
    assert_equal(before.result, MA_SUCCESS)
    assert_equal(syraw.log_post(lib, lg, UInt32(3), "hello from the view"), MA_SUCCESS)
    assert_equal(syraw.log_postf(lib, lg, UInt32(3), "value: %s", "x"), MA_SUCCESS)
    assert_equal(syraw.log_postv(lib, lg, UInt32(3), "value: %s", "y"), MA_SUCCESS)
    assert_equal(syraw.log_message_count(lib, lg).value, before.value + UInt32(3))

    # A second view of the same engine log sees the same stream: a message posted
    # through one reaches the callback registered through the other.
    var other = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, other, eng), MA_SUCCESS)
    assert_equal(syraw.log_post(lib, other, UInt32(3), "from the other view"), MA_SUCCESS)
    assert_equal(syraw.log_message_count(lib, lg).value, before.value + UInt32(4))

    assert_equal(syraw.log_unregister_callback(lib, lg), MA_SUCCESS)
    assert_equal(syraw.log_post(lib, other, UInt32(3), "after unregister"), MA_SUCCESS)
    assert_equal(syraw.log_message_count(lib, lg).value, before.value + UInt32(4))

    syraw.log_free(lib, other)
    syraw.log_free(lib, lg)
    raw.engine_free(lib, eng)


def test_dropping_a_log_view_takes_its_callback_off_the_engines_log() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var observer = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, observer, eng), MA_SUCCESS)

    var doomed = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, doomed, eng), MA_SUCCESS)
    assert_equal(syraw.log_register_callback(lib, doomed), MA_SUCCESS)
    # Freeing the view must unregister its callback; if it did not, the next post
    # would call into freed memory.
    syraw.log_free(lib, doomed)
    assert_equal(syraw.log_post(lib, observer, UInt32(3), "still works"), MA_SUCCESS)

    # uninit does the same and hands the handle back.
    var again = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, again, eng), MA_SUCCESS)
    assert_equal(syraw.log_register_callback(lib, again), MA_SUCCESS)
    assert_equal(syraw.log_uninit(lib, again), MA_SUCCESS)
    assert_equal(syraw.log_post(lib, again, UInt32(3), "no longer a log"), MA_INVALID_ARGS)
    assert_equal(syraw.log_post(lib, observer, UInt32(3), "engine log intact"), MA_SUCCESS)

    syraw.log_free(lib, again)
    syraw.log_free(lib, observer)
    raw.engine_free(lib, eng)


def test_log_view_notices_when_the_engine_is_uninitialised() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var lg = syraw.log_alloc(lib)
    assert_equal(syraw.log_borrow_engine(lib, lg, eng), MA_SUCCESS)
    assert_equal(syraw.log_register_callback(lib, lg), MA_SUCCESS)
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)

    assert_equal(syraw.log_post(lib, lg, UInt32(3), "too late"), MA_INVALID_ARGS)
    assert_equal(syraw.log_message_count(lib, lg).result, MA_INVALID_ARGS)
    # Freeing the view after the engine has gone must not touch the dead log.
    syraw.log_free(lib, lg)
    raw.engine_free(lib, eng)


def test_log_borrow_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var lg = syraw.log_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(syraw.log_borrow_engine(lib, null_handle(), eng), MA_INVALID_ARGS)
    assert_equal(syraw.log_borrow_engine(lib, lg, null_handle()), MA_INVALID_ARGS)
    assert_equal(syraw.log_borrow_engine(lib, lg, cold), MA_INVALID_ARGS)
    assert_equal(syraw.log_post(lib, lg, UInt32(3), "unborrowed"), MA_INVALID_ARGS)

    # A handle that owned a log can become a view (the owned log is released).
    assert_equal(syraw.log_init(lib, lg), MA_SUCCESS)
    assert_equal(syraw.log_register_callback(lib, lg), MA_SUCCESS)
    assert_equal(syraw.log_borrow_engine(lib, lg, eng), MA_SUCCESS)
    assert_equal(syraw.log_message_count(lib, lg).value, UInt32(0))

    raw.engine_free(lib, cold)
    syraw.log_free(lib, lg)
    raw.engine_free(lib, eng)


# ---- ma_engine_get_device ----


def test_device_view_reports_the_engines_device() raises:
    var lib = MaLib.default()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)    # running
    var dev = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)

    assert_equal(draw.device_get_state(lib, dev), STATE_STARTED)
    assert_true(draw.device_is_started(lib, dev))
    assert_equal(draw.device_get_sample_rate(lib, dev), raw.engine_get_sample_rate(lib, eng))
    assert_equal(draw.device_get_channels(lib, dev), raw.engine_get_channels(lib, eng))

    # Stopping the engine stops *the device the view stands for*.
    assert_equal(raw.engine_stop(lib, eng), MA_SUCCESS)
    assert_equal(draw.device_get_state(lib, dev), STATE_STOPPED)
    assert_true(not draw.device_is_started(lib, dev))
    # ...and starting the device through the view starts the engine again.
    assert_equal(draw.device_start(lib, dev), MA_SUCCESS)
    assert_equal(draw.device_get_state(lib, dev), STATE_STARTED)
    assert_equal(draw.device_stop(lib, dev), MA_SUCCESS)

    var name = draw.device_get_name(lib, dev, 1)
    assert_equal(name.result, MA_SUCCESS)
    assert_true(name.value.byte_length() > 0)
    assert_true(draw.device_has_log(lib, dev).value)
    assert_equal(draw.device_get_context_backend(lib, dev).result, MA_SUCCESS)

    draw.device_free(lib, dev)
    raw.engine_free(lib, eng)


def test_device_view_master_volume_and_info() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var dev = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)

    assert_equal(draw.device_set_master_volume(lib, dev, 0.5), MA_SUCCESS)
    assert_equal(draw.device_get_master_volume(lib, dev).value, Float32(0.5))
    assert_equal(draw.device_set_master_volume_db(lib, dev, -6.0), MA_SUCCESS)
    assert_true(draw.device_get_master_volume_db(lib, dev).value < Float32(-5.0))

    # The info snapshot is the view's own, taken from the engine's device.
    assert_equal(draw.device_info_load(lib, dev, 1), MA_SUCCESS)
    assert_true(draw.device_info_name(lib, dev).result == MA_SUCCESS)

    # Two views of one engine are the same device.
    var dev2 = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev2, eng), MA_SUCCESS)
    var same = draw.device_id_equal(lib, dev, dev2, 1)
    assert_equal(same.result, MA_SUCCESS)
    assert_true(same.value)

    draw.device_free(lib, dev2)
    draw.device_free(lib, dev)
    raw.engine_free(lib, eng)


def test_pumping_the_device_view_renders_the_engines_graph() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var node = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, node, g, 2, 0.25), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, node, 0, g, 0), MA_SUCCESS)

    var dev = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)
    var out = List[Float32]()
    out.resize(PERIOD * 2, Float32(0))
    assert_equal(draw.device_handle_backend_data_callback(lib, dev, out, UInt32(PERIOD)), MA_SUCCESS)
    assert_true(_all_equal(out, Float32(0.25)))

    draw.device_free(lib, dev)
    nraw.node_free(lib, node)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_device_view_uninit_and_free_leave_the_device_running() raises:
    var lib = MaLib.default()
    var eng = raw.engine_alloc(lib)
    assert_equal(raw.engine_init(lib, eng, True), MA_SUCCESS)
    var dev = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)

    assert_equal(draw.device_uninit(lib, dev), MA_SUCCESS)
    assert_equal(draw.device_get_state(lib, dev), 0)    # the handle is empty again
    var again = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, again, eng), MA_SUCCESS)
    assert_equal(draw.device_get_state(lib, again), STATE_STARTED)    # the device is untouched
    draw.device_free(lib, again)    # freeing a view must not stop or uninit it
    var third = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, third, eng), MA_SUCCESS)
    assert_equal(draw.device_get_state(lib, third), STATE_STARTED)

    draw.device_free(lib, third)
    draw.device_free(lib, dev)
    raw.engine_free(lib, eng)


def test_device_view_notices_when_the_engine_is_uninitialised() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var dev = draw.device_alloc(lib)
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)

    assert_equal(draw.device_get_state(lib, dev), 0)
    assert_equal(draw.device_start(lib, dev), MA_INVALID_ARGS)
    assert_equal(draw.device_get_master_volume(lib, dev).result, MA_INVALID_ARGS)
    assert_equal(draw.device_get_channels(lib, dev), UInt32(0))
    draw.device_free(lib, dev)
    raw.engine_free(lib, eng)


def test_device_borrow_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var dev = draw.device_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(draw.device_borrow_engine(lib, null_handle(), eng), MA_INVALID_ARGS)
    assert_equal(draw.device_borrow_engine(lib, dev, null_handle()), MA_INVALID_ARGS)
    assert_equal(draw.device_borrow_engine(lib, dev, cold), MA_INVALID_ARGS)
    assert_equal(draw.device_get_state(lib, dev), 0)

    # Identity between a view and an unready handle is an error, not "different".
    assert_equal(draw.device_borrow_engine(lib, dev, eng), MA_SUCCESS)
    var blank = draw.device_alloc(lib)
    assert_equal(draw.device_id_equal(lib, dev, blank, 1).result, MA_INVALID_ARGS)

    draw.device_free(lib, blank)
    raw.engine_free(lib, cold)
    draw.device_free(lib, dev)
    raw.engine_free(lib, eng)


# ---- ma_engine_get_resource_manager ----


def test_resource_manager_view_is_the_engines_own_manager() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var rm = rraw.resource_manager_alloc(lib)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, eng), MA_SUCCESS)
    assert_true(rraw.resource_manager_has_log(lib, rm).value)

    # Decoded data registered through the view is visible to the engine's sounds:
    # that is only possible if the view really is the manager the engine uses.
    var pcm = List[Float32]()
    for _ in range(PERIOD):
        pcm.append(Float32(0.5))
        pcm.append(Float32(0.5))
    var snd = sraw.sound_alloc(lib)
    assert_true(sraw.sound_init_from_file(lib, snd, eng, "registered://tone", 0) != MA_SUCCESS)
    assert_equal(
        rraw.resource_manager_register_decoded_data(
            lib, rm, "registered://tone", pcm, UInt64(PERIOD), 5, 2, raw.engine_get_sample_rate(lib, eng)
        ),
        MA_SUCCESS,
    )
    assert_equal(sraw.sound_init_from_file(lib, snd, eng, "registered://tone", 0), MA_SUCCESS)
    assert_equal(sraw.sound_get_length_in_pcm_frames(lib, snd).value, UInt64(PERIOD))

    # Unregistering through the view takes it away again (the sound already
    # holds its own reference to the data).
    assert_equal(sraw.sound_uninit(lib, snd), MA_SUCCESS)
    assert_equal(rraw.resource_manager_unregister_data(lib, rm, "registered://tone"), MA_SUCCESS)
    assert_true(sraw.sound_init_from_file(lib, snd, eng, "registered://tone", 0) != MA_SUCCESS)

    sraw.sound_free(lib, snd)
    rraw.resource_manager_free(lib, rm)
    raw.engine_free(lib, eng)


def test_data_objects_can_be_built_against_the_resource_manager_view() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var rm = rraw.resource_manager_alloc(lib)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, eng), MA_SUCCESS)

    var buffer = rraw.rm_data_buffer_alloc(lib)
    assert_equal(rraw.rm_data_buffer_init(lib, buffer, rm, WAV_PATH, 0), MA_SUCCESS)
    var snd = sraw.sound_alloc(lib)
    assert_equal(sraw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)
    # The buffer and the engine's sound decode the same file the same way.
    assert_equal(
        rraw.rm_data_buffer_get_length(lib, buffer).value,
        sraw.sound_get_length_in_pcm_frames(lib, snd).value,
    )

    sraw.sound_free(lib, snd)
    rraw.rm_data_buffer_free(lib, buffer)
    rraw.resource_manager_free(lib, rm)
    raw.engine_free(lib, eng)


def test_resource_manager_view_job_slot_is_its_own() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var rm = rraw.resource_manager_alloc(lib)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, eng), MA_SUCCESS)

    # The slot is empty: posting from it, or processing it, has nothing to act on.
    assert_equal(rraw.resource_manager_post_job(lib, rm), MA_INVALID_ARGS)
    assert_equal(rraw.resource_manager_process_job(lib, rm), MA_INVALID_ARGS)

    # Uninit on a view hands it back; the manager keeps serving the engine.
    assert_equal(rraw.resource_manager_uninit(lib, rm), MA_SUCCESS)
    assert_equal(rraw.resource_manager_has_log(lib, rm).result, MA_INVALID_ARGS)
    var snd = sraw.sound_alloc(lib)
    assert_equal(sraw.sound_init_from_file(lib, snd, eng, WAV_PATH, 0), MA_SUCCESS)

    sraw.sound_free(lib, snd)
    rraw.resource_manager_free(lib, rm)
    raw.engine_free(lib, eng)


def test_resource_manager_view_notices_when_the_engine_is_uninitialised() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var rm = rraw.resource_manager_alloc(lib)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, eng), MA_SUCCESS)
    assert_equal(raw.engine_uninit(lib, eng), MA_SUCCESS)

    assert_equal(rraw.resource_manager_has_log(lib, rm).result, MA_INVALID_ARGS)
    assert_equal(rraw.resource_manager_register_file(lib, rm, WAV_PATH, 0), MA_INVALID_ARGS)
    rraw.resource_manager_free(lib, rm)
    raw.engine_free(lib, eng)


def test_resource_manager_borrow_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var rm = rraw.resource_manager_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(rraw.resource_manager_borrow_engine(lib, null_handle(), eng), MA_INVALID_ARGS)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, null_handle()), MA_INVALID_ARGS)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, cold), MA_INVALID_ARGS)
    assert_equal(rraw.resource_manager_has_log(lib, rm).result, MA_INVALID_ARGS)

    # A handle that owned a manager can become a view (the owned one is released).
    assert_equal(rraw.resource_manager_init(lib, rm), MA_SUCCESS)
    assert_equal(rraw.resource_manager_borrow_engine(lib, rm, eng), MA_SUCCESS)
    assert_true(rraw.resource_manager_has_log(lib, rm).value)

    raw.engine_free(lib, cold)
    rraw.resource_manager_free(lib, rm)
    raw.engine_free(lib, eng)


# ---------------------------------------------------------------------------
# ma_engine_node (group flavour)
# ---------------------------------------------------------------------------


def _engine_node(
    lib: MaLib,
    eng: OpaquePointer[MutUntrackedOrigin],
    flags: UInt32 = FLAGS_PASS_THROUGH,
    preallocated: Bool = False,
) raises -> OpaquePointer[MutUntrackedOrigin]:
    var n = nraw.engine_node_alloc(lib)
    assert_true(n != null_handle())
    var code: Int
    if preallocated:
        code = nraw.engine_node_init_preallocated(lib, n, eng, flags, 0, 0, 0, 0)
    else:
        code = nraw.engine_node_init(lib, n, eng, flags, 0, 0, 0, 0)
    assert_equal(code, MA_SUCCESS)
    return n


def test_engine_node_heap_size_depends_on_the_shape() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)

    var stereo = nraw.engine_node_get_heap_size(lib, eng, 0, 0, 0, 0)
    assert_equal(stereo.result, MA_SUCCESS)
    assert_true(stereo.value > UInt64(0))
    var wide = nraw.engine_node_get_heap_size(lib, eng, 0, 8, 8, 0)
    assert_equal(wide.result, MA_SUCCESS)
    assert_true(wide.value > stereo.value)
    # Smoothing volume changes needs a gainer, which needs room.
    var smooth = nraw.engine_node_get_heap_size(lib, eng, 0, 0, 0, 480)
    assert_equal(smooth.result, MA_SUCCESS)
    assert_true(smooth.value > stereo.value)

    raw.engine_free(lib, eng)


def test_engine_node_heap_size_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    var none = nraw.engine_node_get_heap_size(lib, null_handle(), 0, 0, 0, 0)
    assert_equal(none.result, MA_INVALID_ARGS)
    assert_equal(none.value, UInt64(0))
    assert_equal(nraw.engine_node_get_heap_size(lib, cold, 0, 0, 0, 0).result, MA_INVALID_ARGS)

    raw.engine_free(lib, cold)
    raw.engine_free(lib, eng)


def test_engine_node_has_one_input_and_one_output_bus_at_the_engines_channels() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var n = _engine_node(lib, eng)

    assert_equal(nraw.node_get_input_bus_count(lib, n).value, UInt32(1))
    assert_equal(nraw.node_get_output_bus_count(lib, n).value, UInt32(1))
    var channels = raw.engine_get_channels(lib, eng)
    assert_equal(nraw.node_get_input_channels(lib, n, 0).value, channels)
    assert_equal(nraw.node_get_output_channels(lib, n, 0).value, channels)
    assert_equal(nraw.node_get_state(lib, n).value, 0)    # nodes start started

    var g = _graph_view(lib, eng)
    assert_true(nraw.node_belongs_to_graph(lib, n, g).value)

    nraw.node_graph_free(lib, g)
    nraw.engine_node_free(lib, n)
    raw.engine_free(lib, eng)


def test_engine_node_channel_counts_come_from_the_config() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var n = nraw.engine_node_alloc(lib)
    assert_equal(nraw.engine_node_init(lib, n, eng, FLAGS_PASS_THROUGH, 1, 2, 0, 0), MA_SUCCESS)
    assert_equal(nraw.node_get_input_channels(lib, n, 0).value, UInt32(1))
    assert_equal(nraw.node_get_output_channels(lib, n, 0).value, UInt32(2))

    nraw.engine_node_free(lib, n)
    raw.engine_free(lib, eng)


def test_engine_node_passes_what_is_fed_to_it_to_the_endpoint() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var n = _engine_node(lib, eng)
    var src = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, src, g, 2, 0.25), MA_SUCCESS)
    assert_equal(nraw.node_attach_output_bus(lib, src, 0, n, 0), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, n, 0, g, 0), MA_SUCCESS)

    assert_true(_all_equal(_pull(lib, eng), Float32(0.25)))
    # The engine node's own output bus volume is the dial on the route.
    assert_equal(nraw.node_set_output_bus_volume(lib, n, 0, 0.5), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.125)))
    # Detaching it takes it out of the picture.
    assert_equal(nraw.node_detach_all_output_buses(lib, n), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0)))

    nraw.node_free(lib, src)
    nraw.engine_node_free(lib, n)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_engine_node_with_no_flags_runs_the_pitch_stage() raises:
    """Without NO_PITCH the node resamples, which costs it a frame of latency."""
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var n = _engine_node(lib, eng, 0)
    var src = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, src, g, 2, 0.25), MA_SUCCESS)
    assert_equal(nraw.node_attach_output_bus(lib, src, 0, n, 0), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, n, 0, g, 0), MA_SUCCESS)

    var out = _pull(lib, eng)
    assert_equal(out[0], Float32(0))
    assert_equal(out[2], Float32(0.25))

    nraw.node_free(lib, src)
    nraw.engine_node_free(lib, n)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_preallocated_engine_node_behaves_like_the_managed_one() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var managed = _engine_node(lib, eng)
    var prealloc = _engine_node(lib, eng, FLAGS_PASS_THROUGH, True)

    assert_equal(nraw.node_get_input_bus_count(lib, prealloc).value, nraw.node_get_input_bus_count(lib, managed).value)
    assert_equal(nraw.node_get_output_channels(lib, prealloc, 0).value, nraw.node_get_output_channels(lib, managed, 0).value)

    var src = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, src, g, 2, 0.5), MA_SUCCESS)
    assert_equal(nraw.node_attach_output_bus(lib, src, 0, prealloc, 0), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, prealloc, 0, g, 0), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.5)))

    # Uninit releases the shim-owned heap; the handle can be built again.
    assert_equal(nraw.engine_node_uninit(lib, prealloc), MA_SUCCESS)
    assert_equal(nraw.node_get_input_bus_count(lib, prealloc).result, MA_INVALID_ARGS)
    assert_equal(
        nraw.engine_node_init_preallocated(lib, prealloc, eng, FLAGS_PASS_THROUGH, 0, 0, 480, 0),
        MA_SUCCESS,
    )

    nraw.node_free(lib, src)
    nraw.engine_node_free(lib, prealloc)
    nraw.engine_node_free(lib, managed)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_engine_node_uninit_detaches_it() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var g = _graph_view(lib, eng)
    var n = _engine_node(lib, eng)
    var src = nraw.node_alloc(lib)
    assert_equal(nraw.node_init(lib, src, g, 2, 0.5), MA_SUCCESS)
    assert_equal(nraw.node_attach_output_bus(lib, src, 0, n, 0), MA_SUCCESS)
    assert_equal(nraw.node_attach_to_endpoint(lib, n, 0, g, 0), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0.5)))

    assert_equal(nraw.engine_node_uninit(lib, n), MA_SUCCESS)
    assert_true(_all_equal(_pull(lib, eng), Float32(0)))
    # Uninit is idempotent.
    assert_equal(nraw.engine_node_uninit(lib, n), MA_SUCCESS)

    nraw.node_free(lib, src)
    nraw.engine_node_free(lib, n)
    nraw.node_graph_free(lib, g)
    raw.engine_free(lib, eng)


def test_engine_node_init_negative_paths() raises:
    var lib = MaLib.default()
    var eng = _stopped_engine(lib)
    var n = nraw.engine_node_alloc(lib)
    var cold = raw.engine_alloc(lib)    # never initialised

    assert_equal(nraw.engine_node_init(lib, null_handle(), eng, 0, 0, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init(lib, n, null_handle(), 0, 0, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init(lib, n, cold, 0, 0, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init_preallocated(lib, null_handle(), eng, 0, 0, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init_preallocated(lib, n, null_handle(), 0, 0, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_uninit(lib, null_handle()), MA_INVALID_ARGS)
    nraw.engine_node_free(lib, null_handle())

    # A listener that does not exist cannot be pinned to (255 means "closest").
    assert_true(raw.engine_get_listener_count(lib, eng) < UInt32(200))
    assert_true(nraw.engine_node_init(lib, n, eng, 0, 0, 0, 0, 200) != MA_SUCCESS)
    assert_true(nraw.engine_node_init_preallocated(lib, n, eng, 0, 0, 0, 0, 200) != MA_SUCCESS)
    assert_equal(nraw.node_get_input_bus_count(lib, n).result, MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init(lib, n, eng, 0, 0, 0, 0, 255), MA_SUCCESS)
    assert_equal(nraw.engine_node_init(lib, n, eng, 0, 0, 0, 0, 0), MA_SUCCESS)

    # An absurd channel count is an error, not an abort inside miniaudio.
    assert_equal(nraw.engine_node_init(lib, n, eng, 0, 4096, 0, 0, 0), MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_init(lib, n, eng, 0, 0, 4096, 0, 0), MA_INVALID_ARGS)
    assert_equal(
        nraw.engine_node_init_preallocated(lib, n, eng, 0, 4096, 0, 0, 0), MA_INVALID_ARGS
    )
    assert_equal(nraw.engine_node_get_heap_size(lib, eng, 0, 4096, 0, 0).result, MA_INVALID_ARGS)
    assert_equal(nraw.engine_node_get_heap_size(lib, eng, 0, 0, 4096, 0).result, MA_INVALID_ARGS)

    raw.engine_free(lib, cold)
    nraw.engine_node_free(lib, n)
    raw.engine_free(lib, eng)


def _expect_quiet_listener_calls(lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin]) raises:
    """Setters do nothing and getters answer zeros on a handle that is not a ready engine."""
    raw.engine_listener_set_direction(lib, eng, 0, 1.0, 2.0, 3.0)
    var d = raw.engine_listener_get_direction(lib, eng, 0)
    assert_true(d.x == 0.0 and d.y == 0.0 and d.z == 0.0)
    raw.engine_listener_set_velocity(lib, eng, 0, 1.0, 2.0, 3.0)
    var v = raw.engine_listener_get_velocity(lib, eng, 0)
    assert_true(v.x == 0.0 and v.y == 0.0 and v.z == 0.0)
    raw.engine_listener_set_world_up(lib, eng, 0, 1.0, 2.0, 3.0)
    var u = raw.engine_listener_get_world_up(lib, eng, 0)
    assert_true(u.x == 0.0 and u.y == 0.0 and u.z == 0.0)
    raw.engine_listener_set_cone(lib, eng, 0, 1.0, 2.0, 0.5)
    var c = raw.engine_listener_get_cone(lib, eng, 0)
    assert_true(c.inner_angle == 0.0 and c.outer_angle == 0.0 and c.outer_gain == 0.0)
    raw.engine_listener_set_enabled(lib, eng, 0, True)
    assert_equal(raw.engine_listener_is_enabled(lib, eng, 0), 0)


def test_listener_calls_on_a_null_handle_are_quiet_no_ops() raises:
    var lib = _lib()
    _expect_quiet_listener_calls(lib, null_handle())


def test_listener_calls_on_an_uninitialised_engine_are_quiet_no_ops() raises:
    var lib = _lib()
    var eng = raw.engine_alloc(lib)    # allocated, never initialised
    _expect_quiet_listener_calls(lib, eng)
    raw.engine_free(lib, eng)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
