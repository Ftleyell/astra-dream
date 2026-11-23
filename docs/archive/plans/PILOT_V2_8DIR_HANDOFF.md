# Pilot v2 (8-Dir Nativo) — Registro Histórico de Creación Offline

> **⚠️ DOCUMENTO HISTÓRICO DE CREACIÓN OFFLINE:** Registra cómo se generaron las hojas 8-dir, máscaras IA y overlays HD iniciales (métricas previas `0.845` / `6.61x`, `valentina` v1 y Pose Latch/alas activos en aquel hito).
> **Para el estado actual del rig runtime, métricas vigentes (`0.885` / `6.14x`) y contratos activos**, usar exclusivamente [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) y [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md).
> **Suite de verificación:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"`

---

## 1. De la Referencia Inicial al Rig 8-Dir Listo para Pulir (Visión General)

En iteraciones previas quedó demostrado que pedir a modelos generativos de imagen **8 vistas de cuerpo entero juntas** o **4 diagonales aisladas** provoca deriva de ángulo y sesgo fuerte hacia `SE`. El proceso consolidado para construir `valentina_v2` desde cero resuelve esos fallos en **6 etapas reproducibles**:

1. **Etapa 0 — Concepto de referencia y sheets iniciales (IA):** partiendo del concept art maestro ([`Guerrera Cibernética en Vuelo.jpeg`](../sandbox/pilot_rig_lab/source_refs/Guerrera%20Cibern%C3%A9tica%20en%20Vuelo.jpeg)) y las reglas de cámara/pose de [`character_25d_generation_guide.md`](art/character_25d_generation_guide.md) (cámara elevada 3/4, pose abierta *Zero-G A-Pose*, fondo neutro `#808080` sin sombra de suelo), se generaron las hojas crudas `00_raw/sheet_cardinals_raw.jpg` (`S, N, E, W`) y `00_raw/sheet_diagonals_raw.jpg`. Al detectar que la hoja diagonal duplicaba `S` en su primera columna y carecía de `SW` asimétrico auténtico, se congeló la regla: **solo 5 vistas únicas de cuerpo (`S, SE, E, NE, N`)** porque el traje es bilateralmente simétrico, reconstruyendo `SW, W, NW` en Python por espejado + intercambio `L/R` + realineación IoU.
2. **Etapa 1 — Upscale 4x, recorte y alineación canónica (`prepare_8dir_sheets.py`):** upscalado GPU con Upscayl (`digital-art-4x`), separación adaptativa por valles de columna (`find_column_splits`), mateado híbrido (`#808080` flood-fill + IS-Net Anime para huecos cerrados), defringe `#0A0A14` + relleno Voronoi RGB en alpha transparente, y normalización a lienzo nativo (`1152x2304`, base `2248`) y canónico (`1560x1680` = `3x` de `520x560`, altura corporal `1290 px`, base `1605`). Emite además borradores CIELAB (`id_mask_auto_draft/`) y `sw_fix_kit/`.
3. **Etapa 2 — Cabezas asimétricas 8-dir en closeup 4x2 e injerto `SW` (`build_head_and_body_gen_kit.py` → `process_sw_and_8dir_heads.py`):** al tener monóculo rojo en el ojo izquierdo y flequillo asimétrico, se exportaron guías de escala uniforme (`head_gen_kit/`) para generar en IA `00_raw/sheet_heads_4x2_sw_raw.jpg` (`[SE, S, SW, W]` / `[E, NE, N, NW]`). Tras Upscayl 4x, scrub de rebabas internas y normalización a `1024x1024` (`heads_8dir_hires/`), Python registró y empalmó la cabeza auténtica `SW` sobre el cuerpo `flip(SE)` en la costura de cuello/clavícula, completando `8/8` vistas en `metrics_and_audit.json` y generando la plantilla de pintura `parts5_paint_template_8dir_white.png`.
4. **Etapa 3 — Máscaras de segmentación por IA en bloques estándar (`prepare_ai_mask_workspaces.py`):** los lienzos de proporciones arbitrarias inducían estiramientos y recortes en IA. Agrupar vistas sobre blanco puro `#FFFFFF` en proporciones estándar (`16:9` `3072x1728` / `4096x2304`, `4:3` `2304x1728`, `1:1` `2048x2048`) mantuvo la geometría intacta. Con `--ingest all`, Python limpia motas (`_strip_speck_ccs`), alinea a la silueta canónica (`±4%` tolerancia), cuantiza estrictamente a paleta RGB, poda islas menores, rellena hasta el borde RGBA por Voronoi y espeja determinísticamente `SE→SW`, `E→W`, `NE→NW` con intercambio `L/R`.
5. **Etapa 4 — Correcciones manuales dirigidas y reconstrucción de miembros traseros `e`/`w` (`manual_fix_overlays/`):**
   - **Mentón `s, se, sw` (`01_cabezas_menton_se_sw/`):** se exportaron plantillas `1024x1024` alineadas píxel a píxel; tras corrección manual de las máscaras de mentón y re-ingesta en `03_id_mask_heads/split_results/`, se actualizó `_carve_head_neck_stub()` (protección explícita de piel facial + ~3 px de contorno oscuro de mandíbula) y el filtrado `is_collar_blue` en `pilot_rig_stylizer.gdshader`.
   - **Clipping de glúteo en perfiles `e`/`w` (`02_perfiles_gluteo_e_w/`):** mediante overlays `1560x1680` con guías de `Pelvis` y `Thigh_R/L`, se diagnosticó recorte en cadera superior al balancear pierna; se corrigió reanclando `Thigh_R/L` en `_derive_view_bones()` (`pelvis_y + 26 * TEX_SCALE` cuando `limb_segments` arranca en media/bota) y añadiendo blend superior hacia `Pelvis` en `PlanarRigMeshBuilder`.
   - **Brazo y pierna traseros en perfiles `e`/`w` (`03_brazo_trasero_e_w/`):** porque el miembro trasero estaba oculto en la vista de referencia lateral, se extrajeron `e_arm_front_clean_1024.png` + `e_body_context_1024.png` + `PROMPT.txt`, se generó `e_arm_back_raw.jpg` (brazo izquierdo en vista medial/palma), se escaló 4x con Upscayl (`e_arm_back_upscayl_4x.png`), se extrajo/defringó el RGBA (`e_arm_back_upscayl_4x_rgba.png`) y se alineó al lienzo `1560x1680` (`e_arm_back_rgba_1560x1680.png` + espejo horizontal `w_arm_back_rgba_1560x1680.png`). En paralelo, `build_valentina_v2_rig_assets.py` clona la pierna frontal detrás del torso (`leg_l` en `e`, `leg_r` en `w`, `z_order = 0`), sintetiza ID/limb maps (`_synthesize_rear_arm_maps`) e inyecta el brazo trasero (`z_order = 1`).
