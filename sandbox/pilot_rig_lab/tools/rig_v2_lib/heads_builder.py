"""Decoupled 8-dir head carving, neck-cut alignment, SDF outline generation, and metadata."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import cv2
import numpy as np
import scipy.ndimage as ndimage

from polish_outlines import HEAD_PAD_PX, _voronoi_fill, alpha_bleed_only
from process_head_8dir_sheet import _build_clean_head_normal_depth, _build_hair_jiggle_mask
from process_masked_5parts import TEX_SCALE

from .constants import (
    CANONICAL_W,
    DIRECTIONS,
    HEAD_OUTLINE_DEFAULT_PX,
    HEAD_SCALE_FACTOR,
    HEAD_SDF_MAX_DIST_PX,
    HEAD_TARGET_DENSITY_PX_H,
    PX_H,
    PX_W,
    VIEW_TO_HEAD_KEY,
    _canonical_rgba_path,
)


def _extract_hair_and_clean_head_id(
    head_rgba: np.ndarray, id_bgra: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Separate main scalp hair CC + legitimate brows from tiny specular noise in head id_mask."""
    fg = head_rgba[:, :, 3] > 24
    raw_hair = (id_bgra[:, :, 3] > 128) & fg
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(raw_hair.astype(np.uint8))

    hair_main = np.zeros_like(raw_hair)
    hair_for_id = np.zeros_like(raw_hair)
    if n_cc > 1:
        main_cc = max(range(1, n_cc), key=lambda i: int(stats[i, cv2.CC_STAT_AREA]))
        hair_main = lbl == main_cc
        hair_for_id |= hair_main
        for cc in range(1, n_cc):
            if cc == main_cc:
                continue
            area = int(stats[cc, cv2.CC_STAT_AREA])
            y0 = int(stats[cc, cv2.CC_STAT_TOP])
            y1 = y0 + int(stats[cc, cv2.CC_STAT_HEIGHT])
            # Keep eyebrows inside face band; drop collar/shoulder specular specks
            if area >= 150 and y1 < 540:
                hair_for_id |= (lbl == cc)

    clean_id = id_bgra.copy()
    dropped = raw_hair & (~hair_for_id)
    if np.any(dropped):
        valid_non_drop = fg & (~dropped)
        if np.any(valid_non_drop):
            clean_id = _voronoi_fill(clean_id, valid_non_drop)
            clean_id[dropped, 3] = 0
    return clean_id, hair_for_id, hair_main


