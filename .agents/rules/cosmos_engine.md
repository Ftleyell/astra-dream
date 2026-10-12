# Reglas de Desarrollo — Cosmos Engine (Sandbox & Adaptadores)

> **Ámbito de aplicación:** Se aplica siempre que se interactúe con el subsistema `sandbox/`, recursos cósmicos en `sandbox/resources/`, shaders en `sandbox/shaders/` y adaptadores de entorno espacial en `scenes/combat/environment/`.

---

## 1. 🚫 Prohibición Estricta de Exploración y Modificación Ciega de Orquestadores
- **PROHIBIDO modificar o refactorizar scripts orquestadores** (`cosmos_root.gd`, `solar_system_streamer.gd`, `galaxy_streamer_2d.gd`, `debris_streamer_2d.gd`, `planetary_shadow_projector_2d.gd`) ante solicitudes de ajuste visual, balance numérico, colores, tamaños o densidades.
- **PROHIBIDO buscar ciegamente con `grep` o escaneos recursivos** de archivos para localizar parámetros de balance cósmico.

---

## 2. 🗂️ Tabla Contractual Directa: Parámetro $\to$ Recurso (`.tres`)
Toda modificación numérica o estética DEBE realizarse directamente en el recurso exportado correspondiente mediante `replace_file_content`:

| Requerimiento / Aspecto a Modificar | Recurso Exclusivo a Editar | Variables Clave |
|---|---|---|
| **Sombras Planetarias / Eclipses** | `sandbox/resources/data/default_shadow_system.tres` | `shadow_intensity`, `shadow_penumbra_ratio`, `shadow_expansion_factor`, `shadow_heliopause_fade`, `shadow_tint` |
| **Parámetros Estelares / Corona / Luz** | `sandbox/resources/data/default_star_visual.tres` | `heat_distortion_strength`, `pulse_speed`, `light_field_radius_multiplier`, `light_field_intensity`, `heliosphere_noise_strength`, `heliosphere_edge_feather`, `core_brightness` |
| **Arquetipos de Estrellas Específicos** | `sandbox/resources/data/star_archetypes/<tipo>.tres` (`yellow_dwarf`, `blue_giant`, `red_dwarf`, `white_dwarf`, `magnetar`) | `archetype_name`, `spawn_weight`, `star_radius`, `min_orbit_radius`, `max_orbit_radius`, `star_color`, `corona_tint` |
| **Órbitas, Planetas, Lunas y Estaciones** | `sandbox/resources/data/default_planetary_system.tres` | `cell_size`, `cell_boundary_padding`, `min_orbital_spacing`, `planet_theta_jitter_degrees`, `planet_size_multiplier`, `moon_spawn_probability`, `moon_size_ratio`, `station_spawn_probability`, `station_size_ratio` |
| **Composición General de Sistemas Solares** | `sandbox/resources/data/default_celestial_system.tres` | Agregador de `star_visual_config`, `shadow_system_config`, `planetary_system_config` y `star_archetypes` |
| **Biomas de Nebulosa & Paletas de Gas** | `sandbox/resources/data/biomes/<biome>.tres` o `default_cosmic_biome.tres` | `primary_gas_color`, `secondary_gas_color`, `nebula_density`, `turbulence_speed`, `nebula_tile_scale`, `nebula_tile_mix`, `nebula_deep_stars_*` |
| **Buffer Estelar 8K y Fondo** | `sandbox/cosmos_root.tscn` (Materiales de capa) | `ShaderMaterial_nebula` (`deep_stars_intensity`, `deep_stars_scale`), `ShaderMaterial_starfield` (`star_intensity`, `twinkle_amount`, `twinkle_speed`) |
| **Escombros Espaciales MultiMesh** | `sandbox/resources/data/default_debris_layer.tres` | `instance_count`, `scrap_instance_count`, `micro_ratio`, `medium_ratio`, `macro_ratio`, `micro_scale_range`, `medium_scale_range`, `macro_scale_range`, `cell_size` |
| **Macro-Galaxias de Fondo** | `sandbox/resources/data/default_galaxy_landmark.tres` | `spawn_chance`, `maximum_bounding_radius`, `safety_padding`, `base_scale_range`, `scroll_scale`, `max_drift_rotation_speed`, `shader_spin_speed`, `overall_brightness` |
| **Perfil Parallax Maestro Unificado** | `sandbox/resources/data/default_cosmos_environment.tres` | `nebula_scroll_scale`, `starfield_scroll_scale`, `galaxy_scroll_scale`, `debris_scroll_scale`, `solar_system_scroll_scale` |

---

## 3. 🧪 Verificación Rápida y Aislada (Test Específico)
- Prohibido ejecutar suites globales o `-CoreOnly` durante la iteración en Cosmos Engine.
- Usar **únicamente** el test específico del componente tocado:
  - Data-driven / Recursos: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_data_driven.tscn"`
  - Sombras / Proyector: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_planetary_shadows.tscn"`
  - Perfil / Biomas: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_environment_profile.tscn"`
  - Integración del Sandbox: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"`

---

## 4. 🔒 Barrera de Aislamiento de Sandbox
- Ningún archivo de producción bajo `scenes/` o `core/` debe importar `sandbox/` directamente, salvo adaptadores formales de desacople autorizados en `scenes/combat/environment/`.
