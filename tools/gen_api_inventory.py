#!/usr/bin/env python3
"""Parse vendor/miniaudio/miniaudio.h and generate the canonical API inventory.

Output:
  docs/api-inventory.json  -- machine-readable denominator (1,027 core functions)
  docs/api-inventory.md    -- human-readable summary table

Excluded: ma_dr_* and ma_stbvorbis_* (bundled third-party codecs).
"""

import re
import json
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
HEADER = ROOT / "vendor" / "miniaudio" / "miniaudio.h"
OUT_JSON = ROOT / "docs" / "api-inventory.json"
OUT_MD = ROOT / "docs" / "api-inventory.md"

EXCLUDE_PREFIXES = ("ma_dr_", "ma_stbvorbis_")

# Family detection: ordered so more-specific prefixes match first.
FAMILY_PREFIXES = [
    ("ma_sound_group_", "sound_group"),
    ("ma_resource_manager_", "resource_manager"),
    ("ma_node_graph_", "node_graph"),
    ("ma_data_source_", "data_source"),
    ("ma_channel_converter_", "channel_converter"),
    ("ma_data_converter_", "data_converter"),
    ("ma_linear_resampler_", "linear_resampler"),
    ("ma_resampler_", "resampler"),
    ("ma_lpf2_", "lpf"),
    ("ma_lpf1_", "lpf"),
    ("ma_lpf_", "lpf"),
    ("ma_hpf2_", "hpf"),
    ("ma_hpf1_", "hpf"),
    ("ma_hpf_", "hpf"),
    ("ma_bpf2_", "bpf"),
    ("ma_bpf1_", "bpf"),
    ("ma_bpf_", "bpf"),
    ("ma_peak2_", "peak_eq"),
    ("ma_peak_", "peak_eq"),
    ("ma_notch2_", "notch"),
    ("ma_notch_", "notch"),
    ("ma_loshelf2_", "loshelf"),
    ("ma_loshelf_", "loshelf"),
    ("ma_hishelf2_", "hishelf"),
    ("ma_hishelf_", "hishelf"),
    ("ma_biquad_", "biquad"),
    ("ma_delay_node_", "delay_node"),
    ("ma_splitter_node_", "splitter_node"),
    ("ma_lpf_node_", "lpf_node"),
    ("ma_hpf_node_", "hpf_node"),
    ("ma_notch_node_", "notch_node"),
    ("ma_peak_node_", "peak_node"),
    ("ma_loshelf_node_", "loshelf_node"),
    ("ma_hishelf_node_", "hishelf_node"),
    ("ma_node_", "node"),
    ("ma_spatializer_listener_", "spatializer"),
    ("ma_spatializer_", "spatializer"),
    ("ma_engine_node_", "engine"),
    ("ma_engine_", "engine"),
    ("ma_sound_", "sound"),
    ("ma_device_", "device"),
    ("ma_context_", "context"),
    ("ma_decoder_", "decoder"),
    ("ma_encoder_", "encoder"),
    ("ma_waveform_", "waveform"),
    ("ma_noise_", "noise"),
    ("ma_pcm_rb_", "ring_buffer"),
    ("ma_rb_", "ring_buffer"),
    ("ma_vfs_", "vfs"),
    ("ma_default_vfs_", "vfs"),
    ("ma_log_", "log"),
    ("ma_job_queue_", "job_queue"),
    ("ma_job_", "job_queue"),
    ("ma_mutex_", "sync"),
    ("ma_event_", "sync"),
    ("ma_semaphore_", "sync"),
    ("ma_fence_", "sync"),
    ("ma_async_notification_", "sync"),
    ("ma_slot_allocator_", "slot_allocator"),
    ("ma_resource_manager_pipeline_stage_notification_", "resource_manager"),
    ("ma_paged_audio_buffer_", "paged_audio_buffer"),
    ("ma_audio_buffer_", "audio_buffer"),
    ("ma_pcm_", "pcm_convert"),
    ("ma_convert_", "pcm_convert"),
    ("ma_copy_", "pcm_convert"),
    ("ma_blend_", "pcm_convert"),
    ("ma_volume_", "pcm_convert"),
    ("ma_mix_", "pcm_convert"),
    ("ma_format_", "format_util"),
    ("ma_get_", "format_util"),
    ("ma_calculate_", "format_util"),
    ("ma_apply_", "format_util"),
    ("ma_clip_", "format_util"),
    ("ma_zero_", "format_util"),
    ("ma_", "core"),
]


def family_of(name: str) -> str:
    for prefix, fam in FAMILY_PREFIXES:
        if name.startswith(prefix):
            return fam
    return "core"


def parse_functions(header_text: str) -> list[dict]:
    """Extract MA_API function declarations, handling multi-line signatures."""
    functions = []
    seen = set()

    # Match MA_API ... ma_funcname( across single or multi-line declarations.
    # Strategy: find all MA_API positions, then grab the full declaration up to ';' or '{'.
    pattern = re.compile(r"\bMA_API\b([^;{]*?)\bma_([a-zA-Z0-9_]+)\s*\(", re.DOTALL)

    for m in pattern.finditer(header_text):
        func_name = "ma_" + m.group(2)

        # Skip bundled third-party
        if any(func_name.startswith(p) for p in EXCLUDE_PREFIXES):
            continue

        if func_name in seen:
            continue
        seen.add(func_name)

        functions.append({"name": func_name, "family": family_of(func_name)})

    return sorted(functions, key=lambda f: (f["family"], f["name"]))


def group_by_family(functions: list[dict]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for f in functions:
        groups.setdefault(f["family"], []).append(f["name"])
    return dict(sorted(groups.items()))


def write_json(groups: dict, functions: list[dict]) -> None:
    payload = {
        "total": len(functions),
        "excluded_prefixes": list(EXCLUDE_PREFIXES),
        "families": {fam: {"count": len(fns), "functions": fns} for fam, fns in groups.items()},
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"  wrote {OUT_JSON}  ({len(functions)} functions, {len(groups)} families)")


def write_md(groups: dict, total: int) -> None:
    lines = [
        "# miniaudio Public API Inventory",
        "",
        f"**Total core functions**: {total}  ",
        f"**Excluded**: `ma_dr_*` / `ma_stbvorbis_*` (bundled third-party codecs)",
        "",
        "Generated by `tools/gen_api_inventory.py`. Re-run after updating `vendor/miniaudio/`.",
        "",
        "| Family | Functions |",
        "|--------|-----------|",
    ]
    for fam, fns in groups.items():
        lines.append(f"| `{fam}` | {len(fns)} |")

    lines += ["", "## Functions by Family", ""]
    for fam, fns in groups.items():
        lines.append(f"### `{fam}` ({len(fns)})")
        lines.append("")
        for fn in fns:
            lines.append(f"- `{fn}`")
        lines.append("")

    OUT_MD.write_text("\n".join(lines))
    print(f"  wrote {OUT_MD}")


def main() -> None:
    if not HEADER.exists():
        print(f"ERROR: {HEADER} not found", file=sys.stderr)
        sys.exit(1)

    text = HEADER.read_text(encoding="utf-8", errors="replace")
    functions = parse_functions(text)
    groups = group_by_family(functions)

    total = len(functions)
    print(f"Parsed {total} core MA_API functions across {len(groups)} families.")

    write_json(groups, functions)
    write_md(groups, total)


if __name__ == "__main__":
    main()
