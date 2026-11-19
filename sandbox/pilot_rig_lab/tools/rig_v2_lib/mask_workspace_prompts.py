"""Prompt guides and README text generators for AI mask workspaces."""

from __future__ import annotations


def _prompt_guide_01_parts5() -> str:
    return """# 01 — Máscara de Despiece de 5 Partes (`parts_5_despiece`)

## ¿Qué hace esta máscara?
Divide cada cuerpo en **5 piezas móviles independientes** (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`) para el rig 2.5D de Valentina.

## Imágenes de entrada (`inputs/` — Relaciones de aspecto exactas)
| Archivo | Poses (izq → der) | Tamaño px | Relación IA a elegir |
| :--- | :--- | :--- | :--- |
| `batchA_S_SE_E_16x9_white.png` | **`S`** (Frente), **`SE`** (3/4 Frente Der), **`E`** (Perfil Der) | `3072 x 1728` | **`16:9`** Exacto |
| `batchB_NE_N_4x3_white.png` | **`NE`** (3/4 Espalda Der), **`N`** (Espalda Pura) | `2304 x 1728` | **`4:3`** Exacto |
> Selecciona exactamente **`16:9`** para `batchA` y **`4:3`** para `batchB` en tu IA generativa para que las proporciones no se estiren. No necesitas generar `SW`, `W` ni `NW`: Python las espeja e invierte `L/R` automáticamente al re-ingresar (`--ingest`).

## Código estricto de colores RGB
| Color | Hex | Pieza a cubrir | Notas anatómicas clave |
| :--- | :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Mantener puro sólido, sin sombras ni líneas fuera del cuerpo |
| **Verde Neón** | `#00FF00` | `body_core` (Torso + Pelvis + Cuello + **Cabeza completa**) | Incluye hombreras/clavícula hasta el pliegue de la axila y el leotardo hasta la ingle. Incluir cabeza y pelo en verde mantiene el anclaje completo del torso |
| **Rojo Neón** | `#FF0000` | **Brazo IZQUIERDO EN PANTALLA** (`viewer-left arm`) | Todo el brazo izquierdo de la imagen (desde el deltoides debajo de la hombrera hasta las puntas de los dedos) |
| **Azul Neón** | `#0000FF` | **Brazo DERECHO EN PANTALLA** (`viewer-right arm`) | Todo el brazo derecho de la imagen (desde el deltoides debajo de la hombrera hasta las puntas de los dedos). *En `E` (perfil): pinta el brazo visible cercano de **Azul**; si asoma la mano trasera del otro brazo, píntala de **Rojo**.* |
| **Amarillo Neón** | `#FFFF00` | **Pierna IZQUIERDA EN PANTALLA** (`viewer-left leg`) | Muslo izquierdo en pantalla (desde el corte inferior del leotardo), rodilla, pantorrilla y tacón izquierdo |
| **Magenta Neón** | `#FF00FF` | **Pierna DERECHA EN PANTALLA** (`viewer-right leg`) | Muslo derecho en pantalla (desde el corte inferior del leotardo), rodilla, pantorrilla y tacón derecho |

---

## Prompt listo para copiar — `batchA_S_SE_E_16x9_white.png` (Generar en `16:9`)
```text
Edit this exact 3-pose character reference sheet into a flat, crisp, anti-aliased semantic body-part segmentation mask on a pure #FFFFFF solid white background. Preserve the exact silhouettes, pose alignment, spacing, and pixel proportions of all three figures (left to right: front view, front-right 3/4 view, pure right side profile), removing all interior shading, textures, highlights, and line art. Fill every silhouette strictly with flat solid pure RGB block colors:
- #00FF00 Pure Neon Green: full head, silver hair, neck, torso chest/back, waist, leotard crotch, and upper shoulder pauldrons down to the armpit seam and groin hip seam.
- #FF0000 Pure Neon Red: the viewer's LEFT arm (on the left side of each figure's torso) from upper arm below the shoulder pad down to all fingers. On the 3rd rightmost side-profile figure, only paint any far-side hand/arm edge #FF0000 Red if clearly protruding separately; do NOT force red if occluded.
- #0000FF Pure Neon Blue: the viewer's RIGHT arm (on the right side of each figure's torso) from shoulder joint down to fingertips. On the 3rd rightmost side-profile figure, paint the ENTIRE visible near arm cleanly #0000FF Blue.
- #FFFF00 Pure Neon Yellow: the viewer's LEFT leg (from the high-cut hip/thigh seam down through thigh, knee, shin, and high-heel boot). On the 3rd side-profile figure, paint #FFFF00 Yellow ONLY if a separate far leg clearly peeks out behind.
- #FF00FF Pure Neon Magenta: the viewer's RIGHT leg (from the high-cut hip/thigh seam down through thigh, knee, shin, and high-heel boot). On the 3rd rightmost side-profile figure, paint the ENTIRE visible stacked leg silhouette cleanly #FF00FF Magenta (never split one leg vertically into two colors).
Keep crisp razor-sharp boundaries between limbs and torso, keep enclosed gaps between arms and waist pure #FFFFFF white, zero gradients, zero black outlines.
```

## Prompt listo para copiar — `batchB_NE_N_4x3_white.png` (Generar en `4:3`)
```text
Edit this exact 2-pose character reference sheet into a flat, crisp semantic body-part segmentation mask on a pure #FFFFFF solid white background. Preserve the exact silhouettes, alignment, spacing, and pixel proportions of both figures (left to right: back-right 3/4 view, pure back view), removing all shading, details, and black line art. Fill each figure strictly with flat solid pure RGB block colors:
- #00FF00 Pure Neon Green: full head, hair, neck, spine/back torso, shoulder pauldrons, hips and leotard seat down to the glute/thigh crease.
- #FF0000 Pure Neon Red: the arm on the viewer's LEFT side of each figure, from just below the shoulder pauldron down through elbow, forearm, and hand/fingers.
- #0000FF Pure Neon Blue: the arm on the viewer's RIGHT side of each figure, from below the shoulder pauldron down through elbow, forearm, and hand/fingers.
- #FFFF00 Pure Neon Yellow: the leg on the viewer's LEFT side of each figure, from below the leotard/glute seam all the way down to the heel tip.
- #FF00FF Pure Neon Magenta: the leg on the viewer's RIGHT side of each figure, from below the leotard/glute seam all the way down to the heel tip.
Keep enclosed gaps between arms and waist pure #FFFFFF white, crisp clean borders between touching regions, flat unshaded pure hex colors only.
```

## Cómo procesar cuando termines
Guarda los dos resultados con el mismo nombre dentro de `masked_outputs/` y ejecuta:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest 01_parts_5_despiece
```
"""


