# Fase D — Prompts para Canal "Solo Tinta" / Clean-Up Lineart (`*_ink_sdf.png`)

## Objetivo técnico (SDF de Tinta Interna)
Estas hojas generan **tinta negra pura (`#000000`) sobre blanco puro (`#FFFFFF`)** sin rellenos ni sombras. Luego Python las alinea a cada pieza y las convierte en un **Unsigned Distance Field (UDF/SDF)** para que el shader dibuje tanto los contornos como las líneas internas de forma **vectorialmente nítida (razor-sharp)** a cualquier zoom y muestre un canal Rayos-X "Solo Tinta" (`debug_view_mode == 3`) 100% limpio.

## Carpetas de trabajo
- **Entradas limpias (subir al generador):** `inputs/` (fondo `#FFFFFF` puro, sin texto)
- **Guías con rótulos (solo lectura humana):** `guides/`
- **Dónde guardar tus resultados:** `outputs_ink/` *(con el **mismo nombre de archivo** que en `inputs/`)*

## Tabla de las 7 hojas estándar
| Archivo | Aspect Ratio IA | Contenido | Prompt a usar |
| :--- | :---: | :--- | :---: |
| `01_body_core_5dir_16x9.png` | **`16:9`** | 5 torsos (`S, SE, E, NE, N`) | **Prompt 1 (Cuerpo/Traje)** |
| `02a_legs_R_5dir_16x9.png` | **`16:9`** | 5 piernas derechas (`S, SE, E, NE, N`) | **Prompt 1 (Cuerpo/Traje)** |
| `02b_legs_L_5dir_16x9.png` | **`16:9`** | 5 piernas izquierdas (`S, SE, E, NE, N`) | **Prompt 1 (Cuerpo/Traje)** |
| `03_arms_10pcs_16x9.png` | **`16:9`** | 10 brazos (`arm_r` fila sup, `arm_l` fila inf) | **Prompt 1 (Cuerpo/Traje)** |
| `04_pauldrons_10pcs_16x9.png` | **`16:9`** | 10 hombreras (`pauldron_r` sup, `pauldron_l` inf) | **Prompt 1 (Cuerpo/Traje)** |
| `05a_heads_front_2x2_1x1.png` | **`1:1`** | 4 cabezas (`front, front_r / front_l, side_r`) | **Prompt 2 (Cabezas)** |
| `05b_heads_back_2x2_1x1.png` | **`1:1`** | 4 cabezas (`side_l, back_r / back_l, back`) | **Prompt 2 (Cabezas)** |

---

## Prompt 1 — Cuerpo, Piernas, Brazos y Hombreras (`16:9`)
*Usar con: `01_body_core_5dir_16x9.png`, `02a_legs_R_5dir_16x9.png`, `02b_legs_L_5dir_16x9.png`, `03_arms_10pcs_16x9.png`, `04_pauldrons_10pcs_16x9.png`*
```text
Convert this exact anime character piece sheet into ultra-crisp, studio-quality Japanese anime clean-up line art (douga / genga ink pass) using ONLY pure #000000 black ink lines on a pure #FFFFFF solid white background. Preserve the exact canvas dimensions, grid spacing, alignment, proportions, and outer silhouette of every single piece without shifting, resizing, cropping, or adding text.

CRITICAL LINE-ART ONLY RULES (STRICT):
- USE ONLY TWO COLORS: #000000 pure black for ink strokes and #FFFFFF pure white for everything else.
- DO NOT FILL dark areas with solid black! The dark charcoal bodysuit, black gloves, dark boots, dark stockings, and inner crevices MUST remain pure #FFFFFF white inside, defined ONLY by clean black outline and seam strokes.
- DELETE 100% of color, gray shading, cast shadows, cel-shading fills, gradients, highlights, specular shine, screentones, and cross-hatching.
- Keep line weight razor-sharp, clean, continuous, and consistent (anime production clean-up pen, 2–3px crisp ink, zero blurry/fuzzy airbrush lines, zero sketchy double-strokes).
- TRACE EVERY IMPORTANT LINE:
  1. Crisp closed outer silhouette contour of each piece.
  2. All internal armor plate edges, chest/back carapace panel seams, pauldron trims, knee/shin armor plates, and cybernetic spinal details.
  3. All crimson trim piping borders, belt/garter straps, stocking top cuffs, boot seams, and glove/finger contours.
  4. Clean structural suit folds and anatomical cleavage/hip cutout borders.
- Pure #FFFFFF solid white background with zero dust, noise, or gray halos.
```

---

## Prompt 2 — Cabezas (`1:1`)
*Usar con: `05a_heads_front_2x2_1x1.png` y `05b_heads_back_2x2_1x1.png`*
```text
Convert this exact 2x2 high-resolution anime head turnaround sheet into ultra-crisp, studio-quality Japanese anime clean-up line art (douga ink pass) using ONLY pure #000000 black ink lines on a pure #FFFFFF solid white background. Preserve the exact 2x2 grid layout, spacing, hair tip silhouettes, facial proportions, eye placement, monocle position, and neck contours without shifting, resizing, or cropping.

CRITICAL LINE-ART ONLY RULES (STRICT):
- USE ONLY TWO COLORS: #000000 pure black for ink strokes and #FFFFFF pure white for everything else.
- DO NOT FILL dark collars, neck shadows, hair undersides, or eye irises with solid black blobs or gray shading. Leave interiors pure #FFFFFF white, defined strictly by crisp black ink contours (solid black is allowed ONLY on thin upper eyelashes and tiny pupil core).
- DELETE 100% of color, gray shading, blush, hair highlights, gradients, screentones, and sketchy pencil noise.
- Keep ink strokes razor-sharp, smooth, and vector-clean (consistent anime production line weight, tapering cleanly at hair tips).
- TRACE EVERY IMPORTANT DETAIL:
  1. Crisp closed outer hair and jawline/neck silhouette.
  2. Clean internal silver hair strand divisions and bangs.
  3. Precise facial features: eyebrows, upper/lower eyelashes, iris/pupil ring, nose, lips/mouth, ear interior, and neck collar seams.
  4. Crisp red monocle lens rim and thin monocle head-strap lines.
- Pure #FFFFFF solid white background with zero gray halos or artifacts.
```

---

## Checklist rápido antes de correr las 7 hojas (Prueba con 1 hoja primero)
Antes de generar las 7 hojas, prueba primero con `01_body_core_5dir_16x9.png` o `05a_heads_front_2x2_1x1.png` y verifica:
1. **Traje oscuro vacío por dentro**: el traje negro/botas/guantes deben verse **blancos por dentro** con solo sus líneas/costuras negras (si la IA lo rellena de negro sólido, regenerar).
2. **Alineación exacta**: las siluetas deben coincidir en posición y escala con la hoja original en `inputs/`.
3. **Líneas limpias y continuas**: sin sombreado gris, sin tramado manga y sin trazos dobles borrosos.
