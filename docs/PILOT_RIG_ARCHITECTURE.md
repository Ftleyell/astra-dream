# Pilot Rig Architecture — Planar 8-Dir & Decoupled Head

> **Estado:** I+D Consolidado en `sandbox/pilot_rig_lab/` — **Valentina v2 (8-Dir Nativo)** únicamente (v1 eliminado; animaciones de locomoción/combate/física purgadas dejando solo cambio de dirección 8-dir y transiciones de orientación Modos 4/5/6). Ver referencia de máscaras y estado limpio actual en [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md).  
> **Escena Lab:** `res://sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn`  
> **Suite de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"`

---

## 1. Visión General

El rig de combate planar opera actualmente de forma exclusiva sobre **Valentina v2 (8-Dir Nativo)** (`valentina` v1 fue eliminado del Lab):
- **8-Dir Nativo (`valentina_v2`):** descubre y monta las **8 vistas nativas de cuerpo** (`s, se, e, ne, n, nw, w, sw`, siempre con `body_flip_x = false`) más **8 cabezas desacopladas asimétricas** (`head_flip_x = false`). En perfiles puros `e` y `w`, los 5 slots `parts_5` + hombreras están activos: la pierna trasera se clona de la frontal en `z_order = 0` y el brazo trasero se inyecta en `z_order = 1` (`pauldron_l`/`pauldron_r` trasero es placeholder `12×12`).

