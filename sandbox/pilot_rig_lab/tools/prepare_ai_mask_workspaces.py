#!/usr/bin/env python3
"""Prepare grouped/blocked white-background image sheets and AI prompt guides for
mask generation (01..05), and re-split/align/mirror returned AI masks back into
per-view canonical masks (`--ingest`).

Usage:
  python prepare_ai_mask_workspaces.py --export
  python prepare_ai_mask_workspaces.py --ingest all
  python prepare_ai_mask_workspaces.py --ingest 01_parts_5_despiece
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from prepare_8dir_sheets import CANONICAL_H, CANONICAL_W, DEFAULT_WORK_DIR  # noqa: E402
from process_head_8dir_sheet import CELL_KEYS as HEAD_4X2_NAMES  # noqa: E402
from process_masked_5parts import _align_mask_to_ref, _place_on_canvas  # noqa: E402
from rig_v2_lib.mask_workspace_prompts import (  # noqa: E402
    _prompt_guide_01_parts5,
    _prompt_guide_02_id_bodies,
    _prompt_guide_03_id_heads,
    _prompt_guide_04_limb_anim,
    _prompt_guide_05_secondary_jiggle,
    _root_readme,
)

WORKSPACES_DIRNAME = "05_mask_ai_workspaces"
BASE_BODY_DIRS: tuple[str, ...] = ("s", "se", "e", "ne", "n")
ALL_8_DIRS: tuple[str, ...] = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
MIRROR_SOURCE_MAP: dict[str, str] = {"sw": "se", "w": "e", "nw": "ne"}
HEAD_4X2_DIRS: list[list[str]] = [
    ["s", "se", "sw", "w"],
    ["e", "ne", "nw", "n"],
]

FOLDER_KEYS: tuple[str, ...] = (
    "01_parts_5_despiece",
    "02_id_mask_bodies",
    "03_id_mask_heads",
    "04_limb_anim_masks",
    "05_secondary_jiggle_masks",
)

PARTS5_CANONICAL_BGR: dict[str, tuple[int, int, int]] = {
    "body_core": (0, 255, 0),
    "arm_r": (0, 0, 255),     # Red in RGB = (255, 0, 0)
    "arm_l": (255, 0, 0),     # Blue in RGB = (0, 0, 255)
    "leg_r": (0, 255, 255),   # Yellow in RGB = (255, 255, 0)
    "leg_l": (255, 0, 255),   # Magenta in RGB = (255, 0, 255)
}

IMAGE_EXTS: tuple[str, ...] = (".png", ".jpg", ".jpeg", ".webp")


@dataclass(frozen=True)
class BatchLayout:
    filename: str
    rows: int
    cols: int
    cell_w: int
    cell_h: int
    crop_x0: int
    views_grid: list[list[str]]
    description: str


def _canonical_rgba_path(work_dir: Path, view: str) -> Path:
    return work_dir / "02_poses_canonical_1560x1680" / f"{view}_rgba_1560x1680.png"


def _head_hires_rgba_path(work_dir: Path, view: str) -> Path:
    return work_dir / "04_mask_prep_ready" / "heads_8dir_hires" / "rgba" / f"head_{view}_1024.png"


def _head_hires_white_path(work_dir: Path, view: str) -> Path:
    return work_dir / "04_mask_prep_ready" / "heads_8dir_hires" / "white" / f"head_{view}_1024.png"


def _body_autodraft_path(work_dir: Path, view: str) -> Path:
    return work_dir / "04_mask_prep_ready" / "id_mask_auto_draft" / f"{view}_id_mask_paint_draft.png"


def _composite_rgba_on_white(rgba: np.ndarray) -> np.ndarray:
    alpha = rgba[:, :, 3:4].astype(np.float32) / 255.0
    fg = rgba[:, :, :3].astype(np.float32)
    white = np.full_like(fg, 255.0)
    return np.clip(fg * alpha + white * (1.0 - alpha), 0.0, 255.0).astype(np.uint8)


STD_CANVAS_H = 1728       # Exact LCM height supporting 16:9 (3072x1728) and 4:3 (2304x1728)
STD_16X9_3COL_W = 3072    # 1024 * 3 -> 3072 / 1728 = 16 / 9
STD_4X3_2COL_W = 2304     # 1152 * 2 -> 2304 / 1728 = 4 / 3
HEAD_4X2_CELL_W = 1024
HEAD_4X2_CELL_H = 1152    # 4096 x 2304 = 16 / 9


def _compute_union_body_bbox(work_dir: Path) -> tuple[int, int, int, int]:
    """Return tight union (x0, y0, x1, y1) across all 8 canonical body poses."""
    x0, y0, x1, y1 = CANONICAL_W, CANONICAL_H, 0, 0
    for view in ALL_8_DIRS:
        rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        if rgba is None:
            continue
        ys, xs = np.where(rgba[:, :, 3] > 20)
        if len(xs) == 0:
            continue
        x0 = min(x0, int(xs.min()))
        y0 = min(y0, int(ys.min()))
        x1 = max(x1, int(xs.max()) + 1)
        y1 = max(y1, int(ys.max()) + 1)
    return x0, y0, x1, y1


def _build_body_batch_image(
    work_dir: Path,
    views: list[str],
    cell_w: int,
    cell_h: int,
    body_y0: int,
    body_y1: int,
    source_fn: Callable[[str], np.ndarray],
) -> np.ndarray:
    cx = CANONICAL_W // 2
    crop_x0 = max(0, cx - cell_w // 2)
    body_h = body_y1 - body_y0
    dst_y0 = max(0, (cell_h - body_h) // 2)
    copy_h = min(body_h, cell_h - dst_y0)

    canvas = np.full((cell_h, cell_w * len(views), 3), 255, dtype=np.uint8)
    for idx, view in enumerate(views):
        img = source_fn(view)
        patch = img[body_y0 : body_y0 + copy_h, crop_x0 : crop_x0 + cell_w]
        canvas[dst_y0 : dst_y0 + copy_h, idx * cell_w : (idx + 1) * cell_w] = patch
    return canvas


def _build_head_batch_image(
    work_dir: Path,
    views_grid: list[list[str]],
    source_fn: Callable[[str], np.ndarray],
    cell_w: int = 1024,
    cell_h: int = 1024,
) -> np.ndarray:
    rows = len(views_grid)
    cols = len(views_grid[0])
    inner_size = min(cell_w, cell_h)
    pad_x = (cell_w - inner_size) // 2
    pad_y = (cell_h - inner_size) // 2
    canvas = np.full((rows * cell_h, cols * cell_w, 3), 255, dtype=np.uint8)
    for r, row_views in enumerate(views_grid):
        for c, view in enumerate(row_views):
            cell = source_fn(view)
            if cell.shape[:2] != (inner_size, inner_size):
                cell = cv2.resize(cell, (inner_size, inner_size), interpolation=cv2.INTER_AREA)
            y0 = r * cell_h + pad_y
            x0 = c * cell_w + pad_x
            canvas[y0 : y0 + inner_size, x0 : x0 + inner_size] = cell
    return canvas


def _build_head_paint_draft_rgb(work_dir: Path, view: str) -> np.ndarray:
    """Create a white-bg ink-locked heuristic head id_mask preview matching head specs."""
    rgba = cv2.imread(str(_head_hires_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
    h, w = rgba.shape[:2]
    bgr = rgba[:, :, :3]
    alpha = rgba[:, :, 3] > 28
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
    sat, val = hsv[:, :, 1], hsv[:, :, 2]

    b = bgr[:, :, 0].astype(np.float32)
    g = bgr[:, :, 1].astype(np.float32)
    r = bgr[:, :, 2].astype(np.float32)

    # Rich dark-crimson monocle/straps (rejects pale peach skin where g,b > 130)
    is_monocle_red = (r > np.maximum(g, b) * 1.48) & (g < 120) & (b < 120) & (r > 75)
    is_hair_silver = (sat <= 42) & (val >= 100)
    is_skin_warm = (r > b + 8) & (val >= 120) & (sat >= 22) & (~is_monocle_red)

    out = np.full((h, w, 3), 255, dtype=np.uint8)
    # Default foreground = Suit/Collar Blue (#0000FF -> BGR 255,0,0)
    out[alpha] = (255, 0, 0)
    out[alpha & is_hair_silver] = (255, 255, 0)  # Cyan
    out[alpha & is_skin_warm] = (0, 255, 0)      # Green
    out[alpha & is_monocle_red] = (0, 0, 255)    # Red

    # Dark outlines get filled by nearest non-dark label inside alpha
    valid_lbl = alpha & ((val >= 65) | is_monocle_red)
    if np.any(valid_lbl) and np.any(alpha & (~valid_lbl)):
        _, labels = cv2.distanceTransformWithLabels(
            (~valid_lbl).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
        )
        vy, vx = np.where(valid_lbl)
        uy, ux = np.where(alpha & (~valid_lbl))
        out[uy, ux] = out[vy[labels[uy, ux] - 1], vx[labels[uy, ux] - 1]]
    return out


def _write_layout_meta(folder: Path, mask_key: str, batches: list[BatchLayout]) -> None:
    payload = {
        "mask_key": mask_key,
        "batches": [
            {
                "filename": b.filename,
                "rows": b.rows,
                "cols": b.cols,
                "cell_w": b.cell_w,
                "cell_h": b.cell_h,
                "crop_x0": b.crop_x0,
                "views_grid": b.views_grid,
                "description": b.description,
            }
            for b in batches
        ],
    }
    (folder / "layout_meta.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _export_folder_skeleton(ws_root: Path, mask_key: str) -> Path:
    folder = ws_root / mask_key
    for sub in ("inputs", "masked_outputs", "split_results"):
        (folder / sub).mkdir(parents=True, exist_ok=True)
    # Remove stale PNGs in generated input folders only (preserve masked_outputs & split_results)
    for p in (folder / "inputs").glob("*.png"):
        p.unlink()
    draft_dir = folder / "python_auto_draft"
    if draft_dir.exists():
        for p in draft_dir.glob("*.png"):
            p.unlink()
    return folder


def export_workspaces(work_dir: Path) -> Path:
    ws_root = work_dir / WORKSPACES_DIRNAME
    ws_root.mkdir(parents=True, exist_ok=True)
    (ws_root / "README.md").write_text(_root_readme(), encoding="utf-8")

    bx0, by0, bx1, by1 = _compute_union_body_bbox(work_dir)
    cell_w_3 = STD_16X9_3COL_W // 3  # 1024 -> 3072 x 1728 (exact 16:9)
    cell_w_2 = STD_4X3_2COL_W // 2   # 1152 -> 2304 x 1728 (exact 4:3)
    crop_x0_3 = max(0, CANONICAL_W // 2 - cell_w_3 // 2)
    crop_x0_2 = max(0, CANONICAL_W // 2 - cell_w_2 // 2)

    body_white_fn: Callable[[str], np.ndarray] = lambda v: _composite_rgba_on_white(
        cv2.imread(str(_canonical_rgba_path(work_dir, v)), cv2.IMREAD_UNCHANGED)
    )

    def body_draft_fn(v: str) -> np.ndarray:
        draft = cv2.imread(str(_body_autodraft_path(work_dir, v)), cv2.IMREAD_COLOR)
        ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, v)), cv2.IMREAD_UNCHANGED)
        bg = ref_rgba[:, :, 3] <= 20
        draft[bg] = 255
        return draft

    body_batches = [
        BatchLayout(
            filename="batchA_S_SE_E_16x9_white.png",
            rows=1,
            cols=3,
            cell_w=cell_w_3,
            cell_h=STD_CANVAS_H,
            crop_x0=crop_x0_3,
            views_grid=[["s", "se", "e"]],
            description="3072x1728 (16:9) left->right: S (Front), SE (Front-Right 3/4), E (Right Profile)",
        ),
        BatchLayout(
            filename="batchB_NE_N_4x3_white.png",
            rows=1,
            cols=2,
            cell_w=cell_w_2,
            cell_h=STD_CANVAS_H,
            crop_x0=crop_x0_2,
            views_grid=[["ne", "n"]],
            description="2304x1728 (4:3) left->right: NE (Back-Right 3/4), N (Back)",
        ),
    ]

    # 01_parts_5_despiece
    f01 = _export_folder_skeleton(ws_root, "01_parts_5_despiece")
    for b in body_batches:
        img = _build_body_batch_image(work_dir, b.views_grid[0], b.cell_w, b.cell_h, by0, by1, body_white_fn)
        cv2.imwrite(str(f01 / "inputs" / b.filename), img)
    _write_layout_meta(f01, "01_parts_5_despiece", body_batches)
    (f01 / "PROMPT_GUIDE.md").write_text(_prompt_guide_01_parts5(), encoding="utf-8")

    # 02_id_mask_bodies (+ python_auto_draft mirrors)
    f02 = _export_folder_skeleton(ws_root, "02_id_mask_bodies")
    (f02 / "python_auto_draft").mkdir(parents=True, exist_ok=True)
    for b in body_batches:
        img = _build_body_batch_image(work_dir, b.views_grid[0], b.cell_w, b.cell_h, by0, by1, body_white_fn)
        cv2.imwrite(str(f02 / "inputs" / b.filename), img)
        draft_img = _build_body_batch_image(work_dir, b.views_grid[0], b.cell_w, b.cell_h, by0, by1, body_draft_fn)
        cv2.imwrite(str(f02 / "python_auto_draft" / b.filename.replace("_white.png", "_autodraft.png")), draft_img)
    _write_layout_meta(f02, "02_id_mask_bodies", body_batches)
    (f02 / "PROMPT_GUIDE.md").write_text(_prompt_guide_02_id_bodies(), encoding="utf-8")

    # 03_id_mask_heads (exact 1:1 2x2 batches + exact 16:9 4x2 sheet)
    f03 = _export_folder_skeleton(ws_root, "03_id_mask_heads")
    (f03 / "python_auto_draft").mkdir(parents=True, exist_ok=True)
    head_white_fn: Callable[[str], np.ndarray] = lambda v: cv2.imread(
        str(_head_hires_white_path(work_dir, v)), cv2.IMREAD_COLOR
    )
    head_draft_fn: Callable[[str], np.ndarray] = lambda v: _build_head_paint_draft_rgb(work_dir, v)

    head_batches = [
        BatchLayout(
            filename="batchA_front_2x2_1x1_white.png",
            rows=2,
            cols=2,
            cell_w=1024,
            cell_h=1024,
            crop_x0=0,
            views_grid=[["s", "se"], ["sw", "w"]],
            description="2048x2048 (1:1) grid: Row0=[S, SE], Row1=[SW, W]",
        ),
        BatchLayout(
            filename="batchB_back_2x2_1x1_white.png",
            rows=2,
            cols=2,
            cell_w=1024,
            cell_h=1024,
            crop_x0=0,
            views_grid=[["e", "ne"], ["nw", "n"]],
            description="2048x2048 (1:1) grid: Row0=[E, NE], Row1=[NW, N]",
        ),
        BatchLayout(
            filename="all8_4x2_16x9_white.png",
            rows=2,
            cols=4,
            cell_w=HEAD_4X2_CELL_W,
            cell_h=HEAD_4X2_CELL_H,
            crop_x0=0,
            views_grid=HEAD_4X2_DIRS,
            description="4096x2304 (16:9) grid: Row0=[S, SE, SW, W], Row1=[E, NE, NW, N]",
        ),
    ]
    for b in head_batches:
        img = _build_head_batch_image(work_dir, b.views_grid, head_white_fn, cell_w=b.cell_w, cell_h=b.cell_h)
        cv2.imwrite(str(f03 / "inputs" / b.filename), img)
        draft_img = _build_head_batch_image(work_dir, b.views_grid, head_draft_fn, cell_w=b.cell_w, cell_h=b.cell_h)
        cv2.imwrite(str(f03 / "python_auto_draft" / b.filename.replace("_white.png", "_autodraft.png")), draft_img)
    _write_layout_meta(f03, "03_id_mask_heads", head_batches)
    (f03 / "PROMPT_GUIDE.md").write_text(_prompt_guide_03_id_heads(), encoding="utf-8")

    # 04_limb_anim_masks
    f04 = _export_folder_skeleton(ws_root, "04_limb_anim_masks")
    for b in body_batches:
        img = _build_body_batch_image(work_dir, b.views_grid[0], b.cell_w, b.cell_h, by0, by1, body_white_fn)
        cv2.imwrite(str(f04 / "inputs" / b.filename), img)
    _write_layout_meta(f04, "04_limb_anim_masks", body_batches)
    (f04 / "PROMPT_GUIDE.md").write_text(_prompt_guide_04_limb_anim(), encoding="utf-8")

    # 05_secondary_jiggle_masks
    f05 = _export_folder_skeleton(ws_root, "05_secondary_jiggle_masks")
    sec_batches = [
        BatchLayout(
            filename="batchA_front_S_SE_4x3_white.png",
            rows=1,
            cols=2,
            cell_w=cell_w_2,
            cell_h=STD_CANVAS_H,
            crop_x0=crop_x0_2,
            views_grid=[["s", "se"]],
            description="2304x1728 (4:3) Front Bust left->right: S, SE (paint bust Cyan #00FFFF)",
        ),
        BatchLayout(
            filename="batchB_back_N_NE_4x3_white.png",
            rows=1,
            cols=2,
            cell_w=cell_w_2,
            cell_h=STD_CANVAS_H,
            crop_x0=crop_x0_2,
            views_grid=[["n", "ne"]],
            description="2304x1728 (4:3) Back Glutes left->right: N, NE (paint glutes Magenta #FF00FF)",
        ),
    ]
    for b in sec_batches:
        img = _build_body_batch_image(work_dir, b.views_grid[0], b.cell_w, b.cell_h, by0, by1, body_white_fn)
        cv2.imwrite(str(f05 / "inputs" / b.filename), img)
    _write_layout_meta(f05, "05_secondary_jiggle_masks", sec_batches)
    (f05 / "PROMPT_GUIDE.md").write_text(_prompt_guide_05_secondary_jiggle(), encoding="utf-8")

    return ws_root


# ---------------------------------------------------------------------------
# Ingest: adaptive grid splitter, IoU alignment, cleanup, and L/R symmetry
# ---------------------------------------------------------------------------

def _find_masked_file(masked_dir: Path, expected_png_name: str) -> Path | None:
    stem = Path(expected_png_name).stem
    candidates = (
        stem.replace("_white", "_mask"),
        stem.replace("_white", "_masked"),
        stem,
        stem.replace("_white", ""),
        stem.replace("_white", "_autodraft"),
    )
    for candidate_stem in candidates:
        for ext in IMAGE_EXTS:
            p = masked_dir / f"{candidate_stem}{ext}"
            if p.exists():
                return p
    return None


def _nonwhite_fg_mask(bgr: np.ndarray) -> np.ndarray:
    """Return foreground boolean mask excluding pure/off-white background (#FFFFFF)."""
    cmin = np.min(bgr, axis=2)
    cmax = np.max(bgr, axis=2)
    sat_diff = cmax.astype(np.int16) - cmin.astype(np.int16)
    return (cmin < 218) | (sat_diff > 36)


def _split_grid_cells(sheet_bgr: np.ndarray, rows: int, cols: int) -> list[list[np.ndarray]]:
    """Slice sheet_bgr into rows x cols cells, refining column & row cuts along white gutters."""
    h, w = sheet_bgr.shape[:2]
    fg = _nonwhite_fg_mask(sheet_bgr)

    y_cuts = [0]
    if rows > 1:
        row_sums = fg.sum(axis=1)
        for r in range(1, rows):
            nom = int(round(h * r / rows))
            rad = max(8, int(h * 0.08))
            y0, y1 = max(1, nom - rad), min(h - 1, nom + rad)
            best_y = y0 + int(np.argmin(row_sums[y0:y1]))
            y_cuts.append(best_y)
    y_cuts.append(h)

    grid: list[list[np.ndarray]] = []
    for r in range(rows):
        ry0, ry1 = y_cuts[r], y_cuts[r + 1]
        col_sums = fg[ry0:ry1, :].sum(axis=0)
        x_cuts = [0]
        for c in range(1, cols):
            nom = int(round(w * c / cols))
            rad = max(8, int(w * (0.14 / max(cols, 1))))
            x0, x1 = max(1, nom - rad), min(w - 1, nom + rad)
            best_x = x0 + int(np.argmin(col_sums[x0:x1]))
            x_cuts.append(best_x)
        x_cuts.append(w)
        grid.append([sheet_bgr[ry0:ry1, x_cuts[c] : x_cuts[c + 1]] for c in range(cols)])
    return grid


def _strip_speck_ccs(mask: np.ndarray, min_area: int = 300) -> np.ndarray:
    """Remove tiny isolated AI/JPEG dust specks before bounding-box alignment."""
    total_fg = int(mask.sum())
    if total_fg == 0:
        return mask
    thresh = min(min_area, max(1, total_fg // 20))
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8))
    if n_cc <= 2:
        return mask
    kept = np.zeros_like(mask, dtype=bool)
    for cc in range(1, n_cc):
        if int(stats[cc, cv2.CC_STAT_AREA]) >= thresh:
            kept |= (lbl == cc)
    return kept if np.any(kept) else mask


def _mirror_aligned_canvas(
    src_canvas: np.ndarray,
    src_ref_alpha: np.ndarray,
    dst_ref_alpha: np.ndarray,
    bg_val: int | tuple[int, ...],
    voronoi_fill: bool = True,
) -> np.ndarray:
    """Flip src_canvas horizontally, lock onto dst_ref_alpha by IoU translation, and Voronoi-fill edge gaps."""
    flipped = np.fliplr(src_canvas).copy()
    flip_alpha = np.fliplr(src_ref_alpha)
    th, tw = dst_ref_alpha.shape[:2]

    ys_s, xs_s = np.where(flip_alpha)
    ys_d, xs_d = np.where(dst_ref_alpha)
    if len(xs_s) > 0 and len(xs_d) > 0:
        cx_s, cy_s = 0.5 * (xs_s.min() + xs_s.max()), 0.5 * (ys_s.min() + ys_s.max())
        cx_d, cy_d = 0.5 * (xs_d.min() + xs_d.max()), 0.5 * (ys_d.min() + ys_d.max())
        base_dx = int(round(cx_d - cx_s))
        base_dy = int(round(cy_d - cy_s))
        ds = 4
        sw, sh = max(32, tw // ds), max(32, th // ds)
        fa_s = cv2.resize(flip_alpha.astype(np.uint8), (sw, sh), interpolation=cv2.INTER_NEAREST) > 0
        da_s = cv2.resize(dst_ref_alpha.astype(np.uint8), (sw, sh), interpolation=cv2.INTER_NEAREST) > 0
        best_iou = -1.0
        best_d = (base_dx, base_dy)
        for dy in range(base_dy - 12, base_dy + 13, 4):
            for dx in range(base_dx - 24, base_dx + 25, 4):
                m = np.float32([[1, 0, dx / float(ds)], [0, 1, dy / float(ds)]])
                shifted_a = cv2.warpAffine(fa_s.astype(np.uint8), m, (sw, sh), flags=cv2.INTER_NEAREST) > 0
                inter = int((shifted_a & da_s).sum())
                union = int((shifted_a | da_s).sum())
                iou = float(inter) / max(1.0, float(union))
                if iou > best_iou:
                    best_iou = iou
                    best_d = (dx, dy)
        # Fine 1px polish around best coarse shift
        cx0, cy0 = best_d
        best_iou = -1.0
        for dy in range(cy0 - 2, cy0 + 3, 1):
            for dx in range(cx0 - 2, cx0 + 3, 1):
                m = np.float32([[1, 0, dx], [0, 1, dy]])
                shifted_a = cv2.warpAffine(flip_alpha.astype(np.uint8), m, (tw, th), flags=cv2.INTER_NEAREST) > 0
                inter = int((shifted_a & dst_ref_alpha).sum())
                union = int((shifted_a | dst_ref_alpha).sum())
                iou = float(inter) / max(1.0, float(union))
                if iou > best_iou:
                    best_iou = iou
                    best_d = (dx, dy)
        m_best = np.float32([[1, 0, best_d[0]], [0, 1, best_d[1]]])
        shifted = cv2.warpAffine(
            flipped,
            m_best,
            (tw, th),
            flags=cv2.INTER_NEAREST,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=bg_val,
        )
        valid_src = (
            cv2.warpAffine(flip_alpha.astype(np.uint8), m_best, (tw, th), flags=cv2.INTER_NEAREST) > 0
        ) & dst_ref_alpha
    else:
        shifted = flipped
        valid_src = flip_alpha & dst_ref_alpha

    if voronoi_fill and np.any(valid_src):
        missing = dst_ref_alpha & (~valid_src)
        if np.any(missing):
            _, labels = cv2.distanceTransformWithLabels(
                (~valid_src).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            oy, ox = np.where(valid_src)
            my, mx = np.where(missing)
            idx = labels[my, mx] - 1
            shifted[my, mx] = shifted[oy[idx], ox[idx]]

    shifted[~dst_ref_alpha] = bg_val
    return shifted


def _align_cell_to_ref_alpha(cell_bgr: np.ndarray, ref_alpha: np.ndarray, scale_down_for_iou: int = 3) -> np.ndarray:
    """Align cell_bgr foreground bbox onto ref_alpha canvas (H, W) with aspect-drift tolerance."""
    th, tw = ref_alpha.shape[:2]
    fg = _strip_speck_ccs(_nonwhite_fg_mask(cell_bgr))
    ys, xs = np.where(fg)
    if len(xs) == 0:
        return np.full((th, tw, 3), 255, dtype=np.uint8)

    my0, my1 = int(ys.min()), int(ys.max()) + 1
    mx0, mx1 = int(xs.min()), int(xs.max()) + 1
    crop_bgr = cell_bgr[my0:my1, mx0:mx1]
    crop_fg = fg[my0:my1, mx0:mx1]
    ch, cw = crop_fg.shape[:2]

    if scale_down_for_iou > 1:
        sw, sh = max(32, tw // scale_down_for_iou), max(32, th // scale_down_for_iou)
        ref_small = cv2.resize(ref_alpha.astype(np.uint8), (sw, sh), interpolation=cv2.INTER_NEAREST) > 0
        ox_s, oy_s, sc_s = _align_mask_to_ref(crop_fg, ref_small)
    else:
        sw, sh = tw, th
        ref_small = ref_alpha
        ox_s, oy_s, sc_s = _align_mask_to_ref(crop_fg, ref_small)

    # Fine search across mild +/-4% horizontal aspect drift + 2px translation on ref_small
    crop_u8 = crop_fg.astype(np.uint8) * 255
    best_iou = -1.0
    best_params = (ox_s, oy_s, sc_s, sc_s)
    for ar_mul in (0.96, 0.98, 1.0, 1.02, 1.04):
        sx = sc_s * ar_mul
        sy = sc_s
        nw_s = max(4, int(round(cw * sx)))
        nh_s = max(4, int(round(ch * sy)))
        res = cv2.resize(crop_u8, (nw_s, nh_s), interpolation=cv2.INTER_NEAREST) > 127
        dx_c = int(round((cw * sc_s - nw_s) * 0.5))
        for dy in (-2, 0, 2):
            for dx in (-2, 0, 2):
                ox_t = ox_s + dx_c + dx
                oy_t = oy_s + dy
                px0, py0 = max(0, ox_t), max(0, oy_t)
                px1, py1 = min(sw, ox_t + nw_s), min(sh, oy_t + nh_s)
                if px1 <= px0 or py1 <= py0:
                    continue
                m_sub = res[py0 - oy_t : py1 - oy_t, px0 - ox_t : px1 - ox_t]
                r_sub = ref_small[py0:py1, px0:px1]
                inter = int((m_sub & r_sub).sum())
                union = int(res.sum() + ref_small.sum() - inter)
                iou = float(inter) / max(1.0, float(union))
                if iou > best_iou:
                    best_iou = iou
                    best_params = (ox_t, oy_t, sx, sy)

    ox = best_params[0] * scale_down_for_iou
    oy = best_params[1] * scale_down_for_iou
    nw = max(4, int(round(cw * best_params[2] * float(scale_down_for_iou))))
    nh = max(4, int(round(ch * best_params[3] * float(scale_down_for_iou))))
    placed = _place_on_canvas(crop_bgr, nw, nh, ox, oy, tw, th, cv2.INTER_NEAREST)
    crop_fg_bgr = cv2.cvtColor(crop_u8, cv2.COLOR_GRAY2BGR)
    placed_fg = _place_on_canvas(crop_fg_bgr, nw, nh, ox, oy, tw, th, cv2.INTER_NEAREST)[:, :, 0] > 127
    placed[~placed_fg] = 255
    return placed


def _prune_small_islands_and_outliers(
    best_idx: np.ndarray,
    ref_alpha: np.ndarray,
    num_classes: int,
    min_island_px: int,
) -> np.ndarray:
    """Remove tiny AI/JPEG seam-blend islands & 1px noise dots, reassigning via nearest valid label."""
    h, w = ref_alpha.shape[:2]
    clean_idx = best_idx.copy()

    # 1. Remove isolated small connected components per class
    if min_island_px > 0:
        valid_surviving = np.zeros((h, w), dtype=bool)
        for cls_i in range(num_classes):
            m = (ref_alpha & (clean_idx == cls_i)).astype(np.uint8)
            n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(m)
            for cc in range(1, n_cc):
                if int(stats[cc, cv2.CC_STAT_AREA]) >= min_island_px:
                    valid_surviving |= (lbl == cc)
        need_fill = ref_alpha & (~valid_surviving)
        if np.any(valid_surviving) and np.any(need_fill):
            _, labels = cv2.distanceTransformWithLabels(
                (~valid_surviving).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            vy, vx = np.where(valid_surviving)
            fy, fx = np.where(need_fill)
            clean_idx[fy, fx] = clean_idx[vy[labels[fy, fx] - 1], vx[labels[fy, fx] - 1]]

    # 2. Categorical 3x3 outlier pass: replace single isolated pixels where >= 6 of 8 neighbors agree
    padded = np.pad(np.where(ref_alpha, clean_idx, -1), 1, mode="constant", constant_values=-1)
    votes = np.zeros((num_classes, h, w), dtype=np.uint8)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            nbr = padded[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
            for cls_i in range(num_classes):
                votes[cls_i] += (nbr == cls_i).astype(np.uint8)
    top_votes = votes.max(axis=0)
    top_cls = np.argmax(votes, axis=0)
    outlier = ref_alpha & (top_cls != clean_idx) & (top_votes >= 6)
    clean_idx[outlier] = top_cls[outlier]
    return clean_idx


def _nearest_palette_quantize(
    aligned_bgr: np.ndarray,
    ref_alpha: np.ndarray,
    palette_bgr: dict[str, tuple[int, int, int]],
    valid_pixel_mask: np.ndarray | None = None,
    min_island_px: int = 24,
) -> dict[str, np.ndarray]:
    """Snap ref_alpha pixels to pure palette_bgr colors, stripping AI JPEG ringing & blend seams."""
    fg_raw = _nonwhite_fg_mask(aligned_bgr)
    names = list(palette_bgr.keys())
    colors = np.array([palette_bgr[k] for k in names], dtype=np.float32)  # (K, 3) BGR
    bgr_f = aligned_bgr.astype(np.float32)
    dists = np.linalg.norm(bgr_f[:, :, None, :] - colors[None, None, :, :], axis=-1)
    sorted_dists = np.sort(dists, axis=-1)
    d_best = sorted_dists[:, :, 0]
    d_second = sorted_dists[:, :, 1] if len(names) > 1 else np.full_like(d_best, 999.0)
    best_idx = np.argmin(dists, axis=-1)

    if valid_pixel_mask is not None:
        valid = fg_raw & valid_pixel_mask
    else:
        cmax = np.max(aligned_bgr, axis=2)
        cmin = np.min(aligned_bgr, axis=2)
        chroma = cmax.astype(np.int16) - cmin.astype(np.int16)
        # Reject blended seam colors (like Red+Green->Yellow or pale edge haze)
        strict_valid = fg_raw & (chroma >= 64) & ((255 - cmin.astype(np.int16)) >= 50) & (d_best <= 110.0) & (d_best <= 0.78 * d_second)
        valid = strict_valid if int(strict_valid.sum()) >= 64 else (fg_raw & (chroma > 38))

    if np.any(valid):
        need_fill = ref_alpha & (~valid)
        if np.any(need_fill):
            _, labels = cv2.distanceTransformWithLabels(
                (~valid).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            vy, vx = np.where(valid)
            fy, fx = np.where(need_fill)
            filled_idx = best_idx.copy()
            filled_idx[fy, fx] = best_idx[vy[labels[fy, fx] - 1], vx[labels[fy, fx] - 1]]
            best_idx = filled_idx

    best_idx = _prune_small_islands_and_outliers(best_idx, ref_alpha, len(names), min_island_px=min_island_px)
    return {k: (ref_alpha & (best_idx == i)) for i, k in enumerate(names)}


def _save_visual_overlay(out_path: Path, ref_rgba: np.ndarray, mask_bgr: np.ndarray, fg_alpha: np.ndarray) -> None:
    ref_rgb = _composite_rgba_on_white(ref_rgba).astype(np.float32)
    ov = ref_rgb.copy()
    m_f = mask_bgr.astype(np.float32)
    alpha3 = fg_alpha[:, :, None].astype(np.float32)
    ov = np.where(alpha3 > 0.5, ref_rgb * 0.42 + m_f * 0.58, 255.0)
    comp = np.concatenate([ref_rgb.astype(np.uint8), mask_bgr.astype(np.uint8), np.clip(ov, 0, 255).astype(np.uint8)], axis=1)
    cv2.imwrite(str(out_path), comp)


def _ingest_parts5(work_dir: Path, folder: Path, meta: dict) -> list[str]:
    out_dir = folder / "split_results"
    viewer_palette = {
        "body_core": PARTS5_CANONICAL_BGR["body_core"],
        "arm_left_img": PARTS5_CANONICAL_BGR["arm_r"],   # Red in image
        "arm_right_img": PARTS5_CANONICAL_BGR["arm_l"],  # Blue in image
        "leg_left_img": PARTS5_CANONICAL_BGR["leg_r"],   # Yellow in image
        "leg_right_img": PARTS5_CANONICAL_BGR["leg_l"],  # Magenta in image
    }

    parsed_views: dict[str, dict[str, np.ndarray]] = {}
    for b in meta["batches"]:
        mpath = _find_masked_file(folder / "masked_outputs", b["filename"])
        if mpath is None:
            continue
        sheet = cv2.imread(str(mpath), cv2.IMREAD_COLOR)
        grid = _split_grid_cells(sheet, b["rows"], b["cols"])
        for r, row_views in enumerate(b["views_grid"]):
            for c, view in enumerate(row_views):
                ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
                ref_alpha = ref_rgba[:, :, 3] > 24
                aligned = _align_cell_to_ref_alpha(grid[r][c], ref_alpha)
                cls_masks = _nearest_palette_quantize(aligned, ref_alpha, viewer_palette, min_island_px=150)

                # Resolve anatomical arm_r/arm_l & leg_r/leg_l according to hemisphere
                is_back = view in ("n", "ne")
                arm_a, arm_b = cls_masks["arm_left_img"], cls_masks["arm_right_img"]
                leg_a, leg_b = cls_masks["leg_left_img"], cls_masks["leg_right_img"]
                if view == "e":
                    # Side profile facing +X: Blue = visible near arm, Magenta = visible near leg
                    # Suppress tiny orphan < 80px bleeds on far-side slots back into near limbs
                    if int(arm_a.sum()) < 80:
                        arm_b = arm_b | arm_a
                        arm_a = np.zeros_like(arm_a)
                    if int(leg_a.sum()) < 80:
                        leg_b = leg_b | leg_a
                        leg_a = np.zeros_like(leg_a)
                    arm_r_m, arm_l_m = arm_b, arm_a
                    leg_r_m, leg_l_m = leg_b, leg_a
                elif is_back:
                    arm_r_m, arm_l_m = arm_b, arm_a
                    leg_r_m, leg_l_m = leg_b, leg_a
                else:
                    arm_r_m, arm_l_m = arm_a, arm_b
                    leg_r_m, leg_l_m = leg_a, leg_b

                parsed_views[view] = {
                    "body_core": cls_masks["body_core"],
                    "arm_r": arm_r_m,
                    "arm_l": arm_l_m,
                    "leg_r": leg_r_m,
                    "leg_l": leg_l_m,
                }

    # Auto-mirror sw<-se, w<-e, nw<-ne (with L/R anatomical swap & aligned Voronoi fill)
    for dst_view, src_view in MIRROR_SOURCE_MAP.items():
        if src_view not in parsed_views:
            continue
        src_parts = parsed_views[src_view]
        src_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, src_view)), cv2.IMREAD_UNCHANGED)
        src_alpha = src_rgba[:, :, 3] > 24
        dst_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, dst_view)), cv2.IMREAD_UNCHANGED)
        dst_alpha = dst_rgba[:, :, 3] > 24

        swap_src_vis = np.full((CANONICAL_H, CANONICAL_W, 3), 255, dtype=np.uint8)
        swap_src_vis[src_parts["body_core"]] = PARTS5_CANONICAL_BGR["body_core"]
        swap_src_vis[src_parts["arm_l"]] = PARTS5_CANONICAL_BGR["arm_r"]
        swap_src_vis[src_parts["arm_r"]] = PARTS5_CANONICAL_BGR["arm_l"]
        swap_src_vis[src_parts["leg_l"]] = PARTS5_CANONICAL_BGR["leg_r"]
        swap_src_vis[src_parts["leg_r"]] = PARTS5_CANONICAL_BGR["leg_l"]

        mir_vis = _mirror_aligned_canvas(swap_src_vis, src_alpha, dst_alpha, (255, 255, 255), voronoi_fill=True)
        parsed_views[dst_view] = {
            pname: dst_alpha & np.all(mir_vis == np.array(color_bgr, dtype=np.uint8)[None, None, :], axis=2)
            for pname, color_bgr in PARTS5_CANONICAL_BGR.items()
        }

    written: list[str] = []
    for view, parts in parsed_views.items():
        ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        ref_alpha = ref_rgba[:, :, 3] > 24
        vis = np.full((CANONICAL_H, CANONICAL_W, 3), 255, dtype=np.uint8)
        for pname, color_bgr in PARTS5_CANONICAL_BGR.items():
            vis[parts[pname]] = color_bgr
        out_mask = out_dir / f"{view}_parts5_mask.png"
        cv2.imwrite(str(out_mask), vis)
        _save_visual_overlay(out_dir / f"{view}_parts5_audit.png", ref_rgba, vis, ref_alpha)
        written.append(out_mask.name)
    return written


def _ingest_id_bodies(work_dir: Path, folder: Path, meta: dict) -> list[str]:
    out_dir = folder / "split_results"
    id_palette_bgr = {
        "skin_neutral": (0, 255, 255),   # Yellow in RGB -> (0,0,0,0) shader
        "accent_r": (0, 0, 255),         # Red in RGB -> R channel
        "armor_g": (0, 255, 0),          # Green in RGB -> G channel
        "suit_b": (255, 0, 0),           # Blue in RGB -> B channel
        "stocking_a": (255, 255, 0),     # Cyan in RGB -> A channel
    }

    parsed_shader: dict[str, tuple[np.ndarray, np.ndarray]] = {}
    for b in meta["batches"]:
        mpath = _find_masked_file(folder / "masked_outputs", b["filename"])
        if mpath is None:
            continue
        sheet = cv2.imread(str(mpath), cv2.IMREAD_COLOR)
        grid = _split_grid_cells(sheet, b["rows"], b["cols"])
        for r, row_views in enumerate(b["views_grid"]):
            for c, view in enumerate(row_views):
                ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
                ref_alpha = ref_rgba[:, :, 3] > 24
                aligned = _align_cell_to_ref_alpha(grid[r][c], ref_alpha)
                cls = _nearest_palette_quantize(aligned, ref_alpha, id_palette_bgr)

                shader_bgra = np.zeros((CANONICAL_H, CANONICAL_W, 4), dtype=np.uint8)
                shader_bgra[cls["accent_r"], 2] = 255
                shader_bgra[cls["armor_g"], 1] = 255
                shader_bgra[cls["suit_b"], 0] = 255
                shader_bgra[cls["stocking_a"], 3] = 255

                paint_vis = np.full((CANONICAL_H, CANONICAL_W, 3), 255, dtype=np.uint8)
                for k, col in id_palette_bgr.items():
                    paint_vis[cls[k]] = col
                parsed_shader[view] = (shader_bgra, paint_vis)

    for dst_view, src_view in MIRROR_SOURCE_MAP.items():
        if src_view not in parsed_shader:
            continue
        src_sh, src_vis = parsed_shader[src_view]
        src_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, src_view)), cv2.IMREAD_UNCHANGED)
        src_alpha = src_rgba[:, :, 3] > 24
        dst_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, dst_view)), cv2.IMREAD_UNCHANGED)
        dst_alpha = dst_rgba[:, :, 3] > 24
        dst_sh = _mirror_aligned_canvas(src_sh, src_alpha, dst_alpha, (0, 0, 0, 0), voronoi_fill=True)
        dst_vis = _mirror_aligned_canvas(src_vis, src_alpha, dst_alpha, (255, 255, 255), voronoi_fill=True)
        parsed_shader[dst_view] = (dst_sh, dst_vis)

    written: list[str] = []
    for view, (shader_bgra, paint_vis) in parsed_shader.items():
        ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        ref_alpha = ref_rgba[:, :, 3] > 24
        out_sh = out_dir / f"{view}_id_mask.png"
        out_vis = out_dir / f"{view}_id_mask_preview.png"
        cv2.imwrite(str(out_sh), shader_bgra)
        cv2.imwrite(str(out_vis), paint_vis)
        _save_visual_overlay(out_dir / f"{view}_id_mask_audit.png", ref_rgba, paint_vis, ref_alpha)
        written.append(out_sh.name)
    return written


