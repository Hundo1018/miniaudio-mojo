"""miniaudio — idiomatic Mojo bindings for miniaudio.

Public surface (migrated slices): the decoder and encoder. Other module groups
follow the same three-layer pattern (thin C shim -> raw binding layer -> RAII
API). See docs/binding-architecture.md.
"""

from miniaudio._lib import MaLib
from miniaudio.result import (
    result_name,
    is_success,
    MA_SUCCESS,
    MA_AT_END,
    MA_INVALID_ARGS,
    MA_DOES_NOT_EXIST,
)
from miniaudio.decoder import (
    Decoder,
    SampleFormat,
    SAMPLE_FORMAT_UNKNOWN,
    SAMPLE_FORMAT_U8,
    SAMPLE_FORMAT_S16,
    SAMPLE_FORMAT_S24,
    SAMPLE_FORMAT_S32,
    SAMPLE_FORMAT_F32,
)
from miniaudio.encoder import (
    Encoder,
    EncodingFormat,
    ENCODING_FORMAT_UNKNOWN,
    ENCODING_FORMAT_WAV,
)
from miniaudio.device import (
    Device,
    DeviceInfo,
    NativeDataFormat,
    DeviceJobThread,
    JobResult,
    DEVICE_TYPE_PLAYBACK,
    DEVICE_TYPE_CAPTURE,
    DEVICE_TYPE_DUPLEX,
    DEVICE_TYPE_LOOPBACK,
    DEVICE_STATE_UNINITIALIZED,
    DEVICE_STATE_STOPPED,
    DEVICE_STATE_STARTED,
    DEVICE_STATE_STARTING,
    DEVICE_STATE_STOPPING,
    JOB_TYPE_QUIT,
    JOB_TYPE_CUSTOM,
    JOB_QUEUE_FLAG_NON_BLOCKING,
)
from miniaudio.engine import Engine
from miniaudio.sound import Sound
from miniaudio.sound_group import SoundGroup
from miniaudio.waveform import (
    Waveform,
    WaveformTypeSine,
    WaveformTypeSquare,
    WaveformTypeTriangle,
    WaveformTypeSawtooth,
)
from miniaudio.noise import (
    Noise,
    NoiseTypeWhite,
    NoiseTypePink,
    NoiseTypeBrownian,
)
