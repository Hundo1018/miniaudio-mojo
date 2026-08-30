"""TDD contract tests for the job queue BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent. All 9 MA_API job queue functions are
exercised here (positive and negative paths). `ma_job` never crosses into Mojo:
the shim keeps a single job slot that post / next / process work through.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_CANCELLED
import miniaudio._ffi.sync_raw as raw


comptime JOB_TYPE_QUIT: UInt32 = 0
comptime CAPACITY: UInt32 = 16


def _lib() raises -> MaLib:
    return MaLib.default()


def test_heap_size_is_reported_from_the_config_alone() raises:
    """The get_heap_size call answers before anything is built."""
    var lib = _lib()
    var rc = raw.job_queue_get_heap_size(lib, UInt32(0), CAPACITY)
    assert_equal(rc.result, MA_SUCCESS)
    assert_true(rc.value > UInt64(0))


def test_a_job_can_be_posted_popped_and_run() raises:
    """The whole round trip through the shim's job slot."""
    var lib = _lib()
    var q = raw.job_queue_alloc(lib)
    assert_true(q != null_handle())
    assert_equal(raw.job_queue_init(lib, q, UInt32(0), CAPACITY), MA_SUCCESS)

    assert_equal(raw.job_queue_post(lib, q, JOB_TYPE_QUIT), MA_SUCCESS)

    # A quit job is labelled MA_CANCELLED on the way out; the job is still real.
    var job = raw.job_queue_next(lib, q)
    assert_equal(job.result, MA_CANCELLED)
    assert_equal(job.value, Int(JOB_TYPE_QUIT))

    assert_equal(raw.job_queue_process(lib, q), MA_SUCCESS)
    # The slot is empty again.
    assert_equal(raw.job_queue_process(lib, q), MA_INVALID_ARGS)

    assert_equal(raw.job_queue_uninit(lib, q), MA_SUCCESS)
    raw.job_queue_free(lib, q)


def test_the_preallocated_path_builds_the_same_queue() raises:
    """A shim-owned heap gives a queue that behaves identically."""
    var lib = _lib()
    var q = raw.job_queue_alloc(lib)
    assert_equal(
        raw.job_queue_init_preallocated(lib, q, UInt32(0), CAPACITY), MA_SUCCESS
    )

    assert_equal(raw.job_queue_post(lib, q, JOB_TYPE_QUIT), MA_SUCCESS)
    assert_equal(raw.job_queue_next(lib, q).result, MA_CANCELLED)
    assert_equal(raw.job_queue_process(lib, q), MA_SUCCESS)

    raw.job_queue_free(lib, q)


def test_operations_before_init_are_invalid() raises:
    """Every entry point rejects a handle that was allocated but never initialised."""
    var lib = _lib()
    var q = raw.job_queue_alloc(lib)

    assert_equal(raw.job_queue_post(lib, q, JOB_TYPE_QUIT), MA_INVALID_ARGS)
    assert_equal(raw.job_queue_next(lib, q).result, MA_INVALID_ARGS)
    assert_equal(raw.job_queue_process(lib, q), MA_INVALID_ARGS)
    assert_equal(raw.job_queue_uninit(lib, q), MA_SUCCESS)

    raw.job_queue_free(lib, q)
    assert_equal(
        raw.job_queue_init(lib, null_handle(), UInt32(0), CAPACITY), MA_INVALID_ARGS
    )
    assert_equal(
        raw.job_queue_init_preallocated(lib, null_handle(), UInt32(0), CAPACITY),
        MA_INVALID_ARGS,
    )
    raw.job_queue_free(lib, null_handle())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
