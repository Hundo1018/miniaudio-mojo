"""TDD contract tests for the resource manager BINDING layer (raw 1:1 over the shim).

Deterministic despite being a family built around asynchrony: the manager is
created with zero job threads and the non-blocking flag, so nothing runs on a
background thread and the job queue is pumped explicitly by the test. All 56
bindable MA_API resource manager functions are exercised here (positive and
negative paths); the 8 `_w` wide-char variants are excluded project-wide.

The sound used is the generated test WAV, so the pixi task runs gen-test-wav
first.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import (
    MA_SUCCESS,
    MA_INVALID_ARGS,
    MA_AT_END,
    MA_NOT_IMPLEMENTED,
    MA_CANCELLED,
    MA_NO_DATA_AVAILABLE,
)
import miniaudio._ffi.resource_manager_raw as raw
from support.wav_fixtures import embedded_wav_stereo_2frames


comptime WAV_PATH = "./build/test_assets/sine_440_stereo.wav"
comptime FMT_F32: Int = 5
comptime FLAG_STREAM: UInt32 = 1
comptime FLAG_DECODE: UInt32 = 2


def _lib() raises -> MaLib:
    return MaLib.default()


def _sink(n: Int) -> List[Float32]:
    var out = List[Float32](capacity=n)
    out.resize(n, Float32(0))
    return out^


def _manager(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    var rm = raw.resource_manager_alloc(lib)
    assert_true(rm != null_handle())
    assert_equal(raw.resource_manager_init(lib, rm), MA_SUCCESS)
    return rm


def _threaded_manager(lib: MaLib) raises -> OpaquePointer[MutUntrackedOrigin]:
    """A manager with a worker thread, which streams require.

    Note the non-blocking flag has to come off: miniaudio only accepts it with a
    job thread count of zero, and rejects the combination with MA_INVALID_ARGS.

    ma_resource_manager_data_stream_uninit always posts a free job and waits for
    it, with no flag to opt out (see the note in ma_shim_resource_manager.h), so
    a stream on a zero-thread manager can be created but never torn down. With a
    worker thread the synchronous init and uninit both settle on their own,
    which also keeps the assertions below deterministic.
    """
    var rm = raw.resource_manager_alloc(lib)
    assert_true(rm != null_handle())
    assert_equal(
        raw.resource_manager_init(
            lib, rm, job_thread_count=UInt32(1), non_blocking=False
        ),
        MA_SUCCESS,
    )
    return rm


def _pump(lib: MaLib, rm: OpaquePointer[MutUntrackedOrigin]):
    """Run queued jobs until the queue is empty. Nothing else will."""
    for _ in range(64):
        var code = raw.resource_manager_process_next_job(lib, rm)
        if code != MA_SUCCESS:
            return


# ---- the manager ------------------------------------------------------------


def test_a_manager_starts_up_with_a_log() raises:
    """A fresh manager initialises and reports its log."""
    var lib = _lib()
    var rm = _manager(lib)

    var log = raw.resource_manager_has_log(lib, rm)
    assert_equal(log.result, MA_SUCCESS)
    assert_true(log.value)

    raw.resource_manager_free(lib, rm)


def test_files_can_be_registered_and_unregistered() raises:
    """Preloading a file into the cache and dropping it again both succeed."""
    var lib = _lib()
    var rm = _manager(lib)

    assert_equal(
        raw.resource_manager_register_file(lib, rm, WAV_PATH, FLAG_DECODE), MA_SUCCESS
    )
    _pump(lib, rm)
    assert_equal(raw.resource_manager_unregister_file(lib, rm, WAV_PATH), MA_SUCCESS)

    raw.resource_manager_free(lib, rm)


def test_decoded_and_encoded_data_can_be_registered() raises:
    """Both in-memory registration paths accept data and give it a name."""
    var lib = _lib()
    var rm = _manager(lib)

    var frames = List[Float32]()
    for i in range(8):
        frames.append(Float32(i) * Float32(0.1))
    assert_equal(
        raw.resource_manager_register_decoded_data(
            lib, rm, "decoded", frames, UInt64(8), FMT_F32, UInt32(1), UInt32(48000)
        ),
        MA_SUCCESS,
    )
    assert_equal(raw.resource_manager_unregister_data(lib, rm, "decoded"), MA_SUCCESS)

    var wav = embedded_wav_stereo_2frames()
    assert_equal(
        raw.resource_manager_register_encoded_data(lib, rm, "encoded", wav), MA_SUCCESS
    )
    assert_equal(raw.resource_manager_unregister_data(lib, rm, "encoded"), MA_SUCCESS)

    raw.resource_manager_free(lib, rm)


def test_a_job_can_be_popped_reposted_and_run() raises:
    """The whole job round trip, without Mojo ever holding an ma_job."""
    var lib = _lib()
    var rm = _manager(lib)

    # An empty non-blocking queue says so rather than blocking.
    assert_equal(
        raw.resource_manager_process_next_job(lib, rm), MA_NO_DATA_AVAILABLE
    )

    assert_equal(raw.resource_manager_post_job_quit(lib, rm), MA_SUCCESS)

    # next_job reports MA_CANCELLED for a quit job. That is not a failure: the
    # job struct is filled in, and MA_CANCELLED is how miniaudio says "this one
    # is the quit job".
    var job = raw.resource_manager_next_job(lib, rm)
    assert_equal(job.result, MA_CANCELLED)
    assert_true(job.value >= 0)

    # The slot holds a real job, so it can go back on the queue and be run.
    assert_equal(raw.resource_manager_post_job(lib, rm), MA_SUCCESS)
    assert_equal(raw.resource_manager_process_next_job(lib, rm), MA_CANCELLED)

    # A quit job is sticky — it stays on the queue so every worker sees it.
    assert_equal(raw.resource_manager_process_next_job(lib, rm), MA_CANCELLED)

    raw.resource_manager_free(lib, rm)


def test_a_popped_job_can_be_processed_directly() raises:
    """The process_job entry point runs the job sitting in the shim's slot."""
    var lib = _lib()
    var rm = _manager(lib)

    assert_equal(raw.resource_manager_post_job_quit(lib, rm), MA_SUCCESS)
    assert_equal(raw.resource_manager_next_job(lib, rm).result, MA_CANCELLED)

    # Running the job succeeds. The MA_CANCELLED signal belongs to the *retrieval*
    # step, not to running it: next_job (and process_next_job, which retrieves
    # internally) report the quit, while process_job just executes what it is given.
    assert_equal(raw.resource_manager_process_job(lib, rm), MA_SUCCESS)

    # The slot is empty again.
    assert_equal(raw.resource_manager_process_job(lib, rm), MA_INVALID_ARGS)

    raw.resource_manager_free(lib, rm)


