class_name PilotDialoguePortraitController
extends Node2D
## Controlador reutilizable de retratos de diálogo vivos (Living Dialogue Portraits).
## Orquesta cross-fade entre emociones/poses, shader de iluminación cósmica y máscaras,
## recoloreo de skins, dinámica de habla/escucha, modo radio Comms y partículas estelares.

const ConfigScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_config.gd")
const EntryScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_entry.gd")
const PortraitShader: Shader = preload("res://scenes/pilots/shaders/pilot_dialogue_portrait.gdshader")

const PARTICLE_COUNT_BG: int = 20
const PARTICLE_COUNT_FG: int = 10


class _CosmicParticlesNode extends Node2D:
	var owner_ctrl: PilotDialoguePortraitController = null
	var is_foreground: bool = false

	func _draw() -> void:
		if owner_ctrl != null:
			owner_ctrl.draw_cosmic_particles(self, is_foreground)


@export var config: ConfigScript = null
@export var auto_step: bool = true

var _bg_fx: _CosmicParticlesNode = null
var _portrait_root: Node2D = null
var _backlight_sprite: Sprite2D = null
var _backlight_tex: GradientTexture2D = null
var _sprite_prev: Sprite2D = null
var _sprite_cur: Sprite2D = null
var _fg_fx: _CosmicParticlesNode = null

var _mat_prev: ShaderMaterial = null
var _mat_cur: ShaderMaterial = null

var _tex_cache: Dictionary = {}
var _active_entry: EntryScript = null
var _prev_entry: EntryScript = null
var _current_emotion: StringName = &""

var _anim_time: float = 0.0
var _crossfade_t: float = 1.0
var _entry_anim_t: float = 1.0
var _speech_pulse: float = 0.0
var _speech_hop: float = 0.0
var _speaking_glow: float = 0.0
var _focus_t: float = 1.0
var _comms_t: float = 0.0

var _is_focused: bool = true
var _is_speaking: bool = false
var _is_comms: bool = false
var _is_mirrored: bool = false
var _living_enabled: bool = true
var _particles_enabled: bool = true
var _debug_view_mode: int = 0

var _mouse_target: Vector2 = Vector2.ZERO
var _mouse_smooth: Vector2 = Vector2.ZERO

var _active_skin: PilotSkinPreset = null
var _hair_recolor_enabled: bool = false
var _rng := RandomNumberGenerator.new()
var _particles_bg: Array[Dictionary] = []
var _particles_fg: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = 42087
	_build_nodes()
	_init_particles()
	if config == null:
		config = ConfigScript.new()
	config.ensure_defaults()
	if _current_emotion.is_empty():
		set_emotion(config.default_emotion, true)


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func set_config(p_config: ConfigScript) -> void:
	config = p_config if p_config != null else ConfigScript.new()
	config.ensure_defaults()
	if is_inside_tree():
		var target_em: StringName = _current_emotion if not _current_emotion.is_empty() else config.default_emotion
		set_emotion(target_em, true)


func get_config() -> ConfigScript:
	return config


func get_current_emotion() -> StringName:
	return _current_emotion


func get_portrait_root() -> Node2D:
	return _portrait_root


func get_available_emotions() -> Array[StringName]:
	return config.get_emotion_ids() if config != null else []


func set_emotion(emotion_id: StringName, instant: bool = false) -> void:
	if config == null:
		return
	var next_entry: EntryScript = config.get_entry(emotion_id)
	if next_entry == null:
		return
	var resolved_id: StringName = next_entry.emotion_id
	if resolved_id == _current_emotion and _active_entry != null and not instant:
		return

	if _active_entry != null and not instant:
		_prev_entry = _active_entry
		_copy_cur_to_prev_sprite()
		_crossfade_t = 0.0
	else:
		_prev_entry = null
		_crossfade_t = 1.0
		if _sprite_prev != null:
			_sprite_prev.visible = false

	_active_entry = next_entry
	_current_emotion = resolved_id
	_entry_anim_t = 0.0 if not instant else 1.0
	_apply_entry_to_sprite(_sprite_cur, _mat_cur, _active_entry)
	_sync_shared_shader_uniforms()


