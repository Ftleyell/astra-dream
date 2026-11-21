class_name PilotLiveBannerController
extends Node2D
## Controlador reutilizable de Live Banner 2.5D para Selección de Personajes.
## Gestiona el shader orgánico por máscaras (respiración, cabello, parpadeo, parallax 2.5D,
## rim-light, recolor de skins), física de resorte en hover/mouse y atmósfera orbital de fondo.

const BannerShader = preload("res://sandbox/pilot_rig_lab/banner_lab/pilot_live_banner.gdshader")
const Pass2Shader = preload("res://sandbox/pilot_rig_lab/pilot_rig_pass2.gdshader")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_live_banner_config.gd")

const STAR_COUNT: int = 34
const TARGET_BANNER_HEIGHT_PX: float = 640.0


class _BackdropFX extends Node2D:
	var controller: PilotLiveBannerController = null
	var is_foreground: bool = false

	func _draw() -> void:
		if controller != null:
			controller.draw_atmosphere(self, is_foreground)


var _config: ConfigScript = null
var _bg_fx: _BackdropFX = null
var _wings_root: Node2D = null
var _wing_shards: Array[Dictionary] = []
var _fg_fx: _BackdropFX = null
var _unified_group: CanvasGroup = null
var _pass2_material: ShaderMaterial = null
var _character_root: Node2D = null
var _banner_sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _free_arm_pivot: Node2D = null
var _free_arm_sprite: Sprite2D = null
var _arm_material: ShaderMaterial = null
var _arm_pivot_local: Vector2 = Vector2.ZERO

var _anim_time: float = 0.0
var _mouse_target: Vector2 = Vector2.ZERO
var _mouse_smooth: Vector2 = Vector2.ZERO
var _prev_mouse_smooth: Vector2 = Vector2.ZERO
var _auto_mouse_demo: bool = false

var _jiggle_pos: Vector2 = Vector2.ZERO
var _jiggle_vel: Vector2 = Vector2.ZERO

var _blink_timer: float = 3.2
var _blink_phase: float = -1.0 # < 0: abierto, [0..1]: ciclo de parpadeo
var _blink_amount: float = 0.0

var _is_selected: bool = false
var _select_elapsed: float = 0.0
var _impact_frame_phase: int = 0
var _wings_deploy: float = 0.0
var _wings_light_intensity: float = 0.0
var _hair_burst_lift: float = 0.0
var _hair_burst_vel: float = 0.0
var _shockwave_t: float = 1.0

var _debug_view_mode: int = 0
var _base_scale: float = 0.5
var _stars: Array[Dictionary] = []


func _ready() -> void:
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()
	_init_stars()
	_build_nodes()
	reload_textures_from_config()
	_load_psychic_wings()
	_push_shader_params()


func set_config(cfg: ConfigScript) -> void:
	_config = cfg if cfg != null else ConfigScript.new()
	_config.ensure_defaults()
	if is_inside_tree():
		reload_textures_from_config()
		_push_shader_params()


func get_config() -> ConfigScript:
	return _config


func get_banner_sprite() -> Sprite2D:
	return _banner_sprite


func get_character_root() -> Node2D:
	return _character_root


func get_unified_group() -> CanvasGroup:
	return _unified_group


func get_blink_amount() -> float:
	return _blink_amount


func get_jiggle_offset() -> Vector2:
	return _jiggle_pos


func is_pilot_selected() -> bool:
	return _is_selected


func get_impact_frame_phase() -> int:
	return _impact_frame_phase


func get_wings_deploy() -> float:
	return _wings_deploy


func get_wing_shard_count() -> int:
	return _wing_shards.size()


func trigger_select_sequence() -> void:
	_is_selected = true
	_select_elapsed = 0.0
	_impact_frame_phase = 1
	_wings_deploy = 0.0
	_wings_light_intensity = 1.65
	_hair_burst_lift = 0.0
	_hair_burst_vel = 9.5 # Impulso ascendente snappy en los pelos al abrirse las alas
	_shockwave_t = 0.0
	trigger_hover_impulse(0.85)
	_push_shader_params()


