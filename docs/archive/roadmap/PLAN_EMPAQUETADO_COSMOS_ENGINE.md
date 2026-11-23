# Plan de Empaquetado y Promoción de Cosmos Engine — Sesiones Atómicas

> **Ubicación:** `docs/roadmap/PLAN_EMPAQUETADO_COSMOS_ENGINE.md`  
> **Objetivo:** Promover y empaquetar de forma modular el motor astronómico procedural desde `sandbox/` a producción (`scenes/combat/environment/cosmos/`), dotándolo de inyección determinista de celdas (POIs narrativos), seguimiento transparente de cinemáticas de cámara y compatibilidad total con `PauseArbitrator` y freezes de combate.  
> **Directriz de Ejecución:** Cumplir la regla de higiene de sesiones (1 Sesión / Tarea Atómica = 1 Conversación, máx. 12-15 turnos por sesión, pruebas aisladas con `tools/run_tests.ps1`).

---

## 🗺️ Mapa de Dependencias de las Sesiones

```mermaid
flowchart TD
    S1["Sesión 1: Estructura del Módulo & Migración de Activos Base\n(scenes/combat/environment/cosmos/)"]
    S2["Sesión 2: Determinismo & POI Override Registry\n(Inyección narrativa de celdas/arquetipos)"]
    S3["Sesión 3: Cinemáticas & Sincronización de Viewport\n(ViewportCanvasTracker & Cámara dirigida)"]
    S4["Sesión 4: Fachada CosmosHostController, Pausa & Freeze\n(PauseArbitrator, hit-stops & transiciones de región)"]
    S5["Sesión 5: Enlace con SpaceEnvironmentHost & Validación Integral\n(Plug & Play en MainGame + Test Suite completa)"]

    S1 --> S2
    S1 --> S3
    S2 --> S4
    S3 --> S4
    S4 --> S5
```

---

## 📦 Sesión 1: Estructura del Paquete en Producción & Copia Segura de Componentes
* **Objetivo:** Crear el árbol de producción bajo `scenes/combat/environment/cosmos/` y promover los scripts, shaders y recursos validados sin alterar `sandbox/` (manteniéndolo como playground/testbed).
* **Alcance Técnico:**
  1. Crear estructura de carpetas:
     - `scenes/combat/environment/cosmos/core/` (math, streamers, grid, hashing)
     - `scenes/combat/environment/cosmos/shaders/` (nebulosas, starfield, sombras, estrellas)
     - `scenes/combat/environment/cosmos/resources/` (perfiles de bioma, arquetipos de estrellas)
     - `scenes/combat/environment/cosmos/scenes/` (`cosmos_root.tscn`)
  2. Ajustar rutas de `preload` y dependencias cruzadas en los scripts promovidos para que apunten a la nueva ruta en producción.
  3. Garantizar tipado estricto en el 100% de los archivos movidos.
* **Criterio de Verificación:**
  - Test runner específico de integridad:
    ```powershell
    powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_packaging_smoke.tscn"
    ```
* **Entregable:** Subescena base `cosmos_root.tscn` instanciable limpiamente bajo `scenes/combat/environment/cosmos/`.

---

## 📦 Sesión 2: Motor Determinista & `CosmicPoiRegistry` (Inyección Narrativa) (✅ Completada)
* **Objetivo:** Permitir que `MainGame` o los directores de eventos inyecten configuraciones específicas de soles/planetas/galaxias en coordenadas virtuales o relativas al jugador.
* **Alcance Técnico Completado:**
  1. ✅ Diseñado el recurso tipado [`CosmicPoiConfig`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd) (`archetype`, `planet_count`, `custom_label`, `hazard_level`, `seed_override`).
  2. ✅ Implementado [`CosmicPoiRegistry`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/cosmic_poi_registry.gd):
     - Almacenamiento $O(1)$ de overrides por coordenada de celda `Vector2i(gx, gy)`.
     - Métodos: `register_poi()`, `register_relative_poi()`, `unregister_poi()`, `clear_overrides()`, `has_poi()`, `get_poi()`.
  3. ✅ Adaptados `CosmosSolarSystemStreamer`, `CosmosSolarSystem2D` y `CosmosGalaxyStreamer2D`:
     - Al recorrer las celdas en el frustum visible, comprueban `poi_registry.has_poi(cell)`.
     - Si existe override, instancian la entidad con los parámetros forzados del `CosmicPoiConfig` (arquetipo estelar, label personalizado y número exacto de planetas), omitiendo la aleatoriedad procedural.
  4. ✅ Enlace y delegación implementados en [`CosmosRootNode`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/scenes/cosmos_root.gd) con sincronización automática hacia todos los streamers.
* **Criterio de Verificación Cumplido:**
  - Test runner aislado pasando al 100%:
    ```powershell
    powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmic_poi_registry.tscn"
    ```
* **Entregable:** Inyección procedural de POIs sobreescribible en tiempo real sin fugas de memoria ni regresiones.

---

