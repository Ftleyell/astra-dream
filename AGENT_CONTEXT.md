# Contexto del Agente — Astra Dream
> **Leer este archivo SIEMPRE antes de explorar cualquier otro.**
> Contiene todo lo necesario para orientarse en una sesión sin exploración ciega.

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone activo:** M7 (Balance Fino)

---

## 🗂️ Mapa Sistema → Archivo Principal

> Para encontrar el código de cualquier sistema, ir primero a este archivo.
> Leer solo el rango indicado mediante `view_file` con `StartLine` y `EndLine` — no el archivo completo.

| Si el cambio/bug está en... | Archivo | Rango clave |
| Selección de personaje (ESC, launch, skins, hero picker) | `scenes/ui/character_select/character_select.gd` | Orquestador: L234, Input: L447, Roster: L488 |
| Constructor de tarjetas del elenco (CharacterSelect) | `scenes/ui/character_select/components/character_roster_grid_builder.gd` | Grilla procedural, avatares, bordes y hover |
| Tabs (Loadout ↔ Habilidades) en CharacterSelect | `scenes/ui/character_select/components/character_select_tab_controller.gd` | — |
| Enrutamiento de modales CharacterSelect | `scenes/ui/character_select/components/character_select_modal_router.gd` | — |
| Presentación visual y habilidades CharacterSelect | `scenes/ui/character_select/components/character_select_display_manager.gd` | — |
| Secuencia de lanzamiento y retorno Hub | `scenes/ui/character_select/components/character_select_launch_controller.gd` | — |
| Coordinador de skins / companion / gacha | `scenes/ui/character_select/components/character_skin_coordinator.gd` | — |
| Malla y router de foco teclado/gamepad | `scenes/ui/character_select/components/character_focus_router.gd` | — |
| Combate (orquestador raíz) | `scenes/combat/main_game.gd` | Orquestador: L420 |
| Ensamblado e inicialización de escena de combate | `scenes/combat/systems/combat_scene_assembler.gd` | Bootstrap de modales, directores y cableado reactivo |
| Coordinador de modales y colas reactivas | `scenes/combat/ui/combat_modal_coordinator.gd` | Cola FIFO de modales, LevelUp, Tienda y Arcanas |
| Orquestación de encuentros y rivales | `scenes/combat/controllers/combat_encounter_controller.gd` | — |

