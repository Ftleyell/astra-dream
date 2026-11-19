"""Slice uploaded 16:9 pauldron masks, align to each view's body_core.png, and export visual audit."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from build_valentina_v2_rig_assets import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR

UPLOAD_S_SE_SW_E = Path(
    r"C:\Users\Frani\.gemini\antigravity\brain\741e1e7a-0964-486e-a8bc-2c31d5d45bd1\.user_uploaded\media_1794723038679_dd879515.jpg"
)
UPLOAD_N_NE_NW_W = Path(
    r"C:\Users\Frani\.gemini\antigravity\brain\741e1e7a-0964-486e-a8bc-2c31d5d45bd1\.user_uploaded\media_1794723038660_9b2dfb62.jpg"
)


def main() -> None:
    ws_dir = DEFAULT_SOURCE_DIR / "05_mask_ai_workspaces"
    base_dir = ws_dir / "manual_fix_overlays" / "05_pauldron_masks_16x9"
    masks_out = base_dir / "masks"
    masks_out.mkdir(parents=True, exist_ok=True)

    manifest = json.loads((base_dir / "pauldron_sheets_manifest.json").read_text(encoding="utf-8"))
    sheet_map = {
        "01_body_core_s_se_sw_e_16x9": UPLOAD_S_SE_SW_E,
        "02_body_core_n_ne_nw_w_16x9": UPLOAD_N_NE_NW_W,
    }

    audit_tiles: list[np.ndarray] = []

    for sheet_key, meta in manifest.items():
        up_path = sheet_map[sheet_key]
        img = cv2.imread(str(up_path))
        if img is None:
            raise FileNotFoundError(f"Missing {up_path}")
        sw_target, sh_target = meta["size"]
        if img.shape[1] != sw_target or img.shape[0] != sh_target:
            img = cv2.resize(img, (sw_target, sh_target), interpolation=cv2.INTER_LINEAR)

        for slot in meta["slots"]:
            view = str(slot["view"])
            sx0, sy0, sw, sh = [int(v) for v in slot["slot_rect"]]
            bx, by, bw, bh = [int(v) for v in slot["body_rect"]]
            ow, oh = [int(v) for v in slot["orig_size"]]

            bc_rgba = cv2.imread(str(DEFAULT_OUT_DIR / view / "parts_5" / "body_core.png"), cv2.IMREAD_UNCHANGED)
            bc_alpha = (bc_rgba[:, :, 3] >= 64).astype(np.float32)

            # Search slot_rect for best alignment of (red | green) mask against bc_alpha
            slot_bgr = img[sy0 : sy0 + sh, sx0 : sx0 + sw]
            b_ch, g_ch, r_ch = slot_bgr[:, :, 0].astype(np.int32), slot_bgr[:, :, 1].astype(np.int32), slot_bgr[:, :, 2].astype(np.int32)
            fg_mask = ((r_ch > 90) | (g_ch > 90)).astype(np.float32)

            # Template match bc_alpha (resized to bw, bh) against fg_mask in slot_bgr
            tmpl = cv2.resize(bc_alpha, (bw, bh), interpolation=cv2.INTER_LINEAR)
            res = cv2.matchTemplate(fg_mask, tmpl, cv2.TM_CCOEFF_NORMED)
            _, _, _, max_loc = cv2.minMaxLoc(res)
            mx, my = int(max_loc[0]), int(max_loc[1])

            crop_bgr = slot_bgr[my : my + bh, mx : mx + bw]
            if crop_bgr.shape[1] != ow or crop_bgr.shape[0] != oh:
                crop_bgr = cv2.resize(crop_bgr, (ow, oh), interpolation=cv2.INTER_LINEAR)

            cb, cg, cr = crop_bgr[:, :, 0].astype(np.float32), crop_bgr[:, :, 1].astype(np.float32), crop_bgr[:, :, 2].astype(np.float32)
            is_green = (cg > 105.0) & ((cg - np.maximum(cr, cb)) > 35.0)
            # Soft feather (3px) & dilate slightly (2px) so pauldron ink outlines are cleanly included
            g_dil = cv2.dilate(is_green.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
            g_soft = cv2.GaussianBlur(g_dil.astype(np.float32), (5, 5), 1.0)
            u8 = np.clip(np.round(g_soft * 255.0), 0, 255).astype(np.uint8)

            out_mask = np.zeros((oh, ow, 4), dtype=np.uint8)
            out_mask[:, :, 0] = u8
            out_mask[:, :, 1] = u8
            out_mask[:, :, 2] = u8
            out_mask[:, :, 3] = 255
            cv2.imwrite(str(masks_out / f"{view}_pauldron_mask.png"), out_mask)
            print(f"[PAULDRON MASK] {view}_pauldron_mask.png (green_px={int(is_green.sum())})")

            # Build visual audit tile
            tile = np.full((260, 220, 3), 235, dtype=np.uint8)
            sc = min(200 / max(ow, 1), 220 / max(oh, 1))
            rw, rh = max(1, int(round(ow * sc))), max(1, int(round(oh * sc)))
            bc_rs = cv2.resize(bc_rgba, (rw, rh))
            m_rs = cv2.resize(u8, (rw, rh)).astype(np.float32) / 255.0
            ox, oy = (220 - rw) // 2, 28
            af = bc_rs[:, :, 3:4].astype(np.float32) / 255.0
            rgb = bc_rs[:, :, :3].astype(np.float32)
            # Tint green pauldron area in preview
            rgb[:, :, 1] = np.clip(rgb[:, :, 1] * (1.0 - 0.55 * m_rs) + 255.0 * (0.55 * m_rs), 0, 255)
            roi = tile[oy : oy + rh, ox : ox + rw].astype(np.float32)
            tile[oy : oy + rh, ox : ox + rw] = np.clip(np.round(rgb * af + roi * (1.0 - af)), 0, 255).astype(np.uint8)
            cv2.putText(tile, view.upper(), (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (20, 20, 20), 1)
            audit_tiles.append(tile)

    grid = np.full((2 * 260, 4 * 220, 3), 220, dtype=np.uint8)
    for i, t in enumerate(audit_tiles):
        r, c = divmod(i, 4)
        grid[r * 260 : (r + 1) * 260, c * 220 : (c + 1) * 220] = t
    cv2.imwrite(str(base_dir / "pauldron_mask_audit.png"), grid)
    print(f"[AUDIT] {base_dir / 'pauldron_mask_audit.png'}")


if __name__ == "__main__":
    main()
