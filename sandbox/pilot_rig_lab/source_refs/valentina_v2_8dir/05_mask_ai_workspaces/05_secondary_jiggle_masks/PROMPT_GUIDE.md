# 05 — Máscara de Física Secundaria Torso (`secondary_jiggle_masks`)

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
