#!/usr/bin/env python3
"""Slice an 8-direction 4x2 head sheet + its 4x2 semantic mask sheet,
upscale via Upscayl digital-art-4x, align masks per cell via IoU,
generate crisp RGBA, id_mask, normal_depth, and heads_metadata.json.
"""

import json
from pathlib import Path
import cv2
import numpy as np

from process_masked_5parts import upscale_with_upscayl, _align_mask_to_ref, _place_on_canvas

CELL_KEYS = [
    ["head_front", "head_front_r", "head_front_l", "head_side_l"],
    ["head_side_r", "head_back_r", "head_back_l", "head_back"],
]

TARGET_DISP_H = 88.9
TEX_SCALE = 3


def _remove_white_bg_floodfill(bgr: np.ndarray, white_thr: int = 212) -> np.ndarray:
    h, w = bgr.shape[:2]
    cmin = np.min(bgr, axis=2)
    cmax = np.max(bgr, axis=2)
    is_bright = ((cmin >= white_thr) & ((cmax - cmin) <= 24)).astype(np.uint8)
    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    seed_img = is_bright.copy() * 255
    for x in range(w):
        if seed_img[0, x] == 255:
            cv2.floodFill(seed_img, ff_mask, (x, 0), 128)
        if seed_img[h - 1, x] == 255:
            cv2.floodFill(seed_img, ff_mask, (x, h - 1), 128)
    for y in range(h):
        if seed_img[y, 0] == 255:
            cv2.floodFill(seed_img, ff_mask, (0, y), 128)
        if seed_img[y, w - 1] == 255:
            cv2.floodFill(seed_img, ff_mask, (w - 1, y), 128)

    fg_raw = (seed_img != 128).astype(np.uint8) * 255
    k_erode = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    fg_clean = cv2.erode(fg_raw, k_erode, iterations=1) > 0
    fg_inner = cv2.erode(fg_clean.astype(np.uint8) * 255, k_erode, iterations=1) > 0

    alpha_f = cv2.GaussianBlur(fg_clean.astype(np.float32) * 255.0, (5, 5), 1.0)
    alpha_f = np.where(fg_clean, alpha_f, 0.0)
    alpha_f = np.where(fg_inner, 255.0, alpha_f)
    alpha_f = np.where(alpha_f < 18.0, 0.0, alpha_f)

    # Decontaminate edge RGB & bleed 2px into transparent margin to prevent bilinear white/black halos
    clean_bgr = np.zeros_like(bgr)
    if np.any(fg_inner):
        clean_bgr[fg_inner] = bgr[fg_inner]
        k_bleed = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        fg_margin = cv2.dilate(fg_clean.astype(np.uint8) * 255, k_bleed, iterations=1) > 0
        bleed_zone = fg_margin & (~fg_inner)
        if np.any(bleed_zone):
            _, labels = cv2.distanceTransformWithLabels(
                (~fg_inner).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            iy, ix = np.where(fg_inner)
            zy, zx = np.where(bleed_zone)
            clean_bgr[zy, zx] = bgr[iy[labels[zy, zx] - 1], ix[labels[zy, zx] - 1]]

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = clean_bgr
    rgba[:, :, 3] = np.clip(alpha_f, 0, 255).astype(np.uint8)
    return rgba


def _classify_head_mask_cell(mask_bgr: np.ndarray, target_size: tuple[int, int], ref_alpha: np.ndarray) -> np.ndarray:
    """Align mask_bgr to ref_alpha (W, H) via IoU and convert to shader id_mask RGBA:
    Cyan (#00FFFF) -> A (Hair), Blue (#0000FF) -> B (Collar/Suit), Red (#FF0000) -> R (Monocle), Green -> 0 (Skin).
    """
    tw, th = target_size
    b = mask_bgr[:, :, 0].astype(np.float32)
    g = mask_bgr[:, :, 1].astype(np.float32)
    r = mask_bgr[:, :, 2].astype(np.float32)
    sil_fg = np.maximum(np.maximum(r, g), b) > 48.0

    ys, xs = np.where(sil_fg)
    my0, my1 = int(ys.min()), int(ys.max()) + 1
    mx0, mx1 = int(xs.min()), int(xs.max()) + 1
    crop_bgr = mask_bgr[my0:my1, mx0:mx1]
    rys, rxs = np.where(ref_alpha > 24)
    rw_box = max(1, int(rxs.max()) - int(rxs.min()) + 1)
    rh_box = max(1, int(rys.max()) - int(rys.min()) + 1)
    # Match exact ref bbox aspect ratio first so 16:9 vs 2:1 mask sheets align chin-to-crown
    crop_bgr = cv2.resize(crop_bgr, (rw_box, rh_box), interpolation=cv2.INTER_NEAREST)
    crop_fg = np.max(crop_bgr.astype(np.float32), axis=2) > 48.0
    ox, oy, scale = _align_mask_to_ref(crop_fg, ref_alpha > 24)
    rw_ref = max(1, int(round(rw_box * scale)))
    rh_ref = max(1, int(round(rh_box * scale)))
    aligned_bgr = _place_on_canvas(crop_bgr, rw_ref, rh_ref, ox, oy, tw, th, cv2.INTER_NEAREST)

    ab = aligned_bgr[:, :, 0].astype(np.float32)
    ag = aligned_bgr[:, :, 1].astype(np.float32)
    ar = aligned_bgr[:, :, 2].astype(np.float32)
    is_col = (np.maximum(np.maximum(ar, ag), ab) > 48.0)

    # Nearest-neighbor fill dark interior outlines (eyebrows/hair lines) inside ref_alpha
    if np.any(is_col):
        _, nearest_idx = cv2.distanceTransformWithLabels((~is_col).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
        # Map flat coordinates of valid pixels
        valid_ys, valid_xs = np.where(is_col)
        # distanceTransformWithLabels labels start at 1; use simple dilation fallback for speed & exactness
        filled = aligned_bgr.copy()
        kernel = np.ones((5, 5), np.uint8)
        for _ in range(4):
            dark = np.maximum(np.maximum(filled[:, :, 0], filled[:, :, 1]), filled[:, :, 2]) <= 48
            if not np.any(dark & (ref_alpha > 24)):
                break
            dil = cv2.dilate(filled, kernel, iterations=1)
            filled[dark] = dil[dark]
        aligned_bgr = filled

    fb = aligned_bgr[:, :, 0].astype(np.float32)
    fg = aligned_bgr[:, :, 1].astype(np.float32)
    fr = aligned_bgr[:, :, 2].astype(np.float32)

    # Nearest semantic class in RGB
    classes = np.stack([
        np.linalg.norm(np.stack([fr, fg, fb], axis=-1) - np.array([0, 255, 255]), axis=-1),  # 0: Cyan = Hair (A)
        np.linalg.norm(np.stack([fr, fg, fb], axis=-1) - np.array([0, 0, 255]), axis=-1),    # 1: Blue = Collar (B)
        np.linalg.norm(np.stack([fr, fg, fb], axis=-1) - np.array([255, 0, 0]), axis=-1),    # 2: Red = Monocle (R)
        np.linalg.norm(np.stack([fr, fg, fb], axis=-1) - np.array([0, 255, 0]), axis=-1),    # 3: Green = Skin (0)
    ], axis=-1)
    cls_idx = np.argmin(classes, axis=-1)
    fg_valid = ref_alpha > 20

    # OpenCV BGRA -> RGBA in PNG: [B, G, R, A]
    id_bgra = np.zeros((th, tw, 4), dtype=np.uint8)
    id_bgra[:, :, 3] = np.where(fg_valid & (cls_idx == 0), 255, 0).astype(np.uint8)  # A = Hair
    id_bgra[:, :, 0] = np.where(fg_valid & (cls_idx == 1), 255, 0).astype(np.uint8)  # B = Collar
    id_bgra[:, :, 2] = np.where(fg_valid & (cls_idx == 2), 255, 0).astype(np.uint8)  # R = Monocle
    return id_bgra


def _build_clean_head_normal_depth(alpha_u8: np.ndarray) -> np.ndarray:
    """Smooth spherical cranium normal + clean edge-free depth (no blotchy luma spikes)."""
    h, w = alpha_u8.shape
    a = (alpha_u8 > 20).astype(np.float32)
    dist = cv2.distanceTransform((alpha_u8 > 20).astype(np.uint8), cv2.DIST_L2, 5)
    dist_norm = np.clip(dist / max(1.0, float(dist.max())), 0.0, 1.0)
    depth = cv2.GaussianBlur(0.30 + 0.65 * np.sqrt(dist_norm), (15, 15), 4.0) * a

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = np.clip((xx - w * 0.5) / (w * 0.45), -0.85, 0.85)
    ny = np.clip((yy - h * 0.45) / (h * 0.45), -0.85, 0.85)
    nz = np.sqrt(np.clip(1.0 - nx * nx * 0.45 - ny * ny * 0.45, 0.25, 1.0))

    nd_bgra = np.zeros((h, w, 4), dtype=np.uint8)
    nd_bgra[:, :, 2] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)  # R = nx
    nd_bgra[:, :, 1] = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)  # G = ny
    nd_bgra[:, :, 0] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)  # B = nz
    nd_bgra[:, :, 3] = np.clip(depth * 255.0, 0, 255).astype(np.uint8)             # A = depth
    return nd_bgra


