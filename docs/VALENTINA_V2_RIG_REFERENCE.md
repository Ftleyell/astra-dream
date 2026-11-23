# Referencia Completa del Rig Limpio — Valentina v2 (8-Dir Nativo)

> **Única Fuente de Verdad Runtime:** Este documento refleja el estado actual real del rig **Valentina v2** (`valentina` v1 eliminado). Para el índice de milestone y hoja de ruta, ver [`docs/VALENTINA_V2_MILESTONE_STATUS.md`](VALENTINA_V2_MILESTONE_STATUS.md); para reglas rápidas de edición y tabla contractual sin relecturas, consultar [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md).
> **Estado actual:** Rig exclusivo de **Valentina v2 (8-Dir Nativo)**. Los controladores legacy (`planar_rig_animator.gd`, `planar_rig_perspective_controller.gd`, `planar_rig_secondary_physics.gd`) permanecen purgados en rest pose; sobre ese baseline limpio operan el **enrutado 8-dir nativo + transiciones snappy (Modos 4/5/6 + whip cervical)**, el **pipeline de animación data-driven `.tres`** (Pose Base Zero-G, Idle 3-capas, Locomoción/Freno, Kiting 360°, Giros 2.5D y Jiggle Busto/Glúteos — Sección 6), el **Rig Facial Vivo** (`VALENTINA_V2_FACE_RIG_REFERENCE.md`), las **Alas Psíquicas Base** (`VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`) y el **Power-Up Sandevistan** (`VALENTINA_PROPULSION_VFX_SPEC.md`).
> **Escenas de Laboratorio:** [`planar_combat_rig_proto.tscn`](../sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn) · [`planar_shader_lab.tscn`](../sandbox/pilot_rig_lab/shader_lab/planar_shader_lab.tscn) (A/B Shaders) · [`planar_anim_test.tscn`](../sandbox/pilot_rig_lab/proto/planar_anim_test.tscn) (Animación 2.5D) · [`valentina_face_lab.tscn`](../sandbox/pilot_rig_lab/face_lab/valentina_face_lab.tscn) (Rig Facial Vivo) · [`valentina_vfx_lab.tscn`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn) (Alas + VFX Sandevistan)
> **Backup Inmutable Baseline:** [`backups/valentina_v2_clean_baseline/`](../sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/) + [`restore_valentina_v2_baseline.ps1`](../sandbox/pilot_rig_lab/backups/restore_valentina_v2_baseline.ps1) + tag Git `valentina-v2-clean-baseline`
> **Suites de Verificación:** `tools/run_tests.ps1 -Test "pilot_rig_lab"` · `-Test "valentina_face_lab"` · `-Test "valentina_vfx_lab"`

---

## 1. Qué Está Activo vs Qué Fue Purgado

