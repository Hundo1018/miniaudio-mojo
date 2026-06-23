# miniaudio-mojo

Mojo-first bindings project for miniaudio.

This repository targets Mojo users first. The C example is kept as a native baseline for low-level verification and debugging.

## Binding workflow policy

- Test-first is required for every binding slice.
- Mojo binding test modules live under `tests/`.
- See `docs/binding-test-policy.md` for required checklist and gate commands.

## Mojo-first quick start

Run the Mojo bridge smoke (builds `build/libminiaudio_mojo.so`, then runs `main.mojo`):

```bash
pixi run run-mojo-quickstart
```

Expected result: short sine playback and `playback ok`.

## Current status

- Mojo workspace initialized with pixi.
- Phase 1 implementation includes:
	- Native C shim:
		- `src/native/miniaudio_shim.c`
		- `src/native/miniaudio_shim.h`
		- Lifecycle foundation APIs for context and decoder handles (`create/init/uninit/destroy`)
	- Mojo bridge layers (pure Mojo FFI, no Python ctypes runtime dependency):
		- `src/ffi/miniaudio_ctypes.mojo`
		- `src/api/miniaudio.mojo`
	- Mojo smoke entrypoint:
		- `main.mojo`
	- Native baseline smoke:
		- `examples/native_smoke.c` (debug/baseline, not the main user path)

## Capability snapshot

| Module group | Status |
| --- | --- |
| Context | implemented |
| Device lifecycle/control | implemented |
| Decoder (file+memory/seek/read-probe/read) | implemented |
| Decoder VFS path (default VFS bridge) | implemented (MVP) |
| Capture/duplex smoke paths | implemented |
| Engine/Sound high-level API | partial |
| Resource manager | partial (expanded async/streaming workflow) |
| Async notification primitives | implemented (MVP) |
| Job queue primitives | implemented (MVP) |
| Logging (callback + post) | implemented (MVP) |
| 3D listener/sound controls | partial |
| Node graph/effects slices | partial |
| Waveform generation (f32) | implemented (MVP) |
| Noise generation (f32) | implemented (MVP) |
| Data converter (f32 bridge) | implemented (MVP) |
| Resampler (linear f32) | implemented (MVP) |
| Channel converter (f32) | implemented (MVP) |
| Custom data-source provider | implemented (MVP) |
| Data Source/RingBuffer | partial |
| Encoder VFS path (default VFS bridge) | implemented (MVP) |

For implementation tracking, see `docs/binding-coverage.md`.

## Quick commands

- Run Mojo bridge smoke:

	```bash
	pixi run run-ffi
	```

- Generate native shim coverage baseline report:

	```bash
	pixi run coverage-native-baseline
	```

- Run hardware-independent native binding smoke suite:

	```bash
	pixi run smoke-native-binding-suite
	```

	This runs deterministic shim smoke helpers without requiring audio playback hardware.

- Run fast test-first gate (suite + coverage):

	```bash
	pixi run gate-binding-test-first
	```

	This is the fastest verification path before and after binding changes.

- Run fast Mojo binding gate (deterministic suite):

	```bash
	pixi run gate-binding-test-first-mojo
	```

	This validates Mojo binding surfaces without requiring baseline playback hardware.

- Run Mojo binding contract smoke:

	```bash
	pixi run run-mojo-binding-contract-smoke
	```

	This verifies Mojo-to-FFI error contracts (null/invalid handle paths) from Mojo tests.

- Run Mojo handle lifecycle contract smoke:

	```bash
	pixi run run-mojo-handle-lifecycle-contract-smoke
	```

	This verifies Mojo wrapper lifecycle idempotency (`uninit` before `init`, repeated `close`).

	This builds and runs `examples/native_smoke.c` with coverage flags and emits reports under `build/coverage/native`.
	If `gcovr` is available, it writes:
	- `build/coverage/native/summary.txt`
	- `build/coverage/native/summary.json`
	- `build/coverage/native/index.html`

	If `gcovr` is not available but `gcov` is available, it writes:
	- `build/coverage/native/gcov.txt`

