class_name CrescentCyclone
extends Node2D

@export var max_radius: float = 210.0
@export var duration: float = 0.32

var hit_context: HitContext
var current_time: float = 0.0
var current_radius: float = 0.0
var damaged_nodes: Array[Node2D] = []

@onready var blade_ring: Line2D = $BladeRing

func setup(p_origin: Vector2, p_ctx: HitContext, p_size_mult: float = 1.0) -> void:
	global_position = p_origin
	hit_context = p_ctx
	max_radius *= p_size_mult

	if is_inside_tree():
		_start_cyclone()
	else:
		ready.connect(_start_cyclone, CONNECT_ONE_SHOT)

func _start_cyclone() -> void:
	if is_inside_tree():
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("dash", 1.2, 3.0)
	_clear_bullets()

func _process(delta: float) -> void:
	current_time += delta
	var t := current_time / duration
	if t >= 1.0:
		queue_free()
		return

	current_radius = max_radius * sin(t * PI * 0.5)
	_clear_bullets()
	_update_visual(t)
	_check_hits()

func _clear_bullets() -> void:
	var tree := get_tree()
	if not tree:
		return
	var bs = tree.get_first_node_in_group("bullet_server")
	if bs and bs.has_method("clear_bullets_in_radius"):
		bs.clear_bullets_in_radius(global_position, maxf(60.0, current_radius + 25.0))

func _update_visual(t: float) -> void:
	if not blade_ring:
		blade_ring = get_node_or_null("BladeRing") as Line2D
	if not blade_ring:
		return
	var pts := PackedVector2Array()
	var segs := 36
	for i in range(segs + 1):
		var angle := float(i) * TAU / float(segs)
		pts.append(Vector2(cos(angle), sin(angle)) * current_radius)
	blade_ring.points = pts
	blade_ring.width = lerpf(14.0, 1.0, t)
	blade_ring.default_color = Color(0.92, 0.25, 1.0, 1.0 - t * 0.8)

func _check_hits() -> void:
	var tree := get_tree()
	if not tree:
		return

	var r_sq := current_radius * current_radius
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if damaged_nodes.has(target):
			continue

		if global_position.distance_squared_to(target.global_position) <= r_sq:
			damaged_nodes.append(target)
			if target.has_method("take_damage"):
				var c := hit_context
				if not c:
					c = HitContext.new()
					c.final_damage = 55.0
				target.take_damage(c)
				if c.attacker and "inventory" in c.attacker and c.attacker.inventory:
					c.attacker.inventory.process_hit_procs(c, c.attacker)
