"""Idiomatic sound API (Layer 3).

`Sound` is an RAII wrapper around ma_sound — a single playable sound owned by an
`Engine`. It is created from a file against an engine, and supports start/stop,
volume/pan/pitch, looping, spatialization, seeking, and cursor/length queries.

A sound must not outlive its engine, so `Sound` holds an `ArcPointer[Engine]`
that keeps the engine alive; `__del__` uninits the sound (while the engine is
still valid) before releasing that reference. `at_end()` polls completion (the
constrained, shim-friendly stand-in for ma_sound_set_end_callback).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import SampleFormat
from miniaudio.engine import Engine
from miniaudio._ffi.sound_raw import Vec3, MaCone, MaDataFormat
import miniaudio._ffi.sound_raw as raw


@fieldwise_init
struct AttenuationModel(ImplicitlyCopyable, Movable, Equatable):
    """Spatial distance attenuation model. Codes match ma_attenuation_model."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime ATTENUATION_NONE = AttenuationModel(0)
comptime ATTENUATION_INVERSE = AttenuationModel(1)
comptime ATTENUATION_LINEAR = AttenuationModel(2)
comptime ATTENUATION_EXPONENTIAL = AttenuationModel(3)


@fieldwise_init
struct Positioning(ImplicitlyCopyable, Movable, Equatable):
    """Spatial positioning mode. Codes match ma_positioning."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime POSITIONING_ABSOLUTE = Positioning(0)
comptime POSITIONING_RELATIVE = Positioning(1)


@fieldwise_init
struct PanMode(ImplicitlyCopyable, Movable, Equatable):
    """Stereo pan mode. Codes match ma_pan_mode."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime PAN_MODE_BALANCE = PanMode(0)
comptime PAN_MODE_PAN = PanMode(1)


@fieldwise_init
struct DataFormat(ImplicitlyCopyable, Movable):
    """Resolved output data format of a sound (format/channels/sample_rate)."""

    var format: SampleFormat
    var channels: UInt32
    var sample_rate: UInt32


