#!/usr/bin/env python3
"""
Reusable chroma-key & PBR/Cel map generator for the Stela Galactica title logo.
Takes a chroma-green (#00FF00) isolated emblem image and produces:
  - stela_galactica_logo_albedo.png (clean RGBA with despilled anti-aliased edges)
  - stela_galactica_logo_normal.png (tangent-space normal map from bevel SDF + metallic ridges)
  - stela_galactica_logo_masks.png  (R: gold/metal, G: cyan rim/accent, B: bevel height/AO)

Usage:
  python tools/process_stela_logo.py --input path/to/raw.png --out-dir assets/ui
"""

import argparse
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter


def find_green_bg_mask(rgb: np.ndarray) -> np.ndarray:
    """Return boolean mask of all chroma-green (#00FF00) pixels (including enclosed letter holes)."""
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)

    green_excess = g - np.maximum(r, b)
    return (green_excess > 34.0) & (g > 90.0)


def compute_alpha_and_despill(rgb: np.ndarray, bg_mask: np.ndarray) -> np.ndarray:
    """Create soft anti-aliased alpha around bg_mask and despill green fringe."""
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)

    alpha = np.where(bg_mask, 0.0, 255.0).astype(np.float32)

    # Smooth 1.2px edge feathering by eroding/blurring binary mask slightly on boundary
    mask_img = Image.fromarray((~bg_mask).astype(np.uint8) * 255, mode="L")
    blurred = np.asarray(mask_img.filter(ImageFilter.GaussianBlur(radius=0.85)), dtype=np.float32)

    # Soften green-tinted boundary pixels near the exterior
    green_excess = np.clip(g - np.maximum(r, b), 0.0, 255.0)
    fringe = (blurred < 245.0) & (~bg_mask) & (green_excess > 12.0)
    alpha[fringe] = np.clip(alpha[fringe] * (1.0 - (green_excess[fringe] / 120.0)), 0.0, 255.0)
    alpha = np.minimum(alpha, np.where(bg_mask, 0.0, np.clip(blurred * 1.15, 0.0, 255.0)))

    # Despill green channel near semi-transparent or bright-green-adjacent edges
    edge_zone = (blurred < 252.0) | (green_excess > 8.0)
    max_rb = np.maximum(r, b)
    g_despill = np.minimum(g, max_rb + 6.0)
    g = np.where(edge_zone, g_despill, g)

    # Darken remaining bright fringe where alpha < 210 to avoid bright edge halos
    semi = (alpha > 0.0) & (alpha < 210.0)
    dark_factor = np.where(semi, 0.45 + 0.55 * (alpha / 210.0), 1.0)
    r *= dark_factor
    g *= dark_factor
    b *= dark_factor

    rgba = np.stack([
        np.clip(r, 0, 255).astype(np.uint8),
        np.clip(g, 0, 255).astype(np.uint8),
        np.clip(b, 0, 255).astype(np.uint8),
        np.clip(alpha, 0, 255).astype(np.uint8),
    ], axis=-1)
    return rgba


def crop_and_resize(rgba: np.ndarray, max_dim: int = 1024, pad_ratio: float = 0.08) -> np.ndarray:
    """Tightly crop non-transparent bbox, add symmetric padding, and resize to <= max_dim."""
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 8)
    if len(xs) == 0 or len(ys) == 0:
        return rgba

    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    cw, ch = x1 - x0, y1 - y0
    pad_x = max(8, int(cw * pad_ratio))
    pad_y = max(8, int(ch * pad_ratio))

    h, w, _ = rgba.shape
    cx0 = max(0, x0 - pad_x)
    cy0 = max(0, y0 - pad_y)
    cx1 = min(w, x1 + pad_x)
    cy1 = min(h, y1 + pad_y)

    cropped = rgba[cy0:cy1, cx0:cx1]
    img = Image.fromarray(cropped, mode="RGBA")
    cur_w, cur_h = img.size
    scale = min(1.0, float(max_dim) / float(max(cur_w, cur_h)))
    if scale < 0.999:
        new_size = (max(16, int(round(cur_w * scale))), max(16, int(round(cur_h * scale))))
        img = img.resize(new_size, Image.Resampling.LANCZOS)
    return np.asarray(img, dtype=np.uint8)