6. **Etapa 5 — Ensamblado analítico y pulido del asset pack (`build_valentina_v2_rig_assets.py`):** aplica calibración anatómica de cabezas (`HEAD_SCALE_FACTOR = 0.845`, densidad uniforme y `HEAD_OUTLINE_DEFAULT_PX = 4.0`), limpieza completa de halos/polvo/de-matting (`_clean_edge_matting_bgra`, `alpha_bleed_and_defringe`, `restore_body_core_neck_rgb`, `fade_body_core_neck_top`, `_voronoi_fill`, `HEAD_PAD_PX = 24`), desvanece internamente el puente glúteo-muslo (`N`/`NE`/`NW`), construye `arm_r/l_over_mask.png` (`s`/`se`/`sw`), `body_core_secondary_mask.png` (incluyendo busto lateral `e`/`w`), `_normal_depth.png`, `_outline_sdf.png` (`32 px`), `_hair_jiggle_mask.png`, underlap geodésico (`10–14 px`), oscurecimiento de profundidad trasero `-15%` (`0.85x`), pivotes independientes en `e`/`w` (`_derive_view_bones`), `parts_5_meta.json`, `heads_metadata.json`, `body_metrics.json`, `head_outline_config.json` y láminas de auditoría en `05_mask_ai_workspaces/final_rig_audit/` (complementado en Godot por `valentina_v2_anim_config.tres` y `pilots/valentina_v2/valentina_v2_profile.tres`).