| Feedback sensorial y trauma de cámara | `scenes/combat/systems/combat_player_feedback_coordinator.gd` | Shake, daño y enrutamiento de muerte |
| Optimizador de gemas y batching de EXP | `scenes/combat/systems/combat_exp_batch_optimizer.gd` | Agrupación periódica de cristales distantes |
| Despacho de inputs y hotkeys de combate | `scenes/combat/controllers/combat_input_dispatcher.gd` | Toggle de debug F1 y hotkeys |
| Interacciones tácticas de campo (Chronos/Salvage) | `scenes/combat/systems/combat_tactical_interactions.gd` | — |
| Bootstrap de loadouts y branches debug | `scenes/combat/systems/combat_bootstrapper.gd` | — |
| Pipeline y ciclo de vida de oleadas | `scenes/combat/directors/combat_wave_pipeline.gd` | State machine & subsystem dispatch |
| Contexto desacoplado de combate | `scenes/combat/systems/combat_context.gd` | Inyección de actores centrales |
| Interfaz base de subsistemas Plug&Play | `scenes/combat/systems/combat_subsystem.gd` | Contrato virtual CombatSubsystem |
| Fin de partida y derrota | `scenes/combat/controllers/combat_end_run_controller.gd` | Telemetría y modal de game over |
| Jugador (orquestador raíz) | `scenes/combat/player/player.gd` | Orquestador: L250, Damage: L540 |
| Locomoción y cinemática 360° del jugador | `scenes/combat/player/player_locomotion_controller.gd` | Vuelo, bank tilt, tactical focus, core hitbox |
| Economía y experiencia in-run del jugador | `scenes/combat/player/player_economy_component.gd` | Exp, levels, credits, biomass, dark matter |
| Procesador de daño y OSP del jugador | `scenes/combat/player/player_damage_processor.gd` | Mitigación, One-Shot Protection, invulnerabilidad |
| Inventario de arcanas del jugador | `scenes/combat/player/player_arcana_inventory.gd` | Registro y aplicación de modificadores de arcanas |
| Hub 3D (hangar, pilotos, terminales, skill tree) | `scenes/ui/hub/hub_world.gd` | Pilot select: L382, Interactables: L312 |
| Cinemática y paralaje de cámara Hub 3D | `scenes/ui/hub/components/hub_camera_controller_3d.gd` | FOV, posicionamiento y paralaje estelar |
| Despacho de atajos e inputs del Hub | `scenes/ui/hub/components/hub_input_dispatcher.gd` | ESC en modales, Q quit y settings |
| Coordinación de jefes y colosos (CombatSubsystem) | `scenes/combat/directors/combat_boss_coordinator.gd` | Orquestador: L36, Spawner: BossEncounterSpawner, Cinemática: BossCinematicSequence, HUD: BossHealthBarManager |
| Spawner y escalado de colosos y rivales | `scenes/combat/directors/boss_encounter_spawner.gd` | Instanciación y escalado de vida adaptativo |
| Jefe rival y duelos 1v1 (Flota Astra) | `scenes/combat/bosses/rival_pilot_boss.gd` | Orquestador de duelo rival |
| Máquina de estados de rival (reto vs perdón) | `scenes/combat/bosses/components/rival_engagement_behavior.gd` | Radios de advertencia, challenge timer y spared timer |
| Cinemática y motor de vuelo rival | `scenes/combat/bosses/components/rival_flight_motor.gd` | Vuelo orbital, micro-dashes y bank tilt shader |
| Controlador maestro de armas | `scenes/combat/player/weapon_controller.gd` | Orquestador de arsenal y equipamiento |
| Autoaim y adquisición de blancos 2D | `scenes/combat/player/combat_targeting_system.gd` | Priorización de blancos, toggle manual y stutter field |
| Tracker de cooldowns y carga láser | `scenes/combat/player/weapon_cooldown_tracker.gd` | Cooldowns activos/pasivos, carga continua y memoria |
| Narrativa, radio, diálogos in-run (CombatSubsystem) | `scenes/combat/directors/combat_narrative_director.gd` | — |
| Satélites orbitales y estaciones (CombatSubsystem) | `scenes/combat/systems/combat_satellite_coordinator.gd` | Orquestador satelital |
| Odómetro de vuelo espacial | `scenes/combat/satellite/components/satellite_odometer.gd` | Tracking de distancia pura |
| Selector de estaciones orbitales | `scenes/combat/satellite/components/satellite_spawn_selector.gd` | Selección y proyección extensible |
| Contrato base de estación interactuable | `scenes/combat/satellite/components/base_space_station.gd` | Contrato polimórfico de estación |
| Administrador de debris espacial y macro-objetos | `scenes/combat/systems/combat_space_debris_manager.gd` | Asteroides, planetas y monolitos |
| Recompensas y tragamonedas (CombatSubsystem) | `scenes/combat/systems/combat_loot_coordinator.gd` | — |
| Fábrica balística extensible (Strategy Pattern) | `scenes/combat/weapons/weapon_projectile_factory.gd` | Registro abierto de proyectiles |
| Estrategias de disparo activo y pasivo | `scenes/combat/weapons/behaviors/` | `standard_active_behaviors.gd`, `standard_passive_behaviors.gd` |
| Gestor de crisis extensible (Event Registry) | `scenes/combat/events/crisis_event_manager.gd` | Registro de anomalías espaciales |
| Definición modular de crisis espacial | `scenes/combat/events/definitions/crisis_event_definition.gd` | Contrato data-driven de anomalías |
| Skins / cosméticos / autodescubrimiento | `core/systems/cosmetics_manager.gd` | DB load & discovery: L1 |
| Sistema de save y persistencia | `core/autoloads/save_manager.gd` | Fachada estática → delega en core/systems/persistence/ |
| Schemas DTO de persistencia (Roster, Economía, Settings) | `core/systems/persistence/schemas/` | DTOs fuertemente tipados y validación modular |
| Perfil del jugador (biomasa, trofeos, unlocks) | `core/systems/persistence/meta_progression_state.gd` | — |
| Run activa (armas, ítems, estado de partida) | `core/systems/persistence/active_run_storage.gd` | — |
| Items y loot pool | `core/types/item_pool_manager.gd` | — |
| Satélite orbital (tienda in-run) | `scenes/combat/satellite/satellite_shop.gd` | — |
| Economía y ofertas de tienda satelital | `scenes/combat/satellite/components/satellite_shop_economy_controller.gd` | Rerolls, límites de stacks y roll algorithm |
| Tarjetas de tienda | `scenes/combat/satellite/components/satellite_shop_card_builder.gd` | — |
| Gacha modal | `scenes/ui/gacha/gacha_modal.gd` | — |
| Motor probabilístico y banners de gacha | `scenes/ui/gacha/components/gacha_banner_engine.gd` | Pity garantizado, pools temáticos y rarezas |
| Matriz de stats en pausa | `scenes/ui/pause_menu/components/build_stats_matrix_presenter.gd` | Renderizado y formateo de atributos |
| Sinergias de build en pausa | `scenes/ui/pause_menu/components/build_synergy_calculator.gd` | Arsenal, grimorios y chips de equipo |
| Pedestales 3D y materiales del Hub | `scenes/ui/hub/components/pedestal_visual_presenter.gd` | Mallas 3D, halos, shaders y skins de pilotos |
| Navegación de modales de compañeros | `scenes/ui/character_select/components/companion_modal_navigation_helper.gd` | Inputs, trampas de foco y bounds click |
| Carrusel de skins | `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` | — |
| Transición entre escenas | `core/autoloads/scene_transition.gd` | — |
| Pausa (tokens de pausa) | `core/autoloads/pause_arbitrator.gd` | — |
| HUD de combate (orquestador raíz) | `scenes/ui/hud/hud.gd` | — |
| Ranuras de armas y barridos CD del HUD | `scenes/ui/hud/components/hud_weapon_cooldown_bar.gd` | — |
| Salud, escudo, EXP y OSP del HUD | `scenes/ui/hud/components/hud_health_shield_display.gd` | — |
| Dock lateral de estadísticas de combate | `scenes/ui/hud/components/hud_combat_stats_dock_controller.gd` | Tab toggle y modales |
| Indicador de maldición del HUD | `scenes/ui/hud/components/hud_curse_badge_controller.gd` | Badge y escalado dinámico |
| Radar y timer de oleada del HUD | `scenes/ui/hud/components/hud_satellite_radar_controller.gd` | Formato temporal y proyección satelital |
| Administrador de trackers de borde (Edge Trackers) | `scenes/ui/hud/components/hud_edge_tracker_manager.gd` | Satélite, arcana, jefes y cofres perimetrales |
| Debug de combate (F1 en partida) | `scenes/ui/debug/ingame_debug_modal.gd` | — |
| Debug de metajuego (Character Select) | `scenes/ui/debug/debug_menu_modal.gd` | — |

