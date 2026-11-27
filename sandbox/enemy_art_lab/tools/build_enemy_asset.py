#!/usr/bin/env python3
"""
Astra Dream — Enemy 2.5D Asset Pack Compiler (Sandbox EnemyArtLab)
Compiles a 3-part exploded albedo sheet + semantic ID, Ink, and Normal sheets
into the 3+1 packed RGBA texture contract + rig_meta.json + visual audit sheet.

Outputs per part (<out_dir>/<part>_*.png):
  - <part>_albedo.png        (sRGB RGBA, defringed alpha)
  - <part>_normal_height.png (Linear RGBA: R=Nx, G=Ny, B=Height, A=PrimaryEmissive)
  - <part>_ilm_sdf.png       (Linear RGBA @ 2x res: R=AO, G=Specular, B=InkSDF, A=OuterSDF)
  - <part>_fx_motion.png     (Linear RGBA: R=MotionWeight, G=RecolorZone, B=SecondaryEmissive, A=SSS)

Also mirrors right-side modules (elytron_r -> elytron_l, inner_wing_r -> inner_wing_l)
with exact Nx inversion (R' = 255 - R) on normal_height.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple

import cv2
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

REPO_ROOT = Path(__file__).resolve().parents[3]
PILOT_TOOLS_DIR = REPO_ROOT / "sandbox" / "pilot_rig_lab" / "tools"
if str(PILOT_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(PILOT_TOOLS_DIR))

try:
    from process_masked_5parts import upscale_with_upscayl  # type: ignore
except Exception:
    upscale_with_upscayl = None  # type: ignore


INK_SDF_RANGE_NATIVE_PX: float = 8.0
OUTER_SDF_RANGE_NATIVE_PX: float = 24.0


def _load_rgb(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGB"), dtype=np.uint8)


def _save_rgba(path: Path, rgba: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(path, format="PNG")


def _voronoi_fill(arr: np.ndarray, valid_mask: np.ndarray, max_dist_px: float = -1.0) -> np.ndarray:
    """Propagate nearest valid pixel values via Euclidean Voronoi into invalid pixels."""
    if not np.any(valid_mask):
        return arr.copy()
    out = arr.copy()
    invalid = ~valid_mask
    if not np.any(invalid):
        return out
    dists, labels = cv2.distanceTransformWithLabels(
        invalid.astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    oy, ox = np.where(valid_mask)
    fill_mask = invalid if max_dist_px < 0.0 else (invalid & (dists <= max_dist_px))
    if np.any(fill_mask):
        fy, fx = np.where(fill_mask)
        idx = labels[fy, fx] - 1
        out[fy, fx] = arr[oy[idx], ox[idx]]
    return out


def _alpha_bleed_and_defringe(rgba: np.ndarray, bg_gray: Tuple[int, int, int] = (128, 128, 128)) -> np.ndarray:
    """Bleed opaque RGB into transparent regions and strip #808080 border fringes."""
    out = rgba.copy()
    alpha = out[:, :, 3]
    opaque = alpha >= 200
    if not np.any(opaque):
        opaque = alpha > 40
    if not np.any(opaque):
        return out

    _, labels = cv2.distanceTransformWithLabels(
        (~opaque).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    oy, ox = np.where(opaque)

    trans = alpha == 0
    if np.any(trans):
        ty, tx = np.where(trans)
        idx = labels[ty, tx] - 1
        out[ty, tx, :3] = out[oy[idx], ox[idx], :3]

    # Defringe narrow border pixels polluted by neutral #808080 background
    semi = (alpha > 0) & (alpha < 200)
    if np.any(semi):
        sy, sx = np.where(semi)
        idx = labels[sy, sx] - 1
        nearest_rgb = out[oy[idx], ox[idx], :3].astype(np.float32)
        cur_rgb = out[sy, sx, :3].astype(np.float32)
        a_f = alpha[sy, sx].astype(np.float32)[:, None] / 255.0
        # Un-premultiply neutral gray #808080 spill when alpha is significant
        bg_f = np.array(bg_gray, dtype=np.float32)[None, :]
        unblended = np.clip((cur_rgb - bg_f * (1.0 - a_f)) / np.maximum(a_f, 0.20), 0.0, 255.0)
        dist_to_gray = np.linalg.norm(cur_rgb - bg_f, axis=1)
        blend_w = np.clip((20.0 - dist_to_gray) / 20.0, 0.0, 1.0)[:, None]
        fixed = unblended * (1.0 - blend_w * 0.65) + nearest_rgb * (blend_w * 0.65)
        out[sy, sx, :3] = np.clip(fixed, 0, 255).astype(np.uint8)

    return out


def _extract_sheet_foreground_alpha(albedo_rgb: np.ndarray, use_rembg: bool = True) -> np.ndarray:
    """
    Extract clean foreground alpha from #808080 neutral background, preserving
    bright translucent wing membranes in the bottom-right region.
    """
    h, w = albedo_rgb.shape[:2]
    rgb_f = albedo_rgb.astype(np.float32)

    # Estimate exact background gray from border ring (handles slight generator drift from #808080)
    border_pixels = np.concatenate([
        rgb_f[0:12, :, :].reshape(-1, 3),
        rgb_f[-12:, :, :].reshape(-1, 3),
        rgb_f[:, 0:12, :].reshape(-1, 3),
        rgb_f[:, -12:, :].reshape(-1, 3),
    ], axis=0)
    bg_med = np.median(border_pixels, axis=0)

    diff_bg = np.linalg.norm(rgb_f - bg_med[None, None, :], axis=2)
    chroma_mask = (diff_bg > 15.0).astype(np.uint8) * 255

    rembg_alpha: Optional[np.ndarray] = None
    if use_rembg:
        try:
            from rembg import new_session, remove  # type: ignore

            session = new_session("isnet-anime")
            fg_rgba = np.array(remove(Image.fromarray(albedo_rgb, mode="RGB"), session=session).convert("RGBA"))
            rembg_alpha = fg_rgba[:, :, 3]
        except Exception as exc:
            print(f"[Warn] rembg unavailable, using chroma/floodfill matting: {exc}")

    # External floodfill from borders over background-like pixels to avoid interior holes
    bg_candidate = (diff_bg < 16.5).astype(np.uint8)
    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    flood = bg_candidate.copy()
    for sx, sy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if flood[sy, sx] == 1:
            cv2.floodFill(flood, ff_mask, (sx, sy), 2)
    is_exterior_bg = (flood == 2)
    flood_alpha = np.where(is_exterior_bg, 0, 255).astype(np.uint8)

    if rembg_alpha is not None:
        # Union rembg with exterior floodfill for translucent bottom-right wing membrane
        alpha = np.maximum(rembg_alpha, (flood_alpha > 128).astype(np.uint8) * 220)
        # Preserve soft alpha where rembg was confident on opaque shells
        solid_core = rembg_alpha > 230
        alpha[solid_core] = rembg_alpha[solid_core]
    else:
        alpha = np.minimum(flood_alpha, np.where(diff_bg > 11.0, 255, 0).astype(np.uint8))

    # Feather 1px edge smoothly based on background distance where near border
    edge_band = (alpha > 0) & (diff_bg < 26.0)
    soft_alpha = np.clip((diff_bg - 11.0) / 14.0, 0.0, 1.0) * 255.0
    alpha = np.where(edge_band, np.maximum(alpha.astype(np.float32) * 0.4, soft_alpha), alpha.astype(np.float32))
    alpha_u8 = np.clip(alpha, 0, 255).astype(np.uint8)

    # Remove tiny background specks
    bin_m = (alpha_u8 > 24).astype(np.uint8)
    num_cc, labels, stats, _ = cv2.connectedComponentsWithStats(bin_m)
    min_area = max(120, int(h * w * 0.0012))
    keep = np.zeros_like(bin_m)
    for i in range(1, num_cc):
        if stats[i, cv2.CC_STAT_AREA] >= min_area:
            keep[labels == i] = 1
    alpha_u8 = np.where(keep > 0, alpha_u8, 0).astype(np.uint8)
    return alpha_u8


def _region_bboxes(alpha_u8: np.ndarray) -> Dict[str, Tuple[int, int, int, int]]:
    """Locate bounding boxes for body_core (left), elytron_r (top-right), inner_wing_r (bottom-right)."""
    h, w = alpha_u8.shape
    fg = alpha_u8 > 24
    num_cc, labels, stats, centroids = cv2.connectedComponentsWithStats(fg.astype(np.uint8))

    regions: Dict[str, np.ndarray] = {
        "body_core": np.zeros((h, w), dtype=bool),
        "elytron_r": np.zeros((h, w), dtype=bool),
        "inner_wing_r": np.zeros((h, w), dtype=bool),
    }

    for i in range(1, num_cc):
        area = int(stats[i, cv2.CC_STAT_AREA])
        if area < 80:
            continue
        cx, cy = float(centroids[i][0]), float(centroids[i][1])
        if cx < w * 0.54:
            regions["body_core"] |= (labels == i)
        elif cy < h * 0.50:
            regions["elytron_r"] |= (labels == i)
        else:
            regions["inner_wing_r"] |= (labels == i)

    bboxes: Dict[str, Tuple[int, int, int, int]] = {}
    for name, mask in regions.items():
        ys, xs = np.where(mask)
        if xs.size == 0:
            raise RuntimeError(f"Failed to locate foreground region '{name}' in albedo sheet.")
        bboxes[name] = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return bboxes


def _compute_alignment_masks(
    albedo_patch: np.ndarray,
    id_patch: np.ndarray,
    ink_patch: np.ndarray,
    norm_patch: np.ndarray,
) -> Dict[str, np.ndarray]:
    """Build comparable silhouette/edge soft masks to align id/ink/norm onto albedo."""
    a_sil = cv2.GaussianBlur((albedo_patch[:, :, 3] > 32).astype(np.float32), (9, 9), 2.5)
    a_edge = cv2.Canny(cv2.cvtColor(albedo_patch[:, :, :3], cv2.COLOR_RGB2GRAY), 40, 120).astype(np.float32) / 255.0
    a_edge = cv2.GaussianBlur(a_edge, (7, 7), 1.8)
    ref_sig = np.clip(a_sil * 0.72 + a_edge * 0.55, 0.0, 1.0)

    # ID silhouette: non-white
    id_fg = (np.min(id_patch, axis=2) < 232).astype(np.uint8)
    id_sil = cv2.GaussianBlur(id_fg.astype(np.float32), (9, 9), 2.5)
    id_edge = cv2.Canny(id_patch, 40, 120).astype(np.float32) / 255.0
    id_edge = cv2.GaussianBlur(id_edge, (7, 7), 1.8)
    id_sig = np.clip(id_sil * 0.72 + id_edge * 0.55, 0.0, 1.0)

    # Ink silhouette: filled outer contour + line edges
    ink_gray = cv2.cvtColor(ink_patch, cv2.COLOR_RGB2GRAY)
    ink_lines = (ink_gray < 170).astype(np.uint8)
    ink_closed = cv2.morphologyEx(ink_lines, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    contours, _ = cv2.findContours(ink_closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    ink_filled = np.zeros_like(ink_gray, dtype=np.uint8)
    if contours:
        cv2.drawContours(ink_filled, contours, -1, 1, thickness=cv2.FILLED)
    ink_sil = cv2.GaussianBlur(ink_filled.astype(np.float32), (9, 9), 2.5)
    ink_l_blur = cv2.GaussianBlur(ink_lines.astype(np.float32), (7, 7), 1.8)
    ink_sig = np.clip(ink_sil * 0.72 + ink_l_blur * 0.55, 0.0, 1.0)

    # Normal silhouette: distance from #8080FF
    n_diff = np.linalg.norm(norm_patch.astype(np.float32) - np.array([128.0, 128.0, 255.0]), axis=2)
    n_fg = (n_diff > 14.0).astype(np.uint8)
    n_sil = cv2.GaussianBlur(n_fg.astype(np.float32), (9, 9), 2.5)
    n_edge = cv2.Canny(norm_patch, 35, 110).astype(np.float32) / 255.0
    n_edge = cv2.GaussianBlur(n_edge, (7, 7), 1.8)
    n_sig = np.clip(n_sil * 0.72 + n_edge * 0.55, 0.0, 1.0)

    return {"ref": ref_sig, "id": id_sig, "ink": ink_sig, "normal": n_sig}


def _align_patch_ecc_and_flow(
    src_img: np.ndarray,
    ref_sig: np.ndarray,
    src_sig: np.ndarray,
    border_val: Tuple[int, int, int],
    max_flow_px: float = 3.5,
) -> np.ndarray:
    """Align src_img onto ref_sig using ECC Affine followed by bounded Farneback optical flow."""
    h, w = ref_sig.shape
    warp_mat = np.eye(2, 3, dtype=np.float32)
    criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 120, 1e-5)

    aligned = src_img.copy()
    aligned_sig = src_sig.copy()
    try:
        _, warp_mat = cv2.findTransformECC(
            ref_sig, src_sig, warp_mat, cv2.MOTION_AFFINE, criteria, None, 5
        )
        # Sanity bound on affine drift
        tx, ty = float(warp_mat[0, 2]), float(warp_mat[1, 2])
        if abs(tx) < w * 0.12 and abs(ty) < h * 0.12:
            aligned = cv2.warpAffine(
                src_img, warp_mat, (w, h),
                flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                borderMode=cv2.BORDER_CONSTANT, borderValue=border_val,
            )
            aligned_sig = cv2.warpAffine(
                src_sig, warp_mat, (w, h),
                flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                borderMode=cv2.BORDER_CONSTANT, borderValue=0.0,
            )
    except cv2.error:
        pass

    # Bounded Farneback refinement for sub-pixel seam lock
    flow = cv2.calcOpticalFlowFarneback(
        (ref_sig * 255.0).astype(np.uint8),
        (aligned_sig * 255.0).astype(np.uint8),
        None,
        pyr_scale=0.5, levels=3, winsize=15, iterations=3, poly_n=5, poly_sigma=1.2, flags=0,
    )
    mag = np.sqrt(flow[:, :, 0] ** 2 + flow[:, :, 1] ** 2)
    scale = np.where(mag > max_flow_px, max_flow_px / np.maximum(mag, 1e-6), 1.0)
    flow[:, :, 0] *= scale
    flow[:, :, 1] *= scale

    grid_x, grid_y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    map_x = grid_x + flow[:, :, 0]
    map_y = grid_y + flow[:, :, 1]
    interp = cv2.INTER_NEAREST if border_val == (255, 255, 255) else cv2.INTER_LINEAR
    refined = cv2.remap(
        aligned, map_x, map_y, interpolation=interp,
        borderMode=cv2.BORDER_CONSTANT, borderValue=border_val,
    )
    return refined


def _classify_id_channels(id_rgb: np.ndarray, alpha_mask: np.ndarray) -> Dict[str, np.ndarray]:
    """
    Classify aligned semantic ID sheet into clean boolean/float masks:
      chitin (#FF0000), matte (#808080), em_primary (#00FF00),
      em_secondary (#0000FF), recolor (#FF00FF), motion_sss (#00FFFF).
    """
    rgb = id_rgb.astype(np.float32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]

    # Confident prototypes avoiding white background and mixed boundary pixels
    not_white = np.min(rgb, axis=2) < 220.0
    fg = alpha_mask & not_white

    d_red = np.linalg.norm(rgb - np.array([255.0, 0.0, 0.0]), axis=2)
    d_green = np.linalg.norm(rgb - np.array([0.0, 255.0, 0.0]), axis=2)
    d_blue = np.linalg.norm(rgb - np.array([0.0, 0.0, 255.0]), axis=2)
    d_mag = np.linalg.norm(rgb - np.array([255.0, 0.0, 255.0]), axis=2)
    d_cyan = np.linalg.norm(rgb - np.array([0.0, 255.0, 255.0]), axis=2)
    d_gray = np.linalg.norm(rgb - np.array([128.0, 128.0, 128.0]), axis=2)

    # Also treat darker neutral gray ribbing inside thorax cavity as matte gray
    is_neutral_gray = (np.max(rgb, axis=2) - np.min(rgb, axis=2) < 34.0) & (r > 55.0) & (r < 205.0)
    d_gray_eff = np.where(is_neutral_gray, np.minimum(d_gray, 55.0), d_gray)

    stack = np.stack([d_red, d_gray_eff, d_green, d_blue, d_mag, d_cyan], axis=0)
    best = np.argmin(stack, axis=0)
    min_d = np.min(stack, axis=0)
    confident = fg & (min_d < 145.0)

    # Voronoi fill class index over any remaining foreground edge pixels
    best_filled = _voronoi_fill(best.astype(np.int32), confident)
    best_filled = np.where(alpha_mask, best_filled, -1)

    def _feather(cls_idx: int, sigma: float = 0.7) -> np.ndarray:
        m = ((best_filled == cls_idx) & alpha_mask).astype(np.float32)
        if sigma > 0.0:
            m = cv2.GaussianBlur(m, (0, 0), sigma)
        return np.clip(m, 0.0, 1.0)

    return {
        "chitin": _feather(0, 0.5),
        "matte": _feather(1, 0.6),
        "em_primary": _feather(2, 0.75),
        "em_secondary": _feather(3, 0.75),
        "recolor": _feather(4, 0.6),
        "motion_sss": _feather(5, 0.75),
    }


def _reconstruct_height_from_normals(
    nx: np.ndarray,
    ny: np.ndarray,
    nz: np.ndarray,
    fg_mask: np.ndarray,
    ink_lines_f: np.ndarray,
) -> np.ndarray:
    """
    Fast FFT Poisson solver integrating tangent-space normals into a smooth height field,
    blended with convex silhouette dome and sharp ink-seam bevel grooves.
    """
    h, w = nx.shape
    # OpenGL tangent space: +X right, +Y up -> screen +Y down means dy = +ny / nz
    p = np.where(fg_mask, -nx / np.maximum(nz, 0.25), 0.0)
    q = np.where(fg_mask, ny / np.maximum(nz, 0.25), 0.0)

    # Enforce zero boundary outside fg
    p = cv2.GaussianBlur(p, (3, 3), 0.6)
    q = cv2.GaussianBlur(q, (3, 3), 0.6)

    div = np.zeros((h, w), dtype=np.float32)
    div[:, :-1] += p[:, 1:] - p[:, :-1]
    div[:-1, :] += q[1:, :] - q[:-1, :]

    ky = np.fft.fftfreq(h)[:, None] * 2.0 * np.pi
    kx = np.fft.fftfreq(w)[None, :] * 2.0 * np.pi
    denom = (2.0 * np.cos(kx) - 2.0) + (2.0 * np.cos(ky) - 2.0)
    denom[0, 0] = 1.0

    z_hat = np.fft.fft2(div) / denom
    z_hat[0, 0] = 0.0
    height_poisson = np.real(np.fft.ifft2(z_hat)).astype(np.float32)

    # Normalize within foreground
    if np.any(fg_mask):
        vals = height_poisson[fg_mask]
        lo, hi = float(np.percentile(vals, 2)), float(np.percentile(vals, 98))
        height_poisson = np.clip((height_poisson - lo) / max(hi - lo, 1e-4), 0.0, 1.0)

    # Silhouette dome via EDT so edges always slope cleanly to 0
    dist_in = distance_transform_edt(fg_mask).astype(np.float32)
    dome = np.sqrt(np.clip(dist_in / max(float(dist_in.max()), 1.0), 0.0, 1.0))

    combined = np.where(fg_mask, height_poisson * 0.68 + dome * 0.32 - ink_lines_f * 0.08, 0.0)
    return np.clip(combined, 0.0, 1.0)


def _compute_signed_sdf(mask_bool: np.ndarray, range_px: float) -> np.ndarray:
    """
    Compute signed Euclidean distance encoded in [0..1] around 0.5:
      0.5 = exact edge; < 0.5 = inside mask; > 0.5 = outside mask.
    Matches ink_hq_pipeline.py convention ((val - 0.5) * 2 * range_px).
    """
    d_out = distance_transform_edt(~mask_bool).astype(np.float32)
    d_in = distance_transform_edt(mask_bool).astype(np.float32)
    signed = d_out - d_in
    norm = np.clip(0.5 + signed / (2.0 * max(range_px, 1.0)), 0.0, 1.0)
    return np.clip(np.round(norm * 255.0), 0, 255).astype(np.uint8)


def _extract_clean_ink_mask(ink_rgb_2x: np.ndarray, fg_mask_2x: np.ndarray) -> np.ndarray:
    """Extract crisp black line strokes at 2x resolution, rejecting accidental thick solid fills."""
    gray = cv2.cvtColor(ink_rgb_2x, cv2.COLOR_RGB2GRAY)
    raw_dark = (gray < 142) & fg_mask_2x
    # Reject huge accidental dark blobs (> 14px diameter in 2x) while preserving thick outer ink
    d_inside = distance_transform_edt(raw_dark)
    strokes = raw_dark & (d_inside <= 7.5)
    return strokes


def _place_scaled_patch(
    img: np.ndarray,
    target_canvas: int,
    px_scale: float,
    border_val: Tuple[int, ...],
    interp: int = cv2.INTER_AREA,
) -> Tuple[np.ndarray, Tuple[int, int, int, int]]:
    """Scale patch by exact unified px_scale and center inside target_canvas x target_canvas."""
    sh, sw = img.shape[:2]
    nw = max(4, int(round(sw * px_scale)))
    nh = max(4, int(round(sh * px_scale)))
    resized = cv2.resize(img, (nw, nh), interpolation=interp if px_scale < 1.0 else cv2.INTER_CUBIC)

    if img.ndim == 2:
        canvas = np.full((target_canvas, target_canvas), border_val[0], dtype=img.dtype)
    else:
        canvas = np.full((target_canvas, target_canvas, img.shape[2]), border_val, dtype=img.dtype)

    ox = (target_canvas - nw) // 2
    oy = (target_canvas - nh) // 2

    # Clip safely if oversized
    sx0 = max(0, -ox)
    sy0 = max(0, -oy)
    dx0 = max(0, ox)
    dy0 = max(0, oy)
    cw = min(nw - sx0, target_canvas - dx0)
    ch = min(nh - sy0, target_canvas - dy0)
    canvas[dy0:dy0 + ch, dx0:dx0 + cw] = resized[sy0:sy0 + ch, sx0:sx0 + cw]
    return canvas, (dx0, dy0, cw, ch)


def _compute_part_normal_height(
    norm_rgb: np.ndarray,
    alpha_u8: np.ndarray,
    id_ch: Dict[str, np.ndarray],
    ink_lines_1x: np.ndarray,
    is_wing: bool,
) -> np.ndarray:
    """Build packed <part>_normal_height.png (R=Nx, G=Ny, B=Height, A=PrimaryEmissive)."""
    fg = alpha_u8 > 28
    raw = (norm_rgb.astype(np.float32) / 255.0) * 2.0 - 1.0

    # Voronoi-fill normal inside fg edges so silhouette rims never sample #8080FF border haze
    n_diff = np.linalg.norm(norm_rgb.astype(np.float32) - np.array([128.0, 128.0, 255.0]), axis=2)
    valid_n = fg & (alpha_u8 > 140)
    if not np.any(valid_n):
        valid_n = fg
    raw_clean = _voronoi_fill(raw, valid_n)

    # Blend subtle convex edge normal dome near silhouette for crisp rim-light
    dist_in = distance_transform_edt(fg).astype(np.float32)
    dome = cv2.GaussianBlur(np.sqrt(np.clip(dist_in / max(float(dist_in.max()), 1.0), 0.0, 1.0)), (7, 7), 1.6)
    gx = cv2.Sobel(dome, cv2.CV_32F, 1, 0, ksize=5)
    gy = cv2.Sobel(dome, cv2.CV_32F, 0, 1, ksize=5)
    # OpenGL convention: +X right -> -gx, +Y up -> +gy
    rim_blend = np.clip(1.0 - dist_in / 14.0, 0.0, 0.35) if not is_wing else np.zeros_like(dome)

    nx = raw_clean[:, :, 0] - gx * rim_blend * 0.65
    ny = raw_clean[:, :, 1] + gy * rim_blend * 0.65
    nz = np.maximum(raw_clean[:, :, 2], 0.25 if not is_wing else 0.72)

    if is_wing:
        # Keep wing predominantly flat/cambered so it catches specular & SSS cleanly
        nx *= 0.55
        ny *= 0.55

    n_len = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx /= n_len
    ny /= n_len
    nz /= n_len

    height = _reconstruct_height_from_normals(nx, ny, nz, fg, ink_lines_1x)
    em_primary = np.where(alpha_u8 > 12, id_ch["em_primary"], 0.0)

    out = np.zeros((alpha_u8.shape[0], alpha_u8.shape[1], 4), dtype=np.uint8)
    out[:, :, 0] = np.where(fg, np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255), 128).astype(np.uint8)
    out[:, :, 1] = np.where(fg, np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255), 128).astype(np.uint8)
    out[:, :, 2] = np.clip(height * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(em_primary * 255.0, 0, 255).astype(np.uint8)
    return out


def _compute_part_ilm_sdf_2x(
    height_1x: np.ndarray,
    alpha_1x: np.ndarray,
    id_ch_1x: Dict[str, np.ndarray],
    ink_rgb_2x: np.ndarray,
    is_wing: bool,
) -> np.ndarray:
    """Build 2x Linear RGBA <part>_ilm_sdf.png (R=AO, G=Specular, B=InkSDF, A=OuterSDF)."""
    h1, w1 = alpha_1x.shape
    h2, w2 = h1 * 2, w1 * 2

    # Cavity AO from height curvature + matte recessed thorax cavity
    blur_h = cv2.GaussianBlur(height_1x, (13, 13), 3.2)
    curv = height_1x - blur_h
    ao_1x = np.clip(0.56 + curv * 1.9 - id_ch_1x["matte"] * 0.24, 0.08, 0.95)
    if is_wing:
        ao_1x = np.clip(0.70 + curv * 0.8, 0.35, 0.95)

    ao_1x = np.where(alpha_1x > 16, ao_1x, 0.50)

    # Specular / Material map
    spec_1x = np.clip(
        id_ch_1x["chitin"] * 0.95
        + id_ch_1x["recolor"] * 0.85
        + id_ch_1x["motion_sss"] * 0.62
        + id_ch_1x["matte"] * 0.28
        + id_ch_1x["em_primary"] * 0.50
        + id_ch_1x["em_secondary"] * 0.55,
        0.15, 1.0,
    )
    spec_1x = np.where(alpha_1x > 16, spec_1x, 0.0)

    ao_2x = cv2.resize(ao_1x, (w2, h2), interpolation=cv2.INTER_CUBIC)
    spec_2x = cv2.resize(spec_1x, (w2, h2), interpolation=cv2.INTER_CUBIC)
    alpha_2x = cv2.resize(alpha_1x, (w2, h2), interpolation=cv2.INTER_CUBIC)
    fg_2x = alpha_2x > 72

    ink_strokes_2x = _extract_clean_ink_mask(ink_rgb_2x, fg_2x)
    # 1 native texel == 2 texels at 2x resolution
    ink_sdf_2x = _compute_signed_sdf(ink_strokes_2x, INK_SDF_RANGE_NATIVE_PX * 2.0)
    outer_sdf_2x = _compute_signed_sdf(fg_2x, OUTER_SDF_RANGE_NATIVE_PX * 2.0)

    out = np.zeros((h2, w2, 4), dtype=np.uint8)
    out[:, :, 0] = np.clip(ao_2x * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(spec_2x * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 2] = ink_sdf_2x
    out[:, :, 3] = outer_sdf_2x
    return out


def _compute_part_fx_motion(
    alpha_u8: np.ndarray,
    id_ch: Dict[str, np.ndarray],
    part_name: str,
    hinge_px: Tuple[float, float],
) -> np.ndarray:
    """Build <part>_fx_motion.png (R=MotionWeight, G=RecolorZone, B=SecondaryEmissive, A=SSS)."""
    h, w = alpha_u8.shape
    fg = alpha_u8 > 16
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    if part_name == "inner_wing_r":
        # Radial distance from top-left hinge locks hinge (0.0) and vibrates wing tip (1.0)
        dist = np.sqrt((xx - hinge_px[0]) ** 2 + (yy - hinge_px[1]) ** 2)
        fg_dists = dist[fg]
        max_d = max(float(np.percentile(fg_dists, 98)) if fg_dists.size > 0 else 1.0, 1.0)
        ramp = np.clip((dist / max_d - 0.10) / 0.85, 0.0, 1.0)
        # Allow chitin spar tip to flex slightly less than gossamer membrane
        motion = ramp * np.clip(id_ch["motion_sss"] * 1.0 + id_ch["chitin"] * 0.45, 0.0, 1.0)
    elif part_name == "body_core":
        # Vibrate cyan rear legs + subtle bite motion on upper mandible tips (masked strictly to fg)
        ys, xs = np.where(fg)
        y_min, y_max = float(ys.min()), float(ys.max())
        mandible_zone = np.clip((y_min + (y_max - y_min) * 0.28 - yy) / max((y_max - y_min) * 0.22, 1.0), 0.0, 1.0)
        motion = np.where(fg, np.clip(np.maximum(id_ch["motion_sss"], mandible_zone * 0.65), 0.0, 1.0), 0.0)
    else:
        motion = np.zeros((h, w), dtype=np.float32)

    recolor = np.where(fg, id_ch["recolor"], 0.0)
    em_sec = np.where(fg, id_ch["em_secondary"], 0.0)
    sss = np.where(
        fg,
        np.clip(id_ch["motion_sss"] * 1.0 + id_ch["chitin"] * 0.35 + id_ch["matte"] * 0.10, 0.0, 1.0),
        0.0,
    )

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 0] = np.clip(motion * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(recolor * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 2] = np.clip(em_sec * 255.0, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(sss * 255.0, 0, 255).astype(np.uint8)
    return out


def _mirror_part_pack(
    albedo: np.ndarray,
    normal_height: np.ndarray,
    ilm_sdf_2x: np.ndarray,
    fx_motion: np.ndarray,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Mirror right-side module cleanly to left-side, inverting Nx (R' = 255 - R)."""
    m_alb = np.fliplr(albedo).copy()
    m_nh = np.fliplr(normal_height).copy()
    m_ilm = np.fliplr(ilm_sdf_2x).copy()
    m_fx = np.fliplr(fx_motion).copy()

    valid = m_alb[:, :, 3] > 8
    m_nh[:, :, 0] = np.where(valid, 255 - m_nh[:, :, 0], 128).astype(np.uint8)
    return m_alb, m_nh, m_ilm, m_fx


def _find_hinge_and_mount(
    body_alb: np.ndarray,
    body_id: Dict[str, np.ndarray],
    ely_alb: np.ndarray,
    wing_alb: np.ndarray,
) -> Dict[str, object]:
    """Derive exact dorsal hinge pivots and mount offsets relative to body_core center."""
    bh, bw = body_alb.shape[:2]
    b_ys, b_xs = np.where(body_alb[:, :, 3] > 64)
    b_top, b_bot = float(b_ys.min()), float(b_ys.max())
    b_cx = float((b_xs.min() + b_xs.max()) * 0.5)

    # Locate top of dorsal thorax cavity (matte cavity below pronotum/eyes, y > 35% of body height)
    cav_zone = (yy_b := np.mgrid[0:bh, 0:bw][0].astype(np.float32)) > (b_top + (b_bot - b_top) * 0.36)
    cav = (body_id["matte"] > 0.45) & cav_zone & (body_alb[:, :, 3] > 64)
    # Keep central thorax region (avoid lateral leg joints)
    xx_b = np.mgrid[0:bh, 0:bw][1].astype(np.float32)
    cav &= np.abs(xx_b - b_cx) < (bw * 0.16)
    cav_ys, _ = np.where(cav)
    if cav_ys.size > 0:
        thorax_top_y = float(np.percentile(cav_ys, 2))
    else:
        thorax_top_y = b_top + (b_bot - b_top) * 0.48

    # Elytron hinge: top-left corner of solid shell along straight dorsal seam
    eh, ew = ely_alb.shape[:2]
    e_ys, e_xs = np.where(ely_alb[:, :, 3] > 80)
    e_left = float(e_xs.min())
    near_left = e_ys[e_xs <= e_left + 12.0]
    e_top_left_y = float(near_left.min()) if near_left.size > 0 else float(e_ys.min())
    ely_hinge_px = (e_left + 1.0, e_top_left_y + 10.0)

    # Inner wing hinge: top-left leading-edge root
    wh, ww = wing_alb.shape[:2]
    w_ys, w_xs = np.where(wing_alb[:, :, 3] > 80)
    w_left = float(w_xs.min())
    w_top_band = w_ys[w_xs <= w_left + 20.0]
    w_top_y = float(w_top_band.min()) if w_top_band.size > 0 else float(w_ys.min())
    wing_hinge_px = (w_left + 10.0, w_top_y + 10.0)

    # Art faces UP (-Y). Mount offset in art-up space relative to body_core center:
    ely_mount_art = (
        round((b_cx - bw * 0.5) + 1.0, 2),
        round((thorax_top_y - bh * 0.5) - 6.0, 2),
    )
    wing_mount_art = (
        round((b_cx - bw * 0.5) + 12.0, 2),
        round((thorax_top_y - bh * 0.5) + 14.0, 2),
    )

    return {
        "body_height_px": round(b_bot - b_top, 1),
        "elytron_hinge_uv": [round(ely_hinge_px[0] / ew, 4), round(ely_hinge_px[1] / eh, 4)],
        "elytron_hinge_px": [round(ely_hinge_px[0], 2), round(ely_hinge_px[1], 2)],
        "elytron_mount_art_px": [ely_mount_art[0], ely_mount_art[1]],
        "inner_wing_hinge_uv": [round(wing_hinge_px[0] / ww, 4), round(wing_hinge_px[1] / wh, 4)],
        "inner_wing_hinge_px": [round(wing_hinge_px[0], 2), round(wing_hinge_px[1], 2)],
        "inner_wing_mount_art_px": [wing_mount_art[0], wing_mount_art[1]],
    }


def _alpha_composite(dst: np.ndarray, src: np.ndarray, pos_xy: Tuple[int, int], angle_deg: float = 0.0) -> None:
    """Alpha composite src RGBA onto dst RGBA around src center at pos_xy (audit preview helper)."""
    dh, dw = dst.shape[:2]
    sh, sw = src.shape[:2]
    mat = cv2.getRotationMatrix2D((sw * 0.5, sh * 0.5), angle_deg, 1.0)
    rot = cv2.warpAffine(src, mat, (sw, sh), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    x0 = int(round(pos_xy[0] - sw * 0.5))
    y0 = int(round(pos_xy[1] - sh * 0.5))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    cw = min(sw - sx0, dw - dx0)
    ch = min(sh - sy0, dh - dy0)
    if cw <= 0 or ch <= 0:
        return
    sub_s = rot[sy0:sy0 + ch, sx0:sx0 + cw].astype(np.float32) / 255.0
    sub_d = dst[dy0:dy0 + ch, dx0:dx0 + cw].astype(np.float32) / 255.0
    a = sub_s[:, :, 3:4]
    out_rgb = sub_s[:, :, :3] * a + sub_d[:, :, :3] * (1.0 - a)
    out_a = np.clip(a + sub_d[:, :, 3:4] * (1.0 - a), 0.0, 1.0)
    dst[dy0:dy0 + ch, dx0:dx0 + cw, :3] = np.clip(out_rgb * 255.0, 0, 255).astype(np.uint8)
    dst[dy0:dy0 + ch, dx0:dx0 + cw, 3] = np.clip(out_a[:, :, 0] * 255.0, 0, 255).astype(np.uint8)


def _render_audit_sheet(
    audit_path: Path,
    parts_data: Dict[str, Dict[str, np.ndarray]],
    rig_meta: Dict[str, object],
) -> None:
    """Render visual QA audit sheet: maps breakdown + assembled Closed vs Open-V preview."""
    tile = 240
    cols = 5
    rows = 3
    canvas = np.full((rows * tile + 40, cols * tile, 4), (16, 18, 32, 255), dtype=np.uint8)

    bc = parts_data["body_core"]
    alb = bc["albedo"]
    nh = bc["normal_height"]
    ilm = cv2.resize(bc["ilm_sdf"], (alb.shape[1], alb.shape[0]), interpolation=cv2.INTER_AREA)
    fx = bc["fx_motion"]

    def _put_tile(r: int, c: int, img_rgb: np.ndarray, label: str) -> None:
        t = cv2.resize(img_rgb, (tile - 8, tile - 24), interpolation=cv2.INTER_AREA)
        y0, x0 = r * tile + 20, c * tile + 4
        canvas[y0:y0 + t.shape[0], x0:x0 + t.shape[1], :3] = t
        cv2.putText(canvas, label, (x0 + 4, r * tile + 15), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (210, 225, 255, 255), 1, cv2.LINE_AA)

    # Composite albedo onto dark space slate for legibility
    a_f = alb[:, :, 3:4].astype(np.float32) / 255.0
    alb_vis = np.clip(alb[:, :, :3].astype(np.float32) * a_f + np.array([28.0, 30.0, 48.0]) * (1.0 - a_f), 0, 255).astype(np.uint8)
    _put_tile(0, 0, alb_vis, "1. Albedo")
    _put_tile(0, 1, np.stack([nh[:, :, 0], nh[:, :, 1], np.full_like(nh[:, :, 0], 220)], axis=-1), "2. Normal XY")
    _put_tile(0, 2, np.repeat(nh[:, :, 2:3], 3, axis=2), "3. Height")
    _put_tile(0, 3, np.repeat(nh[:, :, 3:4], 3, axis=2), "4. Primary Emissive")
    _put_tile(0, 4, np.stack([ilm[:, :, 0], ilm[:, :, 1], np.zeros_like(ilm[:, :, 0])], axis=-1), "5. AO(R)+Spec(G)")

    _put_tile(1, 0, np.repeat(ilm[:, :, 2:3], 3, axis=2), "6. Ink SDF 2x")
    _put_tile(1, 1, np.repeat(ilm[:, :, 3:4], 3, axis=2), "7. Outer SDF 2x")
    _put_tile(1, 2, fx[:, :, :3], "8. FX Motion/Recol/Em2")
    _put_tile(1, 3, np.repeat(fx[:, :, 3:4], 3, axis=2), "9. SSS Mask")

    # Preview Closed vs Open-V + Scissor Bite assembly in row 2
    def _place_hinged(prev: np.ndarray, part_key: str, side_sign: float, angle_deg: float, mount_off: list, hinge_px: list, cx: int, cy: int) -> None:
        img = parts_data[part_key]["albedo"]
        ph, pw = img.shape[:2]
        hx = float(hinge_px[0]) if side_sign > 0 else (pw - float(hinge_px[0]))
        hy = float(hinge_px[1])
        dx = (pw * 0.5 - hx)
        dy = (ph * 0.5 - hy)
        ang_rad = np.deg2rad(-angle_deg * side_sign)
        rx = dx * np.cos(ang_rad) - dy * np.sin(ang_rad)
        ry = dx * np.sin(ang_rad) + dy * np.cos(ang_rad)
        _alpha_composite(
            prev, img,
            (int(round(cx + float(mount_off[0]) * side_sign + rx)), int(round(cy + float(mount_off[1]) + ry))),
            angle_deg * side_sign,
        )

    def _assemble_preview(ely_deg: float, wing_deg: float, show_wing: bool, mand_deg: float = 0.0) -> np.ndarray:
        prev = np.full((560, 560, 4), (18, 20, 38, 255), dtype=np.uint8)
        cx, cy = 280, 280
        mm_off = rig_meta.get("mandible_mount_art_px", [30.0, -73.0])  # type: ignore
        mh_px = rig_meta.get("mandible_hinge_px", [128.0, 180.0])  # type: ignore
        _place_hinged(prev, "mandible_l", -1.0, mand_deg, mm_off, mh_px, cx, cy)  # type: ignore
        _place_hinged(prev, "mandible_r", 1.0, mand_deg, mm_off, mh_px, cx, cy)  # type: ignore
        _alpha_composite(prev, parts_data["body_core"]["albedo"], (cx, cy), 0.0)

        em_off = rig_meta["elytron_mount_art_px"]  # type: ignore
        wm_off = rig_meta["inner_wing_mount_art_px"]  # type: ignore
        eh_px = rig_meta["elytron_hinge_px"]  # type: ignore
        wh_px = rig_meta["inner_wing_hinge_px"]  # type: ignore

        for side_sign, suffix in ((1.0, "r"), (-1.0, "l")):
            if show_wing:
                _place_hinged(prev, f"inner_wing_{suffix}", side_sign, wing_deg, wm_off, wh_px, cx, cy)  # type: ignore
            _place_hinged(prev, f"elytron_{suffix}", side_sign, ely_deg, em_off, eh_px, cx, cy)  # type: ignore
        return prev[:, :, :3]

    closed_rgb = _assemble_preview(0.0, 0.0, False, 0.0)
    open_rgb = _assemble_preview(40.0, 30.0, True, -26.0)
    bite_rgb = _assemble_preview(18.0, 22.0, True, 34.0)
    _put_tile(2, 0, closed_rgb, "10. Assembled CLOSED")
    _put_tile(2, 1, open_rgb, "11. OPEN-V + Jaws Wide")
    _put_tile(2, 2, bite_rgb, "12. SCISSOR BITE (+34 deg)")

    # Big comparison on remaining right columns of row 2
    comp_big = np.concatenate([open_rgb, bite_rgb], axis=1)
    comp_resized = cv2.resize(comp_big, (tile * 2 - 12, tile - 24), interpolation=cv2.INTER_AREA)
    y0, x0 = 2 * tile + 20, 3 * tile + 6
    canvas[y0:y0 + comp_resized.shape[0], x0:x0 + comp_resized.shape[1], :3] = comp_resized

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, mode="RGBA").save(audit_path, format="PNG")


def _split_mandibles_from_body_core(
    parts_data: Dict[str, Dict[str, np.ndarray]],
) -> Dict[str, object]:
    """
    Slice mandible_r and mandible_l cleanly out of body_core at exact 1:1 scale,
    add a small hidden chitin cheek-socket stub for gap-free wide-open rotation,
    mirror Nx cleanly to mandible_l, and update Outer SDFs on body_core + mandibles.
    """
    bc = parts_data["body_core"]
    alb = bc["albedo"]
    nh = bc["normal_height"]
    ilm_2x = bc["ilm_sdf"]
    fx = bc["fx_motion"]
    bh, bw = alb.shape[:2]  # 512x512

    # Measured right-mandible polygon in 512x512 body_core space:
    # Passes cleanly through the gap between central crown horn (x<=268) and mandible (y<160),
    # then wraps around the entire green glowing inner cutting edge down to (268, 174) -> (287, 191).
    poly_r = np.array([
        [270, 60], [348, 60], [348, 146], [312, 148],
        [301, 166], [295, 184], [287, 191],
        [272, 178], [266, 170], [268, 160], [274, 150], [270, 138],
    ], dtype=np.int32)
    mask_r = np.zeros((bh, bw), dtype=np.uint8)
    cv2.fillPoly(mask_r, [poly_r], 255)
    fg_b = alb[:, :, 3] > 20
    mand_r_fg = (mask_r > 0) & fg_b

    # Hinge pivot deeply tucked inside cheek socket (280, 188) in body_core 512x512
    hinge_body_x, hinge_body_y = 280.0, 188.0

    # Generous circular socket disc (r=16px) + cheek bridge so wide-open & scissor-bite have ZERO gaps
    stub_poly = np.array([[270, 172], [296, 180], [295, 200], [274, 200]], dtype=np.int32)
    stub_mask = np.zeros((bh, bw), dtype=np.uint8)
    cv2.fillPoly(stub_mask, [stub_poly], 255)
    cv2.circle(stub_mask, (int(hinge_body_x), int(hinge_body_y)), 16, 255, thickness=-1)
    stub_only = (stub_mask > 0) & (~mand_r_fg)

    # Seed Voronoi fill from dark chitin on mandible_r (avoiding bright green edge & empty background)
    luma_m = 0.299 * alb[:, :, 0].astype(np.float32) + 0.587 * alb[:, :, 1].astype(np.float32) + 0.114 * alb[:, :, 2].astype(np.float32)
    chitin_seed = mand_r_fg & (alb[:, :, 3] > 200) & (nh[:, :, 3] < 40) & (fx[:, :, 2] < 40) & (luma_m < 95.0) & (np.arange(bh)[:, None] > 158)
    if not np.any(chitin_seed):
        chitin_seed = mand_r_fg & (alb[:, :, 3] > 200)

    filled_alb = _voronoi_fill(alb[:, :, :3], chitin_seed)
    filled_nh = _voronoi_fill(nh[:, :, :3], chitin_seed)

    m_alb_src = alb.copy()
    m_nh_src = nh.copy()
    m_fx_src = fx.copy()
    # CRITICAL: Preserve 100% of original mandible pixels on mand_r_fg; Voronoi-fill ONLY stub_only!
    m_alb_src[:, :, :3] = np.where(stub_only[:, :, None], filled_alb, alb[:, :, :3])
    m_alb_src[:, :, 3] = np.where(mand_r_fg, alb[:, :, 3], np.where(stub_only, 255, 0)).astype(np.uint8)
    m_nh_src[:, :, :3] = np.where(stub_only[:, :, None], filled_nh, nh[:, :, :3])
    m_nh_src[:, :, 3] = np.where(mand_r_fg, nh[:, :, 3], 0).astype(np.uint8)
    m_fx_src[:, :, :] = np.where(mand_r_fg[:, :, None], fx, 0).astype(np.uint8)
    # Zero out motion weight on mandible rigid piece (driven by real pivot rotation)
    m_fx_src[:, :, 0] = 0

    # Upscale masks at 2x cleanly for AO/Spec/Ink inside mandible_r
    mand_r_full = mand_r_fg | stub_only
    ys_m, xs_m = np.where(mand_r_full)
    cx_m = int(round((xs_m.min() + xs_m.max()) * 0.5))
    cy_m = int(round((ys_m.min() + ys_m.max()) * 0.5))
    m_sz = 256
    half_m = m_sz // 2

    def _crop_to_256(src: np.ndarray, scale_mult: int, default_bg: Tuple[int, ...]) -> np.ndarray:
        c = m_sz * scale_mult
        out = np.full((c, c, src.shape[2]), default_bg, dtype=src.dtype) if src.ndim == 3 else np.full((c, c), default_bg[0], dtype=src.dtype)
        sx0 = (cx_m - half_m) * scale_mult
        sy0 = (cy_m - half_m) * scale_mult
        sx1 = sx0 + c
        sy1 = sy0 + c
        ix0, iy0 = max(0, sx0), max(0, sy0)
        ix1, iy1 = min(src.shape[1], sx1), min(src.shape[0], sy1)
        dx0, dy0 = ix0 - sx0, iy0 - sy0
        out[dy0:dy0 + (iy1 - iy0), dx0:dx0 + (ix1 - ix0)] = src[iy0:iy1, ix0:ix1]
        return out

    m_mask_full_256 = _crop_to_256(mand_r_full.astype(np.uint8), 1, (0,)) > 0
    mr_alb = _crop_to_256(m_alb_src, 1, (128, 128, 128, 0))
    mr_alb = np.where(m_mask_full_256[:, :, None], mr_alb, np.array([128, 128, 128, 0], dtype=np.uint8))
    mr_alb = _alpha_bleed_and_defringe(mr_alb)

    mr_nh = _crop_to_256(m_nh_src, 1, (128, 128, 255, 0))
    mr_nh = np.where(m_mask_full_256[:, :, None], mr_nh, np.array([128, 128, 0, 0], dtype=np.uint8))

    mr_fx = _crop_to_256(m_fx_src, 1, (0, 0, 0, 0))
    mr_fx = np.where(m_mask_full_256[:, :, None], mr_fx, 0)

    mr_ilm_2x = _crop_to_256(ilm_2x, 2, (128, 220, 255, 255))
    # Keep hidden socket stub clean of stray head ink lines
    mr_stub_2x = cv2.resize((_crop_to_256(stub_only.astype(np.uint8), 1, (0,)) > 0).astype(np.uint8), (m_sz * 2, m_sz * 2), interpolation=cv2.INTER_NEAREST) > 0
    mr_ilm_2x[:, :, 2] = np.where(mr_stub_2x, 255, mr_ilm_2x[:, :, 2]).astype(np.uint8)
    mr_fg_2x = cv2.resize(mr_alb[:, :, 3], (m_sz * 2, m_sz * 2), interpolation=cv2.INTER_CUBIC) > 72
    mr_ilm_2x[:, :, 3] = _compute_signed_sdf(mr_fg_2x, OUTER_SDF_RANGE_NATIVE_PX * 2.0)

    parts_data["mandible_r"] = {
        "albedo": mr_alb,
        "normal_height": mr_nh,
        "ilm_sdf": mr_ilm_2x,
        "fx_motion": mr_fx,
    }
    ml_alb, ml_nh, ml_ilm, ml_fx = _mirror_part_pack(mr_alb, mr_nh, mr_ilm_2x, mr_fx)
    parts_data["mandible_l"] = {
        "albedo": ml_alb,
        "normal_height": ml_nh,
        "ilm_sdf": ml_ilm,
        "fx_motion": ml_fx,
    }

    # Erase mandibles cleanly from body_core (shrunk 1px from head seam so cheek ink stays crisp & green edge is removed)
    mask_l = np.fliplr(mask_r)
    erase_both = cv2.erode(((mask_r > 0) | (mask_l > 0)).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    keep_body = ~erase_both
    bc_alb = alb.copy()
    bc_alb[:, :, 3] = np.where(keep_body, bc_alb[:, :, 3], 0).astype(np.uint8)
    bc_alb = _alpha_bleed_and_defringe(bc_alb)
    bc_nh = np.where(keep_body[:, :, None], nh, np.array([128, 128, 0, 0], dtype=np.uint8))
    bc_fx = np.where(keep_body[:, :, None], fx, 0)
    bc_fg_2x = cv2.resize(bc_alb[:, :, 3], (bw * 2, bh * 2), interpolation=cv2.INTER_CUBIC) > 72
    bc_ilm = ilm_2x.copy()
    bc_ilm[:, :, 3] = _compute_signed_sdf(bc_fg_2x, OUTER_SDF_RANGE_NATIVE_PX * 2.0)

    parts_data["body_core"] = {
        "albedo": bc_alb,
        "normal_height": bc_nh,
        "ilm_sdf": bc_ilm,
        "fx_motion": bc_fx,
    }

    hinge_local_x = hinge_body_x - (cx_m - half_m)
    hinge_local_y = hinge_body_y - (cy_m - half_m)
    return {
        "mandible_hinge_px": [round(hinge_local_x, 2), round(hinge_local_y, 2)],
        "mandible_hinge_uv": [round(hinge_local_x / float(m_sz), 4), round(hinge_local_y / float(m_sz), 4)],
        "mandible_mount_art_px": [round(hinge_body_x - bw * 0.5, 2), round(hinge_body_y - bh * 0.5, 2)],
    }


def compile_enemy(
    raw_dir: Path,
    out_dir: Path,
    audit_path: Path,
    prefix: str = "void_scarab_parts",
    use_upscayl: bool = True,
    use_rembg: bool = True,
    delight_strength: float = 0.14,
) -> None:
    albedo_path = raw_dir / f"{prefix}_albedo.png"
    id_path = raw_dir / f"{prefix}_id.png"
    ink_path = raw_dir / f"{prefix}_ink.png"
    norm_path = raw_dir / f"{prefix}_normal.png"

    for p in (albedo_path, id_path, ink_path, norm_path):
        if not p.exists():
            raise FileNotFoundError(f"Missing raw input sheet: {p}")

    # Optional Upscayl 4x on albedo + ink (matches Valentina pipeline)
    work_tmp = raw_dir.parent / "_tmp_upscaled"
    eff_albedo_path = albedo_path
    eff_ink_path = ink_path
    if use_upscayl and upscale_with_upscayl is not None:
        up_alb = work_tmp / f"{prefix}_albedo_4x.png"
        up_ink = work_tmp / f"{prefix}_ink_4x.png"
        eff_albedo_path = up_alb if up_alb.exists() else upscale_with_upscayl(albedo_path, up_alb)
        eff_ink_path = up_ink if up_ink.exists() else upscale_with_upscayl(ink_path, up_ink)

    alb_rgb = _load_rgb(eff_albedo_path)
    ah, aw = alb_rgb.shape[:2]

    def _load_match(p: Path, border_interp: int = cv2.INTER_LINEAR) -> np.ndarray:
        arr = _load_rgb(p)
        if arr.shape[:2] != (ah, aw):
            arr = cv2.resize(arr, (aw, ah), interpolation=border_interp)
        return arr

    id_rgb = _load_match(id_path, cv2.INTER_NEAREST)
    ink_rgb = _load_match(eff_ink_path, cv2.INTER_AREA)
    norm_rgb = _load_match(norm_path, cv2.INTER_CUBIC)

    print(f"[EnemyBuild] Loaded sheet {aw}x{ah}; extracting foreground alpha...")
    sheet_alpha = _extract_sheet_foreground_alpha(alb_rgb, use_rembg=use_rembg)
    bboxes = _region_bboxes(sheet_alpha)
    print(f"[EnemyBuild] Located 3 regions: {bboxes}")

    # Unified px_scale so body_core fits inside 512x512 with 72px padding (14% margin for Outer SDF)
    bx0, by0, bx1, by1 = bboxes["body_core"]
    body_max_dim = max(bx1 - bx0, by1 - by0)
    body_canvas = 512
    px_scale = float(body_canvas - 2 * 72) / float(max(body_max_dim, 1))

    # Choose square canvas >= content * px_scale + 128px padding (multiple of 64)
    def _pick_canvas(bbox: Tuple[int, int, int, int], min_size: int) -> int:
        x0, y0, x1, y1 = bbox
        need = int(np.ceil(max(x1 - x0, y1 - y0) * px_scale)) + 128
        size = max(min_size, ((need + 63) // 64) * 64)
        return size

    part_specs = {
        "body_core": (bboxes["body_core"], body_canvas, False),
        "elytron_r": (bboxes["elytron_r"], _pick_canvas(bboxes["elytron_r"], 384), False),
        "inner_wing_r": (bboxes["inner_wing_r"], _pick_canvas(bboxes["inner_wing_r"], 384), True),
    }

    pad_raw = max(24, int(round(0.03 * max(aw, ah))))
    parts_data: Dict[str, Dict[str, np.ndarray]] = {}
    id_channels_map: Dict[str, Dict[str, np.ndarray]] = {}

    for part_name, (bbox, canvas_sz, is_wing) in part_specs.items():
        x0 = max(0, bbox[0] - pad_raw)
        y0 = max(0, bbox[1] - pad_raw)
        x1 = min(aw, bbox[2] + pad_raw)
        y1 = min(ah, bbox[3] + pad_raw)

        p_alb = np.dstack([alb_rgb[y0:y1, x0:x1], sheet_alpha[y0:y1, x0:x1]])
        p_id = id_rgb[y0:y1, x0:x1]
        p_ink = ink_rgb[y0:y1, x0:x1]
        p_norm = norm_rgb[y0:y1, x0:x1]

        sigs = _compute_alignment_masks(p_alb, p_id, p_ink, p_norm)
        p_id_al = _align_patch_ecc_and_flow(p_id, sigs["ref"], sigs["id"], (255, 255, 255), max_flow_px=3.5)
        p_ink_al = _align_patch_ecc_and_flow(p_ink, sigs["ref"], sigs["ink"], (255, 255, 255), max_flow_px=3.0)
        p_norm_al = _align_patch_ecc_and_flow(p_norm, sigs["ref"], sigs["normal"], (128, 128, 255), max_flow_px=3.5)

        # Place on unified-scale canvas (1x and 2x for ink)
        c_alb, _ = _place_scaled_patch(p_alb, canvas_sz, px_scale, (128, 128, 128, 0))
        c_alb = _alpha_bleed_and_defringe(c_alb)

        # Gentle de-lighting on low-frequency shadow bias if requested (preserves ink & emissives)
        if delight_strength > 0.001:
            fg_1x = c_alb[:, :, 3] > 32
            rgb_f = c_alb[:, :, :3].astype(np.float32)
            luma = 0.299 * rgb_f[:, :, 0] + 0.587 * rgb_f[:, :, 1] + 0.114 * rgb_f[:, :, 2]
            low = cv2.GaussianBlur(luma, (31, 31), 9.0)
            if np.any(fg_1x):
                med_l = float(np.median(low[fg_1x]))
                gain = np.clip((med_l / np.maximum(low, 18.0) - 1.0) * delight_strength + 1.0, 0.88, 1.24)
                # Protect dark ink strokes from lifting
                not_ink = np.clip((luma - 28.0) / 36.0, 0.0, 1.0)
                eff_gain = 1.0 + (gain - 1.0) * not_ink
                c_alb[:, :, :3] = np.where(
                    fg_1x[:, :, None],
                    np.clip(rgb_f * eff_gain[:, :, None], 0, 255).astype(np.uint8),
                    c_alb[:, :, :3],
                )

        c_id, _ = _place_scaled_patch(p_id_al, canvas_sz, px_scale, (255, 255, 255), cv2.INTER_NEAREST)
        c_norm, _ = _place_scaled_patch(p_norm_al, canvas_sz, px_scale, (128, 128, 255), cv2.INTER_CUBIC)
        c_ink_1x, _ = _place_scaled_patch(p_ink_al, canvas_sz, px_scale, (255, 255, 255), cv2.INTER_AREA)
        c_ink_2x, _ = _place_scaled_patch(p_ink_al, canvas_sz * 2, px_scale * 2.0, (255, 255, 255), cv2.INTER_AREA)

        fg_1x = c_alb[:, :, 3] > 20
        id_ch = _classify_id_channels(c_id, fg_1x)
        id_channels_map[part_name] = id_ch
        ink_lines_1x = _extract_clean_ink_mask(c_ink_1x, fg_1x).astype(np.float32)

        c_nh = _compute_part_normal_height(c_norm, c_alb[:, :, 3], id_ch, ink_lines_1x, is_wing)
        c_ilm = _compute_part_ilm_sdf_2x(c_nh[:, :, 2].astype(np.float32) / 255.0, c_alb[:, :, 3], id_ch, c_ink_2x, is_wing)

        parts_data[part_name] = {
            "albedo": c_alb,
            "normal_height": c_nh,
            "ilm_sdf": c_ilm,
        }

    # Compute hinges before building fx_motion (since wing hinge locks radial vertex buzz)
    hinges = _find_hinge_and_mount(
        parts_data["body_core"]["albedo"],
        id_channels_map["body_core"],
        parts_data["elytron_r"]["albedo"],
        parts_data["inner_wing_r"]["albedo"],
    )

    for part_name in ("body_core", "elytron_r", "inner_wing_r"):
        h_px = tuple(hinges["inner_wing_hinge_px"]) if part_name == "inner_wing_r" else (0.0, 0.0)  # type: ignore
        parts_data[part_name]["fx_motion"] = _compute_part_fx_motion(
            parts_data[part_name]["albedo"][:, :, 3],
            id_channels_map[part_name],
            part_name,
            h_px,  # type: ignore
        )

    # Mirror right modules to left modules with Nx inversion
    for r_name, l_name in (("elytron_r", "elytron_l"), ("inner_wing_r", "inner_wing_l")):
        src = parts_data[r_name]
        m_alb, m_nh, m_ilm, m_fx = _mirror_part_pack(
            src["albedo"], src["normal_height"], src["ilm_sdf"], src["fx_motion"]
        )
        parts_data[l_name] = {
            "albedo": m_alb,
            "normal_height": m_nh,
            "ilm_sdf": m_ilm,
            "fx_motion": m_fx,
        }

    # Slice articulated scissor mandibles cleanly from body_core
    mandible_hinges = _split_mandibles_from_body_core(parts_data)
    hinges.update(mandible_hinges)

    # Export PNG packs
    out_dir.mkdir(parents=True, exist_ok=True)
    parts_meta: Dict[str, object] = {}
    for p_name, maps in parts_data.items():
        for suffix, arr in maps.items():
            _save_rgba(out_dir / f"{p_name}_{suffix}.png", arr)
        ah_p, aw_p = maps["albedo"].shape[:2]
        ih_p, iw_p = maps["ilm_sdf"].shape[:2]
        parts_meta[p_name] = {
            "albedo_size": [aw_p, ah_p],
            "ilm_sdf_size": [iw_p, ih_p],
            "ink_sdf_range_native_px": INK_SDF_RANGE_NATIVE_PX,
            "outer_sdf_range_native_px": OUTER_SDF_RANGE_NATIVE_PX,
        }

    rig_meta: Dict[str, object] = {
        "schema_version": 1,
        "enemy_id": "void_scarab",
        "faction": "biomech",
        "art_forward_axis": "UP_NEG_Y",
        "px_scale_from_raw": round(px_scale, 5),
        "parts": parts_meta,
        **hinges,
    }
    (out_dir / "rig_meta.json").write_text(json.dumps(rig_meta, indent=2), encoding="utf-8")
    _render_audit_sheet(audit_path, parts_data, rig_meta)
    print(f"[EnemyBuild] Exported 5-part pack (20 PNGs + rig_meta.json) to {out_dir}")
    print(f"[EnemyBuild] Audit sheet written to {audit_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Compile 2.5D enemy asset pack + 2x SDF maps.")
    parser.add_argument(
        "--raw-dir",
        type=Path,
        default=REPO_ROOT / "sandbox" / "enemy_art_lab" / "source_refs" / "void_scarab" / "00_raw",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=REPO_ROOT / "sandbox" / "enemy_art_lab" / "assets" / "void_scarab",
    )
    parser.add_argument(
        "--audit-path",
        type=Path,
        default=REPO_ROOT / "sandbox" / "enemy_art_lab" / "source_refs" / "void_scarab" / "01_audit" / "void_scarab_audit.png",
    )
    parser.add_argument("--prefix", type=str, default="void_scarab_parts")
    parser.add_argument("--no-upscayl", action="store_true")
    parser.add_argument("--no-rembg", action="store_true")
    parser.add_argument("--delight", type=float, default=0.14)
    args = parser.parse_args()

    compile_enemy(
        raw_dir=args.raw_dir,
        out_dir=args.out_dir,
        audit_path=args.audit_path,
        prefix=args.prefix,
        use_upscayl=not args.no_upscayl,
        use_rembg=not args.no_rembg,
        delight_strength=args.delight,
    )


if __name__ == "__main__":
    main()