---

## 2. Mapa de Archivos y Artefactos Generados

### A. Fuentes, Kit de Generación, Fixes Manuales y Auditoría
Ubicación: `sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir/` (protegido de Godot por `.gdignore`).

| Carpeta | Contenido y propósito |
|---|---|
| `00_raw/` | Entradas crudas de IA sin procesar: `sheet_cardinals_raw.jpg`, `sheet_diagonals_raw.jpg`, `sheet_heads_4x2_sw_raw.jpg`, más `00_raw/overlays_hd/` (originales HD `2752x1536` de torsos `torsos_8dir_regen_hd_raw.jpg`, hombreras `pauldrons_8unique_hd_raw.jpg`, piernas `legs_front_s_se_sw_clean_hd_raw.jpg` / `legs_back_n_ne_nw_hd_raw.jpg`, cabezas `heads_8dir_4x2_hd_raw.jpg` y hojas base de brazos/piernas de perfil). |
| `01_upscayl_4x/` | Salidas escaladas 4x con Upscayl (`digital-art-4x`): `sheet_cardinals_4x.png`, `sheet_diagonals_4x.png`, `sheet_heads_4x2_sw_4x.png`. |
| `02_poses_native_{rgba,white,gray80}/` | Las 8 poses limpias a resolución nativa 4x (`e, n, ne, nw, s, se, sw, w`, lienzo `1152x2304`). |
| `02_poses_canonical_1560x1680/` | Poses alineadas al lienzo canónico `1560x1680` (`3x` de `520x560`), RGBA y fondo blanco. |
| `03_sheets_aligned/` | Comprobaciones y hojas alineadas: `sheet_7dir_*`, `sheet_8dir_compass_*.png`, `sheet_8dir_alignment_audit.png`. |
| `04_mask_prep_ready/heads_8dir_hires/` | 8 cabezas normalizadas a `1024x1024` (`rgba/`, `white/`, `gray80/`) y hojas `4x2`. |
| `04_mask_prep_ready/head_gen_kit/` | Kits exportados para generación IA (`ref_1_head_4cardinals_2x2_gray80.png`, `ref_2_head_8dir_turnaround_gap_4x2_gray80.png`, `ref_3_body_5min_S_SE_E_NE_N_gray80.png`). |
| `04_mask_prep_ready/id_mask_auto_draft/` | Pre-máscaras heurísticas CIELAB usadas como borrador/guía visual para `02_id_mask_bodies`. |
| `04_mask_prep_ready/sw_fix_kit/` | Kit auxiliar de referencia usado en el empalme de busto `SW`. |
| `05_mask_ai_workspaces/` | Workspaces modulares de las 5 máscaras (ver tabla B) + `manual_fix_overlays/`. |
| `05_mask_ai_workspaces/manual_fix_overlays/` | `01_cabezas_menton_se_sw/` (`1024x1024`), `02_perfiles_gluteo_e_w/` (`1560x1680`) y `03_brazo_trasero_e_w/` (`PROMPT.txt`, `e_arm_back_raw.jpg`, `e_arm_back_upscayl_4x*.png`, `e_arm_back_rgba_1560x1680.png`, `w_arm_back_rgba_1560x1680.png`). |
| `05_mask_ai_workspaces/final_rig_audit/` | Láminas visuales de control: `audit_bodies_bones_8dir.png`, `audit_carved_heads_8dir.png`, `audit_mounted_rigs_8dir.png`. |

### B. Detalle de los 5 Workspaces de Máscaras IA (`05_mask_ai_workspaces/`)

