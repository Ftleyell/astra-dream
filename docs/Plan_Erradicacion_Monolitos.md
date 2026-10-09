# 🗺️ Plan Maestro Definitivo: Erradicación de God-Objects y Monolitos
**Proyecto:** Astra Dream | **Versión:** Alpha 0.1 | **Fecha:** 2026-10-09  
**Objetivo:** Llevar la base de código a un estado de **cero acoplamiento crítico**, con scripts <400 líneas, contratos de interfaz estrictos y micro-tests unitarios (<10s), dejando el juego en condiciones óptimas para expansión infinita de contenido (personajes, armas, biomas y modos).

---

## 1. Diagnóstico de Partida y Metas Cuantitativas

| Métrica | Estado Actual | Meta Post-Plan | Impacto Operativo |
|---|---|---|---|
| **Scripts >500 líneas** | 18 scripts | **0 scripts** (Máximo 350-400 L en orquestadores) | Ningún archivo abruma la ventana de contexto. |
| **Tiempo de Verificación de Lógica** | 11.3s (5 tests) | **<15s (12 micro-tests unitarios)** | Feedback instantáneo durante el desarrollo. |
| **`MainGame` (Combate)** | 1.127 líneas | **<350 líneas** (Puro bus de eventos y lifecycle) | Separación total de reglas, spawners y satélites. |
| **`CharacterSelect` (Metajuego)** | 894 líneas | **<300 líneas** (Coordinador visual) | UI de selección modular e inmune a regresiones. |
| **`Player` (Entidad Jugable)** | 630 líneas | **<300 líneas** (Fachada de componentes) | Fácil adición de nuevas mecánicas de vuelo o pasivas. |
| **Consumo de Tokens por Tarea** | ~100k (sesiones largas) | **15k - 25k (Micro-sesiones quirúrgicas)** | **Reducción del 75% en costo y tiempo de espera.** |

---

## 2. Las 5 Fases Quirúrgicas de Ejecución

---

### FASE 1: La Purga de Modales Gemelos y Desduplicación de UI
> **Objetivo:** Terminar de estandarizar la arquitectura de modales que ya demostró éxito en armas y transmutación.  
> **Complejidad:** Baja-Media | **Riesgo:** Bajo

#### 1.1 `TomeSelectionModal` (624 L → <250 L)
* **Extraer:** `scenes/ui/character_select/components/tome_card_renderer.gd` (Construcción visual y StyleBoxes de grimorios).
* **Extraer:** `scenes/ui/character_select/components/tome_pool_data_controller.gd` (Filtrado de tags, sinergias pasivas y tomes activos).
* **Micro-test:** `tests/unit/test_tome_pool_rules_unit.gd`.

#### 1.2 Deprecación y Unificación de Modales de Skins
* **Problema:** Coexisten `skin_selection_modal.gd` (607 L, grilla vieja) y `cosmetic_carousel_modal.gd` (588 L, carrusel moderno).
* **Acción:** Redirigir el 100% de las invocaciones de `character_select.gd` y `hub_world.gd` al carrusel moderno. Archivar/eliminar el modal antiguo.
* **Refactor del Carrusel:** Extraer `cosmetic_carousel_3d_renderer.gd` (manejo del SubViewport 3D y rotación) dejando el controlador en <280 L.

#### 1.3 `WeaponSwapModal` (486 L → <200 L)
* Reutilizar `WeaponCardRenderer` ya creado en la fase previa para renderizar las opciones de reemplazo in-run.

---

### FASE 2: Desmembramiento Final del Orquestador de Combate (`MainGame`)
> **Objetivo:** Bajar `main_game.gd` de 1.127 a <350 líneas transformándolo en un ensamblador puro de escena.  
> **Complejidad:** Alta | **Riesgo:** Medio (Cubierto por `CoreOnly 21/21 PASS`)

