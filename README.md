# miniaudio-mojo

Mojo-first bindings project for miniaudio.

This repository targets Mojo users first. The C example is kept as a native baseline for low-level verification and debugging.

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
| Decoder (file/seek/read-probe/read) | implemented |
| Capture/duplex smoke paths | implemented |
| Engine/Sound high-level API | planned |
| Resource manager | planned |
| 3D listener/sound controls | planned |
| Node graph/effects slices | planned |

For implementation tracking, see `docs/binding-coverage.md`.

## Quick commands

- Run Mojo bridge smoke:

	```bash
	pixi run run-ffi
	```

- Run decoder smoke with an audio file (WAV/FLAC/etc supported by miniaudio decoders):

	```bash
	MINIAUDIO_DECODER_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates decoder init, seek, and a small PCM read probe.

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

- Run spatial scene sequence smoke:

	```bash
	MINIAUDIO_SPATIAL_SCENE_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates listener + sound 3D controls together in a single scenario sequence.

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

- Run all current Mojo smoke paths:

	```bash
	pixi run run-all-smokes
	```

- Decoder smoke shortcut tasks:

	```bash
	pixi run run-decoder-smoke-success
	pixi run run-decoder-smoke-missing
	pixi run run-decoder-read-smoke-success
	pixi run run-decoder-read-smoke-missing
	pixi run run-playback-file-smoke-success
	pixi run run-playback-file-smoke-missing
	pixi run run-engine-play-smoke-success
	pixi run run-engine-play-smoke-missing
	pixi run run-engine-listener-smoke
	pixi run run-sound-control-smoke-success
	pixi run run-sound-control-smoke-missing
	pixi run run-sound-spatial-smoke-success
	pixi run run-sound-spatial-smoke-missing
	pixi run run-spatial-scene-smoke-success
	pixi run run-spatial-scene-smoke-missing
	pixi run run-resource-manager-smoke-success
	pixi run run-resource-manager-smoke-missing
	pixi run run-resource-manager-async-smoke-success
	pixi run run-resource-manager-async-smoke-missing
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

- Shortcut tasks:

	```bash
	pixi run run-context-smoke
	pixi run run-capture-smoke
	pixi run run-capture-file-smoke-success
	pixi run run-capture-file-smoke-missing
	pixi run run-duplex-smoke
	pixi run run-duplex-control-smoke
	pixi run run-devices-smoke
	pixi run run-device-control-smoke
	pixi run run-device-volume-smoke
	pixi run run-device-config-smoke
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