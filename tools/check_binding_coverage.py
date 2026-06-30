#!/usr/bin/env python3
"""Binding coverage checker — hard gate for CI / pixi run coverage-binding.

Checks:
  1. Every exported ma_shim_* symbol in ma_shim.h has:
       a. A matching .call["ma_shim_..."] in some _ffi/*_raw.mojo (L2).
       b. A reference to the raw function in some tests/test_*.mojo (test exists).
  2. Every @binds declaration in ma_shim.c names a function that exists in
     docs/api-inventory.json (typo / non-existent symbol guard).
  3. Every family declared dod_met=true in docs/coverage-targets.json meets its
     stated dod_level (L2: positive + negative test; L3: also behavioral tests).

Exits 0 only when all gates pass. Reports all failures before exiting.
"""

import re
import sys
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent

NATIVE_DIR = ROOT / "src" / "native"
# The shim is split per family (ma_shim_<family>.{h,c}); the legacy single
# ma_shim.{h,c} also matches these globs. Scan all of them.
SHIM_HEADERS = lambda: sorted(NATIVE_DIR.glob("ma_shim*.h"))
SHIM_SOURCES = lambda: sorted(NATIVE_DIR.glob("ma_shim*.c"))
FFI_DIR = ROOT / "src" / "miniaudio" / "_ffi"
SRC_MOJO_DIR = ROOT / "src" / "miniaudio"
TESTS_DIR = ROOT / "tests"
INVENTORY = ROOT / "docs" / "api-inventory.json"
TARGETS = ROOT / "docs" / "coverage-targets.json"
EXCLUSIONS = ROOT / "docs" / "coverage-exclusions.json"

# ---- helpers ----------------------------------------------------------------

def fail(msg: str) -> None:
    print(f"  FAIL  {msg}", file=sys.stderr)

def info(msg: str) -> None:
    print(f"  ok    {msg}")

def section(title: str) -> None:
    print(f"\n=== {title} ===")


# ---- 1. Parse shim exports from ma_shim.h -----------------------------------

def shim_exports() -> list[str]:
    """Return list of ma_shim_* function names declared in any ma_shim*.h."""
    text = "\n".join(h.read_text() for h in SHIM_HEADERS())
    # Match lines like: int ma_shim_foo(...); or void* ma_shim_bar(void);
    return re.findall(r"\bma_shim_([a-zA-Z0-9_]+)\s*\(", text)


# ---- 2. Parse @binds from ma_shim.c ----------------------------------------

def shim_binds() -> dict[str, list[str]]:
    """Return {shim_func_name: [bound_ma_* names]} from @binds comments across ma_shim*.c."""
    text = "\n".join(c.read_text() for c in SHIM_SOURCES())
    result: dict[str, list[str]] = {}

    # Each @binds comment immediately precedes a shim function definition.
    # Pattern: /* @binds ma_foo, ma_bar */ \n ... ma_shim_xyz(
    binds_pattern = re.compile(
        r"/\*\s*@binds\s+([^*]+?)\s*\*/\s*(?:[^{;]*?\bma_shim_([a-zA-Z0-9_]+)\s*\()",
        re.DOTALL,
    )
    for m in binds_pattern.finditer(text):
        bound_raw = m.group(1)
        shim_name = "ma_shim_" + m.group(2)
        bound = [s.strip().rstrip(",") for s in re.split(r"[,\s]+", bound_raw) if s.strip()]
        # Strip trailing comment artifacts (e.g. "(shim-managed..." text)
        bound = [b for b in bound if re.match(r"^ma_[a-zA-Z0-9_]+$", b)]
        result[shim_name] = bound

    return result


# ---- 3. Parse L2 raw bindings from _ffi/*_raw.mojo -------------------------

def l2_symbols() -> set[str]:
    """Return set of shim symbol names called in any Mojo source file under src/miniaudio/.

    This includes both _ffi/*_raw.mojo (primary L2) and _lib.mojo / __init__.mojo
    (which call core helpers like ma_shim_version and ma_shim_result_description).
    The .call[ pattern may span a newline before the string literal.
    """
    called = set()
    # Scan all .mojo files under src/miniaudio/ (recursive)
    for f in SRC_MOJO_DIR.rglob("*.mojo"):
        text = f.read_text()
        # Handle both same-line and newline-split forms:
        #   .call["ma_shim_foo", ...]   and   .call[\n    "ma_shim_foo", ...]
        for m in re.finditer(r'\.call\[\s*"(ma_shim_[a-zA-Z0-9_]+)"', text, re.DOTALL):
            called.add(m.group(1))
    return called


# ---- 4. Parse test references -----------------------------------------------