def build_normal_and_masks(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Generate tangent-space normal map and packed RGBA masks (R=metal, G=cyan, B=AO/height)."""
    r = rgba[:, :, 0].astype(np.float32) / 255.0
    g = rgba[:, :, 1].astype(np.float32) / 255.0
    b = rgba[:, :, 2].astype(np.float32) / 255.0
    a = rgba[:, :, 3].astype(np.float32) / 255.0

    luma = 0.299 * r + 0.587 * g + 0.114 * b
    ink_mask = np.clip((0.18 - luma) / 0.14, 0.0, 1.0) * a

    # Gold / warm metallic mask + bright silver-chrome mask (excluding dark indigo disc & black ink)
    warm_gold = np.clip((r - b) * 2.2, 0.0, 1.0) * np.clip((luma - 0.16) * 3.0, 0.0, 1.0)
    bright_chrome = np.clip((luma - 0.52) * 2.8, 0.0, 1.0) * np.clip((b - r * 0.65) * 2.2 + 0.35, 0.0, 1.0)
    metal_mask = np.clip(np.maximum(warm_gold, bright_chrome * 0.85) * (1.0 - ink_mask) * a, 0.0, 1.0)

    # Cyan rim / accent mask
    cyan_dom = np.clip(((b + g) * 0.5 - r) * 3.2, 0.0, 1.0) * np.clip((b - 0.42) * 2.6, 0.0, 1.0)
    accent_mask = np.clip(cyan_dom * (1.0 - ink_mask) * a, 0.0, 1.0)

    # Build multi-scale bevel heightfield from alpha boundary + metallic ridge luminance
    alpha_img = Image.fromarray((a * 255.0).astype(np.uint8), mode="L")
    bevel_wide = np.asarray(alpha_img.filter(ImageFilter.GaussianBlur(radius=9.0)), dtype=np.float32) / 255.0
    bevel_tight = np.asarray(alpha_img.filter(ImageFilter.GaussianBlur(radius=2.5)), dtype=np.float32) / 255.0

    luma_img = Image.fromarray((np.clip(luma * (1.0 - ink_mask * 0.85), 0.0, 1.0) * 255.0).astype(np.uint8), mode="L")
    luma_soft = np.asarray(luma_img.filter(ImageFilter.GaussianBlur(radius=2.2)), dtype=np.float32) / 255.0

    height = (bevel_wide * 0.42 + bevel_tight * 0.25 + luma_soft * 0.48) * a
    # Flatten height slopes slightly inside dark ink lines
    height = height * (1.0 - ink_mask * 0.45)

    # Sobel / central-difference gradients
    gy, gx = np.gradient(height)
    strength = 4.2
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(nx)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    # Flatten normals strictly inside pure ink & transparent regions
    flat_w = np.clip(ink_mask * 0.85 + (1.0 - a), 0.0, 1.0)
    nx = nx * (1.0 - flat_w)
    ny = ny * (1.0 - flat_w)
    nz = nz * (1.0 - flat_w) + flat_w

    normal_rgb = np.stack([
        np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8),
        np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8),
        np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8),
    ], axis=-1)

    ao_height = np.clip(0.35 + height * 0.65, 0.0, 1.0)
    masks_rgba = np.stack([
        np.clip(metal_mask * 255.0, 0, 255).astype(np.uint8),
        np.clip(accent_mask * 255.0, 0, 255).astype(np.uint8),
        np.clip(ao_height * 255.0, 0, 255).astype(np.uint8),
        np.full_like(rgba[:, :, 0], 255, dtype=np.uint8),
    ], axis=-1)
    return normal_rgb, masks_rgba


def main() -> None:
    parser = argparse.ArgumentParser(description="Process Stela Galactica chroma-key logo into albedo, normal & masks PNGs.")
    parser.add_argument("--input", required=True, help="Path to raw chroma-green (#00FF00) logo image.")
    parser.add_argument("--out-dir", default="assets/ui", help="Output directory (default: assets/ui).")
    parser.add_argument("--prefix", default="stela_galactica_logo", help="Output filename prefix.")
    parser.add_argument("--max-dim", type=int, default=1024, help="Maximum width/height in pixels (default: 1024).")
    args = parser.parse_args()

    in_path = Path(args.input)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    raw_img = Image.open(in_path).convert("RGB")
    rgb = np.asarray(raw_img, dtype=np.uint8)

    bg_mask = find_green_bg_mask(rgb)
    rgba = compute_alpha_and_despill(rgb, bg_mask)
    rgba = crop_and_resize(rgba, max_dim=args.max_dim)
    normal_rgb, masks_rgba = build_normal_and_masks(rgba)

    albedo_path = out_dir / f"{args.prefix}_albedo.png"
    normal_path = out_dir / f"{args.prefix}_normal.png"
    masks_path = out_dir / f"{args.prefix}_masks.png"

    Image.fromarray(rgba, mode="RGBA").save(albedo_path)
    Image.fromarray(normal_rgb, mode="RGB").save(normal_path)
    Image.fromarray(masks_rgba, mode="RGBA").save(masks_path)

    print(f"[process_stela_logo] Saved {albedo_path} ({rgba.shape[1]}x{rgba.shape[0]})")
    print(f"[process_stela_logo] Saved {normal_path}")
    print(f"[process_stela_logo] Saved {masks_path}")


if __name__ == "__main__":
    main()