#### 2.1 Desacoplar `CombatSatelliteCoordinator` en Micro-Servicios Extensibles (Mod-Friendly)
> **Problema actual:** `combat_satellite_coordinator.gd` (272 L) mezcla el odómetro de vuelo del jugador, la proyección geométrica de spawn, la selección fija por alternancia matemática (`satellites_collected_total % 2 == 1`), y duck-typing (`"uses_remaining" in current_satellite`). Agregar un nuevo tipo de satélite (ej. satélite de reparación, estación de blackjack) obligaría a modificar este archivo.
* **Extraer `scenes/combat/satellite/components/satellite_odometer.gd` (~60 L):** Odómetro espacial puro e independiente. Rastrea la distancia de vuelo real del jugador y emite `target_distance_reached`. Reutilizable para cualquier evento espacial por odometría.
* **Extraer `scenes/combat/satellite/components/satellite_spawn_selector.gd` (~70 L):** Selector de estaciones extensible guiado por datos/recursos (`StationEntry` o pool ponderado). Permite registrar nuevas estaciones espaciales vía mods o tablas sin tocar el código central.
* **Definir Contrato `InteractableSpaceStation` / `BaseSpaceStation`:** Unificar satélites y forjas con métodos polimórficos (`is_active()`, `can_be_despawned()`, `interact()`) eliminando duck-typing frágil (`"current_charge" in sat`).
* **Coordinador Ligero (<120 L):** Solo escucha eventos del odómetro, solicita la escena al selector y la instancia en el árbol de combate.

#### 2.2 Extraer `CombatGameOverDirector`
* Aislar la secuencia de muerte del jugador, cámara lenta, detención de timers, volcado de estadísticas a `active_run_storage` y apertura del modal de derrota.

#### 2.3 Extraer `CombatSpaceDebrisManager`
* Aislar el spawn de asteroides destructibles, macro-estructuras planetarias y loot drops del fondo.

---

### FASE 2.B: Erradicación de Fábricas Cerradas y Monolitos de Contenido (Arquitectura 100% Mod-Friendly)
> **Objetivo:** Transformar despachadores hardcodeados en registros abiertos orientados a datos (Data-Driven / Strategy Pattern), garantizando que agregar contenido por mods o expansiones no requiera modificar scripts centrales ("Open/Closed Principle").
> **Complejidad:** Media | **Riesgo:** Bajo-Medio

#### 2.B.1 `WeaponProjectileFactory` (344 L → Despacho por Estrategia)
* **Problema:** Enorme bifurcación `match wdata.active_behavior_type` con 11 `preload` de escenas y ramas hardcodeadas (`laser`, `projectile`, `shotgun`, `singularity`, `chain`, `cluster`, `solar`, `boomerang`, etc.). Un mod de arma no puede registrar un tipo balístico nuevo sin editar este archivo.
* **Solución:** Cada tipo balístico se convierte en un recurso/estrategia `ProjectileBehavior` (`behaviors/laser_behavior.gd`, `behaviors/shotgun_behavior.gd`, etc.). La fábrica pasa a ser un registro dinámico extensible.

#### 2.B.2 `CrisisEventManager` (277 L → Event Registry / Mod-Friendly Crisis System)
* **Problema:** Eventos espaciales hardcodeados en un array estático `["solar_storm", "flock_rush", "mitosis_invasion", "containment_arena"]` con `match crisis_id:` cableado a shaders y escenas fijas. Imposible crear una nueva crisis ambiental espacial (ej. "Lluvia de Meteoritos", "Distorsión Temporal") sin editar este archivo.
* **Solución:** Abstraer cada evento en un recurso de evento `CrisisEventDefinition` (`id`, `title`, `subtitle`, `tint`, `duration`, `crisis_script`). El manager solo ejecuta el ciclo de vida sin conocer qué hace cada crisis internamente.

#### 2.B.3 `CosmeticsManager` (432 L → Autodescubrimiento Dinámico de Categorías y Skins)
* **Problema:** El diccionario de categorías está congelado en código: `CATEGORY_FILES = {"ship": ..., "pilot": ..., "weapon": ..., "pet": ..., "navigator": ...}`. Un mod no puede registrar una nueva categoría estética (ej. "drones", "auras", "estilos_de_hud") sin editar este script core.
* **Solución:** Descubrimiento dinámico de archivos JSON/TRES en `res://data/cosmetics/categories/` mediante escaneo de directorio (`DirAccess`), permitiendo que cualquier mod suelte su carpeta o archivo de categoría y sea detectado automáticamente.

