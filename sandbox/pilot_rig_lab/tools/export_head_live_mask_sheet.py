#!/usr/bin/env python3
"""Export a unified 16:9 (2560x1440) 2x4 head-mask authoring sheet for Valentina v2.

Generates clean inputs, an automated pixel-accurate pre-mask, an ink-overlaid
manual painting base, a palette reference guide, JSON slot manifest, and
authoring/AI prompt instructions under:
  sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/08_head_live_rig/
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

WORK_SUBDIR = "08_head_live_rig"
SHEET_W = 2560
SHEET_H = 1440
ROWS = 2
COLS = 4
LEFT_PAD = 48
RIGHT_PAD = 48
TOP_PAD = 28
BOTTOM_PAD = 108
UNIFORM_SCALE = 1.70

HEAD_ORDER: tuple[str, ...] = (
    "head_front",
    "head_front_r",
    "head_front_l",
    "head_side_r",
    "head_side_l",
    "head_back_r",
    "head_back_l",
    "head_back",
)

FACE_VISIBLE_HEADS: frozenset[str] = frozenset({
    "head_front",
    "head_front_r",
    "head_front_l",
    "head_side_r",
    "head_side_l",
})

# Palette entries: (key, hex, rgb, short_label, role_summary)
PALETTE_SPEC: tuple[tuple[str, str, tuple[int, int, int], str, str], ...] = (
    ("background", "#000000", (0, 0, 0), "Fondo", "Exterior vacio (alpha 0)"),
    ("face_skin", "#FFD000", (255, 208, 0), "Piel Rostro", "Cara y orejas rigidas"),
    ("neck", "#0055FF", (0, 85, 255), "Cuello", "Soldadura cervical Pass 1"),
    ("iris_pupil", "#00FFFF", (0, 255, 255), "Iris/Pupila", "face_anim.g (mirada/sacadas)"),
    ("eyelid", "#FFFFFF", (255, 255, 255), "Parpado", "face_anim.r (parpadeo/squint)"),
    ("eyebrow", "#FF6600", (255, 102, 0), "Cejas", "face_anim.b (expresion)"),
    ("mouth", "#FF0055", (255, 0, 85), "Boca/Labios", "face_anim.a (respiracion/gesto)"),
    ("monocle", "#AA00FF", (170, 0, 255), "Monoculo", "Parallax frontal + HUD vivo"),
    ("hair_crown", "#606878", (96, 104, 120), "Pelo Rigido", "Coronilla anclada al craneo"),
    ("hair_bangs", "#00FF66", (0, 255, 102), "Flequillo", "hair_jiggle.r (frontal)"),
    ("hair_sides", "#FF00FF", (255, 0, 255), "Mechones Lat", "hair_jiggle.g (mejillas/sienes)"),
    ("hair_back", "#80FF00", (128, 255, 0), "Puntas/Nuca", "hair_jiggle.b (estela trasera)"),
)

PALETTE_BGR: dict[str, tuple[int, int, int]] = {
    key: (rgb[2], rgb[1], rgb[0]) for key, _, rgb, _, _ in PALETTE_SPEC
}


def _load_head_inputs(heads_dir: Path, head_key: str) -> dict[str, np.ndarray]:
    """Load required calibrated RGBA texture and companion masks for one head."""
    col_path = heads_dir / f"{head_key}.png"
    id_path = heads_dir / f"{head_key}_id_mask.png"
    ink_path = heads_dir / f"{head_key}_ink_sdf.png"
    jig_path = heads_dir / f"{head_key}_hair_jiggle_mask.png"

    for p in (col_path, id_path, ink_path, jig_path):
        if not p.exists():
            raise FileNotFoundError(f"Missing required head asset: {p}")

    col = cv2.imread(str(col_path), cv2.IMREAD_UNCHANGED)
    idm = cv2.imread(str(id_path), cv2.IMREAD_UNCHANGED)
    ink = cv2.imread(str(ink_path), cv2.IMREAD_UNCHANGED)
    jig = cv2.imread(str(jig_path), cv2.IMREAD_UNCHANGED)
    if col is None or idm is None or ink is None or jig is None:
        raise RuntimeError(f"Failed to decode one or more textures for {head_key}")
    if col.shape[:2] != idm.shape[:2] or col.shape[:2] != ink.shape[:2] or col.shape[:2] != jig.shape[:2]:
        raise ValueError(f"Mismatched mask dimensions for {head_key}: col={col.shape}")
    return {"col": col, "id": idm, "ink": ink, "jig": jig}


def _build_native_premask(head_key: str, data: dict[str, np.ndarray]) -> np.ndarray:
    """Synthesize flat semantic pre-mask at native resolution (BGR uint8)."""
    col = data["col"]
    idm = data["id"]
    h, w = col.shape[:2]

    fg = col[:, :, 3] >= 24
    is_neck = (idm[:, :, 0] > 128) & (idm[:, :, 2] < 100) & fg
    is_monocle = (idm[:, :, 2] > 128) & (idm[:, :, 0] < 100) & fg
    is_hair = (idm[:, :, 3] > 128) & fg & (~is_neck) & (~is_monocle)
    is_skin = fg & (~is_hair) & (~is_neck) & (~is_monocle)

    out = np.zeros((h, w, 3), dtype=np.uint8)
    out[is_skin] = PALETTE_BGR["face_skin"]
    out[is_neck] = PALETTE_BGR["neck"]
    out[is_monocle] = PALETTE_BGR["monocle"]

    if not np.any(is_hair):
        return out

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    hy, hx = np.where(is_hair)
    hy0, hy1 = float(hy.min()), float(hy.max())
    hx0, hx1 = float(hx.min()), float(hx.max())
    hx_mid = 0.5 * (hx0 + hx1)
    y_hair_norm = (yy - hy0) / max(hy1 - hy0, 1.0)

    # Smooth curved scalp/crown cap anchored to the upper skull.
    r_crown_x = (xx - hx_mid) / max(0.50 * (hx1 - hx0), 1.0)
    r_crown_y = (yy - hy0) / max(0.36 * (hy1 - hy0), 1.0)
    is_crown = is_hair & ((0.42 * r_crown_x * r_crown_x + r_crown_y * r_crown_y) <= 1.0)
    dyn_hair = is_hair & (~is_crown)

    out[is_crown] = PALETTE_BGR["hair_crown"]

    if head_key in FACE_VISIBLE_HEADS and np.any(is_skin):
        sy, sx = np.where(is_skin)
        sy0, sy1 = float(sy.min()), float(sy.max())
        sx0, sx1 = float(sx.min()), float(sx.max())
        sw = max(sx1 - sx0, 1.0)
        sh = max(sy1 - sy0, 1.0)

        if head_key == "head_side_r":
            is_bangs = dyn_hair & (xx >= (sx0 + 0.52 * sw)) & (yy <= (sy0 + 0.72 * sh))
            is_nape = dyn_hair & (~is_bangs) & (
                ((xx < (sx0 + 0.20 * sw)) & (y_hair_norm >= 0.36)) | (y_hair_norm >= 0.78)
            )
        elif head_key == "head_side_l":
            is_bangs = dyn_hair & (xx <= (sx1 - 0.52 * sw)) & (yy <= (sy0 + 0.72 * sh))
            is_nape = dyn_hair & (~is_bangs) & (
                ((xx > (sx1 - 0.20 * sw)) & (y_hair_norm >= 0.36)) | (y_hair_norm >= 0.78)
            )
        else:
            face_cx = float(np.median(sx))
            bang_t = np.clip((yy - hy0) / max(sy0 + 0.62 * sh - hy0, 1.0), 0.0, 1.5)
            bang_half_w = (0.56 - 0.14 * np.clip(bang_t, 0.0, 1.0)) * sw
            is_bangs = dyn_hair & (np.abs(xx - face_cx) <= bang_half_w) & (yy <= (sy0 + 0.62 * sh))
            nape_curve_y = 0.76 - 0.14 * np.exp(-(((xx - face_cx) / max(0.55 * sw, 1.0)) ** 2))
            is_nape = dyn_hair & (~is_bangs) & (y_hair_norm >= nape_curve_y)

        is_sides = dyn_hair & (~is_bangs) & (~is_nape)

        out[is_bangs] = PALETTE_BGR["hair_bangs"]
        out[is_nape] = PALETTE_BGR["hair_back"]
        out[is_sides] = PALETTE_BGR["hair_sides"]
    else:
        x_hair_norm = np.abs(xx - hx_mid) / max(0.5 * (hx1 - hx0), 1.0)
        is_sides = dyn_hair & (x_hair_norm >= (0.44 + 0.16 * y_hair_norm)) & (y_hair_norm < 0.80)
        is_nape = dyn_hair & (~is_sides)

        out[is_sides] = PALETTE_BGR["hair_sides"]
        out[is_nape] = PALETTE_BGR["hair_back"]

    return out


def _blend_rgba_onto(canvas: np.ndarray, rgba: np.ndarray, dx: int, dy: int) -> None:
    """Alpha-composite BGRA image onto BGR canvas in-place."""
    nh, nw = rgba.shape[:2]
    alpha = np.clip(rgba[:, :, 3:4].astype(np.float32) / 255.0, 0.0, 1.0)
    fg = rgba[:, :, :3].astype(np.float32)
    roi = canvas[dy : dy + nh, dx : dx + nw].astype(np.float32)
    canvas[dy : dy + nh, dx : dx + nw] = np.clip(np.round(fg * alpha + roi * (1.0 - alpha)), 0, 255).astype(np.uint8)


def _draw_palette_bar(canvas: np.ndarray) -> None:
    """Render the 12-swatch semantic color legend inside y in [1336, 1440]."""
    bar_y0 = TOP_PAD + ROWS * ((SHEET_H - TOP_PAD - BOTTOM_PAD) // ROWS) + 8
    cv2.rectangle(canvas, (0, bar_y0 - 4), (SHEET_W, SHEET_H), (22, 24, 30), -1)
    cv2.line(canvas, (0, bar_y0 - 4), (SHEET_W, bar_y0 - 4), (72, 78, 96), 2)

    usable_w = SHEET_W - LEFT_PAD - RIGHT_PAD
    count = len(PALETTE_SPEC)
    cell_w = usable_w / float(count)

    for i, (key, hex_code, _, label, _) in enumerate(PALETTE_SPEC):
        x0 = int(round(LEFT_PAD + i * cell_w))
        x1 = int(round(LEFT_PAD + (i + 1) * cell_w)) - 8
        sw_y0 = bar_y0 + 10
        sw_y1 = SHEET_H - 12

        # Solid pure-color swatch block on the left half for clean eyedropper picking
        box_w = min(56, max(38, (x1 - x0) // 3))
        bgr = PALETTE_BGR[key]
        cv2.rectangle(canvas, (x0, sw_y0), (x0 + box_w, sw_y1), bgr, -1)
        cv2.rectangle(canvas, (x0, sw_y0), (x0 + box_w, sw_y1), (185, 190, 205), 1)

        tx = x0 + box_w + 8
        cv2.putText(canvas, hex_code, (tx, sw_y0 + 26), cv2.FONT_HERSHEY_SIMPLEX, 0.56, (240, 244, 252), 1, cv2.LINE_AA)
        cv2.putText(canvas, label, (tx, sw_y0 + 52), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (185, 196, 220), 1, cv2.LINE_AA)


def _build_prompt_markdown(out_dir: Path) -> str:
    """Build bilingual/Spanish workflow & AI prompt documentation for 08_head_live_rig."""
    rows = "\n".join(
        f"| `{hex_code}` | `RGB{rgb}` | **{label}** | {role} |"
        for _, hex_code, rgb, label, role in PALETTE_SPEC
    )
    return f"""# Fase 1 — Lámina 16:9 (`2560×1440`) para Máscara Facial Viva y Cabello Multicapa (Valentina v2)

