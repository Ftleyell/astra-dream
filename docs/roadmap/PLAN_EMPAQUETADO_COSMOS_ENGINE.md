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

## 📦 Sesión 4: Fachada `CosmosHostController`, Transiciones de Región & Freeze/Pausa
* **Objetivo:** Construir la API pública unificada del entorno cósmico que consumirá `MainGame`, integrando control de regiones, congelamiento por hit-stop y pausa de árbol.
* **Alcance Técnico:**
  1. Implementar `CosmosHostController.gd`:
     - API pública:
       - `change_region(region_id: StringName, blend_duration: float)`
       - `inject_poi_relative_to_player(...)` / `inject_poi_at_virtual_coords(...)`
       - `set_frozen(is_frozen: bool)`
     - Conexión a `PauseArbitrator.pause_state_changed`:
       - Al pausarse el juego, suspende el incremento de `_global_time` y congela los tweens de nebulosa activos.
     - Manejo de `set_frozen(true)` para congelar el tiempo cósmico durante micro-hit-stops de combate (sin requerir pausa del árbol completo).
  2. Implementar `CosmicBiomeBlender.gd` para interpolar suavemente los uniforms de color y turbulencia de los shaders de nebulosa y starfield durante cambios de región.
* **Criterio de Verificación:**
  - Test runner de fachada, pausa y hit-stop:
    ```powershell
    powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_host_controller.tscn"
    ```
* **Entregable:** Fachada de alto nivel desacoplada y lista para conectarse al juego.

---

## 📦 Sesión 5: Integración Plug & Play en `SpaceEnvironmentHost` & Validación Integral
* **Objetivo:** Conectar el empaquetado final a `SpaceEnvironmentHost` en `scenes/combat/environment/` y validar en combate real a 60 FPS sin regresiones.
* **Alcance Técnico:**
  1. Asignar la subescena empaquetada como opción en `SpaceEnvironmentHost.gd`:
     - Configurar `custom_environment_scene` o default con `CosmosCombatEnvironment`.
  2. Enlazar eventos de inicio de oleada (`on_wave_started`) y narrativa de combate con `CosmosHostController`.
  3. Ejecutar suite completa de tests de combate y core:
     ```powershell
     powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_space_environment.tscn"
     powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
     ```
  4. Actualizar [`AGENT_CONTEXT.md`](AGENT_CONTEXT.md) reflejando la promoción oficial de Cosmos Engine al árbol de producción.
* **Criterio de Verificación:**
  - Main Game corriendo a 60 FPS estables con Cosmos Engine de fondo en combate.
  - Cero regresiones en danmaku (`BulletServer`), colisiones y HUD.
* **Entregable:** Cosmos Engine 100% operativo en producción.
