"""Fix body_core under-pauldron Voronoi stains/gaps and improve rear pauldron shoulder coverage in diagonals."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import cv2
import numpy as np

from polish_outlines import _voronoi_fill, alpha_bleed_only
from process_head_8dir_sheet import _build_clean_head_normal_depth
from rig_v2_lib.constants import (
    DEFAULT_OUT_DIR,
    DEFAULT_SOURCE_DIR,
    DIRECTIONS,
    PX_H,
    PX_W,
)

# Dark undersuit tone (BGR) for hidden socket under pauldrons
UNDERSUIT_BGR = (44, 38, 46)


def _load_or_backup(path: Path, backup_path: Path) -> np.ndarray:
    if backup_path.exists():
        img = cv2.imread(str(backup_path), cv2.IMREAD_UNCHANGED)
        if img is not None:
            return img
    img = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if img is None:
        raise FileNotFoundError(f"Missing {path}")
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_path)
    return img


def _expand_and_nudge_pauldron(
    p_rgba: np.ndarray,
    id_mask: np.ndarray,
    rect_du: list[float],
    tex_scale: int,
    scale_x: float,
    scale_y: float,
    shift_px_x: int,
    shift_px_y: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, list[float]]:
    """Scale and shift a pauldron patch slightly so it covers the rear shoulder cleanly."""
    oh, ow = p_rgba.shape[:2]
    nw = max(1, int(round(ow * scale_x)))
    nh = max(1, int(round(oh * scale_y)))
    new_rgba = cv2.resize(p_rgba, (nw, nh), interpolation=cv2.INTER_CUBIC)
    new_rgba = alpha_bleed_only(new_rgba)

    new_id = cv2.resize(id_mask, (nw, nh), interpolation=cv2.INTER_NEAREST)
    interior = new_rgba[:, :, 3] >= 128
    nd = _build_clean_head_normal_depth(new_rgba[:, :, 3])
    nz = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
    valid = interior & nz
    if np.any(valid) and not np.all(valid):
        nd = _voronoi_fill(nd, valid)

    rx, ry, _, _ = [float(v) * float(tex_scale) for v in rect_du]
    # Keep top-inner anchor roughly aligned, then apply explicit shift
    dx = rx - 0.5 * (nw - ow) + float(shift_px_x)
    dy = ry - 0.5 * (nh - oh) + float(shift_px_y)
    new_rect = [
        round(dx / float(tex_scale), 2),
        round(dy / float(tex_scale), 2),
        round(nw / float(tex_scale), 2),
        round(nh / float(tex_scale), 2),
    ]
    return new_rgba, new_id, nd, new_rect


def main() -> None:
    ws_dir = DEFAULT_SOURCE_DIR / "05_mask_ai_workspaces"
    torso_dir = ws_dir / "manual_fix_overlays" / "06_torso_and_leg_e_16x9" / "ingested_1560x1680"
    backup_dir = ws_dir / "manual_fix_overlays" / "07_pauldron_polish_16x9" / "backup_before_seam_fix"
    backup_dir.mkdir(parents=True, exist_ok=True)

    # 1) Improve rear pauldron coverage + tuck rear arm & pauldron closer to torso in diagonal views (se/sw, ne/nw)
    #    In se/ne, rear arm/pauldron is *_l; in sw/nw, rear arm/pauldron is *_r.
    rear_adjustments: dict[tuple[str, str], tuple[float, float, int, int]] = {
        ("se", "pauldron_l"): (1.12, 1.10, -3, 4),
        ("sw", "pauldron_r"): (1.12, 1.10, 3, 4),
        ("ne", "pauldron_l"): (1.16, 1.12, 3, 4),
        ("nw", "pauldron_r"): (1.16, 1.12, -3, 4),
        ("nw", "pauldron_l"): (1.06, 1.04, 12, 2),
    }
    rear_arm_tuck_du: dict[tuple[str, str], float] = {
        ("se", "arm_l"): -3.5,
        ("sw", "arm_r"): 3.5,
        ("ne", "arm_l"): 3.5,
        ("nw", "arm_r"): -3.5,
    }

    for (view, pname), (sx, sy, dx, dy) in rear_adjustments.items():
        pdir = DEFAULT_OUT_DIR / view / "parts_5"
        meta_path = pdir / "parts_5_meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        ts = int(meta["tex_scale"])

        p_rgba = _load_or_backup(pdir / f"{pname}.png", backup_dir / f"{view}_{pname}.png")
        p_id = _load_or_backup(pdir / f"{pname}_id_mask.png", backup_dir / f"{view}_{pname}_id_mask.png")
        orig_rect = meta["rects"][pname]
        b_meta = meta
        if (backup_dir / f"{view}_parts_5_meta.json").exists():
            b_meta = json.loads((backup_dir / f"{view}_parts_5_meta.json").read_text(encoding="utf-8"))
            orig_rect = b_meta["rects"][pname]
        else:
            shutil.copy2(meta_path, backup_dir / f"{view}_parts_5_meta.json")

        new_rgba, new_id, new_nd, new_rect = _expand_and_nudge_pauldron(
            p_rgba, p_id, orig_rect, ts, sx, sy, dx, dy
        )
        cv2.imwrite(str(pdir / f"{pname}.png"), new_rgba)
        cv2.imwrite(str(pdir / f"{pname}_id_mask.png"), new_id)
        cv2.imwrite(str(pdir / f"{pname}_normal_depth.png"), new_nd)
        meta["rects"][pname] = new_rect
        # Also shift the corresponding Pauldron_* bone from backup so pivot stays locked & idempotent
        p_bone_name = "Pauldron_L" if pname == "pauldron_l" else "Pauldron_R"
        b_orig_bones = {b["name"]: b["pos"] for b in b_meta["bones"]}
        for b_entry in meta["bones"]:
            if b_entry["name"] == p_bone_name and p_bone_name in b_orig_bones:
                b_entry["pos"] = [
                    round(float(b_orig_bones[p_bone_name][0]) + (new_rect[0] - orig_rect[0]) + 0.5 * (new_rect[2] - orig_rect[2]), 2),
                    round(float(b_orig_bones[p_bone_name][1]) + (new_rect[1] - orig_rect[1]) + 0.5 * (new_rect[3] - orig_rect[3]), 2),
                ]
                break
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"[REAR PAULDRON] {view}/{pname}: rect {orig_rect} -> {new_rect}")

    # 1b) Tuck rear arm (rect + Shoulder/Elbow/Wrist bones) closer to torso in se/sw/ne/nw
    for (view, arm_name), dx_du in rear_arm_tuck_du.items():
        pdir = DEFAULT_OUT_DIR / view / "parts_5"
        meta_path = pdir / "parts_5_meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        b_meta = json.loads((backup_dir / f"{view}_parts_5_meta.json").read_text(encoding="utf-8"))
        orig_arm_rect = list(b_meta["rects"][arm_name])
        meta["rects"][arm_name] = [
            round(float(orig_arm_rect[0]) + dx_du, 2),
            orig_arm_rect[1],
            orig_arm_rect[2],
            orig_arm_rect[3],
        ]
        suffix = "_L" if arm_name == "arm_l" else "_R"
        arm_bones = {f"Shoulder{suffix}", f"Elbow{suffix}", f"Wrist{suffix}"}
        b_orig_bones = {b["name"]: b["pos"] for b in b_meta["bones"]}
        for b_entry in meta["bones"]:
            if b_entry["name"] in arm_bones and b_entry["name"] in b_orig_bones:
                b_entry["pos"] = [
                    round(float(b_orig_bones[b_entry["name"]][0]) + dx_du, 2),
                    b_orig_bones[b_entry["name"]][1],
                ]
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"[REAR ARM TUCK] {view}/{arm_name}: dx_du={dx_du:+.2f}")

    # 2) Rebuild body_core from the clean AI-reconstructed torso (06_torso_and_leg_e_16x9)
    #    keeping the seamless inner collar/armpit intact and ONLY trimming old pauldron overhang
    #    that protrudes outside the new polished pauldrons.
    for view in DIRECTIONS:
        pdir = DEFAULT_OUT_DIR / view / "parts_5"
        meta = json.loads((pdir / "parts_5_meta.json").read_text(encoding="utf-8"))
        ts = int(meta["tex_scale"])
        rects = meta["rects"]

        bc_path = pdir / "body_core.png"
        bc_rgba = _load_or_backup(bc_path, backup_dir / f"{view}_body_core.png")
        bx, by, _, _ = [int(round(v * ts)) for v in rects["body_core"]]
        bh, bw = bc_rgba.shape[:2]

        # Build canonical 1560x1680 mask of the current pauldrons
        new_p_canvas = np.zeros((PX_H, PX_W), dtype=bool)
        for pname in ("pauldron_r", "pauldron_l"):
            p_img = cv2.imread(str(pdir / f"{pname}.png"), cv2.IMREAD_UNCHANGED)
            if p_img is None or p_img.shape[:2] == (12, 12):
                continue
            rx, ry, _, _ = [int(round(v * ts)) for v in rects[pname]]
            ph, pw = p_img.shape[:2]
            x0, y0 = max(0, rx), max(0, ry)
            x1, y1 = min(PX_W, rx + pw), min(PX_H, ry + ph)
            if x1 > x0 and y1 > y0:
                new_p_canvas[y0:y1, x0:x1] |= p_img[y0 - ry : y1 - ry, x0 - rx : x1 - rx, 3] >= 64

        pm_path = torso_dir / f"{view}_pauldron_mask.png"
        raw_torso_path = torso_dir / f"{view}_body_core.png"
        if not pm_path.exists() or not raw_torso_path.exists():
            continue
        pm_full = cv2.imread(str(pm_path), cv2.IMREAD_GRAYSCALE) >= 128
        raw_torso = cv2.imread(str(raw_torso_path), cv2.IMREAD_UNCHANGED)

        # Crop raw_torso, pm_full, and new_p_canvas to body_core's local patch
        y0, y1 = max(0, by), min(PX_H, by + bh)
        x0, x1 = max(0, bx), min(PX_W, bx + bw)
        pm_crop = np.zeros((bh, bw), dtype=bool)
        new_p_crop = np.zeros((bh, bw), dtype=bool)
        bc_fixed = bc_rgba.copy()
        pm_crop[y0 - by : y1 - by, x0 - bx : x1 - bx] = pm_full[y0:y1, x0:x1]
        new_p_crop[y0 - by : y1 - by, x0 - bx : x1 - bx] = new_p_canvas[y0:y1, x0:x1]

        # Restore clean raw_torso pixels inside pm_crop (eliminates staircase cutout & white dashed gaps!)
        raw_crop = np.zeros((bh, bw, 4), dtype=np.uint8)
        raw_crop[y0 - by : y1 - by, x0 - bx : x1 - bx] = raw_torso[y0:y1, x0:x1]
        restore_zone = cv2.dilate(pm_crop.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
        # Keep existing neck fade / lower glute feather from bc_rgba outside restore_zone
        bc_fixed[restore_zone] = raw_crop[restore_zone]

        # Trim ONLY old pauldron overhang outside the new pauldron (eroded 2px)
        safe_under = cv2.erode(new_p_crop.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        protruding_stump = pm_crop & (~safe_under)
        bc_fixed[protruding_stump] = 0

        bc_fixed = alpha_bleed_and_defringe(bc_fixed)
        cv2.imwrite(str(bc_path), bc_fixed)

        interior_nd = bc_fixed[:, :, 3] >= 128
        nd = _build_clean_head_normal_depth(bc_fixed[:, :, 3])
        nz = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
        valid_nd = interior_nd & nz
        if np.any(valid_nd) and not np.all(valid_nd):
            nd = _voronoi_fill(nd, valid_nd)
        cv2.imwrite(str(pdir / "body_core_normal_depth.png"), nd)
        print(f"[BODY CORE CLEAN] {view}: restored_raw_px={int(restore_zone.sum())}, trimmed_overhang_px={int(protruding_stump.sum())}")


if __name__ == "__main__":
    main()
