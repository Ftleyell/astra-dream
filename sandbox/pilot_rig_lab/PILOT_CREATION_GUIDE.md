# Guía Operativa Multi-Piloto — Astra Dream (`PilotRigLab v6`)

> **Propósito:** Guía paso a paso para generar nuevas pilotos (concepto maestro, hoja de piezas separadas, Upscayl 4x, mapa semántico Clown-Pass y calibración en Godot `PilotRigLab`), diseñada para retomar la producción en cualquier sesión futura en minutos.

---

## 📁 Estructura del Laboratorio (`res://sandbox/pilot_rig_lab/`)

```text
sandbox/pilot_rig_lab/
├── pilot_rig_lab.tscn                <- Escena principal del Studio Visual Identity & Multi-Rig
├── pilot_rig_lab.gd                  <- Orquestador del Lab (Multi-Piloto, Perfiles, A/B, In-Game PIP, FK 2D)
├── pilot_rig_stylizer.gdshader       <- Shader unificado: 5 Métodos Recolor, 6 Patrones, Lab Pelo, Física UV, Rayos-X
├── saved_style_profiles.json         <- Perfiles visuales personalizados guardados desde la UI (★ [Guardado])
├── rig_offsets_saved.json            <- Calibración fina de offsets manuales para la piloto base (Valentina)
├── source_refs/                      <- Imágenes fuente canónicas por piloto (<id>_step1/2/3.*)
│   ├── valentina_step1_master_9x16.jpg
│   ├── valentina_step2_parts_16x9.jpg
│   └── valentina_step3_clown_pass_16x9.jpg
├── tools/
│   └── build_pilot_rig_pipeline.py   <- Pipeline Python automatizado (Upscayl 4x + EDT + Clown-Pass Masks)
├── assets/                           <- Rig compilado de Valentina (Piloto Base por defecto)
└── pilots/                           <- Rigs compilados de pilotos adicionales (ej. pilots/kaelen/)
    └── .gdignore                     <- Mantiene sandbox fuera del export final hasta promoción a producción
```

---

## 🚀 Workflow Canónico de 4 Pasos para Crear una Nueva Piloto

Supongamos que vas a diseñar a una nueva piloto con ID `kaelen`:

### Paso 1 — Concepto Maestro Vertical (`--ar 9:16` en Google Pics / Gemini)
Generar primero la ilustración completa en **formato vertical 9:16** (evita que la IA aplaste las piernas y maximiza la resolución de rostro y armadura). **Sin alas** en la lámina base si van a generarse aparte como energía holográfica.

**Plantilla de Prompt Paso 1 (`9:16`):**
```text
Vertical 9:16 full body character sheet illustration of [NOMBRE Y DESCRIPCIÓN DE PILOTO], 90s sci-fi anime cel-shaded style inspired by Studio Trigger and Skullgirls, crisp uniform bold black ink lineart (#080812), flat posterized cel-shaded shadows with clean specular highlights, standing heroic idle pose facing 3/4 front, isolated on a completely flat solid chroma key green background (#4EB347), zero floor shadow, zero particles, zero UI text, --ar 9:16
```
- Guardar resultado en: `sandbox/pilot_rig_lab/source_refs/kaelen_step1_master_9x16.jpg`

---

### Paso 2 — Hoja de 6 Piezas Separadas (`--ar 16:9` en 3 Zonas Limpias)
Pasar la imagen del **Paso 1** como referencia visual en Google Pics para extraer **únicamente las 6 piezas modulares** organizadas en 3 columnas limpias (nunca incluir cuerpo completo repetido en la lámina):

**Plantilla de Prompt Paso 2 (`16:9` 3-Zonas):**
```text
Using the attached character design as exact style, lineart, proportion, and color reference, create a clean 16:9 2D skeletal animation parts sheet (paper-doll breakdown) on a completely flat solid chroma key green background (#4EB347). Draw ONLY 6 cleanly separated modular parts arranged in 3 distinct columns with generous green empty margin between every piece and ZERO overlapping:
- LEFT COLUMN: Top = detached head and neck collar; Bottom = detached torso and hips leotard/bodysuit cut cleanly at the waist/groin (no arms, no head, no legs).
- CENTER COLUMN: Full legs with hips and upper thighs from waist cut down to boots/heels cleanly connected together as one piece.
- RIGHT COLUMN: Top-left = right arm (bent pose); Top-right = left arm (relaxed pose); Bottom = detached back cape/coat isolated on its own.
Strict 100% consistent black ink lineart and flat cel shading. ZERO full body character duplicate, ZERO detached bust piece, ZERO text labels, ZERO grid lines.
```
- Guardar resultado en: `sandbox/pilot_rig_lab/source_refs/kaelen_step2_parts_16x9.jpg`

---

### Paso 3 — Mapa Semántico de Materiales / "Clown Pass" (`--ar 16:9`)
Pasar la hoja del **Paso 2** como referencia exacta en Google Pics para generar la máscara plana sin sombras (`Clown Pass`). Este mapa separa quirúrgicamente piel, medias translúcidas, pelo, armadura, tela y acentos incluso cuando comparten luminancia en el dibujo original.

