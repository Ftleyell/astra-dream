"""Non-destructive outline polish for Valentina planar assets.

Operates directly on the current PNGs in s/parts_5, n/parts_5, and heads/
so manual Photoshop silhouette edits are 100% preserved:
1. Alpha-bleed + bright-fringe cleanup on alpha==0 and semi-transparent edges.
2. Smooth neck-top alpha fade on body_core so the body's neck outline
   does not clash with the head/chin.
3. Symmetric 12px transparent padding on heads/* (plus matching maps and
   proportional disp_size update in heads_metadata.json) so outward head
   outline dilation in the shader never clips at the quad border.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import cv2
import numpy as np

ASSETS_DIR = Path("sandbox/pilot_rig_lab/combat_assets/valentina_planar")
BACKUP_DIR = ASSETS_DIR / "_backup_before_outline_polish"
PART_NAMES = ("body_core", "arm_r", "arm_l", "leg_r", "leg_l")
HEAD_PAD_PX = 24


def _ensure_backup() -> None:
    if BACKUP_DIR.exists():
        return
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for view in ("s", "n"):
        src_dir = ASSETS_DIR / view / "parts_5"
        dst_dir = BACKUP_DIR / view / "parts_5"
        dst_dir.mkdir(parents=True, exist_ok=True)
        for p in src_dir.glob("*.png"):
            shutil.copy2(p, dst_dir / p.name)
        meta_p = src_dir / "parts_5_meta.json"
        if meta_p.exists():
            shutil.copy2(meta_p, dst_dir / meta_p.name)
    heads_src = ASSETS_DIR / "heads"
    heads_dst = BACKUP_DIR / "heads"
    if heads_src.exists():
        shutil.copytree(heads_src, heads_dst, dirs_exist_ok=True)


def _voronoi_fill(img: np.ndarray, valid_mask: np.ndarray, max_dist_px: float = -1.0) -> np.ndarray:
    """Propagate nearest valid pixel values via Euclidean Voronoi into invalid regions."""
    if not np.any(valid_mask):
        return img
    out = img.copy()
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
        out[fy, fx] = img[oy[idx], ox[idx]]
    return out


def alpha_bleed_and_defringe(bgra: np.ndarray) -> np.ndarray:
    """Fill transparent RGB with nearest opaque pixel RGB and remove bright fringe."""
    out = bgra.copy()
    alpha = out[:, :, 3]
    opaque = alpha >= 210
    if not np.any(opaque):
        return out

    _, labels = cv2.distanceTransformWithLabels(
        (~opaque).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    oy, ox = np.where(opaque)

    # 1. Bleed RGB into completely transparent pixels so bilinear filtering never pulls white
    trans = alpha == 0
    if np.any(trans):
        ty, tx = np.where(trans)
        idx = labels[ty, tx] - 1
        out[ty, tx, :3] = out[oy[idx], ox[idx], :3]

    # 2. Defringe semi-transparent border pixels that are brighter than nearest opaque pixel
    semi = (alpha > 0) & (alpha < 210)
    if np.any(semi):
        sy, sx = np.where(semi)
        idx = labels[sy, sx] - 1
        nearest_rgb = out[oy[idx], ox[idx], :3]
        cur_luma = out[sy, sx, :3].astype(np.float32).mean(axis=1)
        near_luma = nearest_rgb.astype(np.float32).mean(axis=1)
        bright_halo = cur_luma > (near_luma + 18.0)
        if np.any(bright_halo):
            out[sy[bright_halo], sx[bright_halo], :3] = nearest_rgb[bright_halo]

    return out


def _neck_window_geom(meta: dict) -> tuple[float, float, float, float, float, float]:
    tex_scale = float(meta.get("tex_scale", 3.0))
    rect = meta["rects"]["body_core"]
    bones = {b["name"]: b["pos"] for b in meta.get("bones", [])}
    neck_pos = bones.get("Neck", meta.get("neck_anchor", [rect[0] + rect[2] * 0.5, rect[1] + 10.0]))
    neck_x = (float(neck_pos[0]) - float(rect[0])) * tex_scale
    neck_y = (float(neck_pos[1]) - float(rect[1])) * tex_scale
    x_half = 11.5 * tex_scale
    x_fade = 4.5 * tex_scale
    y0 = neck_y - 4.0 * tex_scale
    y1 = neck_y + 2.5 * tex_scale
    return neck_x, neck_y, x_half, x_fade, y0, y1


def fade_body_core_neck_top(bgra: np.ndarray, meta: dict) -> np.ndarray:
    """Softly fade the top neck rim on body_core so it tucks cleanly under the head."""
    out = bgra.copy()
    neck_x, _, x_half, x_fade, y0, y1 = _neck_window_geom(meta)

    h, w = out.shape[:2]
    yy, xx = np.mgrid[:h, :w].astype(np.float32)

    # Horizontal window centered on neck opening (keeps collar/shoulders untouched)
    dx = np.abs(xx - neck_x)
    hx = 1.0 - np.clip((dx - x_half) / x_fade, 0.0, 1.0)
    hx = hx * hx * (3.0 - 2.0 * hx)

    # Vertical fade from y0 (full clear) to y1 (full opaque)
    vy = np.clip((yy - y0) / max(y1 - y0, 1.0), 0.0, 1.0)
    vy = vy * vy * (3.0 - 2.0 * vy)

    neck_keep = 1.0 - hx * (1.0 - vy)
    out[:, :, 3] = np.clip(out[:, :, 3].astype(np.float32) * neck_keep, 0, 255).astype(np.uint8)
    return out


def restore_body_core_neck_rgb(bgra: np.ndarray, meta: dict) -> np.ndarray:
    """Restore collar/skin RGB in the body_core neck fade window tainted by INK_RGB."""
    out = bgra.copy()
    neck_x, _, x_half, x_fade, _, y1 = _neck_window_geom(meta)
    h, w = out.shape[:2]
    yy, xx = np.mgrid[:h, :w].astype(np.float32)
    dx = np.abs(xx - neck_x)

    luma = (
        0.114 * out[:, :, 0].astype(np.float32)
        + 0.587 * out[:, :, 1].astype(np.float32)
        + 0.299 * out[:, :, 2].astype(np.float32)
    )
    neck_win = (yy <= (y1 + 2.0)) & (dx <= (x_half + x_fade))
    valid_src = (out[:, :, 3] >= 210) & (luma > 25.0) & (yy > y1) & (dx <= (x_half + x_fade + 6.0))
    if not np.any(valid_src):
        return out

    ink_corrupt = neck_win & ((luma <= 25.0) | (out[:, :, 3] < 210))
    if not np.any(ink_corrupt):
        return out

    filled_bgr = _voronoi_fill(out[:, :, :3], valid_src)
    out[ink_corrupt, :3] = filled_bgr[ink_corrupt]
    return out


def _pad_image(img: np.ndarray, pad: int, border_val: tuple[int, ...]) -> np.ndarray:
    return cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=border_val)


def sanitize_masks_and_alignments() -> None:
    """Fix s/leg_r 8px crop mismatch, normal_depth edge zeros, and head id_mask hair margin."""
    # 1. Align s/parts_5/leg_r maps (cropped 8 top rows from 739 -> 731)
    s_parts = ASSETS_DIR / "s" / "parts_5"
    leg_r_col = cv2.imread(str(s_parts / "leg_r.png"), cv2.IMREAD_UNCHANGED)
    if leg_r_col is not None and leg_r_col.shape[:2] == (731, 270):
        for suffix in ("_id_mask.png", "_normal_depth.png"):
            mp = s_parts / f"leg_r{suffix}"
            if mp.exists():
                m_img = cv2.imread(str(mp), cv2.IMREAD_UNCHANGED)
                if m_img is not None and m_img.shape[:2] == (739, 270):
                    cv2.imwrite(str(mp), m_img[8:739, :])
                    print(f"Cropped s/parts_5/leg_r{suffix} [8:739] -> {m_img[8:739, :].shape[:2]}")

    # 2. Voronoi fill normal_depth edge holes & background + id_mask border margin in parts_5
    for view in ("s", "n"):
        parts_dir = ASSETS_DIR / view / "parts_5"
        for k in PART_NAMES:
            col = cv2.imread(str(parts_dir / f"{k}.png"), cv2.IMREAD_UNCHANGED)
            if col is None or col.shape[2] != 4:
                continue
            interior = col[:, :, 3] >= 128

            nd_path = parts_dir / f"{k}_normal_depth.png"
            if nd_path.exists():
                nd = cv2.imread(str(nd_path), cv2.IMREAD_UNCHANGED)
                if nd is not None and nd.shape[:2] == col.shape[:2]:
                    non_zero = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
                    valid_nd = interior & non_zero
                    if np.any(valid_nd) and not np.all(valid_nd):
                        cv2.imwrite(str(nd_path), _voronoi_fill(nd, valid_nd))

            id_path = parts_dir / f"{k}_id_mask.png"
            if id_path.exists():
                id_m = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
                if id_m is not None and id_m.shape[:2] == col.shape[:2]:
                    cv2.imwrite(str(id_path), _voronoi_fill(id_m, interior, max_dist_px=8.0))
        print(f"Sanitized {view}/parts_5 masks (Voronoi normal_depth + id_mask border)")

    # 3. Heads: Voronoi fill normal_depth & dilate id_mask (hair A channel) across outer SDF margin
    heads_dir = ASSETS_DIR / "heads"
    meta = json.loads((heads_dir / "heads_metadata.json").read_text(encoding="utf-8"))
    for h_key, entry in list(meta.items()):
        if h_key.startswith("_") or not isinstance(entry, dict):
            continue
        col = cv2.imread(str(heads_dir / f"{h_key}.png"), cv2.IMREAD_UNCHANGED)
        if col is None or col.shape[2] != 4:
            continue
        interior = col[:, :, 3] >= 128

        nd_path = heads_dir / f"{h_key}_normal_depth.png"
        if nd_path.exists():
            nd = cv2.imread(str(nd_path), cv2.IMREAD_UNCHANGED)
            if nd is not None and nd.shape[:2] == col.shape[:2] and nd.shape[2] == 4:
                non_zero = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
                valid_nd = interior & non_zero & (nd[:, :, 3] > 0)
                if np.any(valid_nd):
                    cv2.imwrite(str(nd_path), _voronoi_fill(nd, valid_nd))

        id_path = heads_dir / f"{h_key}_id_mask.png"
        if id_path.exists():
            id_m = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
            if id_m is not None and id_m.shape[:2] == col.shape[:2]:
                cv2.imwrite(str(id_path), _voronoi_fill(id_m, interior, max_dist_px=14.0))
    print("Sanitized heads/* masks (Voronoi normal_depth + 14px id_mask hair dilation)")


def sanitize_arm_underlap_wedges() -> None:
    """Replace pure-black geodesic underlap wedges on arms behind body_core via Voronoi."""
    for view in ("s", "n"):
        parts_dir = ASSETS_DIR / view / "parts_5"
        meta_path = parts_dir / "parts_5_meta.json"
        if not meta_path.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if bool(meta.get("_arm_underlap_sanitized", False)):
            continue
        bc_path = parts_dir / "body_core.png"
        bc_col = cv2.imread(str(bc_path), cv2.IMREAD_UNCHANGED)
        if bc_col is None or bc_col.shape[2] != 4:
            continue
        z_orders = meta.get("z_orders", {})
        rects = meta.get("rects", {})
        if "body_core" not in rects:
            continue
        bx, by, bw, bh = [float(v) for v in rects["body_core"]]
        bc_h, bc_w = bc_col.shape[:2]
        bc_z = int(z_orders.get("body_core", 4))

        changed = False
        for k in ("arm_r", "arm_l"):
            if int(z_orders.get(k, bc_z)) >= bc_z or k not in rects:
                continue
            arm_path = parts_dir / f"{k}.png"
            col = cv2.imread(str(arm_path), cv2.IMREAD_UNCHANGED)
            if col is None or col.shape[2] != 4:
                continue
            ah, aw = col.shape[:2]
            ax, ay, arw, arh = [float(v) for v in rects[k]]

            yy, xx = np.mgrid[:ah, :aw].astype(np.float32)
            cx = ax + (xx + 0.5) * (arw / max(aw, 1))
            cy = ay + (yy + 0.5) * (arh / max(ah, 1))
            bx_px = np.round((cx - bx) * (bc_w / max(bw, 1e-4)) - 0.5).astype(np.int32)
            by_px = np.round((cy - by) * (bc_h / max(bh, 1e-4)) - 0.5).astype(np.int32)

            in_bounds = (bx_px >= 0) & (bx_px < bc_w) & (by_px >= 0) & (by_px < bc_h)
            in_bc_overlap = np.zeros((ah, aw), dtype=bool)
            in_bc_overlap[in_bounds] = bc_col[by_px[in_bounds], bx_px[in_bounds], 3] >= 128

            luma = (
                0.114 * col[:, :, 0].astype(np.float32)
                + 0.587 * col[:, :, 1].astype(np.float32)
                + 0.299 * col[:, :, 2].astype(np.float32)
            ) / 255.0
            target_mask = in_bc_overlap & (col[:, :, 3] >= 128) & (luma < 0.14)
            if not np.any(target_mask):
                continue

            interior_free = (col[:, :, 3] >= 210) & (~in_bc_overlap)
            valid_src = interior_free & (luma >= 0.15)
            if not np.any(valid_src) and np.any(interior_free):
                p60 = float(np.percentile(luma[interior_free], 60))
                valid_src = interior_free & (luma >= p60)
            if not np.any(valid_src):
                continue

            filled_bgr = _voronoi_fill(col[:, :, :3], valid_src)
            ao_bgr = np.clip(filled_bgr.astype(np.float32) * 0.85, 0, 255).astype(np.uint8)
            col[target_mask, :3] = ao_bgr[target_mask]
            cv2.imwrite(str(arm_path), col)
            changed = True
            print(f"Sanitized underlap wedge in {view}/parts_5/{k}.png ({int(np.sum(target_mask))} px)")

        meta["_arm_underlap_sanitized"] = True
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        if changed:
            print(f"Updated {view}/parts_5_meta.json (_arm_underlap_sanitized=true)")


def _compute_luma(bgr: np.ndarray) -> np.ndarray:
    """Compute Rec.601 normalized luminance [0..1] from a BGR image."""
    bgr_f = bgr.astype(np.float32)
    return (0.114 * bgr_f[:, :, 0] + 0.587 * bgr_f[:, :, 1] + 0.299 * bgr_f[:, :, 2]) / 255.0


def _normalize_single_back_arm(arm_path: Path, idm_path: Path) -> int:
    """Normalize outer outline to ~4 texels and lift thick cast-shadow interiors on a back arm."""
    col = cv2.imread(str(arm_path), cv2.IMREAD_UNCHANGED)
    idm = cv2.imread(str(idm_path), cv2.IMREAD_UNCHANGED)
    if col is None or col.shape[2] != 4 or idm is None or idm.shape[:2] != col.shape[:2]:
        return 0

    alpha = col[:, :, 3]
    interior = (alpha >= 128).astype(np.uint8)
    dist = cv2.distanceTransform(interior, cv2.DIST_L2, 5)
    bgr = col[:, :, :3].astype(np.float32)
    luma = _compute_luma(bgr)

    # 1. Consolidate crisp ~4.0 texel outer outline matching front arms
    outer_band = (alpha >= 128) & (dist <= 4.2) & (luma < 0.20)
    t_out = np.clip((dist - 2.8) / 1.4, 0.0, 1.0)[:, :, None]
    ink_bgr = np.array([6.0, 4.0, 4.0], dtype=np.float32)
    bgr[outer_band] = (ink_bgr * (1.0 - t_out) + bgr * t_out)[outer_band]

    # 2. Detect thin internal armor creases/bolts so interior lifting keeps them intact
    kernel_9 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    local_max_luma = cv2.dilate(luma, kernel_9)
    local_min_dist_dark = cv2.distanceTransform((luma < 0.14).astype(np.uint8), cv2.DIST_L2, 5)
    is_internal_crease = (
        (dist > 5.2)
        & (local_max_luma > 0.21)
        & (local_min_dist_dark <= 3.0)
        & ((idm[:, :, 1] > 60) | (local_max_luma > 0.26))
    )

    # 3. Lift thick baked cast-shadow / inner border bands while preserving chromatic identity
    inner_zone = (alpha >= 128) & (dist > 4.2) & (luma < 0.175) & (~is_internal_crease)
    if not np.any(inner_zone):
        return 0

    ramp = np.clip((dist - 4.0) / 1.8, 0.0, 1.0)
    target_luma = 0.165 + 0.35 * luma
    new_luma = luma * (1.0 - ramp) + np.maximum(luma, target_luma) * ramp

    is_orig_crimson = (bgr[:, :, 2] > bgr[:, :, 0] * 1.25) & (idm[:, :, 2] > 80)
    suit_ratio = np.array([1.15, 0.90, 1.06], dtype=np.float32)
    crim_ratio = np.array([0.82, 0.58, 1.62], dtype=np.float32)
    ratio = np.where(is_orig_crimson[:, :, None], crim_ratio, suit_ratio)

    lifted_bgr = np.clip(new_luma[:, :, None] * 255.0 * ratio, 0.0, 255.0)
    orig_w = np.clip((luma - 0.07) / 0.10, 0.0, 1.0)[:, :, None] * 0.55
    scale_orig = np.clip(bgr * (new_luma / np.maximum(luma, 0.02))[:, :, None], 0.0, 255.0)
    final_inner_bgr = lifted_bgr * (1.0 - orig_w) + scale_orig * orig_w

    bgr[inner_zone] = final_inner_bgr[inner_zone]
    col[:, :, :3] = np.clip(np.round(bgr), 0, 255).astype(np.uint8)
    cv2.imwrite(str(arm_path), col)
    return int(np.sum(inner_zone))


def _thin_s_body_core_breast_seam(bc_path: Path) -> int:
    """Thin the heavy >15px black border on s/body_core right chest overlapping arm_l."""
    bc = cv2.imread(str(bc_path), cv2.IMREAD_UNCHANGED)
    if bc is None or bc.shape[2] != 4:
        return 0
    alpha = bc[:, :, 3]
    dist = cv2.distanceTransform((alpha >= 128).astype(np.uint8), cv2.DIST_L2, 5)
    bgr = bc[:, :, :3].astype(np.float32)
    luma = _compute_luma(bgr)
    yy, xx = np.mgrid[: bc.shape[0], : bc.shape[1]]
    breast_seam = (alpha >= 128) & (xx > 260) & (yy >= 75) & (yy <= 215) & (dist > 3.8) & (luma < 0.17)
    if not np.any(breast_seam):
        return 0

    ramp = np.clip((dist - 3.6) / 2.0, 0.0, 1.0)
    target_luma = 0.175 + 0.35 * luma
    new_luma = luma * (1.0 - ramp) + np.maximum(luma, target_luma) * ramp
    suit_ratio = np.array([1.16, 0.90, 1.10], dtype=np.float32)
    bgr[breast_seam] = np.clip((new_luma[:, :, None] * 255.0 * suit_ratio)[breast_seam], 0.0, 255.0)
    bc[:, :, :3] = np.clip(np.round(bgr), 0, 255).astype(np.uint8)
    cv2.imwrite(str(bc_path), bc)
    return int(np.sum(breast_seam))


def normalize_back_arm_outlines() -> None:
    """Normalize back-arm outline width and overlapping body_core chest border idempotently."""
    back_arm_by_view = {"s": "arm_l", "n": "arm_r"}
    for view, arm_key in back_arm_by_view.items():
        parts_dir = ASSETS_DIR / view / "parts_5"
        meta_path = parts_dir / "parts_5_meta.json"
        if not meta_path.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if bool(meta.get("_back_arm_outline_normalized", False)):
            continue

        arm_px = _normalize_single_back_arm(parts_dir / f"{arm_key}.png", parts_dir / f"{arm_key}_id_mask.png")
        print(f"Normalized back arm outline in {view}/parts_5/{arm_key}.png (lifted {arm_px} px)")
        if view == "s":
            bc_px = _thin_s_body_core_breast_seam(parts_dir / "body_core.png")
            print(f"Thinned right breast overlap seam in s/parts_5/body_core.png ({bc_px} px)")

        meta["_back_arm_outline_normalized"] = True
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"Updated {view}/parts_5_meta.json (_back_arm_outline_normalized=true)")


def polish_parts_5() -> None:
    for view in ("s", "n"):
        parts_dir = ASSETS_DIR / view / "parts_5"
        meta_path = parts_dir / "parts_5_meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        apply_neck_fade = not bool(meta.get("_neck_fade_applied", False))
        for k in PART_NAMES:
            p = parts_dir / f"{k}.png"
            if not p.exists():
                continue
            bgra = cv2.imread(str(p), cv2.IMREAD_UNCHANGED)
            if bgra is None or bgra.shape[2] != 4:
                continue
            cleaned = alpha_bleed_and_defringe(bgra)
            if k == "body_core":
                if apply_neck_fade:
                    cleaned = fade_body_core_neck_top(cleaned, meta)
                cleaned = restore_body_core_neck_rgb(cleaned, meta)
            cv2.imwrite(str(p), cleaned)
        if apply_neck_fade:
            meta["_neck_fade_applied"] = True
            meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"Polished {view}/parts_5 (alpha-bleed + defringe + body_core neck fade/RGB restore)")


def polish_heads() -> None:
    heads_dir = ASSETS_DIR / "heads"
    meta_path = heads_dir / "heads_metadata.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    existing_pad = int(meta.get("_outline_pad_px", 0))
    add_pad = max(0, HEAD_PAD_PX - existing_pad)

    for h_key, entry in list(meta.items()):
        if h_key.startswith("_") or not isinstance(entry, dict):
            continue
        col_path = heads_dir / f"{h_key}.png"
        if not col_path.exists():
            continue
        col = cv2.imread(str(col_path), cv2.IMREAD_UNCHANGED)
        if col is None or col.shape[2] != 4:
            continue
        old_h, old_w = col.shape[:2]

        if add_pad > 0:
            col = _pad_image(col, add_pad, (0, 0, 0, 0))
            for suffix, bval in (
                ("_id_mask.png", (0, 0, 0, 0)),
                ("_normal_depth.png", (255, 128, 128, 0)),
                ("_hair_jiggle_mask.png", (0, 0, 0, 0)),
            ):
                mp = heads_dir / f"{h_key}{suffix}"
                if mp.exists():
                    m_img = cv2.imread(str(mp), cv2.IMREAD_UNCHANGED)
                    if m_img is not None:
                        val = bval[:m_img.shape[2]] if m_img.ndim == 3 else bval[0]
                        cv2.imwrite(str(mp), _pad_image(m_img, add_pad, val))

            new_h, new_w = col.shape[:2]
            disp_sz = entry.get("disp_size", [110.0, 120.0])
            entry["disp_size"] = [
                round(float(disp_sz[0]) * (new_w / max(old_w, 1)), 4),
                round(float(disp_sz[1]) * (new_h / max(old_h, 1)), 4),
            ]

        col = alpha_bleed_and_defringe(col)
        cv2.imwrite(str(col_path), col)

        # Exact Euclidean distance field (0..32 px -> 0..255) for gap-free shader outline
        dist_px = cv2.distanceTransform((col[:, :, 3] < 128).astype(np.uint8), cv2.DIST_L2, 5)
        sdf_u8 = np.clip((dist_px / 32.0) * 255.0, 0, 255).astype(np.uint8)
        cv2.imwrite(str(heads_dir / f"{h_key}_outline_sdf.png"), sdf_u8)

    if add_pad > 0:
        meta["_outline_pad_px"] = HEAD_PAD_PX
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"Polished heads/* (pad={add_pad}px -> total={HEAD_PAD_PX}px + alpha-bleed + defringe)")


if __name__ == "__main__":
    _ensure_backup()
    sanitize_arm_underlap_wedges()
    normalize_back_arm_outlines()
    polish_parts_5()
    polish_heads()
    sanitize_masks_and_alignments()
