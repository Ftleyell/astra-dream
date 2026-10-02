class_name ExpBlob
extends Node2D

@export var exp_value: float = 15.0

var player: Player = null
var is_being_absorbed: bool = false
var is_collected: bool = false
var is_force_magnetized: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0
var merge_check_timer: float = 0.0

static func trigger_global_magnet(tree: SceneTree) -> void:
	if not tree:
		return
	for node in tree.get_nodes_in_group("exp_blobs"):
		if is_instance_valid(node) and node is ExpBlob:
			(node as ExpBlob).is_force_magnetized = true

static func batch_distant_blobs_if_needed(tree: SceneTree, player_pos: Vector2) -> void:
	if not tree:
		return
	var blobs := tree.get_nodes_in_group("exp_blobs")
	if blobs.size() <= 60:
		return

	# Compactar cristales lejanos (> 950 px del jugador) en un Mega-Cristal
	var distant_blobs: Array[ExpBlob] = []
	for b in blobs:
		var blob := b as ExpBlob
		if is_instance_valid(blob) and not blob.is_being_absorbed and not blob.is_collected:
			if blob.global_position.distance_squared_to(player_pos) > 950.0 * 950.0:
				distant_blobs.append(blob)

	if distant_blobs.size() >= 4:
		var target_blob := distant_blobs[0]
		for i in range(1, distant_blobs.size()):
			var src := distant_blobs[i]
			target_blob.exp_value += src.exp_value
			src.queue_free()
		target_blob._update_visuals()

const MERGE_RADIUS_SQ: float = 52.0 * 52.0
const PICKUP_RADIUS_SQ: float = 140.0 * 140.0
const COLLECT_RADIUS_SQ: float = 44.0 * 44.0

const TEX_TIER_1 := preload("res://assets/sprites/pickups/exp_crystal_tier1.png")
const TEX_TIER_2 := preload("res://assets/sprites/pickups/exp_crystal_tier2.png")
const TEX_TIER_3 := preload("res://assets/sprites/pickups/exp_crystal_tier3.png")
const TEX_TIER_4 := preload("res://assets/sprites/pickups/exp_crystal_tier4.png")

@onready var crystal_visual: Node2D = get_node_or_null("CrystalVisual")
@onready var crystal_sprite: Sprite2D = get_node_or_null("CrystalVisual/CrystalSprite")

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

func _process(_delta: float) -> void:
	# Animación de levitación y oscilación suave del cristal
	if crystal_visual and not is_being_absorbed and not is_collected:
		var time := Time.get_ticks_msec() * 0.004
		crystal_visual.position.y = sin(time) * 3.5
		crystal_visual.rotation = sin(time * 0.7) * 0.12

func _physics_process(delta: float) -> void:
	if is_being_absorbed or is_collected:
		return

	# Fricción del impulso inicial
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 160.0 * delta)
		global_position += velocity * delta

	# Cull de física si está muy lejos del jugador (> 1350 px)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	if is_instance_valid(player) and not is_force_magnetized:
		var dist_to_player_sq := global_position.distance_squared_to(player.global_position)
		if dist_to_player_sq > 1350.0 * 1350.0:
			return

	# 1. Comprobación periódica de fusión (merging) con otros blobs cercanos
	merge_check_timer -= delta
	if merge_check_timer <= 0.0:
		merge_check_timer = randf_range(0.15, 0.28)
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

	# Pulso de fusión del cristal receptor
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

	var p_radius: float = 100.0
	if is_instance_valid(player) and player.stats:
		p_radius = player.stats.get_stat(&"pickup_radius")
	var effective_radius := p_radius * 1.4
	var effective_pickup_sq := effective_radius * effective_radius
	if player.is_dashing:
		effective_pickup_sq *= 2.2

	if is_force_magnetized or dist_sq <= effective_pickup_sq:
		var dir := to_player.normalized()
		var target_speed := 1200.0 if is_force_magnetized else 750.0
		var accel := 3200.0 if is_force_magnetized else 1900.0
		magnet_speed = move_toward(magnet_speed, target_speed, accel * delta)
		global_position += dir * magnet_speed * delta

		if dist_sq <= COLLECT_RADIUS_SQ:
			_collect()

func _collect() -> void:
	is_collected = true
	if is_instance_valid(player):
		player.add_exp(exp_value)

	# Sonido SFX de cristal recogido
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("exp", randf_range(0.95, 1.15))

	# Animación de absorción en el jugador
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.06)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _get_target_scale() -> Vector2:
	if exp_value < 45.0:
		return Vector2(2.0, 2.0)
	elif exp_value < 150.0:
		return Vector2(2.7, 2.7)
	elif exp_value < 450.0:
		return Vector2(3.5, 3.5)
	else:
		return Vector2(4.5, 4.5)

func _update_visuals() -> void:
	scale = _get_target_scale()

	if not crystal_sprite:
		return

	if exp_value < 45.0:
		crystal_sprite.texture = TEX_TIER_1
	elif exp_value < 150.0:
		crystal_sprite.texture = TEX_TIER_2
	elif exp_value < 450.0:
		crystal_sprite.texture = TEX_TIER_3
	else:
		crystal_sprite.texture = TEX_TIER_4
