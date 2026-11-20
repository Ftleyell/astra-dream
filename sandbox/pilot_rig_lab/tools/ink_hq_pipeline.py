#!/usr/bin/env python3
"""Iterative HQ Ink Lineart Pipeline (1:1 2048x2048 sheets -> Upscayl 4x -> ECC + Optical Flow -> 2x SDF)
for Valentina v2.

Keeps `export_piece_mask_sheets.py` and `ingest_piece_mask_sheets.py` untouched while providing:
  - `--action export`: Exports 13 high-density 1:1 sheets into `07_ink_hq_regen/`
    (`inputs_color/`, `inputs_anchor/`, `guides/`, `ink_hq_manifest.json`, `PROMPTS_INK_HQ.md`).
  - `--action test --sheet <name>`: Upscayls 4x (if needed), runs bounded affine + elastic alignment,
    computes quantitative drift/coverage metrics, and writes a 5-column visual audit without touching live assets.
  - `--action apply --sheet <name>`: Runs the same alignment/SDF bake and writes `*_ink_sdf.png`
    (including mirrored views SW/W/NW, `head_side`, and empty profile pauldrons) into live assets.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from process_masked_5parts import upscale_with_upscayl  # noqa: E402
from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

WORK_SUBDIR: str = "07_ink_hq_regen"
CANVAS_SIZE: tuple[int, int] = (2048, 2048)
OUTER_PAD: int = 64
CELL_PAD: int = 40
INK_SDF_RANGE_PX: float = 8.0
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


def _sheet_specs(assets_dir: Path) -> list[dict]:
    """Define the 13 high-density 1:1 (2048x2048) sheets covering all canonical pieces and heads."""
    def _body_item(view: str, part: str) -> dict:
        return {
            "kind": "body",
            "view": view,
            "part": part,
            "label": f"{view.upper()} {part}",
            "path": str(assets_dir / view / "parts_5" / f"{part}.png"),
        }

    def _head_item(head_key: str) -> dict:
        return {
            "kind": "head",
            "head_key": head_key,
            "label": head_key,
            "path": str(assets_dir / "heads" / f"{head_key}.png"),
        }

    specs: list[dict] = [
        {
            "sheet_name": "01_heads_front_2x2",
            "category": "heads",
            "rows": 2,
            "cols": 2,
            "items": [_head_item(hk) for hk in ("head_front", "head_front_r", "head_front_l", "head_side_r")],
        },
        {
            "sheet_name": "02_heads_back_2x2",
            "category": "heads",
            "rows": 2,
            "cols": 2,
            "items": [_head_item(hk) for hk in ("head_side_l", "head_back_r", "head_back_l", "head_back")],
        },
        {
            "sheet_name": "03_body_core_front_1x3",
            "category": "body_core",
            "rows": 1,
            "cols": 3,
            "items": [_body_item(v, "body_core") for v in ("s", "se", "e")],
        },
        {
            "sheet_name": "04_body_core_back_1x2",
            "category": "body_core",
            "rows": 1,
            "cols": 2,
            "items": [_body_item(v, "body_core") for v in ("ne", "n")],
        },
        {
            "sheet_name": "05_legs_R_front_1x3",
            "category": "legs",
            "rows": 1,
            "cols": 3,
            "items": [_body_item(v, "leg_r") for v in ("s", "se", "e")],
        },
        {
            "sheet_name": "06_legs_R_back_1x2",
            "category": "legs",
            "rows": 1,
            "cols": 2,
            "items": [_body_item(v, "leg_r") for v in ("ne", "n")],
        },
        {
            "sheet_name": "07_legs_L_front_1x3",
            "category": "legs",
            "rows": 1,
            "cols": 3,
            "items": [_body_item(v, "leg_l") for v in ("s", "se", "e")],
        },
        {
            "sheet_name": "08_legs_L_back_1x2",
            "category": "legs",
            "rows": 1,
            "cols": 2,
            "items": [_body_item(v, "leg_l") for v in ("ne", "n")],
        },
        {
            "sheet_name": "09_arms_R_front_1x3",
            "category": "arms",
            "rows": 1,
            "cols": 3,
            "items": [_body_item(v, "arm_r") for v in ("s", "se", "e")],
        },
        {
            "sheet_name": "10_arms_R_back_1x2",
            "category": "arms",
            "rows": 1,
            "cols": 2,
            "items": [_body_item(v, "arm_r") for v in ("ne", "n")],
        },
        {
            "sheet_name": "11_arms_L_front_1x3",
            "category": "arms",
            "rows": 1,
            "cols": 3,
            "items": [_body_item(v, "arm_l") for v in ("s", "se", "e")],
        },
        {
            "sheet_name": "12_arms_L_back_1x2",
            "category": "arms",
            "rows": 1,
            "cols": 2,
            "items": [_body_item(v, "arm_l") for v in ("ne", "n")],
        },
        {
            "sheet_name": "13_pauldrons_3x3",
            "category": "pauldrons",
            "rows": 3,
            "cols": 3,
            "items": [
                _body_item("s", "pauldron_r"),
                _body_item("se", "pauldron_r"),
                _body_item("e", "pauldron_r"),
                _body_item("ne", "pauldron_r"),
                _body_item("n", "pauldron_r"),
                _body_item("s", "pauldron_l"),
                _body_item("se", "pauldron_l"),
                _body_item("ne", "pauldron_l"),
                _body_item("n", "pauldron_l"),
            ],
        },
    ]
    return specs


def _extract_native_ink_2x(orig_bgra: np.ndarray) -> np.ndarray:
    """Extract real dark ink strokes from orig_bgra at 2x supersampled resolution (0.0 px drift)."""
    oh, ow = orig_bgra.shape[:2]
    alpha = orig_bgra[:, :, 3].astype(np.float32)
    if not np.any(alpha > 20.0):
        return np.zeros((oh * 2, ow * 2), dtype=bool)

    bgr = orig_bgra[:, :, :3].astype(np.float32)
    luma = (0.299 * bgr[:, :, 2] + 0.587 * bgr[:, :, 1] + 0.114 * bgr[:, :, 0]) / 255.0
    luma_u8 = np.clip(np.round(luma * 255.0), 0, 255).astype(np.uint8)
    ellipse_5x5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    blackhat = cv2.morphologyEx(luma_u8, cv2.MORPH_BLACKHAT, ellipse_5x5).astype(np.float32)

    interior_1x = cv2.erode((alpha > 180.0).astype(np.uint8) * 255, np.ones((3, 3), dtype=np.uint8), iterations=1)
    luma_2x = cv2.resize(luma, (ow * 2, oh * 2), interpolation=cv2.INTER_CUBIC)
    alpha_2x = cv2.resize(alpha, (ow * 2, oh * 2), interpolation=cv2.INTER_LINEAR)
    blackhat_2x = cv2.resize(blackhat, (ow * 2, oh * 2), interpolation=cv2.INTER_LINEAR)
    interior_2x = cv2.resize(interior_1x, (ow * 2, oh * 2), interpolation=cv2.INTER_NEAREST) > 128

    ink_interior_2x = ((luma_2x < 0.145) | ((blackhat_2x > 19.0) & (luma_2x < 0.22))) & interior_2x
    ink_edge_2x = (alpha_2x > 105.0) & (luma_2x < 0.132)
    return ink_interior_2x | ink_edge_2x


def _bbox_of_mask(mask_bool: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask_bool)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _build_prompts_markdown() -> str:
    return r"""# Prompts HQ para Capa de Tinta (`07_ink_hq_regen/` — 13 Hojas `1:1`)