func refresh_active_entry_params() -> void:
	if _active_entry != null and _mat_cur != null:
		_apply_entry_visual_uniforms(_mat_cur, _active_entry)
	_sync_shared_shader_uniforms()


func apply_skin_preset(skin: PilotSkinPreset, _star_level: int = 1) -> void:
	_active_skin = skin
	_sync_skin_uniforms(_mat_cur)
	_sync_skin_uniforms(_mat_prev)


func set_hair_recolor_enabled(enabled: bool) -> void:
	_hair_recolor_enabled = enabled
	_sync_skin_uniforms(_mat_cur)
	_sync_skin_uniforms(_mat_prev)


func set_debug_view_mode(mode_idx: int) -> void:
	_debug_view_mode = clampi(mode_idx, 0, 6)
	_sync_shared_shader_uniforms()


func set_comms_mode(enabled: bool, instant: bool = false) -> void:
	_is_comms = enabled
	if instant:
		_comms_t = 1.0 if enabled else 0.0
	_sync_shared_shader_uniforms()


func set_focused(focused: bool, instant: bool = false) -> void:
	_is_focused = focused
	if instant:
		_focus_t = 1.0 if focused else 0.0
	_sync_shared_shader_uniforms()


func set_speaking(speaking: bool) -> void:
	_is_speaking = speaking
	if speaking:
		_is_focused = true
		_speech_hop = 0.0
		_speech_pulse = maxf(_speech_pulse, 0.35)


func notify_speech_pulse() -> void:
	# Pulso óptico suave en ojos/monóculo; prohibido el salto vertical al escribir
	_speech_hop = 0.0
	_speaking_glow = maxf(_speaking_glow, 0.42)


func refresh_layout_metrics() -> void:
	if _sprite_cur != null and _active_entry != null:
		_apply_sprite_layout(_sprite_cur, _active_entry)
	if _sprite_prev != null and _prev_entry != null and _sprite_prev.visible:
		_apply_sprite_layout(_sprite_prev, _prev_entry)
	_update_backlight()
	_sync_shared_shader_uniforms()


func set_mirrored(mirrored: bool) -> void:
	_is_mirrored = mirrored


func is_mirrored() -> bool:
	return _is_mirrored


func set_living_enabled(enabled: bool) -> void:
	_living_enabled = enabled
	_sync_shared_shader_uniforms()
	if _bg_fx != null:
		_bg_fx.queue_redraw()
	if _fg_fx != null:
		_fg_fx.queue_redraw()


func set_particles_enabled(enabled: bool) -> void:
	_particles_enabled = enabled
	if _bg_fx != null:
		_bg_fx.visible = enabled
	if _fg_fx != null:
		_fg_fx.visible = enabled


func set_mouse_normalized(pos: Vector2) -> void:
	if config == null or not config.follow_mouse:
		_mouse_target = Vector2.ZERO
		return
	_mouse_target = Vector2(clampf(pos.x, -1.0, 1.0), clampf(pos.y, -1.0, 1.0))


func set_shader_param(param_name: String, value: Variant) -> void:
	if _mat_cur != null:
		_mat_cur.set_shader_parameter(param_name, value)
	if _mat_prev != null:
		_mat_prev.set_shader_parameter(param_name, value)


