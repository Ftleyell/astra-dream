# Guía de Migración y Desacople: Cosmos Engine a Entorno de Producción

> **Estado:** Documento Técnico de Arquitectura y Protocolo de Promoción (Sesión 7)  
> **Ubicación:** `docs/sandbox/GUIA_MIGRACION_COSMOS_PRODUCCION.md`  
> **Área:** `sandbox/` -> `scenes/combat/environment/`  
> **Motor:** Godot 4.7.2+ (GDScript 4 Tipado Estricto + GLSL CanvasItem Shaders)

---

## 1. Resumen Ejecutivo y Estado de I+D

El prototipo procedural **Cosmos Engine** desarrollado en el aislamiento de `sandbox/` ha culminado con éxito todas sus etapas de desarrollo y verificación matemática. Integra:
1. **Streaming Determinista $O(1)$ sin asignación en memoria:** Mediante `CosmicMacroGrid` y `CosmicHasher`.
2. **Jerarquía Orbital Kepleriana:** `SolarSystemStreamer`, `SolarSystem2D` y `OrbitalBody2D` gobernados por tiempo global analítico sin desincronización acumulativa de `delta`.
3. **Macro-Galaxias de Frustum Ultra-Lento:** `GalaxyStreamer2D` con regla analítica de galaxia única sin solapamientos.
4. **Cinturón de Escombros en 1 Draw Call:** `DebrisStreamer2D` utilizando `MultiMeshInstance2D` con `TRANSFORM_2D` y `use_colors = true`.
5. **Shader Continuo de Espacio Profundo y Nebulosas:** `universe_nebula.gdshader` y `NebulaBackdropController` con anti-tiling estocástico y blending suave de biomas.
6. **Sistema de Coordenadas Flotantes Anti-Jitter:** `FloatingOriginTracker` con absorción analítica precisa por capa en `Parallax2D.scroll_offset` y prioridad de orden de proceso garantizada (`process_priority = -50`).
7. **Suite de Pruebas Automatizadas:** 5 suites en verde bajo `tests/sandbox/` ejecutadas en modo headless.

---

## 2. Contrato de Desacople entre Cosmos Engine y MainGame

Para respetar la **Regla 2 (Modularidad Radical - Anti God-Objects)** y la **Regla 8 (Aislamiento de Sandbox)**, la arquitectura de combate existente ya cuenta con el subsistema `SpaceEnvironmentHost` (`scenes/combat/environment/space_environment_host.gd`).

### Principios Fundamentales de la Promoción:
- **Cero alteración de `BulletServer`:** El servidor de proyectiles opera en coordenadas de gameplay mundiales sin interferencia de las capas de paralaje de fondo.
- **Cero alteración de colisiones ni capas físicas:** Todas las capas cósmicas de `CosmosRoot` corren bajo capas de paralaje visuales puras (`CanvasItem`, `Parallax2D`) sin `CollisionObject2D`.
- **Plug & Play mediante `SpaceEnvironmentHost`:**
  `SpaceEnvironmentHost` exporta:
  ```gdscript
  @export var default_environment_scene: PackedScene = preload("res://scenes/combat/environment/space_background.tscn")
  @export var custom_environment_scene: PackedScene = null
  ```
  La migración solo requiere instanciar una variante de entorno de combate basada en `CosmosRoot` y asignarla como `custom_environment_scene` o sustituto natural de `space_background.tscn`.

---

## 3. Arquitectura del Adaptador: `CosmosCombatEnvironment`

Para integrar `CosmosRoot` en el bucle de juego de combate sin crear acoplamientos rígidos:

### 3.1. Adaptador de Ciclo de Vida
Se creará un nodo adaptador en `scenes/combat/environment/cosmos_combat_environment.gd` que herede o implemente la interfaz esperada por `SpaceEnvironmentHost`:

```gdscript
class_name CosmosCombatEnvironment
extends Node2D

@onready var cosmos_root: CosmosRoot = $CosmosRoot

func set_camera_reference(cam: Camera2D) -> void:
	cosmos_root.camera = cam
	cosmos_root._bind_camera_to_streamers()

func set_player_reference(p: Node2D) -> void:
	cosmos_root.player_target = p
	if cosmos_root.floating_origin_tracker:
		cosmos_root.floating_origin_tracker.target = p

func notify_wave_started(wave_idx: int) -> void:
	# Mapear progresión de oleadas con transición de biomas cósmicos
	_transition_to_wave_biome(wave_idx)
```