Pipeline iterativo de alta densidad (`2048x2048` por hoja, `1:1`).
Cada hoja se pasa a **Gemini Web** con **2 imágenes** (o **1 imagen** de fallback) para obtener trazos de clean-up anime (`#000000` sobre `#FFFFFF`), que luego Python escala con **Upscayl (`digital-art-4x`)**, alinea con **ECC Afín + Flujo Óptico acotado** y hornea en `*_ink_sdf.png` **2×**.

## Cómo usar en Gemini Web (Modo 2 Imágenes — Recomendado)
1. Sube **Imagen 1** desde `inputs_color/<hoja>.png` (guía de color, silueta y rasgos).
2. Sube **Imagen 2** desde `inputs_anchor/<hoja>.png` (mapa geométrico exacto de trazos nativos a `0.0 px` de deriva).
3. Copia el **Prompt 2 Imágenes** de la categoría correspondiente y genera en **`1:1`**.
4. **Fallback 1 Imagen** (si Gemini Web deforma o mezcla el grid con 2 entradas): sube **solo** `inputs_color/<hoja>.png` y usa el mismo prompt eliminando las frases que mencionan *Image 2* (en el bloque se indica dónde recortar).
5. Guarda el resultado en `outputs_raw/<hoja>.png` (o `.jpg` / `.webp`) y corre:
   `C:\Python314\python.exe sandbox/pilot_rig_lab/tools/ink_hq_pipeline.py --action test --sheet <hoja>`

---

## Checklist de las 13 Hojas (`1:1`)
| # | Archivo | Grid | Contenido | Categoría Prompt |
| :---: | :--- | :---: | :--- | :--- |
| 1 | `01_heads_front_2x2.png` | `2×2` | `head_front, head_front_r, head_front_l, head_side_r` (+ `head_side` en apply) | **A — Cabezas** |
| 2 | `02_heads_back_2x2.png` | `2×2` | `head_side_l, head_back_r, head_back_l, head_back` | **A — Cabezas** |
| 3 | `03_body_core_front_1x3.png` | `1×3` | `S, SE, E` torsos | **B — Torsos** |
| 4 | `04_body_core_back_1x2.png` | `1×2` | `NE, N` torsos | **B — Torsos** |
| 5 | `05_legs_R_front_1x3.png` | `1×3` | `S, SE, E` pierna derecha | **C — Piernas** |
| 6 | `06_legs_R_back_1x2.png` | `1×2` | `NE, N` pierna derecha | **C — Piernas** |
| 7 | `07_legs_L_front_1x3.png` | `1×3` | `S, SE, E` pierna izquierda | **C — Piernas** |
| 8 | `08_legs_L_back_1x2.png` | `1×2` | `NE, N` pierna izquierda | **C — Piernas** |
| 9 | `09_arms_R_front_1x3.png` | `1×3` | `S, SE, E` brazo derecho | **D — Brazos** |
| 10 | `10_arms_R_back_1x2.png` | `1×2` | `NE, N` brazo derecho | **D — Brazos** |
| 11 | `11_arms_L_front_1x3.png` | `1×3` | `S, SE, E` brazo izquierdo | **D — Brazos** |
| 12 | `12_arms_L_back_1x2.png` | `1×2` | `NE, N` brazo izquierdo | **D — Brazos** |
| 13 | `13_pauldrons_3x3.png` | `3×3` | 9 hombreras (`pauldron_r` S..N + `pauldron_l` S,SE,NE,N) | **E — Hombreras** |

---

## Prompt A — Cabezas (`01_heads_front_2x2`, `02_heads_back_2x2`)
```text
Create an ultra-crisp, studio-quality Japanese anime clean-up ink sheet (douga / genga line art pass) using Image 1 as the color/design reference and Image 2 as the exact geometric line-placement anchor.
Output a 1:1 square image matching the exact 2x2 grid positions, head scales, proportions, eye coordinates, monocle geometry, hair tips, and neck contours of Image 1 and Image 2 with ZERO shifting, resizing, cropping, or redesign.

STRICT INK-ONLY RULES:
- ONLY two tones: #000000 pure black ink lines on a pure #FFFFFF solid white background.
- DO NOT fill dark hair undersides, collars, eye irises, or shadows with solid black blobs or gray tones (solid black is allowed ONLY on the thin upper eyelash line and tiny pupil dot; everything else inside must stay pure #FFFFFF white).
- DELETE 100% of color, gray shading, cel-shading, highlights, blush, gradients, screentones, and sketchy double strokes.
- Re-ink and clean up every line anchored to Image 2 while restoring any faint or broken fine seams visible in Image 1:
  1. Firm, smooth primary outer contours around hair silhouettes, jawline, ears, and neck.
  2. Clean, tapered secondary strokes for silver hair strand divisions and bangs.
  3. Razor-sharp facial linework: eyebrows, upper/lower eyelashes, clean iris ring + small pupil, crisp nose bridge/tip, lips/mouth, and neck collar seam.
  4. Crisp circular red monocle rim and thin monocle head-strap lines (where visible).
- Zero grid borders, zero boxes, zero labels or text anywhere on the image.
```
*(Fallback 1 imagen: sube solo Image 1 y quita `and Image 2 as the exact geometric line-placement anchor`, `and Image 2`, y `anchored to Image 2`.)*

---

