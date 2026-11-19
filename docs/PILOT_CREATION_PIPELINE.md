# Pilot Creation Pipeline — De Arte Base a `.tres` en el Lab

> Guía paso a paso para crear un nuevo piloto compatible con `PlanarCombatRig` (soporte **Estándar v2: 8-Dir Nativo** y legado **v1: 2-Dir S/N + Flip-H**).
> Para el registro operativo completo de la creación de **Valentina v2** y la guía de ajustes finos, consultar [`docs/PILOT_V2_8DIR_HANDOFF.md`](PILOT_V2_8DIR_HANDOFF.md).

---

## 0. Estrategia Estándar Recomendada (v2 — 8-Dir Nativo)

Para evitar la deriva angular de modelos generativos al pedir 8 cuerpos desde cero, el estándar consolidado separa **cuerpo simétrico (generación mínima + espejado en Python)** y **cabeza asimétrica (8 vistas completas closeup)**:

1. **Arte base de cuerpo (solo 5 vistas IA: `S, SE, E, NE, N`):**
   - Cámara elevada consistente (`45°–60°` / `~30°–45°` 3/4 combate), altura alineada y pose abierta (*Zero-G A-Pose*, brazos despejados 30°–45°, fondo `#808080` sin sombra al suelo).
   - Ver plantillas base en [Guía Técnica de Generación de Personajes 2.5D](art/character_25d_generation_guide.md) y [GOOGLE_AI_PROMPTS.md](../sandbox/pilot_rig_lab/reference_templates/GOOGLE_AI_PROMPTS.md).
   - Las 3 vistas simétricas restantes (`SW, W, NW`) se reconstruyen en Python por espejado horizontal e intercambio `L/R` con alineación IoU.
2. **Cabeza asimétrica (8 vistas completas en hoja 4x2):**
   - Generadas en closeup sobre grilla 4x2 con escala unificada (`build_head_and_body_gen_kit.py`) y procesadas a `1024x1024` (`process_sw_and_8dir_heads.py`, empalmando la cabeza auténtica `SW` sobre el cuerpo `flip(SE)`).
3. **Máscaras de segmentación por IA en bloques estándar (`16:9`, `4:3`, `1:1`):**
   - Exportar las 5 carpetas en blanco puro (`#FFFFFF`) con relaciones exactas (`prepare_ai_mask_workspaces.py --export`): `01_parts_5_despiece`, `02_id_mask_bodies`, `03_id_mask_heads`, `04_limb_anim_masks`, `05_secondary_jiggle_masks`. Cada carpeta genera su propio `PROMPT_GUIDE.md`.
   - Devolver resultados en `<carpeta>/masked_outputs/` como `<lote>_mask.{png,jpeg}` (o `<lote>_masked.*` / mismo nombre que `inputs/`) y ejecutar `--ingest all`: Python cuantiza a paleta RGB pura, filtra motas aisladas, limpia antialiasing y genera automáticamente `SW/W/NW` + auditorías en `split_results/`.
4. **Ajustes locales e inyección de miembros traseros en `e`/`w` (`source_refs/<pilot_dir>/05_mask_ai_workspaces/manual_fix_overlays/`):**
   - Corrección dirigida de máscaras de mentón (`01_cabezas_menton_se_sw/`), auditoría de pivote glúteo (`02_perfiles_gluteo_e_w/`) y reconstrucción del brazo trasero medial (`03_brazo_trasero_e_w/` → Upscayl 4x + alineación `1560x1680` + clonado de pierna trasera `leg_l`/`leg_r`) documentados en [PILOT_V2_8DIR_HANDOFF.md](PILOT_V2_8DIR_HANDOFF.md).