func step(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	if _living_enabled:
		_anim_time += dt
	if config == null or not config.follow_mouse:
		_mouse_target = Vector2.ZERO
		_mouse_smooth = Vector2.ZERO
	else:
		_mouse_smooth = _mouse_smooth.lerp(_mouse_target, clampf(dt * 8.0, 0.0, 1.0))

	var dur: float = config.transition_duration_sec if config != null else 0.16
	if _crossfade_t < 1.0:
		_crossfade_t = minf(1.0, _crossfade_t + dt / maxf(dur, 0.04))
		if _crossfade_t >= 1.0 and _sprite_prev != null:
			_sprite_prev.visible = false

	if _entry_anim_t < 1.0:
		_entry_anim_t = minf(1.0, _entry_anim_t + dt / 0.28)

	var target_glow: float = 0.42 if _is_speaking else 0.0
	_speaking_glow = move_toward(_speaking_glow, target_glow, dt * 3.2)
	_speech_pulse = maxf(0.0, _speech_pulse - dt * 2.5)
	_speech_hop = 0.0

	var target_focus: float = 1.0 if _is_focused else 0.0
	_focus_t = move_toward(_focus_t, target_focus, dt * 6.0)

	var target_comms: float = 1.0 if _is_comms else 0.0
	_comms_t = move_toward(_comms_t, target_comms, dt * 8.0)

	_update_root_transform()
	_update_backlight()
	_update_particles(dt)
	_sync_dynamic_uniforms()


func draw_cosmic_particles(canvas: CanvasItem, is_foreground: bool) -> void:
	if not _particles_enabled or (config != null and not config.show_cosmic_particles):
		return
	var col: Color = _active_entry.rim_light_color if _active_entry != null else Color(0.56, 0.72, 1.0, 1.0)
	if _is_comms and config != null:
		col = col.lerp(config.comms_tint_color, _comms_t * 0.6)
	var list: Array[Dictionary] = _particles_fg if is_foreground else _particles_bg
	var focus_alpha: float = lerpf(0.38, 1.0, _focus_t)
	for p: Dictionary in list:
		var pos: Vector2 = p["pos"] as Vector2
		var rad: float = float(p["radius"])
		var alpha: float = float(p["alpha"]) * focus_alpha
		var c := Color(col.r, col.g, col.b, alpha)
		canvas.draw_circle(pos, rad, c)
		if rad > 2.2:
			canvas.draw_circle(pos, rad * 2.1, Color(col.r, col.g, col.b, alpha * 0.22))


func _build_nodes() -> void:
	_bg_fx = _CosmicParticlesNode.new()
	_bg_fx.name = "CosmicParticlesBg"
	_bg_fx.owner_ctrl = self
	_bg_fx.is_foreground = false
	add_child(_bg_fx)

	_portrait_root = Node2D.new()
	_portrait_root.name = "PortraitRoot"
	add_child(_portrait_root)

	_backlight_tex = _build_backlight_texture()
	_backlight_sprite = Sprite2D.new()
	_backlight_sprite.name = "BacklightGlow"
	_backlight_sprite.texture = _backlight_tex
	_backlight_sprite.centered = true
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_backlight_sprite.material = add_mat
	_portrait_root.add_child(_backlight_sprite)

	_mat_prev = ShaderMaterial.new()
	_mat_prev.shader = PortraitShader

	_mat_cur = ShaderMaterial.new()
	_mat_cur.shader = PortraitShader

	_sprite_prev = Sprite2D.new()
	_sprite_prev.name = "SpritePrev"
	_sprite_prev.centered = true
	_sprite_prev.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite_prev.material = _mat_prev
	_sprite_prev.visible = false
	_portrait_root.add_child(_sprite_prev)

	_sprite_cur = Sprite2D.new()
	_sprite_cur.name = "SpriteCur"
	_sprite_cur.centered = true
	_sprite_cur.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite_cur.material = _mat_cur
	_portrait_root.add_child(_sprite_cur)

	_fg_fx = _CosmicParticlesNode.new()
	_fg_fx.name = "CosmicParticlesFg"
	_fg_fx.owner_ctrl = self
	_fg_fx.is_foreground = true
	add_child(_fg_fx)


func _init_particles() -> void:
	_particles_bg.clear()
	_particles_fg.clear()
	for i: int in range(PARTICLE_COUNT_BG):
		_particles_bg.append({
			"pos": Vector2(_rng.randf_range(-240.0, 240.0), _rng.randf_range(-620.0, -20.0)),
			"vel": Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-24.0, -8.0)),
			"radius": _rng.randf_range(1.2, 3.4),
			"alpha": _rng.randf_range(0.18, 0.48),
		})
	for j: int in range(PARTICLE_COUNT_FG):
		_particles_fg.append({
			"pos": Vector2(_rng.randf_range(-210.0, 210.0), _rng.randf_range(-560.0, -40.0)),
			"vel": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-34.0, -14.0)),
			"radius": _rng.randf_range(1.6, 4.0),
			"alpha": _rng.randf_range(0.12, 0.30),
		})


