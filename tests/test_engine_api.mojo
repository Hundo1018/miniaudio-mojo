"""TDD tests for the idiomatic engine API (RAII Engine).

L3 behavioral: every engine runs on the null backend (deterministic, no audio
hardware). We assert observable streaming progress (the engine clock advances),
volume round-trips, and RAII lifetime cleans up safely.
"""

from std.testing import assert_equal, assert_true, TestSuite
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import Engine
from miniaudio._lib import MaLib
from std.testing import assert_raises
from miniaudio.node import NodeGraph, OffsetNode, EndpointNode, EngineNode, NODE_STATE_STARTED
from miniaudio.sync import Log
from miniaudio.device import Device, DEVICE_STATE_STARTED, DEVICE_STATE_STOPPED
from miniaudio.resource_manager import ResourceManager, ResourceDataBuffer
from miniaudio.sound import Sound, SOUND_FLAG_NO_PITCH, SOUND_FLAG_NO_SPATIALIZATION


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _play_briefly(lib: ArcPointer[MaLib]) raises -> UInt64:
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    return eng.time_in_frames()


def test_engine_plays_and_clock_advances() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    assert_true(eng.sample_rate() > 0)
    assert_true(eng.channels() > 0)
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_volume_roundtrip() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.set_volume(0.5)
    assert_true(eng.volume() > 0.4 and eng.volume() < 0.6)


