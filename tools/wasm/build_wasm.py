#!/usr/bin/env python3
"""Build a wasm64 module from a Mojo entry file that exports C-ABI functions.

    pixi run -e wasm python3 tools/wasm/build_wasm.py examples/web/audio.mojo \\
        -I examples/web -o build/wasm/audio.wasm --export 'web_*'

Mojo 1.2.0 has no WebAssembly target, so:
  1. mojo build --emit llvm -D MINIAUDIO_LINK=static --target-cpu x86-64   (host IR;
     static mode: every shim call is a plain `declare`, nothing is dlopened)
  2. tools/wasm/retarget.py                                (triple/datalayout swap)
  3. opt -O3, llc -O3 -mattr=...                            (LLVM >= 23, wasm64 object)
  4. clang --target=wasm64: miniaudio.c + the device-less shim files + musl
     math/string + tools/wasm/runtime.c (MA_NO_DEVICE_IO, MA_NO_THREADING)
  5. wasm-ld -mwasm64                                       (one module, no undefined
     symbols except the `env.host_*` imports runtime.c declares)

Needs the `wasm` pixi environment (clang / llc / opt / wasm-ld 23 on PATH) and the
`emsdk` one (emscripten, read for its wasm64 libc headers and musl sources only).
C objects are cached under build/wasm/obj and rebuilt when a source or header is newer.
"""

import argparse
import glob
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OBJ = ROOT / "build" / "wasm" / "obj"

# Shim files that need devices, contexts or threads are not part of this build.
SHIM_EXCLUDE = {"ma_shim_context.c", "ma_shim_sync.c"}
MA_DEFINES = ["-DMA_NO_DEVICE_IO", "-DMA_NO_THREADING", "-DMA_NO_RUNTIME_LINKING"]
# musl sources (src/<dir>/<name>.c) for what miniaudio and Mojo call.
MUSL = [
    "math/exp", "math/exp_data", "math/log", "math/log_data", "math/pow", "math/pow_data",
    "math/sin", "math/cos", "math/__sin", "math/__cos", "math/__rem_pio2", "math/__rem_pio2_large",
    "math/sinf", "math/cosf", "math/__sindf", "math/__cosdf", "math/__rem_pio2f",
    "math/sqrt", "math/sqrt_data", "math/sqrtf", "math/floor", "math/floorf", "math/ceil", "math/ceilf",
    "math/fabs", "math/fabsf", "math/scalbn", "math/scalbnf", "math/fmod", "math/fmodf", "math/fminf", "math/fmaxf", "math/fmin", "math/fmax",
    "math/__math_oflow", "math/__math_uflow", "math/__math_xflow", "math/__math_invalid",
    "math/__math_divzero", "math/__math_oflowf", "math/__math_uflowf", "math/__math_xflowf",
    "math/__math_invalidf", "math/__math_divzerof",
    "string/memcpy", "string/memmove", "string/memset", "string/memcmp", "string/strlen",
    "string/strcmp", "string/strncmp", "string/strncpy", "string/strcpy", "string/strcasecmp",
    "string/wcslen", "ctype/tolower",
]
LLC_ATTRS = "+tail-call,+simd128,+bulk-memory,+nontrapping-fptoint,+sign-ext,+mutable-globals"
C_FEATURES = ["-mbulk-memory", "-mnontrapping-fptoint", "-msign-ext", "-mmutable-globals"]


def tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        sys.exit(f"build_wasm: `{name}` not on PATH; run inside `pixi run -e wasm ...`")
    return path


def emscripten_root() -> Path:
    override = os.environ.get("MA_WASM_EMSCRIPTEN")
    if override:
        return Path(override)
    hits = sorted(glob.glob(str(ROOT / ".pixi" / "envs" / "emsdk" / "lib" / "emscripten-*")))
    if not hits:
        sys.exit("build_wasm: emscripten not found: run `pixi install -e emsdk` (or set MA_WASM_EMSCRIPTEN)")
    return Path(hits[-1])


def run(cmd: list[str], what: str) -> None:
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"build_wasm: {what} failed ({cmd[0]})\n" + (proc.stdout + proc.stderr)[-4000:])


