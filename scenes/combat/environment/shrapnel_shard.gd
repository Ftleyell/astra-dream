class_name ShrapnelShard
extends Node2D

## ShrapnelShard.gd
## Esquirla balística cinemática reactiva emitida al fracturarse objetos espaciales (Vector 3).
## Inflige daño determinista D = max(15, tier * 20), busca enemigos cercanos con leve homing
## y aplica retroceso cinemático (knockback) para liberar espacio de maniobra y kiting.

@export var speed: float = 680.0
@export var damage: float = 20.0
@export var tier: int = 1
@export var lifetime: float = 1.3
@export var knockback_force: float = 340.0
@export var contact_radius: float = 18.0
@export var shard_color: Color = Color(0.85, 0.9, 1.0, 1.0)

var velocity: Vector2 = Vector2.ZERO
var current_age: float = 0.0
var target_enemy: Node2D = null
var is_spent: bool = false

@onready var visual_polygon: Polygon2D = get_node_or_null("VisualPolygon")
@onready var trail_line: Line2D = get_node_or_null("TrailLine")

const SHARD_SCENE_PATH: String = "res://scenes/combat/environment/shrapnel_shard.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("shrapnel_shards")
	_apply_visuals()


func setup(p_pos: Vector2, p_vel: Vector2, p_tier: int, p_color: Color = Color(0.9, 0.95, 1.0)) -> void:
	global_position = p_pos
	velocity = p_vel
	tier = p_tier
	damage = maxf(15.0, float(tier) * 20.0)
	shard_color = p_color
	speed = p_vel.length()
	if speed < 100.0:
		speed = 680.0
	rotation = velocity.angle()
	_apply_visuals()


func _apply_visuals() -> void:
	if visual_polygon:
		visual_polygon.color = shard_color
	if trail_line:
		trail_line.default_color = Color(shard_color.r, shard_color.g, shard_color.b, 0.5)


func _physics_process(delta: float) -> void:
	if is_spent:
		return

	current_age += delta
	if current_age >= lifetime:
		queue_free()
		return

	# Homing sutil hacia el enemigo más próximo
	_update_homing(delta)

	# Movimiento cinemático directo
	rotation = velocity.angle()
	global_position += velocity * delta

	# Detección de colisión con enemigos
	_check_enemy_collisions()


func _update_homing(delta: float) -> void:
	if not is_instance_valid(target_enemy) or (target_enemy.has_method("is_dead") and target_enemy.is_dead()):
		target_enemy = _find_nearest_enemy(550.0)

	if is_instance_valid(target_enemy):
		var to_enemy := (target_enemy.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_enemy * speed, speed * 2.2 * delta)


func _find_nearest_enemy(max_dist: float) -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var enemies := tree.get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist_sq := max_dist * max_dist
	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var dist_sq := global_position.distance_squared_to((node as Node2D).global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			nearest = node as Node2D
	return nearest


func _check_enemy_collisions() -> void:
	var tree := get_tree()
	if not tree:
		return

	var enemies := tree.get_nodes_in_group("enemies")
	var hit_radius_sq := contact_radius * contact_radius

	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy := node as Node2D
		if global_position.distance_squared_to(enemy.global_position) <= hit_radius_sq:
			_hit_enemy(enemy)
			break


func _hit_enemy(enemy: Node2D) -> void:
	if is_spent:
		return
	is_spent = true

	# 1. Aplicación de daño determinista
	if enemy.has_method("take_damage"):
		var ctx := HitContext.new()
		ctx.raw_damage = damage
		ctx.final_damage = damage
		ctx.hit_position = global_position
		enemy.take_damage(ctx)

	# 2. Impulso cinemático de retroceso (Knockback)
	var push_dir := velocity.normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.RIGHT.rotated(rotation)

	if "velocity" in enemy:
		enemy.velocity += push_dir * knockback_force
	enemy.global_position += push_dir * 18.0

	# 3. SFX y desvanecimiento
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("hit_bullet", randf_range(1.1, 1.3))

	_play_impact_spark()


func _play_impact_spark() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.5, 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.chain().tween_callback(queue_free)


## Método canónico estático para emitir la onda de metralla e impulso de retroceso
static func spawn_shattered_burst(container: Node, pos: Vector2, p_tier: int, count: int = -1, p_color: Color = Color(0.85, 0.9, 1.0)) -> Array:
	var spawned: Array = []
	if not container or not container.is_inside_tree():
		return spawned

	var num_shards: int = count if count > 0 else randi_range(4, 8)
	var base_force: float = 280.0 + float(p_tier) * 40.0
	var wave_radius_sq: float = 190.0 * 190.0

	# 1. Onda de choque expansiva reactiva para desatascar enemigos en kiting
	var tree := container.get_tree()
	if tree:
		for node in tree.get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var enemy := node as Node2D
			var offset := enemy.global_position - pos
			var d_sq := offset.length_squared()
			if d_sq <= wave_radius_sq and d_sq > 0.01:
				var push_dir := offset.normalized()
				if "velocity" in enemy:
					enemy.velocity += push_dir * base_force
				enemy.global_position += push_dir * 22.0

	# 2. Generación de las esquirlas cinemáticas
	var shard_packed: PackedScene = load(SHARD_SCENE_PATH) as PackedScene
	if not shard_packed:
		return spawned

	var parent_target: Node = container
	if container is DestructibleSpaceObject or container is PlanetSegment:
		parent_target = container.get_parent() if container.get_parent() else tree.current_scene

	for i in range(num_shards):
		var shard := shard_packed.instantiate() as ShrapnelShard
		if not shard:
			continue

		var angle := (TAU / float(num_shards)) * float(i) + randf_range(-0.35, 0.35)
		var spd := randf_range(560.0, 780.0)
		var vel := Vector2(cos(angle), sin(angle)) * spd

		shard.setup(pos, vel, p_tier, p_color)
		parent_target.call_deferred("add_child", shard)
		spawned.append(shard)

	return spawned