def test_engine_start_stop() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.stop()
    eng.start()  # restartable
    eng.play_sound(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_lifetime_sequential() raises:
    """Behavioral: an engine fully tears down; a fresh one still works."""
    var lib = _lib()
    var t1 = _play_briefly(lib)
    var t2 = _play_briefly(lib)
    assert_true(t1 > 0)
    assert_true(t2 > 0)


def test_engine_play_sound_ex() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound_ex(WAV_PATH)
    sleep(RUN_SECONDS)
    assert_true(eng.time_in_frames() > 0)


def test_engine_clock_set_get() raises:
    """Stop freezes the clock; set/get round-trips exactly (offline)."""
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.stop()
    eng.set_time_in_frames(4800)
    assert_equal(eng.time_in_frames(), UInt64(4800))
    assert_true(eng.time_in_milliseconds() > 0)
    eng.set_time_in_milliseconds(50)
    assert_true(eng.time_in_frames() > 0)


def test_engine_read_offline() raises:
    """A playing sound feeds the graph; manual read pulls it (device stopped)."""
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    eng.play_sound(WAV_PATH)
    eng.stop()  # single reader
    var buf = List[Float32]()
    var read = eng.read(buf, UInt64(128))
    assert_true(read > UInt64(0))
    assert_equal(len(buf), Int(read) * Int(eng.channels()))


def test_engine_listener_spatialization() raises:
    var lib = _lib()
    var eng = Engine.create(lib, use_null_backend=True)
    assert_true(eng.listener_count() >= UInt32(1))

    eng.set_listener_position(0, 1.0, 2.0, 3.0)
    var p = eng.listener_position(0)
    assert_true(p.x == 1.0 and p.y == 2.0 and p.z == 3.0)

    eng.set_listener_direction(0, 0.0, 0.0, -1.0)
    assert_true(eng.listener_direction(0).z == -1.0)

    eng.set_listener_cone(0, 0.5, 1.0, 0.25)
    var cone = eng.listener_cone(0)
    assert_true(cone.inner_angle == 0.5 and cone.outer_gain == 0.25)

    eng.set_listener_enabled(0, False)
    assert_true(not eng.listener_is_enabled(0))
    eng.set_listener_enabled(0, True)
    assert_true(eng.listener_is_enabled(0))

    assert_true(eng.find_closest_listener(1.0, 0.0, 0.0) < eng.listener_count())


# ---------------------------------------------------------------------------
# Borrowed views of what the engine owns, and the engine node.
#
# Each of these is a *view*: it acts on the engine's own object and dropping it
# leaves that object alone, while it keeps the engine alive for as long as it
# exists. The engine here is always stopped so the test is its only reader, and
# reads are whole periods because the engine renders whole periods.
# ---------------------------------------------------------------------------

comptime PERIOD: UInt64 = 480
comptime PASS_THROUGH: UInt32 = SOUND_FLAG_NO_PITCH | SOUND_FLAG_NO_SPATIALIZATION


def _stopped_engine() raises -> ArcPointer[Engine]:
    var eng = ArcPointer(Engine.create(_lib(), use_null_backend=True))
    eng[].stop()
    return eng^


def _period(eng: ArcPointer[Engine]) raises -> List[Float32]:
    var out = List[Float32]()
    _ = eng[].read(out, PERIOD)
    return out^


def _all_equal(samples: List[Float32], value: Float32) -> Bool:
    for i in range(len(samples)):
        if samples[i] != value:
            return False
    return True


def test_node_graph_view_is_the_engines_graph() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    assert_equal(graph[].channels(), eng[].channels())
    assert_equal(graph[].endpoint_input_bus_count(), UInt32(1))

    # Nodes built against the view are heard through the engine.
    var node = OffsetNode.create(graph, offset=Float32(0.25))
    node.attach_to_endpoint()
    assert_true(_all_equal(_period(eng), Float32(0.25)))
    assert_true(node.belongs_to(graph))

    # The clock is shared: setting it on one side reads back on the other.
    eng[].set_time_in_frames(960)
    assert_equal(graph[].time(), UInt64(960))
    graph[].set_time(4800)
    assert_equal(eng[].time_in_frames(), UInt64(4800))


def test_node_graph_view_reads_like_the_engine() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var node = OffsetNode.create(graph, offset=Float32(0.5))
    node.attach_to_endpoint()

    var frames = graph[].read(PERIOD)
    assert_equal(len(frames), Int(PERIOD) * 2)
    assert_true(_all_equal(frames, Float32(0.5)))
    assert_true(node.belongs_to(graph))


def test_node_graph_view_keeps_the_engine_alive() raises:
    """The engine's last owner goes away; the view (and a node on it) still works."""
    var graph = ArcPointer(_graph_of_a_vanished_engine())
    assert_equal(graph[].channels(), UInt32(2))
    var node = OffsetNode.create(graph, offset=Float32(0.25))
    node.attach_to_endpoint()
    var frames = graph[].read(PERIOD)
    assert_true(_all_equal(frames, Float32(0.25)))
    assert_true(node.belongs_to(graph))


def _graph_of_a_vanished_engine() raises -> NodeGraph:
    var eng = _stopped_engine()
    return NodeGraph.of_engine(eng)


def test_node_graph_view_uninit_leaves_the_engines_graph_alone() raises:
    var eng = _stopped_engine()
    var view = NodeGraph.of_engine(eng)
    view.uninit()
    with assert_raises():
        _ = view.channels()
    assert_equal(eng[].channels(), UInt32(2))

    var again = ArcPointer(NodeGraph.of_engine(eng))
    var node = OffsetNode.create(again, offset=Float32(0.5))
    node.attach_to_endpoint()
    assert_true(_all_equal(_period(eng), Float32(0.5)))
    assert_true(node.belongs_to(again))


def test_endpoint_view_is_the_endpoint_of_the_engines_graph() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var endpoint = EndpointNode.of_engine(eng)

    assert_true(endpoint.is_endpoint_of(graph))
    assert_true(endpoint.belongs_to(graph))
    assert_equal(endpoint.input_bus_count(), UInt32(1))
    assert_equal(endpoint.input_channels(), eng[].channels())
    assert_equal(endpoint.state(), NODE_STATE_STARTED)

    # A node of the same graph is not its endpoint, and nor is another engine's.
    var node = OffsetNode.create(graph, offset=Float32(0))
    var stranger = ArcPointer(NodeGraph.of_engine(_stopped_engine()))
    assert_true(not endpoint.is_endpoint_of(stranger))
    assert_true(node.belongs_to(graph))


def test_endpoint_view_volume_is_the_engines_volume() raises:
    var eng = _stopped_engine()
    var endpoint = EndpointNode.of_engine(eng)

    assert_equal(endpoint.volume(), eng[].volume())
    endpoint.set_volume(Float32(0.5))
    assert_equal(eng[].volume(), Float32(0.5))
    eng[].set_volume(Float32(0.25))
    assert_equal(endpoint.volume(), Float32(0.25))


def test_a_node_attached_to_the_endpoint_view_reaches_the_output() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var endpoint = EndpointNode.of_engine(eng)
    var node = OffsetNode.create(graph, offset=Float32(0.75))
    node.attach_to(endpoint)

    assert_true(_all_equal(_period(eng), Float32(0.75)))
    # The endpoint's time is the engine's time.
    assert_true(endpoint.time() > UInt64(0))
    assert_equal(endpoint.output_bus_count(), UInt32(1))
    assert_equal(endpoint.output_channels(), eng[].channels())
    assert_true(node.belongs_to(graph))


def test_endpoint_view_uninit_leaves_the_endpoint_alone() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var endpoint = EndpointNode.of_engine(eng)
    endpoint.uninit()
    with assert_raises():
        _ = endpoint.input_bus_count()
    assert_equal(graph[].endpoint_input_bus_count(), UInt32(1))


def test_log_view_posts_to_the_engines_own_log() raises:
    var eng = _stopped_engine()
    var log = Log.of_engine(eng)
    log.register_callback()
    var before = log.message_count()
    log.post("hello from the view")
    log.postf("value: %s", "x")
    log.postv("value: %s", "y")
    assert_equal(log.message_count(), before + UInt32(3))

    # A second view of the same log hears the same stream.
    var other = Log.of_engine(eng)
    other.post("from the other view")
    assert_equal(log.message_count(), before + UInt32(4))

    log.unregister_callback()
    other.post("after unregister")
    assert_equal(log.message_count(), before + UInt32(4))


def test_dropping_a_log_view_unregisters_its_callback() raises:
    var eng = _stopped_engine()
    var observer = Log.of_engine(eng)
    _drop_a_registered_log_view(eng)
    # If the dropped view's callback were still registered this would call freed memory.
    observer.post("still fine")
    observer.post("really")


def _drop_a_registered_log_view(eng: ArcPointer[Engine]) raises:
    var doomed = Log.of_engine(eng)
    doomed.register_callback()
    doomed.post("last words")


def test_log_view_keeps_the_engine_alive() raises:
    var log = _log_of_a_vanished_engine()
    log.register_callback()
    log.post("engine's last owner is gone")
    assert_true(log.message_count() >= UInt32(1))


def _log_of_a_vanished_engine() raises -> Log:
    return Log.of_engine(_stopped_engine())


def test_device_view_follows_the_engines_device() raises:
    var eng = ArcPointer(Engine.create(_lib(), use_null_backend=True))    # running
    var device = Device.of_engine(eng)

    assert_equal(device.state(), DEVICE_STATE_STARTED)
    assert_true(device.is_started())
    assert_equal(device.sample_rate(), eng[].sample_rate())
    assert_equal(device.channels(), eng[].channels())
    assert_true(device.name().byte_length() > 0)
    assert_true(device.has_log())

    # Stopping the engine stops the very device the view stands for.
    eng[].stop()
    assert_equal(device.state(), DEVICE_STATE_STOPPED)
    assert_true(not device.is_started())
    device.start()
    assert_equal(device.state(), DEVICE_STATE_STARTED)
    device.stop()
    assert_equal(device.state(), DEVICE_STATE_STOPPED)
    assert_equal(device.frames_processed(), UInt64(0))    # a view has no decoder to count


def test_device_view_master_volume_round_trips() raises:
    var eng = _stopped_engine()
    var device = Device.of_engine(eng)
    device.set_master_volume(Float32(0.5))
    assert_equal(device.master_volume(), Float32(0.5))
    device.set_master_volume_db(Float32(-6.0))
    assert_true(device.master_volume_db() < Float32(-5.0))

    var info = device.info()
    assert_true(info.name.byte_length() > 0)
    var twin = Device.of_engine(eng)
    assert_true(device.id_equals(twin))


def test_pumping_the_device_view_renders_the_engines_graph() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var node = OffsetNode.create(graph, offset=Float32(0.25))
    node.attach_to_endpoint()

    var device = Device.of_engine(eng)
    var out = List[Float32]()
    out.resize(Int(PERIOD) * 2, Float32(0))
    device.pump(out, UInt32(PERIOD))
    assert_true(_all_equal(out, Float32(0.25)))
    assert_true(node.belongs_to(graph))


def test_device_view_keeps_the_engine_alive() raises:
    var device = _device_of_a_vanished_engine()
    assert_equal(device.channels(), UInt32(2))
    assert_true(device.is_started())


def _device_of_a_vanished_engine() raises -> Device:
    return Device.of_engine(ArcPointer(Engine.create(_lib(), use_null_backend=True)))


def test_resource_manager_view_is_the_manager_the_engines_sounds_use() raises:
    var eng = _stopped_engine()
    var manager = ResourceManager.of_engine(eng)
    assert_true(manager.has_log())

    var pcm = List[Float32]()
    pcm.resize(Int(PERIOD) * 2, Float32(0.5))
    with assert_raises():
        _ = Sound.from_file(eng, "registered://tone")
    manager.register_decoded_data(
        "registered://tone", pcm, channels=2, sample_rate=eng[].sample_rate()
    )
    # Registered through the view, visible to the engine: it is one manager.
    var snd = Sound.from_file(eng, "registered://tone")
    assert_equal(snd.length_in_frames(), PERIOD)

    # Unregistering is also done through the view (the sound already built keeps
    # its own reference to the data).
    manager.unregister_data("registered://tone")
    assert_equal(snd.length_in_frames(), PERIOD)
    # miniaudio does not copy registered frames; keep them alive to here.
    assert_equal(len(pcm), Int(PERIOD) * 2)


def test_data_objects_built_against_the_resource_manager_view() raises:
    var eng = _stopped_engine()
    var manager = ArcPointer(ResourceManager.of_engine(eng))
    var buffer = ResourceDataBuffer.create(manager, WAV_PATH)
    var snd = Sound.from_file(eng, WAV_PATH)
    assert_equal(buffer.length(), snd.length_in_frames())
    assert_true(len(buffer.read(UInt64(16))) > 0)


def test_resource_manager_view_keeps_the_engine_alive() raises:
    var manager = _manager_of_a_vanished_engine()
    assert_true(manager.has_log())
    manager.register_file(WAV_PATH)


def _manager_of_a_vanished_engine() raises -> ResourceManager:
    return ResourceManager.of_engine(_stopped_engine())


def test_resource_manager_view_uninit_leaves_the_manager_alone() raises:
    var eng = _stopped_engine()
    var manager = ResourceManager.of_engine(eng)
    manager.uninit()
    with assert_raises():
        _ = manager.has_log()
    var snd = Sound.from_file(eng, WAV_PATH)
    assert_true(snd.length_in_frames() > UInt64(0))


# ---- EngineNode ----


def test_engine_node_heap_size_depends_on_its_shape() raises:
    var eng = _stopped_engine()
    var stereo = EngineNode.heap_size(eng)
    assert_true(stereo > UInt64(0))
    assert_true(EngineNode.heap_size(eng, channels_in=8, channels_out=8) > stereo)
    assert_true(EngineNode.heap_size(eng, volume_smooth_time=480) > stereo)


def test_engine_node_is_one_input_and_one_output_at_the_engines_width() raises:
    var eng = _stopped_engine()
    var node = EngineNode.create(eng, flags=PASS_THROUGH)
    assert_equal(node.input_bus_count(), UInt32(1))
    assert_equal(node.output_bus_count(), UInt32(1))
    assert_equal(node.input_channels(), eng[].channels())
    assert_equal(node.output_channels(), eng[].channels())
    assert_equal(node.state(), NODE_STATE_STARTED)
    assert_true(node.belongs_to(ArcPointer(NodeGraph.of_engine(eng))))


def test_engine_node_channels_come_from_the_arguments() raises:
    var eng = _stopped_engine()
    var node = EngineNode.create(eng, flags=PASS_THROUGH, channels_in=1, channels_out=2)
    assert_equal(node.input_channels(), UInt32(1))
    assert_equal(node.output_channels(), UInt32(2))


def test_engine_node_passes_what_is_fed_to_it_to_the_endpoint() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var node = EngineNode.create(eng, flags=PASS_THROUGH)
    var source = OffsetNode.create(graph, offset=Float32(0.25))
    source.attach_to(node)
    node.attach_to_endpoint()

    assert_true(_all_equal(_period(eng), Float32(0.25)))
    # The node's output bus volume is the dial on the route.
    node.set_volume(Float32(0.5))
    assert_equal(node.volume(), Float32(0.5))
    assert_true(_all_equal(_period(eng), Float32(0.125)))
    # Detached, it contributes nothing.
    node.detach_all()
    assert_equal(len(_period(eng)), 0)
    assert_true(source.belongs_to(graph))


def test_engine_nodes_chain() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var first = EngineNode.create(eng, flags=PASS_THROUGH)
    var second = EngineNode.create(eng, flags=PASS_THROUGH)
    var source = OffsetNode.create(graph, offset=Float32(0.5))
    source.attach_to(first)
    first.attach_to(second)
    second.attach_to_endpoint()
    first.set_volume(Float32(0.5))
    second.set_volume(Float32(0.5))

    assert_true(_all_equal(_period(eng), Float32(0.125)))
    # Keep every node in use until after the read: a dropped node detaches.
    assert_true(source.belongs_to(graph))
    assert_true(first.belongs_to(graph))
    assert_true(second.belongs_to(graph))


def test_engine_node_into_the_endpoint_view() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var endpoint = EndpointNode.of_engine(eng)
    var node = EngineNode.create(eng, flags=PASS_THROUGH)
    var source = OffsetNode.create(graph, offset=Float32(0.5))
    source.attach_to(node)
    node.attach_to(endpoint)
    assert_true(_all_equal(_period(eng), Float32(0.5)))
    assert_true(source.belongs_to(graph))
    assert_true(node.belongs_to(graph))


def test_engine_node_without_no_pitch_resamples() raises:
    """With the pitch stage on, the node's resampler costs it a frame of latency."""
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var node = EngineNode.create(eng)
    var source = OffsetNode.create(graph, offset=Float32(0.25))
    source.attach_to(node)
    node.attach_to_endpoint()

    var out = _period(eng)
    assert_equal(out[0], Float32(0))
    assert_equal(out[2], Float32(0.25))
    assert_true(source.belongs_to(graph))
    assert_true(node.belongs_to(graph))


def test_preallocated_engine_node_behaves_like_the_managed_one() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var managed = EngineNode.create(eng, flags=PASS_THROUGH)
    var prealloc = EngineNode.create(eng, flags=PASS_THROUGH, preallocated=True)
    assert_equal(prealloc.input_bus_count(), managed.input_bus_count())
    assert_equal(prealloc.output_channels(), managed.output_channels())

    var source = OffsetNode.create(graph, offset=Float32(0.5))
    source.attach_to(prealloc)
    prealloc.attach_to_endpoint()
    assert_true(_all_equal(_period(eng), Float32(0.5)))
    assert_true(source.belongs_to(graph))
    assert_true(prealloc.belongs_to(graph))


def test_engine_node_uninit_detaches_it() raises:
    var eng = _stopped_engine()
    var graph = ArcPointer(NodeGraph.of_engine(eng))
    var node = EngineNode.create(eng, flags=PASS_THROUGH)
    var source = OffsetNode.create(graph, offset=Float32(0.5))
    source.attach_to(node)
    node.attach_to_endpoint()
    assert_true(_all_equal(_period(eng), Float32(0.5)))

    node.uninit()
    assert_equal(len(_period(eng)), 0)
    with assert_raises():
        _ = node.input_bus_count()
    assert_true(source.belongs_to(graph))


def test_engine_node_rejects_bad_arguments() raises:
    var eng = _stopped_engine()
    with assert_raises():
        _ = EngineNode.create(eng, pinned_listener_index=200)    # no such listener
    with assert_raises():
        _ = EngineNode.create(eng, channels_in=4096)
    with assert_raises():
        _ = EngineNode.heap_size(eng, channels_out=4096)
    # 255 means "the closest listener" and is fine.
    var node = EngineNode.create(eng, pinned_listener_index=255)
    assert_equal(node.input_bus_count(), UInt32(1))


def test_engine_node_keeps_the_engine_alive() raises:
    var node = _engine_node_of_a_vanished_engine()
    assert_equal(node.input_bus_count(), UInt32(1))
    node.attach_to_endpoint()


def _engine_node_of_a_vanished_engine() raises -> EngineNode:
    return EngineNode.create(_stopped_engine(), flags=PASS_THROUGH)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
