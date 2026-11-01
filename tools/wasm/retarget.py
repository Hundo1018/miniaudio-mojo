#!/usr/bin/env python3
"""Retarget Mojo's host LLVM IR to wasm64 for an external LLVM (>= 23).

    python3 -I tools/wasm/retarget.py in.ll out.ll

Mojo 1.2.0 cannot emit WebAssembly itself, but `mojo build --emit llvm` IR built
for a baseline x86-64 CPU is close to target-neutral. This swaps the triple and
datalayout, strips the x86 target-cpu / target-features attributes, and stubs
the two x86 MXCSR intrinsics (an FTZ/DAZ guard in the stdlib). Method and
findings: ludens-engine tools/wasm/poc (retarget.py, FINDINGS.md), 2026-11-01.
"""

import re
import sys

DATALAYOUT = "e-m:e-p:64:64-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20"


def main() -> int:
    src, dst = sys.argv[1], sys.argv[2]
    stubbed = 0
    with open(src) as fi, open(dst, "w") as fo:
        for line in fi:
            if line.startswith("target datalayout"):
                line = f'target datalayout = "{DATALAYOUT}"\n'
            elif line.startswith("target triple"):
                line = 'target triple = "wasm64-unknown-unknown"\n'
            elif line.startswith("attributes #"):
                line = re.sub(r'"target-(cpu|features)"="[^"]*"', "", line)
                line = re.sub(r"\{\s*\}", '{ "wasm-retargeted" }', line)
            m = re.match(r"\s*call void @llvm\.x86\.sse\.stmxcsr\(ptr (%\S+)\)", line)
            if m:
                line = f"  store i32 8064, ptr {m.group(1)}, align 4\n"  # default MXCSR
                stubbed += 1
            if "@llvm.x86.sse.ldmxcsr" in line or line.startswith("declare void @llvm.x86.sse.stmxcsr"):
                stubbed += 1
                continue
            fo.write(line)
    print(f"retarget: wasm64, {stubbed} x86 MXCSR sites stubbed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
