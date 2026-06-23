"""miniaudio — idiomatic Mojo bindings for miniaudio.

Public surface (reference slice): the decoder. Other module groups follow the
same three-layer pattern (thin C shim -> raw binding layer -> RAII API). See
docs/binding-architecture.md.
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
