# Mapa Integral de Dominios y Arquitectura — Astra Dream

> **Propósito:** Documento de referencia y navegación de segundo nivel (tras `AGENT_CONTEXT.md`).
> Proporciona la ubicación exacta de orquestadores, subsistemas, componentes, recursos exportados (`.tres`), grupos y suites de prueba asociadas.
> **Regla de oro:** Consultar este mapa antes de buscar archivos o explorar el árbol de carpetas.

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone:** M7 (Balance Fino)

---

## 🧭 Índice Rápido de Dominios

1. [Límites del Árbol de Directorios y Zonas Protegidas](#1-límites-del-árbol-de-directorios-y-zonas-protegidas)
2. [Los 7 Servicios Globales (Autoloads)](#2-los-7-servicios-globales-autoloads)
3. [Dominio de Combate Raíz](#3-dominio-de-combate-raíz)
4. [Dominio del Jugador y Locomoción](#4-dominio-del-jugador-y-locomoción)
5. [Dominio de Armamento y Proyectiles](#5-dominio-de-armamento-y-proyectiles)
6. [Dominio Danmaku y BulletServer](#6-dominio-danmaku-y-bulletserver)
7. [Dominio de Directores y Jefes](#7-dominio-de-directores-y-jefes)
8. [Dominio de Entorno Espacial y Cosmos Engine](#8-dominio-de-entorno-espacial-y-cosmos-engine)
9. [Dominio de Satélites, Estaciones y Economía de Campo](#9-dominio-de-satélites-estaciones-y-economía-de-campo)
10. [Dominio del HUD de Combate y Radares](#10-dominio-del-hud-de-combate-y-radares)
11. [Dominio de Modales y Flujo de UI de Combate](#11-dominio-de-modales-y-flujo-de-ui-de-combate)
12. [Dominio Fuera de Combate: Hub 3D, Roster y Gacha](#12-dominio-fuera-de-combate-hub-3d-roster-y-gacha)
13. [Dominio de Persistencia y Guardado](#13-dominio-de-persistencia-y-guardado)
14. [Catálogo de Grupos de Entidades](#14-catálogo-de-grupos-de-entidades)
15. [Catálogo de Recursos Data-Driven (`.tres`)](#15-catálogo-de-recursos-data-driven-tres)
16. [Catálogo de Suites de Prueba Automatizadas](#16-catálogo-de-suites-de-prueba-automatizadas)

---

## 1. Límites del Árbol de Directorios y Zonas Protegidas

```
astra_dream/
├── .agents/rules/           <- Reglas canónicas del proyecto (core, cosmos, gdscript, git, arquitectura)
├── assets/                  <- Arte 2D/3D procesado, audio, fuentes y shaders
├── core/                    <- Autoloads de infraestructura, modelos DTO y persistencia
├── docs/                    <- Documentación arquitectónica, planes y guías de desarrollo
├── scenes/
│   ├── combat/              <- Escena de combate, jugador, jefes, entorno y satélites
│   └── ui/                  <- Hub 3D, selección de personaje, HUD, modales y gacha
├── tests/                   <- Suites de prueba automatizadas (runners .tscn y scripts .gd)
│   ├── unit/                <- Tests de lógica y componentes desacoplados
│   └── sandbox/             <- Tests de prototipos y física experimental
├── sandbox/                 <- ZONA AISLADA: Prototipos e I+D (prohibido enlazar a combate)
├── tools/                   <- Harness de pruebas (run_tests.ps1) y scripts auxiliares
└── [PROHIBIDOS]             <- addons/, .godot/, preprocess/ (no explorar ni modificar)
```

---

## 2. Los 7 Servicios Globales (Autoloads)

Todos los servicios globales residen bajo `core/autoloads/` y están registrados en `project.godot`:

| Autoload | Archivo Fuente | Responsabilidad Central | Regla de Interacción |
|---|---|---|---|
| `PauseArbitrator` | `core/autoloads/pause_arbitrator.gd` | Gestión concurrente basada en tokens (`acquire_pause`, `release_pause`). | **Prohibido** alterar `get_tree().paused` directamente en scripts de juego. |
| `SettingsManager` | `core/autoloads/settings_manager.gd` | Configuración de gráficos, audio, controles y calidad (`space_background_quality`). | Escuchar la señal `settings_changed`. |
| `SaveManager` | `core/autoloads/save_manager.gd` | Fachada global de persistencia delegada en schemas tipados bajo `core/systems/persistence/`. | Cero accesos directos con `FileAccess` crudo fuera de la capa de persistencia. |
| `DebugManager` | `core/autoloads/debug_manager.gd` | Herramientas de depuración, overlay de métricas y profiling en desarrollo. | No incluir lógica de gameplay ligada a debug flags. |
| `EventBus` | `core/autoloads/event_bus.gd` | Bus de eventos desacoplado para señales transversales entre escenas y dominios. | Utilizar tipos y argumentos estrictos en cada señal emitida. |
| `AudioManager` | `core/autoloads/audio_manager.gd` | BGM dinámica, crossfades, buses de mezcla y efectos de sonido balísticos. | Disparar mediante `play_sfx()`, `play_music()` con enum o claves tipadas. |
| `SceneTransition` | `core/autoloads/scene_transition.gd` | Transiciones visuales con fundido entre Hangar 3D y Combate 2D. | Invocación asíncrona mediante `fade_to_scene()`. |

---

## 3. Dominio de Combate Raíz

- **Orquestador Principal:** `scenes/combat/main_game.gd` y `scenes/combat/main_game.tscn`
- **Contrato Arquitectónico:** Orquestador liviano que coordina la instanciación de subsistemas sin concentrar lógica de colisiones ni cálculo de proyectiles. Posee la semilla canónica de la partida (`run_seed: int`).

| Componente | Archivo Fuente | Rol |
|---|---|---|
| Ensamblador de Escena | `scenes/combat/combat_scene_assembler.gd` | Configura referencias de cámara, jugador, entorno y HUD en `_ready()`. |
| Contexto de Combate | `scenes/combat/combat_context.gd` | Contenedor de estado compartido (jugador, cámara, puntuación, tiempo de oleada). |
| Pipeline de Oleadas | `scenes/combat/combat_wave_pipeline.gd` | Control del avance temporal de oleadas y eventos programados. |
| Spawner de Enemigos | `scenes/combat/spawners/enemy_spawner.gd` | Spawns procedurales según pesos y composición de `EncounterTimelineConfig`. |
| Serializador de Estado | `scenes/combat/systems/run_state_serializer.gd` | Serializa y restaura `run_seed`, inventario, armas y estado de partida activa. |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"`

---

## 4. Dominio del Jugador y Locomoción

- **Orquestador:** `scenes/combat/player/player.gd` (`class_name Player`, grupo `"player"`)
- **Arquitectura:** Composición desacoplada de controladores modulares como nodos hijos.

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Locomoción | `scenes/combat/player/components/player_locomotion_controller.gd` | Inercia, aceleración, fricción y dash direccional. |
| Procesador de Daño | `scenes/combat/player/components/player_damage_processor.gd` | Escudo, vida, inmunidad post-impacto y One-Shot Protection (OSP). |
| Economía del Jugador | `scenes/combat/player/components/player_economy_component.gd` | Oro en partida, polvo estelar y conteo de llaves cuánticas. |
| Secuencia de Muerte | `scenes/combat/player/components/player_death_sequence_controller.gd` | Hitstop, explosión visual, congelamiento de entrada y transición a Game Over. |
| Inventario de Partida | `scenes/combat/player/components/player_inventory_component.gd` | Stacks de ítems pasivos adquiridos y cómputo de stats derivados. |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "proc_coefficients_and_osp"`

---

## 5. Dominio de Armamento y Proyectiles

- **Orquestador:** `scenes/combat/player/weapon_controller.gd` (`class_name WeaponController`)
- **Datos Data-Driven:** `res://resources/weapons/<weapon_name>.tres` (`WeaponData`)

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Sistema de Puntería | `scenes/combat/player/systems/combat_targeting_system.gd` | Selección del objetivo óptimo (más cercano, más débil, boss prioritario). |
| Cooldowns de Armas | `scenes/combat/player/systems/weapon_cooldown_tracker.gd` | Gestión de cadencia de tiro por slot de arma activa. |
| Fábrica de Proyectiles | `scenes/combat/player/systems/weapon_projectile_factory.gd` | Despacho hacia proyectiles convencionales o inyección en `BulletServer`. |
| Comportamientos de Armas | `scenes/combat/player/weapons/behaviors/` | Lógica específica de disparo por tipo (láser continuo, ráfagas, misiles teledirigidos). |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "weapons"`

---

## 6. Dominio Danmaku y BulletServer

- **Ubicación:** `core/autoloads/bullet_server.gd` (`class_name BulletServer`, registrado en grupo `"bullet_server"`)
- **Filosofía:** Zero-allocation en combate. Prohibido instanciar `Area2D` individuales para patrones danmaku masivos.
- **Implementación Interna:** Búferes contiguos `PackedFloat32Array` y visualización mediante `MultiMeshInstance2D`.
- **Interacción con Entorno:** Requiere coordenadas en espacio absoluto de combate. `FloatingOriginTracker` está desactivado asertivamente para no fragmentar ni desincronizar la memoria física contigua.

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "phase5_boss_and_bullets"`

---

## 7. Dominio de Directores y Jefes

- **Directorio:** `scenes/combat/directors/` y `scenes/combat/bosses/`

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Coordinador de Jefes | `scenes/combat/directors/combat_boss_coordinator.gd` | Gestión de entrada, banners de alerta, música de boss y milestones. |
| Spawner de Encuentros | `scenes/combat/directors/boss_encounter_spawner.gd` | Instanciación de jefes según el cronograma `EncounterTimelineConfig`. |
| Director Narrativo | `scenes/combat/directors/combat_narrative_director.gd` | Diálogos de radio, transmisiones e interrupciones narrativas. |
| Director de Bifurcaciones | `scenes/combat/directors/combat_fork_director.gd` | Gestión de decisiones in-run (forks), detección por umbral de distancia y orquestación cinemática. |
| Manager de Modificadores | `scenes/combat/systems/run_modifier_manager.gd` | Aplicación y almacenamiento de modificadores activos de la run. |
| Jefe Rival | `scenes/combat/bosses/rival_pilot_boss.gd` | Comportamientos tácticos de la nave rival (`rival_engagement_behavior.gd`). |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "boss"` y `test_run_fork`

---

## 8. Dominio de Entorno Espacial y Cosmos Engine

- **Host en Combate:** `scenes/combat/environment/space_environment_host.gd`
- **Ambiente de Producción:** `scenes/combat/environment/cosmos_combat_environment.gd`
- **Motor Cósmico:** `scenes/combat/environment/cosmos/`
- **Grupo de Detección:** `&"cosmos_root"`
- **Fachada Pública:** `CosmosHostController` (`scenes/combat/environment/cosmos/core/cosmos_host_controller.gd`)

```
[SpaceEnvironmentHost]
   └── active_environment: CosmosCombatEnvironment
         ├── CosmosRootNode (grupo &"cosmos_root")
         │     ├── ParallaxNebulaDeep (CanvasLayer -100, FBM)
         │     ├── ParallaxMacroGalaxies (Parallax2D scroll 0.1)
         │     ├── CanvasLayerStarfield (CanvasLayer -105, desconectable por GPU)
         │     ├── ParallaxSolarSystems (Parallax2D scroll 1.0, Pool de 8 sistemas)
         │     └── ParallaxDebrisBelt (MultiMesh de escombros)
         └── CosmosHostController (Fachada pública)
               └── CosmosOrbitalSlotTracker (Genera slots CosmosOrbitSlot puramente analíticos)
```

| Componente | Archivo Fuente | Rol Arquitectónico |
|---|---|---|
| Contrato Base | `scenes/combat/environment/base_space_environment.gd` | Métodos virtuales `get_cosmos_controller()`, `set_environment_seed()`. |
| Seguidor Orbital | `scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd` | Sincroniza entidades de juego con slots analíticos $\mathcal{O}(1)$. Anti-snapping suave ($0.4\,\text{s}$). |
| Slot Orbital | `scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd` | *Value Object* analítico sin punteros a nodos del árbol. |
| Spawner Planetario | `scenes/combat/environment/planet_spawner.gd` | Instanciador reactivo a señales `solar_system_streamed` / `solar_system_unstreamed`. |
| Sombra Planetaria | `scenes/combat/environment/gameplay_planet_shadow_caster_2d.gd` | Proyección de sombra desacoplada orientada hacia el sol de fondo. |

- **Recursos Data-Driven:** Ver tabla completa en `.agents/rules/cosmos_engine.md`.
- **Runners de Prueba:**
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "space_environment"` (~4.3s)
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "orbital_binding_events"` (~6.3s)
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmos_host_controller"` (~4.1s)

---

## 9. Dominio de Satélites, Estaciones y Economía de Campo

- **Coordinador:** `scenes/combat/systems/combat_satellite_coordinator.gd`
- **Entidades de Campo:** `scenes/combat/satellite/`

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Odómetro de Satélites | `scenes/combat/satellite/satellite_odometer.gd` | Conteo de distancia recorrida para activar balizas por distancia. |
| Selector de Spawns | `scenes/combat/satellite/satellite_spawn_selector.gd` | Selección ponderada del tipo de estación o satélite a desplegar. |
| Tienda de Satélite | `scenes/combat/satellite/satellite_shop.gd` | Baliza comercial con catálogo de ítems y arcanas. |
| Máquina Tragamonedas | `scenes/combat/satellite/slot_machine_beacon.gd` | Baliza de azar con tiradas, marquee animado y premios en oro/ítems. |
| Estación de Transmutación | `scenes/combat/satellite/transmutation_station.gd` | Forja cuántica anclada al sol central (`r=0, \omega=0`) para transmutar equipo. |
| Consumibles de Campo | `scenes/combat/pickups/field_consumable.gd` | Llaves cuánticas, cápsulas de curación y núcleos de energía. |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_items"` y `test_chest_economy`

---

## 10. Dominio del HUD de Combate y Radares

- **Orquestador Principal:** `scenes/ui/hud/hud.gd` y `scenes/ui/hud/hud.tscn` (`class_name GameHUD`)
- **Controladores Hijos:** `scenes/ui/hud/components/`

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Dock de Estadísticas | `scenes/ui/hud/components/hud_combat_stats_dock_controller.gd` | Visualización de stats en vivo (DPS, velocidad, crítico, armor). |
| Radar Satelital Clásico | `scenes/ui/hud/components/hud_satellite_radar_controller.gd` | Indicadores perimétricos para satélites fuera de pantalla. |
| Manager de Bordes | `scenes/ui/hud/components/hud_edge_tracker_manager.gd` | Flechas de borde para jefes (`BossEdgeIndicator`) y cofres (`ChestEdgeIndicator`). |
| Radar Esférico (Dragon Radar) | `scenes/ui/hud/components/hud_dragon_radar_display.gd` | Miniradar circular con shader CRT (`dragon_radar_screen.gdshader`) y blips direccionales (`dragon_radar_blip.gd`). |
| Teclas de Economía | `scenes/ui/hud/components/hud_economy_keybinds_controller.gd` | Atajos y recordatorios para compra rápida y consumibles. |

- **Runners de Prueba:**
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "dragon_radar"` (~2.0s)
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_edge_indicator"` (~2.5s)
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "phase1_ui_polish"` (~6.3s)

---

## 11. Dominio de Modales y Flujo de UI de Combate

- **Coordinador:** `scenes/combat/ui/combat_modal_coordinator.gd`
- **Política de Concurrencia:** Cola FIFO estricta. Ningún modal de subida de nivel, arcana o tienda puede superponerse en pantalla al mismo tiempo. Utiliza `PauseArbitrator` con tokens únicos.

| Modal | Archivo Fuente | Disparador |
|---|---|---|
| Modal de Level-Up | `scenes/ui/level_up/level_up_modal.gd` | Señal `level_up_occurred` de `Player`. |
| Modal de Tienda | `scenes/ui/shop/shop_modal.gd` | Interacción en radio de baliza comercial. |
| Modal de Arcanas | `scenes/ui/arcana/arcana_modal.gd` | Recogida de orbe arcano o cofre especial. |
| Modal de Banlist | `scenes/ui/character_select/arsenal_banlist_modal.gd` | Bloqueo/desbloqueo de armas previo al combate. |

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "level_up_queue"` y `test_arsenal_banlist_modal`

---

## 12. Dominio Fuera de Combate: Hub 3D, Roster y Gacha

- **Hub Principal (Hangar 3D):** `scenes/ui/hub/hub_world.gd` y `scenes/ui/hub/hub_world.tscn`

| Subsistema | Archivo Fuente | Rol |
|---|---|---|
| Cámara 3D del Hub | `scenes/ui/hub/components/hub_camera_controller_3d.gd` | Órbitas y transiciones cinematográficas entre pedestales y pantallas. |
| Pedestales Visuales | `scenes/ui/hub/components/pedestal_visual_presenter.gd` | Renderizado 3D de naves, trajes de piloto y efectos holográficos. |
| Selección de Piloto | `scenes/ui/character_select/character_select.gd` | Roster de personajes, stats de heroínas y selección de skins. |
| Motor de Gacha | `scenes/ui/gacha/gacha_modal.gd` | Banners de reclutamiento, pity counters y animación de invocación (`gacha_banner_engine.gd`). |
| Carrusel de Skins | `core/systems/cosmetics_manager.gd` | Gestión de cosméticos desbloqueados y trajes equipados. |

- **Runners de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "slot_machine_and_gacha"` y `test_title_and_hub_navigation`

---

## 13. Dominio de Persistencia y Guardado

- **Fachada Estática:** `core/autoloads/save_manager.gd`
- **Directorio de Schemas y Lógica:** `core/systems/persistence/`

```
core/systems/persistence/
├── schemas/
│   ├── meta_progression_schema.gd   <- Desbloqueos globales, talentos, roster y balance de cristales
│   ├── active_run_schema.gd         <- Partida en curso (vida, armas, items, run_seed, piso/tiempo)
│   └── settings_schema.gd           <- Preferencias de audio, gráficos y calidad de fondo
├── meta_progression_state.gd        <- Estado en memoria de la metaprogresión
└── active_run_storage.gd            <- Guardado y restauración atómica en user://
```

- **Runner de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"` (~7.6s)

---

## 14. Catálogo de Grupos de Entidades

Godot utiliza grupos de cadenas fuertemente tipadas (`StringName`) para queries rápidas sin recursión:

| Nombre de Grupo (`StringName`) | Asignado en | Finalidad Principal |
|---|---|---|
| `&"cosmos_root"` | `CosmosRootNode._ready()` | Localización directa del motor cósmico por seguidores orbitales y sombras. |
| `&"bullet_server"` | `BulletServer._ready()` | Detección del subsistema danmaku para desactivar floating origin en combate. |
| `&"main_game"` | `MainGame._ready()` | Verificación de ejecución en modo combate real. |
| `&"player"` | `Player._ready()` | Target prioritario de proyectiles, enemigos y pickup magnets. |
| `&"enemies"` | `EnemyBase._ready()`, bosses | Receptores de daño obligatorio implementando `take_damage(ctx: HitContext)`. |
| `&"emitters"` | Emisores de peligro | Objetos destructibles o generadores secundarios atacables. |

---

## 15. Catálogo de Recursos Data-Driven (`.tres`)

Todo balance numérico reside en estos directorios. **Prohibido hardcodear números en scripts `.gd`**:

| Recurso / Dominio | Directorio Base | Clase GDScript Asociada |
|---|---|---|
| Armas | `resources/weapons/` | `WeaponData` (`WeaponLevelStats`) |
| Personajes / Pilotos | `resources/characters/` | `CharacterData` |
| Ítems Pasivos | `resources/items/` | `ItemData` (`ItemEffect`) |
| Cronograma de Oleadas | `resources/waves/` | `EncounterTimelineConfig` (`WaveData`) |
| Mascotas / Drones | `resources/pets/` | `PetData` |
| Navegantes / Asistentes | `resources/navigators/` | `NavigatorData` |
| Banners de Gacha | `resources/gacha/` | `GachaBannerData` |
| Configuración de Cosmos | `scenes/combat/environment/cosmos/resources/data/` | `CosmosEnvironmentConfig`, `CelestialSystemConfig`, `CosmicBiomeData`, etc. |

---

## 16. Catálogo de Suites de Prueba Automatizadas

### Ejecución Directa Recomendada (Latencia: 2 a 7 segundos)

El arnés `tools/run_tests.ps1` admite búsqueda recursiva inteligente. Se puede invocar con subcadenas:

```powershell
# Entorno Espacial y Cosmos Engine
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "space_environment"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "orbital_binding_events"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmos_host_controller"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmos_packaging_smoke"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "gameplay_orbital_binding"

# HUD, Radares y UI
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "dragon_radar"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_edge_indicator"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "phase1_ui_polish"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "weapon_swap_and_hud"

# Armas, Combate y Jefes
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "weapons"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "boss"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "rival_engagement_rules"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "proc_coefficients_and_osp"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "phase5_boss_and_bullets"

# Economía, Satélites, Persistencia y Bifurcaciones
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_items"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "chest_economy"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "slot_machine_and_gacha"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "run_fork"
```

### Verificación Integral Final (Solo antes de dar por cerrada una tarea)

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```
*(Ejecuta las 24 suites clave de regresión rápida con timeout estricto de 15s por suite).*
