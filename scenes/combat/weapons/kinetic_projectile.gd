class_name KineticProjectile
extends Node2D

const KineticImpactSparkVFXScript = preload("res://scenes/combat/weapons/kinetic_impact_vfx.gd")
var spark_scene: PackedScene = preload("res://scenes/combat/weapons/kinetic_impact_vfx.tscn")

@export var speed: float = 850.0
@export var lifetime: float = 2.5
@export var bounces_max: int = 0
@export var pierces_max: int = 1
@export var radius: float = 6.0
@export var is_boomerang: bool = false
@export var return_to_player: bool = false

var hit_context: HitContext
var velocity: Vector2 = Vector2.ZERO
var bounces_left: int = 0
var pierces_left: int = 1
var player: Node2D = null
var current_age: float = 0.0
var has_started_return: bool = false
var hit_targets: Array[Node2D] = []

@onready var trail_line: Line2D = get_node_or_null("TrailLine")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
var trail_positions: Array[Vector2] = []
const MAX_TRAIL_PTS: int = 14

var spark_color: Color = Color(0.3, 0.92, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_projectiles")

	if trail_line:
		var trail_tex := load("res://assets/sprites/effects/beam_trail_gradient.png") as Texture2D
		if trail_tex:
			trail_line.texture = trail_tex
			trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		trail_line.begin_cap_mode = Line2D.LINE_CAP_NONE
		trail_line.end_cap_mode = Line2D.LINE_CAP_NONE
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))    # Cabeza ancha en el proyectil
		curve.add_point(Vector2(0.18, 0.85))
		curve.add_point(Vector2(0.45, 0.45))
		curve.add_point(Vector2(0.75, 0.12))
		curve.add_point(Vector2(1.0, 0.0))    # Punta cónica de aguja afilada
		trail_line.width_curve = curve
		trail_line.width = 9.0 * scale.x

	if is_boomerang:
		var blade_tex := load("res://assets/sprites/weapons/projectile_crescent_blade.png") as Texture2D
		if blade_tex and sprite:
			sprite.texture = blade_tex
			sprite.scale = Vector2(0.55, 0.55)
		spark_color = Color(0.95, 0.28, 1.0)
		if trail_line:
			trail_line.default_color = Color(0.95, 0.28, 1.0, 0.9)
	elif pierces_max > 1 or speed >= 1000.0:
		# Francotirador iónico de Valentina
		var needle_tex := load("res://assets/sprites/weapons/projectile_ion_needle.png") as Texture2D
		if needle_tex and sprite:
			sprite.texture = needle_tex
			sprite.scale = Vector2(0.38, 0.38)
		spark_color = Color(0.3, 0.92, 1.0)
		if trail_line:
			trail_line.default_color = Color(0.3, 0.92, 1.0, 0.9)
	else:
		# Perdigón de escopeta / cinética de Roxy
		var slug_tex := load("res://assets/sprites/weapons/projectile_kinetic_slug.png") as Texture2D
		if slug_tex and sprite:
			sprite.texture = slug_tex
			sprite.scale = Vector2(0.32, 0.32)
		spark_color = Color(1.0, 0.65, 0.15)
		if trail_line:
			trail_line.default_color = Color(1.0, 0.65, 0.15, 0.9)

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_player: Node2D = null, p_speed_mult: float = 1.0, p_size_mult: float = 1.0) -> void:
	global_position = p_origin
	var dir := p_dir.normalized() if p_dir.length_squared() > 0.001 else Vector2.RIGHT
	velocity = dir * (speed * p_speed_mult)
	rotation = velocity.angle()
	hit_context = p_ctx
	player = p_player
	bounces_left = bounces_max
	pierces_left = pierces_max
	if p_size_mult != 1.0:
		scale = Vector2(p_size_mult, p_size_mult)
		radius *= p_size_mult
	add_to_group("player_projectiles")

