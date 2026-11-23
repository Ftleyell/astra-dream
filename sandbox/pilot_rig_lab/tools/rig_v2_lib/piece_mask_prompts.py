"""Anti-outline AI prompt guides for Valentina v2 piece-level mask regeneration (ID, Normal/Depth, ILM)."""

from __future__ import annotations


def build_prompt_a_id_mask() -> str:
    return r"""# Fase A — Prompts para Máscaras de Material / ID (`*_id_mask.png`)

## Carpetas de trabajo
- **Entradas limpias (subir al generador):** `inputs/` (fondo `#FFFFFF` puro, sin texto)
- **Guías con rótulos (solo lectura humana):** `guides/`
- **Dónde guardar tus resultados:** `outputs_id/` *(con el **mismo nombre de archivo** que en `inputs/`)*

## Tabla de las 7 hojas estándar
| Archivo | Aspect Ratio IA | Contenido |
| :--- | :---: | :--- |
| `01_body_core_5dir_16x9.png` | **`16:9`** | 5 torsos (`S, SE, E, NE, N`) |
| `02a_legs_R_5dir_16x9.png` | **`16:9`** | 5 piernas derechas (`S, SE, E, NE, N`) |
| `02b_legs_L_5dir_16x9.png` | **`16:9`** | 5 piernas izquierdas (`S, SE, E, NE, N`) |
| `03_arms_10pcs_16x9.png` | **`16:9`** | 10 brazos (`arm_r` fila sup, `arm_l` fila inf) |
| `04_pauldrons_10pcs_16x9.png` | **`16:9`** | 10 hombreras (`pauldron_r` sup, `pauldron_l` inf) |
| `05a_heads_front_2x2_1x1.png` | **`1:1`** | 4 cabezas (`front, front_r / front_l, side_r`) |
| `05b_heads_back_2x2_1x1.png` | **`1:1`** | 4 cabezas (`side_l, back_r / back_l, back`) |

## Código estricto de colores RGB (Paleta Ortogonal)
| Color | Hex | Material |
| :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío (puro, sin sombras) |
| **Amarillo Neón** | `#FFFF00` | **Piel expuesta** (rostro, ojos/labios, escote, muslo superior desnudo, glúteos) |
| **Azul Neón** | `#0000FF` | **Traje oscuro táctico**, cuello alto, guantes, botas/suelas oscuras |
| **Verde Neón** | `#00FF00` | **Placas de armadura rígida** (hombreras, placa pecho/espalda, rodilleras, tobilleras rígidas) |
| **Rojo Neón** | `#FF0000` | **Acentos carmesí / tiras rojas** (bordes rojos, cintas, ribetes, monóculo rojo + correa) |
| **Cian Neón** | `#00FFFF` | **Cabello plateado** (cabezas) y **medias translúcidas** (piernas, desde la liga hasta la bota) |

---

## Prompt 1 — `01_body_core_5dir_16x9.png` (Generar en **`16:9`**)
```text
Convert this exact 5-torso reference sheet into a flat, razor-sharp semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact canvas dimensions, 5-column spacing, alignment, and outer silhouette of every torso without shifting, cropping, or adding text.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink linework, interior contour lines, shading, highlights, and gradients.
- Do NOT leave black, dark-gray, or antialiased muddy borders between colors.
- Extend/bleed each flat material color cleanly all the way across where the black outline used to be (1–2px outward is fine; zero black border pixels allowed).
- Use ONLY flat unshaded solid pure hex blocks with hard razor-sharp boundaries:

COLOR MAP:
- #FFFF00 Pure Neon Yellow: ALL bare exposed skin (chest cleavage cutout, bare waist/hip cutouts, exposed buttocks on back views, any visible neck skin). Never leave skin white.
- #00FF00 Pure Neon Green: rigid raised armor plates (chest armor cups/plate, upper back carapace plate, hip armor plates).
- #FF0000 Pure Neon Red: ALL crimson/burgundy trim strips, red straps, red piping borders, and glowing red chest/back accents.
- #0000FF Pure Neon Blue: dark charcoal undersuit leotard, turtleneck collar, spinal cybernetic vertebrae column, and dark inner fabric.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Prompt 2 — `02a_legs_R_5dir_16x9.png` y `02b_legs_L_5dir_16x9.png` (Generar en **`16:9`**)
```text
Convert this exact 5-leg reference sheet into a flat, razor-sharp semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact canvas dimensions, 5-column spacing, alignment, and silhouette of all 5 legs without shifting or resizing.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink outlines, interior line art, shading, specular shine, and gradients.
- Replace every black outline pixel with the flat solid color of its material so ZERO black or gray line pixels remain.
- Keep hard crisp boundaries with zero soft blending or color mixing between adjacent neon colors.

COLOR MAP:
- #FFFF00 Pure Neon Yellow: bare exposed upper thigh skin ABOVE the stocking top band/cuff. Never leave skin white.
- #00FFFF Pure Neon Cyan: the semi-translucent dark thigh-high stocking from the top thigh cuff band down to where the armored knee/shin boot begins.
- #00FF00 Pure Neon Green: rigid raised armor plates (knee cap shield, armored shin guard, metallic ankle/heel armor plates).
- #FF0000 Pure Neon Red: ALL crimson/red trim lines, thigh garter red accents, red knee/boot straps, and red piping.
- #0000FF Pure Neon Blue: dark charcoal boot body, dark heel/sole, and dark non-translucent fabric cuffs.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Prompt 3 — `03_arms_10pcs_16x9.png` (Generar en **`16:9`**)
```text
Convert this exact 5x2 (10-arm) reference sheet into a flat, razor-sharp semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact 5x2 grid layout, spacing, and silhouette of all 10 arms (5 top row, 5 bottom row) without shifting, merging, or cropping.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink linework, outer outlines, shadows, and highlights.
- Paint flat pure colors right over where black outlines used to sit (zero black, gray, or soft antialiased halos).
- Keep finger silhouettes crisp and solid.

COLOR MAP:
- #0000FF Pure Neon Blue: dark charcoal sleeve, cybernetic forearm undersuit, and gloves/hands/fingers.
- #00FF00 Pure Neon Green: rigid raised armor plates on elbow, forearm bracer, or upper arm.
- #FF0000 Pure Neon Red: ALL crimson/red arm straps, wrist/bicep trim strips, and glowing red cuffs.
- #FFFF00 Pure Neon Yellow: ONLY if any bare skin is visible (otherwise do not use yellow).
- #FFFFFF Pure Solid White: empty background only.
```

---

## Prompt 4 — `04_pauldrons_10pcs_16x9.png` (Generar en **`16:9`**)
```text
Convert this exact 5x2 (10-pauldron) shoulder armor sheet into a flat, razor-sharp semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact 5x2 grid layout, spacing, and silhouette of all 10 shoulder pauldrons without shifting or resizing.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black outlines, shading, metallic sheen, and gradients.
- Fill completely across where black line art used to be with flat solid hex colors (zero black/gray pixels, zero blurry edges).

COLOR MAP:
- #00FF00 Pure Neon Green: main rigid shoulder armor plate surface.
- #FF0000 Pure Neon Red: ALL crimson/red outer trim borders, red stripes, and red accent bands on each pauldron.
- #0000FF Pure Neon Blue: dark inner/underside joint fabric or dark recess trim.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Prompt 5 — `05a_heads_front_2x2_1x1.png` y `05b_heads_back_2x2_1x1.png` (Generar en **`1:1`**)
```text
Convert this exact 2x2 high-resolution anime head turnaround grid into a flat, ultra-clean semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact 2x2 layout, hair tip silhouettes, facial contours, and neck collars without shifting or cropping.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink outlines, hair strand lines, eyelashes/eyebrow shading, and gradients.
- Fill every pixel strictly with flat solid pure hex blocks; extend colors cleanly over black outlines so zero black/gray edge pixels remain.
- Do NOT blur or blend Cyan hair into Yellow skin (keep razor-sharp hair strand edges!).

COLOR MAP:
- #00FFFF Pure Neon Cyan: the ENTIRE silver-white hair (bangs, side locks, crown, and back hair spikes).
- #FFFF00 Pure Neon Yellow: ALL exposed facial skin, ears, lips/mouth, visible normal eye/sclera/iris, and any bare neck/chest skin. Never leave skin white.
- #FF0000 Pure Neon Red: ONLY the round red left-eye monocle lens + its diagonal temple strap + any thin red collar trim. Be extra precise on 3/4 and side views where only the edge of the monocle peeks out.
- #0000FF Pure Neon Blue: the dark high-neck tactical turtleneck collar and neck vertebrae column.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Ingesta automática en Python
Cuando guardes tus hojas en `outputs_id/`, ejecuta:
```powershell
python sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind id
```
"""