Cada subcarpeta contiene `inputs/`, `masked_outputs/`, `split_results/`, `layout_meta.json` y `PROMPT_GUIDE.md` (además de `python_auto_draft/` en `02` y `03`):

| Carpeta | Qué segmenta | Lotes en `inputs/` (Relación IA) | Vistas trabajadas en IA | Salida en `split_results/` |
|---|---|---|---|---|
| `01_parts_5_despiece` | 5 partes móviles (`body_core` Verde `#00FF00`; en imagen: brazo izq. Rojo `#FF0000` / der. Azul `#0000FF`, pierna izq. Amarillo `#FFFF00` / der. Magenta `#FF00FF`; en perfil `E` los miembros cercanos van en Azul/Magenta). `--ingest` resuelve `arm_r`/`arm_l` y `leg_r`/`leg_l` anatómicos según hemisferio y espeja `SW/W/NW`. | `batchA_S_SE_E_16x9_white.png` (`3072x1728`, **16:9**)<br>`batchB_NE_N_4x3_white.png` (`2304x1728`, **4:3**) | Solo `S, SE, E, NE, N` | 8× `<dir>_parts5_mask.png` + `<dir>_parts5_audit.png` |
| `02_id_mask_bodies` | ID de materiales cuerpo (`#FFFF00` piel, `#0000FF` traje, `#00FF00` armadura, `#FF0000` carmesí, `#00FFFF` medias/pelo) | `batchA_S_SE_E_16x9_white.png` (`3072x1728`, **16:9**)<br>`batchB_NE_N_4x3_white.png` (`2304x1728`, **4:3**) | Solo `S, SE, E, NE, N` | 8× `<dir>_id_mask.png` + `<dir>_id_mask_preview.png` + `<dir>_id_mask_audit.png` |
| `03_id_mask_heads` | ID de materiales de las 8 cabezas asimétricas | `batchA_front_2x2_1x1_white.png` (`2048x2048`, **1:1**, `[S,SE / SW,W]`)<br>`batchB_back_2x2_1x1_white.png` (`2048x2048`, **1:1**, `[E,NE / NW,N]`)<br>`all8_4x2_16x9_white.png` (`4096x2304`, **16:9**, Fila 0 `[S, SE, SW, W]` / Fila 1 `[E, NE, NW, N]`) | Las 8 vistas (`S..NW`) | 8× `head_<dir>_id_mask.png` + `head_<dir>_id_mask_preview.png` + `head_<dir>_id_mask_audit.png` |
| `04_limb_anim_masks` | Peso esquelético de extremidades (segmentos superior/medio/extremo RGB) | `batchA_S_SE_E_16x9_white.png` (`3072x1728`, **16:9**)<br>`batchB_NE_N_4x3_white.png` (`2304x1728`, **4:3**) | Solo `S, SE, E, NE, N` | 8× `<dir>_limb_segments.png` + `<dir>_limb_segments_audit.png` |
| `05_secondary_jiggle_masks` | Zonas blandas secundarias (Cian `#00FFFF` busto frontal en `S/SE`; Magenta `#FF00FF` glúteos en `N/NE`) | `batchA_front_S_SE_4x3_white.png` (`2304x1728`, **4:3**)<br>`batchB_back_N_NE_4x3_white.png` (`2304x1728`, **4:3**) | `S, SE, N, NE` (`SW/NW` espejados) | 6× (`s, se, sw, n, ne, nw`) `<dir>_secondary_jiggle_mask.png` + `<dir>_secondary_audit.png` |

