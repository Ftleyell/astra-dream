#!/usr/bin/env python3
"""Export standardized 1:1 (2048x2048) 2x2 high-res eye close-up sheets for Valentina v2.

Generates the clean 4-view input reference (`eyes_4dir_zoom_1x1.png`), an aligned
guide overlay (`eyes_4dir_zoom_guide_1x1.png`), exact coordinate manifest
(`eye_sheets_manifest.json`), and prompt files under:
  sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/09_eye_live2d_assets/
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

WORK_SUBDIR = "09_eye_live2d_assets"
SHEET_PX = 2048
MARGIN_PX = 40
GAP_PX = 48
PANEL_PX = 960
CROP_PX = 80
SCALE_FACTOR = PANEL_PX / float(CROP_PX)  # 12.0x exact
FRAME_COLOR_BGR = (220, 212, 208)  # #D0D4DC in BGR
CY_LIFT_PX = 4

EYE_SLOTS: tuple[tuple[str, str, int, int], ...] = (
    ("head_front", "1. head_front (S)", 0, 0),
    ("head_front_r", "2. head_front_r (SE)", 0, 1),
    ("head_front_l", "3. head_front_l (SW)", 1, 0),
    ("head_side_r", "4. head_side_r (E)", 1, 1),
)

ARTIFACT_PREVIEW_PATH = Path(
    "C:/Users/Frani/.gemini/antigravity/brain/6a2782c5-870c-48aa-bd0f-fa06a7ff5fb4/eyes_4dir_zoom_1x1.png"
)

PROMPT_01_TEXT = """# Prompt 1 de 2 — Lámina 1:1 de Iris Completo 360° (Valentina v2 Live2D Eye)

**Imagen base:** `eyes_4dir_zoom_1x1.png` (`2048×2048`, grilla `2×2`, relación de aspecto **`1:1`**)
**Relación de aspecto de salida:** **`1:1`**

```text
Using the attached 1:1 (2x2 grid) anime eye close-up sheet as exact spatial and style reference, isolate and complete ONLY the 4 oval irises on a pure flat solid white (#FFFFFF) background.

Layout and alignment rules:
- Keep the EXACT 1:1 square format and 2x2 quadrant arrangement (top-left, top-right, bottom-left, bottom-right).
- Keep the EXACT center position, scale, tilt, and perspective foreshortening of each of the 4 irises from the reference (do NOT enlarge, shrink, re-center, or change perspective):
  - Top-left: wide front-facing oval iris
  - Top-right: 3/4 right-turned oval iris
  - Bottom-left: narrower 3/4 left-turned foreshortened oval iris
  - Bottom-right: slim narrow side-profile right-facing oval iris

What to DRAW in each of the 4 irises:
- Complete the hidden top 25%-30% arc of each oval iris that was covered by the upper eyelid in the reference so every iris is a 100% complete, smooth, unbroken 360-degree closed oval shape.
- Crisp, continuous, uniform black (#000000) outer ink outline ring all the way around 360 degrees (matching the anime cel-shaded line weight in the reference).
- Pale silver-lavender iris fill (#D6CED8 / #C4B9C9) with a subtle cool grey-lavender inner upper gradient, matching the exact anime cel-shaded palette of the reference.
- Sharp vertical dark cat-slit pupil centered inside each iris.

What to REMOVE completely:
- Remove ALL skin, eyebrows, hair, upper and lower eyelashes, eyelid creases, white sclera, shadows, grid borders, gray frames, and text.
- The area outside the 4 isolated black-ringed oval irises must be 100% pure solid flat white (#FFFFFF) with no lighting reflections, no text, and no borders.
- Do NOT draw any white specular highlight dot or glossy white reflection inside the iris (leave the iris surface clean so our shader renders dynamic specular highlights in real time).
```
"""

PROMPT_02_TEXT = """# Prompt 2 de 2 — Lámina 1:1 de Ojo Cerrado Anime (Valentina v2 Live2D Eye)

**Imagen base:** `eyes_4dir_zoom_1x1.png` (`2048×2048`, grilla `2×2`, relación de aspecto **`1:1`**)
**Relación de aspecto de salida:** **`1:1`**

