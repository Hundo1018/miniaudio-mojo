# miniaudio-mojo

Mojo project for miniaudio integration.

## Current status

- Mojo workspace initialized with pixi.
- Phase 1 implementation started with a native C shim:
	- `src/native/miniaudio_shim.c`
	- `src/native/miniaudio_shim.h`
- Native smoke demo:
	- `examples/native_smoke.c`

## Quick commands

- Run Mojo bridge demo (builds `.so` then plays a short sine tone):

	```bash
	pixi run run-ffi
	```

- Run native smoke test directly:

	```bash
	pixi run smoke-native
	```

- Build shared library (`build/libminiaudio_mojo.so`):

	```bash
	pixi run build-native-lib
	```

- Build and run native playback smoke test:

	```bash
	pixi run smoke-native
	```