- Show the latest native coverage text summary:

	```bash
	pixi run coverage-native-summary
	```

	This reads `summary.txt` when gcovr exists, or falls back to `gcov.txt` when only gcov is available.

- Run decoder smoke with an audio file (WAV/FLAC/etc supported by miniaudio decoders):

	```bash
	MINIAUDIO_DECODER_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates decoder init, seek, and a small PCM read probe.

 - Run decoder output format matrix smoke with an audio file:

	 ```bash
	 MINIAUDIO_DECODER_FORMAT_MATRIX_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	 ```

	 This validates decoder init across output format matrix (`f32`, `s16`, `s32`, `u8`, `s24`) and invalid-format rejection.

- Run decoder VFS smoke with an audio file:

	```bash
	MINIAUDIO_DECODER_VFS_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the VFS-based decoder path (`ma_decoder_init_vfs`) via shim default VFS.

- Run decoder memory smoke (embedded WAV bytes):

	```bash
	MINIAUDIO_DECODER_MEMORY_SMOKE=1 pixi run run-ffi
	```

	This validates decoder memory init (`ma_decoder_init_memory`) + seek + PCM read probe.

- Run decoder memory invalid-args smoke:

	```bash
	MINIAUDIO_DECODER_MEMORY_INVALID_ARGS_SMOKE=1 pixi run run-ffi
	```

	This validates decoder memory init argument checks.

- Run waveform sine smoke:

	```bash
	pixi run run-waveform-sine-smoke
	```

	This validates the initial waveform generation slice (`ma_waveform`) through the native shim.

- Run waveform invalid-args smoke:

	```bash
	pixi run run-waveform-invalid-args-smoke
	```

	This validates waveform argument rejection for zero frequency and invalid waveform type.

- Run noise smoke:

	```bash
	pixi run run-noise-smoke
	```

	This validates the initial noise generation slice (`ma_noise`) through the native shim.

- Run noise invalid-args smoke:

	```bash
	pixi run run-noise-invalid-args-smoke
	```

	This validates noise argument rejection for invalid channels/type and pre-init usage.

- Run custom buffer data source smoke:

	```bash
	pixi run run-custom-buffer-data-source-smoke
	```

	This validates a custom PCM buffer-backed `ma_data_source` lifecycle, read, seek, and query path.

- Run custom buffer data source invalid-args smoke:

	```bash
	pixi run run-custom-buffer-data-source-invalid-args-smoke
	```

	This validates guardrails for null buffers, empty sources, and pre-init usage.

- Run resource manager streaming async smoke with an audio file:

	```bash
	pixi run run-resource-manager-stream-async-smoke-success
	```

	This validates async+stream decode flow state transitions (`MA_BUSY` -> `MA_SUCCESS`) and available-frame readiness.

- Run resource manager init_ex smoke with an audio file:

	```bash
	pixi run run-resource-manager-init-ex-smoke-success
	```

	This validates the config-based `ma_resource_manager_data_source_init_ex` path, including range, loop point, and initial cursor settings.

- Run resource manager init_ex_w smoke with an audio file:

	```bash
	MINIAUDIO_RESOURCE_INIT_EX_W_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the wide-path config-based `ma_resource_manager_data_source_init_ex` path, including range, loop point, and initial cursor settings.

- Run resource manager init_copy smoke with an audio file:

	```bash
	pixi run run-resource-manager-init-copy-smoke-success
	```

	This validates the copy-path `ma_resource_manager_data_source_init_copy` flow from an existing initialized data source.

- Run resource manager init_w smoke with an audio file:

	```bash
	MINIAUDIO_RESOURCE_INIT_W_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the wide-path resource manager init variant (`ma_resource_manager_data_source_init_w`) via the shim bridge.

- Run data converter smoke:

	```bash
	pixi run run-data-converter-smoke
	```

	This validates standalone `ma_data_converter` channel/rate bridge operations.

- Run data converter invalid-args smoke:

	```bash
	pixi run run-data-converter-invalid-args-smoke
	```

	This validates guardrails for invalid converter init and pre-init processing calls.

