class_name CrescentSlash
extends Node2D

@export var base_reach: float = 160.0
@export var arc_angle_deg: float = 135.0

var hit_context: HitContext
var flurry_count: int = 1
var current_flurry: int = 0
var flurry_interval: float = 0.08
var flurry_timer: float = 0.0
var slash_direction: Vector2 = Vector2.RIGHT
var reach: float = 160.0

@onready var slash_line: Line2D = $SlashLine

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_count: int = 1, p_size_mult: float = 1.0) -> void:
	global_position = p_origin
	slash_direction = p_dir.normalized()
	if slash_direction.length_squared() < 0.001:
		slash_direction = Vector2.RIGHT
	hit_context = p_ctx
	flurry_count = maxi(1, p_count)
	reach = base_reach * p_size_mult
	rotation = slash_direction.angle()
	if is_inside_tree():
		_execute_single_slash()
	else:
		ready.connect(_execute_single_slash, CONNECT_ONE_SHOT)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if current_flurry < flurry_count:
		flurry_timer += delta
		if flurry_timer >= flurry_interval:
			flurry_timer = 0.0
			_execute_single_slash()
	else:
		# Tras terminar la ráfaga de cortes, espera a que el visual termine y se libera
		flurry_timer += delta
		if flurry_timer >= 0.2:
			queue_free()

func _execute_single_slash() -> void:
	current_flurry += 1

	# Audio de corte de espada rápido
	if is_inside_tree():
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("dash", 1.6 + float(current_flurry) * 0.1, 1.0)

	_draw_crescent_visual()
	_check_slash_hits()

func _draw_crescent_visual() -> void:
	if not slash_line:
		slash_line = get_node_or_null("SlashLine") as Line2D
	if not slash_line:
		return
	slash_line.clear_points()
	var half_arc := deg_to_rad(arc_angle_deg * 0.5)
	var segs := 18
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var angle := lerpf(-half_arc, half_arc, t)
		# Forma de arco en medialuna hacia delante
		var r := reach * (0.85 + 0.15 * cos(angle * 1.5))
		slash_line.add_point(Vector2(cos(angle), sin(angle)) * r)

	slash_line.width = 12.0
	slash_line.default_color = Color(0.95, 0.35, 1.0, 1.0)

	var tw := create_tween()
	tw.tween_property(slash_line, "width", 1.0, 0.12)
	tw.parallel().tween_property(slash_line, "default_color:a", 0.0, 0.14)

func _check_slash_hits() -> void:
	var tree := get_tree()
	if not tree:
		return

	var half_arc := deg_to_rad(arc_angle_deg * 0.5)
	var reach_sq := reach * reach

	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		var to_target := target.global_position - global_position
		var dist_sq := to_target.length_squared()
		if dist_sq > reach_sq:
			continue

		var angle_to := slash_direction.angle_to(to_target)
		if abs(angle_to) <= half_arc:
			if target.has_method("take_damage"):
				var ctx_to_use: HitContext = hit_context
				if not ctx_to_use:
					ctx_to_use = HitContext.new()
					ctx_to_use.final_damage = 45.0
					ctx_to_use.is_crit = false
				target.take_damage(ctx_to_use)
				if ctx_to_use.attacker and "inventory" in ctx_to_use.attacker and ctx_to_use.attacker.inventory:
					ctx_to_use.attacker.inventory.process_hit_procs(ctx_to_use, ctx_to_use.attacker)
