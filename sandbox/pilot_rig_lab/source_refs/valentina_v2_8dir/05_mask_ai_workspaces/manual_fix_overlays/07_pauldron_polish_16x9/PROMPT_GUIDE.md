# Guía de Pulido IA — 8 Hombreras Únicas (16:9)

Solo se exportan las **8 hombreras únicas** (las 8 restantes se generan automáticamente por espejado horizontal en Python):
- **Fila 1:** `S pauldron_r` (→ `S pauldron_l`), `SE pauldron_r` (→ `SW pauldron_l`), `SE pauldron_l` (→ `SW pauldron_r`), `E pauldron_r` (→ `W pauldron_l`)
- **Fila 2:** `N pauldron_r` (→ `N pauldron_l`), `NE pauldron_r` (→ `NW pauldron_l`), `NE pauldron_l` (→ `NW pauldron_r`), `E pauldron_l` (→ `W pauldron_r`)

## Archivo de entrada (`inputs/`)
- `01_pauldrons_unique_8_16x9.png` (2560x1440, 16:9)
- Referencia con nombres: `guide/01_pauldrons_unique_8_16x9_labeled.png`

## Prompt recomendado para el generador de imagen
> Clean up and complete these 8 isolated sci-fi anime armor shoulder pauldrons on a pure solid white `#FFFFFF` background. Preserve the exact position, size, perspective, silhouette, cel-shaded dark navy/blue/gold/crimson palette, and crisp dark ink outlines of each piece. Fix any cut edges, missing corners, blurry seams, or perspective artifacts so every pauldron looks like a complete, clean, production-ready 2D anime game asset. Do not move, resize, rotate, merge, or add text, labels, shadows, or grid lines.

## Siguiente paso (Upscayl + Python)
1. Pasa el resultado por **Upscayl** (`digital-art-4x`) y guárdalo en `upscayl_outputs/` (por ejemplo `01_pauldrons_unique_8_16x9.png`).
2. Avísame para ejecutar `ingest_pauldron_polish_16x9.py` (recorta, limpia bordes, espeja las 8 simétricas, regenera mapas y reaplica las 16 al rig + `pilot_rig_lab`).
