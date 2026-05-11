# Binding Coverage Matrix

This document tracks miniaudio binding coverage in this repository.

## Scope

- Upstream reference: `vendor/miniaudio/miniaudio.h`
- Native shim surface: `src/native/miniaudio_shim.h`
- Mojo bridge surface: `src/ffi/miniaudio_ctypes.mojo`
- Mojo API layer: `src/api/*`

## Current baseline (2026-05-12)

Estimated totals:

- Upstream exported API (`MA_API`): large surface (roughly hundreds of functions).
- Current shim exports (`mmj_*`): 38 public functions.
- Effective coverage mode: foundational I/O path coverage, not high-level feature parity.

## Module status

| Module group | Coverage status | Notes |
| --- | --- | --- |
| Context | implemented | create/init/uninit/destroy + device count/name |
| Device lifecycle/control | implemented | init variants/start/stop/is_started/kind/rate/channels/volume |
| Decoder | implemented | init file, read probe, read frames, seek, uninit |
| Capture/duplex smoke paths | implemented | smoke helpers via shim |
| Engine/Sound | partial | engine lifecycle + play_sound + sound object controls (init/start/stop/loop/volume) |
| Resource manager | partial | manager init/uninit + data source init/length + async result polling |
| 3D audio controls | partial | listener controls + sound spatialization/position/rolloff/min-max distance |
| Node graph routing | not started | planned |
| Effect chain (LPF/reverb slices) | not started | planned vertical slices |

## Planned milestones

1. P1: Engine/Sound minimal usable set.
2. P2: Resource manager + 3D MVP.
3. P3: Node/effect vertical slices.
4. R: Stability and release gates.

## Definition of done checkpoints

- Keep existing smoke tasks green.
- Add dedicated smoke tasks for each newly introduced module group.
- Include at least one negative-path check per new module group.
- Keep README capability snapshot synchronized with this file.
