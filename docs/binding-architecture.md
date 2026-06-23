# Binding Architecture (layered rebinding)

This document defines the target architecture for the rebinding effort and the
contract each layer must honour. The **decoder** is the implemented reference
slice; every other module group is migrated by following the same pattern.

## Layers

```
Layer 3  Idiomatic Mojo API      src/miniaudio/decoder.mojo, result.mojo, _lib.mojo, __init__.mojo
           RAII (__del__), raises Error, List/Span buffers, SampleFormat, no `bridge` arg
Layer 2  Binding layer           src/miniaudio/_ffi/decoder_raw.mojo
           free functions, 1:1 over the shim, return raw ma_result codes / MaCount, no policy
Layer 1  Thin native shim        src/native/ma_shim.{h,c}  ->  build/libma_shim.so
           opaque alloc/free + field accessors + config marshalling + forward to real ma_*
Layer 0  Vendored miniaudio      vendor/miniaudio/*  (unchanged)
```

### Layer 1 — thin shim contract (`ma_shim.c`)
- Allocation only: `malloc`/`calloc` of an miniaudio handle plus a small
  `initialized` bookkeeping flag. **No** scenario logic, synthesis, format
  matrices, or smoke flows (those belong in Mojo tests).
- Config marshalling is limited to building the standard `ma_*_config` from
  primitive args and forwarding to the real `ma_*` function.
- Field reads go through miniaudio's public query APIs (e.g.
  `ma_decoder_get_data_format`) because Mojo cannot read C struct layout.
- Every entry point returns a raw `ma_result` int (or a documented sentinel).
- Sample-format codes equal miniaudio's `ma_format` enum: unknown=0, u8=1,
  s16=2, s24=3, s32=4, f32=5.

### Layer 2 — binding layer contract (`_ffi/*_raw.mojo`)
- Per-domain **free functions** taking `lib: MaLib` + raw handle. This avoids
  the previous 439-method monolith.
- Marshals Mojo types to the C ABI and returns the raw code (or `MaCount` =
  `(result, value)` for uint64 out-params). **No** lifecycle/error policy.
- This is the layer the contract tests target directly (positive + negative).

### Layer 3 — API contract (`decoder.mojo` etc.)
- RAII types own the handle and clean up in `__del__`; no manual `close`.
- The loaded library is shared via `ArcPointer[MaLib]`; **no `bridge` argument**
  is threaded through methods.
- Failures `raise Error` with messages built from `result_name` +
  `MaLib.result_description`.
- Buffers are `List[Float32]` / `List[UInt8]` / `Span` — never `String`.
- For `init_memory`, the API keeps the source bytes alive for the decoder's
  lifetime (miniaudio references, does not copy, the memory).

## Conventions established this slice
- Library path resolved centrally: `MINIAUDIO_MOJO_LIB` env var, else
  `build/libma_shim.so` (`MaLib.default()`). Never hardcoded per call site.
- Tests use `std.testing` (`assert_*`, `assert_raises`,
  `TestSuite.discover_tests[__functions_in_module()]().run()`); the removed
  `mojo test` CLI is not used.
- Null/opaque handles: `OpaquePointer[MutUntrackedOrigin]`; the null sentinel is
  `unsafe_from_address=Int(0)` (a runtime `Int`, since the pinned nightly
  rejects a literal `0` as non-nullable).

## Build & test
```bash
pixi run build-shim     # build build/libma_shim.so
pixi run test-decoder   # build shim + gen wav + run binding & API test suites
pixi run test           # alias for the full new-suite (grows per slice)
```

## Migration rollout
Apply the same three-layer + TDD template to, in order: encoder, device/
playback, engine/sound, data_source/ring_buffer, converters/resampler/channel,
nodes/effects/eq, resource_manager, sync/async/job_queue/logging, context/
devices. Add each domain's shim functions to `ma_shim.c`, its raw module under
`src/miniaudio/_ffi/`, its RAII type under `src/miniaudio/`, and its test files
under `tests/` (wired into the `test` task). Retire the matching legacy
`src/api` module and fat-shim section once a group is migrated; the final step
removes `main.mojo`'s env-var dispatcher.

## Note on the legacy code
The legacy layers (`src/api`, `src/ffi`, `src/native/miniaudio_shim.*`,
`main.mojo`) did **not** compile on the currently pinned Mojo nightly: 55 sites
used `OpaquePointer[...](unsafe_from_address=0)`, now rejected. They were given
the minimal mechanical fix (`unsafe_from_address=Int(0)`) so the legacy gate
(`pixi run gate-binding-test-first-mojo`) builds and runs again as an
integration smoke during migration. No legacy behaviour was otherwise changed.
