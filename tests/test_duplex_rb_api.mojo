"""TDD tests for the idiomatic DuplexRingBuffer API (RAII, L3 behavioural)."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.util import DuplexRingBuffer


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _stereo(frames: Int, first: Int = 1) -> List[Float32]:
    """Frame f holds (f, -f), so a swapped or shifted channel shows up."""
    var out = List[Float32]()
    for f in range(frames):
        out.append(Float32(first + f))
        out.append(Float32(-(first + f)))
    return out^


def _new() raises -> DuplexRingBuffer:
    return DuplexRingBuffer.create(
        _lib(),
        channels=2,
        sample_rate=48000,
        capture_internal_sample_rate=48000,
        capture_period_size_in_frames=240,
    )


def test_starts_with_two_periods_of_silence_queued() raises:
    var rb = _new()
    assert_equal(rb.available_read(), UInt32(480))
    assert_equal(rb.available_write(), UInt32(720))  # 5 periods = 1200 frames in all
    var head = rb.read(480)
    assert_equal(len(head), 960)
    var silent = True
    for s in head:
        if s != 0.0:
            silent = False
    assert_true(silent)


def test_capture_frames_reach_playback_in_order_after_the_silence() raises:
    var rb = _new()
    assert_equal(rb.write(_stereo(240)), UInt32(240))  # one capture period
    _ = rb.read(480)  # drain the priming
    var played = rb.read(240)
    assert_equal(len(played), 480)
    var expected = _stereo(240)
    for i in range(480):
        assert_equal(played[i], expected[i])


def test_writes_accumulate_across_calls() raises:
    var rb = _new()
    _ = rb.read(480)
    assert_equal(rb.write(_stereo(100, 1)), UInt32(100))
    assert_equal(rb.write(_stereo(100, 101)), UInt32(100))
    assert_equal(rb.available_read(), UInt32(200))
    var out = rb.read(200)
    var expected = _stereo(200)
    for i in range(400):
        assert_equal(out[i], expected[i])
    assert_equal(rb.available_read(), UInt32(0))


def test_a_write_larger_than_the_room_is_cut_short() raises:
    var rb = _new()
    var room = rb.available_write()
    var accepted = rb.write(_stereo(Int(room) + 50))
    assert_equal(accepted, room)
    assert_equal(rb.available_write(), UInt32(0))
    assert_equal(rb.write(_stereo(8)), UInt32(0))


def test_reading_past_the_queued_frames_returns_fewer() raises:
    var rb = _new()
    var out = rb.read(5000)
    assert_equal(len(out), 960)  # the 480 priming frames, 2 channels
    assert_equal(len(rb.read(10)), 0)


def test_a_partial_trailing_frame_is_not_written() raises:
    var rb = _new()
    var odd = _stereo(3)
    odd.append(Float32(99))  # half a frame
    assert_equal(rb.write(odd), UInt32(3))


def test_sizing_follows_the_rate_ratio() raises:
    var slow = DuplexRingBuffer.create(
        _lib(),
        channels=1,
        sample_rate=48000,
        capture_internal_sample_rate=24000,
        capture_period_size_in_frames=100,
    )
    # Capturing at half the playback rate: five periods become ten.
    assert_equal(slow.available_read() + slow.available_write(), UInt32(1000))


def test_unusable_configurations_raise() raises:
    with assert_raises():
        _ = DuplexRingBuffer.create(
            _lib(),
            channels=2,
            sample_rate=48000,
            capture_internal_sample_rate=48000,
            capture_period_size_in_frames=0,
        )
    with assert_raises():
        _ = DuplexRingBuffer.create(
            _lib(),
            channels=0,
            sample_rate=48000,
            capture_internal_sample_rate=48000,
            capture_period_size_in_frames=100,
        )
    with assert_raises():  # playback rate so low the priming would not fit
        _ = DuplexRingBuffer.create(
            _lib(),
            channels=2,
            sample_rate=8000,
            capture_internal_sample_rate=48000,
            capture_period_size_in_frames=600,
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
