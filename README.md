# miniaudio-mojo

Mojo bindings for [miniaudio](https://miniaud.io) (vendored 0.11.25): playback, capture,
the engine / sound / node graph, decoding and encoding (WAV, FLAC, MP3), filters and effects,
resampling and format conversion, the resource manager, and the low-level utilities.

**Coverage:** 990 of miniaudio's 1,027 core `MA_API` functions are bound and tested. That is
every bindable one; the 37 exclusions are listed with their reasons in
`docs/coverage-exclusions.json` (see `docs/binding-coverage.md`). The project is pre-1.0, and the
API can still change.

## Requirements

- Linux x86-64, a C compiler (`cc`), and [pixi](https://pixi.sh).
- Mojo `>=1.2.0,<2`, installed by pixi from `conda.modular.com/max`.

## Quick start

```bash
pixi run play                      # builds the shim, plays a generated 440 Hz test tone
pixi run play -- path/to/file.mp3  # any WAV, FLAC or MP3
MINIAUDIO_NULL_BACKEND=1 pixi run play   # no audio device needed
```

`examples/play_file.mojo` is the whole program:

```mojo
from std.memory import ArcPointer
from miniaudio import MaLib, MaResult, MaError
from miniaudio.engine import Engine
from miniaudio.sound import Sound

def play(path: String) raises MaError:
    var lib = ArcPointer(MaLib.default())          # loads build/libma_shim.so
    var engine = ArcPointer(Engine.create(lib))
    var sound = Sound.from_file(engine, path)
    sound.start()
    ...
```

`MaLib.default()` loads `build/libma_shim.so` (built by `pixi run build-shim`); set
`MINIAUDIO_MOJO_LIB` to load it from elsewhere.

## Errors

Every raising function raises `MaError`, which carries the miniaudio result as a `MaResult`:

```mojo
try:
    var sound = Sound.from_file(engine, path)
except e:
    match e.result:
        case .DOES_NOT_EXIST:
            print("no such file")
        case .NO_BACKEND | .NO_DEVICE:
            print("no playback device")
        case _:
            print(e)   # "sound init from file failed: MA_INVALID_FILE - Invalid file (-10)"
```

`MaResult` covers every `ma_result` value; it prints its C name (`MA_AT_END`), and the
`MA_*` names are importable from `miniaudio.result`. Checks made on the Mojo side use the code
miniaudio would use (`INVALID_ARGS`, `INVALID_OPERATION`, `OUT_OF_MEMORY`, ...). In a `try` that
reads `e.result`, call only functions that raise `MaError`. A plain `raises` call in the same
block (an `assert_*`, for example) widens `e` to `Error`.

## Layout

Three layers, one per directory (details in `docs/binding-architecture.md`):

| Layer | Where | What |
| --- | --- | --- |
| RAII API | `src/miniaudio/*.mojo` | Owning types (`Decoder`, `Engine`, `Sound`, `Device`, ...); cleanup in `__del__`; `raises MaError` |
| Binding | `src/miniaudio/_ffi/*_raw.mojo` | 1:1 functions over the shim; return `MaResult` and plain values, no policy |
| Shim | `src/native/ma_shim*.{h,c}` | Thin C over miniaudio: opaque alloc/free, accessors, config marshalling |

Tests live in `tests/`: `test_<family>_binding.mojo` covers the raw layer, and
`test_<family>_api.mojo` covers the RAII layer.

## Development

```bash
pixi run test               # every test-<family> task (null backend, no audio device needed)
pixi run gate               # test + coverage: the definition of done (about 20 minutes)
pixi run test-sound         # one family; see pixi.toml for the full list
pixi run coverage-binding   # every shim export bound, @binds valid, exclusions justified
pixi run coverage-shim      # gcov line coverage of the shim, at least 95%
pixi run check-enum-values  # Mojo enum cases equal their miniaudio.h values
```

Test-first is required for every binding; see `docs/binding-test-policy.md`.

## Callback safety

Do not call device lifecycle functions (init / start / stop / uninit) from a miniaudio data
callback or any other audio-thread callback. Signal from the callback, and do the lifecycle work
on another thread.
