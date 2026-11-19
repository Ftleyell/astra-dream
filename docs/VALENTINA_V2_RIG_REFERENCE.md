# Referencia Completa del Rig Limpio — Valentina v2 (8-Dir Nativo)

> **Única Fuente de Verdad Runtime:** Este documento refleja el estado actual real del rig **Valentina v2** (`valentina` v1 eliminado). Para reglas rápidas de edición y tabla contractual sin relecturas, consultar [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md).
> **Estado actual:** Rig purgado y exclusivo de **Valentina v2**. Todas las animaciones procedurales de locomoción/idle/combate, deformaciones 2.5D en vértice y físicas secundarias están desactivadas. **Únicamente están activos el cambio de dirección 8-dir nativo y su animación de transición de orientación** (enrutado de cuerpo + cabeza desacoplada + cono cervical + backpedal + `PlanarRigTransitionController` Modos 4/5/6 con squash/stretch, smear/flash/holo-sweep, afterimage de giro y micro-snap de cabeza) junto con el pipeline de render estático.
> **Escenas de Laboratorio:** [`planar_combat_rig_proto.tscn`](../sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn) · [`planar_shader_lab.tscn`](../sandbox/pilot_rig_lab/shader_lab/planar_shader_lab.tscn) (A/B Shaders) · [`planar_anim_test.tscn`](../sandbox/pilot_rig_lab/proto/planar_anim_test.tscn) (Animación 2.5D)
> **Backup Inmutable Baseline:** [`backups/valentina_v2_clean_baseline/`](../sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/) + [`restore_valentina_v2_baseline.ps1`](../sandbox/pilot_rig_lab/backups/restore_valentina_v2_baseline.ps1) + tag Git `valentina-v2-clean-baseline`
> **Suite de Verificación:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"`

---

## 1. Qué Está Activo vs Qué Fue Purgado

| Sistema | Estado | Archivo / Módulo | Notas para reconstrucción |
|---|---|---|---|
| **Enrutado 8-Dir Cuerpo + Cabeza** | **ACTIVO** | [`planar_rig_view_router.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd) | 8 vistas nativas (`s, se, e, ne, n, nw, w, sw`, `body_flip_x = false`) + 8 cabezas asimétricas (`head_flip_x = false`), cono cervical `±65°`, histéresis de giro y backpedal (`BACKPEDAL_ENTER_DOT_8DIR = 0.56`, `EXIT = 0.68`). |
| **Animación de Cambio de Orientación** | **ACTIVO** | [`planar_rig_transition_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_transition_controller.gd), [`planar_rig_wings_vfx.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_wings_vfx.gd) | Modos snappy 4/5/6 (`WHIP_SNAP_AFTERIMAGE`, `MICRO_FLASH_SNAP`, `HOLO_SNAP_FAST`): `snap_scale_xy` en `BodyPivot`/`HeadAnchor`, smear en Pasada 2, flash/holo-sweep en Pasada 1, afterimage de giro (`spawn_snap_afterimage`) y micro-snap de cabeza. *(Estela Sandevistan y alas/propulsores permanecen purgados).* |
| **Montaje de Mallas y Pesos** | **ACTIVO** | [`planar_rig_mesh_builder.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd) | Construye `Skeleton2D` (18 huesos), mallas `Polygon2D`, pesos desde `*_anim_mask.png`, blends de cadera/hombro/hombrera y cabezas en 2 pasadas (`head_layer_pass = 1/2`). |
| **Materiales, Recolor, Iluminación 2.5D, Outlines, Hit Flash / Impact Frame** | **ACTIVO** | [`planar_rig_material_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_material_controller.gd) | Skins (10), Cabello (10), Estilos (9), `use_normal_depth`, `conic_rim_lut`, Pasada 2 unificada, rayos-X (`debug_view_mode = 0..5`), `leg_depth_phase` estático en `e`/`w`. |
| **Animación Esquelética Procedural** | **PURGADO (Rest Pose)** | [`planar_rig_animator.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_animator.gd) | Mantiene `BodyPivot.position = ZERO`, `rotation = 0` y los 18 `Bone2D` en `rest_rots` (`BodyPivot.scale` recibe únicamente `snap_scale_xy` durante giros). Conserva enum `AnimState`, `ANIM_BONES`, `step_spring()` y lectura de límites `*_limits` en `.tres`. |
| **Perspectiva 2.5D Post-Skinning** | **PURGADO (`persp_mode = 0`)** | [`planar_rig_perspective_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_perspective_controller.gd) | Fuerza `persp_mode = 0`, `poly.position = ZERO`, `bone_chain_angles = ZERO`, `joint_flexion = 0`, `Pauldron_R/L.position = rest_pos`, `Bone2D.scale = ONE`. Solo conserva `leg_depth_phase` estático en `e`/`w` (`0.65` / `-0.75`). |
| **Física Secundaria (Jiggle / Whiplash)** | **PURGADO** | [`planar_rig_secondary_physics.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_secondary_physics.gd) | Fija `secondary_jiggle_l_px = ZERO` y `secondary_jiggle_r_px = ZERO` en `body_core` y cabezas (`enable_secondary_jiggle = false` en cabezas; textura cargada y lista en `body_core`). |
| **Resortes de Cabeza / Pose Latch 15 FPS** | **PURGADO** | [`planar_combat_rig.gd`](../sandbox/pilot_rig_lab/proto/planar_combat_rig.gd) | `_head_anchor` y `_head_under_anchor` anclados a `Neck.global_position` (`rotation = 0`, `scale = snap_scale_xy / head_micro_snap_scale`), `q_time = 0`, `banking_tilt_2d = ZERO`. |
| **Valentina v1 (2-Dir + Flip-H)** | **ELIMINADO** | — | Eliminados `pilots/valentina/` y `combat_assets/valentina_planar/`. Skins migradas a [`pilots/valentina_v2/skins/`](../sandbox/pilot_rig_lab/pilots/valentina_v2/skins/). |

