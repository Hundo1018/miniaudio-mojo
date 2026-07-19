"""TDD tests for the idiomatic playback device API (RAII Device).

L3 behavioral: every device runs on the null backend (deterministic, no audio
hardware). We assert observable streaming progress (frames_processed) and that
the device's RAII lifetime (which owns the source Decoder) cleans up safely.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_almost_equal,
    TestSuite,
)
from std.time import sleep
from std.memory import ArcPointer

from miniaudio import (
    Device,
    Decoder,
    DeviceJobThread,
    JobResult,
    DEVICE_STATE_STOPPED,
    DEVICE_STATE_STARTED,
    JOB_TYPE_QUIT,
    JOB_TYPE_CUSTOM,
    SAMPLE_FORMAT_F32,
    MA_SUCCESS,
)
from miniaudio.result import MA_NO_DATA_AVAILABLE, MA_CANCELLED
from miniaudio._lib import MaLib


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2

# ma_backend_null — last member of the ma_backend enum.
comptime BACKEND_NULL = Int32(14)


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def _play_briefly(lib: ArcPointer[MaLib], var source: Decoder) raises -> UInt64:
    """Open a null-backend device over `source`, run it briefly, return frames."""
    var dev = Device.play(lib, source^, use_null_backend=True)
    dev.start()
    sleep(RUN_SECONDS)
    dev.stop()
    return dev.frames_processed()


def test_play_streams_frames() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)
    assert_equal(dev.channels(), UInt32(2))
    assert_equal(dev.sample_rate(), UInt32(48000))

    dev.start()
    sleep(RUN_SECONDS)
    dev.stop()
    assert_true(dev.frames_processed() > 0)


def test_sample_rate_override() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, sample_rate=22050, use_null_backend=True)
    assert_equal(dev.sample_rate(), UInt32(22050))


def test_device_owns_decoder_and_cleans_up() raises:
    """Behavioral: the device owns the decoder; playing then dropping is safe,
    and a second device can be created afterwards."""
    var lib = _lib()
    var frames1 = _play_briefly(lib, Decoder.from_file(lib, WAV_PATH))
    assert_true(frames1 > 0)
    # First device fully torn down (its __del__ joined the audio thread); a
    # fresh device over a new decoder still works.
    var frames2 = _play_briefly(lib, Decoder.from_file(lib, WAV_PATH))
    assert_true(frames2 > 0)


def test_play_ex_selects_backend() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var backends = [BACKEND_NULL]
    var dev = Device.play_ex(lib, dec^, backends^)
    assert_equal(dev.channels(), UInt32(2))
    # The device is running on the backend we requested.
    assert_equal(dev.context_backend(), UInt32(BACKEND_NULL))


def test_state_and_is_started() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)
    assert_equal(dev.state(), DEVICE_STATE_STOPPED)
    assert_false(dev.is_started())

    dev.start()
    assert_equal(dev.state(), DEVICE_STATE_STARTED)
    assert_true(dev.is_started())

    dev.stop()
    assert_equal(dev.state(), DEVICE_STATE_STOPPED)
    assert_false(dev.is_started())


def test_master_volume_round_trip() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)

    assert_equal(dev.master_volume(), Float32(1.0))  # starts at unity gain
    dev.set_master_volume(0.5)
    assert_equal(dev.master_volume(), Float32(0.5))

    assert_almost_equal(dev.master_volume_db(), Float32(-6.0206), atol=0.01)
    dev.set_master_volume_db(0.0)
    assert_equal(dev.master_volume(), Float32(1.0))  # 0 dB == unity gain


def test_name_and_info() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)

    assert_equal(dev.name(), String("NULL Playback Device"))
    assert_true(dev.has_log())

    var info = dev.info()
    assert_equal(info.name, String("NULL Playback Device"))
    assert_true(info.is_default)
    assert_true(len(info.native_data_formats) >= 1)

    # add_native_data_format appends to the loaded snapshot.
    dev.add_native_data_format(SAMPLE_FORMAT_F32.code, 2, 44100, 0)
    var info2 = dev.info()  # re-load resets, so count returns to baseline
    assert_true(len(info2.native_data_formats) >= 1)


def test_id_equals_self() raises:
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)
    assert_true(dev.id_equals(dev))


def test_pump_renders_offline() raises:
    """`pump` drives the callback with no real-time thread — deterministic."""
    var lib = _lib()
    var dec = Decoder.from_file(lib, WAV_PATH)
    var dev = Device.play(lib, dec^, use_null_backend=True)

    var frames = UInt32(256)
    var buf = List[Float32]()
    buf.resize(Int(frames) * 2, Float32(0))

    assert_equal(dev.frames_processed(), UInt64(0))
    dev.pump(buf, frames)
    assert_true(dev.frames_processed() > UInt64(0))


def test_job_thread_post_and_drain() raises:
    var lib = _lib()
    var jt = DeviceJobThread.create(lib, no_thread=True, non_blocking=True)

    jt.post(JOB_TYPE_CUSTOM)
    var got = jt.next()
    assert_equal(got.result, MA_SUCCESS)
    assert_equal(got.code, JOB_TYPE_CUSTOM)

    # Empty non-blocking queue reports no data instead of blocking.
    assert_equal(jt.next().result, MA_NO_DATA_AVAILABLE)


def test_job_thread_quit_is_cancelled() raises:
    var lib = _lib()
    var jt = DeviceJobThread.create(lib, no_thread=True, non_blocking=True)
    jt.post(JOB_TYPE_QUIT)
    assert_equal(jt.next().result, MA_CANCELLED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