## Prompt B — Torsos (`03_body_core_front_1x3`, `04_body_core_back_1x2`)
```text
Create an ultra-crisp, studio-quality Japanese anime clean-up ink sheet (douga / genga line art pass) using Image 1 as the color/design reference and Image 2 as the exact geometric line-placement anchor.
Output a 1:1 square image matching the exact column layout, spacing, scale, silhouette, and seam coordinates of Image 1 and Image 2 with ZERO shifting, resizing, cropping, or redesign.

STRICT INK-ONLY RULES:
- ONLY two tones: #000000 pure black ink lines on a pure #FFFFFF solid white background.
- DO NOT FILL the dark bodysuit, turtleneck collar, hip/waist dark fabric, or inner crevices with solid black or gray! All dark suit areas MUST stay pure #FFFFFF white inside, defined solely by crisp black ink contours and seam lines.
- DELETE 100% of color, shading, gradients, highlights, and sketchy double lines.
- Re-ink every line anchored to Image 2 while cleanly connecting any broken fine seams visible in Image 1:
  1. Firm continuous outer silhouette contour of each torso (including open armhole rings and neck edge).
  2. Crisp armor plate edges (chest/bust carapace, hip plates, upper back armor) and cybernetic spinal vertebrae details on back views.
  3. Fine continuous secondary strokes for crimson trim piping borders, belt/strap borders, cleavage cutout edge, and clean structural suit folds.
- Zero grid borders, zero dividing lines, zero labels or text.
```

---

## Prompt C — Piernas (`05_legs_R_front_1x3` .. `08_legs_L_back_1x2`)
```text
Create an ultra-crisp, studio-quality Japanese anime clean-up ink sheet (douga / genga line art pass) using Image 1 as the color/design reference and Image 2 as the exact geometric line-placement anchor.
Output a 1:1 square image matching the exact column layout, spacing, scale, leg proportions, and boot silhouettes of Image 1 and Image 2 with ZERO shifting, resizing, cropping, or redesign.

STRICT INK-ONLY RULES:
- ONLY two tones: #000000 pure black ink lines on a pure #FFFFFF solid white background.
- DO NOT FILL the dark thigh-high stockings, dark boots, soles, heels, or inner shadows with solid black or gray! Every part of the stocking and boot interior MUST stay pure #FFFFFF white, defined strictly by clean black outline and seam lines.
- DELETE 100% of color, shading, nylon sheen, specular shine, gradients, and sketchy double lines.
- Re-ink every line anchored to Image 2 while cleanly connecting any broken fine seams visible in Image 1:
  1. Firm closed outer silhouette contour from upper thigh through boot tip and heel.
  2. Crisp top thigh stocking cuff band and crimson garter/trim borders.
  3. Clean armored knee shield, shin plate edges, ankle armor, and boot/sole/heel panel seams using crisp secondary line weights.
- Zero grid borders, zero dividing lines, zero labels or text.
```

---

## Prompt D — Brazos (`09_arms_R_front_1x3` .. `12_arms_L_back_1x2`)
```text
Create an ultra-crisp, studio-quality Japanese anime clean-up ink sheet (douga / genga line art pass) using Image 1 as the color/design reference and Image 2 as the exact geometric line-placement anchor.
Output a 1:1 square image matching the exact column layout, spacing, scale, finger pose, and arm proportions of Image 1 and Image 2 with ZERO shifting, resizing, cropping, or redesign.

STRICT INK-ONLY RULES:
- ONLY two tones: #000000 pure black ink lines on a pure #FFFFFF solid white background.
- DO NOT FILL the dark sleeves, cybernetic forearm, or dark gloves/hands with solid black or gray! Keep glove and sleeve interiors pure #FFFFFF white, defined only by razor-sharp black ink outlines and seam lines.
- DELETE 100% of color, shading, highlights, gradients, and sketchy double strokes.
- Re-ink every line anchored to Image 2 while cleaning and separating fine finger/hand lines visible in Image 1:
  1. Firm smooth outer arm contour from shoulder cap to fingertips.
  2. Crisp elbow and forearm bracer armor edges plus crimson strap/cuff trim borders.
  3. Ultra-clean, separated individual finger, thumb, and knuckle ink contours (never merge fingers into solid black blobs).
- Zero grid borders, zero dividing lines, zero labels or text.
```

---

