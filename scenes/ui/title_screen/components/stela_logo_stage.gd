class_name StelaLogoStage
extends Control

## Escenario modular en 4 capas vivas para el logotipo de Stela Galactica:
## 1) AstrolabeRingsRect (anillos astrolabio procedurales contrarrotativos detrás)
## 2) MedallionRect (medallón astrolabio separado rotando con su Normal Map compensado)
## 3) LogoHeroRect (tipografía STELA GALACTICA cel-shaded + Normal Map reactivo al Cosmos)
## 4) EnergySlashRect (tajo energético diagonal animado por delante de "STELA")

signal entrance_completed()
signal dissolve_completed()

const ConfigScript = preload("res://data/ui/stela_logo_vfx_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://data/ui/default_stela_logo_vfx_config.tres")
const SHADER_LOGO: Shader = preload("res://shaders/ui/stela_logo_cel_lit.gdshader")
const SHADER_RINGS: Shader = preload("res://shaders/ui/stela_logo_astrolabe_rings.gdshader")
const SHADER_SLASH: Shader = preload("res://shaders/ui/stela_logo_energy_slash.gdshader")

const ALBEDO_PATH: String = "res://assets/ui/stela_galactica_logo_albedo.png"
const NORMAL_PATH: String = "res://assets/ui/stela_galactica_logo_normal.png"
const MASKS_PATH: String = "res://assets/ui/stela_galactica_logo_masks.png"

const MEDALLION_ALBEDO_PATH: String = "res://assets/ui/stela_galactica_medallion_albedo.png"
const MEDALLION_NORMAL_PATH: String = "res://assets/ui/stela_galactica_medallion_normal.png"
const MEDALLION_MASKS_PATH: String = "res://assets/ui/stela_galactica_medallion_masks.png"

@export var config: ConfigScript = DEFAULT_CONFIG

var _rings_rect: ColorRect = null
var _medallion_rect: TextureRect = null
var _logo_holder: Control = null
var _logo_rect: TextureRect = null
var _slash_rect: ColorRect = null

var _rings_mat: ShaderMaterial = null
var _medallion_mat: ShaderMaterial = null
var _logo_mat: ShaderMaterial = null
var _slash_mat: ShaderMaterial = null

var _time_acc: float = 0.0
var _shine_timer: float = 1.6
var _shine_active: bool = false
var _shine_elapsed: float = 0.0
var _is_dissolving: bool = false
var _entrance_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if config == null:
		config = DEFAULT_CONFIG
	_build_layers()
	apply_config(config)


func _build_layers() -> void:
	if _logo_rect != null:
		return

	_rings_mat = ShaderMaterial.new()
	_rings_mat.shader = SHADER_RINGS

	_rings_rect = ColorRect.new()
	_rings_rect.name = "AstrolabeRingsRect"
	_rings_rect.set_anchors_preset(Control.PRESET_CENTER)
	_rings_rect.offset_left = -390.0
	_rings_rect.offset_top = -390.0
	_rings_rect.offset_right = 390.0
	_rings_rect.offset_bottom = 390.0
	_rings_rect.pivot_offset = Vector2(390.0, 390.0)
	_rings_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings_rect.material = _rings_mat
	add_child(_rings_rect)

	_medallion_mat = ShaderMaterial.new()
	_medallion_mat.shader = SHADER_LOGO
	_medallion_mat.set_shader_parameter("normal_tex", _load_texture_safe(MEDALLION_NORMAL_PATH))
	_medallion_mat.set_shader_parameter("masks_tex", _load_texture_safe(MEDALLION_MASKS_PATH))

	_medallion_rect = TextureRect.new()
	_medallion_rect.name = "MedallionRect"
	_medallion_rect.set_anchors_preset(Control.PRESET_CENTER)
	_medallion_rect.offset_left = -260.0
	_medallion_rect.offset_top = -260.0
	_medallion_rect.offset_right = 260.0
	_medallion_rect.offset_bottom = 260.0
	_medallion_rect.pivot_offset = Vector2(260.0, 260.0)
	_medallion_rect.texture = _load_texture_safe(MEDALLION_ALBEDO_PATH)
	_medallion_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medallion_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medallion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_rect.material = _medallion_mat
	add_child(_medallion_rect)

	_logo_holder = Control.new()
	_logo_holder.name = "LogoHeroHolder"
	_logo_holder.set_anchors_preset(Control.PRESET_CENTER)
	_logo_holder.offset_left = -350.0
	_logo_holder.offset_top = -220.0
	_logo_holder.offset_right = 350.0
	_logo_holder.offset_bottom = 220.0
	_logo_holder.pivot_offset = Vector2(350.0, 220.0)
	_logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_holder)

	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = SHADER_LOGO
	_logo_mat.set_shader_parameter("normal_tex", _load_texture_safe(NORMAL_PATH))
	_logo_mat.set_shader_parameter("masks_tex", _load_texture_safe(MASKS_PATH))

	_logo_rect = TextureRect.new()
	_logo_rect.name = "LogoHeroRect"
	_logo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo_rect.texture = _load_texture_safe(ALBEDO_PATH)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_rect.material = _logo_mat
	_logo_holder.add_child(_logo_rect)

	_slash_mat = ShaderMaterial.new()
	_slash_mat.shader = SHADER_SLASH

	_slash_rect = ColorRect.new()
	_slash_rect.name = "EnergySlashRect"
	_slash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slash_rect.offset_left = -80.0
	_slash_rect.offset_top = -45.0
	_slash_rect.offset_right = 80.0
	_slash_rect.offset_bottom = 45.0
	_slash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash_rect.material = _slash_mat
	_logo_holder.add_child(_slash_rect)


