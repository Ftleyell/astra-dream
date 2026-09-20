class_name ExpBlob
extends Node2D

@export var exp_value: float = 15.0

var player: Player = null
var is_being_absorbed: bool = false
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0
var merge_check_timer: float = 0.0

const MERGE_RADIUS_SQ: float = 52.0 * 52.0
const PICKUP_RADIUS_SQ: float = 140.0 * 140.0
const COLLECT_RADIUS_SQ: float = 22.0 * 22.0

@onready var visual_core: Polygon2D = $VisualCore
@onready var visual_outer: Polygon2D = $VisualOuter

func _ready() -> void:
	add_to_group("exp_blobs")
	_update_visuals()
	# Pequeño impulso inicial de dispersión
	var angle := randf() * TAU
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(30.0, 80.0)

func setup(p_exp: float, p_pos: Vector2) -> void:
	exp_value = p_exp
	global_position = p_pos
	if is_inside_tree():
		_update_visuals()

func _physics_process(delta: float) -> void:
	if is_being_absorbed or is_collected:
		return

	# Fricción del impulso inicial
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 160.0 * delta)
		global_position += velocity * delta

	# 1. Comprobación periódica de fusión (merging) con otros blobs cercanos
	merge_check_timer -= delta
	if merge_check_timer <= 0.0:
		merge_check_timer = randf_range(0.12, 0.22)
		_check_merging()

	# 2. Atracción magnética hacia el jugador
	_handle_player_magnet(delta)

func _check_merging() -> void:
	var blobs := get_tree().get_nodes_in_group("exp_blobs")
	for node in blobs:
		if node == self or not is_instance_valid(node):
			continue
		var other := node as ExpBlob
		if not other or other.is_being_absorbed or other.is_collected:
			continue

		var dist_sq := global_position.distance_squared_to(other.global_position)
		if dist_sq <= MERGE_RADIUS_SQ:
			# Para evitar doble fusión simultánea: el que tiene mayor ID absorbe al menor
			if get_instance_id() > other.get_instance_id():
				absorb_blob(other)
				break

func absorb_blob(other: ExpBlob) -> void:
	other.is_being_absorbed = true
	var added_exp: float = other.exp_value

	# Animación de succión del otro blob hacia nosotros
	var tween := other.create_tween()
	tween.tween_property(other, "global_position", global_position, 0.1)
	tween.parallel().tween_property(other, "scale", Vector2(0.2, 0.2), 0.1)
	tween.tween_callback(other.queue_free)

	exp_value += added_exp
	_update_visuals()

	# Pulso de fusión del blob receptor
	var pulse := create_tween()
	pulse.tween_property(self, "scale", scale * 1.35, 0.08)
	pulse.tween_property(self, "scale", _get_target_scale(), 0.12)

func _handle_player_magnet(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var to_player := player.global_position - global_position
	var dist_sq := to_player.length_squared()

	# Aumento de rango si el jugador hace dash
	var effective_pickup_sq := PICKUP_RADIUS_SQ
	if player.is_dashing:
		effective_pickup_sq *= 2.2

	if dist_sq <= effective_pickup_sq:
		var dir := to_player.normalized()
		magnet_speed = move_toward(magnet_speed, 750.0, 1900.0 * delta)
		global_position += dir * magnet_speed * delta

		if dist_sq <= COLLECT_RADIUS_SQ:
			_collect()

func _collect() -> void:
	is_collected = true
	if is_instance_valid(player):
		player.add_exp(exp_value)

	# Animación de absorción en el jugador
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.06)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _get_target_scale() -> Vector2:
	if exp_value < 45.0:
		return Vector2(1.0, 1.0)
	elif exp_value < 150.0:
		return Vector2(1.35, 1.35)
	elif exp_value < 450.0:
		return Vector2(1.75, 1.75)
	else:
		return Vector2(2.25, 2.25)

func _update_visuals() -> void:
	if not visual_core or not visual_outer:
		return

	scale = _get_target_scale()

	if exp_value < 45.0:
		# Tier 1: Cian eléctrico
		visual_core.color = Color(1.0, 1.0, 1.0, 1.0)
		visual_outer.color = Color(0.2, 0.9, 1.0, 0.8)
	elif exp_value < 150.0:
		# Tier 2: Amatista / Magenta radiante
		visual_core.color = Color(1.0, 0.85, 1.0, 1.0)
		visual_outer.color = Color(0.85, 0.3, 1.0, 0.85)
	elif exp_value < 450.0:
		# Tier 3: Oro solar
		visual_core.color = Color(1.0, 1.0, 0.9, 1.0)
		visual_outer.color = Color(1.0, 0.85, 0.2, 0.9)
	else:
		# Tier 4: Supernova carmesí
		visual_core.color = Color(1.0, 0.95, 0.95, 1.0)
		visual_outer.color = Color(1.0, 0.25, 0.45, 0.95)