## 📦 Sesión 3: Compatibilidad con Cinemáticas & `ViewportCanvasTracker` (✅ Completada)
* **Objetivo:** Desacoplar el seguimiento de la cámara del nodo específico del jugador, sincronizando las capas de paralaje de forma continua y transparente con cualquier cámara activa o cinemática.
* **Alcance Técnico Completado:**
  1. ✅ Implementado [`CosmosViewportCanvasTracker`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/viewport_canvas_tracker.gd):
     - Muestreo analítico exacto de `Transform2D` invertido vía `get_viewport().get_canvas_transform()`.
     - Extracción automática de posición central de pantalla, rotación y zoom vectorial.
     - Suavizado contra micro-saltos y teleport/cortes instantáneos (`force_teleport()`, `max_position_delta_per_frame`).
  2. ✅ Enlazado e integrado en [`CosmosRootNode`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/scenes/cosmos_root.gd):
     - Detección automática en `_ready()` o instanciación dinámica en tiempo de ejecución.
     - Señal `viewport_updated` redirigida a `_on_viewport_updated` propagando overrides analíticos directos a todos los streamers (`set_camera_override`) y shaders (`set_world_view_position`).
  3. ✅ Soporte de fallback y origen flotante en [`CosmosFloatingOriginTracker`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/floating_origin_tracker.gd):
     - Método analítico `get_tracked_position()` monitoreando prioritariamente `player_target`, `viewport_tracker` o `camera`.
* **Criterio de Verificación Cumplido:**
  - Test runner específico de cinemáticas y transform del viewport pasando al 100%:
    ```powershell
    powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_viewport_tracker.tscn"
    ```
* **Entregable:** Fondo cósmico reactivo tanto a juego libre como a cámaras dirigidas por cinemáticas sin necesidad de enlazar nodos manualmente.

---

## 📦 Sesión 4: Fachada `CosmosHostController`, Transiciones de Región & Freeze/Pausa (✅ Completada)
* **Objetivo:** Construir la API pública unificada del entorno cósmico que consumirá `MainGame`, integrando control de regiones, congelamiento por hit-stop y pausa de árbol.
* **Alcance Técnico Completado:**
  1. ✅ Implementado [`CosmosHostController`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/cosmos_host_controller.gd):
     - API pública unificada:
       - `change_region(region_id: StringName, blend_duration: float)`
       - `apply_biome(biome_config: CosmosBiomeConfig, blend_duration: float)`
       - `inject_poi_relative_to_player(...)` / `inject_poi_at_virtual_coords(...)`
       - `set_frozen(is_frozen: bool)`
     - Integración reactiva con `PauseArbitrator.pause_state_changed`: sincroniza pausas globales pausando el tiempo cósmico `_global_time`.
     - Soporte desacoplado para hit-stops y freezes balísticos sin requerir pausar el SceneTree completo.
  2. ✅ Implementado [`CosmicBiomeBlender`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/cosmic_biome_blender.gd):
     - Transición suave de biomas mediante tweens de SceneTree o progresión analítica manual (`advance_manual_blend`).
     - Control exacto de uniforms `biome_blend_factor` y paletas A/B sin allocations dinámicas.
  3. ✅ Soporte de congelamiento `is_frozen` integrado en [`CosmosRootNode`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/scenes/cosmos_root.gd) y propagado a [`CosmosNebulaBackdropController`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos/core/nebula_backdrop_controller.gd).
* **Criterio de Verificación Cumplido:**
  - Test runner específico pasando al 100%:
    ```powershell
    powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_host_controller.tscn"
    ```
* **Entregable:** Fachada de alto nivel desacoplada y validada contra pausas globales, hit-stops, cambios de región e inyección de POIs.

---

## 📦 Sesión 5: Integración Plug & Play en `SpaceEnvironmentHost` & Validación Integral (✅ Completada)
* **Objetivo:** Conectar el empaquetado final a `SpaceEnvironmentHost` en `scenes/combat/environment/` y validar en combate real a 60 FPS sin regresiones.
* **Alcance Técnico Completado:**
  1. ✅ Creado el adaptador [`CosmosCombatEnvironment`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos_combat_environment.gd) y su escena [`cosmos_combat_environment.tscn`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/cosmos_combat_environment.tscn), implementando el contrato formal de [`BaseSpaceEnvironment`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/base_space_environment.gd).
  2. ✅ Enlazado en [`SpaceEnvironmentHost`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/environment/space_environment_host.gd):
     - Mapeo y progresión reactiva de biomas cósmicos (`WAVE_BIOME_MAP`) al avanzar oleadas (`on_wave_started`).
     - Métodos de acceso y conveniencia `get_cosmos_controller()` y `change_region()`.
     - Soporte desacoplado de freeze/pausa conectando `CosmosHostController` con `PauseArbitrator`.
  3. ✅ Suite de pruebas automatizadas y arnés de integración:
     - `test_space_environment_integration.tscn` ejecutada y aprobada (100% PASS).
     - Verificación de instanciación e integridad de todas las escenas principales (`test_scenes_integrity.gd`) pasando al 100%.
     - Verificación de regresión integral con la suite `-CoreOnly` (21/21 suites en verde, 0 fallos, 0 timeouts).
  4. ✅ Actualizado [`AGENT_CONTEXT.md`](AGENT_CONTEXT.md) reflejando la promoción y disponibilidad del módulo en producción.
* **Criterio de Verificación Cumplido:**
  - Integración Plug & Play sin acoplamiento, cero regresiones en danmaku (`BulletServer`), colisiones y HUD.
* **Entregable:** Cosmos Engine 100% operativo y promovido en producción.