func _update_particles(dt: float) -> void:
	if not _particles_enabled or not _living_enabled:
		return
	for p: Dictionary in _particles_bg:
		var pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
		if pos.y < -650.0:
			pos.y = 0.0
			pos.x = _rng.randf_range(-240.0, 240.0)
		p["pos"] = pos
	for p: Dictionary in _particles_fg:
		var pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
		if pos.y < -600.0:
			pos.y = 0.0
			pos.x = _rng.randf_range(-210.0, 210.0)
		p["pos"] = pos
	if _bg_fx != null:
		_bg_fx.queue_redraw()
	if _fg_fx != null:
		_fg_fx.queue_redraw()


func _apply_entry_to_sprite(sprite: Sprite2D, mat: ShaderMaterial, entry: EntryScript) -> void:
	if sprite == null or mat == null or entry == null:
		return
	var tex: Texture2D = _load_texture(entry.texture_path, true)
	sprite.texture = tex
	_apply_sprite_layout(sprite, entry)
	_update_backlight()

	var norm_tex: Texture2D = _load_texture(entry.normal_map_path, false)
	var dep_tex: Texture2D = _load_texture(entry.depth_map_path, false)
	var id_tex: Texture2D = _load_texture(entry.id_mask_path, false)
	var ilm_tex: Texture2D = _load_texture(entry.ilm_map_path, false)
	var mot_tex: Texture2D = _load_texture(entry.motion_mask_path, false)

	mat.set_shader_parameter("has_normal_map", norm_tex != null)
	if norm_tex != null:
		mat.set_shader_parameter("normal_map", norm_tex)

	mat.set_shader_parameter("has_depth_map", dep_tex != null)
	if dep_tex != null:
		mat.set_shader_parameter("depth_map", dep_tex)

	mat.set_shader_parameter("has_id_mask", id_tex != null)
	if id_tex != null:
		mat.set_shader_parameter("id_mask", id_tex)

	mat.set_shader_parameter("has_ilm_map", ilm_tex != null)
	if ilm_tex != null:
		mat.set_shader_parameter("ilm_map", ilm_tex)

	mat.set_shader_parameter("has_motion_mask", mot_tex != null)
	if mot_tex != null:
		mat.set_shader_parameter("motion_mask", mot_tex)

	_apply_entry_visual_uniforms(mat, entry)
	_sync_skin_uniforms(mat)


func _apply_entry_visual_uniforms(mat: ShaderMaterial, entry: EntryScript) -> void:
	if mat == null or entry == null:
		return
	mat.set_shader_parameter("breath_amp_px", entry.breath_amp_px)
	mat.set_shader_parameter("breath_speed", entry.breath_speed)
	mat.set_shader_parameter("hair_sway_amp_px", entry.hair_sway_amp_px)
	mat.set_shader_parameter("rim_light_color", entry.rim_light_color)
	mat.set_shader_parameter("rim_light_strength", entry.rim_light_strength)
	mat.set_shader_parameter("rim_light_angle_deg", entry.rim_light_angle_deg)
	mat.set_shader_parameter("cel_strength", entry.cel_strength)
	mat.set_shader_parameter("cel_shadow_tint", entry.cel_shadow_tint)
	mat.set_shader_parameter("specular_strength", entry.specular_strength)
	mat.set_shader_parameter("ilm_ao_strength", entry.ilm_ao_strength)
	mat.set_shader_parameter("face_shadow_protect", entry.face_shadow_protect)
	mat.set_shader_parameter("eye_shimmer_strength", entry.eye_shimmer_strength)


func _copy_cur_to_prev_sprite() -> void:
	if _sprite_cur == null or _sprite_prev == null or _mat_cur == null or _mat_prev == null:
		return
	_sprite_prev.texture = _sprite_cur.texture
	_sprite_prev.offset = _sprite_cur.offset
	_sprite_prev.scale = _sprite_cur.scale
	_sprite_prev.position = _sprite_cur.position
	_sprite_prev.visible = _sprite_prev.texture != null
	if _prev_entry != null:
		_apply_entry_to_sprite(_sprite_prev, _mat_prev, _prev_entry)


