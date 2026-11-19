class_name PlanarRigMaterialController
extends RefCounted
## Controlador centralizado de ShaderMaterials para PlanarCombatRig.
## Aplica perfiles de estilo, skins, pelo, iluminación 2.5D y hit_flash.

const DEFAULT_OUTER_OUTLINE_WIDTH_PX: float = 0.65
const DEFAULT_OUTER_OUTLINE_STRENGTH: float = 0.0
const BASE_OUTER_OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)

var materials: Array[ShaderMaterial] = []
var pass2_material: ShaderMaterial = null
var current_accent_color: Color = Color(0.86, 0.18, 0.32, 1.0)
var current_light_dir_2d: Vector2 = Vector2(-0.58, -0.81).normalized()
var current_zoom_scale: float = 1.0
var _banking_tilt: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0


func clear() -> void:
	materials.clear()
	pass2_material = null
	_banking_tilt = Vector2.ZERO
	_hit_flash = 0.0


func _compute_lit_outline_color(accent: Color) -> Color:
	return BASE_OUTER_OUTLINE_COLOR.lerp(accent.darkened(0.62), 0.42)


func set_pass2_material(mat: ShaderMaterial) -> void:
	pass2_material = mat
	if pass2_material != null:
		pass2_material.set_shader_parameter("smear_tint", current_accent_color)
		pass2_material.set_shader_parameter("light_dir_2d", current_light_dir_2d)
		pass2_material.set_shader_parameter("zoom_scale", current_zoom_scale)
		pass2_material.set_shader_parameter("enable_outer_outline", true)
		pass2_material.set_shader_parameter("outer_outline_width_px", DEFAULT_OUTER_OUTLINE_WIDTH_PX)
		pass2_material.set_shader_parameter("outer_outline_strength", DEFAULT_OUTER_OUTLINE_STRENGTH)
		pass2_material.set_shader_parameter("outer_outline_color", BASE_OUTER_OUTLINE_COLOR)
		pass2_material.set_shader_parameter("outer_outline_lit_color", _compute_lit_outline_color(current_accent_color))
		pass2_material.set_shader_parameter("outer_outline_tint_mix", 0.0)


func set_pass2_zoom_scale(zoom_scale: float) -> void:
	current_zoom_scale = clampf(zoom_scale, 0.35, 4.0)
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("zoom_scale", current_zoom_scale)
	if pass2_material != null:
		pass2_material.set_shader_parameter("zoom_scale", current_zoom_scale)


func set_q_time(q_time: float) -> void:
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("q_time", q_time)
	if pass2_material != null:
		pass2_material.set_shader_parameter("q_time", q_time)


func set_outer_outline_params(enabled: bool, width_px: float, strength: float) -> void:
	if pass2_material == null:
		return
	pass2_material.set_shader_parameter("enable_outer_outline", enabled)
	pass2_material.set_shader_parameter("outer_outline_width_px", clampf(width_px, 0.0, 8.0))
	pass2_material.set_shader_parameter("outer_outline_strength", clampf(strength, 0.0, 1.0))


func set_pass2_impact_phase(phase: int) -> void:
	if pass2_material != null:
		pass2_material.set_shader_parameter("impact_frame_phase", clampi(phase, 0, 2))


func set_pass2_impact_center_uv(center_uv: Vector2) -> void:
	if pass2_material != null:
		pass2_material.set_shader_parameter("impact_center_uv", center_uv)


func update_pass2_transition_fx(smear_str: float, smear_dir: Vector2, holo_pos: float, holo_str: float, holo_dir: Vector2) -> void:
	if pass2_material == null:
		return
	pass2_material.set_shader_parameter("smear_strength", smear_str)
	pass2_material.set_shader_parameter("smear_dir", smear_dir)
	pass2_material.set_shader_parameter("smear_tint", current_accent_color)
	pass2_material.set_shader_parameter("holo_sweep_pos", holo_pos)
	pass2_material.set_shader_parameter("holo_sweep_strength", holo_str)
	pass2_material.set_shader_parameter("holo_sweep_dir", holo_dir)


func add_materials(mats: Array) -> void:
	for m: Variant in mats:
		if m is ShaderMaterial:
			materials.append(m as ShaderMaterial)


