"""Binding layer: raw 1:1 wrappers over the spatializer shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in
spatializer.mojo.

Two object kinds share this module: `ma_spatializer_listener` (the ear) and
`ma_spatializer` (one source). Every shim entry point returns a result code, so
the getters come back as (result, value) pairs here and an uninitialised handle
is observable as MA_INVALID_ARGS rather than a silent default.

Frames are f32: miniaudio's spatializer supports no other format.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.decoder_raw import MaCount
from miniaudio._ffi.converter_raw import MaChannelMap
from miniaudio._ffi.sound_raw import Vec3, MaCone


@fieldwise_init
struct MaFloat(Copyable, Movable):
    """Raw (result_code, value) pair for a float getter."""

    var result: Int
    var value: Float32


@fieldwise_init
struct MaU32(Copyable, Movable):
    """Raw (result_code, value) pair for an unsigned getter (channels, enum codes)."""

    var result: Int
    var value: UInt32


@fieldwise_init
struct MaBool(Copyable, Movable):
    """Raw (result_code, value) pair for a boolean getter."""

    var result: Int
    var value: Bool


@fieldwise_init
struct MaVec3(Copyable, Movable):
    """Raw (result_code, vector) pair for a getter returning an ma_vec3f."""

    var result: Int
    var value: Vec3


@fieldwise_init
struct MaConeResult(Copyable, Movable):
    """Raw (result_code, cone) pair for get_cone."""

    var result: Int
    var value: MaCone


@fieldwise_init
struct MaRelative(Copyable, Movable):
    """Raw (result_code, position, direction) for get_relative_position_and_direction."""

    var result: Int
    var position: Vec3
    var direction: Vec3


comptime _CHANNEL_MAP_CAPACITY: Int = 32


# ================= ma_spatializer_listener =================

def spatializer_listener_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_spatializer_listener_alloc", OpaquePointer[MutUntrackedOrigin]]()


def spatializer_listener_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_spatializer_listener_free", NoneType](h)


def spatializer_listener_get_heap_size(
    lib: MaLib,
    channels_out: UInt32,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_heap_size", Int32](
            channels_out, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def spatializer_listener_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels_out: UInt32,
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_init", Int32](h, channels_out))


def spatializer_listener_init_preallocated(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels_out: UInt32,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_spatializer_listener_init_preallocated", Int32](h, channels_out)
    )


def spatializer_listener_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_uninit", Int32](h))

def spatializer_listener_get_channel_map(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaChannelMap:
    """The listener's output channel map (one ma_channel code per output channel)."""
    var buf = List[UInt8](capacity=_CHANNEL_MAP_CAPACITY)
    buf.resize(_CHANNEL_MAP_CAPACITY, UInt8(0))
    var count = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_channel_map", Int32](
            h, buf.unsafe_ptr(), UInt32(_CHANNEL_MAP_CAPACITY), count.unsafe_ptr()
        )
    )
    buf.resize(Int(count[0]), UInt8(0))
    return MaChannelMap(code, buf^)

def spatializer_listener_set_cone(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    inner_angle: Float32,
    outer_angle: Float32,
    outer_gain: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_spatializer_listener_set_cone", Int32](
            h, inner_angle, outer_angle, outer_gain
        )
    )


def spatializer_listener_get_cone(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaConeResult:
    var inner = [Float32(0)]
    var outer = [Float32(0)]
    var gain = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_cone", Int32](
            h, inner.unsafe_ptr(), outer.unsafe_ptr(), gain.unsafe_ptr()
        )
    )
    return MaConeResult(code, MaCone(inner[0], outer[0], gain[0]))

def spatializer_listener_set_position(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_set_position", Int32](h, x, y, z))


def spatializer_listener_get_position(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_position", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_listener_set_direction(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_set_direction", Int32](h, x, y, z))


def spatializer_listener_get_direction(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_direction", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_listener_set_velocity(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_set_velocity", Int32](h, x, y, z))


def spatializer_listener_get_velocity(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_velocity", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_listener_set_speed_of_sound(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_set_speed_of_sound", Int32](h, value))


def spatializer_listener_get_speed_of_sound(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_speed_of_sound", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_listener_set_world_up(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_listener_set_world_up", Int32](h, x, y, z))


def spatializer_listener_get_world_up(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_get_world_up", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_listener_set_enabled(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], enabled: Bool) -> Int:
    return Int(
        lib.handle.call["ma_shim_spatializer_listener_set_enabled", Int32](h, Int32(1 if enabled else 0))
    )


def spatializer_listener_is_enabled(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_listener_is_enabled", Int32](h, holder.unsafe_ptr())
    )
    return MaBool(code, holder[0] != 0)


# ================= ma_spatializer =================

def spatializer_alloc(lib: MaLib) -> OpaquePointer[MutUntrackedOrigin]:
    return lib.handle.call["ma_shim_spatializer_alloc", OpaquePointer[MutUntrackedOrigin]]()


def spatializer_free(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]):
    lib.handle.call["ma_shim_spatializer_free", NoneType](h)


