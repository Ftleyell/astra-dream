#!/usr/bin/env python3
"""Compile 1:1 2x2 eye sheets into 3-layer Live2D runtime assets for Valentina v2.

Consumes:
  sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/09_eye_live2d_assets/
    - eye_sheets_manifest.json
    - inputs/eyes_4dir_zoom_1x1.png
    - outputs/eyes_4dir_iris_360_1x1.png
    - outputs/eyes_4dir_closed_1x1.png

Writes runtime assets to sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/heads/:
  - <head>_eye_iris.png       (128x128 full 360° unclipped iris RGBA, dark-ink fringe decontaminated)
  - <head>_eye_closed.png     (256x256 aligned closed eyelid + lash RGBA patch, skin matched & guarded)
  - <head>_face_live_mask.png (refined G channel: upper eyelash overhang trimmed; R covers full socket)
  - eye_live2d_meta.json      (calibrated eye_center_uv, eye_iris_size_uv, eye_patch_rect_uv per head)
  - guides/audit_eye_live2d_compiled.png (7-column visual audit across all 4 uncovered-eye heads)
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from scipy import ndimage

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

WORK_SUBDIR = "09_eye_live2d_assets"
IRIS_TEX_PX = 128
IRIS_FILL_FRAC = 0.875  # 112 / 128 -> 8px clean transparent margin on every side
CLOSED_PATCH_PX = 256
DARK_INK_BGR = np.array([10.0, 8.0, 12.0], dtype=np.float32)

# Calibrated native neutral iris geometry matching Valentina v2's resting open gaze:
#   (iris_cx_px, iris_cy_px, iris_w_px, iris_h_px, ring_bold_px_512)
CALIBRATED_IRIS_SPEC: dict[str, tuple[float, float, float, float, float]] = {
    "head_front": (108.3, 165.0, 19.2, 19.8, 19.5),
    "head_front_r": (147.8, 165.8, 20.0, 20.2, 18.5),
    "head_front_l": (80.2, 168.4, 14.6, 18.2, 15.5),
    "head_side_r": (206.2, 159.0, 9.2, 17.8, 12.5),
}


def _extract_iris_sprite(quad_bgr: np.ndarray, ring_bold_px: float) -> np.ndarray:
    """Extract full 360° oval iris onto clean 128x128 RGBA with dark-ink fringe decontamination."""
    qh, qw = quad_bgr.shape[:2]
    gray = cv2.cvtColor(quad_bgr, cv2.COLOR_BGR2GRAY)

    # Flood-fill connected exterior white background from all 4 corners.
    ff = (gray > 238).astype(np.uint8)
    ff_mask = np.zeros((qh + 2, qw + 2), dtype=np.uint8)
    for sx, sy in ((0, 0), (qw - 1, 0), (0, qh - 1), (qw - 1, qh - 1)):
        if ff[sy, sx] == 1:
            cv2.floodFill(ff, ff_mask, (sx, sy), 2)
    exterior = ff == 2
    inside = ~exterior

    # Keep largest interior connected component (clean iris).
    labeled, n_comp = ndimage.label(inside)
    if n_comp > 1:
        counts = np.bincount(labeled.ravel())
        counts[0] = 0
        inside = labeled == int(counts.argmax())
        exterior = ~inside

    # Smooth anti-aliased outer edge alpha on the immediate 1px boundary into exterior.
    k3 = np.ones((3, 3), dtype=np.uint8)
    fringe = (cv2.dilate(inside.astype(np.uint8), k3, iterations=1) > 0) & exterior
    alpha_f = inside.astype(np.float32)
    alpha_f[fringe] = np.clip((248.0 - gray[fringe].astype(np.float32)) / 185.0, 0.0, 1.0)

    rgb = quad_bgr.astype(np.float32)
    # Decontaminate white background spill on semi-transparent boundary toward crisp dark ink.
    edge_decontam = fringe | (inside & (ndimage.distance_transform_edt(inside) < 2.2))
    semi = edge_decontam & (alpha_f < 0.995)
    rgb[semi] = DARK_INK_BGR

    # Ring shoulder & chroma-safe pupil detection for saturated cel-shaded irises (e.g. Deep Amethyst).
    max_ch = quad_bgr.max(axis=2).astype(np.float32)
    min_ch = quad_bgr.min(axis=2).astype(np.float32)
    dist_in = ndimage.distance_transform_edt(inside)
    ring_shoulder = min(ring_bold_px, 16.5)
    ring_reinforce = np.clip((ring_shoulder - dist_in) / 3.0, 0.0, 1.0) * inside.astype(np.float32)
    dark_enough = np.clip((88.0 - max_ch) / 52.0, 0.0, 1.0)
    ring_w = ring_reinforce * dark_enough
    rgb = rgb * (1.0 - ring_w[:, :, None]) + DARK_INK_BGR * ring_w[:, :, None]

    # Isolate pure black/plum-black cat-slit pupil using max_ch + luma gate so dark amethyst fill stays untouched.
    interior_guard = dist_in > max(ring_bold_px + 8.0, 24.0)
    slit_seed = inside & interior_guard & (gray < 46) & (max_ch < 62)
    if np.any(slit_seed):
        sl_lbl, sl_n = ndimage.label(slit_seed)
        if sl_n > 1:
            sl_cnt = np.bincount(sl_lbl.ravel())
            sl_cnt[0] = 0
            slit_seed = sl_lbl == int(sl_cnt.argmax())
        ys_in, xs_in = np.where(inside)
        iris_xc = 0.5 * float(xs_in.min() + xs_in.max())
        iris_half_w = max(0.5 * float(xs_in.max() - xs_in.min()), 1.0)
        sy_idx, sx_idx = np.where(slit_seed)
        sy_min, sy_max = int(sy_idx.min()), int(sy_idx.max())
        slit_h = max(float(sy_max - sy_min), 1.0)
        xs_grid = np.arange(qw, dtype=np.float32)
        slit_alpha = np.zeros((qh, qw), dtype=np.float32)
        for yy_i in range(sy_min, sy_max + 1):
            row_xs = np.where(slit_seed[yy_i])[0]
            if len(row_xs) == 0:
                continue
            xc = 0.5 * float(row_xs[0] + row_xs[-1])
            hw_orig = 0.5 * float(row_xs[-1] - row_xs[0] + 1)
            skew = abs(xc - iris_xc) / iris_half_w
            extra_pad = 2.0 * (1.0 - 0.6 * min(skew * 2.5, 1.0))
            t_v = (yy_i - sy_min) / slit_h
            # Smooth sin^1.15 vertical envelope keeps both almond tips sharply tapered.
            taper = float(np.sin(np.pi * np.clip(t_v, 0.0, 1.0)) ** 1.15)
            hw_target = hw_orig * 1.15 + extra_pad * taper
            row_cov = np.clip(hw_target - np.abs(xs_grid - xc) + 0.75, 0.0, 1.0)
            slit_alpha[yy_i] = np.maximum(slit_alpha[yy_i], row_cov)
        slit_alpha *= inside.astype(np.float32) * (dist_in > max(ring_bold_px * 0.9, 14.0)).astype(np.float32)
        pupil_ink = np.array([18.0, 10.0, 20.0], dtype=np.float32)
        rgb = rgb * (1.0 - slit_alpha[:, :, None]) + pupil_ink[None, None, :] * slit_alpha[:, :, None]

    # Preserve chromatic cel-shaded irises (e.g. Deep Amethyst); only apply fallback pale-lavender boost when near-achromatic.
    fill_probe = inside & (dist_in > ring_bold_px * 0.9) & (max_ch > 75.0)
    median_chroma = float(np.median(max_ch[fill_probe] - min_ch[fill_probe])) if np.any(fill_probe) else 0.0
    if median_chroma < 28.0:
        ys_in, xs_in = np.where(inside)
        iy_top, iy_bot = float(ys_in.min()), float(ys_in.max())
        norm_y = np.clip((np.arange(qh, dtype=np.float32)[:, None] - iy_top) / max(iy_bot - iy_top, 1.0), 0.0, 1.0)
        rgb_luma = (0.299 * rgb[:, :, 2] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 0])
        is_fill = inside & (dist_in > ring_bold_px * 0.85) & (rgb_luma > 95.0)
        upper_shade = np.clip((0.46 - norm_y) / 0.34, 0.0, 1.0) * is_fill.astype(np.float32)
        lower_glow = np.exp(-((norm_y - 0.74) / 0.17) ** 2) * is_fill.astype(np.float32)
        upper_target_bgr = np.array([154.0, 114.0, 128.0], dtype=np.float32)
        lower_target_bgr = np.array([242.0, 226.0, 232.0], dtype=np.float32)
        rgb = rgb * (1.0 - 0.52 * upper_shade[:, :, None]) + upper_target_bgr[None, None, :] * (0.52 * upper_shade[:, :, None])
        rgb = rgb * (1.0 - 0.38 * lower_glow[:, :, None]) + lower_target_bgr[None, None, :] * (0.38 * lower_glow[:, :, None])

    ys, xs = np.where(alpha_f > 0.03)
    if len(xs) == 0:
        raise RuntimeError("Empty extracted iris alpha mask.")
    ix0, ix1 = int(xs.min()), int(xs.max())
    iy0, iy1 = int(ys.min()), int(ys.max())

    crop_rgb = rgb[iy0 : iy1 + 1, ix0 : ix1 + 1]
    crop_a = alpha_f[iy0 : iy1 + 1, ix0 : ix1 + 1]
    crop_bgra = np.dstack([crop_rgb, crop_a * 255.0])

    # Premultiply on dark ink so INTER_AREA downsampling never pulls white into transparent fringe.
    fill_px = int(round(IRIS_TEX_PX * IRIS_FILL_FRAC))
    margin_px = (IRIS_TEX_PX - fill_px) // 2
    resized = cv2.resize(crop_bgra, (fill_px, fill_px), interpolation=cv2.INTER_AREA)

    canvas = np.zeros((IRIS_TEX_PX, IRIS_TEX_PX, 4), dtype=np.float32)
    canvas[:, :, :3] = DARK_INK_BGR
    canvas[margin_px : margin_px + fill_px, margin_px : margin_px + fill_px] = resized

    # Fill pure transparent texels with dark ink bleed so GPU mipmaps have zero white halo.
    a_out = canvas[:, :, 3]
    transparent = a_out < 1.5
    canvas[transparent, :3] = DARK_INK_BGR
    return np.clip(np.rint(canvas), 0, 255).astype(np.uint8)


def _lower_convex_envelope(xs: np.ndarray, ys: np.ndarray) -> np.ndarray:
    """Compute monotone-smooth concave-down eyelid arch (lower y-hull across x)."""
    pts = sorted(zip(xs.tolist(), ys.tolist()), key=lambda p: p[0])
    hull: list[tuple[float, float]] = []
    for px, py in pts:
        while len(hull) >= 2:
            x1, y1 = hull[-2]
            x2, y2 = hull[-1]
            # Keep concave-down lid arch: pop intermediate valleys (y dipping down > arch chord).
            cross = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)
            if cross <= 0.0:
                hull.pop()
            else:
                break
        hull.append((float(px), float(py)))
    hx = np.array([p[0] for p in hull], dtype=np.float32)
    hy = np.array([p[1] for p in hull], dtype=np.float32)
    all_x = np.arange(int(xs[0]), int(xs[-1]) + 1, dtype=np.float32)
    return np.interp(all_x, hx, hy)


def _refine_open_eye_socket_mask(
    head_bgra: np.ndarray,
    flm_bgra: np.ndarray,
    iris_cx: float,
    head_name: str,
) -> np.ndarray:
    """Trim solid black upper eyelash overhang & mauve upper-lid bleed from channel G."""
    out_flm = flm_bgra.copy()
    g_old = flm_bgra[:, :, 1] > 127
    # Ensure lid sweep mask (R channel index 2) always encloses full original eye socket + lash region.
    out_flm[:, :, 2] = np.maximum(out_flm[:, :, 2], flm_bgra[:, :, 1])

    bgr = head_bgra[:, :, :3].astype(np.float32)
    b, gr, r = bgr[:, :, 0], bgr[:, :, 1], bgr[:, :, 2]
    lum = 0.299 * r + 0.587 * gr + 0.114 * b

    ys, xs = np.where(g_old)
    gx0, gx1 = int(xs.min()), int(xs.max())
    gy0, gy1 = int(ys.min()), int(ys.max())

    # Identify pure sclera OR non-ink eyeball pixels below upper lash.
    is_sclera = g_old & (lum >= 216.0) & ((r - b) < 16.0)
    is_dark = lum < 105.0
    is_warm_lid = ((r - b) >= 16.0) & (lum < 210.0)
    is_eyeball_bright = g_old & (~is_dark) & (~is_warm_lid)

    if head_name == "head_side_r":
        y_scl = np.where(is_sclera)[0]
        if len(y_scl) > 0:
            scl_top = int(y_scl.min())
            is_eyeball_bright[:scl_top, :] = False

    valid_cols: list[int] = []
    valid_tops: list[float] = []
    for x in range(gx0, gx1 + 1):
        col_bright = np.where(is_eyeball_bright[:, x])[0]
        if len(col_bright) > 0:
            top_y = int(col_bright[0])
            col_dark = np.where(is_dark[gy0 : gy1 + 1, x])[0] + gy0
            if len(col_dark) > 0 and top_y < int(col_dark[0]):
                col_scl = np.where(is_sclera[:, x])[0]
                if len(col_scl) > 0 and int(col_scl[0]) > top_y + 1:
                    top_y = int(col_scl[0])
            valid_cols.append(x)
            valid_tops.append(float(top_y))

    y_top_col = np.full(head_bgra.shape[1], gy1 + 1, dtype=np.float32)
    if len(valid_cols) >= 3:
        vc = np.array(valid_cols, dtype=np.int32)
        vy = np.array(valid_tops, dtype=np.float32)
        arch_y = _lower_convex_envelope(vc, vy)
        all_cols = np.arange(vc[0], vc[-1] + 1)
        y_top_col[all_cols] = arch_y
        # Extend eyelid tangent smoothly to shaded far corner (e.g. head_side_r iris against nasal bridge).
        if vc[-1] < gx1 and head_name == "head_side_r":
            slope = float(arch_y[-1] - arch_y[max(0, len(arch_y) - 4)]) / max(float(min(3, len(arch_y) - 1)), 1.0)
            slope = float(np.clip(slope, 0.0, 0.45))
            for ex in range(int(vc[-1]) + 1, gx1 + 1):
                y_top_col[ex] = y_top_col[int(vc[-1])] + slope * float(ex - int(vc[-1]))

    g_clean = g_old.copy()
    yy = np.arange(head_bgra.shape[0])[:, None]
    above_cut = yy < np.rint(y_top_col)[None, :]
    g_clean[above_cut] = False

    if len(valid_cols) >= 3:
        g_clean[:, : valid_cols[0]] = False
        if head_name != "head_side_r":
            g_clean[:, valid_cols[-1] + 1 :] = False

    g_clean = ndimage.binary_fill_holes(g_clean)
    labeled, n_comp = ndimage.label(g_clean)
    if n_comp > 1:
        best_lbl = 1
        best_dist = 1e9
        for cid in range(1, n_comp + 1):
            cys, cxs = np.where(labeled == cid)
            if len(cxs) < 12:
                continue
            d = abs(float(cxs.mean()) - iris_cx)
            if d < best_dist:
                best_dist = d
                best_lbl = cid
        g_clean = labeled == best_lbl

    # Mild sub-pixel AA on aperture boundary without expanding upward over the upper black eyelash.
    g_soft = cv2.GaussianBlur(g_clean.astype(np.float32), (0, 0), sigmaX=0.55, sigmaY=0.55)
    g_soft[~g_old] = 0.0
    g_soft[above_cut] = 0.0
    out_flm[:, :, 1] = np.clip(np.rint(g_soft * 255.0), 0, 255).astype(np.uint8)
    return out_flm


def _build_closed_eye_patch(
    open_panel_bgr: np.ndarray,
    closed_panel_bgr: np.ndarray,
    native_crop_bgra: np.ndarray,
    native_crop_id: np.ndarray,
    native_crop_flm: np.ndarray,
) -> np.ndarray:
    """Register closed-eye AI panel to native crop, color-match skin, and feather alpha cleanly."""
    ph, pw = open_panel_bgr.shape[:2]

    # 1. Sub-pixel registration using brow/cheek bands (outside eye band y=310..670).
    o_g = cv2.cvtColor(open_panel_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    c_g = cv2.cvtColor(closed_panel_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    o_ctx = np.vstack([o_g[:290, :], o_g[680:, :]])
    c_ctx = np.vstack([c_g[:290, :], c_g[680:, :]])
    shift, resp = cv2.phaseCorrelate(o_ctx, c_ctx)
    if abs(shift[0]) > 0.05 or abs(shift[1]) > 0.05:
        mat = np.float32([[1.0, 0.0, -shift[0]], [0.0, 1.0, -shift[1]]])
        closed_reg = cv2.warpAffine(
            closed_panel_bgr, mat, (pw, ph), flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE
        )
    else:
        closed_reg = closed_panel_bgr.copy()

    # 2. Upscale native 80x80 ground truth crop, id_mask, and FLM to 256x256.
    closed_256 = cv2.resize(closed_reg, (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_AREA).astype(
        np.float32
    )
    open_256 = cv2.resize(open_panel_bgr, (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_AREA).astype(
        np.float32
    )
    nat_bgr_256 = cv2.resize(
        native_crop_bgra[:, :, :3], (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_LINEAR
    ).astype(np.float32)
    nat_a_256 = (
        cv2.resize(native_crop_bgra[:, :, 3], (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_LINEAR)
        / 255.0
    )

    id_256 = cv2.resize(native_crop_id, (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_NEAREST)
    flm_256 = cv2.resize(native_crop_flm, (CLOSED_PATCH_PX, CLOSED_PATCH_PX), interpolation=cv2.INTER_LINEAR)

    # Mask semantic regions in 256x256: id_mask BGRA -> A=hair, R(idx 2)=monocle, B(idx 0)=neck.
    is_hair = id_256[:, :, 3] > 110
    is_monocle = id_256[:, :, 2] > 110
    # Brow channel (flm.b = idx 0) strictly above the upper eyelid zone.
    flm_r_ys = np.where(flm_256[:, :, 2] > 80)[0]
    brow_y_limit = int(flm_r_ys.min()) + 16 if len(flm_r_ys) > 0 else int(CLOSED_PATCH_PX * 0.45)
    is_brow = (flm_256[:, :, 0] > 95) & (np.arange(CLOSED_PATCH_PX)[:, None] < brow_y_limit)

    is_skin_ref = (nat_a_256 > 0.85) & (~is_hair) & (~is_monocle) & (~is_brow)
    diff_max = np.max(np.abs(closed_256 - open_256), axis=2)

    # Color-match skin offset from stable surrounding skin pixels (diff < 8) to eliminate tone seams.
    stable_skin = is_skin_ref & (diff_max < 9.0)
    if stable_skin.sum() > 250:
        med_closed = np.median(closed_256[stable_skin], axis=0)
        med_native = np.median(nat_bgr_256[stable_skin], axis=0)
        skin_offset = np.clip(med_native - med_closed, -16.0, 16.0)
        # Preserve pure dark ink closed lash lines while matching skin tint across lighter texels.
        closed_luma = (0.299 * closed_256[:, :, 2] + 0.587 * closed_256[:, :, 1] + 0.114 * closed_256[:, :, 0])
        ink_protect = np.clip((closed_luma - 55.0) / 70.0, 0.0, 1.0)
        closed_256 = np.clip(closed_256 + skin_offset[None, None, :] * ink_protect[:, :, None], 0.0, 255.0)

    # 3. Construct feathered alpha centered tightly on changed eye region + original socket/lid masks.
    flm_eye_lid = np.maximum(flm_256[:, :, 1], flm_256[:, :, 2]) > 95
    # Restrict diff mask away from tiny panel-border jitter using spatial core connected to eye socket.
    diff_raw = (diff_max > 14.0) & (~is_hair) & (~is_monocle) & (nat_a_256 > 0.7)
    labeled_d, nd_comp = ndimage.label(diff_raw | flm_eye_lid)
    core_mask = flm_eye_lid.copy()
    if nd_comp > 0:
        for cid in range(1, nd_comp + 1):
            comp = labeled_d == cid
            if np.any(comp & flm_eye_lid):
                core_mask |= comp

    k7 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    dilated = cv2.dilate(core_mask.astype(np.uint8), k7, iterations=1) > 0
    dilated = ndimage.binary_fill_holes(dilated)

    # Soft feather 4.5 px, then force 1.0 inside core open-eyeball + new closed lash pixels.
    alpha_f = cv2.GaussianBlur(dilated.astype(np.float32), (0, 0), sigmaX=4.5, sigmaY=4.5)
    must_opaque = flm_eye_lid | ((diff_max > 22.0) & core_mask)
    alpha_f = np.maximum(alpha_f, must_opaque.astype(np.float32))

    # Strict protection guards: never touch eyebrows, hair, monocle, or outside head alpha.
    guard_block = is_hair | is_monocle | is_brow | (nat_a_256 < 0.75)
    guard_keep = 1.0 - cv2.GaussianBlur(guard_block.astype(np.float32), (0, 0), sigmaX=1.6, sigmaY=1.6)
    alpha_f = np.clip(alpha_f * np.clip(guard_keep, 0.0, 1.0), 0.0, 1.0)

    # Zero tiny residual noise < 0.02 and clamp.
    alpha_f[alpha_f < 0.015] = 0.0
    out = np.dstack([closed_256, alpha_f * 255.0])
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def _checkerboard(h: int, w: int, cell: int = 12) -> np.ndarray:
    yy, xx = np.indices((h, w))
    chk = ((yy // cell) + (xx // cell)) % 2
    out = np.zeros((h, w, 3), dtype=np.float32)
    out[chk == 0] = np.array([185.0, 190.0, 198.0], dtype=np.float32)
    out[chk == 1] = np.array([128.0, 134.0, 144.0], dtype=np.float32)
    return out


def _render_audit_row(
    head_name: str,
    head_bgra: np.ndarray,
    refined_flm: np.ndarray,
    iris_bgra: np.ndarray,
    closed_bgra: np.ndarray,
    crop_rect: list[int],
    iris_spec: tuple[float, float, float, float, float],
) -> np.ndarray:
    """Render 7-column x 320px high-zoom diagnostic strip for a single head."""
    cell_px = 320
    x0, y0, cw, ch = crop_rect
    h_px, w_px = head_bgra.shape[:2]
    iris_cx, iris_cy, iris_w, iris_h, _ = iris_spec

    crop_orig = head_bgra[y0 : y0 + ch, x0 : x0 + cw]
    # Alpha composite over light neutral studio slate for visibility.
    bg_plate = np.full((ch, cw, 3), [245.0, 244.0, 248.0], dtype=np.float32)
    orig_a = crop_orig[:, :, 3:4].astype(np.float32) / 255.0
    c1_bgr = crop_orig[:, :, :3].astype(np.float32) * orig_a + bg_plate * (1.0 - orig_a)

    # Col 2: Refined G aperture cyan contour over native crop.
    c1_320 = cv2.resize(np.clip(c1_bgr, 0, 255).astype(np.uint8), (cell_px, cell_px), interpolation=cv2.INTER_NEAREST)
    c2_320 = c1_320.copy()
    g_crop = (refined_flm[y0 : y0 + ch, x0 : x0 + cw, 1] > 127).astype(np.uint8) * 255
    g_320 = cv2.resize(g_crop, (cell_px, cell_px), interpolation=cv2.INTER_NEAREST)
    contours, _ = cv2.findContours(g_320, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(c2_320, contours, -1, (255, 225, 0), 2, lineType=cv2.LINE_AA)

    # Col 3: Extracted 360° iris on checkerboard.
    iris_rs = cv2.resize(iris_bgra, (cell_px, cell_px), interpolation=cv2.INTER_AREA).astype(np.float32)
    chk = _checkerboard(cell_px, cell_px, cell=16)
    ia = iris_rs[:, :, 3:4] / 255.0
    c3_320 = np.clip(iris_rs[:, :, :3] * ia + chk * (1.0 - ia), 0, 255).astype(np.uint8)

    # Col 4 & 5: Simulate Live2D Eye at Neutral (0,0) and Gaze Down-Right (+2.8, +2.6 px) at 320px resolution.
    flm_g_320 = (
        cv2.resize(refined_flm[y0 : y0 + ch, x0 : x0 + cw, 1], (cell_px, cell_px), interpolation=cv2.INTER_LINEAR)
        / 255.0
    )
    scale_320 = cell_px / float(cw)
    # Probes matching shader upper-lid fixed shadow.
    sh_far = np.roll(flm_g_320, int(round(3.8 * scale_320)), axis=0)
    sh_near = np.roll(flm_g_320, int(round(1.9 * scale_320)), axis=0)
    lid_sh_w = np.clip(((1.0 - sh_far) * 0.55 + (1.0 - sh_near) * 0.45) * 0.72, 0.0, 0.85)

    def _sim_gaze(dx_px: float, dy_px: float) -> np.ndarray:
        yy, xx = np.mgrid[0:cell_px, 0:cell_px].astype(np.float32)
        nat_x = x0 + (xx + 0.5) / scale_320
        nat_y = y0 + (yy + 0.5) / scale_320
        span_w = iris_w / IRIS_FILL_FRAC
        span_h = iris_h / IRIS_FILL_FRAC
        lu = (nat_x - (iris_cx + dx_px)) / span_w + 0.5
        lv = (nat_y - (iris_cy + dy_px)) / span_h + 0.5
        map_x = lu * float(IRIS_TEX_PX) - 0.5
        map_y = lv * float(IRIS_TEX_PX) - 0.5
        sampled = cv2.remap(
            iris_bgra.astype(np.float32),
            map_x,
            map_y,
            interpolation=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0, 0),
        )
        sclera = np.full((cell_px, cell_px, 3), [249.0, 245.0, 245.0], dtype=np.float32)
        sa = sampled[:, :, 3:4] / 255.0
        eye_rgb = sclera * (1.0 - sa) + sampled[:, :, :3] * sa
        # Apply fixed upper-lid cast shadow.
        sh_tint = np.array([198.0, 162.0, 173.0], dtype=np.float32) / 255.0  # cool lavender shadow BGR
        eye_rgb *= 1.0 * (1.0 - lid_sh_w[:, :, None]) + sh_tint[None, None, :] * lid_sh_w[:, :, None]
        # Reactive specular catchlight.
        c1x, c1y = 0.50 - 0.08 + dx_px * 0.013, 0.42 - 0.08 + dy_px * 0.013
        d1 = np.sqrt((lu - c1x) ** 2 + ((lv - c1y) * 1.15) ** 2)
        spec = np.clip((0.11 - d1) / 0.04, 0.0, 1.0) * (sa[:, :, 0] > 0.55) * (1.0 - (1.0 - sh_near) * 0.4)
        eye_rgb = np.clip(eye_rgb + spec[:, :, None] * 210.0, 0, 255)
        w_eye = np.clip((flm_g_320 - 0.14) / 0.42, 0.0, 1.0)[:, :, None]
        comp = c1_320.astype(np.float32) * (1.0 - w_eye) + eye_rgb * w_eye
        return np.clip(np.rint(comp), 0, 255).astype(np.uint8)

    c4_320 = _sim_gaze(0.0, 0.0)
    c5_320 = _sim_gaze(2.8, 2.6)

    # Col 6: Closed eye patch composited onto native 80x80 crop.
    closed_320 = cv2.resize(closed_bgra, (cell_px, cell_px), interpolation=cv2.INTER_LINEAR).astype(np.float32)
    ca = closed_320[:, :, 3:4] / 255.0
    c6_320 = np.clip(np.rint(c1_320.astype(np.float32) * (1.0 - ca) + closed_320[:, :, :3] * ca), 0, 255).astype(
        np.uint8
    )

    # Col 7: Simulated Combat Zoom 1.15x (34x34 area-sampled eye patch upscaled NN to 320px).
    combat_34 = cv2.resize(c4_320, (34, 34), interpolation=cv2.INTER_AREA)
    c7_320 = cv2.resize(combat_34, (cell_px, cell_px), interpolation=cv2.INTER_NEAREST)

    row_img = np.hstack([c1_320, c2_320, c3_320, c4_320, c5_320, c6_320, c7_320])
    cv2.putText(row_img, head_name, (10, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.72, (0, 235, 255), 2, cv2.LINE_AA)
    return row_img


def _bake_neutral_eye_into_head(
    head_bgra: np.ndarray,
    refined_flm: np.ndarray,
    iris_bgra: np.ndarray,
    iris_spec: tuple[float, float, float, float, float],
) -> np.ndarray:
    """Bake 4x-supersampled neutral Deep Amethyst iris + sclera into base head albedo (preserving alpha)."""
    out = head_bgra.copy()
    h_px, w_px = out.shape[:2]
    flm_g = refined_flm[:, :, 1].astype(np.float32) / 255.0
    ys, xs = np.where(flm_g > 0.04)
    if len(xs) == 0:
        return out

    bx0 = max(0, int(xs.min()) - 6)
    bx1 = min(w_px, int(xs.max()) + 7)
    by0 = max(0, int(ys.min()) - 6)
    by1 = min(h_px, int(ys.max()) + 7)
    bw, bh = bx1 - bx0, by1 - by0
    if bw <= 0 or bh <= 0:
        return out

    ss = 4
    sh, sw = bh * ss, bw * ss
    flm_g_patch = flm_g[by0:by1, bx0:bx1]
    flm_g_4x = cv2.resize(flm_g_patch, (sw, sh), interpolation=cv2.INTER_LINEAR)
    sh_far_4x = ndimage.shift(flm_g_4x, (3.8 * ss, 0.0), order=1, mode="nearest")
    sh_near_4x = ndimage.shift(flm_g_4x, (1.9 * ss, 0.0), order=1, mode="nearest")
    lid_sh_w = np.clip(((1.0 - sh_far_4x) * 0.55 + (1.0 - sh_near_4x) * 0.45) * 0.72, 0.0, 0.85)

    iris_cx, iris_cy, iris_w, iris_h, _ = iris_spec
    yy_4, xx_4 = np.mgrid[0:sh, 0:sw].astype(np.float32)
    nat_x = float(bx0) + (xx_4 + 0.5) / float(ss)
    nat_y = float(by0) + (yy_4 + 0.5) / float(ss)
    span_w = iris_w / IRIS_FILL_FRAC
    span_h = iris_h / IRIS_FILL_FRAC
    lu = (nat_x - iris_cx) / span_w + 0.5
    lv = (nat_y - iris_cy) / span_h + 0.5
    map_x = lu * float(IRIS_TEX_PX) - 0.5
    map_y = lv * float(IRIS_TEX_PX) - 0.5

    sampled = cv2.remap(
        iris_bgra.astype(np.float32),
        map_x,
        map_y,
        interpolation=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )
    sclera = np.full((sh, sw, 3), [249.0, 245.0, 245.0], dtype=np.float32)
    sa = sampled[:, :, 3:4] / 255.0
    eye_4x = sclera * (1.0 - sa) + sampled[:, :, :3] * sa
    sh_tint = np.array([198.0, 162.0, 173.0], dtype=np.float32) / 255.0  # cool lavender cast BGR
    eye_4x *= 1.0 * (1.0 - lid_sh_w[:, :, None]) + sh_tint[None, None, :] * lid_sh_w[:, :, None]

    eye_1x = cv2.resize(eye_4x, (bw, bh), interpolation=cv2.INTER_AREA)
    w_eye = np.clip((flm_g_patch - 0.14) / 0.42, 0.0, 1.0)[:, :, None]
    orig_patch = out[by0:by1, bx0:bx1, :3].astype(np.float32)
    comp = orig_patch * (1.0 - w_eye) + eye_1x * w_eye
    out[by0:by1, bx0:bx1, :3] = np.clip(np.rint(comp), 0, 255).astype(np.uint8)
    return out


def ingest_eye_assets(heads_dir: Path, work_dir: Path) -> dict[str, Any]:
    manifest_path = work_dir / "eye_sheets_manifest.json"
    open_sheet_path = work_dir / "inputs" / "eyes_4dir_zoom_1x1.png"
    iris_sheet_path = work_dir / "outputs" / "eyes_4dir_iris_360_1x1.png"
    closed_sheet_path = work_dir / "outputs" / "eyes_4dir_closed_1x1.png"

    for p in (manifest_path, open_sheet_path, iris_sheet_path, closed_sheet_path):
        if not p.exists():
            raise FileNotFoundError(f"Missing required eye pipeline input: {p}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    open_sheet = cv2.imread(str(open_sheet_path), cv2.IMREAD_COLOR)
    iris_sheet = cv2.imread(str(iris_sheet_path), cv2.IMREAD_COLOR)
    closed_sheet_raw = cv2.imread(str(closed_sheet_path), cv2.IMREAD_COLOR)
    closed_sheet = cv2.resize(closed_sheet_raw, tuple(manifest["sheet_size"]), interpolation=cv2.INTER_LANCZOS4)

    ih, iw = iris_sheet.shape[:2]
    qw, qh = iw // 2, ih // 2

    meta_out: dict[str, Any] = {}
    audit_rows: list[np.ndarray] = []

    for head_name, info in manifest["heads"].items():
        row, col = int(info["slot_rc"][0]), int(info["slot_rc"][1])
        px, py, pw, ph = [int(v) for v in info["panel_rect"]]
        x0, y0, cw, ch = [int(v) for v in info["native_crop_rect"]]

        head_path = heads_dir / f"{head_name}.png"
        id_path = heads_dir / f"{head_name}_id_mask.png"
        flm_path = heads_dir / f"{head_name}_face_live_mask.png"
        head_backup_dir = work_dir / "outputs" / "_heads_native_backup"
        head_backup_dir.mkdir(parents=True, exist_ok=True)
        head_bak = head_backup_dir / f"{head_name}.png"
        if head_path.exists() and not head_bak.exists():
            shutil.copy2(head_path, head_bak)
        head_src = head_bak if head_bak.exists() else head_path

        flm_backup_dir = work_dir / "outputs" / "_flm_backup"
        flm_backup_dir.mkdir(parents=True, exist_ok=True)
        flm_bak = flm_backup_dir / f"{head_name}_face_live_mask.png"
        if flm_path.exists() and not flm_bak.exists():
            shutil.copy2(flm_path, flm_bak)
        flm_src = flm_bak if flm_bak.exists() else flm_path

        head_bgra = cv2.imread(str(head_src), cv2.IMREAD_UNCHANGED)
        id_bgra = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
        flm_bgra = cv2.imread(str(flm_src), cv2.IMREAD_UNCHANGED)
        if head_bgra is None or id_bgra is None or flm_bgra is None:
            raise FileNotFoundError(f"Missing head textures for {head_name} in {heads_dir}")

        h_px, w_px = head_bgra.shape[:2]
        iris_cx, iris_cy, iris_w, iris_h, ring_bold_px = CALIBRATED_IRIS_SPEC[head_name]

        # 1. Extract & save 128x128 360° iris sprite.
        quad_bgr = iris_sheet[row * qh : (row + 1) * qh, col * qw : (col + 1) * qw]
        iris_bgra = _extract_iris_sprite(quad_bgr, ring_bold_px)
        cv2.imwrite(str(heads_dir / f"{head_name}_eye_iris.png"), iris_bgra)

        # 2. Build & save 256x256 closed-eye patch aligned 1:1 to native_crop_rect.
        open_panel = open_sheet[py : py + ph, px : px + pw]
        closed_panel = closed_sheet[py : py + ph, px : px + pw]
        closed_bgra = _build_closed_eye_patch(
            open_panel,
            closed_panel,
            head_bgra[y0 : y0 + ch, x0 : x0 + cw],
            id_bgra[y0 : y0 + ch, x0 : x0 + cw],
            flm_bgra[y0 : y0 + ch, x0 : x0 + cw],
        )
        cv2.imwrite(str(heads_dir / f"{head_name}_eye_closed.png"), closed_bgra)

        # 3. Refine FLM channel G (clean open aperture beneath solid upper black eyelash).
        refined_flm = _refine_open_eye_socket_mask(head_bgra, flm_bgra, iris_cx, head_name)
        cv2.imwrite(str(flm_path), refined_flm)

        # 3b. Bake 4x SSAA neutral Deep Amethyst iris + sclera into base head albedo for static/baseline rigs.
        baked_head = _bake_neutral_eye_into_head(head_bgra, refined_flm, iris_bgra, CALIBRATED_IRIS_SPEC[head_name])
        cv2.imwrite(str(head_path), baked_head)

        # 4. Record calibrated UV metadata.
        meta_out[head_name] = {
            "native_size": [w_px, h_px],
            "eye_center_uv": [round(iris_cx / float(w_px), 6), round(iris_cy / float(h_px), 6)],
            "eye_iris_size_uv": [
                round((iris_w / IRIS_FILL_FRAC) / float(w_px), 6),
                round((iris_h / IRIS_FILL_FRAC) / float(h_px), 6),
            ],
            "eye_patch_rect_uv": [
                round(x0 / float(w_px), 6),
                round(y0 / float(h_px), 6),
                round(cw / float(w_px), 6),
                round(ch / float(h_px), 6),
            ],
            "iris_fill_frac": IRIS_FILL_FRAC,
            "eye_palette": "deep_amethyst",
        }

        audit_rows.append(
            _render_audit_row(
                head_name,
                head_bgra,
                refined_flm,
                iris_bgra,
                closed_bgra,
                [x0, y0, cw, ch],
                CALIBRATED_IRIS_SPEC[head_name],
            )
        )

    # Alias head_side -> head_side_r
    for suffix in (".png", "_eye_iris.png", "_eye_closed.png", "_face_live_mask.png"):
        shutil.copy2(heads_dir / f"head_side_r{suffix}", heads_dir / f"head_side{suffix}")
    meta_out["head_side"] = dict(meta_out["head_side_r"])

    meta_path = heads_dir / "eye_live2d_meta.json"
    meta_path.write_text(json.dumps(meta_out, indent=2) + "\n", encoding="utf-8")

    # Build audit banner header + stacked rows.
    headers = [
        "1. Original",
        "2. Socket G (Refined)",
        "3. Iris 360 (Alpha)",
        "4. Live2D Neutral",
        "5. Gaze (+2.8,+2.6)",
        "6. Closed Eye",
        "7. Combat Zoom 1.15x",
    ]
    banner = np.full((38, 320 * len(headers), 3), (28, 32, 42), dtype=np.uint8)
    for ci, title in enumerate(headers):
        cv2.putText(banner, title, (ci * 320 + 12, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.68, (220, 235, 255), 2, cv2.LINE_AA)
    audit_img = np.vstack([banner] + audit_rows)
    audit_path = work_dir / "guides" / "audit_eye_live2d_compiled.png"
    cv2.imwrite(str(audit_path), audit_img)
    return {"meta": meta_out, "audit_path": str(audit_path)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile Live2D 3-layer eye assets for Valentina v2.")
    parser.add_argument("--heads-dir", type=Path, default=REPO_ROOT / DEFAULT_OUT_DIR / "heads")
    parser.add_argument("--work-dir", type=Path, default=REPO_ROOT / DEFAULT_SOURCE_DIR / WORK_SUBDIR)
    args = parser.parse_args()

    res = ingest_eye_assets(args.heads_dir, args.work_dir)
    print(f"Compiled Live2D eye runtime assets for {len(res['meta'])} head entries.")
    print(f"Audit image: {res['audit_path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
