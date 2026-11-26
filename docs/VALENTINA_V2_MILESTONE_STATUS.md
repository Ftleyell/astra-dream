# Valentina v2 — Estado de Milestone y Hoja de Ruta (`PilotRigLab` & Producción)

> **Propósito:** Índice ejecutivo del milestone **Valentina v2 (8-Dir Nativo)** tras cerrar su integración completa en producción (**Fases 1–5 ✅**), junto con los **Workbenches / Combat Gym** y el roadmap hacia **M8** y **M9**.
> **Plan Maestro de Integración (Fases 1–5 Cerradas ✅):** [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md)
> **Playbook para construir el resto del Cast:** [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md)
> **Reglas de edición y tabla contractual:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md)

---

## 1. Resumen del Milestone Alcanzado (Cerrado y Verificado en Producción)

| Área | Estado | Artefactos Clave | Especificación Técnica |
|---|---|---|---|
| **Rig 8-Dir Nativo + Mallas + 18 Huesos** | **Cerrado (Prod.)** | `scenes/pilots/rig/planar_combat_rig.gd`, `planar_rig_mesh_builder.gd`, `planar_rig_view_router.gd` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Máscaras HQ + Ink SDF 2× (65 mapas)** | **Cerrado (Prod.)** | `assets/pilots/valentina_v2/planar/**`, `sandbox/pilot_rig_lab/tools/ink_hq_pipeline.py` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Shaders Cel 2.5D + 3 Estilos + 10 Skins + 10 Pelos** | **Cerrado (Prod.)** | `scenes/pilots/shaders/pilot_rig_{stylizer,pass2}.gdshader`, `data/pilots/styles/*.tres`, `data/pilots/valentina_v2/skins/*.tres` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Animación Data-Driven (6 sistemas `.tres`)** | **Cerrado (Prod.)** | `data/pilots/valentina_v2/valentina_v2_*.tres` (Pose Base, Idle, Locomoción/Freno, Kiting 360°, Giros 2.5D, Jiggle) | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Rig Facial Vivo + Cabello 3-Zonas + Ojos Amatista** | **Cerrado (Prod.)** | `scenes/pilots/rig/planar_rig_face_controller.gd`, `data/pilots/valentina_v2/valentina_v2_face_anim.tres`, `rig_face_live.gdshaderinc` | [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md) |
| **Alas Psíquicas & Propulsión Base Multi-Piloto** | **Cerrado (Prod.)** | `scenes/pilots/vfx/valentina_base_propulsion_controller.gd`, `wing_red_glow.gdshader`, `data/pilots/valentina_v2/valentina_v2_base_propulsion.tres` | [`VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) |
| **VFX Power-Up Sandevistan (Estela Ping-Pong)** | **Cerrado (Prod.)** | `scenes/pilots/vfx/sandevistan_trail_controller.gd`, `scenes/pilots/shaders/sandevistan_*.gdshader`, `data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres` | [`VALENTINA_PROPULSION_VFX_SPEC.md`](VALENTINA_PROPULSION_VFX_SPEC.md) |
| **Anillo Orbital 2.5D & Guns Lab (1–4 Slots)** | **Cerrado (Prod.)** | `scenes/pilots/weapons/orbital_weapon_{ring_controller,3d_renderer}.gd`, `scenes/pilots/shaders/orbital_weapon_25d.gdshader`, `data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres` | [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) |
| **3D Lab & Alas 3D Cel-Shaded (*Astral Seraph*)** | **Cerrado (Prod.)** | `scenes/pilots/vfx/astral_wings_3d_{mesh_builder,controller}.gd`, `scenes/pilots/shaders/astral_wing_*.gdshader`, `data/pilots/valentina_v2/valentina_v2_wings_3d.tres` | [`VALENTINA_3D_LAB_SPEC.md`](VALENTINA_3D_LAB_SPEC.md) · [`VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md) |
| **Live Banner 2.5D + Icono 512×512 + Lockout Roster** | **Cerrado (Fase 2)** | `scenes/pilots/banner/pilot_live_banner_controller.gd`, `character_live_banner_viewport.gd`, `data/pilots/valentina_v2/valentina_v2_live_banner.tres`, `assets/pilots/valentina_v2/banner/` | [`VALENTINA_LIVE_BANNER_SPEC.md`](VALENTINA_LIVE_BANNER_SPEC.md) |
| **Hub 3D Embebido en `MainGame` + Astral Glide-Hop (`GaitStyle.ASTRAL_GLIDE_HOP`)** | **Cerrado (Prod.)** | `scenes/combat/controllers/combat_hub_session_controller.gd`, `scenes/ui/hub/astral_station/astral_station_hub.gd`, `scenes/combat/player/{player_rig_v2_controller,hub_landing_ripple_vfx}.gd`, `scenes/pilots/rig/planar_rig_grounded_evaluator.gd`, `data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres` *(legacy: `hub_rig_avatar_3d.gd`, `hub_world.tscn`)* | [`HUB_3D_REWORK_BLUEPRINT.md`](HUB_3D_REWORK_BLUEPRINT.md) · [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) |
| **Skins 100% por Shaders (`pilot` / `wings` / `weapon`)** | **Cerrado (Fase 4)** | `data/pilots/schemas/{shader_skin_entry,pilot_shader_skin_catalog}.gd`, `data/pilots/valentina_v2/valentina_v2_skin_catalog.tres`, `core/systems/cosmetics_manager.gd` | [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) |
| **Combate In-Game (`PlayerRigV2Controller`)** | **Cerrado (Fase 5)** | `scenes/combat/player/player_rig_v2_controller.gd`, `data/pilots/valentina_v2/valentina_v2_combat_rig.tres`, Twin-Stick 360°, `CosmicLightingSampler`, Sobre-Enfoque y 1–4 Armas | [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) |
| **Skill [R] & Ultimate [Q] en 4 Actos (3D + Sandevistan + Skin-Contrast)** | **Cerrado (Fase 1 Prod. + Lab)** | `scenes/pilots/vfx/abilities/{pilot_skin_palette_resolver,ultimate_sandevistan_radar_controller,ultimate_3d_stage_rig,pilot_cutin_theater,sniper_weakpoint_rail_vfx,ultimate_wing_barrage_controller}.gd`, `scenes/pilots/shaders/{cutin_skin_composite,fullscreen_impact_shatter,cutin_window_mask}.gdshader`, `data/pilots/valentina_v2/valentina_v2_{skill,ultimate}.tres`, `sandbox/workbenches/skill_ult_workbench/`, `vfx_lab/valentina_skill_ult_studio.tscn` | [`pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md) |
| **Workbenches & Combat Gym (`F6`)** | **Cerrado (Sandbox)** | `sandbox/workbenches/workbench_hub.tscn`, `hud_workbench/`, `dialogue_workbench/`, `character_select_workbench/`, `skill_ult_workbench/`, `sandbox/hub_art_lab/hub_locomotion_lab/`, `sandbox/combat_gym/combat_gym.tscn` | [`DOMAIN_MAP.md`](DOMAIN_MAP.md) |
| **Fábrica Multi-Piloto v2** | **Listo (Cast v2)** | `sandbox/pilot_rig_lab/tools/scaffold_new_pilot.py`, `sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd`, Playbook v2 | [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md) |
| **Backup Inmutable de Baseline** | **Cerrado** | `sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/` + tag Git `valentina-v2-clean-baseline` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |

---

## 2. Mapa de Labs, Workbenches y Suites de Prueba

### Lanzador Unificado (`F6` en Godot)
- **`sandbox/workbenches/workbench_hub.tscn`**: Centraliza los **Workbenches sobre producción** (`Combat Gym`, `HUD Workbench`, `Dialogue Workbench`, `Character Select Workbench`, `Hub Art Lab`, `Gacha 3D Lab`, **`Skill & Ult Workbench`**, **`Hub Locomotion Lab 3D`**), el selector global de **Piloto Activo** (`PilotLabSelector`) y el lanzamiento directo de los **Pilot Rig Labs** de `sandbox/pilot_rig_lab/`.

### Escenas de Laboratorio (`sandbox/pilot_rig_lab/` — Parametrizadas por Piloto)
1. **Arena Principal del Rig:** `proto/planar_combat_rig_proto.tscn`
2. **Laboratorio de Animación (6 pestañas):** `proto/planar_anim_test.tscn`
3. **Laboratorio Facial Aislado:** `face_lab/valentina_face_lab.tscn`
4. **Laboratorio A/B de Shaders:** `shader_lab/planar_shader_lab.tscn`
5. **Laboratorio VFX Alas + Sandevistan:** `vfx_lab/valentina_vfx_lab.tscn`
6. **Laboratorio de Armamento Orbital 2.5D (Guns Lab):** `guns_lab/valentina_guns_lab.tscn`
7. **Laboratorio Live Banner 2.5D (Banner Lab):** `banner_lab/valentina_banner_lab.tscn`
8. **Laboratorio 3D Cel-Shaded / Alas 3D (3D Lab):** `3d_lab/valentina_3d_lab.tscn`
9. **Laboratorio de Iluminación Cósmica:** `cosmos_lighting_lab/valentina_cosmos_lab.tscn`
10. **Calibrador de Anclas y Huesos:** `calibrator/rig_calibrator.tscn`
11. **Laboratorio Skill [R] & Ultimate [Q] (4 Actos 3D + Sandevistan):** `vfx_lab/valentina_skill_ult_studio.tscn`

### Comandos Rápidos de Verificación (`tests/sandbox/` & `tests/unit/`)
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_skill_ult_studio"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "workbenches_and_combat_gym" -TimeoutSeconds 35
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_player_valentina_v2_combat"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_shader_skins_system"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_main_game_embedded_hub" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_grounded_walk"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_locomotion_lab" -TimeoutSeconds 25
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_25d_valentina_rig"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_roster_rework_lockout"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_banner_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmic_lighting_sampler"
```

---

## 3. Roadmap Post-Milestone (Próximas Etapas)

### M8 — Pulido Integral In-Game, UI y Narrativa (Valentina v2)
1. **Equidistancia In-Game (Vida & Armas):** Calibrar `OverheadHealthBar.HEALTH_RING_RADIUS` vs `PilotOrbitalWeaponConfig` (`ring_radius_x`, `ring_radius_y`, `ring_center_offset`) en `CombatGym` (`[G]`), y separación de `WeaponSlotsRow` / `TacticalAbilitiesRow` / `BottomBar` en `HUDWorkbench`.
2. **Nuevos Retratos & Expresiones de Valentina en Diálogos:** Definir pipeline de retratos para `narrative/characters/valentina.dch` (y soporte dinámico de skins si aplica) y validar todos los eventos de `CombatNarrativeDirector` en `DialogueWorkbench`.
3. **Pulido de Selección de Personaje:** Afinar jerarquía visual, espaciado y presentación de `CharacterSelectUI` / `HeroPickerModal` en `CharacterSelectWorkbench`.

### M9 — Escalado del Cast Completo v2 (Nova, Kira, Selene, Roxy, Echo, Nyx)
- Seguir paso a paso [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md) usando `scaffold_new_pilot.py` + `WorkbenchHub` (`PilotLabSelector`) para crear, calibrar y habilitar (`is_playable_rework_ready = true`) una piloto por milestone atómico.
