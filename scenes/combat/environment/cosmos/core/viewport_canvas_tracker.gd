class_name CosmosViewportCanvasTracker
extends Node

## Sincronizador agnóstico de cámara y viewport para Cosmos Engine.
## Extrae la posición efectiva del centro del viewport, zoom y rotación a partir
## del CanvasTransform actual (`get_viewport().get_canvas_transform()`),
## desacoplando por completo el seguimiento cósmico de cualquier nodo de cámara o jugador específico.
## Es 100% compatible con cinemáticas, AnimationPlayer, transiciones y cámaras virtuales.

signal viewport_updated(center_world_pos: Vector2, zoom: Vector2, rotation_rad: float)

@export var enabled: bool = true
## Umbral de velocidad o salto para interpolar/suavizar en caso de paneos ultra-rápidos de cinemáticas
@export var smooth_cinematic_jumps: bool = true
@export var max_position_delta_per_frame: float = 20000.0

var current_center: Vector2 = Vector2.ZERO
var current_zoom: Vector2 = Vector2.ONE
var current_rotation: float = 0.0

var _last_valid_center: Vector2 = Vector2.ZERO
var _has_first_sample: bool = false

func _ready() -> void:
	# Prioridad de proceso temprana para proveer las coordenadas antes de que los streamers procesen celdas
	process_priority = -90
	sample_viewport()

func _process(_delta: float) -> void:
	if not enabled:
		return
	sample_viewport()

## Realiza una lectura analítica inmediata del canvas transform del Viewport.
func sample_viewport() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var xform: Transform2D = vp.get_canvas_transform()
	var vp_size: Vector2 = Vector2(vp.get_visible_rect().size)
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1920.0, 1080.0)

	# El canvas transform mapea coordenadas del mundo a coordenadas de pantalla:
	# screen_pos = xform * world_pos
	# Por lo tanto, world_pos = xform.affine_inverse() * screen_pos
	var inv_xform: Transform2D = xform.affine_inverse()
	var center_screen: Vector2 = vp_size * 0.5
	var raw_world_center: Vector2 = inv_xform * center_screen

	# Extraer zoom (escala efectiva del canvas transform)
	var sx: float = xform.x.length()
	var sy: float = xform.y.length()
	var extracted_zoom: Vector2 = Vector2(
		sx if sx > 0.0001 else 1.0,
		sy if sy > 0.0001 else 1.0
	)

	# Extraer rotación del canvas transform
	var extracted_rot: float = -xform.get_rotation()

	var final_center: Vector2 = raw_world_center
	if _has_first_sample and smooth_cinematic_jumps and max_position_delta_per_frame > 0.0:
		var delta_pos: Vector2 = raw_world_center - _last_valid_center
		var dist: float = delta_pos.length()
		if dist > max_position_delta_per_frame:
			# Limitar el salto extremo en un único frame para evitar spikes en streaming
			final_center = _last_valid_center + delta_pos.normalized() * max_position_delta_per_frame

	current_center = final_center
	current_zoom = extracted_zoom
	current_rotation = extracted_rot
	_last_valid_center = current_center
	_has_first_sample = true

	viewport_updated.emit(current_center, current_zoom, current_rotation)

## Forzar actualización o reseteo de posición (útil al teletransportar o cortar cinemáticas).
func force_teleport(new_center: Vector2) -> void:
	current_center = new_center
	_last_valid_center = new_center
	_has_first_sample = true
	viewport_updated.emit(current_center, current_zoom, current_rotation)
