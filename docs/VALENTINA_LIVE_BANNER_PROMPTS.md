# Guía de Prompts IA — Live Banner HQ & Máscara ILM (`Valentina v2`)

> **Propósito:** Prompts listos para copiar y pegar en el generador de IA (Image-to-Image / Edit) para llevar el **Live Banner 2.5D** al mismo nivel visual que el Combat Rig (`02_valentina_razor_sharp`) y el Face Lab.
> **Referencia técnica:** [`VALENTINA_LIVE_BANNER_SPEC.md`](VALENTINA_LIVE_BANNER_SPEC.md)

---

## 0. Archivos de Entrada y Dónde Guardar los Resultados

- **Imagen de entrada (subir al generador):**
  `sandbox/pilot_rig_lab/banner_lab/refs/valentina_v2_splash_raw_master.jpg` *(o el nuevo `valentina_v2_splash_hq_master.png` una vez generado)*
- **Carpeta donde guardar los resultados:**
  `sandbox/pilot_rig_lab/banner_lab/refs/`
- **Aspect Ratio obligatorio en todas las pasadas:** **`9:16`** (vertical, sin recortar ni mover el encuadre).

| Prioridad | Archivo a guardar en `banner_lab/refs/` | Qué desbloquea |
|---|---|---|
| **1 (Clave)** | `valentina_v2_splash_hq_master.png` | Elimina borrosidad y artefactos JPG (`571×1024` → PNG HQ nítido en dedos, rostro, armadura y silueta). |
| **2 (Clave)** | `mask5_ilm_raw.png` | Paridad con `02_valentina_razor_sharp`: separa brillo metálico de hombreras/rodilleras, halo ángel en cabello, AO permanente bajo mentón/busto/hombreras y protección facial. |
| **3 (Opcional)** | `mask4_ink_hq_raw.png` | Solo si el Master HQ alteró micro-detalles respecto a `mask4_ink_raw.png` (asegura `ink_sdf 2×` 100% alineado). |
| **4 (Opcional)** | `mask6_normal_raw.png` | Normales 2.5D esculpidas con bordes duros en hombreras y relieve facial (superior al Sobel derivado de `depth`). |

> **Nota sobre los ojos:** **NO hace falta generar assets de ojos con IA.** En la integración vamos a reutilizar directamente `head_front_eye_iris.png` y `head_front_eye_closed.png` del Face Lab (`combat_assets/valentina_v2_planar/heads/`) con el shader Live2D de 3 capas.

---

## Prompt 1 — Master Splash HQ (`valentina_v2_splash_hq_master.png`)
*Subir: `valentina_v2_splash_raw_master.jpg` · Aspect Ratio: **`9:16`** · Formato de salida: **PNG***

```text
Remaster and upscale this exact anime sci-fi pilot full-body character illustration to ultra-sharp, studio-quality Arc System Works / high-budget anime game splash art resolution on a PURE #FFFFFF solid white background.

CRITICAL LOCK-IN RULES (STRICT):
- PRESERVE 100% of the exact pose, silhouette, proportions, framing, camera angle, limb positions, hair spikes, outfit design, and colors without shifting, zooming, cropping, or redesigning anything.
- Pure #FFFFFF solid white background with ZERO drop shadows, ZERO floor shadow, ZERO glow bleed, and ZERO gray haze around the character.
- Clean, razor-sharp, consistent dark anime ink linework (zero JPEG artifacts, zero blurry edges, zero painterly smudging).
- Crisp anime cel-shading: keep skin tones clean and luminous (face, neck, chest cutout, thighs), dark charcoal tactical undersuit matte and clean, rigid shoulder pauldrons and knee/shin armor plates sharp and structured, crimson trim lines crisp, and the round red left-eye monocle clean and glossy.
- Right eye (viewer's left): crisp anime eye with clean white sclera, sharp dark upper eyelash, and deep amethyst violet iris (#421D70 top -> #8B5CF6 mid -> #DFC4FF lower crescent) with a sharp dark vertical feline pupil (#100816).
- Refine fingers, facial expression (confident smirk), hair strands, and armor panel seams to crisp 2K+ vector-like clarity while keeping exact pixel alignment with the input silhouette.
```

---

## Prompt 2 — Máscara ILM de Materiales y AO (`mask5_ilm_raw.png`)
*Subir: `valentina_v2_splash_hq_master.png` (o `valentina_v2_splash_raw_master.jpg`) · Aspect Ratio: **`9:16`** · Formato: **PNG***
*(Usa exactamente el mismo código de 6 colores ortogonales del Combat Rig en `piece_mask_prompts.py`)*