- Run decoder memory output format matrix smoke:

	```bash
	MINIAUDIO_DECODER_MEMORY_FORMAT_MATRIX_SMOKE=1 pixi run run-ffi
	```

	This validates decoder memory init across output format matrix (`f32`, `s16`, `s32`, `u8`, `s24`) and invalid-format rejection.

- Run encoder WAV output format matrix smoke:

	```bash
	MINIAUDIO_ENCODER_FORMAT_MATRIX_SMOKE=1 pixi run run-ffi
	```

	This validates encoder WAV init across output format matrix (`f32`, `s16`, `s32`, `u8`) and invalid-format rejection.

- Run encoder VFS WAV smoke:

	```bash
	MINIAUDIO_ENCODER_VFS_WAV_FILE=./build/test_assets/encoder_vfs.wav pixi run run-ffi
	```

	This validates the VFS-based encoder path (`ma_encoder_init_vfs`) and decode-back verification.
 
 - Run decoder format matrix smoke success:
 
	 ```bash
	 pixi run run-decoder-format-matrix-smoke-success
	 ```
 
 - Run decoder format matrix smoke missing:
 
	 ```bash
	 pixi run run-decoder-format-matrix-smoke-missing
	 ```

 - Run decoder memory format matrix smoke:

	 ```bash
	 pixi run run-decoder-memory-format-matrix-smoke
	 ```

 - Run encoder format matrix smoke:

	 ```bash
	 pixi run run-encoder-format-matrix-smoke
	 ```

 - Run encoder invalid-state smoke:

	 ```bash
	 pixi run run-encoder-invalid-state-smoke
	 ```

	 This validates lifecycle guardrails by asserting encoder/decoder read-write APIs reject calls before initialization.

- Run playback file smoke with an audio file:

	```bash
	MINIAUDIO_PLAYBACK_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates decoder + playback device end-to-end using the native shim callback.

- Run engine play-sound smoke with an audio file:

	```bash
	MINIAUDIO_ENGINE_PLAY_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the new high-level engine path (`mmj_engine_*`) through Mojo API.

- Run engine listener 3D control smoke:

	```bash
	MINIAUDIO_ENGINE_LISTENER_SMOKE=1 pixi run run-ffi
	```

	This validates listener position/direction/world-up control APIs.

- Run sound object control smoke with an audio file:

	```bash
	MINIAUDIO_SOUND_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates `mmj_sound_*` path (`init_from_file`, `set_looping`, `set_volume`, `start`, `stop`).

- Run sound spatial control smoke with an audio file:

	```bash
	MINIAUDIO_SOUND_SPATIAL_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates sound-side 3D controls (`spatialization`, `position`, `rolloff`, `min/max distance`).

- Run sound seek smoke with an audio file:

	```bash
	MINIAUDIO_SOUND_SEEK_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates seek-to-frame control and cursor observation via `mmj_sound_seek_to_pcm_frame`.

- Run sound pause smoke with an audio file:

	```bash
	MINIAUDIO_SOUND_PAUSE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates pause behavior and repeated pause safety for sound control flow.

- Run spatial scene sequence smoke:

	```bash
	MINIAUDIO_SPATIAL_SCENE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates listener + sound 3D controls together in a single scenario sequence.

- Run standalone spatializer smoke:

	```bash
	MINIAUDIO_SPATIALIZER_SMOKE=1 pixi run run-ffi
	```

	This validates direct `ma_spatializer` + `ma_spatializer_listener` processing outside the engine/sound wrappers.

- Run standalone spatializer invalid-args smoke:

	```bash
	MINIAUDIO_SPATIALIZER_INVALID_ARGS_SMOKE=1 pixi run run-ffi
	```

	This validates guardrails for invalid channel counts and pre-init processing calls.

- Run node attach/detach smoke:

	```bash
	MINIAUDIO_NODE_ATTACH_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates node attach/detach on a sound node routed to the engine endpoint.

- Run node routing scene smoke:

	```bash
	MINIAUDIO_NODE_ROUTING_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates node output-bus routing + per-bus volume control.

- Run LPF node smoke:

	```bash
	MINIAUDIO_LPF_NODE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates sound -> LPF -> endpoint routing and cutoff sweep.

