"""Idiomatic sound API (Layer 3).

`Sound` is an RAII wrapper around ma_sound — a single playable sound owned by an
`Engine`. It is created from a file against an engine, and supports start/stop,
volume/pan/pitch, looping, spatialization, seeking, and cursor/length queries.

A sound must not outlive its engine, so `Sound` holds an `ArcPointer[Engine]`
that keeps the engine alive; `__del__` uninits the sound (while the engine is
still valid) before releasing that reference. `at_end()` polls completion (the
constrained, shim-friendly stand-in for ma_sound_set_end_callback).
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS
from miniaudio.engine import Engine
import miniaudio._ffi.sound_raw as raw


struct Sound(Movable):
    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]  # keeps the owning engine alive
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._engine = engine^
        self._ptr = ptr

    @staticmethod
    def from_file(
        engine: ArcPointer[Engine], path: String, *, flags: UInt32 = 0
    ) raises -> Self:
        var lib = engine[]._lib.copy()
        var ptr = raw.sound_alloc(lib[])
        if ptr == null_handle():
            raise Error("sound_alloc failed (out of memory)")
        var code = raw.sound_init_from_file(lib[], ptr, engine[]._ptr, path, flags)
        if code != MA_SUCCESS:
            raw.sound_free(lib[], ptr)
            raise Error(lib[].describe("sound init from file failed", code))
        return Self(lib^, engine.copy(), ptr)

    def start(mut self) raises:
        var code = raw.sound_start(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound start failed", code))

    def stop(mut self) raises:
        var code = raw.sound_stop(self._lib[], self._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound stop failed", code))

    def set_volume(mut self, volume: Float32) raises:
        if raw.sound_set_volume(self._lib[], self._ptr, volume) != MA_SUCCESS:
            raise Error("sound set_volume on uninitialized sound")

    def volume(self) -> Float32:
        return raw.sound_get_volume(self._lib[], self._ptr)

    def set_pan(mut self, pan: Float32) raises:
        if raw.sound_set_pan(self._lib[], self._ptr, pan) != MA_SUCCESS:
            raise Error("sound set_pan on uninitialized sound")

    def pan(self) -> Float32:
        return raw.sound_get_pan(self._lib[], self._ptr)

    def set_pitch(mut self, pitch: Float32) raises:
        if raw.sound_set_pitch(self._lib[], self._ptr, pitch) != MA_SUCCESS:
            raise Error("sound set_pitch on uninitialized sound")

    def pitch(self) -> Float32:
        return raw.sound_get_pitch(self._lib[], self._ptr)

    def set_looping(mut self, looping: Bool) raises:
        if raw.sound_set_looping(self._lib[], self._ptr, looping) != MA_SUCCESS:
            raise Error("sound set_looping on uninitialized sound")

    def is_looping(self) -> Bool:
        return raw.sound_is_looping(self._lib[], self._ptr) != 0

    def is_playing(self) -> Bool:
        return raw.sound_is_playing(self._lib[], self._ptr) != 0

    def at_end(self) -> Bool:
        return raw.sound_at_end(self._lib[], self._ptr) != 0

    def set_spatialization_enabled(mut self, enabled: Bool) raises:
        if (
            raw.sound_set_spatialization_enabled(self._lib[], self._ptr, enabled)
            != MA_SUCCESS
        ):
            raise Error("sound set_spatialization_enabled on uninitialized sound")

    def is_spatialization_enabled(self) -> Bool:
        return raw.sound_is_spatialization_enabled(self._lib[], self._ptr) != 0

    def seek(mut self, frame_index: UInt64) raises:
        var code = raw.sound_seek_to_pcm_frame(self._lib[], self._ptr, frame_index)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("sound seek failed", code))

    def cursor(self) raises -> UInt64:
        var c = raw.sound_get_cursor_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("sound cursor query failed", c.result))
        return c.value

    def length_in_frames(self) raises -> UInt64:
        var c = raw.sound_get_length_in_pcm_frames(self._lib[], self._ptr)
        if c.result != MA_SUCCESS:
            raise Error(self._lib[].describe("sound length query failed", c.result))
        return c.value

    def __del__(deinit self):
        # Uninit the sound while the engine (held via _engine) is still valid.
        if self._ptr != null_handle():
            raw.sound_free(self._lib[], self._ptr)
