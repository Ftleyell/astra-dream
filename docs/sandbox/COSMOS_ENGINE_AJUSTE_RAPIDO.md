# Cheatsheet & Mapa de Ajuste Rápido — Cosmos Engine

> **Objetivo:** Consultar este archivo antes de abrir scripts del sandbox. Proporciona las líneas exactas, archivos responsables, variables editables y tests específicos para modificar o afinar cualquier aspecto del motor espacial **sin incurrir en lecturas ciegas ni desperdiciar tokens**.

---

## 🗺️ 1. Mapa de Subsistemas -> Archivos Directos

| Subsistema / Elemento Visual | Archivo Principal | Recurso de Balance (.tres) | Qué controla |
|---|---|---|---|
| **Orquestador Central** | [`sandbox/cosmos_root.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/cosmos_root.gd) | `sandbox/cosmos_root.tscn` | Prioridad de proceso (`-100`), orquestación de tiempo global `_global_time`, enlace de cámara y estratos. |
| **Origen Flotante (Anti-Jitter)** | [`sandbox/core/floating_origin_tracker.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/core/floating_origin_tracker.gd) | Configurado en nodo export | Umbral de recentrado (`threshold_distance = 10000.0`), absorción en `Parallax2D.scroll_offset`. |
| **Grid Determinista & Hash** | [`sandbox/core/cosmic_macro_grid.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/core/cosmic_macro_grid.gd) / [`cosmic_hasher.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/core/cosmic_hasher.gd) | — | Tamaño de cuadrantes ($O(1)$ sin estado), funciones hash pseudo-aleatorias y semillas estables. |
| **Sistemas Solares & Órbitas** | [`sandbox/astronomy/solar_system_streamer.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/astronomy/solar_system_streamer.gd) | [`sandbox/resources/data/default_celestial_system.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_celestial_system.tres) | Generación de estrellas centrales, planetas keplerianos, radios min/max, lunas y streaming por celda. |
| **Cuerpos Celestes Individuales** | [`sandbox/astronomy/solar_system_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/astronomy/solar_system_2d.gd) / [`orbital_body_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/astronomy/orbital_body_2d.gd) | [`sandbox/resources/celestial_system_profile.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/celestial_system_profile.gd) | Fórmulas analíticas $\theta(t) = \theta_0 + t \cdot \omega$, dibujo de órbitas vectoriales, sol central. |
| **Macro-Galaxias Ultra-Lentas** | [`sandbox/rendering/galaxy_streamer_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/rendering/galaxy_streamer_2d.gd) | [`sandbox/resources/data/default_galaxy_landmark.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_galaxy_landmark.tres) | Regla de galaxia única sin solapamiento, frustum analítico en capa ultralenta (`scroll_scale = 0.02`), desvanecimiento suave. |
| **Cinturón de Escombros GPU** | [`sandbox/environment/debris_streamer_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/environment/debris_streamer_2d.gd) | [`sandbox/resources/data/default_debris_layer.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_debris_layer.tres) | `MultiMeshInstance2D` (1 draw call, 2000 fragmentos), densidad, escala, rotación estocástica. |
| **Shader de Nebulosa & Biomas** | [`sandbox/shaders/universe_nebula.gdshader`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/shaders/universe_nebula.gdshader) / [`nebula_backdrop_controller.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/rendering/nebula_backdrop_controller.gd) | [`sandbox/resources/data/default_cosmic_biome.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_cosmic_biome.tres) | FBM Simplex en GPU, anti-tiling estocástico, blending de color A/B, turbulencia de gas. |
| **Nave de Prueba & Heroína** | [`sandbox/scenes/player_vessel.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/scenes/player_vessel.gd) | [`data/characters/roster/nova.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/characters/roster/nova.tres) | Aceleración, frenado, giro inercial, toberas de plasma, Sandevistan VFX y alternancia de heroína (`TAB`/`E`/`Q`). |
| **Cámara & Zoom Suave** | [`sandbox/scenes/cosmos_camera_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/scenes/cosmos_camera_2d.gd) | — | Suavizado posicional, zoom elástico por rueda de ratón (`min_zoom = 0.2`, `max_zoom = 2.0`). |
| **Overlay de Telemetría** | [`sandbox/scenes/cosmos_telemetry_overlay.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/scenes/cosmos_telemetry_overlay.gd) | — | HUD de depuración: FPS, celda galáctica, coordenadas locales y absolutas, origin shifts. |

---

## 🎛️ 2. Parámetros de Ajuste Rápido y Dónde Cambiarlos

### A. Si quieres cambiar la densidad o distancia de los Sistemas Solares:
- **Archivo:** [`sandbox/resources/data/default_celestial_system.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_celestial_system.tres)
- **Variables clave:**
  - `cell_size`: Tamaño de cuadrante estelar (ej. `8000.0` px). Disminuir = sistemas más juntos; Aumentar = más vacío espacial.
  - `spawn_chance`: Probabilidad de que una celda contenga un sistema ($0.0 \to 1.0$).
  - `min_planets` / `max_planets`: Cantidad de planetas generados alrededor de la estrella.
  - `min_orbit_radius` / `max_orbit_radius`: Distancias orbitales desde el sol central.
  - `min_orbital_speed` / `max_orbital_speed`: Velocidad angular ($\omega$).

