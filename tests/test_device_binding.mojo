"""TDD contract tests for the device BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: every device runs on miniaudio's NULL
backend (use_null_backend=True), which drives the shim-owned data callback on a
real-time timer thread with no audio hardware. The callback pulls f32 PCM from a
decoder, so we assert observable progress (frames_processed + decoder cursor).
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.time import sleep

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import (
    MA_SUCCESS,
    MA_INVALID_ARGS,
    MA_OUT_OF_RANGE,
    MA_NO_DATA_AVAILABLE,
    MA_CANCELLED,
)
import miniaudio._ffi.decoder_raw as draw
import miniaudio._ffi.device_raw as raw
from support.wav_fixtures import embedded_wav_stereo_2frames


comptime FMT_F32 = 5
comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime RUN_SECONDS = 0.2

# ma_backend_null — last member of the ma_backend enum.
comptime BACKEND_NULL = Int32(14)
# ma_device_type_playback.
comptime DEVICE_TYPE_PLAYBACK = 1
# ma_device_state codes.
comptime STATE_UNINITIALIZED = 0
comptime STATE_STOPPED = 1
comptime STATE_STARTED = 2
# ma_job_type codes.
comptime JOB_QUIT = UInt16(0)
comptime JOB_CUSTOM = UInt16(1)
# MA_JOB_QUEUE_FLAG_NON_BLOCKING — without it, `next` blocks on an empty queue.
comptime JOB_QUEUE_NON_BLOCKING = UInt32(1)


def _lib() raises -> MaLib:
    return MaLib.default()


def _null_device(lib: MaLib, dec: OpaquePointer[MutUntrackedOrigin]) raises -> OpaquePointer[MutUntrackedOrigin]:
    """Allocates + inits a null-backend playback device pulling from `dec`."""
    var dev = raw.device_alloc(lib)
    assert_true(dev != null_handle())
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    return dev


def _file_decoder(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var dec = draw.decoder_alloc(lib)
    assert_equal(
        draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS
    )
    return dec


def test_playback_pulls_from_decoder() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)

    var dev = raw.device_alloc(lib)
    assert_true(dev != null_handle())
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    assert_equal(raw.device_get_channels(lib, dev), UInt32(2))
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(48000))

    assert_equal(raw.device_start(lib, dev), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_equal(raw.device_stop(lib, dev), MA_SUCCESS)

    # The null backend drove the callback -> frames flowed and the decoder advanced.
    assert_true(raw.device_get_frames_processed(lib, dev) > 0)
    assert_true(draw.decoder_get_cursor_in_pcm_frames(lib, dec).value > 0)

    assert_equal(raw.device_uninit(lib, dev), MA_SUCCESS)
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_eof_tail_is_zero_filled() raises:
    """Source shorter than one period: callback zero-fills the tail (coverage)."""
    var lib = _lib()
    var data = embedded_wav_stereo_2frames()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_memory(lib, dec, data, FMT_F32, 2, 8000), MA_SUCCESS)

    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    assert_equal(raw.device_start(lib, dev), MA_SUCCESS)
    sleep(RUN_SECONDS)
    assert_equal(raw.device_stop(lib, dev), MA_SUCCESS)

    # The 2 source frames are read once; later callbacks read 0 (tail zeroed).
    assert_true(raw.device_get_frames_processed(lib, dev) >= 1)

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)
    _ = data  # keep the backing bytes alive until after playback


def test_null_device_ops_invalid_args() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, null_handle(), dec, 0, True),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.device_start(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_stop(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.device_get_channels(lib, null_handle()), UInt32(0))
    assert_equal(raw.device_get_sample_rate(lib, null_handle()), UInt32(0))
    assert_equal(raw.device_get_frames_processed(lib, null_handle()), UInt64(0))
    draw.decoder_free(lib, dec)


def test_init_with_null_decoder_invalid() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, null_handle(), 0, True),
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)


def test_init_with_uninitialized_decoder_invalid() raises:
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)  # allocated but not initialised
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True),
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_start_stop_before_init_invalid() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_equal(raw.device_start(lib, dev), MA_INVALID_ARGS)
    assert_equal(raw.device_stop(lib, dev), MA_INVALID_ARGS)
    raw.device_free(lib, dev)


def test_uninit_uninitialized_is_success() raises:
    var lib = _lib()
    var dev = raw.device_alloc(lib)
    assert_true(dev != null_handle())
    assert_equal(raw.device_uninit(lib, dev), MA_SUCCESS)
    raw.device_free(lib, dev)


def test_free_null_handle_is_noop() raises:
    var lib = _lib()
    raw.device_free(lib, null_handle())  # must not crash


def test_reinit_and_free_initialized() raises:
    """Re-init auto-uninits the previous device; then free an initialized handle."""
    var lib = _lib()
    var dec = draw.decoder_alloc(lib)
    assert_equal(draw.decoder_init_file(lib, dec, WAV_PATH, FMT_F32, 2, 48000), MA_SUCCESS)
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 0, True), MA_SUCCESS
    )
    # Re-init on the same handle (with a sample-rate override): shim uninits first.
    assert_equal(
        raw.device_init_playback_from_decoder(lib, dev, dec, 22050, True), MA_SUCCESS
    )
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(22050))
    # Free an initialised device without an explicit uninit.
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_init_ex_selects_null_backend() raises:
    """The init_ex path takes an explicit backend priority list, not a context."""
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = raw.device_alloc(lib)
    var backends = [BACKEND_NULL]
    assert_equal(
        raw.device_init_ex_playback_from_decoder(lib, dev, dec, backends, 0),
        MA_SUCCESS,
    )
    assert_equal(raw.device_get_channels(lib, dev), UInt32(2))
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(48000))

    # The device really is running on the backend we asked for.
    var backend = raw.device_get_context_backend(lib, dev)
    assert_equal(backend.result, MA_SUCCESS)
    assert_equal(backend.value, UInt32(BACKEND_NULL))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_init_ex_sample_rate_override() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = raw.device_alloc(lib)
    var backends = [BACKEND_NULL]
    assert_equal(
        raw.device_init_ex_playback_from_decoder(lib, dev, dec, backends, 22050),
        MA_SUCCESS,
    )
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(22050))
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_init_ex_invalid_args() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var backends = [BACKEND_NULL]
    # Null device handle.
    assert_equal(
        raw.device_init_ex_playback_from_decoder(
            lib, null_handle(), dec, backends, 0
        ),
        MA_INVALID_ARGS,
    )
    # Null decoder handle.
    var dev = raw.device_alloc(lib)
    assert_equal(
        raw.device_init_ex_playback_from_decoder(
            lib, dev, null_handle(), backends, 0
        ),
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_state_and_is_started_track_lifecycle() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_get_state(lib, dev), STATE_STOPPED)
    assert_false(raw.device_is_started(lib, dev))

    assert_equal(raw.device_start(lib, dev), MA_SUCCESS)
    assert_equal(raw.device_get_state(lib, dev), STATE_STARTED)
    assert_true(raw.device_is_started(lib, dev))

    assert_equal(raw.device_stop(lib, dev), MA_SUCCESS)
    assert_equal(raw.device_get_state(lib, dev), STATE_STOPPED)
    assert_false(raw.device_is_started(lib, dev))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_state_null_and_uninitialized_sentinels() raises:
    var lib = _lib()
    assert_equal(raw.device_get_state(lib, null_handle()), STATE_UNINITIALIZED)
    assert_false(raw.device_is_started(lib, null_handle()))
    # Allocated but never initialised reports the same sentinel.
    var dev = raw.device_alloc(lib)
    assert_equal(raw.device_get_state(lib, dev), STATE_UNINITIALIZED)
    assert_false(raw.device_is_started(lib, dev))
    raw.device_free(lib, dev)


def test_master_volume_round_trip() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    # Devices start at unity gain.
    var initial = raw.device_get_master_volume(lib, dev)
    assert_equal(initial.result, MA_SUCCESS)
    assert_equal(initial.value, Float32(1.0))

    assert_equal(raw.device_set_master_volume(lib, dev, 0.25), MA_SUCCESS)
    var v = raw.device_get_master_volume(lib, dev)
    assert_equal(v.result, MA_SUCCESS)
    assert_equal(v.value, Float32(0.25))

    # 0.0 is a legitimate value, not an error sentinel.
    assert_equal(raw.device_set_master_volume(lib, dev, 0.0), MA_SUCCESS)
    var silent = raw.device_get_master_volume(lib, dev)
    assert_equal(silent.result, MA_SUCCESS)
    assert_equal(silent.value, Float32(0.0))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_master_volume_db_round_trip() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    # Unity gain is 0 dB.
    var initial = raw.device_get_master_volume_db(lib, dev)
    assert_equal(initial.result, MA_SUCCESS)
    assert_equal(initial.value, Float32(0.0))

    assert_equal(raw.device_set_master_volume_db(lib, dev, -6.0), MA_SUCCESS)
    var db = raw.device_get_master_volume_db(lib, dev)
    assert_equal(db.result, MA_SUCCESS)
    assert_true(db.value < Float32(-5.9) and db.value > Float32(-6.1))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_master_volume_null_handle_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.device_set_master_volume(lib, null_handle(), 0.5), MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_get_master_volume(lib, null_handle()).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_set_master_volume_db(lib, null_handle(), -6.0), MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_get_master_volume_db(lib, null_handle()).result, MA_INVALID_ARGS
    )


def test_get_name_returns_null_backend_name() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    var name = raw.device_get_name(lib, dev, DEVICE_TYPE_PLAYBACK)
    assert_equal(name.result, MA_SUCCESS)
    assert_equal(name.value, String("NULL Playback Device"))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_get_name_null_handle_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.device_get_name(lib, null_handle(), DEVICE_TYPE_PLAYBACK).result,
        MA_INVALID_ARGS,
    )


def test_info_load_and_accessors() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_info_load(lib, dev, DEVICE_TYPE_PLAYBACK), MA_SUCCESS)

    var name = raw.device_info_name(lib, dev)
    assert_equal(name.result, MA_SUCCESS)
    assert_equal(name.value, String("NULL Playback Device"))

    var is_default = raw.device_info_is_default(lib, dev)
    assert_equal(is_default.result, MA_SUCCESS)
    assert_true(is_default.value)  # the null backend's only device

    var count = raw.device_info_native_data_format_count(lib, dev)
    assert_equal(count.result, MA_SUCCESS)
    assert_true(count.value >= UInt32(1))

    var first = raw.device_info_native_data_format(lib, dev, 0)
    assert_equal(first.result, MA_SUCCESS)

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_info_accessors_before_load_invalid_args() raises:
    """Accessors fail until a successful info_load snapshots the device info."""
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_info_name(lib, dev).result, MA_INVALID_ARGS)
    assert_equal(raw.device_info_is_default(lib, dev).result, MA_INVALID_ARGS)
    assert_equal(
        raw.device_info_native_data_format_count(lib, dev).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_info_native_data_format(lib, dev, 0).result, MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_info_add_native_data_format(lib, dev, FMT_F32, 2, 44100, 0),
        MA_INVALID_ARGS,
    )

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_info_load_null_handle_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.device_info_load(lib, null_handle(), DEVICE_TYPE_PLAYBACK),
        MA_INVALID_ARGS,
    )


def test_info_add_native_data_format_appends() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_info_load(lib, dev, DEVICE_TYPE_PLAYBACK), MA_SUCCESS)
    var before = raw.device_info_native_data_format_count(lib, dev)
    assert_equal(before.result, MA_SUCCESS)

    assert_equal(
        raw.device_info_add_native_data_format(lib, dev, FMT_F32, 2, 44100, 0),
        MA_SUCCESS,
    )
    var after = raw.device_info_native_data_format_count(lib, dev)
    assert_equal(after.result, MA_SUCCESS)
    assert_equal(after.value, before.value + UInt32(1))

    # The appended entry reads back exactly as written.
    var added = raw.device_info_native_data_format(lib, dev, after.value - 1)
    assert_equal(added.result, MA_SUCCESS)
    assert_equal(added.format, FMT_F32)
    assert_equal(added.channels, UInt32(2))
    assert_equal(added.sample_rate, UInt32(44100))
    assert_equal(added.flags, UInt32(0))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_info_native_data_format_index_out_of_range() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_info_load(lib, dev, DEVICE_TYPE_PLAYBACK), MA_SUCCESS)
    var count = raw.device_info_native_data_format_count(lib, dev)
    assert_equal(count.result, MA_SUCCESS)
    assert_equal(
        raw.device_info_native_data_format(lib, dev, count.value).result,
        MA_INVALID_ARGS,
    )

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_info_add_native_data_format_until_full() raises:
    """Appending past the fixed-capacity array reports MA_OUT_OF_RANGE."""
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    assert_equal(raw.device_info_load(lib, dev, DEVICE_TYPE_PLAYBACK), MA_SUCCESS)
    # The snapshot array holds 64 entries; keep appending until it's full.
    var saw_full = False
    for _i in range(128):
        var code = raw.device_info_add_native_data_format(
            lib, dev, FMT_F32, 2, 48000, 0
        )
        if code == MA_OUT_OF_RANGE:
            saw_full = True
            break
        assert_equal(code, MA_SUCCESS)
    assert_true(saw_full)
    # Once full, the count is pinned at the capacity.
    var count = raw.device_info_native_data_format_count(lib, dev)
    assert_equal(count.result, MA_SUCCESS)
    assert_equal(count.value, UInt32(64))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_init_ex_reinit_same_handle() raises:
    """Re-init via init_ex on an already-initialised handle uninits the old one."""
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = raw.device_alloc(lib)
    var backends = [BACKEND_NULL]
    assert_equal(
        raw.device_init_ex_playback_from_decoder(lib, dev, dec, backends, 0),
        MA_SUCCESS,
    )
    # Second init on the same handle (with an override) must succeed cleanly.
    assert_equal(
        raw.device_init_ex_playback_from_decoder(lib, dev, dec, backends, 22050),
        MA_SUCCESS,
    )
    assert_equal(raw.device_get_sample_rate(lib, dev), UInt32(22050))
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_id_equal_same_device_is_true() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    var eq = raw.device_id_equal(lib, dev, dev, DEVICE_TYPE_PLAYBACK)
    assert_equal(eq.result, MA_SUCCESS)
    assert_true(eq.value)

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_id_equal_null_handle_invalid_args() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)
    assert_equal(
        raw.device_id_equal(lib, dev, null_handle(), DEVICE_TYPE_PLAYBACK).result,
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.device_id_equal(lib, null_handle(), dev, DEVICE_TYPE_PLAYBACK).result,
        MA_INVALID_ARGS,
    )
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_has_log_and_context_backend_null_handle_invalid_args() raises:
    var lib = _lib()
    assert_equal(raw.device_has_log(lib, null_handle()).result, MA_INVALID_ARGS)
    assert_equal(
        raw.device_get_context_backend(lib, null_handle()).result, MA_INVALID_ARGS
    )


def test_has_log_on_initialized_device() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)
    var has_log = raw.device_has_log(lib, dev)
    assert_equal(has_log.result, MA_SUCCESS)
    assert_true(has_log.value)  # every device borrows its context's log
    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_handle_backend_data_callback_drives_callback() raises:
    """Drives the data callback synchronously, as a backend would — no timer thread.

    This is the deterministic counterpart to start()/sleep()/stop(): frames flow
    because we pumped them, not because a real-time thread happened to fire.
    """
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    var frames = UInt32(128)
    var buf = List[Float32]()
    buf.resize(Int(frames) * 2, Float32(0))

    assert_equal(raw.device_get_frames_processed(lib, dev), UInt64(0))
    assert_equal(
        raw.device_handle_backend_data_callback(lib, dev, buf, frames), MA_SUCCESS
    )
    # The shim callback pulled from the decoder and the decoder advanced.
    assert_true(raw.device_get_frames_processed(lib, dev) > UInt64(0))
    assert_true(draw.decoder_get_cursor_in_pcm_frames(lib, dec).value > UInt64(0))

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_handle_backend_data_callback_invalid_args() raises:
    var lib = _lib()
    var dec = _file_decoder(lib)
    var dev = _null_device(lib, dec)

    var buf = List[Float32]()
    buf.resize(8, Float32(0))
    # miniaudio rejects a zero frame count outright.
    assert_equal(
        raw.device_handle_backend_data_callback(lib, dev, buf, 0), MA_INVALID_ARGS
    )
    # Null device handle.
    assert_equal(
        raw.device_handle_backend_data_callback(lib, null_handle(), buf, 4),
        MA_INVALID_ARGS,
    )

    raw.device_free(lib, dev)
    draw.decoder_free(lib, dec)


def test_job_thread_post_and_next_round_trip() raises:
    """With no_thread=1 the queue is caller-drained, so this is deterministic."""
    var lib = _lib()
    var jt = raw.device_job_thread_alloc(lib)
    assert_true(jt != null_handle())
    assert_equal(
        raw.device_job_thread_init(lib, jt, True, 8, JOB_QUEUE_NON_BLOCKING),
        MA_SUCCESS,
    )

    assert_equal(raw.device_job_thread_post(lib, jt, JOB_CUSTOM), MA_SUCCESS)
    var job = raw.device_job_thread_next(lib, jt)
    assert_equal(job.result, MA_SUCCESS)
    assert_equal(job.value, UInt32(JOB_CUSTOM))

    assert_equal(raw.device_job_thread_uninit(lib, jt), MA_SUCCESS)
    raw.device_job_thread_free(lib, jt)


def test_job_thread_next_on_empty_queue_has_no_data() raises:
    var lib = _lib()
    var jt = raw.device_job_thread_alloc(lib)
    assert_equal(
        raw.device_job_thread_init(lib, jt, True, 8, JOB_QUEUE_NON_BLOCKING),
        MA_SUCCESS,
    )
    # Non-blocking queue: draining an empty queue reports no data rather than blocking.
    assert_equal(raw.device_job_thread_next(lib, jt).result, MA_NO_DATA_AVAILABLE)
    raw.device_job_thread_free(lib, jt)


def test_job_thread_quit_job_is_cancelled() raises:
    """A quit job is reported as MA_CANCELLED and left in the queue."""
    var lib = _lib()
    var jt = raw.device_job_thread_alloc(lib)
    assert_equal(
        raw.device_job_thread_init(lib, jt, True, 8, JOB_QUEUE_NON_BLOCKING),
        MA_SUCCESS,
    )
    assert_equal(raw.device_job_thread_post(lib, jt, JOB_QUIT), MA_SUCCESS)
    assert_equal(raw.device_job_thread_next(lib, jt).result, MA_CANCELLED)
    raw.device_job_thread_free(lib, jt)


def test_job_thread_uninit_is_idempotent_and_reinit_works() raises:
    var lib = _lib()
    var jt = raw.device_job_thread_alloc(lib)
    assert_equal(
        raw.device_job_thread_init(lib, jt, True, 8, JOB_QUEUE_NON_BLOCKING),
        MA_SUCCESS,
    )
    assert_equal(raw.device_job_thread_uninit(lib, jt), MA_SUCCESS)
    assert_equal(raw.device_job_thread_uninit(lib, jt), MA_SUCCESS)
    # Re-init on the same handle.
    assert_equal(
        raw.device_job_thread_init(lib, jt, True, 8, JOB_QUEUE_NON_BLOCKING),
        MA_SUCCESS,
    )
    assert_equal(raw.device_job_thread_post(lib, jt, JOB_CUSTOM), MA_SUCCESS)
    raw.device_job_thread_free(lib, jt)


def test_job_thread_null_and_uninitialized_invalid_args() raises:
    var lib = _lib()
    assert_equal(
        raw.device_job_thread_init(lib, null_handle(), True, 8, 0), MA_INVALID_ARGS
    )
    assert_equal(raw.device_job_thread_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(
        raw.device_job_thread_post(lib, null_handle(), JOB_CUSTOM), MA_INVALID_ARGS
    )
    assert_equal(
        raw.device_job_thread_next(lib, null_handle()).result, MA_INVALID_ARGS
    )
    # Allocated but never initialised.
    var jt = raw.device_job_thread_alloc(lib)
    assert_equal(raw.device_job_thread_post(lib, jt, JOB_CUSTOM), MA_INVALID_ARGS)
    assert_equal(raw.device_job_thread_next(lib, jt).result, MA_INVALID_ARGS)
    raw.device_job_thread_free(lib, jt)
    raw.device_job_thread_free(lib, null_handle())  # must not crash


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
