#!/usr/bin/env python3
"""Extract smooth L/R secondary motion masks (bust for S, glutes for N)
from the side-by-side semantic sheet and align them pixel-perfectly to parts_5/body_core.png.
Output RGBA: R = left lobe weight, G = right lobe weight, B = 0, A = 255.
"""

import json
from pathlib import Path
import cv2
import numpy as np

from process_masked_5parts import TEX_SCALE, _align_mask_to_ref, _place_on_canvas


def _extract_half_masks(half_bgr: np.ndarray, target_color_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (silhouette_fg, zone_mask) booleans from one half of the sheet."""
    b, g, r = half_bgr[:, :, 0].astype(np.int16), half_bgr[:, :, 1].astype(np.int16), half_bgr[:, :, 2].astype(np.int16)
    luma = (r + g + b) / 3.0
    sil_fg = luma > 16.0

    # Color distance to pure cyan (255,255,0 BGR) or magenta (255,0,255 BGR)
    diff = np.linalg.norm(half_bgr.astype(np.float32) - target_color_bgr[None, None, :], axis=2)
    zone = sil_fg & (diff < 155.0) & (np.maximum(np.maximum(r, g), b) > 120)
    return sil_fg, zone


def process_secondary_view(view: str, half_bgr: np.ndarray, target_color_bgr: np.ndarray, audit_dir: Path) -> None:
    vdir = Path(f"sandbox/pilot_rig_lab/combat_assets/valentina_planar/{view}")
    parts_dir = vdir / "parts_5"
    meta = json.loads((parts_dir / "parts_5_meta.json").read_text(encoding="utf-8"))

    ref_1x_raw = cv2.imread(str(vdir / "body_unified.png"), cv2.IMREAD_UNCHANGED)
    W1, H1 = 520, 560
    W, H = W1 * TEX_SCALE, H1 * TEX_SCALE
    bones_by_name = {b["name"]: b["pos"] for b in meta["bones"]}
    neck_x, neck_y = bones_by_name["Neck"][0], bones_by_name["Neck"][1]
    rh1, rw1 = ref_1x_raw.shape[:2]
    ref_scale_1x = 430.0 / float(rh1)
    rw_1x, rh_1x = int(round(rw1 * ref_scale_1x)), int(round(rh1 * ref_scale_1x))
    ox_1x = int(round(neck_x - rw_1x * 0.50))
    oy_1x = int(round(neck_y - rh_1x * 0.04))
    ref_1x_canvas = _place_on_canvas(ref_1x_raw, rw_1x, rh_1x, ox_1x, oy_1x, W1, H1, cv2.INTER_AREA)
    ref_alpha_1x = ref_1x_canvas[:, :, 3] > 28

    sil_fg, zone_raw = _extract_half_masks(half_bgr, target_color_bgr)
    ox, oy, scale = _align_mask_to_ref(sil_fg, ref_alpha_1x)
    print(f"[{view}] aligned secondary sheet: ox={ox}, oy={oy}, scale={scale:.4f}")

    ys_s, xs_s = np.where(sil_fg)
    my0, my1 = int(ys_s.min()), int(ys_s.max()) + 1
    mx0, mx1 = int(xs_s.min()), int(xs_s.max()) + 1
    zone_crop = np.repeat((zone_raw[my0:my1, mx0:mx1].astype(np.uint8) * 255)[:, :, None], 3, axis=2)
    rw_ref = max(1, int(round((mx1 - mx0) * scale * TEX_SCALE)))
    rh_ref = max(1, int(round((my1 - my0) * scale * TEX_SCALE)))
    zone_canvas = _place_on_canvas(
        zone_crop,
        rw_ref,
        rh_ref,
        ox * TEX_SCALE,
        oy * TEX_SCALE,
        W,
        H,
        cv2.INTER_NEAREST,
    )[:, :, 0].astype(np.float32) / 255.0

    # Crop to exact body_core rect
    rx, ry, rw, rh = meta["rects"]["body_core"]
    x0, y0 = int(round(rx * TEX_SCALE)), int(round(ry * TEX_SCALE))
    bw, bh = int(round(rw * TEX_SCALE)), int(round(rh * TEX_SCALE))
    core_img = cv2.imread(str(parts_dir / "body_core.png"), cv2.IMREAD_UNCHANGED)
    ch, cw = core_img.shape[:2]

    crop_zone = zone_canvas[y0:y0 + ch, x0:x0 + cw]
    core_alpha = (core_img[:, :, 3].astype(np.float32) / 255.0)

    # Smooth Gaussian feathering so UV displacement never creates hard seams,
    # then clamp inside body_core silhouette (eroded slightly from outer outline)
    inner_alpha = cv2.erode((core_alpha > 0.5).astype(np.uint8) * 255, np.ones((7, 7), np.uint8), iterations=1).astype(np.float32) / 255.0
    inner_alpha = cv2.GaussianBlur(inner_alpha, (9, 9), 2.5)
    soft_zone = cv2.GaussianBlur(crop_zone, (21, 21), 6.0) * inner_alpha

    # Split Left vs Right smoothly around zone horizontal centroid
    ys, xs = np.where(crop_zone > 0.5)
    cx = float(xs.mean()) if len(xs) > 0 else cw * 0.5
    xx = np.arange(cw, dtype=np.float32)[None, :]
    w_right = np.clip((xx - (cx - 10.0)) / 20.0, 0.0, 1.0)
    w_left = 1.0 - w_right

    left_mask = np.clip(soft_zone * w_left * 1.15, 0.0, 1.0)
    right_mask = np.clip(soft_zone * w_right * 1.15, 0.0, 1.0)

    out_rgba = np.zeros((ch, cw, 4), dtype=np.uint8)
    out_rgba[:, :, 2] = (left_mask * 255.0).astype(np.uint8)   # R channel in RGB -> Left
    out_rgba[:, :, 1] = (right_mask * 255.0).astype(np.uint8)  # G channel in RGB -> Right
    out_rgba[:, :, 3] = 255

    out_path = parts_dir / "body_core_secondary_mask.png"
    cv2.imwrite(str(out_path), out_rgba)

    # Save visual audit overlay on body_core
    vis = core_img[:, :, :3].copy().astype(np.float32)
    vis[:, :, 2] = np.clip(vis[:, :, 2] + left_mask * 140.0, 0, 255)
    vis[:, :, 1] = np.clip(vis[:, :, 1] + right_mask * 140.0, 0, 255)
    bg = np.full_like(vis, 30.0)
    a3 = core_alpha[:, :, None]
    comp = np.clip(vis * a3 + bg * (1.0 - a3), 0, 255).astype(np.uint8)
    audit_dir.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(audit_dir / f"audit_secondary_mask_{view}.png"), comp)
    print(f"[{view}] saved {out_path} ({cw}x{ch}), max L={left_mask.max():.2f} R={right_mask.max():.2f}")


def main() -> None:
    sheet_path = Path("sandbox/pilot_rig_lab/source_refs/valentina_secondary_mask.jpg")
    sheet = cv2.imread(str(sheet_path), cv2.IMREAD_COLOR)
    if sheet is None:
        raise FileNotFoundError(f"Missing {sheet_path}")
    h, w = sheet.shape[:2]
    mid = w // 2
    audit_dir = Path("C:/Users/Frani/.gemini/antigravity/brain/7a3a228c-eb42-4859-8dfd-b49e7048ca8f/scratch")

    # Left = S (Cyan BGR: 255, 255, 0), Right = N (Magenta BGR: 255, 0, 255)
    process_secondary_view("s", sheet[:, :mid], np.array([255, 255, 0], dtype=np.float32), audit_dir)
    process_secondary_view("n", sheet[:, mid:], np.array([255, 0, 255], dtype=np.float32), audit_dir)


if __name__ == "__main__":
    main()
