class_name PlanarRigWingsVFX
extends RefCounted
## Controlador de VFX procedurales para PlanarCombatRig:
## - Alas de energía y propulsores de botas.
## - Estela Sandevistan en dash y afterimage en snap.

const MAX_ACTIVE_GHOSTS: int = 5

var vfx_root: Node2D = null
var wings_node: Node2D = null
var wing_polys: Array[Polygon2D] = []
var thruster_node: Node2D = null
var thruster_polys: Array[Polygon2D] = []
var _add_mat: CanvasItemMaterial = null
var _dash_ghost_timer: float = 0.0
var _active_ghosts: Array[Node2D] = []


func build(rig_root: Node2D, accent_color: Color) -> void:
	wing_polys.clear()
	thruster_polys.clear()
	_active_ghosts.clear()

	vfx_root = Node2D.new()
	vfx_root.name = "VFXBehindLayer"
	vfx_root.z_index = -1
	rig_root.add_child(vfx_root)

	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var add_mat: CanvasItemMaterial = _add_mat

	wings_node = Node2D.new()
	wings_node.name = "ProceduralEnergyWings"
	wings_node.position = Vector2(0.0, -94.0)
	wings_node.material = add_mat
	vfx_root.add_child(wings_node)

	for side: float in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.material = add_mat
		wing.polygon = PackedVector2Array([
			Vector2(18.0 * side, -6.0),
			Vector2(92.0 * side, -78.0),
			Vector2(188.0 * side, -56.0),
			Vector2(138.0 * side, -16.0),
			Vector2(162.0 * side, 4.0),
			Vector2(102.0 * side, 16.0),
			Vector2(20.0 * side, 14.0),
		])
		wing.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.24)
		wings_node.add_child(wing)
		wing_polys.append(wing)

		var blade := Line2D.new()
		blade.material = add_mat
		blade.points = PackedVector2Array([
			Vector2(18.0 * side, -6.0),
			Vector2(92.0 * side, -78.0),
			Vector2(188.0 * side, -56.0),
			Vector2(102.0 * side, 16.0),
		])
		blade.width = 2.4
		blade.default_color = Color(1.0, 0.85, 0.90, 0.65)
		wings_node.add_child(blade)

	thruster_node = Node2D.new()
	thruster_node.name = "BootThrusters"
	vfx_root.add_child(thruster_node)

	for _idx: int in range(2):
		var flame := Polygon2D.new()
		flame.material = add_mat
		flame.polygon = PackedVector2Array([
			Vector2(-7.0, 0.0),
			Vector2(7.0, 0.0),
			Vector2(0.0, 44.0),
		])
		flame.color = Color(0.20, 0.92, 1.0, 0.62)
		thruster_node.add_child(flame)
		thruster_polys.append(flame)


func animate(
	enable_wings: bool,
	enable_thrusters: bool,
	flight_phase: float,
	smooth_move_dir: Vector2,
	smooth_speed: float,
	whiplash_wing_kick: float,
	accent_color: Color,
	views: Dictionary,
	active_view_key: String,
	holo_split_active: bool,
	snap_t: float,
	body_pivot: Node2D = null
) -> void:
	if vfx_root != null and body_pivot != null:
		vfx_root.position = body_pivot.position
		vfx_root.rotation = body_pivot.rotation
		vfx_root.scale = body_pivot.scale
	var down_brake: float = clampf(smooth_move_dir.y, 0.0, 1.0) * smooth_speed
	if wings_node != null:
		wings_node.visible = enable_wings
		if enable_wings:
			var flap: float = sin(flight_phase * 2.1) * (0.06 + smooth_speed * 0.14)
			var spread: float = 0.86 + smooth_speed * 0.28 + down_brake * 0.22 + absf(whiplash_wing_kick) * 0.16
			wings_node.scale = Vector2(spread, 1.0 + flap * 0.45 + down_brake * 0.18 - absf(whiplash_wing_kick) * 0.08)
			wings_node.rotation = whiplash_wing_kick * 0.16
			wings_node.position.y = lerpf(-94.0, -104.0, down_brake)
			for i: int in range(wing_polys.size()):
				wing_polys[i].color = Color(accent_color.r, accent_color.g, accent_color.b, 0.34 + 0.16 * absf(sin(flight_phase)))

	if thruster_node != null:
		var thruster_vis: bool = enable_thrusters and (not holo_split_active or absf(snap_t - 0.5) > 0.36)
		thruster_node.visible = thruster_vis
		if thruster_vis and views.has(active_view_key):
			var bones: Dictionary = (views[active_view_key] as Dictionary)["bones"] as Dictionary
			var ankles: Array[String] = ["Ankle_R", "Ankle_L"]
			var anti_vel: Vector2 = -smooth_move_dir
			var flame_rot: float = Vector2.DOWN.angle_to(anti_vel)
			var brake_attenuation: float = lerpf(1.0, 0.32, clampf(smooth_move_dir.y, 0.0, 1.0))
			for i: int in range(min(thruster_polys.size(), ankles.size())):
				if bones.has(ankles[i]):
					var ank: Bone2D = bones[ankles[i]] as Bone2D
					thruster_polys[i].global_position = ank.global_position
					thruster_polys[i].global_rotation = flame_rot * 0.45
					var pulse: float = (0.68 + 0.46 * smooth_speed + 0.16 * sin(flight_phase * 5.0 + float(i) * 1.4)) * brake_attenuation
					thruster_polys[i].scale = Vector2(0.82 * brake_attenuation + 0.18, pulse)


