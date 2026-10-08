"""TDD contract tests for the duplex_rb BINDING layer (raw 1:1 over the shim).

Deterministic and hardware-independent: ma_duplex_rb is a PCM ring buffer sized
from the capture period (five periods, scaled to the playback rate) and primed
with two periods of silence. Both MA_API duplex_rb functions are exercised
(positive and negative); the shim's write / read / available helpers expose the
buffer inside so frames can be put in and taken out.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_INVALID_ARGS
import miniaudio._ffi.util_raw as raw

comptime F32 = 5


def _lib() raises -> MaLib:
    return MaLib.default()


def _ready(lib: MaLib, channels: UInt32, rate: UInt32, internal: UInt32, period: UInt32) raises -> OpaquePointer[MutUntrackedOrigin]:
    var h = raw.duplex_rb_alloc(lib)
    assert_true(h != null_handle())
    assert_equal(raw.duplex_rb_init(lib, h, F32, channels, rate, internal, period), MA_SUCCESS)
    return h


def _ramp(frames: Int, channels: Int, first: Int = 1) -> List[Float32]:
    """Frame f of channel c holds f * 10 + c, so every sample is distinct."""
    var out = List[Float32]()
    for f in range(frames):
        for c in range(channels):
            out.append(Float32((first + f) * 10 + c))
    return out^


def test_init_primes_two_periods_in_a_five_period_buffer() raises:
    var lib = _lib()
    var h = _ready(lib, 2, 48000, 48000, 100)
    var readable = raw.duplex_rb_available_read(lib, h)
    var writable = raw.duplex_rb_available_write(lib, h)
    assert_equal(readable.result, MA_SUCCESS)
    assert_equal(readable.value, UInt32(200))  # 2 periods of priming
    assert_equal(writable.result, MA_SUCCESS)
    assert_equal(writable.value, UInt32(300))  # 5 periods - priming
    raw.duplex_rb_free(lib, h)


def test_buffer_size_scales_with_the_playback_to_capture_rate_ratio() raises:
    var lib = _lib()
    var slow_capture = _ready(lib, 2, 48000, 24000, 100)  # playback runs twice as fast
    assert_equal(raw.duplex_rb_available_read(lib, slow_capture).value, UInt32(200))
    assert_equal(raw.duplex_rb_available_write(lib, slow_capture).value, UInt32(800))
    raw.duplex_rb_free(lib, slow_capture)
    var fast_capture = _ready(lib, 1, 24000, 48000, 400)  # playback at half the capture rate
    assert_equal(raw.duplex_rb_available_read(lib, fast_capture).value, UInt32(800))
    assert_true(raw.duplex_rb_available_write(lib, fast_capture).value > UInt32(0))
    raw.duplex_rb_free(lib, fast_capture)


def test_frames_written_come_back_after_the_priming_silence() raises:
    var lib = _lib()
    var h = _ready(lib, 2, 48000, 48000, 100)
    var wrote = raw.duplex_rb_write(lib, h, _ramp(100, 2), 100)
    assert_equal(wrote.result, MA_SUCCESS)
    assert_equal(wrote.value, UInt32(100))
    assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(300))

    var silence = List[Float32]()
    silence.resize(400, Float32(-1))
    var first = raw.duplex_rb_read(lib, h, silence, 200)  # the priming periods
    assert_equal(first.value, UInt32(200))
    var all_silent = True
    for i in range(400):
        if silence[i] != 0.0:
            all_silent = False
    assert_true(all_silent)

    var out = List[Float32]()
    out.resize(200, Float32(-1))
    var second = raw.duplex_rb_read(lib, h, out, 100)  # then what was written
    assert_equal(second.result, MA_SUCCESS)
    assert_equal(second.value, UInt32(100))
    var expected = _ramp(100, 2)
    for i in range(200):
        assert_equal(out[i], expected[i])
    assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(0))
    raw.duplex_rb_free(lib, h)


def test_a_full_buffer_accepts_no_more_frames() raises:
    var lib = _lib()
    var h = _ready(lib, 1, 48000, 48000, 100)
    var src = _ramp(400, 1)
    var wrote = raw.duplex_rb_write(lib, h, src, 400)  # only 300 frames of room
    assert_equal(wrote.result, MA_SUCCESS)
    assert_equal(wrote.value, UInt32(300))
    assert_equal(raw.duplex_rb_available_write(lib, h).value, UInt32(0))
    assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(500))
    var more = raw.duplex_rb_write(lib, h, src, 10)
    assert_equal(more.result, MA_SUCCESS)
    assert_equal(more.value, UInt32(0))
    raw.duplex_rb_free(lib, h)


def test_reading_more_than_is_queued_returns_what_there_is() raises:
    var lib = _lib()
    var h = _ready(lib, 1, 48000, 48000, 100)
    var out = List[Float32]()
    out.resize(1000, Float32(0))
    var got = raw.duplex_rb_read(lib, h, out, 1000)
    assert_equal(got.result, MA_SUCCESS)
    assert_equal(got.value, UInt32(200))
    var again = raw.duplex_rb_read(lib, h, out, 10)
    assert_equal(again.value, UInt32(0))
    raw.duplex_rb_free(lib, h)


def test_init_rejects_bad_configuration() raises:
    var lib = _lib()
    var h = raw.duplex_rb_alloc(lib)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 2, 48000, 48000, 0), MA_INVALID_ARGS)  # no period
    assert_equal(raw.duplex_rb_init(lib, h, 0, 2, 48000, 48000, 100), MA_INVALID_ARGS)  # format unknown
    assert_equal(raw.duplex_rb_init(lib, h, 6, 2, 48000, 48000, 100), MA_INVALID_ARGS)  # not a format
    assert_equal(raw.duplex_rb_init(lib, h, -1, 2, 48000, 48000, 100), MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 0, 48000, 48000, 100), MA_INVALID_ARGS)  # no channels
    assert_equal(raw.duplex_rb_init(lib, h, F32, 2, 0, 48000, 100), MA_INVALID_ARGS)  # no playback rate
    assert_equal(raw.duplex_rb_init(lib, h, F32, 2, 48000, 0, 100), MA_INVALID_ARGS)  # no capture rate
    assert_equal(raw.duplex_rb_available_read(lib, h).result, MA_INVALID_ARGS)  # nothing initialised
    raw.duplex_rb_free(lib, h)


def test_init_rejects_a_buffer_shorter_than_the_priming() raises:
    """Playback far slower than capture leaves less than two periods of room; miniaudio
    would report success and corrupt the cursors, so the shim refuses."""
    var lib = _lib()
    var h = raw.duplex_rb_alloc(lib)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 1, 8000, 48000, 600), MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_available_write(lib, h).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 1, 48000, 48000, 600), MA_SUCCESS)  # same period, same rate: fine
    raw.duplex_rb_free(lib, h)


def test_any_sample_format_initialises() raises:
    var lib = _lib()
    var h = raw.duplex_rb_alloc(lib)
    for format in range(1, 6):  # u8, s16, s24, s32, f32
        assert_equal(raw.duplex_rb_init(lib, h, format, 2, 48000, 48000, 64), MA_SUCCESS)
        assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(128))
    raw.duplex_rb_free(lib, h)


def test_uninit_then_ops_invalid_and_reinit_ok() raises:
    var lib = _lib()
    var h = raw.duplex_rb_alloc(lib)
    assert_equal(raw.duplex_rb_uninit(lib, h), MA_SUCCESS)  # uninit before init is a no-op
    assert_equal(raw.duplex_rb_init(lib, h, F32, 1, 48000, 48000, 50), MA_SUCCESS)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 2, 48000, 48000, 20), MA_SUCCESS)  # reinit
    assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(40))
    assert_equal(raw.duplex_rb_uninit(lib, h), MA_SUCCESS)
    assert_equal(raw.duplex_rb_available_read(lib, h).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_init(lib, h, F32, 1, 48000, 48000, 10), MA_SUCCESS)
    assert_equal(raw.duplex_rb_available_read(lib, h).value, UInt32(20))
    raw.duplex_rb_free(lib, h)


def test_null_handle_ops_invalid_args() raises:
    var lib = _lib()
    var n = null_handle()
    var buf = _ramp(4, 1)
    assert_equal(raw.duplex_rb_init(lib, n, F32, 1, 48000, 48000, 100), MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_uninit(lib, n), MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_write(lib, n, buf, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_read(lib, n, buf, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_available_read(lib, n).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_available_write(lib, n).result, MA_INVALID_ARGS)
    raw.duplex_rb_free(lib, n)


def test_write_and_read_reject_missing_buffers() raises:
    var lib = _lib()
    var h = _ready(lib, 1, 48000, 48000, 100)
    var empty = List[Float32]()  # NULL
    assert_equal(raw.duplex_rb_write(lib, h, empty, 4).result, MA_INVALID_ARGS)
    assert_equal(raw.duplex_rb_read(lib, h, empty, 4).result, MA_INVALID_ARGS)
    raw.duplex_rb_free(lib, h)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