---

## 🚫 ZONAS PROHIBIDAS — Nunca explorar

```
addons/                  ← Plugin Godot AI (herramienta, no es código del juego)
addons/.godot_ai_update/ ← Staging obsoleto de actualización del addon
.godot/                  ← Cache del motor, generado automáticamente
scratch/                 ← Código temporal, ignorado por git
sandbox/                 ← Shaders y escenas de prueba
preprocess/              ← Fuentes crudas de arte (JPGs sin procesar, 23 MB)
```

Si el agente necesita encontrar algo y no está en la tabla de arriba → leer
`docs/DOMAIN_MAP.md` → luego `ARCHITECTURE.md`. Nunca explorar el árbol de carpetas
directamente.

---

## ⚙️ Los 7 Autoloads (Servicios Globales)

Acceder via nombre de clase directamente. No referenciar por ruta de nodo.

| Autoload | Ruta del script | Responsabilidad |
|---|---|---|
| `PauseArbitrator` | `res://core/autoloads/pause_arbitrator.gd` | Tokens de pausa concurrentes. **NUNCA** asignar `get_tree().paused` directo. |
| `SettingsManager` | `res://core/autoloads/settings_manager.gd` | Gráficos, volumen, controles |
| `SaveManager` | `res://core/autoloads/save_manager.gd` | Fachada de persistencia (delega en `core/systems/persistence/`) |
| `DebugManager` | `res://core/autoloads/debug_manager.gd` | Poda de debug en producción. Usar `DebugManager.is_debug_enabled()` |
| `EventBus` | `res://core/autoloads/event_bus.gd` | Señales globales desacopladas |
| `AudioManager` | `res://core/autoloads/audio_manager.gd` | BGM, SFX, anti-fatiga |
| `SceneTransition` | `res://core/autoloads/scene_transition.gd` | Fundidos entre escenas |