def _ingest_id_heads(work_dir: Path, folder: Path, meta: dict) -> list[str]:
    out_dir = folder / "split_results"
    head_palette_bgr = {
        "hair_a": (255, 255, 0),    # Cyan -> A
        "collar_b": (255, 0, 0),    # Blue -> B
        "monocle_r": (0, 0, 255),   # Red -> R
        "skin_0": (0, 255, 0),      # Green -> 0 (Skin)
    }

    # Prefer split 4x1 batches if present, otherwise fallback to all8_4x2
    collected: dict[str, np.ndarray] = {}
    ordered_batches = sorted(
        meta["batches"],
        key=lambda b: 0 if "batch" in b["filename"] else 1,
    )
    for b in ordered_batches:
        mpath = _find_masked_file(folder / "masked_outputs", b["filename"])
        if mpath is None:
            continue
        sheet = cv2.imread(str(mpath), cv2.IMREAD_COLOR)
        grid = _split_grid_cells(sheet, b["rows"], b["cols"])
        for r, row_views in enumerate(b["views_grid"]):
            for c, view in enumerate(row_views):
                if view not in collected:
                    collected[view] = grid[r][c]

    written: list[str] = []
    for view, cell_bgr in collected.items():
        ref_rgba = cv2.imread(str(_head_hires_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        ref_alpha = ref_rgba[:, :, 3] > 20
        aligned = _align_cell_to_ref_alpha(cell_bgr, ref_alpha, scale_down_for_iou=2)
        cls = _nearest_palette_quantize(aligned, ref_alpha, head_palette_bgr)

        th, tw = ref_rgba.shape[:2]
        shader_bgra = np.zeros((th, tw, 4), dtype=np.uint8)
        shader_bgra[cls["monocle_r"], 2] = 255
        shader_bgra[cls["collar_b"], 0] = 255
        shader_bgra[cls["hair_a"], 3] = 255

        paint_vis = np.full((th, tw, 3), 255, dtype=np.uint8)
        for k, col in head_palette_bgr.items():
            paint_vis[cls[k]] = col

        out_sh = out_dir / f"head_{view}_id_mask.png"
        out_vis = out_dir / f"head_{view}_id_mask_preview.png"
        cv2.imwrite(str(out_sh), shader_bgra)
        cv2.imwrite(str(out_vis), paint_vis)
        _save_visual_overlay(out_dir / f"head_{view}_id_mask_audit.png", ref_rgba, paint_vis, ref_alpha)
        written.append(out_sh.name)
    return written


def _ingest_limb_anim(work_dir: Path, folder: Path, meta: dict) -> list[str]:
    out_dir = folder / "split_results"
    limb_palette_bgr = {
        "upper": (0, 0, 255),      # Red
        "lower": (0, 255, 0),      # Green
        "extremity": (255, 0, 0),  # Blue
    }

    parsed_limbs: dict[str, np.ndarray] = {}
    for b in meta["batches"]:
        mpath = _find_masked_file(folder / "masked_outputs", b["filename"])
        if mpath is None:
            continue
        sheet = cv2.imread(str(mpath), cv2.IMREAD_COLOR)
        grid = _split_grid_cells(sheet, b["rows"], b["cols"])
        for r, row_views in enumerate(b["views_grid"]):
            for c, view in enumerate(row_views):
                ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
                ref_alpha = ref_rgba[:, :, 3] > 24
                aligned = _align_cell_to_ref_alpha(grid[r][c], ref_alpha)

                cmax = np.max(aligned, axis=2)
                cmin = np.min(aligned, axis=2)
                is_limb_chromatic = (cmax > 110) & ((cmax.astype(np.int16) - cmin.astype(np.int16)) > 55)

                vis = np.full((CANONICAL_H, CANONICAL_W, 3), 255, dtype=np.uint8)
                vis[ref_alpha] = (24, 24, 24)  # Charcoal torso anchor

                if np.any(is_limb_chromatic):
                    bgr_f = aligned.astype(np.float32)
                    colors = np.array(list(limb_palette_bgr.values()), dtype=np.float32)
                    dists = np.linalg.norm(bgr_f[:, :, None, :] - colors[None, None, :, :], axis=-1)
                    cls_idx = np.argmin(dists, axis=-1)
                    for idx, col in enumerate(limb_palette_bgr.values()):
                        m = (ref_alpha & is_limb_chromatic & (cls_idx == idx)).astype(np.uint8)
                        n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(m)
                        kept = np.zeros_like(m, dtype=bool)
                        for cc in range(1, n_cc):
                            if int(stats[cc, cv2.CC_STAT_AREA]) >= 60:
                                kept |= (lbl == cc)
                        vis[kept] = col
                parsed_limbs[view] = vis

    for dst_view, src_view in MIRROR_SOURCE_MAP.items():
        if src_view not in parsed_limbs:
            continue
        src_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, src_view)), cv2.IMREAD_UNCHANGED)
        src_alpha = src_rgba[:, :, 3] > 24
        dst_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, dst_view)), cv2.IMREAD_UNCHANGED)
        dst_alpha = dst_rgba[:, :, 3] > 24
        parsed_limbs[dst_view] = _mirror_aligned_canvas(
            parsed_limbs[src_view], src_alpha, dst_alpha, (255, 255, 255), voronoi_fill=True
        )

    written: list[str] = []
    for view, vis in parsed_limbs.items():
        ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        ref_alpha = ref_rgba[:, :, 3] > 24
        out_p = out_dir / f"{view}_limb_segments.png"
        cv2.imwrite(str(out_p), vis)
        _save_visual_overlay(out_dir / f"{view}_limb_segments_audit.png", ref_rgba, vis, ref_alpha)
        written.append(out_p.name)
    return written