def build_prompt_b_normal_depth() -> str:
    return r"""# Fase B — Prompts para Normales 2.5D + Profundidad (`*_normal_depth.png`)

## Carpetas de trabajo
- **Entradas limpias (subir al generador):** `inputs_normal/` (fondo neutro `#8080FF` para evitar halos blancos en normales)
- **Dónde guardar tus resultados:** `outputs_normal/` *(con el **mismo nombre de archivo** que en `inputs_normal/`)*

## Reglas clave para Normales Anime (sin "efecto plastilina")
- El fondo debe permanecer **`#8080FF`** (normal neutra `(0, 0, +1)` apuntando directo a cámara).
- **Convención Tangent-Space OpenGL/Godot:**
  - Superficie mirando hacia la **DERECHA** (`+X`) → **Rosa / Rojo cálido** (`#FF8080`)
  - Superficie mirando hacia la **IZQUIERDA** (`-X`) → **Cian / Azul verdoso** (`#0080FF`)
  - Superficie mirando hacia **ARRIBA** (`-Y` en pantalla) → **Verde brillante** (`#80FF80`)
  - Superficie mirando hacia **ABAJO** (`+Y` en pantalla) → **Violeta / Magenta oscuro** (`#8000FF`)
  - Superficie **PLANA hacia cámara** (`+Z`) → **Lavanda neutro** (`#8080FF`)
- **IMPORTANTE:** Al ingerir (`--kind normal`), Python normaliza matemáticamente cada píxel (`normalize(N)`), recorta al alpha exacto de la pieza, sintetiza profundidad en el canal Alfa e **invierte automáticamente `Nx` (`R' = 255 - R`) al espejar `SW, W, NW`**.

---

## Prompt Universal — Hojas de Cuerpo (`01_body_core`, `02a/b_legs`, `03_arms`, `04_pauldrons` en **`16:9`**)
```text
Convert this exact multi-piece anime character sheet into a clean, stylized tangent-space 3D normal map on a flat #8080FF neutral periwinkle background. Preserve the exact grid layout, piece count, spacing, and outer silhouettes with zero shifting or cropping.

CRITICAL ANTI-OUTLINE & ANIME NORMAL RULES:
- DELETE 100% of black ink outlines, textures, colors, and painted shadows; output ONLY smooth tangent-space normal RGB colors.
- Treat each limb and torso as clean, sculptural anime cel-shading geometry (like Guilty Gear Strive / ArcSys): smooth rounded cylinders for thighs, shins, and arms; clean beveled planar facets for hard armor plates and pauldrons; smooth anatomical curves for chest/back torso.
- Avoid noisy bumpy "clay/plasticine" micro-details or fabric wrinkles — keep broad, clean, readable curvature gradients so cel-shading cuts cleanly!
- Standard tangent-space normal encoding:
  * Facing camera (+Z) = #8080FF lavender
  * Facing right (+X) = pinkish red (#FF8080)
  * Facing left (-X) = cyan-blue (#0080FF)
  * Facing up = green (#80FF80)
  * Facing down = violet-purple (#8000FF)
- Extend normal colors cleanly to the silhouette edge (zero black outlines, zero white halos).
```

---

## Prompt — Hojas de Cabezas (`05a_heads_front_2x2_1x1.png` y `05b_heads_back_2x2_1x1.png` en **`1:1`**)
```text
Convert this exact 2x2 anime head turnaround grid into a clean, stylized anime tangent-space normal map on a flat #8080FF neutral background. Preserve the exact 2x2 layout and silhouettes without shifting.

CRITICAL ANIME FACE NORMAL RULES (ArcSys / Guilty Gear style):
- DELETE 100% of black ink outlines, eye/mouth color details, and painted shading.
- Sculpt the FACE as a very smooth, simplified anime sphere/oval (minimal nose bump, NO heavy realistic eye sockets or bumpy cheeks) so directional cel-shading produces clean, flattering anime shadows across the face.
- Sculpt the HAIR bangs and locks as bold, clean directional ribbons/cylinders with crisp bevels between major hair clumps.
- Sculpt the neck collar as a clean vertical cylinder and the monocle lens as a flat forward-facing disc (#8080FF).
- Standard tangent-space RGB normal encoding (#8080FF flat, +X pink/red, -X cyan/blue, up green, down violet). Zero black lines, zero noise.
```

---

## Ingesta automática en Python
Cuando guardes tus hojas en `outputs_normal/`, ejecuta:
```powershell
python sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind normal
```
"""


