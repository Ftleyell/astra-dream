# Cheatsheet & Mapa de Ajuste Rápido — Cosmos Engine

> **Objetivo:** Consultar este archivo antes de abrir scripts del sandbox. Proporciona las líneas exactas, archivos responsables, variables editables y tests específicos para modificar o afinar cualquier aspecto del motor espacial **sin incurrir en lecturas ciegas ni desperdiciar tokens**.

---

## 🗺️ 1. Mapa de Subsistemas -> Archivos Directos

| Subsistema / Elemento Visual | Archivo Principal | Recurso de Balance (.tres) | Qué controla |
|---|---|---|---|
| **Orquestador Central** | [`sandbox/cosmos_root.gd`](../../sandbox/cosmos_root.gd) | `sandbox/cosmos_root.tscn` | Prioridad de proceso (`-100`), orquestación de tiempo global `_global_time`, enlace de cámara y estratos. |
| **Perfil Maestro Unificado** | [`sandbox/resources/cosmos_environment_profile.gd`](../../sandbox/resources/cosmos_environment_profile.gd) | [`sandbox/resources/data/default_cosmos_environment.tres`](../../sandbox/resources/data/default_cosmos_environment.tres) | Centraliza factores de paralaje (1-5), sub-perfiles y parámetros ópticos de shaders con propagación reactiva en runtime. |
| **Origen Flotante (Anti-Jitter)** | [`sandbox/core/floating_origin_tracker.gd`](../../sandbox/core/floating_origin_tracker.gd) | Configurado en nodo export | Umbral de recentrado (`threshold_distance = 10000.0`), absorción en `Parallax2D.scroll_offset`. |
| **Grid Determinista & Hash** | [`sandbox/core/cosmic_macro_grid.gd`](../../sandbox/core/cosmic_macro_grid.gd) / [`cosmic_hasher.gd`](../../sandbox/core/cosmic_hasher.gd) | — | Tamaño de cuadrantes ($O(1)$ sin estado), funciones hash pseudo-aleatorias y semillas estables. |
| **Sistemas Solares & Órbitas** | [`sandbox/astronomy/solar_system_streamer.gd`](../../sandbox/astronomy/solar_system_streamer.gd) | [`sandbox/resources/data/default_planetary_system.tres`](../../sandbox/resources/data/default_planetary_system.tres) / [`default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres) | Generación de estrellas centrales, planetas keplerianos, radios min/max, lunas y streaming por celda. |
| **Sombras Planetarias & Eclipses** | [`sandbox/astronomy/planetary_shadow_projector_2d.gd`](../../sandbox/astronomy/planetary_shadow_projector_2d.gd) | [`sandbox/resources/data/default_shadow_system.tres`](../../sandbox/resources/data/default_shadow_system.tres) | Conos de sombra analíticos, penumbra smoothstep, desvanecimiento en heliopausa y composición anti-double-darkening. |
| **Cuerpos Celestes Individuales** | [`sandbox/astronomy/solar_system_2d.gd`](../../sandbox/astronomy/solar_system_2d.gd) / [`orbital_body_2d.gd`](../../sandbox/astronomy/orbital_body_2d.gd) | [`sandbox/resources/data/default_star_visual.tres`](../../sandbox/resources/data/default_star_visual.tres) / [`star_archetypes/`](../../sandbox/resources/data/star_archetypes/) | Fórmulas analíticas keplerianas, dibujo de órbitas vectoriales, sol central, corona y heliosfera. |
| **Macro-Galaxias Ultra-Lentas** | [`sandbox/rendering/galaxy_streamer_2d.gd`](../../sandbox/rendering/galaxy_streamer_2d.gd) | [`sandbox/resources/data/default_galaxy_landmark.tres`](../../sandbox/resources/data/default_galaxy_landmark.tres) | Regla de galaxia única sin solapamiento, retención analítica en frustum anti-desaparición, capa ultra-profunda (`scroll_scale = 0.04`). |
| **Buffer Estelar 8K Óptico (Capa 2)** | [`sandbox/shaders/deep_starfield.gdshader`](../../sandbox/shaders/deep_starfield.gdshader) / [`starfield_backdrop_controller.gd`](../../sandbox/rendering/starfield_backdrop_controller.gd) | Configurado en `ShaderMaterial_starfield` ([`cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L40)) | CanvasLayer (-105) a pantalla completa inmune al zoom. Muestreo 1:1 de máscara 8K RGB pura. Kernel óptico: halos, núcleo incandescente y espículas. Discard de fondo negro. |
| **Micro-Estrellas Nebulares (Capa 1)** | [`sandbox/shaders/universe_nebula.gdshader`](../../sandbox/shaders/universe_nebula.gdshader#L134) | Configurado en `ShaderMaterial_nebula` ([`cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L23)) | Ventana amplia (escala 3.0) para micro-estrellas nítidas de 1-2px, tintadas por canal RGB sin espículas ni centelleo. Fondo casi inmóvil (`parallax = 0.005`). |
| **Cinturón de Escombros GPU** | [`sandbox/environment/debris_streamer_2d.gd`](../../sandbox/environment/debris_streamer_2d.gd) | [`sandbox/resources/data/default_debris_layer.tres`](../../sandbox/resources/data/default_debris_layer.tres) | `MultiMeshInstance2D` (1 draw call, 2000 fragmentos), densidad, escala, rotación estocástica. |
| **Shader de Nebulosa & Biomas** | [`sandbox/shaders/universe_nebula.gdshader`](../../sandbox/shaders/universe_nebula.gdshader) / [`nebula_backdrop_controller.gd`](../../sandbox/rendering/nebula_backdrop_controller.gd) | [`sandbox/resources/data/default_cosmic_biome.tres`](../../sandbox/resources/data/default_cosmic_biome.tres) | FBM Simplex en GPU, anti-tiling estocástico, blending de color A/B, turbulencia de gas. |
| **Visual Debugger 2D (Gizmos)** | [`sandbox/rendering/cosmos_debug_drawer_2d.gd`](../../sandbox/rendering/cosmos_debug_drawer_2d.gd) | Tecla `F2` en runtime | Renderizado vectorial: frustum analítico de cámara, celdas de macro-grid, círculos de delimitación galáctica y origen flotante. |
| **Nave de Prueba & Heroína** | [`sandbox/scenes/player_vessel.gd`](../../sandbox/scenes/player_vessel.gd) | [`data/characters/roster/nova.tres`](../../data/characters/roster/nova.tres) | Aceleración, frenado, giro inercial, toberas de plasma, Sandevistan VFX y alternancia de heroína (`TAB`/`E`/`Q`). |
| **Cámara & Zoom Suave** | [`sandbox/scenes/cosmos_camera_2d.gd`](../../sandbox/scenes/cosmos_camera_2d.gd) | — | Suavizado posicional, zoom elástico por rueda de ratón (`min_zoom = 0.2`, `max_zoom = 2.0`). |
| **Overlay y Panel Live Debug** | [`sandbox/scenes/cosmos_telemetry_overlay.gd`](../../sandbox/scenes/cosmos_telemetry_overlay.gd) | Tecla `F1` / Toggles `1-5` / `F2` | HUD y panel interactivo colapsable: telemetría en tiempo real, toggles de estratos 1 a 5, sliders en caliente y acelerador de tiempo cósmico. |

---

## 🎛️ 2. Parámetros de Ajuste Rápido y Dónde Cambiarlos

### A. Si quieres cambiar los Sistemas Solares o Arquetipos Estelares:
- **Perfil Maestro de Sistemas:** [`sandbox/resources/data/default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres)
- **Arquetipos Data-Driven (`StarArchetype`):**
  - Enana Amarilla (Estándar/Equilibrada): [`yellow_dwarf.tres`](../../sandbox/resources/data/star_archetypes/yellow_dwarf.tres) (`weight: 4.0`, radio: 700px, órbitas: 1600-4800px, color ámbar cálido)
  - Gigante Azul (Masiva/Caliente): [`blue_giant.tres`](../../sandbox/resources/data/star_archetypes/blue_giant.tres) (`weight: 1.5`, radio: 1000px, órbitas: 2200-5600px, color azul zafiro)
  - Enana Roja (Compacta/Densa): [`red_dwarf.tres`](../../sandbox/resources/data/star_archetypes/red_dwarf.tres) (`weight: 3.0`, radio: 520px, órbitas: 1200-3600px, color carmesí)
- **Shaders Visuales de Soles:**
  - Shader de Corona Solar y Distorsión de Calor: [`sandbox/shaders/star_corona.gdshader`](../../sandbox/shaders/star_corona.gdshader) (Elimina el fondo negro JPG, ondas convectivas de calor y borde de plasma palpitante).
  - Shader de Luz Orbital y Heliosfera: [`sandbox/shaders/star_light_field.gdshader`](../../sandbox/shaders/star_light_field.gdshader) (Proyecta el bioma cósmico local del sol: halo orgánico con ruido procedural FBM de gas/polvo estelar y suave fade-out smoothstep en el límite de la heliopausa).
  - Shader Universal de Cuerpos Celestes: [`sandbox/shaders/celestial_body.gdshader`](../../sandbox/shaders/celestial_body.gdshader) (Incorpora tinte dinámico de luz solar sobre la cara diurna iluminada y el Fresnel atmosférico, con atenuación analítica por distancia orbital).
- **Proporciones Planetarias y Subestructuras:**
  - Multiplicador de escala de planetas: `planet_size_multiplier = 1.15` (+15% de escala sobre diámetro base).
  - Lunas: Activas con probabilidad (`moon_spawn_probability = 0.65`, 1-2 por planeta en zonas habitables), tamaño al `20%` del diámetro del planeta (`moon_size_ratio = 0.20`).
  - Estaciones espaciales: Garantizadas 1 por planeta habitable (`station_spawn_probability = 1.0`), tamaño al `15%` del diámetro del planeta (`station_size_ratio = 0.15`) y radio orbital adaptativo (1.9x a 2.5x).
  - Escala armónica secundaria: Al crecer los planetas un 15%, las lunas, estaciones y sus radios orbitales secundarios se expanden un 15% de forma proporcional.
- **Variables clave de ajuste:**
  - `cell_size`: Tamaño de cuadrante estelar (calibrado a: `12000.0` px para holgura de sistemas grandes).
  - `cell_boundary_padding`: Margen perimetral de seguridad por celda (calibrado a: `250.0` px, sumando 500px entre celdas contiguas para evitar solapamientos en las comisuras sin generar franjas vacías excesivas).
  - `min_orbital_spacing`: Buffer radial mínimo garantizado anti-pisado entre planetas consecutivos (default: `650.0` px).
  - `planet_theta_jitter_degrees`: Dispersión angular orgánica sobre la fase distribuida ($360^\circ / N$, default: `25.0` deg).
  - `spawn_chance`: Probabilidad de que una celda contenga un sistema (`1.0` = 100%).
  - `spawn_weight`: Probabilidad ponderada de aparición de cada arquetipo.
  - `heat_distortion_strength`: Intensidad de la ondulación térmica del disco central.
  - `pulse_speed`: Frecuencia de latido y respiración del plasma solar.
  - `light_field_radius_multiplier` / `light_field_intensity`: Alcance e intensidad del halo ambiental y bioma estelar.
  - `heliosphere_noise_strength` / `heliosphere_edge_feather`: Turbulencia FBM del bioma de gas orbital y suavidad del fade out en el borde orbital.
  - `core_brightness`: Brillo térmico del núcleo solar en el shader de corona (calibrado a: `1.25` para evitar deslumbramiento blanco excesivo).
  - `planet_day_exposure` / `planet_night_ambient`: Factor de exposición diurna (`1.30`) y luz ambiental nocturna enriquecida (`0.22`, earthshine/starlight) en `celestial_body.gdshader`.
  - `enable_planetary_shadows` / `shadow_intensity` / `shadow_penumbra_ratio` / `shadow_expansion_factor` / `shadow_heliopause_fade` / `shadow_tint`: Sistema de sombras planetarias concéntricas agrupadas en `CanvasGroup` con shader de composición `cosmic_shadow_group.gdshader` (Anti Double-Darkening garantizado). Punta circular concéntrica exacta a la heliopausa (`r_sun = sqrt((D+x)^2 + y^2)`), base calibrada al disco visible real y eclipses interplanetarios analíticos en GPU. Ajustable en vivo desde el Debug Panel (F1): Opacidad, Suavidad de Penumbra, Expansión Cónica y Fade Heliopausa.

### B. Si quieres cambiar la escala, distancia o velocidad de las Macro-Galaxias de fondo:
- **Archivo de Balance:** [`sandbox/resources/data/default_galaxy_landmark.tres`](../../sandbox/resources/data/default_galaxy_landmark.tres)
- **Perfil Parallax:** [`default_cosmos_environment.tres`](../../sandbox/resources/data/default_cosmos_environment.tres) (`galaxy_scroll_scale`)
- **Variables clave:**
  - `spawn_chance`: Probabilidad estocástica (`1.0` = 100% de presencia en cuadrantes).
  - `maximum_bounding_radius`: Radio analítico (calibrado a: `2000.0` px para reducir drásticamente el espacio muerto entre galaxias).
  - `safety_padding`: Margen de amortiguación en frustum (calibrado a: `400.0` px).
  - `base_scale_range`: Rango min/max de escala estocástica (`Vector2(0.85, 1.35)`).
  - `scroll_scale`: Velocidad relativa del paralaje (`Vector2(0.1, 0.1)`).
  - `max_drift_rotation_speed`: Giro continuo del sprite en el espacio (`0.012` rad/s).
  - `shader_spin_speed`: Giro de los brazos espirales en el shader (`0.015`).
  - `overall_brightness`: Opacidad y luminosidad aditiva general (`1.45`).



### C. Si quieres cambiar la cantidad, mezclas o estratos de Escombros Espaciales (Dual MultiMesh):
- **Archivo:** [`sandbox/resources/data/default_debris_layer.tres`](../../sandbox/resources/data/default_debris_layer.tres)
- **Variables clave:**
  - `rock_texture` / `scrap_texture`: Texturas de atlas (`debris_atlas_0.png` y `debris_atlas_1.png`).
  - `instance_count` / `scrap_instance_count`: Instancias por estrato (default: 1000 rocas, 600 chatarra -> 1600 total en 2 draw calls).
  - `micro_ratio` / `medium_ratio` / `macro_ratio`: Ponderación estocástica de tamaños (calibrado a 70% micro, 25% mediano, 5% macro).
  - `micro_scale_range` / `medium_scale_range` / `macro_scale_range`: Rangos de escala para cada estrato sin deformación de aspecto.
  - `micro_alpha_multiplier` / `medium_alpha_multiplier` / `macro_alpha_multiplier`: Modulación de alfa y profundidad por estrato.
  - `cell_size`: Cuadrante espacial de regeneración estocástica (default: `8192.0` px).


### D. Si quieres alterar los colores o densidad de la Nebulosa:
- **Archivo:** [`sandbox/resources/data/default_cosmic_biome.tres`](../../sandbox/resources/data/default_cosmic_biome.tres) / [`sandbox/cosmos_root.tscn`](../../sandbox/cosmos_root.tscn)
- **Variables clave:**
  - `primary_gas_color`: Color base del gas estelar.
  - `secondary_gas_color`: Color de acento / choque térmico.
  - `nebula_density`: Opacidad general del shader ($0.0 \to 1.0$).
  - `turbulence_speed`: Velocidad de movimiento del FBM en tiempo global.
  - `nebula_tile_texture`: Textura seamless de detalle en tiles (`nebula_seamless_0.png`).
  - `nebula_tile_scale`: Escala UV espacial de repetición del tile (default: `0.00035`).
  - `nebula_tile_mix`: Peso de mezcla de la textura con el FBM procedural ($0.0 \to 1.0$, default: `0.45`).
  - `nebula_deep_stars_twinkle_speed`: Frecuencia de centelleo y pulsación estocástica de micro-estrellas (default: `2.2`).
  - `nebula_deep_stars_sparkle_intensity`: Intensidad de los chispazos agudos repentinos en los picos de oscilación (default: `0.85`).
  - `nebula_deep_stars_halo_radius`: Expansión del halo incandescente en el clímax de la estrella (default: `1.35`).
  - `nebula_deep_stars_gas_interaction`: Fuerza de fusión volumétrica e iluminación sobre el gas nebular (default: `0.75`).

### E. Si quieres calibrar la sensibilidad o umbral del Floating Origin:
- **Archivo:** [`sandbox/core/floating_origin_tracker.gd`](../../sandbox/core/floating_origin_tracker.gd#L14)
- **Variables clave:**
  - `threshold_distance`: Distancia antes de recentrar (default: `10000.0` px). Disminuir a `5000.0` para pruebas de estrés de shifts frecuentes; aumentar a `20000.0` para mundos muy abiertos.

### F. Si quieres calibrar el suavizado y amortiguación de la Cámara (Anti-Snapback):
- **Archivo:** [`sandbox/scenes/cosmos_camera_2d.gd`](../../sandbox/scenes/cosmos_camera_2d.gd)
- **Variables clave:**
  - `smoothing_enabled`: Habilita o deshabilita la amortiguación inercial (default: `true`).
  - `smoothing_speed`: Velocidad de seguimiento amortiguado (default: `8.0`). Valores mayores = cámara más pegada; valores menores = mayor desfase dinámico a velocidad.
  - `max_smoothing_distance`: Tope máximo de lag visual (default: `600.0` px) para garantizar que la nave nunca salga del encuadre en aceleraciones extremas.
  - *Nota técnica:* El sistema desacopla el lag nativo de Godot (`position_smoothing_enabled = false`) y utiliza absorción vectorial analítica en `on_origin_shifted(shift)` para garantizar **cero snapback** cuando la posición local se recentra a (0, 0).

### G. Si quieres calibrar los 2 Estratos de Estrellas en la Nebulosa (Máscara 8K sobre negro):
- **Estrato 1 (Micro-estrellas de fondo ultra-lejanas):**
  - **Material:** `ShaderMaterial_nebula` en [`sandbox/cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L23)
  - `deep_stars_intensity`: Brillo general del lecho estelar ultra-profundo (default: `0.55`).
  - `deep_stars_scale`: Escala de la ventana (default: `3.0` -> micro-puntos densos de 1-2px).
  - `deep_stars_parallax`: Factor de traslación respecto a la cámara (default: `0.005` -> casi inmóvil).
  - *Interacción de gas:* Fusión volumétrica suave bañando el gas cósmico.
- **Capa 2 (Buffer Estelar 8K Óptico en CanvasLayer -105, detrás de la Nebulosa):**
  - **Ubicación:** `CanvasLayerStarfield` (`layer = -105`, `follow_viewport_enabled = true`) en [`sandbox/cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L110). Físicamente ubicado **por detrás** de la nebulosa (`layer = -100`).
  - **Material:** `ShaderMaterial_starfield` en [`sandbox/cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L56).
  - `scroll_scale`: Velocidad de paralaje calibrada a `Vector2(0.0065, 0.0065)` (más rápido que el fondo 0.005 pero majestuoso y lento).
  - `window_scale`: Escala de proyección sobre los 8192 px (`1.35` -> puntos medianos visibles de 4-8px con halo esférico).
  - `star_intensity`: Brillo general e incandescencia (calibrado a: `3.6`).
  - `twinkle_amount` / `twinkle_speed`: Titileo orgánico y picos de destello (`0.35` / `2.4`).
  - *Translucidez del gas:* El shader `universe_nebula.gdshader` en `layer = -100` tiene alfa variable por densidad de gas, cubriendo las estrellas donde el gas es denso y dejándolas brillar a través en el espacio oscuro.

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
| **Perfil & Live Debug** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_environment_profile.tscn"` |
| **Integración Total** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"` |

---

## 🚫 4. Reglas Inviolables de Mantenimiento

1. **Nunca editar números mágicos en código `.gd`:** Todo valor de radio, velocidad, color, escala o probabilidad DEBE editarse en los archivos `.tres` correspondientes en `sandbox/resources/data/`.
2. **Inspecciones con rangos acotados:** No leer más de 50-80 líneas al usar `view_file`. Consultar la tabla de arriba para conocer el número de línea exacto de antemano.
3. **No contaminar producción:** Ningún script de `scenes/combat/` o `core/` debe importar archivos de `sandbox/` hasta la fase formal de promoción.
