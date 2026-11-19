"""Clean per-part crop export (RGBA, ID mask, normal+depth, anim weights, secondary/pauldron masks)."""

from __future__ import annotations

import shutil
from pathlib import Path

import cv2
import numpy as np

from polish_outlines import _voronoi_fill, alpha_bleed_only
from process_limb_anim_masks import MASK_SCALE
from process_masked_5parts import TEX_SCALE

from .constants import CANONICAL_W, DEFAULT_SOURCE_DIR, LIMB_PARTS, PART_PAD_PX, PX_H, PX_W
from .mask_and_matting import _apply_rear_depth_darkening
from .skeleton_and_normals import (
    _bake_geodesic_anim_mask_with_crease_cut,
    _build_part_bone_chain_3d,
    _build_torso_relief_height,
    _synthesize_skeleton_normal_and_depth,
)


def _export_part_patch(
    pname: str,
    orig_mask: np.ndarray,
    ref_rgba: np.ndarray,
    id_bgra_full: np.ndarray,
    sec_jiggle_full: np.ndarray | None,
    parts_dir: Path,
    meta_bones_dict: dict,
    depth_darken_factor: float = 1.0,
    leg_masks_union: np.ndarray | None = None,
    body_core_mask: np.ndarray | None = None,
    pauldron_mask_full: np.ndarray | None = None,
    exact_crop_rect_px: tuple[int, int, int, int] | None = None,
    rect_shift_du: tuple[float, float] = (0.0, 0.0),
) -> list[float]:
    """Slice one canonical HD part's RGBA and auxiliary maps while preserving 100% of original borders."""
    if int(orig_mask.sum()) < 250:
        w_px, h_px = 12, 12
        cv2.imwrite(str(parts_dir / f"{pname}.png"), np.zeros((h_px, w_px, 4), dtype=np.uint8))
        cv2.imwrite(str(parts_dir / f"{pname}_id_mask.png"), np.zeros((h_px, w_px, 4), dtype=np.uint8))
        nd_empty = np.zeros((h_px, w_px, 4), dtype=np.uint8)
        nd_empty[:, :, 0] = 255
        nd_empty[:, :, 1] = 128
        nd_empty[:, :, 2] = 128
        cv2.imwrite(str(parts_dir / f"{pname}_normal_depth.png"), nd_empty)
        if pname in LIMB_PARTS:
            am_w = max(4, (w_px * MASK_SCALE) // TEX_SCALE)
            am_h = max(4, (h_px * MASK_SCALE) // TEX_SCALE)
            am = np.zeros((am_h, am_w, 3), dtype=np.uint8)
            am[:, :, 2] = 255
            cv2.imwrite(str(parts_dir / f"{pname}_anim_mask.png"), am)
        return [round(float(CANONICAL_W) * 0.5 - 2.0, 2), 200.0, 4.0, 4.0]

    if exact_crop_rect_px is not None:
        x0, y0, pw, ph = exact_crop_rect_px
        x1 = min(PX_W, x0 + pw)
        y1 = min(PX_H, y0 + ph)
        pw = x1 - x0
        ph = y1 - y0
    else:
        ys, xs = np.where(orig_mask)
        x0 = max(0, int(xs.min()) - PART_PAD_PX)
        y0 = max(0, int(ys.min()) - PART_PAD_PX)
        x1 = min(PX_W, int(xs.max()) + 1 + PART_PAD_PX)
        y1 = min(PX_H, int(ys.max()) + 1 + PART_PAD_PX)
        pw, ph = x1 - x0, y1 - y0

    # Copy canonical RGBA verbatim so all anti-aliased border pixels (alpha > 0) remain untouched
    part_rgba = ref_rgba[y0:y1, x0:x1].copy()

    # Drop only disconnected micro-dust specks (< 64 px) without eroding or altering main contour
    n_cc_f, lbl_f, st_f, _ = cv2.connectedComponentsWithStats((part_rgba[:, :, 3] >= 16).astype(np.uint8), connectivity=8)
    if n_cc_f > 2:
        for cc_id in range(1, n_cc_f):
            if int(st_f[cc_id, cv2.CC_STAT_AREA]) < 64:
                part_rgba[lbl_f == cc_id] = 0

    if depth_darken_factor < 0.999:
        part_rgba = _apply_rear_depth_darkening(part_rgba, depth_darken_factor)

    # Pure alpha==0 RGB bleed for GPU bilinear safety (never modifies alpha > 0 pixels)
    part_rgba = alpha_bleed_only(part_rgba)
    cv2.imwrite(str(parts_dir / f"{pname}.png"), part_rgba)

    rect_disp = [
        round(float(x0) / float(TEX_SCALE) + float(rect_shift_du[0]), 4),
        round(float(y0) / float(TEX_SCALE) + float(rect_shift_du[1]), 4),
        round(float(pw) / float(TEX_SCALE), 4),
        round(float(ph) / float(TEX_SCALE), 4),
    ]

    # Local bone anchor offset in texture pixels (rect_shift_du cancels bone shift cleanly)
    x0_shifted = x0 + int(round(float(rect_shift_du[0]) * float(TEX_SCALE)))
    y0_shifted = y0 + int(round(float(rect_shift_du[1]) * float(TEX_SCALE)))

    # Normal+Depth cilíndrico multi-hueso + Z global + Voronoi bleed (orden BGRA: B=nz, G=ny, R=nx, A=depth)
    interior_nd = part_rgba[:, :, 3] >= 128
    bone_chain_xy, bone_chain_z = _build_part_bone_chain_3d(pname, meta_bones_dict, x0_shifted, y0_shifted, ph, pw)
    bc_crop = body_core_mask[y0:y1, x0:x1] if body_core_mask is not None else None
    if pname in LIMB_PARTS and bc_crop is not None:
        cap_open = bc_crop
    elif pname == "body_core" and leg_masks_union is not None:
        cap_open = leg_masks_union[y0:y1, x0:x1]
    else:
        cap_open = None
    torso_relief = _build_torso_relief_height(ph, pw, meta_bones_dict, x0_shifted, y0_shifted) if pname == "body_core" else None
    nd = _synthesize_skeleton_normal_and_depth(
        interior_nd,
        bone_chain_xy,
        bone_chain_z,
        z_global_range=(-110.0, 110.0),
        cap_open_mask=cap_open,
        torso_relief_height=torso_relief,
        nz_min_byte=202,
    )
    if np.any(interior_nd) and not np.all(interior_nd):
        nd = _voronoi_fill(nd, interior_nd)
    cv2.imwrite(str(parts_dir / f"{pname}_normal_depth.png"), nd)

    # ID Mask cropped & dilated by 8px margin
    id_crop = id_bgra_full[y0:y1, x0:x1].copy()
    if np.any(interior_nd):
        id_crop = _voronoi_fill(id_crop, interior_nd, max_dist_px=8.0)
    cv2.imwrite(str(parts_dir / f"{pname}_id_mask.png"), id_crop)

    if pname in LIMB_PARTS:
        aw = max(4, int(round(rect_disp[2] * MASK_SCALE)))
        ah = max(4, int(round(rect_disp[3] * MASK_SCALE)))
        limb_mask_2x = cv2.resize((part_rgba[:, :, 3] >= 64).astype(np.uint8), (aw, ah), interpolation=cv2.INTER_NEAREST) > 0
        side_k = "R" if pname.endswith("_r") else "L"
        b_names = (
            ("Shoulder_" + side_k, "Elbow_" + side_k, "Wrist_" + side_k)
            if pname.startswith("arm")
            else ("Thigh_" + side_k, "Knee_" + side_k, "Ankle_" + side_k)
        )
        bmap_full = {str(b["name"]): b["pos"] for b in meta_bones_dict.get("bones", [])}
        if all(bn in bmap_full for bn in b_names):
            pts_2x = [
                (
                    (float(bmap_full[bn][0]) - float(rect_disp[0])) * float(MASK_SCALE),
                    (float(bmap_full[bn][1]) - float(rect_disp[1])) * float(MASK_SCALE),
                )
                for bn in b_names
            ]
            anim_bgra = _bake_geodesic_anim_mask_with_crease_cut(
                limb_mask_2x,
                pts_2x[0],
                pts_2x[1],
                pts_2x[2],
                seam_pivot=pts_2x[0],
                seam_fade_radius=42.0 * (float(MASK_SCALE) / 2.0),
            )
            if np.any(limb_mask_2x) and not np.all(limb_mask_2x):
                anim_bgra = _voronoi_fill(anim_bgra, limb_mask_2x)
        else:
            anim_bgra = np.zeros((ah, aw, 4), dtype=np.uint8)
            anim_bgra[:, :, 2] = 255
            anim_bgra[:, :, 3] = 255
        cv2.imwrite(str(parts_dir / f"{pname}_anim_mask.png"), anim_bgra)

        over_p = parts_dir / f"{pname}_over_mask.png"
        if over_p.exists():
            over_p.unlink()

    if pname == "body_core":
        if sec_jiggle_full is not None:
            sec_crop = sec_jiggle_full[y0:y1, x0:x1].copy()
            bc_fg = part_rgba[:, :, 3] >= 64
            sec_crop[~bc_fg, :3] = 0
            sec_crop[:, :, 3] = np.where(bc_fg, 255, 0).astype(np.uint8)
        else:
            sec_crop = np.zeros((ph, pw, 4), dtype=np.uint8)
            sec_crop[:, :, 3] = 255
        cv2.imwrite(str(parts_dir / "body_core_secondary_mask.png"), sec_crop)
        view_name = str(meta_bones_dict.get("view", ""))
        if pauldron_mask_full is not None and pauldron_mask_full.shape[:2] == (PX_H, PX_W):
            crop_pm = pauldron_mask_full[y0:y1, x0:x1]
            if crop_pm.shape[:2] != (ph, pw):
                crop_pm = cv2.resize(crop_pm, (pw, ph), interpolation=cv2.INTER_NEAREST)
            cv2.imwrite(str(parts_dir / "body_core_pauldron_mask.png"), crop_pm)
        else:
            full_pauldron_src = (
                DEFAULT_SOURCE_DIR
                / "05_mask_ai_workspaces"
                / "manual_fix_overlays"
                / "06_torso_and_leg_e_16x9"
                / "ingested_1560x1680"
                / f"{view_name}_pauldron_mask.png"
            )
            if full_pauldron_src.exists():
                full_pm = cv2.imread(str(full_pauldron_src), cv2.IMREAD_GRAYSCALE)
                if full_pm is not None and full_pm.shape[:2] == (PX_H, PX_W):
                    crop_pm = full_pm[y0:y1, x0:x1]
                    if crop_pm.shape[:2] != (ph, pw):
                        crop_pm = cv2.resize(crop_pm, (pw, ph), interpolation=cv2.INTER_NEAREST)
                    cv2.imwrite(str(parts_dir / "body_core_pauldron_mask.png"), crop_pm)
            else:
                pauldron_src = (
                    DEFAULT_SOURCE_DIR
                    / "05_mask_ai_workspaces"
                    / "manual_fix_overlays"
                    / "05_pauldron_masks_16x9"
                    / "masks"
                    / f"{view_name}_pauldron_mask.png"
                )
                if pauldron_src.exists():
                    shutil.copy2(pauldron_src, parts_dir / "body_core_pauldron_mask.png")

    return rect_disp
