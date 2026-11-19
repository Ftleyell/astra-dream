#!/usr/bin/env python3
"""Process Upscayl-4x 4x2 head sheet -> 8 hi-res heads + complete 8-direction body turnaround.

Workflow:
  1. Upscale raw 4x2 head sheet via Upscayl (`digital-art-4x`) if needed.
  2. Cleanly extract all 8 busts (`se, s, sw, w, e, ne, n, nw`) via hybrid outer-#808080
     flood-fill + IS-Net Anime enclosed-pocket removal + #0A0A14 defringe + Voronoi bleed.
  3. Normalize all 8 standalone busts to uniform body-matched 1:1 head proportions inside
     1024x1024 hi-res canvases (`heads_8dir_hires/`) and export CELL_KEYS-ordered 4x2 sheets.
  4. Register the authentic `sw` head+collar onto mirrored `se` body (`flip(se)`), splice cleanly
     at the turtleneck/pauldron seam, regenerate `sw` aligned native/canonical outputs, and
     assemble complete 8-direction compass + alignment audit sheets (`s, se, e, ne, n, nw, w, sw`).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from ml_stage_processors import clear_vram  # noqa: E402
from polish_outlines import alpha_bleed_and_defringe  # noqa: E402
from prepare_8dir_sheets import (  # noqa: E402
    CANONICAL_BODY_H,
    CANONICAL_BOTTOM_Y,
    CANONICAL_H,
    CANONICAL_W,
    DEFAULT_WORK_DIR,
    NATIVE_BOTTOM_Y,
    NATIVE_CELL_H,
    NATIVE_CELL_W,
    build_auto_id_mask_draft,
    composite_on_bg,
    compute_pose_metrics,
    crop_head_from_pose,
    draw_alignment_audit_sheet,
    extract_clean_pose_rgba,
    place_aligned_pose,
    run_upscayl_4x,
)

COMPASS_8_ORDER: tuple[str, ...] = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
HEAD_4X2_SOURCE_GRID: tuple[tuple[str, ...], ...] = (
    ("se", "s", "sw", "w"),
    ("e", "ne", "n", "nw"),
)
# Matches `process_head_8dir_sheet.py` CELL_KEYS layout left-to-right, top-to-bottom.
HEAD_CELL_KEYS_MAP: tuple[tuple[tuple[str, str], ...], ...] = (
    (("s", "head_front"), ("se", "head_front_r"), ("sw", "head_front_l"), ("w", "head_side_l")),
    (("e", "head_side_r"), ("ne", "head_back_r"), ("nw", "head_back_l"), ("n", "head_back")),
)
HIRES_HEAD_CANVAS = 1024
HIRES_HEAD_BOTTOM_PAD = 24
HIRES_SCALE_REF = 968.0 / 581.0


def _premultiplied_resize(bgra: np.ndarray, nw: int, nh: int) -> np.ndarray:
    """Resize BGRA with premultiplied alpha to avoid edge halos."""
    interp = cv2.INTER_AREA if (nw < bgra.shape[1] and nh < bgra.shape[0]) else cv2.INTER_LANCZOS4
    pm = bgra.astype(np.float32)
    pm[:, :, :3] *= pm[:, :, 3:4] / 255.0
    res = cv2.resize(pm, (nw, nh), interpolation=interp)
    out = np.zeros((nh, nw, 4), dtype=np.uint8)
    ra = res[:, :, 3]
    valid = ra > 1.0
    out[:, :, 3] = np.clip(np.round(ra), 0, 255).astype(np.uint8)
    out[valid, :3] = np.clip(np.round(res[valid, :3] / (ra[valid, None] / 255.0)), 0, 255).astype(np.uint8)
    return alpha_bleed_and_defringe(out)


def _tight_crop_bgra(bgra: np.ndarray, alpha_thr: int = 96) -> np.ndarray:
    """Crop tightly around opaque foreground pixels."""
    ys, xs = np.where(bgra[:, :, 3] > alpha_thr)
    return bgra[int(ys.min()) : int(ys.max()) + 1, int(xs.min()) : int(xs.max()) + 1]


def _scrub_enclosed_pocket_rims(bgra: np.ndarray, orig_bgr: np.ndarray, bg_bgr: np.ndarray) -> np.ndarray:
    """Use untouched upscaled BGR around confirmed pockets to strip #808080 tails & fake ink loops."""
    h, w = bgra.shape[:2]
    trans = (bgra[:, :, 3] < 96).astype(np.uint8)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(trans)
    holes = np.zeros((h, w), dtype=bool)
    for cid in range(1, n_cc):
        x0 = int(stats[cid, cv2.CC_STAT_LEFT])
        y0 = int(stats[cid, cv2.CC_STAT_TOP])
        cw = int(stats[cid, cv2.CC_STAT_WIDTH])
        ch = int(stats[cid, cv2.CC_STAT_HEIGHT])
        area = int(stats[cid, cv2.CC_STAT_AREA])
        touches_border = (x0 <= 0) or (y0 <= 0) or (x0 + cw >= w) or (y0 + ch >= h)
        if not touches_border and area >= 60:
            holes[lbl == cid] = True
    if not np.any(holes):
        return bgra

    bgr = orig_bgr.astype(np.float32)
    diff = np.linalg.norm(bgr - bg_bgr[None, None, :].astype(np.float32), axis=2)
    sat = bgr.max(axis=2) - bgr.min(axis=2)
    luma = 0.114 * bgr[:, :, 0] + 0.587 * bgr[:, :, 1] + 0.299 * bgr[:, :, 2]

    # Grow geodesically from confirmed pockets using pre-defringe BGR so fake dark-painted loops vanish.
    pocket_domain = holes | ((diff < 34.0) & (sat < 16.0) & (luma >= 60.0) & (luma <= 156.0))
    _, dom_lbl = cv2.connectedComponents(pocket_domain.astype(np.uint8))
    seed_ids = set(np.unique(dom_lbl[holes]).tolist()) - {0}
    full_holes = np.isin(dom_lbl, list(seed_ids))

    # Strip remaining 1px anti-aliased haze around pocket ink edges without eroding true black ink (<48).
    k5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    rim = (cv2.dilate(full_holes.astype(np.uint8) * 255, k5) > 0) & (~full_holes) & (bgra[:, :, 3] > 0)
    haze = full_holes | (rim & (sat < 18.0) & (luma >= 54.0) & (luma <= 160.0))

    out = bgra.copy()
    out[haze] = 0
    # Drop tiny isolated ink specks (<= 35px) left stranded inside the cleaned pocket opening.
    fg_u8 = (out[:, :, 3] > 64).astype(np.uint8)
    n_fg, fg_lbl, fg_stats, _ = cv2.connectedComponentsWithStats(fg_u8)
    for cid in range(1, n_fg):
        if int(fg_stats[cid, cv2.CC_STAT_AREA]) < 60:
            out[fg_lbl == cid] = 0
    return alpha_bleed_and_defringe(out)


