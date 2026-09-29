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
from miniaudio.data_source import (
    DataSource,
    DataSourceNode,
    DataFormat,
    FrameRange,
)
from miniaudio.audio_buffer import (
    AudioBuffer,
    AudioBufferRef,
)
from miniaudio.context import (
    Context,
    Vfs,
    DeviceCounts,
    DeviceSummary,
    OPEN_MODE_READ,
    OPEN_MODE_WRITE,
    SEEK_ORIGIN_START,
    SEEK_ORIGIN_CURRENT,
    SEEK_ORIGIN_END,
)
from miniaudio.sync import (
    Mutex,
    Event,
    Semaphore,
    Fence,
    AsyncPoll,
    AsyncEvent,
    JobQueue,
    Log,
    SlotAllocator,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_WARNING,
    LOG_LEVEL_INFO,
    LOG_LEVEL_DEBUG,
)
from miniaudio.resource_manager import (
    ResourceManager,
    ResourceDataBuffer,
    ResourceDataStream,
    ResourceDataSource,
    DataFormat,
    RESOURCE_FLAG_STREAM,
    RESOURCE_FLAG_DECODE,
    RESOURCE_FLAG_ASYNC,
    RESOURCE_FLAG_WAIT_INIT,
    RESOURCE_FLAG_LOOPING,
)
from miniaudio.node import (
    NodeGraph,
    OffsetNode,
    DelayNode,
    SplitterNode,
    NODE_STATE_STARTED,
    NODE_STATE_STOPPED,
)
from miniaudio.filter import (
    Biquad,
    Bpf2,
    Bpf,
    Notch2,
    Peak2,
    Loshelf2,
    Hishelf2,
    BpfNode,
    NotchNode,
    PeakNode,
    LoshelfNode,
    HishelfNode,
    Lpf1,
    Lpf2,
    Lpf,
    Hpf1,
    Hpf2,
    Hpf,
    BiquadNode,
    LpfNode,
    HpfNode,
)
from miniaudio.converter import (
    Resampler,
    LinearResampler,
    ChannelConverter,
    DataConverter,
    ConversionResult,
    ResampleAlgorithm,
    ChannelMixMode,
    RESAMPLE_ALGORITHM_LINEAR,
    RESAMPLE_ALGORITHM_CUSTOM,
    CHANNEL_MIX_MODE_RECTANGULAR,
    CHANNEL_MIX_MODE_SIMPLE,
    CHANNEL_MIX_MODE_CUSTOM_WEIGHTS,
)
from miniaudio.paged_audio_buffer import (
    PagedAudioBuffer,
    PageInfo,
)
from miniaudio.ring_buffer import (
    RingBuffer,
    PcmRingBuffer,
    PcmRingBufferFormat,
)
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
from miniaudio.spatializer import (
    Spatializer,
    SpatializerListener,
    RelativeTransform,
)