def _prompt_guide_02_id_bodies() -> str:
    return """# 02 — Máscara de Materiales / ID de Cuerpos (`id_mask_bodies`)

## ¿Qué hace esta máscara?
Le indica al shader de iluminación cel (`pilot_rig_stylizer.gdshader`) qué regiones del cuerpo son piel viva (exenta de tinte), traje táctico oscuro, armadura rígida, detalles carmesí o medias translúcidas.

## Entradas incluidas (`inputs/` y `python_auto_draft/` — Relaciones de aspecto exactas)
| Archivo | Poses (izq → der) | Tamaño px | Relación IA a elegir |
| :--- | :--- | :--- | :--- |
| `inputs/batchA_S_SE_E_16x9_white.png` | **`S | SE | E`** | `3072 x 1728` | **`16:9`** Exacto |
| `inputs/batchB_NE_N_4x3_white.png` | **`NE | N`** | `2304 x 1728` | **`4:3`** Exacto |
* `python_auto_draft/` — Copias pre-segmentadas por Python exactamente en `16:9` (`3072x1728`) y `4:3` (`2304x1728`); puedes darle a tu IA **[input original + auto_draft]** como guía para limpiar bordes o generarla desde cero.

## Código estricto de colores RGB
| Color | Hex | Material / Capa | Canal final en shader |
| :--- | :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Ignorado (`alpha = 0`) |
| **Amarillo Neón** | `#FFFF00` | **Piel expuesta** (muslos arriba de la media, escote del pecho, glúteos desnudos, rostro si aparece) | `Skin (0,0,0,0)` *(Usamos amarillo para no chocar con fondo blanco)* |
| **Azul Neón** | `#0000FF` | **Traje oscuro, botas altas, guantes cibernéticos y vértebras de cuello/espalda** | Canal **`B`** (Dark suit / cyber) |
| **Verde Neón** | `#00FF00` | **Placas de armadura rígida** (hombreras, rodilleras, placa central del pecho/espalda, tobilleras rígidas) | Canal **`G`** (Armor plates) |
| **Rojo Neón** | `#FF0000` | **Acentos carmesí / tiras rojas** (bordes rojos de hombreras, muslos/brazos, rodilleras, cintas, monóculo rojo) | Canal **`R`** (Crimson accent) |
| **Cian Neón** | `#00FFFF` | **Medias translúcidas de muslo** (desde la liga oscura superior hasta los protectores metálicos de espinilla) + **pelo plateado** | Canal **`A`** (Stockings / hair) |

---

## Prompt listo para copiar — `batchA_S_SE_E_16x9_white.png` (`16:9`) y `batchB_NE_N_4x3_white.png` (`4:3`)
> *(Puedes subir la imagen de `inputs/` sola, o subir `inputs/` junto con su par de `python_auto_draft/` diciendo que corrija y limpie los bloques sobre la silueta exacta).*

```text
Convert this multi-pose character turnaround sheet into a flat, razor-sharp semantic material ID mask on a pure #FFFFFF solid white background. Preserve the exact pixel silhouette, outline boundary, pose spacing, and alignment of every figure, removing all lighting, gradients, specular highlights, and black contour lines. Map every visible pixel of every character strictly to these 5 flat pure hex colors:
- #FFFF00 Pure Neon Yellow: ALL bare exposed skin (face skin, neck skin if any, chest cleavage cutout, bare upper thighs between leotard and stocking cuffs, bare buttocks on back views). Never leave skin white.
- #00FFFF Pure Neon Cyan: silver-white hair AND the semi-translucent dark-brown thigh-high stockings (from the dark top thigh band down to the top edge of the armored shin boots).
- #00FF00 Pure Neon Green: hard raised armor plates — outer shoulder pauldrons, upper back carapace plate, chest armor cup plate, knee cap shields, and rigid shin/ankle armor plates.
- #FF0000 Pure Neon Red: ALL crimson/burgundy fabric trim, glowing red eye monocle, red straps on shoulders/arms/waist/knees, and red side piping strips.
- #0000FF Pure Neon Blue: the dark charcoal undersuit leotard, sleeves, gloves/hands, turtleneck collar, spinal cybernetic cable, and dark high-heel boots/soles.
Use flat unshaded solid colors only, crisp pixel borders, keep enclosed background gaps pure #FFFFFF white.
```

## Cómo procesar cuando termines
Guarda las imágenes resultantes en `masked_outputs/` con el mismo nombre (`batchA_S_SE_E_16x9_white.png` / `batchB_NE_N_4x3_white.png`) y ejecuta:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest 02_id_mask_bodies
```
"""


