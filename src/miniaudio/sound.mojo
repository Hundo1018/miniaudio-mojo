"""Idiomatic sound API (Layer 3).

`Sound` is an RAII wrapper around ma_sound — a single playable sound owned by an
`Engine`. It is created from a file against an engine, and supports start/stop,
volume/pan/pitch, looping, spatialization, seeking, and cursor/length queries.

A sound must not outlive its engine, so `Sound` holds an `ArcPointer[Engine]`
that keeps the engine alive; `__deinit__` uninits the sound (while the engine is
still valid) before releasing that reference. `at_end()` polls completion (the
constrained, shim-friendly stand-in for ma_sound_set_end_callback).

A sound can come from a file (`from_file`), from a `DataSource` you built
(`from_data_source`; the sound keeps the source alive), or from a `SoundConfig`
(`from_config`), which adds what the other two cannot say: a slice of the source
to play, loop points, an initial seek position, a group or node to feed into.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import SampleFormat
from miniaudio.engine import Engine
from miniaudio.data_source import DataSource
from miniaudio.sound_group import SoundGroup
from miniaudio.node import EngineNode
from miniaudio._sound_types import (
    AttenuationModel,
    Positioning,
    PanMode,
    ATTENUATION_NONE,
    ATTENUATION_INVERSE,
    ATTENUATION_LINEAR,
    ATTENUATION_EXPONENTIAL,
    POSITIONING_ABSOLUTE,
    POSITIONING_RELATIVE,
    PAN_MODE_BALANCE,
    PAN_MODE_PAN,
    SOUND_FLAG_STREAM,
    SOUND_FLAG_DECODE,
    SOUND_FLAG_ASYNC,
    SOUND_FLAG_WAIT_INIT,
    SOUND_FLAG_UNKNOWN_LENGTH,
    SOUND_FLAG_LOOPING,
    SOUND_FLAG_NO_DEFAULT_ATTACHMENT,
    SOUND_FLAG_NO_PITCH,
    SOUND_FLAG_NO_SPATIALIZATION,
    SOUND_SOURCE_CHANNEL_COUNT,
    FRAME_RANGE_END,
)
from miniaudio._ffi.sound_raw import Vec3, MaCone, MaDataFormat
import miniaudio._ffi.sound_raw as raw
import miniaudio._ffi.data_source_raw as dsraw


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
    var _source: Optional[ArcPointer[DataSource]]  # keeps a caller-supplied source alive
    var _group: Optional[ArcPointer[SoundGroup]]  # keeps the group it feeds alive
    var _node: Optional[ArcPointer[EngineNode]]  # keeps the engine node it feeds alive

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr
        self._source = None
        self._group = None
        self._node = None

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

    @staticmethod
    def from_data_source(
        engine: ArcPointer[Engine],
        source: ArcPointer[DataSource],
        *,
        flags: UInt32 = 0,
    ) raises -> Self:
        """A sound that plays from a `DataSource` you built.

        The sound reads the source on the engine's audio thread, so it keeps the
        source alive for as long as it exists. A borrowed view (`Sound.data_source`)
        is refused: it owns nothing for the sound to keep.
        """
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_alloc failed (out of memory)")
        var code = raw.sound_init_from_data_source(
            lib[], ptr, engine[]._ptr, source[]._ptr, flags
        )
        if code != MA_SUCCESS:
            raw.sound_free(lib[], ptr)
            raise Error(lib[].describe("sound init from data source failed", code))
        var snd = Self(lib^, engine.copy(), ptr)
        snd._source = source.copy()
        return snd^

    @staticmethod
    def from_config(engine: ArcPointer[Engine], config: SoundConfig) raises -> Self:
        """A sound built from a `SoundConfig` (ma_sound_init_ex).

        The config supplies a file path, a data source, or neither (which gives a
        group-like sound with no data of its own). The sound keeps alive whatever
        the config handed it: its data source, and the group or engine node it
        feeds into (a node that goes away detaches everything attached to it).
        """
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_alloc failed (out of memory)")
        var code = raw.sound_init_ex(lib[], ptr, engine[]._ptr, config._ptr)
        if code != MA_SUCCESS:
            raw.sound_free(lib[], ptr)
            raise Error(lib[].describe("sound init_ex failed", code))
        var snd = Self(lib^, engine.copy(), ptr)
        snd._source = config._source.copy()
        snd._group = config._group.copy()
        snd._node = config._node.copy()
        return snd^

    def engine(self) raises -> ArcPointer[Engine]:
        """The engine this sound belongs to (ma_sound_get_engine).

        miniaudio hands back the very engine the sound was created against; the
        shim reports that engine's handle, and this checks it is the one held
        here before returning a shared reference to it.
        """
        var handle = raw.sound_get_engine(self._lib[], self._ptr)
        if handle == null_handle():
            raise Error("sound has no engine (not initialised)")
        if handle != self._engine[]._ptr:
            raise Error("sound reports an engine other than the one it was built with")
        return self._engine.copy()

    def data_source(self) raises -> DataSource:
        """A borrowed view of the data source this sound plays from (ma_sound_get_data_source).

        For a sound built with `from_data_source` it is that very source
        (`view.is_same(source)`); for one loaded from a file it is the resource
        manager's source behind it. The view's generic read / seek / range /
        loop-point / format calls act on what the sound plays; dropping it leaves
        the sound alone, and once the sound is gone the view's calls raise.
        """
        var ptr = dsraw.data_source_alloc(self._lib[])
        if ptr == null_handle():
            raise Error("data_source_alloc failed (out of memory)")
        var code = dsraw.data_source_borrow_sound(self._lib[], ptr, self._ptr)
        if code != MA_SUCCESS:
            dsraw.data_source_free(self._lib[], ptr)
            raise Error(self._lib[].describe("sound data source borrow failed", code))
        var fmt = self.data_format()
        return DataSource(self._lib.copy(), ptr, fmt.channels)

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

    def __deinit__(deinit self):
        # Uninit the sound while the engine (held via _engine) is still valid.
        if self._ptr != null_handle():
            raw.sound_free(self._lib[], self._ptr)


struct SoundConfig(Movable):
    """Everything a sound's init can be told (ma_sound_config), behind a handle.

    miniaudio passes this struct around by value; here it lives on the shim's
    heap and is filled in through setters, then handed to `Sound.from_config`.
    `create` starts from miniaudio's defaults (ma_sound_config_init);
    `for_engine` starts from the defaults for one engine (ma_sound_config_init_2),
    which picks up that engine's mono-expansion and pitch-resampling settings.

    Beyond what `Sound.from_file` can say it controls:

    - `set_range` / `set_loop_point`: the slice of the source to play, and where
      a looping sound jumps back to;
    - `set_initial_seek_point`: where in the source playback starts;
    - `set_group` / `set_engine_node`: the node the sound feeds, instead of the
      engine's endpoint;
    - `set_flags`, `set_channels`, `set_volume_smooth_time`, ...

    The config holds whatever it points at (a data source, a group, an engine
    node) alive until it is dropped, so building the sound later is safe.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _source: Optional[ArcPointer[DataSource]]
    var _group: Optional[ArcPointer[SoundGroup]]
    var _node: Optional[ArcPointer[EngineNode]]

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr
        self._source = None
        self._group = None
        self._node = None

    @staticmethod
    def create(lib: ArcPointer[MaLib]) raises -> Self:
        """miniaudio's default config (ma_sound_config_init)."""
        var ptr = raw.sound_config_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_config_alloc failed (out of memory)")
        var code = raw.sound_config_init(lib[], ptr)
        if code != MA_SUCCESS:
            raw.sound_config_free(lib[], ptr)
            raise Error(lib[].describe("sound config init failed", code))
        return Self(lib.copy(), ptr)

    @staticmethod
    def for_engine(engine: ArcPointer[Engine]) raises -> Self:
        """The default config for one engine (ma_sound_config_init_2)."""
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_config_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_config_alloc failed (out of memory)")
        var code = raw.sound_config_init_for_engine(lib[], ptr, engine[]._ptr)
        if code != MA_SUCCESS:
            raw.sound_config_free(lib[], ptr)
            raise Error(lib[].describe("sound config init for engine failed", code))
        return Self(lib^, ptr)

    def set_file_path(mut self, path: String) raises:
        """Load the sound from a file through the engine's resource manager."""
        var code = raw.sound_config_set_file_path(self._lib[], self._ptr, path)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_file_path failed", code))

    def clear_file_path(mut self) raises:
        var code = raw.sound_config_clear_file_path(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config clear_file_path failed", code))

    def set_data_source(mut self, source: ArcPointer[DataSource]) raises:
        """Play from a `DataSource` you built. A borrowed view is refused."""
        var code = raw.sound_config_set_data_source(
            self._lib[], self._ptr, source[]._ptr
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_data_source failed", code))
        self._source = source.copy()

    def clear_data_source(mut self) raises:
        var code = raw.sound_config_set_data_source(
            self._lib[], self._ptr, null_handle()
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config clear_data_source failed", code))
        self._source = None

    def set_group(
        mut self, group: ArcPointer[SoundGroup], *, input_bus: UInt32 = 0
    ) raises:
        """Feed the new sound into a sound group instead of the endpoint."""
        var code = raw.sound_config_set_initial_attachment_group(
            self._lib[], self._ptr, group[]._ptr, input_bus
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_group failed", code))
        self._group = group.copy()
        self._node = None

    def set_engine_node(
        mut self, node: ArcPointer[EngineNode], *, input_bus: UInt32 = 0
    ) raises:
        """Feed the new sound into an `EngineNode` instead of the endpoint."""
        var code = raw.sound_config_set_initial_attachment_node(
            self._lib[], self._ptr, node[]._ptr, input_bus
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_engine_node failed", code))
        self._node = node.copy()
        self._group = None

    def clear_attachment(mut self) raises:
        """Back to the default: attach straight to the engine's endpoint."""
        var code = raw.sound_config_set_initial_attachment_node(
            self._lib[], self._ptr, null_handle(), UInt32(0)
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config clear_attachment failed", code))
        self._group = None
        self._node = None

    def set_flags(mut self, flags: UInt32) raises:
        """`SOUND_FLAG_*` values OR-ed together."""
        var code = raw.sound_config_set_flags(self._lib[], self._ptr, flags)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_flags failed", code))

    def set_channels(
        mut self, channels_in: UInt32, channels_out: UInt32 = UInt32(0)
    ) raises:
        """0 means the engine's channel count; `channels_out` may also be
        `SOUND_SOURCE_CHANNEL_COUNT` to follow the data source."""
        var code = raw.sound_config_set_channels(
            self._lib[], self._ptr, channels_in, channels_out
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_channels failed", code))

    def set_volume_smooth_time(mut self, frames: UInt32) raises:
        """Frames over which volume changes are smoothed (0 for none)."""
        var code = raw.sound_config_set_volume_smooth_time(self._lib[], self._ptr, frames)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_volume_smooth_time failed", code))

    def set_mono_expansion_mode(mut self, mode: Int) raises:
        """An ma_mono_expansion_mode code (0 duplicate, 1 average, 2 stereo-only)."""
        var code = raw.sound_config_set_mono_expansion_mode(self._lib[], self._ptr, mode)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_mono_expansion_mode failed", code))

    def set_initial_seek_point(mut self, frame: UInt64) raises:
        """Where in the source (in frames) playback starts."""
        var code = raw.sound_config_set_initial_seek_point(self._lib[], self._ptr, frame)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_initial_seek_point failed", code))

    def set_range(mut self, beg: UInt64, end: UInt64 = FRAME_RANGE_END) raises:
        """The slice of the source to play; `end` defaults to the end of the source."""
        var code = raw.sound_config_set_range(self._lib[], self._ptr, beg, end)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_range failed", code))

    def set_loop_point(mut self, beg: UInt64, end: UInt64 = FRAME_RANGE_END) raises:
        """Where a looping sound jumps back from (`end`) and to (`beg`)."""
        var code = raw.sound_config_set_loop_point(self._lib[], self._ptr, beg, end)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound config set_loop_point failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.sound_config_free(self._lib[], self._ptr)
