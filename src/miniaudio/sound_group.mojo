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
from miniaudio.sound import AttenuationModel, Positioning, PanMode
from miniaudio._ffi.sound_raw import Vec3, MaCone
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

    # ---- spatialization: position / direction / velocity ----

    def set_position(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_group_set_position(self._lib[], self._ptr, x, y, z)

    def position(self) -> Vec3:
        return raw.sound_group_get_position(self._lib[], self._ptr)

    def set_direction(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_group_set_direction(self._lib[], self._ptr, x, y, z)

    def direction(self) -> Vec3:
        return raw.sound_group_get_direction(self._lib[], self._ptr)

    def direction_to_listener(self) -> Vec3:
        return raw.sound_group_get_direction_to_listener(self._lib[], self._ptr)

    def set_velocity(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_group_set_velocity(self._lib[], self._ptr, x, y, z)

    def velocity(self) -> Vec3:
        return raw.sound_group_get_velocity(self._lib[], self._ptr)

    # ---- spatialization: models & scalar params ----

    def set_attenuation_model(mut self, model: AttenuationModel):
        raw.sound_group_set_attenuation_model(self._lib[], self._ptr, model.code)

    def attenuation_model(self) -> AttenuationModel:
        return AttenuationModel(
            raw.sound_group_get_attenuation_model(self._lib[], self._ptr)
        )

    def set_positioning(mut self, positioning: Positioning):
        raw.sound_group_set_positioning(self._lib[], self._ptr, positioning.code)

    def positioning(self) -> Positioning:
        return Positioning(raw.sound_group_get_positioning(self._lib[], self._ptr))

    def set_rolloff(mut self, rolloff: Float32):
        raw.sound_group_set_rolloff(self._lib[], self._ptr, rolloff)

    def rolloff(self) -> Float32:
        return raw.sound_group_get_rolloff(self._lib[], self._ptr)

    def set_min_gain(mut self, min_gain: Float32):
        raw.sound_group_set_min_gain(self._lib[], self._ptr, min_gain)

    def min_gain(self) -> Float32:
        return raw.sound_group_get_min_gain(self._lib[], self._ptr)

    def set_max_gain(mut self, max_gain: Float32):
        raw.sound_group_set_max_gain(self._lib[], self._ptr, max_gain)

    def max_gain(self) -> Float32:
        return raw.sound_group_get_max_gain(self._lib[], self._ptr)

    def set_min_distance(mut self, min_distance: Float32):
        raw.sound_group_set_min_distance(self._lib[], self._ptr, min_distance)

    def min_distance(self) -> Float32:
        return raw.sound_group_get_min_distance(self._lib[], self._ptr)

    def set_max_distance(mut self, max_distance: Float32):
        raw.sound_group_set_max_distance(self._lib[], self._ptr, max_distance)

    def max_distance(self) -> Float32:
        return raw.sound_group_get_max_distance(self._lib[], self._ptr)

    def set_cone(
        mut self, inner_angle: Float32, outer_angle: Float32, outer_gain: Float32
    ):
        raw.sound_group_set_cone(
            self._lib[], self._ptr, inner_angle, outer_angle, outer_gain
        )

    def cone(self) -> MaCone:
        return raw.sound_group_get_cone(self._lib[], self._ptr)

    def set_doppler_factor(mut self, factor: Float32):
        raw.sound_group_set_doppler_factor(self._lib[], self._ptr, factor)

    def doppler_factor(self) -> Float32:
        return raw.sound_group_get_doppler_factor(self._lib[], self._ptr)

    def set_directional_attenuation_factor(mut self, factor: Float32):
        raw.sound_group_set_directional_attenuation_factor(self._lib[], self._ptr, factor)

    def directional_attenuation_factor(self) -> Float32:
        return raw.sound_group_get_directional_attenuation_factor(self._lib[], self._ptr)

    def set_pan_mode(mut self, pan_mode: PanMode):
        raw.sound_group_set_pan_mode(self._lib[], self._ptr, pan_mode.code)

    def pan_mode(self) -> PanMode:
        return PanMode(raw.sound_group_get_pan_mode(self._lib[], self._ptr))

    def set_pinned_listener_index(mut self, index: UInt32):
        raw.sound_group_set_pinned_listener_index(self._lib[], self._ptr, index)

    def pinned_listener_index(self) -> UInt32:
        return raw.sound_group_get_pinned_listener_index(self._lib[], self._ptr)

    def listener_index(self) -> UInt32:
        return raw.sound_group_get_listener_index(self._lib[], self._ptr)

    # ---- fade ----

    def set_fade_in_pcm_frames(
        mut self, vol_beg: Float32, vol_end: Float32, len_frames: UInt64
    ):
        raw.sound_group_set_fade_in_pcm_frames(
            self._lib[], self._ptr, vol_beg, vol_end, len_frames
        )

    def set_fade_in_milliseconds(
        mut self, vol_beg: Float32, vol_end: Float32, len_ms: UInt64
    ):
        raw.sound_group_set_fade_in_milliseconds(
            self._lib[], self._ptr, vol_beg, vol_end, len_ms
        )

    def current_fade_volume(self) -> Float32:
        return raw.sound_group_get_current_fade_volume(self._lib[], self._ptr)

    # ---- start/stop time scheduling ----

    def set_start_time_in_pcm_frames(mut self, abs_time: UInt64):
        raw.sound_group_set_start_time_in_pcm_frames(self._lib[], self._ptr, abs_time)

    def set_start_time_in_milliseconds(mut self, abs_time: UInt64):
        raw.sound_group_set_start_time_in_milliseconds(self._lib[], self._ptr, abs_time)

    def set_stop_time_in_pcm_frames(mut self, abs_time: UInt64):
        raw.sound_group_set_stop_time_in_pcm_frames(self._lib[], self._ptr, abs_time)

    def set_stop_time_in_milliseconds(mut self, abs_time: UInt64):
        raw.sound_group_set_stop_time_in_milliseconds(self._lib[], self._ptr, abs_time)

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.sound_group_free(self._lib[], self._ptr)
