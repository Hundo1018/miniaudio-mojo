"""Idiomatic waveform API (Layer 3).

`Waveform` is an RAII wrapper around ma_waveform — a PCM generator that
produces sine, square, triangle, or sawtooth audio frames in-memory without
any audio device or engine. Useful for synthesis, testing, and procedural audio.
`__deinit__` uninits the waveform automatically.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.waveform_raw as raw

comptime WaveformTypeSine: Int = raw.WAVEFORM_TYPE_SINE
comptime WaveformTypeSquare: Int = raw.WAVEFORM_TYPE_SQUARE
comptime WaveformTypeTriangle: Int = raw.WAVEFORM_TYPE_TRIANGLE
comptime WaveformTypeSawtooth: Int = raw.WAVEFORM_TYPE_SAWTOOTH


struct Waveform(Movable):
    """PCM waveform generator (RAII). Owns its shim handle; uninits on drop."""

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        format: Int = 5,
        channels: UInt32 = 1,
        sample_rate: UInt32 = 44100,
        waveform_type: Int = raw.WAVEFORM_TYPE_SINE,
        amplitude: Float64 = 1.0,
        frequency: Float64 = 440.0,
    ) raises -> Self:
        """Create and initialise a waveform generator.

        format: ma_format code (5 = f32). channels: output channel count.
        sample_rate: output sample rate in Hz. waveform_type: one of
        WaveformTypeSine / Square / Triangle / Sawtooth. amplitude: 0.0–1.0.
        frequency: pitch in Hz.
        """
        var ptr = raw.waveform_alloc(lib[])
        if ptr == null_handle():
            raise Error("waveform_alloc failed (out of memory)")
        var code = raw.waveform_init(
            lib[], ptr, format, channels, sample_rate, waveform_type, amplitude, frequency
        )
        if code != MA_SUCCESS:
            raw.waveform_free(lib[], ptr)
            raise Error(lib[].describe("waveform init failed", code))
        return Self(lib.copy(), ptr, channels)

    def read_frames(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Generate `frame_count` PCM frames as f32 samples (channels interleaved)."""
        var n = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=n)
        buf.resize(n, Float32(0))
        var rc = raw.waveform_read_pcm_frames(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("waveform read_frames failed", rc.result))
        return buf^

    def seek_to_frame(mut self, frame_index: UInt64) raises:
        var code = raw.waveform_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("waveform seek_to_frame failed", code))

    def set_amplitude(mut self, amplitude: Float64) raises:
        if raw.waveform_set_amplitude(self._lib[], self._ptr, amplitude) != MA_SUCCESS:
            raise Error("waveform set_amplitude on uninitialized waveform")

    def set_frequency(mut self, frequency: Float64) raises:
        if raw.waveform_set_frequency(self._lib[], self._ptr, frequency) != MA_SUCCESS:
            raise Error("waveform set_frequency on uninitialized waveform")

    def set_type(mut self, waveform_type: Int) raises:
        if raw.waveform_set_type(self._lib[], self._ptr, waveform_type) != MA_SUCCESS:
            raise Error("waveform set_type on uninitialized waveform")

    def set_sample_rate(mut self, sample_rate: UInt32) raises:
        if raw.waveform_set_sample_rate(self._lib[], self._ptr, sample_rate) != MA_SUCCESS:
            raise Error("waveform set_sample_rate on uninitialized waveform")

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.waveform_free(self._lib[], self._ptr)


struct PulseWave(Movable):
    """Square-wave generator with adjustable duty cycle (RAII over ma_pulsewave).

    The duty cycle is the fraction of each period spent at +amplitude (the rest
    is at -amplitude); 0.5 is a symmetric square wave.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def create(
        lib: ArcPointer[MaLib],
        *,
        channels: UInt32 = 1,
        sample_rate: UInt32 = 44100,
        duty_cycle: Float64 = 0.5,
        amplitude: Float64 = 1.0,
        frequency: Float64 = 440.0,
    ) raises -> Self:
        """Create an f32 pulse-wave generator."""
        var ptr = raw.pulsewave_alloc(lib[])
        if ptr == null_handle():
            raise Error("pulsewave_alloc failed (out of memory)")
        var code = raw.pulsewave_init(
            lib[], ptr, 5, channels, sample_rate, duty_cycle, amplitude, frequency
        )
        if code != MA_SUCCESS:
            raw.pulsewave_free(lib[], ptr)
            raise Error(lib[].describe("pulsewave init failed", code))
        return Self(lib.copy(), ptr, channels)

    def read_frames(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Generate `frame_count` frames as interleaved f32 samples."""
        var n = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=n)
        buf.resize(n, Float32(0))
        var rc = raw.pulsewave_read_pcm_frames(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave read_frames failed", rc.result))
        return buf^

    def seek_to_frame(mut self, frame_index: UInt64) raises:
        var code = raw.pulsewave_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave seek_to_frame failed", code))

    def set_amplitude(mut self, amplitude: Float64) raises:
        var code = raw.pulsewave_set_amplitude(self._lib[], self._ptr, amplitude)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave set_amplitude failed", code))

    def set_frequency(mut self, frequency: Float64) raises:
        var code = raw.pulsewave_set_frequency(self._lib[], self._ptr, frequency)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave set_frequency failed", code))

    def set_sample_rate(mut self, sample_rate: UInt32) raises:
        var code = raw.pulsewave_set_sample_rate(self._lib[], self._ptr, sample_rate)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave set_sample_rate failed", code))

    def set_duty_cycle(mut self, duty_cycle: Float64) raises:
        var code = raw.pulsewave_set_duty_cycle(self._lib[], self._ptr, duty_cycle)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("pulsewave set_duty_cycle failed", code))

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.pulsewave_free(self._lib[], self._ptr)
