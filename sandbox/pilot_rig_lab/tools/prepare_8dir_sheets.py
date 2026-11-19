#!/usr/bin/env python3
"""Pre-masking preparation pipeline for Valentina v2 8-direction sheets.

Processes raw turnaround sheets through:
  1. Upscayl CLI (`digital-art-4x`) lossless 4x upscaling (1024x571 -> 4096x2284).
  2. Adaptive vertical-valley column detection (avoids fixed 1/4 clipping of wide hands).
  3. Hybrid foreground matte extraction (neutral-#808080 outer flood-fill + IS-Net Anime
     confirmation for enclosed background pockets such as chin/bang triangles).
  4. Anti-halo edge defringing, smooth outer alpha AA, and Voronoi RGB alpha bleed.
  5. Baseline + crown + horizontal center alignment across all unique directions onto:
       - Native 4x crisp canvases (1152x2304, zero scaling blur)
       - Rig-canonical 1560x1680 canvases (3x 520x560 matching photoshop_align)
  6. Reconstructed spotless #808080, #FFFFFF, and RGBA master strips + head crops +
     ink-barrier / non-ink shadow metrics + ink-locked CIELAB id_mask starter drafts.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
MODELS_CACHE = TOOLS_DIR / "models"
os.environ.setdefault("HF_HOME", str(MODELS_CACHE))
os.environ.setdefault("U2NET_HOME", str(MODELS_CACHE / "u2net"))

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from id_mask_ink_refiner import (  # noqa: E402
    extract_ink_barrier,
    refine_mask_ink_locked,
)
from ml_stage_processors import clear_vram  # noqa: E402
from polish_outlines import alpha_bleed_and_defringe  # noqa: E402

UPSCAYL_BIN = Path(r"C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe")
UPSCAYL_MODELS = Path(r"C:\Program Files\Upscayl\resources\models")
DEFAULT_WORK_DIR = Path("sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir")

CANONICAL_W = 1560
CANONICAL_H = 1680
CANONICAL_BODY_H = 1290
CANONICAL_BOTTOM_Y = 1605

NATIVE_CELL_W = 1152
NATIVE_CELL_H = 2304
NATIVE_BOTTOM_Y = 2248

COMPASS_7_ORDER = ("s", "se", "e", "ne", "n", "nw", "w")


@dataclass(frozen=True)
class SheetSpec:
    """Definition of one 4-column input sheet and its pose names left-to-right."""

    key: str
    raw_filename: str
    upscaled_filename: str
    pose_names: tuple[str, str, str, str]


@dataclass
class PoseMetrics:
    """Geometric and tone diagnostics for a cleaned single-direction crop."""

    name: str
    source_sheet: str
    col_index: int
    raw_bbox_xywh: list[int]
    fg_pixels: int
    inner_holes_removed_px: int
    ink_ratio_pct: float
    ink_median_luma: float
    non_ink_p01_luma: float
    non_ink_p99_luma: float
    bright_gt225_pct: float


def run_upscayl_4x(src_path: Path, dst_path: Path, model: str = "digital-art-4x") -> Path:
    """Upscale an image 4x with Upscayl Vulkan CLI unless already up-to-date."""
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    if dst_path.exists() and dst_path.stat().st_mtime >= src_path.stat().st_mtime:
        return dst_path
    if not UPSCAYL_BIN.exists():
        raise FileNotFoundError(f"Upscayl CLI not found at {UPSCAYL_BIN}")
    cmd = [
        str(UPSCAYL_BIN),
        "-i",
        str(src_path),
        "-o",
        str(dst_path),
        "-m",
        str(UPSCAYL_MODELS),
        "-n",
        model,
        "-z",
        "4",
        "-s",
        "4",
        "-f",
        "png",
    ]
    subprocess.run(cmd, check=True)
    return dst_path


def find_column_splits(bgr: np.ndarray, expected_cols: int = 4) -> tuple[list[int], np.ndarray]:
    """Locate empty #808080 vertical valleys separating characters across the horizontal strip."""
    h, w = bgr.shape[:2]
    bg_bgr = np.median(bgr[:40, :, :], axis=(0, 1))
    diff = np.linalg.norm(bgr.astype(np.float32) - bg_bgr[None, None, :], axis=2)
    fg = diff > 10.0
    col_sums = fg.sum(axis=0)
    active = col_sums > 5

    spans: list[tuple[int, int]] = []
    in_span = False
    start = 0
    for x in range(w):
        if active[x] and not in_span:
            in_span = True
            start = x
        elif not active[x] and in_span:
            in_span = False
            if x - start > 50:
                spans.append((start, x - 1))
    if in_span and (w - start) > 50:
        spans.append((start, w - 1))

    if len(spans) != expected_cols:
        step = w // expected_cols
        return [i * step for i in range(expected_cols)] + [w], bg_bgr

    splits = [0] + [(spans[i][1] + spans[i + 1][0]) // 2 for i in range(expected_cols - 1)] + [w]
    return splits, bg_bgr


def _predict_isnet_alpha(sub_bgr: np.ndarray, bg_bgr: np.ndarray, session: Any) -> np.ndarray:
    """Run IS-Net Anime on a square-padded crop so full portrait proportions are preserved."""
    from rembg import remove

    h, w = sub_bgr.shape[:2]
    side = max(h, w)
    pad_w = max(0, side - w) // 2
    sq_rgb = np.full((side, side, 3), bg_bgr[::-1].astype(np.uint8), dtype=np.uint8)
    sq_rgb[:h, pad_w : pad_w + w] = cv2.cvtColor(sub_bgr, cv2.COLOR_BGR2RGB)
    out = np.array(remove(Image.fromarray(sq_rgb), session=session))
    return out[:h, pad_w : pad_w + w, 3]


def extract_clean_pose_rgba(
    sub_bgr: np.ndarray,
    bg_bgr: np.ndarray,
    isnet_session: Any,
) -> tuple[np.ndarray, int]:
    """Extract crisp RGBA silhouette via outer flood-fill + IS-Net confirmed inner holes + defringe."""
    h, w = sub_bgr.shape[:2]
    diff = np.linalg.norm(sub_bgr.astype(np.float32) - bg_bgr[None, None, :], axis=2)
    sat = sub_bgr.max(axis=2).astype(np.int16) - sub_bgr.min(axis=2).astype(np.int16)

    # 1. Outer neutral-gray background flood-fill bounded by crisp #080812 ink barriers.
    # Include soft compression haze in concave hand/finger pockets where IS-Net agrees bg (<185),
    # while hard-stopping at dark outline ink (luma < 72), skin/crimson chroma (sat >= 14), or bright hair.
    isnet_a = _predict_isnet_alpha(sub_bgr, bg_bgr, isnet_session)
    luma = (
        0.114 * sub_bgr[:, :, 0].astype(np.float32)
        + 0.587 * sub_bgr[:, :, 1].astype(np.float32)
        + 0.299 * sub_bgr[:, :, 2].astype(np.float32)
    )
    can_flood_bg = ((diff < 13.0) & (sat < 14)) | (
        (diff < 28.0) & (sat < 14) & (luma >= 72.0) & (luma <= 145.0) & (isnet_a < 185)
    )
    ff = can_flood_bg.astype(np.uint8)
    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    for pt in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if ff[pt[1], pt[0]] == 1:
            cv2.floodFill(ff, ff_mask, pt, 2)
    outer_bg = ff == 2
    fg_raw = ~outer_bg

    # 2. Remove genuinely enclosed #808080 background pockets (never punching gray armor/hair)
    inner_cand = fg_raw & (diff < 8.5) & (sat < 11) & (isnet_a < 32)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(inner_cand.astype(np.uint8))
    holes_mask = np.zeros_like(fg_raw)
    for cid in range(1, n_cc):
        if int(stats[cid, cv2.CC_STAT_AREA]) >= 80:
            holes_mask[lbl == cid] = True
    fg = fg_raw & (~holes_mask)

    # Prune tiny detached dust speckles (< 120 px)
    n_fg, fg_lbl, fg_stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8))
    keep_fg = np.zeros_like(fg)
    min_fg_area = max(120, int(fg.sum() * 0.0005))
    for cid in range(1, n_fg):
        if int(fg_stats[cid, cv2.CC_STAT_AREA]) >= min_fg_area:
            keep_fg[fg_lbl == cid] = True
    fg = keep_fg

    # Trim remaining 1px gray-contaminated rim touching exterior bg if luma sits near #808080 above ink
    k3 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    fg_u8 = fg.astype(np.uint8) * 255
    outer_1px = fg & (cv2.erode(fg_u8, k3, iterations=1) == 0)
    gray_rim = outer_1px & (diff < 34.0) & (sat < 14) & (luma > 58.0) & (luma < 152.0)
    fg = fg & (~gray_rim)

    # 3. Sub-pixel boundary AA ramp while preserving 100% solid interior opacity
    fg_inner = cv2.erode(fg.astype(np.uint8) * 255, k3, iterations=1) > 0
    fg_blur = cv2.GaussianBlur(fg.astype(np.float32) * 255.0, (3, 3), 0.72)
    alpha = np.where(fg, np.clip(fg_blur, 96.0, 255.0), 0.0)
    alpha[fg_inner] = 255.0
    alpha_u8 = np.clip(np.round(alpha), 0, 255).astype(np.uint8)

    bgra = np.zeros((h, w, 4), dtype=np.uint8)
    bgra[:, :, :3] = sub_bgr
    bgra[:, :, 3] = alpha_u8

    # Snap outer semi-transparent/rim neutral pixels (< 252 alpha) to dark ink before alpha-bleeding
    ink_rim = (alpha_u8 > 0) & (~fg_inner) & (sat < 16) & (luma > 42.0)
    bgra[ink_rim, :3] = (20, 10, 10)  # Dark #0A0A14 ink in BGR

    # 4. Defringe + 4-way Voronoi RGB bleed into transparent pixels
    bgra_clean = alpha_bleed_and_defringe(bgra)
    return bgra_clean, int(holes_mask.sum())


