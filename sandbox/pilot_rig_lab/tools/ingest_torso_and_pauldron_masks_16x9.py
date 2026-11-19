#!/usr/bin/env python3
"""Ingest AI-generated 16:9 full-torso (armpit-filled + larger pauldrons) & mask sheets into 1560x1680."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from polish_outlines import alpha_bleed_only  # noqa: E402
from rig_v2_lib.constants import (  # noqa: E402
    DEFAULT_SOURCE_DIR,
    DIRECTIONS,
    PX_H,
    PX_W,
)
from rig_v2_lib.heads_builder import _compute_body_neck_cut  # noqa: E402
from prepare_ai_mask_workspaces import _canonical_rgba_path  # noqa: E402

TORSO_SHEET = (
    Path(__file__).resolve().parent.parent
    / "source_refs"
    / "valentina_v2_8dir"
    / "05_mask_ai_workspaces"
    / "manual_fix_overlays"
    / "06_torso_and_leg_e_16x9"
    / "06_torso_armpit_fill_16x9_upscayl.png"
)
MASK_SHEET = Path(
    r"C:\Users\Frani\.gemini\antigravity\brain\741e1e7a-0964-486e-a8bc-2c31d5d45bd1\.user_uploaded\media_1794726305665_2a4736d3.jpg"
)


def _extract_foreground_from_white(slot_bgr: np.ndarray) -> np.ndarray:
    """Flood-fill exterior near-white background to alpha=0, preserving interior whites/highlights."""
    h, w = slot_bgr.shape[:2]
    gray = cv2.cvtColor(slot_bgr, cv2.COLOR_BGR2GRAY)
    sat = np.max(slot_bgr, axis=2).astype(np.int16) - np.min(slot_bgr, axis=2).astype(np.int16)
    near_white = (gray >= 238) & (sat <= 22)

    work = np.where(near_white, 255, 0).astype(np.uint8)
    ff_mask = np.zeros((h + 2, w + 2), np.uint8)
    for x in range(0, w, 4):
        if work[0, x] == 255 and ff_mask[1, x + 1] == 0:
            cv2.floodFill(work, ff_mask, (x, 0), 128)
        if work[h - 1, x] == 255 and ff_mask[h, x + 1] == 0:
            cv2.floodFill(work, ff_mask, (x, h - 1), 128)
    for y in range(0, h, 4):
        if work[y, 0] == 255 and ff_mask[y + 1, 1] == 0:
            cv2.floodFill(work, ff_mask, (0, y), 128)
        if work[y, w - 1] == 255 and ff_mask[y + 1, w] == 0:
            cv2.floodFill(work, ff_mask, (w - 1, y), 128)

    ext_bg = work == 128
    # Keep only main connected component (torso) to drop tiny JPEG speckles
    fg_bin = (~ext_bg).astype(np.uint8)
    num_lbl, labels, stats, _ = cv2.connectedComponentsWithStats(fg_bin, connectivity=8)
    if num_lbl > 1:
        best_lbl = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        fg_bin = (labels == best_lbl).astype(np.uint8)

    alpha = (fg_bin * 255).astype(np.uint8)
    kernel = np.ones((3, 3), np.uint8)
    edge = cv2.dilate(fg_bin, kernel, iterations=1) ^ cv2.erode(fg_bin, kernel, iterations=1)
    edge_soft = np.clip((246.0 - gray.astype(np.float32)) * (255.0 / 34.0), 0.0, 255.0).astype(np.uint8)
    alpha = np.where((edge > 0) & (fg_bin > 0), np.minimum(alpha, edge_soft), alpha)

    bgra = cv2.cvtColor(slot_bgr, cv2.COLOR_BGR2BGRA)
    bgra[:, :, 3] = alpha
    return bgra


def _align_torso_to_canvas(
    gen_bgra: np.ndarray,
    orig_rgba_full: np.ndarray,
    orig_mask_full: np.ndarray,
) -> tuple[np.ndarray, int, int]:
    """Align AI-edited torso to 1560x1680 canvas using the untouched lower 55% of orig_body_core."""
    ys, xs = np.where(orig_mask_full)
    ox0, oy0, ox1, oy1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    oh = oy1 - oy0

    anchor_y0 = oy0 + int(round(oh * 0.45))
    anchor_crop = orig_rgba_full[anchor_y0:oy1, ox0:ox1]
    anchor_mask = orig_mask_full[anchor_y0:oy1, ox0:ox1]

    af = anchor_mask.astype(np.float32)[:, :, None]
    anchor_w = np.clip(np.round(anchor_crop[:, :, :3].astype(np.float32) * af + 255.0 * (1.0 - af)), 0, 255).astype(np.uint8)

    gf = gen_bgra[:, :, 3:4].astype(np.float32) / 255.0
    gen_w = np.clip(np.round(gen_bgra[:, :, :3].astype(np.float32) * gf + 255.0 * (1.0 - gf)), 0, 255).astype(np.uint8)

    gh, gw = gen_w.shape[:2]
    ah, aw = anchor_w.shape[:2]
    best_x, best_y = 0, 0
    if gh >= ah and gw >= aw:
        res = cv2.matchTemplate(gen_w, anchor_w, cv2.TM_CCOEFF_NORMED)
        _, _, _, max_loc = cv2.minMaxLoc(res)
        best_x, best_y = int(max_loc[0]), int(max_loc[1])

    canvas_x0 = ox0 - best_x
    canvas_y0 = anchor_y0 - best_y

    placed = np.zeros((PX_H, PX_W, 4), dtype=np.uint8)
    sx0 = max(0, -canvas_x0)
    sy0 = max(0, -canvas_y0)
    dx0 = max(0, canvas_x0)
    dy0 = max(0, canvas_y0)
    cw = min(gw - sx0, PX_W - dx0)
    ch = min(gh - sy0, PX_H - dy0)
    if cw > 0 and ch > 0:
        placed[dy0 : dy0 + ch, dx0 : dx0 + cw] = gen_bgra[sy0 : sy0 + ch, sx0 : sx0 + cw]

    # Preserve soft top-neck alpha fade from original if it sits inside the neck top 14px
    placed = alpha_bleed_only(placed)
    return placed, canvas_x0, canvas_y0


def main() -> None:
    source_dir = DEFAULT_SOURCE_DIR
    ws_dir = source_dir / "05_mask_ai_workspaces"
    base_dir = ws_dir / "manual_fix_overlays" / "06_torso_and_leg_e_16x9"
    out_dir = base_dir / "ingested_1560x1680"
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads((base_dir / "torso_leg_manifest.json").read_text(encoding="utf-8"))
    meta = manifest["06_torso_armpit_fill_16x9"]
    mw, mh = [int(v) for v in meta["size"]]

    torso_sheet = cv2.imread(str(TORSO_SHEET), cv2.IMREAD_COLOR)
    mask_sheet = cv2.imread(str(MASK_SHEET), cv2.IMREAD_COLOR)
    if torso_sheet is None or mask_sheet is None:
        raise FileNotFoundError("Missing uploaded torso or mask sheet")
    if torso_sheet.shape[1] != mw or torso_sheet.shape[0] != mh:
        interp = cv2.INTER_AREA if mw < torso_sheet.shape[1] else cv2.INTER_LANCZOS4
        torso_sheet = cv2.resize(torso_sheet, (mw, mh), interpolation=interp)
    if mask_sheet.shape[1] != mw or mask_sheet.shape[0] != mh:
        mask_sheet = cv2.resize(mask_sheet, (mw, mh), interpolation=cv2.INTER_NEAREST)

    audit_tiles: list[np.ndarray] = []

    for slot in meta["slots"]:
        view = str(slot["view"])
        sx0, sy0, sw, sh = [int(v) for v in slot["slot_rect"]]
        torso_crop = torso_sheet[sy0 : sy0 + sh, sx0 : sx0 + sw]
        mask_crop = mask_sheet[sy0 : sy0 + sh, sx0 : sx0 + sw]

        ref_rgba = cv2.imread(str(_canonical_rgba_path(source_dir, view)), cv2.IMREAD_UNCHANGED)
        p5_mask = cv2.imread(str(ws_dir / "01_parts_5_despiece" / "split_results" / f"{view}_parts5_mask.png"))
        id_bgra = cv2.imread(str(ws_dir / "02_id_mask_bodies" / "split_results" / f"{view}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        part_masks, _ = _compute_body_neck_cut(p5_mask, id_bgra, ref_rgba)
        orig_mask = part_masks["body_core"]

        fg_torso = _extract_foreground_from_white(torso_crop)
        placed_torso, cx0, cy0 = _align_torso_to_canvas(fg_torso, ref_rgba, orig_mask)

        # Align green/red mask silhouette to placed_torso silhouette using template match on binary masks
        torso_bin = (placed_torso[:, :, 3] >= 128).astype(np.uint8) * 255
        # In mask_crop (BGR): green = G - max(R, B) > 40, body = (G > 40) | (R > 40)
        b_ch, g_ch, r_ch = cv2.split(mask_crop)
        green_bin = ((g_ch.astype(np.int16) - np.maximum(r_ch, b_ch).astype(np.int16)) > 40).astype(np.uint8)
        all_mask_bin = ((g_ch > 50) | (r_ch > 50)).astype(np.uint8) * 255

        # Keep largest component of all_mask_bin and tighten crop for template matching
        mys, mxs = np.where(all_mask_bin > 0)
        tys, txs = np.where(torso_bin > 0)
        placed_pauldron = np.zeros((PX_H, PX_W), dtype=np.uint8)
        if len(mys) > 0 and len(tys) > 0:
            my0, my1 = int(mys.min()), int(mys.max()) + 1
            mx0, mx1 = int(mxs.min()), int(mxs.max()) + 1
            m_tpl = all_mask_bin[my0:my1, mx0:mx1]
            g_tpl = (green_bin[my0:my1, mx0:mx1] * 255).astype(np.uint8)

            # Pad search region around torso_bin
            pad = 40
            sy_a = max(0, int(tys.min()) - pad)
            sy_b = min(PX_H, int(tys.max()) + 1 + pad)
            sx_a = max(0, int(txs.min()) - pad)
            sx_b = min(PX_W, int(txs.max()) + 1 + pad)
            search_roi = torso_bin[sy_a:sy_b, sx_a:sx_b]
            if search_roi.shape[0] >= m_tpl.shape[0] and search_roi.shape[1] >= m_tpl.shape[1]:
                res = cv2.matchTemplate(search_roi, m_tpl, cv2.TM_CCOEFF_NORMED)
                _, _, _, max_loc = cv2.minMaxLoc(res)
                dx = sx_a + int(max_loc[0])
                dy = sy_a + int(max_loc[1])
                mh_t, mw_t = g_tpl.shape[:2]
                placed_pauldron[dy : dy + mh_t, dx : dx + mw_t] = g_tpl
            else:
                # Fallback to direct canvas placement
                sx_p = max(0, -cx0)
                sy_p = max(0, -cy0)
                dx_p = max(0, cx0)
                dy_p = max(0, cy0)
                cw_p = min(sw - sx_p, PX_W - dx_p)
                ch_p = min(sh - sy_p, PX_H - dy_p)
                if cw_p > 0 and ch_p > 0:
                    placed_pauldron[dy_p : dy_p + ch_p, dx_p : dx_p + cw_p] = (green_bin[sy_p : sy_p + ch_p, sx_p : sx_p + cw_p] * 255).astype(np.uint8)

        # Clip pauldron mask cleanly to torso alpha and remove tiny specks
        placed_pauldron = np.where((placed_pauldron >= 128) & (placed_torso[:, :, 3] >= 64), 255, 0).astype(np.uint8)

        cv2.imwrite(str(out_dir / f"{view}_body_core.png"), placed_torso)
        cv2.imwrite(str(out_dir / f"{view}_pauldron_mask.png"), placed_pauldron)
        print(f"[TORSO] {view}_body_core.png + {view}_pauldron_mask.png (pauldron_px={int((placed_pauldron > 0).sum())})")

        # Audit tile
        ys, xs = np.where(placed_torso[:, :, 3] >= 64)
        if len(ys) > 0:
            ay0, ay1 = max(0, int(ys.min()) - 12), min(PX_H, int(ys.max()) + 12)
            ax0, ax1 = max(0, int(xs.min()) - 12), min(PX_W, int(xs.max()) + 12)
            sub = placed_torso[ay0:ay1, ax0:ax1]
            pm_sub = placed_pauldron[ay0:ay1, ax0:ax1] > 127
            tile = np.full((260, 220, 3), 240, dtype=np.uint8)
            sc = min(200 / max(sub.shape[1], 1), 220 / max(sub.shape[0], 1))
            nw = max(1, int(sub.shape[1] * sc))
            nh = max(1, int(sub.shape[0] * sc))
            rs = cv2.resize(sub, (nw, nh))
            rpm = cv2.resize(pm_sub.astype(np.uint8) * 255, (nw, nh), interpolation=cv2.INTER_NEAREST) > 127
            af = rs[:, :, 3:4].astype(np.float32) / 255.0
            rgb = rs[:, :, :3].astype(np.float32)
            rgb[rpm] = rgb[rpm] * 0.65 + np.array([40.0, 220.0, 60.0], dtype=np.float32) * 0.35
            ox = (220 - nw) // 2
            oy = 28
            roi = tile[oy : oy + nh, ox : ox + nw].astype(np.float32)
            tile[oy : oy + nh, ox : ox + nw] = np.clip(np.round(rgb * af + roi * (1.0 - af)), 0, 255).astype(np.uint8)
            cv2.putText(tile, view.upper(), (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (20, 20, 20), 2)
            audit_tiles.append(tile)

    if audit_tiles:
        grid = np.vstack([np.hstack(audit_tiles[:4]), np.hstack(audit_tiles[4:8])])
        audit_path = base_dir / "torso_pauldron_audit.png"
        cv2.imwrite(str(audit_path), grid)
        print(f"[AUDIT] {audit_path}")


if __name__ == "__main__":
    main()
