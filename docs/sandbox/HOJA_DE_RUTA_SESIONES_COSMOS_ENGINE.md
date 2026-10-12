# Hoja de Ruta Sesión a Sesión: Cosmos Engine (Sandbox)

> **Ubicación:** `docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md`  
> **Destino de Código:** `sandbox/` (Aislado de producción `scenes/` y `core/`)  
> **Documentación Base:** `docs/sandbox/MOTOR_ESPACIAL_PROCEDURAL_ARQUITECTURA.md` y `docs/sandbox/Arquitectura Cosmos Engine Godot.md`  
> **Regla de Sesión:** "1 Tarea = 1 Conversación" (Máx. 10-12 turnos para mantener el contexto < 40k tokens).

---

## 📋 Resumen del Roadmap de 7 Sesiones Atómicas

| Sesión | Componente Principal | Entregables Clave | Suite de Test Asociada |
|---|---|---|---|
| **S1** | **Cimientos de Datos y Math** | Recursos `.tres`, `CosmicHasher`, `CosmicMacroGrid` | `tests/sandbox/test_cosmic_math.tscn` |
| **S2** | **Fase 1: Galaxia Única 1-a-1** | `GalaxyStreamer2D`, Frustum analítico en Parallax | `tests/sandbox/test_galaxy_streaming.tscn` |
| **S3** | **Fase 2: Sistemas Keplerianos** | `OrbitalBody2D`, `SolarSystem2D`, `SolarSystemStreamer` | `tests/sandbox/test_solar_system.tscn` |
| **S4** | **Floating Origin Tracker** | `FloatingOriginTracker`, compensación `scroll_offset` | `tests/sandbox/test_floating_origin.tscn` |
| **S5** | **MultiMesh Debris & Biomas** | `DebrisStreamer2D` (GPU batch), `universe_nebula.gdshader` | `tests/sandbox/test_debris_multimesh.tscn` |
| **S6** | **Fase 3: Integración CosmosRoot** | `CosmosRoot.tscn`, 6 capas, nave de test libre | `tests/sandbox/test_cosmos_engine_integration.tscn` |
| **S7** | **Telemetría y Criterios Migración** | Benchmark 60 FPS, guía de desacople para producción | Checklist de Auditoría |

---

## 🚀 Guía de Ejecución Sesión a Sesión

---

### 🔹 SESIÓN 1: Cimientos de Datos y Matemáticas Deterministas

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 1 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Implementa los recursos data-driven y el núcleo matemático determinista de CosmicHasher y CosmicMacroGrid en sandbox/, con su suite de prueba unitaria BaseTestSuite.
```

#### Alcance y Archivos a Crear:
1. **Recursos Data-Driven (`sandbox/resources/`):**
   - `cosmic_biome_config.gd` (clase `CosmicBiomeConfig` extendiendo `Resource`).
   - `galaxy_landmark_profile.gd` (clase `GalaxyLandmarkProfile`).
   - `celestial_system_profile.gd` (clase `CelestialSystemProfile`).
   - `debris_layer_profile.gd` (clase `DebrisLayerProfile`).
   - Crear instancias `.tres` por defecto en `sandbox/resources/data/`.
2. **Matemáticas Deterministas $O(1)$ (`sandbox/core/`):**
   - `cosmic_hasher.gd` (`class_name CosmicHasher extends RefCounted`):
     - Implementar variante SplitMix64 con constantes `BIT_MIXER_1`, `BIT_MIXER_2`, `BIT_MIXER_3`.
     - Funciones: `hash_2d(x: int, y: int, seed: int) -> int`, `hash_2d_float(x: int, y: int, seed: int) -> float` (retorno en $[0.0, 1.0)$), `hash_2d_vector(x: int, y: int, seed: int) -> Vector2`.
   - `cosmic_macro_grid.gd` (`class_name CosmicMacroGrid extends RefCounted`):
     - Conversión `world_to_grid_coords(pos: Vector2) -> Vector2i`.
     - `grid_to_world_center(coords: Vector2i) -> Vector2`.
     - `get_cell_normalized_offset` y `get_cell_pseudorandom_float`.
3. **Suite de Test (`tests/sandbox/`):**
   - `test_cosmic_math.gd` y `test_cosmic_math.tscn` (heredando de `BaseTestSuite`).
   - Validar: Determinismo (misma semilla = mismo resultado), dispersión uniforme de hashes, y precisión en coordenadas negativas y positivas.

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmic_math.tscn"
```