def _prompt_guide_03_id_heads() -> str:
    return """# 03 — Máscara de Materiales / ID de Cabezas Hi-Res (`id_mask_heads`)

## ¿Qué hace esta máscara?
Segmenta las **8 cabezas asimétricas de alta resolución (`1024x1024`)**: pelo, piel/ojos, cuello de traje y el **monóculo rojo** (con su cinta).
> **Importante:** Las cabezas NO se espejan porque el mechón largo y el monóculo rojo cambian según el ángulo. Te entregamos el bloque completo `4x2` Y también dos mitades `4x1` de mayor resolución para que uses el formato donde la IA dibuje el monóculo más nítido.

## Entradas disponibles (`inputs/` y `python_auto_draft/` — Relaciones de aspecto exactas)
| Opción | Archivo | Cuadrícula | Tamaño px | Relación IA a elegir |
| :--- | :--- | :--- | :--- | :--- |
| **Recomendada (2x2)** | `batchA_front_2x2_1x1_white.png` | Sup `[S | SE]`, Inf `[SW | W]` | `2048 x 2048` | **`1:1`** Exacto |
| **Recomendada (2x2)** | `batchB_back_2x2_1x1_white.png` | Sup `[E | NE]`, Inf `[NW | N]` | `2048 x 2048` | **`1:1`** Exacto |
| Alternativa (`4x2`) | `all8_4x2_16x9_white.png` | Sup `[S, SE, SW, W]`, Inf `[E, NE, NW, N]` | `4096 x 2304` | **`16:9`** Exacto |
* **`python_auto_draft/`** tiene el borrador ink-locked hecho por Python con exactamente los mismos lienzos (`1:1` y `16:9`).

## Código estricto de colores RGB (compatible con `process_head_8dir_sheet.py`)
| Color | Hex | Parte del busto | Canal final en shader |
| :--- | :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Ignorado (`alpha = 0`) |
| **Cian Neón** | `#00FFFF` | **Cabello plateado completo** (flequillo y nuca) | Canal **`A`** (y genera `hair_jiggle_mask`) |
| **Verde Neón** | `#00FF00` | **Piel de rostro, orejas, labios, ojo normal visible y piel del escote del pecho** | `Skin (0,0,0,0)` |
| **Azul Neón** | `#0000FF` | **Cuello alto táctico, vértebras cervicales, hombreras, corpiño oscuro** | Canal **`B`** (Collar/Suit) |
| **Rojo Neón** | `#FF0000` | **Monóculo cibernético rojo** (lente + cinta diagonal hacia la oreja) y tiras rojas del pecho/hombro | Canal **`R`** (Monocle / Red accent) |

---

## Prompt listo para copiar — `batchA_front_2x2_1x1_white.png` / `batchB_back_2x2_1x1_white.png` (`1:1`) o `all8_4x2_16x9_white.png` (`16:9`)
```text
Convert this high-resolution anime bust turnaround grid into a flat, ultra-clean semantic ID mask on a pure #FFFFFF solid white background. Preserve the exact silhouette, hair tips, facial outline, shoulders, and grid layout of every bust portrait, removing all shading, highlights, and interior ink lines. Paint every pixel inside each bust silhouette strictly with these 4 flat solid pure hex colors:
- #00FFFF Pure Neon Cyan: the entire silver-white hair (bangs, side locks, crown, and back hair spikes).
- #00FF00 Pure Neon Green: all exposed facial skin, ear, mouth/lips, the visible bare eye/sclera/iris (excluding eyebrow hair covering it, or paint skin under bangs green cleanly), and the bare cleavage chest skin cutout.
- #FF0000 Pure Neon Red: ONLY the round red left-eye monocle lens + its diagonal temple strap + the thin crimson straps on the collar/shoulders. Be extra precise on 3/4 and side views where only the edge of the monocle or strap peeks out!
- #0000FF Pure Neon Blue: the dark high-neck tactical turtleneck collar, neck spinal vertebrae column, shoulder pauldrons, and dark bustier armor.
Keep hair strands cutting cleanly over skin and collar, pure #FFFFFF white background outside silhouettes, flat unshaded hex colors with zero gradients or outlines.
```

## Cómo procesar cuando termines
Guarda en `masked_outputs/` O BIEN `batchA_front_2x2_1x1_white.png` + `batchB_back_2x2_1x1_white.png`, O BIEN `all8_4x2_16x9_white.png`, y ejecuta:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest 03_id_mask_heads
```
"""