- Run reverb-like chain smoke:

	```bash
	MINIAUDIO_REVERB_LIKE_CHAIN_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates a reverb-like chain (sound -> LPF -> delay -> endpoint).

- Run splitter (dry/wet) smoke:

	```bash
	MINIAUDIO_SPLITTER_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates signal branching via splitter node (sound -> LPF -> splitter with dual outputs -> endpoint). Volume control is applied per-bus (bus 0 and bus 1) to demonstrate dry/wet mixing.

- Run resource manager smoke with an audio file:

	```bash
	MINIAUDIO_RESOURCE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates minimal resource manager path (`init`, `data_source_init`, `length query`, `uninit`).

- Run resource manager async polling smoke:

	```bash
	MINIAUDIO_RESOURCE_ASYNC_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates async init + terminal status wait (timeout-bound polling) + length query.

- Run resource manager pipeline notifications smoke:

	```bash
	MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates callback-driven stage notifications (`init` + `done`) through `ma_resource_manager_pipeline_notifications` wiring.

- Run resource manager pipeline notifications_w smoke:

	```bash
	MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_W_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the wide-path pipeline notification variant (`ma_resource_manager_data_source_init_w`) with callback-driven stage notifications (`init` + `done`).

- Run resource manager pipeline fence smoke:

	```bash
	MINIAUDIO_RESOURCE_PIPELINE_FENCE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates stage fence wiring (`init` + `done`) through `ma_resource_manager_pipeline_notifications` and blocks on both fences before final result verification.

- Run resource manager pipeline notifications+fences smoke:

	```bash
	MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FENCES_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates combined stage signaling (`init` + `done`) where both poll notifications and fences are wired in the same pipeline init flow.

