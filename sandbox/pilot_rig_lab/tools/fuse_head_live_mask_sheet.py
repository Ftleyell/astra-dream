#!/usr/bin/env python3
"""Fuse AI-generated 16:9 head mask sheets onto canonical Valentina v2 silhouettes.

Combines:
- Canonical silhouette, neck (#0055FF), and monocle (#AA00FF) from `heads/*_id_mask.png`
  (guaranteeing exact IoU = 1.0000 and zero border drift).
- Facial features (#00FFFF iris, #FFFFFF eyelid, #FF6600 eyebrow, #FF0055 mouth)
  from sheet 1 where all 5 face-visible views are aligned and complete.
- 4-zone hair segmentation (#606878 crown, #00FF66 bangs, #FF00FF side locks,
  #80FF00 rear/nape tips) from sheet 2 (and mirrored side_l nape boundary onto
  sheet 1's head_side_r).

Outputs:
- `outputs/heads_8dir_live_mask_16x9.png` (2560x1440 clean mask sheet)
- `guides/audit_01_heads_live_mask_16x9.png` (annotated audit + color legend)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
import scipy.ndimage as ndimage

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from export_head_live_mask_sheet import (  # noqa: E402
    PALETTE_BGR,
    PALETTE_SPEC,
    SHEET_H,
    SHEET_W,
    WORK_SUBDIR,
    _draw_palette_bar,
)
from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

DEFAULT_IMG1 = Path(
    r"C:/Users/Frani/.gemini/antigravity/brain/6a2782c5-870c-48aa-bd0f-fa06a7ff5fb4/.user_uploaded/media_1795142797424_2c19ccb7.jpg"
)
DEFAULT_IMG2 = Path(
    r"C:/Users/Frani/.gemini/antigravity/brain/6a2782c5-870c-48aa-bd0f-fa06a7ff5fb4/.user_uploaded/media_1795142949082_67d745a8.jpg"
)

PALETTE_KEYS: tuple[str, ...] = tuple(k for k, _, _, _, _ in PALETTE_SPEC)
PALETTE_MAT_BGR: np.ndarray = np.stack(
    [np.array(PALETTE_BGR[k], dtype=np.float32) for k in PALETTE_KEYS],
    axis=0,
)
KEY_TO_IDX: dict[str, int] = {k: i for i, k in enumerate(PALETTE_KEYS)}
HAIR_ZONE_KEYS: tuple[str, ...] = ("hair_crown", "hair_bangs", "hair_sides", "hair_back")


def _extract_slot_patch(
    sheet_bgr: np.ndarray,
    piece_rect: list[int],
    orig_size: list[int],
) -> np.ndarray:
    """Crop a scaled slot from a 16:9 sheet of arbitrary resolution and resize to native head size."""
    sh, sw = sheet_bgr.shape[:2]
    dx, dy, nw, nh = piece_rect
    iw, ih = orig_size
    x0 = max(0, int(round(dx * sw / float(SHEET_W))))
    y0 = max(0, int(round(dy * sh / float(SHEET_H))))
    x1 = min(sw, int(round((dx + nw) * sw / float(SHEET_W))))
    y1 = min(sh, int(round((dy + nh) * sh / float(SHEET_H))))
    patch = sheet_bgr[y0:y1, x0:x1]
    return cv2.resize(patch, (iw, ih), interpolation=cv2.INTER_NEAREST)


def _classify_all_palette(patch_bgr: np.ndarray) -> np.ndarray:
    """Return index into PALETTE_KEYS per pixel using Euclidean distance in BGR."""
    diff = patch_bgr.astype(np.float32)[:, :, None, :] - PALETTE_MAT_BGR[None, None, :, :]
    return np.argmin(np.linalg.norm(diff, axis=-1), axis=-1)


def _prune_tiny_components(mask: np.ndarray, min_area: int) -> np.ndarray:
    """Drop isolated tiny connected components under min_area pixels."""
    if min_area <= 1 or not np.any(mask):
        return mask
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
    kept = np.zeros_like(mask, dtype=bool)
    for cc in range(1, n_cc):
        if int(stats[cc, cv2.CC_STAT_AREA]) >= min_area:
            kept |= (lbl == cc)
    return kept


def _keep_largest_component(mask: np.ndarray) -> np.ndarray:
    """Keep only the single largest connected component of mask."""
    if not np.any(mask):
        return mask
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
    if n_cc <= 1:
        return np.zeros_like(mask, dtype=bool)
    best_cc = max(range(1, n_cc), key=lambda cc: int(stats[cc, cv2.CC_STAT_AREA]))
    return lbl == best_cc


def _voronoi_assign_labels(
    target_mask: np.ndarray,
    seed_labels: np.ndarray,
) -> np.ndarray:
    """Fill unassigned pixels (-1) inside target_mask with nearest valid seed label."""
    out = seed_labels.copy()
    missing = target_mask & (out < 0)
    valid = target_mask & (out >= 0)
    if np.any(missing) and np.any(valid):
        indices = ndimage.distance_transform_edt(~valid, return_distances=False, return_indices=True)
        out[missing] = out[indices[0][missing], indices[1][missing]]
    return out


def _fuse_single_head(
    slot: dict,
    heads_dir: Path,
    img1: np.ndarray,
    img2: np.ndarray,
    side_l_slot: dict,
) -> tuple[np.ndarray, dict[str, int], float]:
    """Build pixel-exact fused semantic mask at native head dimensions."""
    hk = str(slot["head_key"])
    iw, ih = int(slot["orig_size"][0]), int(slot["orig_size"][1])
    has_face = bool(slot["has_visible_face"])

    col = cv2.imread(str(heads_dir / f"{hk}.png"), cv2.IMREAD_UNCHANGED)
    idm = cv2.imread(str(heads_dir / f"{hk}_id_mask.png"), cv2.IMREAD_UNCHANGED)
    if col is None or idm is None:
        raise FileNotFoundError(f"Missing canonical head or id_mask for {hk}")

    fg = col[:, :, 3] >= 24
    is_neck = (idm[:, :, 0] > 128) & (idm[:, :, 2] < 100) & fg
    is_monocle = (idm[:, :, 2] > 128) & (idm[:, :, 0] < 100) & fg
    is_hair = (idm[:, :, 3] > 128) & fg & (~is_neck) & (~is_monocle)
    is_skin = fg & (~is_hair) & (~is_neck) & (~is_monocle)

    out = np.zeros((ih, iw, 3), dtype=np.uint8)
    out[is_neck] = PALETTE_BGR["neck"]
    out[is_monocle] = PALETTE_BGR["monocle"]
    out[is_skin] = PALETTE_BGR["face_skin"]

    # 1. Facial features from sheet 1 inside canonical skin region (only on face-visible heads)
    if has_face and np.any(is_skin):
        p1 = _extract_slot_patch(img1, slot["piece_rect"], slot["orig_size"])
        cls1 = _classify_all_palette(p1)
        sy, sx = np.where(is_skin)
        sy0, sy1 = float(sy.min()), float(sy.max())
        sh = max(sy1 - sy0, 1.0)
        yy_grid = np.broadcast_to(np.arange(ih, dtype=np.float32)[:, None], (ih, iw))
        upper_face = yy_grid <= (sy0 + 0.62 * sh)
        lower_face = yy_grid >= (sy0 + 0.45 * sh)
        mono_margin = cv2.dilate(is_monocle.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0

        for fkey, min_a in (("iris_pupil", 18), ("eyelid", 40), ("eyebrow", 18)):
            fmask = is_skin & upper_face & (cls1 == KEY_TO_IDX[fkey])
            fmask = _prune_tiny_components(fmask, min_area=min_a)
            out[fmask] = PALETTE_BGR[fkey]

        # Also exclude pixels near AI-predicted monocle/strap from mouth detection
        ai_mono_margin = cv2.dilate((cls1 == KEY_TO_IDX["monocle"]).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
        mouth_mask = is_skin & lower_face & (~mono_margin) & (~ai_mono_margin) & (cls1 == KEY_TO_IDX["mouth"])
        mouth_mask = _keep_largest_component(_prune_tiny_components(mouth_mask, min_area=35))
        out[mouth_mask] = PALETTE_BGR["mouth"]
    else:
        cls1 = None

    # 2. Hair zones inside canonical hair region
    if hk == "head_side_r":
        if cls1 is None:
            cls1 = _classify_all_palette(_extract_slot_patch(img1, slot["piece_rect"], slot["orig_size"]))
        hair_cls = np.full((ih, iw), -1, dtype=np.int32)
        for hkey in ("hair_crown", "hair_bangs", "hair_sides"):
            hmask = _prune_tiny_components(is_hair & (cls1 == KEY_TO_IDX[hkey]), min_area=20)
            hair_cls[hmask] = KEY_TO_IDX[hkey]

        # Mirror head_side_l nape (#80FF00) from sheet 2 onto head_side_r rear hair
        p2_sl = _extract_slot_patch(img2, side_l_slot["piece_rect"], side_l_slot["orig_size"])
        p2_sl_flip = cv2.resize(np.fliplr(p2_sl), (iw, ih), interpolation=cv2.INTER_NEAREST)
        cls2_flip = _classify_all_palette(p2_sl_flip)
        nape_mask = _prune_tiny_components(is_hair & (cls2_flip == KEY_TO_IDX["hair_back"]), min_area=40)
        keep_front = (hair_cls == KEY_TO_IDX["hair_bangs"]) | (hair_cls == KEY_TO_IDX["hair_crown"])
        hair_cls[nape_mask & (~keep_front)] = KEY_TO_IDX["hair_back"]

        # Convert any remaining side-lock stripe behind the ear to rear/nape hair (#80FF00)
        if np.any(is_skin):
            _, sx_r = np.where(is_skin)
            ear_rear_x = float(sx_r.min()) + 0.24 * max(float(sx_r.max() - sx_r.min()), 1.0)
            xx_grid = np.broadcast_to(np.arange(iw, dtype=np.float32)[None, :], (ih, iw))
            rear_stripe = (hair_cls == KEY_TO_IDX["hair_sides"]) & (xx_grid < ear_rear_x)
            hair_cls[rear_stripe] = KEY_TO_IDX["hair_back"]
    else:
        p2 = _extract_slot_patch(img2, slot["piece_rect"], slot["orig_size"])
        cls2 = _classify_all_palette(p2)
        hair_cls = np.full((ih, iw), -1, dtype=np.int32)
        for hkey in HAIR_ZONE_KEYS:
            hmask = _prune_tiny_components(is_hair & (cls2 == KEY_TO_IDX[hkey]), min_area=20)
            hair_cls[hmask] = KEY_TO_IDX[hkey]

    hair_cls = _voronoi_assign_labels(is_hair, hair_cls)
    for hkey in HAIR_ZONE_KEYS:
        out[is_hair & (hair_cls == KEY_TO_IDX[hkey])] = PALETTE_BGR[hkey]

    # Audit exact silhouette IoU & per-zone pixel counts
    out_fg = out.max(axis=2) > 0
    iou = float((fg & out_fg).sum()) / float(max((fg | out_fg).sum(), 1))
    out_cls = _classify_all_palette(out)
    counts = {
        k: int(((out_cls == KEY_TO_IDX[k]) & fg).sum())
        for k in PALETTE_KEYS
        if k != "background" and ((out_cls == KEY_TO_IDX[k]) & fg).sum() > 0
    }
    return out, counts, iou


def fuse_sheets(
    assets_dir: Path,
    source_dir: Path,
    img1_path: Path,
    img2_path: Path,
) -> Path:
    """Fuse AI sheets onto canonical silhouettes and export final 16:9 live mask sheet."""
    work_dir = source_dir / WORK_SUBDIR
    man_path = work_dir / "head_live_sheet_manifest.json"
    if not man_path.exists():
        raise FileNotFoundError(f"Missing manifest: {man_path}")

    img1 = cv2.imread(str(img1_path))
    img2 = cv2.imread(str(img2_path))
    if img1 is None:
        raise FileNotFoundError(f"Failed to read sheet 1: {img1_path}")
    if img2 is None:
        raise FileNotFoundError(f"Failed to read sheet 2: {img2_path}")

    man = json.loads(man_path.read_text(encoding="utf-8"))
    slots: list[dict] = man["slots"]
    side_l_slot = next(s for s in slots if s["head_key"] == "head_side_l")
    heads_dir = assets_dir / "heads"

    out_sheet = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)
    audit_sheet = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)

    for slot in slots:
        hk = str(slot["head_key"])
        dx, dy, nw, nh = [int(v) for v in slot["piece_rect"]]
        sx, sy, sw, sh = [int(v) for v in slot["slot_rect"]]
        native_mask, counts, iou = _fuse_single_head(slot, heads_dir, img1, img2, side_l_slot)

        scaled_mask = cv2.resize(native_mask, (nw, nh), interpolation=cv2.INTER_NEAREST)
        out_sheet[dy : dy + nh, dx : dx + nw] = scaled_mask
        audit_sheet[dy : dy + nh, dx : dx + nw] = scaled_mask

        cv2.rectangle(audit_sheet, (sx + 3, sy + 3), (sx + sw - 4, sy + sh - 4), (92, 102, 128), 2)
        cv2.putText(
            audit_sheet,
            f"{hk} IoU={iou:.4f}",
            (sx + 16, sy + 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.62,
            (226, 232, 248),
            1,
            cv2.LINE_AA,
        )
        print(f"[FUSE] {hk:14s} IoU={iou:.4f} counts={counts}")

    _draw_palette_bar(audit_sheet)

    out_path = work_dir / "outputs" / "heads_8dir_live_mask_16x9.png"
    audit_path = work_dir / "guides" / "audit_01_heads_live_mask_16x9.png"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_path), out_sheet)
    cv2.imwrite(str(audit_path), audit_sheet)
    print(f"\n[OK] Fused sheet written to: {out_path}")
    print(f"[OK] Audit sheet written to: {audit_path}")
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Fuse AI head mask sheets onto canonical Valentina v2 heads.")
    parser.add_argument("--assets-dir", type=Path, default=REPO_ROOT / DEFAULT_OUT_DIR)
    parser.add_argument("--source-dir", type=Path, default=REPO_ROOT / DEFAULT_SOURCE_DIR)
    parser.add_argument("--img1", type=Path, default=DEFAULT_IMG1, help="Sheet 1 (faces + head_side_r)")
    parser.add_argument("--img2", type=Path, default=DEFAULT_IMG2, help="Sheet 2 (bottom-row 4-zone hair)")
    args = parser.parse_args()
    fuse_sheets(args.assets_dir, args.source_dir, args.img1, args.img2)


if __name__ == "__main__":
    main()
