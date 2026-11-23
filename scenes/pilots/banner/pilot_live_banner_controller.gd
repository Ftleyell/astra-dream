class_name PilotLiveBannerController
extends Node2D
## Controlador reutilizable de Live Banner 2.5D para Selección de Personajes.
## Gestiona el shader orgánico por máscaras (respiración, cabello, parpadeo, parallax 2.5D,
## rim-light, recolor de skins), física de resorte en hover/mouse y atmósfera orbital de fondo.

const BannerShader = preload("res://scenes/pilots/shaders/pilot_live_banner.gdshader")
const Pass2Shader = preload("res://scenes/pilots/shaders/pilot_rig_pass2.gdshader")
const WingGlowShader = preload("res://scenes/pilots/shaders/wing_red_glow.gdshader")
const ConfigScript = preload("res://data/pilots/schemas/pilot_live_banner_config.gd")

const STAR_COUNT: int = 34
const MAX_EMBERS: int = 44
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
var _blink_speed_mult: float = 1.0

var _is_selected: bool = false
var _select_elapsed: float = 0.0
var _lock_triggered: bool = false
var _lock_elapsed: float = 0.0
var _impact_frame_phase: int = 0
var _wings_deploy: float = 0.0
var _wings_light_intensity: float = 0.0
var _hair_burst_lift: float = 0.0
var _hair_burst_vel: float = 0.0
var _shockwave_t: float = 1.0
var _lock_eye_flare: float = 0.0
var _lock_iris_scale: float = 1.0
var _arm_flare_deg: float = 0.0
var _arm_flare_vel: float = 0.0
var _camera_zoom_punch: float = 0.0
var _camera_shake_amp: float = 0.0
var _camera_shake_offset: Vector2 = Vector2.ZERO
var _active_accent_color: Color = Color(1.0, 0.12, 0.28, 1.0)
var _active_pilot_skin: PilotSkinPreset = null
var _wings_skin_override: PilotSkinPreset = null
var _pilot_star_level: int = 1
var _wings_star_level: int = 1
var _embers: Array[Dictionary] = []
var _ember_spawn_accum: float = 0.0
var _rng := RandomNumberGenerator.new()

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
	if _active_pilot_skin != null:
		apply_skin_preset(_active_pilot_skin, _pilot_star_level)
	if _wings_skin_override != null:
		apply_wings_skin_preset(_wings_skin_override, _wings_star_level)


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


func get_camera_zoom_punch() -> float:
	return _camera_zoom_punch


func get_camera_shake_offset() -> Vector2:
	return _camera_shake_offset


func get_lock_eye_flare() -> float:
	return _lock_eye_flare


func get_active_ember_count() -> int:
	return _embers.size()


func trigger_select_sequence() -> void:
	_is_selected = true
	_select_elapsed = 0.0
	_lock_triggered = false
	_lock_elapsed = 0.0
	_impact_frame_phase = 0
	_wings_deploy = 0.0
	_wings_light_intensity = 0.25
	_hair_burst_lift = 0.0
	_hair_burst_vel = 0.0
	_shockwave_t = 1.0
	_lock_eye_flare = 0.14
	_lock_iris_scale = 1.0
	_arm_flare_deg = 0.0
	_arm_flare_vel = 0.0
	_camera_zoom_punch = 0.0
	_camera_shake_amp = 0.0
	_camera_shake_offset = Vector2.ZERO
	_embers.clear()
	_ember_spawn_accum = 0.0
	# Parpadeo rápido de anticipación durante la cascada de cuchillas
	_blink_phase = 0.0
	_blink_speed_mult = 1.65
	for item: Dictionary in _wing_shards:
		item["ignition"] = 0.0
		item["locked_flash"] = false
	trigger_hover_impulse(0.45)
	_push_shader_params()


func reset_select_sequence() -> void:
	_is_selected = false
	_select_elapsed = 0.0
	_lock_triggered = false
	_lock_elapsed = 0.0
	_impact_frame_phase = 0
	_wings_deploy = 0.0
	_wings_light_intensity = 0.0
	_hair_burst_lift = 0.0
	_hair_burst_vel = 0.0
	_shockwave_t = 1.0
	_lock_eye_flare = 0.0
	_lock_iris_scale = 1.0
	_arm_flare_deg = 0.0
	_arm_flare_vel = 0.0
	_camera_zoom_punch = 0.0
	_camera_shake_amp = 0.0
	_camera_shake_offset = Vector2.ZERO
	_blink_speed_mult = 1.0
	_embers.clear()
	for item: Dictionary in _wing_shards:
		item["ignition"] = 0.0
		item["locked_flash"] = false
	_update_wings(0.0)
	_push_shader_params()


