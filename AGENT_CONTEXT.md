# Contexto del Agente — Stela Galactica (repo `astra_dream`)
> **Leer este archivo SIEMPRE antes de explorar cualquier otro.**
> Contiene la orientación fundamental para no realizar exploraciones ciegas ni consumir tokens innecesarios.
> Para el mapa detallado de subsistemas, contratos y suites de prueba, consultar [`docs/DOMAIN_MAP.md`](docs/DOMAIN_MAP.md) y el índice maestro [`docs/README.md`](docs/README.md).

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone activo:** M8 (Pulido In-Game & Fábrica Multi-Piloto v2)

---

## 🗂️ Mapa Rápido de Subsistemas

Para ubicar el código de cualquier dominio, consulta esta tabla antes de abrir archivos:

| Dominio | Archivo Principal / Orquestador | Componentes Clave |
|---|---|---|
| **Identidad, Título & Singularidad** | `scenes/combat/controllers/combat_title_session_controller.gd` + `core/systems/singularity_transition_presenter.gd` | `StelaLogoStage` (4 capas + `CosmicLightingSampler`), `TitleMenuOverlay`, `title_screen.gd` (Boot Preloader), shaders `stela_logo_*` / `singularity_transition`, `tools/process_stela_logo.py` *(doc: [`docs/STELA_GALACTICA_IDENTITY_AND_ONBOARDING.md`](docs/STELA_GALACTICA_IDENTITY_AND_ONBOARDING.md))* |
| **Combate Raíz** | `scenes/combat/main_game.gd` | `combat_scene_assembler.gd`, `combat_context.gd`, `combat_wave_pipeline.gd`, `controllers/{combat_title_session_controller,combat_hub_session_controller}.gd`, `run_state_serializer.gd` |
| **Jugador 2D** | `scenes/combat/player/player.gd` | `player_locomotion_controller.gd`, `player_damage_processor.gd`, `player_economy_component.gd`, `player_death_sequence_controller.gd`, `player_rig_v2_controller.gd`, `hub_landing_ripple_vfx.gd` |
| **Arsenal y Armas** | `scenes/combat/player/weapon_controller.gd` | `combat_targeting_system.gd`, `weapon_cooldown_tracker.gd`, `weapon_projectile_factory.gd`, `behaviors/` |
| **Danmaku / Balas** | `core/autoloads/bullet_server.gd` (Hijo de MainGame) | Pool contiguo `PackedFloat32Array`, zero-allocation, espacio absoluto |
| **Directores de Combate** | `scenes/combat/directors/` | `combat_boss_coordinator.gd`, `boss_encounter_spawner.gd`, `combat_narrative_director.gd` |
| **Voces & Mumble Speech** | `core/audio/dialogic_mumble_bridge.gd` | `mumble_speech_controller.gd`, `data/voices/voice_profile_registry.gd`, `data/voices/profiles/*.tres` |
| **Bifurcaciones de Run (Forks)** | `scenes/combat/directors/combat_fork_director.gd` | `run_modifier_manager.gd`, `run_fork_overlay.gd`, `fork_choice_card.gd`, `core/data/run_forks/` |
| **Encuentro Rival** | `scenes/combat/bosses/rival_pilot_boss.gd` | `rival_engagement_behavior.gd`, `rival_flight_motor.gd` |
| **Entorno y Fondo Espacial** | `scenes/combat/environment/space_environment_host.gd` | `base_space_environment.gd`, `cosmos_combat_environment.gd`, `cosmos/` (`CosmosHostController`, `CosmosRootNode`, `OrbitalWorldFollower2D`) |
| **Satélites y Estaciones** | `scenes/combat/systems/combat_satellite_coordinator.gd` | `satellite_odometer.gd`, `satellite_spawn_selector.gd`, `satellite_shop.gd`, `slot_machine_beacon.gd`, `transmutation_station.gd` |
| **HUD de Combate & Radares** | `scenes/ui/hud/hud.gd` | `hud_health_shield_display.gd`, `hud_satellite_radar_controller.gd`, `hud_edge_tracker_manager.gd`, `hud_dragon_radar_display.gd`, `dragon_radar_blip.gd` |
| **Modales de Combate** | `scenes/combat/ui/combat_modal_coordinator.gd` | Subscripciones FIFO a LevelUp, Shop, Arcanas, Banlist |
| **Game Over / Victoria** | `scenes/ui/game_over/game_over_modal.gd` | `game_over_layout_builder.gd`, `game_over_telemetry_formatter.gd` |
| **Salón de la Fama / Records** | `scenes/ui/highscores/highscores_modal.gd` | `highscores_table_builder.gd`, `highscores_tab_controller.gd` |
| **Hub 3D (Estación Astral v4 embebido en `MainGame`)** | `scenes/combat/controllers/combat_hub_session_controller.gd` + `scenes/ui/hub/astral_station/astral_station_hub.gd` | `hub_embedded_viewport_bridge.gd` (paridad ortográfica 2D↔3D sobre `CosmosCombatEnvironment`), materialización hexagonal (`demat_invert`), `HubTutorialDirector` (Dialogic nativo Mochi + `tutorial_highlight_pulse` + `? Guía` / `[F1]`, `hub_tutorial_completed`), `Player` 2D único (`PlayerRigV2Controller` con **Astral Glide-Hop** `GaitStyle.ASTRAL_GLIDE_HOP` ↔ Vuelo Zero-G + Dash pacífico), seed `AUTO` fresca por visita, exclusión/supresión de spawners (`29.5 m` / `6.0 s` cono frontal), sombras `SHADOW_ORTHOGONAL`, zoom cercano `2.60×`/`2.50×`, modales/alas `hub_*` y despegue zero-rail *(standalone: `astral_station_hub.tscn`; labs: `sandbox/hub_art_lab/{hub_art_lab.gd,hub_locomotion_lab/}`; legacy: `hub_world.gd`)* |
| **Selección de Personaje** | `scenes/ui/character_select/character_select.gd` | `character_roster_grid_builder.gd`, `character_live_banner_viewport.gd`, `character_pilot_showcase.gd`, `hero_picker_modal.gd`, `arsenal_banlist_modal.gd` |
| **Gacha y Banners** | `scenes/ui/gacha/gacha_modal.gd` | `gacha_modal_layout_builder.gd`, `gacha_banner_engine.gd`, `gacha_reveal_theater.gd`, `gacha_wardrobe_controller.gd` |
| **Cosméticos y Skins** | `core/systems/cosmetics_manager.gd` | `cosmetic_carousel_modal.gd`, `cosmetic_carousel_layout_builder.gd`, `shader_skin_live_preview.gd`, `shader_skin_swatch.gd` |
| **Pilotos & Rig Valentina v2 (Prod.)** | `scenes/pilots/rig/planar_combat_rig.gd` | `scenes/pilots/{rig,shaders,vfx,weapons,banner}/`, `data/pilots/`, `assets/pilots/` (*Single Source of Truth*) |
| **Estudio Arte & Rigs Pilotos (I+D)** | `sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn` | Labs interactivos (`proto/`, `face_lab/`, `vfx_lab/` + `valentina_skill_ult_studio.tscn`, `guns_lab/`, `3d_lab/`, `banner_lab/`, `dialogue_lab/`) consumiendo producción; docs `VALENTINA_V2_*.md` |
| **Workbenches & Combat Gym (Sandbox)** | `sandbox/workbenches/workbench_hub.tscn` | `sandbox/workbenches/{sfx_lab,hud_workbench,dialogue_workbench,character_select_workbench,skill_ult_workbench,stela_intro_lab,shared}/`, `sandbox/hub_art_lab/` y `sandbox/combat_gym/combat_gym.tscn` consumiendo escenas reales de producción |
| **Audio, SFX v2 & SfxLab** | `core/autoloads/audio_manager.gd` + `data/audio/default_sfx_cue_bank.tres` | `core/audio/{sfx_cue_data,sfx_cue_bank,sfx_density_tracker,audio_mix_director,ambience_crossfade_controller}.gd`, 7 buses (`default_bus_layout.tres`), 7 familias en `data/weapons/**/*.tres`, `tools/normalize_sfx.py`, lab [`SfxLab`](sandbox/workbenches/sfx_lab/sfx_lab.tscn) + librería en `sandbox/workbenches/sfx_lab/packs/` *(doc: [`docs/SFX_AUDIO_AND_LAB_GUIDE.md`](docs/SFX_AUDIO_AND_LAB_GUIDE.md), regla: [`.agents/rules/audio_sfx.md`](.agents/rules/audio_sfx.md))* |
| **Persistencia y Guardado** | `core/autoloads/save_manager.gd` | Fachada estática -> `core/systems/persistence/` (`schemas/`, `meta_progression_state.gd`, `active_run_storage.gd`) |
| **Pausa del Juego** | `core/autoloads/pause_arbitrator.gd` | Tokens concurrentes (`PauseArbitrator.acquire_pause(...)`) |