def _carve_head_neck_stub(
    head_rgba: np.ndarray, id_bgra: np.ndarray, hair_main: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray, tuple[int, int, int, int]]:
    """Strip suit neck/collar stump completely while preserving 100% of hair, face, monocle, and jawline outline."""
    fg = head_rgba[:, :, 3] > 24
    blue = (id_bgra[:, :, 0] > 128) & (id_bgra[:, :, 1] < 90) & (id_bgra[:, :, 2] < 90) & fg
    red = (id_bgra[:, :, 2] > 128) & (id_bgra[:, :, 1] < 90) & (id_bgra[:, :, 0] < 90) & fg

    bys = np.where(blue)[0]
    b_top = int(bys.min()) if len(bys) > 0 else 610

    lefts: list[float] = []
    rights: list[float] = []
    for y in range(b_top + 30, min(1024, b_top + 66)):
        xs = np.where(blue[y])[0]
        if len(xs) > 30:
            lefts.append(float(xs.min()))
            rights.append(float(xs.max()))
    if lefts and rights:
        nx0 = float(np.median(lefts))
        nx1 = min(float(np.median(rights)), nx0 + 188.0)
        nw = max(140.0, nx1 - nx0)
    else:
        nw = 175.0

    r_strap = red.copy()
    r_strap[:600, :] = False
    rys = np.where(r_strap)[0]
    strap_y0 = int(rys.min()) if len(rys) > 0 else b_top + 135

    flare_y = strap_y0 + 12
    for y in range(b_top + 58, min(1000, strap_y0 + 30)):
        xs = np.where(blue[y])[0]
        if len(xs) > 30 and (xs.max() - xs.min()) > nw * 1.44:
            flare_y = y
            break

    hh, ww = fg.shape
    yy, xx = np.mgrid[:hh, :ww].astype(np.float32)

    # Keep all upper-head skin (face, enclosed ears, forehead slits) above collarbone + outer chin contour; exclude lower cleavage
    skin_all = fg & (~hair_main) & (~blue) & (~red)
    luma_u8 = (
        0.114 * head_rgba[:, :, 0].astype(np.float32)
        + 0.587 * head_rgba[:, :, 1].astype(np.float32)
        + 0.299 * head_rgba[:, :, 2].astype(np.float32)
    )
    b_ch = head_rgba[:, :, 0].astype(np.float32)
    r_ch = head_rgba[:, :, 2].astype(np.float32)
    blue_neck_zone = cv2.dilate(blue.astype(np.uint8), np.ones((35, 35), np.uint8)) > 0
    non_warm_neck = ((blue_neck_zone & (yy >= float(b_top - 4))) | (yy >= float(b_top + 78))) & ((r_ch < b_ch + 14.0) | (luma_u8 < 82.0))
    face_skin = skin_all & (yy <= float(min(b_top + 115, flare_y + 2))) & (~non_warm_neck)
    face_skin = ndimage.binary_fill_holes(face_skin) & fg
    if np.any(face_skin):
        n_fs, lbl_fs, st_fs, _ = cv2.connectedComponentsWithStats(face_skin.astype(np.uint8), connectivity=8)
        if n_fs > 2:
            main_fs = max(range(1, n_fs), key=lambda i: int(st_fs[i, cv2.CC_STAT_AREA]))
            valid_fs = lbl_fs == main_fs
            for i_cc in range(1, n_fs):
                if int(st_fs[i_cc, cv2.CC_STAT_AREA]) >= 800 and int(st_fs[i_cc, cv2.CC_STAT_TOP]) < b_top:
                    valid_fs |= lbl_fs == i_cc
            face_skin = valid_fs | (face_skin & (yy < float(b_top - 15)))
    # Preserve outer dark jawline/chin contour (~3px) around face_skin & hair_main, excluding blue neck suit & pale smudges
    dark_ink = luma_u8 < 96.0
    blue_near = (
        (cv2.dilate(blue.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)
        & (yy >= float(b_top + 6))
        & ((r_ch < b_ch + 10.0) & (luma_u8 >= 48.0))
    )
    jaw_outline = (cv2.dilate(face_skin.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & fg & (~blue) & (~blue_near) & dark_ink
    hair_outline = (cv2.dilate(hair_main.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0) & fg & (~blue) & (~blue_near) & (luma_u8 < 68.0)
    monocle = red & (yy <= float(b_top + 48))

    face_closed = ndimage.binary_fill_holes(face_skin | jaw_outline | monocle) & fg & (~blue)
    keep = fg & (hair_main | face_closed | hair_outline)
    # Break thin 1px dark collarbone bridges and keep strictly largest head component
    keep_opened = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
    n_k, lbl_k, st_k, _ = cv2.connectedComponentsWithStats(keep_opened.astype(np.uint8))
    if n_k > 1:
        largest_k = max(range(1, n_k), key=lambda i: int(st_k[i, cv2.CC_STAT_AREA]))
        keep = keep & ((lbl_k == largest_k) | (cv2.dilate((lbl_k == largest_k).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0))
    n_k2, lbl_k2, st_k2, _ = cv2.connectedComponentsWithStats(keep.astype(np.uint8), connectivity=8)
    if n_k2 > 2:
        largest_k2 = max(range(1, n_k2), key=lambda i: int(st_k2[i, cv2.CC_STAT_AREA]))
        keep = lbl_k2 == largest_k2

    # Feather ONLY along internal synthetic neck cut without eroding original head/hair outline
    carved = head_rgba.copy()
    cut_band = (~keep) & fg
    if np.any(cut_band):
        dist_to_cut = cv2.distanceTransform((~cut_band).astype(np.uint8), cv2.DIST_L2, 5)
        feather = np.clip((dist_to_cut - 0.5) / 2.5, 0.0, 1.0)
        new_a = np.where(keep, np.minimum(carved[:, :, 3].astype(np.float32), feather * 255.0), 0.0)
        carved[:, :, 3] = np.clip(new_a, 0, 255).astype(np.uint8)

    carved_id = id_bgra.copy()
    carved_id[~keep] = 0

    ys, xs = np.where(carved[:, :, 3] > 8)
    x0, y0 = int(xs.min()), int(ys.min())
    x1, y1 = int(xs.max()) + 1, int(ys.max()) + 1
    return carved[y0:y1, x0:x1], carved_id[y0:y1, x0:x1], hair_main[y0:y1, x0:x1], (x0, y0, x1 - x0, y1 - y0)


def _align_head_to_body_canonical(
    stub_rgba: np.ndarray, hair_main: np.ndarray, body_rgba: np.ndarray
) -> tuple[float, float, float, float]:
    """Match carved head silhouette onto the upper head region of the canonical body image."""
    sh, sw = stub_rgba.shape[:2]
    # Use upper 72% (hair crown + upper face silhouette) which matches body_rgba top identically
    match_h = max(16, int(round(sh * 0.72)))
    head_sil_full = ((stub_rgba[:, :, 3] > 64) | hair_main)[:match_h, :].astype(np.float32)

    roi_y0, roi_y1 = 270, 620
    roi_x0, roi_x1 = 490, 1070
    body_roi = (body_rgba[roi_y0:roi_y1, roi_x0:roi_x1, 3] > 64).astype(np.float32)

    # Work at canonical 1x scale (divide by TEX_SCALE) for speed and sub-unit precision
    rw_1x = max(16, (roi_x1 - roi_x0) // TEX_SCALE)
    rh_1x = max(16, (roi_y1 - roi_y0) // TEX_SCALE)
    roi_1x = cv2.resize(body_roi, (rw_1x, rh_1x), interpolation=cv2.INTER_AREA)

    best_score = -1.0
    best_rect = (float(CANONICAL_W) * 0.5 - 44.0, 104.0, 88.0, 92.0)

    # Full carved head height in 1x canonical spans ~82..106 canonical units
    for cand_full_h in np.linspace(78.0, 108.0, 31):
        cand_w = cand_full_h * (float(sw) / max(float(sh), 1.0))
        tw = max(8, int(round(cand_w)))
        th = max(8, int(round(cand_full_h * (float(match_h) / float(sh)))))
        if tw >= rw_1x or th >= rh_1x:
            continue
        tpl = cv2.resize(head_sil_full, (tw, th), interpolation=cv2.INTER_AREA)
        res = cv2.matchTemplate(roi_1x, tpl, cv2.TM_CCORR_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(res)
        # Mild soft preference for expected canonical head size (~90 display units)
        if max_val > best_score:
            best_score = float(max_val)
            hx_1x = float(roi_x0) / float(TEX_SCALE) + float(max_loc[0])
            hy_1x = float(roi_y0) / float(TEX_SCALE) + float(max_loc[1])
            best_rect = (hx_1x, hy_1x, cand_w, cand_full_h)
    return best_rect


def _compute_body_neck_cut(
    parts5_mask: np.ndarray, id_bgra: np.ndarray, ref_rgba: np.ndarray
) -> tuple[dict[str, np.ndarray], tuple[float, float]]:
    """Extract mutually exclusive parts masks with head cleanly cut above turtleneck top."""
    p5_colors = {
        "body_core": (0, 255, 0),
        "arm_r": (0, 0, 255),
        "arm_l": (255, 0, 0),
        "leg_r": (0, 255, 255),
        "leg_l": (255, 0, 255),
    }
    ra = ref_rgba[:, :, 3] > 24
    masks: dict[str, np.ndarray] = {}
    for pname, bgr in p5_colors.items():
        masks[pname] = ra & np.all(parts5_mask == np.array(bgr, dtype=np.uint8)[None, None, :], axis=2)

    bc = masks["body_core"]
    bys = np.where(bc)[0]
    y0_top = int(bys.min()) if len(bys) > 0 else 315

    # Narrowest neck tube between crown+115 and crown+330
    neck_y = y0_top + 218
    best_w = 10**6
    for y in range(y0_top + 135, min(PX_H, y0_top + 310)):
        xs = np.where(bc[y])[0]
        if len(xs) >= 35:
            span = int(xs.max() - xs.min())
            if span < best_w:
                best_w = span
                neck_y = y
    neck_xs = np.where(bc[neck_y])[0]
    neck_cx = float(neck_xs.mean()) if len(neck_xs) > 0 else float(PX_W) * 0.5
    neck_hw = max(36.0, float(best_w) * 0.54)

    # Remove everything above top of neck fade window + hair spikes outside neck collar
    yy, xx = np.mgrid[:PX_H, :PX_W]
    above_head = yy < (neck_y - 10)
    hair_m = id_bgra[:, :, 3] > 128
    suit_or_armor = (id_bgra[:, :, 0] > 128) | (id_bgra[:, :, 1] > 128) | (id_bgra[:, :, 2] > 128)
    skin_m = bc & (~hair_m) & (~suit_or_armor)
    # Remove any head hair or face skin extending laterally or sitting above shoulder line
    stray_head_hair = hair_m & (yy < neck_y + 42) & (np.abs(xx - neck_cx) > neck_hw * 0.98)
    stray_face_skin = skin_m & (yy < neck_y + 22)
    masks["body_core"] = bc & (~above_head) & (~stray_head_hair) & (~stray_face_skin)

    # Keep only largest main torso CC so stray detached scalp flecks cannot float
    n_bc, lbl_bc, st_bc, _ = cv2.connectedComponentsWithStats(masks["body_core"].astype(np.uint8))
    if n_bc > 2:
        main_bc = max(range(1, n_bc), key=lambda i: int(st_bc[i, cv2.CC_STAT_AREA]))
        masks["body_core"] = lbl_bc == main_bc

    return masks, (neck_cx / float(TEX_SCALE), float(neck_y) / float(TEX_SCALE))


_V2_COLLAR_DX_BY_VIEW: dict[str, float] = {
    "s": 0.60, "se": 3.35, "sw": -3.35, "e": 8.45, "w": -8.45, "ne": -0.25, "nw": 0.25, "n": 0.75,
}
_V2_HEAD_LOOK_DX: dict[tuple[str, str], float] = {
    ("se", "head_side_r"): 0.65, ("sw", "head_side_l"): -0.65,
    ("e", "head_front_r"): 0.95, ("w", "head_front_l"): -0.95,
}
_V2_CROWN_REL_Y_BY_VIEW: dict[str, float] = {
    "s": -171.8, "se": -171.8, "sw": -171.8, "e": -171.8, "w": -171.8, "ne": -172.0, "nw": -172.0, "n": -172.0,
}
_V2_TARGET_CYL_W_PX: dict[str, float] = {
    "head_front": 164.0,
    "head_front_r": 165.0,
    "head_front_l": 165.0,
    "head_side_r": 156.0,
    "head_side_l": 156.0,
    "head_back_r": 164.0,
    "head_back_l": 164.0,
    "head_back": 164.0,
}


def _v2_combo_scale(v_k: str, h_k: str) -> float:
    if v_k in ("e", "w") and h_k in ("head_front_r", "head_front_l"):
        return 0.95
    if v_k in ("se", "sw") and h_k in ("head_side_r", "head_side_l"):
        return 1.00
    return 0.98


def _carve_cylindrical_neck_v2(
    h_key: str,
    rgba: np.ndarray,
    id_bgra: np.ndarray,
    cx0: int,
    cx1: int,
    cy0: int = 0,
    cy1: int = 0,
) -> tuple[np.ndarray, np.ndarray, float]:
    """Carve flared trapezius wings on the blue neck into a torso-compatible tapered cylinder."""
    ch_i, cw_i = rgba.shape[:2]
    fg = rgba[:, :, 3] > 24
    is_blue = (id_bgra[:, :, 0] > 128) & fg & (id_bgra[:, :, 3] < 128)
    bys = np.where(is_blue)[0]
    if len(bys) < 10:
        return rgba, id_bgra, 0.5 * float(cx0 + cx1)

    b_top, b_bot = int(bys.min()), int(bys.max())
    neck_spans: list[tuple[int, float, float]] = []
    scan_y0 = max(b_top + 20, cy0 + 480)
    scan_y1 = min(b_bot - 20, cy0 + 520)
    for y in range(scan_y0, max(scan_y0 + 1, scan_y1)):
        xs_b = np.where(is_blue[y])[0]
        if len(xs_b) >= 80:
            span = float(xs_b.max() - xs_b.min() + 1)
            if 130.0 <= span <= 205.0:
                neck_spans.append((y, span, 0.5 * (float(xs_b.min()) + float(xs_b.max()))))
    if neck_spans:
        neck_spans.sort(key=lambda t: t[1])
        y_unocc, waist_w, neck_cx = neck_spans[0]
    else:
        y_unocc, waist_w, neck_cx = int(b_top + 0.35 * (b_bot - b_top)), 168.0, 0.5 * float(cx0 + cx1)

    if "side" in h_key:
        y_waist = cy0 + 474
    elif "back" in h_key:
        y_waist = max(y_unocc, cy0 + 475)
    elif h_key == "head_front":
        y_waist = cy0 + 445
    else:
        y_waist = cy0 + 465

    max_cyl_w = min(waist_w, _V2_TARGET_CYL_W_PX.get(h_key, 162.0))
    hw_top = 0.5 * max_cyl_w
    b_bot_cap = min(b_bot, y_unocc + int(0.85 * max_cyl_w))

    yy_c, xx_c = np.ogrid[:ch_i, :cw_i]
    t_y = np.clip((yy_c.astype(np.float32) - float(y_unocc)) / max(1.0, float(b_bot_cap - y_unocc)), 0.0, 1.5)
    allowed_hw = (
        hw_top
        * (1.0 - 0.18 * np.clip(t_y, 0.0, 1.0))
        * np.sqrt(np.clip(1.0 - np.maximum(0.0, t_y - 0.68) / 0.32, 0.0, 1.0))
    )
    dx_abs = np.abs(xx_c.astype(np.float32) - neck_cx)

    lower_excess = (is_blue & (yy_c >= y_waist)) & ((dx_abs > allowed_hw) | (yy_c > b_bot_cap))
    rgba[lower_excess, 3] = 0
    fg_carved = rgba[:, :, 3] > 24
    n_cc, lbl_cc, st_cc, _ = cv2.connectedComponentsWithStats(fg_carved.astype(np.uint8), connectivity=8)
    if n_cc > 2:
        main_cc = max(range(1, n_cc), key=lambda i: int(st_cc[i, cv2.CC_STAT_AREA]))
        drop_cc = (lbl_cc > 0) & (lbl_cc != main_cc)
        rgba[drop_cc, 3] = 0
        fg_carved = rgba[:, :, 3] > 24

    d_neck_in = cv2.distanceTransform(fg_carved.astype(np.uint8), cv2.DIST_L2, 5)
    ink_start_y = (y_unocc - 6) if "side" in h_key else y_waist
    new_neck_ink = (
        is_blue
        & fg_carved
        & (d_neck_in <= 5.5)
        & (yy_c >= ink_start_y)
        & (yy_c < y_unocc + int(0.55 * (b_bot_cap - y_unocc)))
    )
    rgba[new_neck_ink, :3] = np.array([14, 10, 12], dtype=np.uint8)
    semi_neck = is_blue & fg_carved & (d_neck_in <= 2.0) & (yy_c >= ink_start_y)
    rgba[semi_neck, 3] = np.clip(d_neck_in[semi_neck] * 127.0, 0, 255).astype(np.uint8)

    hair_prot = cv2.dilate((id_bgra[:, :, 3] > 128).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    blue_dil = cv2.dilate((id_bgra[:, :, 0] > 128).astype(np.uint8), np.ones((11, 11), np.uint8)) > 0
    outer_perim = fg_carved & (d_neck_in <= 6.5) & (yy_c >= ink_start_y) & is_blue
    id_bgra[blue_dil & (~hair_prot) & ((~fg_carved) | outer_perim)] = np.array([255, 0, 0, 0], dtype=np.uint8)
    rgba, id_bgra = _fill_interior_alpha_holes(rgba, id_bgra, max_hole_area=800)
    return rgba, id_bgra, neck_cx


def _fill_interior_alpha_holes(
    rgba: np.ndarray, id_bgra: np.ndarray, max_hole_area: int = 800
) -> tuple[np.ndarray, np.ndarray]:
    """Fill small interior transparent pinholes so heads never reveal background through the sprite."""
    fg = (rgba[:, :, 3] > 24).astype(np.uint8)
    inv = (1 - fg).astype(np.uint8)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(inv, connectivity=8)
    if n_cc <= 1:
        return rgba, id_bgra
    h, w = fg.shape
    holes = np.zeros((h, w), dtype=bool)
    for cid in range(1, n_cc):
        x = int(stats[cid, cv2.CC_STAT_LEFT])
        y = int(stats[cid, cv2.CC_STAT_TOP])
        bw = int(stats[cid, cv2.CC_STAT_WIDTH])
        bh = int(stats[cid, cv2.CC_STAT_HEIGHT])
        area = int(stats[cid, cv2.CC_STAT_AREA])
        if x > 0 and y > 0 and (x + bw) < w and (y + bh) < h and area <= max_hole_area:
            holes |= (lbl == cid)
    if not np.any(holes):
        return rgba, id_bgra
    valid = (rgba[:, :, 3] > 24) & (~holes)
    if np.any(valid):
        filled_rgba = _voronoi_fill(rgba, valid)
        filled_id = _voronoi_fill(id_bgra, valid)
        rgba = rgba.copy()
        id_bgra = id_bgra.copy()
        rgba[holes, :3] = filled_rgba[holes, :3]
        rgba[holes, 3] = 255
        id_bgra[holes] = filled_id[holes]
    return rgba, id_bgra


def _align_v2_combo_transforms(
    out_root: Path,
    ct_in: dict,
    metadata: dict[str, object],
    head_anchors: dict[str, tuple[float, float]],
    ov_views: dict | None = None,
) -> dict:
    """Align each (view, head) combo so neck cylinder center and perceptible crown height match across 8 views."""
    new_ct: dict[str, dict[str, dict[str, object]]] = {}
    for v_k, v_map in ct_in.items():
        if not isinstance(v_map, dict):
            continue
        pm_path = out_root / v_k / "parts_5" / "parts_5_meta.json"
        if not pm_path.exists():
            continue
        pm = json.loads(pm_path.read_text(encoding="utf-8"))
        v_ov = ov_views.get(v_k, {}) if isinstance(ov_views, dict) else {}
        ro_x, ro_y = v_ov.get("rig_origin", pm["rig_origin"])
        na_x, na_y = v_ov.get("neck_anchor", pm["neck_anchor"])

        target_crown_y = float(ro_y) + _V2_CROWN_REL_Y_BY_VIEW.get(v_k, -171.8)
        target_neck_x = float(na_x) + _V2_COLLAR_DX_BY_VIEW.get(v_k, 0.0)

        new_v_map: dict[str, dict[str, object]] = {}
        for h_k, tf in v_map.items():
            if not isinstance(tf, dict) or h_k not in metadata or h_k not in head_anchors:
                continue
            s_val = _v2_combo_scale(v_k, h_k)
            disp_size = metadata[h_k]["disp_size"]  # type: ignore[index]
            dw, dh = float(disp_size[0]) * s_val, float(disp_size[1]) * s_val
            neck_cx_du, crown_y_du = head_anchors[h_k][0] * s_val, head_anchors[h_k][1] * s_val
            look_dx = _V2_HEAD_LOOK_DX.get((v_k, h_k), 0.0)
            off_x = (target_neck_x + look_dx - float(na_x)) + dw * 0.5 - neck_cx_du
            off_y = (target_crown_y - float(na_y)) + dh * 0.5 - crown_y_du
            new_v_map[h_k] = {
                "scale": round(s_val, 3),
                "sprite_offset": [round(off_x, 2), round(off_y, 2)],
            }
        new_ct[v_k] = new_v_map
    return new_ct


def _refine_v2_head_id_color_locked(
    h_key: str,
    rgba: np.ndarray,
    id_bgra: np.ndarray,
    cx0: int,
    cy0: int,
    cy1: int,
) -> np.ndarray:
    """Align hair/skin/neck ID boundaries strictly to actual RGB colors in the 4x head sprite."""
    fg = rgba[:, :, 3] > 24
    b_c = rgba[:, :, 0].astype(np.int32)
    g_c = rgba[:, :, 1].astype(np.int32)
    r_c = rgba[:, :, 2].astype(np.int32)
    chroma_span = np.maximum(np.maximum(r_c, g_c), b_c) - np.minimum(np.minimum(r_c, g_c), b_c)
    ch_i, cw_i = rgba.shape[:2]
    yy_g, xx_g = np.ogrid[:ch_i, :cw_i]

    if h_key == "head_back":
        warm_neck = fg & ((r_c - b_c) >= 22) & (yy_g >= int(cy0 + 0.52 * (cy1 - cy0)))
        id_bgra[warm_neck] = np.array([255, 0, 0, 0], dtype=np.uint8)
        hair_m = (id_bgra[:, :, 3] > 128) & fg
        n_h, lbl_h, st_h, _ = cv2.connectedComponentsWithStats(hair_m.astype(np.uint8), connectivity=8)
        if n_h > 1:
            main_h = max(range(1, n_h), key=lambda i: int(st_h[i, cv2.CC_STAT_AREA]))
            stray_h = hair_m & (lbl_h != main_h)
            id_bgra[stray_h] = np.array([255, 0, 0, 0], dtype=np.uint8)
        return id_bgra

    if h_key == "head_back_l":
        jaw_skin = fg & (id_bgra[:, :, 0] > 128) & (id_bgra[:, :, 3] < 128) & (yy_g <= cy0 + 450) & (xx_g < cx0 + 148)
        id_bgra[jaw_skin] = np.array([0, 0, 0, 0], dtype=np.uint8)

    # Connected silver hair strands accidentally masked as neck/skin (excludes isolated eye sclera)
    hair_near = cv2.dilate((id_bgra[:, :, 3] > 128).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    silver_hair = fg & ((r_c - b_c) <= 18) & (g_c >= 90) & (chroma_span <= 28) & hair_near
    id_bgra[silver_hair] = np.array([0, 0, 0, 255], dtype=np.uint8)

    # Warm skin pixels mistakenly tagged as hair: reassign via Voronoi to nearest non-hair face/neck neighbor
    warm_skin_in_hair = fg & ((r_c - b_c) >= 28) & (r_c >= 115) & ((r_c - g_c) < 55) & (id_bgra[:, :, 2] < 128) & (id_bgra[:, :, 3] > 128)
    if np.any(warm_skin_in_hair):
        non_hair_valid = fg & (~warm_skin_in_hair) & (id_bgra[:, :, 3] < 128)
        if np.any(non_hair_valid):
            filled_non_hair = _voronoi_fill(id_bgra.copy(), non_hair_valid)
            id_bgra[warm_skin_in_hair] = filled_non_hair[warm_skin_in_hair]
    return id_bgra


def _segment_v2_head_id_ink_guided(
    c_cell: np.ndarray,
    fg: np.ndarray,
    m_aligned: np.ndarray,
    ref_bgr: np.ndarray,
) -> np.ndarray:
    """Propagate ID classes strictly inside dark-ink bounded cel regions so hair never bleeds onto neck skin."""
    ch_i, cw_i = fg.shape
    gray = cv2.cvtColor(c_cell, cv2.COLOR_BGR2GRAY)
    b_c = c_cell[:, :, 0].astype(np.int32)
    g_c = c_cell[:, :, 1].astype(np.int32)
    r_c = c_cell[:, :, 2].astype(np.int32)
    chroma = np.maximum(np.maximum(r_c, g_c), b_c) - np.minimum(np.minimum(r_c, g_c), b_c)

    # Dark ink lines separate hair locks, face skin, neck skin, and monocle (exclude dark crimson monocle fill)
    ink = fg & (gray < 80) & ((r_c - b_c) < 35)
    non_ink = fg & (~ink)

    # Reliable seed pixels from aligned AI ID mask (0=hair/cyan, 1=skin/green, 2=neck/blue, 3=monocle/red)
    m_fg_eroded = cv2.erode((m_aligned.min(axis=2) < 185).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    m_sat = (m_aligned.max(axis=2).astype(np.int32) - m_aligned.min(axis=2).astype(np.int32)) > 90
    diff = m_aligned.astype(np.float32)[:, :, None, :] - ref_bgr[None, None, :, :]
    dist2 = np.sum(diff * diff, axis=3)
    seed_cls = np.argmin(dist2, axis=2)
    pure_color = np.min(dist2, axis=2) < (90.0 * 90.0)
    valid_seeds = non_ink & m_fg_eroded & m_sat & pure_color

    # Color-consistency guard on seeds so slight AI mask shifts cannot poison watershed or cell votes
    warm_skin_px = ((r_c - b_c) >= 20) & (r_c >= 95) & ((r_c - g_c) < 55)
    silver_hair_px = ((r_c - b_c) <= 14) & (chroma <= 26) & (g_c >= 85)
    valid_seeds = valid_seeds & (~((seed_cls == 0) & warm_skin_px))
    valid_seeds = valid_seeds & (~(((seed_cls == 1) | (seed_cls == 2)) & silver_hair_px))

    cls_map = np.full((ch_i, cw_i), -1, dtype=np.int16)
    n_cc, lbl_cc, _, _ = cv2.connectedComponentsWithStats(non_ink.astype(np.uint8), connectivity=4)

    for cid in range(1, n_cc):
        comp = lbl_cc == cid
        comp_seeds = valid_seeds & comp
        n_seeds = int(np.sum(comp_seeds))
        if n_seeds == 0:
            continue
        counts = np.bincount(seed_cls[comp_seeds], minlength=4)
        active = [k for k in range(4) if counts[k] >= 80 and counts[k] >= 0.10 * n_seeds]
        if len(active) >= 2:
            # Mixed cell (e.g., open cheek-to-neck transition in side view): run color-gradient watershed
            markers = np.zeros((ch_i, cw_i), dtype=np.int32)
            for k in active:
                markers[comp_seeds & (seed_cls == k)] = k + 1
            ws = cv2.watershed(c_cell.copy(), markers)
            for k in active:
                cls_map[comp & (ws == (k + 1))] = k
            unassigned = comp & (cls_map < 0)
            if np.any(unassigned):
                assigned = comp & (cls_map >= 0)
                if np.any(assigned):
                    _, idx = ndimage.distance_transform_edt(~assigned, return_indices=True)
                    cls_map[unassigned] = cls_map[idx[0][unassigned], idx[1][unassigned]]
        else:
            winner = int(np.argmax(counts))
            # Guard small/medium pure cells against wrong majority due to shifted AI mask
            med_rb = float(np.median(r_c[comp] - b_c[comp]))
            med_rg = float(np.median(r_c[comp] - g_c[comp]))
            med_r = float(np.median(r_c[comp]))
            if winner == 0 and med_rb >= 20.0 and med_r >= 95.0 and med_rg < 55.0:
                # Warm skin cell wrongly voted as hair: defer to nearest non-hair class
                continue
            cls_map[comp] = winner

    # Fill any tiny unseeded non-ink cells (e.g. shaded skin pocket under hair tips or fine hair tip)
    # using color-aware nearest assigned neighbor
    unseeded_non_ink = non_ink & (cls_map < 0)
    if np.any(unseeded_non_ink):
        n_un, lbl_un, _, _ = cv2.connectedComponentsWithStats(unseeded_non_ink.astype(np.uint8), connectivity=4)
        assigned_non_hair = non_ink & (cls_map >= 1)
        assigned_any = non_ink & (cls_map >= 0)
        idx_non_hair = (
            ndimage.distance_transform_edt(~assigned_non_hair, return_indices=True)[1]
            if np.any(assigned_non_hair)
            else None
        )
        idx_any = (
            ndimage.distance_transform_edt(~assigned_any, return_indices=True)[1]
            if np.any(assigned_any)
            else None
        )
        for uid in range(1, n_un):
            ucomp = lbl_un == uid
            med_rb = float(np.median(r_c[ucomp] - b_c[ucomp]))
            med_rg = float(np.median(r_c[ucomp] - g_c[ucomp]))
            med_r = float(np.median(r_c[ucomp]))
            if idx_non_hair is not None and med_rb >= 18.0 and med_r >= 90.0 and med_rg < 55.0:
                # Shaded/warm skin pocket: inherit nearest non-hair neighbor (neck_blue or face skin)
                src = idx_non_hair
            elif idx_any is not None:
                src = idx_any
            else:
                continue
            nbr_cls = cls_map[src[0][ucomp], src[1][ucomp]]
            cls_map[ucomp] = int(np.argmax(np.bincount(nbr_cls[nbr_cls >= 0], minlength=4)))

    # Assign dark ink pixels with explicit priority so hair/face/monocle keep 100% of their dark outline
    # in Pass 2 while neck-only ink stays neck_blue: monocle(3) > hair(0) > skin(1) > neck_blue(2)
    k5 = np.ones((5, 5), np.uint8)
    for k in (2, 1, 0, 3):
        touching = cv2.dilate((cls_map == k).astype(np.uint8), k5) > 0
        cls_map[ink & touching] = k

    # Fallback for any thick ink interior pixels not within 2px of a non-ink cell
    still_unset = fg & (cls_map < 0)
    if np.any(still_unset):
        known = fg & (cls_map >= 0)
        if np.any(known):
            _, idx_k = ndimage.distance_transform_edt(~known, return_indices=True)
            cls_map[still_unset] = cls_map[idx_k[0][still_unset], idx_k[1][still_unset]]

    # Neck (class 2) is always a single connected column; any detached blue pocket trapped
    # between hair locks and jaw/ear (e.g. head_back_r/l) is face skin, not neck.
    blue_m = (cls_map == 2) & fg
    n_bl, lbl_bl, st_bl, _ = cv2.connectedComponentsWithStats(blue_m.astype(np.uint8), connectivity=8)
    if n_bl > 2:
        main_bl = max(range(1, n_bl), key=lambda i: int(st_bl[i, cv2.CC_STAT_AREA]))
        cls_map[blue_m & (lbl_bl != main_bl)] = 1

    id_bgra = np.zeros((ch_i, cw_i, 4), dtype=np.uint8)
    id_bgra[cls_map == 0, 3] = 255
    id_bgra[cls_map == 2, 0] = 255
    id_bgra[cls_map == 3, 2] = 255
    return id_bgra


def _build_heads_from_v2_base(v2_base_dir: Path, heads_out: Path) -> dict:
    """Compile all 8 decoupled heads + bare necks from canonical 4x upscaled 4x2 sheets."""
    col_sheet = cv2.imread(str(v2_base_dir / "heads_v2_color_4x.png"))
    msk_raw = cv2.imread(str(v2_base_dir / "heads_v2_id_mask.png"))
    h_sh, w_sh = col_sheet.shape[:2]
    msk_sheet = cv2.resize(msk_raw, (w_sh, h_sh), interpolation=cv2.INTER_NEAREST)

    grid = [
        ["head_front", "head_front_r", "head_side_r", "head_back_r"],
        ["head_back", "head_back_l", "head_side_l", "head_front_l"],
    ]
    du_per_px = 69.03 / float(HEAD_TARGET_DENSITY_PX_H)
    pad = HEAD_PAD_PX
    cw, ch = w_sh // 4, h_sh // 2
    ref_bgr = np.array(
        [[255.0, 255.0, 0.0], [0.0, 255.0, 0.0], [255.0, 0.0, 0.0], [0.0, 0.0, 255.0]],
        dtype=np.float32,
    )
    metadata: dict[str, object] = {"_outline_pad_px": pad}

    # Pass 1: extract RGBA, clean Voronoi ID masks, carve cylindrical necks, and measure crown->chin height
    extracted: list[dict[str, object]] = []
    for r_idx, row_keys in enumerate(grid):
        for c_idx, h_key in enumerate(row_keys):
            x0, x1 = c_idx * cw, (c_idx + 1) * cw if c_idx < 3 else w_sh
            y0, y1 = r_idx * ch, (r_idx + 1) * ch if r_idx < 1 else h_sh
            c_cell = col_sheet[y0:y1, x0:x1]
            m_cell = msk_sheet[y0:y1, x0:x1]
            ch_i, cw_i = c_cell.shape[:2]

            gray = cv2.cvtColor(c_cell, cv2.COLOR_BGR2GRAY)
            bg_seed = np.zeros((ch_i + 2, cw_i + 2), np.uint8)
            ff = c_cell.copy()
            cv2.floodFill(
                ff, bg_seed, (0, 0), (0, 255, 0),
                loDiff=(70, 70, 70), upDiff=(70, 70, 70),
                flags=4 | cv2.FLOODFILL_FIXED_RANGE,
            )
            ext_bg = bg_seed[1:-1, 1:-1] > 0

            dist_in = cv2.distanceTransform((~ext_bg).astype(np.uint8), cv2.DIST_L2, 5)
            boundary = (dist_in > 0) & (dist_in <= 4.0)
            edge_alpha = np.clip((185.0 - gray.astype(np.float32)) / 145.0, 0.0, 1.0)
            alpha = np.where(ext_bg, 0.0, np.where(boundary, edge_alpha, 1.0))
            alpha_u8 = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)

            bgr_clean = c_cell.copy()
            bgr_clean[(alpha > 0.0) & (alpha < 0.96)] = np.array([14, 10, 12], dtype=np.uint8)
            rgba = np.dstack([bgr_clean, alpha_u8])
            fg = alpha_u8 > 24

            ys_c, xs_c = np.where(fg)
            cx0, cx1, cy0, cy1 = int(xs_c.min()), int(xs_c.max()), int(ys_c.min()), int(ys_c.max())
            ys_m, xs_m = np.where(m_cell.min(axis=2) < 200)
            mx0, mx1, my0, my1 = int(xs_m.min()), int(xs_m.max()), int(ys_m.min()), int(ys_m.max())

            m_aligned = np.full_like(m_cell, 255)
            m_aligned[cy0 : cy1 + 1, cx0 : cx1 + 1] = cv2.resize(
                m_cell[my0 : my1 + 1, mx0 : mx1 + 1],
                (cx1 - cx0 + 1, cy1 - cy0 + 1),
                interpolation=cv2.INTER_NEAREST,
            )
            id_bgra = _segment_v2_head_id_ink_guided(c_cell, fg, m_aligned, ref_bgr)

            # Prune tiny anti-aliased hair specks along chin/neck keeping main hair + eyebrows
            raw_hair = (id_bgra[:, :, 3] > 128) & fg
            n_hc, lbl_hc, st_hc, _ = cv2.connectedComponentsWithStats(raw_hair.astype(np.uint8))
            if n_hc > 2:
                main_hc = max(range(1, n_hc), key=lambda i: int(st_hc[i, cv2.CC_STAT_AREA]))
                drop_hc = np.zeros_like(raw_hair)
                for cid in range(1, n_hc):
                    if cid == main_hc:
                        continue
                    if int(st_hc[cid, cv2.CC_STAT_AREA]) < 150 or int(st_hc[cid, cv2.CC_STAT_TOP]) > int(cy0 + 0.55 * (cy1 - cy0)):
                        drop_hc |= (lbl_hc == cid)
                if np.any(drop_hc):
                    keep_non_drop = fg & (~drop_hc)
                    if np.any(keep_non_drop):
                        id_bgra = _voronoi_fill(id_bgra, keep_non_drop)

            id_bgra = _refine_v2_head_id_color_locked(h_key, rgba, id_bgra, cx0, cy0, cy1)
            rgba, id_bgra, neck_cx = _carve_cylindrical_neck_v2(h_key, rgba, id_bgra, cx0, cx1, cy0, cy1)
            fg = rgba[:, :, 3] > 24
            ys_c2, xs_c2 = np.where(fg)
            cx0, cx1, cy0, cy1 = int(xs_c2.min()), int(xs_c2.max()), int(ys_c2.min()), int(ys_c2.max())

            cx_mid0 = cx0 + int(round(0.20 * (cx1 - cx0)))
            cx_mid1 = cx0 + int(round(0.80 * (cx1 - cx0)))
            central_non_blue_ys = np.where(fg[:, cx_mid0 : cx_mid1 + 1] & (id_bgra[:, cx_mid0 : cx_mid1 + 1, 0] < 128))[0]
            head_h_raw = float(central_non_blue_ys.max() - cy0 + 1) if len(central_non_blue_ys) > 20 else float(cy1 - cy0 + 1)
            extracted.append({
                "h_key": h_key,
                "rgba": rgba,
                "id_bgra": id_bgra,
                "bbox": (cx0, cx1, cy0, cy1),
                "head_h_raw": head_h_raw,
                "neck_cx_rel": neck_cx - float(cx0),
            })

    median_head_h = float(np.median([float(item["head_h_raw"]) for item in extracted]))
    uniform_scale = float(HEAD_TARGET_DENSITY_PX_H) / max(median_head_h, 1.0)
    head_anchors: dict[str, tuple[float, float]] = {}

    for item in extracted:
        h_key = str(item["h_key"])
        rgba = item["rgba"]
        id_bgra = item["id_bgra"]
        cx0, cx1, cy0, cy1 = item["bbox"]  # type: ignore[misc]

        new_w = max(1, int(round((cx1 - cx0 + 1) * uniform_scale)))
        new_h = max(1, int(round((cy1 - cy0 + 1) * uniform_scale)))
        res_rgba = cv2.resize(rgba[cy0 : cy1 + 1, cx0 : cx1 + 1], (new_w, new_h), interpolation=cv2.INTER_AREA)
        res_id = cv2.resize(id_bgra[cy0 : cy1 + 1, cx0 : cx1 + 1], (new_w, new_h), interpolation=cv2.INTER_NEAREST)
        ra = res_rgba[:, :, 3]
        res_rgba[(ra > 0) & (ra < 235), :3] = np.array([14, 10, 12], dtype=np.uint8)
        res_rgba[ra < 16] = 0
        res_rgba, res_id = _fill_interior_alpha_holes(res_rgba, res_id, max_hole_area=200)

        fw, fh = new_w + 2 * pad, new_h + 2 * pad
        out_rgba = np.zeros((fh, fw, 4), dtype=np.uint8)
        out_id = np.zeros((fh, fw, 4), dtype=np.uint8)
        out_rgba[pad : pad + new_h, pad : pad + new_w] = res_rgba
        out_id[pad : pad + new_h, pad : pad + new_w] = res_id
        fg_out = out_rgba[:, :, 3] > 24
        if np.any(fg_out):
            out_id = _voronoi_fill(out_id, fg_out)

        nd_bgra = _build_clean_head_normal_depth(out_rgba[:, :, 3])
        interior_nd = out_rgba[:, :, 3] >= 128
        non_zero_nd = (nd_bgra[:, :, 0] > 0) | (nd_bgra[:, :, 1] > 0) | (nd_bgra[:, :, 2] > 0)
        valid_nd = interior_nd & non_zero_nd & (nd_bgra[:, :, 3] > 0)
        if np.any(valid_nd):
            nd_bgra = _voronoi_fill(nd_bgra, valid_nd)

        jiggle_bgr = _build_hair_jiggle_mask(out_rgba, out_id)
        dist_px = cv2.distanceTransform((out_rgba[:, :, 3] < 128).astype(np.uint8), cv2.DIST_L2, 5)
        sdf_u8 = np.clip((dist_px / HEAD_SDF_MAX_DIST_PX) * 255.0, 0, 255).astype(np.uint8)

        cv2.imwrite(str(heads_out / f"{h_key}.png"), alpha_bleed_only(out_rgba))
        cv2.imwrite(str(heads_out / f"{h_key}_id_mask.png"), out_id)
        cv2.imwrite(str(heads_out / f"{h_key}_normal_depth.png"), nd_bgra)
        cv2.imwrite(str(heads_out / f"{h_key}_hair_jiggle_mask.png"), jiggle_bgr)
        cv2.imwrite(str(heads_out / f"{h_key}_outline_sdf.png"), sdf_u8)

        neck_cx_du = (float(pad) + float(item["neck_cx_rel"]) * uniform_scale) * du_per_px
        crown_y_du = float(pad) * du_per_px
        head_anchors[h_key] = (neck_cx_du, crown_y_du)

        blue_ys, _ = np.where((out_id[:, :, 0] > 128) & (out_rgba[:, :, 3] > 128))
        piv_y_px = float(np.percentile(blue_ys, 15)) if len(blue_ys) > 10 else fh * 0.72
        disp_w = round(fw * du_per_px, 4)
        disp_h = round(fh * du_per_px, 4)
        piv_x_du = round(neck_cx_du, 4)
        piv_y_du = round(piv_y_px * du_per_px, 4)
        metadata[h_key] = {
            "disp_size": [disp_w, disp_h],
            "neck_pivot_px": [piv_x_du, piv_y_du],
            "sprite_offset": [round(disp_w * 0.5 - piv_x_du, 4), round(disp_h * 0.5 - piv_y_du, 4)],
        }
        if h_key == "head_side_r":
            metadata["head_side"] = dict(metadata[h_key])

    for r_k, l_k in (("head_front_r", "head_front_l"), ("head_side_r", "head_side_l"), ("head_back_r", "head_back_l")):
        if r_k in metadata and l_k in metadata and r_k in head_anchors and l_k in head_anchors:
            e_r = metadata[r_k]  # type: ignore[assignment]
            e_l = metadata[l_k]  # type: ignore[assignment]
            dw_r = float(e_r["disp_size"][0])  # type: ignore[index]
            dw_l = float(e_l["disp_size"][0])  # type: ignore[index]
            dr = dw_r * 0.5 - head_anchors[r_k][0]
            dl = dw_l * 0.5 - head_anchors[l_k][0]
            mag = 0.5 * (abs(dr) + abs(dl))
            sgn = 1.0 if dr >= 0.0 else -1.0
            piv_x_r = round(dw_r * 0.5 - sgn * mag, 4)
            piv_x_l = round(dw_l * 0.5 + sgn * mag, 4)
            head_anchors[r_k] = (piv_x_r, head_anchors[r_k][1])
            head_anchors[l_k] = (piv_x_l, head_anchors[l_k][1])
            e_r["neck_pivot_px"][0] = piv_x_r  # type: ignore[index]
            e_l["neck_pivot_px"][0] = piv_x_l  # type: ignore[index]
            e_r["sprite_offset"][0] = round(dw_r * 0.5 - piv_x_r, 4)  # type: ignore[index]
            e_l["sprite_offset"][0] = round(dw_l * 0.5 - piv_x_l, 4)  # type: ignore[index]
            if r_k == "head_side_r":
                metadata["head_side"] = dict(e_r)  # type: ignore[arg-type]

    def _sync_base_from_combos(ct_map: dict) -> None:
        for native_v, h_k in VIEW_TO_HEAD_KEY.items():
            tf = ct_map.get(native_v, {}).get(h_k)
            if isinstance(tf, dict) and h_k in metadata and "sprite_offset" in tf:
                h_entry = metadata[h_k]  # type: ignore[assignment]
                dw_h = float(h_entry["disp_size"][0])  # type: ignore[index]
                dh_h = float(h_entry["disp_size"][1])  # type: ignore[index]
                ox_c, oy_c = float(tf["sprite_offset"][0]), float(tf["sprite_offset"][1])
                h_entry["sprite_offset"] = [round(ox_c, 4), round(oy_c, 4)]  # type: ignore[index]
                h_entry["neck_pivot_px"] = [round(dw_h * 0.5 - ox_c, 4), round(dh_h * 0.5 - oy_c, 4)]  # type: ignore[index]
                if h_k == "head_side_r":
                    metadata["head_side"] = dict(h_entry)  # type: ignore[arg-type]

    meta_path = heads_out / "heads_metadata.json"
    ov_path = heads_out.parent / "manual_calibration_overrides.json"
    if ov_path.exists():
        ov = json.loads(ov_path.read_text(encoding="utf-8"))
        heads_ov = ov.get("heads", {})
        ct = heads_ov.get("combo_transforms")
        if isinstance(ct, dict):
            new_ct = _align_v2_combo_transforms(heads_out.parent, ct, metadata, head_anchors, ov.get("views"))
            metadata["combo_transforms"] = new_ct
            heads_ov["combo_transforms"] = new_ct
            _sync_base_from_combos(new_ct)
        for hk_upd, h_val in metadata.items():
            if not hk_upd.startswith("_") and hk_upd != "combo_transforms":
                heads_ov[hk_upd] = h_val
        ov["heads"] = heads_ov
        ov_path.write_text(json.dumps(ov, indent=2) + "\n", encoding="utf-8")
    elif meta_path.exists():
        prev_meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if isinstance(prev_meta.get("combo_transforms"), dict):
            new_ct = _align_v2_combo_transforms(
                heads_out.parent, prev_meta["combo_transforms"], metadata, head_anchors
            )
            metadata["combo_transforms"] = new_ct
            _sync_base_from_combos(new_ct)
    meta_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata


def build_heads_pack(source_dir: Path, out_dir: Path, neck_by_view: dict[str, tuple[float, float]]) -> dict:
    """Process all 8 hires heads + neck-stub trimming + 16% scale calibration + edge cleanup + SDF."""
    heads_out = out_dir / "heads"
    heads_out.mkdir(parents=True, exist_ok=True)
    v2_base_dir = source_dir / "heads_v2_base"
    if (v2_base_dir / "heads_v2_color_4x.png").exists() and (v2_base_dir / "heads_v2_id_mask.png").exists():
        return _build_heads_from_v2_base(v2_base_dir, heads_out)
    ws_heads = source_dir / "05_mask_ai_workspaces" / "03_id_mask_heads" / "split_results"
    hires_dir = source_dir / "04_mask_prep_ready" / "heads_8dir_hires" / "rgba"

    metadata: dict[str, object] = {"_outline_pad_px": HEAD_PAD_PX}

    for view in DIRECTIONS:
        h_key = VIEW_TO_HEAD_KEY[view]
        raw_rgba = cv2.imread(str(hires_dir / f"head_{view}_1024.png"), cv2.IMREAD_UNCHANGED)
        raw_id = cv2.imread(str(ws_heads / f"head_{view}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        body_rgba = cv2.imread(str(_canonical_rgba_path(source_dir, view)), cv2.IMREAD_UNCHANGED)

        clean_id, _, hair_main = _extract_hair_and_clean_head_id(raw_rgba, raw_id)
        stub_rgba, stub_id, hair_main_crop, (crop_x0, _crop_y0, crop_w, _crop_h) = _carve_head_neck_stub(
            raw_rgba, clean_id, hair_main
        )
        hx0_0, hy0_0, dw_0, dh_0 = _align_head_to_body_canonical(stub_rgba, hair_main_crop, body_rgba)

        # Compute true anatomical neck-column center from the full unoccluded turtleneck tube
        # (below jaw/chin occlusion, before shoulder flare) so all 64 cross-combos align cleanly.
        fg_1024 = raw_rgba[:, :, 3] > 24
        blue_1024 = (clean_id[:, :, 0] > 128) & (clean_id[:, :, 1] < 90) & (clean_id[:, :, 2] < 90) & fg_1024
        bys_1024 = np.where(blue_1024)[0]
        b_top_1024 = int(bys_1024.min()) if len(bys_1024) > 0 else 610
        neck_cxs_1024: list[float] = []
        for y_scan in range(b_top_1024 + 55, min(1024, b_top_1024 + 115)):
            xs_scan = np.where(blue_1024[y_scan])[0]
            span_x = int(xs_scan.max() - xs_scan.min()) if len(xs_scan) > 0 else 0
            if 150 <= span_x <= 220:
                neck_cxs_1024.append(0.5 * (float(xs_scan.min()) + float(xs_scan.max())))
        if not neck_cxs_1024:
            for y_scan in range(b_top_1024, min(1024, b_top_1024 + 80)):
                xs_scan = np.where(blue_1024[y_scan])[0]
                span_x = int(xs_scan.max() - xs_scan.min()) if len(xs_scan) > 0 else 0
                if 80 <= span_x <= 225:
                    neck_cxs_1024.append(0.5 * (float(xs_scan.min()) + float(xs_scan.max())))
        head_neck_cx_1024 = float(np.median(neck_cxs_1024)) if neck_cxs_1024 else (float(crop_x0) + float(crop_w) * 0.5)

        # Anchor uniform proportion reduction directly on the updated HD Neck collar ring
        nx_d, ny_d = neck_by_view[view]
        dw_nopad = dw_0 * HEAD_SCALE_FACTOR
        dh_nopad = dh_0 * HEAD_SCALE_FACTOR

        # Seat chin / jaw-base / nape cleanly OVER the collar ring ("el cuello por sobre el anillo del cuello")
        # using b_top_1024 (where head meets turtleneck collar in original 1024px head) + chin/nape balance.
        stub_fg = stub_rgba[:, :, 3] >= 64
        stub_h_px = max(stub_rgba.shape[0], 1)
        stub_skin = stub_fg & (~(stub_id[:, :, 3] > 128)) & (stub_id[:, :, 0] < 90)
        b_top_frac = float(np.clip(float(b_top_1024 - _crop_y0) / float(stub_h_px), 0.55, 0.96))
        if view in ("n", "ne", "nw"):
            anchor_frac = b_top_frac
        elif view in ("s", "se", "sw"):
            # Measure true chin tip in central face band so SE/SW mirror symmetrically and chin rests over collar ring
            cw_s = stub_skin.shape[1]
            cx0_s, cx1_s = int(round(cw_s * 0.34)), int(round(cw_s * 0.66))
            y_sk_s = np.where(stub_skin[:, cx0_s:cx1_s])[0]
            if len(y_sk_s) == 0:
                y_sk_s = np.where(stub_skin)[0]
            skin_frac = float(y_sk_s.max()) / float(stub_h_px) if len(y_sk_s) > 0 else 0.92
            anchor_frac = skin_frac
        else:
            y_sk_s = np.where(stub_skin)[0]
            skin_frac = float(y_sk_s.max()) / float(stub_h_px) if len(y_sk_s) > 0 else 0.92
            anchor_frac = 0.55 * skin_frac + 0.45 * b_top_frac
        seat_dy_by_view: dict[str, float] = {
            "s": 5.6,
            "se": 8.0,
            "sw": 8.0,
            "e": 5.4,
            "w": 5.4,
            "ne": -1.6,
            "nw": -1.6,
            "n": 0.2,
        }
        anchor_target_y = ny_d + seat_dy_by_view.get(view, -2.5)
        hy_c = anchor_target_y - (anchor_frac - 0.5) * dh_nopad

        # Resize carved head to calibrated pixel density so SDF & 4.0px head ink match body pass2
        scale_to_v1 = HEAD_TARGET_DENSITY_PX_H / float(max(stub_rgba.shape[0], 1))
        rw = max(16, int(round(stub_rgba.shape[1] * scale_to_v1)))
        rh = max(16, int(round(stub_rgba.shape[0] * scale_to_v1)))
        col_rs = cv2.resize(stub_rgba, (rw, rh), interpolation=cv2.INTER_AREA)
        id_rs = cv2.resize(stub_id, (rw, rh), interpolation=cv2.INTER_NEAREST)

        # Pad symmetrically by HEAD_PAD_PX and expand disp_size proportionally
        col_pad = cv2.copyMakeBorder(col_rs, HEAD_PAD_PX, HEAD_PAD_PX, HEAD_PAD_PX, HEAD_PAD_PX, cv2.BORDER_CONSTANT, value=(0, 0, 0, 0))
        id_pad = cv2.copyMakeBorder(id_rs, HEAD_PAD_PX, HEAD_PAD_PX, HEAD_PAD_PX, HEAD_PAD_PX, cv2.BORDER_CONSTANT, value=(0, 0, 0, 0))
        new_h, new_w = col_pad.shape[:2]
        dw_pad = dw_nopad * (float(new_w) / float(rw))
        dh_pad = dh_nopad * (float(new_h) / float(rh))

        # Pure alpha==0 RGB bleed only, preserving 100% of carved HD head anti-aliased borders
        col_pad = alpha_bleed_only(col_pad)
        n_hp, lbl_hp, st_hp, _ = cv2.connectedComponentsWithStats((col_pad[:, :, 3] >= 12).astype(np.uint8), connectivity=8)
        if n_hp > 2:
            main_hp = max(range(1, n_hp), key=lambda i: int(st_hp[i, cv2.CC_STAT_AREA]))
            drop_hp = (lbl_hp > 0) & (lbl_hp != main_hp)
            col_pad[drop_hp] = 0
            id_pad[drop_hp] = 0
        cv2.imwrite(str(heads_out / f"{h_key}.png"), col_pad)

        # Clean ID mask for shader + brow-filtered version for hair jiggle map
        interior = col_pad[:, :, 3] >= 128
        id_shader = _voronoi_fill(id_pad, interior, max_dist_px=14.0) if np.any(interior) else id_pad
        cv2.imwrite(str(heads_out / f"{h_key}_id_mask.png"), id_shader)

        # Keep only scalp hair CCs (>= 1500 px) for jiggle map so eyebrows stay rigid
        hair_a = id_pad[:, :, 3] > 128
        n_hc, lbl_hc, st_hc, _ = cv2.connectedComponentsWithStats(hair_a.astype(np.uint8))
        id_jiggle_src = id_pad.copy()
        id_jiggle_src[:, :, 3] = 0
        if n_hc > 1:
            big_hc = max(range(1, n_hc), key=lambda i: int(st_hc[i, cv2.CC_STAT_AREA]))
            id_jiggle_src[lbl_hc == big_hc, 3] = 255
        jiggle = _build_hair_jiggle_mask(col_pad, id_jiggle_src)
        cv2.imwrite(str(heads_out / f"{h_key}_hair_jiggle_mask.png"), jiggle)

        nd = _build_clean_head_normal_depth(col_pad[:, :, 3])
        non_zero = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
        valid_nd = interior & non_zero & (nd[:, :, 3] > 0)
        if np.any(valid_nd):
            nd = _voronoi_fill(nd, valid_nd)
        cv2.imwrite(str(heads_out / f"{h_key}_normal_depth.png"), nd)

        dist_px = cv2.distanceTransform((col_pad[:, :, 3] < 128).astype(np.uint8), cv2.DIST_L2, 5)
        sdf_u8 = np.clip((dist_px / HEAD_SDF_MAX_DIST_PX) * 255.0, 0, 255).astype(np.uint8)
        cv2.imwrite(str(heads_out / f"{h_key}_outline_sdf.png"), sdf_u8)

        # Store symmetric neck-offset metadata; L/R pairs are symmetrized right after the loop
        pad_du_x = float(HEAD_PAD_PX) * (dw_pad / float(max(new_w, 1)))
        rel_neck_x = (head_neck_cx_1024 - float(crop_x0)) / float(max(crop_w, 1))
        raw_ox = dw_pad * 0.5 - (pad_du_x + rel_neck_x * dw_nopad)
        max_ox_by_view: dict[str, float] = {
            "s": 2.0,
            "n": 0.8,
            "se": 1.8,
            "sw": 1.8,
            "e": 2.6,
            "w": 2.6,
            "ne": 2.0,
            "nw": 2.0,
        }
        ox_lim = max_ox_by_view.get(view, 2.5)
        clamped_ox = float(np.clip(raw_ox, -ox_lim, ox_lim))
        anat_piv_x = dw_pad * 0.5 - clamped_ox
        piv_y = ny_d - (hy_c - dh_pad * 0.5)
        entry = {
            "disp_size": [round(dw_pad, 4), round(dh_pad, 4)],
            "neck_pivot_px": [round(anat_piv_x, 1), round(piv_y, 1)],
            "sprite_offset": [round(clamped_ox, 2), round(hy_c - ny_d, 2)],
        }
        metadata[h_key] = entry

        # Legacy alias head_side -> head_side_r
        if h_key == "head_side_r":
            for suffix in (".png", "_id_mask.png", "_normal_depth.png", "_hair_jiggle_mask.png", "_outline_sdf.png"):
                shutil.copy2(heads_out / f"{h_key}{suffix}", heads_out / f"head_side{suffix}")
            metadata["head_side"] = dict(entry)

    # Enforce exact L/R horizontal neck-pivot symmetry across mirrored head pairs
    for r_k, l_k in (("head_front_r", "head_front_l"), ("head_side_r", "head_side_l"), ("head_back_r", "head_back_l")):
        if r_k in metadata and l_k in metadata:
            e_r = metadata[r_k]
            e_l = metadata[l_k]
            ox_r = float(e_r["sprite_offset"][0])
            ox_l = float(e_l["sprite_offset"][0])
            sgn_r = 1.0 if ox_r >= 0.0 else -1.0
            sym_mag = 0.5 * (abs(ox_r) + abs(ox_l))
            new_ox_r = round(sgn_r * sym_mag, 2)
            new_ox_l = round(-sgn_r * sym_mag, 2)
            e_r["sprite_offset"][0] = new_ox_r
            e_l["sprite_offset"][0] = new_ox_l
            e_r["neck_pivot_px"][0] = round(float(e_r["disp_size"][0]) * 0.5 - new_ox_r, 1)
            e_l["neck_pivot_px"][0] = round(float(e_l["disp_size"][0]) * 0.5 - new_ox_l, 1)
            if r_k == "head_front_r":
                oy_avg = round(0.5 * (float(e_r["sprite_offset"][1]) + float(e_l["sprite_offset"][1])), 2)
                e_r["sprite_offset"][1] = oy_avg
                e_l["sprite_offset"][1] = oy_avg
                e_r["neck_pivot_px"][1] = round(float(e_r["disp_size"][1]) * 0.5 - oy_avg, 1)
                e_l["neck_pivot_px"][1] = round(float(e_l["disp_size"][1]) * 0.5 - oy_avg, 1)
            if r_k == "head_side_r" and "head_side" in metadata:
                metadata["head_side"] = dict(e_r)

    meta_path = heads_out / "heads_metadata.json"
    if meta_path.exists():
        prev_meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if "combo_transforms" in prev_meta:
            metadata["combo_transforms"] = prev_meta["combo_transforms"]
    if "combo_transforms" not in metadata:
        ov_path = heads_out.parent / "manual_calibration_overrides.json"
        if ov_path.exists():
            ov = json.loads(ov_path.read_text(encoding="utf-8"))
            ct = ov.get("heads", {}).get("combo_transforms")
            if isinstance(ct, dict):
                metadata["combo_transforms"] = ct
    meta_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata
