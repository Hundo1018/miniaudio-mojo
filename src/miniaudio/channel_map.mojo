"""Idiomatic channel-map API (Layer 3).

A `ChannelMap` is miniaudio's per-channel speaker layout: one position per
channel (front left, front right, LFE ...), as used by the converters, the
device descriptors and the spatializer. It owns a plain byte list and asks
miniaudio for everything else: the standard layouts (Microsoft / default,
ALSA, RFC 3551, FLAC, Vorbis, sound(4), sndio), validity, equality, lookup and
the printable form.

A *blank* map (every position CHANNEL_NONE) means "use the native layout"; it is
valid. Quirks of miniaudio 0.11.25 pinned by the tests:

- `is_valid` rejects a map with more than one channel that contains MONO, and a
  channel count of zero; it does not check that positions are distinct.
- `to_string` returns the length of the whole text even when the buffer was too
  small; whole names that do not fit are dropped rather than cut.
- Past 8 channels a standard map fills the extra ones with AUX_0, AUX_1 ... up to
  channel index 31 (AUX_23); channels from index 32 on are CHANNEL_NONE.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.channel_map_raw as raw

comptime StandardMapDefault: Int = raw.STANDARD_MAP_DEFAULT
comptime StandardMapMicrosoft: Int = raw.STANDARD_MAP_MICROSOFT
comptime StandardMapAlsa: Int = raw.STANDARD_MAP_ALSA
comptime StandardMapRfc3551: Int = raw.STANDARD_MAP_RFC3551
comptime StandardMapFlac: Int = raw.STANDARD_MAP_FLAC
comptime StandardMapVorbis: Int = raw.STANDARD_MAP_VORBIS
comptime StandardMapSound4: Int = raw.STANDARD_MAP_SOUND4
comptime StandardMapSndio: Int = raw.STANDARD_MAP_SNDIO

comptime ChannelNone: UInt8 = raw.CHANNEL_NONE
comptime ChannelMono: UInt8 = raw.CHANNEL_MONO
comptime ChannelFrontLeft: UInt8 = raw.CHANNEL_FRONT_LEFT
comptime ChannelFrontRight: UInt8 = raw.CHANNEL_FRONT_RIGHT
comptime ChannelFrontCenter: UInt8 = raw.CHANNEL_FRONT_CENTER
comptime ChannelLfe: UInt8 = raw.CHANNEL_LFE
comptime ChannelBackLeft: UInt8 = raw.CHANNEL_BACK_LEFT
comptime ChannelBackRight: UInt8 = raw.CHANNEL_BACK_RIGHT
comptime ChannelFrontLeftCenter: UInt8 = raw.CHANNEL_FRONT_LEFT_CENTER
comptime ChannelFrontRightCenter: UInt8 = raw.CHANNEL_FRONT_RIGHT_CENTER
comptime ChannelBackCenter: UInt8 = raw.CHANNEL_BACK_CENTER
comptime ChannelSideLeft: UInt8 = raw.CHANNEL_SIDE_LEFT
comptime ChannelSideRight: UInt8 = raw.CHANNEL_SIDE_RIGHT
comptime ChannelTopCenter: UInt8 = raw.CHANNEL_TOP_CENTER
comptime ChannelAux0: UInt8 = raw.CHANNEL_AUX_0


def channel_position_name(lib: ArcPointer[MaLib], position: UInt8) raises -> String:
    """miniaudio's name for a position, e.g. "CHANNEL_FRONT_LEFT"; "UNKNOWN" past the table."""
    var rc = raw.channel_position_to_string(lib[], UInt32(position))
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("channel_position_to_string failed", rc.result))
    return rc.value


