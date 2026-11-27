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
17. [Dominio Sandbox: Estudio de Pilotos 2.5D (`pilot_rig_lab`)](#17-dominio-sandbox-estudio-de-pilotos-25d-pilot_rig_lab)

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
| `SceneTransition` | `core/autoloads/scene_transition.gd` | Transiciones cinemáticas de Singularidad (3 fases + `load_threaded_request`) vía `SingularityTransitionPresenter`. | Invocación asíncrona mediante `change_scene_to_file()` o `play_wipe()`. |

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
| Rig Visual Enemigos 2.5D | `scenes/combat/enemies/rig/{void_scarab_rig_25d,enemy_visual_controller}.gd` | Rig procedural 7 piezas en producción (`combat_lite_mode`), catálogo `.tres` de variantes y pooling `EnemyBase`. |
| Sesión Título Viva & Materialización | `scenes/combat/controllers/combat_title_session_controller.gd` | `TITLE_ACTIVE ↔ HUB_MATERIALIZING` (`StelaLogoStage`, `TitleMenuOverlay`, materialización del Hub 3D y fly-in de Valentina). |
| Sesión Hub 3D Embebido | `scenes/combat/controllers/combat_hub_session_controller.gd` | Ciclo `TITLE_STANDBY ↔ HUB_ACTIVE → DEPARTING_DISSOLVE → COMBAT_LIVE` dentro de `MainGame`, `HubTutorialDirector`, exclusión de spawners y paridad 2D↔3D. |
| Serializador de Estado | `scenes/combat/systems/run_state_serializer.gd` | Serializa y restaura `run_seed`, inventario, armas y estado de partida activa. |

- **Runners de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"` y `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_main_game_embedded_hub" -TimeoutSeconds 30`

---

## 4. Dominio del Jugador y Locomoción

- **Orquestador:** `scenes/combat/player/player.gd` (`class_name Player`, grupo `"player"`)
- **Arquitectura:** Composición desacoplada de controladores modulares como nodos hijos.

| Componente | Archivo Fuente | Responsabilidad |
|---|---|---|
| Locomoción | `scenes/combat/player/player_locomotion_controller.gd` | Inercia, aceleración, fricción, dash direccional; en Hub: velocidades `440/760 px/s`, freno en pivote y Dash pacífico sin slow-mo. |
| Procesador de Daño | `scenes/combat/player/player_damage_processor.gd` | Escudo, vida, inmunidad post-impacto y One-Shot Protection (OSP). |
| Economía del Jugador | `scenes/combat/player/player_economy_component.gd` | Oro en partida, polvo estelar y conteo de llaves cuánticas. |
| Secuencia de Muerte | `scenes/combat/player/player_death_sequence_controller.gd` | Hitstop, explosión visual, congelamiento de entrada y transición a Game Over. |
| Inventario de Partida | `scenes/combat/player/player_inventory_component.gd` | Stacks de ítems pasivos adquiridos y cómputo de stats derivados. |
| Controlador Rig v2 & Hub Mode | `scenes/combat/player/player_rig_v2_controller.gd` + `hub_landing_ripple_vfx.gd` | Twin-Stick 360° + Anillo Orbital en combate; **Astral Glide-Hop** ↔ Vuelo Zero-G, sombra reactiva y pool zero-alloc de doble ripple + chispas al rebotar en Hub. |

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

## 12. Dominio Fuera de Combate: Hub 3D (*Estación Astral v4* Embebido en `MainGame`), Roster y Gacha

- **Arquitectura Embebida Seamless en Producción:** Al iniciar una incursión (`RunLaunchRequest.EntryMode.HUB`), `MainGame` arranca directamente en **`HUB_ACTIVE`** rolando una semilla `AUTO` fresca por visita sobre el `CosmosCombatEnvironment` vivo. El jugador controla al único `Player` 2D real (`z_index = 5`, `PlayerRigV2Controller`), mientras `AstralStationHub` corre en `embedded_mode = true` proyectando su `SubViewport` 3D ortográfico transparente en `Hub3DDisplaySprite` (`z_index = 3`) mediante `HubEmbeddedViewportBridge`.
- **Travesía, Sombras, Aislamiento y Despegue Zero-Rail:**
  - **Locomoción Hub:** Sobre las 9 islas y 8 puentes (`440 px/s`), la piloto usa **Astral Glide-Hop** (`GaitStyle.ASTRAL_GLIDE_HOP` en `valentina_v2_grounded_locomotion.tres`) con sombra reactiva y doble ripple astral luminoso al rebotar (`HubLandingRippleVFX` en `+76 px` / `hub_astral_ripple_3d.gdshader` en Hub 3D); al salir al perímetro espacial (`760 px/s`), despliega Alas 3D y entra en Vuelo Zero-G; soporta Dash pacífico (`1120 px/s`, Sandevistan sin slow-mo ni peligros).
  - **Iluminación y Zooms Exclusivos:** `DirectionalLight3D` fija en `(-48°, -28°, 0°)` con `SHADOW_ORTHOGONAL` (`pancake_size = 0.0`) y `ndotl`/`ATTENUATION` desacoplados en shaders *ArcSys*; zooms cercanos exclusivos en Cápsula de Piloto (`2.60×`) y Espejo de Skins (`2.50×`) vía `GameCamera2D.zoom_override` compensados al tercio izquierdo.
  - **Aislamiento de Spawners y Salida:** Durante `HUB_ACTIVE`, los spawners de combate permanecen suprimidos; al cruzar `launch_radius` (`30.0 m`), `DEPARTING_DISSOLVE` desmaterializa el Hub sin recarga de escena ni Dialogic manteniendo exclusión radial de `29.5 m` y sesgo en cono frontal (`65°`, `min_dot = 0.15`) durante `6.0 s` (`EnemySpawner`, `CombatSatelliteCoordinator`, `PlanetSpawner`, `ChestDirector`, `SpaceObjectSpawner`, `AsteroidSpawner`, `CombatLootCoordinator`, `CrisisEventManager`).
- **Configuración Data-Driven & Assets de Producción:** [`data/hub/default_astral_station_config.tres`](../data/hub/default_astral_station_config.tres), [`data/hub/default_astral_floating_layout.tres`](../data/hub/default_astral_floating_layout.tres), [`data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres`](../data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres), [`data/hub/default_hub_gacha_3d_config.tres`](../data/hub/default_hub_gacha_3d_config.tres), [`assets/environments/astral_station/`](../assets/environments/astral_station/). *(Modo standalone disponible en `astral_station_hub.tscn`; labs en `sandbox/hub_art_lab/{hub_art_lab.gd,hub_locomotion_lab/}`; escena legacy `scenes/ui/hub/hub_world.tscn` conservada para compatibilidad de suites antiguas).*

| Subsistema | Archivo Fuente | Rol |
|---|---|---|
| Orquestador Sesión Embebida | `scenes/combat/controllers/combat_hub_session_controller.gd` | Ciclo `TITLE_STANDBY ↔ HUB_ACTIVE → DEPARTING_DISSOLVE → COMBAT_LIVE`, `HubTutorialDirector`, exclusión `29.5 m` / cono `65°`, supresión de spawners, foco/zoom y colisiones de cubierta. |
| Título Vivo & Onboarding Hub | `scenes/ui/title_screen/components/{stela_logo_stage,title_menu_overlay}.gd` + `scenes/ui/hub/astral_station/components/hub_tutorial_{director,highlight_controller}.gd` | Logo *Stela Galactica* 4 capas, menú Astral Pop-Ink sobre Cosmos vivo, Boot Preloader `title_screen.gd`, y tutorial Dialogic nativo de Mochi (`? Guía` / `[F1]`). *(Doc: [`docs/STELA_GALACTICA_IDENTITY_AND_ONBOARDING.md`](STELA_GALACTICA_IDENTITY_AND_ONBOARDING.md))* |
| Puente Ortográfico 2D↔3D | `scenes/ui/hub/astral_station/components/hub_embedded_viewport_bridge.gd` | Paridad 1:1 `Camera3D` ortogonal (`near=2.0`, `far=72.0`) ↔ `GameCamera2D` y `Hub3DDisplaySprite` (`z_index=3`). |
| Orquestador Estación Astral | `scenes/ui/hub/astral_station/astral_station_hub.gd` | Ensamblado 3D (`embedded_mode` y standalone), luz `SHADOW_ORTHOGONAL`, `SettingsModal`, modos de foco e interacción. |
| Locomoción & Ondas del Player | `scenes/combat/player/{player_rig_v2_controller,hub_landing_ripple_vfx}.gd` + `scenes/ui/hub/shaders/hub_astral_ripple_3d.gdshader` | **Astral Glide-Hop** ↔ Vuelo Zero-G, Dash pacífico en Hub, sombra de contacto reactiva y doble ripple astral al rebotar (`z_index=4` / 3D). |
| Despegue Radial & Controlador 3D | `scenes/ui/hub/astral_station/components/hub_{radial_departure_controller,art_lab_player}.gd` | Cuantización 8 sectores cardinales, desmaterialización hexagonal y modo standalone heredado. |
| Alas Este / Oeste & Gacha 3D | `scenes/ui/hub/astral_station/components/hub_{east_wing,west_sanctuary,gacha_summoner_3d}.gd` | Invocador Giroscópico Gacha 3D + 5 Balizas prismáticas (Este), 5 Reliquias cristalinas (Oeste) y órbita de mascotas (SW). |
| Constructores Mallas & Shaders | `scenes/ui/hub/astral_station/{meshes,shaders}/` | Mallas *ArcSys* 3 superficies, cubierta 8-fold, puente Hardlight y sombras cel ortogonales sin halftone móvil. |
| Selección de Piloto / Gacha / Skins | `scenes/ui/character_select/character_select.gd`, `scenes/ui/gacha/gacha_modal.gd`, `core/systems/cosmetics_manager.gd` | Modales integrados consumidos desde `hub_antesala_modal_coordinator.gd`. |

- **Runners de Prueba:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_main_game_embedded_hub" -TimeoutSeconds 30`, `test_hub_grounded_walk`, `test_hub_locomotion_lab -TimeoutSeconds 25`, `test_astral_station_hub_production`, `test_hub_art_lab -TimeoutSeconds 30`, `slot_machine_and_gacha` y `test_title_and_hub_navigation`.

---

## 13. Dominio de Persistencia y Guardado

- **Fachada Estática:** `core/autoloads/save_manager.gd`
- **Directorio de Schemas y Lógica:** `core/systems/persistence/`

```
core/systems/persistence/
├── schemas/
│   ├── meta_progression_schema.gd   <- Desbloqueos globales, talentos, roster y balance de cristales
│   ├── active_run_schema.gd         <- Partida en curso (vida, armas, items, run_seed, piso/tiempo)
│   └── profile_settings_data.gd     <- Velocidad, trofeos, career_stats y `hub_tutorial_completed`
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
| Identidad, Singularidad & Tutorial Hub | `data/ui/` + `data/hub/` | `StelaLogoVFXConfig`, `SingularityTransitionConfig`, `TitleToHubSequenceConfig`, `HubTutorialSequenceConfig` (`HubTutorialStepData`). |

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
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_25d_production"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_art_lab"

# Economía, Satélites, Persistencia y Bifurcaciones
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "satellite_items"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "chest_economy"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "slot_machine_and_gacha"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "persistence"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "run_fork"

# Hub 3D Estación Astral v4 (Embebido en MainGame + Astral Glide-Hop) & Integración Valentina v2
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_stela_identity_and_tutorial" -TimeoutSeconds 35
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_title_and_hub_navigation" -TimeoutSeconds 25
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_scene_transition_and_tape_button" -TimeoutSeconds 25
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_main_game_embedded_hub" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_astral_station_hub_production" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_art_lab" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_grounded_walk"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_locomotion_lab" -TimeoutSeconds 25
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "workbenches_and_combat_gym"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_player_valentina_v2_combat"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_shader_skins_system"
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

> **Arquitectura *Single Source of Truth*:** El runtime (`scenes/pilots/`), los esquemas y presets `.tres` (`data/pilots/`) y los assets compilados (`assets/pilots/`) viven en **producción**. Los laboratorios interactivos (`sandbox/pilot_rig_lab/`), los workbenches (`sandbox/workbenches/`) y `CombatGym` (`sandbox/combat_gym/`) consumen producción sin crear dependencias inversas.

### Verificación Integral Final (Solo antes de dar por cerrada una tarea)

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```
*(Ejecuta las 24 suites clave de regresión rápida con timeout estricto de 15s por suite).*

---

## 17. Dominio Pilotos 2.5D (`scenes/pilots/`, `data/pilots/`, `assets/pilots/`) & Labs (`sandbox/pilot_rig_lab/`)

> **Single Source of Truth:** Todo runtime, shaders, esquemas, `.tres` y assets compilados residen en producción (`scenes/pilots/`, `data/pilots/`, `assets/pilots/`). `sandbox/pilot_rig_lab/` conserva los laboratorios interactivos (parametrizados por piloto vía `shared/pilot_lab_selector.gd`), herramientas Python (`tools/`), fuentes crudas (`source_refs/`) y baseline inmutable (`backups/`).
> **Contrato rápido anti-relectura:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md) · **Playbook Cast v2:** [`docs/PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md) · **Índice Maestro:** [`docs/README.md`](README.md).
> **Estado de Milestone:** [`docs/VALENTINA_V2_MILESTONE_STATUS.md`](VALENTINA_V2_MILESTONE_STATUS.md) — **Fases 1–5 cerradas ✅** (Valentina v2 activa en `CharacterSelectUI`, `HubRigAvatar3D`, Skins Shader y `PlayerRigV2Controller` In-Game).
> **Escenas de Laboratorio (accesibles desde `sandbox/workbenches/workbench_hub.tscn`):** `proto/planar_combat_rig_proto.tscn` · `proto/planar_anim_test.tscn` · `face_lab/valentina_face_lab.tscn` · `shader_lab/planar_shader_lab.tscn` · `vfx_lab/valentina_vfx_lab.tscn` · `guns_lab/valentina_guns_lab.tscn` · `3d_lab/valentina_3d_lab.tscn` · `banner_lab/valentina_banner_lab.tscn` · `cosmos_lighting_lab/valentina_cosmos_lab.tscn` · `calibrator/rig_calibrator.tscn`

### 17.1 Módulos Runtime de Producción (`scenes/pilots/` y `data/pilots/`)
| Archivo | Responsabilidad |
|---|---|
| `scenes/pilots/rig/planar_combat_rig.gd` | Orquestador del rig 8-Dir (`UnifiedCharacterGroup` `CanvasGroup`, `HeadContactShadow`, rostro vivo, alas 2D/3D y estilos). |
| `scenes/pilots/rig/planar_rig_mesh_builder.gd` | Construye mallas `Polygon2D` + `Skeleton2D` (18 huesos) desde `parts_5_meta.json`, pesos desde `*_anim_mask.png`, y cabezas en 2 pasadas (`head_layer_pass = 1/2`). |
| `scenes/pilots/rig/planar_rig_view_router.gd` | Enrutado 8-dir nativo (`body_flip_x = false`), cono cervical `±65°`, histéresis y backpedal anti-exorcista. |
| `scenes/pilots/rig/planar_rig_transition_controller.gd` | Transiciones snappy de giro (Modos 4..6), estado 2.5D/cascada (`get_turn_anim_state`) y whip cervical. |
| `scenes/pilots/rig/planar_rig_face_controller.gd` | Rig facial vivo, ojos Live2D, parpadeo, 6 expresiones + comms, cabello 3-zonas y monóculo HUD. |
| `scenes/pilots/vfx/valentina_base_propulsion_controller.gd` | Alas psíquicas 8-dir por cuchillas (`WingsUnderMount`/`WingsOverMount`), glow HDR, apertura lineal y 12 cintas. |
| `scenes/pilots/vfx/astral_wings_3d_{mesh_builder,controller}.gd` | Estándar Multi-Piloto de Alas 3D Cel-Shaded (`Dual-Pass 768×768`, contorno caligráfico, *crease ink* y Post-Pass 2D). |
| `scenes/pilots/vfx/sandevistan_trail_controller.gd` | Estela Sandevistan Ping-Pong con tintado SDF 2× y aberración cromática controlada por `PilotPropulsionVFXConfig`. |
| `scenes/pilots/weapons/orbital_weapon_{ring_controller,3d_renderer}.gd` | Anillo Orbital 2.5D (1–4 slots) con Z-sorting, Rail-Lance 3D Cel-Shaded, paletas por `WeaponData` y bocas `3D -> 2D`. |
| `scenes/pilots/banner/pilot_live_banner_controller.gd` | Live Banner 2.5D para `CharacterSelectUI` y `HeroPickerModal` con parallax, respiración, jiggle y Lock-In. |
| `scenes/pilots/rig/planar_rig_material_controller.gd` | Aplica `RigStyleProfile`, `PilotSkinPreset`, `PilotHairPreset`, Pasada 2, Ink SDF 2×, `CosmicLightingSampler` y `hit_flash`. |
| `scenes/pilots/rig/planar_rig_{base_pose,grounded,kiting}_evaluator.gd` | Evaluadores data-driven de Pose Base Zero-G, Idle 3-capas, Locomoción/Freno, **Astral Glide-Hop** (`GaitStyle.ASTRAL_GLIDE_HOP` / `MOON_HOP` / `WALK_STRIDE` en Hub), Kiting 360°, Giros Snappy y Jiggle. |
| `data/pilots/schemas/*.gd` + `data/pilots/<pilot_id>/` | Esquemas y bundles `.tres` por piloto (`PilotRigProfile`, 6 configs de animación, `face_anim`, `base_propulsion`, `wings_3d`, `propulsion_vfx`, `orbital_weapon`, `live_banner`, `combat_rig`, `skin_catalog`, `skins/*.tres`). |
| `sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd` | Selector compartido multi-piloto que parametriza los 10 labs para cualquier `<pilot_id>_profile.tres`. |

### 17.2 Shaders y Máscaras Activas (`scenes/pilots/shaders/` & `assets/pilots/`)
- **Pasada 1 (por pieza/cabeza):** `scenes/pilots/shaders/pilot_rig_stylizer.gdshader` + `rig_{color_recolor,stylized_lighting,perspective_25d,face_live}.gdshaderinc`.
- **Pasada 2 (silueta unificada):** `scenes/pilots/shaders/pilot_rig_pass2.gdshader` sobre `UnifiedCharacterGroup` y `UnifiedBannerGroup`.
- **VFX, Alas, Armas y Banner:** `wing_red_glow.gdshader`, `astral_wing_{toon_3d,outline_3d,post_2d}.gdshader`, `sandevistan_{ghost,ghost_part,edge_aberration}.gdshader`, `orbital_weapon_25d.gdshader`, `orbital_ring_25d.gdshader`, `rail_lance_toon_3d.gdshader`, `pilot_live_banner.gdshader`, `shader_skin_swatch.gdshader`.
- **Tabla rápida de máscaras en uso** *(detalle en [`docs/PILOT_RIG_ARCHITECTURE.md`](PILOT_RIG_ARCHITECTURE.md#51-inventario-de-máscaras-en-uso-offline-vs-runtime))*:
  - **Runtime GPU (Pasada 1):** `*_id_mask.png` (`RGBA`, canal `B` cuello en cabezas), `*_normal_depth.png`, `*_ilm.png`, `*_ink_sdf.png` (`2×`, sin mipmaps), `body_core_secondary_mask.png`, `*_hair_jiggle_mask.png`, `body_core_pauldron_mask.png`, `*_outline_sdf.png`, `assets/pilots/shared/persp_masks/leg_*_persp_mask.png`.
  - **Runtime CPU (`Skeleton2D`):** `*_anim_mask.png` (`RGB` = pesos proximal/bisagra/distal).
  - **Offline Python (`sandbox/pilot_rig_lab/tools/`):** `scaffold_new_pilot.py`, `rig_v2_lib/`, `build_valentina_v2_rig_assets.py`, `ink_hq_pipeline.py`, `ingest_eye_live2d_assets.py`, `build_valentina_v2_wings.py`, `build_valentina_weapon.py`, `build_orbital_ring_texture.py`, `build_valentina_live_banner.py` (ver catálogo en `tools/README.md`).

### 17.3 Carpetas de Arte Crudo vs Compilado (Producción vs Sandbox)
- **Fuentes crudas sin procesar (protegidas con `.gdignore`):** `sandbox/pilot_rig_lab/source_refs/<pilot_id>/00_raw/`.
- **Asset Packs compilados en producción:** `assets/pilots/<pilot_id>/planar/` (`s..sw/parts_5/`, `heads/`, `wings/`, `hd_torsos/`, `*.json`), `assets/pilots/<pilot_id>/banner/`, `assets/pilots/<pilot_id>/weapons/`.
- **Backup inmutable de baseline:** `sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/` + `restore_valentina_v2_baseline.ps1`.
- **Pipeline Multi-Piloto v2:** Ver [`docs/PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md) (y [`archive/plans/PILOT_V2_8DIR_HANDOFF.md`](archive/plans/PILOT_V2_8DIR_HANDOFF.md) como registro histórico de Valentina v2).

---

## 18. Workbenches sobre Producción & Combat Gym (`sandbox/workbenches/`, `sandbox/combat_gym/`)
- **Lanzador Unificado (`F6`):** `sandbox/workbenches/workbench_hub.tscn` (`[1..9]`, incl. `[7] Hub Locomotion Lab 3D` y `[9] StelaIntroLab` en `sandbox/workbenches/stela_intro_lab/stela_intro_lab.tscn`).
- **Workbenches sobre escenas reales:**
  - `sandbox/workbenches/hud_workbench/hud_workbench.tscn` (`GameHUD` real + guías de equidistancia, presets de resolución, 0–4 armas simuladas).
  - `sandbox/workbenches/dialogue_workbench/dialogue_workbench.tscn` (`CombatNarrativeDirector` + `DialogueBackdropLayer` + inspector `.dch`).
  - `sandbox/workbenches/character_select_workbench/character_select_workbench.tscn` (`CharacterSelectUI` + `HeroPickerModal` + respaldo automático de perfil vía `WorkbenchSaveSandbox`).
- **Arena In-Game:** `sandbox/combat_gym/combat_gym.tscn` (`Player` Valentina v2 + `OverheadHealthBar` + `OrbitalWeaponRingController` + `GameHUD` + `BulletServer` + `CosmosCombatEnvironment` + `CombatGymDummy` + overlay de radios en tiempo real).
- **Suite:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "workbenches_and_combat_gym"`