## Carpeta de Trabajo
- **Raíz:** `{out_dir.as_posix()}`
- **Inputs limpios:**
  - `inputs/heads_8dir_clean_white_16x9.png` — 8 cabezas a escala uniforme `{UNIFORM_SCALE:.2f}x` sobre `#FFFFFF` puro (ideal para IA o referencia superior).
  - `inputs/heads_8dir_clean_black_16x9.png` — 8 cabezas a escala uniforme `{UNIFORM_SCALE:.2f}x` sobre `#000000` puro.
  - `inputs/heads_8dir_premask_16x9.png` — Pre-máscara plana autogenerada (piel, cuello, monóculo, coronilla rígida y partición inicial de cabello).
- **Guías de pintado y referencia:**
  - `guides/heads_8dir_manual_paint_base_16x9.png` — Pre-máscara + trazos de tinta (`*_ink_sdf.png`) al `38%` + barra inferior de swatches exactos.
  - `guides/heads_8dir_palette_guide_16x9.png` — Referencia visual con grilla, nombres de vista y barra inferior de paleta.
- **Dónde guardar tu máscara terminada:**
  - `outputs/heads_8dir_live_mask_16x9.png` *(mismas dimensiones `2560×1440`)*

---

## Paleta Semántica Estricta (11 Zonas + Fondo `#000000`)

