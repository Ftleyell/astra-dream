# Reglas de Desarrollo — Cosmos Engine (Producción & Sandbox)

> **Ámbito de aplicación:** Se aplica siempre que se interactúe con el entorno espacial en producción (`scenes/combat/environment/cosmos/`, `scenes/combat/environment/`) o el banco de pruebas experimental (`sandbox/`).

---

## 1. 🚫 Regla de Orquestadores vs Recursos de Balance
- **PROHIBIDO modificar scripts orquestadores** (`cosmos_root.gd`, `solar_system_streamer.gd`, `galaxy_streamer_2d.gd`, `debris_streamer_2d.gd`, `planetary_shadow_projector_2d.gd`, `cosmos_host_controller.gd`) ante solicitudes de **ajuste visual, balance numérico, colores, tamaños o densidades**. Estos ajustes van estrictamente en `.tres` (sección 2).
- **PERMITIDO:** Modificaciones de contratos tipados, corrección de bugs de inicialización, transforms y conexiones de interoperabilidad descritas en [`docs/COSMIC_GAMEPLAY_BRIDGE.md`](docs/COSMIC_GAMEPLAY_BRIDGE.md).
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
- Prohibido ejecutar suites globales o `-CoreOnly` durante la iteración activa en Cosmos Engine.
- Usar **únicamente** el test específico del componente tocado (búsqueda recursiva habilitada):
  - **Integración con MainGame y Semillas:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "space_environment"` (~4.3s)
  - **Órbitas, Anti-snapping y Parallax:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "orbital_binding_events"` (~6.3s)
  - **Slots Analíticos y Binding de Entidades:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "gameplay_orbital_binding"` (~4.1s)
  - **Controlador Host & Biomas (Producción):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmos_host_controller"` (~4.1s)
  - **Smoke Packaging Cosmos:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmos_packaging_smoke"` (~4.0s)
  - **Inyección POIs Narrativos (Producción):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmic_poi_registry"` (~4.1s)
  - **Sandbox Experimental (I+D):** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"`

---

## 4. 🔒 Barrera de Aislamiento y Producción
- El juego de combate principal (`main_game.tscn`) usa Cosmos Engine **exclusivamente** desde `scenes/combat/environment/cosmos/` a través de `SpaceEnvironmentHost` y `CosmosCombatEnvironment`.
- Prohibido enlazar nada de `sandbox/` en el árbol de escenas o código de combate de producción.

---

## 5. 🛡️ Contratos Arquitectónicos y Blindaje
1. **Desactivación de Floating Origin en Combate:** `FloatingOriginTracker` está estrictamente inhabilitado (`is_enabled = false`, `set_physics_process(false)`) al detectar `main_game` o `bullet_server` para prevenir desincronizaciones con el búfer contiguo de proyectiles.
2. **Slots Analíticos Puros:** `CosmosOrbitSlot` es un *Value Object* analítico sin punteros a nodos de la escena (`body_reference` eliminado). Las posiciones orbitales planetarias compuestas se evalúan en $\mathcal{O}(1)$ matemáticamente puro:
   $$\text{Pos}(t) = \text{Pos}_{\text{estrella}} + \text{Órbita}_{\text{planeta}}(t) + \text{Órbita}_{\text{satélite}}(t)$$
3. **Anti-Snapping en Parallax:** `OrbitalWorldFollower2D` aplica un bloqueo inmediato al congelar (`_freeze_weight = 1.0`) y una interpolación ponderada de descompresión suave a $0.4\,\text{s}$ al salir de un área congelada (`move_toward(_freeze_weight, 0.0, delta / 0.4)`). Si `scroll_scale == (1,1)`, el arrastre de paralaje es nulo y se omite.
4. **Sincronización Determinista de Semillas:** `CosmosCombatEnvironment.randomize_seed_on_ready` se mantiene en `false`. `main_game.run_seed` se inyecta canónicamente vía `SpaceEnvironmentHost` y se serializa/restaura con `RunStateSerializer`.
5. **Escalabilidad Gráfica de GPU:** `SettingsManager.space_background_quality` (0=Bajo/iGPU, 1=Medio/Deck, 2=Alto/Desktop) conmuta `CanvasLayerStarfield` y complejidad de destellos/dispersión para garantizar 60 FPS estables.
