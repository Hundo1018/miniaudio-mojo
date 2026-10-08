"""Binding layer: raw 1:1 wrappers over the channel-map shim functions.

Policy-free: marshals Mojo types to the C ABI and returns raw ma_result codes
or Ma* result/value pairs. No lifecycle / error policy; that lives in
channel_map.mojo.

A channel map is a plain `List[UInt8]` with one entry per channel (a
`ma_channel`). There are no handles. Every buffer is passed with its length, so
the shim refuses one that is too short rather than letting miniaudio run off
its end.

An *empty* list stands for NULL: for the lookup functions miniaudio reads a NULL
map as "the default map for that channel count", and for `copy_or_default` a
NULL input means "fill the default". An empty output list is invalid.
"""

from miniaudio._lib import MaLib
from miniaudio._ffi.device_raw import MaText
from miniaudio._ffi.spatializer_raw import MaU32, MaBool


# ma_standard_channel_map
comptime STANDARD_MAP_MICROSOFT: Int = 0
comptime STANDARD_MAP_DEFAULT: Int = 0
comptime STANDARD_MAP_ALSA: Int = 1
comptime STANDARD_MAP_RFC3551: Int = 2
comptime STANDARD_MAP_FLAC: Int = 3
comptime STANDARD_MAP_VORBIS: Int = 4
comptime STANDARD_MAP_SOUND4: Int = 5
comptime STANDARD_MAP_SNDIO: Int = 6

# ma_channel positions
comptime CHANNEL_NONE: UInt8 = 0
comptime CHANNEL_MONO: UInt8 = 1
comptime CHANNEL_FRONT_LEFT: UInt8 = 2
comptime CHANNEL_FRONT_RIGHT: UInt8 = 3
comptime CHANNEL_FRONT_CENTER: UInt8 = 4
comptime CHANNEL_LFE: UInt8 = 5
comptime CHANNEL_BACK_LEFT: UInt8 = 6
comptime CHANNEL_BACK_RIGHT: UInt8 = 7
comptime CHANNEL_FRONT_LEFT_CENTER: UInt8 = 8
comptime CHANNEL_FRONT_RIGHT_CENTER: UInt8 = 9
comptime CHANNEL_BACK_CENTER: UInt8 = 10
comptime CHANNEL_SIDE_LEFT: UInt8 = 11
comptime CHANNEL_SIDE_RIGHT: UInt8 = 12
comptime CHANNEL_TOP_CENTER: UInt8 = 13
comptime CHANNEL_AUX_0: UInt8 = 20
comptime CHANNEL_AUX_31: UInt8 = 51

comptime TEXT_CAP: Int = 1024
"""Room for the longest channel map miniaudio names (32 channels fit well inside)."""


@fieldwise_init
struct MaFind(Copyable, Movable):
    """Raw (result_code, found, index) from find_channel_position."""

    var result: Int
    var found: Bool
    var index: UInt32


@fieldwise_init
struct MaMapText(Copyable, Movable):
    """Raw (result_code, text, full length) from channel_map_to_string.

    `length` is the length miniaudio computed for the whole map; `text` holds
    only what fitted in the buffer.
    """

    var result: Int
    var text: String
    var length: UInt32


def _addr(map: List[UInt8]) -> Int:
    """The list's address, or 0 (NULL) for an empty list."""
    if len(map) == 0:
        return 0
    return Int(map.unsafe_ptr())


def channel_map_init_blank(lib: MaLib, mut map: List[UInt8], channels: UInt32) -> Int:
    return Int(
        lib.handle.call["ma_shim_channel_map_init_blank", Int32](
            _addr(map), UInt32(len(map)), channels
        )
    )


def channel_map_init_standard(
    lib: MaLib, standard: Int, mut map: List[UInt8], channels: UInt32
) -> Int:
    """Fills at most len(map) entries even when channels is larger."""
    return Int(
        lib.handle.call["ma_shim_channel_map_init_standard", Int32](
            Int32(standard), _addr(map), UInt32(len(map)), channels
        )
    )


