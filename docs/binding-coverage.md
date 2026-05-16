# Binding Coverage Matrix

This document tracks miniaudio binding coverage in this repository.

## Scope

- Upstream reference: `vendor/miniaudio/miniaudio.h`
- Native shim surface: `src/native/miniaudio_shim.h`
- Mojo bridge surface: `src/ffi/miniaudio_ctypes.mojo`
- Mojo API layer: `src/api/*`

## Current baseline (2026-05-16)

Estimated totals:

- Upstream exported API (`MA_API`): large surface (roughly hundreds of functions).
- Current shim exports (`mmj_*`): 170+ public functions (includes resampler + channel converter MVP slice).
- Effective coverage mode: foundational I/O path coverage, not high-level feature parity.

## Module status

| Module group | Coverage status | Notes |
| --- | --- | --- |
| Context | implemented | create/init/uninit/destroy + device count/name |
| Device lifecycle/control | implemented | init variants/start/stop/is_started/kind/rate/channels/volume + playback/capture/duplex format matrix init (`u8/s16/s24/s32/f32`) |
| Decoder | implemented | init file/memory with output format matrix (`f32/s16/s32/u8/s24`) + matrix smokes (file+memory) + read probe/read frames/seek/uninit |
| Encoder | implemented (format matrix MVP) | init WAV file with output format matrix (`f32/s16/s32/u8`) + write silence + write PCM frames (int64_t return) + uninit |
| Capture/duplex smoke paths | implemented | smoke helpers via shim |
| Engine/Sound | partial | engine lifecycle + play_sound + sound object controls (init/start/stop/pause/seek/loop/volume/cursor/time) |
| Resource manager | partial | manager init/uninit + data source init/length + async result polling |
| Logging | implemented (MVP) | log create/init/uninit + register/unregister counting callback + post info |
| 3D audio controls | partial | listener controls + sound spatial controls + scenario sequence smoke |
| Node graph routing | partial | endpoint lookup + sound node attach/detach + output bus volume control |
| Effect chain (LPF/reverb/splitter) | partial | LPF node smoke + reverb-like LPF→delay chain smoke + splitter dry/wet branching smoke |
| Resampler | implemented (MVP) | linear f32 init/process/reset + expected-output query + positive/negative smokes |
| Channel converter | implemented (MVP) | f32 init/process/uninit (rectangular/simple modes) + stereo→mono and invalid-channel smokes |
| Data Source/RingBuffer | partial | pcm ring buffer f32 init/read/write/available/reset + overflow/invalid-args smokes |

## Planned milestones

1. Stage 1: Engine/Sound minimal usable set.
2. Stage 2: Resource manager + 3D MVP.
3. Stage 3: Node/effect vertical slices.
4. Stage 4: Stability and release gates.

## Definition of done checkpoints

- Keep existing smoke tasks green.
- Add dedicated smoke tasks for each newly introduced module group.
- Include at least one negative-path check per new module group.
- Keep README capability snapshot synchronized with this file.
