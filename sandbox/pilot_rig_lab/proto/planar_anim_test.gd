extends Node2D
## Laboratorio de Animación 2.5D — Valentina v2 (8 Direcciones Completas en Grilla 4x2).

const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const ViewRouterScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd")
const MeshBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd")
const CalibStoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")

enum AnimMode {
	COMBINED_BONES_AND_25D = 0,
	BONES_ONLY = 1,
	SHADER_25D_ONLY = 2,
}

const ALL_VIEWS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const COMPASS_RADIUS: float = 290.0
const HEAD_CYCLE_SEC: float = 1.4

var _rig_entries: Array[Dictionary] = []
var _camera: Camera2D = null
var _zone_masks: Dictionary = {}
var _hip_shadows: Dictionary = {}
var _stocking_pinches: Dictionary = {}
var _playing: bool = true
var _anim_time: float = 0.0
var _mode: int = AnimMode.COMBINED_BONES_AND_25D
var _amp_scale: float = 1.0
var _dragging: bool = false
var _head_cycle_enabled: bool = true

var _outline_enabled: bool = true
var _outline_px: float = 1.35
var _outline_on_head: bool = false
var _outline_centered: bool = false
var _outline_color: Color = Color(0.015, 0.015, 0.025, 1.0)

var _play_btn: Button = null
var _head_btn: CheckBox = null
var _outline_lbl: Label = null
var _mode_btn: OptionButton = null
var _amp_slider: HSlider = null
var _readout_label: Label = null