#### Definition of Done:
- [ ] 4 clases de recursos tipadas y 4 archivos `.tres` creados.
- [ ] `CosmicHasher` y `CosmicMacroGrid` con tipado estricto y sin asignaciones dinámicas.
- [ ] Test unitario ejecutado y pasando al 100% en menos de 2 segundos.

---

### 🔹 SESIÓN 2: Fase 1 — Macro-Galaxia Única y Frustum Ultra-Lento

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 2 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Implementa GalaxyStreamer2D en sandbox/rendering/ con proyección analítica en Parallax2D lento (scroll_scale 0.02) y garantía geométrica 1-a-1, escena interactiva y suite de test.
```

#### Alcance y Archivos a Crear:
1. **Controlador de Streaming Galáctico (`sandbox/rendering/`):**
   - `galaxy_streamer_2d.gd` (`class_name GalaxyStreamer2D extends Node2D`):
     - Propiedades exportadas: `landmark_profile: GalaxyLandmarkProfile`, `parallax_layer: Parallax2D`, `camera: Camera2D`, `run_seed: int`.
     - `_initialize_exclusivity_geometry()`: derivar tamaño de celda $L_{\text{cell}} \ge 2 \cdot D_{\text{min}}$ donde $D_{\text{min}} = D_{\text{frustum}}^{\text{max}} + 2 R_{\text{max}} + 2 P_{\text{safe}}$.
     - Frustum culling analítico exacto en espacio de capa: `_intersects_frustum(pos, center, half_extents)`.
     - Zero allocations: Instanciar un único `Sprite2D` preasignado en `_ready()` (`_active_galaxy_sprite`). Reutilizarlo y cambiar textura, posición, escala y rotación.
     - Transición suave: interpolación de opacidad `_current_alpha` mediante `move_toward` a `_target_alpha`.
2. **Escena de Visualización Interactiva (`sandbox/scenes/`):**
   - `test_galaxy_frustum.tscn`: Contiene `Camera2D` con script de movimiento libre por teclado (WASD/flechas), un `Parallax2D` (`scroll_scale = Vector2(0.02, 0.02)`), y el nodo `GalaxyStreamer2D`.
3. **Suite de Test Automatizada (`tests/sandbox/`):**
   - `test_galaxy_streaming.gd` y `test_galaxy_streaming.tscn` (heredando de `BaseTestSuite`).
   - Comprobar que en ninguna posición aleatoria o durante desplazamientos de miles de píxeles existen 2 galaxias simultáneas en el frustum proyectado.

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_galaxy_streaming.tscn"
```

#### Definition of Done:
- [ ] Exclusividad 1-a-1 comprobada matemáticamente.
- [ ] Cero nodos instanciados o destruidos durante el loop `_process(delta)`.
- [ ] Suite de test en verde en < 3 segundos.

---

### 🔹 SESIÓN 3: Fase 2 — Cinemática Orbital Determinista y Sistemas Solares

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 3 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Implementa OrbitalBody2D, SolarSystem2D y SolarSystemStreamer en sandbox/astronomy/ con cinemática kepleriana analítica continua t_global * omega en Parallax2D, escena interactiva y suite de test.
```

#### Alcance y Archivos a Crear:
1. **Entidades Astronómicas (`sandbox/astronomy/`):**
   - `orbital_body_2d.gd` (`class_name OrbitalBody2D extends Node2D`):
     - Almacenar parámetros estáticos: `orbit_radius`, `angular_velocity`, `initial_theta`, `axial_rotation_velocity`.
     - `evaluate_orbital_position(global_time: float) -> void`: Cálculo analítico $x = r \cos(\theta_0 + \omega t)$, $y = r \sin(\theta_0 + \omega t)$. Evaluar recursivamente cuerpos secundarios (lunas).
   - `solar_system_2d.gd` (`class_name SolarSystem2D extends Node2D`):
     - `_build_system_hierarchy()`: Construcción procedural basada en `system_seed` (estrella central + $N$ planetas en rangos keplerianos y lunas).
     - `update_astronomical_state(global_time: float) -> void`.
   - `solar_system_streamer.gd` (`class_name SolarSystemStreamer extends Node2D`):
     - Macro-grilla determinista para activar y posicionar sistemas solares bajo `Parallax2D` (`scroll_scale = Vector2(0.20, 0.20)`).
     - Object pool preasignado de instancias `SolarSystem2D`.
2. **Escena de Visualización Interactiva (`sandbox/scenes/`):**
   - `test_solar_hierarchy.tscn`: Sol + planetas + lunas orbitando en tiempo real con control de velocidad de tiempo.
3. **Suite de Test Automatizada (`tests/sandbox/`):**
   - `test_solar_system.gd` y `test_solar_system.tscn`.
   - Evaluar posición en $t = 0$, avanzar a $t = 10000$ y regresar a $t = 0$; comprobar error euclidiano $< 0.0001$ px (cero deriva numérica).

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_solar_system.tscn"
```

