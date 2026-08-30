"""TDD tests for the idiomatic job queue API (RAII JobQueue).

L3 behavioral: verifies a job survives the round trip through the shim's slot,
that both init paths build a working queue, and that a released queue refuses
further use.
"""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from std.memory import ArcPointer

from miniaudio import MaLib
from miniaudio.result import MA_SUCCESS, MA_CANCELLED
from miniaudio.sync import JobQueue


comptime JOB_TYPE_QUIT: UInt32 = 0


def _lib() raises -> ArcPointer[MaLib]:
    return ArcPointer(MaLib.default())


def test_a_job_survives_the_round_trip() raises:
    """Post, pop and run — the quit job comes back labelled MA_CANCELLED."""
    var q = JobQueue.create(_lib())
    q.post(JOB_TYPE_QUIT)

    assert_equal(q.next_job(), MA_CANCELLED)
    assert_equal(q.process(), MA_SUCCESS)


def test_the_popped_job_reports_its_type() raises:
    """The type code that went in is the one that comes out."""
    var q = JobQueue.create(_lib())
    q.post(JOB_TYPE_QUIT)
    assert_equal(q.next_job_type(), Int(JOB_TYPE_QUIT))


def test_both_init_paths_build_a_working_queue() raises:
    """Where the queue's heap lives makes no difference."""
    _ = JobQueue.heap_size(_lib())
    var q = JobQueue.create(_lib(), preallocated=True)
    q.post(JOB_TYPE_QUIT)
    assert_equal(q.next_job(), MA_CANCELLED)
    assert_equal(q.process(), MA_SUCCESS)


def test_uninit_makes_further_use_an_error() raises:
    """After an explicit uninit posting raises."""
    var q = JobQueue.create(_lib())
    q.uninit()
    with assert_raises():
        q.post(JOB_TYPE_QUIT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