---

## 2. Topología del SceneTree en Runtime

```text
PlanarCombatRig (Node2D, scale = display_scale = 0.378)
├── VFXBehindLayer (Node2D, z_index = -1)
└── UnifiedCharacterGroup (CanvasGroup, z_index = 0, use_mipmaps = true, fit/clear_margin = 64.0) [Pasada 2]
    ├── DecoupledHeadUnderMount (Node2D, z_index = 0)  [9 Sprite2D, head_layer_pass = 1]
    ├── BodyPivot (Node2D, z_index = 0)
    │   ├── BodyView_S .. BodyView_SW (8x Node2D)
    │   │   ├── Skeleton2D (18 Bone2D)
    │   │   └── Meshes (Node2D, todos los hijos con z_index = 0 ordenados por z_orders)
    │   │       ├── Part_arm_* / Part_leg_* / Part_body_core / Part_pauldron_*
    │   │       └── Part_leg_*_stocking (solo en s, se, e, w, sw; leg_layer_pass = 2 sobre body_core)
    │   └── HeadContactShadow (Sprite2D, z_index = 0, último hijo; oculto en n, ne, nw)
    └── DecoupledHeadMount (Node2D, z_index = 0)       [9 Sprite2D, head_layer_pass = 2]
```

> **Regla crítica de `CanvasGroup`:** todos los nodos dentro de `UnifiedCharacterGroup` deben mantener `z_index = 0`. El orden de dibujado se controla exclusivamente mediante el orden de hijos en `Meshes` (dictado por `z_orders` en `parts_5_meta.json`).

---

## 3. Jerarquía de Huesos (18 Huesos) y Métricas Base

Cada vista `s, se, e, ne, n, nw, w, sw` define sus pivotes y `rest_rots` en `combat_assets/valentina_v2_planar/<dir>/parts_5/parts_5_meta.json`.

### 3.1 Árbol Esquelético (`BONE_PARENTS`)
```text
Pelvis (raíz, en rig_origin)
├── Waist ──► Chest
│             ├── Neck (referencia para DecoupledHead* y HeadContactShadow)
│             ├── Shoulder_R ──► Elbow_R ──► Wrist_R
│             ├── Shoulder_L ──► Elbow_L ──► Wrist_L
│             ├── Pauldron_R
│             └── Pauldron_L
├── Thigh_R ──► Knee_R ──► Ankle_R
└── Thigh_L ──► Knee_L ──► Ankle_L
```