| Sistema | Estado | Archivo / Módulo | Notas para reconstrucción |
|---|---|---|---|
| **Enrutado 8-Dir Cuerpo + Cabeza** | **ACTIVO** | [`planar_rig_view_router.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd) | 8 vistas nativas (`s, se, e, ne, n, nw, w, sw`, `body_flip_x = false`) + 8 cabezas asimétricas (`head_flip_x = false`), cono cervical `±65°`, histéresis de giro y backpedal (`BACKPEDAL_ENTER_DOT_8DIR = 0.56`, `EXIT = 0.68`). |
| **Animación de Cambio de Orientación** | **ACTIVO** | [`planar_rig_transition_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_transition_controller.gd), [`planar_rig_wings_vfx.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_wings_vfx.gd) | Modos snappy 4/5/6 (`WHIP_SNAP_AFTERIMAGE`, `MICRO_FLASH_SNAP`, `HOLO_SNAP_FAST`): `snap_scale_xy` en `BodyPivot`/`HeadAnchor`, smear en Pasada 2, flash/holo-sweep en Pasada 1, afterimage de giro (`spawn_snap_afterimage`) y micro-snap de cabeza. *(Estela Sandevistan en `vfx_lab/`; alas estandarizadas vía `enable_base_propulsion_wings`)*. |
| **Alas Psíquicas & Propulsión Base (Multi-Piloto)** | **ACTIVO (Opt-In)** | [`valentina_base_propulsion_controller.gd`](../sandbox/pilot_rig_lab/vfx_lab/valentina_base_propulsion_controller.gd), [`pilot_base_propulsion_config.gd`](../sandbox/pilot_rig_lab/data/pilot_base_propulsion_config.gd) | Enlazado vía `PilotRigProfile` (`base_propulsion_config`, `wings_assets_subdir`). Monta `WingsUnderMount`/`WingsOverMount` en `UnifiedCharacterGroup` (`z_index = 0`) + capas HDR externas (`WingsGlowUnder`/`WingsGlowOver`), apertura lineal cohesiva, empuje Newtoniano y 12 cintas rojas. Ver [`docs/VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md). |
| **Montaje de Mallas y Pesos** | **ACTIVO** | [`planar_rig_mesh_builder.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd) | Construye `Skeleton2D` (18 huesos), mallas `Polygon2D`, pesos desde `*_anim_mask.png`, blends de cadera/hombro/hombrera y cabezas en 2 pasadas (`head_layer_pass = 1/2`). |
| **Materiales, Recolor, Iluminación 2.5D, Outlines, Hit Flash / Impact Frame** | **ACTIVO** | [`planar_rig_material_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_material_controller.gd) | Skins (10), Cabello (10), Estilos (3: `00_original`, `01_valentina_definitive` ArcSys Cosmos y `02_valentina_razor_sharp`), tinta interna Ink SDF 2×, `use_normal_depth`, Pasada 2 unificada, rayos-X (`debug_view_mode = 0..8`), `leg_depth_phase` estático en `e`/`w`. |
| **Animación Esquelética Procedural** | **PURGADO (Rest Pose)** | [`planar_rig_animator.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_animator.gd) | Mantiene `BodyPivot.position = ZERO`, `rotation = 0` y los 18 `Bone2D` en `rest_rots` (`BodyPivot.scale` recibe únicamente `snap_scale_xy` durante giros). Conserva enum `AnimState`, `ANIM_BONES`, `step_spring()` y lectura de límites `*_limits` en `.tres`. |
| **Perspectiva 2.5D Post-Skinning** | **PURGADO (`persp_mode = 0`)** | [`planar_rig_perspective_controller.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_perspective_controller.gd) | Fuerza `persp_mode = 0`, `poly.position = ZERO`, `bone_chain_angles = ZERO`, `joint_flexion = 0`, `Pauldron_R/L.position = rest_pos`, `Bone2D.scale = ONE`. Solo conserva `leg_depth_phase` estático en `e`/`w` (`0.65` / `-0.75`). |
| **Física Secundaria (Jiggle / Whiplash)** | **PURGADO** | [`planar_rig_secondary_physics.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_secondary_physics.gd) | Fija `secondary_jiggle_l_px = ZERO` y `secondary_jiggle_r_px = ZERO` en `body_core` y cabezas (`enable_secondary_jiggle = false` en cabezas; textura cargada y lista en `body_core`). |
| **Resortes de Cabeza / Pose Latch 15 FPS** | **PURGADO** | [`planar_combat_rig.gd`](../sandbox/pilot_rig_lab/proto/planar_combat_rig.gd) | `_head_anchor` y `_head_under_anchor` anclados a `Neck.global_position` (`rotation = 0`, `scale = snap_scale_xy / head_micro_snap_scale`), `q_time = 0`, `banking_tilt_2d = ZERO`. |
| **Valentina v1 (2-Dir + Flip-H)** | **ELIMINADO** | — | Eliminados `pilots/valentina/` y `combat_assets/` heredados. Skins promovidas a [`data/pilots/valentina_v2/skins/`](../data/pilots/valentina_v2/skins/). |

---

## 2. Topología del SceneTree en Runtime

```text
PlanarCombatRig (Node2D, scale = display_scale = 0.378)
├── BasePropulsionWings (ValentinaBasePropulsionController, z_index = -2) [opt-in]
├── WingsGlowUnder (Node2D, z_index = -1) [opt-in HDR Bloom]
├── VFXBehindLayer (Node2D, z_index = -1)
├── UnifiedCharacterGroup (CanvasGroup, z_index = 0, use_mipmaps = true, fit/clear_margin = 64.0) [Pasada 2]
│   ├── WingsUnderMount (Node2D, z_index = 0)        [Alas detrás del torso: s, se, sw, ala lejana e/w]
│   ├── DecoupledHeadUnderMount (Node2D, z_index = 0)  [9 Sprite2D, head_layer_pass = 1]
│   ├── BodyPivot (Node2D, z_index = 0)
│   │   ├── BodyView_S .. BodyView_SW (8x Node2D)
│   │   │   ├── Skeleton2D (18 Bone2D)
│   │   │   └── Meshes (Node2D, todos los hijos con z_index = 0 ordenados por z_orders)
│   │   │       ├── Part_arm_* / Part_leg_* / Part_body_core / Part_pauldron_*
│   │   │       └── Part_leg_*_stocking (solo en s, se, e, w, sw; leg_layer_pass = 2 sobre body_core)
│   │   └── HeadContactShadow (Sprite2D, z_index = 0, último hijo; oculto en n, ne, nw)
│   ├── WingsOverMount (Node2D, z_index = 0)         [Alas sobre espalda bajo cabeza: n, ne, nw, ala cercana e/w]
│   └── DecoupledHeadMount (Node2D, z_index = 0)       [9 Sprite2D, head_layer_pass = 2]
└── WingsGlowOver (Node2D, z_index = 1) [opt-in HDR Bloom]
```

> **Regla crítica de `CanvasGroup`:** todos los nodos dentro de `UnifiedCharacterGroup` deben mantener `z_index = 0`. El orden de dibujado se controla exclusivamente mediante el orden de hijos en `Meshes` (dictado por `z_orders` en `parts_5_meta.json`).

---

## 3. Jerarquía de Huesos (18 Huesos) y Métricas Base

Cada vista `s, se, e, ne, n, nw, w, sw` define sus pivotes y `rest_rots` en `assets/pilots/valentina_v2/planar/<dir>/parts_5/parts_5_meta.json`.

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

Ubicación base del asset pack: [`assets/pilots/valentina_v2/planar/`](../assets/pilots/valentina_v2/planar/)

### 4.1 Piezas de Cuerpo (`<dir>/parts_5/` — 28 archivos por vista × 8 vistas)

Para las 7 piezas (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`, `pauldron_r`, `pauldron_l`):

