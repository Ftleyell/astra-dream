class_name SandevistanTrailController
extends Node2D
## Controlador desacoplado de propulsión Sandevistan Astral para PlanarCombatRig.
## Captura pose snapshots congeladas (Skeleton2D + cabeza desacoplada) en CanvasGroup
## y aplica evolución cromática dual (secuencia + edad) con calco de outline dominante.

const GHOST_SHADER_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost.gdshader"
const GHOST_PART_SHADER_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost_part.gdshader"

@export var config: PilotPropulsionVFXConfig = null

var _ghost_shader: Shader = null
var _ghost_part_shader: Shader = null
var _part_mat_cache: Dictionary = {}
var _ghosts: Array[Dictionary] = []
var _has_last_pos: bool = false
var _last_rig_pos: Vector2 = Vector2.ZERO
var _last_spawn_pos: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.ZERO
var _distance_accum: float = 0.0
var _sequence_progress: float = 0.0
var _color_cursor: float = 0.0
var _color_dir: float = 1.0
var _total_spawned_count: int = 0


func _ready() -> void:
	_ensure_shader_loaded()
	if config == null:
		config = PilotPropulsionVFXConfig.new()
	config.ensure_defaults()


func set_config(cfg: PilotPropulsionVFXConfig) -> void:
	config = cfg
	if config != null:
		config.ensure_defaults()


func get_active_ghost_count() -> int:
	return _ghosts.size()


func get_sequence_progress() -> float:
	return _sequence_progress


func get_color_cursor() -> float:
	return _color_cursor


func get_total_spawned_count() -> int:
	return _total_spawned_count


func clear_all_ghosts() -> void:
	for entry: Dictionary in _ghosts:
		var node: CanvasGroup = entry.get("node", null) as CanvasGroup
		if is_instance_valid(node):
			node.queue_free()
	_ghosts.clear()
	_distance_accum = 0.0
	_sequence_progress = 0.0
	_color_cursor = 0.0
	_color_dir = 1.0
	_has_last_pos = false


func trigger_burst_impulse(rig: Node2D) -> void:
	if config == null or rig == null:
		return
	_sequence_progress = maxf(_sequence_progress, 0.08)
	_color_cursor = 0.0
	_color_dir = 1.0
	_spawn_snapshot_from_rig(rig, true)
	_last_spawn_pos = rig.global_position
	_distance_accum = 0.0


func step(delta: float, rig: Node2D, velocity_px_s: Vector2, is_burst_active: bool) -> void:
	if config == null or rig == null:
		return
	config.ensure_defaults()
	_ensure_shader_loaded()

	var current_pos: Vector2 = rig.global_position
	var speed: float = velocity_px_s.length()
	var move_dir: Vector2 = velocity_px_s / speed if speed > 1.0 else Vector2.ZERO

	if not _has_last_pos:
		_last_rig_pos = current_pos
		_last_spawn_pos = current_pos
		_last_move_dir = move_dir
		_has_last_pos = true

	var frame_dist: float = current_pos.distance_to(_last_rig_pos)
	_last_rig_pos = current_pos

	# 1. Evolución de secuencia (eje A: duración de ráfaga)
	var is_moving_fast: bool = speed >= config.base_min_speed_px_s or (is_burst_active and speed >= 20.0)
	if is_moving_fast:
		if is_burst_active:
			_sequence_progress = minf(1.0, _sequence_progress + config.sequence_burst_charge_rate * delta)
		else:
			var target_cap: float = clampf(config.base_sequence_cap, 0.05, 1.0)
			if _sequence_progress < target_cap:
				_sequence_progress = minf(target_cap, _sequence_progress + config.sequence_charge_rate * delta)
			else:
				_sequence_progress = maxf(target_cap, _sequence_progress - config.sequence_decay_rate * 0.5 * delta)
	else:
		_sequence_progress = maxf(0.0, _sequence_progress - config.sequence_decay_rate * delta)
		_distance_accum = 0.0
		# Al detenerse en reposo, el pincel reinicia fresco en Turquesa (0.0)
		_color_cursor = 0.0
		_color_dir = 1.0

	# 2. Disparo por desplazamiento + compresión en giros bruscos
	if is_moving_fast and frame_dist > 0.001:
		_distance_accum += frame_dist
		var base_step: float = config.burst_spawn_distance_px if is_burst_active else config.base_spawn_distance_px
		var turn_factor: float = 1.0
		if _last_move_dir.length_squared() > 0.25 and move_dir.length_squared() > 0.25:
			var dot_v: float = clampf(_last_move_dir.dot(move_dir), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_v))
			if angle_deg >= config.turn_angle_compress_deg:
				turn_factor = clampf(config.turn_distance_compress_factor, 0.25, 1.0)

		var effective_step: float = maxf(6.0, base_step * turn_factor)
		if _distance_accum >= effective_step:
			_spawn_snapshot_from_rig(rig, is_burst_active)
			_last_spawn_pos = current_pos
			_distance_accum = fmod(_distance_accum, effective_step)
			_last_move_dir = move_dir

	# 3. Envejecimiento y actualización shader de copias activas (eje B: edad individual)
	_update_active_ghosts(delta, is_burst_active)