func _apply_sprite_layout(sprite: Sprite2D, entry: EntryScript) -> void:
	if sprite == null:
		return
	var tex: Texture2D = sprite.texture
	if tex == null or entry == null:
		sprite.offset = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
		return
	var sz: Vector2 = tex.get_size()
	sprite.offset = Vector2(0.0, -sz.y * 0.5)
	var base_h: float = config.base_display_height_px if config != null else 860.0
	var s: float = (base_h / maxf(sz.y, 1.0)) * entry.scale_bias
	sprite.scale = Vector2(s, s)
	sprite.position = entry.offset_px


func _build_backlight_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.45, Color(1.0, 1.0, 1.0, 0.35))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.width = 512
	gt.height = 768
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.gradient = grad
	return gt


func _update_backlight() -> void:
	if _backlight_sprite == null:
		return
	if _debug_view_mode != 0:
		_backlight_sprite.visible = false
		return
	_backlight_sprite.visible = true
	var display_h: float = config.base_display_height_px if config != null else 860.0
	if _active_entry != null:
		display_h *= _active_entry.scale_bias
	var display_w: float = display_h * 0.92
	_backlight_sprite.position = Vector2(0.0, -display_h * 0.48)
	_backlight_sprite.scale = Vector2((display_w / 512.0) * 1.15, (display_h / 768.0) * 1.15)
	var glow_col: Color = _active_entry.rim_light_color if _active_entry != null else Color(0.56, 0.72, 1.0, 1.0)
	if _is_comms and config != null:
		glow_col = glow_col.lerp(config.comms_tint_color, _comms_t * 0.65)
	var alpha: float = lerpf(0.12, 0.38, _focus_t) + _speaking_glow * 0.16
	_backlight_sprite.modulate = Color(glow_col.r, glow_col.g, glow_col.b, clampf(alpha, 0.0, 0.52))