```text
Edit the attached 1:1 (2x2 grid) anime eye close-up sheet so that ALL FOUR eyes are cleanly closed while keeping everything else 100% pixel-aligned in place.

Strict consistency rules:
- Keep the exact 1:1 2x2 grid layout, panel borders, skin tones, eyebrows, nose bridge shading, hair wisps, and outer silhouettes identical in position, scale, and color to the input sheet.
- In each of the 4 quadrants, replace ONLY the open eye (white sclera, iris, pupil, lower lash) with a clean closed-eye expression in Valentina's exact cel-shaded anime style:
  - Fill the area where the eyeball was with smooth continuous skin matching her exact flat peach skin tone (#E8B5A7 / subtle cool shadow near brow).
  - Draw a graceful downward-curved crisp black anime closed eyelash line along the lower-middle curve of the eye socket, slightly thicker at the outer wing tip to match her upper lash line style and perspective for each angle (front, 3/4 right, 3/4 left, side profile right).
- Keep eyebrows unchanged in exact position and shape. Do NOT add text, labels, watermarks, or extra creases.
```
"""


def _alpha_composite_white(crop_bgra: np.ndarray) -> np.ndarray:
    """Alpha-composite BGRA patch onto pure #FFFFFF and return uint8 BGR."""
    alpha = crop_bgra[:, :, 3:4].astype(np.float32) / 255.0
    bgr = crop_bgra[:, :, :3].astype(np.float32)
    white = np.full_like(bgr, 255.0)
    blended = bgr * alpha + white * (1.0 - alpha)
    return np.clip(np.rint(blended), 0, 255).astype(np.uint8)


def _upscale_crisp(crop_bgr: np.ndarray, target_px: int) -> np.ndarray:
    """Upscale native 80x80 patch 12x cleanly with subtle bilateral smoothing."""
    lanczos = cv2.resize(crop_bgr, (target_px, target_px), interpolation=cv2.INTER_LANCZOS4)
    smooth = cv2.bilateralFilter(lanczos, d=5, sigmaColor=16, sigmaSpace=16)
    blended = cv2.addWeighted(lanczos, 0.65, smooth, 0.35, 0.0)
    return np.clip(blended, 0, 255).astype(np.uint8)


def _clamp_crop_origin(center_val: int, crop_px: int, limit_px: int) -> int:
    origin = center_val - crop_px // 2
    return max(0, min(limit_px - crop_px, origin))


def _panel_origin(row: int, col: int) -> tuple[int, int]:
    px = MARGIN_PX + col * (PANEL_PX + GAP_PX)
    py = MARGIN_PX + row * (PANEL_PX + GAP_PX)
    return px, py


