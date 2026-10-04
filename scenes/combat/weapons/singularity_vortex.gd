class_name SingularityVortex
extends Node2D

@export var pull_radius: float = 240.0
@export var pull_force: float = 380.0
@export var duration: float = 2.8
@export var damage_tick_rate: float = 0.25

var hit_context: HitContext
var time_alive: float = 0.0
var tick_timer: float = 0.0

@onready var accretion_disk: Sprite2D = get_node_or_null("AccretionDisk") as Sprite2D
@onready var inner_circle: Polygon2D = get_node_or_null("InnerCircle") as Polygon2D
@onready var outer_ring: Line2D = get_node_or_null("OuterRing") as Line2D

func setup(p_pos: Vector2, p_ctx: HitContext, p_size_mult: float = 1.0) -> void:
	global_position = p_pos
	hit_context = p_ctx
	pull_radius *= p_size_mult
	scale = Vector2(p_size_mult, p_size_mult)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Spawn sound si audio manager está activo
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.5, 3.0)

func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= duration:
		_implode_and_free()
		return

	rotation += 6.0 * delta
	queue_redraw()

	# Atraer enemigos hacia el centro
	var tree := get_tree()
	if not tree:
		return

	var pull_r_sq := pull_radius * pull_radius
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		var is_boss_target: bool = target.is_in_group("bosses") or target.is_in_group("rival_pilots") or target.is_in_group("rival_pilot") or (target.get("is_boss") == true)
		if is_boss_target:
			continue
		var d_sq := global_position.distance_squared_to(target.global_position)
		if d_sq <= pull_r_sq and d_sq > 16.0:
			var pull_dir := (global_position - target.global_position).normalized()
			var factor := 1.0 - (sqrt(d_sq) / pull_radius)
			target.global_position += pull_dir * (pull_force * factor * delta)

	# Ticks de daño
	tick_timer += delta
	if tick_timer >= damage_tick_rate:
		tick_timer = 0.0
		_apply_vortex_tick_damage()

func _apply_vortex_tick_damage() -> void:
	var tree := get_tree()
	if not tree:
		return

	var pull_r_sq := pull_radius * pull_radius
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles") + tree.get_nodes_in_group("emitters")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if global_position.distance_squared_to(target.global_position) <= pull_r_sq:
			if target.has_method("take_damage"):
				var tick_ctx := hit_context
				if not tick_ctx:
					tick_ctx = HitContext.new()
					tick_ctx.final_damage = 12.0
					tick_ctx.raw_damage = 12.0
				var ctx_clone := HitContext.new()
				ctx_clone.attacker = tick_ctx.attacker
				ctx_clone.raw_damage = tick_ctx.raw_damage * 0.35
				ctx_clone.final_damage = tick_ctx.final_damage * 0.35
				ctx_clone.is_crit = tick_ctx.is_crit
				ctx_clone.proc_coefficient = 0.3
				ctx_clone.hit_position = target.global_position
				target.take_damage(ctx_clone)

func _implode_and_free() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	# Ondas gravitatorias circulares suaves que se contraen hacia el horizonte de sucesos
	for i in range(3):
		var wave_t := fmod((time_alive * 0.85) + float(i) * 0.333, 1.0)
		var r := lerpf(pull_radius * 0.65, 24.0, wave_t)
		var alpha := sin(wave_t * PI) * 0.45
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.72, 0.38, 1.0, alpha), 2.0)
