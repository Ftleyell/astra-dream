"""Compile only the 8 unique/non-mirrorable rig pauldrons into 1 clean 16:9 (2560x1440) sheet on pure white."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from build_valentina_v2_rig_assets import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR

SHEET_W = 2560
SHEET_H = 1440
SIDE_MARGIN_PX = 80
VERT_MARGIN_PX = 80
CELL_PAD_PX = 40

# Only the 8 unique pauldrons (canonical hemisphere S, SE, E, NE, N).
# Each entry: (source_view, source_part, mirror_targets[(target_view, target_part)])
UNIQUE_PAULDRON_SPECS: list[tuple[str, str, list[tuple[str, str]]]] = [
    # Row 0 (front / front-diag / side front)
    ("s", "pauldron_r", [("s", "pauldron_l")]),
    ("se", "pauldron_r", [("sw", "pauldron_l")]),
    ("se", "pauldron_l", [("sw", "pauldron_r")]),
    ("e", "pauldron_r", [("w", "pauldron_l")]),
    # Row 1 (back / back-diag / side rear)
    ("n", "pauldron_r", [("n", "pauldron_l")]),
    ("ne", "pauldron_r", [("nw", "pauldron_l")]),
    ("ne", "pauldron_l", [("nw", "pauldron_r")]),
    ("e", "pauldron_l", [("w", "pauldron_r")]),
]


def _build_unique_sheet(
    sheet_name: str,
    assets_dir: Path,
    inputs_dir: Path,
    guide_dir: Path,
) -> dict:
    canvas = np.full((SHEET_H, SHEET_W, 3), 255, dtype=np.uint8)
    guide = canvas.copy()

    cols = 4
    rows = 2
    usable_w = SHEET_W - 2 * SIDE_MARGIN_PX
    usable_h = SHEET_H - 2 * VERT_MARGIN_PX
    slot_w = usable_w // cols
    slot_h = usable_h // rows
    slots_meta: list[dict] = []

    for idx, (view, part_name, mirror_targets) in enumerate(UNIQUE_PAULDRON_SPECS):
        r_idx, c_idx = divmod(idx, cols)
        p_path = assets_dir / view / "parts_5" / f"{part_name}.png"
        bgra = cv2.imread(str(p_path), cv2.IMREAD_UNCHANGED)
        if bgra is None or bgra.shape[2] != 4:
            raise FileNotFoundError(f"Missing RGBA pauldron: {p_path}")

        ph, pw = bgra.shape[:2]
        max_w = slot_w - 2 * CELL_PAD_PX
        max_h = slot_h - 2 * CELL_PAD_PX
        scale = min(max_w / max(pw, 1), max_h / max(ph, 1), 3.5)
        nw = max(1, int(round(pw * scale)))
        nh = max(1, int(round(ph * scale)))
        interp = cv2.INTER_CUBIC if scale > 1.0 else cv2.INTER_AREA
        resized = cv2.resize(bgra, (nw, nh), interpolation=interp)

        sx0 = SIDE_MARGIN_PX + c_idx * slot_w
        sy0 = VERT_MARGIN_PX + r_idx * slot_h
        dx = sx0 + (slot_w - nw) // 2
        dy = sy0 + (slot_h - nh) // 2

        alpha = resized[:, :, 3:4].astype(np.float32) / 255.0
        roi = canvas[dy : dy + nh, dx : dx + nw].astype(np.float32)
        blended = resized[:, :, :3].astype(np.float32) * alpha + roi * (1.0 - alpha)
        comp = np.clip(np.round(blended), 0, 255).astype(np.uint8)
        canvas[dy : dy + nh, dx : dx + nw] = comp
        guide[dy : dy + nh, dx : dx + nw] = comp

        cv2.rectangle(guide, (sx0, sy0), (sx0 + slot_w - 1, sy0 + slot_h - 1), (200, 200, 200), 2)
        mirror_str = ", ".join(f"{mv.upper()}:{mp[-1].upper()}" for mv, mp in mirror_targets)
        label = f"{view.upper()} - {part_name} (-> {mirror_str})"
        cv2.putText(guide, label, (sx0 + 14, sy0 + 34), cv2.FONT_HERSHEY_SIMPLEX, 0.68, (40, 40, 40), 2)

        slots_meta.append({
            "row": r_idx,
            "col": c_idx,
            "view": view,
            "part": part_name,
            "mirror_targets": [[mv, mp] for mv, mp in mirror_targets],
            "slot_rect": [sx0, sy0, slot_w, slot_h],
            "pauldron_rect": [dx, dy, nw, nh],
            "orig_size": [pw, ph],
            "scale": round(scale, 5),
        })

    out_path = inputs_dir / f"{sheet_name}.png"
    guide_path = guide_dir / f"{sheet_name}_labeled.png"
    cv2.imwrite(str(out_path), canvas)
    cv2.imwrite(str(guide_path), guide)
    print(f"[PAULDRON SHEET] {out_path.name} ({len(slots_meta)} unique pauldrons, {SHEET_W}x{SHEET_H})")
    return {"file": out_path.name, "size": [SHEET_W, SHEET_H], "slots": slots_meta}


def main() -> None:
    ws_dir = DEFAULT_SOURCE_DIR / "05_mask_ai_workspaces"
    base_dir = ws_dir / "manual_fix_overlays" / "07_pauldron_polish_16x9"
    inputs_dir = base_dir / "inputs"
    guide_dir = base_dir / "guide"
    upscayl_dir = base_dir / "upscayl_outputs"
    for d in (inputs_dir, guide_dir, upscayl_dir):
        d.mkdir(parents=True, exist_ok=True)

    # Clean up any previous 2-sheet files so only the 1 unique sheet remains
    for old_dir in (inputs_dir, guide_dir):
        for old_f in old_dir.glob("*.png"):
            old_f.unlink()

    sheet_name = "01_pauldrons_unique_8_16x9"
    manifest = {sheet_name: _build_unique_sheet(sheet_name, DEFAULT_OUT_DIR, inputs_dir, guide_dir)}

    (inputs_dir / "pauldron_polish_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    prompt_md = """# Guía de Pulido IA — 8 Hombreras Únicas (16:9)

