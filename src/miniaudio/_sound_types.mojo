"""Spatialization enums and the end-handler trait shared by sounds and sound groups (Layer 3).

These live in their own module so `sound` and `sound_group` can depend on each
other's types without an import cycle (a `Sound` is built from a `SoundConfig`
that can route it into a `SoundGroup`, and a `SoundGroup` shares these enums).
`miniaudio.sound` re-exports every name here, so existing imports keep working.
"""


@fieldwise_init
struct AttenuationModel(ImplicitlyCopyable, Movable, Equatable):
    """Spatial distance attenuation model. Codes match ma_attenuation_model."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime ATTENUATION_NONE = AttenuationModel(0)
comptime ATTENUATION_INVERSE = AttenuationModel(1)
comptime ATTENUATION_LINEAR = AttenuationModel(2)
comptime ATTENUATION_EXPONENTIAL = AttenuationModel(3)


@fieldwise_init
struct Positioning(ImplicitlyCopyable, Movable, Equatable):
    """Spatial positioning mode. Codes match ma_positioning."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime POSITIONING_ABSOLUTE = Positioning(0)
comptime POSITIONING_RELATIVE = Positioning(1)


@fieldwise_init
struct PanMode(ImplicitlyCopyable, Movable, Equatable):
    """Stereo pan mode. Codes match ma_pan_mode."""

    var code: UInt32

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return self.code != other.code


comptime PAN_MODE_BALANCE = PanMode(0)
comptime PAN_MODE_PAN = PanMode(1)


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


# ---- end handler (ma_sound_set_end_callback) ----


trait SoundEndHandler(Movable, Deinitable):
    """Your own code, run when a sound reaches its end (`Sound.set_end_callback`).

    The sound takes the handler (it lives on the heap) and calls `on_end` from the
    **audio thread**: the thread miniaudio mixes on, or whichever thread is pulling
    frames from the engine. So keep it short and non-blocking -- bump an atomic,
    push to a lock-free queue, set a flag -- and do not touch the sound it belongs
    to from inside it (restarting, uninitialising or re-attaching a handler there
    deadlocks or corrupts it). Have another thread act on what you signalled.

    `on_end` cannot raise: there is no one to catch it on the audio thread.
    The handler is destroyed exactly once, never while `on_end` runs: when it is
    replaced, cleared, or the sound is dropped.
    """

    def on_end(mut self):
        """The sound reached its end. Runs on the audio thread."""
        ...