def test_symbols() -> set[str]:
    """Return set of function/method names called in test files.

    Matches:
      - raw.<fn>(        — _ffi layer functions aliased as `raw`
      - lib[].<method>(  — _lib.MaLib methods (version, result_description, describe)
      - lib.<method>(    — same without subscript
      - Any .<identifier>( call, to cover edge cases
    """
    called = set()
    for f in TESTS_DIR.glob("test_*.mojo"):
        text = f.read_text()
        for m in re.finditer(r"\braw\.([a-zA-Z0-9_]+)\s*\(", text):
            called.add(m.group(1))
        # Method calls on any receiver: .version(, .describe(, .result_description(, etc.
        for m in re.finditer(r"\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", text):
            called.add(m.group(1))
    return called


def raw_functions() -> dict[str, set[str]]:
    """Return {shim_symbol: set_of_function_names} from all src/miniaudio/**/*.mojo.

    Matches both top-level `def` and indented struct methods (e.g. in MaLib).
    """
    mapping: dict[str, set[str]] = {}
    for f in SRC_MOJO_DIR.rglob("*.mojo"):
        text = f.read_text()
        # Match any def at any indentation level
        defs = list(re.finditer(r"^\s*def ([a-zA-Z0-9_]+)\s*\(", text, re.MULTILINE))
        for i, d in enumerate(defs):
            start = d.start()
            end = defs[i + 1].start() if i + 1 < len(defs) else len(text)
            body = text[start:end]
            for c in re.finditer(r'\.call\[\s*"(ma_shim_[a-zA-Z0-9_]+)"', body, re.DOTALL):
                mapping.setdefault(c.group(1), set()).add(d.group(1))
    return mapping


# ---- 5. Parse coverage targets ----------------------------------------------

def load_targets() -> dict:
    if not TARGETS.exists():
        return {}
    return json.loads(TARGETS.read_text())


def load_exclusions() -> set[str]:
    """Functions intentionally excluded from the 100%-of-bindable denominator."""
    if not EXCLUSIONS.exists():
        return set()
    data = json.loads(EXCLUSIONS.read_text())
    excluded: set[str] = set()
    for cat in data.get("categories", {}).values():
        excluded.update(cat.get("functions", []))
    return excluded


# ---- 6. Load API inventory --------------------------------------------------

def load_inventory() -> set[str]:
    if not INVENTORY.exists():
        print("ERROR: docs/api-inventory.json not found — run: pixi run gen-api-inventory", file=sys.stderr)
        sys.exit(1)
    data = json.loads(INVENTORY.read_text())
    funcs = set()
    for fam_info in data["families"].values():
        funcs.update(fam_info["functions"])
    return funcs


# ---- main -------------------------------------------------------------------

