class_name SandevistanFlightVFX
extends Node2D

## sandevistan_flight_vfx.gd
## Orquestador cinemático y gestor de imágenes residuales (Afterimages) estilo Cyberpunk Sandevistan.
## Implementa Node Pooling estático (Zero-Allocation) para garantizar 60+ FPS sin recolección de basura.

const POOL_CAPACITY: int = 20

@export var source_sprite: Sprite2D
@export var base_shader: Shader = preload("res://shaders/exo_pilot_flight.gdshader")
@export var noise_texture: Texture2D = preload("res://shaders/flame_noise.tres")

@export_category("Cinemática Sandevistan")
@export var cruise_distance_step: float = 34.0
@export var dash_distance_step: float = 16.0
@export var min_speed_threshold: float = 180.0
@export var ghost_lifetime: float = 0.32

var _pool: Array[Sprite2D] = []
var _tweens: Array[Tween] = []
var _pool_index: int = 0
var _last_spawn_pos: Vector2 = Vector2.ZERO
var _primary_color: Color = Color(0.2, 0.75, 1.0, 1.0)
var _secondary_color: Color = Color(1.0, 0.85, 0.4, 1.0)
var _is_initialized: bool = false


func _ready() -> void:
	_init_pool()
	_last_spawn_pos = global_position


func configure_colors(p_color: Color, s_color: Color) -> void:
	_primary_color = p_color
	_secondary_color = s_color
	for spr in _pool:
		if spr and spr.material is ShaderMaterial:
			var mat := spr.material as ShaderMaterial
			mat.set_shader_parameter("primary_color", _primary_color)
			mat.set_shader_parameter("secondary_color", _secondary_color)


func _init_pool() -> void:
	if _is_initialized:
		return
	_is_initialized = true

	for i in range(POOL_CAPACITY):
		var ghost := Sprite2D.new()
		ghost.name = "SandevistanGhost_%d" % i
		ghost.top_level = true # Desacopla la posición del movimiento del jugador
		ghost.visible = false
		ghost.z_index = 0 # Justo debajo de la nave de la piloto
		ghost.z_as_relative = false

		var mat := ShaderMaterial.new()
		mat.shader = base_shader
		mat.set_shader_parameter("margin_expansion", 18.0)
		mat.set_shader_parameter("flame_thickness", 14.0)
		mat.set_shader_parameter("flame_speed", 6.0)
		mat.set_shader_parameter("primary_color", _primary_color)
		mat.set_shader_parameter("secondary_color", _secondary_color)
		mat.set_shader_parameter("hdr_energy_multiplier", 2.2)
		mat.set_shader_parameter("silhouette_solidarity", 0.75) # Silueta estilizada neón
		if noise_texture:
			mat.set_shader_parameter("noise_texture", noise_texture)

		ghost.material = mat
		add_child(ghost)
		_pool.append(ghost)
		_tweens.append(null)


func update_flight(delta: float, current_velocity: Vector2, is_dashing: bool) -> void:
	if not source_sprite or not source_sprite.visible or not source_sprite.texture:
		return

	var speed: float = current_velocity.length()
	if not is_dashing and speed < min_speed_threshold:
		_last_spawn_pos = global_position
		return

	var step: float = dash_distance_step if is_dashing else cruise_distance_step
	var dist: float = global_position.distance_to(_last_spawn_pos)

	if dist >= step:
		var total_steps: int = mini(int(dist / step), 4) # Limitar a máx 4 clones por frame
		for i in range(total_steps):
			var weight: float = float(i + 1) / float(total_steps)
			var interp_pos: Vector2 = _last_spawn_pos.lerp(global_position, weight)
			_spawn_ghost(interp_pos, is_dashing)
		_last_spawn_pos = global_position


func _spawn_ghost(spawn_pos: Vector2, is_dashing: bool) -> void:
	if _pool.is_empty():
		return

	var ghost := _pool[_pool_index]
	var tw: Tween = _tweens[_pool_index]

	# Matar tween previo si aún estaba activo en este nodo
	if tw and tw.is_valid():
		tw.kill()

	ghost.texture = source_sprite.texture
	ghost.global_position = spawn_pos
	ghost.global_rotation = source_sprite.global_rotation
	ghost.global_scale = source_sprite.global_scale
	ghost.modulate.a = 0.85 if is_dashing else 0.55
	ghost.visible = true

	var mat := ghost.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("silhouette_solidarity", 0.85 if is_dashing else 0.45)
		mat.set_shader_parameter("thrust_intensity", 2.0 if is_dashing else 1.0)
		mat.set_shader_parameter("flame_thickness", 16.0 if is_dashing else 10.0)

	var new_tw := create_tween().set_parallel(true)
	new_tw.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mat:
		new_tw.tween_method(
			func(val: float) -> void: mat.set_shader_parameter("flame_thickness", val),
			16.0 if is_dashing else 10.0,
			0.0,
			ghost_lifetime
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	new_tw.chain().tween_callback(func() -> void:
		ghost.visible = false
	)
	_tweens[_pool_index] = new_tw

	_pool_index = (_pool_index + 1) % POOL_CAPACITY
