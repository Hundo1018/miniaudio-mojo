#!/usr/bin/env python3
"""Build and run every tests/test_*.mojo in one link mode.

    python3 tools/run_tests.py --link static            # pixi run test-static
    python3 tools/run_tests.py --link dynamic test_noise_api test_wav_api

Static mode builds each test with `-D MINIAUDIO_LINK=static` against build/libma_shim.a
(see tools/build_shim_static.py), so the binary contains the shim and dlopens nothing.
Tests are built in parallel and run one at a time from the repo root (they use
relative asset paths). Prints one line per suite and a summary; exits non-zero if any
suite fails to build, crashes or has a failing test.
"""

import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIN_DIR = ROOT / "build" / "test_bin"
SUMMARY_RE = re.compile(r"(\d+) tests run: (\d+) passed , (\d+) failed")
STATIC_LIBS = ["-lpthread", "-lm", "-ldl", "-latomic"]


def build(test: Path, link: str) -> tuple[Path, Path, str]:
    exe = BIN_DIR / link / test.stem
    cmd = ["mojo", "build", "-I", "src", "-I", "tests", str(test), "-o", str(exe)]
    if link == "static":
        cmd[2:2] = ["-D", "MINIAUDIO_LINK=static", "-Xlinker", str(ROOT / "build" / "libma_shim.a")]
        for lib in STATIC_LIBS:
            cmd += ["-Xlinker", lib]
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    return test, exe, "" if proc.returncode == 0 else (proc.stdout + proc.stderr)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", choices=["static", "dynamic"], required=True)
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("tests", nargs="*", help="test file stems; default: all tests/test_*.mojo")
    args = parser.parse_args()

    tests = [ROOT / "tests" / f"{t}.mojo" for t in args.tests] or sorted((ROOT / "tests").glob("test_*.mojo"))
    (BIN_DIR / args.link).mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(args.jobs) as pool:
        built = list(pool.map(lambda t: build(t, args.link), tests))

    env = dict(os.environ)
    if args.link == "static":
        env.pop("MINIAUDIO_MOJO_LIB", None)  # nothing is loaded; make sure nothing could be
    failed, total_tests, total_passed = [], 0, 0
    for test, exe, build_err in built:
        if build_err:
            failed.append(test.stem)
            print(f"BUILD FAIL {test.stem}\n{build_err[-2000:]}")
            continue
        proc = subprocess.run([str(exe)], cwd=ROOT, capture_output=True, text=True, env=env)
        out = proc.stdout + proc.stderr
        m = SUMMARY_RE.search(out)
        ok = proc.returncode == 0 and m is not None and m.group(3) == "0"
        if m:
            total_tests += int(m.group(1))
            total_passed += int(m.group(2))
        print(f"{'ok  ' if ok else 'FAIL'} {test.stem}: {m.group(0) if m else f'exit {proc.returncode}, no summary'}")
        if not ok:
            failed.append(test.stem)
            fails = [line for line in out.splitlines() if "FAIL" in line or "error" in line.lower()]
            print("\n".join(fails[:20]) or out[-2000:])
    print(
        f"run_tests --link {args.link}: {len(tests) - len(failed)}/{len(tests)} suites ok, "
        f"{total_passed}/{total_tests} tests passed"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