| Hex | RGB | Zona | Uso Runtime |
| :--- | :--- | :--- | :--- |
{rows}

---

## Opción 1 (Recomendada): Edición Manual Rápida sobre la Pre-Máscara
1. **Con capas limpias (ideal):** Abre `inputs/heads_8dir_premask_16x9.png` como capa base plana y coloca encima `guides/heads_8dir_manual_paint_base_16x9.png` (o `inputs/heads_8dir_clean_white_16x9.png` en modo *Multiply* al 35–50%) como guía visual temporal; desactiva la capa guía antes de exportar. *(También puedes pintar directo sobre `guides/heads_8dir_manual_paint_base_16x9.png`: usa la barra inferior de swatches con el cuentagotas y el ingestor cuantizará los trazos guía al color más cercano).*
2. Usa un **pincel duro sin antialiasing** (`100%` opacidad, herramienta Lápiz / Binary Pen) tomando los colores exactos desde la barra inferior de swatches (`y >= 1336` en las guías) o los códigos Hex de la tabla.
3. En las **5 cabezas con rostro** (`head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side_l`), pinta sobre `#FFD000`:
   - `#00FFFF`: Iris / Pupila (solo el disco del ojo descubierto).
   - `#FFFFFF`: Párpado superior / línea de pestañas superiores (cubre el arco superior del ojo para el parpadeo y *squint*).
   - `#FF6600`: Cejas completas.
   - `#FF0055`: Boca / Labios.
   - Refina si lo deseas la frontera entre `#606878` (Coronilla rígida), `#00FF66` (Flequillo frontal), `#FF00FF` (Mechones laterales) y `#80FF00` (Puntas traseras / nuca).
