# miniaudio-mojo

Mojo project for miniaudio integration.

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
	- Native smoke demo:
		- `examples/native_smoke.c`

## Quick commands

- Run Mojo bridge demo (builds `.so` then plays a short sine tone):

	```bash
	pixi run run-ffi
	```

- Run decoder smoke with an audio file (WAV/FLAC/etc supported by miniaudio decoders):

	```bash
	MINIAUDIO_DECODER_FILE=/absolute/path/to/sample.wav pixi run run-ffi
	```

	This validates decoder init, seek, and a small PCM read probe.

- Decoder smoke shortcut tasks:

	```bash
	pixi run run-decoder-smoke-success
	pixi run run-decoder-smoke-missing
	```

- Run context lifecycle smoke:

	```bash
	MINIAUDIO_CONTEXT_SMOKE=1 pixi run run-ffi
	```

- Run capture lifecycle smoke:

	```bash
	MINIAUDIO_CAPTURE_SMOKE=1 pixi run run-ffi
	```

- Run duplex smoke (capture + playback in one device):

	```bash
	MINIAUDIO_DUPLEX_SMOKE=1 pixi run run-ffi
	```

- Run device enumeration smoke:

	```bash
	MINIAUDIO_DEVICES_SMOKE=1 pixi run run-ffi
	```

- Shortcut tasks:

	```bash
	pixi run run-context-smoke
	pixi run run-capture-smoke
	pixi run run-duplex-smoke
	pixi run run-devices-smoke
	pixi run run-all-smokes
	```

## Callback safety notes

- Do not call device lifecycle APIs from inside miniaudio data callbacks. In particular, avoid calling init/start/stop/uninit from callback threads.
- If you need to stop or reconfigure audio, signal from callback and perform lifecycle operations on another thread.

- Run native smoke test directly:

	```bash
	pixi run smoke-native
	```

- Build shared library (`build/libminiaudio_mojo.so`):

	```bash
	pixi run build-native-lib
	```