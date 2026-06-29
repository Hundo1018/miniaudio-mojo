"""Idiomatic playback device API (Layer 3).

`Device` is an RAII wrapper around a miniaudio playback device whose data
callback (owned by the C shim) pulls f32 PCM from a `Decoder`. Because the
audio thread reads the decoder for the device's lifetime, `Device` takes
ownership of the `Decoder` and keeps it alive; `__del__` uninits the device
(which stops and joins the audio thread) before the decoder is destroyed.

NOTE on the callback: the pinned Mojo nightly cannot pass a Mojo function value
across the FFI as a C function pointer (function values do not conform to
`AnyType` in `DLHandle.call`), so a user-supplied Mojo data callback is not
possible. The callback therefore lives in C and pulls from the decoder. Use
`use_null_backend=True` for deterministic, hardware-free runs (tests).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.decoder import Decoder
import miniaudio._ffi.device_raw as raw


struct Device(Movable):
    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _source: Decoder  # kept alive for the device's lifetime; the cb pulls from it

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        var source: Decoder,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._source = source^

    @staticmethod
    def play(
        lib: ArcPointer[MaLib],
        var source: Decoder,
        *,
        sample_rate: UInt32 = 0,
        use_null_backend: Bool = False,
    ) raises -> Self:
        """Opens a playback device that streams `source`. Call `start()` to play.

        `sample_rate` of 0 uses the decoder's native rate. `use_null_backend`
        runs on miniaudio's null backend (no hardware) for deterministic tests.
        """
        var ptr = raw.device_alloc(lib[])
        if ptr == null_handle():
            raise Error("device_alloc failed (out of memory)")
        var code = raw.device_init_playback_from_decoder(
            lib[], ptr, source._ptr, sample_rate, use_null_backend
        )
        if code != MA_SUCCESS:
            raw.device_free(lib[], ptr)
            raise Error(lib[].describe("device init for playback failed", code))
        return Self(lib.copy(), ptr, source^)

    def start(mut self) raises:
        var code = raw.device_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device start failed", code))

    def stop(mut self) raises:
        var code = raw.device_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("device stop failed", code))

    def channels(self) -> UInt32:
        return raw.device_get_channels(self._lib[], self._ptr)

    def sample_rate(self) -> UInt32:
        return raw.device_get_sample_rate(self._lib[], self._ptr)

    def frames_processed(self) -> UInt64:
        return raw.device_get_frames_processed(self._lib[], self._ptr)

    def __del__(deinit self):
        # Uninit the device first (stops + joins the audio thread) so the
        # callback is no longer reading the decoder when `_source` is destroyed.
        if self._ptr != null_handle():
            raw.device_free(self._lib[], self._ptr)
