# Paquetes de Referencias y Prompts para Google AI

## Paso 2 — Cabezas Base 3 Ángulos (`valentina_heads_3angles.jpg`)
- **Carpeta:** `sandbox/pilot_rig_lab/reference_templates/02_SUBIR_PARA_CABEZAS/`
- **Imágenes a adjuntar:**
  1. `1_base_sockets_cuello.png`
  2. `2_ref_valentina_frente.jpg`
  3. *(Opcional solo si tu herramienta pide máscara inpaint)* `3_opcional_mascara_inpaint.png`
- **Guardar salida en:** `sandbox/pilot_rig_lab/source_refs/valentina_heads_3angles.jpg` (o `.png`)
- **Prompt (`PROMPT_02_CABEZAS.txt`):**
```text
2D anime game character portrait turnaround on a flat solid neutral #808080 gray background.
Using 1_base_sockets_cuello.png as the exact alignment template (and 2_ref_valentina_frente.jpg for facial identity, silver-white hairstyle, and crimson targeting monocle), illustrate ONLY the missing heads seated inside the three upper flight-suit collar openings. Keep the dark armored high-neck flight-suit collars and shoulders from 1_base_sockets_cuello.png locked in place so each head connects seamlessly into its collar.
Left slot: symmetrical Front View portrait looking straight forward, tousled silver-white anime hair, round crimson targeting lens over her left eye (viewer's right).
Center slot: strict 90-degree Right Profile portrait looking straight right, clean jawline, side hair locks, crimson targeting lens edge visible.
Right slot: clean Back View head with tousled silver-white hair overlapping neatly over the dark high-neck rear armor collar rim.
Bold crisp #080812 dark ink outlines, clean 2-tone cel shading, completely flat #808080 gray background, no gradients, no text.
```

---

## Paso 3 — Cabezas Asimétricas 4 Ángulos (`valentina_heads_asym_4angles.jpg`)
- **Carpeta:** `sandbox/pilot_rig_lab/reference_templates/03_SUBIR_PARA_CABEZAS_ASIMETRICAS/`
- **Imágenes a adjuntar:**
  1. `1_ref_cabezas_actuales.jpg`
  2. `2_base_4slots_cuello_asimetrico.png`
  3. *(Opcional solo si tu herramienta pide máscara inpaint)* `3_opcional_mascara_inpaint.png`
- **Guardar salida en:** `sandbox/pilot_rig_lab/source_refs/valentina_heads_asym_4angles.jpg`
- **Compilar en el rig después de guardar:**
  `sandbox\pilot_rig_lab\tools\.venv\Scripts\python.exe sandbox/pilot_rig_lab/tools/build_planar_rig_pipeline.py --pilot valentina --view heads_asym`
- **Prompt (`PROMPT_03_CABEZAS_ASIMETRICAS.txt`):**
```text
2D anime mecha-pilot portrait character sheet (2x2 grid, 4 separate head portraits seated cleanly into high-neck flight-suit collars) on a completely flat solid neutral #808080 gray background.
Use 1_ref_cabezas_actuales.jpg ONLY for character face identity, asymmetrical tousled silver-white anime hair bangs, and her single round crimson targeting monocle over her anatomical LEFT eye ONLY (her RIGHT eye is natural amber/gold with NO monocle). Use 2_base_4slots_cuello_asimetrico.png as the EXACT 2x2 collar socket layout: keep the four dark armored high-neck collars locked in their exact coordinates and paint ONLY the 4 missing heads emerging cleanly from each collar opening.
STRICT ASYMMETRY PER QUADRANT (do NOT duplicate or mirror the monocle across sides):
- TOP-LEFT quadrant (head_side_l): strict 90-degree LEFT SIDE PROFILE facing straight LEFT. Because her anatomical left cheek faces the viewer, the round crimson targeting monocle over her left eye IS CLEARLY VISIBLE, plus asymmetrical forward silver-white hair locks.
- TOP-RIGHT quadrant (head_side_r): strict 90-degree RIGHT SIDE PROFILE facing straight RIGHT. Because her anatomical right cheek faces the viewer, NO crimson monocle is visible (only her uncovered natural right eye, clean jawline, and windswept silver-white hair).
- BOTTOM-LEFT quadrant (head_back_l): three-quarter OVER-THE-LEFT-SHOULDER BACK-LEFT view looking away and toward the LEFT. Show the back of her silver-white hair overlapping the rear collar rim plus her left profile cheek and the round crimson monocle edge over her left eye.
- BOTTOM-RIGHT quadrant (head_back_r): three-quarter OVER-THE-RIGHT-SHOULDER BACK-RIGHT view looking away and toward the RIGHT. Show the back of her silver-white hair overlapping the rear collar rim plus her right profile cheek and natural uncovered right eye (NO monocle).
Bold crisp #080812 dark ink outlines, clean 2-tone anime cel shading matching 1_ref_cabezas_actuales.jpg, completely flat #808080 gray background, no grid divider lines, no labels, no text, no watermarks.
```
