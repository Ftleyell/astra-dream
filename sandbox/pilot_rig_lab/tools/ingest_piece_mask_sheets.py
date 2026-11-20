#!/usr/bin/env python3
"""Ingest AI-generated piece mask sheets (ID, Normal/Depth, or ILM) back into
Valentina v2's calibrated live assets with:
  - Automatic silhouette alignment (fixes 1-10 px AI drift/rescale)
  - Strict orthogonal palette quantization + 3x3 modal cleanup (kills neon AA halos)
  - Voronoi / Distance-Transform fill inside true piece alpha (eliminates black outline gaps)
  - Automatic horizontal mirroring SE->SW, E->W, NE->NW with L<->R swap (and Nx flip for normals)
  - Automatic visual audit contact sheet (`audit_<kind>.png`)

Usage:
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind id
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind normal
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind ilm --dry-run
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

WORK_SUBDIR = "06_piece_mask_regen"
IMAGE_EXTS: tuple[str, ...] = (".png", ".jpg", ".jpeg", ".webp")
MIRROR_VIEW_MAP: dict[str, str] = {"se": "sw", "e": "w", "ne": "nw"}
MIRROR_PART_SWAP: dict[str, str] = {
    "body_core": "body_core",
    "arm_r": "arm_l",
    "arm_l": "arm_r",
    "leg_r": "leg_l",
    "leg_l": "leg_r",
    "pauldron_r": "pauldron_l",
    "pauldron_l": "pauldron_r",
}

# Palettes in RGB order for nearest-color classification
# ID Mask: 0=Skin(#FFFF00), 1=Accent(#FF0000), 2=Armor(#00FF00), 3=Suit(#0000FF), 4=Hair/Stocking(#00FFFF)
ID_PALETTE_RGB = np.array([
    [255, 255, 0],    # 0: Skin
    [255, 0, 0],      # 1: Accent (R)
    [0, 255, 0],      # 2: Armor (G)
    [0, 0, 255],      # 3: Suit (B)
    [0, 255, 255],    # 4: Hair / Stockings (A)
], dtype=np.float32)

ID_TO_RGBA = np.array([
    [0, 0, 0, 0],       # 0: Skin -> (0,0,0,0)
    [255, 0, 0, 0],     # 1: Accent -> R
    [0, 255, 0, 0],     # 2: Armor -> G
    [0, 0, 255, 0],     # 3: Suit -> B
    [0, 0, 0, 255],     # 4: Hair/Stockings -> A
], dtype=np.uint8)

# ILM Mask: 0=Metal(#FF0000), 1=Satin(#00FFFF), 2=ShadowAO(#0000FF), 3=ProtectedSkin(#FFFF00), 4=Matte(#00FF00), 5=Emissive(#FF00FF)
ILM_PALETTE_RGB = np.array([
    [255, 0, 0],      # 0: Hard Specular Metal
    [0, 255, 255],    # 1: Satin / Nylon / Hair Angel Ring
    [0, 0, 255],      # 2: Permanent Cel Shadow / AO
    [255, 255, 0],    # 3: Protected Skin / Face
    [0, 255, 0],      # 4: Matte Suit / Base Hair
    [255, 0, 255],    # 5: Emissive Glow
], dtype=np.float32)

ILM_TO_RGBA = np.array([
    [255, 140, 255, 0],   # 0: Metal (R=1.0, G=0.55, B=1.0, A=0.0)
    [148, 133, 191, 0],   # 1: Satin/Nylon (R=0.58, G=0.52, B=0.75, A=0.0)
    [13, 20, 26, 0],      # 2: Shadow AO (R=0.05, G=0.08, B=0.10, A=0.0)
    [20, 235, 46, 0],     # 3: Protected Skin (R=0.08, G=0.92, B=0.18, A=0.0)
    [38, 128, 217, 0],    # 4: Matte Neutral (R=0.15, G=0.50, B=0.85, A=0.0)
    [230, 255, 255, 255], # 5: Emissive Glow (R=0.90, G=1.0, B=1.0, A=1.0)
], dtype=np.uint8)


def _find_output_file(out_dir: Path, stem: str) -> Path | None:
    for ext in IMAGE_EXTS:
        p = out_dir / f"{stem}{ext}"
        if p.exists():
            return p
    return None


def _bbox_of_mask(mask_bool: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask_bool)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _align_slot_to_orig(
    slot_bgr: np.ndarray,
    orig_bgra: np.ndarray,
    is_normal: bool,
    use_linear: bool = False,
) -> np.ndarray:
    """Align extracted AI slot image to the exact original piece dimensions using silhouette bbox fit."""
    oh, ow = orig_bgra.shape[:2]
    orig_fg = orig_bgra[:, :, 3] > 20
    ob = _bbox_of_mask(orig_fg)
    if ob is None:
        return cv2.resize(slot_bgr, (ow, oh), interpolation=cv2.INTER_LINEAR)

    if is_normal:
        # Foreground is pixels differing from neutral #8080FF (BGR 255, 128, 128)
        diff = np.linalg.norm(slot_bgr.astype(np.float32) - np.array([255.0, 128.0, 128.0]), axis=2)
        ai_fg = diff > 14.0
    else:
        # Foreground is non-white pixels
        ai_fg = np.min(slot_bgr, axis=2) < 238

    ab = _bbox_of_mask(ai_fg)
    if ab is None:
        return cv2.resize(slot_bgr, (ow, oh), interpolation=cv2.INTER_LINEAR)

    ox0, oy0, ox1, oy1 = ob
    ax0, ay0, ax1, ay1 = ab
    crop = slot_bgr[ay0:ay1, ax0:ax1]
    target_w = max(1, ox1 - ox0)
    target_h = max(1, oy1 - oy0)
    if is_normal or use_linear:
        interp = cv2.INTER_AREA if (target_w < crop.shape[1] or target_h < crop.shape[0]) else cv2.INTER_LINEAR
    else:
        interp = cv2.INTER_NEAREST
    resized_crop = cv2.resize(crop, (target_w, target_h), interpolation=interp)

    bg_val = (255, 128, 128) if is_normal else (255, 255, 255)
    aligned = np.full((oh, ow, 3), bg_val, dtype=np.uint8)
    aligned[oy0:oy1, ox0:ox1] = resized_crop
    return aligned


def _align_flipped_crop_to_orig(
    flipped_crop_bgr: np.ndarray,
    src_orig_bgra: np.ndarray,
    mir_orig_bgra: np.ndarray,
    use_linear: bool,
) -> np.ndarray:
    """Align a horizontally flipped crop from a canonical view to the mirrored view's exact PNG."""
    oh, ow = mir_orig_bgra.shape[:2]
    src_fg_flip = cv2.flip((src_orig_bgra[:, :, 3] > 20).astype(np.uint8), 1) > 0
    mir_fg = mir_orig_bgra[:, :, 3] > 20
    sb = _bbox_of_mask(src_fg_flip)
    mb = _bbox_of_mask(mir_fg)
    interp = cv2.INTER_LINEAR if use_linear else cv2.INTER_NEAREST
    if sb is None or mb is None:
        return cv2.resize(flipped_crop_bgr, (ow, oh), interpolation=interp)

    # First map flipped_crop_bgr into src_orig's exact flipped dimensions
    sh_s, sw_s = src_orig_bgra.shape[:2]
    if sh_s == oh and sw_s == ow and sb == mb:
        return cv2.resize(flipped_crop_bgr, (ow, oh), interpolation=interp)

    flipped_src_res = cv2.resize(flipped_crop_bgr, (sw_s, sh_s), interpolation=interp)
    sx0, sy0, sx1, sy1 = sb
    mx0, my0, mx1, my1 = mb
    sub = flipped_src_res[sy0:sy1, sx0:sx1]
    resized_sub = cv2.resize(sub, (max(1, mx1 - mx0), max(1, my1 - my0)), interpolation=interp)
    out = np.full((oh, ow, 3), (255, 255, 255), dtype=np.uint8)
    out[my0:my1, mx0:mx1] = resized_sub
    return out