Cada vista de cuerpo se construye en modo `parts_5` (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`, `pauldron_r`, `pauldron_l`) sobre un `Skeleton2D` (18 huesos) en un `Node2D` (`BodyView_<DIR>`). Toda la silueta del personaje (`DecoupledHeadUnderMount -> BodyPivot -> DecoupledHeadMount`, con `z_index = 0` y orden de árbol limpio sin `CanvasGroup` anidados) se envuelve dentro de **1 único `CanvasGroup` padre** (`UnifiedCharacterGroup`) con shader de Pasada 2 (`pilot_rig_pass2.gdshader`).

### Reloj de Runtime Actual (Rig Limpio)
- **Activo a 60+ FPS:** Enrutado 8-dir nativo (`±65°`), transiciones *snappy* de orientación (Modos 4/5/6 + `afterimage` de giro y micro-snap de cabeza), *hit_flash*, *hit-stop* local (40–65 ms sin mutar `Engine.time_scale`) e *impact frames* de 2 fases.
- **Purgado (en rest pose):** Locomoción esquelética (`PlanarRigAnimator`), perspectiva 2.5D en vértice (`persp_mode = 0`), física secundaria (`jiggle = ZERO`), Pose Latch 15 FPS, alas y estela Sandevistan. Ver detalle exacto en [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md#1-qué-está-activo-vs-qué-fue-purgado).

---

## 2. Arquitectura Modular (`sandbox/pilot_rig_lab/proto/`)

| Módulo | Responsabilidad Única |
|---|---|
| `planar_combat_rig.gd` (`PlanarCombatRig`) | Orquestador principal (`Node2D`). Descubre vistas disponibles (`DIRECTION_ORDER_8`), ajusta `head_over_face_keep` (frente/perfil vs espalda) y expone `load_pilot_profile()`, `get_available_view_keys()`, `has_8dir_body()`, `set_locomotion_state()`, `set_transition_style()`, `trigger_hit_flash()`, `set_static_inspection()`. |
| `planar_rig_mesh_builder.gd` (`PlanarRigMeshBuilder`) | Construye mallas `Polygon2D` + pesos `Skeleton2D` desde `parts_5_meta.json` y cabezas en 2 pasadas (`head_layer_pass = 1` bajo torso, `2` sobre torso). Prioriza `Image.load_from_file()` (por `.gdignore`) con fallback a `ResourceLoader.load()`. |
| `planar_rig_view_router.gd` (`PlanarRigViewRouter`) | Resuelve enrutado 8-dir nativo (`body_flip_x = false`), selecciona cabeza 8-dir (`head_flip_x = false`), impone cono de cuello `±65°` (`MAX_NECK_DEG_8DIR`), histéresis y backpedal anti-exorcista. |
| `planar_rig_transition_controller.gd` (`PlanarRigTransitionController`) | Gestiona transiciones *snappy* (`4 = WHIP_SNAP_AFTERIMAGE`, `5 = MICRO_FLASH_SNAP`, `6 = HOLO_SNAP_FAST`) y micro-snap de cabeza entre las 8 vistas. |
| `planar_rig_animator.gd` (`PlanarRigAnimator`) | **Purgado (Rest Pose):** Mantiene huesos en `rest_rots` y `BodyPivot` en `ZERO/0.0`; conserva `AnimState`, `step_spring()` y lectura de `PlanarRigAnimConfig` (`.tres`). |
| `planar_rig_perspective_controller.gd` (`PlanarRigPerspectiveController`) | **Purgado (`persp_mode = 0`):** Desactiva escorzos 2.5D en vértice; conserva solo `leg_depth_phase` estático en perfiles `e`/`w`. |
| `planar_rig_secondary_physics.gd` (`PlanarRigSecondaryPhysics`) | **Purgado:** Fija `secondary_jiggle_l/r_px = ZERO` sin whiplash ni resortes activos. |
| `planar_rig_wings_vfx.gd` (`PlanarRigWingsVFX`) | **Parcial:** Solo `spawn_snap_afterimage` para el modo 4; alas procedurales, propulsores y estela Sandevistan purgados. |
| `planar_rig_material_controller.gd` (`PlanarRigMaterialController`) | Aplica `RigStyleProfile`, `PilotSkinPreset`, `PilotHairPreset`, iluminación 2.5D, modo Rayos-X y decaimiento de `hit_flash`. |
| `planar_lab_hud_builder.gd` (`PlanarLabHudBuilder`) | Construye la UI del Lab, escanea `pilots/*/*.tres` ordenados por `pilot_id` y reconstruye dinámicamente el selector de inspección estática (`2` o `8` cuerpos) al cambiar de piloto (`rebuild_static_body_options()`). |

---

## 3. Sistema Data-Driven (`.tres`) en `sandbox/pilot_rig_lab/data/`

- **`PilotRigProfile` (`pilot_rig_profile.gd`):** Perfil maestro de piloto (`pilot_id`, `display_name`, `assets_root`, `anim_config`, `display_scale`, `head_outline_strength`, `head_outline_width_px`, `skins`, `hair_presets`, `style_profiles`). Ubicación por piloto: `pilots/<id>/<id>_profile.tres`.
- **`PilotSkinPreset` (`pilot_skin_preset.gd`):** Paleta (`accent_color`, `panel_color`, `suit_dark_color`, `hair_color`) + booleano explícito `is_base_skin`.
- **`PilotHairPreset` (`pilot_hair_preset.gd`):** Color primario/secundario de cabello + booleanos explícitos `override_color` y `follow_skin_hair`.
- **`RigStyleProfile` (`rig_style_profile.gd`):** Parámetros de post-proceso para `pilot_rig_stylizer.gdshader` (`pipeline_mode`, semitonos, cel-step, noir, rim-light, glow).
- **`RigPerspectiveConfig` (`proto/rig_perspective_config.gd`):** Parámetros 2.5D (`cam_tan_alpha`, `jacobian_floor`, `k_conicity`, `k_volume`, curvas sakuga `tick_*` y perfiles de escorzo/profundidad por estado y vista).

---

## 4. Pipeline de Shaders en 2 Pasadas (`hdr_2d = true` Lineal)

- **Pasada 1 (`pilot_rig_stylizer.gdshader` + `shaders/*.gdshaderinc`, por pieza/cabeza):**
  - **Módulos `#include`:** `shaders/rig_perspective_25d.gdshaderinc` (proyección axial, escorzo, conicidad, *tuck* y *depth tints*), `shaders/rig_stylized_lighting.gdshaderinc` (cel-shading, RNM cilíndrico, sombras analíticas ILM, SSS piel, Nylon Fresnel, tinta SDF cabeza) y `shaders/rig_color_recolor.gdshaderinc` (recolorado LCH/YCbCr sobre `id_mask_tex`).
  - **Compatibilidad Lineal (`hdr_2d = true`):** `: source_color` en `conic_rim_lut` y colores; texturas de datos (`id_mask_tex`, `normal_depth_tex`, `outline_sdf_tex`, `secondary_jiggle_mask_tex`, `pauldron_mask_tex`) sin `: source_color`; conversión `linear_to_srgb()` para `orig_luma` y detección de color.
  - **Híbrido 2.5D:** *Halftone* curvado por `n25.xy * depth`, cel-shading sesgado por `normal_depth_tex.a`, separación *Key Rim* vs *Fill Rim* en `conic_rim_lut`, contorno SDF de cabeza modulado por `ndotl`, `hair_mid_fill` (`head_layer_pass == 1`) aplicado antes de la iluminación 2.5D/FX, `part_rig_rect` de cabeza calculado desde `neck_anchor - rig_origin` real, y ondas animadas con `q_time`.
  - **Inspector Rayos-X (`debug_view_mode`):** `0=Final`, `1=Clown-Pass`, `2=Luminancia`, `3=Tinta`, `4=Normales 2.5D`, `5=Profundidad 2.5D`.
- **Pasada 2 (`pilot_rig_pass2.gdshader`, sobre `UnifiedCharacterGroup`):**
  - `hint_screen_texture` con `use_mipmaps = true`, des-premultiplicación de alfa (`c.rgb /= c.a`), **Anillo 1 compartido (8 taps a `1.35 px` con soldador morfológico bipolar) + Anillo 2 condicional (8 taps Rotated Poisson con IGN)** y *Light-Wrap* HDR.
  - Outline exterior unificado compensado por `zoom_scale` (`zoom_eff = pow(zc, 0.60)`) y reactivo a `light_dir_2d`, *smear* seco direccional desacoplado para Modo 4 y *Impact Frames* de 2 fases (B/N directo → invertido con rayos radiales).
- **Lab HDR 2D, Sombra de Contacto y Siluetas Reales:**
  - `WorldEnvironment` en `planar_combat_rig_proto.gd` (`BG_CANVAS`, `TONE_MAPPER_AGX`, `glow_hdr_threshold = 1.05`) + toggle de fondo espacial/nebulosa.
  - `HeadContactShadow` dentro de `BodyPivot` como último hijo tras las vistas `BodyView_<DIR>` (`S`/`N` en v1; 8 vistas `S..SW` en v2, con `z_index = 0` para no escapar del `CanvasGroup`) siguiendo `Neck`, `-light_dir_2d` y `_head_spring_pos`.
  - `PlanarRigWingsVFX` clona la pose real de piezas + cabeza en `spawn_snap_afterimage` y `process_sandevistan_trail` (pool acotado a `MAX_ACTIVE_GHOSTS = 5`).
  - `PlanarRigAnimator` + `PlanarRigAnimConfig`: estructura conservada en rest pose (`BodyPivot.position = ZERO`, `rotation = 0`, huesos en `rest_rots`) para futura reconstrucción de locomoción.

---

## 5. Sistema de Outlines y Pulido de Bordes (Pasada 1 + Pasada 2)

### Regla Crítica de `CanvasGroup` en Godot 4 (`RendererCanvasCull`)
- En Godot 4, un `CanvasGroup` (`z_index = 0`) solo captura en su backbuffer descendientes cuyo `z_index` relativo es **`0`**. Cualquier nodo con `z_index != 0` escapa de la Pasada 2 y provoca outlines asimétricos.
- **Orden de árbol obligatorio dentro de `UnifiedCharacterGroup`** (todo con `z_index = 0`):
  1. `DecoupledHeadUnderMount` (`head_layer_pass = 1`)
  2. `BodyPivot`:
     - `BodyView_<DIR>` (`S`/`N` en v1; 8 vistas `S..SW` en v2) → `Meshes` ordenado por `z_orders` ascendente (`parts_5_meta.json`, incluyendo `pauldron_r/l` independientes en v2 y `Part_leg_*_stocking` con `leg_layer_pass = 2` sobre `body_core`, recortado en shader al cuff `UV.y ∈ [0.25, 0.48]`).
     - `HeadContactShadow` como último hijo de `BodyPivot`.
  3. `DecoupledHeadMount` (`head_layer_pass = 2`)

### 5.1 Inventario de Máscaras en Uso (Offline vs Runtime)

| Archivo / Máscara | Consumidor | Canales y Propósito Exacto | Estado / Notas |
|---|---|---|---|
| **`<part>_id_mask.png` / `<head>_id_mask.png`** | **Shader Pasada 1** (`id_mask_tex`) | `R`=acentos carmesí, `G`=armadura/paneles, `B`=traje oscuro (o cuello en cabeza para `is_collar_blue`), `A`=medias (en piernas) o cabello (`is_hair` en cabezas). `1-(R+G+B+A)`=piel. | **Activo (todas las piezas y cabezas)** |
| **`<part>_normal_depth.png` / `<head>_normal_depth.png`** | **Shader Pasada 1** (`normal_depth_tex`) | `RGB`=normal 2.5D (`nx, ny, nz`), `A`=profundidad `80..239` (cel-bias, parallax, sombras ILM y `DBG 4/5`). | **Activo (todas las piezas y cabezas)** |
| **`body_core_secondary_mask.png`** | **Shader Pasada 1** (`secondary_jiggle_mask_tex`) | `R`=zona blanda izq, `G`=zona blanda der (busto en `s/se/sw/e/w`, glúteos en `ne/n/nw`). | **Activo en `body_core`** |
| **`<head>_hair_jiggle_mask.png`** | **Shader Pasada 1** (`secondary_jiggle_mask_tex`) | `R`/`G`=mechones reactivos de cabello (`head_data` y `head_under_data` sincronizados). | **Activo en cabezas** |
| **`body_core_pauldron_mask.png`** | **Shader Pasada 1** (`pauldron_mask_tex`) | Escala de grises: sombra proyectada de la hombrera sobre el torso (`has_pauldron_mask`). | **Activo en `body_core`** |
| **`<head>_outline_sdf.png`** | **Shader Pasada 1** (`outline_sdf_tex`) | Campo de distancia (`24 px` pad) para contorno SDF de cabeza (`compute_head_sdf_ink`). | **Activo en cabezas (`use_mipmaps=false`)** |
| **`<limb>_anim_mask.png`** | **GDScript CPU** (`PlanarRigMeshBuilder._bind_parts5_weights`) | `R`=hueso proximal (`Shoulder`/`Thigh`), `G`=bisagra (`Elbow`/`Knee`), `B`=distal (`Wrist`/`Ankle`). `A`=`seam_fade` horneado por Python. | **Activo RGB en CPU** (canal `A` pendiente de conectar) |
| **`arm_r_over_mask.png` / `arm_l_over_mask.png`** | *(Retirado en v2)* | Reemplazado por `pauldron_r/l` separados y `z_orders`; `build_valentina_v2_rig_assets.py:1337` lo elimina si existe. | **Obsoleto en v2** (solo fallback v1) |
| **`01_parts_5_despiece` (`*_parts5_mask.png`)** | **Python Offline** (`build_valentina_v2_rig_assets.py`) | Verde=`body_core`, Rojo/Azul=`arm_l/r`, Amarillo/Magenta=`leg_r/l` (recorte inicial de las 5 piezas). | **Activo offline** |
| **`02_id_mask_bodies` (`*_id_mask.png`)** | **Python Offline** | Máscara semántica fuente de cuerpo antes de recortar y propagar a caps/torsos HD. | **Activo offline** |
| **`03_id_mask_heads` (`head_*_id_mask.png`)** | **Python Offline** | Máscara semántica fuente de cabezas para `_carve_head_neck_stub` y cabezas finales. | **Activo offline** |
| **`04_limb_anim_masks` (`*_limb_segments.png`)** | **Python Offline** | Segmentos RGB proximal/medio/distal de entrada al solucionador armónico (`_bake_geodesic_anim_mask_with_crease_cut`). | **Activo offline** |
| **`05_secondary_jiggle_masks`** | **Python Offline** | Cian=busto (`s/se/sw`), Magenta=glúteos (`n/ne/nw`); en `e/w` se sintetiza el busto lateral en Python. | **Activo offline** |
| **`06_torso_and_leg_e_16x9/.../*_pauldron_mask.png`** | **Python Offline** | Separa `pauldron_r/l` del torso y genera `body_core_pauldron_mask.png`. | **Activo offline** (`05_pauldron_masks_16x9` es fallback) |

### Pasada 1 — Por Pieza (`pilot_rig_stylizer.gdshader` + `planar_rig_mesh_builder.gd`)
- **Mipmaps Selectivos (`load_texture_res`):** Activados con filtro anisotrópico (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC`) en color, `_id_mask.png` y `_normal_depth.png`; **desactivados** (`use_mipmaps = false`) en `_outline_sdf.png`, `*_hair_jiggle_mask.png`, `body_core_secondary_mask.png`, `body_core_pauldron_mask.png` y `*_anim_mask.png` para no corromper distancias SDF ni máscaras de peso.
- **Sincronía `hair_jiggle`:** `PlanarRigSecondaryPhysics` aplica los mismos offsets de jiggle en `_head_data` y `_head_under_data` para evitar desfases de cabello bajo el mentón/hombros.
- **Sello Adaptativo (`pilot_rig_stylizer.gdshader`, secc. 10.5):** `seal_px = TEXTURE_PIXEL_SIZE * clamp(screen_px_in_texels * 0.45, 1.5, 3.2)` acotado con `seal_edge_gate` (`base.a` / `orig_luma`) para limpiar halos sin engrosar bordes oscuros ni brazos traseros; excluye costuras de cuello y tope de muslos (`hip_ao`).
- **Protección de Brazos Traseros (`s/arm_l`, `n/arm_r`, secc. 9.5):** `ink_protect = smoothstep(0.08, 0.16, orig_luma) * edge_alpha_guard`, `cel_min = 0.88` en cuerpo y `depth_bias = max(nd_sample.a - 0.5, -0.08) * 0.24` para que valores bajos de profundidad en brazos traseros no aplasten tonos oscuros del traje contra la tinta `#040406`.

### Pasada 2 — Silueta Completa Unificada (`pilot_rig_pass2.gdshader` + `planar_rig_material_controller.gd`)
- Envuelve el contorno exterior completo (cabeza + cabello + torso + brazos + piernas) sin duplicar líneas en las costuras internas.
- **Valores Base (`PlanarRigMaterialController`):** `DEFAULT_OUTER_OUTLINE_WIDTH_PX = 1.45`, `DEFAULT_OUTER_OUTLINE_STRENGTH = 1.0`, `BASE_OUTER_OUTLINE_COLOR = Color(0.0, 0.0, 0.0, 1.0)`, `outer_outline_tint_mix = 0.0`.
- **Compensación de Zoom y Soldadura:** `zoom_eff = pow(clamp(zoom_scale, 0.35, 4.0), 0.60)` con **Anillo 1 (8 taps a `1.35 px` + soldador morfológico bipolar) + Anillo 2 condicional (8 taps Rotated Poisson con IGN)** y *Light-Wrap* HDR (`hdr_threshold = 1.08`). (`outer_outline_tint_mix` permite reactivar tinte opcional por luz/skin si se requiere).

---

## 6. Guía Rápida de Ajustes para Próximas Sesiones

| Qué ajustar | Dónde tocar | Notas / Rango actual |
|---|---|---|
| **Grosor / Fuerza por defecto del outline unificado** | `planar_rig_material_controller.gd` (`DEFAULT_OUTER_OUTLINE_*`) y `pilot_rig_pass2.gdshader` | Actual: `1.45 px` / `1.0` negro sólido (`step 0.05` en `planar_lab_hud_builder.gd`). |
| **Escala del outline según zoom de cámara** | `pilot_rig_pass2.gdshader` (`zoom_eff = pow(zc, 0.60)`) | Ajusta la curva de compensación entre vista de combate y close-up. |
| **Tinte opcional por luz/skin en outline** | `pilot_rig_pass2.gdshader` (`outer_outline_tint_mix`) y `planar_rig_material_controller.gd` | Actual: `0.0` (negro sólido `#000000`). Subir hacia `1.0` para reactivar el tinte cromático. |
| **Outline SDF individual de cabeza** | `pilots/valentina_v2/valentina_v2_profile.tres` y `planar_rig_mesh_builder.gd` | **`4.0 px` calibrado en v2** con `sdf_pad_px = 32.0` (`HEAD_SDF_MAX_DIST_PX = 32.0`). Ajustable en el slider **Outline Cabeza**. |
| **Regenerar / ajustar piezas y máscaras v2 (8-Dir)** | `sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py` y `build_valentina_v2_rig_assets.py` (librería `rig_v2_lib/`) | Ver runbook en [`docs/PILOT_V2_8DIR_HANDOFF.md`](PILOT_V2_8DIR_HANDOFF.md) y tabla directa en [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md). |
| **Inspección rápida por script en Vulkan** | `tools/run_tests.ps1 -Test "pilot_rig_lab"` + escena Lab | Verifica jerarquía `z_index = 0`, orden `Meshes`, carga 8-dir v2 + simetría `e/w` + HUD `64` combos y parámetros Pasada 2. |