func _process(delta: float) -> void:
	current_age += delta
	if current_age >= lifetime:
		queue_free()
		return

	if is_boomerang:
		if current_age >= lifetime * 0.4 and not has_started_return:
			has_started_return = true
		if has_started_return and is_instance_valid(player):
			var to_player := (player.global_position - global_position).normalized()
			velocity = velocity.move_toward(to_player * speed, speed * 2.5 * delta)
			rotation += 18.0 * delta
		else:
			rotation += 14.0 * delta
	else:
		rotation = velocity.angle()

	global_position += velocity * delta

	# Actualizar estela visual TrailLine
	if trail_line:
		trail_positions.push_front(global_position)
		if trail_positions.size() > MAX_TRAIL_PTS:
			trail_positions.pop_back()
		trail_line.clear_points()
		for p in trail_positions:
			trail_line.add_point(to_local(p))

	# Comprobación de impactos contra enemigos y destructibles
	_check_collisions()

func _check_collisions() -> void:
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return

	var r_sq := radius * radius
	var tree := get_tree()
	if not tree:
		return

	var potential_targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles") + tree.get_nodes_in_group("emitters")
	for node in potential_targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if target in hit_targets:
			continue
		if target.get("is_dead") or target.get("is_dying"):
			continue

		var is_hit := false
		if target is PlanetSector:
			var sec := target as PlanetSector
			if sec.is_dead or sec.is_dying:
				continue
			var local_p := sec.to_local(global_position)
			if sec.collision_poly and not sec.collision_poly.disabled:
				is_hit = Geometry2D.is_point_in_polygon(local_p, sec.collision_poly.polygon)

		if not is_hit:
			var t_radius: float = target.get("obstacle_radius") if "obstacle_radius" in target else 24.0
			var hit_r := radius + t_radius
			if global_position.distance_squared_to(target.global_position) <= hit_r * hit_r:
				is_hit = true

		if is_hit:
			hit_targets.append(target)
			_apply_hit(target)
			if pierces_left <= 0:
				queue_free()
				return

func _apply_hit(target: Node2D) -> void:
	var hp_before: float = float(target.get("current_health")) if "current_health" in target else 0.0
	var max_hp: float = float(target.get("max_health")) if ("max_health" in target and float(target.get("max_health")) > 0.0) else (hp_before if hp_before > 0.0 else 1.0)
	var hp_pct: float = hp_before / max_hp

	var ctx := hit_context
	if not ctx:
		ctx = HitContext.new()
		ctx.final_damage = 25.0
		ctx.raw_damage = 25.0
	ctx.hit_position = global_position

	if target.has_method("take_damage"):
		target.take_damage(ctx)

	var is_scatter: bool = (ctx.source_weapon_id == &"scatter_laser" or ctx.source_weapon_id == &"sniper_rifle")
	var is_dead: bool = (not is_instance_valid(target)) or (target.get("is_dying") == true) or (target.get("current_health") != null and float(target.get("current_health")) <= 0.0)
	if is_scatter and ctx.weapon_level <= 2 and hp_pct < 0.20 and is_dead and not has_meta("is_scatter_fragment"):
		_spawn_scatter_fragments(global_position, ctx)

	pierces_left -= 1
	_spawn_spark_effect()

func _spawn_scatter_fragments(pos: Vector2, parent_ctx: HitContext) -> void:
	var tree := get_tree()
	if not tree:
		return
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
	var frag_dmg: float = parent_ctx.final_damage * 0.25
	var base_angle: float = randf() * TAU
	for i in range(4):
		var dir := Vector2.from_angle(base_angle + float(i) * (TAU / 4.0))
		var frag_ctx := parent_ctx.fork_child_hit(frag_dmg, 0.0, &"scatter_fragmentation")
		var frag: KineticProjectile = duplicate() as KineticProjectile
		if not frag:
			continue
		frag.set_meta("is_scatter_fragment", true)
		frag.hit_targets.clear()
		frag.pierces_left = 1
		frag.pierces_max = 1
		frag.speed = 900.0
		frag.lifetime = 0.5
		frag.setup(pos, dir, frag_ctx, player, 1.0, 0.6)
		frag.modulate = Color(2.0, 0.4, 1.5, 1.0)
		spawn_parent.add_child(frag)

func _spawn_spark_effect() -> void:
	if spark_scene:
		var spark = spark_scene.instantiate()
		if spark:
			if spark.has_method("setup"):
				spark.setup(global_position, spark_color, 16.0 * scale.x)
			var parent_node := get_parent() if is_inside_tree() else null
			if not parent_node and is_inside_tree():
				parent_node = get_tree().current_scene
			if parent_node:
				parent_node.add_child(spark)
