#!/usr/bin/env python3
"""EnumLike value guard — pixi run check-enum-values.

Every `EnumLike` struct in src/miniaudio mirrors a miniaudio C enum: its case
index is its discriminant, so case `i` must be `Self(i)` and must equal the C
enumerator of the same name. This script reads the cases straight from the Mojo
source, writes one `_Static_assert` per case, and has the C compiler check them
against vendor/miniaudio/miniaudio.h (syntax-only, nothing is linked).

Exits non-zero when a case is out of order, has no C enumerator, or differs from
it; when `_enum_case_names` (what `match` and print use) disagrees with the
cases; and when an EnumLike struct is missing from C_ENUMS below.
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).parent.parent
SRC_MOJO_DIR = ROOT / "src" / "miniaudio"

# Mojo struct -> C enumerator prefix (the C enum type name, minus `ma_` quirks).
C_ENUMS = {
    "AttenuationModel": "ma_attenuation_model",
    "Positioning": "ma_positioning",
    "PanMode": "ma_pan_mode",
    "ResampleAlgorithm": "ma_resample_algorithm",
    "ChannelMixMode": "ma_channel_mix_mode",
    "EncodingFormat": "ma_encoding_format",
    "SampleFormat": "ma_format",
}

STRUCT_RE = re.compile(r"^struct (\w+)\(([^)]*)\):\n(.*?)(?=^\S)", re.M | re.S)
CASE_RE = re.compile(r"^    comptime ([A-Z][A-Z0-9_]*) = Self\((\d+)\)$", re.M)
NAMES_RE = re.compile(r"_enum_case_names = ParameterList\.of\[(.*?)\]\.values", re.S)


def enum_like_structs():
    for path in sorted(SRC_MOJO_DIR.glob("*.mojo")):
        for m in STRUCT_RE.finditer(path.read_text()):
            if "EnumLike" in m.group(2).split(", "):
                body = m.group(3)
                cases = [(n, int(v)) for n, v in CASE_RE.findall(body)]
                names = NAMES_RE.search(body)
                names = re.findall(r'"(\w+)"\.value', names.group(1)) if names else []
                yield path.relative_to(ROOT), m.group(1), cases, names


def main():
    errors = []
    asserts = []
    count = 0
    for path, name, cases, names in enum_like_structs():
        prefix = C_ENUMS.get(name)
        if prefix is None:
            errors.append(f"{path}: {name} is EnumLike but has no entry in C_ENUMS")
            continue
        if not cases:
            errors.append(f"{path}: {name} declares no `comptime NAME = Self(N)` cases")
        if names != [case for case, _ in cases]:
            errors.append(f"{path}: {name}._enum_case_names {names} != its cases in order")
        for index, (case, code) in enumerate(cases):
            if code != index:
                errors.append(f"{path}: {name}.{case} is Self({code}) but is case {index}")
            c_name = f"{prefix}_{case.lower()}"
            asserts.append(
                f'_Static_assert({c_name} == {code}, "{path}: {name}.{case} != {c_name}");'
            )
            count += 1

    src = '#include "miniaudio.h"\n\n' + "\n".join(asserts) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".c") as f:
        f.write(src)
        f.flush()
        proc = subprocess.run(
            ["cc", "-fsyntax-only", "-w", f.name, f"-I{ROOT / 'vendor' / 'miniaudio'}"],
            capture_output=True,
            text=True,
        )
    if proc.returncode != 0:
        errors.append("C compiler rejected the enum values:\n" + proc.stderr.strip())

    if errors:
        print("\n".join(errors))
        print(f"check-enum-values: FAIL ({len(errors)} problem(s))")
        return 1
    print(f"check-enum-values: PASS ({count} cases in {len(C_ENUMS)} EnumLike types match miniaudio.h)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