func reset_select_sequence() -> void:
	_is_selected = false
	_select_elapsed = 0.0
	_impact_frame_phase = 0
	_wings_deploy = 0.0
	_wings_light_intensity = 0.0
	_hair_burst_lift = 0.0
	_hair_burst_vel = 0.0
	_shockwave_t = 1.0
	_update_wings(0.0)
	_push_shader_params()


func set_mouse_normalized(norm_pos: Vector2) -> void:
	_mouse_target = Vector2(clampf(norm_pos.x, -1.0, 1.0), clampf(norm_pos.y, -1.0, 1.0))


func set_auto_mouse_demo(enabled: bool) -> void:
	_auto_mouse_demo = enabled


func set_debug_view_mode(mode_idx: int) -> void:
	_debug_view_mode = clampi(mode_idx, 0, 5)
	for m: ShaderMaterial in [_material, _arm_material]:
		if m != null:
			m.set_shader_parameter("debug_view_mode", _debug_view_mode)


func set_zoom_scale(zoom_scale: float) -> void:
	if _pass2_material != null:
		_pass2_material.set_shader_parameter("zoom_scale", clampf(zoom_scale, 0.35, 4.0))


func trigger_blink() -> void:
	_blink_phase = 0.0


func trigger_hover_impulse(strength: float = 1.0) -> void:
	if _config == null:
		return
	var amp: float = _config.hover_jiggle_amp * strength
	_jiggle_vel += Vector2(amp * 4.5, -amp * 14.0)


func apply_skin_preset(skin: PilotSkinPreset) -> void:
	var mats: Array[ShaderMaterial] = [_material, _arm_material]
	for m: ShaderMaterial in mats:
		if m == null:
			continue
		if skin == null or skin.is_base_skin:
			m.set_shader_parameter("skin_recolor_enabled", false)
		else:
			m.set_shader_parameter("skin_recolor_enabled", true)
			m.set_shader_parameter("skin_accent_color", skin.accent_color)
			m.set_shader_parameter("skin_hair_color", skin.hair_color)
	if _pass2_material != null:
		var counter_col: Color = Color(1.0, 0.18, 0.34, 1.0) if (skin == null or skin.is_base_skin) else skin.accent_color
		_pass2_material.set_shader_parameter("rim_counter_color", counter_col)


func reload_textures_from_config() -> void:
	if _config == null or _banner_sprite == null or _material == null:
		return

	var base_tex: Texture2D = _load_tex(_config.base_texture_path)
	if base_tex != null:
		_banner_sprite.texture = base_tex
		var sz: Vector2 = base_tex.get_size()
		var h: float = maxf(sz.y, 1.0)
		_base_scale = TARGET_BANNER_HEIGHT_PX / h
		if _character_root != null:
			_character_root.scale = Vector2(_base_scale, _base_scale)
		_arm_pivot_local = Vector2((_config.right_shoulder_uv.x - 0.5) * sz.x, (_config.right_shoulder_uv.y - 0.5) * sz.y)

	var arm_tex: Texture2D = _load_tex(_config.free_arm_texture_path)
	if _free_arm_pivot != null and _free_arm_sprite != null:
		_free_arm_pivot.visible = (arm_tex != null)
		if arm_tex != null:
			_free_arm_sprite.texture = arm_tex
			_free_arm_pivot.position = _arm_pivot_local
			_free_arm_sprite.position = -_arm_pivot_local

	var m_tex: Texture2D = _load_tex(_config.motion_mask_path)
	var fx_tex: Texture2D = _load_tex(_config.fx_mask_path)
	var d_tex: Texture2D = _load_tex(_config.depth_map_path)
	var n_tex: Texture2D = _load_tex(_config.normal_map_path)
	var ink_tex: Texture2D = _load_tex(_config.ink_sdf_path, true)
	for m: ShaderMaterial in [_material, _arm_material]:
		if m == null:
			continue
		m.set_shader_parameter("has_motion_mask", m_tex != null)
		if m_tex != null:
			m.set_shader_parameter("motion_mask", m_tex)
		m.set_shader_parameter("has_fx_mask", fx_tex != null)
		if fx_tex != null:
			m.set_shader_parameter("fx_mask", fx_tex)
		m.set_shader_parameter("has_depth_map", d_tex != null)
		if d_tex != null:
			m.set_shader_parameter("depth_map", d_tex)
		m.set_shader_parameter("has_normal_map", n_tex != null)
		if n_tex != null:
			m.set_shader_parameter("normal_map", n_tex)
		m.set_shader_parameter("has_ink_sdf", ink_tex != null)
		if ink_tex != null:
			m.set_shader_parameter("ink_sdf", ink_tex)


