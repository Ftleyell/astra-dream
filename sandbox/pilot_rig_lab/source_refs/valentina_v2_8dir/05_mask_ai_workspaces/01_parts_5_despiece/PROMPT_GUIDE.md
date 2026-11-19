# 01 — Máscara de Despiece de 5 Partes (`parts_5_despiece`)

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