5. **Ingesta HD de Overlays (Upscayl 4x sobre torsos, caps de extremidades y hombreras):**
   - `ingest_hd_torsos_16x9.py` (desde `07_torso_neck_regen_16x9/torsos_8dir_regen_raw.jpg` `2752x1536` → Upscayl 4x `11008x6144` → `combat_assets/<id>_planar/hd_torsos/`).
   - `ingest_cap_sheets_16x9.py` (desde `04_cap_sheets_16x9/Joints/` → Upscayl 4x en `upscayl_4x/` → `capped_rgba_1560x1680/`).
   - `ingest_pauldron_polish_16x9.py` (desde `07_pauldron_polish_16x9/inputs/01_pauldrons_unique_8_16x9_hd.jpg` → Upscayl 4x → `06_torso_and_leg_e_16x9/hd_pauldrons/`).
6. **Ensamblado del asset pack (`build_valentina_v2_rig_assets.py` con `C:\Python314\python.exe`):**
   - Construye `sandbox/pilot_rig_lab/combat_assets/<pilot_id>_planar/` usando `scipy` (corte de pliegue de Neumann en `_anim_mask.png` con canal `A=seam_fade`), helpers de `polish_outlines.py`, limpieza `_clean_edge_matting_bgra` y suavizado subglúteo en `N/NE/NW`, generando las 8 carpetas `<dir>/parts_5/` (incluyendo `pauldron_r/l` independientes, `body_core_pauldron_mask.png`, `body_core_secondary_mask.png`, `*_normal_depth.png` en orden BGRA), `heads/` (8 cabezas × 5 mapas + alias `head_side`), `body_metrics.json`, `head_outline_config.json`, `parts_5_meta.json`, `heads_metadata.json` y láminas en `05_mask_ai_workspaces/final_rig_audit/` (sin `arm_*_over_mask.png`, retirado en v2).

---

## 1. Estructura de Carpetas del Nuevo Piloto

1. **Fuentes crudas sin procesar (fuera del import de Godot):** `sandbox/pilot_rig_lab/source_refs/<pilot_dir>/` (protegido con `.gdignore`), con toda la base sin procesar en `00_raw/` (incluyendo `00_raw/overlays_hd/` para torsos, piernas, brazos, hombreras y cabezas HD originales).
2. **Assets procesados de combate:** `sandbox/pilot_rig_lab/combat_assets/<pilot_id>_planar/`
   - **8-Dir Nativo (v2):** `s/`, `se/`, `e/`, `ne/`, `n/`, `nw/`, `w/`, `sw/`, cada uno con `parts_5/` (`body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l`, `pauldron_r`, `pauldron_l` en RGBA + `_id_mask.png` + `_normal_depth.png`, más `*_anim_mask.png`, `body_core_secondary_mask.png`, `body_core_pauldron_mask.png` y `parts_5_meta.json`). *(En modo legado v1: solo `s/` y `n/`)*.
   - **Cabezas:** `heads/` con `head_{front,front_l,front_r,side_l,side_r,back,back_l,back_r}` (RGBA + `_id_mask.png` + `_normal_depth.png` + `_hair_jiggle_mask.png` + `_outline_sdf.png`) y `heads_metadata.json`.
   - **Raíz del pack:** `.gdignore`, `body_metrics.json`, `head_outline_config.json`, `<pilot_id>_anim_config.tres`, `valentina_v2_perspective_config.tres`, `hd_torsos/` *(caché de torsos HD alineados)*.
3. **Perfil y Skins `.tres`:** `sandbox/pilot_rig_lab/pilots/<pilot_id>/`
   - `<pilot_id>_profile.tres` (`PilotRigProfile`)
   - `skins/*.tres` (`PilotSkinPreset`, pueden reutilizarse o definirse propios)

---

## 2. Scripts Activos del Pipeline Python (`sandbox/pilot_rig_lab/tools/`)

Usar `.venv/Scripts/python.exe` para etapas 1–5 y **`C:\Python314\python.exe`** (con `scipy`) para `build_valentina_v2_rig_assets.py`.

### Ruta Estándar v2 (8-Dir Nativo + Overlays HD + Ensamblado)