Solo se exportan las **8 hombreras únicas** (las 8 restantes se generan automáticamente por espejado horizontal en Python):
- **Fila 1:** `S pauldron_r` (→ `S pauldron_l`), `SE pauldron_r` (→ `SW pauldron_l`), `SE pauldron_l` (→ `SW pauldron_r`), `E pauldron_r` (→ `W pauldron_l`)
- **Fila 2:** `N pauldron_r` (→ `N pauldron_l`), `NE pauldron_r` (→ `NW pauldron_l`), `NE pauldron_l` (→ `NW pauldron_r`), `E pauldron_l` (→ `W pauldron_r`)

## Archivo de entrada (`inputs/`)
- `01_pauldrons_unique_8_16x9.png` (2560x1440, 16:9)
- Referencia con nombres: `guide/01_pauldrons_unique_8_16x9_labeled.png`

## Prompt recomendado para el generador de imagen
> Clean up and complete these 8 isolated sci-fi anime armor shoulder pauldrons on a pure solid white `#FFFFFF` background. Preserve the exact position, size, perspective, silhouette, cel-shaded dark navy/blue/gold/crimson palette, and crisp dark ink outlines of each piece. Fix any cut edges, missing corners, blurry seams, or perspective artifacts so every pauldron looks like a complete, clean, production-ready 2D anime game asset. Do not move, resize, rotate, merge, or add text, labels, shadows, or grid lines.

## Siguiente paso (Upscayl + Python)
1. Pasa el resultado por **Upscayl** (`digital-art-4x`) y guárdalo en `upscayl_outputs/` (por ejemplo `01_pauldrons_unique_8_16x9.png`).
2. Avísame para ejecutar `ingest_pauldron_polish_16x9.py` (recorta, limpia bordes, espeja las 8 simétricas, regenera mapas y reaplica las 16 al rig + `pilot_rig_lab`).
"""
    (base_dir / "PROMPT_GUIDE.md").write_text(prompt_md, encoding="utf-8")


if __name__ == "__main__":
    main()
