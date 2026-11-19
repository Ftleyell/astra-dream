"""Visual verification audit sheet rendering for Valentina v2 8-dir rig."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from .constants import (
    BONE_PARENTS,
    CANONICAL_H,
    CANONICAL_W,
    DIRECTIONS,
    PART_NAMES,
    PX_H,
    PX_W,
    VIEW_TO_HEAD_KEY,
)


def render_final_audits(source_dir: Path, out_dir: Path, audit_dir: Path, heads_meta: dict) -> None:
    """Export composite visual sheets verifying reassembled bodies, bones, carved heads, and mounted heads."""
    audit_dir.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = 360, 480
    scale_x = 0.85

    def _world_to_cell(px: float, py: float, col_idx: int) -> tuple[int, int]:
        cx = col_idx * cell_w + int(round((px - 260.0) * scale_x + cell_w * 0.5))
        cy = int(round((py - 60.0) * scale_x))
        return cx, cy

    canvas_bodies = np.full((cell_h, cell_w * len(DIRECTIONS), 4), 255, dtype=np.uint8)
    canvas_mounted = np.full((cell_h, cell_w * len(DIRECTIONS), 4), 255, dtype=np.uint8)

    for idx, v in enumerate(DIRECTIONS):
        parts_dir = out_dir / v / "parts_5"
        meta = json.loads((parts_dir / "parts_5_meta.json").read_text(encoding="utf-8"))
        z_orders = meta["z_orders"]
        bones = {b["name"]: b["pos"] for b in meta["bones"]}

        # Composite 5 body parts onto transparent cell buffer in canonical coordinates
        comp = np.full((cell_h, cell_w, 4), 255, dtype=np.uint8)
        for pname, _z in sorted(z_orders.items(), key=lambda kv: kv[1]):
            img = cv2.imread(str(parts_dir / f"{pname}.png"), cv2.IMREAD_UNCHANGED)
            rx, ry, rw, rh = meta["rects"][pname]
            tx0 = int(round((rx - 260.0) * scale_x + cell_w * 0.5))
            ty0 = int(round((ry - 60.0) * scale_x))
            tw = max(1, int(round(rw * scale_x)))
            th = max(1, int(round(rh * scale_x)))
            rs = cv2.resize(img, (tw, th), interpolation=cv2.INTER_AREA)
            px0, py0 = max(0, tx0), max(0, ty0)
            px1, py1 = min(cell_w, tx0 + tw), min(cell_h, ty0 + th)
            if px1 > px0 and py1 > py0:
                sub = rs[py0 - ty0 : py1 - ty0, px0 - tx0 : px1 - tx0]
                a = sub[:, :, 3:4].astype(np.float32) / 255.0
                dst = comp[py0:py1, px0:px1, :3].astype(np.float32)
                comp[py0:py1, px0:px1, :3] = np.clip(dst * (1.0 - a) + sub[:, :, :3].astype(np.float32) * a, 0, 255).astype(np.uint8)

        mounted = comp.copy()
        h_key = VIEW_TO_HEAD_KEY[v]
        h_img = cv2.imread(str(out_dir / "heads" / f"{h_key}.png"), cv2.IMREAD_UNCHANGED)
        h_info = heads_meta[h_key]
        combo_tf = heads_meta.get("combo_transforms", {}).get(v, {}).get(h_key, {})
        h_scale = float(combo_tf.get("scale", 1.0)) if isinstance(combo_tf, dict) else 1.0
        dw = float(h_info["disp_size"][0]) * h_scale
        dh = float(h_info["disp_size"][1]) * h_scale
        ox, oy = combo_tf.get("sprite_offset", h_info["sprite_offset"]) if isinstance(combo_tf, dict) else h_info["sprite_offset"]
        nx, ny = bones["Neck"]
        hx_c, hy_c = nx + ox, ny + oy
        hx0 = int(round((hx_c - dw * 0.5 - 260.0) * scale_x + cell_w * 0.5))
        hy0 = int(round((hy_c - dh * 0.5 - 60.0) * scale_x))
        hw = max(1, int(round(dw * scale_x)))
        hh = max(1, int(round(dh * scale_x)))
        hrs = cv2.resize(h_img, (hw, hh), interpolation=cv2.INTER_AREA)
        px0, py0 = max(0, hx0), max(0, hy0)
        px1, py1 = min(cell_w, hx0 + hw), min(cell_h, hy0 + hh)
        if px1 > px0 and py1 > py0:
            sub = hrs[py0 - hy0 : py1 - hy0, px0 - hx0 : px1 - hx0]
            a = sub[:, :, 3:4].astype(np.float32) / 255.0
            dst = mounted[py0:py1, px0:px1, :3].astype(np.float32)
            mounted[py0:py1, px0:px1, :3] = np.clip(dst * (1.0 - a) + sub[:, :, :3].astype(np.float32) * a, 0, 255).astype(np.uint8)

        # Draw bone skeleton on bodies audit
        for bname, parent in BONE_PARENTS:
            p_c = _world_to_cell(bones[bname][0], bones[bname][1], 0)
            if parent:
                p_p = _world_to_cell(bones[parent][0], bones[parent][1], 0)
                cv2.line(comp, p_p, p_c, (20, 180, 255, 255), 2, cv2.LINE_AA)
            cv2.circle(comp, p_c, 4, (0, 60, 255, 255), -1)

        cv2.putText(comp, v.upper(), (14, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (30, 30, 30, 255), 2, cv2.LINE_AA)
        cv2.putText(mounted, f"{v.upper()} + {h_key}", (14, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.68, (30, 30, 30, 255), 2, cv2.LINE_AA)
        canvas_bodies[:, idx * cell_w : (idx + 1) * cell_w] = comp
        canvas_mounted[:, idx * cell_w : (idx + 1) * cell_w] = mounted

    cv2.imwrite(str(audit_dir / "audit_bodies_bones_8dir.png"), canvas_bodies[:, :, :3])
    cv2.imwrite(str(audit_dir / "audit_mounted_rigs_8dir.png"), canvas_mounted[:, :, :3])

    # Carved heads strip audit
    hcell = 340
    strip = np.full((hcell, hcell * len(DIRECTIONS), 3), 240, dtype=np.uint8)
    for idx, v in enumerate(DIRECTIONS):
        hk = VIEW_TO_HEAD_KEY[v]
        him = cv2.imread(str(out_dir / "heads" / f"{hk}.png"), cv2.IMREAD_UNCHANGED)
        sc = (hcell - 40) / float(max(him.shape[:2]))
        rw, rh = int(round(him.shape[1] * sc)), int(round(him.shape[0] * sc))
        rs = cv2.resize(him, (rw, rh), interpolation=cv2.INTER_AREA)
        x0 = idx * hcell + (hcell - rw) // 2
        y0 = (hcell - rh) // 2
        a = rs[:, :, 3:4].astype(np.float32) / 255.0
        dst = strip[y0 : y0 + rh, x0 : x0 + rw].astype(np.float32)
        strip[y0 : y0 + rh, x0 : x0 + rw] = np.clip(dst * (1.0 - a) + rs[:, :, :3].astype(np.float32) * a, 0, 255).astype(np.uint8)
        cv2.putText(strip, hk, (idx * hcell + 12, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (25, 25, 25), 2, cv2.LINE_AA)
    cv2.imwrite(str(audit_dir / "audit_carved_heads_8dir.png"), strip)
