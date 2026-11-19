---
trigger: model_decision
description: "Reglas de desarrollo, tabla contractual directa, zonas prohibidas y tests para el rig de Valentina v2 y PilotRigLab (sandbox/pilot_rig_lab/)."
---

# Reglas de Desarrollo — PilotRigLab & Valentina v2 (`sandbox/pilot_rig_lab/`)

> **Ámbito de aplicación:** Se aplica siempre que se trabaje en `PlanarCombatRig`, shaders del rig 2.5D, presets de piloto/skin/estilo o el pipeline Python de Valentina v2 (`sandbox/pilot_rig_lab/`).
> **Fuente de verdad técnica del rig runtime:** [`docs/VALENTINA_V2_RIG_REFERENCE.md`](../../docs/VALENTINA_V2_RIG_REFERENCE.md).

---

## 1. 🚫 Zonas Prohibidas de Exploración y Búsqueda (31,000+ archivos)
- **PROHIBIDO** listar recursivamente, hacer `grep`/`Select-String` o abrir archivos de forma ciega dentro de:
  - `sandbox/pilot_rig_lab/tools/.venv/` *(30,351 archivos)*
  - `sandbox/pilot_rig_lab/tools/models/` *(modelos ONNX/pesos)*
  - `sandbox/pilot_rig_lab/source_refs/` *(505 archivos de arte crudo y workspaces)*
  - `sandbox/pilot_rig_lab/combat_assets/` *(293 PNGs/JSONs compilados — leer solo `body_metrics.json` o `parts_5_meta.json` puntuales si hace falta)*
- **PROHIBIDO** leer completos los scripts Python o GDScript largos: consultar la tabla contractual inferior y leer acotado (máx. 100–200 líneas).

---

## 2. 🗂️ Tabla Contractual Directa: Qué Quieres Tocar $\to$ Archivo Exacto

### A. Balance Visual, Escalas, Skins, Pelo y Estilos (Cero código)
| Requerimiento / Ajuste | Archivo(s) Exclusivo(s) | Qué Editar |
|---|---|---|
| **Perfil maestro Valentina v2** | `sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres` | `display_scale` (`0.378`), `head_outline_width_px` (`4.0`), `stepped_fps`, listas `skins`/`hair_presets`/`style_profiles` |
| **Configuración de animación/suavizado** | `sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/valentina_v2_anim_config.tres` | `dir_smooth_rate`, `aim_smooth_rate`, `speed_smooth_rate`, `*_limits` |
| **Configuración 2.5D (purgada a neutro)** | `sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/valentina_v2_perspective_config.tres` | Parámetros `RigPerspectiveConfig` |
| **Paletas de Skin (10 presets)** | `sandbox/pilot_rig_lab/pilots/valentina_v2/skins/*.tres` | `accent_color`, `panel_color`, `suit_dark_color`, `hair_color`, `is_base_skin` |
| **Paletas de Cabello (10 presets)** | `sandbox/pilot_rig_lab/data/hair/*.tres` | `primary_color`, `secondary_color`, `override_color`, `follow_skin_hair` |
| **Estilos de Shader (9 presets)** | `sandbox/pilot_rig_lab/data/styles/*.tres` | `pipeline_mode`, cel-step, halftone, rim-light, `outer_outline_tint_mix` |

### B. Comportamiento Runtime del Rig (`sandbox/pilot_rig_lab/proto/` y `shaders/`)
| Sistema / Responsabilidad | Archivo Único | Estado Actual |
|---|---|---|
| **Orquestador principal del rig** | `proto/planar_combat_rig.gd` | **Activo** (delega en controladores) |
| **Hit-stop local e Impact Frames (2 fases)** | `proto/planar_rig_impact_controller.gd` | **Activo** |
| **Enrutado 8-dir nativo, cono `±65°`, histéresis, backpedal** | `proto/planar_rig_view_router.gd` | **Activo** |
| **Transiciones snappy de giro (Modos 4/5/6 + micro-snap cabeza)** | `proto/planar_rig_transition_controller.gd` | **Activo** |
| **Afterimage de giro (`spawn_snap_afterimage`)** | `proto/planar_rig_wings_vfx.gd` | **Parcial** (alas/Sandevistan purgados) |
| **Montaje `Skeleton2D` (18 huesos), `Polygon2D`, `head_layer_pass`** | `proto/planar_rig_mesh_builder.gd` | **Activo** |
| **Materiales, skins, pelo, estilos, `hit_flash`, `debug_view_mode`** | `proto/planar_rig_material_controller.gd` | **Activo** |
| **UI del Lab y selector de pilotos/inspección** | `proto/planar_lab_hud_builder.gd` + `proto/planar_combat_rig_proto.gd` | **Activo** |
| **Laboratorio de Animación 2.5D (aislado)** | `proto/planar_anim_test.tscn` + `proto/planar_anim_test.gd` + `proto/leg_*_persp_mask.png` | **Activo (I+D)** (Brújula 8-Dir, zoom/paneo, 16 máscaras de pierna y rotación de cabezas) |
| **Laboratorio A/B de Shaders (aislado)** | `shader_lab/planar_shader_lab.tscn` + `shader_lab/planar_shader_lab.gd` + `shader_lab/shader_lab_hud.gd` + `shader_lab/shader_lab_backdrop.gd` | **Activo (I+D)** (Comparativa A/B, panel izquierdo con 4 pestañas, luz giratoria, Rayos-X `0..6`, guardado `.tres`) |
| **Backup Inmutable Baseline Calibrado** | `backups/valentina_v2_clean_baseline/` + `backups/restore_valentina_v2_baseline.ps1` | **Activo** (Snapshot SHA256 con `.gdignore` + tag Git `valentina-v2-clean-baseline`; soporta `-MetaOnly` / `-ShadersOnly` / `-DryRun`) |
| **Animación esquelética procedural** | `proto/planar_rig_animator.gd` | **Purgado (Rest Pose)** |
| **Perspectiva 2.5D en vértice** | `proto/planar_rig_perspective_controller.gd` | **Purgado (`persp_mode = 0`, solo `leg_depth_phase` en `e/w`)** |
| **Física secundaria (jiggle/whiplash)** | `proto/planar_rig_secondary_physics.gd` | **Purgado (`ZERO`)** |
| **Shader Pasada 1 (piezas y cabezas)** | `pilot_rig_stylizer.gdshader` + `shaders/rig_{color_recolor,stylized_lighting,perspective_25d}.gdshaderinc` | **Activo** |
| **Shader Pasada 2 (`UnifiedCharacterGroup`)** | `pilot_rig_pass2.gdshader` | **Activo** |

