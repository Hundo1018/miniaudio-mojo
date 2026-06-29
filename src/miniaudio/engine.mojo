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

    def time_in_frames(self) -> UInt64:
        return raw.engine_get_time_in_pcm_frames(self._lib[], self._ptr)

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.engine_free(self._lib[], self._ptr)