func step(delta: float) -> void:
	if _config == null or _banner_sprite == null:
		return
	_anim_time += delta

	# Coreografía Idle autónoma 2.5D (siempre se ve fluida y compuesta sin seguir el mouse)
	var desired_view := Vector2(
		sin(_anim_time * 0.62) * 0.42,
		sin(_anim_time * 1.24 - 0.6) * 0.24
	)
	if _auto_mouse_demo:
		desired_view = _mouse_target

	_prev_mouse_smooth = _mouse_smooth
	var m_lerp: float = 1.0 - exp(-_config.mouse_smooth_rate * delta)
	_mouse_smooth = _mouse_smooth.lerp(desired_view, m_lerp)

	# Física de resorte 2D para micro-jiggle orgánico (impulsos de hover/selección + micro-pulso respiratorio)
	var spring_acc: Vector2 = -_jiggle_pos * _config.jiggle_stiffness - _jiggle_vel * _config.jiggle_damping
	_jiggle_vel += spring_acc * delta
	_jiggle_pos += _jiggle_vel * delta
	var max_jig: float = maxf(0.002, _config.hover_jiggle_amp * 2.2)
	if _jiggle_pos.length() > max_jig:
		_jiggle_pos = _jiggle_pos.normalized() * max_jig

	# Temporizador natural de parpadeo
	if _config.blink_enabled:
		if _blink_phase < 0.0:
			_blink_timer -= delta
			if _blink_timer <= 0.0:
				_blink_phase = 0.0
				_blink_timer = lerpf(_config.blink_interval_min_sec, _config.blink_interval_max_sec, fmod(absf(sin(_anim_time * 13.7)), 1.0))
		else:
			_blink_phase += delta / maxf(_config.blink_duration_sec, 0.05)
			if _blink_phase >= 1.0:
				_blink_phase = -1.0
				_blink_amount = 0.0
			else:
				_blink_amount = sin(_blink_phase * PI)
	else:
		_blink_phase = -1.0
		_blink_amount = 0.0

	# Secuencia "Elegir Piloto": 2-phase Impact Frames + despliegue firme de Alas Psíquicas
	var punch_scale: float = 1.0
	var shake_off := Vector2.ZERO
	if _is_selected:
		_select_elapsed += delta
		var t1: float = maxf(0.02, _config.impact_frame_1_sec)
		var t2: float = t1 + maxf(0.02, _config.impact_frame_2_sec)
		if _select_elapsed < t1:
			_impact_frame_phase = 1
			punch_scale = 1.055
			shake_off = Vector2(sin(_select_elapsed * 210.0) * 6.0, cos(_select_elapsed * 180.0) * 4.5)
		elif _select_elapsed < t2:
			_impact_frame_phase = 2
			punch_scale = 1.04
			shake_off = Vector2(cos(_select_elapsed * 240.0) * 4.0, sin(_select_elapsed * 190.0) * 3.5)
		else:
			_impact_frame_phase = 0
			var settle_t: float = clampf((_select_elapsed - t2) / 0.28, 0.0, 1.0)
			punch_scale = lerpf(1.035, 1.015, 1.0 - pow(1.0 - settle_t, 3.0))

		var dep_dur: float = maxf(0.12, _config.wings_deploy_duration_sec)
		_wings_deploy = clampf((_select_elapsed - t1 * 0.5) / dep_dur, 0.0, 1.0)
		_shockwave_t = clampf(_select_elapsed / 0.48, 0.0, 1.0)
		# Luz roja emitida por las alas: explosión inicial (1.75) que asienta en halo carmesí vivo (0.88 + pulso)
		var steady_light: float = 0.85 + 0.14 * sin(_anim_time * 3.2)
		var burst_light: float = (1.0 - _shockwave_t) * 1.10
		_wings_light_intensity = clampf(_wings_deploy * steady_light + burst_light, 0.0, 2.2)
	else:
		_impact_frame_phase = 0
		_wings_deploy = 0.0
		_wings_light_intensity = 0.0
		_shockwave_t = 1.0

	# Resorte de viento ascendente en el cabello al abrirse las alas (salta hacia arriba y cae suave)
	var hair_acc: float = -_hair_burst_lift * 28.0 - _hair_burst_vel * 5.2
	_hair_burst_vel += hair_acc * delta
	_hair_burst_lift = clampf(_hair_burst_lift + _hair_burst_vel * delta, -0.25, 1.35)
	if absf(_hair_burst_lift) < 0.002 and absf(_hair_burst_vel) < 0.002:
		_hair_burst_lift = 0.0
		_hair_burst_vel = 0.0

	# Flotación Zero-G + inclinación sutil + punch de selección aplicados al nodo unificado (cuerpo + brazo)
	var bob_y: float = sin(_anim_time * _config.float_bob_speed) * _config.float_bob_amp_px
	if _character_root != null:
		_character_root.position = Vector2(_mouse_smooth.x * 5.0, bob_y + _mouse_smooth.y * 3.0) + shake_off
		_character_root.rotation = deg_to_rad(_mouse_smooth.x * _config.mouse_tilt_deg)
		_character_root.scale = Vector2(_base_scale * punch_scale, _base_scale * punch_scale)
	# Mantener compatibilidad de tests que leen rotación del sprite principal
	_banner_sprite.rotation = 0.0

	# Animación 2.5D limpia del brazo libre (pivote 100% FIJO bajo la hombrera — NUNCA se separa!)
	var arm_phase: float = sin(_anim_time * _config.arm_sway_speed + _config.arm_sway_phase_offset)
	if _free_arm_pivot != null and _free_arm_pivot.visible:
		var persp_x: float = 1.0 + arm_phase * _config.arm_persp_scale_amp
		var persp_y: float = 1.0 + arm_phase * (_config.arm_persp_scale_amp * 0.65)
		_free_arm_pivot.position = _arm_pivot_local
		_free_arm_pivot.scale = Vector2(persp_x, persp_y)
		_free_arm_pivot.rotation = deg_to_rad(arm_phase * 2.0)
	if _arm_material != null:
		_arm_material.set_shader_parameter("arm_depth_shade", arm_phase * _config.arm_depth_shade_amp)

	_update_wings(bob_y)
	_push_shader_params()

	if _bg_fx != null:
		_bg_fx.queue_redraw()
	if _fg_fx != null:
		_fg_fx.queue_redraw()


