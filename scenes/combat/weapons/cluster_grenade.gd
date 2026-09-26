class_name ClusterGrenade
extends Node2D

@export var speed: float = 620.0
@export var fuse_time: float = 0.85
@export var sub_munitions_count: int = 6
@export var explosion_radius: float = 110.0

var hit_context: HitContext
var velocity: Vector2 = Vector2.ZERO
var target_dest: Vector2 = Vector2.ZERO
var current_time: float = 0.0
var player: Node2D = null

@onready var visual_body: Polygon2D = $Body

func setup(p_origin: Vector2, p_target: Vector2, p_ctx: HitContext, p_player: Node2D = null) -> void:
	global_position = p_origin
	target_dest = p_target
	hit_context = p_ctx
	player = p_player
	var dist := p_origin.distance_to(p_target)
	var dir := (p_target - p_origin).normalized() if dist > 1.0 else Vector2.RIGHT
	var flight_duration := clampf(dist / speed, 0.35, 1.2)
	fuse_time = flight_duration
	velocity = dir * (dist / flight_duration)
	add_to_group("player_projectiles")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	current_time += delta
	rotation += 10.0 * delta
	global_position += velocity * delta

	if current_time >= fuse_time:
		_detonate_cluster()

func _detonate_cluster() -> void:
	# 1. Onda de choque central
	var shock_scene: PackedScene = load("res://scenes/combat/weapons/shockwave_area.tscn")
	if shock_scene:
		var shock: ShockwaveArea = shock_scene.instantiate() as ShockwaveArea
		shock.setup(global_position, hit_context, 1.0)
		get_parent().add_child(shock)

	# 2. Liberar submuniciones cinéticas radiales
	var proj_scene: PackedScene = load("res://scenes/combat/weapons/kinetic_projectile.tscn")
	if proj_scene:
		for i in range(sub_munitions_count):
			var angle := float(i) * TAU / float(sub_munitions_count) + randf_range(-0.2, 0.2)
			var sub_dir := Vector2(cos(angle), sin(angle))
			var sub_ctx := HitContext.new()
			if hit_context:
				sub_ctx.attacker = hit_context.attacker
				sub_ctx.raw_damage = hit_context.raw_damage * 0.4
				sub_ctx.final_damage = hit_context.final_damage * 0.4
				sub_ctx.is_crit = hit_context.is_crit
			sub_ctx.proc_coefficient = 0.35
			var sub := proj_scene.instantiate() as KineticProjectile
			sub.setup(global_position, sub_dir, sub_ctx, player, 0.65, 0.8)
			get_parent().add_child(sub)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.2, 2.0)

	queue_free()
