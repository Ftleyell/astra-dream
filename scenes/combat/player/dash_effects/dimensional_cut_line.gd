class_name DimensionalCutLine
extends Node2D

@export var lifetime: float = 0.32
@export var cut_thickness: float = 34.0

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var hit_context: HitContext = null
var player_ref: Node2D = null

@onready var cut_line: Line2D = $CutLine
@onready var glow_line: Line2D = $GlowLine

func setup(p_start: Vector2, p_end: Vector2, p_player: Node2D = null, p_ctx: HitContext = null) -> void:
	start_pos = p_start
	end_pos = p_end
	player_ref = p_player
	hit_context = p_ctx

	global_position = Vector2.ZERO
	if cut_line:
		cut_line.clear_points()
		cut_line.add_point(start_pos)
		cut_line.add_point(end_pos)
	if glow_line:
		glow_line.clear_points()
		glow_line.add_point(start_pos)
		glow_line.add_point(end_pos)

	_slice_enemies_along_line()
	_animate_cut()

func _slice_enemies_along_line() -> void:
	var tree := get_tree()
	if not tree:
		return

	var line_vec := end_pos - start_pos
	var line_len_sq := line_vec.length_squared()
	if line_len_sq < 0.001:
		return

	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		var p := target.global_position

		# Proyección del punto al segmento start_pos -> end_pos
		var t := clampf((p - start_pos).dot(line_vec) / line_len_sq, 0.0, 1.0)
		var proj := start_pos + line_vec * t
		var dist := p.distance_to(proj)

		if dist <= cut_thickness:
			if target.has_method("take_damage"):
				var c := hit_context
				if not c:
					c = HitContext.new()
					c.attacker = player_ref
					c.raw_damage = 70.0
					c.final_damage = 70.0
				target.take_damage(c)
				if player_ref and "inventory" in player_ref and player_ref.inventory:
					player_ref.inventory.process_hit_procs(c, player_ref)

func _animate_cut() -> void:
	var tw := create_tween().set_parallel(true)
	if cut_line:
		tw.tween_property(cut_line, "width", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if glow_line:
		tw.tween_property(glow_line, "width", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(glow_line, "default_color:a", 0.0, lifetime)
	tw.chain().tween_callback(queue_free)