func _ready() -> void:
	_build_backdrop()

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2(0.85, 0.85)
	add_child(_camera)

	for v_key: String in ALL_VIEWS:
		_zone_masks["%s_r" % v_key] = _load_png_tex("res://sandbox/pilot_rig_lab/proto/leg_r_%s_persp_mask.png" % v_key)
		_zone_masks["%s_l" % v_key] = _load_png_tex("res://sandbox/pilot_rig_lab/proto/leg_l_%s_persp_mask.png" % v_key)
		var meta_path: String = "%s/%s/parts_5/parts_5_meta.json" % [MeshBuilderScript.ASSETS_ROOT, v_key]
		var meta_d: Dictionary = MeshBuilderScript.load_json_dict(meta_path)
		_hip_shadows[v_key] = CalibStoreScript.parse_hip_cast_shadow_from_meta(meta_d, v_key)
		_stocking_pinches[v_key] = CalibStoreScript.parse_stocking_pinch_from_meta(meta_d)

	for v_key: String in ALL_VIEWS:
		var dir_vec: Vector2 = ViewRouterScript.get_body_dir_vector(v_key)
		var pos: Vector2 = dir_vec * COMPASS_RADIUS
		var allowed_heads: Array = (ViewRouterScript.ALLOWED_HEADS_BY_BODY_8DIR.get(v_key, [ViewRouterScript.get_default_head_for_body(v_key)]) as Array).duplicate()
		var rig: PlanarCombatRig = PlanarRigScript.new()
		rig.name = "PilotRig_%s" % v_key.to_upper()
		rig.position = pos
		add_child(rig)
		rig.set_static_inspection(true, v_key, str(allowed_heads[0]))
		rig.calibration_manual_pose = true

		var tag := Label.new()
		tag.text = v_key.to_upper()
		tag.position = pos + Vector2(-14.0, -116.0)
		tag.modulate = Color(0.75, 0.85, 1.0, 0.85)
		add_child(tag)

		_rig_entries.append({
			"view": v_key,
			"rig": rig,
			"heads": allowed_heads,
			"head_idx": 0,
		})

	_build_ui()
	_apply_all_poses()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_camera(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_camera(1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and _camera != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_camera.position -= mm.relative / maxf(_camera.zoom.x, 0.05)
	elif event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_SPACE:
				_toggle_play()
			elif kev.keycode == KEY_R:
				_reset_pose()


func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var mouse_before: Vector2 = get_global_mouse_position()
	var z: float = clampf(_camera.zoom.x * factor, 0.40, 12.0)
	_camera.zoom = Vector2(z, z)
	var mouse_after: Vector2 = get_global_mouse_position()
	_camera.position += (mouse_before - mouse_after)


func _process(delta: float) -> void:
	if _playing:
		_anim_time += delta
		if _head_cycle_enabled:
			_update_head_cycles()
	_apply_all_poses()


func _update_head_cycles() -> void:
	var step_idx: int = int(floor(_anim_time / HEAD_CYCLE_SEC))
	for i: int in range(_rig_entries.size()):
		var entry: Dictionary = _rig_entries[i]
		var heads: Array = entry["heads"] as Array
		if heads.size() <= 1:
			continue
		var target_idx: int = (step_idx + i) % heads.size()
		if int(entry["head_idx"]) != target_idx:
			entry["head_idx"] = target_idx
			var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
			var v_key: String = entry["view"] as String
			rig.set_static_inspection(true, v_key, str(heads[target_idx]))


func _toggle_play() -> void:
	_playing = not _playing
	if _play_btn != null:
		_play_btn.text = "Pausar (Espacio)" if _playing else "Reproducir (Espacio)"


func _reset_pose() -> void:
	_anim_time = 0.0
	if _camera != null:
		_camera.position = Vector2.ZERO
		_camera.zoom = Vector2(0.85, 0.85)
	_apply_all_poses()


func _load_png_tex(res_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img: Image = Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _compute_leg_params(view_key: String, is_r: bool, use_bones: bool) -> Dictionary:
	var side_sign: float = 1.0 if is_r else -1.0
	var phase_offset: float = 0.0 if is_r else 2.15
	var t: float = _anim_time * 1.05 + phase_offset
	var wave: float = sin(t) + 0.10 * sin(t * 2.0)
	var wave_lag: float = sin(t - 0.50) + 0.08 * sin((t - 0.50) * 2.0)
	var wave_foot: float = sin(t - 0.95) + 0.06 * sin((t - 0.95) * 2.0)

	if view_key == "s" or view_key == "n":
		var is_back: bool = view_key == "n"
		var scr_sign: float = -side_sign if is_back else side_sign
		var z_sign: float = -1.0 if is_back else 1.0
		var base_bend: float = 1.0 if is_r else 0.72
		return {
			"thigh_pos_x": 0.0,
			"thigh_rot": 0.0 if is_back else (((-0.088 if is_r else 0.074) + (0.010 * wave) * scr_sign * _amp_scale) if use_bones else 0.0),
			"knee_rot": (((0.070 if is_r else -0.062) * (-1.0 if is_back else 1.0)) + (-0.015 * wave_lag) * scr_sign * _amp_scale) if use_bones else 0.0,
			"ankle_rot": ((0.026 * scr_sign) + (0.014 * wave_foot) * scr_sign * _amp_scale) if use_bones else 0.0,
			"phi_thigh": 0.0 if is_back else ((0.08 * base_bend + 0.045 * wave) * z_sign * _amp_scale),
			"phi_shin": (-0.16 * base_bend - 0.065 * wave_lag) * z_sign * _amp_scale,
			"distal_amp": (-0.08 * base_bend + 0.025 * wave_foot) * z_sign * _amp_scale,
			"depth_phase": (-0.06 * base_bend + 0.05 * wave) * z_sign * _amp_scale,
			"pivot_v": 0.445,
		}

	if view_key == "e" or view_key == "w":
		var m_sign: float = 1.0 if view_key == "e" else -1.0
		var is_front: bool = (view_key == "e" and is_r) or (view_key == "w" and not is_r)
		var base_bend_ew: float = 1.0 if is_front else 0.75
		return {
			"thigh_pos_x": 0.0,
			"thigh_rot": (((-0.055 if is_front else 0.045) + 0.024 * wave) * m_sign * _amp_scale) if use_bones else 0.0,
			"knee_rot": (((0.095 if is_front else 0.055) - 0.032 * wave_lag) * m_sign * _amp_scale) if use_bones else 0.0,
			"ankle_rot": (((-0.045 if is_front else -0.025) + 0.028 * wave_foot) * m_sign * _amp_scale) if use_bones else 0.0,
			"phi_thigh": (0.04 * base_bend_ew + 0.025 * wave) * _amp_scale,
			"phi_shin": (-0.07 * base_bend_ew - 0.035 * wave_lag) * _amp_scale,
			"distal_amp": (-0.05 * base_bend_ew + 0.020 * wave_foot) * _amp_scale,
			"depth_phase": (0.12 if is_front else -0.18) + 0.03 * wave,
			"pivot_v": 0.440,
		}

	# Oblicuas: SE/SW (frente 3/4) y NE/NW (espalda 3/4)
	var is_rear_oblique: bool = view_key == "ne" or view_key == "nw"
	var mir: float = 1.0 if (view_key == "se" or view_key == "ne") else -1.0
	var is_front_ob: bool = ((view_key == "se" or view_key == "ne") and is_r) or ((view_key == "sw" or view_key == "nw") and not is_r)
	var base_b: float = 1.0 if is_front_ob else 0.72
	var z_dir: float = -1.0 if is_rear_oblique else 1.0
	return {
		"thigh_pos_x": 0.0,
		"thigh_rot": 0.0 if is_rear_oblique else (((( -0.018 if is_front_ob else 0.014) * mir + 0.008 * wave * side_sign) * _amp_scale) if use_bones else 0.0),
		"knee_rot": (((0.048 if is_front_ob else 0.028) * mir - 0.014 * wave_lag * mir) * _amp_scale) if use_bones else 0.0,
		"ankle_rot": (((-0.028 if is_front_ob else -0.016) * mir + 0.014 * wave_foot * mir) * _amp_scale) if use_bones else 0.0,
		"phi_thigh": 0.0 if is_rear_oblique else ((0.08 * base_b + 0.045 * wave) * z_dir * _amp_scale),
		"phi_shin": (-0.16 * base_b - 0.065 * wave_lag) * z_dir * _amp_scale,
		"distal_amp": (-0.08 * base_b + 0.025 * wave_foot) * z_dir * _amp_scale,
		"depth_phase": (-0.06 * base_b + 0.05 * wave) * z_dir * _amp_scale,
		"pivot_v": 0.433 if is_front_ob else 0.460,
	}


func _apply_spine_and_arms_idle(
	view_key: String,
	bones: Dictionary,
	rest_rots: Dictionary,
	rest_pos: Dictionary,
	use_bones: bool
) -> Dictionary:
	var t: float = _anim_time * 1.05
	var breath: float = sin(t)
	var sway: float = sin(t * 0.52)
	var mirror_sign: float = -1.0 if view_key in ["sw", "w", "nw", "n"] else 1.0

	if use_bones:
		if bones.has("Pelvis") and rest_pos.has("Pelvis") and rest_rots.has("Pelvis"):
			var pelvis: Bone2D = bones["Pelvis"] as Bone2D
			pelvis.position = (rest_pos["Pelvis"] as Vector2) + Vector2(sway * 1.4 * mirror_sign, breath * 3.0) * _amp_scale
			pelvis.rotation = float(rest_rots["Pelvis"]) + sin(t * 0.52 - 0.3) * 0.011 * mirror_sign * _amp_scale
		if bones.has("Waist") and rest_rots.has("Waist"):
			(bones["Waist"] as Bone2D).rotation = float(rest_rots["Waist"]) + sway * 0.012 * mirror_sign * _amp_scale
		if bones.has("Chest") and rest_rots.has("Chest") and rest_pos.has("Chest"):
			var chest: Bone2D = bones["Chest"] as Bone2D
			chest.position = (rest_pos["Chest"] as Vector2) + Vector2(0.0, -breath * 0.7) * _amp_scale
			chest.rotation = float(rest_rots["Chest"]) + (breath * 0.008 - sway * 0.008 * mirror_sign) * _amp_scale
		if bones.has("Neck") and rest_rots.has("Neck"):
			(bones["Neck"] as Bone2D).rotation = float(rest_rots["Neck"]) - breath * 0.006 * _amp_scale

		for p_cfg: Array in [["Pauldron_R", 1.0], ["Pauldron_L", -1.0]]:
			var p_name: String = p_cfg[0] as String
			var s_sign: float = float(p_cfg[1]) * (1.0 if view_key != "n" else -1.0)
			if bones.has(p_name) and rest_pos.has(p_name) and rest_rots.has(p_name):
				var pb: Bone2D = bones[p_name] as Bone2D
				pb.position = (rest_pos[p_name] as Vector2) + Vector2(0.0, -breath * 1.1) * _amp_scale
				pb.rotation = float(rest_rots[p_name]) + breath * 0.014 * s_sign * _amp_scale

		var arm_scale: float = 0.75 if view_key in ["e", "w"] else 1.0
		for arm_cfg: Array in [["R", 1.0, 0.0], ["L", -1.0, 0.65]]:
			var sfx: String = arm_cfg[0] as String
			var s_sign: float = float(arm_cfg[1]) * (1.0 if view_key != "n" else -1.0)
			var ph: float = float(arm_cfg[2])
			var w_sh: float = sin(t - 0.35 + ph)
			var w_el: float = sin(t - 0.80 + ph)
			var w_wr: float = sin(t - 1.25 + ph)
			if bones.has("Shoulder_" + sfx) and rest_rots.has("Shoulder_" + sfx):
				(bones["Shoulder_" + sfx] as Bone2D).rotation = float(rest_rots["Shoulder_" + sfx]) + (-0.018 + 0.020 * w_sh) * s_sign * arm_scale * _amp_scale
			if bones.has("Elbow_" + sfx) and rest_rots.has("Elbow_" + sfx):
				(bones["Elbow_" + sfx] as Bone2D).rotation = float(rest_rots["Elbow_" + sfx]) + (0.026 + 0.024 * w_el) * s_sign * arm_scale * _amp_scale
			if bones.has("Wrist_" + sfx) and rest_rots.has("Wrist_" + sfx):
				(bones["Wrist_" + sfx] as Bone2D).rotation = float(rest_rots["Wrist_" + sfx]) + (0.030 * w_wr) * s_sign * arm_scale * _amp_scale

	return {
		"torso_trap": 0.024 * breath * _amp_scale,
		"torso_yaw": 0.018 * sway * mirror_sign * _amp_scale,
		"arm_r_phi1": 0.06 * sin(t - 0.35) * _amp_scale,
		"arm_r_phi2": -0.09 * sin(t - 0.80) * _amp_scale,
		"arm_l_phi1": 0.06 * sin(t + 0.30) * _amp_scale,
		"arm_l_phi2": -0.09 * sin(t - 0.15) * _amp_scale,
	}


func _apply_all_poses() -> void:
	var use_bones: bool = _mode == AnimMode.COMBINED_BONES_AND_25D or _mode == AnimMode.BONES_ONLY
	var use_25d: bool = _mode == AnimMode.COMBINED_BONES_AND_25D or _mode == AnimMode.SHADER_25D_ONLY

	for entry: Dictionary in _rig_entries:
		var view_key: String = entry["view"] as String
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		var views: Dictionary = rig.get_views()
		if not views.has(view_key):
			continue
		var vd: Dictionary = views[view_key] as Dictionary
		var bones: Dictionary = vd.get("bones", {}) as Dictionary
		var rest_rots: Dictionary = vd.get("rest_rots", {}) as Dictionary
		var rest_pos: Dictionary = vd.get("rest_pos", {}) as Dictionary
		var polys: Dictionary = vd.get("polys", {}) as Dictionary

		var body_fx: Dictionary = _apply_spine_and_arms_idle(view_key, bones, rest_rots, rest_pos, use_bones)
		var r_params: Dictionary = _compute_leg_params(view_key, true, use_bones)
		var l_params: Dictionary = _compute_leg_params(view_key, false, use_bones)

		for suffix_cfg: Array in [["R", r_params], ["L", l_params]]:
			var sfx: String = suffix_cfg[0] as String
			var prm: Dictionary = suffix_cfg[1] as Dictionary
			var thigh_name: String = "Thigh_" + sfx
			if bones.has(thigh_name) and rest_pos.has(thigh_name):
				(bones[thigh_name] as Bone2D).position = (rest_pos[thigh_name] as Vector2) + Vector2(float(prm["thigh_pos_x"]), 0.0)
			for pair: Array in [["Thigh_" + sfx, "thigh_rot"], ["Knee_" + sfx, "knee_rot"], ["Ankle_" + sfx, "ankle_rot"]]:
				var b_name: String = pair[0] as String
				if bones.has(b_name) and rest_rots.has(b_name):
					(bones[b_name] as Bone2D).rotation = float(rest_rots[b_name]) + float(prm[pair[1]])

		_apply_view_shaders(view_key, bones, rest_pos, polys, r_params, l_params, body_fx, use_25d)
		_apply_outline_uniforms(rig, vd)

	if _readout_label != null:
		_readout_label.text = "Brújula 8-Dir | Rueda: Zoom | Click+Arrastrar: Mover | R: Centrar | Modo: %s" % [
			_mode_btn.get_item_text(_mode) if _mode_btn != null else "",
		]


func _apply_outline_uniforms(rig: PlanarCombatRig, vd: Dictionary) -> void:
	var mat_lists: Array = [
		vd.get("materials", []) as Array,
		rig.get_head_data().get("materials", []) as Array,
		rig.get_head_under_data().get("materials", []) as Array,
	]
	for mats: Array in mat_lists:
		for m_v: Variant in mats:
			var mat: ShaderMaterial = m_v as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("enable_inward_outline", _outline_enabled)
			mat.set_shader_parameter("inward_outline_px", _outline_px)
			mat.set_shader_parameter("inward_outline_on_head", _outline_on_head)
			mat.set_shader_parameter("inward_outline_centered", _outline_centered)
			mat.set_shader_parameter("inward_outline_color", _outline_color)


func _apply_view_shaders(
	view_key: String,
	bones: Dictionary,
	rest_pos: Dictionary,
	polys: Dictionary,
	r_params: Dictionary,
	l_params: Dictionary,
	body_fx: Dictionary,
	use_25d: bool
) -> void:
	var bc_poly: Polygon2D = polys.get("body_core", null) as Polygon2D
	var bc_tex: Texture2D = bc_poly.texture if bc_poly != null else null
	var bc_rect: Variant = (bc_poly.material as ShaderMaterial).get_shader_parameter("part_rig_rect") if (bc_poly != null and bc_poly.material is ShaderMaterial) else Vector4(0.0, 0.0, 1.0, 1.0)
	var pelvis_bone: Bone2D = bones.get("Pelvis", null) as Bone2D
	var pelvis_delta: Vector2 = (pelvis_bone.position - (rest_pos.get("Pelvis", Vector2.ZERO) as Vector2)) if pelvis_bone != null else Vector2.ZERO
	for p_key: String in polys.keys():
		var poly: Polygon2D = polys[p_key] as Polygon2D
		if poly == null or not (poly.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = poly.material as ShaderMaterial
		var is_r: bool = p_key.begins_with("leg_r")
		var is_l: bool = p_key.begins_with("leg_l")
		if use_25d and (is_r or is_l):
			var sfx: String = "R" if is_r else "L"
			var prm: Dictionary = r_params if is_r else l_params
			var mask_key: String = "%s_%s" % [view_key, "r" if is_r else "l"]
			var z_mask: Texture2D = _zone_masks.get(mask_key, null) as Texture2D
			var b_root: Bone2D = bones.get("Thigh_" + sfx, null) as Bone2D
			var b_mid: Bone2D = bones.get("Knee_" + sfx, null) as Bone2D
			var b_tip: Bone2D = bones.get("Ankle_" + sfx, null) as Bone2D
			if b_root != null and b_mid != null and b_tip != null:
				var p_root: Vector2 = poly.to_local(b_root.global_position)
				var p_mid: Vector2 = poly.to_local(b_mid.global_position)
				var p_tip: Vector2 = poly.to_local(b_tip.global_position)
				mat.set_shader_parameter("persp_mode", 1)
				mat.set_shader_parameter("use_persp_zone_mask", z_mask != null)
				if z_mask != null:
					mat.set_shader_parameter("persp_zone_mask", z_mask)
				mat.set_shader_parameter("persp_anchors_root_mid", Vector4(p_root.x, p_root.y, p_mid.x, p_mid.y))
				mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(p_tip.x, p_tip.y, float(prm["pivot_v"]), float(prm["phi_thigh"])))
				mat.set_shader_parameter("persp_params_a", Vector4(float(prm["phi_shin"]), 0.18, 0.22, 0.14))
				mat.set_shader_parameter("persp_params_b", Vector4(0.02, float(prm["distal_amp"]), -0.35, 0.0))
				mat.set_shader_parameter("leg_depth_phase", float(prm["depth_phase"]))
				var sh_cfg: Dictionary = _hip_shadows.get(view_key, {}) as Dictionary
				var use_cast: bool = bool(sh_cfg.get("enabled", true)) and bc_tex != null
				mat.set_shader_parameter("enable_hip_cast_shadow", use_cast)
				if use_cast:
					mat.set_shader_parameter("hip_cast_body_tex", bc_tex)
					mat.set_shader_parameter("hip_cast_body_rect", bc_rect)
					mat.set_shader_parameter("hip_cast_pelvis_delta", pelvis_delta)
					mat.set_shader_parameter("hip_cast_shadow_offset_px", sh_cfg.get("offset", Vector2(0.8, 3.2)) as Vector2)
					mat.set_shader_parameter("hip_cast_shadow_color", sh_cfg.get("color", Color(0.82, 0.68, 0.74, 1.0)) as Color)
				var sp_cfg: Dictionary = _stocking_pinches.get(view_key, {}) as Dictionary
				var use_pinch: bool = bool(sp_cfg.get("enabled", true))
				mat.set_shader_parameter("enable_stocking_pinch", use_pinch)
				if use_pinch:
					var v_key_sp: String = "v_l" if p_key.begins_with("leg_l") else "v_r"
					var tilt_key: String = "tilt_l" if p_key.begins_with("leg_l") else "tilt_r"
					var v_val_sp: float = float(sp_cfg.get(v_key_sp, sp_cfg.get("v", 0.25)))
					mat.set_shader_parameter("stocking_pinch_v", v_val_sp)
					mat.set_shader_parameter("stocking_pinch_center_u", CalibStoreScript.compute_pinch_center_u(poly.texture, v_val_sp))
					mat.set_shader_parameter("stocking_pinch_tilt", float(sp_cfg.get(tilt_key, sp_cfg.get("tilt", 0.0))))
					mat.set_shader_parameter("stocking_pinch_strength", float(sp_cfg.get("strength", 0.045)))
					mat.set_shader_parameter("stocking_pinch_width", float(sp_cfg.get("width", 0.032)))
					mat.set_shader_parameter("stocking_pinch_shadow", float(sp_cfg.get("shadow", 0.20)))
				continue
		if use_25d and (p_key == "arm_r" or p_key == "arm_l"):
			var a_sfx: String = "R" if p_key == "arm_r" else "L"
			var a_root: Bone2D = bones.get("Shoulder_" + a_sfx, null) as Bone2D
			var a_mid: Bone2D = bones.get("Elbow_" + a_sfx, null) as Bone2D
			var a_tip: Bone2D = bones.get("Wrist_" + a_sfx, null) as Bone2D
			if a_root != null and a_mid != null and a_tip != null:
				var pr_a: Vector2 = poly.to_local(a_root.global_position)
				var pm_a: Vector2 = poly.to_local(a_mid.global_position)
				var pt_a: Vector2 = poly.to_local(a_tip.global_position)
				var phi1_a: float = float(body_fx["arm_r_phi1" if p_key == "arm_r" else "arm_l_phi1"])
				var phi2_a: float = float(body_fx["arm_r_phi2" if p_key == "arm_r" else "arm_l_phi2"])
				mat.set_shader_parameter("persp_mode", 1)
				mat.set_shader_parameter("use_persp_zone_mask", false)
				mat.set_shader_parameter("persp_anchors_root_mid", Vector4(pr_a.x, pr_a.y, pm_a.x, pm_a.y))
				mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(pt_a.x, pt_a.y, 0.48, phi1_a))
				mat.set_shader_parameter("persp_params_a", Vector4(phi2_a, 0.15, 0.22, 0.10))
				mat.set_shader_parameter("persp_params_b", Vector4(0.02, 0.0, 0.0, 0.0))
				mat.set_shader_parameter("leg_depth_phase", 0.0)
				continue
		if use_25d and p_key == "body_core":
			var b_neck: Bone2D = bones.get("Neck", null) as Bone2D
			var b_pelvis: Bone2D = bones.get("Pelvis", null) as Bone2D
			if b_neck != null and b_pelvis != null:
				var pn: Vector2 = poly.to_local(b_neck.global_position)
				var pp: Vector2 = poly.to_local(b_pelvis.global_position)
				mat.set_shader_parameter("persp_mode", 2)
				mat.set_shader_parameter("use_persp_zone_mask", false)
				mat.set_shader_parameter("persp_anchors_root_mid", Vector4(pn.x, pn.y, pn.x, pn.y))
				mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(pp.x, pp.y, 0.5, 0.03))
				mat.set_shader_parameter("persp_params_a", Vector4(0.0, 0.15, 0.22, 0.0))
				mat.set_shader_parameter("persp_params_b", Vector4(0.0, 0.0, 0.0, float(body_fx["torso_trap"])))
				mat.set_shader_parameter("persp_params_c", Vector4(float(body_fx["torso_yaw"]), 0.0, 0.35, 0.0))
				mat.set_shader_parameter("leg_depth_phase", 0.0)
				continue
		mat.set_shader_parameter("persp_mode", 0)
		mat.set_shader_parameter("use_persp_zone_mask", false)
		mat.set_shader_parameter("leg_depth_phase", 0.0)


func _draw() -> void:
	var col := Color(0.28, 0.34, 0.48, 0.45)
	draw_arc(Vector2.ZERO, COMPASS_RADIUS, 0.0, TAU, 72, col, 1.5)
	draw_line(Vector2(-COMPASS_RADIUS - 30.0, 0.0), Vector2(COMPASS_RADIUS + 30.0, 0.0), col, 1.0)
	draw_line(Vector2(0.0, -COMPASS_RADIUS - 30.0), Vector2(0.0, COMPASS_RADIUS + 30.0), col, 1.0)


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.14, 1.0)
	bg.position = Vector2(-2400.0, -1600.0)
	bg.size = Vector2(4800.0, 3200.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Anim Lab — Valentina v2 (8 Direcciones)"
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_play_btn = Button.new()
	_play_btn.text = "Pausar (Espacio)"
	_play_btn.pressed.connect(_toggle_play)
	hbox.add_child(_play_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reiniciar (R)"
	reset_btn.pressed.connect(_reset_pose)
	hbox.add_child(reset_btn)

	_mode_btn = OptionButton.new()
	_mode_btn.add_item("Huesos + 2.5D Limpio", AnimMode.COMBINED_BONES_AND_25D)
	_mode_btn.add_item("Solo Huesos (Skeleton2D)", AnimMode.BONES_ONLY)
	_mode_btn.add_item("Solo Shader 2.5D", AnimMode.SHADER_25D_ONLY)
	_mode_btn.item_selected.connect(func(idx: int) -> void:
		_mode = idx
		_apply_all_poses()
	)
	vbox.add_child(_mode_btn)

	var amp_row := HBoxContainer.new()
	vbox.add_child(amp_row)
	var amp_lbl := Label.new()
	amp_lbl.text = "Amplitud:"
	amp_row.add_child(amp_lbl)

	_amp_slider = HSlider.new()
	_amp_slider.min_value = 0.25
	_amp_slider.max_value = 2.0
	_amp_slider.step = 0.05
	_amp_slider.value = 1.0
	_amp_slider.custom_minimum_size = Vector2(160.0, 20.0)
	_amp_slider.value_changed.connect(func(val: float) -> void:
		_amp_scale = val
		_apply_all_poses()
	)
	amp_row.add_child(_amp_slider)

	_head_btn = CheckBox.new()
	_head_btn.text = "Rotar cabezas válidas"
	_head_btn.button_pressed = true
	_head_btn.toggled.connect(func(v: bool) -> void: _head_cycle_enabled = v)
	vbox.add_child(_head_btn)

	var out_sep := HSeparator.new()
	vbox.add_child(out_sep)

	var out_row := HBoxContainer.new()
	out_row.add_theme_constant_override("separation", 8)
	vbox.add_child(out_row)

	var out_chk := CheckBox.new()
	out_chk.text = "Outline Interno"
	out_chk.button_pressed = _outline_enabled
	out_chk.toggled.connect(func(v: bool) -> void:
		_outline_enabled = v
		_apply_all_poses()
	)
	out_row.add_child(out_chk)

	var head_out_chk := CheckBox.new()
	head_out_chk.text = "Cabeza"
	head_out_chk.button_pressed = _outline_on_head
	head_out_chk.toggled.connect(func(v: bool) -> void:
		_outline_on_head = v
		_apply_all_poses()
	)
	out_row.add_child(head_out_chk)

	var center_out_chk := CheckBox.new()
	center_out_chk.text = "Centrado"
	center_out_chk.button_pressed = _outline_centered
	center_out_chk.toggled.connect(func(v: bool) -> void:
		_outline_centered = v
		_apply_all_poses()
	)
	out_row.add_child(center_out_chk)

	var col_btn := ColorPickerButton.new()
	col_btn.color = _outline_color
	col_btn.edit_alpha = false
	col_btn.custom_minimum_size = Vector2(36.0, 22.0)
	col_btn.color_changed.connect(func(c: Color) -> void:
		_outline_color = c
		_apply_all_poses()
	)
	out_row.add_child(col_btn)

	var px_row := HBoxContainer.new()
	vbox.add_child(px_row)
	_outline_lbl = Label.new()
	_outline_lbl.text = "Grosor: %.2f px" % _outline_px
	px_row.add_child(_outline_lbl)

	var px_slider := HSlider.new()
	px_slider.min_value = 0.25
	px_slider.max_value = 3.5
	px_slider.step = 0.05
	px_slider.value = _outline_px
	px_slider.custom_minimum_size = Vector2(150.0, 20.0)
	px_slider.value_changed.connect(func(val: float) -> void:
		_outline_px = val
		if _outline_lbl != null:
			_outline_lbl.text = "Grosor: %.2f px" % _outline_px
		_apply_all_poses()
	)
	px_row.add_child(px_slider)

	_readout_label = Label.new()
	_readout_label.text = ""
	vbox.add_child(_readout_label)