def channel_map_copy(
    lib: MaLib, mut out: List[UInt8], inp: List[UInt8], channels: UInt32
) -> Int:
    return Int(
        lib.handle.call["ma_shim_channel_map_copy", Int32](
            _addr(out), UInt32(len(out)), _addr(inp), UInt32(len(inp)), channels
        )
    )


def channel_map_copy_or_default(
    lib: MaLib, mut out: List[UInt8], inp: List[UInt8], channels: UInt32
) -> Int:
    """An empty `inp` fills the default map instead of copying."""
    return Int(
        lib.handle.call["ma_shim_channel_map_copy_or_default", Int32](
            _addr(out), UInt32(len(out)), _addr(inp), UInt32(len(inp)), channels
        )
    )


def channel_map_get_channel(
    lib: MaLib, map: List[UInt8], channel_count: UInt32, channel_index: UInt32
) -> MaU32:
    """An empty `map` reads the default map; an index past the end is CHANNEL_NONE."""
    var holder = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_get_channel", Int32](
            _addr(map), UInt32(len(map)), channel_count, channel_index, holder.unsafe_ptr()
        )
    )
    return MaU32(code, holder[0])


def channel_map_is_valid(lib: MaLib, map: List[UInt8], channels: UInt32) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_is_valid", Int32](
            _addr(map), UInt32(len(map)), channels, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)


def channel_map_is_equal(
    lib: MaLib, a: List[UInt8], b: List[UInt8], channels: UInt32
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_is_equal", Int32](
            _addr(a), UInt32(len(a)), _addr(b), UInt32(len(b)), channels, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)


def channel_map_is_blank(lib: MaLib, map: List[UInt8], channels: UInt32) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_is_blank", Int32](
            _addr(map), UInt32(len(map)), channels, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)


def channel_map_contains_channel_position(
    lib: MaLib, channels: UInt32, map: List[UInt8], position: UInt32
) -> MaBool:
    var holder = [Int32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_contains_channel_position", Int32](
            channels, _addr(map), UInt32(len(map)), position, holder.unsafe_ptr()
        )
    )
    return MaBool(code, holder[0] != 0)


def channel_map_find_channel_position(
    lib: MaLib, channels: UInt32, map: List[UInt8], position: UInt32
) -> MaFind:
    var found = [Int32(0)]
    var index = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_find_channel_position", Int32](
            channels,
            _addr(map),
            UInt32(len(map)),
            position,
            found.unsafe_ptr(),
            index.unsafe_ptr(),
        )
    )
    return MaFind(code, found[0] != 0, index[0])


def channel_map_to_string(
    lib: MaLib, map: List[UInt8], channels: UInt32, capacity: Int = TEXT_CAP
) -> MaMapText:
    """Space-separated channel names; whole names that do not fit are dropped."""
    var buf = List[UInt8](capacity=capacity)
    buf.resize(capacity, UInt8(0))
    var length = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_to_string", Int32](
            _addr(map),
            UInt32(len(map)),
            channels,
            buf.unsafe_ptr(),
            UInt32(capacity),
            length.unsafe_ptr(),
        )
    )
    return MaMapText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()), length[0])


def channel_map_length(lib: MaLib, map: List[UInt8], channels: UInt32) -> MaU32:
    """Asks for the length only (a NULL output buffer)."""
    var length = [UInt32(0)]
    var code = Int(
        lib.handle.call["ma_shim_channel_map_to_string", Int32](
            _addr(map), UInt32(len(map)), channels, Int(0), UInt32(0), length.unsafe_ptr()
        )
    )
    return MaU32(code, length[0])


def channel_position_to_string(lib: MaLib, position: UInt32) -> MaText:
    var buf = List[UInt8](capacity=64)
    buf.resize(64, UInt8(0))
    var code = Int(
        lib.handle.call["ma_shim_channel_position_to_string", Int32](
            position, buf.unsafe_ptr(), UInt32(64)
        )
    )
    return MaText(code, String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))