| Archivo | Uso Actual | Canales / Formato | Cómo aprovecharlo al re-animar |
|---|---|---|---|
| `<part>.png` | **GPU Pasada 1** (`TEXTURE`, mipmaps + aniso) | RGBA sRGB pre-saneado con Voronoi bleed en alfa 0. | Textura albedo base; ya incluye underlap geodésico (`10–14 px`) para rotación articular sin grietas. |
| `<part>_id_mask.png` | **GPU Pasada 1** (`id_mask_tex`, mipmaps) | `R`=acentos carmesí/emisivos<br>`G`=armadura/paneles<br>`B`=traje oscuro<br>`A`=medias nylon (en piernas)<br>`1-(R+G+B+A)`=piel | Permite animar efectos por material (ej. pulso emisivo en `mask.r`, brillo de armadura `mask.g`, o reacciones localizadas por zona). |
| `<part>_normal_depth.png` | **GPU Pasada 1** (`normal_depth_tex`, mipmaps) | `RGB`=normal 2.5D tangente (`0.5, 0.5, 1.0` neutro)<br>`A`=profundidad `80..239` (normalizada `0..1`) | Permite sombreado dinámico direccional al rotar/inclinar el rig, oclusión por profundidad y parallax 2.5D (`depth_parallax_px`). |
| `<part>_ilm_mask.png` | **GPU Pasada 1** (`ilm_mask_tex`, mipmaps, `has_ilm_mask = true`) | `R`=especularidad metal/nylon<br>`G`=shadow bias / AO fija (`<0.25` sombra cel permanente, `>0.85` piel protegida)<br>`B`=peso de rim-light<br>`A`=emisivo/glow | Control artístico estilo ArcSys/Guilty Gear de corte cel, AO en pliegues, brillo metálico/nylon y protección de piel/rostro. |
| `<part>_ink_sdf.png` | **GPU Pasada 1** (`ink_sdf_tex`, **sin mipmaps**, `has_ink_sdf = true`) | SDF con signo 8-bit a **resolución `2×`** (`±8 px` en texels nativos, `0.5 = borde exacto del trazo`, horneado desde Upscayl `4×`) | Lineart interno y externo vectorialmente nítido a cualquier zoom (`fwidth`/pantalla), protege trazos (`ink_protect`), alimenta Colored Line Art y Rayos-X `debug_view_mode = 1/3`. **Nunca activar mipmaps.** |
| `<limb>_anim_mask.png` *(arm_r/l, leg_r/l)* | **CPU Skinning** (`use_mipmaps = false`) | `R`=peso hueso proximal (`Shoulder`/`Thigh`)<br>`G`=peso bisagra (`Elbow`/`Knee`)<br>`B`=peso distal (`Wrist`/`Ankle`)<br>`A`=**`seam_fade` horneado en Python** | **RGB activo** para pesos de `Polygon2D` en `PlanarRigMeshBuilder._bind_parts5_weights`. **Nota:** el canal `A` (`seam_fade`) está disponible en la textura pero aún no se consume en shader/CPU. |
| `body_core_secondary_mask.png` | **GPU Pasada 1** (`secondary_jiggle_mask_tex`, sin mipmaps) | `R`=zona blanda izq. / busto (`e/w`)<br>`G`=zona blanda der. / glúteo (`e/w`)<br>*(busto en `s/se/sw`, glúteos en `n/ne/nw`, dual `R=busto / G=glúteo` en `e/w`)* | Ya cargada y activa en `body_core_mat` (`enable_secondary_jiggle = true`), impulsada por `PilotJigglePhysicsConfig` + micro-inclinación normal (`secondary_jiggle_normal_strength`). |
| `body_core_pauldron_mask.png` | **GPU Pasada 1** (`pauldron_mask_tex`, sin mipmaps) | Escala de grises (`R`): área bajo hombrera sobre `body_core`. | Activa (`has_pauldron_mask = true`). Proyecta sombra de contacto de hombreras sobre el torso según `light_dir_2d`. |
| `parts_5_meta.json` | **CPU Rig Builder** | `rig_origin`, `neck_anchor`, `z_orders`, `rects`, `bones`, `part_outlines` | Fuente de verdad de pivotes, `rest_rots` de los 18 huesos y calibración de borde por pieza (`erode_du` transparente + `outline_du` sólido). |

### 4.2 Cabezas Desacopladas (`heads/` — 45 texturas + `heads_metadata.json`)

Claves disponibles: `head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side_l`, `head_back_r`, `head_back_l`, `head_back` (+ alias `head_side`).

