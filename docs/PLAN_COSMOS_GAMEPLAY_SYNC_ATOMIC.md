# Plan de Implementación en Sesiones Atómicas: Cosmos Engine & Gameplay World Sync

> **Regla de Higiene de Sesiones:** Cumplir el principio de **1 Tarea = 1 Conversación**. Cada sesión debe comenzar en un nuevo chat para mantener el contexto ligero (<15k tokens iniciales) y finalizar con su test específico verificado.

---

## 🗺️ Mapa de Sesiones Atómicas

| Sesión | Dominio / Tarea | Archivos Clave | Test Específico de Cierre |
|---|---|---|---|
| **Sesión 1** | **Slot Orbital Dedicado Anti-Superposición** | `solar_system_2d.gd`<br>`cosmos_orbital_slot_tracker.gd`<br>`planet_spawner.gd` | `tests/unit/test_space_environment_integration.tscn` |
| **Sesión 2** | **Sombra Fotométrica Idéntica (`blend_mul`)** | `gameplay_planet_shadow_cone.gdshader`<br>`gameplay_planet_shadow_caster_2d.gd` | `tests/unit/test_space_environment_integration.tscn` |
| **Sesión 3** | **Overlay Día/Noche Universal Orientado al Sol** | `planet_day_night_lighting.gdshader`<br>`planet.gd`<br>`planet.tscn` | `tests/unit/test_space_environment_integration.tscn` |
| **Sesión 4** | **Anclaje de la Forja Cuántica al Centro Solar ($r=0$)** | `cosmos_orbital_slot_tracker.gd`<br>`combat_satellite_coordinator.gd` | `tests/test_chest_economy_suite.tscn` |

---

## 🚀 Sesión 1: Slot Orbital Dedicado Anti-Superposición

### Objetivo
Asegurar que cada sistema solar de Cosmos Engine genere un slot orbital invisible exclusivo con separación kepleriana garantizada (`effective_min_spacing`), y que `PlanetSpawner` en MainGame consuma dicho slot, eliminando de raíz cualquier colisión o solapamiento con planetas de fondo.

### Archivos Involucrados
1. [`scenes/combat/environment/cosmos/core/solar_system_2d.gd`](scenes/combat/environment/cosmos/core/solar_system_2d.gd):
   - Al calcular la progresión orbital kepleriana, reservar un radio y slot determinista para el planeta interactuable (`destructible_slot`).
   - Ningún planeta visual de fondo se genera en esa franja radial reservada.
2. [`scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd`](scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd):
   - Añadir método tipado `get_destructible_planet_slot(sys: CosmosSolarSystem2D, cell: Vector2i) -> CosmosOrbitSlot`.
   - Empaquetar este slot dentro del diccionario retornado por `get_slots_for_system()`.
3. [`scenes/combat/environment/planet_spawner.gd`](scenes/combat/environment/planet_spawner.gd):
   - En `_on_solar_system_streamed()` y `_spawn_planet_ahead()`, consumir prioritariamente el `destructible_slot` en lugar del radio estático 1450 px o posiciones aleatorias por odómetro cuando Cosmos Engine está activo.

### Criterios de Aceptación
- Ningún planeta de fondo comparte órbita con el planeta destructible.
- El planeta destructible orbita la estrella central de forma matemáticamente consistente con los demás planetas del sistema.
- El test pasa en <2 segundos:
  `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/unit/test_space_environment_integration.tscn"`

---

## 🌑 Sesión 2: Sombra Fotométrica Idéntica (`blend_mul`)

### Objetivo
Hacer que la sombra cónica del planeta destructible use el mismo modo de mezcla multiplicativo que Cosmos Engine para que el oscurecimiento sobre el espacio, nebulosas y polvo sea fotométricamente idéntico y no un velo translúcido.

### Archivos Involucrados
1. [`scenes/combat/environment/gameplay_planet_shadow_cone.gdshader`](scenes/combat/environment/gameplay_planet_shadow_cone.gdshader):
   - Cambiar `render_mode blend_mix, unshaded;` a `render_mode blend_mul, unshaded;`.
   - Modificar el cálculo de salida a:
     ```glsl
     vec3 mult_color = mix(vec3(1.0), shadow_tint.rgb, total_mask * shadow_opacity);
     COLOR = vec4(mult_color, 1.0);
     ```
2. [`scenes/combat/environment/gameplay_planet_shadow_caster_2d.gd`](scenes/combat/environment/gameplay_planet_shadow_caster_2d.gd):
   - Inyectar la configuración `CosmosShadowSystemConfig` activa desde Cosmos Engine (o cargar `default_shadow_system.tres` por defecto) para sincronizar `shadow_tint`, `shadow_opacity`, `penumbra_ratio` y `expansion_factor`.

### Criterios de Aceptación
- La sombra del planeta destructible oscurece la luz estelar y las nebulosas con exactamente el mismo tono y contraste que las sombras de los planetas de fondo.

---

## ☀️ Sesión 3: Overlay Día/Noche Universal Orientado al Sol

### Objetivo
Añadir iluminación esférica día/noche al planeta destructible sin alterar su complejo shader de destrucción de corteza por 8 sectores, grietas incandescentes y erosión del manto.

### Archivos Involucrados
1. `scenes/combat/environment/planet_day_night_lighting.gdshader` (Nuevo):
   - Shader esférico analítico en `render_mode blend_mul, unshaded;`.
   - Normal esférica $Z = \sqrt{1 - X^2 - Y^2}$ y producto escalar $N \cdot L$.
   - Parámetros: `light_direction`, `terminator_softness`, `night_ambient`, `day_exposure_boost`.
2. [`scenes/combat/environment/planet.gd`](scenes/combat/environment/planet.gd) y `planet.tscn`:
   - Añadir un Sprite2D overlay (`LightingOverlaySprite`) con el shader anterior cubriendo el radio del planeta.
   - En `_process()`, calcular el vector normalizado hacia la estrella (`(star_pos - global_position).normalized()`) y actualizar el parámetro `light_direction` del material.

### Criterios de Aceptación
- El planeta interactuable tiene una cara diurna orientada al sol y una cara nocturna en penumbra.
- Al destruir sectores de la corteza, el manto expuesto sigue respetando la iluminación día/noche de la esfera.

---

## ⚗️ Sesión 4: Anclaje de la Forja Cuántica al Centro Solar ($r = 0$)

### Objetivo
Hacer que la baliza de Forja Cuántica (`TransmutationStation`) aparezca en el centro exacto de la estrella central del sistema solar y permanezca anclada a ella con `OrbitalWorldFollower2D`.

### Archivos Involucrados
1. [`scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd`](scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd):
   - Exponer un método tipado `create_star_center_slot(sys, cell, scroll_scale) -> CosmosOrbitSlot` con radio orbital $r = 0.0$ y velocidad angular $\omega = 0.0$.
2. [`scenes/combat/systems/combat_satellite_coordinator.gd`](scenes/combat/systems/combat_satellite_coordinator.gd):
   - En el flujo de spawning (`_find_best_orbit_slot` / `spawn_next_satellite_ahead`), detectar si la estación a instanciar es `TransmutationStation`.
   - Si es la Forja, seleccionar el slot del centro del sol más cercano en lugar de una órbita planetaria.
   - Asegurar el orden de capas / z-index para que la forja y su indicador HUD sean claramente visibles sobre el núcleo solar.

### Criterios de Aceptación
- La Forja Cuántica aparece en el centro exacto de la estrella.
- El radar HUD apunta correctamente a la estrella cuando la forja está activa.
- Test verificado: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/test_chest_economy_suite.tscn"`.