def _find_4x2_splits(bgr: np.ndarray) -> tuple[list[int], list[int], np.ndarray]:
    """Locate clean horizontal row valley and 4 column valleys on 4x2 head sheet."""
    h, w = bgr.shape[:2]
    bg_bgr = np.median(bgr[:40, :, :], axis=(0, 1))
    diff = np.linalg.norm(bgr.astype(np.float32) - bg_bgr[None, None, :], axis=2)
    fg = diff > 12.0

    row_fg = fg.sum(axis=1)
    mid_lo, mid_hi = int(h * 0.35), int(h * 0.65)
    mid_zeros = np.where(row_fg[mid_lo:mid_hi] < 5)[0]
    row_split = (mid_lo + int(mid_zeros[len(mid_zeros) // 2])) if mid_zeros.size > 0 else (h // 2)
    row_bounds = [0, row_split, h]

    col_bounds = [0]
    col_fg = fg.sum(axis=0)
    for k in range(1, 4):
        nom = int(round(w * (k / 4.0)))
        lo, hi = max(0, nom - w // 10), min(w, nom + w // 10)
        z = np.where(col_fg[lo:hi] < 5)[0]
        split_x = (lo + int(z[len(z) // 2])) if z.size > 0 else nom
        col_bounds.append(split_x)
    col_bounds.append(w)
    return row_bounds, col_bounds, bg_bgr


def _register_sw_bust_to_mirror_body(
    sw_bust_tight: np.ndarray,
    sw_mirror_body: np.ndarray,
) -> tuple[np.ndarray, float, tuple[int, int, int, int]]:
    """Find best scale & offset matching SW bust lower collar onto mirrored SE torso."""
    fg_body = sw_mirror_body[:, :, 3] > 128
    ys, _ = np.where(fg_body)
    top_y, bot_y = int(ys.min()), int(ys.max())
    fig_h = bot_y - top_y
    ref_crop = crop_head_from_pose(sw_mirror_body, pad=36)
    ref_tight = _tight_crop_bgra(ref_crop)
    ref_h, ref_w = ref_tight.shape[:2]

    # Locate tight crop's top-left inside full sw_mirror_body canvas.
    ref_gray_sub = ref_crop[:, :, 3] > 96
    ry0, rx0 = np.where(ref_gray_sub)
    head_cut_y = min(sw_mirror_body.shape[0], top_y + int(round(fig_h * 0.255)))
    sub_tmp = sw_mirror_body[max(0, top_y - 36) : head_cut_y, :]
    _, sx_full = np.where(sub_tmp[:, :, 3] > 64)
    crop_x_off = max(0, int(sx_full.min()) - 36)
    crop_y_off = max(0, top_y - 36)
    tight_x0 = crop_x_off + int(rx0.min())
    tight_y0 = crop_y_off + int(ry0.min())

    # Match lower 42% (collar, straps, pauldrons, chest cutout) using normalized gradients + luma.
    y_band0 = int(round(ref_h * 0.56))
    y_band1 = int(round(ref_h * 0.94))
    pad = 40
    ref_zone_bgr = composite_on_bg(ref_tight, (128, 128, 128))
    ref_gray = cv2.cvtColor(ref_zone_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    tpl = ref_gray[y_band0:y_band1, :]
    tpl_mask = (ref_tight[y_band0:y_band1, :, 3] > 128).astype(np.float32)

    nom_scale = float(ref_h) / float(sw_bust_tight.shape[0])
    best_score = -1.0
    best_scale = nom_scale
    best_loc = (pad, pad + y_band0)

    for s in np.linspace(nom_scale * 0.90, nom_scale * 1.12, 45):
        nw = max(16, int(round(sw_bust_tight.shape[1] * float(s))))
        nh = max(16, int(round(sw_bust_tight.shape[0] * float(s))))
        cand = _premultiplied_resize(sw_bust_tight, nw, nh)
        cand_bgr = composite_on_bg(cand, (128, 128, 128))
        cand_gray = cv2.cvtColor(cand_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
        search = np.full((nh + 2 * pad, nw + 2 * pad), 128.0, dtype=np.float32)
        search[pad : pad + nh, pad : pad + nw] = cand_gray
        if search.shape[0] <= tpl.shape[0] or search.shape[1] <= tpl.shape[1]:
            continue
        res = cv2.matchTemplate(search, tpl, cv2.TM_CCORR_NORMED, mask=tpl_mask)
        res = np.nan_to_num(res, nan=-1.0, posinf=-1.0, neginf=-1.0)
        _, max_val, _, max_pt = cv2.minMaxLoc(res)
        if max_val > best_score:
            best_score = float(max_val)
            best_scale = float(s)
            best_loc = (int(max_pt[0]), int(max_pt[1]))

    # `max_pt` corresponds to `tpl` top-left `(0, y_band0)` inside `search` `(pad, pad)` coords:
    # ref_tight(0,0) aligns at cand_x = max_pt[0] - pad, cand_y = max_pt[1] - pad - y_band0.
    nw = max(16, int(round(sw_bust_tight.shape[1] * best_scale)))
    nh = max(16, int(round(sw_bust_tight.shape[0] * best_scale)))
    sw_bust_scaled = _premultiplied_resize(sw_bust_tight, nw, nh)
    paste_x = tight_x0 - (best_loc[0] - pad)
    paste_y = tight_y0 - (best_loc[1] - pad - y_band0)
    return sw_bust_scaled, best_scale, (paste_x, paste_y, nw, nh)


def _splice_sw_bust_onto_body(
    sw_bust_scaled: np.ndarray,
    sw_mirror_body: np.ndarray,
    rect_xywh: tuple[int, int, int, int],
) -> np.ndarray:
    """Splice SW head+collar cleanly onto mirrored SE body with zero old-hair ghost."""
    px, py, nw, nh = rect_xywh
    h_canvas, w_canvas = sw_mirror_body.shape[:2]

    head_layer = np.zeros_like(sw_mirror_body)
    dx0, dy0 = max(0, px), max(0, py)
    dx1, dy1 = min(w_canvas, px + nw), min(h_canvas, py + nh)
    sx0, sy0 = dx0 - px, dy0 - py
    sx1, sy1 = sx0 + (dx1 - dx0), sy0 + (dy1 - dy0)
    head_layer[dy0:dy1, dx0:dx1] = sw_bust_scaled[sy0:sy1, sx0:sx1]

    # Clear old SE-mirrored head & dangling front hair locks down to pauldron ridge line.
    ys_h, _ = np.where(head_layer[:, :, 3] > 128)
    head_top = int(ys_h.min())
    head_bot = int(ys_h.max())
    bh = max(1, head_bot - head_top)
    clear_cut_y = head_top + int(round(bh * 0.72))
    seam_y0 = head_top + int(round(bh * 0.73))
    seam_y1 = head_top + int(round(bh * 0.86))

    body_clean = sw_mirror_body.copy()
    body_clean[:clear_cut_y, :] = 0

    out = body_clean.copy()
    head_fg = head_layer[:, :, 3] > 0
    body_fg = body_clean[:, :, 3] > 0

    # Above seam_y0: 100% pure SW head + turtleneck; in [seam_y0..seam_y1]: smooth vertical blend.
    yy = np.arange(h_canvas, dtype=np.float32)[:, None]
    w_head = np.clip((seam_y1 - yy) / max(1.0, float(seam_y1 - seam_y0)), 0.0, 1.0)
    w_head = 0.5 - 0.5 * np.cos(w_head * np.pi)

    ha = head_layer[:, :, 3:4].astype(np.float32) / 255.0
    ba = body_clean[:, :, 3:4].astype(np.float32) / 255.0
    hrgb = head_layer[:, :, :3].astype(np.float32)
    brgb = body_clean[:, :, :3].astype(np.float32)

    both = head_fg & body_fg
    only_head = head_fg & (~body_fg)

    # Where only SW exists above seam_y1 (hair/neck/shoulder cap), copy SW directly.
    only_head_keep = only_head & (yy <= float(seam_y1))
    out[only_head_keep] = head_layer[only_head_keep]

    w3 = np.repeat(w_head[:, :, None], 3, axis=2)
    blended_rgb = np.clip(np.round(hrgb * w3 + brgb * (1.0 - w3)), 0, 255).astype(np.uint8)
    blended_a = np.clip(np.round((ha * w3[:, :, :1] + ba * (1.0 - w3[:, :, :1])) * 255.0), 0, 255).astype(np.uint8)

    out[both, :3] = blended_rgb[both]
    out[both, 3] = np.maximum(body_clean[both, 3], blended_a[both, 0])

    # Remove tiny leftover body dust above clear_cut_y or outside continuous torso.
    fg_bin = (out[:, :, 3] > 64).astype(np.uint8)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(fg_bin)
    if n_cc > 2:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        out[lbl != largest] = 0

    return alpha_bleed_and_defringe(out)


def _normalize_hires_head_cell(
    bust_tight: np.ndarray,
    target_bust_h: int,
) -> np.ndarray:
    """Place a cleaned bust scaled to target_bust_h onto a canonical 1024x1024 transparent tile."""
    cur_h, cur_w = bust_tight.shape[:2]
    scale = float(target_bust_h) / float(max(1, cur_h))
    nw = max(1, int(round(cur_w * scale)))
    nh = max(1, target_bust_h)
    max_inner = HIRES_HEAD_CANVAS - 48
    if nw > max_inner or nh > max_inner:
        clamp = min(max_inner / float(nw), max_inner / float(nh))
        nw = max(1, int(round(nw * clamp)))
        nh = max(1, int(round(nh * clamp)))
    scaled = bust_tight if (nw == cur_w and nh == cur_h) else _premultiplied_resize(bust_tight, nw, nh)

    canvas = np.zeros((HIRES_HEAD_CANVAS, HIRES_HEAD_CANVAS, 4), dtype=np.uint8)
    fg = scaled[:, :, 3] > 128
    _, fxs = np.where(fg)
    med_x = int(round(float(np.median(fxs)))) if fxs.size > 0 else (nw // 2)
    ox = max(8, min(HIRES_HEAD_CANVAS - nw - 8, (HIRES_HEAD_CANVAS // 2) - med_x))
    oy = max(8, HIRES_HEAD_CANVAS - HIRES_HEAD_BOTTOM_PAD - nh)
    canvas[oy : oy + nh, ox : ox + nw] = scaled
    return alpha_bleed_and_defringe(canvas)


def run_sw_and_8dir_processing(work_dir: Path) -> dict[str, Any]:
    """Extract 8 hi-res heads, build SW full body, and emit complete 8-direction sheets."""
    raw_path = work_dir / "00_raw" / "sheet_heads_4x2_sw_raw.jpg"
    up_path = work_dir / "01_upscayl_4x" / "sheet_heads_4x2_sw_4x.png"
    run_upscayl_4x(raw_path, up_path)

    up_bgr = cv2.imread(str(up_path))
    if up_bgr is None:
        raise FileNotFoundError(f"Failed to read {up_path}")

    row_bounds, col_bounds, bg_bgr = _find_4x2_splits(up_bgr)

    from rembg import new_session

    isnet_session = new_session("isnet-anime")
    raw_busts: dict[str, np.ndarray] = {}
    head_holes: dict[str, int] = {}

    try:
        for r, r_keys in enumerate(HEAD_4X2_SOURCE_GRID):
            y0, y1 = row_bounds[r], row_bounds[r + 1]
            for c, key in enumerate(r_keys):
                x0, x1 = col_bounds[c], col_bounds[c + 1]
                sub = up_bgr[y0:y1, x0:x1]
                clean_bgra, holes = extract_clean_pose_rgba(sub, bg_bgr, isnet_session)
                clean_bgra = _scrub_enclosed_pocket_rims(clean_bgra, sub, bg_bgr)
                raw_busts[key] = _tight_crop_bgra(clean_bgra)
                head_holes[key] = holes
    finally:
        del isnet_session
        clear_vram()

    # 1. Measure body-locked scale of SW against mirrored SE torso, and build full-body sw.png
    se_native = cv2.imread(str(work_dir / "02_poses_native_rgba" / "se.png"), cv2.IMREAD_UNCHANGED)
    if se_native is None:
        raise FileNotFoundError("Missing 02_poses_native_rgba/se.png")
    sw_mirror_body = cv2.flip(se_native, 1)

    sw_bust_for_body, sw_body_scale, rect_xywh = _register_sw_bust_to_mirror_body(raw_busts["sw"], sw_mirror_body)
    sw_spliced = _splice_sw_bust_onto_body(sw_bust_for_body, sw_mirror_body, rect_xywh)

    sw_native, n_rect = place_aligned_pose(sw_spliced, NATIVE_CELL_W, NATIVE_CELL_H, NATIVE_BOTTOM_Y, target_height=None)
    sw_canon, c_rect = place_aligned_pose(sw_spliced, CANONICAL_W, CANONICAL_H, CANONICAL_BOTTOM_Y, target_height=CANONICAL_BODY_H)

    # Save SW full body variants + close-up seam audit + native-scale head crop
    cv2.imwrite(str(work_dir / "02_poses_native_rgba" / "sw.png"), sw_native)
    cv2.imwrite(str(work_dir / "02_poses_native_gray80" / "sw.png"), composite_on_bg(sw_native, (128, 128, 128)))
    cv2.imwrite(str(work_dir / "02_poses_native_white" / "sw.png"), composite_on_bg(sw_native, (255, 255, 255)))
    cv2.imwrite(str(work_dir / "02_poses_canonical_1560x1680" / "sw_rgba_1560x1680.png"), sw_canon)
    cv2.imwrite(
        str(work_dir / "02_poses_canonical_1560x1680" / "sw_white_1560x1680.png"),
        composite_on_bg(sw_canon, (255, 255, 255)),
    )

    prep_dir = work_dir / "04_mask_prep_ready"
    heads_crops_dir = prep_dir / "heads_crops"
    sw_head_native = crop_head_from_pose(sw_native)
    cv2.imwrite(str(heads_crops_dir / "head_sw_rgba.png"), sw_head_native)
    cv2.imwrite(str(heads_crops_dir / "head_sw_gray80.png"), composite_on_bg(sw_head_native, (128, 128, 128)))

    # 2. Export normalized 1024x1024 Hi-Res 8-direction heads + CELL_KEYS-ordered 4x2 sheets
    hires_dir = prep_dir / "heads_8dir_hires"
    for sub in ("rgba", "gray80", "white"):
        (hires_dir / sub).mkdir(parents=True, exist_ok=True)

    # Reference scale: use exact measured body-matched native crop heights so all 8 hi-res busts match 1:1
    hires_heads: dict[str, np.ndarray] = {}
    for k in COMPASS_8_ORDER:
        body_crop = cv2.imread(str(heads_crops_dir / f"head_{k}_rgba.png"), cv2.IMREAD_UNCHANGED)
        body_fg_ys, _ = np.where(body_crop[:, :, 3] > 96)
        native_bust_h = int(body_fg_ys.max()) - int(body_fg_ys.min()) + 1
        target_bust_h = int(round(float(native_bust_h) * HIRES_SCALE_REF))
        tile = _normalize_hires_head_cell(raw_busts[k], target_bust_h)
        hires_heads[k] = tile
        cv2.imwrite(str(hires_dir / "rgba" / f"head_{k}_1024.png"), tile)
        cv2.imwrite(str(hires_dir / "gray80" / f"head_{k}_1024.png"), composite_on_bg(tile, (128, 128, 128)))
        cv2.imwrite(str(hires_dir / "white" / f"head_{k}_1024.png"), composite_on_bg(tile, (255, 255, 255)))

    rows_rgba = [np.hstack([hires_heads[dir_key] for dir_key, _ in row]) for row in HEAD_CELL_KEYS_MAP]
    sheet_heads_rgba = np.vstack(rows_rgba)
    cv2.imwrite(str(hires_dir / "sheet_heads_8dir_hires_4x2_rgba.png"), sheet_heads_rgba)
    cv2.imwrite(str(hires_dir / "sheet_heads_8dir_hires_4x2_gray80.png"), composite_on_bg(sheet_heads_rgba, (128, 128, 128)))
    cv2.imwrite(str(hires_dir / "sheet_heads_8dir_hires_4x2_white.png"), composite_on_bg(sheet_heads_rgba, (255, 255, 255)))

    # 3. Rebuild complete 8-direction body compass strips, paint templates & SW id_mask starter
    poses_native: dict[str, np.ndarray] = {}
    poses_canon: dict[str, np.ndarray] = {}
    for k in COMPASS_8_ORDER:
        poses_native[k] = cv2.imread(str(work_dir / "02_poses_native_rgba" / f"{k}.png"), cv2.IMREAD_UNCHANGED)
        poses_canon[k] = cv2.imread(str(work_dir / "02_poses_canonical_1560x1680" / f"{k}_rgba_1560x1680.png"), cv2.IMREAD_UNCHANGED)

    sheets_dir = work_dir / "03_sheets_aligned"
    compass_8_rgba = np.hstack([poses_native[k] for k in COMPASS_8_ORDER])
    cv2.imwrite(str(sheets_dir / "sheet_8dir_compass_rgba.png"), compass_8_rgba)
    cv2.imwrite(str(sheets_dir / "sheet_8dir_compass_gray80.png"), composite_on_bg(compass_8_rgba, (128, 128, 128)))
    cv2.imwrite(str(sheets_dir / "sheet_8dir_compass_white.png"), composite_on_bg(compass_8_rgba, (255, 255, 255)))
    cv2.imwrite(str(sheets_dir / "sheet_8dir_alignment_audit.png"), draw_alignment_audit_sheet(poses_native, COMPASS_8_ORDER))

    canon_8_white = [composite_on_bg(poses_canon[k], (255, 255, 255)) for k in COMPASS_8_ORDER]
    cv2.imwrite(str(prep_dir / "parts5_paint_template_8dir_white.png"), np.hstack(canon_8_white))

    # Refresh SW id_mask starter + full 8-dir id_mask strip
    draft_dir = prep_dir / "id_mask_auto_draft"
    ink_dir = prep_dir / "ink_barrier_audit"
    sw_vis, sw_id = build_auto_id_mask_draft(poses_canon["sw"], ink_dir / "sw_ink_audit.png")
    cv2.imwrite(str(draft_dir / "sw_id_mask_paint_draft.png"), sw_vis)
    cv2.imwrite(str(draft_dir / "sw_id_mask_shader_raw.png"), sw_id)
    draft_8_cols = [cv2.imread(str(draft_dir / f"{k}_id_mask_paint_draft.png")) for k in COMPASS_8_ORDER]
    cv2.imwrite(str(draft_dir / "id_mask_draft_8dir_strip.png"), np.hstack(draft_8_cols))

    # Update metrics_and_audit.json so 8/8 complete is recorded cleanly
    audit_path = work_dir / "metrics_and_audit.json"
    audit_data: dict[str, Any] = json.loads(audit_path.read_text(encoding="utf-8")) if audit_path.exists() else {}
    sw_metrics = compute_pose_metrics(sw_native, "sw", "head_4x2_splice_on_mirror_se", 2, head_holes["sw"]).__dict__
    existing_metrics = [m for m in audit_data.get("pose_metrics", []) if m.get("name") != "sw"]
    existing_metrics.append(sw_metrics)
    audit_data["unique_directions"] = list(COMPASS_8_ORDER)
    audit_data["missing_directions"] = []
    audit_data["notes"] = "All 8 cardinal + diagonal bodies (S, SE, E, NE, N, NW, W, SW) and 8 hi-res 1024x1024 heads complete."
    audit_data.setdefault("placements", {}).setdefault("native", {})["sw"] = list(n_rect)
    audit_data.setdefault("placements", {}).setdefault("canonical", {})["sw"] = list(c_rect)
    audit_data["pose_metrics"] = existing_metrics
    audit_data["hires_heads"] = {
        "cell_size": [HIRES_HEAD_CANVAS, HIRES_HEAD_CANVAS],
        "cell_keys_4x2": [list(row) for row in HEAD_CELL_KEYS_MAP],
        "sw_splice_scale": round(sw_body_scale, 4),
        "head_holes_removed_px": head_holes,
    }
    audit_path.write_text(json.dumps(audit_data, indent=2) + "\n", encoding="utf-8")
    return audit_data


def main() -> int:
    parser = argparse.ArgumentParser(description="Process SW + all 8 hi-res heads and complete 8-dir bodies.")
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK_DIR)
    args = parser.parse_args()

    result = run_sw_and_8dir_processing(args.work_dir)
    print(
        f"Complete 8-dir asset set ready: directions={result['unique_directions']}, "
        f"missing={result['missing_directions']}, sw_splice_scale={result['hires_heads']['sw_splice_scale']}"
    )
    print(f"Hires heads holes removed: {result['hires_heads']['head_holes_removed_px']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
