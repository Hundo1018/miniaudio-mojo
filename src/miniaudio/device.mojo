"""Idiomatic playback device API (Layer 3).

`Device` is an RAII wrapper around a miniaudio playback device whose data
callback (owned by the C shim) pulls f32 PCM from a `Decoder`. Because the
audio thread reads the decoder for the device's lifetime, `Device` takes
ownership of the `Decoder` and keeps it alive; `__del__` uninits the device
(which stops and joins the audio thread) before the decoder is destroyed.

NOTE on the callback: the pinned Mojo nightly cannot pass a Mojo function value
across the FFI as a C function pointer (function values do not conform to
`AnyType` in `DLHandle.call`), so a user-supplied Mojo data callback is not
possible. The callback therefore lives in C and pulls from the decoder. Use
`use_null_backend=True` for deterministic, hardware-free runs (tests).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import Decoder
import miniaudio._ffi.device_raw as raw


# ---- ma_device_type codes ----
comptime DEVICE_TYPE_PLAYBACK = 1
comptime DEVICE_TYPE_CAPTURE = 2
comptime DEVICE_TYPE_DUPLEX = 3
comptime DEVICE_TYPE_LOOPBACK = 4

# ---- ma_device_state codes ----
comptime DEVICE_STATE_UNINITIALIZED = 0
comptime DEVICE_STATE_STOPPED = 1
comptime DEVICE_STATE_STARTED = 2
comptime DEVICE_STATE_STARTING = 3
comptime DEVICE_STATE_STOPPING = 4


@fieldwise_init
struct NativeDataFormat(Copyable, Movable):
    """One supported (format, channels, sample_rate, flags) tuple of a device.

    `channels`/`sample_rate` of 0 mean "all supported"; `format` of 0
    (ma_format_unknown) means "all formats supported".
    """

    var format: Int
    var channels: UInt32
    var sample_rate: UInt32
    var flags: UInt32


@fieldwise_init
struct DeviceInfo(Copyable, Movable):
    """A snapshot of a device's descriptive info (name, default flag, formats)."""

    var name: String
    var is_default: Bool
    var native_data_formats: List[NativeDataFormat]


