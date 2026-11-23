# Diagnóstico y Plan Maestro en Sesiones Atómicas: Sistemas Solares, Órbitas, Satélites y Planetas

**Fecha:** 12 de Octubre de 2026  
**Estado:** Diagnóstico Forense Completado — Listo para Ejecución en 2 Sesiones Atómicas

---

## 🔍 1. Resumen Forense de Causas Raíz (Verificadas en Código)

### Causa Raíz A: Paradoja Matemática de `Parallax2D` (`scroll_scale = 0.25`) vs `GameplayWorld` (`1.0`) + Doble Transformación
1. En `scenes/combat/environment/cosmos/scenes/cosmos_root.tscn` y `default_cosmos_environment.tres`, `ParallaxSolarSystems` operaba con `scroll_scale = Vector2(0.25, 0.25)`.
2. En `scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd`, `project_slot_to_world()` calcula:
   `world_pos = (cam_pos * (Vector2.ONE - s_scale)) + layer_pos` (`cam_pos * 0.75 + layer_pos`).
   **Consecuencia:** Por cada `100 px` que el jugador vuela hacia un satélite o planeta, el objeto se desplaza `75 px` alejándose en la misma dirección (huye al **75% de la velocidad de la nave**).
3. En `scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd` (líneas 46–55), `calculate_layer_position()` sumaba `body_reference.global_position + rel_pos` (que ya incluía el desplazamiento global de la capa), duplicando el arrastre de cámara al **150% de la velocidad del jugador**.
4. Al cruzar el umbral de `1200 px`, `freeze_parallax_drag` alternaba entre `true` y `false` sin compensar el tiempo transcurrido, haciendo que el satélite **se teletransportara instantáneamente** a otro punto de la órbita.

### Causa Raíz B: Autodestrucción del Satélite por Odómetro Activo + Bloqueo Post-Plante
1. En `scenes/combat/systems/combat_satellite_coordinator.gd`, si el satélite activo estaba a `> 1200 px`, `_is_player_interacting_with_satellite()` devolvía `false`.
2. Al volar `1200 px` hacia él, `SatelliteOdometer` alcanzaba su meta (`1200 px`), disparaba `required_distance_reached` -> `spawn_next_satellite()` y ejecutaba `current_satellite.queue_free()`, destruyendo el satélite antes de que el jugador pudiera alcanzarlo.
3. Inversamente, una vez plantado el satélite (`is_planted = true`), `satellite_beacon.gd` devolvía `is_station_ready() == true` permanentemente, dejando el odómetro congelado para siempre tras el primer satélite.
4. Además, `hud.set_active_satellite(target_pos, idx)` solo se llamaba una vez al spawnear, dejando la flecha del HUD apuntando a una coordenada estática obsoleta mientras el satélite orbitaba.

### Causa Raíz C: Planetas Destruibles Huérfanos en el Vacío
1. **Radio Orbital Descomunal:** En `cosmos_orbital_slot_tracker.gd`, `slot_radius = maxf(bounding_r * 1.15, 3200.0)` situaba al planeta a más de 3 pantallas (`1920x1080`) de distancia de su estrella anfitriona.
2. **Celda Inicial Lejana:** El centro de la celda `(0, 0)` del `CosmosMacroGrid` caía en `(3750, 3750)`, a más de `4200 px` del spawn inicial del jugador `(960, 750)`.
3. **Bloqueo Mutuo Planeta-Satélite:** En `planet_spawner.gd` (líneas 221–227), `_is_position_valid_for_planet()` exigía `2500 px` de distancia a cualquier satélite (`station_min_distance_to_planet`), impidiendo que un planeta destruible y un satélite coexistieran en el mismo sistema solar.

### Causa Raíz D: Error de Compilación Headless en `test_orbital_binding_events.tscn`
* `planet_spawner.gd` (línea 56) y `combat_satellite_coordinator.gd` (línea 104) usaban el tipo `CosmosOrbitalSlotTracker` en lugar de la constante precargada `CosmosOrbitalSlotTrackerScript`.

---

## 🚀 2. Plan de Ejecución en 2 Sesiones Atómicas

---

### 📦 SESIÓN ATÓMICA 1: Coherencia Espacial 1:1, Slots Orbitales, Sector Inicial y Fix de Compilación

> **Alcance:** Resolver el desfase espacial entre `ParallaxSolarSystems` y `GameplayWorld`, corregir la matemática de `CosmosOrbitSlot` y `OrbitalWorldFollower2D`, reducir radios orbitales de planetas a escala visible (`1450 px`), posicionar el sistema solar inicial `(0,0)` junto al jugador desde el Frame 0 y dejar 100% en verde las suites unitarias de Cosmos.

