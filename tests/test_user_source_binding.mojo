"""Contract tests for the raw user data source binding
(ma_shim_data_source_init_user / ma_shim_data_source_user).

The shim takes the source over whether init succeeds or not, so every rejected
call must still destroy it exactly once.
"""

from std.testing import assert_equal, assert_true, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS, MA_AT_END
from miniaudio.processor import UserDataSource
from miniaudio._ffi.stream_raw import stream_leak, stream_tag
import miniaudio._ffi.data_source_raw as raw


struct Half(UserDataSource):
    var left: Int
    var dropped: UnsafePointer[Int, MutUntrackedOrigin]

    def __init__(out self, frames: Int, dropped: UnsafePointer[Int, MutUntrackedOrigin]):
        self.left = frames
        self.dropped = dropped

    def read(mut self, output: Span[Float32, MutAnyOrigin], frame_count: Int, channels: Int) -> Int:
        var n = min(frame_count, self.left)
        for i in range(n * channels):
            output[i] = 0.5
        self.left -= n
        return n

    def seek(mut self, frame: UInt64) -> Bool:
        return False

    def length(mut self) -> UInt64:
        return 0

    def __del__(deinit self):
        self.dropped[] += 1


def _lib() raises -> MaLib:
    return MaLib.default()


def test_init_user_reads_then_ends_and_drops_once() raises:
    var lib = _lib()
    var dropped = List[Int](length=1, fill=0)
    var dp = dropped.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    var ds = raw.data_source_alloc(lib)
    assert_equal(raw.data_source_init_user(lib, ds, 1, 48000, stream_leak(Half(3, dp))), MA_SUCCESS)
    assert_true(raw.data_source_user(lib, ds, stream_tag[Half]()) != null_handle())
    assert_equal(raw.data_source_user(lib, ds, UInt64(12345)), null_handle())  # wrong tag
    var buf = List[Float32](length=8, fill=0)
    var rc = raw.data_source_read_pcm_frames(lib, ds, buf, 8)
    assert_equal(rc.result, MA_SUCCESS)  # a short read with data is a success...
    assert_equal(rc.value, UInt64(3))
    assert_equal(buf[2], Float32(0.5))
    rc = raw.data_source_read_pcm_frames(lib, ds, buf, 8)
    assert_equal(rc.result, MA_AT_END)  # ...the end shows on the next one
    assert_equal(rc.value, UInt64(0))
    assert_equal(dropped[0], 0)
    assert_equal(raw.data_source_uninit(lib, ds), MA_SUCCESS)
    assert_equal(dropped[0], 1)
    assert_equal(raw.data_source_user(lib, ds, stream_tag[Half]()), null_handle())
    raw.data_source_free(lib, ds)
    assert_equal(dropped[0], 1)


def test_rejected_inits_drop_the_source() raises:
    var lib = _lib()
    var dropped = List[Int](length=1, fill=0)
    var dp = dropped.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    var ds = raw.data_source_alloc(lib)
    assert_equal(raw.data_source_init_user(lib, null_handle(), 1, 48000, stream_leak(Half(1, dp))), MA_INVALID_ARGS)
    assert_equal(raw.data_source_init_user(lib, ds, 0, 48000, stream_leak(Half(1, dp))), MA_INVALID_ARGS)
    assert_equal(raw.data_source_init_user(lib, ds, 1, 0, stream_leak(Half(1, dp))), MA_INVALID_ARGS)
    assert_equal(dropped[0], 3)
    var n = null_handle()
    assert_equal(raw.data_source_init_user_ptrs(lib, ds, 1, 48000, n, n, n, n, n, 0), MA_INVALID_ARGS)
    assert_equal(raw.data_source_user(lib, null_handle(), 0), null_handle())
    raw.data_source_free(lib, ds)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