#### Definition of Done:
- [x] Posicionamiento orbital 100% analítico sin uso de `delta` acumulativo.
- [x] Jerarquía estrella -> planeta -> luna continua y estable en Parallax2D.
- [x] Suite de prueba pasando al 100%.

---

### 🔹 SESIÓN 4: Supervisor de Origen Flotante y Compensación Parallax

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 4 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Implementa FloatingOriginTracker en sandbox/core/ con absorción vectorial exacta sobre Parallax2D.scroll_offset, mitigando jitter/stutter en recentrados, escena de validación y test automatizado.
```

#### Alcance y Archivos a Crear:
1. **Supervisor Flotante (`sandbox/core/`):**
   - `floating_origin_tracker.gd` (`class_name FloatingOriginTracker extends Node`):
     - Señal: `signal origin_shifted(shift_vector: Vector2)`.
     - Propiedades exportadas: `player_target: Node2D`, `camera: Camera2D`, `threshold_distance: float` (default 10000.0), `parallax_layers: Array[Parallax2D]`.
     - En `_physics_process`: evaluar si `player_target.global_position.length_squared() >= threshold_distance * threshold_distance`.
     - Al recentrar:
       ```gdscript
       player_target.global_position -= shift
       camera.global_position -= shift
       camera.reset_smoothing()
       for layer: Parallax2D in parallax_layers:
           layer.scroll_offset += shift * layer.scroll_scale
       origin_shifted.emit(shift)
       ```
2. **Escena de Prueba Aislada (`sandbox/scenes/`):**
   - `test_floating_origin.tscn`: Cámara móvil que se aleja a alta velocidad, con capas de paralaje de prueba y marcadores visuales para verificar la ausencia de tirones.
3. **Suite de Test Automatizada (`tests/sandbox/`):**
   - `test_floating_origin.gd` y `test_floating_origin.tscn`.
   - Simular un recentrado de $(10000, 10000)$ y medir analíticamente la posición aparente en pantalla de un objeto en Parallax2D antes y después del frame de traslación (diferencia esperada = $0.0$).

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_floating_origin.tscn"
```

#### Definition of Done:
- [x] Absorción pasiva en Parallax2D sin necesidad de iterar sobre nodos hijos.
- [x] Continuidad visual garantizada sin micro-saltos de 1 frame.
- [x] Test automatizado en verde.

---

### 🔹 SESIÓN 5: Cinturón de Escombros MultiMesh GPU y Shaders de Biomas

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 5 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Implementa DebrisStreamer2D con MultiMeshInstance2D determinista en 1 draw call y universe_nebula.gdshader con muestreo anti-tiling y blending de biomas en sandbox/, con escena de prueba y test.
```

#### Alcance y Archivos a Crear:
1. **Cinturón de Escombros GPU (`sandbox/environment/`):**
   - `debris_streamer_2d.gd` (`class_name DebrisStreamer2D extends Node2D`):
     - Uso de `MultiMeshInstance2D` (`TRANSFORM_2D`, `use_colors = true`).
     - Al cruzar frontera de cuadrante: regeneración determinista del buffer de transformaciones y colores en GPU mediante `CosmicHasher`.
2. **Shader de Nebulosa y Biomas (`sandbox/shaders/` y `sandbox/rendering/`):**
   - `universe_nebula.gdshader`:
     - FBM simplex/gradient en GPU con dispersión cromática angular en canales RGB.
     - Función `sample_starfield_anti_tile`: doble muestreo descorrelacionado para eliminar repetición en mosaico.
     - Blending suave `smoothstep` entre Bioma A y Bioma B según `biome_blend_factor`.
   - `nebula_backdrop_controller.gd`: Actualización de uniforms en el material del `ColorRect` (`camera_world_position`, `viewport_resolution`).
3. **Escena Interactiva de Validación (`sandbox/scenes/`):**
   - `test_debris_and_nebula.tscn`.
4. **Suite de Test Automatizada (`tests/sandbox/`):**
   - `test_debris_multimesh.gd` y `test_debris_multimesh.tscn`.
   - Validar conteo de instancias y consistencia determinista de posiciones por cuadrante.

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_debris_multimesh.tscn"
```

#### Definition of Done:
- [x] Hasta 2000 fragmentos de escombros renderizados en 1 único draw call.
- [x] Shader de nebulosa continuo sin costuras y libre de artefactos de 32-bit.
- [x] Suite de prueba aprobada.

