"""Ingest the AI-polished + Upscayl'd 16:9 unique pauldron sheet, mirror symmetric pairs, and reapply all 16 to valentina_v2_planar."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import cv2
import numpy as np

from polish_outlines import _voronoi_fill, alpha_bleed_only
from process_head_8dir_sheet import _build_clean_head_normal_depth
from process_masked_5parts import upscale_with_upscayl

from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR


def _extract_foreground_from_white(bgr_or_bgra: np.ndarray) -> np.ndarray:
    """Remove pure/near-white background via border flood-fill without altering foreground borders."""
    if bgr_or_bgra.shape[2] == 4:
        bgr = bgr_or_bgra[:, :, :3].copy()
        af = bgr_or_bgra[:, :, 3:4].astype(np.float32) / 255.0
        bgr = np.clip(np.round(bgr.astype(np.float32) * af + 255.0 * (1.0 - af)), 0, 255).astype(np.uint8)
    else:
        bgr = bgr_or_bgra.copy()

    h, w = bgr.shape[:2]
    is_near_white = (bgr[:, :, 0] >= 242) & (bgr[:, :, 1] >= 242) & (bgr[:, :, 2] >= 242)
    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    work = is_near_white.astype(np.uint8) * 255
    for x in range(w):
        if work[0, x] == 255 and ff_mask[1, x + 1] == 0:
            cv2.floodFill(work, ff_mask, (x, 0), 128)
        if work[h - 1, x] == 255 and ff_mask[h, x + 1] == 0:
            cv2.floodFill(work, ff_mask, (x, h - 1), 128)
    for y in range(h):
        if work[y, 0] == 255 and ff_mask[y + 1, 1] == 0:
            cv2.floodFill(work, ff_mask, (0, y), 128)
        if work[y, w - 1] == 255 and ff_mask[y + 1, w] == 0:
            cv2.floodFill(work, ff_mask, (w - 1, y), 128)

    fg = work != 128
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8))
    if n_cc > 2:
        areas = stats[1:, cv2.CC_STAT_AREA]
        max_area = float(np.max(areas))
        keep = np.zeros_like(fg)
        for cid in range(1, n_cc):
            if float(stats[cid, cv2.CC_STAT_AREA]) >= max(25.0, 0.015 * max_area):
                keep |= lbl == cid
        fg = keep

    alpha = np.where(fg, 255, 0).astype(np.uint8)
    dist_bg = cv2.distanceTransform(fg.astype(np.uint8), cv2.DIST_L2, 3)
    luma = (
        0.114 * bgr[:, :, 0].astype(np.float32)
        + 0.587 * bgr[:, :, 1].astype(np.float32)
        + 0.299 * bgr[:, :, 2].astype(np.float32)
    )
    bright_rim = fg & (dist_bg <= 1.5) & (luma > 210.0)
    alpha[bright_rim] = np.clip(np.round((250.0 - luma[bright_rim]) / 40.0 * 255.0), 0, 255).astype(np.uint8)
    return alpha_bleed_only(np.dstack([bgr, alpha]))


def _find_upscayl_sheet(upscayl_dir: Path) -> Path:
    candidates = sorted(
        p for p in upscayl_dir.iterdir()
        if p.is_file() and p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
    )
    if not candidates:
        raise FileNotFoundError(f"No upscaled sheet image found in {upscayl_dir}")
    return candidates[0]


def _align_to_orig_patch(gen_bgra: np.ndarray, orig_bgra: np.ndarray, scale: float) -> np.ndarray:
    """Downscale hi-res cleaned pauldron and align it cleanly into orig_bgra's canvas."""
    oh, ow = orig_bgra.shape[:2]
    fg_y, fg_x = np.where(gen_bgra[:, :, 3] >= 64)
    if len(fg_x) == 0:
        return orig_bgra.copy()

    gx0, gy0, gx1, gy1 = int(fg_x.min()), int(fg_y.min()), int(fg_x.max()) + 1, int(fg_y.max()) + 1
    gen_crop = gen_bgra[gy0:gy1, gx0:gx1]
    gh, gw = gen_crop.shape[:2]

    dw = max(1, int(round(gw / max(scale, 0.01))))
    dh = max(1, int(round(gh / max(scale, 0.01))))
    fit_s = min(1.0, (ow - 2) / max(dw, 1), (oh - 2) / max(dh, 1))
    tw = max(1, int(round(dw * fit_s)))
    th = max(1, int(round(dh * fit_s)))
    gen_ds = cv2.resize(gen_crop, (tw, th), interpolation=cv2.INTER_AREA)

    oy, ox = np.where(orig_bgra[:, :, 3] >= 64)
    if len(ox) > 0:
        ocx = 0.5 * (float(ox.min()) + float(ox.max()))
        ocy = 0.5 * (float(oy.min()) + float(oy.max()))
    else:
        ocx, ocy = ow * 0.5, oh * 0.5

    dx = int(round(ocx - tw * 0.5))
    dy = int(round(ocy - th * 0.5))
    dx = max(0, min(ow - tw, dx))
    dy = max(0, min(oh - th, dy))

    out = np.zeros((oh, ow, 4), dtype=np.uint8)
    out[dy : dy + th, dx : dx + tw] = gen_ds
    return alpha_bleed_only(out)


