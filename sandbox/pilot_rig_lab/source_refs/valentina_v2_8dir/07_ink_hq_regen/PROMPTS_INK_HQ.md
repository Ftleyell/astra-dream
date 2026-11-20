# Prompts HQ para Capa de Tinta (`07_ink_hq_regen/` — 13 Hojas `1:1`)

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