### C. Pipeline Offline Python (`sandbox/pilot_rig_lab/tools/`)
- **Librería modular v2:** `sandbox/pilot_rig_lab/tools/rig_v2_lib/` (`constants.py`, `mask_and_matting.py`, `skeleton_and_normals.py`, `heads_builder.py`, `part_exporter.py`, `limb_cap_stages.py`, `torso_pauldron_stages.py`, `limb_seal_stages.py`, `audit_renderer.py`, `mask_workspace_prompts.py`).
- **Orquestador CLI de ensamblado:** `sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py` (ejecutar con `C:\Python314\python.exe` si usa `scipy`).
- **Workspaces de máscaras IA:** `sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py` (ejecutar con `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe`).
- **Regeneración HQ de máscaras por pieza (`ID`, `Normal/Depth`, `ILM`):** `sandbox/pilot_rig_lab/tools/export_piece_mask_sheets.py` + `ingest_piece_mask_sheets.py` + `rig_v2_lib/piece_mask_prompts.py` (7 hojas estándar `16:9` y `1:1` bajo `source_refs/valentina_v2_8dir/06_piece_mask_regen/`, ejecutar con `C:\Python314\python.exe`).
- **Scripts legacy v1 / ingesta puntual:** `tools/legacy_v1/` o módulos de etapa previa (`prepare_8dir_sheets.py`, `ingest_*_16x9.py`). No tocarlos salvo regeneración explícita de fuentes crudas.

---

## 3. 🔒 Invariantes Arquitectónicos Críticos
1. **Regla `CanvasGroup`:** Todos los nodos bajo `UnifiedCharacterGroup` (`DecoupledHeadUnderMount`, `BodyPivot`, `BodyView_*`, `Meshes/*`, `HeadContactShadow`, `DecoupledHeadMount`) DEBEN mantener `z_index = 0`. El orden Z se controla exclusivamente por orden de hijos en el árbol.
2. **Solo Valentina v2 (8-Dir Nativo):** `body_flip_x` y `head_flip_x` siempre `false` en vistas nativas `s, se, e, ne, n, nw, w, sw`.
3. **Aislamiento de Producción:** Todo bajo `sandbox/pilot_rig_lab/` permanece aislado; prohibido enlazar directo en `scenes/combat/`.
4. **Aislamiento del Laboratorio de Animación:** Toda nueva prueba de animación o falsa perspectiva 2.5D se desarrolla en `proto/planar_anim_test.tscn` (o futuros clips bajo `anim_lab/`), usando `calibration_manual_pose = true`. Prohibido ensuciar `planar_rig_perspective_controller.gd` / `planar_rig_animator.gd` (deben mantener `persp_mode = 0` en el rig purgado para que `test_pilot_rig_lab.tscn` siga en PASS).
5. **Canal `B` del Cuello en `heads/head_*_id_mask.png`:** En las 8 cabezas, el canal azul (`B = 255`) de `*_id_mask.png` marca el cuello inferior para dividir `head_layer_pass = 1` (bajo el torso) vs. `head_layer_pass = 2` (sobre el torso). Toda regeneración/ingesta de ID de cabezas **DEBE preservar** ese canal `B` en la zona de piel del cuello (`not hair` y `not monocle`) para que los cuellos no se dibujen por encima del torso.

---

## 4. 🧪 Verificación Rápida
- **Suite única del dominio:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"` *(~8 s)*.
- **Verificación Python tras editar `tools/`:** `C:\Python314\python.exe -m py_compile sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py` (y módulos modificados en `rig_v2_lib/`).