func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res: Resource = load(res_path)
		if res is Texture2D:
			return res as Texture2D
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func apply_config(p_cfg: ConfigScript) -> void:
	if p_cfg == null:
		return
	config = p_cfg
	for mat: ShaderMaterial in [_logo_mat, _medallion_mat]:
		if mat == null:
			continue
		mat.set_shader_parameter("normal_strength", config.normal_strength)
		mat.set_shader_parameter("cel_shadow_threshold", config.cel_shadow_threshold)
		mat.set_shader_parameter("cel_spec_threshold", config.cel_spec_threshold)
		mat.set_shader_parameter("cosmos_light_mix", config.cosmos_light_mix)
		mat.set_shader_parameter("rim_intensity", config.rim_intensity)
		mat.set_shader_parameter("gold_specular_intensity", config.gold_specular_intensity)
	if _medallion_rect != null:
		var ms: float = maxf(config.medallion_scale, 0.2)
		_medallion_rect.scale = Vector2(ms, ms)
	if _rings_mat != null:
		_rings_mat.set_shader_parameter("outer_speed", config.astrolabe_outer_speed)
		_rings_mat.set_shader_parameter("inner_speed", config.astrolabe_inner_speed)
		_rings_mat.set_shader_parameter("global_alpha", config.astrolabe_alpha)
		_rings_mat.set_shader_parameter("primary_color", config.astrolabe_primary_color)
		_rings_mat.set_shader_parameter("secondary_color", config.astrolabe_secondary_color)
	if _slash_mat != null:
		_slash_mat.set_shader_parameter("angle_deg", config.slash_angle_deg)
		_slash_mat.set_shader_parameter("flow_speed", config.slash_flow_speed)
		_slash_mat.set_shader_parameter("intensity", config.slash_intensity)
		_slash_mat.set_shader_parameter("core_color", config.slash_core_color)
		_slash_mat.set_shader_parameter("mid_color", config.slash_mid_color)
		_slash_mat.set_shader_parameter("edge_color", config.slash_edge_color)


func sync_cosmic_lighting(sample: RefCounted) -> void:
	if sample == null:
		return
	var l2d: Vector2 = sample.get("light_dir_2d") if "light_dir_2d" in sample else Vector2(-0.5, -0.5)
	var lz: float = float(sample.get("light_z_3d")) if "light_z_3d" in sample else 0.7
	var l3d: Vector3 = Vector3(l2d.x, l2d.y, maxf(lz, 0.35)).normalized()

	for mat: ShaderMaterial in [_logo_mat, _medallion_mat]:
		if mat == null:
			continue
		mat.set_shader_parameter("cosmos_light_dir", l3d)
		if "key_tint" in sample:
			mat.set_shader_parameter("cosmos_key_color", sample.get("key_tint"))
		if "shadow_tint" in sample:
			mat.set_shader_parameter("cosmos_shadow_tint", sample.get("shadow_tint"))
		if "rim_color" in sample:
			mat.set_shader_parameter("cosmos_rim_color", sample.get("rim_color"))

	if "rim_color" in sample and _rings_mat != null and config != null:
		var rc: Color = sample.get("rim_color") as Color
		_rings_mat.set_shader_parameter("secondary_color", config.astrolabe_secondary_color.lerp(rc, 0.45))


func _process(delta: float) -> void:
	_time_acc += delta
	if _medallion_rect != null and config != null and not _is_dissolving:
		_medallion_rect.rotation = fmod(_medallion_rect.rotation + delta * config.medallion_rotation_speed, TAU)
		if _medallion_mat != null:
			_medallion_mat.set_shader_parameter("sprite_rotation_rad", _medallion_rect.rotation)

	if _logo_holder != null and not _is_dissolving and config != null:
		var hover_y: float = sin(_time_acc * TAU * config.hover_freq_hz) * config.hover_amplitude_px
		_logo_holder.offset_top = -220.0 + hover_y
		_logo_holder.offset_bottom = 220.0 + hover_y

	if config != null and not _is_dissolving:
		if _shine_active:
			_shine_elapsed += delta
			var dur: float = maxf(config.shine_duration_sec, 0.15)
			var u: float = _shine_elapsed / dur
			if u >= 1.0:
				_shine_active = false
				_shine_timer = config.shine_interval_sec
				if _logo_mat != null:
					_logo_mat.set_shader_parameter("shine_progress", -0.6)
				if _medallion_mat != null:
					_medallion_mat.set_shader_parameter("shine_progress", -0.6)
			else:
				var sv: float = lerpf(-0.45, 1.55, u)
				if _logo_mat != null:
					_logo_mat.set_shader_parameter("shine_progress", sv)
				if _medallion_mat != null:
					_medallion_mat.set_shader_parameter("shine_progress", sv)
		else:
			_shine_timer -= delta
			if _shine_timer <= 0.0:
				_shine_active = true
				_shine_elapsed = 0.0