def _ingest_secondary_jiggle(work_dir: Path, folder: Path, meta: dict) -> list[str]:
    out_dir = folder / "split_results"
    parsed_sec: dict[str, np.ndarray] = {}

    for b in meta["batches"]:
        mpath = _find_masked_file(folder / "masked_outputs", b["filename"])
        if mpath is None:
            continue
        sheet = cv2.imread(str(mpath), cv2.IMREAD_COLOR)
        grid = _split_grid_cells(sheet, b["rows"], b["cols"])
        is_front = "front" in b["filename"]

        for r, row_views in enumerate(b["views_grid"]):
            for c, view in enumerate(row_views):
                ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
                ref_alpha = ref_rgba[:, :, 3] > 24
                aligned = _align_cell_to_ref_alpha(grid[r][c], ref_alpha)

                bb = aligned[:, :, 0].astype(np.float32)
                gg = aligned[:, :, 1].astype(np.float32)
                rr = aligned[:, :, 2].astype(np.float32)

                if is_front:
                    # Strictly Cyan (#00FFFF)
                    raw_zone = (gg > 130) & (bb > 130) & ((np.minimum(gg, bb) - rr) > 55) & ref_alpha
                else:
                    # Strictly Magenta (#FF00FF)
                    raw_zone = (rr > 130) & (bb > 130) & ((np.minimum(rr, bb) - gg) > 55) & ref_alpha

                # Keep only meaningful lobe blobs (>= 120 px)
                n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(raw_zone.astype(np.uint8))
                zone = np.zeros_like(raw_zone)
                for cc in range(1, n_cc):
                    if int(stats[cc, cv2.CC_STAT_AREA]) >= 120:
                        zone |= (lbl == cc)

                # Gaussian feather + L/R lobe split (matching process_secondary_mask.py)
                inner_a = cv2.erode(ref_alpha.astype(np.uint8) * 255, np.ones((9, 9), np.uint8), iterations=1).astype(np.float32) / 255.0
                inner_a = cv2.GaussianBlur(inner_a, (11, 11), 3.0)
                soft_zone = cv2.GaussianBlur(zone.astype(np.float32), (25, 25), 7.0) * inner_a

                ys, xs = np.where(zone)
                cx = float(xs.mean()) if len(xs) > 0 else float(CANONICAL_W) * 0.5
                xx = np.arange(CANONICAL_W, dtype=np.float32)[None, :]
                w_right = np.clip((xx - (cx - 14.0)) / 28.0, 0.0, 1.0)
                w_left = 1.0 - w_right

                l_lobe = np.clip(soft_zone * w_left * 1.15, 0.0, 1.0)
                r_lobe = np.clip(soft_zone * w_right * 1.15, 0.0, 1.0)

                out_bgra = np.zeros((CANONICAL_H, CANONICAL_W, 4), dtype=np.uint8)
                out_bgra[:, :, 2] = (l_lobe * 255.0).astype(np.uint8)  # R = Left Lobe
                out_bgra[:, :, 1] = (r_lobe * 255.0).astype(np.uint8)  # G = Right Lobe
                out_bgra[:, :, 3] = 255
                parsed_sec[view] = out_bgra

    # Mirror se->sw, ne->nw aligned to dst_alpha and swap Left(R) <-> Right(G) lobes
    for dst_view, src_view in MIRROR_SOURCE_MAP.items():
        if src_view not in parsed_sec:
            continue
        src_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, src_view)), cv2.IMREAD_UNCHANGED)
        src_alpha = src_rgba[:, :, 3] > 24
        dst_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, dst_view)), cv2.IMREAD_UNCHANGED)
        dst_alpha = dst_rgba[:, :, 3] > 24
        aligned_flip = _mirror_aligned_canvas(
            parsed_sec[src_view], src_alpha, dst_alpha, (0, 0, 0, 255), voronoi_fill=False
        )
        swapped = aligned_flip.copy()
        swapped[:, :, 2] = np.where(dst_alpha, aligned_flip[:, :, 1], 0)
        swapped[:, :, 1] = np.where(dst_alpha, aligned_flip[:, :, 2], 0)
        swapped[:, :, 3] = 255
        parsed_sec[dst_view] = swapped

    written: list[str] = []
    for view, sec_bgra in parsed_sec.items():
        ref_rgba = cv2.imread(str(_canonical_rgba_path(work_dir, view)), cv2.IMREAD_UNCHANGED)
        ref_alpha = ref_rgba[:, :, 3] > 24
        out_p = out_dir / f"{view}_secondary_jiggle_mask.png"
        cv2.imwrite(str(out_p), sec_bgra)
        _save_visual_overlay(out_dir / f"{view}_secondary_audit.png", ref_rgba, sec_bgra[:, :, :3], ref_alpha)
        written.append(out_p.name)
    return written


