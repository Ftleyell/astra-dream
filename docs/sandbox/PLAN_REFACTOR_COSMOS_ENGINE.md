# 🌌 Plan Maestro: Refactorización, Estilizado y Migración de Cosmos Engine

> **Objetivo:** Transformar el prototipo de Cosmos Engine en una arquitectura 100% modular, data-driven (`.tres`), desacoplada y blindada contra loops de contexto de IA, dejándolo listo como un adaptador *drop-in* (`SpaceEnvironmentHost 2.0`) para el juego base.

---

## 🧭 Diagnóstico de Fricción & Anti-Patterns Actuales

1. **Dependencias circulares y valores dispersos:** Parámetros visuales y de balance divididos entre scripts `.gd`, nodos en `cosmos_root.tscn`, el panel F1 (`cosmos_telemetry_overlay.gd`) y recursos `.tres`.
2. **God-Object en Streaming:** `solar_system_streamer.gd` calcula geometría orbital, sombras, spawn de estaciones/lunas y asigna materiales en caliente, forzando al modelo a releer 400+ líneas para un cambio cosmético menor.
3. **Falta de contrato formal:** No existía una especificación de interfaz entre el entorno cósmico y la cámara/nave del juego base.

---

## 📅 Roadmap de Ejecución: 5 Sesiones Micro-Atómicas

### 🔹 Sesión 1: Desacople Estricto & Arquitectura Data-Driven Pura
* **Objetivo:** Extraer todo número mágico y configuración dispersa a Recursos (`.tres`) tipados e inmutables por estrato.
* **Acciones:**
  1. Diseñar y refactorizar schemas de recursos:
     - `PlanetarySystemConfig.tres` (órbitas, espaciados, dispersión angular).
     - `StarVisualConfig.tres` (corona, heliosfera, tintes de luz diurna/nocturna).
     - `ShadowSystemConfig.tres` (ancho base, longitud, pluma, curvatura).
  2. Purgar números mágicos de `solar_system_streamer.gd`, `solar_system_2d.gd` y `orbital_body_2d.gd`.
  3. Desacoplar `cosmos_telemetry_overlay.gd`: que actúe como un consumidor reflectivo de recursos sin tocar variables internas de los streamers.
* **Criterio de Aceptación:** Test unitario `test_cosmos_data_driven.tscn` verde. Cero variables de balance en scripts `.gd`.

---

### 🔹 Sesión 2: Descomposición Modular de Streaming y Shaders (✅ Completada)
* **Objetivo:** Dividir los controladores monolíticos en micro-componentes con responsabilidad única (anti God-Objects).
* **Acciones Completadas:**
  1. ✅ Extraída la generación y oclusión de sombras a un componente dedicado: [`PlanetaryShadowProjector2D`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/astronomy/planetary_shadow_projector_2d.gd).
  2. ✅ Extraído el cálculo kepleriano a una librería matemática pura sin estado de nodo: [`KeplerOrbitMath`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/astronomy/kepler_orbit_math.gd).
  3. ✅ Estandarizados los contratos de shaders de capas y sincronizados con los perfiles data-driven.
  4. ✅ Validación con suites de tests automatizados (`test_planetary_shadows.tscn`, `test_cosmos_engine_integration.tscn`, `test_cosmos_data_driven.tscn`) todas en verde (100% PASS).
* **Criterio de Aceptación Cumplido:** Descomposición modular estricta completada sin fugas de rendimiento ni regresiones funcionales.

---