**Plantilla de Prompt Paso 3 (`Clown Pass` 6 Colores Exactos):**
```text
Use the attached 16:9 character parts sheet as a 100% exact pixel-aligned silhouette and layout template. Convert EVERY part in the exact same position, scale, and outline into a flat unshaded semantic Material Color-ID Mask ("Clown Pass") for game shaders, preserving the crisp thin black ink outer lines on a completely pure SOLID WHITE background (#FFFFFF). ZERO gradients, ZERO cel-shading, ZERO highlights, ONLY 6 pure flat RGB colors inside the regions:
1. PURE YELLOW (#FFFF00): ALL bare exposed skin (face, neck skin, chest cleavage, bare upper thighs/hips above stockings).
2. PURE LIME GREEN (#00FF00): ALL sheer/translucent nylon stockings or legwear covering the thighs and knees (above the boots and below the bare upper thigh).
3. PURE CYAN (#00FFFF): ALL hair strands on the head.
4. PURE RED (#FF0000): ALL glowing visor/monocle/eyepiece, crimson/neon trim strips, straps, and energy seams on torso, arms, and knees.
5. PURE ROYAL BLUE (#0044FF): ALL metallic armor plates, pauldrons, armored gauntlets, shin guards, boots, and metal chest/belly panels.
6. PURE MAGENTA (#FF00FF): ALL dark matte suit fabric, neck collar, leotard undersuit, belt/garter bands, and the entire detached cape.
```
- Guardar resultado en: `sandbox/pilot_rig_lab/source_refs/kaelen_step3_clown_pass_16x9.jpg`

---

### Paso 4 — Compilar Assets + Upscayl 4x + Máscaras EDT en Python
Ejecutar el pipeline unificado (usa GPU vía `C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe` con modelo `digital-art-4x`):

```powershell
python sandbox/pilot_rig_lab/tools/build_pilot_rig_pipeline.py --pilot kaelen
```

**Qué realiza automáticamente:**
1. Recorta las 6 componentes conexas principales (descartando fragmentos vecinos invasores).
2. Escala cada pieza 4x con `digital-art-4x`.
3. Ejecuta **Euclidean Distance Transform (EDT)** para recortar `2.2px` del halo de transición verde, elimina cualquier exceso del canal verde (`G = min(G, max(R,B))`) y fija el borde exterior de la silueta a tinta `#080812` (**0 píxeles verdes residuales**).
4. Alinea por IoU cada pieza del `Clown Pass` y hornea `<part>_id_mask.png` (`R=Acentos`, `G=Armadura`, `B=Traje/Capa`, `A=Pelo en head | Medias en hips_legs`, `0=Piel/Tinta`).
5. Emite `reference_full.png` y `auto_matches.json` dentro de `sandbox/pilot_rig_lab/pilots/kaelen/`.

---

## 🎨 Guía de Calibración en el Estudio (`PilotRigLab v6`)

Abrir la escena interactiva directamente:
```powershell
& "C:/Users/Frani/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" --path "c:/Users/Frani/.gemini/antigravity/scratch/astra_dream" "res://sandbox/pilot_rig_lab/pilot_rig_lab.tscn"
```

1. **Seleccionar Piloto (`Sección 0`):** Elegir entre `Valentina` y cualquier piloto nueva generada en `sandbox/pilot_rig_lab/pilots/`.
2. **Alinear Piezas con Calco Fantasma:** Activar **`👻 Calco 9:16`** en la barra superior (`LAB TOOLS`) → proyecta la referencia maestra semitransparente en cian **por encima** del personaje. Abrir `Sección 5 -> ⚙️ Ajustar Física Idle y Posición de Piezas`, activar `Arrastre Manual`, ajustar offsets y pulsar **`💾 Guardar Offsets`**.
3. **Explorar Balance de Estilo:**
   - Usar **`⬜ Blanco Puro (#FFFFFF)`**, **`🩶 Gris Estudio`** o **`⬛ Abismo #080812`** arriba para validar limpieza de siluetas y bordes.
   - Fijar un estilo candidato con **`📌 Fijar Estilo A`** y activar **`👥 Lado a Lado (A vs B)`** para comparar variantes sin perder la referencia.
   - Probar lectura de combate con **`🎮 Escala In-Game + Balas`**.
   - Auditar umbrales de máscara y tinta con **`🔬 Rayos-X`** (`Clown-Pass ID` / `Luminancia` / `Solo Tinta`).
4. **Guardar Identidad Visual Ganadora:** En `Sección 1`, escribir un nombre y pulsar **`➕ Guardar Nuevo`**. Los ajustes exactos quedan persistidos en `sandbox/pilot_rig_lab/saved_style_profiles.json` listos para trasladar sus `uniform` al shader de producción cuando se cierre la etapa I+D.
