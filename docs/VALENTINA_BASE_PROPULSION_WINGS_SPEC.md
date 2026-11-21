# Guía Maestra y Estándar Multi-Piloto — Alas Psíquicas & Propulsión Base Zero-G

> **Estado:** **Estandarizado y verificado en `PilotRigLab`** (`test_valentina_vfx_lab.tscn`, `test_pilot_rig_lab.tscn` y `test_valentina_face_lab.tscn`).
> **Implementación de Referencia:** **Valentina v2 — *Astral Seraph* (Opción C, Rojo Carmesí + Plata Hielo)**.
> **Complemento Power-Up:** [`docs/VALENTINA_PROPULSION_VFX_SPEC.md`](VALENTINA_PROPULSION_VFX_SPEC.md) (*Sandevistan Astral*).
> **Referencia del Rig 8-Dir:** [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) · **Reglas del Lab:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md)

---

## 1. Arquitectura Estándar Multi-Piloto (Data-Driven)

El sistema de alas está completamente desacoplado e integrado de forma **opt-in** en `PlanarCombatRig` (`enable_base_propulsion_wings = true`, igual que `enable_face_live`). Cualquier piloto nuevo obtiene alas funcionales, recolor de skins, cel-shading 2.5D, cintas y luz HDR sin duplicar código.

```text
PilotRigProfile (.tres)
 ├── assets_root + "/" + wings_assets_subdir ──► wings_metadata.json (schema v2) + 8×6×5 PNGs
 └── base_propulsion_config (.tres) ───────────► PilotBasePropulsionConfig
                                                       │
PlanarCombatRig (enable_base_propulsion_wings = true)  ▼
 ├── BasePropulsionWings (ValentinaBasePropulsionController, z_index = -2)
 │    ├── Capa 2: 12 Cintas Sólidas (Line2D en mundo desde clean_tip_world)
 │    └── Capa 3: Polvo Estelar (_draw(), pool prealocado 4-puntas)
 ├── WingsGlowUnder (Node2D, z_index = -1) ──► 6+6 Sprite2D aditivos HDR (wing_red_glow.gdshader)
 ├── UnifiedCharacterGroup (CanvasGroup, z_index = 0)  [Invariante: hijos siempre z_index = 0]
 │    ├── WingsUnderMount (z_index = 0)  ◄── alas detrás del cuerpo (s, se, sw, ala lejana e/w)
 │    ├── DecoupledHeadUnderMount
 │    ├── BodyPivot (BodyView_*)
 │    ├── WingsOverMount (z_index = 0)   ◄── alas sobre espalda bajo cabeza (n, ne, nw, ala cercana e/w)
 │    └── DecoupledHeadMount
 └── WingsGlowOver (Node2D, z_index = 1)  ──► glow HDR de las alas sobre espalda
```

### Inventario de Archivos del Sistema

