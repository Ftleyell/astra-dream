#!/usr/bin/env python3
"""Ingest AI-generated piece mask sheets (ID, Normal/Depth, or ILM) back into
Valentina v2's calibrated live assets with:
  - Automatic silhouette alignment (fixes 1-10 px AI drift/rescale)
  - Strict orthogonal palette quantization + 3x3 modal cleanup (kills neon AA halos)
  - Voronoi / Distance-Transform fill inside true piece alpha (eliminates black outline gaps)
  - Automatic horizontal mirroring SE->SW, E->W, NE->NW with L<->R swap (and Nx flip for normals)
  - Automatic visual audit contact sheet (`audit_<kind>.png`)

Usage:
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind id
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind normal
  C:\\Python314\\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind ilm --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from build_valentina_v2_rig_assets import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

WORK_SUBDIR = "06_piece_mask_regen"
IMAGE_EXTS: tuple[str, ...] = (".png", ".jpg", ".jpeg", ".webp")
MIRROR_VIEW_MAP: dict[str, str] = {"se": "sw", "e": "w", "ne": "nw"}
MIRROR_PART_SWAP: dict[str, str] = {
    "body_core": "body_core",
    "arm_r": "arm_l",
    "arm_l": "arm_r",
    "leg_r": "leg_l",
    "leg_l": "leg_r",
    "pauldron_r": "pauldron_l",
    "pauldron_l": "pauldron_r",
}

# Palettes in RGB order for nearest-color classification
# ID Mask: 0=Skin(#FFFF00), 1=Accent(#FF0000), 2=Armor(#00FF00), 3=Suit(#0000FF), 4=Hair/Stocking(#00FFFF)
ID_PALETTE_RGB = np.array([
    [255, 255, 0],    # 0: Skin
    [255, 0, 0],      # 1: Accent (R)
    [0, 255, 0],      # 2: Armor (G)
    [0, 0, 255],      # 3: Suit (B)
    [0, 255, 255],    # 4: Hair / Stockings (A)
], dtype=np.float32)

ID_TO_RGBA = np.array([
    [0, 0, 0, 0],       # 0: Skin -> (0,0,0,0)
    [255, 0, 0, 0],     # 1: Accent -> R
    [0, 255, 0, 0],     # 2: Armor -> G
    [0, 0, 255, 0],     # 3: Suit -> B
    [0, 0, 0, 255],     # 4: Hair/Stockings -> A
], dtype=np.uint8)

# ILM Mask: 0=Metal(#FF0000), 1=Satin(#00FFFF), 2=ShadowAO(#0000FF), 3=ProtectedSkin(#FFFF00), 4=Matte(#00FF00), 5=Emissive(#FF00FF)
ILM_PALETTE_RGB = np.array([
    [255, 0, 0],      # 0: Hard Specular Metal
    [0, 255, 255],    # 1: Satin / Nylon / Hair Angel Ring
    [0, 0, 255],      # 2: Permanent Cel Shadow / AO
    [255, 255, 0],    # 3: Protected Skin / Face
    [0, 255, 0],      # 4: Matte Suit / Base Hair
    [255, 0, 255],    # 5: Emissive Glow
], dtype=np.float32)

ILM_TO_RGBA = np.array([
    [255, 140, 255, 0],   # 0: Metal (R=1.0, G=0.55, B=1.0, A=0.0)
    [148, 133, 191, 0],   # 1: Satin/Nylon (R=0.58, G=0.52, B=0.75, A=0.0)
    [13, 20, 26, 0],      # 2: Shadow AO (R=0.05, G=0.08, B=0.10, A=0.0)
    [20, 235, 46, 0],     # 3: Protected Skin (R=0.08, G=0.92, B=0.18, A=0.0)
    [38, 128, 217, 0],    # 4: Matte Neutral (R=0.15, G=0.50, B=0.85, A=0.0)
    [230, 255, 255, 255], # 5: Emissive Glow (R=0.90, G=1.0, B=1.0, A=1.0)
], dtype=np.uint8)


def _find_output_file(out_dir: Path, stem: str) -> Path | None:
    for ext in IMAGE_EXTS:
        p = out_dir / f"{stem}{ext}"
        if p.exists():
            return p
    return None


def _bbox_of_mask(mask_bool: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask_bool)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _align_slot_to_orig(
    slot_bgr: np.ndarray,
    orig_bgra: np.ndarray,
    is_normal: bool,
) -> np.ndarray:
    """Align extracted AI slot image to the exact original piece dimensions using silhouette bbox fit."""
    oh, ow = orig_bgra.shape[:2]
    orig_fg = orig_bgra[:, :, 3] > 20
    ob = _bbox_of_mask(orig_fg)
    if ob is None:
        return cv2.resize(slot_bgr, (ow, oh), interpolation=cv2.INTER_LINEAR)

    if is_normal:
        # Foreground is pixels differing from neutral #8080FF (BGR 255, 128, 128)
        diff = np.linalg.norm(slot_bgr.astype(np.float32) - np.array([255.0, 128.0, 128.0]), axis=2)
        ai_fg = diff > 14.0
    else:
        # Foreground is non-white pixels
        ai_fg = np.min(slot_bgr, axis=2) < 238

    ab = _bbox_of_mask(ai_fg)
    if ab is None:
        return cv2.resize(slot_bgr, (ow, oh), interpolation=cv2.INTER_LINEAR)

    ox0, oy0, ox1, oy1 = ob
    ax0, ay0, ax1, ay1 = ab
    crop = slot_bgr[ay0:ay1, ax0:ax1]
    target_w = max(1, ox1 - ox0)
    target_h = max(1, oy1 - oy0)
    interp = cv2.INTER_LINEAR if is_normal else cv2.INTER_NEAREST
    resized_crop = cv2.resize(crop, (target_w, target_h), interpolation=interp)

    bg_val = (255, 128, 128) if is_normal else (255, 255, 255)
    aligned = np.full((oh, ow, 3), bg_val, dtype=np.uint8)
    aligned[oy0:oy1, ox0:ox1] = resized_crop
    return aligned


def _voronoi_fill_labels(labels: np.ndarray, valid_mask: np.ndarray, target_alpha: np.ndarray) -> np.ndarray:
    """Fill any invalid/outline pixels inside target_alpha with the nearest valid label via distanceTransform."""
    out = labels.copy()
    need_fill = (target_alpha > 10) & (~valid_mask)
    if not np.any(need_fill) or not np.any(valid_mask):
        return out
    inv = np.where(valid_mask, 0, 255).astype(np.uint8)
    _, nearest_idx = cv2.distanceTransformWithLabels(inv, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    # Build lookup from 1-based pixel label to class label
    valid_ys, valid_xs = np.where(valid_mask)
    # OpenCV distanceTransformWithLabels indexes zero pixels in row-major order starting at 1
    valid_classes = labels[valid_ys, valid_xs]
    fill_ys, fill_xs = np.where(need_fill)
    idx_1based = nearest_idx[fill_ys, fill_xs] - 1
    idx_1based = np.clip(idx_1based, 0, len(valid_classes) - 1)
    out[fill_ys, fill_xs] = valid_classes[idx_1based]
    return out


def _quantize_categorical_mask(
    aligned_bgr: np.ndarray,
    orig_bgra: np.ndarray,
    palette_rgb: np.ndarray,
    to_rgba: np.ndarray,
) -> np.ndarray:
    """Classify pixels to orthogonal palette, discard dark outlines/white bg, modal-clean, and Voronoi-fill."""
    rgb = cv2.cvtColor(aligned_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    alpha = orig_bgra[:, :, 3]
    fg = alpha > 10

    # Valid chromatic pixels: not near-white background and not neutral black/gray outline residue
    c_max = np.max(rgb, axis=2)
    c_min = np.min(rgb, axis=2)
    sat = c_max - c_min
    is_white = (c_min > 215.0) & (sat < 35.0)
    is_dark_navy = (rgb[:, :, 2] >= 36.0) & ((rgb[:, :, 2] - rgb[:, :, 0]) >= 10.0) & ((rgb[:, :, 2] - rgb[:, :, 1]) >= 10.0)
    is_dark_outline = ((c_max < 75.0) | ((c_max < 130.0) & (sat < 45.0))) & (~is_dark_navy)
    valid = fg & (~is_white) & (~is_dark_outline)

    # Nearest Euclidean color in RGB space
    dists = np.linalg.norm(rgb[:, :, None, :] - palette_rgb[None, None, :, :], axis=3)
    labels = np.argmin(dists, axis=2).astype(np.int32)
    # Force dark-navy pixels to Suit (class 3 for ID, class 2 for ILM if navy)
    if palette_rgb.shape[0] == 5:
        labels = np.where(is_dark_navy, 3, labels)

    # 3x3 median/modal cleanup on valid pixels to remove 1px antialiased neon mix fringes
    labels_u8 = labels.astype(np.uint8)
    labels_clean = cv2.medianBlur(labels_u8, 3).astype(np.int32)
    labels = np.where(valid, labels_clean, labels)

    # Voronoi-fill all outline/gap pixels inside the true piece alpha
    filled = _voronoi_fill_labels(labels, valid, alpha)

    # Map class index -> shader RGBA, then convert to OpenCV BGRA for imwrite
    rgba = to_rgba[filled]
    rgba[~fg] = 0
    bgra = np.stack([rgba[:, :, 2], rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 3]], axis=2)
    return bgra


def _process_normal_depth(aligned_bgr: np.ndarray, orig_bgra: np.ndarray) -> np.ndarray:
    """Normalize tangent-space RGB normals, enforce Nz >= 0.15, and synthesize clean depth in alpha."""
    rgb = cv2.cvtColor(aligned_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    alpha = orig_bgra[:, :, 3]
    fg = alpha > 10

    # Gentle edge-preserving bilateral smooth to remove AI compression noise without blurring bevels
    smooth_rgb = cv2.bilateralFilter(rgb.astype(np.uint8), d=5, sigmaColor=22, sigmaSpace=5).astype(np.float32)

    # Decode to [-1, 1], clamp Z >= 0.15, renormalize
    n = (smooth_rgb / 255.0) * 2.0 - 1.0
    n[:, :, 2] = np.maximum(n[:, :, 2], 0.15)
    norm = np.linalg.norm(n, axis=2, keepdims=True)
    n = n / np.maximum(norm, 1e-5)

    # Distance-based rounded depth in alpha channel (0..255)
    dist = cv2.distanceTransform(fg.astype(np.uint8), cv2.DIST_L2, 5)
    max_d = max(float(dist.max()), 1.0)
    depth = np.clip(np.sqrt(dist / max_d) * 255.0, 0.0, 255.0).astype(np.uint8)
    depth[~fg] = 0

    enc = np.clip(np.round((n * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    enc[~fg] = np.array([128, 128, 255], dtype=np.uint8)
    bgra = np.stack([enc[:, :, 2], enc[:, :, 1], enc[:, :, 0], depth], axis=2)
    return bgra


def _mirror_mask(bgra: np.ndarray, kind: str) -> np.ndarray:
    flipped = cv2.flip(bgra, 1)
    if kind == "normal":
        # Invert Nx stored in R channel (index 2 in BGRA)
        flipped = flipped.copy()
        flipped[:, :, 2] = 255 - flipped[:, :, 2]
    return flipped


def _dest_path_for(assets_dir: Path, slot: dict, kind: str, mirrored: bool = False) -> Path:
    suffix = {"id": "id_mask", "normal": "normal_depth", "ilm": "ilm_mask"}[kind]
    if slot["kind"] == "head":
        return assets_dir / "heads" / f"{slot['head_key']}_{suffix}.png"
    view = MIRROR_VIEW_MAP[slot["view"]] if mirrored else slot["view"]
    part = MIRROR_PART_SWAP[slot["part"]] if mirrored else slot["part"]
    return assets_dir / view / "parts_5" / f"{part}_{suffix}.png"


def _make_audit_tile(orig_bgra: np.ndarray, mask_bgra: np.ndarray, kind: str) -> np.ndarray:
    """Create a 3-column [Original | Mask | Overlay] preview tile (240px tall)."""
    th = 220
    oh, ow = orig_bgra.shape[:2]
    tw = max(48, int(round(ow * (th / max(oh, 1)))))

    orig_rgb = orig_bgra[:, :, :3].copy()
    orig_a = orig_bgra[:, :, 3:4].astype(np.float32) / 255.0
    orig_vis = np.clip(orig_rgb * orig_a + 32.0 * (1.0 - orig_a), 0, 255).astype(np.uint8)

    if kind == "id":
        # Visualize A channel (hair/stockings) as Cyan and Skin (0,0,0,0) as warm Yellow inside alpha
        m_vis = mask_bgra[:, :, :3].copy()
        a_ch = mask_bgra[:, :, 3]
        has_a = a_ch > 128
        m_vis[has_a] = (255, 255, 0)  # BGR Cyan
        is_skin = (orig_bgra[:, :, 3] > 20) & (np.max(mask_bgra, axis=2) < 30)
        m_vis[is_skin] = (0, 230, 255)  # BGR Yellow
    else:
        m_vis = mask_bgra[:, :, :3].copy()

    overlay = cv2.addWeighted(orig_vis, 0.50, m_vis, 0.50, 0.0)
    t1 = cv2.resize(orig_vis, (tw, th), interpolation=cv2.INTER_AREA)
    t2 = cv2.resize(m_vis, (tw, th), interpolation=cv2.INTER_NEAREST)
    t3 = cv2.resize(overlay, (tw, th), interpolation=cv2.INTER_AREA)
    return np.hstack([t1, t2, t3])


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest AI piece mask sheets into Valentina v2 live assets.")
    parser.add_argument("--kind", required=True, choices=["id", "normal", "ilm"])
    parser.add_argument("--dry-run", action="store_true", help="Validate & generate audit without overwriting assets.")
    args = parser.parse_args()

    kind: str = args.kind
    assets_dir = DEFAULT_OUT_DIR
    work_root = DEFAULT_SOURCE_DIR / WORK_SUBDIR
    manifest_path = work_root / "piece_sheets_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"Missing manifest: {manifest_path}. Run export_piece_mask_sheets.py first.")

    manifest: dict[str, dict] = json.loads(manifest_path.read_text(encoding="utf-8"))
    out_dir = work_root / f"outputs_{kind}"
    if not out_dir.exists():
        raise FileNotFoundError(f"Missing output directory: {out_dir}")

    processed_sheets = 0
    written_files = 0
    audit_tiles: list[np.ndarray] = []

    for sheet_name, s_meta in manifest.items():
        ai_path = _find_output_file(out_dir, sheet_name)
        if ai_path is None:
            print(f"[SKIP] No encontrado en {out_dir.name}/: {sheet_name}.(png/jpg/webp)")
            continue

        ai_bgr = cv2.imread(str(ai_path), cv2.IMREAD_COLOR)
        if ai_bgr is None:
            print(f"[WARN] No se pudo leer {ai_path}")
            continue

        exp_w, exp_h = int(s_meta["size"][0]), int(s_meta["size"][1])
        if ai_bgr.shape[1] != exp_w or ai_bgr.shape[0] != exp_h:
            interp = cv2.INTER_LINEAR if kind == "normal" else cv2.INTER_NEAREST
            ai_bgr = cv2.resize(ai_bgr, (exp_w, exp_h), interpolation=interp)

        processed_sheets += 1
        for slot in s_meta["slots"]:
            sx, sy, sw, sh = [int(v) for v in slot["slot_rect"]]
            slot_bgr = ai_bgr[sy : sy + sh, sx : sx + sw]
            orig_path = Path(slot["source_rel"])
            orig_bgra = cv2.imread(str(orig_path), cv2.IMREAD_UNCHANGED)
            if orig_bgra is None:
                raise FileNotFoundError(f"Missing source piece: {orig_path}")

            aligned = _align_slot_to_orig(slot_bgr, orig_bgra, is_normal=(kind == "normal"))
            if kind == "id":
                mask_bgra = _quantize_categorical_mask(aligned, orig_bgra, ID_PALETTE_RGB, ID_TO_RGBA)
            elif kind == "ilm":
                mask_bgra = _quantize_categorical_mask(aligned, orig_bgra, ILM_PALETTE_RGB, ILM_TO_RGBA)
            else:
                mask_bgra = _process_normal_depth(aligned, orig_bgra)

            dst = _dest_path_for(assets_dir, slot, kind, mirrored=False)
            if not args.dry_run:
                cv2.imwrite(str(dst), mask_bgra)
            written_files += 1
            if len(audit_tiles) < 16:
                audit_tiles.append(_make_audit_tile(orig_bgra, mask_bgra, kind))

            # Auto-mirror SE->SW, E->W, NE->NW for body pieces
            if slot["kind"] == "body" and slot["view"] in MIRROR_VIEW_MAP:
                mir_dst = _dest_path_for(assets_dir, slot, kind, mirrored=True)
                mir_bgra = _mirror_mask(mask_bgra, kind)
                if not args.dry_run:
                    cv2.imwrite(str(mir_dst), mir_bgra)
                written_files += 1

        print(f"[INGEST:{kind.upper()}] {ai_path.name} -> {len(s_meta['slots'])} piezas procesadas")

    if audit_tiles:
        max_w = max(t.shape[1] for t in audit_tiles)
        padded = [
            cv2.copyMakeBorder(t, 4, 4, 4, max_w - t.shape[1] + 4, cv2.BORDER_CONSTANT, value=(24, 28, 36))
            for t in audit_tiles
        ]
        audit_img = np.vstack(padded)
        audit_path = work_root / f"audit_{kind}.png"
        cv2.imwrite(str(audit_path), audit_img)
        print(f"[AUDIT] Guardado: {audit_path}")

    mode_str = "DRY-RUN" if args.dry_run else "APLICADO"
    print(f"\nResumen ({mode_str}): {processed_sheets} hojas procesadas, {written_files} máscaras {'simuladas' if args.dry_run else 'escritas'}.")


if __name__ == "__main__":
    main()