| Archivo | Uso Actual | Canales / Formato | Cómo aprovecharlo al re-animar |
|---|---|---|---|
| `<head>.png` | **GPU Pasada 1** (`TEXTURE`, mipmaps) | RGBA `0.885x` calibrado (`HEAD_PAD_PX = 24`); vistas con ojo descubierto horneadas `4× SSAA` con iris neutro **Amatista Profundo**. | Se instancia doble: `DecoupledHeadUnderMount` (`head_layer_pass = 1`) y `DecoupledHeadMount` (`head_layer_pass = 2`), asegurando ojos Amatista estándar tanto en rigs estáticos (`PlanarShaderLab`, `RigCalibrator`, A/B) como en vivo. |
| `<head>_id_mask.png` | **GPU Pasada 1** (`id_mask_tex`, mipmaps) | `R`=acentos (monóculo)<br>`G`=accesorios/armadura<br>`B`=**cuello inferior (`is_collar_blue`, Pass 1 bajo torso)**<br>`A`=cabello (`is_hair`)<br>`1-(R+G+B+A)`=piel facial | Separa automáticamente cuello detrás del torso vs rostro/cabello por delante en `head_layer_pass = 1/2`. **Invariante:** al regenerar ID de cabezas, preservar siempre el canal `B` del cuello (`ingest_piece_mask_sheets.py` lo hace automáticamente). |
| `<head>_normal_depth.png` | **GPU Pasada 1** (`normal_depth_tex`, mipmaps) | `RGB`=normal 2.5D facial/pelo (óvalo anime suave)<br>`A`=profundidad | Iluminación 2.5D + parallax + rim cónico en cara y mechones. |
| `<head>_ilm_mask.png` | **GPU Pasada 1** (`ilm_mask_tex`, mipmaps, `has_ilm_mask = true`) | `R`=Angel Ring/spec pelo<br>`G`=AO bajo mentón/flequillo vs rostro protegido<br>`B`=peso rim<br>`A`=monóculo emisivo | Control ArcSys de rostro limpio, sombra bajo mentón/nuca, Angel Ring en pelo y glow en monóculo. |
| `<head>_ink_sdf.png` | **GPU Pasada 1** (`ink_sdf_tex`, **sin mipmaps**, `has_ink_sdf = true`) | SDF con signo 8-bit a **resolución `2×`** (`±8 px` en texels nativos, `0.5 = borde exacto del trazo`, horneado desde Upscayl `4×`) | Lineart interno y facial/capilar súper nítido a cualquier zoom; reemplaza el umbral de luminancia en Pasada 1 y en Rayos-X "Solo Tinta" (`debug_view_mode = 3`). |
| `<head>_hair_jiggle_mask.png` | **Cargada en GPU** (`secondary_jiggle_mask_tex`, sin mipmaps) | `R`=flequillo / `G`=laterales / `B`=puntas nuca | **Activo** en 3 zonas cuando `enable_face_live = true` (ver [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md)), sincronizado en ambos pases `_head_data` y `_head_under_data`. |
| `<head>_face_live_mask.png` | **GPU Pasada 1** (`face_live_mask_tex`, **sin mipmaps**) | `R`=párpado sup. / `G`=almendra ocular / `B`=cejas / `A`=boca + soldadura cervical | Enlazado automáticamente por `PlanarRigMeshBuilder.build_decoupled_heads`; en modo estático `enable_face_live = false`, `G` protege con Valor HSV el violeta `#421D70` del entintado falso. |
| `<head>_eye_iris.png` *(4 vistas + alias `head_side`)* | **GPU Pasada 1** (`eye_iris_tex`, `LOD 0` + RGSS) | RGBA `128×128` iris 360° **Amatista Profundo** (`#421D70 → #8B5CF6 → #DFC4FF`, pupila `#100816`) | Capa Live2D móvil + micro-glow táctico; ver detalle completo en [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md). |
| `<head>_eye_closed.png` *(4 vistas + alias `head_side`)* | **GPU Pasada 1** (`eye_closed_tex`) | RGBA `256×256` parche de ojo cerrado y pestaña anime alineado | Sustituye al iris en parpadeos completos e impactos `HIT_WINCE`. |
| `<head>_outline_sdf.png` | **GPU Pasada 1** (`outline_sdf_tex`, sin mipmaps) | Campo de distancia firmado (`sdf_pad_px = 32.0`, `head_outline_width_px = 4.0`) | Dibuja contorno interno nítido de cabeza/pelo independiente de la escala (`compute_head_sdf_ink`). |
| `heads_metadata.json` / `eye_live2d_meta.json` | **CPU Rig Builder** | `_outline_pad_px`, `disp_size`, `neck_pivot_px`, `eye_center_uv`, `eye_iris_size_uv`, `"eye_palette": "deep_amethyst"` | Calibra el pivote del cuello y las coordenadas UV de los ojos Amatista en las 5 vistas descubiertas. |

### 4.3 Máscaras Fuente Offline (`source_refs/valentina_v2_8dir/05_mask_ai_workspaces/`)

