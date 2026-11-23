#!/usr/bin/env python3
"""Offline compiler for top-down 1:1 orbital ring AI textures (Guns Lab — Valentina v2).

Packs a black-background top-down circular ring into 4 shader-ready RGBA channels:
  - R: Silver/structural ring luminance (0..255)
  - G: Crimson/energy accent intensity (0..255)
  - B: Radial zone mask (255 = outer ring, 0 = inner counter-rotating ring)
  - A: Clean background-knockout alpha max(R, G)

Also exports `<name>_meta.json` with calibrated split radius and main rail radius.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
PILOT_RIG_LAB_DIR = TOOLS_DIR.parent
DEFAULT_SRC = PILOT_RIG_LAB_DIR / "source_refs" / "valentina_v2_weapons" / "reticula_tactica_mecha_master.jpg"
DEFAULT_OUT_DIR = PILOT_RIG_LAB_DIR / "combat_assets" / "valentina_v2_planar" / "weapons"

DEFAULT_SIZE_PX: int = 1024
OUTER_UV_RADIUS: float = 0.445  # Leaves ~5.5% margin on all sides so rotation never clips


def _find_radial_split(gray: np.ndarray, cx: float, cy: float, rmax: float) -> float:
    h, w = gray.shape
    yy, xx = np.mgrid[0:h, 0:w]
    rr = np.hypot(xx - cx, yy - cy) / max(rmax, 1.0)

    best_r: float = 0.712
    best_score: float = 1e9
    for r_cand in np.linspace(0.64, 0.80, 65):
        band = (rr >= r_cand - 0.012) & (rr <= r_cand + 0.012)
        if not np.any(band):
            continue
        occ = float((gray[band] > 26).mean())
        if occ < best_score:
            best_score = occ
            best_r = float(r_cand)
    return best_r


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile 1:1 orbital ring AI texture into RGBA packed channels.")
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--name", type=str, default="valentina_mecha_ring")
    parser.add_argument("--size", type=int, default=DEFAULT_SIZE_PX)
    parser.add_argument("--split-r", type=float, default=-1.0, help="Normalized split radius inside bounding circle (0..1).")
    args = parser.parse_args()

    raw = cv2.imread(str(args.src), cv2.IMREAD_COLOR)
    if raw is None:
        raise RuntimeError(f"Could not read source ring image: {args.src}")

    h, w = raw.shape[:2]
    max_ch = raw.max(axis=2)
    ys, xs = np.where(max_ch > 32)
    if len(xs) == 0:
        raise RuntimeError("No foreground ring pixels detected on black background.")

    cx = 0.5 * float(xs.min() + xs.max())
    cy = 0.5 * float(ys.min() + ys.max())
    rmax = float(max(xs.max() - cx, cx - xs.min(), ys.max() - cy, cy - ys.min()))

    split_norm = args.split_r if args.split_r > 0.0 else _find_radial_split(max_ch, cx, cy, rmax)

    # Re-center and fit ring to exact OUTER_UV_RADIUS inside size x size square canvas
    out_sz = max(256, int(args.size))
    target_r_px = OUTER_UV_RADIUS * float(out_sz)
    scale = target_r_px / max(rmax, 1.0)
    out_cx = 0.5 * float(out_sz - 1)
    out_cy = 0.5 * float(out_sz - 1)
    mat = np.array(
        [
            [scale, 0.0, out_cx - cx * scale],
            [0.0, scale, out_cy - cy * scale],
        ],
        dtype=np.float32,
    )
    warped = cv2.warpAffine(raw, mat, (out_sz, out_sz), flags=cv2.INTER_CUBIC, borderValue=(0, 0, 0))

    b_f = warped[:, :, 0].astype(np.float32)
    g_f = warped[:, :, 1].astype(np.float32)
    r_f = warped[:, :, 2].astype(np.float32)

    val_max = np.maximum(r_f, np.maximum(g_f, b_f))
    # Suppress dark JPEG background compression artifacts cleanly
    noise_gate = np.clip((val_max - 14.0) / 18.0, 0.0, 1.0)

    # Smooth separation between crimson energy and white-silver structure
    red_dom = r_f - np.maximum(g_f, b_f)
    energy_w = np.clip((red_dom - 10.0) / 36.0, 0.0, 1.0)

    energy_ch = np.clip(r_f * energy_w * noise_gate, 0.0, 255.0)
    struct_luma = np.maximum(0.299 * r_f + 0.587 * g_f + 0.114 * b_f, val_max * 0.92)
    struct_ch = np.clip(struct_luma * (1.0 - energy_w) * noise_gate, 0.0, 255.0)

    # Radial zone mask (B = 255 outer armored ring, B = 0 inner counter-rotating micro-ticks)
    yy, xx = np.mgrid[0:out_sz, 0:out_sz]
    rr_uv = np.hypot(xx - out_cx, yy - out_cy) / float(out_sz)
    split_uv = split_norm * OUTER_UV_RADIUS
    zone_ch = np.where(rr_uv >= split_uv, 255.0, 0.0).astype(np.float32)

    alpha_ch = np.clip(np.maximum(struct_ch, energy_ch), 0.0, 255.0)

    # OpenCV writes BGRA -> B=zone, G=energy, R=structure, A=alpha
    packed = np.stack(
        [
            np.round(zone_ch).astype(np.uint8),
            np.round(energy_ch).astype(np.uint8),
            np.round(struct_ch).astype(np.uint8),
            np.round(alpha_ch).astype(np.uint8),
        ],
        axis=2,
    )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_png = args.out_dir / f"{args.name}_packed.png"
    cv2.imwrite(str(out_png), packed)

    meta = {
        "schema_version": 1,
        "name": args.name,
        "source": str(args.src.relative_to(PILOT_RIG_LAB_DIR)).replace("\\", "/")
        if args.src.is_relative_to(PILOT_RIG_LAB_DIR)
        else str(args.src),
        "size_px": [out_sz, out_sz],
        "outer_uv_radius": round(OUTER_UV_RADIUS, 4),
        "split_uv_radius": round(float(split_uv), 4),
        "main_rail_uv_radius": round(float(0.86 * OUTER_UV_RADIUS), 4),
    }
    meta_path = args.out_dir / f"{args.name}_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"[DONE] Compiled {out_png.name} ({out_sz}x{out_sz}, split_uv={meta['split_uv_radius']}, main_uv={meta['main_rail_uv_radius']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
