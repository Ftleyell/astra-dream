# Pilot Rig Architecture — Planar 8-Dir & Decoupled Head

> **Estado:** I+D Consolidado en `sandbox/pilot_rig_lab/` (listo para futura promoción a producción).  
> **Escena Lab:** `res://sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn`  
> **Suite de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"`

---

## 1. Visión General

El rig de combate planar combina **2 vistas maestras de cuerpo** (`s` frente 3/4 y `n` espalda 3/4 con Flip-H para 8 direcciones) y **8 cabezas desacopladas asimétricas** (`head_front`, `head_front_l`, `head_front_r`, `head_side_l`, `head_side_r`, `head_back`, `head_back_l`, `head_back_r`, sin Flip-H para preservar asimetrías de flequillo/parche).

Cada vista de cuerpo se construye en modo `parts_5` (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`) sobre un `Skeleton2D` en un `Node2D` (`BodyView_S` / `BodyView_N`). Toda la silueta del personaje (`DecoupledHeadUnderMount -> BodyPivot -> DecoupledHeadMount`, con `z_index = 0` y orden de árbol limpio sin `CanvasGroup` anidados) se envuelve dentro de **1 único `CanvasGroup` padre** (`UnifiedCharacterGroup`) con shader de Pasada 2 (`pilot_rig_pass2.gdshader`). Las capas emisivas/aditivas (`ProceduralEnergyWings`, `BootThrusters` en `VFXBehindLayer`, más `afterimage` / `Sandevistan`) viven fuera del `CanvasGroup` para no recibir outline negro ni binarización de *impact frames*.

### Doble Reloj (*Limitation-as-Style*)
- **Reloj Rápido (60+ FPS):** Movimiento raíz, squash & stretch de *snap*, decaimiento de *smear*, `hit_flash`, *hit-stop* local (40–65 ms con *shake* ortogonal sin congelar `Engine.time_scale`) y *impact frames* de 2 fases.
- **Reloj Escalonado (15 FPS por defecto; configurable 15 / 12 / 60 FPS):** Pose Latch (`Skeleton2D`), jiggle secundario, cabeza con *follow-through* (retraso de 1 frame escalonado en giros de torso) y `q_time` en shaders.

---

## 2. Arquitectura Modular (`sandbox/pilot_rig_lab/proto/`)

| Módulo | Responsabilidad Única |
|---|---|
| `planar_combat_rig.gd` (`PlanarCombatRig`) | Orquestador principal (`Node2D`). Expone `load_pilot_profile()`, `set_locomotion_state()`, `set_transition_style()`, `trigger_hit_flash()`, `set_static_inspection()` y getters de estado. |
| `planar_rig_mesh_builder.gd` (`PlanarRigMeshBuilder`) | Construye mallas `Polygon2D` + pesos `Skeleton2D` desde `parts_5_meta.json` y cabezas en 2 pasadas (`head_layer_pass = 1` bajo torso, `2` sobre torso). Prioriza `ResourceLoader.load()` con fallback a `Image.load_from_file()`. |
| `planar_rig_view_router.gd` (`PlanarRigViewRouter`) | Resuelve dirección de cuerpo (`s`/`n` + Flip-H) y cabeza 8-dir con cono de cuello `±110°`, histéresis anti-parpadeo, backpedal anti-exorcista y sanitización cuerpo/cabeza. |
| `planar_rig_transition_controller.gd` (`PlanarRigTransitionController`) | Gestiona exclusivamente transiciones *snappy* (`4 = WHIP_SNAP_AFTERIMAGE`, `5 = MICRO_FLASH_SNAP`, `6 = HOLO_SNAP_FAST`). |
| `planar_rig_animator.gd` (`PlanarRigAnimator`) | Máquina de estados procedural (`IDLE_HOVER`, `FLIGHT_STRAFE`, `ASCEND`, `DESCEND`, `BACKPEDAL_FOCUS`, `DASH_BOOST`) parametrizada vía `PlanarRigAnimConfig` (`.tres`). |
| `planar_rig_secondary_physics.gd` (`PlanarRigSecondaryPhysics`) | Whiplash de extremidades/torso en giros y resortes 2D amortiguados para drag de busto y cabello reactivo. |
| `planar_rig_wings_vfx.gd` (`PlanarRigWingsVFX`) | Alas energéticas procedurales, propulsores en tobillos, afterimage en snap y estela Sandevistan en dash. |
| `planar_rig_material_controller.gd` (`PlanarRigMaterialController`) | Aplica `RigStyleProfile`, `PilotSkinPreset`, `PilotHairPreset`, iluminación 2.5D, modo Rayos-X y decaimiento de `hit_flash`. |
| `planar_lab_hud_builder.gd` (`PlanarLabHudBuilder`) | Construye la UI del Lab y escanea `pilots/*/*.tres` para selector dinámico de pilotos. |

---

## 3. Sistema Data-Driven (`.tres`) en `sandbox/pilot_rig_lab/data/`

- **`PilotRigProfile` (`pilot_rig_profile.gd`):** Perfil maestro de piloto (`pilot_id`, `display_name`, `assets_root`, `anim_config`, `display_scale`, `head_outline_strength`, `head_outline_width_px`, `skins`, `hair_presets`, `style_profiles`). Ubicación por piloto: `pilots/<id>/<id>_profile.tres`.
- **`PilotSkinPreset` (`pilot_skin_preset.gd`):** Paleta (`accent_color`, `panel_color`, `suit_dark_color`, `hair_color`) + booleano explícito `is_base_skin`.
- **`PilotHairPreset` (`pilot_hair_preset.gd`):** Color primario/secundario de cabello + booleanos explícitos `override_color` y `follow_skin_hair`.
- **`RigStyleProfile` (`rig_style_profile.gd`):** Parámetros de post-proceso para `pilot_rig_stylizer.gdshader` (`pipeline_mode`, semitonos, cel-step, noir, rim-light, glow).

---

## 4. Pipeline de Shaders en 2 Pasadas (`hdr_2d = true` Lineal)

- **Pasada 1 (`pilot_rig_stylizer.gdshader`, por pieza/cabeza):**
  - **Compatibilidad Lineal (`hdr_2d = true`):** `: source_color` en `conic_rim_lut` y colores; texturas de datos (`id_mask_tex`, `normal_depth_tex`, `head_outline_sdf_tex`, `secondary_jiggle_mask_tex`) sin `: source_color`; conversión `linear_to_srgb()` para `orig_luma` y detección de color.
  - **Híbrido 2.5D:** *Halftone* curvado por `n25.xy * depth`, cel-shading sesgado por `normal_depth_tex.a`, separación *Key Rim* vs *Fill Rim* en `conic_rim_lut`, contorno SDF de cabeza modulado por `ndotl`, `hair_mid_fill` (`head_layer_pass == 1`) aplicado antes de la iluminación 2.5D/FX, `part_rig_rect` de cabeza calculado desde `neck_anchor - rig_origin` real, y ondas animadas con `q_time`.
  - **Inspector Rayos-X (`debug_view_mode`):** `0=Final`, `1=Clown-Pass`, `2=Luminancia`, `3=Tinta`, `4=Normales 2.5D`, `5=Profundidad 2.5D`.
- **Pasada 2 (`pilot_rig_pass2.gdshader`, sobre `UnifiedCharacterGroup`):**
  - `hint_screen_texture` con des-premultiplicación de alfa (`c.rgb /= c.a`).
  - Outline exterior unificado compensado por `zoom_scale` y reactivo a `light_dir_2d`, *smear* seco direccional desacoplado para Modo 4 (sin flash invasivo en Pasada 1 ni doble haz holo desalineado en Modo 6) y *Impact Frames* de 2 fases (B/N directo → invertido con rayos radiales).
- **Lab HDR 2D, Sombra de Contacto y Siluetas Reales:**
  - `WorldEnvironment` en `planar_combat_rig_proto.gd` (`BG_CANVAS`, `TONE_MAPPER_AGX`, `glow_hdr_threshold = 1.05`) + toggle de fondo espacial/nebulosa.
  - `HeadContactShadow` dentro de `BodyPivot` como último hijo tras `BodyView_S`/`BodyView_N` (`z_index = 0`, para no escapar del `CanvasGroup`) siguiendo `Neck`, `-light_dir_2d` y `_head_spring_pos`.
  - `PlanarRigWingsVFX` clona la pose real de piezas + cabeza en `spawn_snap_afterimage` y `process_sandevistan_trail` (pool acotado a `MAX_ACTIVE_GHOSTS = 5`).
  - `PlanarRigAnimator` + `PlanarRigAnimConfig`: *contrapposto* en `IDLE_HOVER`, diferenciación de pose `"s"` vs `"n"`, tracking de brazo delantero hacia `_aim_dir` e inercia lateral en `BodyPivot.position.x`.

---

## 5. Sistema de Outlines y Pulido de Bordes (Pasada 1 + Pasada 2)

### Regla Crítica de `CanvasGroup` en Godot 4 (`RendererCanvasCull`)
- En Godot 4, un `CanvasGroup` (`z_index = 0`) solo captura en su backbuffer descendientes cuyo `z_index` relativo es **`0`**. Cualquier nodo con `z_index != 0` escapa de la Pasada 2 y provoca outlines asimétricos.
- **Orden de árbol obligatorio dentro de `UnifiedCharacterGroup`** (todo con `z_index = 0`):
  1. `DecoupledHeadUnderMount` (`head_layer_pass = 1`)
  2. `BodyPivot`:
     - `BodyView_S` / `BodyView_N` → `Meshes` ordenado por `z_orders` ascendente (`parts_5_meta.json`), con `Part_arm_r_over` (`pending_over` en `PlanarRigMeshBuilder._build_parts5_rig`) instanciado al final de `Meshes` y de `poly_refs`.
     - `HeadContactShadow` como último hijo de `BodyPivot`.
  3. `DecoupledHeadMount` (`head_layer_pass = 2`)

### Pasada 1 — Por Pieza (`pilot_rig_stylizer.gdshader` + `planar_rig_mesh_builder.gd`)
- **Mipmaps Selectivos (`load_texture_res`):** Activados con filtro anisotrópico (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC`) en color, `_id_mask.png` y `_normal_depth.png`; **desactivados** (`use_mipmaps = false`) en `_outline_sdf.png`, `*_hair_jiggle_mask.png`, `body_core_secondary_mask.png`, `arm_r_over_mask.png` y `*_anim_mask.png` para no corromper distancias SDF ni máscaras de peso.
- **Sincronía `hair_jiggle`:** `PlanarRigSecondaryPhysics` aplica los mismos offsets de jiggle en `_head_data` y `_head_under_data` para evitar desfases de cabello bajo el mentón/hombros.
- **Sello Adaptativo (`pilot_rig_stylizer.gdshader`, secc. 10.5):** `seal_px = TEXTURE_PIXEL_SIZE * clamp(screen_px_in_texels * 0.45, 1.5, 3.2)` acotado con `seal_edge_gate` (`base.a` / `orig_luma`) para limpiar halos sin engrosar bordes oscuros ni brazos traseros; excluye costuras de cuello y tope de muslos (`hip_ao`).
- **Protección de Brazos Traseros (`s/arm_l`, `n/arm_r`, secc. 9.5):** `ink_protect = smoothstep(0.08, 0.16, orig_luma) * edge_alpha_guard`, `cel_min = 0.88` en cuerpo y `depth_bias = max(nd_sample.a - 0.5, -0.08) * 0.24` para que valores bajos de profundidad en brazos traseros no aplasten tonos oscuros del traje contra la tinta `#040406`.

### Pasada 2 — Silueta Completa Unificada (`pilot_rig_pass2.gdshader` + `planar_rig_material_controller.gd`)
- Envuelve el contorno exterior completo (cabeza + cabello + torso + brazos + piernas) sin duplicar líneas en las costuras internas.
- **Valores Base (`PlanarRigMaterialController`):** `DEFAULT_OUTER_OUTLINE_WIDTH_PX = 1.45`, `DEFAULT_OUTER_OUTLINE_STRENGTH = 1.0`, `BASE_OUTER_OUTLINE_COLOR = Color(0.0, 0.0, 0.0, 1.0)`, `outer_outline_tint_mix = 0.0`.
- **Compensación de Zoom y Anti-Parpadeo:** `zoom_eff = mix(0.52, 1.38, smoothstep(0.50, 2.05, zc))` mantiene el grosor fino y proporcional al alejar (`~0.75 px` a `0.65x`, `~2.0 px` en close-up `2.0x`), con `4 anillos × 16 direcciones` ponderados por `alpha_cov = smoothstep(0.18, 0.65, s_tap.a)` para evitar que motas subpíxel parpadeen alrededor del contorno.
- **Sello Negro Sólido (8 Vecinos):** `inner_seal` sobre los 8 vecinos inmediatos (`a_r..a_dl`) con mordida escalada por zoom (`mix(0.08, 0.78, smoothstep(0.85, 1.90, zc))`) absorbe bordes desprolijos de Pasada 1 dentro del contorno negro sólido sin engrosar la silueta a `0.65x`. (`outer_outline_tint_mix` permite reactivar tinte opcional por luz/skin si se requiere).

---

## 6. Guía Rápida de Ajustes para Próximas Sesiones

| Qué ajustar | Dónde tocar | Notas / Rango actual |
|---|---|---|
| **Grosor / Fuerza por defecto del outline unificado** | `planar_rig_material_controller.gd` (`DEFAULT_OUTER_OUTLINE_*`) y `pilot_rig_pass2.gdshader` | Actual: `1.45 px` / `1.0` negro sólido (`step 0.05` en `planar_lab_hud_builder.gd`). |
| **Escala del outline según zoom de cámara** | `pilot_rig_pass2.gdshader` (`zoom_eff = mix(0.52, 1.38, ...)`) | Ajusta el equilibrio fino entre `0.65x` (~`0.75 px`) y `2.0x` (~`2.0 px`). |
| **Tinte opcional por luz/skin en outline** | `pilot_rig_pass2.gdshader` (`outer_outline_tint_mix`) y `planar_rig_material_controller.gd` | Actual: `0.0` (negro sólido `#000000`). Subir hacia `1.0` para reactivar el tinte cromático. |
| **Outline SDF individual de cabeza** | `pilots/valentina/valentina_profile.tres` (`head_outline_width_px`, `head_outline_strength`) | Actual: `5.5 px` / `1.0`. Ajustable también en el slider **Outline Cabeza** del Lab. |
| **Regenerar / ajustar bordes de piezas `parts_5`** | `sandbox/pilot_rig_lab/tools/polish_outlines.py` (`_normalize_single_back_arm`, `_thin_s_body_core_breast_seam`, flags en `parts_5_meta.json`) | Antes de re-correr transformaciones idempotentes, restaurar desde `combat_assets/<pilot_id>_planar/_backup_before_outline_polish/` o limpiar el flag JSON correspondiente. |
| **Inspección rápida por script en Vulkan** | `tools/run_tests.ps1 -Test "pilot_rig_lab"` + escena Lab | Verifica jerarquía `z_index = 0`, orden `Meshes`, luminancia mínima en brazos traseros (`> 0.08` solape / `> 0.14` visible), alineación `s/leg_r` y parámetros Pasada 2. |
