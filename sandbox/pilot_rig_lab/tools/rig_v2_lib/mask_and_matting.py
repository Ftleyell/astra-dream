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
    origin_px: tuple[float, float] = (0.0, 0.0),
) -> np.ndarray:
    """Synthesize dual E/W secondary mask: R = frontal bust dome, G = rear glute dome."""
    h_img, w_img = body_core_mask.shape[:2]
    mask_bgra = np.zeros((h_img, w_img, 4), dtype=np.uint8)
    mask_bgra[:, :, 3] = 255
    if view not in ("e", "w") or not np.any(body_core_mask):
        return mask_bgra

    ox_px, oy_px = float(origin_px[0]), float(origin_px[1])
    chest_x, chest_y = bones_by_name["Chest"]
    cx_px = float(chest_x) * float(TEX_SCALE) - ox_px
    cy_px = float(chest_y) * float(TEX_SCALE) - oy_px
    pelvis_x, pelvis_y = bones_by_name.get("Pelvis", [chest_x, chest_y + 74.0])
    px_px = float(pelvis_x) * float(TEX_SCALE) - ox_px
    py_px = float(pelvis_y) * float(TEX_SCALE) - oy_px

    front_sign = 1.0 if view == "e" else -1.0
    rear_sign = -front_sign

    # Anatomical + pad guards so outer contour ink and ~12-14 px transparent margin move smoothly
    # while keeping spine, abdomen, neck/shoulders, and hip/crotch anchored at 0.0.
    dist_out = cv2.distanceTransform((~body_core_mask).astype(np.uint8), cv2.DIST_L2, 5)
    pad_guard = np.clip((14.0 - dist_out) / 4.5, 0.0, 1.0)
    yy, xx = np.mgrid[:h_img, :w_img].astype(np.float32)

    neck_guard = np.clip((yy - (cy_px - 19.0 * float(TEX_SCALE))) / (7.0 * float(TEX_SCALE)), 0.0, 1.0)
    front_side_guard = np.clip(((xx - (cx_px - 2.0 * front_sign * float(TEX_SCALE))) * front_sign) / (12.0 * float(TEX_SCALE)), 0.0, 1.0)
    rear_side_guard = np.clip(((xx - (px_px - 2.0 * rear_sign * float(TEX_SCALE))) * rear_sign) / (11.0 * float(TEX_SCALE)), 0.0, 1.0)
    crotch_guard = np.clip(((py_px + 14.0 * float(TEX_SCALE)) - yy) / (10.0 * float(TEX_SCALE)), 0.0, 1.0)

    # 1. Frontal bust dome (Channel R -> BGRA index 2)
    y_b_lo = max(0, int(round(cy_px - 18.0 * TEX_SCALE)))
    y_b_hi = min(h_img, int(round(cy_px + 28.0 * TEX_SCALE)))
    bust_x = cx_px + front_sign * 20.0 * TEX_SCALE
    bust_y = cy_px + 8.0 * TEX_SCALE
    best_bust_reach = -1.0
    for y in range(y_b_lo, y_b_hi):
        xs = np.where(body_core_mask[y])[0]
        if len(xs) < 10:
            continue
        front_edge = float(xs.max()) if front_sign > 0.0 else float(xs.min())
        reach = (front_edge - cx_px) * front_sign
        if reach > best_bust_reach:
            best_bust_reach = reach
            bust_y = float(y)
            bust_x = front_edge - front_sign * (9.5 * TEX_SCALE)

    d2_bust = ((xx - bust_x) / (22.0 * float(TEX_SCALE))) ** 2 + ((yy - bust_y) / (19.5 * float(TEX_SCALE))) ** 2
    dome_bust = np.exp(-d2_bust * 1.10) * pad_guard * neck_guard * front_side_guard
    u8_bust = np.clip(np.round(dome_bust * 255.0), 0, 255).astype(np.uint8)

    # 2. Rear glute dome (Channel G -> BGRA index 1)
    y_g_lo = max(0, int(round(py_px - 10.0 * TEX_SCALE)))
    y_g_hi = min(h_img, int(round(py_px + 22.0 * TEX_SCALE)))
    glute_x = px_px + rear_sign * 14.0 * TEX_SCALE
    glute_y = py_px + 10.0 * TEX_SCALE
    best_glute_reach = -1.0
    for y in range(y_g_lo, y_g_hi):
        xs = np.where(body_core_mask[y])[0]
        if len(xs) < 10:
            continue
        rear_edge = float(xs.min()) if rear_sign < 0.0 else float(xs.max())
        reach = (rear_edge - px_px) * rear_sign
        if reach > best_glute_reach:
            best_glute_reach = reach
            glute_y = float(y) - 4.0 * float(TEX_SCALE)
            glute_x = rear_edge - rear_sign * (10.5 * TEX_SCALE)

    d2_glute = ((xx - glute_x) / (18.5 * float(TEX_SCALE))) ** 2 + ((yy - glute_y) / (17.5 * float(TEX_SCALE))) ** 2
    dome_glute = np.exp(-d2_glute * 1.10) * pad_guard * rear_side_guard * crotch_guard
    u8_glute = np.clip(np.round(dome_glute * 255.0), 0, 255).astype(np.uint8)

    # Godot shader reads .r (bust/L) and .g (glute/R) from BGRA PNG indices 2 and 1
    mask_bgra[:, :, 2] = u8_bust
    mask_bgra[:, :, 1] = u8_glute
    return mask_bgra