func _ensure_shader_loaded() -> void:
	if _ghost_shader == null and ResourceLoader.exists(GHOST_SHADER_PATH):
		_ghost_shader = ResourceLoader.load(GHOST_SHADER_PATH) as Shader
	if _ghost_part_shader == null and ResourceLoader.exists(GHOST_PART_SHADER_PATH):
		_ghost_part_shader = ResourceLoader.load(GHOST_PART_SHADER_PATH) as Shader


func _spawn_snapshot_from_rig(rig: Node2D, is_burst: bool) -> void:
	var max_allowed: int = config.burst_max_ghosts if is_burst else config.base_max_ghosts
	while _ghosts.size() >= maxi(1, max_allowed):
		var oldest: Dictionary = _ghosts.pop_front() as Dictionary
		var old_node: CanvasGroup = oldest.get("node", null) as CanvasGroup
		if is_instance_valid(old_node):
			old_node.queue_free()

	var ghost_group := CanvasGroup.new()
	ghost_group.name = "SandevistanGhost_%d" % _total_spawned_count
	ghost_group.fit_margin = 64.0
	ghost_group.clear_margin = 64.0
	ghost_group.use_mipmaps = false
	ghost_group.global_position = rig.global_position
	ghost_group.global_rotation = rig.global_rotation
	ghost_group.global_scale = rig.global_scale
	ghost_group.z_index = rig.z_index - 1

	var mat := ShaderMaterial.new()
	if _ghost_shader != null:
		mat.shader = _ghost_shader
	ghost_group.material = mat

	var built: bool = _populate_pose_snapshot(rig, ghost_group)
	if not built:
		ghost_group.free()
		return

	add_child(ghost_group)
	_total_spawned_count += 1

	var birth_color_t: float = _color_cursor
	_advance_color_cursor()

	var lifetime: float = config.burst_lifetime_sec if is_burst else config.base_lifetime_sec
	var entry: Dictionary = {
		"node": ghost_group,
		"mat": mat,
		"age": 0.0,
		"lifetime": maxf(0.05, lifetime),
		"birth_color_t": birth_color_t,
		"is_burst": is_burst,
	}
	_apply_ghost_visuals(entry, 0.0)
	_ghosts.append(entry)


func _advance_color_cursor() -> void:
	var step_v: float = clampf(config.color_step_per_ghost, 0.02, 0.5)
	_color_cursor += _color_dir * step_v
	if _color_cursor >= 1.0:
		_color_cursor = maxf(0.0, 2.0 - _color_cursor)
		_color_dir = -1.0
	elif _color_cursor <= 0.0:
		_color_cursor = minf(1.0, -_color_cursor)
		_color_dir = 1.0