### B. Si quieres cambiar la frecuencia o tamaño de las Macro-Galaxias de fondo:
- **Archivo:** [`sandbox/resources/data/default_galaxy_landmark.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_galaxy_landmark.tres)
- **Variables clave:**
  - `cell_size`: Tamaño de celda galáctica (default: `60000.0` px).
  - `spawn_chance`: Probabilidad por macro-celda.
  - `min_scale` / `max_scale`: Escala del sprite o disco galáctico.
  - `fade_distance`: Distancia de suavizado periférico al entrar/salir del frustum.

### C. Si quieres cambiar la cantidad o velocidad de Escombros Espaciales:
- **Archivo:** [`sandbox/resources/data/default_debris_layer.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_debris_layer.tres)
- **Variables clave:**
  - `max_instances`: Cantidad en el pool de GPU (default: `1200` - máx recomendado: `2000`).
  - `cell_size`: Cuadrante de regeneración estocástica.
  - `min_scale` / `max_scale`: Tamaño de las rocas y chatarras.

### D. Si quieres alterar los colores o densidad de la Nebulosa:
- **Archivo:** [`sandbox/resources/data/default_cosmic_biome.tres`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/resources/data/default_cosmic_biome.tres)
- **Variables clave:**
  - `primary_gas_color`: Color base del gas estelar.
  - `secondary_gas_color`: Color de acento / choque térmico.
  - `nebula_density`: Opacidad general del shader ($0.0 \to 1.0$).
  - `turbulence_speed`: Velocidad de movimiento del FBM en tiempo global.

### E. Si quieres calibrar la sensibilidad o umbral del Floating Origin:
- **Archivo:** [`sandbox/core/floating_origin_tracker.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/core/floating_origin_tracker.gd#L14)
- **Variables clave:**
  - `threshold_distance`: Distancia antes de recentrar (default: `10000.0` px). Disminuir a `5000.0` para pruebas de estrés de shifts frecuentes; aumentar a `20000.0` para mundos muy abiertos.

### F. Si quieres calibrar el suavizado y amortiguación de la Cámara (Anti-Snapback):
- **Archivo:** [`sandbox/scenes/cosmos_camera_2d.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/sandbox/scenes/cosmos_camera_2d.gd)
- **Variables clave:**
  - `smoothing_enabled`: Habilita o deshabilita la amortiguación inercial (default: `true`).
  - `smoothing_speed`: Velocidad de seguimiento amortiguado (default: `8.0`). Valores mayores = cámara más pegada; valores menores = mayor desfase dinámico a velocidad.
  - `max_smoothing_distance`: Tope máximo de lag visual (default: `600.0` px) para garantizar que la nave nunca salga del encuadre en aceleraciones extremas.
  - *Nota técnica:* El sistema desacopla el lag nativo de Godot (`position_smoothing_enabled = false`) y utiliza absorción vectorial analítica en `on_origin_shifted(shift)` para garantizar **cero snapback** cuando la posición local se recentra a (0, 0).


---

## 🧪 3. Guía de Ejecución de Tests Específicos (Sin gastar tokens)

**Regla de oro:** Nunca correr suites completas innecesariamente durante ajustes menores. Usar el comando exacto del componente tocado:

| Si modificas... | Ejecuta este único comando en terminal (latencia 2s): |
|---|---|
| **Matemática/Hash** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmic_math.tscn"` |
| **Sistemas Solares** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_solar_system.tscn"` |
| **Galaxias de fondo** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_galaxy_streaming.tscn"` |
| **Origen Flotante** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_floating_origin.tscn"` |
| **Escombros MultiMesh** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_debris_multimesh.tscn"` |
| **Integración Total** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"` |

---

## 🚫 4. Reglas Inviolables de Mantenimiento

1. **Nunca editar números mágicos en código `.gd`:** Todo valor de radio, velocidad, color, escala o probabilidad DEBE editarse en los archivos `.tres` correspondientes en `sandbox/resources/data/`.
2. **Inspecciones con rangos acotados:** No leer más de 50-80 líneas al usar `view_file`. Consultar la tabla de arriba para conocer el número de línea exacto de antemano.
3. **No contaminar producción:** Ningún script de `scenes/combat/` o `core/` debe importar archivos de `sandbox/` hasta la fase formal de promoción.