Para re-generar o ajustar bordes/segmentación con [`build_valentina_v2_rig_assets.py`](../sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py):
- `01_parts_5_despiece/split_results/*_parts5_mask.png` — Despiece de las 5/7 piezas base.
- `02_id_mask_bodies/split_results/*_id_mask.png` — ID de materiales de cuerpo completo.
- `03_id_mask_heads/split_results/head_*_id_mask.png` — ID de materiales de las 8 cabezas.
- `04_limb_anim_masks/split_results/*_limb_segments.png` — Regiones proximal/bisagra/distal de entrada al solucionador armónico.
- `05_secondary_jiggle_masks/split_results/*_secondary_jiggle_mask.png` — Busto (`s/se/sw`) y glúteos (`n/ne/nw`).
- `manual_fix_overlays/` — Fixes de mentón (`01`), glúteos perfil (`02`), brazo trasero (`03`), caps (`04`), hombreras (`06`/`07`) y cuellos HD (`07_torso_neck_regen_16x9`).
- `06_piece_mask_regen/` — Pipeline HQ directo sobre piezas finales calibradas (`export_piece_mask_sheets.py` + `ingest_piece_mask_sheets.py --kind <id|normal|ilm|ink>`): 7 hojas estándar (`5 × 16:9` en `2560×1440` + `2 × 1:1` en `2048×2048`), prompts (`PROMPT_A/B/C/D_*.md`), auditorías visuales (`audit_id/normal/ilm/ink.png`) y espejado automático `SE→SW`, `E→W`, `NE→NW` (`L↔R` + `Nx = -Nx` en normales).
- `07_ink_hq_regen/` — Pipeline iterativo HQ Ink SDF `2×` ([`ink_hq_pipeline.py`](../sandbox/pilot_rig_lab/tools/ink_hq_pipeline.py), `--action export|test|apply --sheet <hoja>`): 13 hojas `1:1` (`2048×2048`, 2–4 piezas grandes por hoja, más `3×3` hombreras) con doble referencia (`inputs_color/` + `inputs_anchor/` a `0.0 px` de deriva), prompts en `PROMPTS_INK_HQ.md`, post-proceso automático **Upscayl `digital-art-4x` → ECC Afín → Flujo Óptico Farneback acotado (`±4.5 px`) → SDF `2×`** (distancias en texels nativos `±8.0`), auditorías de 5 columnas (`audits/*_audit.png`), espejado `SE→SW`, `E→W`, `NE→NW` y sincronización automática de `head_side_ink_sdf.png`. Todos los **65/65** mapas `*_ink_sdf.png` en producción usan este pipeline.

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
- **Máscara ILM y Estilizado Definitivo (`01_valentina_definitive`):**
  - `ilm_mask_tex`, `has_ilm_mask`, `ilm_shadow_bias_strength`, `ilm_ao_strength`, `face_shadow_protect`, más `debug_view_mode = 6` (Inspector Rayos-X ILM).
  - `stylize_enabled`, `cel_strength`, `cel_threshold`, `cel_softness`, `cel_mid_band_strength`, `albedo_de_shade`, `key_light_tint`, `shadow_tint`, `ao_tint`, `skin_shadow_tint`, `sss_skin_color`, `sss_strength`, `color_contrast`, `color_saturation`, `key_light_boost`.
  - Materiales y lineart interno: `armor_spec_strength`, `armor_spec_threshold`, `suit_satin_strength`, `nylon_sheen_strength`, `hair_angel_ring_strength`, `emissive_glow_strength`, `ink_strength`, `ink_color_tint_mix`, `ink_skin_tint`, `ink_cool_tint`, `ink_sdf_tex`, `has_ink_sdf`, `ink_sdf_bias_px`, `ink_sdf_softness`, `normal_rim_strength`, `counter_rim_strength`, `rim_key_color`, `counter_rim_use_skin_accent`, `counter_rim_override_color`.
  - Outline fino por pieza (`part_outlines` en `parts_5_meta.json`): `enable_part_edge_outline`, `part_edge_erode_du` (borde transparente que limpia el borde PNG), `part_edge_outline_du` (contorno sólido hacia afuera), `part_edge_outline_color`, `part_edge_respect_seams`. Base calibrada replicada en las 8 vistas desde `S` (`body_core: erode 0.3 / out 0.3`; extremidades: `erode 1.5 / out 0.2–0.3`; hombreras/cabezas: `enabled = false`).