#### Paso 1.1 — Escala 1:1 en Sistemas Solares (`scroll_scale = Vector2(1.0, 1.0)`)
* **Archivos:**
  * `scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres` (línea 14): cambiar `solar_scroll_scale = Vector2(0.25, 0.25)` a `solar_scroll_scale = Vector2(1.0, 1.0)`.
  * `scenes/combat/environment/cosmos/scenes/cosmos_root.tscn` (línea 125): cambiar `scroll_scale` de `ParallaxSolarSystems` a `Vector2(1.0, 1.0)`.
* **Efecto:** Las nebulosas (`0.01`), starfield 8K (`0.0015`), galaxias (`0.10`) y debris (`0.25`) conservan su paralaje profundo, mientras que los soles y sistemas planetarios operan en coordenadas euclidianas 1:1 idénticas a `GameplayWorld` (`Vector2.ONE - s_scale = Vector2.ZERO`, cero arrastre de cámara y cero separación visual).

#### Paso 1.2 — Coordenadas de Capa Puras en `CosmosOrbitSlot`
* **Archivo:** `scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd` (líneas 45–58).
* **Cambio:** En `calculate_layer_position(global_time: float) -> Vector2`, cuando `is_instance_valid(body_reference)`, obtener la posición local en la capa sumando `(body_reference.get_parent() as Node2D).position + body_reference.position + rel_pos` (si el padre es `Node2D`, o `body_reference.position + rel_pos`), evitando usar `body_reference.global_position`.

#### Paso 1.3 — Pausa Orbital Continua sin Saltos en `OrbitalWorldFollower2D`
* **Archivo:** `scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd`.
* **Cambio:**
  * Añadir `var _paused_time_offset: float = 0.0`.
  * En `_update_position(delta: float)`: cuando `freeze_parallax_drag` es `true`, acumular `_paused_time_offset += delta` y retornar sin mover el nodo. Cuando es `false`, evaluar `project_slot_to_world(slot, t_global - _paused_time_offset, _camera_ref)`, garantizando continuidad angular perfecta y cero teletransporte al entrar o salir del perímetro del satélite.

#### Paso 1.4 — Radios Orbitales Visibles (`1450 px`) y Ordenamiento por Cercanía en `CosmosOrbitalSlotTracker`
* **Archivo:** `scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd`.
* **Cambios:**
  * En `create_star_orbit_slot()` (línea 187) y en el fallback analítico de `get_star_orbit_slots()` (línea 57): fijar `slot_radius = 1450.0` (en lugar de `3200.0` / `3800.0`), situando al planeta destruible a menos de 1 pantalla de su estrella anfitriona.
  * En `get_star_orbit_slots()` y `get_planet_orbit_slots()`: ordenar el array `results` por distancia a ` target_layer_pos` antes de retornarlo para que siempre se seleccione el cuerpo celeste más cercano al jugador.

#### Paso 1.5 — Anclaje del Sistema Solar Inicial en Celda `(0, 0)` y Streaming en Frame 0
* **Archivos:**
  * `scenes/combat/environment/cosmos/core/solar_system_streamer.gd` (`get_system_position_for_cell`): para `cell_coords == Vector2i.ZERO`, retornar `Vector2(2100.0, 540.0)` para que la estrella inicial aparezca inmediatamente en el borde derecho del sector de despliegue de la nave `(960, 750)`.
  * `scenes/combat/environment/cosmos/scenes/cosmos_root.gd` (`_bind_camera_to_streamers`): tras asignar `solar_streamer.camera = camera`, invocar `solar_streamer._update_streaming_and_orbits(_global_time)` para poblar `active_systems` desde el Frame 0.

#### Paso 1.6 — Corrección de Tipado Headless en Consumidores de `CosmosOrbitalSlotTrackerScript`
* **Archivos:**
  * `scenes/combat/environment/planet_spawner.gd` (línea 56): cambiar `var tracker: CosmosOrbitalSlotTracker` a `var tracker: CosmosOrbitalSlotTrackerScript`.
  * `scenes/combat/systems/combat_satellite_coordinator.gd` (línea 104): cambiar `var tracker: CosmosOrbitalSlotTracker` a `var tracker: CosmosOrbitalSlotTrackerScript`.