def _prompt_guide_04_limb_anim() -> str:
    return """# 04 — Máscara de Segmentos de Extremidades (`limb_anim_masks`)

## ¿Qué hace esta máscara?
Divide los **2 brazos y 2 piernas** en 3 zonas rígidas para pesos suaves de articulaciones en el mesh deformado (`Upper`, `Lower`, `Extremity`), evitando estiramientos feos en codos, rodillas y tacones.

## Imágenes de entrada (`inputs/` — Relaciones de aspecto exactas)
| Archivo | Poses (izq → der) | Tamaño px | Relación IA a elegir |
| :--- | :--- | :--- | :--- |
| `inputs/batchA_S_SE_E_16x9_white.png` | **`S | SE | E`** | `3072 x 1728` | **`16:9`** Exacto |
| `inputs/batchB_NE_N_4x3_white.png` | **`NE | N`** | `2304 x 1728` | **`4:3`** Exacto |
> Igual que en `01_parts_5_despiece`, `SW / W / NW` se espejan automáticamente.

## Código estricto de colores RGB
| Color | Hex | Zona del cuerpo | Rol |
| :--- | :--- | :--- | :--- |
| **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Fondo puro |
| **Carbón / Negro Plano** | `#181818` | **Torso + Cadera/Leotardo + Cuello + Cabeza + Hombreras** | **Ancla neutra** (Mantiene la silueta completa del cuerpo para alineación IoU 1:1 en Python, NO se anima como extremidad) |
| **Rojo Neón** | `#FF0000` | **Segmento SUPERIOR de extremidades**: Hombro-Bíceps (hasta el pliegue del codo) **Y** Muslo (desde la ingle hasta justo encima de la rodillera) | `Upper` (`Shoulder` / `Thigh`) |
| **Verde Neón** | `#00FF00` | **Segmento MEDIO de extremidades**: Codo-Antebrazo (hasta la muñeca) **Y** Rodillera + Pantorrilla/Espinillera (hasta el hueso del tobillo) | `Lower` (`Elbow` / `Knee-Shin`) |
| **Azul Neón** | `#0000FF` | **EXTREMIDAD**: Mano completa + dedos (desde la muñeca) **Y** Tobillo + Zapato/Tacón alto completo (punta a tacón) | `Extremity` (`Wrist-Hand` / `Ankle-Heel`) |

---

## Prompt listo para copiar — `batchA_S_SE_E_16x9_white.png` (`16:9`) y `batchB_NE_N_4x3_white.png` (`4:3`)
```text
Convert this multi-pose character turnaround sheet into a flat skeletal limb-segment mask on a pure #FFFFFF solid white background. Preserve the exact silhouette, alignment, and spacing of every figure, removing all shading, textures, and interior black lines. Color every figure using ONLY these 4 flat solid colors:
- #181818 Flat Very Dark Charcoal: fill the entire head, hair, neck, shoulder pauldrons, torso, hips, and leotard pelvis completely dark #181818 (non-limb anchor).
- #FF0000 Pure Neon Red: ALL upper limbs — upper arms (from below shoulder pad down to elbow bend) AND upper thighs (from high-cut leotard thigh crease down to just above the knee pad, covering thigh skin and stockings).
- #00FF00 Pure Neon Green: ALL mid limbs — forearms (from elbow crease down to wrist joint) AND knee pads plus armored calves/shins (from top of knee guard down to the ankle joint).
- #0000FF Pure Neon Blue: ALL extremities — hands and fingers (from wrist joint to fingertips) AND feet plus high-heel shoes (from ankle hinge joint down to toe tip and stiletto heel).
Make the horizontal joint boundaries at shoulder, elbow, wrist, hip, knee, and ankle clean and razor-sharp across every limb. Keep background and enclosed under-arm gaps pure #FFFFFF white.
```

## Cómo procesar cuando termines
Guarda en `masked_outputs/` (`batchA_S_SE_E_16x9_white.png` y `batchB_NE_N_4x3_white.png`) y ejecuta:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest 04_limb_anim_masks
```
"""


