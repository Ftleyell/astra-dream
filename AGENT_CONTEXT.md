# Contexto del Agente — Astra Dream
> **Leer este archivo SIEMPRE antes de explorar cualquier otro.**
> Contiene todo lo necesario para orientarse en una sesión sin exploración ciega.

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone activo:** M7 (Balance Fino)

---

## 🗂️ Mapa de Arquitectura y Subsistemas

Para localizar el código de cualquier sistema, consulta la tabla antes de abrir archivos:

| Dominio | Archivo Principal / Orquestador | Componentes Clave |
|---|---|---|
| **Combate Raíz** | `scenes/combat/main_game.gd` | `combat_scene_assembler.gd`, `combat_context.gd`, `combat_wave_pipeline.gd` |
| **Jugador 2D** | `scenes/combat/player/player.gd` | `player_locomotion_controller.gd`, `player_damage_processor.gd`, `player_economy_component.gd`, `player_death_sequence_controller.gd` |
| **Arsenal y Armas** | `scenes/combat/player/weapon_controller.gd` | `combat_targeting_system.gd`, `weapon_cooldown_tracker.gd`, `weapon_projectile_factory.gd`, `behaviors/` |
| **Danmaku / Balas** | `core/autoloads/bullet_server.gd` (Hijo de MainGame) | Pool contiguo `PackedFloat32Array`, zero-allocation |
| **Directores de Combate** | `scenes/combat/directors/` | `combat_boss_coordinator.gd`, `boss_encounter_spawner.gd`, `combat_narrative_director.gd` |
| **Encuentro Rival** | `scenes/combat/bosses/rival_pilot_boss.gd` | `rival_engagement_behavior.gd`, `rival_flight_motor.gd` |
| **Entorno y Fondo Espacial** | `scenes/combat/environment/space_environment_host.gd` | `base_space_environment.gd`, `combat_space_debris_manager.gd` |
| **Satélites y Estaciones** | `scenes/combat/systems/combat_satellite_coordinator.gd` | `satellite_odometer.gd`, `satellite_spawn_selector.gd`, `satellite_shop.gd` |
| **HUD de Combate** | `scenes/ui/hud/hud.gd` | `hud_health_shield_display.gd`, `hud_weapon_cooldown_bar.gd`, `hud_satellite_radar_controller.gd`, `hud_edge_tracker_manager.gd` |
| **Modales de Combate** | `scenes/combat/ui/combat_modal_coordinator.gd` | Subscripciones FIFO a LevelUp, Shop, Arcanas |
| **Hub 3D (Hangar)** | `scenes/ui/hub/hub_world.gd` | `hub_camera_controller_3d.gd`, `hub_input_dispatcher.gd`, `pedestal_visual_presenter.gd` |
| **Selección de Personaje** | `scenes/ui/character_select/character_select.gd` | `character_roster_grid_builder.gd`, `character_select_tab_controller.gd`, `character_select_modal_router.gd`, `arsenal_banlist_modal.gd` |
| **Gacha y Banners** | `scenes/ui/gacha/gacha_modal.gd` | `gacha_modal_layout_builder.gd`, `gacha_banner_engine.gd` |
| **Cosméticos y Skins** | `core/systems/cosmetics_manager.gd` | `cosmetic_carousel_modal.gd`, `cosmetic_carousel_layout_builder.gd` |
| **Persistencia y Guardado** | `core/autoloads/save_manager.gd` | Fachada estática -> `core/systems/persistence/` (`schemas/`, `meta_progression_state.gd`, `active_run_storage.gd`) |
| **Pausa del Juego** | `core/autoloads/pause_arbitrator.gd` | Tokens concurrentes (`PauseArbitrator.acquire_pause(...)`) |

---

## 🚫 ZONAS PROHIBIDAS — Prohibido Explorar

```
addons/                  <- Plugins de motor y herramientas externas
.godot/                  <- Cache generado automáticamente por Godot
scratch/                 <- Temporales de pruebas
sandbox/                 <- Shaders y prototipos aislados
preprocess/              <- Fuentes crudas de arte no procesadas
```

---

## ⚙️ Los 7 Autoloads (Servicios Globales)

| Autoload | Responsabilidad |
|---|---|
| `PauseArbitrator` | Gestión concurrente de tokens de pausa. **Prohibido** modificar `get_tree().paused` directo. |
| `SettingsManager` | Ajustes de gráficos, audio, controles y accesibilidad. |
| `SaveManager` | Fachada global de persistencia delegada en schemas DTO tipados. |
| `DebugManager` | Control de utilidades de depuración en runtime y builds. |
| `EventBus` | Señales globales desacopladas entre dominios. |
| `AudioManager` | BGM reactiva, SFX balísticos y buses de audio. |
| `SceneTransition` | Fundidos y transiciones suaves de escena. |

---

## 📋 Reglas Fundamentales de Desarrollo

1. **Zero-Allocation Danmaku:** Proyectiles masivos gestionados exclusivamente vía `BulletServer`. Prohibido instanciar `Area2D` individuales para balas masivas.
2. **Modularidad Estricta:** Anti God-Objects. Todo script se mantiene desacoplado en componentes con responsabilidad única.
3. **Data-Driven Balance:** Todo valor numérico debe residir en recursos `.tres` (`WeaponData`, `CharacterData`, etc.). Cero números mágicos en GDScript.
4. **Tipado Estricto:** GDScript 4 con tipado estricto completo en variables, retornos y argumentos.
5. **Verificación de Tests:** Correr tests aislados por runner específico:
   `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<test_runner.tscn>"`