struct ChannelMap(Movable):
    """A per-channel speaker layout (value type over a byte list)."""

    var _lib: ArcPointer[MaLib]
    var _positions: List[UInt8]

    def __init__(out self, var lib: ArcPointer[MaLib], var positions: List[UInt8]):
        self._lib = lib^
        self._positions = positions^

    @staticmethod
    def blank(lib: ArcPointer[MaLib], channels: UInt32) raises -> Self:
        """Every position CHANNEL_NONE: "use the native layout"."""
        var positions = List[UInt8]()
        positions.resize(Int(channels), UInt8(1))  # non-zero so init_blank visibly clears it
        var code = raw.channel_map_init_blank(lib[], positions, channels)
        if code != MA_SUCCESS:
            raise Error(lib[].describe("channel_map init_blank failed", code))
        return Self(lib.copy(), positions^)

    @staticmethod
    def standard(
        lib: ArcPointer[MaLib], channels: UInt32, standard: Int = StandardMapDefault
    ) raises -> Self:
        """One of miniaudio's standard layouts for that many channels."""
        var positions = List[UInt8]()
        positions.resize(Int(channels), UInt8(0))
        var code = raw.channel_map_init_standard(lib[], standard, positions, channels)
        if code != MA_SUCCESS:
            raise Error(lib[].describe("channel_map init_standard failed", code))
        return Self(lib.copy(), positions^)

    @staticmethod
    def from_positions(lib: ArcPointer[MaLib], positions: List[UInt8]) raises -> Self:
        """A map holding a copy of `positions` (copied through miniaudio)."""
        var out = List[UInt8]()
        out.resize(len(positions), UInt8(0))
        var code = raw.channel_map_copy(lib[], out, positions, UInt32(len(positions)))
        if code != MA_SUCCESS:
            raise Error(lib[].describe("channel_map copy failed", code))
        return Self(lib.copy(), out^)

    @staticmethod
    def copy_or_default(
        lib: ArcPointer[MaLib], channels: UInt32, source: List[UInt8] = List[UInt8]()
    ) raises -> Self:
        """A copy of `source`, or the default layout when `source` is empty."""
        var out = List[UInt8]()
        out.resize(Int(channels), UInt8(0))
        var code = raw.channel_map_copy_or_default(lib[], out, source, channels)
        if code != MA_SUCCESS:
            raise Error(lib[].describe("channel_map copy_or_default failed", code))
        return Self(lib.copy(), out^)

    def clone(self) raises -> Self:
        return Self.from_positions(self._lib, self._positions)

    def channels(self) -> UInt32:
        return UInt32(len(self._positions))

    def positions(self) -> List[UInt8]:
        return self._positions.copy()

    def channel(self, index: UInt32) raises -> UInt8:
        """The position at `index`; CHANNEL_NONE past the end."""
        var rc = raw.channel_map_get_channel(self._lib[], self._positions, self.channels(), index)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map get_channel failed", rc.result))
        return UInt8(rc.value)

    def is_valid(self) raises -> Bool:
        var rc = raw.channel_map_is_valid(self._lib[], self._positions, self.channels())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map is_valid failed", rc.result))
        return rc.value

    def is_blank(self) raises -> Bool:
        var rc = raw.channel_map_is_blank(self._lib[], self._positions, self.channels())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map is_blank failed", rc.result))
        return rc.value

    def is_equal(self, other: Self) raises -> Bool:
        """Position-by-position equality over this map's channel count."""
        var rc = raw.channel_map_is_equal(
            self._lib[], self._positions, other._positions, self.channels()
        )
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map is_equal failed", rc.result))
        return rc.value

    def contains(self, position: UInt8) raises -> Bool:
        var rc = raw.channel_map_contains_channel_position(
            self._lib[], self.channels(), self._positions, UInt32(position)
        )
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map contains failed", rc.result))
        return rc.value

    def find(self, position: UInt8) raises -> Optional[UInt32]:
        """The index of the first channel with that position, or None."""
        var rc = raw.channel_map_find_channel_position(
            self._lib[], self.channels(), self._positions, UInt32(position)
        )
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map find failed", rc.result))
        if rc.found:
            return Optional[UInt32](rc.index)
        return Optional[UInt32]()

    def to_string(self) raises -> String:
        """Space-separated position names, e.g. "CHANNEL_FRONT_LEFT CHANNEL_FRONT_RIGHT"."""
        var rc = raw.channel_map_to_string(self._lib[], self._positions, self.channels())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("channel_map to_string failed", rc.result))
        return rc.text