def build_prompt_c_ilm_mask() -> str:
    return r"""# Fase C — Prompts para Máscara ILM / Control Artístico (`*_ilm_mask.png`)

## ¿Qué controla la máscara ILM (estilo Guilty Gear / ArcSys)?
Como las IAs no pintan bien 4 canales RGBA separados a mano, generamos una **hoja de 6 colores planos intuitivos** que `ingest_piece_mask_sheets.py --kind ilm` traduce automáticamente a los 4 canales exactos del shader:

| Color en la hoja IA | Hex | Zona artística | Traducción RGBA en shader |
| :--- | :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Ignorado |
| **Rojo Neón** | `#FF0000` | **Metal / Especular Duro** (placas de armadura, herrajes, biseles brillantes) | `R=1.00, G=0.55, B=1.00, A=0.0` |
| **Cian Neón** | `#00FFFF` | **Nylon / Satinado** (medias translúcidas, zonas semibrillantes, *Angel Ring* del pelo) | `R=0.58, G=0.52, B=0.75, A=0.0` |
| **Azul Neón** | `#0000FF` | **Sombra Cel Fija / Oclusión** (pliegues profundos, bajo busto, axilas, bajo flequillo, interior del cuello) | `R=0.05, G=0.08, B=0.10, A=0.0` |
| **Amarillo Neón** | `#FFFF00` | **Zona Protegida (Rostro / Piel Clave)** — evita sombras cel sucias y rim invasivo en cara y escote | `R=0.08, G=0.92, B=0.18, A=0.0` |
| **Verde Neón** | `#00FF00` | **Mate Neutro con Rim Limpio** (traje mate, guantes, cabello base fuera del brillo) | `R=0.15, G=0.50, B=0.85, A=0.0` |
| **Magenta Neón** | `#FF00FF` | **Emisivo / Glow** (lente del monóculo rojo y acentos luminosos) | `R=0.90, G=1.00, B=1.00, A=1.0` |

---

## Prompt Universal — Cuerpos (`16:9`) y Cabezas (`1:1`) usando `inputs/`
```text
Convert this exact character piece sheet into a flat, razor-sharp cel-shading ILM control zone mask on a pure #FFFFFF solid white background. Preserve exact canvas dimensions, grid positions, and silhouettes without shifting or cropping.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink linework, outlines, gradients, and painted shading.
- Fill every pixel strictly with flat solid pure hex blocks extending cleanly across where black outlines used to be (zero black/gray edge pixels, zero soft airbrushing).

ILM ZONE COLOR MAP:
- #FF0000 Pure Neon Red (HARD SPECULAR METAL): rigid armor plates (pauldrons, chest/back plates, knee shields, metallic shin/ankle guards, hard red trim buckles).
- #00FFFF Pure Neon Cyan (SATIN / NYLON / HAIR SPECULAR): thigh-high translucent stockings AND the horizontal halo specular band ("angel ring") across the crown of the silver hair.
- #0000FF Pure Neon Blue (PERMANENT CEL SHADOW / AO): deep occlusion crevices — underside of chest/bust, armpit folds, deep collar/neck shadow under chin, and dark shadow cast directly under hair bangs.
- #FFFF00 Pure Neon Yellow (PROTECTED SKIN / FACE): clean lit facial skin, cheeks, eyes, bare cleavage skin, and bare upper thighs (protects skin from harsh dirty cel shadows).
- #00FF00 Pure Neon Green (MATTE SUIT & BASE HAIR): matte dark undersuit fabric, sleeves, gloves, boots, and main silver hair volume outside the cyan highlight band.
- #FF00FF Pure Neon Magenta (EMISSIVE GLOW): glowing red monocle lens and any glowing cybernetic energy strips.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Ingesta automática en Python
Cuando guardes tus hojas en `outputs_ilm/`, ejecuta:
```powershell
python sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind ilm
```
"""


def build_prompt_d_ink_lineart() -> str:
    return r"""# Fase D — Prompts para Canal "Solo Tinta" / Clean-Up Lineart (`*_ink_sdf.png`)

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
"""
