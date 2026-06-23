#!/usr/bin/env bash
# shim_coverage.sh — build libma_shim_cov.so with gcov instrumentation,
# run the Mojo test suite against it, then check ma_shim.c line coverage.
#
# Exit 0 if coverage >= threshold; exit 1 otherwise.
#
# Usage: bash tools/shim_coverage.sh [line-threshold]
#   line-threshold  integer 0-100, default 95
#
set -euo pipefail

THRESHOLD="${1:-95}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_COV="$ROOT/build/coverage/shim"
COV_LIB="$BUILD_COV/libma_shim_cov.so"

echo "=== shim_coverage.sh (threshold=${THRESHOLD}%) ==="

# ---- 1. Build instrumented objects + .so (two-step for clean gcno names) ---
mkdir -p "$BUILD_COV"

echo "  Compiling ma_shim.c -> $BUILD_COV/ma_shim.o (with --coverage) ..."
cc -O0 -g --coverage -fPIC -c \
    -o "$BUILD_COV/ma_shim.o" \
    "$ROOT/src/native/ma_shim.c" \
    -I"$ROOT/vendor/miniaudio" \
    -I"$ROOT/src/native"

echo "  Compiling miniaudio.c -> $BUILD_COV/miniaudio.o ..."
cc -O0 -g --coverage -fPIC -c \
    -o "$BUILD_COV/miniaudio.o" \
    "$ROOT/vendor/miniaudio/miniaudio.c" \
    -I"$ROOT/vendor/miniaudio"

echo "  Linking $COV_LIB ..."
cc --coverage -shared \
    -o "$COV_LIB" \
    "$BUILD_COV/ma_shim.o" \
    "$BUILD_COV/miniaudio.o" \
    -lpthread -lm -ldl -latomic

echo "  Objects compiled; .gcno files in $BUILD_COV"
ls "$BUILD_COV/"*.gcno 2>/dev/null || echo "  (no .gcno yet)"

# ---- 2. Run Mojo test suite against instrumented library --------------------
echo "  Running Mojo tests against instrumented shim ..."
export MINIAUDIO_MOJO_LIB="$COV_LIB"
# .gcda files will land alongside .gcno files (same directory as the .o)
# because GCOV_PREFIX is NOT set — gcov writes next to the .gcno.

cd "$ROOT"
python3 tools/gen_test_wav.py 2>/dev/null || true

mojo run -I src -I tests tests/test_decoder_binding.mojo
mojo run -I src -I tests tests/test_decoder_api.mojo

# ---- 3. Verify .gcda files were written ------------------------------------
echo "  Checking for .gcda files ..."
if ! ls "$BUILD_COV/"*.gcda 2>/dev/null | grep -q .; then
    echo "  ERROR: no .gcda files in $BUILD_COV — test process may have crashed." >&2
    exit 1
fi
echo "  Found: $(ls "$BUILD_COV/"*.gcda | xargs basename -a | tr '\n' ' ')"

# ---- 4. Run gcov on ma_shim.c only -----------------------------------------
echo "  Running gcov on ma_shim.c ..."
cd "$BUILD_COV"
GCOV_OUT=$(gcov -b -c -o "$BUILD_COV" "$ROOT/src/native/ma_shim.c" 2>&1)
echo "$GCOV_OUT"

# ---- 5. Parse line coverage -------------------------------------------------
LINE_PCT=$(echo "$GCOV_OUT" | grep -oP "Lines executed:\K[0-9.]+" | head -1)

if [ -z "$LINE_PCT" ]; then
    GCOV_FILE="$BUILD_COV/ma_shim.c.gcov"
    if [ ! -f "$GCOV_FILE" ]; then
        # gcov may write to cwd
        GCOV_FILE="ma_shim.c.gcov"
    fi
    if [ -f "$GCOV_FILE" ]; then
        TOTAL=$(grep -cE "^[[:space:]]+[0-9#]+:" "$GCOV_FILE" || true)
        EXECUTED=$(grep -cE "^[[:space:]]+[0-9]+:" "$GCOV_FILE" || true)
        if [ "$TOTAL" -gt 0 ]; then
            LINE_PCT=$(python3 -c "print(f'{100.0*${EXECUTED}/${TOTAL}:.2f}')")
        fi
    fi
fi

if [ -z "$LINE_PCT" ]; then
    echo "ERROR: could not parse line coverage from gcov output." >&2
    exit 1
fi

LINE_INT=$(python3 -c "print(int(float('$LINE_PCT')))")

echo ""
echo "  ma_shim.c line coverage: ${LINE_PCT}%  (threshold: ${THRESHOLD}%)"

if [ "$LINE_INT" -lt "$THRESHOLD" ]; then
    echo "  FAIL — coverage ${LINE_PCT}% is below threshold ${THRESHOLD}%" >&2
    exit 1
fi

echo "  PASS — coverage ${LINE_PCT}% >= ${THRESHOLD}%"
