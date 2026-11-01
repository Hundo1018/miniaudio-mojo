#!/usr/bin/env python3
"""Build build/libma_shim.a: the same sources as `pixi run build-shim`, as a static archive.

Static link mode (`mojo build -D MINIAUDIO_LINK=static -Xlinker build/libma_shim.a ...`)
resolves every `ma_shim_*` call against this archive instead of dlopening libma_shim.so.
Objects are rebuilt only when their source or a header is newer.
"""

import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "build" / "static"
ARCHIVE = ROOT / "build" / "libma_shim.a"
SOURCES = sorted((ROOT / "src" / "native").glob("ma_shim*.c")) + [ROOT / "vendor" / "miniaudio" / "miniaudio.c"]
HEADERS = sorted((ROOT / "src" / "native").glob("*.h")) + [ROOT / "vendor" / "miniaudio" / "miniaudio.h"]
CFLAGS = ["-O2", "-fPIC", "-I" + str(ROOT / "vendor" / "miniaudio"), "-I" + str(ROOT / "src" / "native")]


def compile_one(src: Path) -> tuple[Path, str]:
    obj = OUT_DIR / (src.stem + ".o")
    newest_input = max(p.stat().st_mtime for p in [src, *HEADERS])
    if obj.exists() and obj.stat().st_mtime >= newest_input:
        return obj, ""
    proc = subprocess.run(["cc", *CFLAGS, "-c", str(src), "-o", str(obj)], capture_output=True, text=True)
    return obj, proc.stderr if proc.returncode else ""


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor() as pool:
        results = list(pool.map(compile_one, SOURCES))
    errors = [err for _, err in results if err]
    if errors:
        print("\n".join(errors))
        return 1
    ARCHIVE.unlink(missing_ok=True)
    subprocess.run(["ar", "rcs", str(ARCHIVE), *(str(obj) for obj, _ in results)], check=True)
    print(f"build-shim-static: {ARCHIVE.relative_to(ROOT)} ({len(results)} objects)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
