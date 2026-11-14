"""1:1 Canonical (1560x1680) normal_depth + semantic id_mask pipeline for Valentina parts_5.

Step 1 (--step1):
  1. Runs Sapiens-Lite 0.3B Normal + Depth-Anything-V2-Small on the full-body 1560x1680
     Upscayl-4x renders (s_body_1560x1680.png, n_body_1560x1680.png) so torso, arms, and legs
     share coherent 3D normals and consistent depth scale.
  2. Crops exact 1:1 rects from parts_5_meta.json, fills any silhouette/extrusion pixels
     via nearest foreground pixel, and writes <part>_normal_depth.png for s and n.
  3. Exports a 1:1 side-by-side reference sheet (3120x1680) + legend for 5-color semantic
     id_mask painting/generation:
       #FF0000 (Red)   -> R: Red/emissive accents
       #00FF00 (Green) -> G: Armor panels
       #0000FF (Blue)  -> B: Dark suit
       #00FFFF (Cyan)  -> A: Stockings (leg_l / leg_r only)
       #FFFF00 (Yellow) or #000000 -> Neutral / Skin (0,0,0,0)

Step 2 (--import-id-mask <path>):
  1. Quantizes the colored S+N semantic mask sheet to pure 5-class labels.
  2. Crops exact 1:1 rects matching <part>.png, applies Voronoi nearest-label fill inside
     each part's alpha silhouette, enforces A=0 on non-leg parts, and writes <part>_id_mask.png.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from id_mask_ink_refiner import refine_mask_ink_locked, voronoi_fill_labels  # noqa: E402
from ml_stage_processors import estimate_sapiens_normals_and_depth  # noqa: E402

ROOT_DIR = Path("sandbox/pilot_rig_lab")
ALIGN_DIR = ROOT_DIR / "source_refs" / "photoshop_align"
ASSETS_DIR = ROOT_DIR / "combat_assets" / "valentina_planar"
SHEETS_DIR = ROOT_DIR / "source_refs" / "mask_sheets"

CANVAS_W = 1560
CANVAS_H = 1680


def _crop_rect(meta: dict, part_name: str, part_h: int, part_w: int) -> tuple[int, int, int, int]:
    tex_scale = float(meta.get("tex_scale", 3))
    rx, ry, _, _ = meta["rects"][part_name]
    x0 = int(round(float(rx) * tex_scale))
    y0 = int(round(float(ry) * tex_scale))
    return x0, y0, x0 + part_w, y0 + part_h


def _voronoi_fill(values: np.ndarray, valid_mask: np.ndarray, target_mask: np.ndarray) -> np.ndarray:
    """Fills missing pixels in target_mask from nearest True pixel in valid_mask."""
    out = values.copy()
    missing = target_mask & (~valid_mask)
    if not np.any(missing) or not np.any(valid_mask):
        return out
    _, labels = cv2.distanceTransformWithLabels(
        (~valid_mask).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    vy, vx = np.where(valid_mask)
    my, mx = np.where(missing)
    src_idx = labels[my, mx] - 1
    out[my, mx] = values[vy[src_idx], vx[src_idx]]
    return out


def run_step1() -> None:
    SHEETS_DIR.mkdir(parents=True, exist_ok=True)
    sheet_canvas = np.full((CANVAS_H, CANVAS_W * 2, 3), 255, dtype=np.uint8)

    for idx, view in enumerate(["s", "n"]):
        body_path = ALIGN_DIR / f"{view}_body_1560x1680.png"
        if not body_path.exists():
            raise FileNotFoundError(f"Missing canonical body image: {body_path}")

        print(f"[Step 1] Running Sapiens-Lite 0.3B + Depth-Anything-V2 on {view} ({body_path.name})...")
        body_pil = Image.open(body_path).convert("RGBA")
        nd_pil = estimate_sapiens_normals_and_depth(body_pil)
        nd_rgba = np.array(nd_pil)
        nd_bgra = cv2.cvtColor(nd_rgba, cv2.COLOR_RGBA2BGRA)
        body_rgba = np.array(body_pil)
        body_fg = body_rgba[:, :, 3] > 24

        # Add to white-background side-by-side reference sheet for clean mask painting
        alpha_f = (body_rgba[:, :, 3:4].astype(np.float32)) / 255.0
        comp_rgb = (body_rgba[:, :, :3].astype(np.float32) * alpha_f + 255.0 * (1.0 - alpha_f)).astype(np.uint8)
        x_off = idx * CANVAS_W
        sheet_canvas[:, x_off : x_off + CANVAS_W] = comp_rgb

        # Crop exact 1:1 parts_5 normal_depth.png
        parts_dir = ASSETS_DIR / view / "parts_5"
        meta = json.loads((parts_dir / "parts_5_meta.json").read_text(encoding="utf-8"))
        print(f"[Step 1] Writing 1:1 normal_depth.png for {view}/parts_5...")
        for part_name in meta["rects"].keys():
            part_path = parts_dir / f"{part_name}.png"
            part_bgra = cv2.imread(str(part_path), cv2.IMREAD_UNCHANGED)
            ph, pw = part_bgra.shape[:2]
            x0, y0, x1, y1 = _crop_rect(meta, part_name, ph, pw)

            nd_crop = nd_bgra[y0:y1, x0:x1].copy()
            fg_crop = body_fg[y0:y1, x0:x1]
            part_fg = part_bgra[:, :, 3] > 16

            # Fill any geodesic shoulder extrusion or edge anti-alias pixels cleanly
            nd_filled = _voronoi_fill(nd_crop, fg_crop & part_fg, part_fg)
            nd_filled[~part_fg] = 0

            out_nd = parts_dir / f"{part_name}_normal_depth.png"
            cv2.imwrite(str(out_nd), nd_filled)
            r_std = float(np.std(nd_filled[part_fg, 2]))
            g_std = float(np.std(nd_filled[part_fg, 1]))
            a_mean = float(np.mean(nd_filled[part_fg, 3]))
            print(f"  - {view}/{part_name}_normal_depth.png ({pw}x{ph}): std(Nx,Ny)=({r_std:.1f},{g_std:.1f}) mean_Depth={a_mean:.1f}")

    ref_out = SHEETS_DIR / "parts5_id_mask_sheet_ref.png"
    Image.fromarray(sheet_canvas).save(ref_out)
    print(f"[Step 1] Exported 1:1 S+N reference sheet: {ref_out} ({CANVAS_W * 2}x{CANVAS_H})")


def _quantize_5_labels(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Classifies RGB pixels into 5 semantic labels:
    0 = neutral/bg/skin, 1 = Red (accent), 2 = Green (armor), 3 = Blue (dark suit), 4 = Cyan (stockings)
    """
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)

    # Ignore near-white / near-black / neutral gray
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    is_colored = sat > 38

    # Pure palette prototypes in RGB:
    # 1: Red (255,0,0), 2: Green (0,255,0), 3: Blue (0,0,255), 4: Cyan (0,255,255), 5: Yellow (255,255,0 -> neutral)
    protos = np.array([
        [255, 0, 0],     # 1: accent
        [0, 255, 0],     # 2: armor
        [0, 0, 255],     # 3: dark suit
        [0, 255, 255],   # 4: stockings
        [255, 255, 0],   # 5: skin (neutral)
    ], dtype=np.float32)

    pts = rgb.astype(np.float32).reshape(-1, 3)
    dists = np.linalg.norm(pts[:, None, :] - protos[None, :, :], axis=2)
    best = (np.argmin(dists, axis=1) + 1).reshape(rgb.shape[:2])
    best[~is_colored] = 0
    best[best == 5] = 0  # Yellow -> neutral/skin (0)
    return best, is_colored