INGEST_HANDLERS: dict[str, Callable[[Path, Path, dict], list[str]]] = {
    "01_parts_5_despiece": _ingest_parts5,
    "02_id_mask_bodies": _ingest_id_bodies,
    "03_id_mask_heads": _ingest_id_heads,
    "04_limb_anim_masks": _ingest_limb_anim,
    "05_secondary_jiggle_masks": _ingest_secondary_jiggle,
}


def ingest_workspace(work_dir: Path, target_key: str) -> dict[str, list[str]]:
    ws_root = work_dir / WORKSPACES_DIRNAME
    keys = list(FOLDER_KEYS) if target_key == "all" else [target_key]
    summary: dict[str, list[str]] = {}
    for key in keys:
        folder = ws_root / key
        meta_path = folder / "layout_meta.json"
        if not meta_path.exists():
            raise FileNotFoundError(f"Missing {meta_path}; run --export first.")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        summary[key] = INGEST_HANDLERS[key](work_dir, folder, meta)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Export / ingest AI mask block workspaces.")
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK_DIR)
    parser.add_argument("--export", action="store_true", help="Create 05_mask_ai_workspaces blocks & PROMPT_GUIDE.md files.")
    parser.add_argument(
        "--ingest",
        choices=["all", *FOLDER_KEYS],
        default=None,
        help="Re-split, IoU-align, and auto-mirror masks placed in masked_outputs/.",
    )
    args = parser.parse_args()

    if not args.export and args.ingest is None:
        args.export = True

    if args.export:
        ws_root = export_workspaces(args.work_dir)
        print(f"Exported AI mask workspaces to: {ws_root}")

    if args.ingest is not None:
        summary = ingest_workspace(args.work_dir, args.ingest)
        for key, files in summary.items():
            print(f"[INGEST {key}] {len(files)} files -> {', '.join(files[:4])}{'...' if len(files) > 4 else ''}")


if __name__ == "__main__":
    main()
