#!/usr/bin/env python3
"""Export 7 standard-aspect-ratio (16:9 and 1:1) piece sheets directly from Valentina v2's
calibrated live PNGs for AI mask regeneration (ID, Normal/Depth, ILM).

Outputs under:
  sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/06_piece_mask_regen/
    - inputs/              (clean pure-white #FFFFFF sheets for ID & ILM)
    - inputs_normal/       (clean neutral #8080FF sheets for tangent-space Normals)
    - guides/              (labeled sheets for human reference only)
    - outputs_id/          (drop AI ID mask results here)
    - outputs_normal/      (drop AI Normal mask results here)
    - outputs_ilm/         (drop AI ILM mask results here)
    - piece_sheets_manifest.json
    - PROMPT_A_ID_MASK.md / PROMPT_B_NORMAL_DEPTH.md / PROMPT_C_ILM_MASK.md
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from build_valentina_v2_rig_assets import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402
from rig_v2_lib.piece_mask_prompts import (  # noqa: E402
    build_prompt_a_id_mask,
    build_prompt_b_normal_depth,
    build_prompt_c_ilm_mask,
    build_prompt_d_ink_lineart,
)

BASE_5_VIEWS: list[str] = ["s", "se", "e", "ne", "n"]
WORK_SUBDIR = "06_piece_mask_regen"

# Standard aspect-ratio canvases
SIZE_16X9 = (2560, 1440)  # Exact 16:9
SIZE_1X1 = (2048, 2048)   # Exact 1:1

BG_WHITE_BGR = (255, 255, 255)
BG_NORMAL_BGR = (255, 128, 128)  # RGB #8080FF -> BGR (255, 128, 128)


def _piece_specs(assets_dir: Path) -> list[dict]:
    """Define the 7 standard-aspect-ratio sheets covering 100% of Valentina v2 base pieces + 8 heads."""
    return [
        {
            "sheet_name": "01_body_core_5dir_16x9",
            "aspect": "16:9",
            "size": SIZE_16X9,
            "rows": 1,
            "cols": 5,
            "items": [
                {"kind": "body", "view": v, "part": "body_core", "label": f"{v.upper()} body_core",
                 "path": str(assets_dir / v / "parts_5" / "body_core.png")}
                for v in BASE_5_VIEWS
            ],
        },
        {
            "sheet_name": "02a_legs_R_5dir_16x9",
            "aspect": "16:9",
            "size": SIZE_16X9,
            "rows": 1,
            "cols": 5,
            "items": [
                {"kind": "body", "view": v, "part": "leg_r", "label": f"{v.upper()} leg_r",
                 "path": str(assets_dir / v / "parts_5" / "leg_r.png")}
                for v in BASE_5_VIEWS
            ],
        },
        {
            "sheet_name": "02b_legs_L_5dir_16x9",
            "aspect": "16:9",
            "size": SIZE_16X9,
            "rows": 1,
            "cols": 5,
            "items": [
                {"kind": "body", "view": v, "part": "leg_l", "label": f"{v.upper()} leg_l",
                 "path": str(assets_dir / v / "parts_5" / "leg_l.png")}
                for v in BASE_5_VIEWS
            ],
        },
        {
            "sheet_name": "03_arms_10pcs_16x9",
            "aspect": "16:9",
            "size": SIZE_16X9,
            "rows": 2,
            "cols": 5,
            "items": (
                [{"kind": "body", "view": v, "part": "arm_r", "label": f"{v.upper()} arm_r",
                  "path": str(assets_dir / v / "parts_5" / "arm_r.png")} for v in BASE_5_VIEWS]
                + [{"kind": "body", "view": v, "part": "arm_l", "label": f"{v.upper()} arm_l",
                    "path": str(assets_dir / v / "parts_5" / "arm_l.png")} for v in BASE_5_VIEWS]
            ),
        },
        {
            "sheet_name": "04_pauldrons_10pcs_16x9",
            "aspect": "16:9",
            "size": SIZE_16X9,
            "rows": 2,
            "cols": 5,
            "items": (
                [{"kind": "body", "view": v, "part": "pauldron_r", "label": f"{v.upper()} pauldron_r",
                  "path": str(assets_dir / v / "parts_5" / "pauldron_r.png")} for v in BASE_5_VIEWS]
                + [{"kind": "body", "view": v, "part": "pauldron_l", "label": f"{v.upper()} pauldron_l",
                    "path": str(assets_dir / v / "parts_5" / "pauldron_l.png")} for v in BASE_5_VIEWS]
            ),
        },
        {
            "sheet_name": "05a_heads_front_2x2_1x1",
            "aspect": "1:1",
            "size": SIZE_1X1,
            "rows": 2,
            "cols": 2,
            "items": [
                {"kind": "head", "head_key": hk, "label": hk,
                 "path": str(assets_dir / "heads" / f"{hk}.png")}
                for hk in ["head_front", "head_front_r", "head_front_l", "head_side_r"]
            ],
        },
        {
            "sheet_name": "05b_heads_back_2x2_1x1",
            "aspect": "1:1",
            "size": SIZE_1X1,
            "rows": 2,
            "cols": 2,
            "items": [
                {"kind": "head", "head_key": hk, "label": hk,
                 "path": str(assets_dir / "heads" / f"{hk}.png")}
                for hk in ["head_side_l", "head_back_r", "head_back_l", "head_back"]
            ],
        },
    ]


def _render_sheet(
    spec: dict,
    out_white: Path,
    out_normal: Path,
    out_guide: Path,
) -> dict:
    sheet_w, sheet_h = spec["size"]
    rows, cols = int(spec["rows"]), int(spec["cols"])
    outer_pad = 56
    cell_pad = 36

    usable_w = sheet_w - 2 * outer_pad
    usable_h = sheet_h - 2 * outer_pad
    slot_w = usable_w // cols
    slot_h = usable_h // rows

    canvas_white = np.full((sheet_h, sheet_w, 3), BG_WHITE_BGR, dtype=np.uint8)
    canvas_normal = np.full((sheet_h, sheet_w, 3), BG_NORMAL_BGR, dtype=np.uint8)
    slots_meta: list[dict] = []

    for idx, item in enumerate(spec["items"]):
        r = idx // cols
        c = idx % cols
        src_path = Path(item["path"])
        bgra = cv2.imread(str(src_path), cv2.IMREAD_UNCHANGED)
        if bgra is None or bgra.shape[2] < 4:
            raise FileNotFoundError(f"Missing RGBA piece PNG: {src_path}")

        ih, iw = bgra.shape[:2]
        avail_w = max(1, slot_w - 2 * cell_pad)
        avail_h = max(1, slot_h - 2 * cell_pad)
        scale = min(avail_w / max(iw, 1), avail_h / max(ih, 1))
        nw = max(1, int(round(iw * scale)))
        nh = max(1, int(round(ih * scale)))
        interp = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_CUBIC
        resized = cv2.resize(bgra, (nw, nh), interpolation=interp)

        sx0 = outer_pad + c * slot_w
        sy0 = outer_pad + r * slot_h
        dx = sx0 + (slot_w - nw) // 2
        dy = sy0 + (slot_h - nh) // 2

        alpha = np.clip(resized[:, :, 3:4].astype(np.float32) / 255.0, 0.0, 1.0)
        fg = resized[:, :, :3].astype(np.float32)

        for canvas in (canvas_white, canvas_normal):
            roi = canvas[dy : dy + nh, dx : dx + nw].astype(np.float32)
            blended = fg * alpha + roi * (1.0 - alpha)
            canvas[dy : dy + nh, dx : dx + nw] = np.clip(np.round(blended), 0, 255).astype(np.uint8)

        entry = {
            "index": idx,
            "row": r,
            "col": c,
            "kind": item["kind"],
            "label": item["label"],
            "source_rel": str(src_path.as_posix()),
            "slot_rect": [sx0, sy0, slot_w, slot_h],
            "piece_rect": [dx, dy, nw, nh],
            "orig_size": [iw, ih],
            "scale": round(scale, 5),
        }
        if item["kind"] == "body":
            entry["view"] = item["view"]
            entry["part"] = item["part"]
        else:
            entry["head_key"] = item["head_key"]
        slots_meta.append(entry)

    fname = f"{spec['sheet_name']}.png"
    cv2.imwrite(str(out_white / fname), canvas_white)
    cv2.imwrite(str(out_normal / fname), canvas_normal)

    # Guide image with subtle slot boxes and labels (for human verification only)
    guide = canvas_white.copy()
    for s in slots_meta:
        sx, sy, sw, sh = s["slot_rect"]
        cv2.rectangle(guide, (sx + 2, sy + 2), (sx + sw - 3, sy + sh - 3), (200, 210, 225), 2)
        cv2.putText(
            guide,
            s["label"],
            (sx + 14, sy + 34),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (40, 50, 75),
            2,
            cv2.LINE_AA,
        )
    cv2.imwrite(str(out_guide / fname), guide)
    print(f"[EXPORT] {fname} ({spec['aspect']}, {sheet_w}x{sheet_h}, {len(slots_meta)} pcs)")

    return {
        "file": fname,
        "aspect": spec["aspect"],
        "size": [sheet_w, sheet_h],
        "rows": rows,
        "cols": cols,
        "slots": slots_meta,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Export 7 piece mask sheets and AI prompt guides for Valentina v2.")
    parser.add_argument(
        "--prompts-only",
        action="store_true",
        help="Only create output folders and write PROMPT_*.md guides without re-rendering input sheets.",
    )
    args = parser.parse_args()

    assets_dir = DEFAULT_OUT_DIR
    out_root = DEFAULT_SOURCE_DIR / WORK_SUBDIR
    inputs_dir = out_root / "inputs"
    inputs_normal_dir = out_root / "inputs_normal"
    guides_dir = out_root / "guides"
    for d in (
        inputs_dir,
        inputs_normal_dir,
        guides_dir,
        out_root / "outputs_id",
        out_root / "outputs_normal",
        out_root / "outputs_ilm",
        out_root / "outputs_ink",
    ):
        d.mkdir(parents=True, exist_ok=True)

    if not args.prompts_only:
        manifest: dict[str, dict] = {}
        for spec in _piece_specs(assets_dir):
            manifest[spec["sheet_name"]] = _render_sheet(spec, inputs_dir, inputs_normal_dir, guides_dir)

        manifest_path = out_root / "piece_sheets_manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    (out_root / "PROMPT_A_ID_MASK.md").write_text(build_prompt_a_id_mask(), encoding="utf-8")
    (out_root / "PROMPT_B_NORMAL_DEPTH.md").write_text(build_prompt_b_normal_depth(), encoding="utf-8")
    (out_root / "PROMPT_C_ILM_MASK.md").write_text(build_prompt_c_ilm_mask(), encoding="utf-8")
    (out_root / "PROMPT_D_INK_LINEART.md").write_text(build_prompt_d_ink_lineart(), encoding="utf-8")

    print(f"\nWorkspace listo en: {out_root}")
    if not args.prompts_only:
        print("  - 7 hojas limpias (#FFFFFF): inputs/")
        print("  - 7 hojas normales (#8080FF): inputs_normal/")
        print("  - 7 guías rotuladas: guides/")
    print("  - Carpetas de salida: outputs_id/, outputs_normal/, outputs_ilm/, outputs_ink/")
    print("  - 4 guías de prompts: PROMPT_A_ID_MASK.md, PROMPT_B_NORMAL_DEPTH.md, PROMPT_C_ILM_MASK.md, PROMPT_D_INK_LINEART.md")


if __name__ == "__main__":
    main()