> `BulletServer` no es autoload — es nodo hijo de `MainGame`.

---

## 🏗️ Contratos de Arquitectura Obligatorios

**Modales:** Todo modal extiende `BaseModal` (`res://scenes/ui/components/base_modal.gd`).
Asignar `modal_token = &"nombre"` en `_ready()`. Usar `open_modal()` y `close_modal()`.
**Nunca** gestionar `PauseArbitrator` manualmente desde un modal.

**Daño:** Todo daño viaja en `HitContext`. Todo enemigo implementa `take_damage(ctx: HitContext)`.
`proc_coefficient = 0.0` en proyectiles hijos (Regla Cero Balística).

**Saves:** Nunca escribir directo a `user://`. Siempre usar `SaveManager.*` o los módulos
en `core/systems/persistence/`.

---

## 🧪 Cómo Correr Tests (Iteración Rápida)

```powershell
# 1. EN ITERACIÓN ACTIVA: Suite específica del módulo tocado (2-3 segundos)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_weapons_runner.tscn"

# 2. AL FINALIZAR TAREA: Regresión Core completa (21 suites, ~80 seg)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly

# 3. Solo para CI / validación total (~25 min)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

> **Regla de Oro:** Durante el desarrollo, **NUNCA** correr `-CoreOnly` en bucle repetitivo. Usar `-Test <suite>` correspondiente para tener feedback instantáneo de 2 segundos. Correr `-CoreOnly` solo una vez antes del commit final.


---

## 📊 Estado Actual

| Campo | Valor |
|---|---|
| Versión | Alpha 0.1 |
| Milestone activo | **M7** — Balance Fino de Combate y Feedback |
| M7.1 | Rebalanceo 8 armas base → `data/weapons/roster/*.tres` |
| M7.2 | Oleadas y colosos → `data/timeline/default_encounter_timeline.tres` |
| M7.3 | Drop rates y créditos → `data/items/roster/*.tres` |
| M7.4 | Feedback audiovisual → `scenes/combat/enemies/`, `scenes/ui/hud/` |

---

## 🐛 Bugs Conocidos Pendientes

| Bug | Archivo principal | Estado |
|---|---|---|
| Nyx desbloqueada permanentemente (workaround temporal) | `character_select.gd` L629, `meta_progression_state.gd` | Pendiente restaurar condición de unlock |
| ValentinaO2 / RoxyO2 sin integrar al Hub3D | `hub_world.gd`, `hub_pilot_showcase_controller.gd` | Pendiente sesión de integración |

---

## 📋 Template de Inicio de Sesión

Copiar y completar al iniciar cada conversación:

```
[SESIÓN ASTRA DREAM]
Sistema: [CHARACTER_SELECT | HUD | COMBAT | HUB | PERSISTENCIA | BALANCE | COSMETICS | ART]
Contexto: [qué se hizo la última vez en este sistema]
Archivos probables: [2-4 archivos]
Pedidos (máx. 4):
  1.
  2.
  3.
```