---

## 🌌 Cosmos Engine en Producción (Entorno Espacial de MainGame)
- **Estado:** **v3.2c Completo (Fase 3 Rework Hub 3D Cerrada — Listo para Fase 4 Skins por Shader)** bajo [`scenes/combat/environment/cosmos/`](scenes/combat/environment/cosmos/). Enlazado en `MainGame` vía [`SpaceEnvironmentHost`](scenes/combat/environment/space_environment_host.gd) y [`CosmosCombatEnvironment`](scenes/combat/environment/cosmos_combat_environment.gd). Incluye:
  - Órbitas 3D orgánicas keplerianas, rotación planetaria multi-mapa + anillos estilizados, cometas tangentes a `-vel.normalized()` y guías `[O]`/`[G]` (`CosmosOrbitGuidesOverlay2D`).
  - 7 arquetipos estelares (`black_hole` con lente gravitacional y `emerald_nova`), 4 sectores no estelares (~35% de parcelas: `Rogue World`, `Derelict Armada`, `Warp Relay`, `Ion Nursery`), corredores interestelares (`hyperspace`, `bow-shocks`, meteoros, ríos laminares de asteroides) y landmarks lejanos en perspectiva 3D detrás de `DustMidSprite` (`z_index = -25`).
  - Puente analítico zero-alloc [`CosmicLightingSampler`](scenes/combat/environment/cosmos/core/cosmic_lighting_sampler.gd) (`sample_lighting_at(...)` desde `CosmosHostController`) calibrado en `sandbox/pilot_rig_lab/cosmos_lighting_lab/valentina_cosmos_lab.tscn`.