def _build_hair_jiggle_mask(final_rgba: np.ndarray, id_bgra: np.ndarray) -> np.ndarray:
    """Smooth 0..1 hair jiggle mask (R channel) covering hair + outer dark ink + transparent margin,
    pinned to 0 at scalp/crown and smoothly zeroed before face/eyes/monocle.
    """
    h, w = final_rgba.shape[:2]
    hair = id_bgra[:, :, 3] > 128
    alpha_fg = final_rgba[:, :, 3] > 20
    luma = (
        final_rgba[:, :, 2].astype(np.float32) * 0.299
        + final_rgba[:, :, 1].astype(np.float32) * 0.587
        + final_rgba[:, :, 0].astype(np.float32) * 0.114
    )
    k_dil = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    dil_hair = cv2.dilate(hair.astype(np.uint8) * 255, k_dil) > 0
    non_hair_fg = alpha_fg & (~hair)
    # Include hair + dark ink outline touching hair + transparent margin outside hair; exclude skin/eyes/collar
    is_non_hair_skin = non_hair_fg & (luma >= 75.0)
    raw = (dil_hair & (~is_non_hair_skin)).astype(np.float32)
    smooth = cv2.GaussianBlur(raw, (11, 11), 3.2)

    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    t = np.clip((ys - 0.16) / (0.54 - 0.16), 0.0, 1.0)
    pin = t * t * (3.0 - 2.0 * t)
    # Zero out non-hair face/eyes/monocle/neck AFTER blur so the face never deforms
    mask_f = np.where(non_hair_fg, 0.0, np.clip(smooth * pin, 0.0, 1.0))

    bgr = np.zeros((h, w, 3), dtype=np.uint8)
    bgr[:, :, 2] = np.clip(mask_f * 255.0, 0, 255).astype(np.uint8)  # R channel
    return bgr


