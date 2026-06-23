#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${1:-build/coverage/native}"
OBJ_DIR="$OUT_DIR/obj"
BIN_PATH="$OUT_DIR/native_smoke_cov"

rm -rf "$OUT_DIR"
mkdir -p "$OBJ_DIR"

CC_BIN="${CC:-cc}"
CFLAGS_COMMON="-O0 -g --coverage -fprofile-arcs -ftest-coverage -fPIC"
INCLUDE_FLAGS="-Ivendor/miniaudio -Isrc/native"
LINK_FLAGS="--coverage -lpthread -lm -ldl -latomic"

"$CC_BIN" $CFLAGS_COMMON $INCLUDE_FLAGS -c src/native/miniaudio_shim.c -o "$OBJ_DIR/miniaudio_shim.o"
"$CC_BIN" $CFLAGS_COMMON $INCLUDE_FLAGS -c vendor/miniaudio/miniaudio.c -o "$OBJ_DIR/miniaudio_vendor.o"
"$CC_BIN" $CFLAGS_COMMON $INCLUDE_FLAGS -c examples/native_smoke.c -o "$OBJ_DIR/native_smoke.o"
"$CC_BIN" "$OBJ_DIR/native_smoke.o" "$OBJ_DIR/miniaudio_shim.o" "$OBJ_DIR/miniaudio_vendor.o" -o "$BIN_PATH" $LINK_FLAGS

MMJ_NATIVE_SKIP_PLAYBACK=1 MMJ_NATIVE_RUN_SUITE=1 "$BIN_PATH"

if command -v gcovr >/dev/null 2>&1; then
    gcovr \
        --root . \
        --object-directory "$OBJ_DIR" \
        --filter '^src/native/' \
        --exclude '^vendor/' \
        --print-summary \
        --txt "$OUT_DIR/summary.txt" \
        --json-summary "$OUT_DIR/summary.json" \
        --html-details "$OUT_DIR/index.html"

    echo "Coverage summary written to: $OUT_DIR/summary.txt"
    echo "Coverage json summary written to: $OUT_DIR/summary.json"
    echo "Coverage html report written to: $OUT_DIR/index.html"
    exit 0
fi

if command -v gcov >/dev/null 2>&1; then
    gcov -b -c -o "$OBJ_DIR" src/native/miniaudio_shim.c > "$OUT_DIR/gcov.txt"
    echo "gcovr not found; fallback report written to: $OUT_DIR/gcov.txt"
    exit 0
fi

echo "Neither gcovr nor gcov is available. Please install one coverage tool and rerun."
exit 1