```text
Convert this exact full-body anime character illustration into a flat, razor-sharp cel-shading ILM control zone mask on a pure #FFFFFF solid white background. Preserve the exact canvas dimensions, framing, proportions, and outer silhouette without shifting, resizing, or cropping.

CRITICAL ANTI-OUTLINE RULES:
- DELETE 100% of black ink linework, outer outlines, gradients, airbrushing, and painted shading.
- Fill every pixel strictly with flat solid pure hex blocks extending cleanly across where black outlines used to be (zero black, dark-gray, or antialiased muddy edge pixels).

ILM ZONE COLOR MAP (USE ONLY THESE EXACT FLAT HEX COLORS):
- #FF0000 Pure Neon Red (HARD SPECULAR METAL): rigid raised armor plates — shoulder pauldrons, armored forearm bracers, chest armor trim/plates, knee cap shields, and metallic shin/ankle guards.
- #00FFFF Pure Neon Cyan (SATIN / NYLON / HAIR ANGEL RING): the horizontal curved specular highlight band ("angel ring") across the upper crown of the silver hair, plus any glossy satin/nylon thigh cuff bands.
- #0000FF Pure Neon Blue (PERMANENT CEL SHADOW / AO): deep occlusion crevices ONLY — underside of the bust/chest, armpit folds under the pauldrons, deep neck shadow directly under the chin/jawline, and narrow shadow cast directly under the hair bangs on the forehead.
- #FFFF00 Pure Neon Yellow (PROTECTED SKIN / FACE): clean lit facial skin, cheeks, visible eye area, bare cleavage skin, and bare exposed thighs (protects skin from harsh dirty shadows).
- #00FF00 Pure Neon Green (MATTE SUIT & BASE HAIR): matte dark charcoal undersuit bodysuit, turtleneck collar, sleeves, gloves, dark boots, and the main silver hair volume outside the cyan angel ring.
- #FF00FF Pure Neon Magenta (EMISSIVE GLOW): the round red left-eye monocle lens and all thin glowing crimson/red suit trim strips.
- #FFFFFF Pure Solid White: empty background only.
```

---

## Prompt 3 (Opcional) — Clean-Up Ink Lineart HQ (`mask4_ink_hq_raw.png`)
*Usar solo si el Master HQ cambió trazos finos respecto a `mask4_ink_raw.png` · Subir: `valentina_v2_splash_hq_master.png` · Aspect Ratio: **`9:16`***

```text
Convert this exact full-body anime character illustration into ultra-crisp, studio-quality Japanese anime clean-up line art (douga / genga ink pass) using ONLY pure #000000 black ink lines on a pure #FFFFFF solid white background. Preserve the exact canvas dimensions, alignment, proportions, and outer silhouette without shifting, resizing, or cropping.

CRITICAL LINE-ART ONLY RULES (STRICT):
- USE ONLY TWO COLORS: #000000 pure black for ink strokes and #FFFFFF pure white for everything else.
- DO NOT FILL dark areas with solid black! The dark charcoal bodysuit, dark gloves, dark boots, turtleneck collar, and eye iris MUST remain pure #FFFFFF white inside, defined ONLY by crisp black ink contours (solid black allowed only on thin upper eyelashes).
- DELETE 100% of color, gray shading, cast shadows, gradients, highlights, and screentones.
- Keep line weight razor-sharp, smooth, continuous, and studio-clean (zero blurry lines, zero sketchy double-strokes).
- Trace every outer silhouette contour, armor plate seam (pauldrons, bracers, knees, shins, boots), suit panel seams, hair strand divisions, monocle rim, facial features, and finger contours cleanly.
- Pure #FFFFFF solid white background with zero gray dust or halos.
```

---

## Prompt 4 (Opcional) — Normal Map 2.5D Tangent-Space (`mask6_normal_raw.png`)
*Subir: `valentina_v2_splash_hq_master.png` · Aspect Ratio: **`9:16`***

```text
Convert this exact full-body anime character illustration into a clean, stylized OpenGL tangent-space Normal Map on a solid flat #8080FF neutral lavender-blue background. Preserve the exact silhouette, proportions, and alignment without shifting or cropping.

CRITICAL NORMAL MAP RULES:
- Background MUST remain flat solid #8080FF (pointing straight toward camera, Z=+1).
- DELETE 100% of black outlines, color textures, and painted shadows.
- Use clean, sculpted anime cel-shading geometry (NO noisy bumpy plastic texture):
  - Surfaces facing RIGHT (+X) -> warm Pink/Red (#FF8080)
  - Surfaces facing LEFT (-X) -> Cyan/Teal (#0080FF)
  - Surfaces facing UP (-Y) -> bright Green (#80FF80)
  - Surfaces facing DOWN (+Y) -> deep Violet/Blue (#8000FF)
  - Flat camera-facing planes (+Z) -> neutral Lavender (#8080FF)
- Keep the face smooth and gently domed (soft anime cheek/nose plane, no harsh ridges).
- Keep shoulder pauldrons, forearm bracers, knee shields, and shin armor with crisp faceted bevels.
- Keep hair locks cleanly beveled per strand.
```

---

## Checklist Rápido Antes de Guardar en `banner_lab/refs/`
1. **Alineación:** Superponiendo mentalmente el Master HQ y `mask5_ilm_raw.png`, la silueta debe coincidir al píxel (sin zoom ni desplazamiento).
2. **ILM sin bordes negros:** En `mask5_ilm_raw.png` no debe quedar ningún contorno negro ni gris entre colores neón, y el fondo debe ser `#FFFFFF` puro.
3. **Ink sin rellenos:** Si generás `mask4_ink_hq_raw.png`, el interior del traje oscuro y botas debe estar **blanco puro** (`#FFFFFF`), solo las líneas en `#000000`.
4. Una vez guardados en `sandbox/pilot_rig_lab/banner_lab/refs/`, avisame y actualizamos `build_valentina_live_banner.py`, el Ojo Live2D 3-capas y `pilot_live_banner.gdshader` en una sola pasada.