func set_mouse_normalized(norm_pos: Vector2) -> void:
	_mouse_target = Vector2(clampf(norm_pos.x, -1.0, 1.0), clampf(norm_pos.y, -1.0, 1.0))


func set_auto_mouse_demo(enabled: bool) -> void:
	_auto_mouse_demo = enabled


func set_debug_view_mode(mode_idx: int) -> void:
	_debug_view_mode = clampi(mode_idx, 0, 6)
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


func apply_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	_active_pilot_skin = skin
	_pilot_star_level = clampi(star_level, 1, 3)
	var star_glow: float = 0.0
	if _pilot_star_level == 2:
		star_glow = 0.45
	elif _pilot_star_level >= 3:
		star_glow = 1.0
	var mats: Array[ShaderMaterial] = [_material, _arm_material]
	for m: ShaderMaterial in mats:
		if m == null:
			continue
		if skin == null or skin.is_base_skin:
			m.set_shader_parameter("skin_recolor_enabled", false)
			m.set_shader_parameter("skin_star_glow", star_glow)
		else:
			m.set_shader_parameter("skin_recolor_enabled", true)
			m.set_shader_parameter("skin_accent_color", skin.accent_color)
			m.set_shader_parameter("skin_panel_color", skin.panel_color)
			m.set_shader_parameter("skin_dark_color", skin.suit_dark_color)
			m.set_shader_parameter("skin_hair_color", skin.hair_color)
			m.set_shader_parameter("skin_star_glow", star_glow)
	_sync_wings_accent_params()


func apply_wings_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	_wings_skin_override = skin
	_wings_star_level = clampi(star_level, 1, 3)
	_sync_wings_accent_params()


func _sync_wings_accent_params() -> void:
	var eff_wings: PilotSkinPreset = _wings_skin_override if _wings_skin_override != null else _active_pilot_skin
	var is_default_wings: bool = (eff_wings == null or eff_wings.is_base_skin)
	_active_accent_color = Color(1.0, 0.12, 0.28, 1.0) if is_default_wings else eff_wings.accent_color
	var use_custom_wings: bool = (_wings_skin_override != null)
	for m: ShaderMaterial in [_material, _arm_material]:
		if m == null:
			continue
		m.set_shader_parameter("use_custom_wings_accent", use_custom_wings)
		m.set_shader_parameter("wings_skin_accent_color", _active_accent_color)
	if _pass2_material != null:
		var counter_col: Color = Color(1.0, 0.18, 0.34, 1.0) if is_default_wings else eff_wings.accent_color
		_pass2_material.set_shader_parameter("rim_counter_color", counter_col)
	for item: Dictionary in _wing_shards:
		var gmat: ShaderMaterial = item.get("glow_mat", null) as ShaderMaterial
		if gmat != null:
			gmat.set_shader_parameter("glow_color", _active_accent_color)


func get_active_skin_id() -> String:
	if _active_pilot_skin == null or _active_pilot_skin.is_base_skin or _active_pilot_skin.id.is_empty():
		return "base"
	return _active_pilot_skin.id