def _prompt_guide_05_secondary_jiggle() -> str:
    return """# 05 — Máscara de Física Secundaria Torso (`secondary_jiggle_masks`)

## ¿Qué hace esta máscara?
Marca exclusivamente las zonas blandas del torso con deformación secundaria (busto al frente y glúteos atrás) para `body_core_secondary_mask.png`. Python las suaviza con gradiente gaussiano y separa automáticamente el lóbulo izquierdo (`R`) del derecho (`G`), además de espejar `SE -> SW` y `NE -> NW`.

## Imágenes de entrada (`inputs/` — Relaciones de aspecto exactas)
| Archivo | Poses y Zona | Color Neón | Tamaño px | Relación IA a elegir |
| :--- | :--- | :--- | :--- | :--- |
| `inputs/batchA_front_S_SE_4x3_white.png` | Frontal **`S | SE`** → solo **BUSTO** | Cian `#00FFFF` | `2304 x 1728` | **`4:3`** Exacto |
| `inputs/batchB_back_N_NE_4x3_white.png` | Espalda **`N | NE`** → solo **GLÚTEOS** | Magenta `#FF00FF` | `2304 x 1728` | **`4:3`** Exacto |

## Código estricto de colores RGB
| Batch | Color | Hex | Zona a tapar | Resto del cuerpo |
| :--- | :--- | :--- | :--- | :--- |
| Ambos | **Fondo Blanco** | `#FFFFFF` | Fondo vacío | Sin cambios fuera de la silueta |
| Ambos | **Gris Oscuro Neutro** | `#404040` | Todo el resto del cuerpo (cabeza, brazos, hombros, abdomen, caderas fuera del área target, piernas y tacones) | **Ancla de silueta plana** *(evita falsos positivos del rojo/piel del traje al segmentar)* |
| `batchA_front_S_SE` | **Cian Neón** | `#00FFFF` | **ÚNICAMENTE el volumen del busto / pecho** (sobre los pechos dentro del corpiño) | No tocar escote superior/cuello, brazos ni cintura |
| `batchB_back_N_NE` | **Magenta Neón** | `#FF00FF` | **ÚNICAMENTE el volumen redondeado de ambos glúteos** (nalgas expuestas + parte baja central del leotardo hasta el pliegue glúteo) | No tocar espalda alta, vértebras, cintura ni parte media del muslo |

---

## Prompt listo para copiar — `batchA_front_S_SE_4x3_white.png` (`4:3`, Frontal: Busto Cian)
```text
Edit this exact 2-pose front character sheet (left: front S view, right: front-right 3/4 SE view) into a secondary-physics zone mask on a pure #FFFFFF solid white background. Preserve the exact silhouettes, alignment, and proportions of both figures, removing all lighting, highlights, outfit colors, and black outlines:
- Fill the entire character silhouette (head, hair, neck, shoulders, arms, waist, leotard hips, legs, and heels) with flat solid #404040 dark neutral gray, EXCEPT for the breast/bust region.
- Paint ONLY the breast/bust mound volume on both figures in pure glowing #00FFFF Neon Cyan (following the exact rounded contour of the bust, stopping cleanly above the ribcage/waist and below the collar cutout, never bleeding onto the arms or shoulders).
Keep enclosed gaps between arms and waist pure #FFFFFF white. Flat solid unshaded hex colors only.
```

## Prompt listo para copiar — `batchB_back_N_NE_4x3_white.png` (`4:3`, Espalda: Glúteos Magenta)
```text
Edit this exact 2-pose back character sheet (left: pure back N view, right: back-right 3/4 NE view) into a secondary-physics zone mask on a pure #FFFFFF solid white background. Preserve the exact silhouettes, alignment, and proportions of both figures, removing all lighting, highlights, outfit colors, and black outlines:
- Fill the entire character silhouette (head, hair, neck, shoulders, upper back, spine, arms, legs below the gluteal fold, and heels) with flat solid #404040 dark neutral gray, EXCEPT for the glutes/buttocks region.
- Paint ONLY both glutes / buttocks cheeks (including the rounded bare buttocks cheeks and lower-seat leotard curve right between them down to the gluteal thigh crease) in pure glowing #FF00FF Neon Magenta, stopping cleanly at the lower waist above and thigh crease below.
Keep enclosed gaps between arms and waist pure #FFFFFF white. Flat solid unshaded hex colors only.
```

## Cómo procesar cuando termines
Guarda en `masked_outputs/` (`batchA_front_S_SE_4x3_white.png` y `batchB_back_N_NE_4x3_white.png`) y ejecuta:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest 05_secondary_jiggle_masks
```
"""


