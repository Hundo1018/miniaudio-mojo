"""Idiomatic format utilities (Layer 3).

miniaudio's stateless helpers, wrapped as free functions because none of them
owns anything: volume scaling and clipping applied to caller-owned buffers,
buffer-size arithmetic, and the format / backend name tables.

The clipping helpers take a *wider* source than destination — that is what they
are for. s32 clips down into s16, s64 into s32 and into packed 3-byte s24, s16
into u8, and f32 clips in place to [-1, 1].
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.format_util_raw as raw


comptime PERFORMANCE_PROFILE_LOW_LATENCY = Int(0)
comptime PERFORMANCE_PROFILE_CONSERVATIVE = Int(1)


def apply_volume(lib: ArcPointer[MaLib], mut samples: List[Float32], factor: Float32) raises:
    """Scale f32 samples in place."""
    var code = raw.apply_volume_factor_f32(lib[], samples, factor)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_f32 failed", code))


def apply_volume_u8(lib: ArcPointer[MaLib], mut samples: List[UInt8], factor: Float32) raises:
    """Scale u8 samples in place."""
    var code = raw.apply_volume_factor_u8(lib[], samples, factor)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_u8 failed", code))


def apply_volume_s16(lib: ArcPointer[MaLib], mut samples: List[Int16], factor: Float32) raises:
    """Scale s16 samples in place."""
    var code = raw.apply_volume_factor_s16(lib[], samples, factor)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_s16 failed", code))


def apply_volume_s24(
    lib: ArcPointer[MaLib], mut samples: List[UInt8], sample_count: UInt64, factor: Float32
) raises:
    """Scale packed 3-byte s24 samples in place; the count is in samples."""
    var code = raw.apply_volume_factor_s24(lib[], samples, sample_count, factor)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_s24 failed", code))


def apply_volume_s32(lib: ArcPointer[MaLib], mut samples: List[Int32], factor: Float32) raises:
    """Scale s32 samples in place."""
    var code = raw.apply_volume_factor_s32(lib[], samples, factor)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_s32 failed", code))


def apply_volume_frames(
    lib: ArcPointer[MaLib],
    mut frames: List[Float32],
    *,
    channels: UInt32 = 1,
    factor: Float32,
    format: SampleFormat = SAMPLE_FORMAT_F32,
) raises:
    """Scale f32 frames in place, through the format-dispatching entry point."""
    var frame_count = UInt64(len(frames)) // UInt64(channels)
    var code = raw.apply_volume_factor_pcm_frames(
        lib[], frames, frame_count, format.code, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames failed", code))


def apply_volume_frames_f32(
    lib: ArcPointer[MaLib], mut frames: List[Float32], *, channels: UInt32 = 1,
    factor: Float32,
) raises:
    """The typed f32 frame entry point."""
    var frame_count = UInt64(len(frames)) // UInt64(channels)
    var code = raw.apply_volume_factor_pcm_frames_f32(
        lib[], frames, frame_count, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames_f32 failed", code))


def apply_volume_frames_u8(
    lib: ArcPointer[MaLib], mut frames: List[UInt8], *, channels: UInt32 = 1,
    factor: Float32,
) raises:
    var frame_count = UInt64(len(frames)) // UInt64(channels)
    var code = raw.apply_volume_factor_pcm_frames_u8(
        lib[], frames, frame_count, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames_u8 failed", code))


def apply_volume_frames_s16(
    lib: ArcPointer[MaLib], mut frames: List[Int16], *, channels: UInt32 = 1,
    factor: Float32,
) raises:
    var frame_count = UInt64(len(frames)) // UInt64(channels)
    var code = raw.apply_volume_factor_pcm_frames_s16(
        lib[], frames, frame_count, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames_s16 failed", code))


def apply_volume_frames_s24(
    lib: ArcPointer[MaLib], mut frames: List[UInt8], frame_count: UInt64,
    *, channels: UInt32 = 1, factor: Float32,
) raises:
    """Packed 3-byte s24 frames, so the frame count is passed explicitly."""
    var code = raw.apply_volume_factor_pcm_frames_s24(
        lib[], frames, frame_count, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames_s24 failed", code))


def apply_volume_frames_s32(
    lib: ArcPointer[MaLib], mut frames: List[Int32], *, channels: UInt32 = 1,
    factor: Float32,
) raises:
    var frame_count = UInt64(len(frames)) // UInt64(channels)
    var code = raw.apply_volume_factor_pcm_frames_s32(
        lib[], frames, frame_count, channels, factor
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("apply_volume_factor_pcm_frames_s32 failed", code))


def clip(lib: ArcPointer[MaLib], src: List[Float32]) raises -> List[Float32]:
    """Clip f32 samples to [-1, 1]."""
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var code = raw.clip_samples_f32(lib[], dst, src, UInt64(len(src)))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_samples_f32 failed", code))
    return dst^


def clip_frames(
    lib: ArcPointer[MaLib],
    src: List[Float32],
    *,
    channels: UInt32 = 1,
    format: SampleFormat = SAMPLE_FORMAT_F32,
) raises -> List[Float32]:
    """Clip f32 frames through the format-dispatching entry point."""
    var dst = List[Float32](capacity=len(src))
    dst.resize(len(src), Float32(0))
    var frame_count = UInt64(len(src)) // UInt64(channels)
    var code = raw.clip_pcm_frames(lib[], dst, src, frame_count, format.code, channels)
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_pcm_frames failed", code))
    return dst^


def clip_to_u8(lib: ArcPointer[MaLib], src: List[Int16]) raises -> List[UInt8]:
    """s16 clipped down into u8."""
    var dst = List[UInt8](capacity=len(src))
    dst.resize(len(src), UInt8(0))
    var code = raw.clip_samples_u8(lib[], dst, src, UInt64(len(src)))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_samples_u8 failed", code))
    return dst^


def clip_to_s16(lib: ArcPointer[MaLib], src: List[Int32]) raises -> List[Int16]:
    """s32 clipped down into s16."""
    var dst = List[Int16](capacity=len(src))
    dst.resize(len(src), Int16(0))
    var code = raw.clip_samples_s16(lib[], dst, src, UInt64(len(src)))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_samples_s16 failed", code))
    return dst^


def clip_to_s24(lib: ArcPointer[MaLib], src: List[Int64]) raises -> List[UInt8]:
    """s64 clipped down into packed 3-byte s24."""
    var dst = List[UInt8](capacity=len(src) * 3)
    dst.resize(len(src) * 3, UInt8(0))
    var code = raw.clip_samples_s24(lib[], dst, src, UInt64(len(src)))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_samples_s24 failed", code))
    return dst^


def clip_to_s32(lib: ArcPointer[MaLib], src: List[Int64]) raises -> List[Int32]:
    """s64 clipped down into s32."""
    var dst = List[Int32](capacity=len(src))
    dst.resize(len(src), Int32(0))
    var code = raw.clip_samples_s32(lib[], dst, src, UInt64(len(src)))
    if code != MA_SUCCESS:
        raise Error(lib[].describe("clip_samples_s32 failed", code))
    return dst^


def frames_from_milliseconds(
    lib: ArcPointer[MaLib], milliseconds: UInt32, sample_rate: UInt32
) raises -> UInt32:
    var rc = raw.calculate_buffer_size_in_frames_from_milliseconds(
        lib[], milliseconds, sample_rate
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("frames from milliseconds failed", rc.result))
    return rc.value


def milliseconds_from_frames(
    lib: ArcPointer[MaLib], frames: UInt32, sample_rate: UInt32
) raises -> UInt32:
    var rc = raw.calculate_buffer_size_in_milliseconds_from_frames(
        lib[], frames, sample_rate
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("milliseconds from frames failed", rc.result))
    return rc.value


def frames_after_resampling(
    lib: ArcPointer[MaLib],
    *,
    sample_rate_out: UInt32,
    sample_rate_in: UInt32,
    frame_count_in: UInt64,
) raises -> UInt64:
    """How many frames a rate change turns frame_count_in into."""
    var rc = raw.calculate_frame_count_after_resampling(
        lib[], sample_rate_out, sample_rate_in, frame_count_in
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("frames after resampling failed", rc.result))
    return rc.value


def frames_from_descriptor(
    lib: ArcPointer[MaLib],
    *,
    sample_rate: UInt32,
    native_sample_rate: UInt32,
    channels: UInt32 = 2,
    period_size_in_frames: UInt32 = 0,
    period_size_in_milliseconds: UInt32 = 0,
    format: SampleFormat = SAMPLE_FORMAT_F32,
    performance_profile: Int = PERFORMANCE_PROFILE_LOW_LATENCY,
) raises -> UInt32:
    """Period size miniaudio would pick for a device described this way."""
    var rc = raw.calculate_buffer_size_in_frames_from_descriptor(
        lib[],
        format.code,
        channels,
        sample_rate,
        period_size_in_frames,
        period_size_in_milliseconds,
        native_sample_rate,
        performance_profile,
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("frames from descriptor failed", rc.result))
    return rc.value


def bytes_per_sample(lib: ArcPointer[MaLib], format: SampleFormat) raises -> UInt32:
    var rc = raw.get_bytes_per_sample(lib[], format.code)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("bytes per sample failed", rc.result))
    return rc.value


def format_name(lib: ArcPointer[MaLib], format: SampleFormat) raises -> String:
    var rc = raw.get_format_name(lib[], format.code)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("format name failed", rc.result))
    return rc.value


def format_priority_index(lib: ArcPointer[MaLib], format: SampleFormat) raises -> UInt32:
    """Where this format sits in miniaudio's preference order."""
    var rc = raw.get_format_priority_index(lib[], format.code)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("format priority failed", rc.result))
    return rc.value


def backend_name(lib: ArcPointer[MaLib], backend: Int) raises -> String:
    var rc = raw.get_backend_name(lib[], backend)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("backend name failed", rc.result))
    return rc.value


def backend_from_name(lib: ArcPointer[MaLib], name: String) raises -> UInt32:
    """The backend code miniaudio maps that name to."""
    var rc = raw.get_backend_from_name(lib[], name)
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("backend from name failed", rc.result))
    return rc.value


def enabled_backends(lib: ArcPointer[MaLib]) raises -> List[Int32]:
    """The backends this build of miniaudio was compiled with."""
    var rc = raw.get_enabled_backends(lib[])
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("enabled backends failed", rc.result))
    return rc.value.copy()
