# Contexto del Agente — Astra Dream
> **Leer este archivo SIEMPRE antes de explorar cualquier otro.**
> Contiene la orientación fundamental para no realizar exploraciones ciegas ni consumir tokens innecesarios.
> Para el mapa detallado de subsistemas, contratos y suites de prueba, consultar [`docs/DOMAIN_MAP.md`](docs/DOMAIN_MAP.md).

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone activo:** M7 (Balance Fino)

---

## 🗂️ Mapa Rápido de Subsistemas

Para ubicar el código de cualquier dominio, consulta esta tabla antes de abrir archivos:

| Dominio | Archivo Principal / Orquestador | Componentes Clave |
|---|---|---|
| **Combate Raíz** | `scenes/combat/main_game.gd` | `combat_scene_assembler.gd`, `combat_context.gd`, `combat_wave_pipeline.gd`, `run_state_serializer.gd` |
| **Jugador 2D** | `scenes/combat/player/player.gd` | `player_locomotion_controller.gd`, `player_damage_processor.gd`, `player_economy_component.gd`, `player_death_sequence_controller.gd` |
| **Arsenal y Armas** | `scenes/combat/player/weapon_controller.gd` | `combat_targeting_system.gd`, `weapon_cooldown_tracker.gd`, `weapon_projectile_factory.gd`, `behaviors/` |
| **Danmaku / Balas** | `core/autoloads/bullet_server.gd` (Hijo de MainGame) | Pool contiguo `PackedFloat32Array`, zero-allocation, espacio absoluto |
| **Directores de Combate** | `scenes/combat/directors/` | `combat_boss_coordinator.gd`, `boss_encounter_spawner.gd`, `combat_narrative_director.gd` |
| **Encuentro Rival** | `scenes/combat/bosses/rival_pilot_boss.gd` | `rival_engagement_behavior.gd`, `rival_flight_motor.gd` |
| **Entorno y Fondo Espacial** | `scenes/combat/environment/space_environment_host.gd` | `base_space_environment.gd`, `cosmos_combat_environment.gd`, `cosmos/` (`CosmosHostController`, `CosmosRootNode`, `OrbitalWorldFollower2D`) |
| **Satélites y Estaciones** | `scenes/combat/systems/combat_satellite_coordinator.gd` | `satellite_odometer.gd`, `satellite_spawn_selector.gd`, `satellite_shop.gd`, `slot_machine_beacon.gd`, `transmutation_station.gd` |
| **HUD de Combate & Radares** | `scenes/ui/hud/hud.gd` | `hud_health_shield_display.gd`, `hud_satellite_radar_controller.gd`, `hud_edge_tracker_manager.gd`, `hud_dragon_radar_display.gd`, `dragon_radar_blip.gd` |
| **Modales de Combate** | `scenes/combat/ui/combat_modal_coordinator.gd` | Subscripciones FIFO a LevelUp, Shop, Arcanas, Banlist |
| **Game Over / Victoria** | `scenes/ui/game_over/game_over_modal.gd` | `game_over_layout_builder.gd`, `game_over_telemetry_formatter.gd` |
| **Salón de la Fama / Records** | `scenes/ui/highscores/highscores_modal.gd` | `highscores_table_builder.gd`, `highscores_tab_controller.gd` |
| **Hub 3D (Hangar)** | `scenes/ui/hub/hub_world.gd` | `hub_camera_controller_3d.gd`, `hub_input_dispatcher.gd`, `pedestal_visual_presenter.gd` |
| **Selección de Personaje** | `scenes/ui/character_select/character_select.gd` | `character_roster_grid_builder.gd`, `character_select_tab_controller.gd`, `arsenal_banlist_modal.gd` |
| **Gacha y Banners** | `scenes/ui/gacha/gacha_modal.gd` | `gacha_modal_layout_builder.gd`, `gacha_banner_engine.gd` |
| **Cosméticos y Skins** | `core/systems/cosmetics_manager.gd` | `cosmetic_carousel_modal.gd`, `cosmetic_carousel_layout_builder.gd` |
| **Persistencia y Guardado** | `core/autoloads/save_manager.gd` | Fachada estática -> `core/systems/persistence/` (`schemas/`, `meta_progression_state.gd`, `active_run_storage.gd`) |
| **Pausa del Juego** | `core/autoloads/pause_arbitrator.gd` | Tokens concurrentes (`PauseArbitrator.acquire_pause(...)`) |

---

## 🌌 Cosmos Engine en Producción (Entorno Espacial de MainGame)
- **Estado:** Promovido y blindado en producción bajo [`scenes/combat/environment/cosmos/`](scenes/combat/environment/cosmos/). Enlazado como entorno por defecto en `MainGame` vía [`SpaceEnvironmentHost`](scenes/combat/environment/space_environment_host.gd) y [`CosmosCombatEnvironment`](scenes/combat/environment/cosmos_combat_environment.gd).
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

## 🚫 ZONAS PROHIBIDAS DE EXPLORACIÓN AUTOMÁTICA
```
addons/                  <- Plugins de motor y herramientas externas
.godot/                  <- Cache generado automáticamente por Godot
preprocess/              <- Fuentes crudas de arte no procesadas
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
| `SceneTransition` | Fundidos y transiciones suaves de escena. |

---

## 🧪 Comandos Rápidos de Verificación (Latencia: 2 a 7 segundos)

El harness `tools/run_tests.ps1` admite coincidencia recursiva por subcadena:

| Sistema Modificado | Comando PowerShell Específico |
|---|---|
| **Cosmos / Fondo Espacial** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "space_environment"` |
| **Órbitas / Parallax Seguidor** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "orbital_binding_events"` |
| **HUD / Dragon Radar** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "dragon_radar"` |
| **HUD / Radar Satelital** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_edge_indicator"` |
| **Armas y Balística** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "weapons"` |
| **Jefes y Encuentros** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "boss"` |
| **Persistencia y Serialización** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"` |
| **Satélites y Economía** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_items"` |
| **Regresión Completa Core** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly` *(solo antes de cerrar tarea)* |

---

## 📋 Reglas Fundamentales de Desarrollo

1. **Zero-Allocation Danmaku:** Proyectiles masivos gestionados exclusivamente vía `BulletServer`. Prohibido instanciar `Area2D` individuales para balas masivas.
2. **Modularidad Radical:** Anti God-Objects. Todo script se mantiene desacoplado en componentes con responsabilidad única.
3. **Data-Driven Balance:** Todo valor numérico debe residir en recursos `.tres` (`WeaponData`, `CharacterData`, etc.). Cero números mágicos en GDScript.
4. **Tipado Estricto:** GDScript 4 con tipado estricto completo en variables miembro, variables locales, argumentos y retornos.
5. **Punto de Entrada Canónico:** Si buscas detalles de archivos o interfaces, consulta [`docs/DOMAIN_MAP.md`](docs/DOMAIN_MAP.md).
