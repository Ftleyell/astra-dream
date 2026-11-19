# Fase B — Prompts para Normales 2.5D + Profundidad (`*_normal_depth.png`)

## Carpetas de trabajo
- **Entradas limpias (subir al generador):** `inputs_normal/` (fondo neutro `#8080FF` para evitar halos blancos en normales)
- **Dónde guardar tus resultados:** `outputs_normal/` *(con el **mismo nombre de archivo** que en `inputs_normal/`)*

## Reglas clave para Normales Anime (sin "efecto plastilina")
- El fondo debe permanecer **`#8080FF`** (normal neutra `(0, 0, +1)` apuntando directo a cámara).
- **Convención Tangent-Space OpenGL/Godot:**
  - Superficie mirando hacia la **DERECHA** (`+X`) → **Rosa / Rojo cálido** (`#FF8080`)
  - Superficie mirando hacia la **IZQUIERDA** (`-X`) → **Cian / Azul verdoso** (`#0080FF`)
  - Superficie mirando hacia **ARRIBA** (`-Y` en pantalla) → **Verde brillante** (`#80FF80`)
  - Superficie mirando hacia **ABAJO** (`+Y` en pantalla) → **Violeta / Magenta oscuro** (`#8000FF`)
  - Superficie **PLANA hacia cámara** (`+Z`) → **Lavanda neutro** (`#8080FF`)
- **IMPORTANTE:** Al ingerir (`--kind normal`), Python normaliza matemáticamente cada píxel (`normalize(N)`), recorta al alpha exacto de la pieza, sintetiza profundidad en el canal Alfa e **invierte automáticamente `Nx` (`R' = 255 - R`) al espejar `SW, W, NW`**.

---

## Prompt Universal — Hojas de Cuerpo (`01_body_core`, `02a/b_legs`, `03_arms`, `04_pauldrons` en **`16:9`**)
```text
Convert this exact multi-piece anime character sheet into a clean, stylized tangent-space 3D normal map on a flat #8080FF neutral periwinkle background. Preserve the exact grid layout, piece count, spacing, and outer silhouettes with zero shifting or cropping.

CRITICAL ANTI-OUTLINE & ANIME NORMAL RULES:
- DELETE 100% of black ink outlines, textures, colors, and painted shadows; output ONLY smooth tangent-space normal RGB colors.
- Treat each limb and torso as clean, sculptural anime cel-shading geometry (like Guilty Gear Strive / ArcSys): smooth rounded cylinders for thighs, shins, and arms; clean beveled planar facets for hard armor plates and pauldrons; smooth anatomical curves for chest/back torso.
- Avoid noisy bumpy "clay/plasticine" micro-details or fabric wrinkles — keep broad, clean, readable curvature gradients so cel-shading cuts cleanly!
- Standard tangent-space normal encoding:
  * Facing camera (+Z) = #8080FF lavender
  * Facing right (+X) = pinkish red (#FF8080)
  * Facing left (-X) = cyan-blue (#0080FF)
  * Facing up = green (#80FF80)
  * Facing down = violet-purple (#8000FF)
- Extend normal colors cleanly to the silhouette edge (zero black outlines, zero white halos).
```

---

## Prompt — Hojas de Cabezas (`05a_heads_front_2x2_1x1.png` y `05b_heads_back_2x2_1x1.png` en **`1:1`**)
```text
Convert this exact 2x2 anime head turnaround grid into a clean, stylized anime tangent-space normal map on a flat #8080FF neutral background. Preserve the exact 2x2 layout and silhouettes without shifting.

CRITICAL ANIME FACE NORMAL RULES (ArcSys / Guilty Gear style):
- DELETE 100% of black ink outlines, eye/mouth color details, and painted shading.
- Sculpt the FACE as a very smooth, simplified anime sphere/oval (minimal nose bump, NO heavy realistic eye sockets or bumpy cheeks) so directional cel-shading produces clean, flattering anime shadows across the face.
- Sculpt the HAIR bangs and locks as bold, clean directional ribbons/cylinders with crisp bevels between major hair clumps.
- Sculpt the neck collar as a clean vertical cylinder and the monocle lens as a flat forward-facing disc (#8080FF).
- Standard tangent-space RGB normal encoding (#8080FF flat, +X pink/red, -X cyan/blue, up green, down violet). Zero black lines, zero noise.
```

---

## Ingesta automática en Python
Cuando guardes tus hojas en `outputs_normal/`, ejecuta:
```powershell
C:\Python314\python.exe sandbox/pilot_rig_lab/tools/ingest_piece_mask_sheets.py --kind normal
```
