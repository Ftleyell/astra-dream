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
var _current_style: RigStyleProfile = null
var _banking_tilt: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0


func clear() -> void:
	materials.clear()
	pass2_material = null
	_current_style = null
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
		pass2_material.set_shader_parameter("outline_min_px", 0.48)
		pass2_material.set_shader_parameter("outline_max_px", 1.15)
		pass2_material.set_shader_parameter("outer_outline_strength", DEFAULT_OUTER_OUTLINE_STRENGTH)
		pass2_material.set_shader_parameter("outer_outline_color", BASE_OUTER_OUTLINE_COLOR)
		pass2_material.set_shader_parameter("outer_outline_lit_color", _compute_lit_outline_color(current_accent_color))
		pass2_material.set_shader_parameter("outer_outline_tint_mix", 0.0)
		pass2_material.set_shader_parameter("outline_calligraphy_amount", 0.65)
		pass2_material.set_shader_parameter("outline_crispness", 0.42)
		pass2_material.set_shader_parameter("outline_inward_replace", 0.12)
		pass2_material.set_shader_parameter("ign_jitter_strength", 0.0)
		pass2_material.set_shader_parameter("silhouette_rim_strength", 0.0)
		pass2_material.set_shader_parameter("silhouette_rim_width_px", 1.45)
		pass2_material.set_shader_parameter("counter_rim_strength", 0.0)
		pass2_material.set_shader_parameter("rim_key_color", Color(0.94, 0.97, 1.0, 1.0))
		pass2_material.set_shader_parameter("rim_counter_color", current_accent_color)
		pass2_material.set_shader_parameter("hdr_light_wrap_strength", 0.0)
		pass2_material.set_shader_parameter("hdr_threshold", 1.05)
		pass2_material.set_shader_parameter("cas_sharpen_strength", 0.0)


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
		if _current_style == null or _current_style.counter_rim_use_skin_accent:
			pass2_material.set_shader_parameter("rim_counter_color", current_accent_color)
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
	_current_style = profile
	for mat: ShaderMaterial in materials:
		mat.set_shader_parameter("stylize_enabled", profile.stylize_enabled)
		mat.set_shader_parameter("use_normal_depth", profile.use_normal_depth)
		mat.set_shader_parameter("cel_strength", profile.cel_strength)
		mat.set_shader_parameter("cel_threshold", profile.cel_threshold)
		mat.set_shader_parameter("cel_softness", profile.cel_softness)
		mat.set_shader_parameter("cel_mid_band_strength", profile.cel_mid_band_strength)
		mat.set_shader_parameter("albedo_de_shade", profile.albedo_de_shade)
		mat.set_shader_parameter("ilm_shadow_bias_strength", profile.ilm_shadow_bias_strength)
		mat.set_shader_parameter("ilm_ao_strength", profile.ilm_ao_strength)
		mat.set_shader_parameter("face_shadow_protect", profile.face_shadow_protect)
		mat.set_shader_parameter("key_light_tint", profile.key_light_tint)
		mat.set_shader_parameter("shadow_tint", profile.shadow_tint)
		mat.set_shader_parameter("ao_tint", profile.ao_tint)
		mat.set_shader_parameter("skin_shadow_tint", profile.skin_shadow_tint)
		mat.set_shader_parameter("sss_skin_color", profile.sss_skin_color)
		mat.set_shader_parameter("sss_strength", profile.sss_strength)
		mat.set_shader_parameter("color_contrast", profile.color_contrast)
		mat.set_shader_parameter("color_saturation", profile.color_saturation)
		mat.set_shader_parameter("key_light_boost", profile.key_light_boost)
		mat.set_shader_parameter("armor_spec_strength", profile.armor_spec_strength)
		mat.set_shader_parameter("armor_spec_threshold", profile.armor_spec_threshold)
		mat.set_shader_parameter("suit_satin_strength", profile.suit_satin_strength)
		mat.set_shader_parameter("nylon_sheen_strength", profile.nylon_sheen_strength)
		mat.set_shader_parameter("stocking_denier", profile.stocking_denier)
		mat.set_shader_parameter("hair_angel_ring_strength", profile.hair_angel_ring_strength)
		mat.set_shader_parameter("emissive_glow_strength", profile.emissive_glow_strength)
		mat.set_shader_parameter("crt_hdr_boost", profile.hdr_cap)
		mat.set_shader_parameter("albedo_lod_bias_offset", clampf(profile.albedo_lod_bias, -1.5, 0.5))
		mat.set_shader_parameter("ink_strength", profile.ink_strength)
		mat.set_shader_parameter("ink_color_tint_mix", profile.ink_color_tint_mix)
		mat.set_shader_parameter("ink_skin_tint", profile.ink_skin_tint)
		mat.set_shader_parameter("ink_cool_tint", profile.ink_cool_tint)
		mat.set_shader_parameter("ink_sdf_bias_px", profile.ink_sdf_bias_px)
		mat.set_shader_parameter("ink_sdf_softness", profile.ink_sdf_softness)
		mat.set_shader_parameter("normal_rim_strength", profile.normal_rim_strength)
		mat.set_shader_parameter("counter_rim_strength", profile.counter_rim_strength)
		mat.set_shader_parameter("rim_key_color", profile.rim_key_color)
		mat.set_shader_parameter("counter_rim_use_skin_accent", profile.counter_rim_use_skin_accent)
		mat.set_shader_parameter("counter_rim_override_color", profile.counter_rim_override_color)
	if pass2_material != null:
		var ctr_col: Color = current_accent_color if profile.counter_rim_use_skin_accent else profile.counter_rim_override_color
		pass2_material.set_shader_parameter("enable_outer_outline", profile.enable_outer_outline)
		pass2_material.set_shader_parameter("outer_outline_width_px", clampf(profile.outer_outline_width_px, 0.0, 8.0))
		pass2_material.set_shader_parameter("outline_min_px", clampf(profile.outline_min_px, 0.1, 4.0))
		pass2_material.set_shader_parameter("outline_max_px", clampf(profile.outline_max_px, 0.2, 8.0))
		pass2_material.set_shader_parameter("outer_outline_strength", clampf(profile.outer_outline_strength, 0.0, 1.0))
		pass2_material.set_shader_parameter("outer_outline_tint_mix", clampf(profile.outer_outline_tint_mix, 0.0, 1.0))
		pass2_material.set_shader_parameter("outline_calligraphy_amount", clampf(profile.outline_calligraphy_amount, 0.0, 1.0))
		pass2_material.set_shader_parameter("outline_crispness", clampf(profile.outline_crispness, 0.05, 1.0))
		pass2_material.set_shader_parameter("outline_inward_replace", clampf(profile.outline_inward_replace, 0.0, 1.0))
		pass2_material.set_shader_parameter("ign_jitter_strength", clampf(profile.ign_jitter_strength, 0.0, 1.0))
		pass2_material.set_shader_parameter("outer_outline_color", profile.outer_outline_color)
		pass2_material.set_shader_parameter("silhouette_rim_strength", profile.silhouette_rim_strength)
		pass2_material.set_shader_parameter("silhouette_rim_width_px", profile.silhouette_rim_width_px)
		pass2_material.set_shader_parameter("counter_rim_strength", profile.counter_rim_strength)
		pass2_material.set_shader_parameter("rim_key_color", profile.rim_key_color)
		pass2_material.set_shader_parameter("rim_counter_color", ctr_col)
		pass2_material.set_shader_parameter("hdr_light_wrap_strength", profile.hdr_light_wrap_strength)
		pass2_material.set_shader_parameter("hdr_threshold", profile.hdr_threshold)
		pass2_material.set_shader_parameter("cas_sharpen_strength", clampf(profile.cas_sharpen_strength, 0.0, 1.0))


func set_pass2_param(param_name: String, value: Variant) -> void:
	if pass2_material != null:
		pass2_material.set_shader_parameter(param_name, value)


func get_current_style_profile() -> RigStyleProfile:
	return _current_style


func get_shader_param(param_name: String, fallback: Variant = null) -> Variant:
	if materials.is_empty():
		return fallback
	return materials[0].get_shader_parameter(param_name)


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