func get_active_wings_skin_id() -> String:
	if _wings_skin_override == null:
		return "follow_pilot"
	if _wings_skin_override.is_base_skin or _wings_skin_override.id.is_empty():
		return "base"
	return _wings_skin_override.id


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

	var m_tex: Texture2D = _load_tex(_config.motion_mask_path, true)
	var fx_tex: Texture2D = _load_tex(_config.fx_mask_path, true)
	var d_tex: Texture2D = _load_tex(_config.depth_map_path)
	var n_tex: Texture2D = _load_tex(_config.normal_map_path)
	var ilm_tex: Texture2D = _load_tex(_config.ilm_map_path, true)
	var ink_tex: Texture2D = _load_tex(_config.ink_sdf_path, true)
	var eye_iris_tex: Texture2D = _load_tex(_config.eye_iris_texture_path, true)
	var eye_closed_tex: Texture2D = _load_tex(_config.eye_closed_texture_path, true)
	var has_eye_assets: bool = (eye_iris_tex != null and eye_closed_tex != null)
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
		m.set_shader_parameter("has_ilm_map", ilm_tex != null)
		if ilm_tex != null:
			m.set_shader_parameter("ilm_map", ilm_tex)
		m.set_shader_parameter("has_ink_sdf", ink_tex != null)
		if ink_tex != null:
			m.set_shader_parameter("ink_sdf", ink_tex)
		m.set_shader_parameter("has_eye_live2d_assets", has_eye_assets)
		if has_eye_assets:
			m.set_shader_parameter("eye_iris_tex", eye_iris_tex)
			m.set_shader_parameter("eye_closed_tex", eye_closed_tex)


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
				_blink_speed_mult = 1.0
				_blink_timer = lerpf(_config.blink_interval_min_sec, _config.blink_interval_max_sec, fmod(absf(sin(_anim_time * 13.7)), 1.0))
		else:
			_blink_phase += (delta * _blink_speed_mult) / maxf(_config.blink_duration_sec, 0.05)
			if _blink_phase >= 1.0:
				_blink_phase = -1.0
				_blink_amount = 0.0
				_blink_speed_mult = 1.0
			else:
				_blink_amount = sin(_blink_phase * PI)
	else:
		_blink_phase = -1.0
		_blink_amount = 0.0
		_blink_speed_mult = 1.0

	# Secuencia Lock-In "Full Anime Overdrive":
	#   Fase A (0 .. cascade_dur): parpadeo rápido de anticipación + abanico secuencial 6x2 con ignición
	#   Fase B (al trabar): apertura súbita del ojo con brillo amatista + contracción iris + brazo libre
	#                       + 2 Impact Frames + micro-zoom/shake + onda expansiva + chispas carmesí
	var punch_scale: float = 1.0
	var shake_off := Vector2.ZERO
	if _is_selected:
		_select_elapsed += delta
		var cascade_dur: float = maxf(0.12, _config.wings_cascade_duration_sec)
		_wings_deploy = clampf(_select_elapsed / cascade_dur, 0.0, 1.0)

		var just_triggered: bool = false
		if not _lock_triggered and _select_elapsed >= cascade_dur:
			_trigger_lock_impact(_select_elapsed - cascade_dur)
			just_triggered = true

		if not _lock_triggered:
			var ramp: float = clampf(_select_elapsed / cascade_dur, 0.0, 1.0)
			_impact_frame_phase = 0
			punch_scale = lerpf(1.0, 0.978, sin(ramp * PI * 0.65))
			shake_off = Vector2(sin(_select_elapsed * 95.0), cos(_select_elapsed * 115.0)) * (1.8 * ramp)
			_wings_light_intensity = lerpf(0.25, 0.95, ramp)
			_lock_eye_flare = lerpf(0.12, 0.42, ramp)
			_lock_iris_scale = lerpf(1.0, 0.94, ramp)
		else:
			if not just_triggered:
				_lock_elapsed += delta
			var t1: float = maxf(0.02, _config.impact_frame_1_sec)
			var t2: float = t1 + maxf(0.02, _config.impact_frame_2_sec)
			if _lock_elapsed < t1:
				_impact_frame_phase = 1
				punch_scale = 1.072
				shake_off = Vector2(sin(_lock_elapsed * 220.0) * 6.5, cos(_lock_elapsed * 190.0) * 5.0)
			elif _lock_elapsed < t2:
				_impact_frame_phase = 2
				punch_scale = 1.052
				shake_off = Vector2(cos(_lock_elapsed * 250.0) * 4.5, sin(_lock_elapsed * 205.0) * 3.8)
			else:
				_impact_frame_phase = 0
				var settle_t: float = clampf((_lock_elapsed - t2) / 0.28, 0.0, 1.0)
				punch_scale = lerpf(1.045, 1.018, 1.0 - pow(1.0 - settle_t, 3.0))

			_shockwave_t = clampf(_lock_elapsed / 0.38, 0.0, 1.0)
			var steady_light: float = 0.88 + 0.16 * sin(_anim_time * 3.4)
			var burst_light: float = (1.0 - _shockwave_t) * 1.25
			_wings_light_intensity = clampf(steady_light + burst_light, 0.0, 2.35)
			if not just_triggered:
				_lock_eye_flare = lerpf(_lock_eye_flare, 0.34, 1.0 - exp(-7.5 * delta))
				_lock_iris_scale = lerpf(_lock_iris_scale, 1.0, 1.0 - exp(-9.0 * delta))
	else:
		_impact_frame_phase = 0
		_wings_deploy = 0.0
		_wings_light_intensity = 0.0
		_shockwave_t = 1.0
		_lock_eye_flare = lerpf(_lock_eye_flare, 0.0, 1.0 - exp(-10.0 * delta))
		_lock_iris_scale = lerpf(_lock_iris_scale, 1.0, 1.0 - exp(-10.0 * delta))

	# Decaimiento de micro-zoom punch y shake de cámara
	_camera_zoom_punch = lerpf(_camera_zoom_punch, 0.0, 1.0 - exp(-11.0 * delta))
	_camera_shake_amp = lerpf(_camera_shake_amp, 0.0, 1.0 - exp(-16.0 * delta))
	if _camera_shake_amp > 0.15:
		_camera_shake_offset = Vector2(
			sin(_anim_time * 185.0) * _camera_shake_amp,
			cos(_anim_time * 215.0) * _camera_shake_amp * 0.78
		)
	else:
		_camera_shake_offset = Vector2.ZERO

	# Resorte de tensión del brazo libre hacia afuera en el instante del trabado
	var target_arm_flare: float = (_config.lock_arm_flare_deg * 0.28) if (_is_selected and _lock_triggered) else 0.0
	var arm_acc: float = (target_arm_flare - _arm_flare_deg) * 145.0 - _arm_flare_vel * 12.5
	_arm_flare_vel += arm_acc * delta
	_arm_flare_deg = clampf(_arm_flare_deg + _arm_flare_vel * delta, -4.0, _config.lock_arm_flare_deg * 1.45)

	# Actualizar destello de ignición de cada cuchilla y chispas carmesí persistentes
	for item: Dictionary in _wing_shards:
		var ign: float = float(item.get("ignition", 0.0))
		if ign > 0.001:
			item["ignition"] = lerpf(ign, 0.0, 1.0 - exp(-12.0 * delta))
	_step_embers(delta)

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
		var flare_scale_boost: float = clampf(_arm_flare_deg / maxf(_config.lock_arm_flare_deg, 1.0), 0.0, 1.5) * 0.025
		var persp_x: float = 1.0 + arm_phase * _config.arm_persp_scale_amp + flare_scale_boost
		var persp_y: float = 1.0 + arm_phase * (_config.arm_persp_scale_amp * 0.65)
		_free_arm_pivot.position = _arm_pivot_local
		_free_arm_pivot.scale = Vector2(persp_x, persp_y)
		_free_arm_pivot.rotation = deg_to_rad(arm_phase * 2.0 + _arm_flare_deg)
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
	_unified_group.use_mipmaps = true
	_unified_group.fit_margin = 48.0
	_unified_group.clear_margin = 48.0
	_pass2_material = ShaderMaterial.new()
	_pass2_material.shader = Pass2Shader
	_pass2_material.set_shader_parameter("enable_outer_outline", true)
	_pass2_material.set_shader_parameter("outer_outline_width_px", 0.42)
	_pass2_material.set_shader_parameter("outer_outline_strength", 0.72)
	_pass2_material.set_shader_parameter("outer_outline_tint_mix", 0.82)
	_pass2_material.set_shader_parameter("outline_calligraphy_amount", 0.55)
	_pass2_material.set_shader_parameter("outline_crispness", 0.48)
	_pass2_material.set_shader_parameter("outline_inward_replace", 0.06)
	_pass2_material.set_shader_parameter("outer_outline_color", Color(0.045, 0.040, 0.095, 1.0))
	_pass2_material.set_shader_parameter("seam_weld_radius_px", 1.15)
	_pass2_material.set_shader_parameter("cas_sharpen_strength", 0.24)
	_pass2_material.set_shader_parameter("silhouette_rim_strength", 0.18)
	_pass2_material.set_shader_parameter("silhouette_rim_width_px", 0.85)
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
		m.set_shader_parameter("lock_eye_flare", _lock_eye_flare)
		m.set_shader_parameter("lock_iris_scale", _lock_iris_scale)
		m.set_shader_parameter("eye_center_uv", _config.eye_center_uv)
		m.set_shader_parameter("eye_almond_bounds_uv", _config.eye_almond_bounds_uv)
		m.set_shader_parameter("eye_iris_size_uv", _config.eye_iris_size_uv)
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
		m.set_shader_parameter("ilm_ao_strength", _config.ilm_ao_strength)
		m.set_shader_parameter("albedo_de_shade", _config.albedo_de_shade)
		m.set_shader_parameter("ink_sdf_enabled", _config.ink_sdf_enabled)
		m.set_shader_parameter("ink_strength", _config.ink_strength)
		m.set_shader_parameter("ink_width_bias", _config.ink_width_bias)
		m.set_shader_parameter("ink_color_tint_mix", _config.ink_color_tint_mix)
		m.set_shader_parameter("ink_color", _config.ink_color)
		m.set_shader_parameter("debug_view_mode", _debug_view_mode)

	if _pass2_material != null:
		var l_rad: float = deg_to_rad(_config.cel_light_angle_deg)
		_pass2_material.set_shader_parameter("light_dir_2d", Vector2(cos(l_rad), sin(l_rad)).normalized())
		_pass2_material.set_shader_parameter("enable_outer_outline", _debug_view_mode == 0)
		_pass2_material.set_shader_parameter("outer_outline_strength", _config.ink_strength if _debug_view_mode == 0 else 0.0)
		_pass2_material.set_shader_parameter("silhouette_rim_strength", _config.rim_light_strength * 0.24 if _debug_view_mode == 0 else 0.0)
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
			var tip_arr: Array = entry.get("tip_offset_px", [256.0, 0.0]) as Array
			var rest_arr: Array = entry.get("rest_offset_px", [0.0, 0.0]) as Array
			var tex_sz := Vector2(maxf(1.0, float(sz_arr[0])), maxf(1.0, float(sz_arr[1])))
			var piv_px := Vector2(float(piv_arr[0]), float(piv_arr[1]))
			var tip_px := Vector2(float(tip_arr[0]), float(tip_arr[1]))
			var tip_rel_px: Vector2 = tip_px - piv_px
			var rest_px := Vector2(float(rest_arr[0]), float(rest_arr[1]))

			var pivot_node := Node2D.new()
			pivot_node.name = "WingShard_%s" % shard_id
			_wings_root.add_child(pivot_node)

			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.offset = -piv_px
			pivot_node.add_child(sp)

			# Capa HDR por máscara ILM (pulso escáner cibernético en las partes rojas de cada cuchilla)
			var ilm_path: String = "%s/%s_ilm_mask.png" % [dir_path, shard_id]
			var ilm_tex: Texture2D = _load_tex(ilm_path, false)
			var glow_sp := Sprite2D.new()
			glow_sp.texture = tex
			glow_sp.centered = false
			glow_sp.offset = -piv_px
			var glow_mat: ShaderMaterial = null
			if ilm_tex != null:
				glow_mat = ShaderMaterial.new()
				glow_mat.shader = WingGlowShader
				glow_mat.set_shader_parameter("ilm_mask_tex", ilm_tex)
				glow_mat.set_shader_parameter("glow_color", _active_accent_color)
				glow_mat.set_shader_parameter("glow_intensity", _config.wing_scanner_glow_intensity)
				glow_mat.set_shader_parameter("blade_pivot_uv", (piv_px / tex_sz).clamp(Vector2.ZERO, Vector2.ONE))
				glow_mat.set_shader_parameter("blade_tip_uv", (tip_px / tex_sz).clamp(Vector2.ZERO, Vector2.ONE))
				glow_mat.set_shader_parameter("pulse_phase_offset", float(shard_idx) * 0.17)
				glow_mat.set_shader_parameter("pulse_speed", _config.wing_scanner_speed)
				glow_mat.set_shader_parameter("pulse_freq", _config.wing_scanner_freq)
				glow_sp.material = glow_mat
				glow_sp.z_index = 1
			else:
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
				"glow_mat": glow_mat,
				"side_sign": side_sign,
				"shard_index": shard_idx,
				"rest_px": rest_px,
				"tip_offset_px": tip_rel_px,
				"tex_size": tex_sz,
				"ignition": 0.0,
				"locked_flash": false,
			})

	_update_wings(0.0)