### C. Asset Pack Final e Integración en Godot
- **Assets finales (`parts_5/` por 8 vistas + `46` archivos en `heads/` + `hd_torsos/` + raíz):** `sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/`
  - Raíz: `.gdignore`, `body_metrics.json`, `head_outline_config.json`, `valentina_v2_anim_config.tres` (`PlanarRigAnimConfig`), `valentina_v2_perspective_config.tres` (`RigPerspectiveConfig`). *(Nota: las métricas vigentes en `body_metrics.json` son `head_scale_factor: 0.885`, `head_target_disp_h: 69.03`, `mounted_total_h_du: 418.61`, `head_to_body_proportion: 6.14`).*
  - `<dir>/parts_5/` (`s, se, e, ne, n, nw, w, sw`): 7 piezas PNG (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`, `pauldron_r`, `pauldron_l`) + `_id_mask.png` + `_normal_depth.png`, 4 extremidades `_anim_mask.png`, `body_core_secondary_mask.png` (busto en `s/se/sw/e/w` y glúteos en `n/ne/nw`), `body_core_pauldron_mask.png` y `parts_5_meta.json` (18 huesos incluyendo `Pauldron_R/L` + `z_orders` por ángulo). *(Nota: `arm_r/l_over_mask.png` fue retirado en v2 al separar `pauldron_r/l`)*. En `e`/`w`, la pierna trasera se clona de la frontal en `z_order = 0` y el brazo trasero se inyecta en `z_order = 1`.
  - `heads/`: 8 cabezas reducidas a `0.845x` (`head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side_l`, `head_back_r`, `head_back_l`, `head_back` + alias `head_side`, es decir `9 × 5 = 45` texturas `.png`, `_id_mask.png`, `_normal_depth.png`, `_hair_jiggle_mask.png`, `_outline_sdf.png`) + `heads_metadata.json`.
- **Perfil `.tres` (configurado en Godot):** `sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres` (`pilot_id = "valentina_v2"`, `display_scale = 0.378` → `~159.3 px` a zoom `1.0`, `head_outline_width_px = 4.0`, `stepped_fps = 15.0`, `anim_config = valentina_v2_anim_config.tres`).
- **Scripts GDScript actualizados (compatibilidad dual 2-dir v1 + 8-dir v2):**
  - `sandbox/pilot_rig_lab/proto/planar_combat_rig.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_animator.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_transition_controller.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_secondary_physics.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd`
  - `sandbox/pilot_rig_lab/proto/planar_rig_wings_vfx.gd`
  - `sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd`
  - `sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.gd`

---

## 3. Runbook Paso a Paso (Reproducción y Reconstrucción Rápida)

Usar siempre el entorno virtual Python del Lab: `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe`.

| Fase | Comando / Acción | Cuándo correrlo |
|---|---|---|
| **1. Recorte y alineación 7-dir desde sheets IA** | `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_8dir_sheets.py` | Solo si cambian `00_raw/sheet_cardinals_raw.jpg` o `sheet_diagonals_raw.jpg`. |
| **2. Kit mínimo + cabezas 8-dir + empalme `SW`** | `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/build_head_and_body_gen_kit.py` → generar `00_raw/sheet_heads_4x2_sw_raw.jpg` → `process_sw_and_8dir_heads.py` | Solo si se regenera la hoja 4x2 de cabezas. |
| **3. Exportar lotes blancos para máscaras IA** | `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --export` | Regenera `inputs/` y `PROMPT_GUIDE.md` manteniendo intactos `masked_outputs/` y `split_results/`. |
| **4. Ingerir, limpiar y espejar máscaras IA** | `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe sandbox/pilot_rig_lab/tools/prepare_ai_mask_workspaces.py --ingest all` *(o una carpeta, ej. `--ingest 03_id_mask_heads`)* | Cada vez que se coloque o edite un archivo en `masked_outputs/` como `<lote>_mask.{png,jpeg}` (o `<lote>_masked.*` / mismo nombre que `inputs/`). |
| **4b. Fixes manuales y brazo trasero `e`/`w`** | `manual_fix_overlays/01_cabezas_menton_se_sw/`, `02_perfiles_gluteo_e_w/` y `03_brazo_trasero_e_w/` (`PROMPT.txt` → Upscayl 4x → mateado/alineación `*_arm_back_rgba_1560x1680.png`) | Cuando haya que corregir mentones, diagnosticar pivotes o regenerar el brazo trasero `e`/`w`. |
| **4c. Ingesta HD (Upscayl 4x)** | `.venv/Scripts/python.exe ingest_hd_torsos_16x9.py` + `ingest_cap_sheets_16x9.py` + `ingest_pauldron_polish_16x9.py` | Cuando se actualicen hojas HD en `00_raw/overlays_hd/`, `07_torso_neck_regen_16x9/`, `04_cap_sheets_16x9/Joints/` o `07_pauldron_polish_16x9/`. |
| **5. Ensamblar `valentina_v2_planar` + auditorías** | `C:\Python314\python.exe sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py` | Usa `scipy` (corte de pliegue Neumann). Corre tras editar máscaras en `split_results/`, ajustar huesos/caps o actualizar los overlays HD. |
| **6. Verificar rig v1 + v2 + HUD en Godot** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"` | Obligatorio tras cambios en assets v2 o scripts del Lab (`~3–6 s`). |

---

## 4. Guía de Ajustes Finos Rápidos

Puntos concretos preparados para iterar sobre el rig sin rehacer las etapas previas:

1. **Correcciones locales de máscaras (`split_results/` directo vs `--ingest`):**
   - Si solo falla un detalle pequeño en una vista concreta (ej. un dedo entre `body_core` y `arm_r` en `se`, un borde de media en `id_mask`, o la frontera codo/muñeca en `limb_segments`):
     - Revisa primero `05_mask_ai_workspaces/<carpeta>/split_results/*_audit.png` y `05_mask_ai_workspaces/final_rig_audit/audit_mounted_rigs_8dir.png`.
     - Puedes editar directamente el archivo individual de `split_results/` (por ejemplo `se_parts5_mask.png`, `e_id_mask.png` o `head_sw_id_mask.png`) — o el bloque en `masked_outputs/` y correr `--ingest <carpeta>` — y luego ejecutar **solo** `build_valentina_v2_rig_assets.py`.
   - *Regla de simetría al corregir bloques:* si editas manualmente en `split_results/` la vista `se`, `e` o `ne`, recuerda aplicar la misma corrección espejada (o volver a correr `--ingest <carpeta>`) si quieres que `sw`, `w` y `nw` hereden el ajuste.
2. **Acople Cabeza ↔ Cuello y Escala de Cabeza (`build_valentina_v2_rig_assets.py`):**
   - La altura y protección del contorno facial/mentón vive en `_carve_head_neck_stub()` y el tamaño relativo de cabeza en pantalla se controla con `HEAD_TARGET_DENSITY_PX_H` y `_align_head_to_body_canonical()`.
   - En runtime Godot, el ocultamiento detrás de hombros en vistas traseras (`n, ne, nw`) vs frontales/laterales (`s, se, sw, e, w`) lo controla `head_over_face_keep` en `PlanarCombatRig._sync_head_transform()`.
3. **Pivotes de Huesos y Capas (`z_orders`) por Ángulo:**
   - Todos los órdenes `Z` de las piezas por vista están centralizados en `VIEW_Z_ORDERS` al inicio de `build_valentina_v2_rig_assets.py`.
   - Los huesos (`BONE_PARENTS`) se calculan en `_derive_view_bones()` (incluyendo `Pauldron_R/L` y el anclaje hip-socket de `Thigh_R/L`) y se exportan a `<dir>/parts_5/parts_5_meta.json`.
   - En v2, las hombreras se separan en `pauldron_r` / `pauldron_l` y se proyecta su sombra sobre `body_core` mediante `body_core_pauldron_mask.png` (el antiguo pase dividido `arm_*_over_mask.png` fue retirado en v2).
4. **Inspección rápida en Lab:** ejecutar [`planar_combat_rig_proto.tscn`](../sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn), activar **Inspección Estática** para recorrer los `64` combos (`8` cuerpos × `8` cabezas) y alternar **Modo Debug Shader** (`Rayos-X: Clown-Pass / Normales / Profundidad`) para detectar costuras o desfases de máscara al instante.

---

## 5. Resultados de Pulido, Re-Animación 8-Dir y Pose Latch (`valentina_v2`)

Esta sección consolida los valores finales calibrados y las correcciones aplicadas en la fase de pulido de `valentina_v2` según [`Estilización 2.5D en Godot 4.md`](art/Estilizaci%C3%B3n%202.5D%20en%20Godot%204.md), [`PILOT_RIG_ARCHITECTURE.md`](PILOT_RIG_ARCHITECTURE.md) y [`ART_DIRECTION_AND_PIPELINE.md`](ART_DIRECTION_AND_PIPELINE.md).

### A. Proporción Cabeza–Cuerpo (`HEAD_SCALE_FACTOR = 0.845`)
| Métrica (`s`) | `valentina` (v1) | `valentina_v2` (Pre-Pulido) | `valentina_v2` (Calibrado Final) |
|---|---|---|---|
| `head_target_disp_h` (`vis_h`) | `~76.4 du` | `77.73 du` | **`65.91 du`** (`HEAD_TARGET_DENSITY_PX_H = 240.0`) |
| `head_crown_to_chin_du` | `~66.9 du` | `~75.4 du` | **`63.71 du`** |
| Altura total montada (`mounted_total_h_du`) | `463.46 du` | `430.00 du` | **`421.33 du`** |
| Proporción cuerpo total / cabeza | `6.06x` / `6.92x` | `5.53x` / `5.70x` | **`6.61x`** (`crown_to_chin`, anime estilizado 6.5x) |
| `display_scale` y altura en combate (`zoom = 1.0`) | `0.365` (`160 px` renderizado) | `0.365` (~`157.0 px`) | **`0.378`** → **`159.3 px`** (`160 px` Vulkan real) |

### B. Outlines, Edge Sanitization y Costuras en Shader
1. **`is_neck_seam` dinámico (`planar_rig_mesh_builder.gd` + `pilot_rig_stylizer.gdshader`):** en `parts_5/body_core`, `PlanarRigMeshBuilder` calcula `neck_seam_u = (neck_anchor.x - dx) / dw` y `neck_seam_max_v` en coordenadas canónicas por vista (`s=0.5061`, `se=0.5565`, `e=0.3756`, `ne=0.5288`, `n=0.5017`, `nw=0.4658`, `w=0.5830`, `sw=0.4881`), eliminando la ventana fija `0.42` que fallaba en `w`/`se`.
2. **Sello inferior de cabeza guiado por máscara (`is_collar_blue`) + `HeadContactShadow` local:** sustituido el corte fijo `sample_uv.y >= 0.80` por la banda de collar/cuello (`is_collar_blue`) para no morder contornos de mentón sin reintroducir costuras sobre el collar; `HeadContactShadow` calcula el offset en `du` locales de `BodyPivot` junto al collar y se oculta en vistas traseras (`n`, `ne`, `nw`).
3. **Calibración de peso de tinta + saneamiento subpíxel y uniones 8-dir:** `head_outline_width_px = 4.0` y `sdf_pad_px = 32.0` (`HEAD_SDF_MAX_DIST_PX = 32.0`) en [`planar_rig_mesh_builder.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd) alineados al `pass2` unificado (`zoom_eff = pow(zc, 0.60)`). En [`build_valentina_v2_rig_assets.py`](../sandbox/pilot_rig_lab/tools/build_valentina_v2_rig_assets.py): saneamiento `_clean_edge_matting_bgra` preservando piel en `underlap` (`dist_whole_air >= 2.5`), curado de sombra superior en `se/leg_l` y `sw/leg_r`, suavizado del contorno anterior de muslo en `e`/`w`, *feather* ampliado en glúteo lateral inferior `ne`/`n`/`nw` (`shifted_up 12 px`, `bot_dist <= 11 px`), cobertura medial `1.06x` en `se/pauldron_l` y `sw/pauldron_r`, y exenciones `is_body_bottom_seam` / `is_leg_top_seam` en shader. Verificado sin costuras ni artefactos en Vulkan Forward+ / Mobile.

### C. Costuras Mecánicas, Pivotes y Máscaras Auxiliares
1. **Registro único de `"Pelvis"` (`planar_rig_mesh_builder.gd`):** eliminada la duplicación del hueso raíz `"Pelvis"` en `_bind_parts5_weights()`.
2. **Brazo y pierna traseros `e`/`w` completos (`build_valentina_v2_rig_assets.py`):** pivotes propios reales (`Shoulder_L/Elbow_L/Wrist_L` en `e`, `_R` en `w`), underlap geodésico bajo el hombro y `REAR_DEPTH_DARKEN_FACTOR = 0.85` (`-15%`) sobre `e/arm_l`, `e/leg_l`, `w/arm_r` y `w/leg_r`.
3. **Máscaras auxiliares activas:** `body_core_pauldron_mask.png` (`8` vistas para sombra de contacto de hombreras) y `body_core_secondary_mask.png` (busto en `s/se/sw/e/w` y glúteos en `n/ne/nw`); `arm_*_over_mask.png` retirado en v2. *(Ver tabla completa de canales en [`docs/PILOT_RIG_ARCHITECTURE.md`](PILOT_RIG_ARCHITECTURE.md#51-inventario-de-máscaras-en-uso-offline-vs-runtime))*.

### D. Re-Animación 8-Dir, Pose Latch 15 FPS y VFX Dinámicos
1. **`PlanarRigAnimConfig` v2 dedicado + familias angulares (`valentina_v2_anim_config.tres` + `planar_rig_animator.gd`):** familias independientes `S`, `SE/SW`, `E/W`, `NE/NW`, `N` con límites propios por familia (`se_*`, `e_*`, `ne_*`, `s_*`, `n_*`), detección dinámica de lateralidad anatómica en `N` (`v2` vs `v1`), contrapposto/rodillas simétricas en `S`/`N`, eliminación de tijera en `e`/`w`, mezcla hip-to-thigh `0.62` en perfil `e`/`w` frontal, separación asimétrica de zancada (`e_th_l - e_th_r`), remapeo/damping en cambios de hemisferio (`_handle_view_swap_remapping`) y **Aim Arm Tracking 2D en 8 direcciones** con `torso_forward.angle_to(smooth_aim_dir)` (signo calibrado en `NE`/`NW`, amortiguación en `S aim S` y límite natural en `E/W aim down` sin cruzar detrás de la cadera). Perspectiva 2.5D sincronizada con `swap_lr = (view_key in ["w", "sw", "nw"]) != body_flip_x`, estados `FLIGHT_STRAFE`/`DASH_BOOST`/`BACKPEDAL_FOCUS` y normal cilíndrica/crest rim acotada a silueta.
2. **Doble Reloj con *Pose Latch* 15 FPS (`planar_combat_rig.gd` + `planar_rig_secondary_physics.gd`):** `body_pivot.position` traslada continuo a `60+ FPS` mientras el `Skeleton2D` (`apply_latched_pose`), rotación de `body_pivot`, escorzo y shader `secondary_jiggle` corporal latches a `stepped_fps = 15.0` con desfase de cabeza/cabello `+1 tick` (`head_pose_stagger_ticks = 1`), respetando *hitstop*, inspección estática y sincronía de perfil/HUD (`display_scale` + `clock_opt`).
3. **Alas y propulsores anclados dinámicamente (`planar_rig_wings_vfx.gd`):** `ProceduralEnergyWings` se ancla en tiempo real al hueso `Chest` de la vista activa con compresión de perspectiva horizontal y plegado dorsal en `e`/`w` (evitando atravesar el pecho), y `BootThrusters` sigue `Ankle_R/L` hasta los talones de bota.
