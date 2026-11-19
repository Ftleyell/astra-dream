# Fase C — Prompts para Máscara ILM / Control Artístico (`*_ilm_mask.png`)

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
C:\Python314\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind ilm
```