#### 2.B.4 `CombatEncounterController` (127 L → Timeline de Oleadas Desacoplada)
* **Problema:** Decisiones de aparición de rivales, jefes y slots fijadas con arrays numéricos imperativos (`current_wave in [1, 4, 7, 10, 13]`, `current_wave in [2, 5, 8, 11, 14]`, etc.) y lista hardcodeada de rivales `[&"nova", &"valentina", &"kira", ...]`.
* **Solución:** Unificar con `EncounterTimelineConfig` data-driven existente, permitiendo a los diseñadores y modders definir la cadencia de jefes, rivales y eventos en un único recurso `.tres` sin tocar lógica de código.

#### 2.B.5 `HUDBannerManager` (456 L → Bus de Notificaciones Genérico)
* **Problema:** Métodos duplicados y hardcodeados (`show_satellite_banner`, `show_unlock_banner`, `show_tactical_alert`) cada uno recreando nodos a mano, configurando StyleBoxes y tweens específicos.
* **Solución:** `NotificationPayload` genérico (`title`, `subtitle`, `icon`, `theme_color`, `duration`). Una sola cola de banners reutilizable que cualquier mod o nuevo evento puede disparar con una línea.

#### 2.B.6 `EnemySpawner` (343 L → Desacoplamiento de Precargas de Escenas)
* **Problema:** 10 variables `@export` de `preload` de enemigos directos en el script (`drone_scene`, `kamikaze_scene`, `tank_scene`, etc.).
* **Solución:** Consolidar la definición de enemigos en el catálogo de datos de la oleada (`enemy_catalog.tres`), permitiendo inyectar nuevos tipos de enemigos sin inflar el script del spawner.

---

### FASE 3: Desacoplamiento del Jugador (`Player`) a ECS Liviano
> **Objetivo:** Bajar `player.gd` de 630 a <280 líneas.  
> **Complejidad:** Media | **Riesgo:** Bajo

#### 3.1 Extraer `PlayerDamageProcessor`
* Aislar el cálculo de mitigación por armadura, invulnerabilidad táctica (OSP), shockwave defensivo y registro de daño en `scenes/combat/player/player_damage_processor.gd`.

#### 3.2 Extraer `PlayerArcanaInventory`
* Mover la recolección, activación de pasivas arcanas y multiplicadores de atributos fuera del cuerpo físico del jugador.

---

### FASE 4: Modularización del HUD y Telemetría (`GameHUD`)
> **Objetivo:** Bajar `hud.gd` de 674 a <300 líneas.  
> **Complejidad:** Media | **Riesgo:** Bajo

#### 4.1 Extraer `HUDCombatStatsDock`
* Aislar el panel lateral de estadísticas en tiempo real (DPS, crítico, velocidad, radio de imán) a su propio subcontrolador.

#### 4.2 Extraer `HUDCurseBadgeController`
* Mover el badge de maldición y escalado de dificultad a un componente visual autocontenido.

---

### FASE 5: Modernización de Persistencia (`ProfileStorage`)
> **Objetivo:** Pasar de un archivo monolítico de 584 líneas sin tipos a un esquema fuertemente tipado.  
> **Complejidad:** Media | **Riesgo:** Alto (Afecta savegames existentes)

#### 5.1 Creación de DTOs / Schemas Tipados
* Dividir la serialización en sub-estructuras:
  * `ProfileRosterData` (Unlocks de pilotos, loadouts de skins, banlists).
  * `ProfileEconomyData` (Biomasa, antimateria, materia oscura, gacha tokens).
  * `ProfileSettingsData` (Velocidad de juego, career stats, trofeos).
* Sanitización modular con pruebas unitarias de retrocompatibilidad (garantizando que cargue JSONs viejos sin pérdida de datos).

---

### FASE 6: Desacoplamiento de Jefes, Combate de Rivales y Balística Jugable
> **Objetivo:** Eliminar el acoplamiento monolítico en los encuentros 1v1 y los sistemas de combate avanzados.  
> **Complejidad:** Media-Alta | **Riesgo:** Medio

#### 6.1 Modularización de `RivalPilotBoss` (566 L → <250 L)
* **Extraer `scenes/combat/bosses/components/rival_engagement_behavior.gd` (~140 L):** Máquina de estados desacoplada del encuentro (`WARPING_IN`, `PEACEFUL_WARN`, `DOGFIGHT`, `WARPING_OUT`, `DYING`). Gestiona la lógica de perdón pacífico (spared timer) vs desafío violento (challenge timer y radios de proximidad).
* **Extraer `scenes/combat/bosses/components/rival_flight_motor.gd` (~120 L):** Cinemática 2D de dogfight, aceleración orbital, dashes evasivos y tilt angular de la nave rival.
* **Micro-test:** `tests/unit/test_rival_engagement_rules_unit.gd`.

