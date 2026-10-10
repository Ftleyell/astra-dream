class_name CosmosRoot
extends Node2D

## Escena Raíz y Orquestador de Cosmos Engine.
## Unifica los 6 estratos cósmicos analíticos y Parallax2D en Godot 4:
## 1. ParallaxNebulaDeep: Shader universe_nebula.gdshader en CanvasLayer de fondo o Parallax ultralento.
## 2. ParallaxMacroGalaxies: GalaxyStreamer2D en capa de muy bajo factor (0.02).
## 3. ParallaxStarfield8K: Textura estelar 8K anti-tiling / espacio profundo en Parallax intermedio-bajo (0.05).
## 4. ParallaxSolarSystems: SolarSystemStreamer en estrato astronómico medio (0.20).
## 5. ParallaxDebrisBelt: DebrisStreamer2D con MultiMesh en GPU (0.50).
## 6. GameplayWorld: Entidades de combate/exploración interactiva (1.00).
##
## Administra el tiempo global cósmico (global_time) y sincroniza prioridades
## de proceso con FloatingOriginTracker para garantizar cero micro-saltos.

signal origin_shifted(shift_vector: Vector2)

@export var camera: Camera2D
@export var player_target: Node2D
@export var floating_origin_tracker: FloatingOriginTracker
@export var time_scale: float = 1.0

# Referencias a Estratos Cósmicos
@export_group("Estratos Cósmicos")
@export var nebula_controller: NebulaBackdropController
@export var parallax_macro_galaxies: Parallax2D
@export var galaxy_streamer: GalaxyStreamer2D
@export var parallax_starfield_8k: Parallax2D
@export var parallax_solar_systems: Parallax2D
@export var solar_streamer: SolarSystemStreamer
@export var parallax_debris_belt: Parallax2D
@export var debris_streamer: DebrisStreamer2D
@export var gameplay_world: Node2D

var _global_time: float = 0.0
var _origin_shift_count: int = 0
var _accumulated_shift: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Prioridad de proceso: CosmosRoot orquesta el tiempo y el tracker se procesa antes del render
	process_priority = -100
	_setup_floating_origin()
	_bind_camera_to_streamers()

func _setup_floating_origin() -> void:
	if floating_origin_tracker == null:
		floating_origin_tracker = get_node_or_null("FloatingOriginTracker") as FloatingOriginTracker
	
	if floating_origin_tracker != null:
		# Establecer prioridad de proceso del tracker previa a los renders
		floating_origin_tracker.process_priority = -50
		if not floating_origin_tracker.origin_shifted.is_connected(_on_floating_origin_shifted):
			floating_origin_tracker.origin_shifted.connect(_on_floating_origin_shifted)
		
		# Registrar capas de paralaje si no están asignadas
		if floating_origin_tracker.parallax_layers.is_empty():
			var layers: Array[Parallax2D] = []
			if parallax_macro_galaxies != null:
				layers.append(parallax_macro_galaxies)
			if parallax_starfield_8k != null:
				layers.append(parallax_starfield_8k)
			if parallax_solar_systems != null:
				layers.append(parallax_solar_systems)
			if parallax_debris_belt != null:
				layers.append(parallax_debris_belt)
			floating_origin_tracker.parallax_layers = layers

func _bind_camera_to_streamers() -> void:
	if camera == null:
		return
	if galaxy_streamer != null and galaxy_streamer.camera == null:
		galaxy_streamer.camera = camera
	if solar_streamer != null and solar_streamer.camera == null:
		solar_streamer.camera = camera
	if debris_streamer != null and debris_streamer.camera == null:
		debris_streamer.camera = camera
	if nebula_controller != null and nebula_controller.camera == null:
		nebula_controller.camera = camera

func _process(delta: float) -> void:
	var delta_time: float = delta * time_scale
	_global_time += delta_time

	# Actualizar tiempo en controladores que dependen de tiempo global continuo
	if nebula_controller != null and is_instance_valid(nebula_controller):
		var mat: ShaderMaterial = nebula_controller.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("global_time", _global_time)

func _on_floating_origin_shifted(shift: Vector2) -> void:
	_origin_shift_count += 1
	_accumulated_shift += shift
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.accumulated_origin_shift = _accumulated_shift
	origin_shifted.emit(shift)

## Devuelve el tiempo cósmico universal transcurrido.
func get_global_time() -> float:
	return _global_time

## Devuelve el conteo de recentrados efectuados.
func get_origin_shift_count() -> int:
	return _origin_shift_count

## Devuelve la suma vectorial acumulada de los recentrados.
func get_accumulated_shift() -> Vector2:
	return _accumulated_shift

## Devuelve la posición absoluta no recentrada en el cosmos continuo.
func get_absolute_position(local_pos: Vector2) -> Vector2:
	return local_pos + _accumulated_shift