func reset_visible() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_is_dissolving = false
	visible = true
	modulate.a = 1.0
	if _logo_holder != null:
		_logo_holder.scale = Vector2.ONE
		_logo_holder.modulate.a = 1.0
	if _medallion_rect != null:
		var ms: float = maxf(config.medallion_scale if config != null else 0.88, 0.2)
		_medallion_rect.scale = Vector2(ms, ms)
		_medallion_rect.modulate.a = 1.0
	for mat: ShaderMaterial in [_logo_mat, _medallion_mat]:
		if mat != null:
			mat.set_shader_parameter("dissolve_progress", 0.0)
			mat.set_shader_parameter("shine_progress", -0.6)
	if _rings_mat != null:
		_rings_mat.set_shader_parameter("reveal_progress", 1.0)
		_rings_mat.set_shader_parameter("dissolve_progress", 0.0)
	if _slash_mat != null:
		_slash_mat.set_shader_parameter("cut_progress", 1.0)
		_slash_mat.set_shader_parameter("dissolve_progress", 0.0)


func play_entrance() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_build_layers()
	_is_dissolving = false
	visible = true
	modulate.a = 1.0

	var dur: float = maxf(config.reveal_duration_sec if config != null else 0.95, 0.25)
	var target_ms: float = maxf(config.medallion_scale if config != null else 0.88, 0.2)

	_medallion_rect.scale = Vector2(target_ms * 0.72, target_ms * 0.72)
	_medallion_rect.modulate.a = 0.0
	_logo_holder.scale = Vector2(0.86, 0.86)
	_logo_holder.modulate.a = 0.0

	for mat: ShaderMaterial in [_logo_mat, _medallion_mat]:
		if mat != null:
			mat.set_shader_parameter("dissolve_progress", 0.0)
	_rings_mat.set_shader_parameter("reveal_progress", 0.05)
	_rings_mat.set_shader_parameter("dissolve_progress", 0.0)
	_slash_mat.set_shader_parameter("cut_progress", 0.0)
	_slash_mat.set_shader_parameter("dissolve_progress", 0.0)

	_entrance_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_method(
		func(v: float) -> void:
			if _rings_mat != null:
				_rings_mat.set_shader_parameter("reveal_progress", v),
		0.05, 1.0, dur * 0.72
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_medallion_rect, "scale", Vector2(target_ms, target_ms), dur * 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_medallion_rect, "modulate:a", 1.0, dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_logo_holder, "scale", Vector2.ONE, dur * 0.58).set_delay(dur * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_logo_holder, "modulate:a", 1.0, dur * 0.42).set_delay(dur * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_method(
		func(v: float) -> void:
			if _slash_mat != null:
				_slash_mat.set_shader_parameter("cut_progress", v),
		0.0, 1.0, dur * 0.42
	).set_delay(dur * 0.36).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_entrance_tween.chain().tween_callback(func() -> void:
		_shine_active = true
		_shine_elapsed = 0.0
		entrance_completed.emit()
	)


func play_dissolve_to_hub() -> void:
	if _is_dissolving:
		return
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_is_dissolving = true

	var dur: float = maxf(config.dissolve_duration_sec if config != null else 0.55, 0.15)
	var target_ms: float = maxf(config.medallion_scale if config != null else 0.88, 0.2)
	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_method(
		func(v: float) -> void:
			if _logo_mat != null:
				_logo_mat.set_shader_parameter("dissolve_progress", v)
			if _medallion_mat != null:
				_medallion_mat.set_shader_parameter("dissolve_progress", v)
			if _rings_mat != null:
				_rings_mat.set_shader_parameter("dissolve_progress", v)
			if _slash_mat != null:
				_slash_mat.set_shader_parameter("dissolve_progress", v),
		0.0, 1.0, dur
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_logo_holder, "scale", Vector2(1.08, 1.08), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_medallion_rect, "scale", Vector2(target_ms * 1.12, target_ms * 1.12), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		visible = false
		_is_dissolving = false
		dissolve_completed.emit()
	)


func get_logo_material() -> ShaderMaterial:
	return _logo_mat


func get_medallion_material() -> ShaderMaterial:
	return _medallion_mat


func get_rings_material() -> ShaderMaterial:
	return _rings_mat


func get_slash_material() -> ShaderMaterial:
	return _slash_mat
