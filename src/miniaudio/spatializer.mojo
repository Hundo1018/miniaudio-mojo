"""Idiomatic spatializer API (Layer 3).

Two RAII wrappers over miniaudio's standalone 3D-audio DSP objects — the ones
an `Engine` drives underneath every `Sound`, usable here without an engine,
device, or file:

- `SpatializerListener` over ma_spatializer_listener — the ear: position,
  facing, world-up, velocity, cone, speed of sound, enabled flag.
- `Spatializer` over ma_spatializer — one source: position, direction,
  velocity, attenuation model and its distance/gain limits, cone, doppler and
  directional-attenuation factors, master volume. `process` attenuates and
  pans mono (or multichannel) f32 frames as heard by a given listener.

Both can be built either way miniaudio offers: `preallocated=True` routes init
through `get_heap_size` + `init_preallocated` with a shim-owned heap.
`__deinit__` uninits either shape.

Gain changes (moving the source, changing volume) are smoothed by miniaudio's
gainer; in the vendored 0.11.25 the first block after a change overshoots the
new gain, and the following blocks are exact.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MaResult, MaError, MA_SUCCESS
from miniaudio.sound import AttenuationModel, Positioning
from miniaudio._ffi.sound_raw import Vec3, MaCone
import miniaudio._ffi.spatializer_raw as raw


@fieldwise_init
struct RelativeTransform(Copyable, Movable):
    """A source's position and direction in its listener's frame of reference."""

    var position: Vec3
    var direction: Vec3



struct SpatializerListener(Movable):
    """The ear a `Spatializer` renders for (RAII).

    Defaults match miniaudio: at the origin, facing -Z, +Y up, 343.3 m/s, enabled.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib],
        *,
        channels_out: UInt32 = 2,
    ) raises MaError -> UInt64:
        var rc = raw.spatializer_listener_get_heap_size(lib[], channels_out)
        if rc.result != MA_SUCCESS:
            raise lib[].error("spatializer listener heap size failed", rc.result)
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels_out: UInt32 = 2,
        preallocated: Bool = False,
    ) raises MaError -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.spatializer_listener_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "spatializer_listener_alloc failed (out of memory)")

        var code: MaResult
        if preallocated:
            code = raw.spatializer_listener_init_preallocated(lib[], ptr, channels_out)
        else:
            code = raw.spatializer_listener_init(lib[], ptr, channels_out)
        if code != MA_SUCCESS:
            raw.spatializer_listener_free(lib[], ptr)
            raise lib[].error("spatializer listener init failed", code)
        return Self(lib.copy(), ptr)

    def channel_map(self) raises MaError -> List[UInt8]:
        """Output channel map as ma_channel codes (stereo: side left, side right)."""
        var rc = raw.spatializer_listener_get_channel_map(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener channel map query failed", rc.result)
        return rc.value.copy()

    def set_cone(
        mut self, inner_angle: Float32, outer_angle: Float32, outer_gain: Float32
    ) raises MaError:
        """Angles in radians; outside the outer angle the gain is outer_gain."""
        var code = raw.spatializer_listener_set_cone(
            self._lib[], self._ptr, inner_angle, outer_angle, outer_gain
        )
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_cone failed", code)

    def cone(self) raises MaError -> MaCone:
        var rc = raw.spatializer_listener_get_cone(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener cone query failed", rc.result)
        return rc.value.copy()

    def set_position(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_listener_set_position(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_position failed", code)

    def position(self) raises MaError -> Vec3:
        var rc = raw.spatializer_listener_get_position(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener position query failed", rc.result)
        return rc.value.copy()

    def set_direction(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_listener_set_direction(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_direction failed", code)

    def direction(self) raises MaError -> Vec3:
        var rc = raw.spatializer_listener_get_direction(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener direction query failed", rc.result)
        return rc.value.copy()

    def set_velocity(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_listener_set_velocity(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_velocity failed", code)

    def velocity(self) raises MaError -> Vec3:
        var rc = raw.spatializer_listener_get_velocity(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener velocity query failed", rc.result)
        return rc.value.copy()

    def set_speed_of_sound(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_listener_set_speed_of_sound(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_speed_of_sound failed", code)

    def speed_of_sound(self) raises MaError -> Float32:
        var rc = raw.spatializer_listener_get_speed_of_sound(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener speed_of_sound query failed", rc.result)
        return rc.value

    def set_world_up(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_listener_set_world_up(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_world_up failed", code)

    def world_up(self) raises MaError -> Vec3:
        var rc = raw.spatializer_listener_get_world_up(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener world_up query failed", rc.result)
        return rc.value.copy()

    def set_enabled(mut self, enabled: Bool) raises MaError:
        """A disabled listener hears silence."""
        var code = raw.spatializer_listener_set_enabled(self._lib[], self._ptr, enabled)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener set_enabled failed", code)

    def is_enabled(self) raises MaError -> Bool:
        var rc = raw.spatializer_listener_is_enabled(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer listener is_enabled query failed", rc.result)
        return rc.value

    def uninit(mut self) raises MaError:
        """Release the object early; the handle stays valid but empty."""
        var code = raw.spatializer_listener_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer listener uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.spatializer_listener_free(self._lib[], self._ptr)


struct Spatializer(Movable):
    """One 3D sound source (RAII): attenuates and pans f32 frames for a listener.

    Defaults match miniaudio: inverse attenuation, absolute positioning, min
    distance 1, rolloff 1, gain clamped to [0, 1].
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self, var lib: ArcPointer[MaLib], ptr: OpaquePointer[MutUntrackedOrigin]
    ):
        self._lib = lib^
        self._ptr = ptr

    @staticmethod
    def heap_size(
        lib: ArcPointer[MaLib],
        *,
        channels_in: UInt32 = 1,
        channels_out: UInt32 = 2,
    ) raises MaError -> UInt64:
        var rc = raw.spatializer_get_heap_size(lib[], channels_in, channels_out)
        if rc.result != MA_SUCCESS:
            raise lib[].error("spatializer heap size failed", rc.result)
        return rc.value

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels_in: UInt32 = 1,
        channels_out: UInt32 = 2,
        preallocated: Bool = False,
    ) raises MaError -> Self:
        """`preallocated` routes init through miniaudio's preallocated-heap path."""
        var ptr = raw.spatializer_alloc(lib[])
        if ptr == null_handle():
            raise MaError(MaResult.OUT_OF_MEMORY, "spatializer_alloc failed (out of memory)")

        var code: MaResult
        if preallocated:
            code = raw.spatializer_init_preallocated(lib[], ptr, channels_in, channels_out)
        else:
            code = raw.spatializer_init(lib[], ptr, channels_in, channels_out)
        if code != MA_SUCCESS:
            raw.spatializer_free(lib[], ptr)
            raise lib[].error("spatializer init failed", code)
        return Self(lib.copy(), ptr)

    def process(
        mut self, listener: SpatializerListener, input: List[Float32]
    ) raises MaError -> List[Float32]:
        """Spatialize `input` (channels_in interleaved) as heard by `listener`.

        Returns channels_out interleaved frames, one output frame per input frame.
        """
        var channels_in = Int(self.input_channels())
        var channels_out = Int(self.output_channels())
        var frames = len(input) // channels_in
        var out = List[Float32](capacity=frames * channels_out)
        out.resize(frames * channels_out, Float32(0))
        var code = raw.spatializer_process(
            self._lib[], self._ptr, listener._ptr, out, input, UInt64(frames)
        )
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer process failed", code)
        return out^

    def relative_to(self, listener: SpatializerListener) raises MaError -> RelativeTransform:
        """This source's position and direction as seen from `listener`."""
        var rc = raw.spatializer_get_relative_position_and_direction(
            self._lib[], self._ptr, listener._ptr
        )
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer relative transform failed", rc.result)
        return RelativeTransform(rc.position.copy(), rc.direction.copy())

    def set_master_volume(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_master_volume(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_master_volume failed", code)

    def master_volume(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_master_volume(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer master_volume query failed", rc.result)
        return rc.value

    def input_channels(self) raises MaError -> UInt32:
        var rc = raw.spatializer_get_input_channels(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer input_channels query failed", rc.result)
        return rc.value

    def output_channels(self) raises MaError -> UInt32:
        var rc = raw.spatializer_get_output_channels(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer output_channels query failed", rc.result)
        return rc.value

    def set_attenuation_model(mut self, value: AttenuationModel) raises MaError:
        var code = raw.spatializer_set_attenuation_model(self._lib[], self._ptr, value.code)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_attenuation_model failed", code)

    def attenuation_model(self) raises MaError -> AttenuationModel:
        var rc = raw.spatializer_get_attenuation_model(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer attenuation_model query failed", rc.result)
        return AttenuationModel(rc.value)

    def set_positioning(mut self, value: Positioning) raises MaError:
        var code = raw.spatializer_set_positioning(self._lib[], self._ptr, value.code)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_positioning failed", code)

    def positioning(self) raises MaError -> Positioning:
        var rc = raw.spatializer_get_positioning(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer positioning query failed", rc.result)
        return Positioning(rc.value)

    def set_rolloff(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_rolloff(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_rolloff failed", code)

    def rolloff(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_rolloff(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer rolloff query failed", rc.result)
        return rc.value

    def set_min_gain(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_min_gain(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_min_gain failed", code)

    def min_gain(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_min_gain(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer min_gain query failed", rc.result)
        return rc.value

    def set_max_gain(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_max_gain(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_max_gain failed", code)

    def max_gain(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_max_gain(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer max_gain query failed", rc.result)
        return rc.value

    def set_min_distance(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_min_distance(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_min_distance failed", code)

    def min_distance(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_min_distance(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer min_distance query failed", rc.result)
        return rc.value

    def set_max_distance(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_max_distance(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_max_distance failed", code)

    def max_distance(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_max_distance(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer max_distance query failed", rc.result)
        return rc.value

    def set_cone(
        mut self, inner_angle: Float32, outer_angle: Float32, outer_gain: Float32
    ) raises MaError:
        """Angles in radians; outside the outer angle the gain is outer_gain."""
        var code = raw.spatializer_set_cone(
            self._lib[], self._ptr, inner_angle, outer_angle, outer_gain
        )
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_cone failed", code)

    def cone(self) raises MaError -> MaCone:
        var rc = raw.spatializer_get_cone(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer cone query failed", rc.result)
        return rc.value.copy()

    def set_doppler_factor(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_doppler_factor(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_doppler_factor failed", code)

    def doppler_factor(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_doppler_factor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer doppler_factor query failed", rc.result)
        return rc.value

    def set_directional_attenuation_factor(mut self, value: Float32) raises MaError:
        var code = raw.spatializer_set_directional_attenuation_factor(self._lib[], self._ptr, value)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_directional_attenuation_factor failed", code)

    def directional_attenuation_factor(self) raises MaError -> Float32:
        var rc = raw.spatializer_get_directional_attenuation_factor(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer directional_attenuation_factor query failed", rc.result)
        return rc.value

    def set_position(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_set_position(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_position failed", code)

    def position(self) raises MaError -> Vec3:
        var rc = raw.spatializer_get_position(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer position query failed", rc.result)
        return rc.value.copy()

    def set_direction(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_set_direction(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_direction failed", code)

    def direction(self) raises MaError -> Vec3:
        var rc = raw.spatializer_get_direction(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer direction query failed", rc.result)
        return rc.value.copy()

    def set_velocity(mut self, x: Float32, y: Float32, z: Float32) raises MaError:
        var code = raw.spatializer_set_velocity(self._lib[], self._ptr, x, y, z)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer set_velocity failed", code)

    def velocity(self) raises MaError -> Vec3:
        var rc = raw.spatializer_get_velocity(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise self._lib[].error("spatializer velocity query failed", rc.result)
        return rc.value.copy()

    def uninit(mut self) raises MaError:
        """Release the object early; the handle stays valid but empty."""
        var code = raw.spatializer_uninit(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise self._lib[].error("spatializer uninit failed", code)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.spatializer_free(self._lib[], self._ptr)
