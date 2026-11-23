#!/usr/bin/env python3
"""Offline asset compiler (v2 — Per-Shard Psychic Blades) for Valentina v2 Astral Seraph Wings.

Pipeline:
  1. Reuses/generates Upscayl `digital-art-4x` upscaled 3-view canonical sheet (4096x2284).
  2. Segments the 4 canonical wings (`wing_0deg_r`, `wing_45deg_far`, `wing_45deg_near`,
     `wing_90deg`) — NO ruby diamond node.
  3. Splits EACH canonical wing into its **6 independent psychic crystal blades** (`shard_0`
     topmost longest -> `shard_5` bottommost), using morphological watershed fallback if any
     two shards touch at the root (e.g. foreshortened `wing_45deg_near`).
  4. Generates full Valentina v2 shader masks per shard:
       - `<wing>_s<i>.png`              (RGBA albedo, native tex_scale=3, Voronoi bleed)
       - `<wing>_s<i>_id_mask.png`      (R=crimson accent, G=silver crystal, B/A=0)
       - `<wing>_s<i>_ilm_mask.png`     (R=spec, G=AO/shadow bias, B=rim, A=emissive)
       - `<wing>_s<i>_normal_depth.png` (RGB=tangent normal, A=depth 80..239)
       - `<wing>_s<i>_ink_sdf.png`      (2x signed distance field, +-8.0 native texels)
  5. Generates exact horizontal mirrors (`wing_0deg_l`, `wing_45deg_far_flip`,
     `wing_45deg_near_flip`, `wing_90deg_flip`) with tangent normal `Nx` inverted.
  6. Exports `wings_metadata.json` (schema v2) with per-shard `rest_offset_px`, `pivot_px`,
     `tip_offset_px`, `length_norm`, and 8-dir routing table, plus a visual audit sheet.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from process_masked_5parts import upscale_with_upscayl  # noqa: E402

PILOT_RIG_LAB_DIR = TOOLS_DIR.parent
REPO_ROOT = PILOT_RIG_LAB_DIR.parent.parent
DEFAULT_SOURCE_SHEET = PILOT_RIG_LAB_DIR / "source_refs" / "valentina_v2_wings" / "wings_3views_sheet.jpg"
DEFAULT_OUT_DIR = REPO_ROOT / "assets" / "pilots" / "valentina_v2" / "planar" / "wings"
DEFAULT_AUDIT_PATH = PILOT_RIG_LAB_DIR / "source_refs" / "valentina_v2_wings" / "audit_wings_shards.png"

INK_SDF_RANGE_PX: float = 8.0
TARGET_WING_HEIGHT_PX: int = 720
PAD_NATIVE_PX: int = 16
EXPECTED_SHARDS: int = 6


def _voronoi_bleed_rgb(bgr: np.ndarray, alpha_mask: np.ndarray) -> np.ndarray:
    fg = alpha_mask > 128
    if not np.any(fg) or np.all(fg):
        return bgr.copy()
    _, labels = cv2.distanceTransformWithLabels(
        (~fg).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    fg_coords = np.argwhere(fg)
    idx = np.clip(labels - 1, 0, len(fg_coords) - 1)
    ys = fg_coords[idx, 0]
    xs = fg_coords[idx, 1]
    out = bgr.copy()
    out[~fg] = bgr[ys[~fg], xs[~fg]]
    return out


def _upscale_sheet(sheet_path: Path, no_upscayl: bool) -> np.ndarray:
    raw = cv2.imread(str(sheet_path), cv2.IMREAD_COLOR)
    if raw is None:
        raise RuntimeError(f"Could not read source sheet: {sheet_path}")
    rh, rw = raw.shape[:2]
    if no_upscayl or max(rw, rh) >= 3200:
        return raw

    up_dir = sheet_path.parent / "outputs_upscayl"
    up_dir.mkdir(parents=True, exist_ok=True)
    up_cache = up_dir / f"{sheet_path.stem}_4x.png"
    if not up_cache.exists() or up_cache.stat().st_mtime < sheet_path.stat().st_mtime:
        print(f"[UPSCAYL] digital-art-4x: {sheet_path.name} ({rw}x{rh}) -> {up_cache.name}")
        res_path = upscale_with_upscayl(sheet_path, up_cache, model="digital-art-4x")
    else:
        print(f"[UPSCAYL] Reusing cache: {up_cache.name}")
        res_path = up_cache

    up_bgr = cv2.imread(str(res_path), cv2.IMREAD_COLOR)
    if up_bgr is None:
        raise RuntimeError(f"Could not read upscaled sheet: {res_path}")
    return up_bgr


def _segment_foreground(sheet_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    h, w = sheet_bgr.shape[:2]
    border_samples = np.concatenate(
        [
            sheet_bgr[0:16, :, :].reshape(-1, 3),
            sheet_bgr[h - 16 : h, :, :].reshape(-1, 3),
            sheet_bgr[:, 0:16, :].reshape(-1, 3),
            sheet_bgr[:, w - 16 : w, :].reshape(-1, 3),
        ],
        axis=0,
    )
    bg_bgr = np.median(border_samples, axis=0).astype(np.float32)
    diff = np.linalg.norm(sheet_bgr.astype(np.float32) - bg_bgr[None, None, :], axis=2)

    bg_cand = (diff < 24.0).astype(np.uint8)
    _, labels = cv2.connectedComponents(bg_cand, connectivity=4)
    border_labels = set(np.unique(labels[0, :]).tolist())
    border_labels.update(np.unique(labels[h - 1, :]).tolist())
    border_labels.update(np.unique(labels[:, 0]).tolist())
    border_labels.update(np.unique(labels[:, w - 1]).tolist())
    border_labels.discard(0)

    fg_hard = ~np.isin(labels, list(border_labels))
    num_fg, fg_labels, fg_stats, _ = cv2.connectedComponentsWithStats(fg_hard.astype(np.uint8), connectivity=8)
    min_area = max(120, int(h * w * 0.00004))
    fg_clean = np.zeros((h, w), dtype=bool)
    for cid in range(1, num_fg):
        if fg_stats[cid, cv2.CC_STAT_AREA] >= min_area:
            fg_clean |= fg_labels == cid

    alpha = np.where(fg_clean, 255.0, 0.0).astype(np.float32)
    outer_ring = cv2.dilate(fg_clean.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1).astype(bool) & (~fg_clean)
    alpha[outer_ring] = np.clip((diff[outer_ring] - 10.0) / 14.0, 0.0, 1.0) * 255.0
    return fg_clean, np.clip(np.round(alpha), 0, 255).astype(np.uint8)


def _split_wing_into_shards(wing_mask: np.ndarray, target_count: int = EXPECTED_SHARDS) -> list[np.ndarray]:
    """Split a wing boolean mask into individual blade masks (using erosion+Voronoi if any touch)."""
    num_cc, labels, stats, _ = cv2.connectedComponentsWithStats(wing_mask.astype(np.uint8), connectivity=8)
    if num_cc - 1 >= target_count:
        shards = [labels == cid for cid in range(1, num_cc)]
    else:
        # Iteratively erode to detach thin bridges at the root, then assign pixels by nearest seed
        best_seeds: list[np.ndarray] = []
        for rad in (5, 9, 13, 17, 21, 25):
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (rad, rad))
            eroded = cv2.erode(wing_mask.astype(np.uint8), kernel, iterations=1)
            n_e, l_e, s_e, _ = cv2.connectedComponentsWithStats(eroded, connectivity=8)
            valid = [cid for cid in range(1, n_e) if s_e[cid, cv2.CC_STAT_AREA] >= 350]
            if len(valid) >= target_count:
                # Keep largest target_count seeds
                valid.sort(key=lambda c: int(s_e[c, cv2.CC_STAT_AREA]), reverse=True)
                best_seeds = [l_e == cid for cid in valid[:target_count]]
                break
        if not best_seeds:
            shards = [labels == cid for cid in range(1, num_cc)]
        else:
            # Assign every pixel in wing_mask to its nearest seed via distance transform
            h, w = wing_mask.shape
            best_dist = np.full((h, w), 1e9, dtype=np.float32)
            owner = np.full((h, w), -1, dtype=np.int32)
            for si, seed in enumerate(best_seeds):
                d = cv2.distanceTransform((~seed).astype(np.uint8), cv2.DIST_L2, 5)
                take = wing_mask & (d < best_dist)
                best_dist[take] = d[take]
                owner[take] = si
            shards = [owner == si for si in range(len(best_seeds))]

    # Sort top-to-bottom by centroid Y (shard_0 = uppermost longest blade -> shard_5 = bottommost)
    def _centroid_y(m: np.ndarray) -> float:
        ys, _ = np.where(m)
        return float(ys.mean()) if len(ys) > 0 else 0.0

    shards = [s for s in shards if np.any(s)]
    shards.sort(key=_centroid_y)
    return shards


def _group_canonical_wings(fg_clean: np.ndarray) -> dict[str, np.ndarray]:
    """Group connected components into the 4 canonical wings (excluding ruby nodes)."""
    h, w = fg_clean.shape
    num_cc, labels, stats, centroids = cv2.connectedComponentsWithStats(fg_clean.astype(np.uint8), connectivity=8)

    comps: list[dict] = []
    for cid in range(1, num_cc):
        comps.append(
            {
                "cid": cid,
                "area": int(stats[cid, cv2.CC_STAT_AREA]),
                "cx": float(centroids[cid, 0]),
                "cy": float(centroids[cid, 1]),
            }
        )

    col1 = [c for c in comps if c["cx"] < w * 0.33]
    col2 = [c for c in comps if w * 0.33 <= c["cx"] < w * 0.68]
    col3 = [c for c in comps if c["cx"] >= w * 0.68]

    def _mask_of(group: list[dict]) -> np.ndarray:
        m = np.zeros((h, w), dtype=bool)
        for c in group:
            m |= labels == c["cid"]
        return m

    col1_sorted = sorted(col1, key=lambda c: c["cx"])
    wing_0_c = col1_sorted[1:]  # skip ruby node

    col2_mid_x = 0.5 * (min(c["cx"] for c in col2) + max(c["cx"] for c in col2))
    col2_node = min(col2, key=lambda c: abs(c["cx"] - col2_mid_x) + 0.002 * c["area"])
    wing_45_far_c = [c for c in col2 if c["cid"] != col2_node["cid"] and c["cx"] < col2_node["cx"]]
    wing_45_near_c = [c for c in col2 if c["cid"] != col2_node["cid"] and c["cx"] > col2_node["cx"]]

    col3_sorted = sorted(col3, key=lambda c: c["cx"])
    wing_90_c = col3_sorted[:-1]  # skip ruby node

    return {
        "wing_0deg_r": _mask_of(wing_0_c),
        "wing_45deg_far": _mask_of(wing_45_far_c),
        "wing_45deg_near": _mask_of(wing_45_near_c),
        "wing_90deg": _mask_of(wing_90_c),
    }


def _extract_ink_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2]
    sat = hsv[:, :, 1]
    dark_neutral = (val < 132) & (sat < 130)
    dark_crimson = (val < 110) & (sat >= 130)
    ink = (dark_neutral | dark_crimson) & fg_hr
    eroded = cv2.erode(fg_hr.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1) > 0
    ink |= fg_hr & (~eroded)
    return ink


def _build_id_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, ink_hr: np.ndarray) -> np.ndarray:
    h, w = fg_hr.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    hue, sat, val = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    r_ch = bgr_hr[:, :, 2].astype(np.int16)
    g_ch = bgr_hr[:, :, 1].astype(np.int16)

    is_red_hue = (hue <= 18) | (hue >= 152)
    crimson = fg_hr & (~ink_hr) & is_red_hue & (sat > 52) & ((r_ch - g_ch) > 18) & (val > 80)
    silver = fg_hr & (~ink_hr) & (~crimson)

    classified = crimson | silver
    if np.any(classified):
        _, labels = cv2.distanceTransformWithLabels(
            (~classified).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
        )
        coords = np.argwhere(classified)
        idx = np.clip(labels - 1, 0, len(coords) - 1)
        is_crimson_full = crimson[coords[idx, 0], coords[idx, 1]] & fg_hr
    else:
        is_crimson_full = np.zeros_like(fg_hr)

    is_silver_full = fg_hr & (~is_crimson_full)
    out[is_crimson_full, 2] = 255
    out[is_silver_full, 1] = 255
    return out


def _build_ilm_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, ink_hr: np.ndarray, id_bgra_hr: np.ndarray) -> np.ndarray:
    h, w = fg_hr.shape
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2].astype(np.float32) / 255.0
    is_crimson = id_bgra_hr[:, :, 2] > 128

    dist_in = cv2.distanceTransform(fg_hr.astype(np.uint8), cv2.DIST_L2, 5)
    max_d = max(1.0, float(np.percentile(dist_in[fg_hr], 90)) if np.any(fg_hr) else 1.0)
    edge_factor = np.clip(1.0 - dist_in / (0.38 * max_d), 0.0, 1.0)

    spec = np.where(is_crimson, 235.0, 145.0 + 95.0 * np.clip((val - 0.55) / 0.45, 0.0, 1.0))
    spec = np.where(ink_hr, 40.0, spec)

    ao = np.where(is_crimson, 232.0, 110.0 + 90.0 * np.clip((val - 0.45) / 0.50, 0.0, 1.0))
    ao = np.where(ink_hr, 55.0, ao)

    rim = 110.0 + 145.0 * (edge_factor ** 0.72)

    emissive = np.where(is_crimson & (~ink_hr), 255.0, np.where(is_crimson, 150.0, 0.0))
    emissive = cv2.GaussianBlur(emissive.astype(np.float32), (0, 0), sigmaX=1.2)
    emissive = np.where(fg_hr, emissive, 0.0)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 0] = np.clip(np.round(np.where(fg_hr, rim, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(np.round(np.where(fg_hr, ao, 128.0)), 0, 255).astype(np.uint8)
    out[:, :, 2] = np.clip(np.round(np.where(fg_hr, spec, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(np.round(emissive), 0, 255).astype(np.uint8)
    return out


def _build_normal_depth_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, shard_index: int) -> np.ndarray:
    h, w = fg_hr.shape
    dist_in = cv2.distanceTransform(fg_hr.astype(np.uint8), cv2.DIST_L2, 5)
    bevel_h = np.sqrt(np.clip(dist_in / 26.0, 0.0, 1.0))
    bevel_h = cv2.GaussianBlur(bevel_h.astype(np.float32), (0, 0), sigmaX=2.8)

    gray = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    gray_smooth = cv2.GaussianBlur(gray, (0, 0), sigmaX=2.0)

    height = 0.72 * bevel_h + 0.28 * gray_smooth
    gx = cv2.Sobel(height, cv2.CV_32F, 1, 0, ksize=5) * 0.45
    gy = cv2.Sobel(height, cv2.CV_32F, 0, 1, ksize=5) * 0.45

    nx, ny, nz = -gx, -gy, np.ones_like(gx, dtype=np.float32)
    nlen = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx = np.where(fg_hr, nx / nlen, 0.0)
    ny = np.where(fg_hr, ny / nlen, 0.0)
    nz = np.where(fg_hr, nz / nlen, 1.0)

    base_depth = 195.0 - float(shard_index) * 14.0
    depth = np.where(fg_hr, np.clip(base_depth + 40.0 * bevel_h, 80.0, 239.0), 128.0)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 2] = np.clip(np.round((nx * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[:, :, 0] = np.clip(np.round((nz * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(np.round(depth), 0, 255).astype(np.uint8)
    return out


def _encode_sdf_2x(ink_hr: np.ndarray, native_w: int, native_h: int, hr_to_native_scale: float) -> np.ndarray:
    out_w, out_h = native_w * 2, native_h * 2
    if not np.any(ink_hr):
        return np.full((out_h, out_w, 4), 255, dtype=np.uint8)
    d_out = cv2.distanceTransform((~ink_hr).astype(np.uint8), cv2.DIST_L2, 5) * hr_to_native_scale
    d_in = cv2.distanceTransform(ink_hr.astype(np.uint8), cv2.DIST_L2, 5) * hr_to_native_scale
    sdf_2x = cv2.resize(d_out - d_in, (out_w, out_h), interpolation=cv2.INTER_AREA)
    u8 = np.clip(np.round(np.clip(0.5 + sdf_2x / (2.0 * INK_SDF_RANGE_PX), 0.0, 1.0) * 255.0), 0, 255).astype(np.uint8)
    return np.stack([u8, u8, u8, np.full((out_h, out_w), 255, dtype=np.uint8)], axis=2)


def _wing_root_hr(wing_mask: np.ndarray, wing_name: str) -> tuple[float, float]:
    ys, xs = np.where(wing_mask)
    mid_y = float(np.percentile(ys, 52))
    near_mid = np.abs(ys - mid_y) < max(24.0, (ys.max() - ys.min()) * 0.14)
    cxs = xs[near_mid] if np.any(near_mid) else xs
    cys = ys[near_mid] if np.any(near_mid) else ys
    idx = int(np.argmin(cxs)) if wing_name in ("wing_0deg_r", "wing_45deg_near") else int(np.argmax(cxs))
    return float(cxs[idx]), float(cys[idx])


def _shard_pivot_and_tip_hr(shard_mask: np.ndarray, wing_root: tuple[float, float]) -> tuple[tuple[float, float], tuple[float, float], float]:
    """Return (root_hr, tip_hr, length_hr): pixel closest to wing_root vs farthest from wing_root."""
    ys, xs = np.where(shard_mask)
    dx = xs.astype(np.float32) - wing_root[0]
    dy = ys.astype(np.float32) - wing_root[1]
    d2 = dx * dx + dy * dy
    i_root = int(np.argmin(d2))
    i_tip = int(np.argmax(d2))
    rx, ry = float(xs[i_root]), float(ys[i_root])
    tx, ty = float(xs[i_tip]), float(ys[i_tip])
    length = math.hypot(tx - rx, ty - ry)
    return (rx, ry), (tx, ty), length


def _save_bundle(out_dir: Path, name: str, alb: np.ndarray, idm: np.ndarray, ilm: np.ndarray, nrm: np.ndarray, sdf: np.ndarray) -> None:
    cv2.imwrite(str(out_dir / f"{name}.png"), alb)
    cv2.imwrite(str(out_dir / f"{name}_id_mask.png"), idm)
    cv2.imwrite(str(out_dir / f"{name}_ilm_mask.png"), ilm)
    cv2.imwrite(str(out_dir / f"{name}_normal_depth.png"), nrm)
    cv2.imwrite(str(out_dir / f"{name}_ink_sdf.png"), sdf)


def _mirror_bundle(alb: np.ndarray, idm: np.ndarray, ilm: np.ndarray, nrm: np.ndarray, sdf: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    m_nrm = cv2.flip(nrm, 1)
    m_nrm[:, :, 2] = 255 - m_nrm[:, :, 2]
    return cv2.flip(alb, 1), cv2.flip(idm, 1), cv2.flip(ilm, 1), m_nrm, cv2.flip(sdf, 1)


def _render_shards_audit(sheet_hr: np.ndarray, wing_shards_map: dict[str, list[dict]], audit_path: Path) -> None:
    """Visual verification: shows each of the 4 canonical wings with 6 color-coded shards + root/tip markers."""
    colors = [(90, 90, 255), (80, 210, 255), (90, 255, 130), (255, 220, 80), (255, 120, 200), (200, 140, 255)]
    cell_w, cell_h = 360, 420
    canvas = np.full((cell_h, cell_w * len(wing_shards_map), 3), (20, 24, 34), dtype=np.uint8)
    for ci, (wname, entries) in enumerate(wing_shards_map.items()):
        x_off = ci * cell_w
        cv2.putText(canvas, f"{wname} ({len(entries)} shards)", (x_off + 12, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (235, 240, 250), 1, cv2.LINE_AA)
        all_pts = []
        for e in entries:
            all_pts.append(e["rest_offset"])
            all_pts.append([e["rest_offset"][0] + e["tip_rel"][0], e["rest_offset"][1] + e["tip_rel"][1]])
        xs = [p[0] for p in all_pts]
        ys = [p[1] for p in all_pts]
        min_x, max_x = min(xs) - 30.0, max(xs) + 30.0
        min_y, max_y = min(ys) - 30.0, max(ys) + 30.0
        sc = min((cell_w - 30.0) / max(1.0, max_x - min_x), (cell_h - 60.0) / max(1.0, max_y - min_y))
        for si, e in enumerate(entries):
            col = colors[si % len(colors)]
            rx = int(round(x_off + 15.0 + (e["rest_offset"][0] - min_x) * sc))
            ry = int(round(45.0 + (e["rest_offset"][1] - min_y) * sc))
            tx = int(round(x_off + 15.0 + (e["rest_offset"][0] + e["tip_rel"][0] - min_x) * sc))
            ty = int(round(45.0 + (e["rest_offset"][1] + e["tip_rel"][1] - min_y) * sc))
            cv2.line(canvas, (rx, ry), (tx, ty), col, 3, cv2.LINE_AA)
            cv2.circle(canvas, (rx, ry), 5, (80, 255, 110), -1)
            cv2.drawMarker(canvas, (tx, ty), (80, 120, 255), cv2.MARKER_DIAMOND, 10, 2)
            cv2.putText(canvas, f"s{si}", (tx + 5, ty), cv2.FONT_HERSHEY_SIMPLEX, 0.42, col, 1, cv2.LINE_AA)
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(audit_path), canvas)
    print(f"[AUDIT] Saved per-shard geometry audit -> {audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile Valentina v2 per-shard Astral Seraph psychic wing assets.")
    parser.add_argument("--sheet", type=Path, default=DEFAULT_SOURCE_SHEET)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT_PATH)
    parser.add_argument("--no-upscayl", action="store_true")
    args = parser.parse_args()

    sheet_hr = _upscale_sheet(args.sheet, args.no_upscayl)
    fg_clean, alpha_hr = _segment_foreground(sheet_hr)
    canonical_wings = _group_canonical_wings(fg_clean)

    ys_ref, _ = np.where(canonical_wings["wing_0deg_r"])
    ref_h_hr = max(1, int(ys_ref.max() - ys_ref.min() + 1))
    hr_to_native = float(TARGET_WING_HEIGHT_PX) / float(ref_h_hr)
    print(f"[SCALE] wing_0deg_r HR height={ref_h_hr}px -> target={TARGET_WING_HEIGHT_PX}px (factor={hr_to_native:.4f})")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    # Remove stale legacy single-piece / wing_node PNGs if present
    for old_png in args.out_dir.glob("wing_node*.png"):
        old_png.unlink(missing_ok=True)

    mirror_map: dict[str, str] = {
        "wing_0deg_r": "wing_0deg_l",
        "wing_45deg_far": "wing_45deg_far_flip",
        "wing_45deg_near": "wing_45deg_near_flip",
        "wing_90deg": "wing_90deg_flip",
    }

    wings_meta: dict[str, list[dict]] = {}
    audit_map: dict[str, list[dict]] = {}

    for wname, wmask in canonical_wings.items():
        shards_hr = _split_wing_into_shards(wmask, EXPECTED_SHARDS)
        wing_root = _wing_root_hr(wmask, wname)
        print(f"[SHARDS] {wname}: {len(shards_hr)} independent blades extracted")

        # Measure lengths for normalized ribbon hierarchy (1.0 longest -> smaller)
        raw_geom = [_shard_pivot_and_tip_hr(sm, wing_root) for sm in shards_hr]
        max_len = max(1.0, max(g[2] for g in raw_geom))

        m_wname = mirror_map[wname]
        wings_meta[wname] = []
        wings_meta[m_wname] = []
        audit_map[wname] = []

        for si, (smask, (s_root, s_tip, s_len)) in enumerate(zip(shards_hr, raw_geom)):
            ys, xs = np.where(smask)
            pad_hr = max(6, int(round(PAD_NATIVE_PX / hr_to_native)))
            y0 = max(0, int(ys.min()) - pad_hr)
            y1 = min(sheet_hr.shape[0], int(ys.max()) + pad_hr + 1)
            x0 = max(0, int(xs.min()) - pad_hr)
            x1 = min(sheet_hr.shape[1], int(xs.max()) + pad_hr + 1)

            crop_bgr = sheet_hr[y0:y1, x0:x1].copy()
            crop_fg = smask[y0:y1, x0:x1]
            dil = cv2.dilate(crop_fg.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1) > 0
            crop_alpha = np.where(dil, alpha_hr[y0:y1, x0:x1], 0).astype(np.uint8)

            ink_hr = _extract_ink_mask_hr(crop_bgr, crop_fg)
            id_hr = _build_id_mask_hr(crop_bgr, crop_fg, ink_hr)
            ilm_hr = _build_ilm_mask_hr(crop_bgr, crop_fg, ink_hr, id_hr)
            nrm_hr = _build_normal_depth_hr(crop_bgr, crop_fg, si)

            nw = max(12, int(round((x1 - x0) * hr_to_native)))
            nh = max(12, int(round((y1 - y0) * hr_to_native)))

            alb_rgb = cv2.resize(crop_bgr, (nw, nh), interpolation=cv2.INTER_AREA)
            alb_a = cv2.resize(crop_alpha, (nw, nh), interpolation=cv2.INTER_AREA)
            alb_1x = np.dstack([_voronoi_bleed_rgb(alb_rgb, alb_a), alb_a])
            id_1x = cv2.resize(id_hr, (nw, nh), interpolation=cv2.INTER_NEAREST)
            ilm_1x = cv2.resize(ilm_hr, (nw, nh), interpolation=cv2.INTER_AREA)
            nrm_1x = cv2.resize(nrm_hr, (nw, nh), interpolation=cv2.INTER_AREA)
            sdf_2x = _encode_sdf_2x(ink_hr, nw, nh, hr_to_native)

            piv_px = [round((s_root[0] - x0) * hr_to_native, 1), round((s_root[1] - y0) * hr_to_native, 1)]
            tip_px = [round((s_tip[0] - x0) * hr_to_native, 1), round((s_tip[1] - y0) * hr_to_native, 1)]
            rest_off = [round((s_root[0] - wing_root[0]) * hr_to_native, 1), round((s_root[1] - wing_root[1]) * hr_to_native, 1)]
            len_norm = round(s_len / max_len, 3)

            piece_id = f"{wname}_s{si}"
            _save_bundle(args.out_dir, piece_id, alb_1x, id_1x, ilm_1x, nrm_1x, sdf_2x)
            wings_meta[wname].append(
                {
                    "id": piece_id,
                    "shard_index": si,
                    "size_px": [nw, nh],
                    "pivot_px": piv_px,
                    "tip_offset_px": tip_px,
                    "rest_offset_px": rest_off,
                    "length_norm": len_norm,
                }
            )
            audit_map[wname].append({"rest_offset": rest_off, "tip_rel": [tip_px[0] - piv_px[0], tip_px[1] - piv_px[1]]})

            # Exact horizontal mirror
            m_piece_id = f"{m_wname}_s{si}"
            m_alb, m_id, m_ilm, m_nrm, m_sdf = _mirror_bundle(alb_1x, id_1x, ilm_1x, nrm_1x, sdf_2x)
            _save_bundle(args.out_dir, m_piece_id, m_alb, m_id, m_ilm, m_nrm, m_sdf)
            wings_meta[m_wname].append(
                {
                    "id": m_piece_id,
                    "shard_index": si,
                    "size_px": [nw, nh],
                    "pivot_px": [round((nw - 1) - piv_px[0], 1), piv_px[1]],
                    "tip_offset_px": [round((nw - 1) - tip_px[0], 1), tip_px[1]],
                    "rest_offset_px": [round(-rest_off[0], 1), rest_off[1]],
                    "length_norm": len_norm,
                }
            )

    metadata = {
        "schema_version": 2,
        "wing_style": "astral_seraph_psychic_blades",
        "tex_scale": 3,
        "ink_sdf_scale": 2,
        "ink_sdf_range_px": INK_SDF_RANGE_PX,
        "shards_per_wing": EXPECTED_SHARDS,
        "wings": wings_meta,
        "views": {
            "s": {"wing_l": "wing_0deg_l", "wing_r": "wing_0deg_r", "layer": "behind_body"},
            "n": {"wing_l": "wing_0deg_l", "wing_r": "wing_0deg_r", "layer": "over_back"},
            "se": {"wing_l": "wing_45deg_far", "wing_r": "wing_45deg_near", "layer": "behind_body"},
            "sw": {"wing_l": "wing_45deg_near_flip", "wing_r": "wing_45deg_far_flip", "layer": "behind_body"},
            "ne": {"wing_l": "wing_45deg_far", "wing_r": "wing_45deg_near", "layer": "over_back"},
            "nw": {"wing_l": "wing_45deg_near_flip", "wing_r": "wing_45deg_far_flip", "layer": "over_back"},
            "e": {"wing_l": "wing_90deg", "wing_r": "wing_90deg", "layer": "split_profile", "rear_darken": 0.85},
            "w": {"wing_l": "wing_90deg_flip", "wing_r": "wing_90deg_flip", "layer": "split_profile", "rear_darken": 0.85},
        },
    }
    meta_path = args.out_dir / "wings_metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"[DONE] Exported {len(wings_meta)} wings x {EXPECTED_SHARDS} shards -> {meta_path}")
    _render_shards_audit(sheet_hr, audit_map, args.audit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