func _update_wings(bob_y: float) -> void:
	if _wings_root == null or _config == null:
		return
	var vis: bool = _is_selected and _wings_deploy > 0.001
	_wings_root.visible = vis
	if not vis:
		return

	var cascade_dur: float = maxf(0.12, _config.wings_cascade_duration_sec)
	var blade_dur: float = clampf(_config.wing_blade_open_sec, 0.04, cascade_dur)
	var span_start: float = maxf(0.0, cascade_dur - blade_dur)
	var parallax_w: Vector2 = -_mouse_smooth * 10.0
	_wings_root.position = _config.wings_anchor_offset + Vector2(0.0, bob_y * 0.8) + parallax_w

	var base_sc: float = _config.wings_scale
	for item: Dictionary in _wing_shards:
		var node: Node2D = item["node"] as Node2D
		var glow: Sprite2D = item["glow"] as Sprite2D
		var gmat: ShaderMaterial = item.get("glow_mat", null) as ShaderMaterial
		if not is_instance_valid(node):
			continue
		var sgn: float = float(item["side_sign"])
		var idx: int = int(item["shard_index"])
		var rest_px: Vector2 = item["rest_px"] as Vector2

		# Despliegue mecánico secuencial en abanico (cuchilla 0..5 de adentro hacia afuera)
		var t_start: float = (float(idx) / 5.0) * span_start
		var local_t: float = clampf((_select_elapsed - t_start) / blade_dur, 0.0, 1.0)
		node.visible = local_t > 0.01
		if local_t > 0.08 and not bool(item.get("locked_flash", false)):
			item["locked_flash"] = true
			item["ignition"] = 2.4

		var overshoot: float = 1.0 - pow(1.0 - local_t, 3.0)
		if local_t < 1.0:
			overshoot += sin(local_t * PI) * 0.18 * (1.0 - local_t * 0.4)

		var idle_wave: float = sin(_anim_time * 2.1 - float(idx) * 0.45) * 0.018 * clampf(_wings_deploy, 0.0, 1.0)
		var fold_rot: float = deg_to_rad(-44.0 * sgn) * (1.0 - overshoot)
		var firm_fan: float = deg_to_rad(float(idx) * 1.6 * sgn) * overshoot
		node.rotation = fold_rot + firm_fan + idle_wave * sgn

		var spread_x: float = sgn * _config.wings_spread_x * overshoot
		node.position = Vector2(spread_x, 0.0) + rest_px * (base_sc * overshoot)

		var sc: float = base_sc * lerpf(0.22, 1.0, overshoot)
		node.scale = Vector2(sc, sc)

		if gmat != null:
			var star_mult: float = 1.0
			if _wings_star_level == 2:
				star_mult = 1.18
			elif _wings_star_level >= 3:
				star_mult = 1.38
			var lock_boost: float = (1.0 + (1.0 - _shockwave_t) * 1.15) * star_mult
			gmat.set_shader_parameter("glow_color", _active_accent_color)
			gmat.set_shader_parameter("glow_intensity", _config.wing_scanner_glow_intensity * lock_boost * clampf(local_t, 0.0, 1.0))
			gmat.set_shader_parameter("pulse_time", _anim_time)
			gmat.set_shader_parameter("pulse_speed", _config.wing_scanner_speed)
			gmat.set_shader_parameter("pulse_freq", _config.wing_scanner_freq)
			gmat.set_shader_parameter("pulse_strength", 0.92 + (1.0 - _shockwave_t) * 0.45)
			gmat.set_shader_parameter("ignition_flash", clampf(float(item.get("ignition", 0.0)) + (1.0 - _shockwave_t) * 0.85, 0.0, 3.0))
		elif is_instance_valid(glow):
			var flash_boost: float = 1.0 + (1.0 - _shockwave_t) * 1.6
			glow.modulate = Color(1.65 * flash_boost, 0.22 * flash_boost, 0.42 * flash_boost, 0.42 * clampf(local_t, 0.0, 1.0))