struct Sound(Movable):
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
    def from_file(
        engine: ArcPointer[Engine], path: String, *, flags: UInt32 = 0
    ) raises -> Self:
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_alloc failed (out of memory)")
        var code = raw.sound_init_from_file(lib[], ptr, engine[]._ptr, path, flags)
        if code != MA_SUCCESS:
            raw.sound_free(lib[], ptr)
            raise Error(lib[].describe("sound init from file failed", code))
        return Self(lib^, engine.copy(), ptr)

    def start(mut self) raises:
        var code = raw.sound_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound start failed", code))

    def stop(mut self) raises:
        var code = raw.sound_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound stop failed", code))

    def set_volume(mut self, volume: Float32) raises:
        if raw.sound_set_volume(self._lib[], self._ptr, volume) != MA_SUCCESS:
            raise Error("sound set_volume on uninitialized sound")

    def volume(self) -> Float32:
        return raw.sound_get_volume(self._lib[], self._ptr)

    def set_pan(mut self, pan: Float32) raises:
        if raw.sound_set_pan(self._lib[], self._ptr, pan) != MA_SUCCESS:
            raise Error("sound set_pan on uninitialized sound")

    def pan(self) -> Float32:
        return raw.sound_get_pan(self._lib[], self._ptr)

    def set_pitch(mut self, pitch: Float32) raises:
        if raw.sound_set_pitch(self._lib[], self._ptr, pitch) != MA_SUCCESS:
            raise Error("sound set_pitch on uninitialized sound")

    def pitch(self) -> Float32:
        return raw.sound_get_pitch(self._lib[], self._ptr)

    def set_looping(mut self, looping: Bool) raises:
        if raw.sound_set_looping(self._lib[], self._ptr, looping) != MA_SUCCESS:
            raise Error("sound set_looping on uninitialized sound")

    def is_looping(self) -> Bool:
        return raw.sound_is_looping(self._lib[], self._ptr) != 0

    def is_playing(self) -> Bool:
        return raw.sound_is_playing(self._lib[], self._ptr) != 0

    def at_end(self) -> Bool:
        return raw.sound_at_end(self._lib[], self._ptr) != 0

    def set_spatialization_enabled(mut self, enabled: Bool) raises:
        if (
            raw.sound_set_spatialization_enabled(self._lib[], self._ptr, enabled)
            != MA_SUCCESS
        ):
            raise Error("sound set_spatialization_enabled on uninitialized sound")

    def is_spatialization_enabled(self) -> Bool:
        return raw.sound_is_spatialization_enabled(self._lib[], self._ptr) != 0

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.sound_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound seek failed", code))

    def cursor(self) raises -> UInt64:
        var c = raw.sound_get_cursor_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("sound cursor query failed", c.result))
        return c.value

    def length_in_frames(self) raises -> UInt64:
        var c = raw.sound_get_length_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("sound length query failed", c.result))
        return c.value

    # ---- seconds-based cursor / seek ----

    def seek_to_second(mut self, seek_point: Float32) raises:
        var code = raw.sound_seek_to_second(self._lib[], self._ptr, seek_point)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound seek_to_second failed", code))

    def cursor_in_seconds(self) raises -> Float32:
        var c = raw.sound_get_cursor_in_seconds(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("sound cursor(s) query failed", c.result)
            )
        return c.value

    def length_in_seconds(self) raises -> Float32:
        var c = raw.sound_get_length_in_seconds(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("sound length(s) query failed", c.result)
            )
        return c.value

    def data_format(self) raises -> DataFormat:
        var d = raw.sound_get_data_format(self._lib[], self._ptr)
        if d.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("sound data_format query failed", d.result)
            )
        return DataFormat(SampleFormat(d.format), d.channels, d.sample_rate)

    # ---- spatialization: position / direction / velocity ----

    def set_position(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_set_position(self._lib[], self._ptr, x, y, z)

    def position(self) -> Vec3:
        return raw.sound_get_position(self._lib[], self._ptr)

    def set_direction(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_set_direction(self._lib[], self._ptr, x, y, z)

    def direction(self) -> Vec3:
        return raw.sound_get_direction(self._lib[], self._ptr)

    def direction_to_listener(self) -> Vec3:
        return raw.sound_get_direction_to_listener(self._lib[], self._ptr)

    def set_velocity(mut self, x: Float32, y: Float32, z: Float32):
        raw.sound_set_velocity(self._lib[], self._ptr, x, y, z)

    def velocity(self) -> Vec3:
        return raw.sound_get_velocity(self._lib[], self._ptr)

    # ---- spatialization: models & scalar params ----

    def set_attenuation_model(mut self, model: AttenuationModel):
        raw.sound_set_attenuation_model(self._lib[], self._ptr, model.code)

    def attenuation_model(self) -> AttenuationModel:
        return AttenuationModel(
            raw.sound_get_attenuation_model(self._lib[], self._ptr)
        )

    def set_positioning(mut self, positioning: Positioning):
        raw.sound_set_positioning(self._lib[], self._ptr, positioning.code)

    def positioning(self) -> Positioning:
        return Positioning(raw.sound_get_positioning(self._lib[], self._ptr))

    def set_rolloff(mut self, rolloff: Float32):
        raw.sound_set_rolloff(self._lib[], self._ptr, rolloff)

    def rolloff(self) -> Float32:
        return raw.sound_get_rolloff(self._lib[], self._ptr)

    def set_min_gain(mut self, min_gain: Float32):
        raw.sound_set_min_gain(self._lib[], self._ptr, min_gain)

    def min_gain(self) -> Float32:
        return raw.sound_get_min_gain(self._lib[], self._ptr)

    def set_max_gain(mut self, max_gain: Float32):
        raw.sound_set_max_gain(self._lib[], self._ptr, max_gain)

    def max_gain(self) -> Float32:
        return raw.sound_get_max_gain(self._lib[], self._ptr)

    def set_min_distance(mut self, min_distance: Float32):
        raw.sound_set_min_distance(self._lib[], self._ptr, min_distance)

    def min_distance(self) -> Float32:
        return raw.sound_get_min_distance(self._lib[], self._ptr)

    def set_max_distance(mut self, max_distance: Float32):
        raw.sound_set_max_distance(self._lib[], self._ptr, max_distance)

    def max_distance(self) -> Float32:
        return raw.sound_get_max_distance(self._lib[], self._ptr)

    def set_cone(
        mut self, inner_angle: Float32, outer_angle: Float32, outer_gain: Float32
    ):
        raw.sound_set_cone(
            self._lib[], self._ptr, inner_angle, outer_angle, outer_gain
        )

    def cone(self) -> MaCone:
        return raw.sound_get_cone(self._lib[], self._ptr)

    def set_doppler_factor(mut self, factor: Float32):
        raw.sound_set_doppler_factor(self._lib[], self._ptr, factor)

    def doppler_factor(self) -> Float32:
        return raw.sound_get_doppler_factor(self._lib[], self._ptr)

    def set_directional_attenuation_factor(mut self, factor: Float32):
        raw.sound_set_directional_attenuation_factor(self._lib[], self._ptr, factor)

    def directional_attenuation_factor(self) -> Float32:
        return raw.sound_get_directional_attenuation_factor(self._lib[], self._ptr)

    def set_pan_mode(mut self, pan_mode: PanMode):
        raw.sound_set_pan_mode(self._lib[], self._ptr, pan_mode.code)

    def pan_mode(self) -> PanMode:
        return PanMode(raw.sound_get_pan_mode(self._lib[], self._ptr))

    def set_pinned_listener_index(mut self, index: UInt32):
        raw.sound_set_pinned_listener_index(self._lib[], self._ptr, index)

    def pinned_listener_index(self) -> UInt32:
        return raw.sound_get_pinned_listener_index(self._lib[], self._ptr)

    def listener_index(self) -> UInt32:
        return raw.sound_get_listener_index(self._lib[], self._ptr)

    # ---- fade ----

    def set_fade_in_pcm_frames(
        mut self, vol_beg: Float32, vol_end: Float32, len_frames: UInt64
    ):
        raw.sound_set_fade_in_pcm_frames(
            self._lib[], self._ptr, vol_beg, vol_end, len_frames
        )

    def set_fade_in_milliseconds(
        mut self, vol_beg: Float32, vol_end: Float32, len_ms: UInt64
    ):
        raw.sound_set_fade_in_milliseconds(
            self._lib[], self._ptr, vol_beg, vol_end, len_ms
        )

    def set_fade_start_in_pcm_frames(
        mut self,
        vol_beg: Float32,
        vol_end: Float32,
        len_frames: UInt64,
        abs_time_frames: UInt64,
    ):
        raw.sound_set_fade_start_in_pcm_frames(
            self._lib[], self._ptr, vol_beg, vol_end, len_frames, abs_time_frames
        )

    def set_fade_start_in_milliseconds(
        mut self,
        vol_beg: Float32,
        vol_end: Float32,
        len_ms: UInt64,
        abs_time_ms: UInt64,
    ):
        raw.sound_set_fade_start_in_milliseconds(
            self._lib[], self._ptr, vol_beg, vol_end, len_ms, abs_time_ms
        )

    def current_fade_volume(self) -> Float32:
        return raw.sound_get_current_fade_volume(self._lib[], self._ptr)

    def reset_fade(mut self):
        raw.sound_reset_fade(self._lib[], self._ptr)

    # ---- start/stop time scheduling ----

    def set_start_time_in_pcm_frames(mut self, abs_time: UInt64):
        raw.sound_set_start_time_in_pcm_frames(self._lib[], self._ptr, abs_time)

    def set_start_time_in_milliseconds(mut self, abs_time: UInt64):
        raw.sound_set_start_time_in_milliseconds(self._lib[], self._ptr, abs_time)

    def set_stop_time_in_pcm_frames(mut self, abs_time: UInt64):
        raw.sound_set_stop_time_in_pcm_frames(self._lib[], self._ptr, abs_time)

    def set_stop_time_in_milliseconds(mut self, abs_time: UInt64):
        raw.sound_set_stop_time_in_milliseconds(self._lib[], self._ptr, abs_time)

    def set_stop_time_with_fade_in_pcm_frames(
        mut self, stop_time: UInt64, fade_len: UInt64
    ):
        raw.sound_set_stop_time_with_fade_in_pcm_frames(
            self._lib[], self._ptr, stop_time, fade_len
        )

    def set_stop_time_with_fade_in_milliseconds(
        mut self, stop_time: UInt64, fade_len: UInt64
    ):
        raw.sound_set_stop_time_with_fade_in_milliseconds(
            self._lib[], self._ptr, stop_time, fade_len
        )

    def stop_with_fade_in_pcm_frames(mut self, fade_len: UInt64) raises:
        var code = raw.sound_stop_with_fade_in_pcm_frames(
            self._lib[], self._ptr, fade_len
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("sound stop_with_fade failed", code)
            )

    def stop_with_fade_in_milliseconds(mut self, fade_len: UInt64) raises:
        var code = raw.sound_stop_with_fade_in_milliseconds(
            self._lib[], self._ptr, fade_len
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("sound stop_with_fade(ms) failed", code)
            )

    def reset_start_time(mut self):
        raw.sound_reset_start_time(self._lib[], self._ptr)

    def reset_stop_time(mut self):
        raw.sound_reset_stop_time(self._lib[], self._ptr)

    def reset_stop_time_and_fade(mut self):
        raw.sound_reset_stop_time_and_fade(self._lib[], self._ptr)

    def time_in_frames(self) -> UInt64:
        return raw.sound_get_time_in_pcm_frames(self._lib[], self._ptr)

    def time_in_milliseconds(self) -> UInt64:
        return raw.sound_get_time_in_milliseconds(self._lib[], self._ptr)

    @staticmethod
    def copy_of(existing: Sound, *, flags: UInt32 = 0) raises -> Self:
        """Create an independent Sound that shares `existing`'s data source."""
        var lib = existing._lib.copy()
        var ptr = raw.sound_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_alloc failed (out of memory)")
        var code = raw.sound_init_copy(
            lib[], ptr, existing._engine[]._ptr, existing._ptr, flags
        )
        if code != MA_SUCCESS:
            raw.sound_free(lib[], ptr)
            raise Error(lib[].describe("sound init_copy failed", code))
        return Self(lib^, existing._engine.copy(), ptr)

    def __del__(deinit self):
        # Uninit the sound while the engine (held via _engine) is still valid.
        if self._ptr != null_handle():
            raw.sound_free(self._lib[], self._ptr)
