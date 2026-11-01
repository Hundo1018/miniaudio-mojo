"""Spatialization enums shared by sounds and sound groups (Layer 3).

These live in their own module so `sound` and `sound_group` can depend on each
other's types without an import cycle (a `Sound` is built from a `SoundConfig`
that can route it into a `SoundGroup`, and a `SoundGroup` shares these enums).
`miniaudio.sound` re-exports every name here, so existing imports keep working.
"""

from std.builtin.variadics import TypeList


@fieldwise_init
struct AttenuationModel(EnumLike, Equatable, ImplicitlyCopyable, Movable, Writable):
    """Spatial distance attenuation model. Codes match ma_attenuation_model."""

    var code: UInt32

    comptime NONE = Self(0)
    comptime INVERSE = Self(1)
    comptime LINEAR = Self(2)
    comptime EXPONENTIAL = Self(3)

    # EnumLike: the case index is the code, so `match` takes `case .NONE:` and
    # print shows `AttenuationModel.EXPONENTIAL`. Not exhaustive: `code` can hold any
    # value C hands back, so a `match` needs a `case _`.
    comptime _enum_case_names = ParameterList.of[
        "NONE".value,
        "INVERSE".value,
        "LINEAR".value,
        "EXPONENTIAL".value,
    ].values
    comptime _enum_case_types = TypeList.splat[
        ParameterList[Self._enum_case_names].size, NoneType
    ].values
    comptime _enum_is_exhaustive = False

    def _get_enum_discriminant(self) -> Int:
        return Int(self.code)

    def _unsafe_get_enum_payload[
        id: Int
    ](ref self) -> ref[self] TypeList[Trait=AnyType, Self._enum_case_types]()[id]:
        comptime assert False, "AttenuationModel cases have no payload"

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code


comptime ATTENUATION_NONE = AttenuationModel.NONE
comptime ATTENUATION_INVERSE = AttenuationModel.INVERSE
comptime ATTENUATION_LINEAR = AttenuationModel.LINEAR
comptime ATTENUATION_EXPONENTIAL = AttenuationModel.EXPONENTIAL


@fieldwise_init
struct Positioning(EnumLike, Equatable, ImplicitlyCopyable, Movable, Writable):
    """Spatial positioning mode. Codes match ma_positioning."""

    var code: UInt32

    comptime ABSOLUTE = Self(0)
    comptime RELATIVE = Self(1)

    # EnumLike: the case index is the code, so `match` takes `case .ABSOLUTE:` and
    # print shows `Positioning.RELATIVE`. Not exhaustive: `code` can hold any
    # value C hands back, so a `match` needs a `case _`.
    comptime _enum_case_names = ParameterList.of[
        "ABSOLUTE".value,
        "RELATIVE".value,
    ].values
    comptime _enum_case_types = TypeList.splat[
        ParameterList[Self._enum_case_names].size, NoneType
    ].values
    comptime _enum_is_exhaustive = False

    def _get_enum_discriminant(self) -> Int:
        return Int(self.code)

    def _unsafe_get_enum_payload[
        id: Int
    ](ref self) -> ref[self] TypeList[Trait=AnyType, Self._enum_case_types]()[id]:
        comptime assert False, "Positioning cases have no payload"

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code


comptime POSITIONING_ABSOLUTE = Positioning.ABSOLUTE
comptime POSITIONING_RELATIVE = Positioning.RELATIVE


@fieldwise_init
struct PanMode(EnumLike, Equatable, ImplicitlyCopyable, Movable, Writable):
    """Stereo pan mode. Codes match ma_pan_mode."""

    var code: UInt32

    comptime BALANCE = Self(0)
    comptime PAN = Self(1)

    # EnumLike: the case index is the code, so `match` takes `case .BALANCE:` and
    # print shows `PanMode.PAN`. Not exhaustive: `code` can hold any
    # value C hands back, so a `match` needs a `case _`.
    comptime _enum_case_names = ParameterList.of[
        "BALANCE".value,
        "PAN".value,
    ].values
    comptime _enum_case_types = TypeList.splat[
        ParameterList[Self._enum_case_names].size, NoneType
    ].values
    comptime _enum_is_exhaustive = False

    def _get_enum_discriminant(self) -> Int:
        return Int(self.code)

    def _unsafe_get_enum_payload[
        id: Int
    ](ref self) -> ref[self] TypeList[Trait=AnyType, Self._enum_case_types]()[id]:
        comptime assert False, "PanMode cases have no payload"

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code


comptime PAN_MODE_BALANCE = PanMode.BALANCE
comptime PAN_MODE_PAN = PanMode.PAN


# ---- ma_sound_flags: OR them together for `flags=` ----
comptime SOUND_FLAG_STREAM = UInt32(0x00000001)
comptime SOUND_FLAG_DECODE = UInt32(0x00000002)
comptime SOUND_FLAG_ASYNC = UInt32(0x00000004)
comptime SOUND_FLAG_WAIT_INIT = UInt32(0x00000008)
comptime SOUND_FLAG_UNKNOWN_LENGTH = UInt32(0x00000010)
comptime SOUND_FLAG_LOOPING = UInt32(0x00000020)
comptime SOUND_FLAG_NO_DEFAULT_ATTACHMENT = UInt32(0x00001000)
comptime SOUND_FLAG_NO_PITCH = UInt32(0x00002000)
comptime SOUND_FLAG_NO_SPATIALIZATION = UInt32(0x00004000)

# ---- sentinels used by ma_sound_config ----
# `channels_out` value meaning "use the data source's channel count".
comptime SOUND_SOURCE_CHANNEL_COUNT = UInt32(0xFFFFFFFF)
# `end` of a range / loop point meaning "to the end of the source".
comptime FRAME_RANGE_END = UInt64(0xFFFFFFFFFFFFFFFF)
