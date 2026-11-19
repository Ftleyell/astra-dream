"""Extract AI-generated rounded limb caps from 16:9 Joints sheets, align to 1560x1680, and export clean RGBA parts."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from polish_outlines import alpha_bleed_only
from process_masked_5parts import upscale_with_upscayl
from rig_v2_lib.constants import DEFAULT_SOURCE_DIR, DIRECTIONS, PX_H, PX_W, _canonical_rgba_path
from rig_v2_lib.heads_builder import _compute_body_neck_cut
from rig_v2_lib.skeleton_and_normals import _synthesize_rear_arm_maps


def _extract_foreground_from_white(bgr_or_bgra: np.ndarray) -> np.ndarray:
    """Remove pure/near-white background via border flood-fill without altering foreground borders."""
    if bgr_or_bgra.shape[2] == 4:
        bgr = bgr_or_bgra[:, :, :3].copy()
        a_in = bgr_or_bgra[:, :, 3]
        af = a_in.astype(np.float32)[:, :, None] / 255.0
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

    bg_flood = work == 128
    fg = ~bg_flood
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8))
    if n_cc > 2:
        areas = stats[1:, cv2.CC_STAT_AREA]
        best = 1 + int(np.argmax(areas))
        fg = lbl == best

    alpha = np.where(fg, 255, 0).astype(np.uint8)
    dist_bg = cv2.distanceTransform((~bg_flood).astype(np.uint8), cv2.DIST_L2, 3)
    luma = 0.114 * bgr[:, :, 0].astype(np.float32) + 0.587 * bgr[:, :, 1].astype(np.float32) + 0.299 * bgr[:, :, 2].astype(np.float32)
    bright_rim = fg & (dist_bg <= 1.5) & (luma > 210.0)
    alpha[bright_rim] = np.clip(np.round((250.0 - luma[bright_rim]) / 40.0 * 255.0), 0, 255).astype(np.uint8)
    return alpha_bleed_only(np.dstack([bgr, alpha]))


def _align_capped_to_canvas(
    gen_bgra: np.ndarray,
    orig_rgba_full: np.ndarray,
    orig_mask_full: np.ndarray,
    expected_limb_rect: list[int],
) -> np.ndarray:
    """Align AI-capped limb to 1560x1680 canvas using the untouched lower 55% of orig_mask_full."""
    ys, xs = np.where(orig_mask_full)
    ox0, oy0, ox1, oy1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    ow, oh = ox1 - ox0, oy1 - oy0

    # Use bottom 55% (hand/forearm or boot/shin) as rigid anchor
    anchor_y0 = oy0 + int(round(oh * 0.45))
    anchor_crop = orig_rgba_full[anchor_y0:oy1, ox0:ox1]
    anchor_mask = orig_mask_full[anchor_y0:oy1, ox0:ox1]

    # Composite anchor onto white for template matching against generated RGB
    af = anchor_mask.astype(np.float32)[:, :, None]
    anchor_w = np.clip(np.round(anchor_crop[:, :, :3].astype(np.float32) * af + 255.0 * (1.0 - af)), 0, 255).astype(np.uint8)

    gf = gen_bgra[:, :, 3:4].astype(np.float32) / 255.0
    gen_w = np.clip(np.round(gen_bgra[:, :, :3].astype(np.float32) * gf + 255.0 * (1.0 - gf)), 0, 255).astype(np.uint8)

    # Search inside gen_bgra (which has plenty of margin around expected_limb_rect)
    gh, gw = gen_w.shape[:2]
    ah, aw = anchor_w.shape[:2]
    best_x, best_y = 0, 0
    if gh >= ah and gw >= aw:
        res = cv2.matchTemplate(gen_w, anchor_w, cv2.TM_CCOEFF_NORMED)
        _, _, _, max_loc = cv2.minMaxLoc(res)
        best_x, best_y = int(max_loc[0]), int(max_loc[1])

    # Map gen_bgra pixel (best_x, best_y) -> canvas (ox0, anchor_y0)
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

    # Use 100% of the clean AI-generated Joints/ limb (no blending with old cut limb to avoid double lines)
    return alpha_bleed_only(placed)


def main() -> None:
    source_dir = DEFAULT_SOURCE_DIR
    ws_dir = source_dir / "05_mask_ai_workspaces"
    base_dir = ws_dir / "manual_fix_overlays" / "04_cap_sheets_16x9"
    joints_dir = base_dir / "Joints"
    out_dir = base_dir / "capped_rgba_1560x1680"
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads((base_dir / "sheets_manifest.json").read_text(encoding="utf-8"))

    # Preload original canonical masks & RGBA
    orig_data: dict[tuple[str, str], tuple[np.ndarray, np.ndarray]] = {}
    for view in DIRECTIONS:
        ref_rgba = cv2.imread(str(_canonical_rgba_path(source_dir, view)), cv2.IMREAD_UNCHANGED)
        p5_mask = cv2.imread(str(ws_dir / "01_parts_5_despiece" / "split_results" / f"{view}_parts5_mask.png"))
        id_bgra = cv2.imread(str(ws_dir / "02_id_mask_bodies" / "split_results" / f"{view}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        part_masks, _ = _compute_body_neck_cut(p5_mask, id_bgra, ref_rgba)
        for pname in ("arm_r", "arm_l", "leg_r", "leg_l"):
            if int(part_masks[pname].sum()) >= 250:
                orig_data[(view, pname)] = (ref_rgba, part_masks[pname])
        if view in ("e", "w"):
            rear_arm = "arm_l" if view == "e" else "arm_r"
            rear_arm_path = ws_dir / "manual_fix_overlays" / "03_brazo_trasero_e_w" / f"{view}_arm_back_rgba_1560x1680.png"
            if rear_arm_path.exists():
                ra_rgba = cv2.imread(str(rear_arm_path), cv2.IMREAD_UNCHANGED)
                if ra_rgba is not None and ra_rgba.shape[:2] == (PX_H, PX_W):
                    ra_mask, _, _ = _synthesize_rear_arm_maps(ra_rgba)
                    orig_data[(view, rear_arm)] = (ra_rgba, ra_mask)

    joint_files = {p.name[:2]: p for p in joints_dir.glob("*.png")}
    upscayl_dir = base_dir / "upscayl_4x"
    upscayl_dir.mkdir(parents=True, exist_ok=True)
    audit_tiles: list[np.ndarray] = []

    for sheet_key, meta in manifest.items():
        prefix = sheet_key[:2]
        if prefix not in joint_files:
            print(f"[SKIP] missing Joints file for {sheet_key}")
            continue
        src_joint = joint_files[prefix]
        up_joint = upscayl_dir / f"{src_joint.stem}_4x.png"
        if (not up_joint.exists()) or (src_joint.stat().st_mtime > up_joint.stat().st_mtime):
            print(f"[UPSCAYL] 4x {src_joint.name} -> {up_joint.name}")
            upscale_with_upscayl(src_joint, up_joint, model="digital-art-4x")
        active_path = up_joint if up_joint.exists() else src_joint
        sheet_img = cv2.imread(str(active_path), cv2.IMREAD_UNCHANGED)
        if sheet_img is None:
            continue
        mw, mh = [int(v) for v in meta["size"]]
        scale_x = float(sheet_img.shape[1]) / float(mw)
        scale_y = float(sheet_img.shape[0]) / float(mh)

        for slot in meta["slots"]:
            view = str(slot["view"])
            part = str(slot["part"])
            sx0, sy0, sw, sh = [int(v) for v in slot["slot_rect"]]
            ux0 = max(0, int(round(sx0 * scale_x)))
            uy0 = max(0, int(round(sy0 * scale_y)))
            ux1 = min(sheet_img.shape[1], int(round((sx0 + sw) * scale_x)))
            uy1 = min(sheet_img.shape[0], int(round((sy0 + sh) * scale_y)))
            slot_crop_hd = sheet_img[uy0:uy1, ux0:ux1]
            fg_hd = _extract_foreground_from_white(slot_crop_hd)
            if fg_hd.shape[1] != sw or fg_hd.shape[0] != sh:
                interp = cv2.INTER_AREA if (fg_hd.shape[1] > sw or fg_hd.shape[0] > sh) else cv2.INTER_LANCZOS4
                fg = alpha_bleed_only(cv2.resize(fg_hd, (sw, sh), interpolation=interp))
            else:
                fg = fg_hd

            orig_rgba, orig_mask = orig_data[(view, part)]
            aligned = _align_capped_to_canvas(fg, orig_rgba, orig_mask, slot["limb_rect"])
            out_path = out_dir / f"{view}_{part}.png"
            cv2.imwrite(str(out_path), aligned)
            print(f"[CAP] {out_path.name}")

            # Small audit preview crop around upper joint
            ys, xs = np.where(aligned[:, :, 3] >= 128)
            if len(ys) > 0:
                ay0 = max(0, int(ys.min()) - 10)
                ax0 = max(0, int(xs.min()) - 10)
                ax1 = min(PX_W, int(xs.max()) + 10)
                ay1 = min(PX_H, ay0 + 280)
                tile = np.full((240, 200, 3), 240, dtype=np.uint8)
                sub = aligned[ay0:ay1, ax0:ax1]
                sc = min(190 / max(sub.shape[1], 1), 210 / max(sub.shape[0], 1))
                rs = cv2.resize(sub, (max(1, int(sub.shape[1] * sc)), max(1, int(sub.shape[0] * sc))))
                af = rs[:, :, 3:4].astype(np.float32) / 255.0
                ox = (200 - rs.shape[1]) // 2
                oy = 24
                roi = tile[oy : oy + rs.shape[0], ox : ox + rs.shape[1]].astype(np.float32)
                tile[oy : oy + rs.shape[0], ox : ox + rs.shape[1]] = np.clip(np.round(rs[:, :, :3].astype(np.float32) * af + roi * (1.0 - af)), 0, 255).astype(np.uint8)
                cv2.putText(tile, f"{view}/{part}", (8, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (30, 30, 30), 1)
                audit_tiles.append(tile)

    if audit_tiles:
        cols = 6
        rows = (len(audit_tiles) + cols - 1) // cols
        grid = np.full((rows * 240, cols * 200, 3), 230, dtype=np.uint8)
        for i, t in enumerate(audit_tiles):
            r, c = divmod(i, cols)
            grid[r * 240 : (r + 1) * 240, c * 200 : (c + 1) * 200] = t
        cv2.imwrite(str(base_dir / "ingest_cap_audit.png"), grid)
        print(f"[AUDIT] {base_dir / 'ingest_cap_audit.png'}")


if __name__ == "__main__":
    main()