def compute_pose_metrics(
    bgra: np.ndarray,
    name: str,
    source_sheet: str,
    col_index: int,
    holes_removed: int,
) -> PoseMetrics:
    """Measure contour ink lock, dark shadow headroom, and highlight peaks."""
    fg = bgra[:, :, 3] > 128
    ys, xs = np.where(fg)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
    ink = extract_ink_barrier(bgra, fg)
    b = bgra[:, :, 0].astype(np.float32)
    g = bgra[:, :, 1].astype(np.float32)
    r = bgra[:, :, 2].astype(np.float32)
    luma = 0.114 * b + 0.587 * g + 0.299 * r
    non_ink = fg & (~ink)
    bright = fg & (luma > 225.0)
    fg_sum = max(int(fg.sum()), 1)
    return PoseMetrics(
        name=name,
        source_sheet=source_sheet,
        col_index=col_index,
        raw_bbox_xywh=bbox,
        fg_pixels=int(fg.sum()),
        inner_holes_removed_px=holes_removed,
        ink_ratio_pct=round(100.0 * float(ink.sum()) / fg_sum, 2),
        ink_median_luma=round(float(np.median(luma[ink])) if np.any(ink) else 0.0, 1),
        non_ink_p01_luma=round(float(np.percentile(luma[non_ink], 1)) if np.any(non_ink) else 0.0, 1),
        non_ink_p99_luma=round(float(np.percentile(luma[non_ink], 99)) if np.any(non_ink) else 0.0, 1),
        bright_gt225_pct=round(100.0 * float(bright.sum()) / fg_sum, 2),
    )


