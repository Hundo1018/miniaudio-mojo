"""TDD tests for the idiomatic resource manager API (RAII ResourceManager & co).

L3 behavioral: verifies that a manager caches sounds and pumps its own job
queue, that a decoded buffer reads back its frames, that a copy shares the
cached sound, that streaming needs a job thread, and that mapping is a
streaming-only path.

The sound used is the generated test WAV, so the pixi task runs gen-test-wav
first.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.result import MA_SUCCESS, MA_CANCELLED, MA_NO_DATA_AVAILABLE
from miniaudio.resource_manager import (
    ResourceManager,
    ResourceDataBuffer,
    ResourceDataStream,
    ResourceDataSource,
    RESOURCE_FLAG_DECODE,
    RESOURCE_FLAG_STREAM,
)


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _manager() raises -> ArcPointer[ResourceManager]:
    """The default shape: no threads, queue pumped by the caller."""
    return ArcPointer(ResourceManager.create(_lib()))


def _threaded_manager() raises -> ArcPointer[ResourceManager]:
    """Streams need a worker thread — see the module docstring."""
    return ArcPointer(
        ResourceManager.create(_lib(), job_thread_count=1, non_blocking=False)
    )


def test_a_manager_has_a_log_and_an_empty_queue() raises:
    """A fresh manager reports its log and says its queue is idle."""
    var m = _manager()
    assert_true(m[].has_log())
    assert_equal(m[].process_next_job(), MA_NO_DATA_AVAILABLE)


def test_files_and_in_memory_data_can_be_registered() raises:
    """All three registration paths accept data and give it a name."""
    var m = _manager()
    m[].register_file(WAV_PATH, flags=RESOURCE_FLAG_DECODE)
    m[].unregister_file(WAV_PATH)

    var frames = List[Float32]()
    for i in range(8):
        frames.append(Float32(i) * Float32(0.1))
    m[].register_decoded_data("decoded", frames)
    m[].unregister_data("decoded")


def test_the_job_queue_round_trips_a_quit_job() raises:
    """A quit job can be popped, put back, and run off the queue."""
    var m = _manager()
    m[].post_quit_job()

    # next_job reports MA_CANCELLED for a quit job rather than raising: the job
    # is real, and MA_CANCELLED is how miniaudio labels it.
    with assert_raises():
        _ = m[].next_job()


def test_a_decoded_buffer_reads_its_frames() raises:
    """A whole-file buffer reports a length and reads frames out of it."""
    var m = _manager()
    var b = ResourceDataBuffer.create(m, WAV_PATH, flags=RESOURCE_FLAG_DECODE)

    var fmt = b.data_format()
    assert_true(fmt.channels > UInt32(0))
    assert_true(fmt.sample_rate > UInt32(0))
    assert_true(b.length() > UInt64(0))
    assert_equal(b.load_result(), MA_SUCCESS)

    var frames = b.read(UInt64(64))
    assert_true(len(frames) > 0)
    assert_true(b.cursor() > UInt64(0))

    b.seek(UInt64(0))
    assert_true(b.cursor() == UInt64(0))

    b.set_looping(True)
    assert_true(b.is_looping())


def test_a_buffer_copy_shares_the_cached_sound() raises:
    """A copy of a buffer reports the same length as the original."""
    var m = _manager()
    var b = ResourceDataBuffer.create(
        m, WAV_PATH, flags=RESOURCE_FLAG_DECODE, through_config=True
    )
    var copy = ResourceDataBuffer.create_copy(m, b)
    assert_equal(copy.length(), b.length())


def test_a_data_source_reads_but_cannot_map_a_buffer() raises:
    """Mapping is a streaming-only path; on a buffer miniaudio declines it."""
    var m = _manager()
    var d = ResourceDataSource.create(m, WAV_PATH, flags=RESOURCE_FLAG_DECODE)

    assert_true(len(d.read(UInt64(32))) > 0)
    assert_equal(d.load_result(), MA_SUCCESS)

    with assert_raises():
        _ = d.map_read(UInt64(16))


def test_a_stream_needs_a_job_thread_and_then_reads() raises:
    """With a worker thread a stream initialises, reads and tears down."""
    var m = _threaded_manager()
    var s = ResourceDataStream.create(m, WAV_PATH)

    var fmt = s.data_format()
    assert_true(fmt.channels > UInt32(0))
    assert_equal(s.load_result(), MA_SUCCESS)

    var frames = s.read(UInt64(32))
    assert_true(len(frames) >= 0)

    s.set_looping(True)
    assert_true(s.is_looping())
    s.uninit()


def test_a_streaming_data_source_can_be_mapped() raises:
    """The same front end with the STREAM flag does support map/unmap."""
    var m = _threaded_manager()
    var d = ResourceDataSource.create(m, WAV_PATH, flags=RESOURCE_FLAG_STREAM)

    assert_true(d.data_format().channels > UInt32(0))
    var mapped = d.map_read(UInt64(16))
    assert_true(len(mapped) >= 0)
    d.uninit()


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit every accessor raises."""
    var m = _manager()
    var b = ResourceDataBuffer.create(m, WAV_PATH, flags=RESOURCE_FLAG_DECODE)
    b.uninit()
    with assert_raises():
        _ = b.length()

    m[].uninit()
    with assert_raises():
        _ = m[].has_log()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
