"""Tests for the EnumLike value types (Mojo 1.2.0 enum-style matching).

Seven `code`-carrying structs mirror miniaudio C enums. The codes themselves are
checked against miniaudio.h by `pixi run check-enum-values` (a C _Static_assert
per case); this file pins the same numbers from the Mojo side and covers what
EnumLike adds: `match` on `.CASE`, case-name printing, and that the old module
constants are the same values as the struct cases.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite

from miniaudio import (
    SampleFormat,
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_U8,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S24,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
    EncodingFormat,
    ENCODING_FORMAT_UNKNOWN,
    ENCODING_FORMAT_WAV,
    ResampleAlgorithm,
    RESAMPLE_ALGORITHM_LINEAR,
    RESAMPLE_ALGORITHM_CUSTOM,
    ChannelMixMode,
    CHANNEL_MIX_MODE_RECTANGULAR,
    CHANNEL_MIX_MODE_SIMPLE,
    CHANNEL_MIX_MODE_CUSTOM_WEIGHTS,
)
from miniaudio.sound import (
    AttenuationModel,
    ATTENUATION_NONE,
    ATTENUATION_INVERSE,
    ATTENUATION_LINEAR,
    ATTENUATION_EXPONENTIAL,
    Positioning,
    POSITIONING_ABSOLUTE,
    POSITIONING_RELATIVE,
    PanMode,
    PAN_MODE_BALANCE,
    PAN_MODE_PAN,
)
from miniaudio.pcm_convert import bytes_per_sample, clip_source_bytes_per_sample


def test_codes_match_c_enums() raises:
    # Same numbers check-enum-values asserts against miniaudio.h.
    assert_equal(SampleFormat.UNKNOWN.code, 0)
    assert_equal(SampleFormat.U8.code, 1)
    assert_equal(SampleFormat.S16.code, 2)
    assert_equal(SampleFormat.S24.code, 3)
    assert_equal(SampleFormat.S32.code, 4)
    assert_equal(SampleFormat.F32.code, 5)
    assert_equal(EncodingFormat.UNKNOWN.code, 0)
    assert_equal(EncodingFormat.WAV.code, 1)
    assert_equal(EncodingFormat.FLAC.code, 2)
    assert_equal(EncodingFormat.MP3.code, 3)
    assert_equal(EncodingFormat.VORBIS.code, 4)
    assert_equal(ResampleAlgorithm.LINEAR.code, 0)
    assert_equal(ResampleAlgorithm.CUSTOM.code, 1)
    assert_equal(ChannelMixMode.RECTANGULAR.code, 0)
    assert_equal(ChannelMixMode.SIMPLE.code, 1)
    assert_equal(ChannelMixMode.CUSTOM_WEIGHTS.code, 2)
    assert_equal(AttenuationModel.NONE.code, 0)
    assert_equal(AttenuationModel.INVERSE.code, 1)
    assert_equal(AttenuationModel.LINEAR.code, 2)
    assert_equal(AttenuationModel.EXPONENTIAL.code, 3)
    assert_equal(Positioning.ABSOLUTE.code, 0)
    assert_equal(Positioning.RELATIVE.code, 1)
    assert_equal(PanMode.BALANCE.code, 0)
    assert_equal(PanMode.PAN.code, 1)


def test_module_constants_are_the_cases() raises:
    assert_true(SAMPLE_FORMAT_UNKNOWN == SampleFormat.UNKNOWN)
    assert_true(SAMPLE_FORMAT_U8 == SampleFormat.U8)
    assert_true(SAMPLE_FORMAT_S16 == SampleFormat.S16)
    assert_true(SAMPLE_FORMAT_S24 == SampleFormat.S24)
    assert_true(SAMPLE_FORMAT_S32 == SampleFormat.S32)
    assert_true(SAMPLE_FORMAT_F32 == SampleFormat.F32)
    assert_true(ENCODING_FORMAT_UNKNOWN == EncodingFormat.UNKNOWN)
    assert_true(ENCODING_FORMAT_WAV == EncodingFormat.WAV)
    assert_true(RESAMPLE_ALGORITHM_LINEAR == ResampleAlgorithm.LINEAR)
    assert_true(RESAMPLE_ALGORITHM_CUSTOM == ResampleAlgorithm.CUSTOM)
    assert_true(CHANNEL_MIX_MODE_RECTANGULAR == ChannelMixMode.RECTANGULAR)
    assert_true(CHANNEL_MIX_MODE_SIMPLE == ChannelMixMode.SIMPLE)
    assert_true(CHANNEL_MIX_MODE_CUSTOM_WEIGHTS == ChannelMixMode.CUSTOM_WEIGHTS)
    assert_true(ATTENUATION_NONE == AttenuationModel.NONE)
    assert_true(ATTENUATION_INVERSE == AttenuationModel.INVERSE)
    assert_true(ATTENUATION_LINEAR == AttenuationModel.LINEAR)
    assert_true(ATTENUATION_EXPONENTIAL == AttenuationModel.EXPONENTIAL)
    assert_true(POSITIONING_ABSOLUTE == Positioning.ABSOLUTE)
    assert_true(POSITIONING_RELATIVE == Positioning.RELATIVE)
    assert_true(PAN_MODE_BALANCE == PanMode.BALANCE)
    assert_true(PAN_MODE_PAN == PanMode.PAN)


def test_equality_and_inequality() raises:
    assert_true(AttenuationModel(2) == AttenuationModel.LINEAR)
    assert_true(AttenuationModel.LINEAR != AttenuationModel.INVERSE)
    assert_false(PanMode.PAN != PanMode(1))


def _distance(model: AttenuationModel) -> String:
    match model:
        case .NONE:
            return "none"
        case .INVERSE | .LINEAR | .EXPONENTIAL:
            return "falloff"
        case _:
            return "other"


def test_match_dispatches_on_case() raises:
    assert_equal(_distance(ATTENUATION_NONE), "none")
    assert_equal(_distance(ATTENUATION_INVERSE), "falloff")
    assert_equal(_distance(AttenuationModel(3)), "falloff")
    # A code outside the declared cases (C could hand one back) takes `case _`.
    assert_equal(_distance(AttenuationModel(42)), "other")


def test_match_drives_bytes_per_sample() raises:
    assert_equal(bytes_per_sample(SAMPLE_FORMAT_U8), 1)
    assert_equal(bytes_per_sample(SAMPLE_FORMAT_S16), 2)
    assert_equal(bytes_per_sample(SAMPLE_FORMAT_S24), 3)
    assert_equal(bytes_per_sample(SAMPLE_FORMAT_S32), 4)
    assert_equal(bytes_per_sample(SAMPLE_FORMAT_F32), 4)
    assert_equal(clip_source_bytes_per_sample(SAMPLE_FORMAT_U8), 2)
    assert_equal(clip_source_bytes_per_sample(SAMPLE_FORMAT_S16), 4)
    assert_equal(clip_source_bytes_per_sample(SAMPLE_FORMAT_S24), 8)
    assert_equal(clip_source_bytes_per_sample(SAMPLE_FORMAT_S32), 8)
    assert_equal(clip_source_bytes_per_sample(SAMPLE_FORMAT_F32), 4)
    for unknown in [SAMPLE_FORMAT_UNKNOWN, SampleFormat(9)]:
        var raised = False
        try:
            _ = bytes_per_sample(unknown)
        except:
            raised = True
        assert_true(raised, "bytes_per_sample must reject " + String(unknown.code))
        raised = False
        try:
            _ = clip_source_bytes_per_sample(unknown)
        except:
            raised = True
        assert_true(raised, "clip_source_bytes_per_sample must reject " + String(unknown.code))


def test_prints_case_name() raises:
    assert_equal(String(SampleFormat.F32), "SampleFormat.F32")
    assert_equal(String(EncodingFormat.WAV), "EncodingFormat.WAV")
    assert_equal(String(ResampleAlgorithm.LINEAR), "ResampleAlgorithm.LINEAR")
    assert_equal(String(ChannelMixMode.CUSTOM_WEIGHTS), "ChannelMixMode.CUSTOM_WEIGHTS")
    assert_equal(String(ATTENUATION_INVERSE), "AttenuationModel.INVERSE")
    assert_equal(String(Positioning.RELATIVE), "Positioning.RELATIVE")
    assert_equal(String(PAN_MODE_PAN), "PanMode.PAN")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
