#!/usr/bin/env python3
"""Offline multi-map compiler (Rig v2 standard) for Valentina v2 Orbital Weapons.

Pipeline:
  1. Loads clean master sprite on uniform neutral grey (#808080) background.
  2. Optionally upscales 4x via Upscayl (`digital-art-4x`) for razor-sharp lineart.
  3. Segments foreground cleanly via border-connected component flood fill, tight-crops
     with uniform padding, resizes to `--target-width`, and applies Voronoi RGB bleed.
  4. Extracts Valentina v2 Rig shader maps:
       - `<name>.png`           (RGBA albedo, Voronoi RGB bleed)
       - `<name>_id_mask.png`   (R=crimson accent, G=silver plates, B=dark navy chassis)
       - `<name>_ilm_mask.png`  (R=specular, G=AO/cel bias, B=rim weight, A=HDR emissive)
       - `<name>_ink_sdf.png`   (2x signed distance field, +-8.0 native texels)
       - `<name>_meta.json`     (dimensions, pivot_u, muzzle_u, source path)
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

from process_masked_5parts import upscale_with_upscayl  # noqa: E402

PILOT_RIG_LAB_DIR = TOOLS_DIR.parent
DEFAULT_SRC = PILOT_RIG_LAB_DIR / "source_refs" / "valentina_v2_weapons" / "rail_lance_autonomo_master.jpg"
DEFAULT_OUT_DIR = PILOT_RIG_LAB_DIR / "combat_assets" / "valentina_v2_planar" / "weapons"

INK_SDF_RANGE_PX: float = 8.0
DEFAULT_TARGET_WIDTH: int = 1024
DEFAULT_PAD_PX: int = 24


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


def _upscale_master(src_path: Path, no_upscayl: bool) -> np.ndarray:
    raw = cv2.imread(str(src_path), cv2.IMREAD_COLOR)
    if raw is None:
        raise RuntimeError(f"Could not read source weapon sprite: {src_path}")
    rh, rw = raw.shape[:2]
    if no_upscayl or max(rw, rh) >= 3200:
        return raw

    up_dir = src_path.parent / "outputs_upscayl"
    up_dir.mkdir(parents=True, exist_ok=True)
    up_cache = up_dir / f"{src_path.stem}_4x.png"
    if not up_cache.exists() or up_cache.stat().st_mtime < src_path.stat().st_mtime:
        print(f"[UPSCAYL] digital-art-4x: {src_path.name} ({rw}x{rh}) -> {up_cache.name}")
        res_path = upscale_with_upscayl(src_path, up_cache, model="digital-art-4x")
    else:
        print(f"[UPSCAYL] Reusing cache: {up_cache.name}")
        res_path = up_cache

    up_bgr = cv2.imread(str(res_path), cv2.IMREAD_COLOR)
    if up_bgr is None:
        raise RuntimeError(f"Could not read upscaled image: {res_path}")
    return up_bgr


def _segment_foreground(bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    h, w = bgr.shape[:2]
    border_samples = np.concatenate(
        [
            bgr[0:16, :, :].reshape(-1, 3),
            bgr[h - 16 : h, :, :].reshape(-1, 3),
            bgr[:, 0:16, :].reshape(-1, 3),
            bgr[:, w - 16 : w, :].reshape(-1, 3),
        ],
        axis=0,
    )
    bg_bgr = np.median(border_samples, axis=0).astype(np.float32)
    diff = np.linalg.norm(bgr.astype(np.float32) - bg_bgr[None, None, :], axis=2)

    bg_cand = (diff < 24.0).astype(np.uint8)
    _, labels = cv2.connectedComponents(bg_cand, connectivity=4)
    border_labels = set(np.unique(labels[0, :]).tolist())
    border_labels.update(np.unique(labels[h - 1, :]).tolist())
    border_labels.update(np.unique(labels[:, 0]).tolist())
    border_labels.update(np.unique(labels[:, w - 1]).tolist())
    border_labels.discard(0)

    fg_hard = ~np.isin(labels, list(border_labels))
    num_fg, fg_labels, fg_stats, _ = cv2.connectedComponentsWithStats(fg_hard.astype(np.uint8), connectivity=8)
    min_area = max(200, int(h * w * 0.0002))
    fg_clean = np.zeros((h, w), dtype=bool)
    for cid in range(1, num_fg):
        if fg_stats[cid, cv2.CC_STAT_AREA] >= min_area:
            fg_clean |= fg_labels == cid

    alpha = np.where(fg_clean, 255.0, 0.0).astype(np.float32)
    outer_ring = cv2.dilate(fg_clean.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1).astype(bool) & (~fg_clean)
    alpha[outer_ring] = np.clip((diff[outer_ring] - 10.0) / 14.0, 0.0, 1.0) * 255.0
    return fg_clean, np.clip(np.round(alpha), 0, 255).astype(np.uint8)


def _extract_ink_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, hr_scale: float) -> np.ndarray:
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2]
    sat = hsv[:, :, 1]

    gray = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2GRAY)
    bh_size = max(5, int(round(7 * hr_scale)) | 1)
    bh_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (bh_size, bh_size))
    blackhat = cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, bh_kernel)

    very_dark = (val < 40) & (sat < 175)
    thin_ridges = (blackhat > 22) & (val < 150)
    ink = (very_dark | thin_ridges) & fg_hr

    # Close tiny 1px pinholes inside solid dark ink strokes
    close_k = np.ones((3, 3), dtype=np.uint8)
    ink = (cv2.morphologyEx(ink.astype(np.uint8), cv2.MORPH_CLOSE, close_k) > 0) & fg_hr

    border_k = max(3, int(round(4 * hr_scale)) | 1)
    eroded = cv2.erode(fg_hr.astype(np.uint8), np.ones((border_k, border_k), dtype=np.uint8), iterations=1) > 0
    ink |= fg_hr & (~eroded)
    return ink


def _build_id_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, ink_hr: np.ndarray) -> np.ndarray:
    h, w = fg_hr.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    hue, sat, val = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    b_ch = bgr_hr[:, :, 0].astype(np.int16)
    g_ch = bgr_hr[:, :, 1].astype(np.int16)
    r_ch = bgr_hr[:, :, 2].astype(np.int16)

    # Guard outer boundary from transitional dark-AA ink edge pixels
    interior = cv2.erode(fg_hr.astype(np.uint8), np.ones((7, 7), dtype=np.uint8), iterations=1) > 0
    is_red_hue = (hue <= 18) | (hue >= 152)
    crimson = fg_hr & (~ink_hr) & is_red_hue & (sat >= 55) & ((r_ch - g_ch) > 18) & (val >= 52)
    navy_chassis = interior & (~ink_hr) & (~crimson) & (val < 135) & (b_ch >= r_ch + 4)
    silver_plates = fg_hr & (~ink_hr) & (~crimson) & (~navy_chassis)

    # Encode labels 1=crimson (R), 2=silver (G), 3=navy (B) and bleed across ink/edges
    cls_map = np.zeros((h, w), dtype=np.uint8)
    cls_map[crimson] = 1
    cls_map[silver_plates] = 2
    cls_map[navy_chassis] = 3

    classified = cls_map > 0
    if np.any(classified):
        _, labels = cv2.distanceTransformWithLabels(
            (~classified).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
        )
        coords = np.argwhere(classified)
        idx = np.clip(labels - 1, 0, len(coords) - 1)
        filled = cls_map[coords[idx, 0], coords[idx, 1]]
        out[(filled == 1) & fg_hr, 2] = 255  # R channel (BGR index 2)
        out[(filled == 2) & fg_hr, 1] = 255  # G channel (BGR index 1)
        out[(filled == 3) & fg_hr, 0] = 255  # B channel (BGR index 0)
    out[:, :, 3] = np.where(fg_hr, 255, 0).astype(np.uint8)
    return out


def _build_ilm_mask_hr(
    bgr_hr: np.ndarray,
    fg_hr: np.ndarray,
    ink_hr: np.ndarray,
    id_bgra_hr: np.ndarray,
) -> np.ndarray:
    h, w = fg_hr.shape
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2].astype(np.float32) / 255.0

    is_crimson = id_bgra_hr[:, :, 2] > 128
    is_silver = id_bgra_hr[:, :, 1] > 128
    is_navy = id_bgra_hr[:, :, 0] > 128

    dist_in = cv2.distanceTransform(fg_hr.astype(np.uint8), cv2.DIST_L2, 5)
    max_d = max(1.0, float(np.percentile(dist_in[fg_hr], 90)) if np.any(fg_hr) else 1.0)
    edge_factor = np.clip(1.0 - dist_in / (0.36 * max_d), 0.0, 1.0)

    # R (BGR idx 2): Specular intensity
    spec = np.where(
        is_crimson,
        235.0,
        np.where(is_silver, 165.0 + 85.0 * np.clip((val - 0.55) / 0.45, 0.0, 1.0), 85.0),
    )
    spec = np.where(ink_hr, 32.0, spec)

    # G (BGR idx 1): AO / Cel-bias
    ao = np.where(
        is_crimson,
        235.0,
        np.where(is_silver, 125.0 + 100.0 * np.clip((val - 0.45) / 0.50, 0.0, 1.0), 75.0 + 50.0 * val),
    )
    ao = np.where(ink_hr, 48.0, ao)

    # B (BGR idx 0): Rim-light mask
    rim = np.where(is_navy, 80.0 + 95.0 * (edge_factor ** 0.8), 115.0 + 140.0 * (edge_factor ** 0.7))

    # A: Emissive mask (core & rail conduits at full strength, fin tips slightly softer)
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    tip_attenuation = np.where(xs < 0.25, 0.72, 1.0)
    emissive = np.where(is_crimson & (~ink_hr), 255.0 * tip_attenuation, np.where(is_crimson, 130.0 * tip_attenuation, 0.0))
    emissive = cv2.GaussianBlur(emissive.astype(np.float32), (0, 0), sigmaX=1.2)
    emissive = np.where(fg_hr, emissive, 0.0)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 2] = np.clip(np.round(np.where(fg_hr, spec, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(np.round(np.where(fg_hr, ao, 128.0)), 0, 255).astype(np.uint8)
    out[:, :, 0] = np.clip(np.round(np.where(fg_hr, rim, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(np.round(emissive), 0, 255).astype(np.uint8)
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile weapon master sprite into Rig v2 multi-map bundle.")
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--name", type=str, default="valentina_rail_lance")
    parser.add_argument("--target-width", type=int, default=DEFAULT_TARGET_WIDTH)
    parser.add_argument("--no-upscayl", action="store_true")
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    bgr_hr = _upscale_master(args.src, args.no_upscayl)
    hr_h, hr_w = bgr_hr.shape[:2]

    fg_hr, alpha_hr = _segment_foreground(bgr_hr)
    ys, xs = np.where(fg_hr)
    if len(xs) == 0:
        raise RuntimeError("No foreground detected in master weapon sprite.")

    raw_w = int(xs.max() - xs.min() + 1)
    hr_to_native = float(args.target_width - 2 * DEFAULT_PAD_PX) / max(1.0, float(raw_w))
    pad_hr = max(8, int(round(DEFAULT_PAD_PX / max(hr_to_native, 1e-4))))

    x0 = max(0, int(xs.min()) - pad_hr)
    x1 = min(hr_w, int(xs.max()) + 1 + pad_hr)
    y0 = max(0, int(ys.min()) - pad_hr)
    y1 = min(hr_h, int(ys.max()) + 1 + pad_hr)

    crop_bgr = bgr_hr[y0:y1, x0:x1].copy()
    crop_fg = fg_hr[y0:y1, x0:x1]
    dil = cv2.dilate(crop_fg.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1) > 0
    crop_alpha = np.where(dil, alpha_hr[y0:y1, x0:x1], 0).astype(np.uint8)

    hr_scale = max(1.0, float(x1 - x0) / float(args.target_width))
    ink_hr = _extract_ink_mask_hr(crop_bgr, crop_fg, hr_scale)
    id_hr = _build_id_mask_hr(crop_bgr, crop_fg, ink_hr)
    ilm_hr = _build_ilm_mask_hr(crop_bgr, crop_fg, ink_hr, id_hr)

    nw = max(64, int(round((x1 - x0) * hr_to_native)))
    nh = max(64, int(round((y1 - y0) * hr_to_native)))

    alb_rgb = cv2.resize(crop_bgr, (nw, nh), interpolation=cv2.INTER_AREA)
    alb_a = cv2.resize(crop_alpha, (nw, nh), interpolation=cv2.INTER_AREA)
    alb_1x = np.dstack([_voronoi_bleed_rgb(alb_rgb, alb_a), alb_a])
    id_1x = cv2.resize(id_hr, (nw, nh), interpolation=cv2.INTER_NEAREST)
    ilm_1x = cv2.resize(ilm_hr, (nw, nh), interpolation=cv2.INTER_AREA)
    sdf_2x = _encode_sdf_2x(ink_hr, nw, nh, hr_to_native)

    # Compute normalized pivot_u (center of ruby chamber) and muzzle_u (rail tip)
    fg_1x = alb_a > 128
    fg_xs = np.where(fg_1x)[1]
    left_u = float(fg_xs.min()) / float(nw)
    right_u = float(fg_xs.max()) / float(nw)
    crystal_mask = (id_1x[:, :, 2] > 128) & (np.linspace(0.0, 1.0, nw)[None, :] > 0.25) & (np.linspace(0.0, 1.0, nw)[None, :] < 0.50)
    if np.any(crystal_mask):
        pivot_u = round(float(np.where(crystal_mask)[1].mean()) / float(nw), 3)
    else:
        pivot_u = round(0.40 * (right_u - left_u) + left_u, 3)
    muzzle_u = round(min(0.99, right_u - 0.01), 3)

    cv2.imwrite(str(args.out_dir / f"{args.name}.png"), alb_1x)
    cv2.imwrite(str(args.out_dir / f"{args.name}_id_mask.png"), id_1x)
    cv2.imwrite(str(args.out_dir / f"{args.name}_ilm_mask.png"), ilm_1x)
    cv2.imwrite(str(args.out_dir / f"{args.name}_ink_sdf.png"), sdf_2x)

    meta = {
        "schema_version": 1,
        "name": args.name,
        "source": str(args.src.relative_to(PILOT_RIG_LAB_DIR)).replace("\\", "/") if args.src.is_relative_to(PILOT_RIG_LAB_DIR) else str(args.src),
        "size_px": [nw, nh],
        "ink_sdf_scale": 2,
        "ink_sdf_range_px": INK_SDF_RANGE_PX,
        "pivot_u": pivot_u,
        "muzzle_u": muzzle_u,
    }
    meta_path = args.out_dir / f"{args.name}_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"[DONE] Compiled {args.name} ({nw}x{nh}, ink_sdf {nw*2}x{nh*2}, pivot_u={pivot_u}, muzzle_u={muzzle_u}) -> {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