#### 6.2 Desacoplamiento de `WeaponController` (499 L → <250 L)
* **Extraer `scenes/combat/player/combat_targeting_system.gd` (~130 L):** Detección, filtrado de prioridades (más cercano, élite, cono de visión) y auto-aim 2D desacoplado del inventario de armas.
* **Extraer `scenes/combat/player/weapon_cooldown_tracker.gd` (~120 L):** Gestión de tiempos de recarga, cadencias escaladas y señales de disparo sincronizadas.

#### 6.3 Adelgazamiento de `CombatBossCoordinator` (538 L → <300 L)
* **Extraer `scenes/combat/bosses/boss_cinematic_director.gd` (~160 L):** Secuencia de congelamiento temporal, travel cinemático de cámara hacia el coloso y disparadores de telemetría narrativa.

---

### FASE 7: Modularización de Economía Satelital, Hub y Metajuego
> **Objetivo:** Terminar de sanear las vistas secundarias, tiendas y sistemas de menú.  
> **Complejidad:** Media | **Riesgo:** Bajo

#### 7.1 `SatelliteShop` (547 L → <220 L)
* **Extraer `scenes/combat/satellite/components/satellite_shop_economy_controller.gd` (~160 L):** Lógica matemática de rerolls, costes de inflación progresiva, slots comprados e inventario dinámico ofrecido.

#### 7.2 `GachaModal` (525 L → <200 L)
* **Extraer `scenes/ui/gacha/components/gacha_banner_engine.gd` (~150 L):** Motor probabilístico puro (pity counter, seed determinista de rarezas, garantía de banners). Completamente desacoplado del renderizado de domo y animaciones visuales.
* **Micro-test:** `tests/unit/test_gacha_banner_engine_unit.gd`.

#### 7.3 `PauseBuildInspector` (617 L → <250 L)
* **Extraer `scenes/ui/pause_menu/components/build_stats_matrix_presenter.gd` (~180 L):** Generación y layout de celdas visuales de atributos.
* **Extraer `scenes/ui/pause_menu/components/build_synergy_calculator.gd` (~120 L):** Algoritmo de agregación de sinergias activas entre tomes e ítems.

#### 7.4 Unificación de Modales de Acompañantes (`NavigatorSelectionModal` 447 L + `PetSelectionModal` 435 L)
* **Diseñar `scenes/ui/character_select/companion_selection_modal.gd` (~250 L):** Modal genérico configurable mediante recurso (`CompanionType` / `Category`), unificando los dos modales duplicados y permitiendo añadir nuevas categorías estéticas (drones, copilotos) sin duplicar código.

#### 7.5 Desacoplamiento del Showcase del Hub (`HubPilotShowcaseController` 517 L → <250 L)
* **Extraer `scenes/ui/hub/components/pedestal_visual_presenter.gd` (~180 L):** Gestión del SubViewport 3D, rotación suave de pedestales e intercambio de materiales/shaders de naves.

---

## 3. Matriz de Resultados Esperados

### A. Resultados Técnicos (Arquitectura)
* **Cero Monolitos:** Ningún archivo de producción superará las 350-400 líneas.
* **Arquitectura de Componentes Clara:** Cada subsistema tendrá una tríada limpia:
  `[Orquestador Liviano] <---> [DataController / Reglas Puras] <---> [CardRenderer / Vista]`
* **Contratos Fuertes:** Prohibido el uso de `find_child` y cadenas de nodos frágiles; todo atado por señales y `@export`.

### B. Resultados en la Experiencia de Desarrollo (Tokens y Tiempos)
* **Turnaround de 10-15 Minutos:** Cualquier cambio puntual (ej. *"añadir una nueva arma"*, *"crear un nuevo satélite"*, *"ajustar la UI de un modal"*) se localizará en un único script de <200 líneas.
* **Explosión de Tokens Neutralizada:** Al no tener que cargar contextos gigantes de 1.200 líneas ni verificar 20 efectos colaterales, cada turno del asistente consumirá una fracción mínima de tokens.
* **Feedback Inmediato (<15s):** Con la suite de micro-tests ampliada a micro-pruebas atómicas, el agente validará sus propios cambios antes de responder, eliminando el ciclo de "prueba y error a ciegas".

