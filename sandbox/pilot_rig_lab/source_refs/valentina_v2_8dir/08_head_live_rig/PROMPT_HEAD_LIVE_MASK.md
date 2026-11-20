# Fase 1 — Lámina 16:9 (`2560×1440`) para Máscara Facial Viva y Cabello Multicapa (Valentina v2)

## Carpeta de Trabajo
- **Raíz:** `C:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/08_head_live_rig`
- **Inputs limpios:**
  - `inputs/heads_8dir_clean_white_16x9.png` — 8 cabezas a escala uniforme `1.70x` sobre `#FFFFFF` puro (ideal para IA o referencia superior).
  - `inputs/heads_8dir_clean_black_16x9.png` — 8 cabezas a escala uniforme `1.70x` sobre `#000000` puro.
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
| `#000000` | `RGB(0, 0, 0)` | **Fondo** | Exterior vacio (alpha 0) |
| `#FFD000` | `RGB(255, 208, 0)` | **Piel Rostro** | Cara y orejas rigidas |
| `#0055FF` | `RGB(0, 85, 255)` | **Cuello** | Soldadura cervical Pass 1 |
| `#00FFFF` | `RGB(0, 255, 255)` | **Iris/Pupila** | face_anim.g (mirada/sacadas) |
| `#FFFFFF` | `RGB(255, 255, 255)` | **Parpado** | face_anim.r (parpadeo/squint) |
| `#FF6600` | `RGB(255, 102, 0)` | **Cejas** | face_anim.b (expresion) |
| `#FF0055` | `RGB(255, 0, 85)` | **Boca/Labios** | face_anim.a (respiracion/gesto) |
| `#AA00FF` | `RGB(170, 0, 255)` | **Monoculo** | Parallax frontal + HUD vivo |
| `#606878` | `RGB(96, 104, 120)` | **Pelo Rigido** | Coronilla anclada al craneo |
| `#00FF66` | `RGB(0, 255, 102)` | **Flequillo** | hair_jiggle.r (frontal) |
| `#FF00FF` | `RGB(255, 0, 255)` | **Mechones Lat** | hair_jiggle.g (mejillas/sienes) |
| `#80FF00` | `RGB(128, 255, 0)` | **Puntas/Nuca** | hair_jiggle.b (estela trasera) |

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