- **Contratos Arquitectónicos Blindados:**
  1. **Floating Origin:** Desactivado asertivamente en combate para salvaguardar la memoria contigua de `BulletServer`.
  2. **Slots Orbitales:** `CosmosOrbitSlot` opera como *Value Object* puramente analítico $\mathcal{O}(1)$ sin punteros al SceneTree.
  3. **Seguidores de Mundo:** `OrbitalWorldFollower2D` proporciona anti-snapping suave ($0.4\,\text{s}$) y bypass si `scroll_scale == (1,1)`.
  4. **Semillas Canónicas:** `main_game.run_seed` se inyecta de forma determinista y se restaura vía `RunStateSerializer`.
  5. **Escalabilidad GPU:** `SettingsManager.space_background_quality` (0=Bajo/iGPU, 1=Medio/Steam Deck, 2=Alto/Desktop) conmuta `CanvasLayerStarfield` y complejidad de shaders.
- **⚡ CERO TOKENS PERDIDOS / ANTI-CICLOS DE RELECTURA:**
  - **Prohibido abrir o reescribir scripts orquestadores `.gd`** para balances estéticos o ajustes numéricos.
  - Para ajustar cualquier aspecto visual o de balance (soles, sombras, órbitas, escombros, nebulosas, galaxias), editar **directamente** los `.tres` en [`scenes/combat/environment/cosmos/resources/data/`](scenes/combat/environment/cosmos/resources/data/) consultando [`.agents/rules/cosmos_engine.md`](.agents/rules/cosmos_engine.md).
- `sandbox/`: Banco de pruebas y playground experimental aislado de I+D (prohibido enlazar a combate).

---