### 3.2 Métricas Calibradas (`body_metrics.json` y `valentina_v2_profile.tres`)
- Lienzo canónico: `520 × 560 du` (`tex_scale = 3` → texturas de origen `1560 × 1680 px`).
- `head_scale_factor`: `0.885` (`head_target_disp_h: 69.03 du`, `head_crown_to_chin_du: 68.17 du`).
- `mounted_total_h_du`: `418.61 du` (`head_to_body_proportion: 6.14`).
- `display_scale`: `0.378` → altura en pantalla a `zoom = 1.0` ≈ `158.2 px`.
- `head_outline_width_px`: `4.0` (`sdf_pad_px = 32.0`).

### 3.3 Órdenes Z y Particularidades por Vista (`parts_5_meta.json`)
- **En `s` (Frente):** `leg_l(0) < leg_r(1) < body_core(2) < arm_l(3) < arm_r(4) < pauldron_l(5), pauldron_r(5)`.
- **En `se` / `ne` (Diagonales derechas):** `arm_l(0) < leg_l(1) < leg_r(2) < body_core(3) < arm_r(4) < pauldron_l(5), pauldron_r(5)`. (`sw`/`nw` invierten `R`/`L`).
- **En `e` (Perfil derecho):** `leg_l(0) < arm_l(1) < pauldron_l(2) < leg_r(3) < body_core(4) < arm_r(5) < pauldron_r(6)`. (`w` invierte `R`/`L`).
  - `arm_l` en `e` (`arm_r` en `w`) es el brazo trasero medial pre-oscurecido (`REAR_DEPTH_DARKEN_FACTOR = 0.85`), con pivotes propios independientes.
  - `pauldron_l` en `e` (`pauldron_r` en `w`) es placeholder transparente `12×12` oculto detrás del torso.
  - `leg_l` en `e` (`leg_r` en `w`) comparte textura con la pierna frontal y se separa térmicamente vía uniforme `leg_depth_phase` (`0.65` frontal / `-0.75` trasera).
- **En `n` (Espalda):** `arm_r(0) < leg_r(1) < leg_l(2) < arm_l(3) < body_core(4) < pauldron_r(5), pauldron_l(5)`.
  - **Atención anatómica en `n`:** `Shoulder_R` está en `+X` (derecha de pantalla) y `Shoulder_L` en `-X` (izquierda de pantalla), al contrario que en `s`.
- **Overlays de medias (`Part_leg_*_stocking`):** `PlanarRigMeshBuilder` duplica las mallas de pierna con `leg_layer_pass = 2` justo encima de `body_core` en `s` (`leg_r/l`), `se`/`e` (`leg_r`) y `sw`/`w` (`leg_l`), recortado en shader al cuff superior (`UV.y ∈ [0.25, 0.48]` y `raw_mask.a`).

---

## 4. Inventario Completo de Máscaras y Texturas Disponibles

Ubicación base del asset pack: [`sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/`](../sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/)

### 4.1 Piezas de Cuerpo (`<dir>/parts_5/` — 28 archivos por vista × 8 vistas)