func spawn_snap_afterimage(
	parent_node: Node,
	global_pos: Vector2,
	z_idx: int,
	turn_dir: float,
	accent_color: Color,
	rig_scale: Vector2 = Vector2.ONE,
	body_pivot: Node2D = null,
	views: Dictionary = {},
	active_view_key: String = "s",
	body_flip_x: bool = false,
	head_anchor: Node2D = null,
	head_data: Dictionary = {},
	active_head_key: String = "head_front"
) -> void:
	_spawn_silhouette_ghost(
		parent_node,
		global_pos + Vector2(-turn_dir * 8.0, 0.0),
		rig_scale,
		z_idx - 1,
		body_pivot,
		views,
		active_view_key,
		body_flip_x,
		head_anchor,
		head_data,
		active_head_key,
		accent_color,
		0.36,
		0.095
	)


func process_sandevistan_trail(
	delta: float,
	enabled: bool,
	speed_norm: float,
	move_dir: Vector2,
	body_pivot: Node2D,
	parent_node: Node,
	global_pos: Vector2,
	z_idx: int,
	accent_color: Color,
	rig_scale: Vector2 = Vector2.ONE,
	views: Dictionary = {},
	active_view_key: String = "s",
	body_flip_x: bool = false,
	head_anchor: Node2D = null,
	head_data: Dictionary = {},
	active_head_key: String = "head_front"
) -> void:
	if not enabled or speed_norm < 1.05 or body_pivot == null:
		return
	_dash_ghost_timer -= delta
	if _dash_ghost_timer > 0.0 or parent_node == null:
		return
	_dash_ghost_timer = 0.065
	_spawn_silhouette_ghost(
		parent_node,
		global_pos - move_dir * 26.0,
		rig_scale,
		z_idx - 1,
		body_pivot,
		views,
		active_view_key,
		body_flip_x,
		head_anchor,
		head_data,
		active_head_key,
		accent_color,
		0.24,
		0.24
	)


func _spawn_silhouette_ghost(
	parent_node: Node,
	ghost_global_pos: Vector2,
	rig_scale: Vector2,
	z_idx: int,
	body_pivot: Node2D,
	views: Dictionary,
	active_view_key: String,
	body_flip_x: bool,
	head_anchor: Node2D,
	head_data: Dictionary,
	active_head_key: String,
	accent_color: Color,
	alpha: float,
	duration: float
) -> void:
	if parent_node == null:
		return

	var alive: Array[Node2D] = []
	for g: Node2D in _active_ghosts:
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			alive.append(g)
	_active_ghosts = alive
	while _active_ghosts.size() >= MAX_ACTIVE_GHOSTS:
		var oldest: Node2D = _active_ghosts.pop_front() as Node2D
		if is_instance_valid(oldest):
			oldest.queue_free()

	var ghost_root := Node2D.new()
	ghost_root.name = "SilhouetteGhost"
	ghost_root.scale = rig_scale
	ghost_root.z_index = z_idx
	if _add_mat != null:
		ghost_root.material = _add_mat

	var tint := Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	var built_real: bool = false

	if body_pivot != null and views.has(active_view_key):
		var vd: Dictionary = views[active_view_key] as Dictionary
		var polys: Dictionary = vd.get("polys", {}) as Dictionary
		if not polys.is_empty():
			var body_holder := Node2D.new()
			body_holder.position = body_pivot.position
			body_holder.rotation = body_pivot.rotation
			body_holder.scale = Vector2(body_pivot.scale.x * (-1.0 if body_flip_x else 1.0), body_pivot.scale.y)
			for p_key: String in polys.keys():
				var src_poly: Polygon2D = polys[p_key] as Polygon2D
				if src_poly == null or not src_poly.visible:
					continue
				var g_poly := Polygon2D.new()
				g_poly.polygon = src_poly.polygon
				g_poly.uv = src_poly.uv
				g_poly.polygons = src_poly.polygons
				g_poly.texture = src_poly.texture
				g_poly.z_index = src_poly.z_index
				g_poly.color = tint
				if _add_mat != null:
					g_poly.material = _add_mat
				body_holder.add_child(g_poly)
			ghost_root.add_child(body_holder)
			built_real = true

	if head_anchor != null and not head_data.is_empty():
		var h_sprites: Dictionary = head_data.get("sprites", {}) as Dictionary
		var src_head: Sprite2D = h_sprites.get(active_head_key, null) as Sprite2D
		if src_head != null:
			var head_holder := Node2D.new()
			head_holder.position = head_anchor.position
			head_holder.rotation = head_anchor.rotation
			head_holder.scale = head_anchor.scale
			head_holder.z_index = 14
			var g_spr := Sprite2D.new()
			g_spr.texture = src_head.texture
			g_spr.centered = src_head.centered
			g_spr.position = src_head.position
			g_spr.scale = src_head.scale
			g_spr.modulate = tint
			if _add_mat != null:
				g_spr.material = _add_mat
			head_holder.add_child(g_spr)
			ghost_root.add_child(head_holder)
			built_real = true

	if not built_real:
		var fb := Polygon2D.new()
		fb.polygon = PackedVector2Array([
			Vector2(0.0, -52.0),
			Vector2(20.0, -14.0),
			Vector2(10.0, 48.0),
			Vector2(0.0, 26.0),
			Vector2(-10.0, 48.0),
			Vector2(-20.0, -14.0),
		])
		fb.color = tint
		if _add_mat != null:
			fb.material = _add_mat
		ghost_root.add_child(fb)

	parent_node.add_child(ghost_root)
	ghost_root.global_position = ghost_global_pos
	_active_ghosts.append(ghost_root)
	var tw: Tween = ghost_root.create_tween()
	tw.tween_property(ghost_root, "modulate:a", 0.0, duration)
	tw.tween_callback(ghost_root.queue_free)


func get_active_ghost_count() -> int:
	var count: int = 0
	for g: Node2D in _active_ghosts:
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			count += 1
	return count