func _load_tex(path: String, no_mipmaps: bool = false) -> Texture2D:
	if path.is_empty():
		return null
	var abs_p: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_p):
		var img := Image.new()
		if img.load(abs_p) == OK:
			if no_mipmaps:
				img.clear_mipmaps()
			else:
				img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var loaded: Texture2D = ResourceLoader.load(path) as Texture2D
		if loaded != null:
			if no_mipmaps:
				var img: Image = loaded.get_image()
				if img != null and not img.is_empty():
					if img.is_compressed():
						img.decompress()
					img.clear_mipmaps()
					return ImageTexture.create_from_image(img)
			return loaded
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


func _trigger_lock_impact(overshoot_sec: float) -> void:
	_lock_triggered = true
	_lock_elapsed = maxf(0.0, overshoot_sec)
	# Apertura instantánea del ojo con brillo amatista y contracción táctica del iris
	_blink_phase = -1.0
	_blink_amount = 0.0
	_blink_speed_mult = 1.0
	_lock_eye_flare = 1.75
	_lock_iris_scale = 0.86
	_hair_burst_lift = 0.0
	_hair_burst_vel = 11.5
	_arm_flare_vel = 260.0
	_shockwave_t = 0.0
	_camera_zoom_punch = _config.lock_zoom_punch if _config != null else 0.075
	_camera_shake_amp = _config.lock_camera_shake_px if _config != null else 9.0
	for item: Dictionary in _wing_shards:
		item["ignition"] = 2.6
	trigger_hover_impulse(1.15)
	_spawn_ember_burst(28)


