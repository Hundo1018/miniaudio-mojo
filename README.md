# miniaudio-mojo

Mojo project for miniaudio integration.

## Current status

- Mojo workspace initialized with pixi.
- Phase 1 implementation includes:
	- Native C shim:
		- `src/native/miniaudio_shim.c`
		- `src/native/miniaudio_shim.h`
	- Mojo bridge layers:
		- `src/ffi/miniaudio_ctypes.mojo`
		- `src/api/miniaudio.mojo`
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