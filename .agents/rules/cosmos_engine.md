# Reglas de Desarrollo — Cosmos Engine (Producción & Sandbox)

> **Ámbito de aplicación:** Se aplica siempre que se interactúe con el entorno espacial en producción (`scenes/combat/environment/cosmos/`, `scenes/combat/environment/`) o el banco de pruebas experimental (`sandbox/`).

---

## 1. 🚫 Prohibición Estricta de Exploración y Modificación Ciega de Orquestadores
- **PROHIBIDO modificar o refactorizar scripts orquestadores** (`cosmos_root.gd`, `solar_system_streamer.gd`, `galaxy_streamer_2d.gd`, `debris_streamer_2d.gd`, `planetary_shadow_projector_2d.gd`, `cosmos_host_controller.gd`) ante solicitudes de ajuste visual, balance numérico, colores, tamaños o densidades.
- **PROHIBIDO buscar ciegamente con `grep` o escaneos recursivos** de archivos para localizar parámetros de balance cósmico.

---

## 2. 🗂️ Tabla Contractual Directa: Parámetro $\to$ Recurso (`.tres`)
Toda modificación numérica o estética DEBE realizarse directamente en el recurso exportado correspondiente en **PRODUCCIÓN** (`scenes/combat/environment/cosmos/resources/data/`) mediante `replace_file_content`:

| Requerimiento / Aspecto a Modificar | Recurso de Producción Exclusivo | Variables Clave |
|---|---|---|
| **Sombras Planetarias / Eclipses** | `scenes/combat/environment/cosmos/resources/data/default_shadow_system.tres` | `shadow_intensity`, `shadow_penumbra_ratio`, `shadow_expansion_factor`, `shadow_heliopause_fade`, `shadow_tint` |
| **Parámetros Estelares / Corona / Luz** | `scenes/combat/environment/cosmos/resources/data/default_star_visual.tres` | `heat_distortion_strength`, `pulse_speed`, `light_field_radius_multiplier`, `light_field_intensity`, `heliosphere_noise_strength`, `heliosphere_edge_feather`, `core_brightness` |
| **Arquetipos de Estrellas Específicos** | `scenes/combat/environment/cosmos/resources/data/star_archetypes/<tipo>.tres` (`yellow_dwarf`, `blue_giant`, `red_dwarf`, `white_dwarf`, `magnetar`) | `archetype_name`, `spawn_weight`, `star_radius`, `min_orbit_radius`, `max_orbit_radius`, `star_color`, `corona_tint` |
| **Órbitas, Planetas, Lunas y Estaciones** | `scenes/combat/environment/cosmos/resources/data/default_planetary_system.tres` | `cell_size`, `cell_boundary_padding`, `min_orbital_spacing`, `planet_theta_jitter_degrees`, `planet_size_multiplier`, `moon_spawn_probability`, `moon_size_ratio`, `station_spawn_probability`, `station_size_ratio` |
| **Composición General de Sistemas Solares** | `scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres` | Agregador de `star_visual_config`, `shadow_system_config`, `planetary_system_config` y `star_archetypes` |
| **Biomas de Nebulosa & Paletas de Gas** | `scenes/combat/environment/cosmos/resources/data/biomes/<biome>.tres` o `default_cosmic_biome.tres` | `primary_gas_color`, `secondary_gas_color`, `nebula_density`, `turbulence_speed`, `nebula_tile_scale`, `nebula_tile_mix`, `nebula_deep_stars_*` |
| **Escombros Espaciales MultiMesh** | `scenes/combat/environment/cosmos/resources/data/default_debris_layer.tres` | `instance_count`, `scrap_instance_count`, `micro_ratio`, `medium_ratio`, `macro_ratio`, `micro_scale_range`, `medium_scale_range`, `macro_scale_range`, `cell_size` |
| **Macro-Galaxias de Fondo** | `scenes/combat/environment/cosmos/resources/data/default_galaxy_landmark.tres` | `spawn_chance`, `maximum_bounding_radius`, `safety_padding`, `base_scale_range`, `scroll_scale`, `max_drift_rotation_speed`, `shader_spin_speed`, `overall_brightness` |
| **Perfil Parallax Maestro Unificado** | `scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres` | `nebula_scroll_scale`, `starfield_scroll_scale`, `galaxy_scroll_scale`, `debris_scroll_scale`, `solar_system_scroll_scale` |
| **Inyección Determinista de POIs (Narrativa)** | `scenes/combat/environment/cosmos/resources/data/pois/<poi>.tres` | `poi_id`, `star_archetype`, `forced_planet_count`, `hazard_level`, `custom_label`, `seed_override` |

*(Nota: Los archivos equivalentes bajo `sandbox/resources/data/` aplican únicamente al experimentar en la escena aislada del sandbox).*

---

## 3. 🧪 Verificación Rápida y Aislada (Test Específico)
- Prohibido ejecutar suites globales o `-CoreOnly` durante la iteración en Cosmos Engine.
- Usar **únicamente** el test específico del componente tocado:
  - **Integración con MainGame / SpaceEnvironmentHost:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_space_environment_integration.tscn"`
  - **Controlador Host & Biomas (Producción):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_host_controller.tscn"`
  - **Inyección POIs Narrativos (Producción):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmic_poi_registry.tscn"`
  - **Viewport Tracker / Cinemáticas (Producción):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_cosmos_viewport_tracker.tscn"`
  - **Sandbox Experimental (I+D):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"`

---

## 4. 🔒 Barrera de Aislamiento y Producción
- El juego de combate principal (`main_game.tscn`) usa Cosmos Engine **exclusivamente** desde `scenes/combat/environment/cosmos/` a través de `SpaceEnvironmentHost` y `CosmosCombatEnvironment`.
- Prohibido enlazar nada de `sandbox/` en el árbol de escenas o código de combate de producción.