| Orden | Script | Función |
|---|---|---|
| 1 | `prepare_8dir_sheets.py` | Upscaling 4x (Upscayl), recorte adaptativo por valles, mateado híbrido `#808080` + IS-Net, alineación canónica `1560x1680` y borradores CIELAB `id_mask_auto_draft/`. |
| 2 | `build_head_and_body_gen_kit.py` | Exporta plantillas de referencia grises `2x2` (cabezas), `4x2` hueco `SW` y tira mínima 5-cuerpos (`S, SE, E, NE, N`). |
| 3 | `process_sw_and_8dir_heads.py` | Normaliza las 8 cabezas a `1024x1024`, injerta la cabeza `SW` sobre cuerpo `flip(SE)` y completa las 8 vistas `canonical`/`native`. |
| 4 | `prepare_ai_mask_workspaces.py` | `--export`: crea bloques `16:9`/`4:3`/`1:1` + `PROMPT_GUIDE.md`. `--ingest <key \| all>`: desparasita, cuantiza paleta, realinea por IoU y genera `SW/W/NW` automáticamente. |
| 5 | `ingest_hd_torsos_16x9.py` / `ingest_cap_sheets_16x9.py` / `ingest_pauldron_polish_16x9.py` | Procesan con **Upscayl 4x** los overlays HD de torsos (`hd_torsos/`), caps de extremidades (`capped_rgba_1560x1680/`) y hombreras únicas (`hd_pauldrons/`). *(Sus exportadores previos fueron `export_cap_sheets_16x9.py`, `export_torso_and_profile_leg_sheets_16x9.py`, `export_pauldron_*_16x9.py`)*. |
| 6 | `build_valentina_v2_rig_assets.py` | Ensambla las 8 vistas `parts_5/` (incluyendo `pauldron_r/l`, brazo/pierna traseros `e/w`, mapas BGRA `_normal_depth.png`, `_anim_mask.png` con corte de pliegue, `body_core_pauldron_mask.png`), 8 cabezas + alias `head_side` y láminas en `final_rig_audit/`. |

### Scripts Base / Compatibilidad v1 (2-Dir `S`/`N`)

Los scripts modulares originales siguen activos como librería compartida o para rigs 2-dir legacy:

| Script | Función / Uso |
|---|---|
| `generate_mask_sheets.py`, `process_masked_5parts.py`, `process_parts5_1to1_maps.py` | Flujo v1 `S`/`N` y helpers compartidos (`TEX_SCALE`, `_align_mask_to_ref`, `_place_on_canvas`). |
| `id_mask_ink_refiner.py`, `ml_stage_processors.py` | Refinamiento CIELAB/SLIC bloqueado a tinta y etapa ML compartida (`clear_vram`, IS-Net/Sapiens). |
| `process_limb_anim_masks.py`, `process_secondary_mask.py`, `build_head_8dir_guide.py`, `process_head_8dir_sheet.py` | Helpers reutilizados por v2 (`MASK_SCALE`, `_build_clean_head_normal_depth`, `_build_hair_jiggle_mask`). |
| `clean_edge_matting.py`, `polish_outlines.py` | `polish_outlines.py` exporta helpers reutilizados por v2 (`alpha_bleed_and_defringe`, `_voronoi_fill`, `restore_body_core_neck_rgb`, `fade_body_core_neck_top`, `HEAD_PAD_PX`); sus pases *standalone* (`polish_parts_5`, `normalize_back_arm_outlines`) y `clean_edge_matting.py` (`w * 0.42`) siguen acoplados a v1 `s`/`n` (con respaldo `_backup_before_outline_polish/`). |

---

## 3. Registro en el Lab (Cero Código)

1. Crear `res://sandbox/pilot_rig_lab/pilots/<pilot_id>/<pilot_id>_profile.tres` de tipo `PilotRigProfile`.
2. Asignar `pilot_id`, `display_name`, `assets_root`, `anim_config` (`PlanarRigAnimConfig`), `skins`, `hair_presets` (pueden reutilizarse los de `data/hair/`) y `style_profiles` (`data/styles/`).
3. Abrir `planar_combat_rig_proto.tscn`: `PlanarLabHudBuilder` escanea `pilots/*/*.tres` automáticamente y muestra al nuevo piloto en el selector **0. PILOTO (.tres)**.

---

## 4. Verificación

Ejecutar siempre tras añadir o modificar un piloto:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
```