### 🔹 Sesión 3: Estilizado Visual, Paletas & Curaduría de Biomas (✅ Completada)
* **Objetivo:** Proveer un flujo de trabajo intuitivo para artistas/diseñadores para crear y estilizar nuevos biomas y sistemas estelares en minutos sin tocar código.
* **Acciones Completadas:**
  1. ✅ Catálogo de presets visuales data-driven enriquecido:
     - Biomas de Nebulosa curados (6 variantes): *Grieta de Perseo*, *Forja de Hiperión*, *Abismo de Carina*, *Velo Carmesí*, *Corona Silícea*, *Vacío de Boötes*.
     - Catálogo de estrellas completado (5 arquetipos): Enana Amarilla, Gigante Azul, Enana Roja, [`white_dwarf.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/star_archetypes/white_dwarf.tres) (compacta, alta densidad/brillo nuclear) y [`magnetar.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/star_archetypes/magnetar.tres) (rotación ultrarrápida, corona intensa y plasma reactivo).
  2. ✅ Atenuación e interacción lumínica calibrada:
     - Curva cuadrática suave y atenuación orbital en `star_light_field.gdshader` sincronizada con límites analíticos de heliopausa.
     - Conos de sombra volumétricos en `planetary_shadow_cone.gdshader` y `cosmic_shadow_group.gdshader` perfectamente alineados con radios heliosféricos.
  3. ✅ Soporte interactivo y en runtime: conmutación de biomas en caliente con la tecla `B` o mediante el Debug Panel (`F1`), e inspección de frustum/límites analíticos vía Visual Debugger (`F2`).
  4. ✅ Suite de pruebas automatizadas actualizada (`test_cosmos_data_driven.tscn`, `test_cosmos_engine_integration.tscn`, `test_cosmos_environment_profile.tscn`) al 100% PASS.
* **Criterio de Aceptación Cumplido:** Conmutación instantánea y fluida de biomas e inyección data-driven de arquetipos estelares validada sin regresiones de rendimiento ni acoplamiento.

---

### 🔹 Sesión 4: Blindaje Documental & Reglas Anti-Loop (`.md` y `.agents/rules`) (✅ Completada)
* **Objetivo:** Erradicar para siempre los loops de contexto y relecturas ciegas en futuras sesiones de IA.
* **Acciones Completadas:**
  1. ✅ Actualizado [`docs/sandbox/COSMOS_ENGINE_AJUSTE_RAPIDO.md`](docs/sandbox/COSMOS_ENGINE_AJUSTE_RAPIDO.md) como contrato absoluto y tabla de correspondencia variable $\to$ `.tres`, integrando los nuevos recursos modulares (`default_shadow_system.tres`, `default_star_visual.tres`, `default_planetary_system.tres`).
  2. ✅ Creada la regla del subsistema en [`.agents/rules/cosmos_engine.md`](.agents/rules/cosmos_engine.md):
     - Instrucción directa al agente: prohibido inspeccionar scripts orquestadores si la tarea es de estilo, visual o balance.
     - Rutas directas a recursos `.tres` para evitar búsquedas recursivas (`grep`/`find`).
     - Especificación de comandos de test aislados por componente (latencia 2s).
  3. ✅ Actualizado [`AGENT_CONTEXT.md`](AGENT_CONTEXT.md) reflejando la regla condicional y la arquitectura modularizada del sandbox.
* **Criterio de Aceptación Cumplido:** Cualquier agente nuevo podrá ajustar el tamaño de una sombra, el color de una estrella o las órbitas consultando un único archivo y realizando una única edición `replace_file_content` sin loops de exploración.

---

### 🔹 Sesión 5: Adaptador Drop-in para Producción (`SpaceEnvironmentHost 2.0`) & Validación Final
* **Objetivo:** Empaquetar el Cosmos Engine para que pueda conectarse de forma transparente y sin romper nada al juego base (`scenes/combat/`).
* **Acciones:**
  1. Crear la fachada de producción `scenes/combat/environment/cosmos_space_environment.gd` que implemente la interfaz de `base_space_environment.gd`.
  2. Conectar la cámara del combate y el `FloatingOriginTracker` de manera invisible para la nave del jugador.
  3. Verificación de rendimiento y estabilidad con la suite completa de tests de producción:
     ```powershell
     powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_space_environment.tscn"
     ```
  4. Test integral final con `-CoreOnly`.
* **Criterio de Aceptación:** Main game corriendo con el Cosmos Engine de fondo a 60 FPS estables sin tocar una sola línea de la lógica de armas, enemigos o balas danmaku.