### 5.2 Uniformes Listos en Pasada 2 (`pilot_rig_pass2.gdshader` sobre `UnifiedCharacterGroup`)
- `smear_strength`, `smear_dir`, `smear_tint` (smear direccional unificado sobre la silueta completa).
- `holo_sweep_pos`, `holo_sweep_strength`, `holo_sweep_dir` (barrido holográfico).
- `impact_frame_phase` (`0..2`), `impact_center_uv` (ya conectado en `PlanarCombatRig.trigger_impact_frame`).
- `enable_outer_outline`, `outer_outline_width_px`, `outer_outline_strength`, `outer_outline_tint_mix`, `outline_calligraphy_amount`, `outer_outline_color`, `silhouette_rim_strength`, `silhouette_rim_width_px`, `counter_rim_strength`, `rim_key_color`, `rim_counter_color`, `hdr_light_wrap_strength`, `hdr_threshold`, `zoom_scale`, `light_dir_2d`.

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
- **Escena dedicada:** `sandbox/pilot_rig_lab/proto/planar_anim_test.tscn` + `planar_anim_test.gd` + `planar_pose_lab_hud.gd`.
- **Disposición y Controles:** Los 8 rigs se muestran en **brújula cardinal** (`N, NE, E, SE, S, SW, W, NW`, `COMPASS_RADIUS = 290 px`) renderizados con `02_valentina_razor_sharp` y `WorldEnvironment` (AgX + bloom), con **rueda del ratón** para zoom (`0.40x–12.0x`), **click + arrastrar** para paneo libre, **`Espacio`** para pausar/reanudar Idle Zero-G, **`M`** (o selector **`Velocidad`**) para ciclos Slow-Mo globales (`1.00x / 0.50x / 0.25x / 0.12x`), **`Tab`** para comparativa A/B instantánea contra Pose Default Rig, **`R`** para centrar cámara, selector de capa base (`0: Híbrido`, `1: Solo Huesos 2D`, `2: Solo 2.5D`, `3: Default Rest`) y HUD de 6 pestañas (`[1. Pose]`, `[2. Idle]`, `[3. Vuelo]`, `[4. Giros]`, `[5. Jiggle]`, `[6. Kiting]`) con guardado directo a `.tres`.
- **Control manual limpio e invariantes de integración:**
  - En inspección estática: `_rig.set_static_inspection(true, view_key, head_key)` y `_rig.calibration_manual_pose = true`.
  - En movimiento/vuelo (`planar_combat_rig_proto.gd`): cuando `_rig.calibration_manual_pose = true`, `PlanarCombatRig._process()` omite `_physics.update()`, `_animator` y `_perspective` para no sobrescribir huesos ni `secondary_jiggle_*`, pero conserva las transiciones snappy 8-dir (`_body_pivot.scale = snap_scale_xy`) y actualiza `_head_anchor` preservando `_manual_head_offset` y `_manual_head_rot` fijados por `sync_head_to_active_neck(extra_offset, extra_rot)`.
  - **Importante sobre `Pelvis` vs `BodyPivot`:** `PlanarCombatRig._process()` mantiene `BodyPivot.position = Vector2.ZERO` para preservar las transiciones y el marco `inv_body_pivot_matrix`; para flotar el cuerpo completo en `Y/X` sin pelear con el rig, animar el hueso raíz **`Pelvis.position`** (toda la jerarquía y `DecoupledHeadMount` lo siguen automáticamente).
  - **Caché de Texturas y Preload Headless:** `PlanarRigMeshBuilder` cachea estáticamente texturas/imágenes (`_texture_cache`, `_image_cache`) para instanciar múltiples rigs 8-dir en milisegundos. Además, todo script nuevo bajo `sandbox/pilot_rig_lab/` debe referenciar nuevas clases `.gd` vía `const FooScript = preload("res://...")` para no depender de `.godot/global_script_class_cache.cfg` en ejecuciones `--headless`.
- **Regla anti-regresión:** No editar `planar_rig_perspective_controller.gd` ni `planar_rig_animator.gd` para prototipos experimentales (deben mantener `persp_mode = 0` cuando `calibration_manual_pose == false` para que `_test_purged_subsystems` en `test_pilot_rig_lab.tscn` siga en PASS).

### 6.1.1 Arquitectura de Pose Base Zero-G + Idle Multicapa (`PlanarRigBasePoseEvaluator`)
- **Recursos Data-Driven:**
  - `PilotBasePoseConfig` (`sandbox/pilot_rig_lab/data/pilot_base_pose_config.gd` → `pilots/valentina_v2/valentina_v2_base_pose.tres`): postura base de **Guardia Táctica Zero-G** por familia canónica (`s, se, e, ne, n`).
  - `PilotIdleAnimConfig` (`sandbox/pilot_rig_lab/data/pilot_idle_anim_config.gd` → `pilots/valentina_v2/valentina_v2_idle_anim.tres`): parámetros del ciclo **Idle Zero-G ("Suspensión Táctica Viva")** más multiplicadores por familia (`float_scale`, `arms_scale`, `legs_scale`, `persp_25d_scale`, `secondary_scale`).
- **Convención de Simetría `lead` vs `trail` (8-Dir Nativo):**
  - En vistas frontales/traseras (`s`, `n`): `lead = R`, `trail = L`, `mirror_sign = +1.0` (en `n`, el signo lateral de onda usa `back_sign = -1.0` para abrir brazos/piernas simétricamente hacia afuera sin cruzar el torso).
  - En vistas derechas (`se`, `e`, `ne`): `lead` (extremidad interior adelantada) `= L`, `trail` (extremidad cercana a cámara en guardia/impulso) `= R`, `mirror_sign = +1.0`.
  - En vistas izquierdas (`sw`, `w`, `nw`): `lead = R`, `trail = L`, `mirror_sign = -1.0` (niega rotaciones 2D en pantalla y `torso_yaw`, conservando el signo Z de escorzos 2.5D).
  - Las hombreras (`Pauldron_R/L`) siguen la rotación del hombro respectivo multiplicada por `pauldron_follow_ratio` (~`0.46–0.48`) para sellar la sisa en todas las poses.
- **Las 3 Capas Conmutables del Idle Zero-G:**
  1. **Capa 1 (`enable_skeleton_layer`) — Esqueleto 2D + Gyro-Lock de Cabeza:** deriva ingrávida en Figura-8 sobre `Pelvis.position` con onda armónica asimétrica (`sin(ph) + asym * sin(2*ph - 0.35)`), respiración en columna (`Pelvis/Waist/Chest/Neck`), ondas en cadena con `phase_lag` (`Shoulder -> Elbow -> Wrist` con `arm_lr_phase_offset`; `Thigh -> Knee -> Ankle` con `leg_scissor_phase_offset`) y estabilización orgánica de cabeza (`sync_head_to_active_neck(head_offset, head_rot)`).
  2. **Capa 2 (`enable_25d_layer`) — Respiración de Escorzo 2.5D:** suma pulsos respiratorios aditivos a `torso_trap`, `torso_yaw`, `arm_phi1/2` y `leg_phi_thigh/shin/distal_amp/depth_phase` sobre la pose base cuando `use_25d` está activo.
  3. **Capa 3 (`enable_secondary_layer`) — Micro-Flotación Secundaria (Máscaras Jiggle):** activa `enable_secondary_jiggle` y `secondary_jiggle_l_px / r_px` en `body_core_mat` (`body_core_secondary_mask.png`) y sincroniza ambos pases de cabeza (`_head_data` + `_head_under_data`, `<head>_hair_jiggle_mask.png`) con retardo de fase independiente. Al pausar el Idle o apagar la capa, limpia offsets a `Vector2.ZERO` y `enable_secondary_jiggle = false` en cabezas.