Para las 7 piezas (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`, `pauldron_r`, `pauldron_l`):

| Archivo | Uso Actual | Canales / Formato | Cómo aprovecharlo al re-animar |
|---|---|---|---|
| `<part>.png` | **GPU Pasada 1** (`TEXTURE`, mipmaps + aniso) | RGBA sRGB pre-saneado con Voronoi bleed en alfa 0. | Textura albedo base; ya incluye underlap geodésico (`10–14 px`) para rotación articular sin grietas. |
| `<part>_id_mask.png` | **GPU Pasada 1** (`id_mask_tex`, mipmaps) | `R`=acentos carmesí/emisivos<br>`G`=armadura/paneles<br>`B`=traje oscuro<br>`A`=medias nylon (en piernas)<br>`1-(R+G+B+A)`=piel | Permite animar efectos por material (ej. pulso emisivo en `mask.r`, brillo de armadura `mask.g`, o reacciones localizadas por zona). |
| `<part>_normal_depth.png` | **GPU Pasada 1** (`normal_depth_tex`, mipmaps) | `RGB`=normal 2.5D tangente (`0.5, 0.5, 1.0` neutro)<br>`A`=profundidad `80..239` (normalizada `0..1`) | Permite sombreado dinámico direccional al rotar/inclinar el rig, oclusión por profundidad y parallax 2.5D (`depth_parallax_px`). |
| `<part>_ilm_mask.png` | **GPU Pasada 1** (`ilm_mask_tex`, mipmaps, `has_ilm_mask = true`) | `R`=especularidad metal/nylon<br>`G`=shadow bias / AO fija (`<0.25` sombra cel permanente, `>0.85` piel protegida)<br>`B`=peso de rim-light<br>`A`=emisivo/glow | Control artístico estilo ArcSys/Guilty Gear de corte cel, AO en pliegues, brillo metálico/nylon y protección de piel/rostro. |
| `<limb>_anim_mask.png` *(arm_r/l, leg_r/l)* | **CPU Skinning** (`use_mipmaps = false`) | `R`=peso hueso proximal (`Shoulder`/`Thigh`)<br>`G`=peso bisagra (`Elbow`/`Knee`)<br>`B`=peso distal (`Wrist`/`Ankle`)<br>`A`=**`seam_fade` horneado en Python** | **RGB activo** para pesos de `Polygon2D` en `PlanarRigMeshBuilder._bind_parts5_weights`. **Nota:** el canal `A` (`seam_fade`) está disponible en la textura pero aún no se consume en shader/CPU. |
| `body_core_secondary_mask.png` | **GPU Pasada 1** (`secondary_jiggle_mask_tex`, sin mipmaps) | `R`=zona blanda izquierda<br>`G`=zona blanda derecha<br>*(busto en `s/se/sw/e/w`; glúteos en `n/ne/nw`)* | Ya cargada en `body_core_mat` (`enable_secondary_jiggle = true`). Solo requiere alimentar `secondary_jiggle_l_px` / `secondary_jiggle_r_px` para respiración de busto o física secundaria en busto/glúteos. |
| `body_core_pauldron_mask.png` | **GPU Pasada 1** (`pauldron_mask_tex`, sin mipmaps) | Escala de grises (`R`): área bajo hombrera sobre `body_core`. | Activa (`has_pauldron_mask = true`). Proyecta sombra de contacto de hombreras sobre el torso según `light_dir_2d`. |
| `parts_5_meta.json` | **CPU Rig Builder** | `rig_origin`, `neck_anchor`, `z_orders`, `rects`, `bones` | Fuente de verdad de pivotes y `rest_rots` de los 18 huesos. |

### 4.2 Cabezas Desacopladas (`heads/` — 45 texturas + `heads_metadata.json`)

Claves disponibles: `head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side_l`, `head_back_r`, `head_back_l`, `head_back` (+ alias `head_side`).

| Archivo | Uso Actual | Canales / Formato | Cómo aprovecharlo al re-animar |
|---|---|---|---|
| `<head>.png` | **GPU Pasada 1** (`TEXTURE`, mipmaps) | RGBA `0.885x` calibrado (`HEAD_PAD_PX = 24`). | Se instancia doble: `DecoupledHeadUnderMount` (`head_layer_pass = 1`) y `DecoupledHeadMount` (`head_layer_pass = 2`). |
| `<head>_id_mask.png` | **GPU Pasada 1** (`id_mask_tex`, mipmaps) | `R`=acentos (monóculo)<br>`G`=accesorios/armadura<br>`B`=**cuello inferior (`is_collar_blue`, Pass 1 bajo torso)**<br>`A`=cabello (`is_hair`)<br>`1-(R+G+B+A)`=piel facial | Separa automáticamente cuello detrás del torso vs rostro/cabello por delante en `head_layer_pass = 1/2`. **Invariante:** al regenerar ID de cabezas, preservar siempre el canal `B` del cuello (`ingest_piece_mask_sheets.py` lo hace automáticamente). |
| `<head>_normal_depth.png` | **GPU Pasada 1** (`normal_depth_tex`, mipmaps) | `RGB`=normal 2.5D facial/pelo (óvalo anime suave)<br>`A`=profundidad | Iluminación 2.5D + parallax + rim cónico en cara y mechones. |
| `<head>_ilm_mask.png` | **GPU Pasada 1** (`ilm_mask_tex`, mipmaps, `has_ilm_mask = true`) | `R`=Angel Ring/spec pelo<br>`G`=AO bajo mentón/flequillo vs rostro protegido<br>`B`=peso rim<br>`A`=monóculo emisivo | Control ArcSys de rostro limpio, sombra bajo mentón/nuca, Angel Ring en pelo y glow en monóculo. |
| `<head>_hair_jiggle_mask.png` | **Cargada en GPU** (`secondary_jiggle_mask_tex`, sin mipmaps) | `R` / `G` = zonas reactivas de mechones de cabello | **Lista para usar:** actualmente desactivada (`enable_secondary_jiggle = false`, offset `ZERO`). Al reconstruir física capilar, activar en **ambos** (`_head_data` y `_head_under_data`) sincronizados. |
| `<head>_outline_sdf.png` | **GPU Pasada 1** (`outline_sdf_tex`, sin mipmaps) | Campo de distancia firmado (`sdf_pad_px = 32.0`, `head_outline_width_px = 4.0`) | Dibuja contorno interno nítido de cabeza/pelo independiente de la escala (`compute_head_sdf_ink`). |
| `heads_metadata.json` | **CPU Rig Builder** | `_outline_pad_px`, `disp_size`, `neck_pivot_px`, `sprite_offset` | Define el pivote exacto del cuello para evitar bamboleo al rotar `_head_anchor`. |

### 4.3 Máscaras Fuente Offline (`source_refs/valentina_v2_8dir/05_mask_ai_workspaces/`)

Para re-generar o ajustar bordes/segmentación con [`build_valentina_v2_rig_assets.py`](../sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py):
- `01_parts_5_despiece/split_results/*_parts5_mask.png` — Despiece de las 5/7 piezas base.
- `02_id_mask_bodies/split_results/*_id_mask.png` — ID de materiales de cuerpo completo.
- `03_id_mask_heads/split_results/head_*_id_mask.png` — ID de materiales de las 8 cabezas.
- `04_limb_anim_masks/split_results/*_limb_segments.png` — Regiones proximal/bisagra/distal de entrada al solucionador armónico.
- `05_secondary_jiggle_masks/split_results/*_secondary_jiggle_mask.png` — Busto (`s/se/sw`) y glúteos (`n/ne/nw`).
- `manual_fix_overlays/` — Fixes de mentón (`01`), glúteos perfil (`02`), brazo trasero (`03`), caps (`04`), hombreras (`06`/`07`) y cuellos HD (`07_torso_neck_regen_16x9`).
- `06_piece_mask_regen/` — Pipeline HQ directo sobre piezas finales calibradas (`export_piece_mask_sheets.py` + `ingest_piece_mask_sheets.py --kind <id|normal|ilm>`): 7 hojas estándar (`5 × 16:9` en `2560×1440` + `2 × 1:1` en `2048×2048`), prompts anti-outline (`PROMPT_A/B/C_*.md`), auditorías visuales (`audit_id/normal/ilm.png`) y espejado automático `SE→SW`, `E→W`, `NE→NW` (`L↔R` + `Nx = -Nx` en normales).

---

## 5. Hooks de Shader y Configuración Disponibles para Re-Animación

### 5.1 Uniformes Listos en Pasada 1 (`pilot_rig_stylizer.gdshader`)
- **Deformación 2.5D en vértice (`rig_perspective_25d.gdshaderinc`):**
  - `persp_mode` (`0=Neutro`, `1=Extremidad 2-seg`, `2=Torso body_core`).
  - `persp_anchors_root_mid`, `persp_anchors_tip_piv`, `persp_params_a/b/c` (escorzo con piso Jacobiano `det(J) >= 0.22`, conicidad, trapecio de torso, torsión `yaw_twist`).
  - `bone_chain_angles`, `joint_flexion`, `joint_v_coord`, `fold_inner_side` (rotación normal cilíndrica RNM + cuña Mignola en codos/rodillas).
  - `caster_capsule_ab`, `caster_capsule_radius_height`, `caster_head_ellipse`, `caster_head_height` (sombras analíticas ILM proyectadas sobre `body_core`).
- **Jiggle y Parallax:**
  - `enable_secondary_jiggle`, `secondary_jiggle_l_px`, `secondary_jiggle_r_px` (desplazamiento UV en píxeles de textura guiado por `secondary_jiggle_mask_tex`).
  - `banking_tilt_2d`, `depth_parallax_px` (desplazamiento sutil por mapa de profundidad).
- **Reloj y FX:**
  - `q_time` (tiempo cuantizado para pulsos/brillos escalonados).
  - `transition_fx_mode` (`0..3`), `transition_fx_strength`, `transition_turn_dir`, `holo_sweep_pos/dir`, `hit_flash`.
- **Máscara ILM (ArcSys / Guilty Gear):**
  - `ilm_mask_tex`, `has_ilm_mask`, `ilm_shadow_bias_strength`, `ilm_spec_strength`, más `debug_view_mode = 6` (Inspector Rayos-X ILM).

### 5.2 Uniformes Listos en Pasada 2 (`pilot_rig_pass2.gdshader` sobre `UnifiedCharacterGroup`)
- `smear_strength`, `smear_dir`, `smear_tint` (smear direccional unificado sobre la silueta completa).
- `holo_sweep_pos`, `holo_sweep_strength`, `holo_sweep_dir` (barrido holográfico).
- `impact_frame_phase` (`0..2`), `impact_center_uv` (ya conectado en `PlanarCombatRig.trigger_impact_frame`).
- `outer_outline_width_px`, `outer_outline_strength`, `outer_outline_tint_mix`, `zoom_scale`, `light_dir_2d` (ya activos).

### 5.3 Límites Articulares Calibrados (Referencia en `valentina_v2_anim_config.tres`)

Valores en radianes validados para no abrir costuras ni generar intersecciones en las 8 vistas (familias `S`, `SE/SW`, `E/W`, `NE/NW`, `N`; vistas izquierdas `sw/w/nw` espejan `R ↔ L` y niegan signo):

| Familia | `Shoulder_R` | `Shoulder_L` | `Elbow_R` | `Elbow_L` | `Thigh_R/L` | `Knee_R/L` | `Ankle_R/L` |
|---|---|---|---|---|---|---|---|
| **`S`** | `[-0.04, 0.14]` | `[-0.14, 0.04]` | `[-0.06, 0.10]` | `[-0.10, 0.06]` | `[-0.045, 0.045]` | `[-0.10, 0.10]` | `[-0.22, 0.22]` |
| **`SE` (`SW`)** | `[-0.045, 0.12]` | `[-0.12, 0.045]` | `[-0.08, 0.08]` | `[-0.10, 0.08]` | `[-0.028, 0.028]` | `[-0.06, 0.24]` | `[-0.22, 0.36]` |
| **`E` (`W`)** | `[-0.68, 0.26]` | `[-0.56, 0.24]` | `[-0.84, 0.07]` | `[-0.68, 0.07]` | `[-0.38, 0.24]` | `[0.00, 0.66]` | `[-0.26, 0.42]` |
| **`NE` (`NW`)** | `[-0.34, 0.14]` | `[-0.14, 0.30]` | `[-0.44, 0.12]` | `[-0.14, 0.30]` | `[-0.09, 0.09]` | `[-0.09, 0.45]` | `[-0.26, 0.26]` |
| **`N`** | `[-0.14, 0.04]` | `[-0.04, 0.14]` | `[-0.10, 0.06]` | `[-0.06, 0.10]` | `[-0.045, 0.045]` | `[-0.10, 0.10]` | `[-0.26, 0.26]` |

> **Columna vertebral recomendada:** `Pelvis ∈ [-0.12, 0.12]`, `Waist/Chest ∈ [-0.175, 0.175]`, `Neck ∈ [-0.28, 0.28]`.
> **Hombreras (`Pauldron_R/L`):** al animar `Shoulder_R/L`, acompañar `Pauldron_R/L` a ~40–58% de la rotación del hombro para sellar la sisa sin flotar fuera del torso.
> **Vista `N`:** recordar que en `n` la lateralidad anatómica está invertida en pantalla (`Shoulder_R` en `+X`, `Shoulder_L` en `-X`); los brazos deben abrir hacia afuera sin cruzar el torso ni la cadera.

---

## 6. Laboratorio de Animación 2.5D (`planar_anim_test.tscn`) & Arquitectura Escalable

### 6.1 Punto de Entrada, Controles y Regla de Aislamiento
- **Escena dedicada:** `sandbox/pilot_rig_lab/proto/planar_anim_test.tscn` + `planar_anim_test.gd`.
- **Disposición y Controles:** Los 8 rigs se muestran en **brújula cardinal** (`N, NE, E, SE, S, SW, W, NW`, `COMPASS_RADIUS = 290 px`), con **rueda del ratón** para zoom (`0.45x–4.5x`), **click + arrastrar** para paneo libre, **`Espacio`** para pausar, **`R`** para centrar/reiniciar, selector de modo (`Huesos + 2.5D` / `Solo Huesos` / `Solo 2.5D`), slider de amplitud y checkbox para ciclar las cabezas válidas de cada vista (`ALLOWED_HEADS_BY_BODY_8DIR`).
- **Control manual limpio:** Siempre inicializar cada rig con:
  ```gdscript
  _rig.set_static_inspection(true, view_key, head_key)
  _rig.calibration_manual_pose = true
  ```
  - **Importante sobre `Pelvis` vs `BodyPivot`:** `PlanarCombatRig._process()` resetea `BodyPivot.position = Vector2.ZERO` en modo inspección; para flotar el cuerpo completo en `Y/X` sin pelear con el rig, animar el hueso raíz **`Pelvis.position`** (toda la jerarquía y `DecoupledHeadMount` lo siguen automáticamente).
- **Regla anti-regresión:** No editar `planar_rig_perspective_controller.gd` ni `planar_rig_animator.gd` para prototipos experimentales (deben mantener `persp_mode = 0` para que `test_pilot_rig_lab.tscn` pase).

### 6.2 Contrato de Máscaras de Zona 2.5D (`persp_zone_mask`)
Uniformes en `pilot_rig_stylizer.gdshader`: `use_persp_zone_mask` (`bool`) y `persp_zone_mask` (`sampler2D`).
- **Inventario actual (8 vistas × 2 piernas = 16 máscaras):** `sandbox/pilot_rig_lab/proto/leg_{r,l}_{n,ne,e,se,s,sw,w,nw}_persp_mask.png`.
- **Canal `R`:** Cadena longitudinal (`0.05` raíz/muslo → `0.48` rodillera → `0.50` articulación → `0.72` pantorrilla → `0.96..1.0` bota).
- **Canal `G`:** Rigidez (`1.0` armadura rígida sin aplastamiento ni `patella_bulge`, `0.0` articulación blanda).
- **Canal `B`:** Sesgo de profundidad intrínseca (`0.88` rodillera al frente, `0.75` espinillera, `0.28` pantorrilla trasera, `0.15` tacón atrás).
- **Canal `A`:** ID semántico de grupo.

**Invariantes obligatorios (lecciones aprendidas):**
1. **Relleno Voronoi 100% del rectángulo:** La malla de cada pieza es un grid (`10×24` en piernas) con vértices fuera de la silueta. Toda `*_persp_mask.png` debe erosionar `2 px` el borde *antialiased* antes de cuantizar los colores y rellenar **todo** el rectángulo por Voronoi (`distance_transform_edt`), nunca dejar `R = 0.0` en el fondo (de lo contrario los vértices exteriores de la punta del pie se asignan al muslo y estiran triángulos negros).
2. **Pivote distal en tobillo/muñeca (`p_tip_proj`):** Toda compresión/retroceso del pie (`distal_amp`) pivota alrededor de `p_tip_proj` (con `foot_recede_shift` simétrico vía `-sign(p_root.x)`), nunca escalando `axial_2` desde la rodilla.
3. **Sin onda UV interna:** `out_uv_relief_shift` debe permanecer en `0.0` para evitar artefactos tipo "columna de calor".

### 6.3 Estructura Planificada para Nuevas Aventuras de Animación (`anim_lab/`)
Para escalar a múltiples estados (`Idle`, `Dash`, `AirBrake`, `Strafe`, `Recoil`) sin convertir `planar_anim_test.gd` en un archivo monolítico:
1. **Clips desacoplados (`sandbox/pilot_rig_lab/anim_lab/clips/`):** cada animación hereda de una interfaz mínima (`BaseAnimLabClip`: `get_id()`, `get_supported_views()`, `evaluate(ctx)`), recibiendo `anim_time`, `amp_scale`, `view_key`, `bones`, `rest_rots`, `rest_pos`, `polys` y `zone_masks`.
2. **Registro de Máscaras por Vista/Pieza (`anim_lab/masks/<view>/`):** al migrar/ordenar máscaras, mover las `leg_{r,l}_<view>_persp_mask.png` desde `proto/` y actualizar la ruta en `planar_anim_test.gd`.
3. **HUD de Laboratorio:** selector de **Clip** + **Modo (`Huesos + 2.5D` / `Solo Huesos` / `Solo 2.5D`)** + **Amplitud** + **Rotar cabezas válidas** + **Pausa/Reiniciar**.
4. **Pipeline de creación de máscaras (para brazos o nuevas piezas):** empaquetar piezas en lámina `1:1` o `16:9` → generar máscara plana de 9 colores sobre `#000000` (sin outlines internos) → auditar `IoU >= 0.95` → compilar a RGBA Voronoi → espejar horizontalmente para el lado opuesto (`R ↔ L`).
5. **Protocolo anti-falsos positivos de filtro de contenido en IA generativa (piezas aisladas con piel):**
   - **Problema:** Los clasificadores automáticos de generadores externos suelen bloquear piezas aisladas (especialmente piernas/muslos de corte alto o vistas traseras `NE`) por falsos positivos de *skin-tone ratio* + corte de traje, incluso si se colocan junto a cabeza/torso o ensambladas en turnaround.
   - **Solución validada (recolor temporal + contorno homogéneo + restauración):**
     1. Cubrir temporalmente las zonas de piel expuesta (muslo superior) usando `*_id_mask.png` (`skin = (0,0,0,0)`) con el tono gris carbón del traje táctico preservando la luminancia, dejando la pieza como armadura/traje completo sobre fondo `#FFFFFF` `1:1`.
     2. Pre-cerrar y homogeneizar el contorno exterior (`~4.2 px` `#140A0A` vía *distance transform*) antes de enviar a la IA para que no deje bordes cortados en cúpulas de articulación.
     3. Usar un **prompt neutro de asset mecánico/táctico** (evitando palabras gatillo como *thigh-high*, *stockings*, *leotard*, *bare*) exigiendo trazo exterior continuo y uniforme (`#000000`) de grosor constante.
     4. Al reingresar el PNG/JPG limpio: extraer alfa por `cv2.floodFill(..., FLOODFILL_FIXED_RANGE)` + *defringe*, restaurar el cel-shading de piel original (`lit [236,185,171] RGB`, `shadow [169,133,139] RGB`), generar el par trasero con `REAR_DEPTH_DARKEN_FACTOR = 0.85` y espejar horizontalmente para la vista opuesta (`E ↔ W`).
6. **Base canónica de 8 cabezas con cuello (`heads_v2_base/`) y separación de capas:**
   - **Fuente permanente:** `sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/heads_v2_base/` (`heads_v2_color_4x.png` generado con Upscayl `digital-art-4x` a `4096×2284` + `heads_v2_id_mask.png`). `heads_builder.py` (`build_heads_pack`) prioriza automáticamente esta base al regenerar cabezas.
   - **Extracción y segmentación guiada por tinta (por defecto en futuros rebuilds):**
     - Remoción de fondo vía `floodFill(..., loDiff=70)` + banda de borde `dist_in <= 4.0` en tinta oscura `[14, 10, 12]`.
     - `_segment_v2_head_id_ink_guided()` usa las líneas negras de tinta (`gray < 80`, excluyendo el rojo del monóculo) como barreras 4-conexas para clasificar cada celda cel-shaded con semillas validadas por color RGB y `cv2.watershed` en celdas abiertas/mixtas (p. ej. transición mejilla-cuello en perfiles). Los píxeles de tinta heredan etiqueta por prioridad (`monóculo > pelo > piel_cara > cuello_azul`) para conservar el outline del cabello sin arrastrar piel del cuello, y el cuello (`cls_map == 2`) se restringe a su componente conexa principal.
     - `_carve_cylindrical_neck_v2()` restringe la propagación perimetral azul a `yy >= ink_start_y & is_blue`, y `_fill_interior_alpha_holes()` rellena cualquier micro-hueco interno en el canal alfa tras el recorte y el reescalado a `240 px`.
   - **Cuello detrás del torso vs Cabeza encima:** el canal azul (`#0000FF`) de `*_id_mask.png` marca el cuello desnudo para dividir `head_layer_pass == 1` (`DecoupledHeadUnderMount`, menor orden que `body_core`) vs `head_layer_pass == 2` (`DecoupledHeadMount`, sobre `body_core`). En `pilot_rig_stylizer.gdshader`, `hair_cov = raw_mask.a` (sin dilatación de 4 px para no arrastrar piel del cuello al borde del cabello en Pass 2) y tras leer `is_collar_blue` se limpia `mask.b = 0.0` cuando `is_head_part` es verdadero para que el cuello conserve sombreado de piel y no se recoloree como traje oscuro.
