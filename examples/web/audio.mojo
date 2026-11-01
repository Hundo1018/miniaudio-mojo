"""C-ABI entry points of the browser module (built by tools/wasm/build_wasm.py).

JavaScript holds one opaque scene handle and calls, per audio block:

    web_render(h, frames) -> pointer to `frames * 2` f32 samples in wasm memory

and between blocks `web_set_tone` / `web_load_clip`. Byte buffers for clips are
allocated in wasm memory with `web_alloc` / `web_free`. Every function that can
fail returns an ma_result code (0 = MA_SUCCESS) instead of raising.
"""

from std.memory import alloc

from miniaudio import MaError, MaResult
from miniaudio._ffi.stream_raw import stream_leak, stream_reclaim
from scene import Scene, render_scene

comptime Opaque = OpaquePointer[MutUntrackedOrigin]


struct _Handle(Movable, Deinitable):
    var scene: Scene
    var out: List[Float32]

    def __init__(out self, var scene: Scene):
        self.scene = scene^
        self.out = List[Float32]()


def _null() -> Opaque:
    return Opaque(unsafe_from_address=Int(0))


def _handle(h: Opaque) -> Pointer[_Handle, MutUntrackedOrigin]:
    return h.unsafe_bitcast[_Handle]()


def _bytes(data: Opaque, length: UInt64) -> List[UInt8]:
    var out = List[UInt8](capacity=Int(length))
    var p = data.unsafe_bitcast[UInt8]()
    for i in range(Int(length)):
        out.append(p[i])
    return out^


@export
def web_create(sample_rate: UInt32) abi("C") -> Opaque:
    """A new scene at `sample_rate`, or NULL on failure."""
    try:
        var cell = stream_leak(_Handle(Scene(sample_rate)))
        return Opaque(unsafe_from_address=Int(cell))
    except:
        return _null()


@export
def web_destroy(h: Opaque) abi("C"):
    if h != _null():
        stream_reclaim(_handle(h))


@export
def web_alloc(size: UInt64) abi("C") -> Opaque:
    """`size` bytes of wasm memory for JavaScript to fill (release with web_free)."""
    return alloc[UInt8](Int(size)).unsafe_bitcast[NoneType]().unsafe_origin_cast[MutUntrackedOrigin]()


@export
def web_free(p: Opaque) abi("C"):
    if p != _null():
        p.unsafe_bitcast[UInt8]().unsafe_free()


@export
def web_set_tone(h: Opaque, frequency_hz: Float32, gain: Float32) abi("C") -> Int32:
    try:
        _handle(h)[].scene.set_tone(frequency_hz, gain)
        return 0
    except e:
        return e.result.code


@export
def web_load_clip(h: Opaque, data: Opaque, length: UInt64) abi("C") -> Int32:
    """Decode the encoded file image at `data` and play it once."""
    try:
        _handle(h)[].scene.load_clip(_bytes(data, length))
        return 0
    except e:
        return e.result.code


@export
def web_render(h: Opaque, frames: UInt32) abi("C") -> Opaque:
    """Mix `frames` stereo frames; returns a pointer to them (valid until the next
    call on this handle), or NULL on failure."""
    try:
        var hp = _handle(h)
        hp[].scene.render(hp[].out, UInt64(frames))
        return hp[].out.unsafe_ptr().unsafe_bitcast[NoneType]().unsafe_origin_cast[MutUntrackedOrigin]()
    except:
        return _null()


@export
def web_render_scene(data: Opaque, length: UInt64, frames: UInt32, dst: Opaque) abi("C") -> Int32:
    """The parity scene (scene.render_scene) into `out` (`frames * 2` f32)."""
    try:
        var pcm = render_scene(_bytes(data, length), Int(frames))
        var p = dst.unsafe_bitcast[Float32]()
        for i in range(len(pcm)):
            p[i] = pcm[i]
        return 0
    except e:
        return e.result.code
