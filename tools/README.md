# Herramientas de Raíz (`tools/`) — Astra Dream

> Para herramientas específicas del pipeline Multi-Piloto v2, ver [`sandbox/pilot_rig_lab/tools/README.md`](../sandbox/pilot_rig_lab/tools/README.md).

## 1. Verificación, Tests y Linter (Uso Diario)
| Archivo | Propósito |
|---|---|
| `run_tests.ps1` | Arnés principal anti-cuelgues para suites Godot (`-Test "<nombre>"`, `-Filter`, `-CoreOnly`). |
| `run_unit_fast.ps1` | Ejecutor rápido de suites unitarias ligeras. |
| `check_syntax.ps1` | Validación rápida de sintaxis GDScript vía Godot CLI. |
| `validate_gdscript.gd` / `.tscn` / `validate_gdscript_scene.gd` | Escenas y validadores auxiliares invocados para compilar scripts y detectar errores tipados. |

## 2. Launcher y Compilación
| Archivo | Propósito |
|---|---|
| `AstraLauncher.cs` | Código fuente del launcher Windows (`AstraLauncher.exe`). |
| `build_launcher.ps1` | Script de compilación de `AstraLauncher`. |
| `launcher.ps1` | Script auxiliar de arranque del proyecto. |
| `sync_assets.ps1` | Utilidad de sincronización de assets. |

## 3. Procesadores de Assets y Generadores `.tres`
| Archivo | Propósito |
|---|---|
| `cosmos_v2/` | Utilidades de generación de assets para Cosmos Engine v2. |
| `process_*.py`, `purify_sprite_pipeline.py` | Procesadores activos de grillas (`icons`, `talents`, `skill_grids`, `flat_stat_icons`, `parallax`, `planet_interiors`, `weapon_chroma`, `hub_o2_cutouts`, `chromakey`), retratos (`process_navigators.ps1`) y limpieza de sprites. |
| `generate_deep_starfield.py`, `generate_atlas_textures.py` | Generadores de texturas de espacio profundo y atlas de combate. |
| `generate_arcanas.gd`, `generate_item_resources.gd`, `generate_tome_resources.gd` | Generadores `.tres` nativos de Godot para arcanas, ítems y tomos. |
| `generate_pilot_skill_trees.py`, `update_item_tres_icons.py`, `update_pilot_weapon_icons.py`, `update_tres_icons.py`, `list_items_summary.py` | Generación/actualización de recursos de talentos, iconos `.tres` y resumen del roster. |

## 4. `legacy_art_experiments/` (Archivo de I+D v1)
Scripts históricos de experimentación CIELAB / recoloreo de skins v1 / avatares y placeholders iniciales movidos fuera de la raíz de `tools/` para mantener limpio el flujo diario. No son importados por producción ni por Pilot Rig Lab v2.