- Run resource manager pipeline notifications+fences_w smoke:

	```bash
	MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FENCES_W_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates the wide-path pipeline init variant (`ma_resource_manager_data_source_init_w`) with combined stage signaling (`init` + `done`) using both poll notifications and fences.

- Run async notification poll smoke:

	```bash
	MINIAUDIO_ASYNC_NOTIFICATION_POLL_SMOKE=1 pixi run run-ffi
	```

	This validates async notification poll init, signal, and signalled state.

- Run async notification event smoke:

	```bash
	MINIAUDIO_ASYNC_NOTIFICATION_EVENT_SMOKE=1 pixi run run-ffi
	```

	This validates async notification event init, signal, and wait flow.

- Run job queue smoke:

	```bash
	MINIAUDIO_JOB_QUEUE_SMOKE=1 pixi run run-ffi
	```

	This validates non-blocking job queue init, custom job post/read, and quit-job termination path.

- Run sync primitives smoke:

	```bash
	MINIAUDIO_SYNC_PRIMITIVES_SMOKE=1 pixi run run-ffi
	```

	This validates mutex lock/unlock, event signal/wait, semaphore release/wait, and spinlock lock/unlock on the shim path.

- Run sync primitives invalid-args smoke:

	```bash
	MINIAUDIO_SYNC_PRIMITIVES_INVALID_ARGS_SMOKE=1 pixi run run-ffi
	```

	This validates null-handle guardrails for synchronization primitives and expects `MA_INVALID_ARGS` on each invalid path.

- Run logging smoke:

	```bash
	MINIAUDIO_LOGGING_SMOKE=1 pixi run run-ffi
	```

	This validates log init, callback registration, info-level post, and callback invocation counting.

- Run logging invalid-state smoke:

	```bash
	MINIAUDIO_LOGGING_INVALID_SMOKE=1 pixi run run-ffi
	```

	This validates a negative path by posting before `log_init` and expecting `MA_INVALID_ARGS`.

- Run resampler linear smoke:

	```bash
	MINIAUDIO_RESAMPLER_LINEAR_SMOKE=1 pixi run run-ffi
	```

	This validates linear f32 resampler init/process path.

- Run resampler invalid-rate smoke:

	```bash
	MINIAUDIO_RESAMPLER_INVALID_RATE_SMOKE=1 pixi run run-ffi
	```

	This validates negative path for invalid sample rate.

- Run channel converter stereo-to-mono smoke:

	```bash
	MINIAUDIO_CHANNEL_CONVERTER_STEREO_MONO_SMOKE=1 pixi run run-ffi
	```

	This validates f32 channel conversion (2ch -> 1ch).

- Run channel converter invalid-channels smoke:

	```bash
	MINIAUDIO_CHANNEL_CONVERTER_INVALID_CHANNELS_SMOKE=1 pixi run run-ffi
	```

	This validates negative path for zero-channel init.

- Run PCM ring buffer smoke:

	```bash
	MINIAUDIO_PCM_RB_SMOKE=1 pixi run run-ffi
	```

	This validates ring buffer f32 write/read/available behavior.

- Run PCM ring buffer overflow smoke:

	```bash
	MINIAUDIO_PCM_RB_OVERFLOW_SMOKE=1 pixi run run-ffi
	```

	This validates overflow boundary behavior (full buffer write attempt).

- Run PCM ring buffer invalid-args smoke:

	```bash
	MINIAUDIO_PCM_RB_INVALID_ARGS_SMOKE=1 pixi run run-ffi
	```

	This validates parameter rejection for invalid initialization.

- Run all current Mojo smoke paths:

	```bash
	pixi run run-all-smokes
	```

- Decoder/Encoder smoke shortcut tasks:

	```bash
	pixi run run-decoder-smoke-success
	pixi run run-decoder-smoke-missing
	pixi run run-decoder-read-smoke-success
	pixi run run-decoder-read-smoke-missing
	pixi run run-decoder-memory-smoke
	pixi run run-decoder-memory-invalid-args-smoke
	pixi run run-encoder-write-frames-smoke-success
	pixi run run-encoder-write-frames-smoke-missing
	pixi run run-playback-file-smoke-success
	pixi run run-playback-file-smoke-missing
	pixi run run-engine-play-smoke-success
	pixi run run-engine-play-smoke-missing
	pixi run run-engine-listener-smoke
	pixi run run-sound-control-smoke-success
	pixi run run-sound-control-smoke-missing
	pixi run run-sound-spatial-smoke-success
	pixi run run-sound-spatial-smoke-missing
	pixi run run-sound-seek-smoke-success
	pixi run run-sound-seek-smoke-missing
	pixi run run-sound-pause-smoke-success
	pixi run run-sound-pause-smoke-missing
	pixi run run-spatial-scene-smoke-success
	pixi run run-spatial-scene-smoke-missing
	pixi run run-node-attach-smoke-success
	pixi run run-node-attach-smoke-missing
	pixi run run-node-routing-smoke-success
	pixi run run-node-routing-smoke-missing
	pixi run run-lpf-node-smoke-success
	pixi run run-lpf-node-smoke-missing
	pixi run run-reverb-like-chain-smoke-success
	pixi run run-reverb-like-chain-smoke-missing
	pixi run run-resource-manager-smoke-success
	pixi run run-resource-manager-smoke-missing
	pixi run run-resource-manager-async-smoke-success
	pixi run run-resource-manager-async-smoke-missing
	pixi run run-resource-manager-init-ex-smoke-success
	pixi run run-resource-manager-init-ex-w-smoke-success
	pixi run run-resource-manager-init-copy-smoke-success
	pixi run run-resource-manager-init-w-smoke-success
	pixi run run-resource-manager-pipeline-notifications-smoke-success
	pixi run run-resource-manager-pipeline-notifications-w-smoke-success
	pixi run run-resource-manager-pipeline-fence-smoke-success
	pixi run run-resource-manager-pipeline-notifications-fences-smoke-success
	pixi run run-resource-manager-pipeline-notifications-fences-w-smoke-success
	pixi run run-job-queue-smoke
	pixi run run-job-queue-invalid-args-smoke
	pixi run run-async-notification-poll-smoke
	pixi run run-async-notification-poll-invalid-args-smoke
	pixi run run-async-notification-event-smoke
	pixi run run-async-notification-event-invalid-args-smoke
	pixi run run-logging-smoke
	pixi run run-logging-invalid-smoke
	pixi run run-resampler-linear-smoke
	pixi run run-resampler-invalid-rate-smoke
	pixi run run-resampler-expected-count-smoke
	pixi run run-channel-converter-stereo-mono-smoke
	pixi run run-channel-converter-invalid-channels-smoke
	pixi run run-channel-converter-init-mode-smoke
	pixi run run-data-converter-smoke
	pixi run run-data-converter-invalid-args-smoke
	pixi run run-noise-smoke
	pixi run run-noise-invalid-args-smoke
	pixi run run-spatializer-smoke
	pixi run run-spatializer-invalid-args-smoke
	pixi run run-custom-buffer-data-source-smoke
	pixi run run-custom-buffer-data-source-invalid-args-smoke
	pixi run run-pcm-rb-smoke
	pixi run run-pcm-rb-overflow-smoke
	pixi run run-pcm-rb-invalid-args-smoke
	pixi run run-pcm-rb-handle-smoke
	```

- Run context lifecycle smoke:

	```bash
	MINIAUDIO_CONTEXT_SMOKE=1 pixi run run-ffi
	```

- Run capture lifecycle smoke:

	```bash
	MINIAUDIO_CAPTURE_SMOKE=1 pixi run run-ffi
	```

- Run capture-to-file smoke:

	```bash
	MINIAUDIO_CAPTURE_FILE=/absolute/path/to/capture.wav pixi run run-ffi
	```

	This validates capture + WAV encoding in the native shim.

- Run duplex smoke (capture + playback in one device):

	```bash
	MINIAUDIO_DUPLEX_SMOKE=1 pixi run run-ffi
	```

- Run duplex control smoke (loopback + start/stop):

	```bash
	MINIAUDIO_DUPLEX_CONTROL_SMOKE=1 pixi run run-ffi
	```

- Run device enumeration smoke:

	```bash
	MINIAUDIO_DEVICES_SMOKE=1 pixi run run-ffi
	```

- Run device control smoke:

	```bash
	MINIAUDIO_DEVICE_CONTROL_SMOKE=1 pixi run run-ffi
	```

- Run device volume smoke:

	```bash
	MINIAUDIO_DEVICE_VOLUME_SMOKE=1 pixi run run-ffi
	```

- Run device config smoke:

	```bash
	MINIAUDIO_DEVICE_CONFIG_SMOKE=1 pixi run run-ffi
	```

- Run device format matrix smoke:

	```bash
	MINIAUDIO_DEVICE_FORMAT_MATRIX_SMOKE=1 pixi run run-ffi
	```

	This validates playback/capture/duplex/duplex-loopback device init across a format matrix (`f32`, `s16`, `s32`, `u8`, `s24`) and checks invalid-format rejection.

- Run device init_ex smoke (period/profile tuning path):

	```bash
	MINIAUDIO_DEVICE_INIT_EX_SMOKE=1 pixi run run-ffi
	```

- Shortcut tasks:

	```bash
	pixi run run-context-smoke
	pixi run run-capture-smoke
	pixi run run-capture-file-smoke-success
	pixi run run-capture-file-smoke-missing
	pixi run run-duplex-smoke
	pixi run run-duplex-control-smoke
	pixi run run-custom-buffer-data-source-smoke
	pixi run run-custom-buffer-data-source-invalid-args-smoke
	pixi run run-devices-smoke
	pixi run run-device-control-smoke
	pixi run run-device-volume-smoke
	pixi run run-device-config-smoke
	pixi run run-device-format-matrix-smoke
	pixi run run-device-init-ex-smoke
	pixi run run-all-smokes
	```

## Native baseline (C)

Use native smoke only when validating low-level native behavior or isolating FFI issues.

- Run native baseline smoke:

	```bash
	pixi run smoke-native-baseline
	```

- Source:

	- `examples/native_smoke.c`

If Mojo smoke fails but native smoke passes, the issue is likely in Mojo FFI/API layers.

## Callback safety notes

- Do not call device lifecycle APIs from inside miniaudio data callbacks. In particular, avoid calling init/start/stop/uninit from callback threads.
- If you need to stop or reconfigure audio, signal from callback and perform lifecycle operations on another thread.

- Build shared library (`build/libminiaudio_mojo.so`):

	```bash
	pixi run build-native-lib
	```