func _populate_pose_snapshot(rig: Node2D, target_group: CanvasGroup) -> bool:
	var unified: Node = rig.get_node_or_null("UnifiedCharacterGroup")
	if unified == null:
		return false

	var has_content: bool = false

	# 0. Alas traseras (bajo cabeza y torso, en orden exacto de UnifiedCharacterGroup)
	var wings_under_mount: Node2D = unified.get_node_or_null("WingsUnderMount") as Node2D
	if wings_under_mount != null and wings_under_mount.visible:
		if _clone_nested_visible_sprites(wings_under_mount, target_group):
			has_content = true

	# 1. Cabeza trasera (cuello / cabello bajo el torso)
	var head_under_mount: Node2D = unified.get_node_or_null("DecoupledHeadUnderMount") as Node2D
	if head_under_mount != null and head_under_mount.visible:
		if _clone_visible_sprites(head_under_mount, target_group):
			has_content = true

	# 2. Cuerpo posado (Skeleton2D + Polygon2D congelados de la vista activa)
	var body_pivot: Node2D = unified.get_node_or_null("BodyPivot") as Node2D
	if body_pivot != null and body_pivot.visible:
		for child: Node in body_pivot.get_children():
			if child is Node2D and (child as Node2D).visible and child.name.begins_with("BodyView_"):
				var holder := Node2D.new()
				holder.name = "GhostBodyPivot"
				holder.transform = body_pivot.transform
				holder.z_index = 0

				var cloned_view: Node2D = (child as Node2D).duplicate(0) as Node2D
				if cloned_view != null:
					_strip_materials_and_zero_z(cloned_view)
					holder.add_child(cloned_view)
					target_group.add_child(holder)
					has_content = true
				break

	# 2.5. Alas sobre torso (perfil cercano o vista dorsal)
	var wings_over_mount: Node2D = unified.get_node_or_null("WingsOverMount") as Node2D
	if wings_over_mount != null and wings_over_mount.visible:
		if _clone_nested_visible_sprites(wings_over_mount, target_group):
			has_content = true

	# 3. Cabeza frontal (rostro + pelo + monóculo sobre el torso)
	var head_over_mount: Node2D = unified.get_node_or_null("DecoupledHeadMount") as Node2D
	if head_over_mount != null and head_over_mount.visible:
		if _clone_visible_sprites(head_over_mount, target_group):
			has_content = true

	return has_content


func _clone_nested_visible_sprites(mount: Node2D, target_group: CanvasGroup) -> bool:
	var holder := Node2D.new()
	holder.name = "Ghost_" + mount.name
	holder.transform = mount.transform
	holder.z_index = 0
	var cloned_any: bool = false
	for child: Node in mount.get_children():
		if child is Node2D and (child as Node2D).visible:
			if _clone_sprite_branch(child as Node2D, holder):
				cloned_any = true
	if cloned_any:
		target_group.add_child(holder)
	else:
		holder.free()
	return cloned_any


func _clone_sprite_branch(src: Node2D, dst_parent: Node2D) -> bool:
	if not src.visible:
		return false
	if src is Sprite2D:
		var src_spr: Sprite2D = src as Sprite2D
		if src_spr.texture == null:
			return false
		var dup := Sprite2D.new()
		dup.name = src_spr.name
		dup.texture = src_spr.texture
		dup.centered = src_spr.centered
		dup.offset = src_spr.offset
		dup.flip_h = src_spr.flip_h
		dup.flip_v = src_spr.flip_v
		dup.region_enabled = src_spr.region_enabled
		dup.region_rect = src_spr.region_rect
		dup.transform = src_spr.transform
		dup.z_index = 0
		dup.material = _get_part_ink_material(src_spr.material)
		dst_parent.add_child(dup)
		return true
	if src is Marker2D:
		return false
	var branch := Node2D.new()
	branch.name = src.name
	branch.transform = src.transform
	branch.z_index = 0
	var cloned_any: bool = false
	for child: Node in src.get_children():
		if child is Node2D and (child as Node2D).visible:
			if _clone_sprite_branch(child as Node2D, branch):
				cloned_any = true
	if cloned_any:
		dst_parent.add_child(branch)
	else:
		branch.free()
	return cloned_any


