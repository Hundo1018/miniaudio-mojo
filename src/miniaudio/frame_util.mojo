"""Idiomatic PCM frame utilities (Layer 3 free functions).

miniaudio's format-dispatching frame helpers: interleave / deinterleave, silence,
pointer offsetting and the debug sine fill. Nothing here owns anything, so this
module is free functions rather than RAII types, which is the shape of the API.

The format is chosen at run time, so these work on raw bytes (`List[UInt8]`);
`miniaudio.pcm_convert` has the helpers that move f32, s16 and s32 lists in and
out of bytes, and the typed interleave / deinterleave pairs. s24 is packed three
bytes per sample, little-endian.

Every function sizes its output from its input, so a call can never write past a
list: a list whose length is not a whole number of frames for the format and
channel count is rejected rather than silently truncated.

Upstream behaviour worth knowing, pinned by tests/test_frame_util_api.mojo:
- u8 is unsigned, so its silence is 128, not 0.
- the offset helpers do pure pointer arithmetic: they neither check the offset
  against the buffer nor read it, so `offset_frames` does the bounds check.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib
from miniaudio.decoder import SampleFormat, SAMPLE_FORMAT_F32, SAMPLE_FORMAT_S16
from miniaudio.pcm_convert import bytes_per_sample, bytes_to_f32, bytes_to_s16
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.frame_util_raw as raw


def _zeroed(count: Int) -> List[UInt8]:
    var out = List[UInt8](capacity=count)
    out.resize(count, UInt8(0))
    return out^


def _frames_in(
    length: Int, format: SampleFormat, channels: UInt32, what: String
) raises -> Int:
    """How many whole frames `length` bytes hold; raises on a remainder."""
    if channels == 0:
        raise Error(what + ": channels must be at least 1")
    var bytes_per_frame = Int(channels) * bytes_per_sample(format)
    if length % bytes_per_frame != 0:
        raise Error(
            what + ": length " + String(length) + " is not a whole number of "
            + String(bytes_per_frame) + "-byte frames"
        )
    return length // bytes_per_frame


def deinterleave(
    lib: ArcPointer[MaLib],
    interleaved: List[UInt8],
    *,
    format: SampleFormat,
    channels: UInt32,
) raises -> List[UInt8]:
    """Split into one plane per channel, laid out end to end."""
    var frame_count = _frames_in(len(interleaved), format, channels, "deinterleave")
    var planes = _zeroed(len(interleaved))
    var stride = UInt64(frame_count * bytes_per_sample(format))
    var code = raw.deinterleave_pcm_frames(
        lib[], format.code, channels, UInt64(frame_count), interleaved, planes, stride
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("deinterleave_pcm_frames failed", code))
    return planes^


def interleave(
    lib: ArcPointer[MaLib],
    planes: List[UInt8],
    *,
    format: SampleFormat,
    channels: UInt32,
) raises -> List[UInt8]:
    """The inverse of `deinterleave`: weave the planes into one interleaved buffer."""
    var frame_count = _frames_in(len(planes), format, channels, "interleave")
    var interleaved = _zeroed(len(planes))
    var stride = UInt64(frame_count * bytes_per_sample(format))
    var code = raw.interleave_pcm_frames(
        lib[], format.code, channels, UInt64(frame_count), planes, stride, interleaved
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("interleave_pcm_frames failed", code))
    return interleaved^


def silence(
    lib: ArcPointer[MaLib],
    mut frames: List[UInt8],
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises:
    """Silence every frame in the buffer. u8 silence is 128; the others are zero."""
    var frame_count = _frames_in(len(frames), format, channels, "silence")
    var code = raw.silence_pcm_frames(
        lib[], frames, UInt64(frame_count), format.code, channels
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("silence_pcm_frames failed", code))


def silent_frames(
    lib: ArcPointer[MaLib],
    frame_count: Int,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> List[UInt8]:
    """A new buffer of `frame_count` silent frames."""
    if channels == 0:
        raise Error("silent_frames: channels must be at least 1")
    var frames = _zeroed(frame_count * Int(channels) * bytes_per_sample(format))
    silence(lib, frames, format=format, channels=channels)
    return frames^


def offset_frames(
    lib: ArcPointer[MaLib],
    mut frames: List[UInt8],
    offset_in_frames: Int,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> Int:
    """The byte index `offset_in_frames` frames into the buffer.

    miniaudio hands back a pointer; this is that pointer minus the buffer's
    start, after checking it lands inside the buffer (one past the end is fine).
    """
    var frame_count = _frames_in(len(frames), format, channels, "offset_frames")
    if offset_in_frames < 0 or offset_in_frames > frame_count:
        raise Error(
            "offset_frames: offset " + String(offset_in_frames) + " is outside "
            + String(frame_count) + " frames"
        )
    var base = Int(frames.unsafe_ptr())
    var rc = raw.offset_pcm_frames_ptr(
        lib[], frames, UInt64(offset_in_frames), format.code, channels
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("offset_pcm_frames_ptr failed", rc.result))
    return rc.address - base


def offset_frames_const(
    lib: ArcPointer[MaLib],
    frames: List[UInt8],
    offset_in_frames: Int,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
) raises -> Int:
    """`offset_frames` for a buffer that is only read."""
    var frame_count = _frames_in(len(frames), format, channels, "offset_frames_const")
    if offset_in_frames < 0 or offset_in_frames > frame_count:
        raise Error(
            "offset_frames_const: offset " + String(offset_in_frames)
            + " is outside " + String(frame_count) + " frames"
        )
    var base = Int(frames.unsafe_ptr())
    var rc = raw.offset_pcm_frames_const_ptr(
        lib[], frames, UInt64(offset_in_frames), format.code, channels
    )
    if rc.result != MA_SUCCESS:
        raise Error(lib[].describe("offset_pcm_frames_const_ptr failed", rc.result))
    return rc.address - base


def sine_wave(
    lib: ArcPointer[MaLib],
    frame_count: UInt32,
    *,
    format: SampleFormat,
    channels: UInt32 = 1,
    sample_rate: UInt32 = 48000,
) raises -> List[UInt8]:
    """`frame_count` frames of a full-scale 400 Hz sine, in `format`, as raw bytes.

    Every channel carries the same signal. The first frame is silence.
    """
    if channels == 0:
        raise Error("sine_wave: channels must be at least 1")
    var frames = _zeroed(Int(frame_count) * Int(channels) * bytes_per_sample(format))
    var code = raw.debug_fill_pcm_frames_with_sine_wave(
        lib[], frames, frame_count, format.code, channels, sample_rate
    )
    if code != MA_SUCCESS:
        raise Error(lib[].describe("debug_fill_pcm_frames_with_sine_wave failed", code))
    return frames^


def sine_wave_f32(
    lib: ArcPointer[MaLib],
    frame_count: UInt32,
    *,
    channels: UInt32 = 1,
    sample_rate: UInt32 = 48000,
) raises -> List[Float32]:
    """`sine_wave` as f32 samples in [-1, 1]."""
    return bytes_to_f32(
        sine_wave(
            lib, frame_count, format=SAMPLE_FORMAT_F32, channels=channels,
            sample_rate=sample_rate,
        )
    )


def sine_wave_s16(
    lib: ArcPointer[MaLib],
    frame_count: UInt32,
    *,
    channels: UInt32 = 1,
    sample_rate: UInt32 = 48000,
) raises -> List[Int16]:
    """`sine_wave` as s16 samples."""
    return bytes_to_s16(
        sine_wave(
            lib, frame_count, format=SAMPLE_FORMAT_S16, channels=channels,
            sample_rate=sample_rate,
        )
    )
