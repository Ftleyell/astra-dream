"""Split, Upscayl-4x, key, and align the 8 AI-completed Valentina v2 torsos into hd_torsos/."""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from polish_outlines import alpha_bleed_only  # noqa: E402
from process_masked_5parts import upscale_with_upscayl  # noqa: E402

ROOT = TOOLS_DIR.parent
ASSETS_DIR = ROOT / "combat_assets" / "valentina_v2_planar"
REGEN_DIR = (
    ROOT
    / "source_refs"
    / "valentina_v2_8dir"
    / "05_mask_ai_workspaces"
    / "manual_fix_overlays"
    / "07_torso_neck_regen_16x9"
)
HD_TORSOS_DIR = ASSETS_DIR / "hd_torsos"
RAW_CROPS_DIR = HD_TORSOS_DIR / "raw_crops"
VIEWS: tuple[str, ...] = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
PX_W, PX_H = 1560, 1680


def _extract_rgba_from_white(cell_bgr: np.ndarray) -> np.ndarray:
    """Flood-fill white exterior background and defringe anti-aliased borders."""
    h, w = cell_bgr.shape[:2]
    b, g, r = cv2.split(cell_bgr)
    min_c = np.minimum(np.minimum(b, g), r)
    max_c = np.maximum(np.maximum(b, g), r)
    chroma = max_c - min_c
    is_bg_cand = (min_c >= 226) & (chroma <= 24)

    # Flood-fill connected background from all 4 cell edges
    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    seed_img = (is_bg_cand.astype(np.uint8)) * 255
    for x in range(w):
        if seed_img[0, x] == 255 and ff_mask[1, x + 1] == 0:
            cv2.floodFill(seed_img, ff_mask, (x, 0), 128)
        if seed_img[h - 1, x] == 255 and ff_mask[h, x + 1] == 0:
            cv2.floodFill(seed_img, ff_mask, (x, h - 1), 128)
    for y in range(h):
        if seed_img[y, 0] == 255 and ff_mask[y + 1, 1] == 0:
            cv2.floodFill(seed_img, ff_mask, (0, y), 128)
        if seed_img[y, w - 1] == 255 and ff_mask[y + 1, w] == 0:
            cv2.floodFill(seed_img, ff_mask, (w - 1, y), 128)

    ext_bg = seed_img == 128
    fg = ~ext_bg

    # Remove tiny detached specks (< 40 px)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8), connectivity=8)
    for cid in range(1, n_cc):
        if int(stats[cid, cv2.CC_STAT_AREA]) < 40:
            fg[lbl == cid] = False

    # Soft alpha ramp on immediate 1-2px near-white boundary
    dist_fg = cv2.distanceTransform(fg.astype(np.uint8), cv2.DIST_L2, 3)
    luma = 0.114 * b.astype(np.float32) + 0.587 * g.astype(np.float32) + 0.299 * r.astype(np.float32)
    alpha = np.where(fg, 255.0, 0.0).astype(np.float32)
    rim = fg & (dist_fg <= 1.5) & (luma >= 210.0)
    alpha[rim] = np.clip((250.0 - luma[rim]) / 40.0, 0.0, 1.0) * 255.0

    rgba = np.dstack([cell_bgr, np.clip(alpha, 0, 255).astype(np.uint8)])
    return alpha_bleed_only(rgba)


