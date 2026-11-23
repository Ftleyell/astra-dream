---
trigger: model_decision
description: "Reglas de desarrollo, tabla contractual directa, zonas prohibidas y tests para el rig de Valentina v2 y PilotRigLab (sandbox/pilot_rig_lab/)."
---

# Reglas de Desarrollo — Pilotos Valentina v2 & PilotRigLab (`scenes/pilots/` & `sandbox/pilot_rig_lab/`)

> **Ámbito de aplicación:** Se aplica siempre que se trabaje en `PlanarCombatRig`, `PilotLiveBannerController`, shaders del rig 2.5D, presets de piloto/skin/estilo en `scenes/pilots/`, `data/pilots/`, `assets/pilots/` o los laboratorios/pipeline Python bajo `sandbox/pilot_rig_lab/`.
> **Índice de milestone y hoja de ruta:** [`docs/VALENTINA_V2_MILESTONE_STATUS.md`](../../docs/VALENTINA_V2_MILESTONE_STATUS.md) · **Plan Maestro:** [`docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](../../docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) · **Fuente de verdad técnica del rig runtime:** [`docs/VALENTINA_V2_RIG_REFERENCE.md`](../../docs/VALENTINA_V2_RIG_REFERENCE.md).

---

## 1. 🚫 Zonas Prohibidas de Exploración y Búsqueda (31,000+ archivos)
- **PROHIBIDO** listar recursivamente, hacer `grep`/`Select-String` o abrir archivos de forma ciega dentro de:
  - `sandbox/pilot_rig_lab/tools/.venv/` *(30,351 archivos)*
  - `sandbox/pilot_rig_lab/tools/models/` *(modelos ONNX/pesos)*
  - `sandbox/pilot_rig_lab/source_refs/` *(505+ archivos de arte crudo y workspaces)*
  - `sandbox/pilot_rig_lab/combat_assets/` *(550+ PNGs/JSONs compilados — leer solo `body_metrics.json`, `parts_5_meta.json` o `wings_metadata.json` puntuales si hace falta)*
  - `sandbox/pilot_rig_lab/backups/` *(snapshot inmutable de baseline calibrado)*
- **PROHIBIDO** leer completos los scripts Python o GDScript largos: consultar la tabla contractual inferior y leer acotado (máx. 100–200 líneas).

---

## 2. 🗂️ Tabla Contractual Directa: Qué Quieres Tocar $\to$ Archivo Exacto

### A. Balance Visual, Escalas, Skins, Pelo y Estilos (Cero código)
| Requerimiento / Ajuste | Archivo(s) Exclusivo(s) | Qué Editar |
|---|---|---|
| **Perfil maestro Valentina v2** | `data/pilots/valentina_v2/valentina_v2_profile.tres` | `display_scale` (`0.378`), `head_outline_width_px` (`4.0`), `stepped_fps`, listas `skins`/`hair_presets`/`style_profiles` |
| **Pose Base Zero-G (5 familias)** | `data/pilots/valentina_v2/valentina_v2_base_pose.tres` | Esquema `PilotBasePoseConfig` (`s, se, e, ne, n`, simetría `lead/trail`, 2D + 2.5D) |
| **Animación Idle Zero-G Multicapa** | `data/pilots/valentina_v2/valentina_v2_idle_anim.tres` | Esquema `PilotIdleAnimConfig` (3 capas conmutables, 4 cadencias, Gyro-Lock, multiplicadores por familia) |
| **Locomoción Continua & Freno Suave** | `data/pilots/valentina_v2/valentina_v2_locomotion_anim.tres` | Esquema `PilotLocomotionAnimConfig` (Avance aerodinámico, Freno contra-pitch, Reversa, atenuación/estela) |
| **Kiting 360° & Hover-Slide Zero-G** | `data/pilots/valentina_v2/valentina_v2_kiting_anim.tres` | Esquema `PilotKitingAnimConfig` (Reversa 180° `rev_`, Freno de Reversa `rbrk_`, Strafe lateral `str_near_`/`str_far_`, equilibrio distal) |
| **Giros Snappy 2.5D & Whip Cervical** | `data/pilots/valentina_v2/valentina_v2_turn_anim.tres` | Esquema `PilotTurnAnimConfig` (Puente 2.5D pre/post-corte, overshoot de torso, cascada brazos/piernas/pelo, whip cabeza desacoplada) |
| **Jiggle Physics Sutil (Busto & Glúteos)** | `data/pilots/valentina_v2/valentina_v2_jiggle_physics.tres` | Esquema `PilotJigglePhysicsConfig` (dinámica diferenciada busto/glúteos, micro-luz 2.5D normal, asimetría L/R, topes elásticos) |
| **Rig Facial Vivo & Cabello 3-Zonas** | `data/pilots/valentina_v2/valentina_v2_face_anim.tres` | Esquema `PilotFaceAnimConfig` (ojos/parpadeo, 6 presets expresión + comms, soldadura cervical, parallax 2.5D Live2D, 3 resortes cabello, monóculo HUD) |
| **Propulsión Base & Alas Psíquicas** | `data/pilots/valentina_v2/valentina_v2_base_propulsion.tres` | Esquema `PilotBasePropulsionConfig` (escala, flotación orbital, apertura lineal, empuje Newtoniano, glow HDR, 12 cintas, polvo estelar) |
| **Anillo Orbital 2.5D & Armamento** | `data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres` | Esquema `PilotOrbitalWeaponConfig` (elipse 3D inclinada, Z-sorting, escorzo, trapezoide 2.5D, extrusión 3D, 1–4 slots, recoil y trazadores) |
| **Alas 3D Cel-Shaded (Estándar Multi-Piloto)** | `data/pilots/valentina_v2/valentina_v2_wings_3d.tres` | Esquema `PilotWings3DConfig` (escala 3D, abanico, barrido, ondas, contorno 3D caligráfico, *crease ink*, glow HDR, Post-Pass 2D CAS + borde, estelas y polvo estelar) |
| **Live Banner 2.5D (Character Select)** | `data/pilots/valentina_v2/valentina_v2_live_banner.tres` | Esquema `PilotLiveBannerConfig` (rutas `base/motion/fx/depth`, respiración, jiggle hover, cabello Zero-G, parpadeo, parallax 2.5D, rim-light) |
| **Montaje Valentina v2 en Combate** | `data/pilots/valentina_v2/valentina_v2_combat_rig.tres` | Esquema `PilotCombatRigConfig` (escala compensada `0.90`, aura cósmica, sobre-enfoque, reacciones e impactos) |
| **Configuración de animación/suavizado** | `data/pilots/valentina_v2/valentina_v2_anim_config.tres` | `dir_smooth_rate`, `aim_smooth_rate`, `speed_smooth_rate`, `*_limits` |
| **Configuración 2.5D (purgada a neutro)** | `data/pilots/valentina_v2/valentina_v2_perspective_config.tres` | Parámetros `RigPerspectiveConfig` |
| **Paletas de Skin (10 presets)** | `data/pilots/valentina_v2/skins/*.tres` | `accent_color`, `panel_color`, `suit_dark_color`, `hair_color`, `is_base_skin` |
| **Catálogo Unificado de Skins Shader** | `data/pilots/valentina_v2/valentina_v2_skin_catalog.tres` + `data/pilots/schemas/{shader_skin_entry,pilot_shader_skin_catalog}.gd` | `base_preset`, 27 `ShaderSkinEntry` (`pilot`, `wings`, `weapon`), `resolve_preset()` |
| **Paletas de Cabello (10 presets)** | `data/pilots/hair/*.tres` | `primary_color`, `secondary_color`, `override_color`, `follow_skin_hair` |
| **Estilos de Shader (3 presets)** | `data/pilots/styles/*.tres` | `00_original` (baseline), `01_valentina_definitive` y `02_valentina_razor_sharp` (`stylize_enabled`, cel 2.5D, paleta Cosmos, materiales ID+ILM, rim híbrido y silueta caligráfica) |

### B. Comportamiento Runtime del Rig (`scenes/pilots/` y laboratorios en `sandbox/pilot_rig_lab/`)
| Sistema / Responsabilidad | Archivo Único | Estado Actual |
|---|---|---|
| **Orquestador principal del rig** | `scenes/pilots/rig/planar_combat_rig.gd` | **Activo (Prod.)** (delega en controladores) |
| **Helpers puros de calibración** | `scenes/pilots/rig/planar_rig_calibration_helpers.gd` | **Activo (Prod.)** (compartido por runtime y calibrador) |
| **Hit-stop local e Impact Frames (2 fases)** | `scenes/pilots/rig/planar_rig_impact_controller.gd` | **Activo (Prod.)** |
| **Enrutado 8-dir nativo, cono `±65°`, histéresis, backpedal** | `scenes/pilots/rig/planar_rig_view_router.gd` | **Activo (Prod.)** |
| **Transiciones snappy de giro (Modos 4/5/6 + whip cabeza)** | `scenes/pilots/rig/planar_rig_transition_controller.gd` | **Activo (Prod.)** (`get_turn_anim_state`, `set_custom_timings`, tiempos configurables desde `.tres`) |
| **Controlador Facial Vivo & Personalidad de Combate** | `scenes/pilots/rig/planar_rig_face_controller.gd` | **Activo (Prod.)** (opt-in en `PlanarCombatRig`; activo por defecto en `planar_combat_rig_proto` y `planar_anim_test`) |
| **Propulsión Base & Alas Psíquicas (Estándar Multi-Piloto)** | `scenes/pilots/vfx/valentina_base_propulsion_controller.gd` + `scenes/pilots/shaders/wing_red_glow.gdshader` | **Activo (Prod.)** (opt-in `enable_base_propulsion_wings` en `PlanarCombatRig`) |
| **Afterimage de giro (`spawn_snap_afterimage`)** | `scenes/pilots/rig/planar_rig_wings_vfx.gd` | **Parcial (Prod.)** (alas/Sandevistan purgados) |
| **Montaje `Skeleton2D` (18 huesos), `Polygon2D`, `head_layer_pass`** | `scenes/pilots/rig/planar_rig_mesh_builder.gd` | **Activo (Prod.)** |
| **Materiales, skins, pelo, estilos, `hit_flash`, `debug_view_mode`** | `scenes/pilots/rig/planar_rig_material_controller.gd` | **Activo (Prod.)** |
| **Live Banner 2.5D (Producción + CharacterSelect)** | `scenes/pilots/banner/pilot_live_banner_controller.gd` + `scenes/ui/character_select/components/character_live_banner_viewport.gd` | **Activo (Prod. Fase 2)** (montado en `CharacterPilotShowcase` y `HeroPickerModal`) |
| **Avatar Hub 3D 2.5D Diorama (Producción)** | `scenes/ui/hub/components/hub_rig_avatar_3d.gd` + `data/hub/default_hub_diorama_config.tres` | **Activo (Prod. Fase 3)** (`SubViewport` HDR sin alas ni anillo, cámara `-42°` / `FOV 38°`, lockout pedestales) |
| **Skins 100% por Shaders + Live Preview (Producción)** | `core/systems/cosmetics_manager.gd` + `scenes/ui/cosmetics/components/{shader_skin_live_preview,shader_skin_swatch}.gd` + `scenes/pilots/shaders/shader_skin_swatch.gdshader` | **Activo (Prod. Fase 4)** (3 slots `pilot`/`wings`/`weapon`, `"follow_pilot"`, sincronizado en Carrusel, Gacha, CharacterSelect y Hub 3D) |
| **Combate In-Game (Player + Anillo + VFX)** | `scenes/combat/player/player_rig_v2_controller.gd` + `scenes/combat/player/player.gd` | **Activo (Prod. Fase 5)** (Twin-Stick 360°, `CosmicLightingSampler`, Sobre-Enfoque completo, Anillo Orbital 1–4 slots híbrido) |
| **UI del Lab y selector de pilotos/inspección** | `sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd` + `proto/planar_combat_rig_proto.gd` | **Activo (Lab)** (sincronizado con Pose Base + Idle + Vuelo/Freno + Giros + Jiggle `.tres`) |
| **Evaluador Pose Base, Idle, Vuelo, Giros y Jiggle** | `scenes/pilots/rig/planar_rig_base_pose_evaluator.gd` | **Activo (Prod.)** (capas A/B 2D + 2.5D + resortes 2D busto/glúteos + micro-normal 2.5D + 4 cadencias + locomoción + giros) |
| **Evaluador Kiting 360° (Hover-Slide / Strafe)** | `scenes/pilots/rig/planar_rig_kiting_evaluator.gd` | **Activo (Prod.)** (Reversa 180°, Freno Reversa y Strafe lateral L↔R vía `PilotKitingAnimConfig`) |
| **Laboratorio Pose Base, Idle, Vuelo, Giros, Jiggle & Kiting** | `sandbox/pilot_rig_lab/proto/planar_anim_test.{tscn,gd}` + `planar_pose_lab_hud.gd` + `assets/pilots/shared/persp_masks/leg_*_persp_mask.png` | **Activo (Lab)** (Brújula 8-Dir con `02_valentina_razor_sharp`, HUD 6 pestañas, Slow-Mo `M`, A/B `Tab`, guardado `.tres`) |
| **Laboratorio Rig Facial Vivo (aislado)** | `sandbox/pilot_rig_lab/face_lab/valentina_face_lab.{tscn,gd}` + `valentina_face_{rig,lab_hud}.gd` + `scenes/pilots/shaders/rig_face_live.gdshaderinc` | **Activo (Lab)** (Hero Close-Up + Galería 8-Dir, Torso Ref `T`, Rayos-X `7..8`, guardado `.tres`) |
| **Laboratorio A/B de Shaders (aislado)** | `sandbox/pilot_rig_lab/shader_lab/planar_shader_lab.{tscn,gd}` + `shader_lab_hud.gd` + `shader_lab_backdrop.gd` | **Activo (Lab)** (Comparativa A/B, panel izquierdo con 4 pestañas, luz giratoria, Rayos-X `0..6`, guardado `.tres`) |
| **VFX Power-Up Sandevistan (Runtime + Lab)** | `scenes/pilots/vfx/sandevistan_trail_controller.gd` + `scenes/pilots/shaders/sandevistan_*.gdshader` + `data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres` | **Activo (Prod. + Lab)** (Pincel Ping-Pong Turquesa↔Bordó↔Amatista, tinta interna SDF 2×; lab en `vfx_lab/valentina_vfx_lab.tscn`) |
| **Armamento Orbital 2.5D (Runtime + Guns Lab)** | `scenes/pilots/weapons/orbital_weapon_{ring_controller,3d_renderer}.gd` + `rail_lance_3d_mesh_builder.gd` + `data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres` | **Activo (Prod. + Lab)** (Anillo Mecha contrarrotativo + Rail-Lance 3D Cel-Shaded; lab en `guns_lab/valentina_guns_lab.tscn`) |
| **Alas 3D Cel-Shaded (Estándar Multi-Piloto)** | `scenes/pilots/vfx/astral_wings_3d_{mesh_builder,controller}.gd` + `scenes/pilots/shaders/astral_wing_{toon_3d,outline_3d,post_2d}.gdshader` + `data/pilots/valentina_v2/valentina_v2_wings_3d.tres` | **Activo (Prod. + Lab)** (`enable_3d_wings` en `PlanarCombatRig`; Dual-Pass `768×768`; lab en `3d_lab/valentina_3d_lab.tscn`) |
| **Laboratorio Live Banner 2.5D (Lab)** | `sandbox/pilot_rig_lab/banner_lab/valentina_banner_lab.{tscn,gd}` + `valentina_banner_lab_hud.gd` | **Activo (Lab)** (Calibración de `valentina_v2_live_banner.tres` consumiendo runtime en `scenes/pilots/banner/`) |
| **Backup Inmutable Baseline Calibrado** | `sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/` + `backups/restore_valentina_v2_baseline.ps1` | **Activo** (Snapshot SHA256 con `.gdignore` + tag Git `valentina-v2-clean-baseline`) |
| **Animación esquelética procedural** | `scenes/pilots/rig/planar_rig_animator.gd` | **Purgado (Rest Pose)** |
| **Perspectiva 2.5D en vértice** | `scenes/pilots/rig/planar_rig_perspective_controller.gd` | **Purgado (`persp_mode = 0`, solo `leg_depth_phase` en `e/w`)** |
| **Física secundaria (jiggle/whiplash)** | `scenes/pilots/rig/planar_rig_secondary_physics.gd` | **Purgado (`ZERO`)** |
| **Shader Pasada 1 (piezas y cabezas)** | `scenes/pilots/shaders/pilot_rig_stylizer.gdshader` + `rig_{color_recolor,stylized_lighting,perspective_25d}.gdshaderinc` | **Activo (Prod.)** |
| **Shader Pasada 2 (`UnifiedCharacterGroup`)** | `scenes/pilots/shaders/pilot_rig_pass2.gdshader` | **Activo (Prod.)** |

### C. Pipeline Offline Python (`sandbox/pilot_rig_lab/tools/`)
- **Librería modular v2:** `sandbox/pilot_rig_lab/tools/rig_v2_lib/` (`constants.py`, `mask_and_matting.py`, `skeleton_and_normals.py`, `heads_builder.py`, `part_exporter.py`, `limb_cap_stages.py`, `torso_pauldron_stages.py`, `limb_seal_stages.py`, `audit_renderer.py`, `mask_workspace_prompts.py`).
- **Orquestador CLI de ensamblado:** `sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py` (ejecutar con `C:\Python314\python.exe` si usa `scipy`).
- **Workspaces de máscaras IA:** `sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py` (ejecutar con `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe`).
- **Regeneración HQ de máscaras por pieza (`ID`, `Normal/Depth`, `ILM`):** `sandbox/pilot_rig_lab/tools/export_piece_mask_sheets.py` + `ingest_piece_mask_sheets.py` (`--kind id|normal|ilm|ink`) + `rig_v2_lib/piece_mask_prompts.py` (7 hojas estándar `16:9` y `1:1` bajo `source_refs/valentina_v2_8dir/06_piece_mask_regen/`, ejecutar con `C:\Python314\python.exe`).
- **Pipeline HQ Ink SDF `2×` (`*_ink_sdf.png`):** `sandbox/pilot_rig_lab/tools/ink_hq_pipeline.py` (`--action export|test|apply --sheet <hoja>`): 13 hojas `1:1` (`2048×2048`) con doble referencia (`inputs_color/` + `inputs_anchor/`) bajo `source_refs/valentina_v2_8dir/07_ink_hq_regen/`, post-procesadas con **Upscayl `digital-art-4x` + ECC Afín + Flujo Óptico Farneback acotado** y horneadas en `*_ink_sdf.png` a resolución **`2×`** (distancias codificadas en texels nativos `±8.0`).
- **Compilador de Alas Multi-Piloto (3 vistas `#808080` → 8-dir por cuchillas):** `sandbox/pilot_rig_lab/tools/build_valentina_v2_wings.py` (`--sheet`, `--out-dir`, `--audit`): Upscayl `4×`, separación por cuchilla (`6` por ala), extracción de 5 mapas (`albedo`, `id`, `ilm`, `normal_depth`, `ink_sdf 2×`), espejado con `Nx = -Nx` y `wings_metadata.json` (`schema_version = 2`). Ver guía en `docs/VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`.
- **Compilador de Armamento Multi-Mapa (`#808080` → `albedo`/`id`/`ilm`/`ink_sdf 2×`):** `sandbox/pilot_rig_lab/tools/build_valentina_weapon.py` (`--src`, `--out-dir`, `--name`, `--target-width`, `--no-upscayl`): segmentación `#808080`, separación 3-materiales (`R` acento/energía, `G` placas, `B` chasis), `ilm_mask`, `ink_sdf 2×` y `*_meta.json`. Ver guía en `docs/VALENTINA_ORBITAL_WEAPON_SPEC.md`.
- **Compilador de Anillo Orbital IA (`1:1 #000000` → RGBA empaquetado):** `sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py` (`--src`, `--out-dir`, `--name`, `--size`, `--split-r`): recentrado `1:1`, extracción `R` estructura / `G` energía / `B` zona exterior-interior (`255/0`) / `A` recorte negro y `*_meta.json`. Ver guía en `docs/VALENTINA_ORBITAL_WEAPON_SPEC.md`.
- **Compilador de Live Banner 2.5D + Icono 1:1 (Splash Character Select):** `sandbox/pilot_rig_lab/tools/build_valentina_live_banner.py` (`--src`, `--mask-parts`, `--mask-mat`, `--mask-depth`, `--mask-ink`, `--out-dir`, `--prefix`): genera `*_body_layer.png` (hombrera fija), `*_free_arm_layer.png` (brazo libre bajo hombrera), `*_splash_motion_mask.png`, `*_splash_fx_mask.png`, `*_splash_depth.png`, `*_splash_normal.png`, `*_splash_ink_sdf.png` e icono `*_icon_1x1.png` (`512×512`).
- **Scripts legacy v1 / ingesta puntual:** `tools/legacy_v1/` o módulos de etapa previa (`prepare_8dir_sheets.py`, `ingest_*_16x9.py`). No tocarlos salvo regeneración explícita de fuentes crudas.

---

## 3. 🔒 Invariantes Arquitectónicos Críticos
1. **Regla `CanvasGroup`:** Todos los nodos bajo `UnifiedCharacterGroup` (`DecoupledHeadUnderMount`, `BodyPivot`, `BodyView_*`, `Meshes/*`, `HeadContactShadow`, `DecoupledHeadMount`) DEBEN mantener `z_index = 0`. El orden Z se controla exclusivamente por orden de hijos en el árbol.
2. **Solo Valentina v2 (8-Dir Nativo):** `body_flip_x` y `head_flip_x` siempre `false` en vistas nativas `s, se, e, ne, n, nw, w, sw`.
3. **Single Source of Truth (Dependencia Unidireccional):** Todo el runtime, shaders, esquemas, presets `.tres` y assets compilados de Valentina v2 viven en `scenes/pilots/`, `data/pilots/` y `assets/pilots/`. Los laboratorios de `sandbox/pilot_rig_lab/` consumen producción; **prohibido que producción importe cualquier recurso o script desde `sandbox/`**.
4. **Aislamiento del Laboratorio de Animación:** Toda nueva prueba de animación o falsa perspectiva 2.5D se desarrolla en `sandbox/pilot_rig_lab/proto/planar_anim_test.tscn` (o futuros clips bajo `anim_lab/`), usando `calibration_manual_pose = true`. Prohibido ensuciar `scenes/pilots/rig/planar_rig_perspective_controller.gd` / `planar_rig_animator.gd` (deben mantener `persp_mode = 0` en el rig purgado para que `test_pilot_rig_lab.tscn` siga en PASS).
5. **Canal `B` del Cuello en `heads/head_*_id_mask.png`:** En las 8 cabezas, el canal azul (`B = 255`) de `*_id_mask.png` marca el cuello inferior para dividir `head_layer_pass = 1` (bajo el torso) vs. `head_layer_pass = 2` (sobre el torso). Toda regeneración/ingesta de ID de cabezas **DEBE preservar** ese canal `B` en la zona de piel del cuello (`not hair` y `not monocle`) para que los cuellos no se dibujen por encima del torso.
6. **Tinta Interna SDF (`*_ink_sdf.png`):** Todo mapa `*_ink_sdf.png` debe cargarse **sin mipmaps** (`use_mipmaps = false`, muestreado en LOD 0 con `sdf_tex / screen_px_in_texels`) para mantener líneas internas vectorialmente nítidas a cualquier zoom. Los 65 mapas actuales están horneados a **`2×`** vía `ink_hq_pipeline.py` (`07_ink_hq_regen/`, doble referencia color + anclaje nativo + Upscayl 4× + ECC/Farneback), manteniendo el interior del traje oscuro/botas/guantes en `#FFFFFF` puro (solo trazos `#000000`, nunca rellenos negros sólidos).
7. **Estándar Ocular Amatista Profundo y Protección HSV:** Todas las vistas con ojo descubierto (`head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side`) usan la paleta **Amatista Profundo** (`#421D70` → `#8B5CF6` → `#DFC4FF`, pupila `#100816`), horneada idempotente (`4× SSAA`) en los `<head>.png` base vía `tools/ingest_eye_live2d_assets.py` (conservando originales en `_heads_native_backup/`). Tanto `pilot_rig_stylizer.gdshader` (vivo RGSS y estático `!enable_face_live && has_eye_live2d_assets`) como `shaders/rig_face_live.gdshaderinc` deben evaluar tinta de pupila/anillo por **Valor HSV** (`max(r, max(g, b))`) en lugar de luminancia Rec.601 para no ennegrecer el violeta `#421D70` superior.

---

## 4. 🧪 Verificación Rápida
- **Suites del dominio:**
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"` *(~8 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"` *(~5 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"` *(~5 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab"` *(~5 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"` *(~5 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_banner_lab"` *(~3 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_roster_rework_lockout"` *(~4 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_25d_valentina_rig"` *(~5 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_shader_skins_system"` *(~9 s)*
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_player_valentina_v2_combat"` *(~7 s)*
- **Verificación Python tras editar `tools/`:** `C:\Python314\python.exe -m py_compile sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py sandbox/pilot_rig_lab/tools/build_valentina_v2_wings.py` (y módulos modificados en `rig_v2_lib/`).