func _build_nodes() -> void:
	_bg_fx = _BackdropFX.new()
	_bg_fx.name = "BannerBackdropFX"
	_bg_fx.controller = self
	_bg_fx.is_foreground = false
	_bg_fx.z_index = 1
	add_child(_bg_fx)

	_wings_root = Node2D.new()
	_wings_root.name = "PsychicWingsRoot"
	_wings_root.z_index = 3
	add_child(_wings_root)

	# CanvasGroup unificado con pilot_rig_pass2.gdshader (EXACTO al rig de combate — Invariante: hijos z_index = 0!)
	_unified_group = CanvasGroup.new()
	_unified_group.name = "UnifiedBannerGroup"
	_unified_group.z_index = 5
	_unified_group.fit_margin = 24.0
	_unified_group.clear_margin = 24.0
	_pass2_material = ShaderMaterial.new()
	_pass2_material.shader = Pass2Shader
	_pass2_material.set_shader_parameter("enable_outer_outline", true)
	_pass2_material.set_shader_parameter("outer_outline_width_px", 0.65)
	_pass2_material.set_shader_parameter("outer_outline_strength", 0.72)
	_pass2_material.set_shader_parameter("outer_outline_tint_mix", 0.82)
	_pass2_material.set_shader_parameter("outline_calligraphy_amount", 0.62)
	_pass2_material.set_shader_parameter("outline_crispness", 0.45)
	_pass2_material.set_shader_parameter("outline_inward_replace", 0.08)
	_pass2_material.set_shader_parameter("outer_outline_color", Color(0.045, 0.040, 0.095, 1.0))
	_pass2_material.set_shader_parameter("seam_weld_radius_px", 1.25)
	_pass2_material.set_shader_parameter("cas_sharpen_strength", 0.28)
	_pass2_material.set_shader_parameter("silhouette_rim_strength", 0.32)
	_pass2_material.set_shader_parameter("silhouette_rim_width_px", 1.35)
	_pass2_material.set_shader_parameter("rim_key_color", Color(0.87, 0.95, 1.0, 1.0))
	_pass2_material.set_shader_parameter("rim_counter_color", Color(1.0, 0.18, 0.34, 1.0))
	_pass2_material.set_shader_parameter("counter_rim_strength", 0.0)
	_pass2_material.set_shader_parameter("hdr_light_wrap_strength", 0.04)
	_unified_group.material = _pass2_material
	add_child(_unified_group)

	_character_root = Node2D.new()
	_character_root.name = "BannerCharacterRoot"
	_character_root.z_index = 0
	_unified_group.add_child(_character_root)

	# Hijo 0: brazo libre detrás del cuerpo por orden de árbol (z_index = 0 obligatorio bajo CanvasGroup)
	_free_arm_pivot = Node2D.new()
	_free_arm_pivot.name = "FreeArmPivot"
	_free_arm_pivot.z_index = 0
	_character_root.add_child(_free_arm_pivot)

	_free_arm_sprite = Sprite2D.new()
	_free_arm_sprite.name = "FreeArmSprite"
	_free_arm_sprite.centered = true
	_free_arm_sprite.z_index = 0
	_arm_material = ShaderMaterial.new()
	_arm_material.shader = BannerShader
	_arm_material.set_shader_parameter("is_arm_layer", true)
	_free_arm_sprite.material = _arm_material
	_free_arm_pivot.add_child(_free_arm_sprite)

	# Hijo 1: cuerpo con hombrera estática ENCIMA de la bisagra del brazo (z_index = 0)
	_banner_sprite = Sprite2D.new()
	_banner_sprite.name = "LiveBannerSprite"
	_banner_sprite.centered = true
	_banner_sprite.z_index = 0
	_material = ShaderMaterial.new()
	_material.shader = BannerShader
	_material.set_shader_parameter("is_arm_layer", false)
	_banner_sprite.material = _material
	_character_root.add_child(_banner_sprite)

	_fg_fx = _BackdropFX.new()
	_fg_fx.name = "BannerForegroundFX"
	_fg_fx.controller = self
	_fg_fx.is_foreground = true
	_fg_fx.z_index = 8
	add_child(_fg_fx)