def place_aligned_pose(
    bgra: np.ndarray,
    canvas_w: int,
    canvas_h: int,
    target_bottom_y: int,
    target_height: int | None = None,
) -> tuple[np.ndarray, tuple[int, int, int, int]]:
    """Center pose horizontally around its torso/bbox mass and lock sole baseline."""
    fg = bgra[:, :, 3] > 128
    ys, xs = np.where(fg)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    tight = bgra[y0:y1, x0:x1]
    th, tw = tight.shape[:2]

    if target_height is not None and th != target_height:
        scale = float(target_height) / float(th)
        nw = max(1, int(round(tw * scale)))
        nh = target_height
        # Premultiplied resize avoids halo fringes at alpha borders
        pm = tight.astype(np.float32)
        a_norm = pm[:, :, 3:4] / 255.0
        pm[:, :, :3] *= a_norm
        res_pm = cv2.resize(pm, (nw, nh), interpolation=cv2.INTER_AREA)
        out_tight = np.zeros((nh, nw, 4), dtype=np.uint8)
        ra = res_pm[:, :, 3:4]
        valid = ra[:, :, 0] > 1.0
        out_tight[:, :, 3] = np.clip(np.round(res_pm[:, :, 3]), 0, 255).astype(np.uint8)
        out_tight[valid, :3] = np.clip(np.round(res_pm[valid, :3] / (ra[valid] / 255.0)), 0, 255).astype(np.uint8)
        out_tight = alpha_bleed_and_defringe(out_tight)
    else:
        out_tight = tight
        nw, nh = tw, th

    # Center horizontally using robust torso/head median X so asymmetric arms don't shift stance center
    alpha_t = out_tight[:, :, 3] > 128
    _, fxs = np.where(alpha_t)
    median_x = int(round(float(np.median(fxs))))
    ox = (canvas_w // 2) - median_x
    ox = max(8, min(canvas_w - nw - 8, ox))
    oy = max(8, target_bottom_y - nh)

    canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    canvas[oy : oy + nh, ox : ox + nw] = out_tight
    canvas = alpha_bleed_and_defringe(canvas)
    return canvas, (ox, oy, nw, nh)


def composite_on_bg(bgra: np.ndarray, rgb_color: tuple[int, int, int]) -> np.ndarray:
    """Composite BGRA cleanly over a flat solid RGB background color."""
    a = bgra[:, :, 3:4].astype(np.float32) / 255.0
    bg = np.array([rgb_color[2], rgb_color[1], rgb_color[0]], dtype=np.float32).reshape(1, 1, 3)
    out = np.clip(np.round(bgra[:, :, :3].astype(np.float32) * a + bg * (1.0 - a)), 0, 255).astype(np.uint8)
    return out


def crop_head_from_pose(pose_bgra: np.ndarray, pad: int = 36) -> np.ndarray:
    """Extract upper head + high collar crop (~top 25% of full character height)."""
    fg = pose_bgra[:, :, 3] > 64
    ys, _ = np.where(fg)
    top_y = int(ys.min())
    bot_y = int(ys.max())
    fig_h = bot_y - top_y
    head_cut_y = min(pose_bgra.shape[0], top_y + int(round(fig_h * 0.255)))
    sub = pose_bgra[max(0, top_y - pad) : head_cut_y, :]
    sfg = sub[:, :, 3] > 64
    sys_i, sxs_i = np.where(sfg)
    x0 = max(0, int(sxs_i.min()) - pad)
    x1 = min(sub.shape[1], int(sxs_i.max()) + 1 + pad)
    return sub[:, x0:x1]


def build_auto_id_mask_draft(pose_bgra: np.ndarray, ink_audit_out: Path) -> tuple[np.ndarray, np.ndarray]:
    """Run calibrated v2 swatch classifier + Ink-Locked SLIC to create editable id_mask drafts.

    Returns (vis_palette_bgr, raw_id_mask_bgra) matching project conventions:
      - Suit -> Blue (#0000FF) -> B
      - Armor/Panel -> Green (#00FF00) -> G
      - Accent/Monocle -> Red (#FF0000) -> R
      - Stockings/Hair -> Cyan (#00FFFF) -> A
      - Skin -> Yellow (#FFFF00) in vis / (0,0,0,0) in raw id_mask
    """
    fg = pose_bgra[:, :, 3] > 64
    ink = extract_ink_barrier(pose_bgra, fg)
    non_ink = fg & (~ink)

    h, w = pose_bgra.shape[:2]
    ys, _ = np.where(fg)
    top_y, bot_y = int(ys.min()), int(ys.max())
    fh = max(1, bot_y - top_y)
    yy_grid = np.arange(h)[:, None]
    hair_cut_y = top_y + int(round(fh * 0.185))
    stocking_y0 = top_y + int(round(fh * 0.54))
    stocking_y1 = top_y + int(round(fh * 0.725))

    bgr = pose_bgra[:, :, :3]
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    hue = hsv[:, :, 0].astype(np.float32)
    sat = hsv[:, :, 1].astype(np.float32)
    b = bgr[:, :, 0].astype(np.float32)
    g = bgr[:, :, 1].astype(np.float32)
    r = bgr[:, :, 2].astype(np.float32)
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    red_dom = r - np.maximum(g, b)
    warm_red = (hue >= 158.0) | (hue <= 14.0)

    # Calibrated semantic priors on Valentina v2 actual RGBA swatches:
    # 5=skin (->0 after ink-locked propagation), 1=accent(R), 2=armor(G), 3=suit(B), 4=stockings/hair(A)
    is_crimson = non_ink & warm_red & (sat >= 88.0) & (red_dom >= 14.0) & (luma >= 26.0)
    is_skin = (
        non_ink
        & (~is_crimson)
        & (r >= 132.0)
        & ((r - b) >= 12.0)
        & ((r - g) >= 14.0)
        & (luma >= 96.0)
        & (sat < 92.0)
    )
    in_stock_band = (yy_grid >= stocking_y0) & (yy_grid <= stocking_y1)
    is_stocking = (
        non_ink
        & (~is_skin)
        & (~is_crimson)
        & in_stock_band
        & (luma >= 40.0)
        & (luma <= 106.0)
        & ((r - g) >= 5.0)
    )
    is_hair = (
        non_ink
        & (~is_skin)
        & (~is_crimson)
        & (yy_grid < hair_cut_y)
        & (luma >= 100.0)
        & (sat <= 40.0)
    )
    is_armor = (
        non_ink
        & (~is_skin)
        & (~is_crimson)
        & (~is_stocking)
        & (~is_hair)
        & (yy_grid >= hair_cut_y)
        & (sat <= 36.0)
        & (luma >= 96.0)
    )

    prior_cls = np.full((h, w), 3, dtype=np.uint8)
    prior_cls[~non_ink] = 0
    prior_cls[is_crimson] = 1
    prior_cls[is_armor] = 2
    prior_cls[is_hair | is_stocking] = 4
    prior_cls[is_skin] = 5

    refined_cls = refine_mask_ink_locked(
        pose_bgra,
        prior_cls,
        allowed_classes=(1, 2, 3, 4),
        allow_zero_class=True,
        zero_seed_code=5,
        erode_px=2,
        px_per_segment=55,
        min_island_area=40,
    )

    # Build bright paintable palette sheet BGR (Yellow=skin/neutral, Red=accent, Green=armor, Blue=suit, Cyan=stockings)
    vis_bgr = np.zeros((h, w, 3), dtype=np.uint8)
    vis_bgr[fg & (refined_cls == 0)] = (0, 255, 255)   # Yellow
    vis_bgr[fg & (refined_cls == 1)] = (0, 0, 255)     # Red
    vis_bgr[fg & (refined_cls == 2)] = (0, 255, 0)     # Green
    vis_bgr[fg & (refined_cls == 3)] = (255, 0, 0)     # Blue
    vis_bgr[fg & (refined_cls == 4)] = (255, 255, 0)   # Cyan

    # Build shader-ready raw RGBA id_mask (BGRA in OpenCV)
    raw_id = np.zeros((h, w, 4), dtype=np.uint8)
    raw_id[fg & (refined_cls == 1), 2] = 255  # R
    raw_id[fg & (refined_cls == 2), 1] = 255  # G
    raw_id[fg & (refined_cls == 3), 0] = 255  # B
    raw_id[fg & (refined_cls == 4), 3] = 255  # A

    # Export ink barrier verification audit overlay (lime contour highlights ink_barrier inside silhouette)
    audit = composite_on_bg(pose_bgra, (240, 240, 240))
    audit[ink] = (20, 230, 80)
    ink_audit_out.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(ink_audit_out), audit)
    return vis_bgr, raw_id


