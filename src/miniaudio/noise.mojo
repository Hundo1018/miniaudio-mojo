"""Idiomatic noise API (Layer 3).

`Noise` is an RAII wrapper around ma_noise — a PCM generator that produces
white, pink, or Brownian noise in-memory without any audio device or engine.
Useful for synthesis, testing, and procedural audio. `__del__` uninits the
noise generator automatically.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
import miniaudio._ffi.noise_raw as raw

comptime NoiseTypeWhite: Int = raw.NOISE_TYPE_WHITE
comptime NoiseTypePink: Int = raw.NOISE_TYPE_PINK
comptime NoiseTypeBrownian: Int = raw.NOISE_TYPE_BROWNIAN


struct Noise(Movable):
    """PCM noise generator (RAII). Owns its shim handle; uninits on drop."""

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
        noise_type: Int = raw.NOISE_TYPE_WHITE,
        seed: Int32 = Int32(0),
        amplitude: Float64 = 1.0,
    ) raises -> Self:
        """Create and initialise a noise generator.

        format: ma_format code (5 = f32). channels: output channel count.
        noise_type: one of NoiseTypeWhite / Pink / Brownian.
        seed: random seed (0 = default). amplitude: 0.0–1.0.
        """
        var ptr = raw.noise_alloc(lib[])
        if ptr == null_handle():
            raise Error("noise_alloc failed (out of memory)")
        var code = raw.noise_init(
            lib[], ptr, format, channels, noise_type, seed, amplitude
        )
        if code != MA_SUCCESS:
            raw.noise_free(lib[], ptr)
            raise Error(lib[].describe("noise init failed", code))
        return Self(lib.copy(), ptr, channels)

    def read_frames(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Generate `frame_count` PCM frames as f32 samples (channels interleaved)."""
        var n = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=n)
        buf.resize(n, Float32(0))
        var rc = raw.noise_read_pcm_frames(self._lib[], self._ptr, buf, frame_count)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("noise read_frames failed", rc.result))
        return buf^

    def set_amplitude(mut self, amplitude: Float64) raises:
        if raw.noise_set_amplitude(self._lib[], self._ptr, amplitude) != MA_SUCCESS:
            raise Error("noise set_amplitude on uninitialized noise")

    def set_seed(mut self, seed: Int32) raises:
        if raw.noise_set_seed(self._lib[], self._ptr, seed) != MA_SUCCESS:
            raise Error("noise set_seed on uninitialized noise")

    def __del__(deinit self):
        if self._ptr != null_handle():
            raw.noise_free(self._lib[], self._ptr)