func _push_shader_params() -> void:
	if _config == null:
		return
	for m: ShaderMaterial in [_material, _arm_material]:
		if m == null:
			continue
		m.set_shader_parameter("anim_time", _anim_time)
		m.set_shader_parameter("mouse_offset", _mouse_smooth)
		m.set_shader_parameter("jiggle_offset", _jiggle_pos)
		m.set_shader_parameter("blink_amount", _blink_amount)
		m.set_shader_parameter("chest_center_uv", _config.chest_center_uv)
		m.set_shader_parameter("breath_speed", _config.breath_speed)
		m.set_shader_parameter("breath_expand_amp", _config.breath_expand_amp)
		m.set_shader_parameter("breath_lift_px", _config.breath_lift_px)
		m.set_shader_parameter("hair_sway_speed", _config.hair_sway_speed)
		m.set_shader_parameter("hair_sway_amp_px", _config.hair_sway_amp_px)
		m.set_shader_parameter("hair_wave_freq", _config.hair_wave_freq)
		m.set_shader_parameter("body_sway_speed", _config.body_sway_speed)
		m.set_shader_parameter("body_sway_amp_px", _config.body_sway_amp_px)
		m.set_shader_parameter("wings_light_intensity", _wings_light_intensity)
		m.set_shader_parameter("hair_burst_lift", _hair_burst_lift)
		m.set_shader_parameter("eye_center_uv", _config.eye_center_uv)
		m.set_shader_parameter("eye_glow_boost", _config.eye_glow_boost)
		m.set_shader_parameter("eye_track_amp_px", _config.eye_track_amp_px)
		m.set_shader_parameter("mouse_parallax_strength", _config.mouse_parallax_strength)
		m.set_shader_parameter("rim_light_strength", _config.rim_light_strength)
		m.set_shader_parameter("rim_light_color", _config.rim_light_color)
		m.set_shader_parameter("emissive_pulse_speed", _config.emissive_pulse_speed)
		m.set_shader_parameter("emissive_boost", _config.emissive_boost)
		m.set_shader_parameter("cel_shading_enabled", _config.cel_shading_enabled)
		m.set_shader_parameter("cel_strength", _config.cel_strength)
		m.set_shader_parameter("cel_light_angle_deg", _config.cel_light_angle_deg)
		m.set_shader_parameter("cel_shadow_tint", _config.cel_shadow_tint)
		m.set_shader_parameter("cel_specular_strength", _config.cel_specular_strength)
		m.set_shader_parameter("ink_sdf_enabled", _config.ink_sdf_enabled)
		m.set_shader_parameter("ink_strength", _config.ink_strength)
		m.set_shader_parameter("ink_width_bias", _config.ink_width_bias)
		m.set_shader_parameter("ink_color", _config.ink_color)
		m.set_shader_parameter("debug_view_mode", _debug_view_mode)

	if _pass2_material != null:
		var l_rad: float = deg_to_rad(_config.cel_light_angle_deg)
		_pass2_material.set_shader_parameter("light_dir_2d", Vector2(cos(l_rad), sin(l_rad)).normalized())
		_pass2_material.set_shader_parameter("enable_outer_outline", _debug_view_mode == 0)
		_pass2_material.set_shader_parameter("outer_outline_strength", _config.ink_strength if _debug_view_mode == 0 else 0.0)
		_pass2_material.set_shader_parameter("silhouette_rim_strength", _config.rim_light_strength * 0.52 if _debug_view_mode == 0 else 0.0)
		# Counter-rim asimétrico desactivado en Pass 2; la luz roja simétrica de alas viene de Pass 1
		_pass2_material.set_shader_parameter("counter_rim_strength", 0.0)
		_pass2_material.set_shader_parameter("impact_frame_phase", _impact_frame_phase if _debug_view_mode == 0 else 0)
		_pass2_material.set_shader_parameter("q_time", _anim_time)