## 🎭 Valentina v2 (Producción *Single Source of Truth* & Labs en Sandbox)
- **Estado:** Runtime, shaders, `.tres` y assets compilados de **Valentina v2 (8-Dir Nativo)** promovidos a producción como *Single Source of Truth* bajo [`scenes/pilots/`](scenes/pilots/), [`data/pilots/`](data/pilots/) y [`assets/pilots/`](assets/pilots/), mientras [`sandbox/pilot_rig_lab/`](sandbox/pilot_rig_lab/) conserva los laboratorios interactivos consumiendo producción (`tools/`, `source_refs/` y `backups/` aislados). Incluye enrutado 8-dir (`±65°`), transiciones snappy (Modos 4/5/6 + whip cervical), pipeline de animación data-driven (Pose Base Zero-G, Idle multicapa, Locomoción/Freno, Kiting 360°, Giros 2.5D, Jiggle sutil), **Rig Facial Vivo & Cabello 3-Zonas** (`planar_rig_face_controller.gd`, paleta ocular *Amatista Profundo*), **Alas Psíquicas & Propulsión Base Multi-Piloto** (`enable_base_propulsion_wings` / `enable_3d_wings`), tinta **Ink SDF 2×**, **Live Banner 2.5D** en `CharacterSelectUI`/`HeroPickerModal` y bloqueo de roster con `is_playable_rework_ready` (solo `valentina` activa).
  - **Live Banner 2.5D (Fase 2), Hub 3D 2.5D Diorama (`HubRigAvatar3D`, Fase 3), Sistema de Skins 100% por Shaders (Fase 4) y Combate In-Game (`PlayerRigV2Controller` + Anillo Orbital 1–4 Slots, Fase 5):** cerrados y verificados en producción (`pilot`/`wings`/`weapon`, `"follow_pilot"`, Twin-Stick 360°, `CosmicLightingSampler`, Sobre-Enfoque completo y compatibilidad legacy intacta); consultar [`docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md).
- **⚡ CERO TOKENS PERDIDOS / ANTI-CICLOS DE RELECTURA:**
  - Leer **siempre** [`.agents/rules/pilot_rig_lab.md`](.agents/rules/pilot_rig_lab.md) (tabla contractual *"Qué cambiar → Archivo exacto"*), [`docs/README.md`](docs/README.md) (índice vivo), [`docs/PILOT_CREATION_PIPELINE.md`](docs/PILOT_CREATION_PIPELINE.md) (Playbook Cast v2 + `sandbox/pilot_rig_lab/tools/scaffold_new_pilot.py`), [`docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](docs/VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) (Fases 1–5 completadas) y [`docs/VALENTINA_V2_MILESTONE_STATUS.md`](docs/VALENTINA_V2_MILESTONE_STATUS.md) (M8/M9).
  - Para ajustar escalas, poses, animaciones, rostro, skins, pelo o estilos, editar **directamente** los `.tres` en `data/pilots/valentina_v2/` (o `data/pilots/<pilot_id>/`), `data/pilots/hair/`, `data/pilots/styles/`.
  - **Prohibido** hacer listados recursivos o búsquedas en `sandbox/pilot_rig_lab/tools/.venv/`, `source_refs/`, `assets/pilots/`, `backups/` o `tools/models/`.

---

## 🚫 ZONAS PROHIBIDAS DE EXPLORACIÓN AUTOMÁTICA
```
addons/                                <- Plugins de motor y herramientas externas
.godot/                                <- Cache generado automáticamente por Godot
preprocess/                            <- Fuentes crudas de arte no procesadas
sandbox/pilot_rig_lab/tools/.venv/     <- Entorno virtual Python (30,351+ archivos)
sandbox/pilot_rig_lab/tools/models/    <- Pesos ONNX / modelos locales
sandbox/pilot_rig_lab/source_refs/     <- Arte crudo IA y workspaces offline (685+ archivos)
assets/pilots/<pilot_id>/planar/       <- Asset packs PNG/JSON compilados en producción
sandbox/pilot_rig_lab/backups/         <- Snapshot inmutable de baseline calibrado
sandbox/workbenches/sfx_lab/packs/     <- Librería fuente de 699 OGGs (con .gdignore)
```

---

## ⚙️ Los 7 Autoloads (Servicios Globales)

| Autoload | Responsabilidad |
|---|---|
| `PauseArbitrator` | Gestión concurrente de tokens de pausa. **Prohibido** modificar `get_tree().paused` directo. |
| `SettingsManager` | Ajustes de gráficos, audio, controles, calidad de fondo y accesibilidad. |
| `SaveManager` | Fachada global de persistencia delegada en schemas DTO tipados. |
| `DebugManager` | Control de utilidades de depuración en runtime y builds. |
| `EventBus` | Señales globales desacopladas entre dominios. |
| `AudioManager` | BGM reactiva, SFX balísticos y buses de audio. |
| `SceneTransition` | Transiciones cinemáticas **Singularidad** (3 fases + `load_threaded_request`) vía `SingularityTransitionPresenter`. |

