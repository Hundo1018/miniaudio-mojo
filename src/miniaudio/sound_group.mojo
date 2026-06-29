"""Idiomatic sound group API (Layer 3).

`SoundGroup` is an RAII wrapper around ma_sound_group — a mixing bus owned by an
`Engine`, attached to the engine endpoint. It shares volume/pan/pitch/
spatialization across sounds routed through it. Like `Sound`, it holds an
`ArcPointer[Engine]` so the engine outlives it; `__del__` uninits the group
(while the engine is still valid).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.engine import Engine
import miniaudio._ffi.sound_group_raw as raw


struct SoundGroup(Movable):
    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]  # keeps the owning engine alive
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr

    @staticmethod
    def create(engine: ArcPointer[Engine], *, flags: UInt32 = 0) raises -> Self:
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_group_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_group_alloc failed (out of memory)")
        var code = raw.sound_group_init(lib[], ptr, engine[]._ptr, flags)
        if code != MA_SUCCESS:
            raw.sound_group_free(lib[], ptr)
            raise Error(lib[].describe("sound group init failed", code))
        return Self(lib^, engine.copy(), ptr)

    def start(mut self) raises:
        var code = raw.sound_group_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound group start failed", code))

    def stop(mut self) raises:
        var code = raw.sound_group_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound group stop failed", code))

    def set_volume(mut self, volume: Float32) raises:
        if raw.sound_group_set_volume(self._lib[], self._ptr, volume) != MA_SUCCESS:
            raise Error("sound group set_volume on uninitialized group")

    def volume(self) -> Float32:
        return raw.sound_group_get_volume(self._lib[], self._ptr)

    def set_pan(mut self, pan: Float32) raises:
        if raw.sound_group_set_pan(self._lib[], self._ptr, pan) != MA_SUCCESS:
            raise Error("sound group set_pan on uninitialized group")

    def pan(self) -> Float32:
        return raw.sound_group_get_pan(self._lib[], self._ptr)

    def set_pitch(mut self, pitch: Float32) raises:
        if raw.sound_group_set_pitch(self._lib[], self._ptr, pitch) != MA_SUCCESS:
            raise Error("sound group set_pitch on uninitialized group")

    def pitch(self) -> Float32:
        return raw.sound_group_get_pitch(self._lib[], self._ptr)

    def set_spatialization_enabled(mut self, enabled: Bool) raises:
        if (
            raw.sound_group_set_spatialization_enabled(self._lib[], self._ptr, enabled)
            != MA_SUCCESS
        ):
            raise Error("sound group set_spatialization_enabled on uninitialized group")

    def is_spatialization_enabled(self) -> Bool:
        return raw.sound_group_is_spatialization_enabled(self._lib[], self._ptr) != 0

    def is_playing(self) -> Bool:
        return raw.sound_group_is_playing(self._lib[], self._ptr) != 0

    def time_in_frames(self) -> UInt64:
        return raw.sound_group_get_time_in_pcm_frames(self._lib[], self._ptr)

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.sound_group_free(self._lib[], self._ptr)