def draw_alignment_audit_sheet(poses_native: dict[str, np.ndarray], order: tuple[str, ...]) -> np.ndarray:
    """Assemble horizontal compass strip with height/joint horizontal guide lines and labels."""
    cols = [composite_on_bg(poses_native[k], (128, 128, 128)) for k in order if k in poses_native]
    strip = np.hstack(cols)
    h, w = strip.shape[:2]

    # Reference guide lines (crown, chin/collar, pelvis, knee, sole baseline) measured on 's'
    s_alpha = poses_native["s"][:, :, 3] > 128
    sys_i, _ = np.where(s_alpha)
    top_y, bot_y = int(sys_i.min()), int(sys_i.max())
    fig_h = bot_y - top_y
    guide_fracs = [
        ("CROWN", 0.0, (0, 220, 255)),
        ("CHIN", 0.19, (255, 220, 0)),
        ("WAIST", 0.41, (0, 255, 140)),
        ("KNEE", 0.72, (255, 160, 0)),
        ("SOLE", 1.0, (0, 255, 0)),
    ]
    for label, frac, color in guide_fracs:
        gy = int(round(top_y + fig_h * frac))
        cv2.line(strip, (0, gy), (w - 1, gy), color, 2, cv2.LINE_AA)
        cv2.putText(strip, label, (18, max(28, gy - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.9, color, 2, cv2.LINE_AA)

    for idx, k in enumerate(order):
        if k not in poses_native:
            continue
        x0 = idx * NATIVE_CELL_W
        if idx > 0:
            cv2.line(strip, (x0, 0), (x0, h - 1), (90, 90, 90), 2)
        cv2.putText(strip, k.upper(), (x0 + 36, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.8, (245, 245, 245), 4, cv2.LINE_AA)
    return strip


def run_pipeline(work_dir: Path, run_id_draft: bool = True) -> dict[str, Any]:
    """Execute full pre-masking pipeline and return structured metrics."""
    raw_dir = work_dir / "00_raw"
    up_dir = work_dir / "01_upscayl_4x"
    poses_native_dir = work_dir / "02_poses_native_rgba"
    poses_gray_dir = work_dir / "02_poses_native_gray80"
    poses_white_dir = work_dir / "02_poses_native_white"
    poses_canon_dir = work_dir / "02_poses_canonical_1560x1680"
    sheets_dir = work_dir / "03_sheets_aligned"
    prep_dir = work_dir / "04_mask_prep_ready"
    heads_dir = prep_dir / "heads_crops"
    draft_dir = prep_dir / "id_mask_auto_draft"
    ink_dir = prep_dir / "ink_barrier_audit"

    for d in (
        poses_native_dir,
        poses_gray_dir,
        poses_white_dir,
        poses_canon_dir,
        sheets_dir,
        heads_dir,
        draft_dir,
        ink_dir,
    ):
        d.mkdir(parents=True, exist_ok=True)

    specs = [
        SheetSpec("cardinals", "sheet_cardinals_raw.jpg", "sheet_cardinals_4x.png", ("s", "n", "e", "w")),
        SheetSpec("diagonals", "sheet_diagonals_raw.jpg", "sheet_diagonals_4x.png", ("s_diag_alt", "se", "ne", "nw")),
    ]

    for sp in specs:
        run_upscayl_4x(raw_dir / sp.raw_filename, up_dir / sp.upscaled_filename)

    from rembg import new_session

    isnet_session = new_session("isnet-anime")

    poses_native: dict[str, np.ndarray] = {}
    poses_canon: dict[str, np.ndarray] = {}
    metrics_list: list[dict[str, Any]] = []
    placements: dict[str, dict[str, list[int]]] = {"native": {}, "canonical": {}}

    try:
        for sp in specs:
            up_img = cv2.imread(str(up_dir / sp.upscaled_filename))
            if up_img is None:
                raise RuntimeError(f"Failed to load {up_dir / sp.upscaled_filename}")
            splits, bg_bgr = find_column_splits(up_img, expected_cols=4)

            sheet_rgba_cols: list[np.ndarray] = []
            sheet_gray_cols: list[np.ndarray] = []

            for i, pose_name in enumerate(sp.pose_names):
                sub = up_img[:, splits[i] : splits[i + 1]]
                bgra_clean, holes_removed = extract_clean_pose_rgba(sub, bg_bgr, isnet_session)
                pm = compute_pose_metrics(bgra_clean, pose_name, sp.key, i, holes_removed)
                metrics_list.append(pm.__dict__)

                native_canvas, n_rect = place_aligned_pose(
                    bgra_clean, NATIVE_CELL_W, NATIVE_CELL_H, NATIVE_BOTTOM_Y, target_height=None
                )
                canon_canvas, c_rect = place_aligned_pose(
                    bgra_clean, CANONICAL_W, CANONICAL_H, CANONICAL_BOTTOM_Y, target_height=CANONICAL_BODY_H
                )

                sheet_rgba_cols.append(native_canvas)
                sheet_gray_cols.append(composite_on_bg(native_canvas, (128, 128, 128)))

                # Keep authentic unique 7 directions separately from duplicated col 1
                cv2.imwrite(str(poses_native_dir / f"{pose_name}.png"), native_canvas)
                cv2.imwrite(str(poses_gray_dir / f"{pose_name}.png"), composite_on_bg(native_canvas, (128, 128, 128)))
                cv2.imwrite(str(poses_white_dir / f"{pose_name}.png"), composite_on_bg(native_canvas, (255, 255, 255)))
                cv2.imwrite(str(poses_canon_dir / f"{pose_name}_rgba_1560x1680.png"), canon_canvas)
                cv2.imwrite(
                    str(poses_canon_dir / f"{pose_name}_white_1560x1680.png"),
                    composite_on_bg(canon_canvas, (255, 255, 255)),
                )

                if pose_name != "s_diag_alt":
                    poses_native[pose_name] = native_canvas
                    poses_canon[pose_name] = canon_canvas
                    placements["native"][pose_name] = list(n_rect)
                    placements["canonical"][pose_name] = list(c_rect)

                    head_rgba = crop_head_from_pose(native_canvas)
                    cv2.imwrite(str(heads_dir / f"head_{pose_name}_rgba.png"), head_rgba)
                    cv2.imwrite(
                        str(heads_dir / f"head_{pose_name}_gray80.png"),
                        composite_on_bg(head_rgba, (128, 128, 128)),
                    )

            cv2.imwrite(str(sheets_dir / f"sheet_{sp.key}_clean_rgba.png"), np.hstack(sheet_rgba_cols))
            cv2.imwrite(str(sheets_dir / f"sheet_{sp.key}_clean_gray80.png"), np.hstack(sheet_gray_cols))
    finally:
        del isnet_session
        clear_vram()

    # Master 7-direction clockwise compass strips (S, SE, E, NE, N, NW, W)
    compass_rgba = np.hstack([poses_native[k] for k in COMPASS_7_ORDER])
    cv2.imwrite(str(sheets_dir / "sheet_7dir_compass_rgba.png"), compass_rgba)
    cv2.imwrite(str(sheets_dir / "sheet_7dir_compass_gray80.png"), composite_on_bg(compass_rgba, (128, 128, 128)))
    cv2.imwrite(str(sheets_dir / "sheet_7dir_compass_white.png"), composite_on_bg(compass_rgba, (255, 255, 255)))

    audit_strip = draw_alignment_audit_sheet(poses_native, COMPASS_7_ORDER)
    cv2.imwrite(str(sheets_dir / "sheet_7dir_alignment_audit.png"), audit_strip)

    # Canonical paint template strip for 5-part body slicing (1560x1680 cells)
    canon_white_cols = [composite_on_bg(poses_canon[k], (255, 255, 255)) for k in COMPASS_7_ORDER]
    cv2.imwrite(str(prep_dir / "parts5_paint_template_7dir_white.png"), np.hstack(canon_white_cols))
    cv2.imwrite(
        str(prep_dir / "parts5_paint_template_cardinals_sn_1560x1680.png"),
        np.hstack([composite_on_bg(poses_canon["s"], (255, 255, 255)), composite_on_bg(poses_canon["n"], (255, 255, 255))]),
    )

    if run_id_draft:
        draft_vis_cols: list[np.ndarray] = []
        for k in COMPASS_7_ORDER:
            vis_bgr, raw_id = build_auto_id_mask_draft(poses_canon[k], ink_dir / f"{k}_ink_audit.png")
            cv2.imwrite(str(draft_dir / f"{k}_id_mask_paint_draft.png"), vis_bgr)
            cv2.imwrite(str(draft_dir / f"{k}_id_mask_shader_raw.png"), raw_id)
            draft_vis_cols.append(vis_bgr)
        cv2.imwrite(str(draft_dir / "id_mask_draft_7dir_strip.png"), np.hstack(draft_vis_cols))

    summary: dict[str, Any] = {
        "unique_directions": list(COMPASS_7_ORDER),
        "missing_directions": ["sw"],
        "notes": "diagonals Col 1 duplicated S (Front); S, SE, E, NE, N, NW, W are clean and aligned.",
        "native_cell_size": [NATIVE_CELL_W, NATIVE_CELL_H],
        "canonical_cell_size": [CANONICAL_W, CANONICAL_H],
        "placements": placements,
        "pose_metrics": metrics_list,
    }
    (work_dir / "metrics_and_audit.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    export_sw_fix_kit(work_dir)
    return summary


def export_sw_fix_kit(work_dir: Path) -> Path:
    """Create horizontally mirrored SE full-body + square head-collar crops for face-only SW repair."""
    se_path = work_dir / "02_poses_native_rgba" / "se.png"
    se_bgra = cv2.imread(str(se_path), cv2.IMREAD_UNCHANGED)
    if se_bgra is None:
        raise FileNotFoundError(f"Missing mirrored source: {se_path}")

    sw_flip = cv2.flip(se_bgra, 1)
    kit_dir = work_dir / "04_mask_prep_ready" / "sw_fix_kit"
    kit_dir.mkdir(parents=True, exist_ok=True)

    cv2.imwrite(str(kit_dir / "sw_mirror_fullbody_rgba.png"), sw_flip)
    cv2.imwrite(str(kit_dir / "sw_mirror_fullbody_gray80.png"), composite_on_bg(sw_flip, (128, 128, 128)))

    fg = sw_flip[:, :, 3] > 64
    ys, xs = np.where(fg)
    top_y, bot_y = int(ys.min()), int(ys.max())
    fig_h = max(1, bot_y - top_y)
    # Square 1:1 crop around head + collar + upper pauldrons for high-res facial editing in Google Pics
    head_ys, head_xs = np.where(fg[: top_y + int(round(fig_h * 0.24)), :])
    cx = int(round((float(head_xs.min()) + float(head_xs.max())) * 0.5))
    side = max(576, int(round(fig_h * 0.275)))
    side = min(side, sw_flip.shape[1])
    x0 = max(0, min(sw_flip.shape[1] - side, cx - side // 2))
    y0 = max(0, top_y - 48)
    y0 = min(y0, sw_flip.shape[0] - side)

    head_crop_rgba = sw_flip[y0 : y0 + side, x0 : x0 + side]
    cv2.imwrite(str(kit_dir / "sw_mirror_head_crop_rgba.png"), head_crop_rgba)
    cv2.imwrite(str(kit_dir / "sw_mirror_head_crop_gray80.png"), composite_on_bg(head_crop_rgba, (128, 128, 128)))

    crop_meta = {"crop_xywh": [int(x0), int(y0), int(side), int(side)], "canvas_wh": [sw_flip.shape[1], sw_flip.shape[0]]}
    (kit_dir / "sw_crop_rect.json").write_text(json.dumps(crop_meta, indent=2) + "\n", encoding="utf-8")
    return kit_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare Upscayl 4x + clean RGBA/aligned/pre-mask Valentina 8-dir assets.")
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK_DIR)
    parser.add_argument("--skip-id-draft", action="store_true")
    parser.add_argument("--sw-fix-kit-only", action="store_true")
    args = parser.parse_args()

    if args.sw_fix_kit_only:
        kit_dir = export_sw_fix_kit(args.work_dir)
        print(f"Exported SW fix kit -> {kit_dir}")
        return 0

    summary = run_pipeline(args.work_dir, run_id_draft=not args.skip_id_draft)
    print(f"Prepared {len(summary['unique_directions'])} directions ({', '.join(summary['unique_directions'])}); missing={summary['missing_directions']}")
    for m in summary["pose_metrics"]:
        print(
            f"  {m['name']:10s} bbox={m['raw_bbox_xywh']} ink={m['ink_ratio_pct']:4.1f}% "
            f"(med={m['ink_median_luma']:4.1f}) nonink_p01={m['non_ink_p01_luma']:4.1f} "
            f"p99={m['non_ink_p99_luma']:5.1f} holes_removed={m['inner_holes_removed_px']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