---

## 🧪 Comandos Rápidos de Verificación (Latencia: 2 a 7 segundos)

El harness `tools/run_tests.ps1` admite coincidencia recursiva por subcadena:

| Sistema Modificado | Comando PowerShell Específico |
|---|---|
| **Cosmos / Fondo Espacial** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "space_environment"` |
| **Órbitas 3D & Cometas (Cosmos v3.1)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "kepler_3d_orbits"` |
| **Sectores No Estelares (Cosmos v3.2)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "living_universe_sectors"` |
| **Corredores Interestelares (Cosmos v3.2c)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "interstellar_corridors"` |
| **Luz Dinámica Cosmos ↔ Rig** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmic_lighting_sampler"` |
| **Órbitas / Parallax Seguidor** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "orbital_binding_events"` |
| **HUD / Dragon Radar** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "dragon_radar"` |
| **HUD / Radar Satelital** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_edge_indicator"` |
| **Armas y Balística** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "weapons"` |
| **Jefes y Encuentros** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "boss"` |
| **Persistencia y Serialización** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"` |
| **Satélites y Economía** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_items"` |
| **Bifurcaciones de Run (Forks)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "run_fork"` |
| **Estudio Arte / PilotRigLab (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"` |
| **Face Lab / Rig Facial (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"` |
| **VFX Lab / Alas + Sandevistan (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"` |
| **Skill & Ult Studio / Workbench (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_skill_ult_studio"` |
| **Guns Lab / Anillo Orbital 2.5D (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab"` |
| **3D Lab / Alas 3D Cel-Shaded (Estándar)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"` |
| **Banner Lab / Live Splash 2.5D (I+D)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_banner_lab"` |
| **Roster Lockout & Live Banner (Fase 2)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_roster_rework_lockout"` |
| **Identidad *Stela Galactica*, Singularidad & Tutorial Hub** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_stela_identity_and_tutorial" -TimeoutSeconds 35` |
| **Title Screen & Navegación Hub** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_title_and_hub_navigation" -TimeoutSeconds 25` |
| **Hub 3D Embebido en MainGame (Integración)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_main_game_embedded_hub" -TimeoutSeconds 30` |
| **Locomoción Grounded / Astral Glide-Hop Hub** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_grounded_walk"` |
| **Hub 3D Estación Astral v4 (Prod.)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_astral_station_hub_production"` |
| **Hub Art Lab & Mallas (Sandbox)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_art_lab" -TimeoutSeconds 30` |
| **Hub Locomotion Lab 3D (Sandbox)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_locomotion_lab" -TimeoutSeconds 25` |
| **Hub 3D 2.5D Diorama & Rig (Legacy/Fase 3)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_25d_valentina_rig"` |
| **Skins 100% por Shaders (Fase 4)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_shader_skins_system"` |
| **Combate In-Game Valentina v2 (Fase 5)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_player_valentina_v2_combat"` |
| **Workbenches & Combat Gym (Sandbox)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "workbenches_and_combat_gym"` |
| **AudioManager v2 (Cues, Buses, Ambience)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_audio_manager_v2"` |
| **SfxLab Workbench & Presets** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_sfx_lab" -TimeoutSeconds 35` |
| **Regresión Completa Core** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly` *(solo antes de cerrar tarea)* |

---

## 📋 Reglas Fundamentales de Desarrollo

1. **Zero-Allocation Danmaku:** Proyectiles masivos gestionados exclusivamente vía `BulletServer`. Prohibido instanciar `Area2D` individuales para balas masivas.
2. **Modularidad Radical:** Anti God-Objects. Todo script se mantiene desacoplado en componentes con responsabilidad única.
3. **Data-Driven Balance:** Todo valor numérico debe residir en recursos `.tres` (`WeaponData`, `CharacterData`, etc.). Cero números mágicos en GDScript.
4. **Tipado Estricto:** GDScript 4 con tipado estricto completo en variables miembro, variables locales, argumentos y retornos.
5. **Punto de Entrada Canónico:** Si buscas detalles de archivos o interfaces, consulta [`docs/DOMAIN_MAP.md`](docs/DOMAIN_MAP.md).