4. Exporta el lienzo completo `2560×1440` sin opacidades parciales (puedes dejar o quitar la barra inferior, el ingestor recorta solo las `piece_rect` de `head_live_sheet_manifest.json`) en:
   `outputs/heads_8dir_live_mask_16x9.png`

---

## Opción 2: Prompt para IA Generativa (16:9 sobre `inputs/heads_8dir_clean_white_16x9.png`)
```text
Convert this exact 2x4 8-head anime character turnaround sheet into a flat, razor-sharp semantic rig mask on a pure #000000 solid black background. Preserve the exact 2560x1440 16:9 canvas dimensions, 2x4 grid positions, scale, and outer silhouettes of all 8 heads without shifting, cropping, or adding text.

CRITICAL ANTI-OUTLINE & FLATNESS RULES:
- DELETE 100% of black ink outlines, interior lineart, shading, gradients, specular highlights, and anti-aliasing.
- Paint ONLY solid unshaded pure hex blocks with hard 1-pixel binary boundaries (zero soft blending between colors).
- Empty exterior background MUST be pure #000000 black.

STRICT HEX COLOR MAP:
- #000000 Pure Black: empty exterior background.
- #FFD000 Vivid Gold-Yellow: exposed face skin and ears (excluding eyes, eyebrows, mouth, neck, and monocle).
- #0055FF Vivid Cobalt Blue: lower bare neck cylinder below the jawline/chin.
- #00FFFF Pure Cyan: iris and pupil inside each visible eye.
- #FFFFFF Pure White: upper eyelid and upper eyelash arch above each eye.
- #FF6600 Vivid Orange: eyebrows.
- #FF0055 Vivid Magenta-Red: mouth and lips.
- #AA00FF Vivid Purple: crimson monocle lens, rim, and monocle strap.
- #606878 Slate Gray: rigid upper scalp/crown hair anchored tightly to the skull.
- #00FF66 Neon Mint Green: dynamic front bangs / fringe hanging over the forehead and upper face.
- #FF00FF Pure Magenta: dynamic side hair locks framing cheeks and temples.
- #80FF00 Chartreuse Lime: dynamic lower rear hair tips and nape strands.
```
"""


def export_head_live_mask_sheet(assets_dir: Path, source_dir: Path) -> Path:
    """Generate all 16:9 sheets, manifest, and prompt guide for 08_head_live_rig."""
    heads_dir = assets_dir / "heads"
    out_root = source_dir / WORK_SUBDIR
    inputs_dir = out_root / "inputs"
    guides_dir = out_root / "guides"
    outputs_dir = out_root / "outputs"
    for folder in (inputs_dir, guides_dir, outputs_dir):
        folder.mkdir(parents=True, exist_ok=True)

    usable_w = SHEET_W - LEFT_PAD - RIGHT_PAD
    usable_h = SHEET_H - TOP_PAD - BOTTOM_PAD
    slot_w = usable_w // COLS
    slot_h = usable_h // ROWS

    canvas_white = np.full((SHEET_H, SHEET_W, 3), (255, 255, 255), dtype=np.uint8)
    canvas_black = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)
    canvas_premask = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)
    canvas_manual = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)
    canvas_palette = np.full((SHEET_H, SHEET_W, 3), (34, 37, 46), dtype=np.uint8)

    slots_meta: list[dict] = []

    for idx, head_key in enumerate(HEAD_ORDER):
        r = idx // COLS
        c = idx % COLS
        data = _load_head_inputs(heads_dir, head_key)
        col = data["col"]
        ink = data["ink"]
        ih, iw = col.shape[:2]

        nw = max(1, int(round(iw * UNIFORM_SCALE)))
        nh = max(1, int(round(ih * UNIFORM_SCALE)))
        if nw > slot_w or nh > slot_h:
            raise ValueError(f"Scaled head {head_key} ({nw}x{nh}) exceeds slot ({slot_w}x{slot_h})")

        sx0 = LEFT_PAD + c * slot_w
        sy0 = TOP_PAD + r * slot_h
        dx = sx0 + (slot_w - nw) // 2
        dy = sy0 + (slot_h - nh) // 2

        col_rs = cv2.resize(col, (nw, nh), interpolation=cv2.INTER_CUBIC)
        _blend_rgba_onto(canvas_white, col_rs, dx, dy)
        _blend_rgba_onto(canvas_black, col_rs, dx, dy)
        _blend_rgba_onto(canvas_palette, col_rs, dx, dy)

        premask_native = _build_native_premask(head_key, data)
        premask_rs = cv2.resize(premask_native, (nw, nh), interpolation=cv2.INTER_NEAREST)
        canvas_premask[dy : dy + nh, dx : dx + nw] = premask_rs

        # Overlay SDF ink strokes softly (~38%) for crisp facial/hair painting guidance
        ink_ch = ink[:, :, 0] if ink.ndim == 3 else ink
        ink_rs = cv2.resize(ink_ch, (nw, nh), interpolation=cv2.INTER_LINEAR).astype(np.float32)
        ink_cov = np.clip((130.0 - ink_rs) / 10.0, 0.0, 1.0) * 0.38
        ink_cov_3 = ink_cov[:, :, None]
        manual_patch = premask_rs.astype(np.float32) * (1.0 - ink_cov_3) + 12.0 * ink_cov_3
        canvas_manual[dy : dy + nh, dx : dx + nw] = np.clip(np.round(manual_patch), 0, 255).astype(np.uint8)

        # Draw slot border & label on reference palette guide only (never on inputs/)
        cv2.rectangle(canvas_palette, (sx0 + 3, sy0 + 3), (sx0 + slot_w - 4, sy0 + slot_h - 4), (92, 102, 128), 2)
        tag = f"{head_key} ({iw}x{ih} -> {nw}x{nh})"
        cv2.putText(canvas_palette, tag, (sx0 + 16, sy0 + 30), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (226, 232, 248), 1, cv2.LINE_AA)

        slots_meta.append({
            "index": idx,
            "row": r,
            "col": c,
            "head_key": head_key,
            "has_visible_face": head_key in FACE_VISIBLE_HEADS,
            "source_rel": f"heads/{head_key}.png",
            "slot_rect": [sx0, sy0, slot_w, slot_h],
            "piece_rect": [dx, dy, nw, nh],
            "orig_size": [iw, ih],
            "scale": UNIFORM_SCALE,
        })

    _draw_palette_bar(canvas_manual)
    _draw_palette_bar(canvas_palette)

    cv2.imwrite(str(inputs_dir / "heads_8dir_clean_white_16x9.png"), canvas_white)
    cv2.imwrite(str(inputs_dir / "heads_8dir_clean_black_16x9.png"), canvas_black)
    cv2.imwrite(str(inputs_dir / "heads_8dir_premask_16x9.png"), canvas_premask)
    cv2.imwrite(str(guides_dir / "heads_8dir_manual_paint_base_16x9.png"), canvas_manual)
    cv2.imwrite(str(guides_dir / "heads_8dir_palette_guide_16x9.png"), canvas_palette)

    manifest = {
        "sheet_name": "heads_8dir_live_mask_16x9",
        "aspect": "16:9",
        "size": [SHEET_W, SHEET_H],
        "rows": ROWS,
        "cols": COLS,
        "padding": {"left": LEFT_PAD, "right": RIGHT_PAD, "top": TOP_PAD, "bottom": BOTTOM_PAD},
        "uniform_scale": UNIFORM_SCALE,
        "swatch_bar_y_start": TOP_PAD + ROWS * slot_h,
        "palette": {
            key: {"hex": hex_code, "rgb": list(rgb), "label": label, "role": role}
            for key, hex_code, rgb, label, role in PALETTE_SPEC
        },
        "slots": slots_meta,
    }
    (out_root / "head_live_sheet_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (out_root / "PROMPT_HEAD_LIVE_MASK.md").write_text(_build_prompt_markdown(out_root), encoding="utf-8")

    print(f"[EXPORT] 08_head_live_rig listo en: {out_root}")
    print(f"  - inputs/heads_8dir_clean_white_16x9.png ({SHEET_W}x{SHEET_H})")
    print(f"  - inputs/heads_8dir_clean_black_16x9.png ({SHEET_W}x{SHEET_H})")
    print(f"  - inputs/heads_8dir_premask_16x9.png ({SHEET_W}x{SHEET_H})")
    print(f"  - guides/heads_8dir_manual_paint_base_16x9.png ({SHEET_W}x{SHEET_H})")
    print(f"  - guides/heads_8dir_palette_guide_16x9.png ({SHEET_W}x{SHEET_H})")
    print("  - head_live_sheet_manifest.json + PROMPT_HEAD_LIVE_MASK.md")
    return out_root


def main() -> None:
    parser = argparse.ArgumentParser(description="Export 16:9 2x4 live head-mask sheet for Valentina v2.")
    parser.add_argument("--assets-dir", type=Path, default=REPO_ROOT / DEFAULT_OUT_DIR)
    parser.add_argument("--source-dir", type=Path, default=REPO_ROOT / DEFAULT_SOURCE_DIR)
    args = parser.parse_args()
    export_head_live_mask_sheet(args.assets_dir, args.source_dir)


if __name__ == "__main__":
    main()