def _expand_secondary_mask_over_ink_and_margin(
    sec_crop: np.ndarray,
    part_rgba: np.ndarray,
    view: str,
    bones_local_px: dict[str, tuple[float, float]] | None = None,
) -> np.ndarray:
    """Expand secondary R/G lobes across contour ink and transparent margin while protecting anchors and canvas edges."""
    ph, pw = part_rgba.shape[:2]
    out = np.zeros((ph, pw, 4), dtype=np.uint8)
    out[:, :, 3] = 255
    bc_fg = part_rgba[:, :, 3] >= 64
    if not np.any(bc_fg):
        return out

    dist_out = cv2.distanceTransform((~bc_fg).astype(np.uint8), cv2.DIST_L2, 5)
    pad_guard = np.clip((14.0 - dist_out) / 4.5, 0.0, 1.0)
    yy, xx = np.mgrid[:ph, :pw].astype(np.float32)

    # Strict 4px zero rim at crop borders to avoid clamp smear when UV approaches 0 or 1
    b_top = np.clip((yy - 3.5) / 4.0, 0.0, 1.0)
    b_bot = np.clip(((float(ph) - 4.5) - yy) / 4.0, 0.0, 1.0)
    b_left = np.clip((xx - 3.5) / 4.0, 0.0, 1.0)
    b_right = np.clip(((float(pw) - 4.5) - xx) / 4.0, 0.0, 1.0)
    border_guard = b_top * b_bot * b_left * b_right

    anchor_guard = np.ones((ph, pw), dtype=np.float32)
    if bones_local_px and "Neck" in bones_local_px and "Chest" in bones_local_px and view in ("s", "se", "sw", "e", "w"):
        ny = float(bones_local_px["Neck"][1])
        cy = float(bones_local_px["Chest"][1])
        y_cut = ny + 0.48 * (cy - ny)
        anchor_guard *= np.clip((yy - y_cut) / 18.0, 0.0, 1.0)

    k_dil = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (23, 23))
    total_guard = pad_guard * border_guard * anchor_guard
    for ch in (2, 1):
        m_in = sec_crop[:, :, ch].astype(np.float32) / 255.0
        if float(m_in.max()) < 0.05:
            continue
        dil = cv2.dilate(m_in, k_dil)
        smoothed = cv2.GaussianBlur(dil, (0, 0), sigmaX=3.8, sigmaY=3.8)
        m_out = np.clip(np.maximum(m_in, smoothed) * total_guard, 0.0, 1.0)
        out[:, :, ch] = np.clip(np.round(m_out * 255.0), 0, 255).astype(np.uint8)
    return out
