# 03 — Máscara de Materiales / ID de Cabezas Hi-Res (`id_mask_heads`)

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