#### Verificación de la Sesión 1:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_orbital_binding_events.tscn"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_gameplay_orbital_binding.tscn"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_space_environment_integration.tscn"
```

---

### 📦 SESIÓN ATÓMICA 2: Blindaje del Ciclo de Vida del Satélite, HUD en Tiempo Real y Coexistencia en `PlanetSpawner`

> **Alcance:** Impedir que el odómetro destruya satélites activos en camino, liberar el odómetro tras plantar/agotar el satélite y alejarse, actualizar cuadro a cuadro la posición orbital del satélite en el HUD y permitir que planetas destruibles y satélites compartan el mismo sistema solar.

#### Paso 2.1 — Blindaje del Ciclo de Vida del Satélite y Odómetro
* **Archivo:** `scenes/combat/systems/combat_satellite_coordinator.gd`.
* **Cambios:**
  1. Añadir constante `const ABANDON_RELOCATE_DISTANCE: float = 12000.0`.
  2. Añadir helper `_is_current_satellite_completed() -> bool`:
     * Si `not is_instance_valid(current_satellite)`: retorna `true`.
     * Si `current_satellite is SatelliteBeacon`: retorna `(current_satellite as SatelliteBeacon).is_planted`.
     * Si `current_satellite is TransmutationStation`: retorna `(current_satellite as TransmutationStation).is_depleted or (current_satellite as TransmutationStation).uses_remaining <= 0`.
  3. En `_is_player_interacting_with_satellite() -> bool`:
     * Para un satélite ya completado (`_is_current_satellite_completed() == true`), retornar `true` **únicamente** si `is_in_perimeter` o `dist_to_sat < 450.0` (evitando que `is_station_ready()` bloquee el odómetro para siempre cuando el jugador ya se alejó).
  4. En `update_satellite_lifecycle()`:
     * Pausar la órbita del satélite (`follower.freeze_parallax_drag`) solo cuando el jugador esté en su cercanía inmediata (`dist_to_sat < 450.0 or is_in_perimeter or is_charging or is_busy`).
     * Congelar el odómetro (`should_freeze_odometer = true`) siempre que:
       * Exista un `current_satellite` válido **no completado** a menos de `ABANDON_RELOCATE_DISTANCE` (`12000.0 px`), O
       * `_is_player_interacting_with_satellite()` sea `true`.
     * Si un satélite no completado queda a `> 12000.0 px`, descongelar el odómetro para permitir su reubicación en el nuevo sector del jugador.
  5. En `spawn_next_satellite()`:
     * Si `is_instance_valid(current_satellite)` y `not _is_current_satellite_completed()` y `main_game.player.global_position.distance_to(current_satellite.global_position) < ABANDON_RELOCATE_DISTANCE`, retornar sin destruir el satélite activo.

#### Paso 2.2 — Tracking Orbital en Tiempo Real en el HUD
* **Archivos:**
  * `scenes/ui/hud/components/hud_edge_tracker_manager.gd`: añadir `update_satellite_position(target_pos: Vector2) -> void` que actualice `satellite_tracker.target_pos = target_pos`.
  * `scenes/ui/hud/hud.gd`: añadir `update_active_satellite_position(pos: Vector2) -> void` que actualice `_radar_ctrl.active_satellite_pos = pos` y `_edge_tracker_mgr.update_satellite_position(pos)` sin re-disparar el banner.
  * `scenes/combat/systems/combat_satellite_coordinator.gd`: invocar `main_game.hud.update_active_satellite_position(current_satellite.global_position)` dentro de `update_satellite_lifecycle()` mientras `is_instance_valid(current_satellite)`.

#### Paso 2.3 — Coexistencia Planeta-Satélite en `PlanetSpawner` y Eliminación de Fallback Huérfano
* **Archivo:** `scenes/combat/environment/planet_spawner.gd`.
* **Cambios:**
  * En `_is_position_valid_for_planet(pos: Vector2, min_dist: float = -1.0, is_orbital_slot: bool = false) -> bool`: cuando `is_orbital_slot == true`, usar una distancia mínima de colisión física de `450.0 px` respecto al grupo `"satellites"` (en lugar de `2500.0 px`), permitiendo que el planeta destruible y el satélite habiten el mismo sistema solar sin bloquearse mutuamente.
  * En `_spawn_initial_test_planet()`: si `_get_cosmos_controller() != null`, usar exclusivamente los slots estelares de Cosmos Engine (sin caer en el fallback huérfano `center + Vector2(1700.0, -400.0)`).

#### Verificación de la Sesión 2:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/test_satellite_odometer_and_transmutation_runner.tscn"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/test_gamespeed_and_satellite_despawn_runner.tscn"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/test_satellite_edge_indicator_runner.tscn"
```

---

## 📋 Prompt Listo para Copiar y Pegar en el Nuevo Chat (Sesión 1)

```text
Ejecuta la SESIÓN ATÓMICA 1 documentada en `Bugs Actuales.md` (Pasos 1.1 a 1.6) y verifica los 3 tests aislados indicados al final de la sesión.
```
