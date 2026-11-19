# Valentina v2 — Workspaces de Máscaras en Bloques para IA (`05_mask_ai_workspaces`)

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