- **Modos de Cadencia Temporal (`CadenceMode`):**
  - `0: FLUID_60` (60 FPS continuo), `1: HYBRID_FLOAT60_POSE15` (deriva continua a 60 FPS + articulaciones/2.5D/pelo cuantizados a 15 FPS), `2: STEPPED_24` (todo a 24 FPS), `3: STEPPED_15` (todo a 15 FPS Sakuga).
- **Locomoción Continua y Freno Suave (`PilotLocomotionAnimConfig` → `valentina_v2_locomotion_anim.tres`):**
  - **Contrato de pesos `{"fwd", "brk", "rev"}`:** en `planar_anim_test.tscn` (Pestaña `3. Vuelo/Freno`) se evalúa mediante `compute_preview_locomotion_weights()` (`AUTO_CYCLE` / `FORWARD_CRUISE` / `BRAKE_COUNTER` / `BACKPEDAL_REVERSE`); en `planar_combat_rig_proto.gd` se calcula en tiempo real desde `_velocity` e `is_backpedaling()` vía `step_live_locomotion_weights(delta, speed_norm, is_backpedal, loco_cfg)`.
  - **Estados calibrados:** `fwd_*` (avance aerodinámico con inclinación al frente, pierna trasera de impulso y arrastre de pelo hacia atrás), `brk_*` (freno suave por contra-inclinación al detectar desaceleración `decel_rate > 0.45` o parada desde avance, proyectando piernas y pelo hacia adelante antes de decaer con `brake_decay_rate`), y `rev_*` (reversa/backpedal manteniendo la mira al frente).
  - **Mezcla con Idle (Estela Viva):** mientras `fwd + brk + rev > 0`, el flote Figura-8 del Idle se atenúa (`flight_idle_float_atten = 0.35`) mientras muñecas, empeines y cabello mantienen una micro-ondulación de estela más rápida (`flight_wake_freq_mul = 1.35`, `flight_wake_amp_mul = 1.15`) sin saltos de fase.
- **Giros Snappy 2.5D & Whip Cervical (`PilotTurnAnimConfig` → `valentina_v2_turn_anim.tres`):**
  - **Contrato de estado (`get_turn_anim_state()`):** `PlanarRigTransitionController` publica fase/dirección/magnitud de cuerpo (`body_active`, `body_t`, `body_swap_pt`, `body_turn_dir`, `body_turn_mag`) y cabeza (`head_active`, `head_t`, `head_turn_dir`) con tiempos configurables (`set_custom_timings()`). En `planar_anim_test.tscn` (Pestaña `4. Giros`) se prueban ciclos `45°`, `90°`, `Completo` y `Solo Cabeza` en la brújula 8-dir.
  - **Puente 2.5D + Cascada Esquelética (Cuerpo 8-Dir):** antes del corte (`u < body_swap_point`), la vista saliente pre-rota `torso_yaw` (`pre_yaw_25d`), comprime `torso_trap`, adelanta la cabeza (`head_lead_rot`) y arrastra extremidades/pelo; tras el corte (`u >= body_swap_point`), la vista entrante arranca con escorzo 2.5D de alcance (`post_catchup_yaw_25d`), *overshoot* de columna/pelvis (`spine_overshoot_rot`, `pelvis_whip_shift_x_px`) y llegada desfasada (`limb_lag_phase`) con latigazo en brazos, piernas y cabello (`body_turn_hair_whip_px`).
  - **Whip Cervical de Cabeza Desacoplada:** al cambiar de ángulo de cabeza, aplica *overshoot* rápido en `DecoupledHeadMount` (`head_whip_overshoot_rot`, `head_whip_offset_x_px`), patada en `Neck`, micro-reacción simpática en `Chest` y `Shoulder_L/R` (`head_sympathetic_chest_rot`) y latigazo de inercia en cabello sincronizado entre Pasada 1 y Pasada 2 (`head_whip_hair_px`).
- **Jiggle Physics Sutiles — Busto & Glúteos (`PilotJigglePhysicsConfig` → `valentina_v2_jiggle_physics.tres`):**
  - **Dinámica Diferenciada y Resortes 2D (`step_live_jiggle_physics()`):** integra 4 resortes subamortiguados (`bust_l/r` a `2.15 Hz`, `damping = 0.28`; `glute_l/r` firmes a `2.85 Hz`, `damping = 0.36` acoplados a cadera/muslos) calibrados a textura `3x` (`<= 7.50 tex_px` busto / `<= 6.20 tex_px` glúteos, con `normal_light_strength = 0.015` y expansión de máscara sobre contorno de tinta y margen transparente) y coreografiados en la pestaña `[5. Jiggle]` con giros snappy 8-dir + ciclo vuelo/freno.
  - **Ruteo Anatómico Dual en `e/w`:** en `s/se/sw` los canales `R/G` manejan Busto L/R; en `n/ne/nw` manejan Glúteos L/R; y en perfiles `e/w` el canal `R` (`secondary_jiggle_l_px`) controla el Busto frontal mientras `G` (`secondary_jiggle_r_px`) controla el Glúteo posterior. Además, `secondary_jiggle_normal_strength` inclina levemente `n25` en GPU para que el brillo especular y el borde cel acompañen la inercia sin exageración.