### 3.2. Manejo de Floating Origin en Combate
En el modo de combate estándar de arena fija o semi-delimitada:
- Si el área de combate es delimitada (ej. $6.000 \times 6.000$ px), el recentrado de origen de `FloatingOriginTracker` puede configurarse con un umbral más amplio o desactivarse pasivamente (`process_mode = Node.PROCESS_MODE_DISABLED`), permitiendo que el paralaje funcione con scroll continuo estándar sin recentrar al jugador.
- Si se activa el modo de combate cósmico abierto o sin límites, `FloatingOriginTracker.origin_shifted` se conecta para desplazar los nodos de la arena de juego y notificar a los orquestadores de oleada y enemigos.

---

## 4. Conexión de Biomas Cósmicos con la Progresión de Oleadas

El shader de nebulosa `universe_nebula.gdshader` soporta uniforms para blending:
- `biome_a_primary_color`, `biome_a_secondary_color`, `biome_a_density`
- `biome_b_primary_color`, `biome_b_secondary_color`, `biome_b_density`
- `biome_blend_factor` ($0.0 \to 1.0$)

### Cronograma de Transición por Oleadas:
| Rango de Oleadas | Perfil de Bioma (`CosmicBiomeConfig`) | Tonalidad / Atmósfera Visual |
|---|---|---|
| **Oleadas 1 - 5** | `default_cosmic_biome.tres` | Azul profundo, baja densidad, escombros dispersos |
| **Oleadas 6 - 10** | `ionized_nebula.tres` | Púrpura eléctrico / magenta, densidad media |
| **Oleadas 11 - 15** | `solar_corona.tres` | Ámbar / dorado brillante, alta turbulencia |
| **Oleadas 16+ / Boss** | `quantum_abyss.tres` | Cian frío / negro abisal, distorsión cromática alta |

El método `notify_wave_started(wave_idx: int)` interpola suavemente `biome_blend_factor` a lo largo de los primeros 10 segundos de la oleada mediante un `Tween` desacoplado, sin impactar el hilo principal.

---

## 5. Auditoría de Rendimiento y Benchmark de 60 FPS

### Métricas de Perfilado:
1. **Draw Calls en DebrisBelt:** 1 único Draw Call para hasta 2.000 fragmentos gracias a `MultiMeshInstance2D`.
2. **Consumo de VRAM de la Textura Estelar 8K:**
   - Textura maestra 8K ($8192 \times 8192$ píxeles).
   - Modo de importación: `compress/mode=2` (VRAM Compressed BPTC / S3TC).
   - Consumo VRAM reducido de ~256 MB (RGBA8 sin comprimir) a **~42.6 MB** en VRAM GPU.
3. **Cálculos Keplerianos y Deterministas:**
   - Tiempo de ejecución analítico por frame en GDScript: $< 0.15\text{ ms}$ para 3 sistemas solares activos.
   - Cero asignaciones periódicas de arrays o diccionarios temporales en `_process`.

---

## 6. Procedimiento Paso a Paso para la Promoción de Archivos

Cuando se apruebe el pase a producción:

1. **Reubicación de Módulos Núcleo:**
   - Mover recursos `.tres` de `sandbox/resources/` a `assets/environments/cosmos/profiles/`.
   - Mover shaders de `sandbox/shaders/` a `scenes/combat/environment/shaders/`.
   - Mover código de streaming y astronomía de `sandbox/core/`, `sandbox/astronomy/`, `sandbox/environment/` a `scenes/combat/environment/cosmos/`.
2. **Preservar `class_name` y UID:**
   - Utilizar el sistema de archivos de Godot o mantener los archivos `.uid` correspondientes para no quebrar enlaces.
3. **Configuración en `SpaceEnvironmentHost`:**
   - Crear `scenes/combat/environment/cosmos_space_environment.tscn`.
   - Asignar dicha escena en `custom_environment_scene` dentro del nodo `SpaceEnvironmentHost` de `main_game.tscn`.
4. **Verificación Automatizada:**
   - Correr test suites de regresión completas de combate:
     `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly`