### C. Condición de Expansión Infinita (Ready to Scale)
* **Nuevos Pilotos y Rivales:** Bastará con crear un `.tres` y su skin mask; la UI, el Hub y el sistema de dogfights los cargarán automáticamente sin tocar código de selección ni de IA.
* **Nuevas Armas:** Se añaden en `data/weapons/roster/*.tres` y la Banlist, el Selector de Armas, el WeaponController y el HUD las integrarán de inmediato.
* **Nuevos Modos / Biomas:** El sistema de Parallax modular y el desacoplamiento de `MainGame` permitirán crear nuevos biomas espaciales simplemente instanciando perfiles de sector.

---

## 4. Desglose en Sesiones Atómicas (1 Tarea = 1 Conversación)

Para respetar estrictamente la **Regla 9 (Higiene de Sesiones Atómicas y Economía de Tokens)**, cada sesión tiene un alcance acotado e independiente, con verificación obligatoria por suite aislada:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 1: FASE 1 — Modales de Selección (Tomes + Deprecación Skins + WeaponSwap)       │
│ • TomeCardRenderer + TomePoolDataController (test_tome_pool_rules_unit)                │
│ • Unificación de Carrusel de Skins y purga del modal viejo                             │
│ • WeaponSwapModal con WeaponCardRenderer                                               │
│ Verificación: test_phase1_ui_polish_runner.tscn + test_weapon_swap_and_hud_runner.tscn │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 2: FASE 3 & FASE 4 — Desacoplamiento de Player y HUD                           │
│ • PlayerDamageProcessor (cálculo de mitigación, OSP, shockwaves)                       │
│ • PlayerArcanaInventory (recolección pasivas)                                          │
│ • HUDCombatStatsDock & HUDCurseBadgeController                                         │
│ Verificación: test_proc_coefficients_and_osp_runner.tscn + test_weapons_runner.tscn    │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 3: FASE 2 — Combate Central (MainGame & Satélites)                              │
│ • SatelliteOdometer + SatelliteSpawnSelector + Contrato BaseSpaceStation               │
│ • CombatGameOverDirector & CombatSpaceDebrisManager                                    │
│ Verificación: test_satellite_items_runner.tscn + test_gamespeed_and_satellite_despawn  │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 4: FASE 2.B — Registros Abiertos y Fábricas Mod-Friendly                        │
│ • WeaponProjectileFactory (estrategias ProjectileBehavior)                             │
│ • CrisisEventManager (CrisisEventDefinition extensible)                                │
│ • CosmeticsManager (autodescubrimiento dinámico de categorías)                         │
│ • CombatEncounterController (timeline de oleadas desacoplada)                          │
│ • HUDBannerManager & EnemySpawner (data-driven)                                        │
│ Verificación: test_crisis_events_suite + test_enemy_spawner_data_driven_suite          │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 5: FASE 6 — Rivales, Jefes y Targeting                                          │
│ • RivalEngagementBehavior & RivalFlightMotor en RivalPilotBoss                         │
│ • CombatTargetingSystem2D & WeaponCooldownTracker en WeaponController                  │
│ • BossCinematicDirector en CombatBossCoordinator                                       │
│ Verificación: test_boss_runner.tscn + test_narrative_and_rival_pilots_suite            │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 6: FASE 7 — Tienda Satélite, Gacha, Pausa y Hub                                 │
│ • SatelliteShopEconomyController en SatelliteShop                                      │
│ • GachaBannerEngine (test_gacha_banner_engine_unit)                                    │
│ • BuildStatsMatrixPresenter & BuildSynergyCalculator en PauseBuildInspector            │
│ • PedestalVisualPresenter en HubPilotShowcaseController                                │
│ • Unificación de modales de compañeros (Navigator + Pet)                                │
│ Verificación: test_slot_machine_and_gacha_runner.tscn + test_run_stats_and_shop        │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SESIÓN 7: FASE 5 — Persistencia Tipada (ProfileStorage Schemas DTO)                   │
│ • ProfileRosterData, ProfileEconomyData, ProfileSettingsData                           │
│ • Tests de retrocompatibilidad y migración de JSONs antiguos                           │
│ Verificación: test_persistence_runner.tscn + tools/run_tests.ps1 -CoreOnly             │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

