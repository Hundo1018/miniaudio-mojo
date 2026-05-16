# Binding Coverage Matrix

This document tracks miniaudio binding coverage in this repository.

## Scope

- Upstream reference: `vendor/miniaudio/miniaudio.h`
- Native shim surface: `src/native/miniaudio_shim.h`
- Mojo bridge surface: `src/ffi/miniaudio_ctypes.mojo`
- Mojo API layer: `src/api/*`

## Current baseline (2026-05-17)

Estimated totals:

- Upstream exported API (`MA_API`): very large surface (hundreds of functions across core, engine, node graph, effects, data conversion, utility subsystems).
- Current shim exports (`mmj_*`): 170+ public functions.
- Effective maturity profile: broad MVP slices exist in multiple domains, but mostly smoke-level and not yet deep parity.

## Maturity framing (breadth-first)

This project has moved past "single-path smoke only" and now covers many miniaudio domains at MVP depth.

- Breadth: medium-high (many module families present).
- Depth: medium-low (most families still minimal wrappers + smokes).
- Parity with upstream: partial (good directional coverage, limited advanced/production workflows).

Interpretation:

- Good status for proving architecture and validating FFI integration across module families.
- Not yet a "feature-complete" binding for upstream miniaudio users.
- Next steps should prioritize adding whole missing feature families before deepening existing ones.

## Module status

| Module group | Coverage status | Notes |
| --- | --- | --- |
| Context | implemented | create/init/uninit/destroy + device count/name |
| Device lifecycle/control | implemented | init variants/start/stop/is_started/kind/rate/channels/volume + playback/capture/duplex format matrix init (`u8/s16/s24/s32/f32`) |
| Device user callbacks | partial | callback registration/clear + smoke helper exist; callback ergonomics/safety still early |
| Decoder | implemented | init file/memory with output format matrix (`f32/s16/s32/u8/s24`) + matrix smokes (file+memory) + read probe/read frames/seek/uninit |
| Encoder | implemented (format matrix MVP) | init WAV file with output format matrix (`f32/s16/s32/u8`) + write silence + write PCM frames (int64_t return) + uninit |
| Capture/duplex smoke paths | implemented | smoke helpers via shim |
| Memory buffer I/O | partial | playback-from-buffer + capture-to-buffer wrappers exist; no dedicated end-to-end smoke suite yet |
| Engine/Sound | partial | engine lifecycle + play_sound + sound object controls (init/start/stop/pause/seek/loop/volume/cursor/time) |
| Sound groups | partial (expanded) | group create/init/start/stop + volume/pan/pitch/spatial toggles + 3D position/direction/velocity + rolloff/min/max distance + attenuation/positioning/pinned-listener/cone/doppler/directional attenuation + parent-group init + sound init-in-group + fade-in-pcm/ms + current-fade-volume + start/stop time scheduling (pcm+ms) + get_time_in_pcm_frames + positive/negative/boundary/fade smokes |
| Resource manager | partial | manager init/uninit + data source init/length + async result polling |
| Logging | implemented (MVP) | log create/init/uninit + register/unregister counting callback + post info |
| 3D audio controls | partial | listener controls + sound spatial controls + scenario sequence smoke |
| Node graph routing | partial | endpoint lookup + sound node attach/detach + output bus volume control |
| Effect chain (LPF/HPF/delay/splitter) | partial | LPF/HPF/delay/splitter wrappers + graph-chain smokes |
| Biquad EQ | partial | biquad node init/reinit + peaking-EQ coefficient helper + positive/negative smokes |
| Notch/Peak/Loshelf/Hishelf EQ nodes | implemented (MVP) | all 4 node families with create/init/reinit/get_node/uninit/destroy lifecycle + positive smokes (notch/peak/loshelf/hishelf) + negative smoke (uninit on invalid handle) |
| Resampler | implemented (MVP) | linear f32 init/process/reset + expected-output query + positive/negative smokes |
| Channel converter | implemented (MVP) | f32 init/process/uninit (rectangular/simple modes) + stereo→mono and invalid-channel smokes |
| Data Source/RingBuffer | partial (expanded) | pcm ring buffer f32 init/read/write/available/reset + overflow/invalid-args smokes; resource data source extended: seek_to_pcm_frame/seek_pcm_frames/get_cursor_pcm/get_cursor_secs/get_length_secs/get_format/channels/sample_rate/set_looping/is_looping/set_range/get_range_beg_end + seek_to_second/seek_seconds/set_loop_point_in_pcm_frames/get_loop_point_beg_in_pcm_frames/get_loop_point_end_in_pcm_frames + positive/negative smokes |

## Missing high-breadth feature families (priority candidates)

These are ranked by "new capability area unlocked" rather than polish depth.

1. Data source ecosystem expansion
	- Add broader `ma_data_source`-style operations and conversion bridges (beyond current decoder/ring buffer MVP).
	- Why breadth-first: unlocks many pipelines (streaming, transform chains, custom sources).
2. Engine asset/mix hierarchy
	- Add sound groups, group-level controls, and richer engine-managed playback patterns.
	- Why breadth-first: opens a major high-level workflow used by typical app/game users.
3. Node graph effect catalog expansion
	- Add additional node families beyond current LPF/HPF/delay/splitter/biquad MVP set.
	- Why breadth-first: quickly grows DSP coverage and chain design flexibility.
4. Advanced device/backend configuration slice
	- Add broader device config surface and callback/control variants.
	- Why breadth-first: unlocks hardware/latency/backend scenarios currently out of reach.
5. Resource manager streaming workflows
	- Expand async/streaming usage coverage (not only init/result/length polling).
	- Why breadth-first: enables real content loading patterns in larger apps.

## Breadth-first roadmap (next)

1. Milestone A: "High-level playback architecture" (recommended first)
	- Target: engine sound groups + grouped controls + one integrated smoke scenario.
	- Coverage gain: large user-facing API family in one step.
	- Status: complete (lifecycle + volume/pan/pitch/spatial + 3D controls + attenuation family + parent-group + grouped sound init + invalid-state/boundary checks + fade/timing family landed).
2. Milestone B: "Data pipeline primitives"
	- Target: data-source conversion/bridging APIs + memory/file/custom source interoperability.
	- Coverage gain: foundational for many other modules.
	- Status: complete (resource data source seek/cursor/length/format/channels/samplerate/looping/range/loop-points APIs + positive/negative smokes landed).
3. Milestone C: "Effect family expansion"
	- Target: add at least 2 new effect/node families with one chain smoke and one negative-path smoke each.
	- Coverage gain: substantial DSP breadth growth.
	- Status: in progress (notch/peak/loshelf/hishelf EQ nodes: 4 node families with lifecycle + positive/negative smokes landed).
4. Milestone D: "Streaming-grade resource manager"
	- Target: async/streaming lifecycle APIs and state/error transitions.
	- Coverage gain: shifts from demo-level to app-level loading workflows.

## Release-readiness blockers (cross-cutting)

Even with breadth prioritized, these remain required for maturity:

- More non-smoke tests per new module family (not only "function returns success").
- Callback/threading safety guidance and lifecycle constraints in API docs.
- Consistent ownership/lifetime patterns across all handle wrappers.
- Linux-only validation must be extended before claiming cross-platform maturity.

## Definition of done checkpoints

- Keep existing smoke tasks green.
- Add dedicated smoke tasks for each newly introduced module group.
- Include at least one negative-path check per new module group.
- Keep README capability snapshot synchronized with this file.