func _spawn_ember_burst(count: int) -> void:
	if _wing_shards.is_empty():
		return
	for i: int in range(count):
		if _embers.size() >= MAX_EMBERS:
			break
		var shard: Dictionary = _wing_shards[i % _wing_shards.size()]
		var node: Node2D = shard.get("node", null) as Node2D
		var sgn: float = float(shard.get("side_sign", 1.0))
		var tip_off: Vector2 = shard.get("tip_offset_px", Vector2(220.0 * sgn, -40.0)) as Vector2
		var base_pos: Vector2 = (_wings_root.position if _wings_root != null else Vector2(0.0, -145.0))
		if is_instance_valid(node):
			base_pos += node.position + tip_off * node.scale
		var out_dir: Vector2 = (tip_off.normalized() + Vector2(sgn * 0.4, -0.55)).normalized()
		var spd: float = _rng.randf_range(75.0, 210.0)
		_embers.append({
			"pos": base_pos + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-14.0, 14.0)),
			"vel": out_dir * spd + Vector2(0.0, -_rng.randf_range(20.0, 65.0)),
			"life": 0.0,
			"max_life": _rng.randf_range(0.55, 1.35),
			"size": _rng.randf_range(2.2, 4.6),
			"phase": _rng.randf_range(0.0, TAU),
		})