def spatializer_get_heap_size(
    lib: MaLib,
    channels_in: UInt32,
    channels_out: UInt32,
) -> MaCount:
    var holder = [UInt64(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_heap_size", Int32](
            channels_in, channels_out, holder.unsafe_ptr()
        )
    )
    return MaCount(code, holder[0])


def spatializer_init(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels_in: UInt32,
    channels_out: UInt32,
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_init", Int32](h, channels_in, channels_out))


def spatializer_init_preallocated(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    channels_in: UInt32,
    channels_out: UInt32,
) -> Int:
    """Init through miniaudio's preallocated-heap path with a shim-owned block."""
    return Int(
        lib.handle.call["ma_shim_spatializer_init_preallocated", Int32](h, channels_in, channels_out)
    )


def spatializer_uninit(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_uninit", Int32](h))

def spatializer_process(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    listener: OpaquePointer[MutUntrackedOrigin],
    mut output: List[Float32],
    input: List[Float32],
    frame_count: UInt64,
) -> Int:
    """Spatialize frame_count f32 frames from input into output, heard by listener."""
    return Int(
        lib.handle.call["ma_shim_spatializer_process", Int32](
            h, listener, output.unsafe_ptr(), input.unsafe_ptr(), frame_count
        )
    )

def spatializer_set_master_volume(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_master_volume", Int32](h, value))


def spatializer_get_master_volume(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_master_volume", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_get_input_channels(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_input_channels", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])

def spatializer_get_output_channels(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_output_channels", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])

def spatializer_set_attenuation_model(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], code: UInt32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_attenuation_model", Int32](h, code))

def spatializer_get_attenuation_model(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_attenuation_model", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])

def spatializer_set_positioning(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], code: UInt32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_positioning", Int32](h, code))

def spatializer_get_positioning(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaU32:
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_positioning", Int32](h, holder.unsafe_ptr())
    )
    return MaU32(code, holder[0])

def spatializer_set_rolloff(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_rolloff", Int32](h, value))


def spatializer_get_rolloff(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_rolloff", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_min_gain(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_min_gain", Int32](h, value))


def spatializer_get_min_gain(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_min_gain", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_max_gain(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_max_gain", Int32](h, value))


def spatializer_get_max_gain(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_max_gain", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_min_distance(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_min_distance", Int32](h, value))


def spatializer_get_min_distance(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_min_distance", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_max_distance(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_max_distance", Int32](h, value))


def spatializer_get_max_distance(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_max_distance", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_cone(
    lib: MaLib,
    h: OpaquePointer[MutUntrackedOrigin],
    inner_angle: Float32,
    outer_angle: Float32,
    outer_gain: Float32,
) -> Int:
    return Int(
        lib.handle.call["ma_shim_spatializer_set_cone", Int32](
            h, inner_angle, outer_angle, outer_gain
        )
    )


def spatializer_get_cone(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaConeResult:
    var inner = [Float32(0)]
    var outer = [Float32(0)]
    var gain = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_cone", Int32](
            h, inner.unsafe_ptr(), outer.unsafe_ptr(), gain.unsafe_ptr()
        )
    )
    return MaConeResult(code, MaCone(inner[0], outer[0], gain[0]))

def spatializer_set_doppler_factor(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_doppler_factor", Int32](h, value))


def spatializer_get_doppler_factor(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_doppler_factor", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_directional_attenuation_factor(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], value: Float32) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_directional_attenuation_factor", Int32](h, value))


def spatializer_get_directional_attenuation_factor(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaFloat:
    var holder = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_directional_attenuation_factor", Int32](h, holder.unsafe_ptr())
    )
    return MaFloat(code, holder[0])

def spatializer_set_position(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_position", Int32](h, x, y, z))


def spatializer_get_position(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_position", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_set_direction(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_direction", Int32](h, x, y, z))


def spatializer_get_direction(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_direction", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_set_velocity(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], x: Float32, y: Float32, z: Float32
) -> Int:
    return Int(lib.handle.call["ma_shim_spatializer_set_velocity", Int32](h, x, y, z))


def spatializer_get_velocity(lib: MaLib, h: OpaquePointer[MutUntrackedOrigin]) -> MaVec3:
    var xs = [Float32(0)]
    var ys = [Float32(0)]
    var zs = [Float32(0)]
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_velocity", Int32](
            h, xs.unsafe_ptr(), ys.unsafe_ptr(), zs.unsafe_ptr()
        )
    )
    return MaVec3(code, Vec3(xs[0], ys[0], zs[0]))

def spatializer_get_relative_position_and_direction(
    lib: MaLib, h: OpaquePointer[MutUntrackedOrigin], listener: OpaquePointer[MutUntrackedOrigin]
) -> MaRelative:
    """The source's position and direction in the listener's frame of reference."""
    var pos = List[Float32](capacity=3)
    pos.resize(3, Float32(0))
    var dir = List[Float32](capacity=3)
    dir.resize(3, Float32(0))
    var code = Int(
        lib.handle.call["ma_shim_spatializer_get_relative_position_and_direction", Int32](
            h, listener, pos.unsafe_ptr(), dir.unsafe_ptr()
        )
    )
    return MaRelative(
        code, Vec3(pos[0], pos[1], pos[2]), Vec3(dir[0], dir[1], dir[2])
    )