- **Kiting 360° Zero-G ("Hover-Slide"), Reversa y Strafe Lateral (`PilotKitingAnimConfig` → `valentina_v2_kiting_anim.tres` + `PlanarRigKitingEvaluator`):**
  - **Descomposición 360° en el Marco de Orientación:** cuando Valentina vuela mirando en otra dirección, `step_live_weights()` proyecta `move_dir` respecto a `face_dir` (eje longitudinal `rev_` 180° + eje lateral canónico `lat_raw * mirror_sign` para `str_near_` y `str_far_`), disparando **`rbrk_` (Freno de Reversa)** al cortar retroceso/kiting sostenido (`_kiting_momentum`). Suprime `rev_` en `_merge_locomotion_into_motion` cuando Kiting está activo para evitar doble suma.
  - **Posturas Hover-Slide y Simetría Total:** en `e/w` reclina el torso en contra-vuelo con rodilla líder recogida y pierna trasera extendida; en `s`/`n` combina fuerte escorzo 2.5D (`torso_trap`, `leg_*_phi_shin`, `distal_amp`) en `rev_` con inclinación lateral y `head_lag_px` en `X` durante `str_near_`/`str_far_`; y añade micro-onda de equilibrio en muñecas/tobillos (`hover_slide_micro_amp`). Calibrable por fase (`rev_`, `rbrk_`, `str_near_`, `str_far_`) en `[6. Kiting]` de `planar_anim_test.tscn` y conmutable en Arena de Combate (`kiting_anim_chk`).

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

### 6.3 Hoja de Ruta y Estructura Escalable para Siguientes Etapas (`anim_lab/`)
Tras consolidar **Pose Base Zero-G**, **Idle Zero-G Multicapa**, **Movimiento Continuo / Freno Suave**, **Kiting 360° ("Hover-Slide" + Strafe Lateral + Freno de Reversa)**, **Giros Snappy 2.5D + Whip Cervical** y **Jiggle Physics Busto & Glúteos** sobre `PilotBasePoseConfig` + `PilotIdleAnimConfig` + `PilotLocomotionAnimConfig` + `PilotKitingAnimConfig` + `PilotTurnAnimConfig` + `PilotJigglePhysicsConfig` + `PlanarRigBasePoseEvaluator` + `PlanarRigKitingEvaluator`, las siguientes etapas se construirán de forma aditiva/combinable sobre la misma arquitectura data-driven sin romper el baseline:
- **Etapa 4 — Maniobras de Impulso (`DASH_BOOST`, `AIR_BRAKE` Explosivo, `LAUNCH`):** overlays aditivos temporizados con curva *ease-out* / *anticipation-overshoot*, refuerzo de trapecio 2.5D (`torso_trap`), compresión distal y disparo de afterimages/whiplash en `secondary_jiggle_*`.
- **Etapa 5 — Combate y Reacción (`ATTACK_RECOIL`, `HIT_REACT`):** micro-retroceso direccional hacia `aim_dir` / `-hit_dir` acoplado a `trigger_impact_frame()` y `hit_flash`.
- **Convenciones de extensión para las próximas sesiones:**
  1. **Evaluador modular / clips desacoplados (`sandbox/pilot_rig_lab/anim_lab/clips/` o controladores por estado):** todo nuevo estado lee la Pose Base desde `PilotBasePoseConfig` como origen (`0.0`) y suma offsets acotados por los límites de `valentina_v2_anim_config.tres`, usando `lead/trail` + `mirror_sign` para no duplicar código en `sw/w/nw`.
  2. **Registro de Máscaras por Vista/Pieza:** las 16 máscaras de pierna (`leg_{r,l}_<view>_persp_mask.png`) residen actualmente en `sandbox/pilot_rig_lab/proto/`. Si se generan máscaras de zona 2.5D para brazos (`arm_{r,l}_<view>_persp_mask.png`), seguir el invariante Voronoi 100% y pivote distal.
  3. **Pipeline de creación de máscaras (para brazos o nuevas piezas):** empaquetar piezas en lámina `1:1` o `16:9` → generar máscara plana de 9 colores sobre `#000000` (sin outlines internos) → auditar `IoU >= 0.95` → compilar a RGBA Voronoi → espejar horizontalmente para el lado opuesto (`R ↔ L`).
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
   - **Re-estandarización de ojos tras rebuilds de cabezas:** tras cualquier reconstrucción completa desde `heads_v2_base/`, re-ejecutar `python sandbox/pilot_rig_lab/tools/ingest_eye_live2d_assets.py` re-compila los `<head>_eye_iris.png` y vuelve a hornear de forma idempotente los ojos neutros **Amatista Profundo** en `heads/head_{front,front_r,front_l,side_r,side}.png`.
