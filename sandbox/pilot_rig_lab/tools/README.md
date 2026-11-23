# Pipeline Python Multi-Piloto v2 (`sandbox/pilot_rig_lab/tools/`)

> Guía de referencia rápida de scripts Python. Para el proceso completo de punta a punta, ver [`docs/PILOT_CREATION_PIPELINE.md`](../../../docs/PILOT_CREATION_PIPELINE.md).

## Entornos Python
- **Etapas estándar / CV / Upscayl / Scipy (`build_valentina_v2_rig_assets.py`, `ink_hq_pipeline.py`, `scaffold_new_pilot.py`, compiladores de alas/armas/banner):** `python` (`C:\Python313\python.exe` en este equipo)
- **Etapas ML offline (`prepare_8dir_sheets.py`, `prepare_ai_mask_workspaces.py`, `ml_stage_processors.py`):** `sandbox/pilot_rig_lab/tools/.venv/Scripts/python.exe` (o `python` según entorno instalado)

---

## 1. Scaffold de Nuevo Piloto (Cero copia manual)
| Script | Uso |
|---|---|
| `scaffold_new_pilot.py` | Genera el bundle completo en `data/pilots/<pilot_id>/` (`17` `.tres` raíz + `skins/*.tres` + skin catalog), carpetas vacías en `assets/pilots/<pilot_id>/` y `source_refs/<pilot_id>/00_raw/` con `.gdignore`. |

---

## 2. Pipeline Canónico v2 (Cuerpo 8-Dir, Cabezas, Tinta, Rostro, Alas, Armas, Banner)
| Orden / Dominio | Script(s) | Función |
|---|---|---|
| **1. Kit de generación IA** | `build_head_and_body_gen_kit.py` | Plantillas `2×2` / `4×2` (cabezas) y tira mínima de 5 cuerpos (`S, SE, E, NE, N`). |
| **2. Mateado & Alineación** | `prepare_8dir_sheets.py` | Upscayl 4×, recorte adaptativo, mateado `#808080` + IS-Net, canvas `1560×1680`. |
| **3. Cabezas 8-Dir** | `process_sw_and_8dir_heads.py` | Normaliza 8 cabezas a `1024×1024` y reconstruye `SW/W/NW` simétricos. |
| **4. Workspaces de Máscaras** | `prepare_ai_mask_workspaces.py` | Exporta bloques `16:9`/`4:3`/`1:1` e ingesta `01_parts_5_despiece` .. `05_secondary_jiggle_masks`. |
| **5. Ensamblado del Rig** | `build_valentina_v2_rig_assets.py` | Compila `parts_5/` (8 vistas), `heads/`, mapas `*_normal_depth.png`, `*_anim_mask.png`, `*_meta.json` y auditorías. |
| **6. Máscaras HQ por pieza** | `export_piece_mask_sheets.py`, `ingest_piece_mask_sheets.py` | Regeneración HQ de mapas `ID`, `Normal/Depth` e `ILM` por hoja estándar. |
| **7. Tinta Interna Ink SDF 2×** | `ink_hq_pipeline.py` | Export/Test/Apply de trazos HQ (`2×` + Upscayl + ECC/Farneback, `use_mipmaps = false`). |
| **8. Rig Facial & Ojos Live2D** | `export_head_live_mask_sheet.py`, `fuse_head_live_mask_sheet.py`, `ingest_head_live_rig_assets.py`, `export_eye_live2d_sheets.py`, `ingest_eye_live2d_assets.py` | Capas oculares/faciales separadas e injerto ocular `4× SSAA`. |
| **9. Alas 2D Base** | `build_valentina_v2_wings.py` | Compila 3 vistas `#808080` a 12 cuchillas 8-dir (`wings_metadata.json`). |
| **10. Arma & Anillo Orbital** | `build_valentina_weapon.py`, `build_orbital_ring_texture.py` | Compila arma multi-mapa (`albedo/id/ilm/ink_sdf 2×`) y anillo RGBA `1:1`. |
| **11. Live Banner 2.5D + Icono** | `build_valentina_live_banner.py` | Genera capas `body/free_arm/motion/fx/depth/normal/ink_sdf` e icono `512×512`. |

---

## 3. Overlays HD Opcionales (Refinamiento Local)
| Etapa | Exportador | Ingesta |
|---|---|---|
| **Caps de extremidades** | `export_cap_sheets_16x9.py` | `ingest_cap_sheets_16x9.py` |
| **Torsos HD** | `export_torso_and_profile_leg_sheets_16x9.py` | `ingest_hd_torsos_16x9.py` |
| **Hombreras y torsos/pauldron** | `export_pauldron_sheets_16x9.py`, `export_pauldron_polish_16x9.py` | `ingest_torso_and_pauldron_masks_16x9.py`, `ingest_pauldron_masks_16x9.py`, `ingest_pauldron_polish_16x9.py` |

---

## 4. Librerías y Helpers Compartidos (NO mover)
- `rig_v2_lib/` (`constants.py`, `mask_and_matting.py`, `skeleton_and_normals.py`, `heads_builder.py`, `part_exporter.py`, `limb_cap_stages.py`, `torso_pauldron_stages.py`, `limb_seal_stages.py`, `view_assembly_stages.py`, `audit_renderer.py`, `mask_workspace_prompts.py`, `piece_mask_prompts.py`)
- Módulos raíz importados por el pipeline v2 y `rig_v2_lib/`:
  - `process_masked_5parts.py` (`TEX_SCALE`, `upscale_with_upscayl`, `_align_mask_to_ref`, `_place_on_canvas`)
  - `polish_outlines.py` (`alpha_bleed_and_defringe`, `alpha_bleed_only`, `_voronoi_fill`, `HEAD_PAD_PX`)
  - `process_head_8dir_sheet.py` (`CELL_KEYS`, `_build_clean_head_normal_depth`, `_build_hair_jiggle_mask`)
  - `process_limb_anim_masks.py` (`MASK_SCALE`)
  - `id_mask_ink_refiner.py` (`refine_mask_ink_locked`, `voronoi_fill_labels`)
  - `ml_stage_processors.py` (`clear_vram`, `estimate_sapiens_normals_and_depth`)

---

## 5. `legacy_v1/` (Scripts v1 2-Dir `S`/`N` sin dependientes)
Scripts de etapas iniciales v1 archivados en `tools/legacy_v1/`:
`clean_edge_matting.py`, `generate_mask_sheets.py`, `process_parts5_1to1_maps.py`, `process_secondary_mask.py`, `build_head_8dir_guide.py`, `fix_shoulder_seams_and_coverage.py`.
