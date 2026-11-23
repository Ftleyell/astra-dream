#!/usr/bin/env python3
"""Export 16:9 (2560x1440) sheets for AI armpit/torso fill (8 views) and E-profile glute/thigh cap."""
from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

DIRECTIONS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
SHEET_W = 2560
SHEET_H = 1440

SCRIPT_DIR = Path(__file__).resolve().parent
LAB_DIR = SCRIPT_DIR.parent
REPO_ROOT = LAB_DIR.parent.parent
COMBAT_DIR = REPO_ROOT / "assets" / "pilots" / "valentina_v2" / "planar"
OUT_DIR = (
    LAB_DIR
    / "source_refs"
    / "valentina_v2_8dir"
    / "05_mask_ai_workspaces"
    / "manual_fix_overlays"
    / "06_torso_and_leg_e_16x9"
)


def _composite_on_white(rgba: np.ndarray) -> np.ndarray:
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    rgb = rgba[:, :, :3].astype(np.float32) * a + 255.0 * (1.0 - a)
    return np.clip(np.round(rgb), 0, 255).astype(np.uint8)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {}

    # 1. All 8 body_core torsos in a 4x2 grid on 2560x1440 white canvas
    torso_canvas = np.full((SHEET_H, SHEET_W, 3), 255, dtype=np.uint8)
    cell_w = SHEET_W // 4
    cell_h = SHEET_H // 2
    torso_slots: list[dict[str, object]] = []

    for idx, view in enumerate(DIRECTIONS):
        src_path = COMBAT_DIR / view / "parts_5" / "body_core.png"
        rgba = cv2.imread(str(src_path), cv2.IMREAD_UNCHANGED)
        if rgba is None:
            raise FileNotFoundError(f"Missing {src_path}")
        h, w = rgba.shape[:2]
        col = idx % 4
        row = idx // 4
        cx0 = col * cell_w
        cy0 = row * cell_h
        px = cx0 + (cell_w - w) // 2
        py = cy0 + (cell_h - h) // 2
        torso_canvas[py : py + h, px : px + w] = _composite_on_white(rgba)
        torso_slots.append(
            {
                "index": idx,
                "view": view,
                "part": "body_core",
                "slot_rect": [cx0, cy0, cell_w, cell_h],
                "paste_xy": [px, py],
                "orig_size": [w, h],
            }
        )

    torso_path = OUT_DIR / "06_torso_armpit_fill_16x9.png"
    cv2.imwrite(str(torso_path), torso_canvas)
    manifest["06_torso_armpit_fill_16x9"] = {
        "file": torso_path.name,
        "size": [SHEET_W, SHEET_H],
        "slots": torso_slots,
    }
    print(f"[EXPORT] {torso_path}")

    # 2. E-profile leg_r centered on 2560x1440 white canvas (will be mirrored for W)
    leg_src = COMBAT_DIR / "e" / "parts_5" / "leg_r.png"
    leg_rgba = cv2.imread(str(leg_src), cv2.IMREAD_UNCHANGED)
    if leg_rgba is None:
        raise FileNotFoundError(f"Missing {leg_src}")
    lh, lw = leg_rgba.shape[:2]
    lpx = (SHEET_W - lw) // 2
    lpy = (SHEET_H - lh) // 2
    leg_canvas = np.full((SHEET_H, SHEET_W, 3), 255, dtype=np.uint8)
    leg_canvas[lpy : lpy + lh, lpx : lpx + lw] = _composite_on_white(leg_rgba)

    leg_path = OUT_DIR / "07_leg_profile_e_glute_16x9.png"
    cv2.imwrite(str(leg_path), leg_canvas)
    manifest["07_leg_profile_e_glute_16x9"] = {
        "file": leg_path.name,
        "size": [SHEET_W, SHEET_H],
        "slots": [
            {
                "index": 0,
                "view": "e",
                "part": "leg_r",
                "slot_rect": [0, 0, SHEET_W, SHEET_H],
                "paste_xy": [lpx, lpy],
                "orig_size": [lw, lh],
            }
        ],
    }
    print(f"[EXPORT] {leg_path}")

    manifest_path = OUT_DIR / "torso_leg_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"[MANIFEST] {manifest_path}")


if __name__ == "__main__":
    main()