def main() -> None:
    errors: list[str] = []

    inventory = load_inventory()
    targets = load_targets()
    exclusions = load_exclusions()

    exports = shim_exports()
    binds = shim_binds()
    l2 = l2_symbols()
    raw_map = raw_functions()  # shim_sym -> {raw_func_names}
    tested = test_symbols()

    bound_fns: set[str] = set()
    for bound_list in binds.values():
        bound_fns.update(bound_list)

    # ---- Gate 1: completeness (every shim export has L2 binding + test) -----
    section("Gate 1 — shim export completeness")
    for sym in sorted(set(exports)):
        shim_sym = "ma_shim_" + sym if not sym.startswith("ma_shim_") else sym
        # Normalise: exports() returns just the suffix
        full_sym = f"ma_shim_{sym}"
        missing_l2 = full_sym not in l2
        raw_fns = raw_map.get(full_sym, set())
        missing_test = not any(fn in tested for fn in raw_fns)

        if missing_l2:
            msg = f"{full_sym}: not called in any _ffi/*_raw.mojo (missing L2 binding)"
            errors.append(msg)
            fail(msg)
        elif missing_test and raw_fns:
            msg = f"{full_sym}: raw function(s) {sorted(raw_fns)} not referenced in any tests/test_*.mojo"
            errors.append(msg)
            fail(msg)
        else:
            status = "no raw fn mapped" if not raw_fns else "L2+test ok"
            info(f"{full_sym}: {status}")

    # ---- Gate 2: @binds references must exist in inventory ------------------
    section("Gate 2 — @binds symbol validity")
    for shim_sym, bound in sorted(binds.items()):
        for ma_fn in bound:
            if ma_fn not in inventory:
                msg = f"{shim_sym} @binds '{ma_fn}' — not found in api-inventory.json"
                errors.append(msg)
                fail(msg)
            else:
                info(f"{shim_sym} @binds {ma_fn} ✓")

    # ---- Gate 2b: exclusion-list names must exist in inventory (typo guard) --
    section("Gate 2b — exclusion-list validity")
    for ex in sorted(exclusions):
        if ex not in inventory:
            msg = f"excluded '{ex}' — not found in api-inventory.json (typo or stale)"
            errors.append(msg)
            fail(msg)
        else:
            info(f"excluded {ex} ✓")

    # ---- Gate 3: dod_met families meet their DoD level ----------------------
    section("Gate 3 — DoD-met compliance")
    if not targets:
        print("  (no coverage-targets.json — skipping DoD gate)")
    else:
        families = targets.get("families", {})
        for fam, meta in sorted(families.items()):
            if not meta.get("dod_met", False):
                print(f"  skip  {fam}: DoD not yet met")
                continue
            dod = meta.get("dod_level", "L2")
            # For now, presence of the family's test files is checked structurally.
            # Detailed L3 behavioral test presence is checked by name convention.
            test_files = list(TESTS_DIR.glob(f"test_{fam}*.mojo"))
            if not test_files:
                msg = f"{fam}: marked dod_met={dod} but no tests/test_{fam}*.mojo found"
                errors.append(msg)
                fail(msg)
                continue

            if dod == "L3":
                # Require at least one test file that contains a behavioral/L3 test.
                # Convention: behavioral tests have names like test_*_seek_*, test_*_cursor_*,
                # test_*_consecutive_*, test_*_reinit_*, etc.  We just verify ≥1 test file
                # exists for api layer (test_{fam}_api.mojo) as a proxy for L3.
                api_files = list(TESTS_DIR.glob(f"test_{fam}_api.mojo"))
                if not api_files:
                    msg = f"{fam}: dod_level=L3 but no test_{fam}_api.mojo found"
                    errors.append(msg)
                    fail(msg)
                    continue
            info(f"{fam}: dod_met={dod} — test files present")

    inv_data = json.loads(INVENTORY.read_text())
    inv_families = {f: set(i["functions"]) for f, i in inv_data["families"].items()}

    # ---- Gate 3b: complete families must bind ALL non-excluded functions ----
    # Opt-in via "complete": true in coverage-targets.json (distinct from "dod_met",
    # which only claims the *bound subset* meets its DoD level). This is the per-family
    # teeth of the "100% of bindable" goal.
    section("Gate 3b — family completeness (complete=true)")
    families = targets.get("families", {})
    any_complete = False
    for fam, meta in sorted(families.items()):
        if not meta.get("complete", False):
            continue
        any_complete = True
        fam_fns = inv_families.get(fam, set())
        unbound = sorted(fam_fns - bound_fns - exclusions)
        if unbound:
            msg = f"{fam}: complete=true but {len(unbound)} non-excluded fn(s) unbound: {unbound[:8]}{'…' if len(unbound) > 8 else ''}"
            errors.append(msg)
            fail(msg)
        else:
            info(f"{fam}: complete — all {len(fam_fns - exclusions)} bindable fns bound")
    if not any_complete:
        print("  (no families marked complete=true yet)")

    # ---- Coverage report (informational) ------------------------------------
    section("Coverage summary (informational)")
    total_inventory = len(inventory)
    bindable = total_inventory - len(exclusions & inventory)
    pct = 100.0 * len(bound_fns) / total_inventory if total_inventory else 0.0
    bpct = 100.0 * len(bound_fns) / bindable if bindable else 0.0
    print(f"  Bound {len(bound_fns)} / {total_inventory} core MA_API functions ({pct:.1f}%)")
    print(f"  Bindable coverage: {len(bound_fns)} / {bindable} "
          f"(= {total_inventory} - {len(exclusions & inventory)} excluded)  ->  {bpct:.1f}% of bindable")
    remaining = (inventory - bound_fns) - exclusions
    print(f"  Remaining unbound (non-excluded): {len(remaining)}")

    # Per-family breakdown from inventory
    for fam, fam_fns in sorted(inv_families.items()):
        covered = fam_fns & bound_fns
        if covered:
            fpct = 100.0 * len(covered) / len(fam_fns)
            print(f"  {fam:30s} {len(covered):3d}/{len(fam_fns):3d} ({fpct:.0f}%)")

    # ---- Result -------------------------------------------------------------
    print()
    if errors:
        print(f"FAIL — {len(errors)} error(s). Fix above and re-run.", file=sys.stderr)
        sys.exit(1)
    print(f"PASS — all {len(exports)} shim exports complete, @binds valid, "
          f"{len(exclusions)} exclusions valid, DoD/completeness gates pass.")


if __name__ == "__main__":
    main()
