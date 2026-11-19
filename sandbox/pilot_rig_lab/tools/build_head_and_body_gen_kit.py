#!/usr/bin/env python3
"""Build minimal body (5-dir) and close-up asymmetric head reference kits for Google Pics.

Minimal 8-direction generation strategy:
  - Body (collar down, bilaterally symmetric): only 5 canonical views are needed
    (S, SE, E, NE, N). The remaining 3 (SW, W, NW) are deterministically mirrored in Python.
  - Head (asymmetric red left-eye monocle + diagonal bangs): all 8 views are needed
    (S, SE, SW, W, E, NE, NW, N), generated at high close-up bust resolution.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

from prepare_8dir_sheets import (
    DEFAULT_WORK_DIR,
    composite_on_bg,
    crop_head_from_pose,
)

NEUTRAL_GRAY_RGB: tuple[int, int, int] = (128, 128, 128)
SILHOUETTE_FILL_BGR: tuple[int, int, int] = (104, 104, 104)
SILHOUETTE_EDGE_BGR: tuple[int, int, int] = (74, 74, 74)
MINIMAL_BODY_KEYS: tuple[str, ...] = ("s", "se", "e", "ne", "n")


def _load_head_crops(work_dir: Path) -> dict[str, np.ndarray]:
    """Load clean RGBA head+collar crops for available directions."""
    heads_dir = work_dir / "04_mask_prep_ready" / "heads_crops"
    out: dict[str, np.ndarray] = {}
    for key in ("s", "se", "e", "ne", "n", "nw", "w"):
        path = heads_dir / f"head_{key}_rgba.png"
        img = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
        if img is None:
            raise FileNotFoundError(f"Missing prepared head crop: {path}")
        out[key] = img
    return out


def _place_bust_in_cell(
    head_bgra: np.ndarray,
    cell_w: int,
    cell_h: int,
    bottom_pad: int = 24,
    top_pad: int = 44,
) -> np.ndarray:
    """Scale proportionally if needed and align bust horizontally centered at cell bottom."""
    h, w = head_bgra.shape[:2]
    max_h = max(64, cell_h - top_pad - bottom_pad)
    max_w = max(64, cell_w - 48)
    scale = min(1.0, max_h / float(h), max_w / float(w))
    if scale < 0.999:
        nw = max(1, int(round(w * scale)))
        nh = max(1, int(round(h * scale)))
        resized = cv2.resize(head_bgra, (nw, nh), interpolation=cv2.INTER_AREA)
    else:
        resized = head_bgra
        nw, nh = w, h

    canvas = np.zeros((cell_h, cell_w, 4), dtype=np.uint8)
    fg = resized[:, :, 3] > 64
    if np.any(fg):
        _, xs = np.where(fg)
        med_x = int(round(float(np.median(xs))))
        ox = max(4, min(cell_w - nw - 4, (cell_w // 2) - med_x))
    else:
        ox = max(0, (cell_w - nw) // 2)
    oy = max(4, cell_h - bottom_pad - nh)
    canvas[oy : oy + nh, ox : ox + nw] = resized
    return canvas


def _build_sw_neutral_head_silhouette(work_dir: Path, cell_w: int, cell_h: int) -> np.ndarray:
    """Create a smoothed, detail-free SW head+collar silhouette placeholder from mirrored SE."""
    se_path = work_dir / "02_poses_native_rgba" / "se.png"
    se_bgra = cv2.imread(str(se_path), cv2.IMREAD_UNCHANGED)
    if se_bgra is None:
        raise FileNotFoundError(f"Missing SE native pose: {se_path}")

    sw_head = crop_head_from_pose(cv2.flip(se_bgra, 1))
    placed = _place_bust_in_cell(sw_head, cell_w, cell_h)
    mask = (placed[:, :, 3] > 96).astype(np.uint8) * 255

    # Fill enclosed exterior contour so chin-bang gaps vanish, and smooth upper hair contour up to shoulders.
    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, close_kernel)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        mask.fill(0)
        cv2.drawContours(mask, contours, -1, 255, thickness=cv2.FILLED)
    ys, _ = np.where(mask > 0)
    if ys.size > 0:
        hair_split_y = int(ys.min()) + int(round((int(ys.max()) - int(ys.min())) * 0.72))
        blurred = cv2.GaussianBlur(mask.astype(np.float32), (31, 31), 11.0)
        upper_soft = (blurred >= 127.5).astype(np.uint8) * 255
        mask[:hair_split_y, :] = upper_soft[:hair_split_y, :]

    edge_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    inner = cv2.erode(mask, edge_kernel, iterations=1)
    outline = cv2.subtract(mask, inner)

    out_bgr = np.full((cell_h, cell_w, 3), NEUTRAL_GRAY_RGB[0], dtype=np.uint8)
    out_bgr[mask > 0] = SILHOUETTE_FILL_BGR
    out_bgr[outline > 0] = SILHOUETTE_EDGE_BGR
    return out_bgr


def build_head_4cardinals_master(heads: dict[str, np.ndarray], out_path: Path) -> Path:
    """Assemble clean 2x2 close-up reference of the 4 cardinal heads [S, W / E, N]."""
    cell_w, cell_h = 680, 680
    order = (("s", "w"), ("e", "n"))
    rows: list[np.ndarray] = []
    for row_keys in order:
        cols = [composite_on_bg(_place_bust_in_cell(heads[k], cell_w, cell_h), NEUTRAL_GRAY_RGB) for k in row_keys]
        rows.append(np.hstack(cols))
    grid = np.vstack(rows)
    cv2.imwrite(str(out_path), grid)
    return out_path


def build_head_4x2_gap_completion(
    heads: dict[str, np.ndarray],
    work_dir: Path,
    out_path: Path,
) -> Path:
    """Assemble 4x2 turntable grid [SE, S, SW_SILHOUETTE, W / E, NE, N, NW] in 16:9."""
    cell_w, cell_h = 576, 648
    sw_placeholder = _build_sw_neutral_head_silhouette(work_dir, cell_w, cell_h)

    row0 = [
        composite_on_bg(_place_bust_in_cell(heads["se"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
        composite_on_bg(_place_bust_in_cell(heads["s"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
        sw_placeholder,
        composite_on_bg(_place_bust_in_cell(heads["w"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
    ]
    row1 = [
        composite_on_bg(_place_bust_in_cell(heads["e"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
        composite_on_bg(_place_bust_in_cell(heads["ne"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
        composite_on_bg(_place_bust_in_cell(heads["n"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
        composite_on_bg(_place_bust_in_cell(heads["nw"], cell_w, cell_h), NEUTRAL_GRAY_RGB),
    ]
    sheet = np.vstack([np.hstack(row0), np.hstack(row1)])
    cv2.imwrite(str(out_path), sheet)
    return out_path


def build_body_5min_sheet(work_dir: Path, out_path: Path) -> Path:
    """Assemble 16:9 showcase sheet of the 5 unique minimal body poses [S, SE, E, NE, N]."""
    poses_dir = work_dir / "02_poses_native_rgba"
    cols_rgba: list[np.ndarray] = []
    for key in MINIMAL_BODY_KEYS:
        pose = cv2.imread(str(poses_dir / f"{key}.png"), cv2.IMREAD_UNCHANGED)
        if pose is None:
            raise FileNotFoundError(f"Missing body pose: {poses_dir / f'{key}.png'}")
        # Trim outer horizontal margin slightly so 5 poses fit a balanced 16:9 strip cleanly.
        cols_rgba.append(pose[:, 112:-112])

    strip_bgr = composite_on_bg(np.hstack(cols_rgba), NEUTRAL_GRAY_RGB)
    target_w, target_h = 2560, 1440
    scale = min(target_w / float(strip_bgr.shape[1]), target_h / float(strip_bgr.shape[0]))
    nw = int(round(strip_bgr.shape[1] * scale))
    nh = int(round(strip_bgr.shape[0] * scale))
    resized = cv2.resize(strip_bgr, (nw, nh), interpolation=cv2.INTER_AREA)

    canvas = np.full((target_h, target_w, 3), NEUTRAL_GRAY_RGB[0], dtype=np.uint8)
    ox = (target_w - nw) // 2
    oy = (target_h - nh) // 2
    canvas[oy : oy + nh, ox : ox + nw] = resized
    cv2.imwrite(str(out_path), canvas)
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Export minimal 5-body + 8-head Google Pics reference kits.")
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK_DIR)
    args = parser.parse_args()

    heads = _load_head_crops(args.work_dir)
    kit_dir = args.work_dir / "04_mask_prep_ready" / "head_gen_kit"
    kit_dir.mkdir(parents=True, exist_ok=True)

    ref_cardinals = build_head_4cardinals_master(heads, kit_dir / "ref_1_head_4cardinals_2x2_gray80.png")
    ref_gap = build_head_4x2_gap_completion(heads, args.work_dir, kit_dir / "ref_2_head_8dir_turnaround_gap_4x2_gray80.png")
    ref_body5 = build_body_5min_sheet(args.work_dir, kit_dir / "ref_3_body_5min_S_SE_E_NE_N_gray80.png")

    print(f"Exported head_gen_kit -> {kit_dir}")
    print(f"  1) {ref_cardinals.name}")
    print(f"  2) {ref_gap.name}")
    print(f"  3) {ref_body5.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