def process_all(sheet_path: Path, mask_path: Path, out_heads_dir: Path, audit_dir: Path, upscayl_cache: Path) -> None:
    upscaled = upscale_with_upscayl(sheet_path, upscayl_cache / "heads_8dir_4x.png")
    img = cv2.imread(str(upscaled), cv2.IMREAD_COLOR)
    mask_img = cv2.imread(str(mask_path), cv2.IMREAD_COLOR)
    if img is None or mask_img is None:
        raise FileNotFoundError("Missing head sheet or mask sheet")

    H, W = img.shape[:2]
    MH, MW = mask_img.shape[:2]
    cw, ch = W // 4, H // 2
    mcw, mch = MW // 4, MH // 2

    out_heads_dir.mkdir(parents=True, exist_ok=True)
    meta = {}
    audit_tiles = []

    for r in range(2):
        for c in range(4):
            key = CELL_KEYS[r][c]
            y0, y1 = r * ch, (r + 1) * ch if r == 0 else H
            x0, x1 = c * cw, (c + 1) * cw if c < 3 else W
            rgba = _remove_white_bg_floodfill(img[y0:y1, x0:x1])

            ys, xs = np.where(rgba[:, :, 3] > 24)
            by0, by1 = max(0, int(ys.min()) - 4), min(rgba.shape[0], int(ys.max()) + 5)
            bx0, bx1 = max(0, int(xs.min()) - 4), min(rgba.shape[1], int(xs.max()) + 5)
            crop = rgba[by0:by1, bx0:bx1]

            target_h_px = int(round(TARGET_DISP_H * TEX_SCALE))
            scale = float(target_h_px) / float(crop.shape[0])
            target_w_px = max(1, int(round(crop.shape[1] * scale)))
            final_rgba = cv2.resize(crop, (target_w_px, target_h_px), interpolation=cv2.INTER_AREA)

            my0, my1 = r * mch, (r + 1) * mch if r == 0 else MH
            mx0, mx1 = c * mcw, (c + 1) * mcw if c < 3 else MW
            id_bgra = _classify_head_mask_cell(mask_img[my0:my1, mx0:mx1], (target_w_px, target_h_px), final_rgba[:, :, 3])
            nd_bgra = _build_clean_head_normal_depth(final_rgba[:, :, 3])
            jiggle_bgr = _build_hair_jiggle_mask(final_rgba, id_bgra)

            cv2.imwrite(str(out_heads_dir / f"{key}.png"), final_rgba)
            cv2.imwrite(str(out_heads_dir / f"{key}_id_mask.png"), id_bgra)
            cv2.imwrite(str(out_heads_dir / f"{key}_normal_depth.png"), nd_bgra)
            cv2.imwrite(str(out_heads_dir / f"{key}_hair_jiggle_mask.png"), jiggle_bgr)

            nb_y0, nb_y1 = int(target_h_px * 0.86), int(target_h_px * 0.97)
            _, nb_xs = np.where(final_rgba[nb_y0:nb_y1, :, 3] > 128)
            neck_x_px = float(nb_xs.mean()) if len(nb_xs) > 0 else target_w_px * 0.5
            neck_y_px = float(target_h_px) * 0.855

            disp_w = round(float(target_w_px) / TEX_SCALE, 1)
            disp_h = TARGET_DISP_H
            neck_disp_x = round(neck_x_px / TEX_SCALE, 1)
            neck_disp_y = round(neck_y_px / TEX_SCALE, 1)

            meta[key] = {
                "disp_size": [disp_w, disp_h],
                "neck_pivot_px": [neck_disp_x, neck_disp_y],
                "sprite_offset": [round(disp_w * 0.5 - neck_disp_x, 1), round(disp_h * 0.5 - neck_disp_y, 1)],
            }

            # Mask audit overlay
            vis = final_rgba[:, :, :3].astype(np.float32)
            # Highlight Hair=Cyan, Collar=Blue, Monocle=Red
            ha = (id_bgra[:, :, 3:4].astype(np.float32) / 255.0) * 0.42
            co = (id_bgra[:, :, 0:1].astype(np.float32) / 255.0) * 0.45
            mo = (id_bgra[:, :, 2:3].astype(np.float32) / 255.0) * 0.50
            vis = vis * (1.0 - ha) + np.array([255, 255, 0], dtype=np.float32) * ha
            vis = vis * (1.0 - co) + np.array([255, 60, 40], dtype=np.float32) * co
            vis = vis * (1.0 - mo) + np.array([40, 40, 255], dtype=np.float32) * mo
            a3 = final_rgba[:, :, 3:4].astype(np.float32) / 255.0
            tile_fg = np.clip(vis * a3 + 38.0 * (1.0 - a3), 0, 255).astype(np.uint8)
            tile = np.full((220, 220, 3), 38, dtype=np.uint8)
            s = min(204.0 / tile_fg.shape[1], 190.0 / tile_fg.shape[0])
            rw, rh = int(round(tile_fg.shape[1] * s)), int(round(tile_fg.shape[0] * s))
            ox, oy = (220 - rw) // 2, (220 - rh) // 2 + 8
            tile[oy:oy + rh, ox:ox + rw] = cv2.resize(tile_fg, (rw, rh), interpolation=cv2.INTER_AREA)
            cv2.putText(tile, key, (8, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (235, 240, 255), 1, cv2.LINE_AA)
            audit_tiles.append(tile)

    # Preserve legacy head_side alias pointing to head_side_r
    meta["head_side"] = dict(meta["head_side_r"])
    (out_heads_dir / "heads_metadata.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    audit_dir.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(audit_dir / "audit_heads_8dir_masks.png"), np.vstack([np.hstack(audit_tiles[:4]), np.hstack(audit_tiles[4:])]))
    print(f"Exported 8 heads + id_mask + normal_depth -> {out_heads_dir}")


if __name__ == "__main__":
    sr = Path("sandbox/pilot_rig_lab/source_refs")
    scratch = Path("C:/Users/Frani/.gemini/antigravity/brain/7a3a228c-eb42-4859-8dfd-b49e7048ca8f/scratch")
    out_heads = Path("sandbox/pilot_rig_lab/combat_assets/valentina_planar/heads")
    process_all(
        sr / "valentina_heads_8dir_sheet.jpg",
        sr / "valentina_heads_8dir_mask.jpg",
        out_heads,
        scratch,
        scratch / "upscayl_out",
    )
