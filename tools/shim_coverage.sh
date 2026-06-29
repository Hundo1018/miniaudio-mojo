#!/usr/bin/env bash
# shim_coverage.sh — build an instrumented libma_shim_cov.so from ALL
# src/native/ma_shim*.c, run every tests/test_*.mojo against it, then check the
# AGGREGATE line coverage across the shim translation units.
#
# Exit 0 if coverage >= threshold; exit 1 otherwise.
#
# Usage: bash tools/shim_coverage.sh [line-threshold]   (default 95)
#
set -euo pipefail

THRESHOLD="${1:-95}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_COV="$ROOT/build/coverage/shim"
COV_LIB="$BUILD_COV/libma_shim_cov.so"

echo "=== shim_coverage.sh (threshold=${THRESHOLD}%) ==="

# ---- 1. Build instrumented objects + .so -----------------------------------
mkdir -p "$BUILD_COV"
rm -f "$BUILD_COV"/*.gcda "$BUILD_COV"/*.gcno "$BUILD_COV"/*.gcov 2>/dev/null || true

OBJS=()
for c in "$ROOT"/src/native/ma_shim*.c; do
    obj="$BUILD_COV/$(basename "${c%.c}").o"
    echo "  Compiling $(basename "$c") -> $(basename "$obj") (with --coverage) ..."
    cc -O0 -g --coverage -fPIC -c -o "$obj" "$c" \
        -I"$ROOT/vendor/miniaudio" -I"$ROOT/src/native"
    OBJS+=("$obj")
done

echo "  Compiling miniaudio.c -> miniaudio.o ..."
cc -O0 -g --coverage -fPIC -c -o "$BUILD_COV/miniaudio.o" \
    "$ROOT/vendor/miniaudio/miniaudio.c" -I"$ROOT/vendor/miniaudio"

echo "  Linking $COV_LIB ..."
cc --coverage -shared -o "$COV_LIB" \
    "${OBJS[@]}" "$BUILD_COV/miniaudio.o" \
    -lpthread -lm -ldl -latomic

# ---- 2. Run the full Mojo test suite against the instrumented library ------
echo "  Running Mojo tests against instrumented shim ..."
export MINIAUDIO_MOJO_LIB="$COV_LIB"
cd "$ROOT"
python3 tools/gen_test_wav.py 2>/dev/null || true

for t in tests/test_*.mojo; do
    echo "  -> $t"
    mojo run -I src -I tests "$t"
done

# ---- 3. Verify .gcda files were written ------------------------------------
if ! ls "$BUILD_COV/"*.gcda 2>/dev/null | grep -q .; then
    echo "  ERROR: no .gcda files in $BUILD_COV — a test process may have crashed." >&2
    exit 1
fi

# ---- 4. gcov each ma_shim*.c and aggregate line coverage -------------------
cd "$BUILD_COV"
for c in "$ROOT"/src/native/ma_shim*.c; do
    gcov -b -c -o "$BUILD_COV" "$c" >/dev/null 2>&1 || true
done

read -r EXECUTED TOTAL < <(python3 - "$BUILD_COV"/ma_shim*.c.gcov <<'PY'
import sys
ex = tot = 0
for path in sys.argv[1:]:
    for line in open(path):
        parts = line.split(":", 2)
        if len(parts) < 3:
            continue
        c = parts[0].strip()
        if c in ("-", ""):      # non-executable / header line
            continue
        tot += 1
        if c[0].isdigit():       # numeric count => executed (gcov uses ##### for 0)
            ex += 1
print(ex, tot)
PY
)

if [ -z "${TOTAL:-}" ] || [ "$TOTAL" -eq 0 ]; then
    echo "ERROR: could not parse aggregate line coverage from gcov output." >&2
    exit 1
fi

LINE_PCT=$(python3 -c "print(f'{100.0*${EXECUTED}/${TOTAL}:.2f}')")
LINE_INT=$(python3 -c "print(int(float('$LINE_PCT')))")

echo ""
echo "  shim aggregate line coverage: ${LINE_PCT}%  (${EXECUTED}/${TOTAL} lines, threshold: ${THRESHOLD}%)"

if [ "$LINE_INT" -lt "$THRESHOLD" ]; then
    echo "  FAIL — coverage ${LINE_PCT}% is below threshold ${THRESHOLD}%" >&2
    exit 1
fi

echo "  PASS — coverage ${LINE_PCT}% >= ${THRESHOLD}%"
