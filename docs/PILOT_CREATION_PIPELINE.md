# Pilot Creation Pipeline — De Arte Base a `.tres` en el Lab

> Guía paso a paso para crear un nuevo piloto compatible con `PlanarCombatRig` sin modificar código GDScript.

---

## 1. Estructura de Carpetas del Nuevo Piloto

1. **Fuentes crudas (fuera del import de Godot):** `sandbox/pilot_rig_lab/source_refs/` (protegido con `.gdignore`).
2. **Assets procesados de combate:** `sandbox/pilot_rig_lab/combat_assets/<pilot_id>_planar/`
   - `s/parts_5/` y `n/parts_5/`: `body_core`, `arm_r`, `arm_l`, `leg_r`, `leg_l` (RGBA + `_id_mask.png` + `_normal_depth.png`), más `*_anim_mask.png`, `body_core_secondary_mask.png` y `parts_5_meta.json`.
   - `heads/`: `head_{front,front_l,front_r,side_l,side_r,back,back_l,back_r}` (RGBA + `_id_mask.png` + `_normal_depth.png` + `_hair_jiggle_mask.png` + `_outline_sdf.png`) y `heads_metadata.json`.
3. **Perfil y Skins `.tres`:** `sandbox/pilot_rig_lab/pilots/<pilot_id>/`
   - `<pilot_id>_profile.tres` (`PilotRigProfile`)
   - `skins/*.tres` (`PilotSkinPreset`)

---

## 2. Scripts Activos del Pipeline Python (`sandbox/pilot_rig_lab/tools/`)

Usar el entorno virtual `sandbox/pilot_rig_lab/tools/.venv`:

| Orden | Script | Función |
|---|---|---|
| 1 | `generate_mask_sheets.py` | Genera hojas guía para segmentación semántica de cuerpo y cabezas. |
| 2 | `process_masked_5parts.py` | Recorta `body_unified` S y N en 5 piezas (`parts_5`) con `parts_5_meta.json` y upscaling 4x. |
| 3 | `process_parts5_1to1_maps.py` | Genera mapas 1:1 `_id_mask.png` y `_normal_depth.png` (usa `ml_stage_processors.py` / Sapiens 0.3b). |
| 4 | `process_limb_anim_masks.py` | Genera `_anim_mask.png` RGB (Hombro/Codo/Muñeca y Muslo/Rodilla/Tobillo) para skinning exacto. |
| 5 | `process_secondary_mask.py` | Genera `body_core_secondary_mask.png` para física secundaria 2D del busto. |
| 6 | `build_head_8dir_guide.py` | Genera plantilla guía 4x2 para las 8 direcciones de cabeza. |
| 7 | `process_head_8dir_sheet.py` | Extrae las 8 cabezas, centra cráneos y genera `heads_metadata.json`, `_hair_jiggle_mask.png` y mapas 2.5D. |
| 8 | `clean_edge_matting.py` | Limpia flecos de alpha semitransparente hacia tinta abisal (`INK_RGB = [10, 10, 20]`), eximiendo la ventana de cuello de `body_core.png` y el tope de piernas bajo pelvis. |
| 9 | `polish_outlines.py` | Pulido integral de bordes y normalización de piezas (idempotente con respaldo automático). |

### Detalles Clave del Saneamiento Automático (`process_masked_5parts.py` y `polish_outlines.py`)
1. **Extensión bajo solapes (`process_masked_5parts.py`):** en brazos traseros (`z_order < body_core`), `ext_zone` usa semillas `m_sub & (ref_luma > 0.14)` con AO progresivo `0.78..1.0` para no propagar tinta negra dentro del muñón oculto bajo el torso.
2. **Respaldo de seguridad (`polish_outlines.py`):** crea automáticamente `combat_assets/<pilot_id>_planar/_backup_before_outline_polish/` antes de mutar PNGs si no existe aún.
3. **Alineación y máscaras (`sanitize_masks_and_alignments`):** recorta `s/parts_5/leg_r_{id_mask,normal_depth}.png` `[8:739]` → `270x731` para empatar `leg_r.png`, rellena huecos `(0, 0, 0)` en `_normal_depth.png` por Voronoi, dilata canal `A` (cabello) de `head_*_id_mask.png` en `14 px` hacia el margen SDF exterior y restaura RGB de piel/cuello en `body_core.png` (`restore_body_core_neck_rgb`).
4. **Sanitización de cuñas (`sanitize_arm_underlap_wedges`):** reemplaza cuñas geodésicas negras en solapes detrás de `body_core` vía Voronoi; marca `_arm_underlap_sanitized = true` en `parts_5_meta.json`.
5. **Normalización de brazos traseros (`normalize_back_arm_outlines`):** en `s/arm_l` y `n/arm_r`, unifica el outline exterior a `~4.0` téxeles (`#040406`), levanta sombras interiores aplastadas preservando pliegues finos de armadura (`is_internal_crease`), y adelgaza la costura derecha del torso sobre `s/arm_l` (`_thin_s_body_core_breast_seam`); marca `_back_arm_outline_normalized = true` en `parts_5_meta.json`.

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