func apply_skin_preset(skin: PilotSkinPreset) -> Color:
	if skin == null:
		return current_accent_color
	current_accent_color = skin.accent_color
	var enable_recolor: bool = not skin.is_base_skin
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("enable_shader_recolor", enable_recolor)
		mat.set_shader_parameter("enable_hair_recolor", enable_recolor)
		mat.set_shader_parameter("accent_color", skin.accent_color)
		mat.set_shader_parameter("panel_color", skin.panel_color)
		mat.set_shader_parameter("suit_dark_color", skin.suit_dark_color)
		mat.set_shader_parameter("hair_color", skin.hair_color)
	if pass2_material != null:
		pass2_material.set_shader_parameter("smear_tint", current_accent_color)
		pass2_material.set_shader_parameter("outer_outline_lit_color", _compute_lit_outline_color(current_accent_color))
	return current_accent_color


func apply_hair_preset(hair: PilotHairPreset, skin_hair_col: Color) -> void:
	if hair == null:
		return
	var h_col: Color = hair.hair_color if hair.override_color else skin_hair_col
	var h_sec: Color = hair.hair_secondary_color if hair.override_color else current_accent_color
	var enable_h: bool = hair.override_color or hair.follow_skin_hair
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("enable_hair_recolor", enable_h)
		mat.set_shader_parameter("hair_color", h_col)
		mat.set_shader_parameter("hair_secondary_color", h_sec)


func apply_style_profile(profile: RigStyleProfile) -> void:
	if profile == null:
		return
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("pipeline_style_mode", profile.pipeline_mode)
		mat.set_shader_parameter("enable_halftone", profile.enable_halftone)
		mat.set_shader_parameter("halftone_pattern_type", profile.halftone_pattern_type)
		mat.set_shader_parameter("halftone_zone_mode", profile.halftone_zone_mode)
		mat.set_shader_parameter("halftone_scale", profile.halftone_scale)
		mat.set_shader_parameter("halftone_strength", profile.halftone_strength)
		mat.set_shader_parameter("halftone_angle_deg", profile.halftone_angle_deg)
		mat.set_shader_parameter("halftone_threshold", profile.halftone_threshold)
		mat.set_shader_parameter("ink_boost", profile.ink_boost)
		mat.set_shader_parameter("cel_step_strength", profile.cel_step_strength)
		mat.set_shader_parameter("noir_shadow_crush", profile.noir_shadow_crush)
		mat.set_shader_parameter("noir_shadow_threshold", profile.noir_shadow_threshold)
		mat.set_shader_parameter("metal_sheen_strength", profile.metal_sheen_strength)
		mat.set_shader_parameter("rim_light_strength", profile.rim_light_strength)
		mat.set_shader_parameter("rim_width_px", profile.rim_width_px)
		mat.set_shader_parameter("dual_rim_strength", profile.dual_rim_strength)
		mat.set_shader_parameter("glow_intensity", profile.glow_intensity)
	if pass2_material != null:
		pass2_material.set_shader_parameter("outer_outline_tint_mix", clampf(profile.outer_outline_tint_mix, 0.0, 1.0))


func set_hair_style_mode(mode_idx: int) -> void:
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("hair_style_mode", mode_idx)


func set_recolor_method(method_idx: int) -> void:
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("recolor_method", method_idx)


func set_shader_param_all(param_name: String, value: Variant) -> void:
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter(param_name, value)


func set_debug_view_mode(mode_idx: int) -> void:
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("debug_view_mode", mode_idx)


func set_normal_depth_options(enabled: bool, light_dir: Vector2, rim_str: float, hdr_boost: float) -> void:
	var n_dir: Vector2 = light_dir.normalized() if light_dir.length_squared() > 0.0001 else Vector2(-0.58, -0.81).normalized()
	current_light_dir_2d = n_dir
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("use_normal_depth", enabled)
		mat.set_shader_parameter("light_dir_2d", n_dir)
		mat.set_shader_parameter("normal_rim_strength", rim_str)
		mat.set_shader_parameter("crt_hdr_boost", hdr_boost)
	if pass2_material != null:
		pass2_material.set_shader_parameter("light_dir_2d", n_dir)


func set_hit_flash(amount: float) -> void:
	_hit_flash = clampf(amount, 0.0, 1.0)
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("hit_flash", _hit_flash)


func get_hit_flash() -> float:
	return _hit_flash


func update_motion_uniforms(delta: float, move_dir: Vector2, speed_norm: float, auto_decay_flash: bool = true) -> void:
	var target_bank := Vector2(move_dir.x, move_dir.y) * speed_norm
	_banking_tilt = _banking_tilt.lerp(target_bank, minf(1.0, delta * 9.0))
	if auto_decay_flash and _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 6.5)
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("banking_tilt_2d", _banking_tilt)
		if auto_decay_flash:
			mat.set_shader_parameter("hit_flash", _hit_flash)