func _load_psychic_wings() -> void:
	if _wings_root == null or _config == null:
		return
	for ch: Node in _wings_root.get_children():
		ch.queue_free()
	_wing_shards.clear()

	var dir_path: String = _config.wings_assets_dir
	var meta_path: String = "%s/wings_metadata.json" % dir_path
	var abs_meta: String = ProjectSettings.globalize_path(meta_path)
	if not FileAccess.file_exists(abs_meta):
		return
	var raw_txt: String = FileAccess.get_file_as_string(abs_meta)
	var parsed: Variant = JSON.parse_string(raw_txt)
	if not (parsed is Dictionary):
		return
	var wings_dict: Dictionary = (parsed as Dictionary).get("wings", {}) as Dictionary

	for side_key: String in ["wing_0deg_l", "wing_0deg_r"]:
		var is_right: bool = (side_key == "wing_0deg_r")
		var side_sign: float = 1.0 if is_right else -1.0
		var list_v: Variant = wings_dict.get(side_key, [])
		if not (list_v is Array):
			continue
		var shards_arr: Array = list_v as Array
		for entry_v: Variant in shards_arr:
			if not (entry_v is Dictionary):
				continue
			var entry: Dictionary = entry_v as Dictionary
			var shard_id: String = String(entry.get("id", ""))
			var shard_idx: int = int(entry.get("shard_index", 0))
			var tex_path: String = "%s/%s.png" % [dir_path, shard_id]
			var tex: Texture2D = _load_tex(tex_path)
			if tex == null:
				continue

			var sz_arr: Array = entry.get("size_px", [256, 256]) as Array
			var piv_arr: Array = entry.get("pivot_px", [128.0, 128.0]) as Array
			var rest_arr: Array = entry.get("rest_offset_px", [0.0, 0.0]) as Array
			var tex_sz := Vector2(float(sz_arr[0]), float(sz_arr[1]))
			var piv_px := Vector2(float(piv_arr[0]), float(piv_arr[1]))
			var rest_px := Vector2(float(rest_arr[0]), float(rest_arr[1]))

			var pivot_node := Node2D.new()
			pivot_node.name = "WingShard_%s" % shard_id
			_wings_root.add_child(pivot_node)

			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.offset = -piv_px
			pivot_node.add_child(sp)

			# Glow aditivo carmesí detrás de la cuchilla
			var glow_sp := Sprite2D.new()
			glow_sp.texture = tex
			glow_sp.centered = false
			glow_sp.offset = -piv_px
			glow_sp.scale = Vector2(1.06, 1.06)
			glow_sp.modulate = Color(1.65, 0.22, 0.42, 0.45)
			var add_mat := CanvasItemMaterial.new()
			add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow_sp.material = add_mat
			glow_sp.z_index = -1
			pivot_node.add_child(glow_sp)

			_wing_shards.append({
				"node": pivot_node,
				"sprite": sp,
				"glow": glow_sp,
				"side_sign": side_sign,
				"shard_index": shard_idx,
				"rest_px": rest_px,
				"tex_size": tex_sz,
			})

	_update_wings(0.0)