def _root_readme() -> str:
    return """# Valentina v2 — Workspaces de Máscaras en Bloques para IA (`05_mask_ai_workspaces`)

Todas las carpetas aquí contienen **imágenes en blanco puro (`#FFFFFF`) agrupadas en bloques de alta densidad** (sin texto incrustado en el PNG para evitar ruido generativo) + un `PROMPT_GUIDE.md` interno listo para copiar/pegar en tu herramienta de IA generativa.

## Estrategia de Simetría y Relaciones de Aspecto Exactas (`16:9`, `4:3`, `1:1`)
* **Todas las imágenes tienen proporción matemática exacta** (`16:9` = `3072x1728` o `4096x2304`, `4:3` = `2304x1728`, `1:1` = `2048x2048`) y los personajes están centrados verticalmente con márgenes iguales arriba y abajo para evitar recorte o estiramiento de proporción al generar máscaras.
* **Cuerpos (`01`, `02`, `04`, `05`):** Solo trabajas en las **5 vistas base** (`S`, `SE`, `E`, `NE`, `N`). Al ejecutar `--ingest`, Python alinea cada pose por IoU (tolerando además pequeñas variaciones de aspecto) y **genera automáticamente `SW`, `W` y `NW`** por espejado + intercambio `L/R`.
* **Cabezas (`03`):** Se entregan las **8 vistas asimétricas** en dos bloques `2x2` (`1:1`, `2048x2048`) de máxima nitidez y también el bloque completo `4x2` (`16:9`, `4096x2304`).

## Carpetas generadas
1. [`01_parts_5_despiece/`](01_parts_5_despiece/PROMPT_GUIDE.md) — 5 partes móviles (`body_core`, `arm_r/l`, `leg_r/l`)
2. [`02_id_mask_bodies/`](02_id_mask_bodies/PROMPT_GUIDE.md) — ID de materiales cuerpo (incluye `python_auto_draft/` en bloques equivalentes)
3. [`03_id_mask_heads/`](03_id_mask_heads/PROMPT_GUIDE.md) — ID de materiales cabeza 8 vistas hi-res (incluye `python_auto_draft/`)
4. [`04_limb_anim_masks/`](04_limb_anim_masks/PROMPT_GUIDE.md) — Segmentos Upper/Lower/Extremity de brazos y piernas
5. [`05_secondary_jiggle_masks/`](05_secondary_jiggle_masks/PROMPT_GUIDE.md) — Zonas blandas separadas: busto frontal Cian (`S | SE`) y glúteos espalda Magenta (`N | NE`)

## 3 Máscaras que NO necesitan IA (100% automáticas en Python)
* `*_outline_sdf.png` -> Transformada de distancia euclidiana (`polish_outlines.py`).
* `head_*_hair_jiggle_mask.png` -> Rampa radial sobre pelo (`R`) generada desde RGBA + `head_id_mask` (`process_head_8dir_sheet.py`).
* `*_normal_depth.png` -> Normales + profundidad suavizada desde silueta limpia + `id_mask`.

## Re-separar e ingerir las máscaras terminadas
Coloca las imágenes devueltas por tu IA dentro de `<carpeta>/masked_outputs/` manteniendo el **mismo nombre de archivo** que `inputs/`, luego corre:
```powershell
sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest all
```
O una sola carpeta específica, por ejemplo `--ingest 03_id_mask_heads`. Los resultados separados y auditorías visuales aparecen en `<carpeta>/split_results/`.
"""