def _write_pauldron_and_maps(
    view: str,
    part_name: str,
    aligned: np.ndarray,
    orig_bgra: np.ndarray,
    backup_dir: Path,
) -> None:
    parts_dir = DEFAULT_OUT_DIR / view / "parts_5"
    p_path = parts_dir / f"{part_name}.png"
    bak_p = backup_dir / f"{view}_{part_name}.png"
    if p_path.exists() and not bak_p.exists():
        shutil.copy2(p_path, bak_p)

    cv2.imwrite(str(p_path), aligned)

    interior_nd = aligned[:, :, 3] >= 128
    nd = _build_clean_head_normal_depth(aligned[:, :, 3])
    non_zero = (nd[:, :, 0] > 0) | (nd[:, :, 1] > 0) | (nd[:, :, 2] > 0)
    valid_nd = interior_nd & non_zero
    if np.any(valid_nd) and not np.all(valid_nd):
        nd = _voronoi_fill(nd, valid_nd)
    cv2.imwrite(str(parts_dir / f"{part_name}_normal_depth.png"), nd)

    id_path = parts_dir / f"{part_name}_id_mask.png"
    id_orig = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
    if id_orig is not None and id_orig.shape[:2] == aligned.shape[:2]:
        orig_fg = (orig_bgra[:, :, 3] >= 128) & (
            (id_orig[:, :, 0] > 0) | (id_orig[:, :, 1] > 0) | (id_orig[:, :, 2] > 0)
        )
        if np.any(orig_fg):
            id_new = _voronoi_fill(id_orig, orig_fg, max_dist_px=24.0)
        else:
            id_new = np.zeros_like(aligned)
            id_new[interior_nd, 1] = 255
            id_new = _voronoi_fill(id_new, interior_nd, max_dist_px=8.0)
    else:
        id_new = np.zeros_like(aligned)
        id_new[interior_nd, 1] = 255
        id_new = _voronoi_fill(id_new, interior_nd, max_dist_px=8.0)
    cv2.imwrite(str(id_path), id_new)


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest AI-polished 16:9 unique pauldron sheet into valentina_v2_planar.")
    parser.add_argument("--sheet", type=Path, default=None, help="Optional explicit path for the upscaled 16:9 sheet.")
    args = parser.parse_args()

    ws_dir = DEFAULT_SOURCE_DIR / "05_mask_ai_workspaces"
    base_dir = ws_dir / "manual_fix_overlays" / "07_pauldron_polish_16x9"
    inputs_dir = base_dir / "inputs"
    upscayl_dir = base_dir / "upscayl_outputs"
    backup_dir = base_dir / "backup_before_ingest"
    backup_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads((inputs_dir / "pauldron_polish_manifest.json").read_text(encoding="utf-8"))
    sheet_key = next(iter(manifest.keys()))
    meta = manifest[sheet_key]

    hd_raw_in = inputs_dir / "01_pauldrons_unique_8_16x9_hd.jpg"
    hd_up_out = upscayl_dir / "01_pauldrons_unique_8_16x9_upscayl4x.png"
    if args.sheet is None and hd_raw_in.exists():
        if (not hd_up_out.exists()) or (hd_raw_in.stat().st_mtime > hd_up_out.stat().st_mtime):
            print(f"[UPSCAYL] 4x {hd_raw_in.name} -> {hd_up_out.name}")
            upscale_with_upscayl(hd_raw_in, hd_up_out, model="digital-art-4x")
    up_path = args.sheet or (hd_up_out if hd_up_out.exists() else _find_upscayl_sheet(upscayl_dir))
    img = cv2.imread(str(up_path), cv2.IMREAD_UNCHANGED)
    if img is None:
        raise FileNotFoundError(f"Could not read {up_path}")

    hd_pauldrons_dir = ws_dir / "manual_fix_overlays" / "06_torso_and_leg_e_16x9" / "hd_pauldrons"
    hd_pauldrons_dir.mkdir(parents=True, exist_ok=True)

    base_w, base_h = [int(v) for v in meta["size"]]
    up_scale_x = img.shape[1] / float(base_w)
    up_scale_y = img.shape[0] / float(base_h)
    print(f"[INGEST] {up_path.name} ({img.shape[1]}x{img.shape[0]}, upscale~{up_scale_x:.2f}x)")

    audit_tiles: list[np.ndarray] = []

    for idx_slot, slot in enumerate(meta["slots"]):
        view = str(slot["view"])
        part_name = str(slot["part"])
        mirror_targets: list[list[str]] = slot.get("mirror_targets", [])
        sx0, sy0, sw, sh = [int(v) for v in slot["slot_rect"]]
        export_scale = float(slot["scale"])

        ux0 = max(0, int(round(sx0 * up_scale_x)))
        uy0 = max(0, int(round(sy0 * up_scale_y)))
        ux1 = min(img.shape[1], int(round((sx0 + sw) * up_scale_x)))
        uy1 = min(img.shape[0], int(round((sy0 + sh) * up_scale_y)))
        slot_img = img[uy0:uy1, ux0:ux1]

        p_path = DEFAULT_OUT_DIR / view / "parts_5" / f"{part_name}.png"
        orig_bgra = cv2.imread(str(p_path), cv2.IMREAD_UNCHANGED)
        if orig_bgra is None:
            raise FileNotFoundError(f"Missing original {p_path}")

        gen_bgra = _extract_foreground_from_white(slot_img)
        # Export cropped HD cell for build_valentina_v2_rig_assets.py reproducibility
        fg_y_c, fg_x_c = np.where(gen_bgra[:, :, 3] >= 64)
        if len(fg_x_c) > 0:
            crop_hd = gen_bgra[int(fg_y_c.min()) : int(fg_y_c.max()) + 1, int(fg_x_c.min()) : int(fg_x_c.max()) + 1]
            cv2.imwrite(str(hd_pauldrons_dir / f"hd_pauldron_{idx_slot}.png"), crop_hd)
        eff_scale = export_scale * 0.5 * (up_scale_x + up_scale_y)
        aligned = _align_to_orig_patch(gen_bgra, orig_bgra, eff_scale)
        _write_pauldron_and_maps(view, part_name, aligned, orig_bgra, backup_dir)
        print(f"  -> updated {view}/parts_5/{part_name}.png ({orig_bgra.shape[1]}x{orig_bgra.shape[0]})")

        # Mirror horizontally to symmetric targets
        for mv, mp in mirror_targets:
            m_path = DEFAULT_OUT_DIR / mv / "parts_5" / f"{mp}.png"
            m_orig = cv2.imread(str(m_path), cv2.IMREAD_UNCHANGED)
            m_flipped = cv2.flip(aligned, 1)
            if m_orig is not None and m_orig.shape[:2] != m_flipped.shape[:2]:
                # Fit into target canvas centered on target fg if dimensions differ slightly
                m_aligned = _align_to_orig_patch(m_flipped, m_orig, 1.0)
            else:
                m_aligned = m_flipped
                if m_orig is None:
                    m_orig = m_aligned
            _write_pauldron_and_maps(mv, mp, m_aligned, m_orig, backup_dir)
            print(f"  -> mirrored to {mv}/parts_5/{mp}.png")

        # Build Before / After tile
        tile = np.full((200, 320, 3), 235, dtype=np.uint8)
        oh, ow = orig_bgra.shape[:2]
        sc = min(130.0 / max(ow, 1), 140.0 / max(oh, 1))
        rw, rh = max(1, int(round(ow * sc))), max(1, int(round(oh * sc)))
        for idx_b, src_b in enumerate((orig_bgra, aligned)):
            rs = cv2.resize(src_b, (rw, rh), interpolation=cv2.INTER_AREA)
            ox = 15 + idx_b * 155 + (140 - rw) // 2
            oy = 42 + (145 - rh) // 2
            af = rs[:, :, 3:4].astype(np.float32) / 255.0
            roi = tile[oy : oy + rh, ox : ox + rw].astype(np.float32)
            tile[oy : oy + rh, ox : ox + rw] = np.clip(
                np.round(rs[:, :, :3].astype(np.float32) * af + roi * (1.0 - af)), 0, 255
            ).astype(np.uint8)
        cv2.putText(tile, f"{view.upper()} {part_name}", (12, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (25, 25, 25), 1)
        cv2.putText(tile, "BEFORE", (48, 38), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (90, 90, 90), 1)
        cv2.putText(tile, "AFTER", (208, 38), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (20, 120, 40), 1)
        audit_tiles.append(tile)

    grid = np.full((2 * 200, 4 * 320, 3), 215, dtype=np.uint8)
    for i, t in enumerate(audit_tiles):
        r, c = divmod(i, 4)
        grid[r * 200 : (r + 1) * 200, c * 320 : (c + 1) * 320] = t
    audit_path = base_dir / "pauldron_polish_audit.png"
    cv2.imwrite(str(audit_path), grid)
    print(f"[AUDIT] {audit_path}")


if __name__ == "__main__":
    main()