def c_objects(clang: str, em: Path) -> list[Path]:
    sysroot = em / "cache" / "sysroot"
    musl = em / "system" / "lib" / "libc" / "musl"
    base = [clang, "--target=wasm64-unknown-emscripten", f"--sysroot={sysroot}", "-O2",
            "-ffp-contract=off", *C_FEATURES, "-w"]
    jobs: list[tuple[Path, list[str], list[Path]]] = []
    headers = list((ROOT / "src" / "native").glob("*.h")) + [ROOT / "vendor" / "miniaudio" / "miniaudio.h"]
    ma_flags = [*MA_DEFINES, "-I" + str(ROOT / "vendor" / "miniaudio"), "-I" + str(ROOT / "src" / "native")]
    sources = [ROOT / "vendor" / "miniaudio" / "miniaudio.c"] + [
        p for p in sorted((ROOT / "src" / "native").glob("ma_shim*.c")) if p.name not in SHIM_EXCLUDE
    ]
    for src in sources:
        jobs.append((src, ma_flags, headers))
    jobs.append((ROOT / "tools" / "wasm" / "runtime.c", ["-ffreestanding", "-nostdlib"], []))
    musl_flags = ["-I" + str(musl / "src" / "include"), "-I" + str(musl / "src" / "internal"),
                  "-I" + str(musl / "arch" / "emscripten"), "-I" + str(musl / "arch" / "generic"),
                  "-D_XOPEN_SOURCE=700", "-fno-builtin"]
    for rel in MUSL:
        jobs.append((musl / "src" / f"{rel}.c", musl_flags, []))

    def build(job):
        src, flags, deps = job
        obj = OBJ / (src.parent.name + "__" + src.stem + ".o")
        newest = max(p.stat().st_mtime for p in [src, *deps])
        if not (obj.exists() and obj.stat().st_mtime >= newest):
            run([*base, *flags, "-c", str(src), "-o", str(obj)], f"compiling {src.name}")
        return obj

    OBJ.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor() as pool:
        return list(pool.map(build, jobs))


def mojo_object(entry: Path, includes: list[str], out_dir: Path) -> Path:
    ll = out_dir / (entry.stem + ".ll")
    wasm_ll = out_dir / (entry.stem + ".wasm64.ll")
    opt_ll = out_dir / (entry.stem + ".opt.bc")
    obj = out_dir / (entry.stem + ".mojo.o")
    inc = [x for d in ["src", *includes] for x in ("-I", d)]
    run(["mojo", "build", "--emit", "llvm", "-D", "MINIAUDIO_LINK=static", "--target-cpu", "x86-64",
         *inc, str(entry), "-o", str(ll)], "mojo --emit llvm")
    run([sys.executable, "-I", str(ROOT / "tools" / "wasm" / "retarget.py"), str(ll), str(wasm_ll)], "retarget")
    names = "-non-global-value-max-name-size=1000000"  # Mojo's mangled local names are long
    run([tool("opt"), names, "-O3", str(wasm_ll), "-o", str(opt_ll)], "opt -O3")
    run([tool("llc"), names, "-O3", "-filetype=obj", f"-mattr={LLC_ATTRS}", str(opt_ll), "-o", str(obj)], "llc")
    return obj


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("entry")
    ap.add_argument("-I", dest="includes", action="append", default=[])
    ap.add_argument("-o", dest="out", required=True)
    ap.add_argument("--export", action="append", default=[], help="symbol or glob, e.g. 'web_*'")
    args = ap.parse_args()

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    clang, em = tool("clang"), emscripten_root()
    with ThreadPoolExecutor(2) as pool:
        c_future = pool.submit(c_objects, clang, em)
        mojo_obj = mojo_object(ROOT / args.entry, args.includes, out.parent)
        c_objs = c_future.result()

    exports = []
    for e in args.export + ["rt_*"]:
        exports.append(f"--export-if-defined={e}" if "*" not in e else f"--export={e}")
    # wasm-ld has no export globs: expand them against the Mojo object's symbols.
    names = subprocess.run([tool("llvm-nm"), "--defined-only", "-j", str(mojo_obj), *map(str, c_objs)],
                           capture_output=True, text=True).stdout.split()
    flat = []
    for e in args.export + ["rt_*"]:
        if "*" in e:
            prefix = e.rstrip("*")
            flat += [f"--export={n}" for n in sorted(set(names)) if n.startswith(prefix)]
        else:
            flat.append(f"--export={e}")
    run([tool("wasm-ld"), "-mwasm64", "--no-entry", "--export-memory", "--gc-sections", "-O2",
         "--stack-first", "-z", "stack-size=1048576", *flat,
         str(mojo_obj), *map(str, c_objs), "-o", str(out)], "wasm-ld")
    print(f"build_wasm: {out.relative_to(ROOT) if out.is_absolute() else out} "
          f"({out.stat().st_size:,} bytes, {len(flat)} exports)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