func _update_wings(bob_y: float) -> void:
	if _wings_root == null or _config == null:
		return
	var vis: bool = _is_selected and _wings_deploy > 0.001
	_wings_root.visible = vis
	if not vis:
		return

	# Curva overshoot firme: se abre de golpe (1.16) y se clava firme en 1.0
	var t: float = _wings_deploy
	var overshoot: float = 1.0 - pow(1.0 - t, 3.0)
	if t < 1.0:
		overshoot += sin(t * PI) * 0.16 * (1.0 - t * 0.4)

	var parallax_w: Vector2 = -_mouse_smooth * 10.0
	_wings_root.position = _config.wings_anchor_offset + Vector2(0.0, bob_y * 0.8) + parallax_w

	var base_sc: float = _config.wings_scale
	for item: Dictionary in _wing_shards:
		var node: Node2D = item["node"] as Node2D
		var glow: Sprite2D = item["glow"] as Sprite2D
		if not is_instance_valid(node):
			continue
		var sgn: float = float(item["side_sign"])
		var idx: int = int(item["shard_index"])
		var rest_px: Vector2 = item["rest_px"] as Vector2

		# Cada cuchilla se despliega con micro-escalonamiento y queda firme con respiración sutil
		var idle_wave: float = sin(_anim_time * 2.1 - float(idx) * 0.45) * 0.018 * clampf(t, 0.0, 1.0)
		var fold_rot: float = deg_to_rad(-38.0 * sgn) * (1.0 - overshoot)
		var firm_fan: float = deg_to_rad(float(idx) * 1.4 * sgn) * overshoot
		node.rotation = fold_rot + firm_fan + idle_wave * sgn

		var spread_x: float = sgn * _config.wings_spread_x * overshoot
		node.position = Vector2(spread_x, 0.0) + rest_px * (base_sc * overshoot)

		var sc: float = base_sc * lerpf(0.25, 1.0, overshoot)
		node.scale = Vector2(sc, sc)

		if is_instance_valid(glow):
			var flash_boost: float = 1.0 + (1.0 - _shockwave_t) * 1.6
			glow.modulate = Color(1.65 * flash_boost, 0.22 * flash_boost, 0.42 * flash_boost, 0.42 * clampf(t, 0.0, 1.0))


func _load_tex(path: String, no_mipmaps: bool = false) -> Texture2D:
	if path.is_empty():
		return null
	if no_mipmaps:
		var abs_p: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img_nm := Image.new()
			if img_nm.load(abs_p) == OK:
				img_nm.clear_mipmaps()
				return ImageTexture.create_from_image(img_nm)
	if ResourceLoader.exists(path):
		var loaded: Texture2D = ResourceLoader.load(path) as Texture2D
		if loaded != null:
			return loaded
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func _init_stars() -> void:
	_stars.clear()
	for i: int in range(STAR_COUNT):
		var seed_a: float = float(i) * 1.6180339
		_stars.append({
			"x": sin(seed_a * 7.3) * 280.0,
			"y": cos(seed_a * 5.1) * 320.0,
			"speed": 10.0 + fmod(float(i) * 7.0, 18.0),
			"size": 1.6 + fmod(float(i) * 0.7, 2.4),
			"phase": seed_a * 3.0,
			"fg": (i % 3 == 0),
		})


func draw_atmosphere(_canvas: Node2D, _is_foreground: bool) -> void:
	# Sin fondo, anillo ni partículas ajenas al rig del personaje.
	pass
