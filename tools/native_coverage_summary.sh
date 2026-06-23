#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/coverage/native}"
SUMMARY_TXT="$OUT_DIR/summary.txt"
GCOV_TXT="$OUT_DIR/gcov.txt"

if [[ -f "$SUMMARY_TXT" ]]; then
    cat "$SUMMARY_TXT"
    exit 0
fi

if [[ -f "$GCOV_TXT" ]]; then
    echo "gcovr summary not found; showing gcov fallback output"
    cat "$GCOV_TXT"
    exit 0
fi

echo "No coverage summary found in $OUT_DIR"
exit 1
