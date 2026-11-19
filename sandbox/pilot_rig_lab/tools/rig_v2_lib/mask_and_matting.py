"""Depth darkening and secondary bust mask helpers for Valentina v2."""

from __future__ import annotations

import cv2
import numpy as np

from process_masked_5parts import TEX_SCALE

from .constants import PX_H, PX_W


def _apply_rear_depth_darkening(bgra: np.ndarray, factor: float) -> np.ndarray:
    """Apply subtle 2.5D depth darkening (e.g. 0.85) on rear limbs in profile E/W while preserving alpha."""
    if factor >= 0.999:
        return bgra
    out = bgra.copy()
    fg = out[:, :, 3] > 0
    if np.any(fg):
        bgr_f = out[fg, :3].astype(np.float32) * float(factor)
        out[fg, :3] = np.clip(np.round(bgr_f), 0, 255).astype(np.uint8)
    return out


def _synthesize_ew_bust_secondary_mask(
    view: str,
    body_core_mask: np.ndarray,
    bones_by_name: dict[str, list[float]],
) -> np.ndarray:
    """Synthesize clean lateral bust secondary jiggle mask for profile E/W views on 1560x1680 canvas."""
    mask_bgra = np.zeros((PX_H, PX_W, 4), dtype=np.uint8)
    mask_bgra[:, :, 3] = 255
    if view not in ("e", "w") or not np.any(body_core_mask):
        return mask_bgra

    chest_x, chest_y = bones_by_name["Chest"]
    cx_px = float(chest_x) * float(TEX_SCALE)
    cy_px = float(chest_y) * float(TEX_SCALE)
    front_sign = 1.0 if view == "e" else -1.0

    # Find exact peak bust silhouette protrusion in the chest band
    y_lo = max(0, int(round(cy_px - 18.0 * TEX_SCALE)))
    y_hi = min(PX_H, int(round(cy_px + 28.0 * TEX_SCALE)))
    bust_x = cx_px + front_sign * 20.0 * TEX_SCALE
    bust_y = cy_px + 8.0 * TEX_SCALE
    best_reach = -1.0
    for y in range(y_lo, y_hi):
        xs = np.where(body_core_mask[y])[0]
        if len(xs) < 10:
            continue
        front_edge = float(xs.max()) if front_sign > 0.0 else float(xs.min())
        reach = (front_edge - cx_px) * front_sign
        if reach > best_reach:
            best_reach = reach
            bust_y = float(y)
            bust_x = front_edge - front_sign * (14.0 * TEX_SCALE)

    # Keep outer contour ink completely stationary (dist_to_edge > 6 px)
    dist_in = cv2.distanceTransform(body_core_mask.astype(np.uint8), cv2.DIST_L2, 5)
    interior_guard = np.clip((dist_in - 5.0) / 8.0, 0.0, 1.0)

    yy, xx = np.mgrid[:PX_H, :PX_W].astype(np.float32)
    rx = 19.0 * float(TEX_SCALE)
    ry = 18.0 * float(TEX_SCALE)
    d2 = ((xx - bust_x) / rx) ** 2 + ((yy - bust_y) / ry) ** 2
    dome = np.exp(-d2 * 1.45) * interior_guard * (dist_in > 2.0).astype(np.float32)
    u8 = np.clip(np.round(dome * 255.0), 0, 255).astype(np.uint8)
    # Godot shader reads .r (L) and .g (R) from BGRA PNG indices 2 and 1
    mask_bgra[:, :, 2] = u8
    mask_bgra[:, :, 1] = u8
    return mask_bgra
