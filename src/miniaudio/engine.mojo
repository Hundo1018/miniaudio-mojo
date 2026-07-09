"""Idiomatic engine API (Layer 3).

`Engine` is an RAII wrapper around ma_engine — the high-level audio engine that
owns its own device and node graph. It plays sound files fire-and-forget, mixes
them, and exposes volume/gain and a running clock. Cleans up in `__del__`,
raises `Error` on failure, shares the library via `ArcPointer[MaLib]`.

`use_null_backend=True` runs on miniaudio's null backend (no hardware) for
deterministic tests; the engine clock still advances while started.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio._ffi.sound_raw import Vec3, MaCone
import miniaudio._ffi.engine_raw as raw


struct Engine(Movable):
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
    def create(lib: ArcPointer[MaLib], *, use_null_backend: Bool = False) raises -> Self:
        """Initialises an engine (auto-started). `use_null_backend` for tests."""
        var ptr = raw.engine_alloc(lib[])
        if ptr == null_handle():
            raise Error("engine_alloc failed (out of memory)")
        var code = raw.engine_init(lib[], ptr, use_null_backend)
        if code != MA_SUCCESS:
            raw.engine_free(lib[], ptr)
            raise Error(lib[].describe("engine init failed", code))
        return Self(lib.copy(), ptr)

    def start(mut self) raises:
        var code = raw.engine_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine start failed", code))

    def stop(mut self) raises:
        var code = raw.engine_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine stop failed", code))

    def play_sound(mut self, path: String) raises:
        """Fire-and-forget: loads and plays `path` to the engine's endpoint."""
        var code = raw.engine_play_sound(self._lib[], self._ptr, path)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine play_sound failed", code))

    def play_sound_ex(mut self, path: String) raises:
        """Fire-and-forget play attached to the engine endpoint (node == NULL)."""
        var code = raw.engine_play_sound_ex(self._lib[], self._ptr, path)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine play_sound_ex failed", code))

    def read(mut self, mut out: List[Float32], frame_count: UInt64) raises -> UInt64:
        """Reads up to frame_count frames from the node graph into `out`.

        `out` is sized to frames_read * channels (interleaved f32). Returns the
        number of frames read. Intended for manual/offline rendering; when the
        engine's device is running it competes with the audio thread.
        """
        var ch = Int(self.channels())
        if ch == 0:
            raise Error("engine has unknown channel count")
        out.resize(Int(frame_count) * ch, Float32(0))
        var c = raw.engine_read_pcm_frames(self._lib[], self._ptr, out, frame_count)
        if c.result != MA_SUCCESS:
            out.resize(0, Float32(0))
            raise Error(self._lib[].describe("engine read failed", c.result))
        out.resize(Int(c.value) * ch, Float32(0))
        return c.value

    def sample_rate(self) -> UInt32:
        return raw.engine_get_sample_rate(self._lib[], self._ptr)

    def channels(self) -> UInt32:
        return raw.engine_get_channels(self._lib[], self._ptr)

    def set_volume(mut self, volume: Float32) raises:
        var code = raw.engine_set_volume(self._lib[], self._ptr, volume)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine set_volume failed", code))

    def volume(self) -> Float32:
        return raw.engine_get_volume(self._lib[], self._ptr)

    def set_gain_db(mut self, gain_db: Float32) raises:
        var code = raw.engine_set_gain_db(self._lib[], self._ptr, gain_db)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine set_gain_db failed", code))

    def gain_db(self) -> Float32:
        return raw.engine_get_gain_db(self._lib[], self._ptr)

    # ---- global clock ----

    def time_in_frames(self) -> UInt64:
        return raw.engine_get_time_in_pcm_frames(self._lib[], self._ptr)

    def time_in_milliseconds(self) -> UInt64:
        return raw.engine_get_time_in_milliseconds(self._lib[], self._ptr)

    def set_time_in_frames(mut self, global_time: UInt64) raises:
        var code = raw.engine_set_time_in_pcm_frames(self._lib[], self._ptr, global_time)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("engine set_time_in_frames failed", code))

    def set_time_in_milliseconds(mut self, global_time: UInt64) raises:
        var code = raw.engine_set_time_in_milliseconds(self._lib[], self._ptr, global_time)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("engine set_time_in_milliseconds failed", code)
            )

    # ---- listeners (index-based spatialization) ----

    def listener_count(self) -> UInt32:
        return raw.engine_get_listener_count(self._lib[], self._ptr)

    def find_closest_listener(self, x: Float32, y: Float32, z: Float32) -> UInt32:
        return raw.engine_find_closest_listener(self._lib[], self._ptr, x, y, z)

    def set_listener_position(
        mut self, index: UInt32, x: Float32, y: Float32, z: Float32
    ):
        raw.engine_listener_set_position(self._lib[], self._ptr, index, x, y, z)

    def listener_position(self, index: UInt32) -> Vec3:
        return raw.engine_listener_get_position(self._lib[], self._ptr, index)

    def set_listener_direction(
        mut self, index: UInt32, x: Float32, y: Float32, z: Float32
    ):
        raw.engine_listener_set_direction(self._lib[], self._ptr, index, x, y, z)

    def listener_direction(self, index: UInt32) -> Vec3:
        return raw.engine_listener_get_direction(self._lib[], self._ptr, index)

    def set_listener_velocity(
        mut self, index: UInt32, x: Float32, y: Float32, z: Float32
    ):
        raw.engine_listener_set_velocity(self._lib[], self._ptr, index, x, y, z)

    def listener_velocity(self, index: UInt32) -> Vec3:
        return raw.engine_listener_get_velocity(self._lib[], self._ptr, index)

    def set_listener_world_up(
        mut self, index: UInt32, x: Float32, y: Float32, z: Float32
    ):
        raw.engine_listener_set_world_up(self._lib[], self._ptr, index, x, y, z)

    def listener_world_up(self, index: UInt32) -> Vec3:
        return raw.engine_listener_get_world_up(self._lib[], self._ptr, index)

    def set_listener_cone(
        mut self,
        index: UInt32,
        inner_angle: Float32,
        outer_angle: Float32,
        outer_gain: Float32,
    ):
        raw.engine_listener_set_cone(
            self._lib[], self._ptr, index, inner_angle, outer_angle, outer_gain
        )

    def listener_cone(self, index: UInt32) -> MaCone:
        return raw.engine_listener_get_cone(self._lib[], self._ptr, index)

    def set_listener_enabled(mut self, index: UInt32, enabled: Bool):
        raw.engine_listener_set_enabled(self._lib[], self._ptr, index, enabled)

    def listener_is_enabled(self, index: UInt32) -> Bool:
        return raw.engine_listener_is_enabled(self._lib[], self._ptr, index) != 0

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.engine_free(self._lib[], self._ptr)