func _clone_visible_sprites(mount: Node2D, target_group: CanvasGroup) -> bool:
	var cloned_any: bool = false
	var holder := Node2D.new()
	holder.name = "Ghost_" + mount.name
	holder.transform = mount.transform
	holder.z_index = 0

	for child: Node in mount.get_children():
		if child is Sprite2D and (child as Sprite2D).visible:
			var src: Sprite2D = child as Sprite2D
			var dup := Sprite2D.new()
			dup.texture = src.texture
			dup.centered = src.centered
			dup.offset = src.offset
			dup.flip_h = src.flip_h
			dup.flip_v = src.flip_v
			dup.region_enabled = src.region_enabled
			dup.region_rect = src.region_rect
			dup.transform = src.transform
			dup.z_index = 0
			dup.material = _get_part_ink_material(src.material)
			holder.add_child(dup)
			cloned_any = true

	if cloned_any:
		target_group.add_child(holder)
	else:
		holder.free()
	return cloned_any


func _strip_materials_and_zero_z(root: Node) -> void:
	if root is Polygon2D or root is Sprite2D:
		var ci: CanvasItem = root as CanvasItem
		ci.material = _get_part_ink_material(ci.material)
		ci.z_index = 0
	elif root is CanvasItem:
		var ci: CanvasItem = root as CanvasItem
		ci.material = null
		ci.z_index = 0
	for child: Node in root.get_children():
		_strip_materials_and_zero_z(child)


func _get_part_ink_material(src_mat: Material) -> ShaderMaterial:
	if _ghost_part_shader == null:
		return null
	var has_ink: bool = false
	var ink_tex: Texture2D = null
	var has_id: bool = false
	var id_tex: Texture2D = null
	var leg_pass: int = 0
	var hip_pass: int = 0
	var head_pass: int = 0
	var head_keep: float = 0.0

	if src_mat is ShaderMaterial:
		var sm: ShaderMaterial = src_mat as ShaderMaterial
		var raw_has: Variant = sm.get_shader_parameter("has_ink_sdf")
		if raw_has is bool and bool(raw_has):
			var raw_tex: Variant = sm.get_shader_parameter("ink_sdf_tex")
			if raw_tex is Texture2D:
				has_ink = true
				ink_tex = raw_tex as Texture2D

		var raw_id: Variant = sm.get_shader_parameter("id_mask_tex")
		if raw_id is Texture2D:
			has_id = true
			id_tex = raw_id as Texture2D

		var raw_leg: Variant = sm.get_shader_parameter("leg_layer_pass")
		if raw_leg is int or raw_leg is float:
			leg_pass = int(raw_leg)
		var raw_hip: Variant = sm.get_shader_parameter("body_hip_skin_pass")
		if raw_hip is int or raw_hip is float:
			hip_pass = int(raw_hip)
		var raw_head: Variant = sm.get_shader_parameter("head_layer_pass")
		if raw_head is int or raw_head is float:
			head_pass = int(raw_head)
		var raw_keep: Variant = sm.get_shader_parameter("head_over_face_keep")
		if raw_keep is float or raw_keep is int:
			head_keep = float(raw_keep)

	var ink_id: int = ink_tex.get_instance_id() if (has_ink and ink_tex != null) else 0
	var id_id: int = id_tex.get_instance_id() if (has_id and id_tex != null) else 0
	var cache_key: String = "%d|%d|%d|%d|%d|%.2f" % [ink_id, id_id, leg_pass, hip_pass, head_pass, head_keep]
	if _part_mat_cache.has(cache_key):
		return _part_mat_cache[cache_key] as ShaderMaterial

	var part_mat := ShaderMaterial.new()
	part_mat.shader = _ghost_part_shader
	part_mat.set_shader_parameter("has_ink_sdf", has_ink)
	if has_ink and ink_tex != null:
		part_mat.set_shader_parameter("ink_sdf_tex", ink_tex)
	part_mat.set_shader_parameter("has_id_mask", has_id)
	if has_id and id_tex != null:
		part_mat.set_shader_parameter("id_mask_tex", id_tex)
	part_mat.set_shader_parameter("leg_layer_pass", leg_pass)
	part_mat.set_shader_parameter("body_hip_skin_pass", hip_pass)
	part_mat.set_shader_parameter("head_layer_pass", head_pass)
	part_mat.set_shader_parameter("head_over_face_keep", head_keep)
	_part_mat_cache[cache_key] = part_mat
	return part_mat


