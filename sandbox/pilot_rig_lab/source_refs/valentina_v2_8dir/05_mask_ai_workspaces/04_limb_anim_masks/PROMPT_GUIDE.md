# 04 — Máscara de Segmentos de Extremidades (`limb_anim_masks`)

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