def _extract_native_ink_mask(orig_bgra: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Detect real ink strokes in orig_bgra at native 1x resolution and return (ink_mask, luma)."""
    alpha = orig_bgra[:, :, 3]
    bgr = orig_bgra[:, :, :3].astype(np.float32)
    luma = (0.299 * bgr[:, :, 2] + 0.587 * bgr[:, :, 1] + 0.114 * bgr[:, :, 0]) / 255.0
    luma_u8 = np.clip(np.round(luma * 255.0), 0, 255).astype(np.uint8)
    kernel_3x3 = np.ones((3, 3), dtype=np.uint8)
    interior = cv2.erode((alpha > 180).astype(np.uint8) * 255, kernel_3x3, iterations=1) > 0
    ellipse_5x5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    blackhat = cv2.morphologyEx(luma_u8, cv2.MORPH_BLACKHAT, ellipse_5x5)
    ink_interior = ((luma < 0.145) | ((blackhat > 19) & (luma < 0.22))) & interior
    ink_edge = (alpha > 105) & (luma < 0.132)
    return (ink_interior | ink_edge), luma


def _voronoi_fill_labels(labels: np.ndarray, valid_mask: np.ndarray, target_mask: np.ndarray) -> np.ndarray:
    """Fill any invalid/outline pixels inside target_mask with the nearest valid label via distanceTransform."""
    out = labels.copy()
    need_fill = target_mask & (~valid_mask)
    if not np.any(need_fill) or not np.any(valid_mask):
        return out
    inv = np.where(valid_mask, 0, 255).astype(np.uint8)
    _, nearest_idx = cv2.distanceTransformWithLabels(inv, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    valid_ys, valid_xs = np.where(valid_mask)
    valid_classes = labels[valid_ys, valid_xs]
    fill_ys, fill_xs = np.where(need_fill)
    idx_1based = nearest_idx[fill_ys, fill_xs] - 1
    idx_1based = np.clip(idx_1based, 0, len(valid_classes) - 1)
    out[fill_ys, fill_xs] = valid_classes[idx_1based]
    return out


def _resolve_compartment_chromatic_class(
    maj_cls: int,
    m_cc: np.ndarray,
    orig_bgra: np.ndarray,
    allowed: np.ndarray | None,
    part_name: str,
    view_key: str,
    ilm_metal: np.ndarray | None,
) -> int:
    """Validate/correct a body compartment class using orig_bgra chromatic signature and ILM metal signal."""
    if part_name == "head" or allowed is None:
        return maj_cls
    alpha = orig_bgra[:, :, 3]
    interior = (alpha > 160) & m_cc
    probe = interior if int(interior.sum()) >= 12 else m_cc
    if not np.any(probe):
        return maj_cls

    obgr = orig_bgra[:, :, :3].astype(np.float32)
    luma = (0.299 * obgr[:, :, 2] + 0.587 * obgr[:, :, 1] + 0.114 * obgr[:, :, 0]) / 255.0
    m_rgb = obgr[probe][:, ::-1].mean(axis=0)
    ml = float(luma[probe].mean())
    rg = float(m_rgb[0] - m_rgb[1])
    rb = float(m_rgb[0] - m_rgb[2])
    ys = np.where(probe)[0]
    cy = float(ys.mean()) / max(float(orig_bgra.shape[0]), 1.0)
    metal_frac = float(ilm_metal[probe].mean()) if ilm_metal is not None else 0.0
    is_dark_rear = (view_key == "e" and part_name in ("arm_l", "leg_l")) or (
        view_key == "w" and part_name in ("arm_r", "leg_r")
    )

    if allowed[0] and ml > 0.38 and rb >= 18.0 and rg >= 14.0 and maj_cls != 4:
        return 0
    if maj_cls == 0 and (not allowed[0] or ml < 0.36 or rb < 14.0):
        return 2 if (allowed[2] and metal_frac > 0.60 and ml >= 0.24) else 3

    rg_thr = 11.5 if is_dark_rear else 17.0
    rb_thr = 7.5 if is_dark_rear else 11.5
    luma_acc_max = 0.25 if is_dark_rear else 0.34
    is_crimson = (rg >= rg_thr) and (rb >= rb_thr) and (ml < luma_acc_max)
    if maj_cls == 1 and part_name not in ("leg_r", "leg_l") and not is_crimson:
        return 2 if (allowed[2] and metal_frac > 0.65 and ml >= (0.18 if is_dark_rear else 0.27)) else 3
    if allowed[1] and maj_cls in (2, 3) and rg >= (12.5 if is_dark_rear else 20.0) and rb >= (8.0 if is_dark_rear else 13.5) and ml < luma_acc_max:
        if not (part_name in ("leg_r", "leg_l") and cy < 0.45):
            return 1

    if part_name == "body_core" and maj_cls == 2 and ilm_metal is not None:
        if metal_frac < 0.30 and (cy > 0.48 or ml < 0.23):
            return 3
    if part_name in ("leg_r", "leg_l") and cy > 0.46:
        arm_luma_min = 0.178 if is_dark_rear else 0.275
        if maj_cls == 3 and ilm_metal is not None and metal_frac > 0.60 and ml >= arm_luma_min and cy < 0.90:
            return 2
        if maj_cls == 2 and ml < (0.172 if is_dark_rear else 0.265) and (cy > 0.85 or metal_frac < 0.50):
            return 3

    return maj_cls


def _lock_compartments(
    labels: np.ndarray,
    valid: np.ndarray,
    orig_bgra: np.ndarray,
    allowed: np.ndarray | None,
    min_sub_area: int,
    small_cc_sub_area: int,
    chromatic_fallback: bool,
    part_name: str = "head",
    view_key: str = "",
    ilm_metal: np.ndarray | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    """Eliminate cross-line bleed within 4-connected ink compartments while preserving coherent sub-regions."""
    alpha = orig_bgra[:, :, 3]
    fg = alpha > 10
    ink_1x, luma = _extract_native_ink_mask(orig_bgra)
    barrier = cv2.morphologyEx((ink_1x | (alpha <= 20)).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
    n_cc, cc, _, _ = cv2.connectedComponentsWithStats((~barrier).astype(np.uint8), connectivity=4)

    obgr = orig_bgra[:, :, :3].astype(np.float32)
    interior = cv2.erode((alpha > 180).astype(np.uint8) * 255, np.ones((3, 3), np.uint8), iterations=1) > 0

    out = labels.copy()
    new_valid = valid.copy()
    for c in range(1, n_cc):
        m_cc = (cc == c) & fg
        if not np.any(m_cc):
            continue
        m_val = m_cc & valid
        v_cnt = int(m_val.sum())
        if v_cnt < 4:
            if chromatic_fallback and allowed is not None:
                cc_int = m_cc & interior
                if int(cc_int.sum()) >= 12:
                    m_rgb = obgr[cc_int][:, ::-1].mean(axis=0)
                    ml = float(luma[cc_int].mean())
                    if allowed[0] and ml > 0.45 and (m_rgb[0] - m_rgb[2]) > 22.0:
                        out[m_cc] = 0
                        new_valid[m_cc] = True
                        continue
                    if allowed[1] and (m_rgb[0] - m_rgb[1]) >= 20.0 and ml < 0.36:
                        out[m_cc] = 1
                        new_valid[m_cc] = True
                        continue
            new_valid[m_cc] = False
            continue

        u, cnts = np.unique(labels[m_val], return_counts=True)
        order = np.argsort(-cnts)
        maj_cls = int(u[order[0]])

        keep_classes = {maj_cls}
        for k_idx in order[1:]:
            k = int(u[k_idx])
            sub = m_val & (labels == k)
            n_s, _, sstats, _ = cv2.connectedComponentsWithStats(sub.astype(np.uint8), connectivity=8)
            max_sub = max([int(sstats[sc, cv2.CC_STAT_AREA]) for sc in range(1, n_s)], default=0)
            if max_sub >= min_sub_area or (v_cnt < 600 and float(cnts[k_idx]) / float(v_cnt) >= 0.25 and max_sub >= small_cc_sub_area):
                keep_classes.add(k)

        if len(keep_classes) == 1:
            resolved_cls = _resolve_compartment_chromatic_class(
                maj_cls, m_cc, orig_bgra, allowed, part_name, view_key, ilm_metal,
            )
            out[m_cc] = resolved_cls
            new_valid[m_cc] = True
        else:
            seed_cc = np.zeros_like(m_cc)
            min_blob = small_cc_sub_area if v_cnt < 600 else max(small_cc_sub_area, int(min_sub_area * 0.7))
            for k in keep_classes:
                sub = m_val & (labels == k)
                n_s, slbl, sstats, _ = cv2.connectedComponentsWithStats(sub.astype(np.uint8), connectivity=8)
                for sc in range(1, n_s):
                    if int(sstats[sc, cv2.CC_STAT_AREA]) >= min_blob:
                        m_blob = (slbl == sc)
                        res_k = _resolve_compartment_chromatic_class(
                            k, m_blob, orig_bgra, allowed, part_name, view_key, ilm_metal,
                        )
                        out[m_blob] = res_k
                        seed_cc |= m_blob
            if np.any(seed_cc):
                out = _voronoi_fill_labels(out, seed_cc, m_cc)
                new_valid[m_cc] = True
            else:
                out[m_cc] = _resolve_compartment_chromatic_class(
                    maj_cls, m_cc, orig_bgra, allowed, part_name, view_key, ilm_metal,
                )
                new_valid[m_cc] = True

    filled = _voronoi_fill_labels(out, new_valid, fg)
    return filled, new_valid


def _quantize_categorical_mask(
    aligned_bgr: np.ndarray,
    orig_bgra: np.ndarray,
    palette_rgb: np.ndarray,
    to_rgba: np.ndarray,
    kind: str,
    part_name: str,
    view_key: str = "",
    ilm_bgra: np.ndarray | None = None,
) -> np.ndarray:
    """Classify pixels to orthogonal palette, lock by 4-connected ink compartments, and Voronoi-fill."""
    rgb = cv2.cvtColor(aligned_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    alpha = orig_bgra[:, :, 3]
    fg = alpha > 10
    if not np.any(fg):
        return np.zeros_like(orig_bgra)

    obgr = orig_bgra[:, :, :3].astype(np.float32)
    oluma = (0.299 * obgr[:, :, 2] + 0.587 * obgr[:, :, 1] + 0.114 * obgr[:, :, 0]) / 255.0

    allowed: np.ndarray | None = None
    if kind == "id":
        allowed = np.ones(palette_rgb.shape[0], dtype=bool)
        if part_name == "head":
            # Heads only have Skin(0), Accent(1), Hair(4); Suit(3) is dark hair-shadow noise & B=255 is preserved from prev collar
            allowed[2] = False
            allowed[3] = False
        elif part_name in ("pauldron_r", "pauldron_l"):
            allowed[0] = False
            allowed[1] = False
            allowed[4] = False
        elif part_name in ("arm_r", "arm_l"):
            allowed[0] = False
            allowed[4] = False
        elif part_name == "body_core":
            allowed[4] = False

    dists = np.linalg.norm(rgb[:, :, None, :] - palette_rgb[None, None, :, :], axis=3)
    if allowed is not None:
        dists[:, :, ~allowed] = 1e6
    labels = np.argmin(dists, axis=2).astype(np.int32)
    dmin = np.min(dists, axis=2)

    c_max = np.max(rgb, axis=2)
    c_min = np.min(rgb, axis=2)
    sat = c_max - c_min
    is_white = (c_min > 215.0) & (sat < 35.0)
    is_dark_navy = (rgb[:, :, 2] >= 36.0) & ((rgb[:, :, 2] - rgb[:, :, 0]) >= 10.0) & ((rgb[:, :, 2] - rgb[:, :, 1]) >= 10.0)
    is_dark_outline = ((c_max < 75.0) | ((c_max < 130.0) & (sat < 45.0))) & (~is_dark_navy)

    if kind == "id":
        ilm_metal: np.ndarray | None = None
        if ilm_bgra is not None and ilm_bgra.shape[:2] == orig_bgra.shape[:2]:
            ilm_metal = (ilm_bgra[:, :, 2] > 200) & (ilm_bgra[:, :, 1] < 180)
        if allowed is not None and allowed[3] and part_name != "head":
            labels = np.where(is_dark_navy, 3, labels)
            dmin = np.where(is_dark_navy, 0.0, dmin)
        if allowed is not None and allowed[0]:
            r_minus_b = obgr[:, :, 2] - obgr[:, :, 0]
            fake_skin = (labels == 0) & ((oluma < 0.34) | (r_minus_b < 10.0))
        else:
            fake_skin = np.zeros_like(fg)
        valid = fg & (~is_white) & (~is_dark_outline) & (dmin < 75.0) & (~fake_skin)
        if part_name != "head" and allowed[1]:
            is_dark_rear = (view_key == "e" and part_name in ("arm_l", "leg_l")) or (
                view_key == "w" and part_name in ("arm_r", "leg_r")
            )
            rg_px = obgr[:, :, 2] - obgr[:, :, 1]
            rb_px = obgr[:, :, 2] - obgr[:, :, 0]
            rg_t = 12.0 if is_dark_rear else 18.0
            rb_t = 8.0 if is_dark_rear else 12.0
            lum_t = 0.25 if is_dark_rear else 0.34
            true_crim = fg & (alpha > 120) & (rg_px >= rg_t) & (rb_px >= rb_t) & (oluma < lum_t) & (labels != 4)
            if part_name in ("leg_r", "leg_l"):
                y_grid = np.linspace(0.0, 1.0, orig_bgra.shape[0], dtype=np.float32)[:, None]
                true_crim &= (y_grid > 0.44)
            n_cr, cr_lbl, cr_st, _ = cv2.connectedComponentsWithStats(true_crim.astype(np.uint8), connectivity=8)
            for sc in range(1, n_cr):
                if int(cr_st[sc, cv2.CC_STAT_AREA]) >= 120:
                    cmask = (cr_lbl == sc)
                    labels[cmask] = 1
                    valid[cmask] = True
            if part_name == "body_core" and ilm_metal is not None:
                y_grid = np.linspace(0.0, 1.0, orig_bgra.shape[0], dtype=np.float32)[:, None]
                false_arm = valid & (labels == 2) & (~ilm_metal) & ((y_grid > 0.48) | (oluma < 0.22))
                labels[false_arm] = 3
            elif part_name in ("leg_r", "leg_l") and ilm_metal is not None:
                y_grid = np.linspace(0.0, 1.0, orig_bgra.shape[0], dtype=np.float32)[:, None]
                arm_l_min = 0.178 if is_dark_rear else 0.285
                miss_arm = valid & (labels == 3) & ilm_metal & (y_grid > 0.46) & (y_grid < 0.90) & (oluma >= arm_l_min)
                labels[miss_arm] = 2
                boot_l_max = 0.172 if is_dark_rear else 0.265
                false_boot = valid & (labels == 2) & (y_grid > 0.85) & (oluma < boot_l_max)
                labels[false_boot] = 3

        filled, _ = _lock_compartments(
            labels, valid, orig_bgra, allowed,
            min_sub_area=140, small_cc_sub_area=40, chromatic_fallback=True,
            part_name=part_name, view_key=view_key, ilm_metal=ilm_metal,
        )
    else:
        valid = fg & (~is_white) & (~is_dark_outline) & (dmin < 85.0)
        if part_name in ("leg_r", "leg_l") and view_key == "n":
            y_grid = np.linspace(0.0, 1.0, orig_bgra.shape[0], dtype=np.float32)[:, None]
            matte_heel = valid & (labels == 0) & (y_grid > 0.81) & (oluma < 0.275)
            labels[matte_heel] = 4
        filled, _ = _lock_compartments(
            labels, valid, orig_bgra, None,
            min_sub_area=80, small_cc_sub_area=30, chromatic_fallback=False,
        )

    rgba = to_rgba[filled]
    rgba[~fg] = 0
    bgra = np.stack([rgba[:, :, 2], rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 3]], axis=2)
    return bgra


def _process_normal_depth(aligned_bgr: np.ndarray, orig_bgra: np.ndarray) -> np.ndarray:
    """Normalize tangent-space RGB normals, enforce Nz >= 0.15, and synthesize clean depth in alpha."""
    rgb = cv2.cvtColor(aligned_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    alpha = orig_bgra[:, :, 3]
    fg = alpha > 10

    # Gentle edge-preserving bilateral smooth to remove AI compression noise without blurring bevels
    smooth_rgb = cv2.bilateralFilter(rgb.astype(np.uint8), d=5, sigmaColor=22, sigmaSpace=5).astype(np.float32)

    # Decode to [-1, 1], clamp Z >= 0.15, renormalize
    n = (smooth_rgb / 255.0) * 2.0 - 1.0
    n[:, :, 2] = np.maximum(n[:, :, 2], 0.15)
    norm = np.linalg.norm(n, axis=2, keepdims=True)
    n = n / np.maximum(norm, 1e-5)

    # Distance-based rounded depth in alpha channel (0..255)
    dist = cv2.distanceTransform(fg.astype(np.uint8), cv2.DIST_L2, 5)
    max_d = max(float(dist.max()), 1.0)
    depth = np.clip(np.sqrt(dist / max_d) * 255.0, 0.0, 255.0).astype(np.uint8)
    depth[~fg] = 0

    enc = np.clip(np.round((n * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    enc[~fg] = np.array([128, 128, 255], dtype=np.uint8)
    bgra = np.stack([enc[:, :, 2], enc[:, :, 1], enc[:, :, 0], depth], axis=2)
    return bgra


INK_SDF_RANGE_PX = 8.0


def _process_ink_sdf(orig_bgra: np.ndarray) -> np.ndarray:
    """Extract real dark ink strokes directly from orig_bgra (0.0 px drift) and encode a 2x-supersampled SDF.

    Encoding (8-bit grayscale stored in RGB, A=255):
      - 0.5 (128) = exact stroke boundary (signed_dist = 0 px)
      - < 0.5     = inside ink stroke (signed_dist < 0 px)
      - > 0.5     = outside ink stroke (signed_dist > 0 px, clamped at +INK_SDF_RANGE_PX)
    """
    oh, ow = orig_bgra.shape[:2]
    alpha = orig_bgra[:, :, 3].astype(np.float32)
    if not np.any(alpha > 20.0):
        return np.full((oh, ow, 4), 255, dtype=np.uint8)

    bgr = orig_bgra[:, :, :3].astype(np.float32)
    luma = (0.299 * bgr[:, :, 2] + 0.587 * bgr[:, :, 1] + 0.114 * bgr[:, :, 0]) / 255.0
    luma_u8 = np.clip(np.round(luma * 255.0), 0, 255).astype(np.uint8)
    ellipse_5x5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    blackhat = cv2.morphologyEx(luma_u8, cv2.MORPH_BLACKHAT, ellipse_5x5).astype(np.float32)

    interior_1x = cv2.erode((alpha > 180.0).astype(np.uint8) * 255, np.ones((3, 3), dtype=np.uint8), iterations=1)
    luma_2x = cv2.resize(luma, (ow * 2, oh * 2), interpolation=cv2.INTER_CUBIC)
    alpha_2x = cv2.resize(alpha, (ow * 2, oh * 2), interpolation=cv2.INTER_LINEAR)
    blackhat_2x = cv2.resize(blackhat, (ow * 2, oh * 2), interpolation=cv2.INTER_LINEAR)
    interior_2x = cv2.resize(interior_1x, (ow * 2, oh * 2), interpolation=cv2.INTER_NEAREST) > 128

    ink_interior_2x = ((luma_2x < 0.145) | ((blackhat_2x > 19.0) & (luma_2x < 0.22))) & interior_2x
    ink_edge_2x = (alpha_2x > 105.0) & (luma_2x < 0.132)
    ink_2x = ink_interior_2x | ink_edge_2x

    if not np.any(ink_2x):
        return np.full((oh, ow, 4), 255, dtype=np.uint8)

    d_out_2x = cv2.distanceTransform((~ink_2x).astype(np.uint8), cv2.DIST_L2, 5) * 0.5
    d_in_2x = cv2.distanceTransform(ink_2x.astype(np.uint8), cv2.DIST_L2, 5) * 0.5
    sdf_2x = d_out_2x - d_in_2x
    sdf = cv2.resize(sdf_2x, (ow, oh), interpolation=cv2.INTER_AREA)

    norm = np.clip(0.5 + sdf / (2.0 * INK_SDF_RANGE_PX), 0.0, 1.0)
    u8 = np.clip(np.round(norm * 255.0), 0, 255).astype(np.uint8)
    alpha_full = np.full((oh, ow), 255, dtype=np.uint8)
    return np.stack([u8, u8, u8, alpha_full], axis=2)


def _mirror_mask(bgra: np.ndarray, kind: str) -> np.ndarray:
    flipped = cv2.flip(bgra, 1)
    if kind == "normal":
        # Invert Nx stored in R channel (index 2 in BGRA)
        flipped = flipped.copy()
        flipped[:, :, 2] = 255 - flipped[:, :, 2]
    return flipped


def _dest_path_for(assets_dir: Path, slot: dict, kind: str, mirrored: bool = False) -> Path:
    suffix = {"id": "id_mask", "normal": "normal_depth", "ilm": "ilm_mask", "ink": "ink_sdf"}[kind]
    if slot["kind"] == "head":
        return assets_dir / "heads" / f"{slot['head_key']}_{suffix}.png"
    view = MIRROR_VIEW_MAP[slot["view"]] if mirrored else slot["view"]
    part = MIRROR_PART_SWAP[slot["part"]] if mirrored else slot["part"]
    return assets_dir / view / "parts_5" / f"{part}_{suffix}.png"


def _close_head_collar_blue_trenches(collar_mask: np.ndarray, allowed_mask: np.ndarray) -> np.ndarray:
    """Close 2-4px dark-outline trenches inside the collar blue mask so Pass 2 never leaks neck ink over torso."""
    u8 = collar_mask.astype(np.uint8) * 255
    k_horiz = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 1))
    k_diag = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 5))
    closed_h = cv2.morphologyEx(u8, cv2.MORPH_CLOSE, k_horiz) > 127
    closed_d = cv2.morphologyEx(u8, cv2.MORPH_CLOSE, k_diag) > 127
    return (collar_mask | closed_h | closed_d) & allowed_mask


def _preserve_head_collar_blue(mask_bgra: np.ndarray, dst_path: Path) -> np.ndarray:
    """Preserve existing collar blue (B=255) in head *_id_mask.png without creating dirty multi-channel overlap."""
    if not dst_path.exists():
        mask_bgra[:, :, 0] = 0
        return mask_bgra
    prev_m = cv2.imread(str(dst_path), cv2.IMREAD_UNCHANGED)
    if prev_m is None or prev_m.shape != mask_bgra.shape:
        mask_bgra[:, :, 0] = 0
        return mask_bgra
    prev_collar = (prev_m[:, :, 0] > 128) & (prev_m[:, :, 1] < 128) & (prev_m[:, :, 2] < 128) & (prev_m[:, :, 3] < 128)
    not_hair_or_red = (mask_bgra[:, :, 3] < 128) & (mask_bgra[:, :, 2] < 128) & (mask_bgra[:, :, 1] < 128)
    apply_collar = _close_head_collar_blue_trenches(prev_collar, not_hair_or_red)
    out = mask_bgra.copy()
    out[:, :, 0] = 0
    out[apply_collar] = [255, 0, 0, 0]
    return out


def _sync_head_side_from_r(assets_dir: Path, kind: str, dry_run: bool) -> int:
    """Copy/extend head_side_r_* mask to head_side_* matching head_side.png exact dimensions."""
    suffix = {"id": "id_mask", "ilm": "ilm_mask"}[kind]
    heads_dir = assets_dir / "heads"
    src_mask_p = heads_dir / f"head_side_r_{suffix}.png"
    dst_mask_p = heads_dir / f"head_side_{suffix}.png"
    orig_side_p = heads_dir / "head_side.png"
    if not src_mask_p.exists() or not orig_side_p.exists():
        return 0
    src_mask = cv2.imread(str(src_mask_p), cv2.IMREAD_UNCHANGED)
    orig_side = cv2.imread(str(orig_side_p), cv2.IMREAD_UNCHANGED)
    if src_mask is None or orig_side is None:
        return 0

    oh, ow = orig_side.shape[:2]
    sh, sw = src_mask.shape[:2]
    out = np.zeros((oh, ow, 4), dtype=np.uint8)
    copy_h = min(oh, sh)
    copy_w = min(ow, sw)
    out[:copy_h, :copy_w] = src_mask[:copy_h, :copy_w]

    # Fill any extra lower neck pixels in head_side.png via Voronoi from valid mask pixels
    fg = orig_side[:, :, 3] > 10
    if kind == "id":
        orig_r = cv2.imread(str(heads_dir / "head_side_r.png"), cv2.IMREAD_UNCHANGED)
        r_fg = (orig_r[:, :, 3] > 10) if orig_r is not None else np.zeros((sh, sw), dtype=bool)
        seed = np.zeros((oh, ow), dtype=bool)
        seed[:copy_h, :copy_w] = r_fg[:copy_h, :copy_w]
        need_fill = fg & (~seed)
        if np.any(need_fill) and np.any(seed):
            inv = np.where(seed, 0, 255).astype(np.uint8)
            _, nearest_idx = cv2.distanceTransformWithLabels(inv, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
            sy, sx = np.where(seed)
            fy, fx = np.where(need_fill)
            idx = np.clip(nearest_idx[fy, fx] - 1, 0, len(sy) - 1)
            out[fy, fx] = out[sy[idx], sx[idx]]
        out[~fg] = 0
        out = _preserve_head_collar_blue(out, dst_mask_p)
    else:
        seed = np.any(out > 0, axis=2) & fg
        need_fill = fg & (~seed)
        if np.any(need_fill) and np.any(seed):
            inv = np.where(seed, 0, 255).astype(np.uint8)
            _, nearest_idx = cv2.distanceTransformWithLabels(inv, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
            sy, sx = np.where(seed)
            fy, fx = np.where(need_fill)
            idx = np.clip(nearest_idx[fy, fx] - 1, 0, len(sy) - 1)
            out[fy, fx] = out[sy[idx], sx[idx]]
        out[~fg] = 0

    if not dry_run:
        cv2.imwrite(str(dst_mask_p), out)
    return 1


def _make_audit_tile(orig_bgra: np.ndarray, mask_bgra: np.ndarray, kind: str) -> np.ndarray:
    """Create a 3-column [Original | Mask | Overlay] preview tile (220px tall)."""
    th = 220
    oh, ow = orig_bgra.shape[:2]
    tw = max(48, int(round(ow * (th / max(oh, 1)))))

    orig_rgb = orig_bgra[:, :, :3].copy()
    orig_a = orig_bgra[:, :, 3:4].astype(np.float32) / 255.0
    orig_vis = np.clip(orig_rgb * orig_a + 32.0 * (1.0 - orig_a), 0, 255).astype(np.uint8)

    if kind == "id":
        # Visualize A channel (hair/stockings) as Cyan and Skin (0,0,0,0) as warm Yellow inside alpha
        m_vis = mask_bgra[:, :, :3].copy()
        a_ch = mask_bgra[:, :, 3]
        has_a = a_ch > 128
        m_vis[has_a] = (255, 255, 0)  # BGR Cyan
        is_skin = (orig_bgra[:, :, 3] > 20) & (np.max(mask_bgra, axis=2) < 30)
        m_vis[is_skin] = (0, 230, 255)  # BGR Yellow
        overlay = cv2.addWeighted(orig_vis, 0.50, m_vis, 0.50, 0.0)
    elif kind == "ink":
        sdf_px = (mask_bgra[:, :, 0].astype(np.float32) / 255.0 - 0.5) * (2.0 * INK_SDF_RANGE_PX)
        ink_w = np.clip(1.0 - (sdf_px + 0.25) / 0.85, 0.0, 1.0) * (orig_bgra[:, :, 3] > 15).astype(np.float32)
        m_gray = np.clip(np.round((1.0 - ink_w) * 255.0), 0, 255).astype(np.uint8)
        m_vis = np.stack([m_gray, m_gray, m_gray], axis=2)
        # Overlay crisp cyan ink directly on original to verify 0-drift alignment
        ov = orig_vis.astype(np.float32)
        cyan = np.array([255.0, 255.0, 0.0], dtype=np.float32)
        overlay = np.clip(ov * (1.0 - ink_w[:, :, None] * 0.85) + cyan * (ink_w[:, :, None] * 0.85), 0, 255).astype(np.uint8)
    else:
        m_vis = mask_bgra[:, :, :3].copy()
        overlay = cv2.addWeighted(orig_vis, 0.50, m_vis, 0.50, 0.0)

    t1 = cv2.resize(orig_vis, (tw, th), interpolation=cv2.INTER_AREA)
    t2 = cv2.resize(m_vis, (tw, th), interpolation=cv2.INTER_AREA if kind == "ink" else cv2.INTER_NEAREST)
    t3 = cv2.resize(overlay, (tw, th), interpolation=cv2.INTER_AREA)
    return np.hstack([t1, t2, t3])


def _run_ink_native_all(assets_dir: Path, work_root: Path, dry_run: bool) -> tuple[int, int]:
    """Generate all 65 *_ink_sdf.png files algorithmically from native live piece & head PNGs (0.0 px drift)."""
    views = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
    parts = ("body_core", "arm_r", "arm_l", "leg_r", "leg_l", "pauldron_r", "pauldron_l")
    heads = (
        "head_front", "head_front_l", "head_front_r",
        "head_side", "head_side_l", "head_side_r",
        "head_back", "head_back_l", "head_back_r",
    )

    written = 0
    audit_tiles: list[np.ndarray] = []

    for v in views:
        for p in parts:
            src_p = assets_dir / v / "parts_5" / f"{p}.png"
            if not src_p.exists():
                continue
            orig_bgra = cv2.imread(str(src_p), cv2.IMREAD_UNCHANGED)
            if orig_bgra is None:
                continue
            sdf_bgra = _process_ink_sdf(orig_bgra)
            dst_p = assets_dir / v / "parts_5" / f"{p}_ink_sdf.png"
            if not dry_run:
                cv2.imwrite(str(dst_p), sdf_bgra)
            written += 1
            if len(audit_tiles) < 12 and orig_bgra.shape[0] > 16:
                audit_tiles.append(_make_audit_tile(orig_bgra, sdf_bgra, "ink"))

    for hk in heads:
        src_h = assets_dir / "heads" / f"{hk}.png"
        if not src_h.exists():
            continue
        orig_bgra = cv2.imread(str(src_h), cv2.IMREAD_UNCHANGED)
        if orig_bgra is None:
            continue
        sdf_bgra = _process_ink_sdf(orig_bgra)
        dst_h = assets_dir / "heads" / f"{hk}_ink_sdf.png"
        if not dry_run:
            cv2.imwrite(str(dst_h), sdf_bgra)
        written += 1
        if len(audit_tiles) < 16:
            audit_tiles.append(_make_audit_tile(orig_bgra, sdf_bgra, "ink"))

    if audit_tiles:
        max_w = max(t.shape[1] for t in audit_tiles)
        padded = [
            cv2.copyMakeBorder(t, 4, 4, 4, max_w - t.shape[1] + 4, cv2.BORDER_CONSTANT, value=(24, 28, 36))
            for t in audit_tiles
        ]
        audit_path = work_root / "audit_ink.png"
        cv2.imwrite(str(audit_path), np.vstack(padded))
        print(f"[AUDIT] Guardado: {audit_path}")

    print(f"[INK:NATIVE] {written} *_ink_sdf.png generados en resolución nativa (0.0 px deriva).")
    return 0, written


def _run_sheet_kind(kind: str, assets_dir: Path, work_root: Path, manifest: dict[str, dict], dry_run: bool) -> tuple[int, int]:
    if kind == "ink":
        return _run_ink_native_all(assets_dir, work_root, dry_run)

    out_dir = work_root / f"outputs_{kind}"
    if not out_dir.exists():
        raise FileNotFoundError(f"Missing output directory: {out_dir}")

    processed_sheets = 0
    written_files = 0
    audit_tiles: list[np.ndarray] = []

    for sheet_name, s_meta in manifest.items():
        ai_path = _find_output_file(out_dir, sheet_name)
        if ai_path is None:
            print(f"[SKIP] No encontrado en {out_dir.name}/: {sheet_name}.(png/jpg/webp)")
            continue

        ai_bgr = cv2.imread(str(ai_path), cv2.IMREAD_COLOR)
        if ai_bgr is None:
            print(f"[WARN] No se pudo leer {ai_path}")
            continue

        exp_w, exp_h = int(s_meta["size"][0]), int(s_meta["size"][1])
        if ai_bgr.shape[1] != exp_w or ai_bgr.shape[0] != exp_h:
            interp = cv2.INTER_LINEAR if kind in ("normal", "ilm") else cv2.INTER_NEAREST
            ai_bgr = cv2.resize(ai_bgr, (exp_w, exp_h), interpolation=interp)

        processed_sheets += 1
        for slot in s_meta["slots"]:
            orig_path = Path(slot["source_rel"])
            orig_bgra = cv2.imread(str(orig_path), cv2.IMREAD_UNCHANGED)
            if orig_bgra is None:
                raise FileNotFoundError(f"Missing source piece: {orig_path}")
            oh, ow = orig_bgra.shape[:2]

            if kind in ("id", "ilm"):
                dx, dy, nw, nh = [int(v) for v in slot["piece_rect"]]
                crop_bgr = ai_bgr[dy : dy + nh, dx : dx + nw]
                interp = cv2.INTER_NEAREST if kind == "id" else cv2.INTER_LINEAR
                aligned = cv2.resize(crop_bgr, (ow, oh), interpolation=interp)
                part_name = slot.get("part", "head") if slot["kind"] == "body" else "head"
                view_key = slot.get("view", "") if slot["kind"] == "body" else ""
                pal = ID_PALETTE_RGB if kind == "id" else ILM_PALETTE_RGB
                to_rgba = ID_TO_RGBA if kind == "id" else ILM_TO_RGBA
                ilm_bgra = None
                if kind == "id" and slot["kind"] == "body":
                    ilm_p = _dest_path_for(assets_dir, slot, "ilm", mirrored=False)
                    if ilm_p.exists():
                        ilm_bgra = cv2.imread(str(ilm_p), cv2.IMREAD_UNCHANGED)
                mask_bgra = _quantize_categorical_mask(
                    aligned, orig_bgra, pal, to_rgba, kind, part_name, view_key=view_key, ilm_bgra=ilm_bgra,
                )
            else:
                sx, sy, sw, sh = [int(v) for v in slot["slot_rect"]]
                slot_bgr = ai_bgr[sy : sy + sh, sx : sx + sw]
                aligned = _align_slot_to_orig(slot_bgr, orig_bgra, is_normal=True, use_linear=False)
                mask_bgra = _process_normal_depth(aligned, orig_bgra)

            dst = _dest_path_for(assets_dir, slot, kind, mirrored=False)
            if kind == "id" and slot["kind"] == "head":
                mask_bgra = _preserve_head_collar_blue(mask_bgra, dst)
            if not dry_run:
                cv2.imwrite(str(dst), mask_bgra)
            written_files += 1
            if len(audit_tiles) < 16:
                audit_tiles.append(_make_audit_tile(orig_bgra, mask_bgra, kind))

            # Auto-mirror SE->SW, E->W, NE->NW for body pieces against exact mirrored piece PNG
            if slot["kind"] == "body" and slot["view"] in MIRROR_VIEW_MAP:
                mir_dst = _dest_path_for(assets_dir, slot, kind, mirrored=True)
                mir_view = MIRROR_VIEW_MAP[slot["view"]]
                mir_part = MIRROR_PART_SWAP[slot["part"]]
                mir_orig_path = assets_dir / mir_view / "parts_5" / f"{mir_part}.png"
                if kind in ("id", "ilm") and mir_orig_path.exists():
                    mir_orig_bgra = cv2.imread(str(mir_orig_path), cv2.IMREAD_UNCHANGED)
                    dx, dy, nw, nh = [int(v) for v in slot["piece_rect"]]
                    flipped_crop = cv2.flip(ai_bgr[dy : dy + nh, dx : dx + nw], 1)
                    mir_aligned = _align_flipped_crop_to_orig(
                        flipped_crop, orig_bgra, mir_orig_bgra, use_linear=(kind == "ilm"),
                    )
                    mir_ilm_bgra = None
                    if kind == "id":
                        mir_ilm_p = _dest_path_for(assets_dir, slot, "ilm", mirrored=True)
                        if mir_ilm_p.exists():
                            mir_ilm_bgra = cv2.imread(str(mir_ilm_p), cv2.IMREAD_UNCHANGED)
                    mir_bgra = _quantize_categorical_mask(
                        mir_aligned, mir_orig_bgra, pal, to_rgba, kind, mir_part, view_key=mir_view, ilm_bgra=mir_ilm_bgra,
                    )
                else:
                    mir_bgra = _mirror_mask(mask_bgra, kind)
                if not dry_run:
                    cv2.imwrite(str(mir_dst), mir_bgra)
                written_files += 1

        print(f"[INGEST:{kind.upper()}] {ai_path.name} -> {len(s_meta['slots'])} piezas procesadas")

    if kind in ("id", "ilm"):
        written_files += _sync_head_side_from_r(assets_dir, kind, dry_run)

    if audit_tiles:
        max_w = max(t.shape[1] for t in audit_tiles)
        padded = [
            cv2.copyMakeBorder(t, 4, 4, 4, max_w - t.shape[1] + 4, cv2.BORDER_CONSTANT, value=(24, 28, 36))
            for t in audit_tiles
        ]
        audit_img = np.vstack(padded)
        audit_path = work_root / f"audit_{kind}.png"
        cv2.imwrite(str(audit_path), audit_img)
        print(f"[AUDIT] Guardado: {audit_path}")

    return processed_sheets, written_files


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest AI piece mask sheets into Valentina v2 live assets.")
    parser.add_argument("--kind", default="all", choices=["all", "id", "normal", "ilm", "ink"])
    parser.add_argument("--dry-run", action="store_true", help="Validate & generate audit without overwriting assets.")
    args = parser.parse_args()

    assets_dir = DEFAULT_OUT_DIR
    work_root = DEFAULT_SOURCE_DIR / WORK_SUBDIR
    manifest_path = work_root / "piece_sheets_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"Missing manifest: {manifest_path}. Run export_piece_mask_sheets.py first.")

    manifest: dict[str, dict] = json.loads(manifest_path.read_text(encoding="utf-8"))
    kinds = ["ilm", "id", "ink"] if args.kind == "all" else [args.kind]
    total_sheets = 0
    total_written = 0
    for k in kinds:
        sh_cnt, wr_cnt = _run_sheet_kind(k, assets_dir, work_root, manifest, args.dry_run)
        total_sheets += sh_cnt
        total_written += wr_cnt

    mode_str = "DRY-RUN" if args.dry_run else "APLICADO"
    print(f"\nResumen ({mode_str}): {total_sheets} hojas procesadas, {total_written} máscaras {'simuladas' if args.dry_run else 'escritas'}.")


if __name__ == "__main__":
    main()