def _align_crop_to_canonical(
    crop_rgba: np.ndarray,
    ref_body_rgba: np.ndarray,
    canonical_rect: list[int],
    init_scale: float,
) -> tuple[np.ndarray, dict]:
    """Align HD torso crop onto 1560x1680 canonical canvas matching lower-72% body_core."""
    rx, ry, _, _ = [int(v) * 3 for v in canonical_rect]
    ref_h, ref_w = ref_body_rgba.shape[:2]
    ref_full = np.zeros((PX_H, PX_W), dtype=np.uint8)
    ref_mask = (ref_body_rgba[:, :, 3] >= 64).astype(np.uint8)
    n_rc, lbl_rc, st_rc, _ = cv2.connectedComponentsWithStats(ref_mask, connectivity=8)
    for cid in range(1, n_rc):
        if int(st_rc[cid, cv2.CC_STAT_AREA]) < 40:
            ref_mask[lbl_rc == cid] = 0
    ref_full[ry : ry + ref_h, rx : rx + ref_w] = ref_mask

    # Use lower 72% of reference torso (chest/waist/hips) so extended neck doesn't bias alignment
    ref_ys, ref_xs = np.where(ref_full > 0)
    ry_min, ry_max = int(ref_ys.min()), int(ref_ys.max())
    rx_mid = 0.5 * (float(ref_xs.min()) + float(ref_xs.max()))
    cut_y = ry_min + int(round(0.28 * float(ry_max - ry_min)))
    ref_low = ref_full.copy()
    ref_low[:cut_y, :] = 0
    ref_low_bool = ref_low > 0

    ch, cw = crop_rgba.shape[:2]
    crop_mask = (crop_rgba[:, :, 3] >= 64).astype(np.uint8)

    best_score = -1.0
    best_params = (init_scale, 0.0, 0.0)

    # Coarse then fine search over scale and (dx, dy) anchored at bottom-center
    for s in np.linspace(init_scale * 0.97, init_scale * 1.05, 9):
        tw = max(8, int(round(cw * s)))
        th = max(8, int(round(ch * s)))
        m_res = cv2.resize(crop_mask, (tw, th), interpolation=cv2.INTER_NEAREST)
        mys, mxs = np.where(m_res > 0)
        if len(mys) == 0:
            continue
        m_y_max = int(mys.max())
        m_x_mid = 0.5 * (float(mxs.min()) + float(mxs.max()))
        base_ox = int(round(rx_mid - m_x_mid))
        base_oy = int(round(ry_max - m_y_max))
        for dy in range(-15, 16, 3):
            for dx in range(-18, 19, 3):
                ox = base_ox + dx
                oy = base_oy + dy
                cand = np.zeros((PX_H, PX_W), dtype=bool)
                sx0 = max(0, -ox)
                sy0 = max(0, -oy)
                dx0 = max(0, ox)
                dy0 = max(0, oy)
                cw_fit = min(tw - sx0, PX_W - dx0)
                ch_fit = min(th - sy0, PX_H - dy0)
                if cw_fit <= 0 or ch_fit <= 0:
                    continue
                cand[dy0 : dy0 + ch_fit, dx0 : dx0 + cw_fit] = m_res[sy0 : sy0 + ch_fit, sx0 : sx0 + cw_fit] > 0
                cand[:cut_y, :] = False
                inter = int(np.sum(cand & ref_low_bool))
                union = int(np.sum(cand | ref_low_bool))
                iou = float(inter) / float(max(union, 1))
                if iou > best_score:
                    best_score = iou
                    best_params = (float(s), float(ox), float(oy))

    s0, ox0, oy0 = best_params
    for s in np.linspace(s0 * 0.985, s0 * 1.015, 7):
        tw = max(8, int(round(cw * s)))
        th = max(8, int(round(ch * s)))
        m_res = cv2.resize(crop_mask, (tw, th), interpolation=cv2.INTER_NEAREST)
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                ox = int(round(ox0)) + dx
                oy = int(round(oy0)) + dy
                cand = np.zeros((PX_H, PX_W), dtype=bool)
                sx0 = max(0, -ox)
                sy0 = max(0, -oy)
                dx0 = max(0, ox)
                dy0 = max(0, oy)
                cw_fit = min(tw - sx0, PX_W - dx0)
                ch_fit = min(th - sy0, PX_H - dy0)
                if cw_fit <= 0 or ch_fit <= 0:
                    continue
                cand[dy0 : dy0 + ch_fit, dx0 : dx0 + cw_fit] = m_res[sy0 : sy0 + ch_fit, sx0 : sx0 + cw_fit] > 0
                cand[:cut_y, :] = False
                inter = int(np.sum(cand & ref_low_bool))
                union = int(np.sum(cand | ref_low_bool))
                iou = float(inter) / float(max(union, 1))
                if iou > best_score:
                    best_score = iou
                    best_params = (float(s), float(ox), float(oy))

    bf_s, bf_ox, bf_oy = best_params
    tw = max(8, int(round(cw * bf_s)))
    th = max(8, int(round(ch * bf_s)))
    ox = int(round(bf_ox))
    oy = int(round(bf_oy))
    interp = cv2.INTER_AREA if (cw >= tw and ch >= th) else cv2.INTER_CUBIC
    resized = cv2.resize(crop_rgba, (tw, th), interpolation=interp)

    out_full = np.zeros((PX_H, PX_W, 4), dtype=np.uint8)
    sx0 = max(0, -ox)
    sy0 = max(0, -oy)
    dx0 = max(0, ox)
    dy0 = max(0, oy)
    cw_fit = min(tw - sx0, PX_W - dx0)
    ch_fit = min(th - sy0, PX_H - dy0)
    if cw_fit > 0 and ch_fit > 0:
        out_full[dy0 : dy0 + ch_fit, dx0 : dx0 + cw_fit] = resized[sy0 : sy0 + ch_fit, sx0 : sx0 + cw_fit]
    out_full = alpha_bleed_only(out_full)

    info = {
        "scale": round(bf_s, 5),
        "paste_xy": [ox, oy],
        "size_wh": [tw, th],
        "lower_torso_iou": round(best_score, 4),
    }
    return out_full, info


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest AI-regenerated 16:9 torsos via Upscayl 4x.")
    parser.add_argument("--sheet", type=Path, default=None, help="Path to AI-regenerated 4x2 sheet.")
    args = parser.parse_args()

    REGEN_DIR.mkdir(parents=True, exist_ok=True)
    HD_TORSOS_DIR.mkdir(parents=True, exist_ok=True)
    RAW_CROPS_DIR.mkdir(parents=True, exist_ok=True)

    raw_sheet = REGEN_DIR / "torsos_8dir_regen_raw.jpg"
    if args.sheet is not None and args.sheet.exists() and args.sheet.resolve() != raw_sheet.resolve():
        shutil.copy2(args.sheet, raw_sheet)
    if not raw_sheet.exists():
        raise FileNotFoundError(f"Regenerated torso sheet not found: {raw_sheet}")

    up_sheet = REGEN_DIR / "torsos_8dir_regen_4x.png"
    upscale_with_upscayl(raw_sheet, up_sheet, model="digital-art-4x")
    sheet_bgr = cv2.imread(str(up_sheet), cv2.IMREAD_COLOR)
    if sheet_bgr is None:
        raise RuntimeError(f"Failed to read upscaled sheet: {up_sheet}")

    sh, sw = sheet_bgr.shape[:2]
    cell_w = sw / 4.0
    cell_h = sh / 2.0

    orig_manifest = json.loads((REGEN_DIR / "torsos_8dir_manifest.json").read_text(encoding="utf-8"))
    orig_canvas_w = float(orig_manifest["canvas"][0])
    init_scale = orig_canvas_w / float(sw)  # maps 4x upscaled pixels back to 3x canonical (1560x1680)

    hd_manifest: dict[str, object] = {
        "source_sheet_raw": raw_sheet.name,
        "source_sheet_4x": up_sheet.name,
        "upscaled_size": [sw, sh],
        "canonical_size": [PX_W, PX_H],
        "views": {},
    }
    audit_tiles: list[np.ndarray] = []

    for idx, view in enumerate(VIEWS):
        row = idx // 4
        col = idx % 4
        x0 = int(round(col * cell_w))
        x1 = int(round((col + 1) * cell_w))
        y0 = int(round(row * cell_h))
        y1 = int(round((row + 1) * cell_h))
        cell = sheet_bgr[y0:y1, x0:x1]

        rgba_cell = _extract_rgba_from_white(cell)
        ys, xs = np.where(rgba_cell[:, :, 3] >= 16)
        if len(ys) == 0:
            raise RuntimeError(f"Empty torso cell for view '{view}'")
        crop_rgba = rgba_cell[int(ys.min()) : int(ys.max()) + 1, int(xs.min()) : int(xs.max()) + 1]
        cv2.imwrite(str(RAW_CROPS_DIR / f"{view}_torso_hd.png"), crop_rgba)

        ref_body_p = ASSETS_DIR / view / "parts_5" / "body_core.png"
        ref_body_rgba = cv2.imread(str(ref_body_p), cv2.IMREAD_UNCHANGED)
        c_rect = orig_manifest["entries"][view]["canonical_rect"]
        aligned_full, info = _align_crop_to_canonical(crop_rgba, ref_body_rgba, c_rect, init_scale)
        cv2.imwrite(str(HD_TORSOS_DIR / f"{view}_body_core_hd.png"), aligned_full)
        hd_manifest["views"][view] = info
        print(f"  [{view.upper()}] crop={crop_rgba.shape[1]}x{crop_rgba.shape[0]} -> canonical={info['size_wh']} IoU={info['lower_torso_iou']}")

        # Build visual alignment tile (white bg + HD torso + red outline of old body_core)
        rx, ry, _, _ = [int(v) * 3 for v in c_rect]
        ref_h, ref_w = ref_body_rgba.shape[:2]
        ref_m = np.zeros((PX_H, PX_W), dtype=np.uint8)
        ref_m[ry : ry + ref_h, rx : rx + ref_w] = (ref_body_rgba[:, :, 3] >= 64).astype(np.uint8) * 255
        edges = cv2.Canny(ref_m, 50, 150) > 0
        edges = cv2.dilate(edges.astype(np.uint8), np.ones((2, 2), np.uint8)) > 0

        vis_tile = np.full((PX_H, PX_W, 3), 255, dtype=np.uint8)
        a = aligned_full[:, :, 3:4].astype(np.float32) / 255.0
        vis_tile = np.clip(vis_tile.astype(np.float32) * (1.0 - a) + aligned_full[:, :, :3].astype(np.float32) * a, 0, 255).astype(np.uint8)
        vis_tile[edges] = np.array([40, 40, 240], dtype=np.uint8)  # BGR red outline of old body_core

        # Crop tile around torso
        ay, ax = np.where((aligned_full[:, :, 3] >= 16) | (ref_m > 0))
        pad = 30
        ty0, ty1 = max(0, int(ay.min()) - pad), min(PX_H, int(ay.max()) + pad)
        tx0, tx1 = max(0, int(ax.min()) - pad), min(PX_W, int(ax.max()) + pad)
        crop_vis = cv2.resize(vis_tile[ty0:ty1, tx0:tx1], (380, 520), interpolation=cv2.INTER_AREA)
        cv2.putText(crop_vis, f"{view.upper()} IoU={info['lower_torso_iou']}", (12, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (20, 20, 20), 2)
        audit_tiles.append(crop_vis)

    (HD_TORSOS_DIR / "hd_torsos_manifest.json").write_text(json.dumps(hd_manifest, indent=2) + "\n", encoding="utf-8")
    row0 = np.hstack(audit_tiles[:4])
    row1 = np.hstack(audit_tiles[4:])
    audit_grid = np.vstack([row0, row1])
    cv2.imwrite(str(REGEN_DIR / "audit_alignment_8dir.png"), audit_grid)
    print(f"Saved HD torsos -> {HD_TORSOS_DIR}")
    print(f"Saved alignment audit -> {REGEN_DIR / 'audit_alignment_8dir.png'}")


if __name__ == "__main__":
    main()
