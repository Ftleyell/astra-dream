# Fase A — Prompts para Máscaras de Material / ID (`*_id_mask.png`)

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
C:\Python314\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind id
```