func _update_active_ghosts(delta: float, is_burst_active: bool) -> void:
	var max_allowed: int = config.burst_max_ghosts if is_burst_active else config.base_max_ghosts
	var alive: Array[Dictionary] = []

	for entry: Dictionary in _ghosts:
		var node: CanvasGroup = entry.get("node", null) as CanvasGroup
		if not is_instance_valid(node):
			continue
		var age: float = float(entry.get("age", 0.0)) + delta
		var lifetime: float = float(entry.get("lifetime", 0.3))
		if age >= lifetime:
			node.queue_free()
			continue
		entry["age"] = age
		var age_t: float = clampf(age / lifetime, 0.0, 1.0)
		_apply_ghost_visuals(entry, age_t)
		alive.append(entry)

	while alive.size() > maxi(1, max_allowed):
		var drop: Dictionary = alive.pop_front() as Dictionary
		var drop_node: CanvasGroup = drop.get("node", null) as CanvasGroup
		if is_instance_valid(drop_node):
			drop_node.queue_free()

	_ghosts = alive


func _apply_ghost_visuals(entry: Dictionary, age_t: float) -> void:
	var mat: ShaderMaterial = entry.get("mat", null) as ShaderMaterial
	if mat == null:
		return

	# Cada copia congela el color con el que nació (pincel ping-pong Turquesa <-> Bordó <-> Amatista)
	var seq_t: float = clampf(float(entry.get("birth_color_t", 0.0)), 0.0, 1.0)

	var base_col: Color = config.sample_sequence_color(seq_t)
	# Outline del mismo tono que la sombra/relleno pero más oscuro (estilo tinta anime)
	var outline_col: Color = base_col.darkened(clampf(config.outline_darken_amount, 0.0, 0.85))

	var fill_a: float = config.sample_fill_alpha(age_t)
	var outline_a: float = config.sample_outline_alpha(age_t)
	var emissive: float = config.compute_emissive_boost(seq_t)

	# Afinado progresivo del outline en el tramo final (70% - 100%)
	var width_t: float = clampf((age_t - 0.65) / 0.35, 0.0, 1.0)
	var outline_w: float = lerpf(config.outline_width_px, config.outline_min_width_px, width_t)

	mat.set_shader_parameter("fill_color", base_col)
	mat.set_shader_parameter("outline_color", outline_col)
	mat.set_shader_parameter("fill_alpha", fill_a)
	mat.set_shader_parameter("outline_alpha", outline_a)
	mat.set_shader_parameter("outline_width_px", outline_w)
	mat.set_shader_parameter("rim_strength", config.rim_strength)
	mat.set_shader_parameter("rim_width_px", config.rim_width_px)
	mat.set_shader_parameter("internal_ink_strength", config.internal_ink_strength)
	mat.set_shader_parameter("emissive_boost", emissive)