func _sync_skin_uniforms(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	var enabled: bool = _active_skin != null and not _active_skin.is_base_skin
	mat.set_shader_parameter("skin_recolor_enabled", enabled)
	mat.set_shader_parameter("use_skin_hair_recolor", _hair_recolor_enabled)
	if _active_skin != null:
		mat.set_shader_parameter("skin_accent_color", _active_skin.accent_color)
		mat.set_shader_parameter("skin_panel_color", _active_skin.panel_color)
		mat.set_shader_parameter("skin_dark_color", _active_skin.suit_dark_color)
		mat.set_shader_parameter("skin_hair_color", _active_skin.hair_color)


func _sync_shared_shader_uniforms() -> void:
	var dim_b: float = config.listening_dim_brightness if config != null else 0.58
	var desat: float = config.listening_desaturate if config != null else 0.25
	var comms_col: Color = config.comms_tint_color if config != null else Color(0.42, 0.90, 1.0, 1.0)
	var fade_start: float = config.bottom_fade_start if config != null else 0.86
	var fade_pow: float = config.bottom_fade_power if config != null else 1.8
	for mat: ShaderMaterial in [_mat_cur, _mat_prev]:
		if mat == null:
			continue
		mat.set_shader_parameter("living_enabled", _living_enabled)
		mat.set_shader_parameter("debug_view_mode", _debug_view_mode)
		mat.set_shader_parameter("listening_dim_brightness", dim_b)
		mat.set_shader_parameter("listening_desaturate", desat)
		mat.set_shader_parameter("comms_tint_color", comms_col)
		mat.set_shader_parameter("bottom_fade_start", fade_start)
		mat.set_shader_parameter("bottom_fade_power", fade_pow)


func _sync_dynamic_uniforms() -> void:
	var alpha_cur: float = clampf(_crossfade_t, 0.0, 1.0)
	var alpha_prev: float = 1.0 - alpha_cur
	var flip_sign: float = -1.0 if _is_mirrored else 1.0
	var m_off := Vector2(_mouse_smooth.x * flip_sign, _mouse_smooth.y)
	var active_pulse: float = maxf(_speaking_glow, _speech_pulse)

	if _mat_cur != null:
		_mat_cur.set_shader_parameter("anim_time", _anim_time)
		_mat_cur.set_shader_parameter("mouse_offset", m_off)
		_mat_cur.set_shader_parameter("fade_alpha", alpha_cur)
		_mat_cur.set_shader_parameter("speech_pulse", active_pulse)
		_mat_cur.set_shader_parameter("focus_amount", _focus_t)
		_mat_cur.set_shader_parameter("comms_amount", _comms_t)
	if _mat_prev != null and _sprite_prev != null and _sprite_prev.visible:
		_mat_prev.set_shader_parameter("anim_time", _anim_time)
		_mat_prev.set_shader_parameter("mouse_offset", m_off)
		_mat_prev.set_shader_parameter("fade_alpha", alpha_prev)
		_mat_prev.set_shader_parameter("speech_pulse", active_pulse)
		_mat_prev.set_shader_parameter("focus_amount", _focus_t)
		_mat_prev.set_shader_parameter("comms_amount", _comms_t)


func _update_root_transform() -> void:
	if _portrait_root == null:
		return
	var flip_sign: float = -1.0 if _is_mirrored else 1.0
	var listen_scale: float = config.listening_scale_mult if config != null else 0.95
	var active_scale: float = config.active_focus_scale if config != null else 1.04
	var turn_scale: float = lerpf(listen_scale, active_scale, _focus_t)

	if not _living_enabled:
		_portrait_root.position = Vector2.ZERO
		_portrait_root.rotation_degrees = 0.0
		_portrait_root.scale = Vector2(flip_sign * turn_scale, turn_scale)
		return

	var float_y: float = 0.0
	var sway_r: float = 0.0

	var active_pulse: float = maxf(_speaking_glow, _speech_pulse)
	var bounce_px: float = config.speaking_bounce_px if config != null else 0.0
	var scale_punch: float = config.speaking_scale_punch if config != null else 0.0
	var hop_curve: float = sin(_speech_hop * PI)
	var speak_y: float = -hop_curve * bounce_px if bounce_px > 0.001 else 0.0
	var speak_scale: float = 1.0 + active_pulse * scale_punch if scale_punch > 0.0001 else 1.0

	var allow_mouse: bool = config != null and config.follow_mouse
	var par_px: float = config.mouse_parallax_px if allow_mouse else 0.0
	var tilt_deg: float = config.mouse_tilt_deg if allow_mouse else 0.0
	var mouse_pos: Vector2 = _mouse_smooth * par_px if allow_mouse else Vector2.ZERO
	var mouse_rot: float = _mouse_smooth.x * tilt_deg * flip_sign if allow_mouse else 0.0

	# Coreografía de entrada según EntryMotion
	var entry_off := Vector2.ZERO
	var entry_scale: float = 1.0
	var entry_rot: float = 0.0
	var inv_t: float = pow(1.0 - clampf(_entry_anim_t, 0.0, 1.0), 2.0)
	if inv_t > 0.001 and _active_entry != null:
		match _active_entry.entry_motion:
			EntryScript.EntryMotion.TACTICAL_SLIDE:
				entry_off.x = -16.0 * inv_t * flip_sign
			EntryScript.EntryMotion.LOCKON_ZOOM:
				entry_scale = 1.0 + 0.055 * inv_t
			EntryScript.EntryMotion.ALERT_SHAKE:
				entry_off.x = sin(_entry_anim_t * 42.0) * 10.0 * inv_t
				entry_off.y = cos(_entry_anim_t * 34.0) * 5.0 * inv_t
			EntryScript.EntryMotion.CONFIDENT_TILT:
				entry_rot = 2.8 * inv_t * flip_sign

	var final_s: float = turn_scale * speak_scale * entry_scale
	_portrait_root.position = Vector2(mouse_pos.x + entry_off.x, float_y + speak_y + mouse_pos.y * 0.5 + entry_off.y)
	_portrait_root.rotation_degrees = sway_r + mouse_rot + entry_rot
	_portrait_root.scale = Vector2(flip_sign * final_s, final_s)


func _load_texture(res_path: String, with_mipmaps: bool) -> Texture2D:
	if res_path.is_empty():
		return null
	var cache_key: String = "%s|%d" % [res_path, int(with_mipmaps)]
	if _tex_cache.has(cache_key) and _tex_cache[cache_key] != null:
		return _tex_cache[cache_key] as Texture2D

	var img: Image = null
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	elif ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path)
		if res is Texture2D:
			img = (res as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()

	if img == null or img.is_empty():
		return null

	if with_mipmaps:
		img.generate_mipmaps()
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = tex
	return tex