func _step_embers(delta: float) -> void:
	for i: int in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		var next_life: float = float(e["life"]) + delta
		var max_life: float = float(e["max_life"])
		if next_life >= max_life:
			_embers.remove_at(i)
			continue
		e["life"] = next_life
		var vel: Vector2 = (e["vel"] as Vector2) * exp(-1.8 * delta) + Vector2(sin(_anim_time * 3.5 + float(e["phase"])) * 18.0, -42.0) * delta
		e["vel"] = vel
		e["pos"] = (e["pos"] as Vector2) + vel * delta

	if _is_selected and _lock_triggered:
		_ember_spawn_accum += delta * 18.0
		while _ember_spawn_accum >= 1.0 and _embers.size() < MAX_EMBERS:
			_ember_spawn_accum -= 1.0
			var x_side: float = -1.0 if (_embers.size() % 2 == 0) else 1.0
			var spawn_pos: Vector2 = Vector2(x_side * _rng.randf_range(55.0, 245.0), _rng.randf_range(-240.0, 40.0))
			_embers.append({
				"pos": spawn_pos,
				"vel": Vector2(x_side * _rng.randf_range(8.0, 28.0), -_rng.randf_range(42.0, 96.0)),
				"life": 0.0,
				"max_life": _rng.randf_range(1.1, 2.2),
				"size": _rng.randf_range(1.8, 3.6),
				"phase": _rng.randf_range(0.0, TAU),
			})