| Componente | Archivo | Rol |
|---|---|---|
| **Perfil de Piloto** | [`sandbox/pilot_rig_lab/data/pilot_rig_profile.gd`](../sandbox/pilot_rig_lab/data/pilot_rig_profile.gd) | Expone `base_propulsion_config` y `wings_assets_subdir` (`"wings"`). |
| **Esquema Data-Driven** | [`sandbox/pilot_rig_lab/data/pilot_base_propulsion_config.gd`](../sandbox/pilot_rig_lab/data/pilot_base_propulsion_config.gd) | Recurso `PilotBasePropulsionConfig` (escala, flotación, onda psíquica, empuje Newtoniano, glow HDR, cintas y polvo estelar). |
| **Preset Calibrado** | [`sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_base_propulsion.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_base_propulsion.tres) | Preset aprobado para Valentina v2 (`wing_scale = 1.60`, `wing_root_spread_x_du = 68.0`, `thrust_linear_slide_du = 22.0`). |
| **Controlador Runtime** | [`sandbox/pilot_rig_lab/vfx_lab/valentina_base_propulsion_controller.gd`](../sandbox/pilot_rig_lab/vfx_lab/valentina_base_propulsion_controller.gd) | Carga dinámica por perfil, enrutado 8-dir desde 3 vistas canónicas, animación por cuchilla, empuje Newtoniano, glow HDR, cintas y polvo estelar. |
| **Shader Glow HDR** | [`sandbox/pilot_rig_lab/vfx_lab/wing_red_glow.gdshader`](../sandbox/pilot_rig_lab/vfx_lab/wing_red_glow.gdshader) | Capa `blend_add` fuera de `CanvasGroup` guiada por `ilm_mask.A` para emitir luz real bajo Bloom + `AgX`. |
| **Integración en Rig** | [`sandbox/pilot_rig_lab/proto/planar_combat_rig.gd`](../sandbox/pilot_rig_lab/proto/planar_combat_rig.gd) | Monta `BasePropulsionWings`, sincroniza materiales al cambiar skins/estilos y alimenta velocidad en `_process`. |
| **Compilador Offline** | [`sandbox/pilot_rig_lab/tools/build_valentina_v2_wings.py`](../sandbox/pilot_rig_lab/tools/build_valentina_v2_wings.py) | Upscayl `4×`, separación por cuchilla (`6` por ala), extracción de 5 mapas, espejado `Nx=-Nx` y `wings_metadata.json` (`v2`). |
| **Laboratorios & Tests** | [`valentina_vfx_lab.tscn`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn) · [`planar_combat_rig_proto.tscn`](../sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn) · [`test_valentina_vfx_lab.gd`](../tests/sandbox/test_valentina_vfx_lab.gd) | Calibración interactiva con guardado directo a `.tres`, preview con skins/estilos y verificación automática. |

> **Nota sobre calibración de escala en pantalla:** Como `PlanarCombatRig` aplica `display_scale` (`0.378`) y en `valentina_vfx_lab` el controlador es hermano del rig (`scale = 1.0`) mientras que integrado en `PlanarCombatRig` es hijo (`global_scale = 0.378`), `ValentinaBasePropulsionController` compensa automáticamente `Line2D.width` y tamaño de estrellas mediante `_get_world_draw_inv_scale()` para que ambos contextos luzcan 100% idénticos.

---

## 2. Guía Reutilizable: Cómo Crear Alas para un Nuevo Personaje

### 2.1 Diseño y Prompt Maestro Optimizado (Gemini `16:9`)

Para que el arte base sea compatible con el pipeline completo de máscaras y los **10 skins**, **NO** generes PNGs con fondo negro, silueta humana ni bloom borroso. Respeta estas **5 reglas de producción**:

1. **Fondo gris medio plano `#808080`:** No se confunde ni con la tinta oscura *ArcSys* ni con placas blancas/plata, y evita contaminación cromática en los bordes.
2. **Cero glow/bloom externo ni alfa semitransparente:** Contornos 100% opacos y cerrados. El resplandor real lo añade el motor vía `ilm_mask.A` + `wing_red_glow.gdshader`.
3. **Separación cel-shaded estricta (2 materiales):**
   - Material principal (ej. cristal plata `#DDE4EE..#FFFFFF` + sombras `#A6B4C8`) → `id_mask.G` (`panel_color`).
   - Material acento/emisivo (ej. núcleo/puntas rubí `#D91E48..#FF335C`) → `id_mask.R` (`accent_color`) + `ilm_mask.A`.
4. **Cero anclaje central / diamante:** Las cuchillas flotan mágicamente alrededor del piloto sin piezas centrales que estorben ni se solapen.
5. **Solo 3 vistas canónicas (`0°`, `45°`, `90°`) para cubrir las 8 direcciones:**
   - **Columna Izquierda (`0°`):** **Únicamente 1 ala derecha grande** (doble resolución + simetría matemática al espejar).
   - **Columna Central (`45°`):** Ala lejana + ala cercana separadas por un hueco limpio `#808080`.
   - **Columna Derecha (`90°`):** Ala única en perfil puro barrida hacia atrás (`-X`).

#### Plantilla de Prompt Maestro (Adaptable a cualquier piloto)
*(Adjunta la imagen de concepto aprobada del personaje como referencia y sustituye lo indicado entre `[...]`)*:

```text
Using the attached reference image ONLY for the exact wing silhouette, [N]-shard layout, crystal/mechanical faceting, and anime style, generate a clean 2D game-rig production asset sheet (16:9 landscape) on a completely flat, uniform neutral medium-grey (#808080) background.

PRODUCTION PIPELINE CONSTRAINTS (CRITICAL):
- Background MUST be 100% flat uniform medium grey (#808080) with ZERO gradients, ZERO vignette, ZERO shadows cast on the background.
- NO human body, NO pilot silhouette, NO central diamond/backpack, NO text, NO labels, NO grid lines, NO floating sparkles or dust dots.
- ZERO outer glow, ZERO bloom, ZERO soft fog, ZERO transparency/translucent bleed into the grey background. Every blade/feather shard must be 100% solid opaque with a closed, crisp dark ink outline so it can be cleanly alpha-cut and converted to SDF lineart.
- HARD CEL-SHADED MATERIAL SEPARATION (for automated ID mask extraction): strictly two clean material colors with razor-sharp boundaries:
  1) [BASE MATERIAL: e.g. Faceted cool silver-white crystal plates #DDE4EE to #FFFFFF, shadow facets #A6B4C8].
  2) [ACCENT EMISSIVE MATERIAL: e.g. Saturated crimson-ruby inner veins and tips #D91E48 to #FF335C].
- Art style: Arc System Works / Guilty Gear 2D anime game sprite, ultra-crisp vector-clean internal facet lineart, consistent top-left directional lighting.
- Keep generous flat #808080 grey padding between every wing piece and between every individual floating shard (no shards touching each other).

3 HORIZONTAL COLUMNS (same vertical scale across all 3 columns):
1. LEFT COLUMN (0° Flat Orthographic — SINGLE RIGHT WING): Draw ONLY ONE large right-side wing (all [N] detached shards fanning up-right and down-right) at maximum clean scale.
2. CENTER COLUMN (45° Three-Quarter View facing right — FAR & NEAR WINGS): Both wings in 3/4 perspective swept slightly backward: far wing (left) slightly wider/open, near wing (right) foreshortened toward camera, separated by a clean empty #808080 grey gap in the middle.
3. RIGHT COLUMN (90° Pure Side Profile facing right — SINGLE PROFILE WING): One single wing in pure side profile swept backward to the left, showing clean 3D foreshortening and layered depth of the [N] detached shards.
```

---

### 2.2 Compilación Offline Python (`build_valentina_v2_wings.py`)

Guarda la hoja generada en `sandbox/pilot_rig_lab/source_refs/<pilot>_wings/<pilot>_wings_3views.png` y ejecuta:

```powershell
C:\Python314\python.exe sandbox/pilot_rig_lab/tools/build_valentina_v2_wings.py `
  --sheet sandbox/pilot_rig_lab/source_refs/<pilot>_wings/<pilot>_wings_3views.png `
  --out-dir sandbox/pilot_rig_lab/combat_assets/<pilot>_planar/wings `
  --audit sandbox/pilot_rig_lab/source_refs/<pilot>_wings/audit_wings_shards.png
```

**Qué automatiza el compilador:**
1. **Super-Resolución y Limpieza:** Ejecuta **Upscayl `digital-art-4x`** (`~4096 px`) para eliminar artefactos de compresión y refinar el lineart interno, luego recorta el alfa por flood-fill desde el borde `#808080` y aplica **Voronoi RGB bleed** en alfa 0.
2. **Despiece Automático por Cuchilla:** Segmenta cada una de las 4 alas canónicas (`wing_0deg_r`, `wing_45deg_far`, `wing_45deg_near`, `wing_90deg`) en sus **`6` cuchillas independientes (`s0..s5`)**, usando erosión morfológica + Voronoi como respaldo si alguna vista en escorzo (`45deg_near`) toca levemente en la raíz.
3. **5 Mapas Estándar por Cuchilla (idénticos al cuerpo del piloto):**
   - `<piece>.png`: Albedo sRGB a escala nativa `tex_scale = 3` (`TARGET_WING_HEIGHT_PX = 720`).
   - `<piece>_id_mask.png`: `R = 255` acento emisivo, `G = 255` material base, `B/A = 0` (`0%` piel).
   - `<piece>_ilm_mask.png`: `R` especular, `G` AO en biseles, `B` peso rim-light, `A` **emisivo puro** para Bloom/glow.
   - `<piece>_normal_depth.png`: Normales tangentes facetadas por bisel + profundidad `A ∈ [80..239]`.
   - `<piece>_ink_sdf.png`: Campo de distancia con signo a resolución **`2×`** (`±8.0` texels nativos, **cargar siempre sin mipmaps**).
4. **Espejado Exacto y Metadatos `v2`:** Genera las 4 alas espejo (`wing_0deg_l`, `wing_45deg_far_flip`, `wing_45deg_near_flip`, `wing_90deg_flip`) invirtiendo el canal `Nx` de las normales (`255 - Nx`) y escribe `wings_metadata.json` (`pivot_px`, `tip_offset_px`, `rest_offset_px`, `length_norm`, y tabla `views` de 8 direcciones).

**Checklist al revisar `audit_wings_shards.png`:**
- Verifica que `wing_0deg_r`, `wing_45deg_far` y `wing_90deg` tengan **6** cuchillas (`s0..s5`) ordenadas de arriba hacia abajo (`s0` = pluma superior más larga), puntos verdes en raíz interna y rombos naranjas/cian en las puntas exteriores.

---

### 2.3 Enlace Data-Driven al Rig de un Nuevo Piloto

1. Duplica [`valentina_v2_base_propulsion.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_base_propulsion.tres) en `sandbox/pilot_rig_lab/pilots/<pilot>/<pilot>_base_propulsion.tres` y ajusta su escala, paleta de glow y cintas.
2. En el `PilotRigProfile` del piloto (`<pilot>_profile.tres`), asigna:
   - `assets_root = "res://sandbox/pilot_rig_lab/combat_assets/<pilot>_planar"`
   - `wings_assets_subdir = "wings"`
   - `base_propulsion_config = <pilot>_base_propulsion.tres`
3. Activa `rig.enable_base_propulsion_wings = true` (o `set_base_propulsion_wings_enabled(true)`) en la escena o arena correspondiente.

---

## 3. Mecánica de Animación y Decisiones de Pulido (v1 → v4)

| Aspecto | Comportamiento Calibrado Final | Por qué se diseñó así |
|---|---|---|
| **Enrutado 8-Dir & Z-Order** | `s, se, sw` → `WingsUnderMount`; `n, ne, nw` → `WingsOverMount` (sobre espalda, debajo de cabeza); `e, w` → ala trasera en `Under` (`0.86×` escala, `0.78×` brillo) y cercana en `Over`. | Evita que las alas se atraviesen entre sí o pasen detrás de una espalda ya dibujada en vistas dorsales y perfiles, conservando `z_index = 0` dentro del `CanvasGroup`. |
| **Apertura Lineal Cohesiva (`s0` intocable)** | Rotación de pivote principal fijada a `0.0°`. La pluma superior `s0` (`blade_t = 0.0`) **nunca rota**; se desliza en línea recta por su eje alejándose/acercándose. Las secundarias `s1..s5` acompañan el deslizamiento lineal y abren un abanico suave hacia abajo/afuera (`blade_fan_spread_deg = 8.0°`). | Rotar el ala como bisagra circular levantaba `s0` verticalmente a 90°, rompiendo la silueta aerodinámica y provocando cruces en tijera al frenar. |
| **Flotación Orbital** | Anillo amplio (`wing_root_spread_x_du = 68.0`, sin diamante de anclaje) + deslizamiento por esfuerzo (`+22.0 du`) y aerofreno en paralelo (`+28.0 du`), suavizado exponencial `1 - exp(-11 * delta)`. | Las cuchillas flotan mágicamente alrededor del torso en todos los ángulos sin tapar el diseño de Valentina ni saltar bruscamente en cambios de dirección. |
| **Empuje Newtoniano Asimétrico** | Moverse/acelerar a `+X` dispara el esfuerzo del ala izquierda (`_effort_l`) y viceversa (`-X` → `_effort_r`); acelerar recto, turbo o frenar brusco dispara ambas al `100%`. | Da lectura física inmediata de propulsión direccional: el ala que empuja se desliza más afuera, vibra sutilmente (`0.9 du` normalizado por `1/wing_scale`), enciende rim carmesí y multiplica su glow HDR. |
| **Luz Roja HDR Real** | `WingsGlowUnder` (`z = -1`) y `WingsGlowOver` (`z = 1`) fuera de `UnifiedCharacterGroup`, sincronizados por `global_transform` y guiados por `ilm_mask.A`. | El `CanvasGroup` recorta colores a LDR `0..1`; sacar la capa aditiva permite disparar el Bloom real en esfuerzo (`1.65`) y frenado (`2.35`). |
| **12 Cintas Sólidas (Sin Zigzag)** | 1 cinta por punta (2 primarias largas arriba + 4 secundarias finas abajo), color rojo sólido `#EB0D2E` semitransparente (`0.66`), nacidas de `clean_tip_world` (sin vibración) y con corte automático ante saltos `> 90 px`. | Elimina vibración en zigzag, evita la línea recta que cruzaba el cuerpo al cambiar de vista 8-dir y quita el núcleo blanco causado por sobreexposición HDR bajo `AgX`. |

---

## 4. Referencia de Parámetros (`PilotBasePropulsionConfig`)

* **Escala y Órbita:** `wing_scale` (`1.60`), `idle_scale_factor` (`0.90`), `flight_scale_factor` (`1.04`), `wing_root_spread_x_du` (`68.0`), `thrust_linear_slide_du` (`22.0`), `brake_spread_extra_du` (`28.0`), `shoulder_anchor_offset_du` (`(0, -14)`).
* **Onda Psíquica y Cohesión:** `idle_breathe_hz` (`0.62`), `blade_wave_float_du` (`4.5`), `blade_wave_amp_deg` (`2.8`), `blade_wave_phase_step` (`0.52`), `blade_fan_spread_deg` (`8.0`), `blade_radial_expand_du` (`10.0`).
* **Empuje, Vibración y Glow HDR:** `effort_asymmetry_gain` (`0.85`), `effort_smooth_rate` (`8.0`), `effort_vibration_amp_du` (`0.9`), `effort_vibration_hz` (`20.0`), `idle_emissive_boost` (`0.85`), `thrust_emissive_boost` (`3.00`), `effort_rim_strength` (`1.35`), `red_glow_idle_intensity` (`0.12`), `red_glow_thrust_intensity` (`1.65`), `red_glow_brake_intensity` (`2.35`).
* **Cintas y Polvo Estelar:** `ribbon_min_speed_px_s` (`55.0`), `ribbon_max_points` (`22`), `ribbon_lifetime_sec` (`0.38`), `ribbon_width_px` (`4.6`), `ribbon_secondary_scale` (`0.48`), `ribbon_opacity` (`0.66`), `stardust_idle_rate_hz` (`2.8`), `stardust_flight_rate_hz` (`18.0`), `stardust_max_particles` (`44`).

---

## 5. Verificación Rápida
* **Suite Wings + VFX Lab:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"`
* **Suite Core Rig 8-Dir:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"`
* **Escenas Interactivas:** [`sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn) (calibración + guardado `.tres`) y [`sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn`](../sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn) (rig estandarizado con skins y estilos).
