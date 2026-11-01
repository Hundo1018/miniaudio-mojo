#!/usr/bin/env python3
"""Native vs WebAssembly parity: render the same scene both ways, compare bytes.

    pixi run -e wasm test-wasm

1. builds build/wasm/audio.wasm (ludens-wasm-rt driver on wasm.toml, examples/web/audio.mojo);
2. builds the native reference examples/web/render_native.mojo statically linked,
   for a baseline x86-64 CPU (no FMA, like wasm);
3. renders examples/web/scene.render_scene -- a decoded WAV clip plus a Mojo
   UserNode tone, 128 frames per block -- natively and in Node (wasm64);
4. passes only if the two f32 PCM files are byte-identical and carry both the
   clip and the tone (so the Mojo node callback ran through the wasm table).
"""

import hashlib
import math
import os
import struct
import subprocess
import sys
from pathlib import Path

import ludens_wasm_rt

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "build" / "wasm"
CLIP = ROOT / "build" / "test_assets" / "sine_440_stereo.wav"
FRAMES = 48000


def native_env() -> dict[str, str]:
    """This process's environment without the wasm environment's activation (its conda
    GCC toolchain and sysroot, which does not link against this system's libdl)."""
    wasm_env = str(ROOT / ".pixi" / "envs" / "wasm")
    env = {k: v for k, v in os.environ.items() if wasm_env not in v or k == "PATH"}
    env["PATH"] = os.pathsep.join(p for p in env["PATH"].split(os.pathsep) if wasm_env not in p)
    return env


def run(cmd: list[str], env: dict[str, str] | None = None) -> str:
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env)
    if proc.returncode != 0:
        sys.exit(f"test-wasm: {' '.join(cmd[:3])} ... failed\n{(proc.stdout + proc.stderr)[-3000:]}")
    return proc.stdout.strip()


def component(left: list[float], hz: float, shape) -> float:
    return abs(2 * sum(v * shape(i * hz / 48000) for i, v in enumerate(left)) / len(left))


def main() -> int:
    run(["pixi", "run", "-e", "default", "build-shim-static"], env=native_env())  # native C: system cc
    print(run([sys.executable, "-m", "ludens_wasm_rt.build_wasm", "--lib", ".", "examples/web/audio.mojo",
               "-I", "examples/web", "-o", str(OUT / "audio.wasm"), "--export", "web_*"]))
    # The native reference links in the default environment, outside the wasm activation.
    run(["pixi", "run", "-e", "default", "mojo", "build", "--target-cpu", "x86-64", "-D", "MINIAUDIO_LINK=static", "-I", "src",
         "-I", "examples/web", "examples/web/render_native.mojo", "-o", str(OUT / "render_native"),
         "-Xlinker", str(ROOT / "build" / "libma_shim.a"), "-Xlinker", "-lpthread",
         "-Xlinker", "-lm", "-Xlinker", "-ldl", "-Xlinker", "-latomic"], env=native_env())
    native, wasm = OUT / "scene_native.f32", OUT / "scene_wasm.f32"
    print(run([str(OUT / "render_native"), str(CLIP), str(FRAMES), str(native)]))
    print(run(["node", "tools/wasm/render_wasm.mjs", str(OUT / "audio.wasm"), str(CLIP), str(FRAMES), str(wasm)],
              env={**os.environ, "LUDENS_WASM_HOST": str(ludens_wasm_rt.HOST_MJS)}))

    a, b = native.read_bytes(), wasm.read_bytes()
    ha, hb = hashlib.sha256(a).hexdigest(), hashlib.sha256(b).hexdigest()
    left = struct.unpack(f"<{len(b) // 4}f", b)[0::2]
    clip = component(left, 440, lambda t: math.sin(2 * math.pi * t))
    tone = component(left, 220, lambda t: -math.cos(2 * math.pi * t))
    print(f"native sha256 {ha}\nwasm   sha256 {hb}")
    print(f"440 Hz clip amplitude {clip:.3f} (expect 0.200), 220 Hz tone fundamental {tone:.3f} (expect 0.203)")
    ok = a == b and len(a) == FRAMES * 2 * 4 and abs(clip - 0.200) < 0.01 and abs(tone - 0.2026) < 0.01
    print(f"test-wasm: {'PASS' if ok else 'FAIL'} ({FRAMES} frames, {'identical' if a == b else 'DIFFERENT'})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