func draw_atmosphere(canvas: Node2D, is_foreground: bool) -> void:
	if canvas == null:
		return
	var has_vfx: bool = _is_selected or _shockwave_t < 0.995 or not _embers.is_empty()
	if not has_vfx:
		return

	var acc_col: Color = _active_accent_color
	var anchor: Vector2 = _config.wings_anchor_offset if _config != null else Vector2(0.0, -162.0)

	if not is_foreground:
		# 1. Onda expansiva geométrica doble en el instante del trabado
		if _shockwave_t < 0.995:
			var ease_s: float = 1.0 - pow(1.0 - _shockwave_t, 3.0)
			var alpha_s: float = (1.0 - _shockwave_t)
			var rad_outer: float = lerpf(40.0, 440.0, ease_s)
			var rad_inner: float = lerpf(24.0, 320.0, ease_s)
			canvas.draw_arc(anchor, rad_outer, 0.0, TAU, 64, Color(acc_col.r * 1.4, acc_col.g * 0.6, acc_col.b * 0.7, alpha_s * 0.65), 3.0 * alpha_s + 0.8, true)
			canvas.draw_arc(anchor, rad_inner, 0.0, TAU, 56, Color(1.35, 1.25, 1.35, alpha_s * 0.80), 1.8 * alpha_s + 0.5, true)

		# 2. Chispas carmesí-blancas persistentes subiendo detrás de Valentina
		for e: Dictionary in _embers:
			var life_n: float = clampf(float(e["life"]) / maxf(float(e["max_life"]), 0.05), 0.0, 1.0)
			var fade: float = sin(life_n * PI)
			var pos: Vector2 = e["pos"] as Vector2
			var sz: float = float(e["size"]) * (1.0 - life_n * 0.35)
			var col_core := Color(1.45, 0.85, 0.95, fade * 0.90)
			var col_halo := Color(acc_col.r * 1.5, acc_col.g * 0.4, acc_col.b * 0.5, fade * 0.45)
			canvas.draw_circle(pos, sz * 1.9, col_halo)
			canvas.draw_circle(pos, sz * 0.8, col_core)
		return

	# Foreground VFX:
	# 1. Líneas de velocidad radiales anime durante los 2 Impact Frames
	if _impact_frame_phase > 0:
		var line_col: Color = Color(1.4, 1.35, 1.45, 0.78) if _impact_frame_phase == 1 else Color(acc_col.r * 1.6, acc_col.g * 0.5, acc_col.b * 0.6, 0.82)
		var ray_count: int = 24
		for r_idx: int in range(ray_count):
			var ang: float = (float(r_idx) / float(ray_count)) * TAU + float(_impact_frame_phase) * 0.13
			var dir := Vector2(cos(ang), sin(ang))
			var inner_r: float = 175.0 + fmod(float(r_idx) * 37.0, 95.0)
			var outer_r: float = 520.0
			var w: float = 2.6 if (r_idx % 3 == 0) else 1.4
			canvas.draw_line(anchor + dir * inner_r, anchor + dir * outer_r, line_col, w, true)

	# 2. Destello en cruz sobre ojo/monóculo en el pico del Lock-In
	if _lock_eye_flare > 0.48 and _character_root != null and _banner_sprite != null and _banner_sprite.texture != null and _config != null:
		var tex_sz: Vector2 = _banner_sprite.texture.get_size()
		var sc: Vector2 = _character_root.scale
		var eye_local: Vector2 = _character_root.position + Vector2((_config.eye_center_uv.x - 0.5) * tex_sz.x, (_config.eye_center_uv.y - 0.5) * tex_sz.y) * sc
		var flare_w: float = clampf((_lock_eye_flare - 0.48) / 1.2, 0.0, 1.0)
		var len_h: float = 28.0 * flare_w + 8.0
		var len_v: float = 18.0 * flare_w + 5.0
		var star_c := Color(1.35, 0.95, 1.65, flare_w * 0.88)
		canvas.draw_line(eye_local - Vector2(len_h, 0.0), eye_local + Vector2(len_h, 0.0), star_c, 1.6, true)
		canvas.draw_line(eye_local - Vector2(0.0, len_v), eye_local + Vector2(0.0, len_v), star_c, 1.4, true)
