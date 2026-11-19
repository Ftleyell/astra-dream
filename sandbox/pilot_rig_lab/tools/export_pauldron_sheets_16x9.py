"""Export 2 clean 16:9 (2560x1440) body_core sheets on pure white for AI + manual pauldron mask creation."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from build_valentina_v2_rig_assets import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR

SHEET_W = 2560
SHEET_H = 1440
SIDE_MARGIN_PX = 80
VERT_MARGIN_PX = 100


def _build_body_sheet(
    sheet_name: str,
    views: list[str],
    assets_dir: Path,
    out_dir: Path,
) -> dict:
    canvas = np.full((SHEET_H, SHEET_W, 3), 255, dtype=np.uint8)
    n = len(views)
    usable_w = SHEET_W - 2 * SIDE_MARGIN_PX
    slot_w = usable_w // max(n, 1)
    max_h = SHEET_H - 2 * VERT_MARGIN_PX
    slots_meta: list[dict] = []

    for idx, view in enumerate(views):
        bc_path = assets_dir / view / "parts_5" / "body_core.png"
        bgra = cv2.imread(str(bc_path), cv2.IMREAD_UNCHANGED)
        if bgra is None:
            raise FileNotFoundError(f"Missing {bc_path}")
        bh, bw = bgra.shape[:2]
        scale = min((slot_w - 60) / max(bw, 1), max_h / max(bh, 1), 1.0)
        nw = max(1, int(round(bw * scale)))
        nh = max(1, int(round(bh * scale)))
        resized = cv2.resize(bgra, (nw, nh), interpolation=cv2.INTER_AREA if scale < 1.0 else cv2.INTER_LINEAR)

        sx0 = SIDE_MARGIN_PX + idx * slot_w
        dx = sx0 + (slot_w - nw) // 2
        dy = VERT_MARGIN_PX + (max_h - nh) // 2

        alpha = resized[:, :, 3:4].astype(np.float32) / 255.0
        roi = canvas[dy : dy + nh, dx : dx + nw].astype(np.float32)
        blended = resized[:, :, :3].astype(np.float32) * alpha + roi * (1.0 - alpha)
        canvas[dy : dy + nh, dx : dx + nw] = np.clip(np.round(blended), 0, 255).astype(np.uint8)

        slots_meta.append({
            "index": idx,
            "view": view,
            "slot_rect": [sx0, 0, slot_w, SHEET_H],
            "body_rect": [dx, dy, nw, nh],
            "orig_size": [bw, bh],
            "scale": round(scale, 5),
        })

    out_path = out_dir / f"{sheet_name}.png"
    cv2.imwrite(str(out_path), canvas)
    print(f"[SHEET] {out_path.name} ({n} views, {SHEET_W}x{SHEET_H})")
    return {"file": out_path.name, "size": [SHEET_W, SHEET_H], "slots": slots_meta}


def main() -> None:
    ws_dir = DEFAULT_SOURCE_DIR / "05_mask_ai_workspaces"
    out_dir = ws_dir / "manual_fix_overlays" / "05_pauldron_masks_16x9"
    out_dir.mkdir(parents=True, exist_ok=True)

    specs: list[tuple[str, list[str]]] = [
        ("01_body_core_s_se_sw_e_16x9", ["s", "se", "sw", "e"]),
        ("02_body_core_n_ne_nw_w_16x9", ["n", "ne", "nw", "w"]),
    ]
    manifest: dict[str, dict] = {}
    for sname, vlist in specs:
        manifest[sname] = _build_body_sheet(sname, vlist, DEFAULT_OUT_DIR, out_dir)

    (out_dir / "pauldron_sheets_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