## Prompt E — Hombreras (`13_pauldrons_3x3`)
```text
Create an ultra-crisp, studio-quality Japanese anime clean-up ink sheet (douga / genga line art pass) using Image 1 as the color/design reference and Image 2 as the exact geometric line-placement anchor.
Output a 1:1 square image matching the exact 3x3 grid placement, spacing, scale, and bevel silhouettes of all 9 shoulder pauldrons in Image 1 and Image 2 with ZERO shifting, resizing, cropping, or redesign.

STRICT INK-ONLY RULES:
- ONLY two tones: #000000 pure black ink lines on a pure #FFFFFF solid white background.
- DO NOT FILL dark underside recesses or inner plates with solid black or gray! Keep all plate interiors pure #FFFFFF white, defined strictly by crisp black ink contours.
- DELETE 100% of color, metallic shading, specular highlights, gradients, and sketchy double lines.
- Re-ink every line anchored to Image 2 while sharpening plate corners visible in Image 1:
  1. Firm closed outer silhouette contour for each of the 9 shoulder armor pieces.
  2. Crisp beveled armor seam lines, inner joint recesses, and crimson outer trim borders.
- Zero grid lines, zero bounding boxes, zero labels or text.
```
"""


def _render_and_export_sheet(
    spec: dict,
    out_color_dir: Path,
    out_anchor_dir: Path,
    out_guide_dir: Path,
) -> dict:
    sheet_w, sheet_h = CANVAS_SIZE
    rows, cols = int(spec["rows"]), int(spec["cols"])
    usable_w = sheet_w - 2 * OUTER_PAD
    usable_h = sheet_h - 2 * OUTER_PAD
    slot_w = usable_w // cols
    slot_h = usable_h // rows

    canvas_color = np.full((sheet_h, sheet_w, 3), 255, dtype=np.uint8)
    canvas_anchor = np.full((sheet_h, sheet_w, 3), 255, dtype=np.uint8)
    slots_meta: list[dict] = []

    for idx, item in enumerate(spec["items"]):
        r = idx // cols
        c = idx % cols
        src_path = Path(item["path"])
        orig_bgra = cv2.imread(str(src_path), cv2.IMREAD_UNCHANGED)
        if orig_bgra is None or orig_bgra.ndim < 3 or orig_bgra.shape[2] < 4:
            raise FileNotFoundError(f"Missing RGBA piece PNG: {src_path}")

        ih, iw = orig_bgra.shape[:2]
        avail_w = max(1, slot_w - 2 * CELL_PAD)
        avail_h = max(1, slot_h - 2 * CELL_PAD)
        scale = min(avail_w / max(iw, 1), avail_h / max(ih, 1))
        nw = max(1, int(round(iw * scale)))
        nh = max(1, int(round(ih * scale)))

        sx0 = OUTER_PAD + c * slot_w
        sy0 = OUTER_PAD + r * slot_h
        dx = sx0 + (slot_w - nw) // 2
        dy = sy0 + (slot_h - nh) // 2

        # 1. Color sheet composite on pure #FFFFFF
        interp_color = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_CUBIC
        resized_color = cv2.resize(orig_bgra, (nw, nh), interpolation=interp_color)
        alpha = np.clip(resized_color[:, :, 3:4].astype(np.float32) / 255.0, 0.0, 1.0)
        fg = resized_color[:, :, :3].astype(np.float32)
        roi_c = canvas_color[dy : dy + nh, dx : dx + nw].astype(np.float32)
        canvas_color[dy : dy + nh, dx : dx + nw] = np.clip(
            np.round(fg * alpha + roi_c * (1.0 - alpha)), 0, 255
        ).astype(np.uint8)

        # 2. Native ink anchor sheet (#000000 on #FFFFFF) at exact same [dx, dy, nw, nh]
        ink_2x = _extract_native_ink_2x(orig_bgra)
        ink_2x_u8 = np.where(ink_2x, 0, 255).astype(np.uint8)
        interp_anchor = cv2.INTER_AREA if (nw <= iw * 2 and nh <= ih * 2) else cv2.INTER_CUBIC
        anchor_patch = np.clip(cv2.resize(ink_2x_u8, (nw, nh), interpolation=interp_anchor), 0, 255).astype(np.uint8)
        canvas_anchor[dy : dy + nh, dx : dx + nw] = np.stack([anchor_patch, anchor_patch, anchor_patch], axis=2)

        entry = {
            "index": idx,
            "row": r,
            "col": c,
            "kind": item["kind"],
            "label": item["label"],
            "source_rel": str(src_path.as_posix()),
            "slot_rect": [sx0, sy0, slot_w, slot_h],
            "piece_rect": [dx, dy, nw, nh],
            "orig_size": [iw, ih],
            "scale": round(scale, 5),
        }
        if item["kind"] == "body":
            entry["view"] = item["view"]
            entry["part"] = item["part"]
        else:
            entry["head_key"] = item["head_key"]
        slots_meta.append(entry)

    fname = f"{spec['sheet_name']}.png"
    cv2.imwrite(str(out_color_dir / fname), canvas_color)
    cv2.imwrite(str(out_anchor_dir / fname), canvas_anchor)

    # Human guide sheet with slot frames and labels
    guide = canvas_color.copy()
    for s in slots_meta:
        sx, sy, sw, sh = s["slot_rect"]
        cv2.rectangle(guide, (sx + 2, sy + 2), (sx + sw - 3, sy + sh - 3), (185, 198, 218), 2)
        cv2.putText(
            guide,
            s["label"],
            (sx + 16, sy + 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.95,
            (35, 45, 70),
            2,
            cv2.LINE_AA,
        )
    cv2.imwrite(str(out_guide_dir / fname), guide)
    print(f"[EXPORT] {fname} ({rows}x{cols}, {len(slots_meta)} pcs)")

    return {
        "file": fname,
        "category": spec["category"],
        "size": [sheet_w, sheet_h],
        "rows": rows,
        "cols": cols,
        "slots": slots_meta,
    }


def _export_all_sheets(assets_dir: Path, work_root: Path) -> None:
    inputs_color = work_root / "inputs_color"
    inputs_anchor = work_root / "inputs_anchor"
    guides = work_root / "guides"
    for d in (
        inputs_color,
        inputs_anchor,
        guides,
        work_root / "outputs_raw",
        work_root / "outputs_upscayl",
        work_root / "audits",
    ):
        d.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, dict] = {}
    for spec in _sheet_specs(assets_dir):
        manifest[spec["sheet_name"]] = _render_and_export_sheet(spec, inputs_color, inputs_anchor, guides)

    manifest_path = work_root / "ink_hq_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (work_root / "PROMPTS_INK_HQ.md").write_text(_build_prompts_markdown(), encoding="utf-8")
    print(f"\nExportadas {len(manifest)} hojas 1:1 (2048x2048) en: {work_root}")


def _find_sheet_input(work_root: Path, sheet_name: str, input_override: str | None) -> Path:
    if input_override:
        p = Path(input_override)
        if not p.exists():
            raise FileNotFoundError(f"Input file not found: {p}")
        return p
    out_raw = work_root / "outputs_raw"
    for ext in IMAGE_EXTS:
        cand = out_raw / f"{sheet_name}{ext}"
        if cand.exists():
            return cand
    raise FileNotFoundError(
        f"No raw output found in {out_raw} for '{sheet_name}' with extensions {IMAGE_EXTS}."
    )


def _resolve_ai_sheet(work_root: Path, sheet_name: str, input_override: str | None, no_upscayl: bool) -> np.ndarray:
    raw_path = _find_sheet_input(work_root, sheet_name, input_override)
    raw_bgr = cv2.imread(str(raw_path), cv2.IMREAD_COLOR)
    if raw_bgr is None:
        raise RuntimeError(f"Could not decode image: {raw_path}")

    rh, rw = raw_bgr.shape[:2]
    if no_upscayl or max(rw, rh) > 2200:
        print(f"[INPUT] Usando directo ({rw}x{rh}): {raw_path.name}")
        return raw_bgr

    up_dir = work_root / "outputs_upscayl"
    up_dir.mkdir(parents=True, exist_ok=True)
    up_cache = up_dir / f"{sheet_name}_4x.png"
    if not up_cache.exists() or up_cache.stat().st_mtime < raw_path.stat().st_mtime:
        print(f"[UPSCAYL] digital-art-4x: {raw_path.name} ({rw}x{rh}) -> {up_cache.name}")
        res_path = upscale_with_upscayl(raw_path, up_cache, model="digital-art-4x")
    else:
        print(f"[UPSCAYL] Reutilizando cache: {up_cache.name}")
        res_path = up_cache

    up_bgr = cv2.imread(str(res_path), cv2.IMREAD_COLOR)
    if up_bgr is None:
        return raw_bgr
    uh, uw = up_bgr.shape[:2]
    print(f"[INPUT] Tras Upscayl: {uw}x{uh}")
    return up_bgr


def _alignment_scores(
    ai_gray_4x: np.ndarray,
    native_ink_1x: np.ndarray,
    orig_fg_1x: np.ndarray,
    ink_thresh: int,
) -> tuple[float, float, float, float, float]:
    """Evaluate alignment metrics at 1x native grid.

    Returns `(mean_ai_to_native, mean_native_to_ai, sym_dist, native_cov_2px, ai_near_native_2px)`.
    """
    oh, ow = orig_fg_1x.shape
    gray_1x = cv2.resize(ai_gray_4x, (ow, oh), interpolation=cv2.INTER_AREA)
    fg_guard = cv2.dilate(orig_fg_1x.astype(np.uint8), np.ones((5, 5), dtype=np.uint8), iterations=1) > 0
    ai_ink = (gray_1x < ink_thresh) & fg_guard

    if not np.any(native_ink_1x) or not np.any(ai_ink):
        return 999.0, 999.0, 999.0, 0.0, 0.0

    dist_to_native = cv2.distanceTransform((~native_ink_1x).astype(np.uint8), cv2.DIST_L2, 5)
    dist_to_ai = cv2.distanceTransform((~ai_ink).astype(np.uint8), cv2.DIST_L2, 5)

    ai_dists = dist_to_native[ai_ink]
    nat_dists = dist_to_ai[native_ink_1x]

    mean_ai_to_nat = float(ai_dists.mean())
    mean_nat_to_ai = float(nat_dists.mean())
    sym = 0.5 * (mean_ai_to_nat + mean_nat_to_ai)
    nat_cov_2 = float((nat_dists <= 2.0).mean() * 100.0)
    ai_near_2 = float((ai_dists <= 2.0).mean() * 100.0)
    return mean_ai_to_nat, mean_nat_to_ai, sym, nat_cov_2, ai_near_2


def _encode_sdf_from_ink_4x(ink_4x: np.ndarray, out_w: int, out_h: int) -> np.ndarray:
    """Compute signed distance in native 1x texels from 4x ink mask and resize to (out_w, out_h)."""
    if not np.any(ink_4x):
        return np.full((out_h, out_w, 4), 255, dtype=np.uint8)
    d_out = cv2.distanceTransform((~ink_4x).astype(np.uint8), cv2.DIST_L2, 5) * 0.25
    d_in = cv2.distanceTransform(ink_4x.astype(np.uint8), cv2.DIST_L2, 5) * 0.25
    sdf_4x = d_out - d_in
    sdf = cv2.resize(sdf_4x, (out_w, out_h), interpolation=cv2.INTER_AREA)
    norm = np.clip(0.5 + sdf / (2.0 * INK_SDF_RANGE_PX), 0.0, 1.0)
    u8 = np.clip(np.round(norm * 255.0), 0, 255).astype(np.uint8)
    alpha_full = np.full((out_h, out_w), 255, dtype=np.uint8)
    return np.stack([u8, u8, u8, alpha_full], axis=2)


def _align_and_bake_piece(
    slot_bgr: np.ndarray,
    orig_bgra: np.ndarray,
    ink_thresh: int,
    max_flow: float,
    sdf_scale: int,
) -> dict:
    """Align AI lineart crop onto calibrated orig_bgra using BBox -> Affine ECC -> Bounded Farneback -> SDF."""
    oh, ow = orig_bgra.shape[:2]
    w4, h4 = ow * 4, oh * 4
    orig_fg_1x = orig_bgra[:, :, 3] > 20
    ob = _bbox_of_mask(orig_fg_1x)

    native_ink_2x = _extract_native_ink_2x(orig_bgra)
    native_ink_1x = cv2.resize(native_ink_2x.astype(np.uint8) * 255, (ow, oh), interpolation=cv2.INTER_AREA) >= 96

    slot_gray = cv2.cvtColor(slot_bgr, cv2.COLOR_BGR2GRAY)
    fg_raw = (slot_gray < 210).astype(np.uint8)
    num_cc, labels, stats, _ = cv2.connectedComponentsWithStats(fg_raw, connectivity=8)
    min_area = max(8, int(slot_gray.shape[0] * slot_gray.shape[1] * 1e-5))
    clean_fg = np.zeros_like(fg_raw, dtype=bool)
    for cid in range(1, num_cc):
        if stats[cid, cv2.CC_STAT_AREA] >= min_area:
            clean_fg |= labels == cid
    if not np.any(clean_fg):
        clean_fg = fg_raw > 0

    ab = _bbox_of_mask(clean_fg)
    ai_gray_4x = np.full((h4, w4), 255, dtype=np.uint8)
    if ob is not None and ab is not None:
        ox0, oy0, ox1, oy1 = ob
        ax0, ay0, ax1, ay1 = ab
        crop = slot_gray[ay0:ay1, ax0:ax1]
        tw = max(1, (ox1 - ox0) * 4)
        th = max(1, (oy1 - oy0) * 4)
        interp = cv2.INTER_AREA if (tw < crop.shape[1] or th < crop.shape[0]) else cv2.INTER_CUBIC
        ai_gray_4x[oy0 * 4 : oy1 * 4, ox0 * 4 : ox1 * 4] = cv2.resize(crop, (tw, th), interpolation=interp)
    else:
        ai_gray_4x = cv2.resize(slot_gray, (w4, h4), interpolation=cv2.INTER_LINEAR)

    cur_ai_dist, _, cur_sym, _, _ = _alignment_scores(ai_gray_4x, native_ink_1x, orig_fg_1x, ink_thresh)
    mean_dist_before = cur_ai_dist

    # Stage 1: Fine Affine ECC on 1x ink energy, applied to 4x gray
    ecc_used = False
    if np.any(native_ink_1x) and cur_ai_dist < 500.0:
        gray_1x = cv2.resize(ai_gray_4x, (ow, oh), interpolation=cv2.INTER_AREA)
        nat_energy = cv2.GaussianBlur(native_ink_1x.astype(np.float32), (0, 0), 3.0)
        ai_energy = cv2.GaussianBlur(
            np.clip((255.0 - gray_1x.astype(np.float32)) / 255.0, 0.0, 1.0), (0, 0), 3.0
        )
        warp_1x = np.eye(2, 3, dtype=np.float32)
        criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 80, 1e-4)
        try:
            _, warp_1x = cv2.findTransformECC(nat_energy, ai_energy, warp_1x, cv2.MOTION_AFFINE, criteria)
            det_a = float(warp_1x[0, 0] * warp_1x[1, 1] - warp_1x[0, 1] * warp_1x[1, 0])
            scale_sqrt = math.sqrt(max(0.0, det_a))
            tx, ty = float(warp_1x[0, 2]), float(warp_1x[1, 2])
            if abs(tx) <= 18.0 and abs(ty) <= 18.0 and 0.88 <= scale_sqrt <= 1.12:
                warp_4x = warp_1x.copy()
                warp_4x[0, 2] *= 4.0
                warp_4x[1, 2] *= 4.0
                cand_4x = cv2.warpAffine(
                    ai_gray_4x,
                    warp_4x,
                    (w4, h4),
                    flags=cv2.INTER_CUBIC | cv2.WARP_INVERSE_MAP,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=255,
                )
                c_ai_dist, _, c_sym, _, _ = _alignment_scores(cand_4x, native_ink_1x, orig_fg_1x, ink_thresh)
                if c_sym <= cur_sym + 0.02 and c_ai_dist <= cur_ai_dist + 0.05:
                    ai_gray_4x = cand_4x
                    cur_ai_dist = c_ai_dist
                    cur_sym = c_sym
                    ecc_used = True
        except cv2.error:
            pass

    # Stage 2: Bounded Elastic Micro-Alignment via Farneback Optical Flow
    flow_used = False
    if max_flow > 0.0 and np.any(native_ink_1x) and cur_ai_dist < 500.0:
        gray_1x = cv2.resize(ai_gray_4x, (ow, oh), interpolation=cv2.INTER_AREA)
        nat_soft = np.clip(
            cv2.GaussianBlur(native_ink_1x.astype(np.float32) * 255.0, (0, 0), 2.0), 0, 255
        ).astype(np.uint8)
        ai_soft = np.clip(
            cv2.GaussianBlur(255.0 - gray_1x.astype(np.float32), (0, 0), 2.0), 0, 255
        ).astype(np.uint8)
        flow = cv2.calcOpticalFlowFarneback(nat_soft, ai_soft, None, 0.5, 3, 21, 4, 7, 1.5, 0)
        flow[:, :, 0] = cv2.GaussianBlur(flow[:, :, 0], (0, 0), 7.0)
        flow[:, :, 1] = cv2.GaussianBlur(flow[:, :, 1], (0, 0), 7.0)
        mag = np.sqrt(flow[:, :, 0] ** 2 + flow[:, :, 1] ** 2)
        clamp_scale = np.minimum(1.0, max_flow / np.maximum(mag, 1e-6))
        flow[:, :, 0] *= clamp_scale
        flow[:, :, 1] *= clamp_scale

        flow_x_4x = cv2.resize(flow[:, :, 0], (w4, h4), interpolation=cv2.INTER_LINEAR) * 4.0
        flow_y_4x = cv2.resize(flow[:, :, 1], (w4, h4), interpolation=cv2.INTER_LINEAR) * 4.0
        grid_x, grid_y = np.meshgrid(np.arange(w4, dtype=np.float32), np.arange(h4, dtype=np.float32))
        cand_4x = cv2.remap(
            ai_gray_4x,
            grid_x + flow_x_4x,
            grid_y + flow_y_4x,
            cv2.INTER_CUBIC,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=255,
        )
        c_ai_dist, _, c_sym, _, _ = _alignment_scores(cand_4x, native_ink_1x, orig_fg_1x, ink_thresh)
        if c_sym <= cur_sym + 0.02 and c_ai_dist <= cur_ai_dist + 0.05:
            ai_gray_4x = cand_4x
            cur_ai_dist = c_ai_dist
            flow_used = True

    # Stage 3: Binarize inside piece alpha guard and bake SDF
    orig_alpha_4x = cv2.resize(orig_bgra[:, :, 3], (w4, h4), interpolation=cv2.INTER_LINEAR)
    alpha_guard_4x = cv2.dilate((orig_alpha_4x > 40).astype(np.uint8), np.ones((3, 3), dtype=np.uint8), iterations=1) > 0
    ink_4x = (ai_gray_4x < ink_thresh) & alpha_guard_4x

    sdf_bgra = _encode_sdf_from_ink_4x(ink_4x, ow * sdf_scale, oh * sdf_scale)
    aligned_ink_1x = cv2.resize(ink_4x.astype(np.uint8) * 255, (ow, oh), interpolation=cv2.INTER_AREA) >= 96

    fg_cnt = max(1, int(orig_fg_1x.sum()))
    ink_pct = float((aligned_ink_1x & orig_fg_1x).sum() * 100.0 / fg_cnt)
    mean_dist_after, _, _, native_cov_2px, ai_near_native_2px = _alignment_scores(
        ai_gray_4x, native_ink_1x, orig_fg_1x, ink_thresh
    )

    if ink_pct > 32.0 or ink_pct < 1.5:
        verdict = "FAIL (SOLID_FILL)" if ink_pct > 32.0 else "FAIL (EMPTY_INK)"
    elif native_cov_2px < 72.0:
        verdict = "FAIL (MISSING_LINES)"
    elif ink_pct > 25.0 or mean_dist_after > 1.6 or native_cov_2px < 82.0:
        verdict = "WARN"
    else:
        verdict = "PASS"

    return {
        "sdf_bgra": sdf_bgra,
        "ink_4x": ink_4x,
        "native_ink_1x": native_ink_1x,
        "aligned_ink_1x": aligned_ink_1x,
        "metrics": {
            "ink_pct": round(ink_pct, 2),
            "mean_dist_before_px": round(mean_dist_before, 3),
            "mean_dist_after_px": round(mean_dist_after, 3),
            "native_cov_2px": round(native_cov_2px, 1),
            "ai_near_native_2px": round(ai_near_native_2px, 1),
            "ecc_used": ecc_used,
            "flow_used": flow_used,
            "verdict": verdict,
        },
    }


def _render_audit_row(orig_bgra: np.ndarray, res: dict, label: str) -> np.ndarray:
    """Build 5-column visual audit row [Albedo | Native Ink | New Ink SDF | Albedo+Cyan | Diff]."""
    row_h = 340
    oh, ow = orig_bgra.shape[:2]
    tw = max(72, int(round(ow * (row_h / max(oh, 1)))))

    orig_a = orig_bgra[:, :, 3:4].astype(np.float32) / 255.0
    orig_vis = np.clip(orig_bgra[:, :, :3].astype(np.float32) * orig_a + 36.0 * (1.0 - orig_a), 0, 255).astype(np.uint8)

    nat_1x: np.ndarray = res["native_ink_1x"]
    sdf_bgra: np.ndarray = res["sdf_bgra"]
    sh, sw = sdf_bgra.shape[:2]
    alpha_sdf = cv2.resize(orig_bgra[:, :, 3], (sw, sh), interpolation=cv2.INTER_LINEAR) > 15
    sdf_px = (sdf_bgra[:, :, 0].astype(np.float32) / 255.0 - 0.5) * (2.0 * INK_SDF_RANGE_PX)
    ink_w_sdf = np.clip(1.0 - (sdf_px + 0.25) / 0.85, 0.0, 1.0) * alpha_sdf.astype(np.float32)

    col_nat = np.where(nat_1x[:, :, None], 18, 255).astype(np.uint8)
    col_nat = np.repeat(col_nat, 3, axis=2)

    gray_new = np.clip(np.round((1.0 - ink_w_sdf) * 255.0), 0, 255).astype(np.uint8)
    col_new = np.stack([gray_new, gray_new, gray_new], axis=2)

    # Column 4: Albedo + Cyan New Ink (at 2x/sdf resolution for crisp inspection)
    orig_vis_hi = cv2.resize(orig_vis, (sw, sh), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    cyan = np.array([255.0, 245.0, 20.0], dtype=np.float32)
    col_overlay = np.clip(
        orig_vis_hi * (1.0 - ink_w_sdf[:, :, None] * 0.9) + cyan * (ink_w_sdf[:, :, None] * 0.9), 0, 255
    ).astype(np.uint8)

    # Column 5: Diff vs Native (Green = match <= 1.5px, Blue = new AI stroke, Red = uncovered native)
    ai_1x: np.ndarray = res["aligned_ink_1x"]
    dist_to_nat = cv2.distanceTransform((~nat_1x).astype(np.uint8), cv2.DIST_L2, 5)
    dist_to_ai = cv2.distanceTransform((~ai_1x).astype(np.uint8), cv2.DIST_L2, 5)
    col_diff = np.full((oh, ow, 3), 245, dtype=np.uint8)
    matched = ai_1x & (dist_to_nat <= 1.5)
    ai_only = ai_1x & (dist_to_nat > 1.5)
    nat_only = nat_1x & (dist_to_ai > 1.5)
    col_diff[nat_only] = (40, 40, 235)   # BGR Red = native missed
    col_diff[ai_only] = (235, 110, 20)   # BGR Blue = extra/new AI line
    col_diff[matched] = (40, 195, 40)    # BGR Green = matched

    cols = [
        cv2.resize(orig_vis, (tw, row_h), interpolation=cv2.INTER_AREA),
        cv2.resize(col_nat, (tw, row_h), interpolation=cv2.INTER_AREA),
        cv2.resize(col_new, (tw, row_h), interpolation=cv2.INTER_AREA),
        cv2.resize(col_overlay, (tw, row_h), interpolation=cv2.INTER_AREA),
        cv2.resize(col_diff, (tw, row_h), interpolation=cv2.INTER_AREA),
    ]
    strip = np.hstack(cols)

    m = res["metrics"]
    banner = np.full((34, strip.shape[1], 3), (28, 32, 42), dtype=np.uint8)
    v_col = (80, 230, 110) if m["verdict"] == "PASS" else ((60, 200, 255) if m["verdict"] == "WARN" else (80, 80, 255))
    info = (
        f"{label}  |  {m['verdict']}  |  ink={m['ink_pct']:.1f}%  "
        f"dist={m['mean_dist_before_px']:.2f}->{m['mean_dist_after_px']:.2f}px  "
        f"natCov={m['native_cov_2px']:.1f}%  aiNear={m['ai_near_native_2px']:.1f}%  "
        f"ECC={int(m['ecc_used'])} Flow={int(m['flow_used'])}"
    )
    cv2.putText(banner, info, (12, 23), cv2.FONT_HERSHEY_SIMPLEX, 0.56, v_col, 1, cv2.LINE_AA)
    return np.vstack([banner, strip])


def _write_audit_sheet(rows: list[np.ndarray], audit_path: Path, title: str) -> None:
    max_w = max(r.shape[1] for r in rows)
    total_w = max_w + 8
    header = np.full((38, total_w, 3), (18, 22, 30), dtype=np.uint8)
    cv2.putText(
        header,
        f"{title}   |   Cols: [1] Albedo   [2] Native Ink   [3] New Ink SDF   [4] Albedo+Cyan   [5] Diff (G=Match B=New R=Miss)",
        (14, 25),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.58,
        (230, 236, 245),
        1,
        cv2.LINE_AA,
    )
    padded = [header] + [
        cv2.copyMakeBorder(r, 4, 4, 4, max_w - r.shape[1] + 4, cv2.BORDER_CONSTANT, value=(22, 24, 30))
        for r in rows
    ]
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(audit_path), np.vstack(padded))
    print(f"[AUDIT] Guardado: {audit_path}")


def _dest_ink_path(assets_dir: Path, slot: dict, mirrored: bool = False) -> Path:
    if slot["kind"] == "head":
        return assets_dir / "heads" / f"{slot['head_key']}_ink_sdf.png"
    view = MIRROR_VIEW_MAP[slot["view"]] if mirrored else slot["view"]
    part = MIRROR_PART_SWAP[slot["part"]] if mirrored else slot["part"]
    return assets_dir / view / "parts_5" / f"{part}_ink_sdf.png"


def _sync_head_side_from_aligned_r(
    assets_dir: Path,
    aligned_r_ink_4x: np.ndarray,
    head_side_r_orig: np.ndarray,
    sdf_scale: int,
) -> Path | None:
    """Sync heads/head_side_ink_sdf.png matching head_side.png (384x280) with lower neck from native ink."""
    heads_dir = assets_dir / "heads"
    side_p = heads_dir / "head_side.png"
    if not side_p.exists():
        return None
    side_orig = cv2.imread(str(side_p), cv2.IMREAD_UNCHANGED)
    if side_orig is None:
        return None

    sh, sw = side_orig.shape[:2]
    rh, rw = head_side_r_orig.shape[:2]
    canvas_4x = np.zeros((sh * 4, sw * 4), dtype=bool)

    native_side_2x = _extract_native_ink_2x(side_orig)
    native_side_4x = cv2.resize(native_side_2x.astype(np.uint8) * 255, (sw * 4, sh * 4), interpolation=cv2.INTER_NEAREST) > 128

    copy_h4 = min(sh * 4, rh * 4)
    copy_w4 = min(sw * 4, rw * 4)
    r_alpha_4x = cv2.resize(head_side_r_orig[:, :, 3], (rw * 4, rh * 4), interpolation=cv2.INTER_LINEAR)
    r_valid_4x = r_alpha_4x[:copy_h4, :copy_w4] > 40

    canvas_4x[:, :] = native_side_4x
    canvas_4x[:copy_h4, :copy_w4] = np.where(
        r_valid_4x,
        aligned_r_ink_4x[:copy_h4, :copy_w4],
        native_side_4x[:copy_h4, :copy_w4],
    )
    sdf_side = _encode_sdf_from_ink_4x(canvas_4x, sw * sdf_scale, sh * sdf_scale)
    dst = heads_dir / "head_side_ink_sdf.png"
    cv2.imwrite(str(dst), sdf_side)
    return dst


def _write_empty_pauldron_sdfs(assets_dir: Path, sdf_scale: int) -> list[Path]:
    written: list[Path] = []
    for view, part in (("e", "pauldron_l"), ("w", "pauldron_r")):
        src_p = assets_dir / view / "parts_5" / f"{part}.png"
        if not src_p.exists():
            continue
        im = cv2.imread(str(src_p), cv2.IMREAD_UNCHANGED)
        if im is None:
            continue
        oh, ow = im.shape[:2]
        white_sdf = np.full((oh * sdf_scale, ow * sdf_scale, 4), 255, dtype=np.uint8)
        dst = assets_dir / view / "parts_5" / f"{part}_ink_sdf.png"
        cv2.imwrite(str(dst), white_sdf)
        written.append(dst)
    return written


def _process_sheet(
    sheet_name: str,
    apply_live: bool,
    assets_dir: Path,
    work_root: Path,
    input_override: str | None,
    no_upscayl: bool,
    sdf_scale: int,
    max_flow: float,
    ink_thresh: int,
    audit_name: str | None,
) -> int:
    manifest_path = work_root / "ink_hq_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"Missing manifest: {manifest_path}. Run --action export first.")
    manifest: dict[str, dict] = json.loads(manifest_path.read_text(encoding="utf-8"))
    if sheet_name not in manifest:
        raise KeyError(f"Unknown sheet '{sheet_name}'. Valid sheets: {', '.join(manifest.keys())}")

    s_meta = manifest[sheet_name]
    ai_bgr = _resolve_ai_sheet(work_root, sheet_name, input_override, no_upscayl)
    ai_h, ai_w = ai_bgr.shape[:2]
    man_w, man_h = int(s_meta["size"][0]), int(s_meta["size"][1])
    sx_ratio = ai_w / float(man_w)
    sy_ratio = ai_h / float(man_h)

    audit_rows: list[np.ndarray] = []
    written_paths: list[Path] = []
    has_fail = False

    print(f"\n=== {sheet_name} ({'APPLY' if apply_live else 'TEST'}) ===")
    for slot in s_meta["slots"]:
        orig_path = Path(slot["source_rel"])
        orig_bgra = cv2.imread(str(orig_path), cv2.IMREAD_UNCHANGED)
        if orig_bgra is None:
            raise FileNotFoundError(f"Missing source piece: {orig_path}")

        sx, sy, sw, sh = [int(v) for v in slot["slot_rect"]]
        cx0 = max(0, int(round(sx * sx_ratio)))
        cy0 = max(0, int(round(sy * sy_ratio)))
        cx1 = min(ai_w, int(round((sx + sw) * sx_ratio)))
        cy1 = min(ai_h, int(round((sy + sh) * sy_ratio)))
        slot_bgr = ai_bgr[cy0:cy1, cx0:cx1]

        res = _align_and_bake_piece(slot_bgr, orig_bgra, ink_thresh, max_flow, sdf_scale)
        m = res["metrics"]
        if str(m["verdict"]).startswith("FAIL"):
            has_fail = True
        print(
            f"  [{m['verdict']}] {slot['label']:18s} | ink={m['ink_pct']:5.1f}% "
            f"| dist={m['mean_dist_before_px']:.2f}->{m['mean_dist_after_px']:.2f}px "
            f"| natCov={m['native_cov_2px']:5.1f}% | aiNear={m['ai_near_native_2px']:5.1f}% "
            f"| ECC={m['ecc_used']} Flow={m['flow_used']}"
        )
        audit_rows.append(_render_audit_row(orig_bgra, res, slot["label"]))

        if apply_live:
            dst = _dest_ink_path(assets_dir, slot, mirrored=False)
            cv2.imwrite(str(dst), res["sdf_bgra"])
            written_paths.append(dst)

            if slot["kind"] == "head" and slot["head_key"] == "head_side_r":
                side_dst = _sync_head_side_from_aligned_r(assets_dir, res["ink_4x"], orig_bgra, sdf_scale)
                if side_dst is not None:
                    written_paths.append(side_dst)

            if slot["kind"] == "body" and slot["view"] in MIRROR_VIEW_MAP:
                mir_view = MIRROR_VIEW_MAP[slot["view"]]
                mir_part = MIRROR_PART_SWAP[slot["part"]]
                mir_orig_path = assets_dir / mir_view / "parts_5" / f"{mir_part}.png"
                if mir_orig_path.exists():
                    mir_orig_bgra = cv2.imread(str(mir_orig_path), cv2.IMREAD_UNCHANGED)
                    if mir_orig_bgra is not None:
                        mir_slot_bgr = cv2.flip(slot_bgr, 1)
                        mir_res = _align_and_bake_piece(mir_slot_bgr, mir_orig_bgra, ink_thresh, max_flow, sdf_scale)
                        mir_dst = _dest_ink_path(assets_dir, slot, mirrored=True)
                        cv2.imwrite(str(mir_dst), mir_res["sdf_bgra"])
                        written_paths.append(mir_dst)
                        mm = mir_res["metrics"]
                        print(
                            f"    -> mirror {mir_view.upper()} {mir_part:11s} [{mm['verdict']}] "
                            f"dist={mm['mean_dist_after_px']:.2f}px natCov={mm['native_cov_2px']:5.1f}%"
                        )

    if apply_live and sheet_name == "13_pauldrons_3x3":
        written_paths.extend(_write_empty_pauldron_sdfs(assets_dir, sdf_scale))

    audit_stem = audit_name if audit_name else f"{sheet_name}_audit"
    _write_audit_sheet(audit_rows, work_root / "audits" / f"{audit_stem}.png", sheet_name)
    if apply_live:
        print(f"[APPLY] Escritas {len(written_paths)} texturas *_ink_sdf.png ({sdf_scale}x).")
    return 1 if has_fail else 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Iterative 1:1 HQ Ink pipeline for Valentina v2.")
    parser.add_argument("--action", required=True, choices=["export", "test", "apply"])
    parser.add_argument("--sheet", default="", help="Sheet stem name (required for test/apply).")
    parser.add_argument("--input", default=None, help="Optional direct image path overriding outputs_raw/<sheet>.*")
    parser.add_argument("--no-upscayl", action="store_true", help="Skip Upscayl 4x step.")
    parser.add_argument("--sdf-scale", type=int, default=2, choices=[1, 2], help="Output SDF resolution scale (default 2).")
    parser.add_argument("--max-flow", type=float, default=4.5, help="Max Farneback optical flow in native px (default 4.5).")
    parser.add_argument("--ink-thresh", type=int, default=175, help="Grayscale ink threshold <255 (default 175).")
    parser.add_argument("--audit-name", default=None, help="Optional audit image stem override.")
    args = parser.parse_args()

    assets_dir = DEFAULT_OUT_DIR
    work_root = DEFAULT_SOURCE_DIR / WORK_SUBDIR

    if args.action == "export":
        _export_all_sheets(assets_dir, work_root)
        return

    if not args.sheet:
        parser.error("--sheet is required for --action test/apply")

    rc = _process_sheet(
        sheet_name=args.sheet,
        apply_live=(args.action == "apply"),
        assets_dir=assets_dir,
        work_root=work_root,
        input_override=args.input,
        no_upscayl=args.no_upscayl,
        sdf_scale=args.sdf_scale,
        max_flow=args.max_flow,
        ink_thresh=args.ink_thresh,
        audit_name=args.audit_name,
    )
    sys.exit(rc)


if __name__ == "__main__":
    main()