def _draw_socket_guide(panel_bgr: np.ndarray, socket_crop: np.ndarray, local_cx: float, local_cy: float) -> np.ndarray:
    """Overlay crisp cyan almond socket contour and center crosshair on guide panel."""
    out = panel_bgr.copy()
    mask_big = cv2.resize(socket_crop.astype(np.uint8) * 255, (PANEL_PX, PANEL_PX), interpolation=cv2.INTER_NEAREST)
    contours, _ = cv2.findContours(mask_big, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(out, contours, -1, (255, 220, 0), 2, lineType=cv2.LINE_AA)

    cx_p = int(round(local_cx * SCALE_FACTOR))
    cy_p = int(round(local_cy * SCALE_FACTOR))
    arm = 24
    cv2.line(out, (cx_p - arm, cy_p), (cx_p + arm, cy_p), (0, 210, 255), 2, cv2.LINE_AA)
    cv2.line(out, (cx_p, cy_p - arm), (cx_p, cy_p + arm), (0, 210, 255), 2, cv2.LINE_AA)
    cv2.circle(out, (cx_p, cy_p), 5, (0, 80, 255), -1, cv2.LINE_AA)
    return out


def export_eye_sheets(heads_dir: Path, work_dir: Path, artifact_copy: Path | None = None) -> dict[str, Any]:
    inputs_dir = work_dir / "inputs"
    guides_dir = work_dir / "guides"
    outputs_dir = work_dir / "outputs"
    for d in (inputs_dir, guides_dir, outputs_dir):
        d.mkdir(parents=True, exist_ok=True)

    clean_canvas = np.full((SHEET_PX, SHEET_PX, 3), 255, dtype=np.uint8)
    guide_canvas = np.full((SHEET_PX, SHEET_PX, 3), 255, dtype=np.uint8)

    heads_manifest: dict[str, Any] = {}

    for head_name, label, row, col in EYE_SLOTS:
        head_path = heads_dir / f"{head_name}.png"
        mask_path = heads_dir / f"{head_name}_face_live_mask.png"
        img_bgra = cv2.imread(str(head_path), cv2.IMREAD_UNCHANGED)
        flm = cv2.imread(str(mask_path), cv2.IMREAD_UNCHANGED)
        if img_bgra is None or flm is None:
            raise FileNotFoundError(f"Missing head or face_live_mask for {head_name} in {heads_dir}")

        h_px, w_px = img_bgra.shape[:2]
        socket_mask = flm[:, :, 1] > 127  # BGR index 1 == G channel
        ys, xs = np.where(socket_mask)
        if len(xs) == 0:
            raise RuntimeError(f"Empty eye socket G mask on {head_name}")

        gx0, gx1 = int(xs.min()), int(xs.max())
        gy0, gy1 = int(ys.min()), int(ys.max())
        cx = float(xs.mean())
        cy = float(ys.mean())

        x0 = _clamp_crop_origin(int(round(cx)), CROP_PX, w_px)
        y0 = _clamp_crop_origin(int(round(cy)) - CY_LIFT_PX, CROP_PX, h_px)

        crop_bgra = img_bgra[y0 : y0 + CROP_PX, x0 : x0 + CROP_PX]
        crop_bgr = _alpha_composite_white(crop_bgra)
        panel_bgr = _upscale_crisp(crop_bgr, PANEL_PX)

        px, py = _panel_origin(row, col)
        clean_canvas[py : py + PANEL_PX, px : px + PANEL_PX] = panel_bgr
        cv2.rectangle(
            clean_canvas,
            (px - 2, py - 2),
            (px + PANEL_PX + 1, py + PANEL_PX + 1),
            FRAME_COLOR_BGR,
            2,
        )

        local_cx = cx - float(x0)
        local_cy = cy - float(y0)
        socket_crop = socket_mask[y0 : y0 + CROP_PX, x0 : x0 + CROP_PX]
        guide_panel = _draw_socket_guide(panel_bgr, socket_crop, local_cx, local_cy)
        guide_canvas[py : py + PANEL_PX, px : px + PANEL_PX] = guide_panel
        cv2.rectangle(
            guide_canvas,
            (px - 2, py - 2),
            (px + PANEL_PX + 1, py + PANEL_PX + 1),
            (90, 100, 120),
            2,
        )
        cv2.putText(
            guide_canvas,
            label,
            (px + 6, py - 12),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.78,
            (35, 42, 55),
            2,
            cv2.LINE_AA,
        )

        heads_manifest[head_name] = {
            "label": label,
            "slot_rc": [row, col],
            "panel_rect": [px, py, PANEL_PX, PANEL_PX],
            "native_img_size": [w_px, h_px],
            "native_crop_rect": [x0, y0, CROP_PX, CROP_PX],
            "socket_bbox_native": [gx0, gy0, gx1, gy1],
            "socket_size_native": [gx1 - gx0 + 1, gy1 - gy0 + 1],
            "socket_center_native": [round(cx, 3), round(cy, 3)],
            "socket_center_uv": [round(cx / float(w_px), 6), round(cy / float(h_px), 6)],
            "socket_center_in_panel": [round(local_cx * SCALE_FACTOR, 2), round(local_cy * SCALE_FACTOR, 2)],
        }

    clean_path = inputs_dir / "eyes_4dir_zoom_1x1.png"
    guide_path = guides_dir / "eyes_4dir_zoom_guide_1x1.png"
    manifest_path = work_dir / "eye_sheets_manifest.json"
    p1_path = work_dir / "PROMPT_01_FULL_IRIS_360.md"
    p2_path = work_dir / "PROMPT_02_CLOSED_EYE.md"

    cv2.imwrite(str(clean_path), clean_canvas)
    cv2.imwrite(str(guide_path), guide_canvas)

    manifest = {
        "sheet_name": "eyes_4dir_zoom_1x1",
        "aspect": "1:1",
        "sheet_size": [SHEET_PX, SHEET_PX],
        "rows": 2,
        "cols": 2,
        "margin_px": MARGIN_PX,
        "gap_px": GAP_PX,
        "panel_px": PANEL_PX,
        "crop_px": CROP_PX,
        "scale_factor": SCALE_FACTOR,
        "cy_lift_px": CY_LIFT_PX,
        "heads": heads_manifest,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    p1_path.write_text(PROMPT_01_TEXT, encoding="utf-8")
    p2_path.write_text(PROMPT_02_TEXT, encoding="utf-8")

    if artifact_copy is not None and artifact_copy.parent.exists():
        shutil.copy2(clean_path, artifact_copy)

    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Export 1:1 (2048x2048) 2x2 eye close-up sheet for Valentina v2.")
    parser.add_argument("--heads-dir", type=Path, default=REPO_ROOT / DEFAULT_OUT_DIR / "heads")
    parser.add_argument("--work-dir", type=Path, default=REPO_ROOT / DEFAULT_SOURCE_DIR / WORK_SUBDIR)
    parser.add_argument("--no-artifact-copy", action="store_true")
    args = parser.parse_args()

    artifact_dest = None if args.no_artifact_copy else ARTIFACT_PREVIEW_PATH
    manifest = export_eye_sheets(args.heads_dir, args.work_dir, artifact_dest)
    print(f"Exported 1:1 ({manifest['sheet_size'][0]}x{manifest['sheet_size'][1]}) eye sheet to {args.work_dir}")
    for h_name, info in manifest["heads"].items():
        print(
            f"  {h_name:12s}: crop={info['native_crop_rect']} socket_size={info['socket_size_native']} "
            f"center_uv={info['socket_center_uv']} panel={info['panel_rect']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
