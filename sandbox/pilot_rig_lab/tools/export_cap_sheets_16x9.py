"""Export clean 16:9 (2560x1440) limb sheets on pure white for AI ball-cap generation."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from rig_v2_lib.constants import (
    DEFAULT_SOURCE_DIR,
    DIRECTIONS,
    PX_H,
    PX_W,
    _canonical_rgba_path,
)
from rig_v2_lib.heads_builder import _compute_body_neck_cut
from rig_v2_lib.skeleton_and_normals import _synthesize_rear_arm_maps

SHEET_W = 2560
SHEET_H = 1440
TOP_HEADROOM_PX = 180
SIDE_MARGIN_PX = 70
BOTTOM_MARGIN_PX = 70


def _extract_clean_limb_crop(rgba: np.ndarray, mask: np.ndarray) -> np.ndarray | None:
    if int(mask.sum()) < 250:
        return None
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    crop = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    m_crop = mask[y0:y1, x0:x1]
    crop[m_crop] = rgba[y0:y1, x0:x1][m_crop]
    return crop


def _build_sheet(
    sheet_name: str,
    items: list[tuple[str, str, np.ndarray]],
    out_dir: Path,
) -> dict:
    canvas = np.full((SHEET_H, SHEET_W, 3), 255, dtype=np.uint8)
    n = len(items)
    usable_w = SHEET_W - 2 * SIDE_MARGIN_PX
    slot_w = usable_w // max(n, 1)
    max_limb_h = SHEET_H - TOP_HEADROOM_PX - BOTTOM_MARGIN_PX
    slots_meta: list[dict] = []

    for idx, (view, part_name, bgra) in enumerate(items):
        lh, lw = bgra.shape[:2]
        scale = min((slot_w - 40) / max(lw, 1), max_limb_h / max(lh, 1), 1.0)
        nw = max(1, int(round(lw * scale)))
        nh = max(1, int(round(lh * scale)))
        resized = cv2.resize(bgra, (nw, nh), interpolation=cv2.INTER_AREA if scale < 1.0 else cv2.INTER_LINEAR)

        sx0 = SIDE_MARGIN_PX + idx * slot_w
        dx = sx0 + (slot_w - nw) // 2
        dy = TOP_HEADROOM_PX + (max_limb_h - nh) // 2

        alpha = resized[:, :, 3:4].astype(np.float32) / 255.0
        roi = canvas[dy : dy + nh, dx : dx + nw].astype(np.float32)
        blended = resized[:, :, :3].astype(np.float32) * alpha + roi * (1.0 - alpha)
        canvas[dy : dy + nh, dx : dx + nw] = np.clip(np.round(blended), 0, 255).astype(np.uint8)

        slots_meta.append({
            "index": idx,
            "view": view,
            "part": part_name,
            "slot_rect": [sx0, 0, slot_w, SHEET_H],
            "limb_rect": [dx, dy, nw, nh],
            "orig_size": [lw, lh],
            "scale": round(scale, 5),
        })

    out_path = out_dir / f"{sheet_name}.png"
    cv2.imwrite(str(out_path), canvas)
    print(f"[SHEET] {out_path.name} ({n} limbs, {SHEET_W}x{SHEET_H})")
    return {"file": out_path.name, "size": [SHEET_W, SHEET_H], "slots": slots_meta}


def main() -> None:
    source_dir = DEFAULT_SOURCE_DIR
    ws_dir = source_dir / "05_mask_ai_workspaces"
    out_dir = ws_dir / "manual_fix_overlays" / "04_cap_sheets_16x9"
    out_dir.mkdir(parents=True, exist_ok=True)

    limbs: dict[tuple[str, str], np.ndarray] = {}
    for view in DIRECTIONS:
        ref_rgba = cv2.imread(str(_canonical_rgba_path(source_dir, view)), cv2.IMREAD_UNCHANGED)
        p5_mask = cv2.imread(str(ws_dir / "01_parts_5_despiece" / "split_results" / f"{view}_parts5_mask.png"))
        id_bgra = cv2.imread(str(ws_dir / "02_id_mask_bodies" / "split_results" / f"{view}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        part_masks, _ = _compute_body_neck_cut(p5_mask, id_bgra, ref_rgba)

        for pname in ("arm_r", "arm_l", "leg_r", "leg_l"):
            crop = _extract_clean_limb_crop(ref_rgba, part_masks[pname])
            if crop is not None:
                limbs[(view, pname)] = crop

        if view in ("e", "w"):
            rear_arm = "arm_l" if view == "e" else "arm_r"
            rear_arm_path = ws_dir / "manual_fix_overlays" / "03_brazo_trasero_e_w" / f"{view}_arm_back_rgba_1560x1680.png"
            if rear_arm_path.exists():
                ra_rgba = cv2.imread(str(rear_arm_path), cv2.IMREAD_UNCHANGED)
                if ra_rgba is not None and ra_rgba.shape[:2] == (PX_H, PX_W):
                    ra_mask, _, _ = _synthesize_rear_arm_maps(ra_rgba)
                    crop = _extract_clean_limb_crop(ra_rgba, ra_mask)
                    if crop is not None:
                        limbs[(view, rear_arm)] = crop

    sheet_specs: list[tuple[str, list[tuple[str, str]]]] = [
        ("01_arms_front_s_se_sw_16x9", [
            ("s", "arm_r"), ("s", "arm_l"),
            ("se", "arm_r"), ("se", "arm_l"),
            ("sw", "arm_r"), ("sw", "arm_l"),
        ]),
        ("02_arms_profile_e_w_16x9", [
            ("e", "arm_r"), ("e", "arm_l"),
            ("w", "arm_r"), ("w", "arm_l"),
        ]),
        ("03_arms_back_n_ne_nw_16x9", [
            ("n", "arm_r"), ("n", "arm_l"),
            ("ne", "arm_r"), ("ne", "arm_l"),
            ("nw", "arm_r"), ("nw", "arm_l"),
        ]),
        ("04_legs_front_s_se_sw_16x9", [
            ("s", "leg_r"), ("s", "leg_l"),
            ("se", "leg_r"), ("se", "leg_l"),
            ("sw", "leg_r"), ("sw", "leg_l"),
        ]),
        ("05_legs_back_n_ne_nw_16x9", [
            ("n", "leg_r"), ("n", "leg_l"),
            ("ne", "leg_r"), ("ne", "leg_l"),
            ("nw", "leg_r"), ("nw", "leg_l"),
        ]),
        ("06_legs_profile_e_w_16x9", [
            ("e", "leg_r"),
            ("w", "leg_l"),
        ]),
    ]

    manifest: dict[str, dict] = {}
    for sname, keys in sheet_specs:
        items = [(v, p, limbs[(v, p)]) for (v, p) in keys if (v, p) in limbs]
        manifest[sname] = _build_sheet(sname, items, out_dir)

    (out_dir / "sheets_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