struct Device(Movable):
    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _source: Decoder  # kept alive for the device's lifetime; the cb pulls from it

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        var source: Decoder,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._source = source^

    @staticmethod
    def play(
        lib: ArcPointer[MaLib],
        var source: Decoder,
        *,
        sample_rate: UInt32 = 0,
        use_null_backend: Bool = False,
    ) raises -> Self:
        """Opens a playback device that streams `source`. Call `start()` to play.

        `sample_rate` of 0 uses the decoder's native rate. `use_null_backend`
        runs on miniaudio's null backend (no hardware) for deterministic tests.
        """
        var ptr = raw.device_alloc(lib[])
        if ptr == null_handle():
            raise Error("device_alloc failed (out of memory)")
        var code = raw.device_init_playback_from_decoder(
            lib[], ptr, source._ptr, sample_rate, use_null_backend
        )
        if code != MA_SUCCESS:
            raw.device_free(lib[], ptr)
            raise Error(lib[].describe("device init for playback failed", code))
        return Self(lib.copy(), ptr, source^)

    @staticmethod
    def play_ex(
        lib: ArcPointer[MaLib],
        var source: Decoder,
        var backends: List[Int32],
        *,
        sample_rate: UInt32 = 0,
    ) raises -> Self:
        """Opens a playback device, selecting the backend from a priority list.

        `backends` holds ma_backend codes in priority order; an empty list uses
        miniaudio's default order. This is the ma_device_init_ex path — the
        device owns the context it creates internally.
        """
        var ptr = raw.device_alloc(lib[])
        if ptr == null_handle():
            raise Error("device_alloc failed (out of memory)")
        var code = raw.device_init_ex_playback_from_decoder(
            lib[], ptr, source._ptr, backends, sample_rate
        )
        if code != MA_SUCCESS:
            raw.device_free(lib[], ptr)
            raise Error(lib[].describe("device init_ex for playback failed", code))
        return Self(lib.copy(), ptr, source^)

    def start(mut self) raises:
        var code = raw.device_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device start failed", code))

    def stop(mut self) raises:
        var code = raw.device_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device stop failed", code))

    def channels(self) -> UInt32:
        return raw.device_get_channels(self._lib[], self._ptr)

    def sample_rate(self) -> UInt32:
        return raw.device_get_sample_rate(self._lib[], self._ptr)

    def frames_processed(self) -> UInt64:
        return raw.device_get_frames_processed(self._lib[], self._ptr)

    def state(self) -> Int:
        """The device's ma_device_state (DEVICE_STATE_* code)."""
        return raw.device_get_state(self._lib[], self._ptr)

    def is_started(self) -> Bool:
        return raw.device_is_started(self._lib[], self._ptr)

    def set_master_volume(mut self, volume: Float32) raises:
        """Sets the linear master volume (0 = silence, 1 = unity gain)."""
        var code = raw.device_set_master_volume(self._lib[], self._ptr, volume)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device set_master_volume failed", code))

    def master_volume(self) raises -> Float32:
        var r = raw.device_get_master_volume(self._lib[], self._ptr)
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_master_volume failed", r.result))
        return r.value

    def set_master_volume_db(mut self, gain_db: Float32) raises:
        """Sets the master volume in decibels (0 dB = unity gain)."""
        var code = raw.device_set_master_volume_db(self._lib[], self._ptr, gain_db)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device set_master_volume_db failed", code))

    def master_volume_db(self) raises -> Float32:
        var r = raw.device_get_master_volume_db(self._lib[], self._ptr)
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_master_volume_db failed", r.result))
        return r.value

    def name(self, device_type: Int = DEVICE_TYPE_PLAYBACK) raises -> String:
        """The device's name for the given device type."""
        var r = raw.device_get_name(self._lib[], self._ptr, device_type)
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_name failed", r.result))
        return r.value

    def context_backend(self) raises -> UInt32:
        """The ma_backend code the device's context is running on."""
        var r = raw.device_get_context_backend(self._lib[], self._ptr)
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_context_backend failed", r.result))
        return r.value

    def has_log(self) raises -> Bool:
        """Whether the device exposes a log object (borrowed from its context)."""
        var r = raw.device_has_log(self._lib[], self._ptr)
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_log failed", r.result))
        return r.value

    def id_equals(
        self, other: Device, device_type: Int = DEVICE_TYPE_PLAYBACK
    ) raises -> Bool:
        """Whether this device and `other` were opened on the same device id."""
        var r = raw.device_id_equal(
            self._lib[], self._ptr, other._ptr, device_type
        )
        if r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device id_equal failed", r.result))
        return r.value

    def info(mut self, device_type: Int = DEVICE_TYPE_PLAYBACK) raises -> DeviceInfo:
        """Loads and returns a self-contained snapshot of the device's info."""
        var code = raw.device_info_load(self._lib[], self._ptr, device_type)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device get_info failed", code))

        var name_r = raw.device_info_name(self._lib[], self._ptr)
        if name_r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device info name failed", name_r.result))
        var default_r = raw.device_info_is_default(self._lib[], self._ptr)
        if default_r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device info is_default failed", default_r.result))
        var count_r = raw.device_info_native_data_format_count(self._lib[], self._ptr)
        if count_r.result != MA_SUCCESS:
            raise Error(self._lib[].describe("device info format count failed", count_r.result))

        var formats = List[NativeDataFormat]()
        for i in range(Int(count_r.value)):
            var f = raw.device_info_native_data_format(self._lib[], self._ptr, UInt32(i))
            if f.result != MA_SUCCESS:
                raise Error(self._lib[].describe("device info format failed", f.result))
            formats.append(
                NativeDataFormat(f.format, f.channels, f.sample_rate, f.flags)
            )
        return DeviceInfo(name_r.value, default_r.value, formats^)

    def add_native_data_format(
        mut self,
        format: Int,
        channels: UInt32,
        sample_rate: UInt32,
        flags: UInt32 = 0,
    ) raises:
        """Appends a native data format to the most recently loaded info snapshot.

        Requires a prior `info()` call to populate the snapshot; mirrors what a
        backend does while enumerating a device's capabilities.
        """
        var code = raw.device_info_add_native_data_format(
            self._lib[], self._ptr, format, channels, sample_rate, flags
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device add_native_data_format failed", code))

    def pump(mut self, mut out: List[Float32], frame_count: UInt32) raises:
        """Drives the data callback synchronously, filling `out` with frame_count
        frames — offline rendering without starting a real-time thread.

        `out` must be pre-sized to at least frame_count * channels floats.
        """
        var code = raw.device_handle_backend_data_callback(
            self._lib[], self._ptr, out, frame_count
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device handle_backend_data_callback failed", code))

    def __del__(deinit self):
        # Uninit the device first (stops + joins the audio thread) so the
        # callback is no longer reading the decoder when `_source` is destroyed.
        if self._ptr != null_handle():
            raw.device_free(self._lib[], self._ptr)


# ---- ma_job_type codes (the subset relevant to the job queue's control flow) ----
comptime JOB_TYPE_QUIT = UInt16(0)
comptime JOB_TYPE_CUSTOM = UInt16(1)

# ---- ma_job_queue flags ----
comptime JOB_QUEUE_FLAG_NON_BLOCKING = UInt32(1)


@fieldwise_init
struct JobResult(Copyable, Movable):
    """Outcome of draining one job: an ma_result code plus the job's type code.

    `code` is meaningful only when `result` is MA_SUCCESS. A quit job surfaces as
    result == MA_CANCELLED; an empty non-blocking queue as MA_NO_DATA_AVAILABLE.
    """

    var result: Int
    var code: UInt16


struct DeviceJobThread(Movable):
    """RAII wrapper around an ma_device_job_thread (a job queue + optional worker).

    With `no_thread=True` no worker is spawned and the caller drains the queue
    via `next()`, which makes the queue deterministically testable. Pass
    `non_blocking=True` so `next()` returns MA_NO_DATA_AVAILABLE on an empty
    queue instead of blocking.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        no_thread: Bool = True,
        capacity: UInt32 = 0,
        non_blocking: Bool = False,
    ) raises -> Self:
        """Creates a job thread. `capacity` of 0 uses miniaudio's default size."""
        var ptr = raw.device_job_thread_alloc(lib[])
        if ptr == null_handle():
            raise Error("device_job_thread_alloc failed (out of memory)")
        var flags = JOB_QUEUE_FLAG_NON_BLOCKING if non_blocking else UInt32(0)
        var code = raw.device_job_thread_init(
            lib[], ptr, no_thread, capacity, flags
        )
        if code != MA_SUCCESS:
            raw.device_job_thread_free(lib[], ptr)
            raise Error(lib[].describe("device_job_thread init failed", code))
        return Self(lib.copy(), ptr)

    def post(mut self, job_code: UInt16) raises:
        """Enqueues a job of the given ma_job_type code."""
        var code = raw.device_job_thread_post(self._lib[], self._ptr, job_code)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device_job_thread post failed", code))

    def next(mut self) -> JobResult:
        """Dequeues the next job. Does not raise: MA_NO_DATA_AVAILABLE (empty,
        non-blocking) and MA_CANCELLED (quit job) are normal control-flow codes.
        """
        var r = raw.device_job_thread_next(self._lib[], self._ptr)
        return JobResult(r.result, UInt16(r.value))

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.device_job_thread_free(self._lib[], self._ptr)
