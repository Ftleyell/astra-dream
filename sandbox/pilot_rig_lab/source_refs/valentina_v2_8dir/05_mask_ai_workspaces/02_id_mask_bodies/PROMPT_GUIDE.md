# 02 — Máscara de Materiales / ID de Cuerpos (`id_mask_bodies`)

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