---

### 🔹 SESIÓN 6: Fase 3 — Integración Maestra de Cosmos Engine en Sandbox

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 6 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Ensambla la escena maestra sandbox/cosmos_root.tscn unificando los 6 estratos Parallax2D, FloatingOriginTracker, nave de exploración libre con telemetría en cosmos_engine_demo.tscn, y suite de integración integral.
```

#### Alcance y Archivos a Crear:
1. **Escena Raíz del Motor (`sandbox/`):**
   - `cosmos_root.tscn` y `cosmos_root.gd`:
     - Estratos canónicos: `ParallaxNebulaDeep`, `ParallaxMacroGalaxies`, `ParallaxStarfield8K`, `ParallaxSolarSystems`, `ParallaxDebrisBelt`, `GameplayWorld`.
     - Orquestación del tiempo global cósmico (`global_time`).
     - Prioridades de proceso configuradas para sincronizar el recentrado antes del render de paralaje.
2. **Escena de Demostración y Vuelo Libre (`sandbox/scenes/`):**
   - `cosmos_engine_demo.tscn`:
     - Nave de exploración `PlayerVessel` (CharacterBody2D con propulsión inercial).
     - `CosmosCamera2D` con zoom suave por rueda del ratón y suavizado elástico.
     - Overlay de depuración en pantalla: Posición absoluta, velocidad, celda galáctica actual, shifts de origen y FPS en vivo.
3. **Suite Integral de Integración (`tests/sandbox/`):**
   - `test_cosmos_engine_integration.gd` y `test_cosmos_engine_integration.tscn`.
   - Ejecución simulada con desplazamiento a $50.000$ unidades, verificando streaming, órbitas, escombros y recentrados coordinados.

#### Comando de Verificación:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"
```

#### Definition of Done:
- [x] Los 6 estratos operan armónicamente en `CosmosRoot`.
- [x] Vuelo libre sin micro-tirones ni saltos visuales durante shifts de origen.
- [x] Suite integral de integración en verde.

---

### 🔹 SESIÓN 7: Telemetría, Benchmark y Protocolo de Promoción

#### Prompt para la Sesión:
```text
Ejecuta la SESIÓN 7 de docs/sandbox/HOJA_DE_RUTA_SESIONES_COSMOS_ENGINE.md: Realiza el análisis de perfilado y benchmark de 60 FPS del Cosmos Engine, documenta el mapa completo de sandbox/ y redacta el protocolo de migración para producción en docs/sandbox/GUIA_MIGRACION_COSMOS_PRODUCCION.md.
```

#### Alcance y Archivos a Crear/Actualizar:
1. **Auditoría de Rendimiento:**
   - Perfilado de memoria y FPS en escenarios de estrés (zoom mínimo $0.25$, velocidad extrema).
   - Verificación de compresión de textura estelar 8K (VRAM Compressed BPTC).
2. **Documentación de Migración y Desacople (`docs/sandbox/`):**
   - `GUIA_MIGRACION_COSMOS_PRODUCCION.md`:
     - Contrato de desacople entre `CosmosRoot` y `scenes/combat/main_game.gd`.
     - Cómo reemplazar `space_environment_host.gd` por capas de Cosmos Engine sin alterar `BulletServer` ni colisiones de gameplay.
     - Requisitos para conectar biomas cósmicos con la progresión de oleadas de combate.
3. **Cierre de I+D:**
   - Actualización de `AGENT_CONTEXT.md` y `docs/sandbox/MOTOR_ESPACIAL_PROCEDURAL_ARQUITECTURA.md` con el estado final completado en `sandbox/`.

#### Definition of Done:
- [x] 60 FPS estables verificados sin picos de stutter.
- [x] Documentación técnica completa y lista para ser consultada por futuros desarrollos.
- [x] Cero dependencias rotas o importaciones cruzadas con producción.

---

## 🛑 Reglas Inviolables Durante Todo el Desarrollo

1. **Nunca enlazar `sandbox/` en runtime de producción:** Ningún archivo en `scenes/` o `core/` debe importar rutas de `sandbox/` hasta que se inicie formalmente la etapa de migración.
2. **Data-Driven Estricto:** Toda constante de radio, velocidad, color, frecuencia o densidad DEBE residir en un recurso `.tres`.
3. **Tipado Estricto GDScript 4:** Cero advertencias del linter; tipado estricto en todas las variables, funciones y argumentos.
4. **Higiene Atómica:** No mezclar sesiones. Al terminar una sesión con test en verde, hacer commit y comenzar la siguiente en un chat limpio.