def test_manager_operations_before_init_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var rm = raw.resource_manager_alloc(lib)
    var frames = _sink(4)

    assert_equal(raw.resource_manager_has_log(lib, rm).result, MA_INVALID_ARGS)
    assert_equal(
        raw.resource_manager_register_file(lib, rm, WAV_PATH, UInt32(0)),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.resource_manager_unregister_file(lib, rm, WAV_PATH), MA_INVALID_ARGS
    )
    assert_equal(
        raw.resource_manager_register_decoded_data(
            lib, rm, "x", frames, UInt64(4), FMT_F32, UInt32(1), UInt32(48000)
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(
        raw.resource_manager_register_encoded_data(
            lib, rm, "x", embedded_wav_stereo_2frames()
        ),
        MA_INVALID_ARGS,
    )
    assert_equal(raw.resource_manager_unregister_data(lib, rm, "x"), MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_post_job_quit(lib, rm), MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_next_job(lib, rm).result, MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_post_job(lib, rm), MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_process_job(lib, rm), MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_process_next_job(lib, rm), MA_INVALID_ARGS)

    raw.resource_manager_free(lib, rm)


def test_manager_uninit_is_idempotent_and_null_safe() raises:
    """Uninit twice is fine; null handles are rejected and free(null) is a noop."""
    var lib = _lib()
    var rm = _manager(lib)
    assert_equal(raw.resource_manager_uninit(lib, rm), MA_SUCCESS)
    assert_equal(raw.resource_manager_uninit(lib, rm), MA_SUCCESS)
    raw.resource_manager_free(lib, rm)

    assert_equal(raw.resource_manager_uninit(lib, null_handle()), MA_INVALID_ARGS)
    assert_equal(raw.resource_manager_init(lib, null_handle()), MA_INVALID_ARGS)
    raw.resource_manager_free(lib, null_handle())


# ---- data buffer -------------------------------------------------------------


def test_a_data_buffer_decodes_a_whole_file() raises:
    """A decoded buffer reports a length and reads frames out of it."""
    var lib = _lib()
    var rm = _manager(lib)
    var b = raw.rm_data_buffer_alloc(lib)
    assert_true(b != null_handle())
    assert_equal(
        raw.rm_data_buffer_init(lib, b, rm, WAV_PATH, FLAG_DECODE), MA_SUCCESS
    )
    _pump(lib, rm)

    var fmt = raw.rm_data_buffer_get_data_format(lib, b)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_true(fmt.channels > UInt32(0))
    assert_true(fmt.sample_rate > UInt32(0))

    var length = raw.rm_data_buffer_get_length(lib, b)
    assert_equal(length.result, MA_SUCCESS)
    assert_true(length.value > UInt64(0))

    var dst = _sink(64 * Int(fmt.channels))
    var rc = raw.rm_data_buffer_read(lib, b, dst, UInt64(64))
    assert_true(rc.result == MA_SUCCESS or rc.result == MA_AT_END)
    assert_true(rc.value > UInt64(0))

    assert_equal(raw.rm_data_buffer_get_cursor(lib, b).value, rc.value)
    assert_equal(raw.rm_data_buffer_get_available(lib, b).result, MA_SUCCESS)
    assert_equal(raw.rm_data_buffer_result(lib, b).value, MA_SUCCESS)

    assert_equal(raw.rm_data_buffer_seek(lib, b, UInt64(0)), MA_SUCCESS)
    assert_equal(raw.rm_data_buffer_get_cursor(lib, b).value, UInt64(0))

    assert_equal(raw.rm_data_buffer_set_looping(lib, b, True), MA_SUCCESS)
    assert_true(raw.rm_data_buffer_is_looping(lib, b).value)

    raw.rm_data_buffer_free(lib, b)
    raw.resource_manager_free(lib, rm)


def test_a_data_buffer_can_be_built_through_the_config_and_copied() raises:
    """Building through init_ex uses the config path; init_copy adds a reader."""
    var lib = _lib()
    var rm = _manager(lib)

    var b = raw.rm_data_buffer_alloc(lib)
    assert_equal(
        raw.rm_data_buffer_init_ex(lib, b, rm, WAV_PATH, FLAG_DECODE), MA_SUCCESS
    )
    _pump(lib, rm)

    var copy = raw.rm_data_buffer_alloc(lib)
    assert_equal(raw.rm_data_buffer_init_copy(lib, copy, rm, b), MA_SUCCESS)
    _pump(lib, rm)

    var a_len = raw.rm_data_buffer_get_length(lib, b).value
    var b_len = raw.rm_data_buffer_get_length(lib, copy).value
    assert_equal(a_len, b_len)

    raw.rm_data_buffer_free(lib, copy)
    raw.rm_data_buffer_free(lib, b)
    raw.resource_manager_free(lib, rm)


def test_data_buffer_operations_before_init_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var b = raw.rm_data_buffer_alloc(lib)
    var dst = _sink(8)

    assert_equal(raw.rm_data_buffer_read(lib, b, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_seek(lib, b, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_get_data_format(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_get_cursor(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_get_length(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_get_available(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_result(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_set_looping(lib, b, True), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_is_looping(lib, b).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_buffer_uninit(lib, b), MA_SUCCESS)

    raw.rm_data_buffer_free(lib, b)
    raw.rm_data_buffer_free(lib, null_handle())


# ---- data stream -------------------------------------------------------------


def test_a_data_stream_pages_a_file_in() raises:
    """A stream reports its format and reads once its pages are loaded."""
    var lib = _lib()
    var rm = _threaded_manager(lib)
    var s = raw.rm_data_stream_alloc(lib)
    assert_true(s != null_handle())
    assert_equal(raw.rm_data_stream_init(lib, s, rm, WAV_PATH, UInt32(0)), MA_SUCCESS)

    var fmt = raw.rm_data_stream_get_data_format(lib, s)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_true(fmt.channels > UInt32(0))

    assert_equal(raw.rm_data_stream_result(lib, s).value, MA_SUCCESS)
    assert_equal(raw.rm_data_stream_get_length(lib, s).result, MA_SUCCESS)
    assert_equal(raw.rm_data_stream_get_available(lib, s).result, MA_SUCCESS)

    var dst = _sink(32 * Int(fmt.channels))
    var rc = raw.rm_data_stream_read(lib, s, dst, UInt64(32))
    assert_true(rc.result == MA_SUCCESS or rc.result == MA_AT_END)
    assert_equal(raw.rm_data_stream_get_cursor(lib, s).result, MA_SUCCESS)

    assert_equal(raw.rm_data_stream_seek(lib, s, UInt64(0)), MA_SUCCESS)

    assert_equal(raw.rm_data_stream_set_looping(lib, s, True), MA_SUCCESS)
    assert_true(raw.rm_data_stream_is_looping(lib, s).value)

    assert_equal(raw.rm_data_stream_uninit(lib, s), MA_SUCCESS)
    raw.rm_data_stream_free(lib, s)
    raw.resource_manager_free(lib, rm)


def test_a_data_stream_can_be_built_through_the_config() raises:
    """Building through init_ex uses the config + notifications path."""
    var lib = _lib()
    var rm = _threaded_manager(lib)
    var s = raw.rm_data_stream_alloc(lib)

    assert_equal(
        raw.rm_data_stream_init_ex(lib, s, rm, WAV_PATH, UInt32(0)), MA_SUCCESS
    )
    assert_equal(raw.rm_data_stream_get_data_format(lib, s).result, MA_SUCCESS)
    assert_equal(raw.rm_data_stream_uninit(lib, s), MA_SUCCESS)

    raw.rm_data_stream_free(lib, s)
    raw.resource_manager_free(lib, rm)


def test_data_stream_operations_before_init_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var s = raw.rm_data_stream_alloc(lib)
    var dst = _sink(8)

    assert_equal(raw.rm_data_stream_read(lib, s, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_seek(lib, s, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_get_data_format(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_get_cursor(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_get_length(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_get_available(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_result(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_set_looping(lib, s, True), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_is_looping(lib, s).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_stream_uninit(lib, s), MA_SUCCESS)

    raw.rm_data_stream_free(lib, s)
    raw.rm_data_stream_free(lib, null_handle())


# ---- the unified data source -------------------------------------------------


def test_a_data_source_reads_and_maps() raises:
    """The unified front end reads through both the read and map/unmap paths."""
    var lib = _lib()
    var rm = _manager(lib)
    var d = raw.rm_data_source_alloc(lib)
    assert_true(d != null_handle())
    assert_equal(
        raw.rm_data_source_init(lib, d, rm, WAV_PATH, FLAG_DECODE), MA_SUCCESS
    )
    _pump(lib, rm)

    var fmt = raw.rm_data_source_get_data_format(lib, d)
    assert_equal(fmt.result, MA_SUCCESS)
    assert_true(fmt.channels > UInt32(0))

    var dst = _sink(32 * Int(fmt.channels))
    var rc = raw.rm_data_source_read(lib, d, dst, UInt64(32))
    assert_true(rc.result == MA_SUCCESS or rc.result == MA_AT_END)
    assert_true(rc.value > UInt64(0))

    # Mapping is a streaming-only path: on a decoded buffer miniaudio answers
    # MA_NOT_IMPLEMENTED outright. The streaming case is covered below.
    var mapped = raw.rm_data_source_map_read(lib, d, dst, UInt64(16))
    assert_equal(mapped.result, MA_NOT_IMPLEMENTED)

    assert_equal(raw.rm_data_source_get_cursor(lib, d).result, MA_SUCCESS)
    assert_equal(raw.rm_data_source_get_length(lib, d).result, MA_SUCCESS)
    assert_equal(raw.rm_data_source_get_available(lib, d).result, MA_SUCCESS)
    assert_equal(raw.rm_data_source_result(lib, d).value, MA_SUCCESS)
    assert_equal(raw.rm_data_source_seek(lib, d, UInt64(0)), MA_SUCCESS)
    assert_equal(raw.rm_data_source_set_looping(lib, d, True), MA_SUCCESS)
    assert_true(raw.rm_data_source_is_looping(lib, d).value)

    raw.rm_data_source_free(lib, d)
    raw.resource_manager_free(lib, rm)


def test_a_data_source_can_be_built_through_the_config_and_copied() raises:
    """Building through init_ex uses the config path; init_copy adds a reader."""
    var lib = _lib()
    var rm = _manager(lib)

    var d = raw.rm_data_source_alloc(lib)
    assert_equal(
        raw.rm_data_source_init_ex(lib, d, rm, WAV_PATH, FLAG_DECODE), MA_SUCCESS
    )
    _pump(lib, rm)

    var copy = raw.rm_data_source_alloc(lib)
    assert_equal(raw.rm_data_source_init_copy(lib, copy, rm, d), MA_SUCCESS)
    _pump(lib, rm)
    assert_equal(
        raw.rm_data_source_get_length(lib, copy).value,
        raw.rm_data_source_get_length(lib, d).value,
    )

    raw.rm_data_source_free(lib, copy)
    raw.rm_data_source_free(lib, d)
    raw.resource_manager_free(lib, rm)


def test_a_streaming_data_source_uses_the_stream_path() raises:
    """The STREAM flag turns the same front end into a stream."""
    var lib = _lib()
    var rm = _threaded_manager(lib)
    var d = raw.rm_data_source_alloc(lib)

    assert_equal(
        raw.rm_data_source_init(lib, d, rm, WAV_PATH, FLAG_STREAM), MA_SUCCESS
    )
    assert_equal(raw.rm_data_source_get_data_format(lib, d).result, MA_SUCCESS)

    # map/unmap only exist on the streaming path, so this is where they work.
    var dst = _sink(64)
    var mapped = raw.rm_data_source_map_read(lib, d, dst, UInt64(16))
    assert_true(mapped.result == MA_SUCCESS or mapped.result == MA_AT_END)

    assert_equal(raw.rm_data_source_uninit(lib, d), MA_SUCCESS)

    raw.rm_data_source_free(lib, d)
    raw.resource_manager_free(lib, rm)


def test_data_source_operations_before_init_are_invalid() raises:
    """Every accessor rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var d = raw.rm_data_source_alloc(lib)
    var dst = _sink(8)

    assert_equal(raw.rm_data_source_read(lib, d, dst, UInt64(4)).result, MA_INVALID_ARGS)
    assert_equal(
        raw.rm_data_source_map_read(lib, d, dst, UInt64(4)).result, MA_INVALID_ARGS
    )
    assert_equal(raw.rm_data_source_seek(lib, d, UInt64(0)), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_get_data_format(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_get_cursor(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_get_length(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_get_available(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_result(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_set_looping(lib, d, True), MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_is_looping(lib, d).result, MA_INVALID_ARGS)
    assert_equal(raw.rm_data_source_uninit(lib, d), MA_SUCCESS)

    raw.rm_data_source_free(lib, d)
    raw.rm_data_source_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