def _bbox_of_mask(m: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(m)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _align_half_labels_to_body(
    half_rgb: np.ndarray,
    body_fg: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, float]:
    """Aligns a generated S or N mask half to the canonical 1560x1680 body silhouette by bbox + IoU search."""
    # Quantize first at native resolution to avoid color bleeding during resize
    lbl_src, colored_src = _quantize_5_labels(half_rgb)
    # Any non-white pixel (including yellow skin which quantizes to 0) is part of the mask silhouette
    min_ch = np.min(half_rgb, axis=2)
    src_fg = colored_src | (min_ch < 225)
    # Also mark yellow explicitly as label 5 temporarily so we don't confuse it with background during bbox
    is_yellow = colored_src & (half_rgb[:, :, 0] > 180) & (half_rgb[:, :, 1] > 180) & (half_rgb[:, :, 2] < 100)
    lbl_src = np.where(is_yellow, 5, lbl_src)

    sx0, sy0, sx1, sy1 = _bbox_of_mask(src_fg)
    tx0, ty0, tx1, ty1 = _bbox_of_mask(body_fg)
    sw, sh = sx1 - sx0, sy1 - sy0
    tw, th = tx1 - tx0, ty1 - ty0

    lbl_crop = lbl_src[sy0:sy1, sx0:sx1]
    fg_crop = src_fg[sy0:sy1, sx0:sx1]

    # Downsample to 1/4 for fast fine IoU search
    scale_f = 0.25
    bf_small = cv2.resize(body_fg.astype(np.uint8), (CANVAS_W // 4, CANVAS_H // 4), interpolation=cv2.INTER_NEAREST) > 0
    best_iou = -1.0
    best_params = (tx0, ty0, tw, th)

    for dsx in (0.97, 0.99, 1.0, 1.01, 1.03):
        for dsy in (0.97, 0.99, 1.0, 1.01, 1.03):
            rw = max(16, int(round(tw * dsx)))
            rh = max(16, int(round(th * dsy)))
            fg_r = cv2.resize(fg_crop.astype(np.uint8), (max(4, rw // 4), max(4, rh // 4)), interpolation=cv2.INTER_NEAREST) > 0
            for dx in range(-12, 13, 4):
                for dy in range(-12, 13, 4):
                    px = (tx0 + dx) // 4
                    py = (ty0 + dy) // 4
                    canvas = np.zeros_like(bf_small)
                    x_a, y_a = max(0, px), max(0, py)
                    x_b, y_b = min(bf_small.shape[1], px + fg_r.shape[1]), min(bf_small.shape[0], py + fg_r.shape[0])
                    if x_b <= x_a or y_b <= y_a:
                        continue
                    canvas[y_a:y_b, x_a:x_b] = fg_r[y_a - py : y_b - py, x_a - px : x_b - px]
                    inter = int(np.sum(canvas & bf_small))
                    union = int(np.sum(canvas | bf_small))
                    iou = inter / max(union, 1)
                    if iou > best_iou:
                        best_iou = iou
                        best_params = (tx0 + dx, ty0 + dy, rw, rh)

    bx, by, bw, bh = best_params
    lbl_resized = cv2.resize(lbl_crop.astype(np.uint8), (bw, bh), interpolation=cv2.INTER_NEAREST)
    aligned = np.zeros((CANVAS_H, CANVAS_W), dtype=np.uint8)
    x_a, y_a = max(0, bx), max(0, by)
    x_b, y_b = min(CANVAS_W, bx + bw), min(CANVAS_H, by + bh)
    aligned[y_a:y_b, x_a:x_b] = lbl_resized[y_a - by : y_b - by, x_a - bx : x_b - bx]

    # Build RGB visualization of aligned labels and preserve yellow(5) as explicit skin seed
    vis = np.zeros((CANVAS_H, CANVAS_W, 3), dtype=np.uint8)
    vis[aligned == 1] = [255, 0, 0]
    vis[aligned == 2] = [0, 255, 0]
    vis[aligned == 3] = [0, 0, 255]
    vis[aligned == 4] = [0, 255, 255]
    vis[aligned == 5] = [255, 255, 0]

    return aligned, vis, best_iou


def _find_part_owner_mask(
    mask5_crop: np.ndarray,
    part_fg: np.ndarray,
) -> np.ndarray:
    """Identifies the quantized RGB owner label in *_mask5_1560x1680.png for this part."""
    quant = (mask5_crop > 128).astype(np.uint8)
    fg_q = quant[part_fg]
    non_black = fg_q[np.max(fg_q, axis=1) > 0]
    if len(non_black) == 0:
        return np.ones(part_fg.shape, dtype=bool)
    vals, cnts = np.unique(non_black, axis=0, return_counts=True)
    dom = vals[int(np.argmax(cnts))]
    owner = np.all(quant == dom, axis=2)
    return owner


def _extract_shifted_part_prior(
    labels_view: np.ndarray,
    mask5_view: np.ndarray,
    meta: dict,
    part_name: str,
    part_bgra: np.ndarray,
) -> np.ndarray:
    """Crops canonical labels for part_name masked strictly to this part's own silhouette owner."""
    ph, pw = part_bgra.shape[:2]
    x0, y0, x1, y1 = _crop_rect(meta, part_name, ph, pw)
    part_fg = part_bgra[:, :, 3] > 20
    lbl_crop = labels_view[y0:y1, x0:x1].copy()
    m5_crop = mask5_view[y0:y1, x0:x1]
    owner = _find_part_owner_mask(m5_crop, part_fg)
    # Zero out labels that belong to overlapping neighboring parts (e.g. pauldron over torso)
    lbl_crop[~owner] = 0
    if part_name == "body_core":
        # Bottom leg-extrusion stumps (under leg_l/leg_r) stay neutral/skin (5->0), never bleeding suit/panel bands
        bottom_band = np.zeros_like(part_fg)
        bottom_band[int(ph * 0.78) :, :] = True
        lbl_crop[bottom_band & ((~owner) | (labels_view[y0:y1, x0:x1] == 4)) & part_fg] = 5
    return lbl_crop


def _refine_body_part_labels(
    part_name: str,
    part_bgra: np.ndarray,
    lbl_crop: np.ndarray,
) -> np.ndarray:
    """Applies ink-locked SLIC superpixel + Lab graph refinement per body part."""
    lbl = lbl_crop.copy()
    is_leg = part_name in ("leg_l", "leg_r")
    is_arm = part_name in ("arm_l", "arm_r")
    if is_leg:
        # Legs are 100% covered (stockings/armor/suit/accent); disallow bare-skin holes inside thighs
        lbl[lbl == 5] = 0
        return refine_mask_ink_locked(
            part_bgra, lbl, allowed_classes=(1, 2, 3, 4), allow_zero_class=False, erode_px=3, min_island_area=40
        )
    if is_arm:
        # Arms/gloves contain only suit, armor, and accents; disallow stockings & skin bleed
        lbl[(lbl == 4) | (lbl == 5)] = 0
        return refine_mask_ink_locked(
            part_bgra, lbl, allowed_classes=(1, 2, 3), allow_zero_class=False, erode_px=3, min_island_area=35
        )
    # Torso (body_core): keep Yellow(5) bare skin cleanly locked inside ink seams, ignore stockings(4)
    lbl[lbl == 4] = 0
    return refine_mask_ink_locked(
        part_bgra, lbl, allowed_classes=(1, 2, 3), allow_zero_class=True, zero_seed_code=5, erode_px=3, min_island_area=40
    )


def run_import_id_mask(mask_path: Path) -> None:
    if not mask_path.exists():
        raise FileNotFoundError(f"Mask sheet not found: {mask_path}")

    raw_rgb = np.array(Image.open(mask_path).convert("RGB"))
    half_w = raw_rgb.shape[1] // 2
    audit_panels: list[np.ndarray] = []

    for idx, view in enumerate(["s", "n"]):
        half_rgb = raw_rgb[:, idx * half_w : (idx + 1) * half_w]
        body_pil = Image.open(ALIGN_DIR / f"{view}_body_1560x1680.png").convert("RGBA")
        body_rgba = np.array(body_pil)
        body_fg = body_rgba[:, :, 3] > 24
        mask5_bgr = cv2.imread(str(ALIGN_DIR / f"{view}_mask5_1560x1680.png"))

        labels_view, vis_rgb, iou = _align_half_labels_to_body(half_rgb, body_fg)
        print(f"[Import] Aligned {view} mask to canonical 1560x1680 silhouette (IoU={iou:.3f})")

        # Audit overlay: 55% body + 45% aligned semantic mask
        overlay = (body_rgba[:, :, :3].astype(np.float32) * 0.55 + vis_rgb.astype(np.float32) * 0.45).astype(np.uint8)
        overlay[~body_fg] = 240
        audit_panels.append(cv2.resize(overlay, (CANVAS_W // 2, CANVAS_H // 2), interpolation=cv2.INTER_AREA))

        parts_dir = ASSETS_DIR / view / "parts_5"
        meta = json.loads((parts_dir / "parts_5_meta.json").read_text(encoding="utf-8"))
        print(f"[Import] Generating 1:1 ink-locked _id_mask.png for {view}/parts_5...")

        for part_name in meta["rects"].keys():
            part_path = parts_dir / f"{part_name}.png"
            part_bgra = cv2.imread(str(part_path), cv2.IMREAD_UNCHANGED)
            ph, pw = part_bgra.shape[:2]
            lbl_crop = _extract_shifted_part_prior(labels_view, mask5_bgr, meta, part_name, part_bgra)
            part_fg = part_bgra[:, :, 3] > 16
            is_leg = part_name in ("leg_l", "leg_r")

            lbl_refined = _refine_body_part_labels(part_name, part_bgra, lbl_crop)

            # Build BGRA for OpenCV: B=suit(3), G=armor(2), R=accent(1), A=stockings(4)
            alpha_any = part_bgra[:, :, 3] > 0
            id_bgra = np.zeros((ph, pw, 4), dtype=np.uint8)
            id_bgra[:, :, 2] = np.where((lbl_refined == 1) & alpha_any, 255, 0)  # R = accent
            id_bgra[:, :, 1] = np.where((lbl_refined == 2) & alpha_any, 255, 0)  # G = armor
            id_bgra[:, :, 0] = np.where((lbl_refined == 3) & alpha_any, 255, 0)  # B = suit_dark
            id_bgra[:, :, 3] = np.where((lbl_refined == 4) & alpha_any & is_leg, 255, 0)  # A = stockings

            out_id = parts_dir / f"{part_name}_id_mask.png"
            cv2.imwrite(str(out_id), id_bgra)
            fg_cnt = max(int(np.sum(part_fg)), 1)
            r_p = float(np.sum(id_bgra[:, :, 2] > 0)) * 100.0 / fg_cnt
            g_p = float(np.sum(id_bgra[:, :, 1] > 0)) * 100.0 / fg_cnt
            b_p = float(np.sum(id_bgra[:, :, 0] > 0)) * 100.0 / fg_cnt
            a_p = float(np.sum(id_bgra[:, :, 3] > 0)) * 100.0 / fg_cnt
            print(f"  - {view}/{part_name}_id_mask.png (fg%): R={r_p:.1f}% G={g_p:.1f}% B={b_p:.1f}% A={a_p:.1f}%")

    if audit_panels:
        audit_out = SHEETS_DIR / "parts5_id_mask_audit_overlay.png"
        Image.fromarray(np.concatenate(audit_panels, axis=1)).save(audit_out)
        print(f"[Import] Saved alignment audit overlay: {audit_out}")


def run_refine_heads() -> None:
    """Refines all heads/*_id_mask.png onto exact ink seams (hair A, visor R, collar B, skin 0)."""
    heads_dir = ASSETS_DIR / "heads"
    head_files = sorted(p for p in heads_dir.glob("head_*.png") if not p.name.endswith(("_id_mask.png", "_normal_depth.png")))
    print(f"[Heads] Refining {len(head_files)} head ID masks with ink-locked SLIC...")
    for col_path in head_files:
        head_key = col_path.stem
        id_path = heads_dir / f"{head_key}_id_mask.png"
        if not id_path.exists():
            continue
        col_bgra = cv2.imread(str(col_path), cv2.IMREAD_UNCHANGED)
        cur_id = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
        if col_bgra is None or cur_id is None:
            continue
        ph, pw = col_bgra.shape[:2]
        fg = col_bgra[:, :, 3] > 16
        alpha_any = col_bgra[:, :, 3] > 0

        # Resolve any overlapping channels cleanly with priority: R(1) > A(4) > G(2) > B(3)
        b_ch = cur_id[:, :, 0] > 128
        g_ch = cur_id[:, :, 1] > 128
        r_ch = cur_id[:, :, 2] > 128
        a_ch = cur_id[:, :, 3] > 128

        # Collar (B) only belongs on lower neck region; clear spurious B upper bleed (e.g. head_side)
        collar_cut_y = int(round(ph * 0.65))
        b_ch[:collar_cut_y, :] = False

        # Prune stray small components from hair (A: keep bottom nape hair strand on head_side y>=0.74*ph) & collar (B)
        for ch_mask, keep_bottom_strand in ((a_ch, head_key == "head_side"), (b_ch, False)):
            cc_n, cc_lbl, cc_stats, _ = cv2.connectedComponentsWithStats((ch_mask & fg).astype(np.uint8), connectivity=8)
            for ci in range(1, cc_n):
                c_area = int(cc_stats[ci, cv2.CC_STAT_AREA])
                c_top = int(cc_stats[ci, cv2.CC_STAT_TOP])
                if keep_bottom_strand and c_area >= 25 and c_top >= int(ph * 0.74):
                    continue
                if c_area < 120:
                    ch_mask[cc_lbl == ci] = False

        # In head_side where visor peeks cleanly on bridge of nose, seed dark crimson R if missing
        if not np.any(r_ch & fg) and head_key == "head_side":
            g_u8 = col_bgra[:, :, 1].astype(np.float32)
            r_u8 = col_bgra[:, :, 2].astype(np.float32)
            crimson = fg & (r_u8 > 55.0) & (r_u8 > g_u8 * 1.45) & (g_u8 < 80.0)
            roi_visor = np.zeros_like(fg)
            roi_visor[int(ph * 0.36) : int(ph * 0.52), int(pw * 0.75) :] = True
            r_ch = crimson & roi_visor

        prior = np.full((ph, pw), 5, dtype=np.uint8)  # 5 = face skin (maps back to 0)
        prior[b_ch & alpha_any] = 3
        prior[g_ch & alpha_any] = 2
        prior[a_ch & alpha_any] = 4
        prior[r_ch & alpha_any] = 1
        prior[~alpha_any] = 0

        if head_key == "head_side":
            # Low-res 226x213 profile sprite already has 1px-sharp boundaries; propagate labels across dark ink seams onto alpha
            bgr_f = col_bgra[:, :, :3].astype(np.float32) / 255.0
            col_luma = 0.299 * bgr_f[:, :, 2] + 0.587 * bgr_f[:, :, 1] + 0.114 * bgr_f[:, :, 0]
            seed_side = np.where(fg, prior, 0).astype(np.uint8)
            seed_side[(seed_side == 5) & (col_luma < 0.28)] = 0
            refined = voronoi_fill_labels(seed_side, seed_side > 0, alpha_any)
        else:
            clean_prior = np.where(fg, prior, 0).astype(np.uint8)
            for cid in (1, 2, 3, 4):
                cm = (clean_prior == cid).astype(np.uint8)
                n_cc, cc_lbl, cc_stats, _ = cv2.connectedComponentsWithStats(cm, connectivity=8)
                for ci in range(1, n_cc):
                    if int(cc_stats[ci, cv2.CC_STAT_AREA]) < 15:
                        clean_prior[cc_lbl == ci] = 5

            refined = refine_mask_ink_locked(
                col_bgra,
                clean_prior,
                allowed_classes=(1, 2, 3, 4),
                allow_zero_class=True,
                zero_seed_code=5,
                erode_px=1,
                px_per_segment=34,
                min_island_area=60,
            )

        # Keep clean 2px dilated A hair margin only into transparent background right around hair
        hair_fg = (refined == 4) & alpha_any
        hair_dil = cv2.dilate(hair_fg.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        hair_margin = hair_dil & (~alpha_any)

        out_bgra = np.zeros((ph, pw, 4), dtype=np.uint8)
        out_bgra[:, :, 2] = np.where((refined == 1) & alpha_any, 255, 0)  # R = visor
        out_bgra[:, :, 1] = np.where((refined == 2) & alpha_any, 255, 0)  # G = panel
        out_bgra[:, :, 0] = np.where((refined == 3) & alpha_any, 255, 0)  # B = collar suit
        out_bgra[:, :, 3] = np.where(((refined == 4) & alpha_any) | hair_margin, 255, 0)  # A = hair
        cv2.imwrite(str(id_path), out_bgra)
        fg_cnt = max(int(np.sum(fg)), 1)
        print(
            f"  - heads/{head_key}_id_mask.png (fg%): "
            f"R={float(np.sum((out_bgra[:,:,2]>0)&fg))*100.0/fg_cnt:.1f}% "
            f"B={float(np.sum((out_bgra[:,:,0]>0)&fg))*100.0/fg_cnt:.1f}% "
            f"A={float(np.sum((out_bgra[:,:,3]>0)&fg))*100.0/fg_cnt:.1f}%"
        )


def run_export_editable_mask(mask_path: Path) -> None:
    """Exports a clean 1:1 3120x1680 pure-color editable mask aligned to parts5_id_mask_sheet_ref.png."""
    if not mask_path.exists():
        raise FileNotFoundError(f"Mask sheet not found: {mask_path}")

    raw_rgb = np.array(Image.open(mask_path).convert("RGB"))
    half_w = raw_rgb.shape[1] // 2
    out_canvas = np.full((CANVAS_H, CANVAS_W * 2, 3), 255, dtype=np.uint8)

    for idx, view in enumerate(["s", "n"]):
        half_rgb = raw_rgb[:, idx * half_w : (idx + 1) * half_w]
        body_pil = Image.open(ALIGN_DIR / f"{view}_body_1560x1680.png").convert("RGBA")
        body_rgba = np.array(body_pil)
        body_fg = body_rgba[:, :, 3] > 24

        _, vis_rgb, iou = _align_half_labels_to_body(half_rgb, body_fg)
        # Keep pure white outside body_fg, and pure semantic colors inside body_fg
        panel = np.where(body_fg[:, :, None], vis_rgb, np.uint8(255))
        # Any unlabeled pixel inside body_fg becomes Yellow (skin/neutral) so it's visible for editing
        unlabeled_fg = body_fg & (np.max(vis_rgb, axis=2) == 0)
        panel[unlabeled_fg] = [255, 255, 0]

        x_off = idx * CANVAS_W
        out_canvas[:, x_off : x_off + CANVAS_W] = panel
        print(f"[Export] Aligned {view} editable mask (IoU={iou:.3f})")

    out_path = SHEETS_DIR / "parts5_id_mask_aligned_edit.png"
    Image.fromarray(out_canvas).save(out_path)
    print(f"[Export] Saved 1:1 editable mask: {out_path} ({CANVAS_W * 2}x{CANVAS_H})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--step1", action="store_true", help="Run Sapiens+Depth 1560x1680 and export S+N reference sheet.")
    parser.add_argument("--import-id-mask", type=str, default="", help="Import colored S+N semantic id_mask sheet.")
    parser.add_argument("--export-editable-mask", type=str, default="", help="Export 1:1 3120x1680 editable semantic mask.")
    parser.add_argument("--refine-heads", action="store_true", help="Refine all heads/*_id_mask.png onto ink seams.")
    args = parser.parse_args()

    if args.step1:
        run_step1()
    if args.export_editable_mask:
        run_export_editable_mask(Path(args.export_editable_mask))
    if args.import_id_mask:
        run_import_id_mask(Path(args.import_id_mask))
    if args.refine_heads:
        run_refine_heads()
    if not args.step1 and not args.import_id_mask and not args.export_editable_mask and not args.refine_heads:
        parser.print_help()


if __name__ == "__main__":
    main()
