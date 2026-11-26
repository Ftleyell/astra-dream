class_name PilotCutInTheater
extends CanvasLayer
## Teatro cinematográfico de pantalla completa para Cut-Ins de Skill [R] y Ultimate [Q].
## Corre en PROCESS_MODE_ALWAYS para animarse a 60/120fps mientras PauseArbitrator congela el mundo.
## Soporta conmutación en vivo entre LIVE_BANNER_25D (estilo Wallpaper Engine HD)
## y RIG_BATTLE_POSE (PlanarCombatRig 18 huesos en SubViewport HDR), además de scrubbing en Studio.

signal cutin_impact_frame_entered(phase: int)
signal cutin_release_reached(mode_name: StringName)
signal cutin_finished(mode_name: StringName)

const ImpactShatterShader = preload("res://scenes/pilots/shaders/fullscreen_impact_shatter.gdshader")
const CutInMaskShader = preload("res://scenes/pilots/shaders/cutin_window_mask.gdshader")
const CutInSkinCompositeShader = preload("res://scenes/pilots/shaders/cutin_skin_composite.gdshader")
const LiveBannerCtrlScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")
const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const Stage3DScript = preload("res://scenes/pilots/vfx/abilities/ultimate_3d_stage_rig.gd")
const PaletteResolverScript = preload("res://scenes/pilots/vfx/abilities/pilot_skin_palette_resolver.gd")
const SkillConfigScript = preload("res://data/pilots/schemas/pilot_skill_config.gd")
const UltimateConfigScript = preload("res://data/pilots/schemas/pilot_ultimate_config.gd")

const DEFAULT_LIVE_BANNER_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_live_banner.tres"
const DEFAULT_PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const VIEWPORT_RES: Vector2i = Vector2i(1280, 720)

enum ActiveMode {
	NONE = 0,
	SKILL = 1,
	ULTIMATE = 2,
}

var _mode: int = ActiveMode.NONE
var _elapsed: float = 0.0
var _total_duration: float = 0.0
var _time_scale: float = 1.0
var _is_frozen: bool = false
var _release_emitted: bool = false
var _last_impact_phase: int = -1

var _skill_cfg: PilotSkillConfig = null
var _ult_cfg: PilotUltimateConfig = null
var _accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var _contrast_color: Color = Color(0.08, 0.96, 0.88, 1.0)
var _stage_bg_color: Color = Color(0.03, 0.02, 0.06, 1.0)
var _secondary_color: Color = Color(0.545, 0.361, 0.965, 1.0)
var _palette: Dictionary = {}
var _impact_center_uv: Vector2 = Vector2(0.5, 0.5)

var _pilot_skin: PilotSkinPreset = null
var _wings_skin: PilotSkinPreset = null
var _pilot_stars: int = 1
var _wings_stars: int = 1

var _dim_rect: ColorRect = null
var _dim_mat: ShaderMaterial = null
var _stage_3d: Ultimate3DStageRig = null
var _stage_3d_bg_display: TextureRect = null
var _stage_3d_fg_display: TextureRect = null
var _cutin_viewport: SubViewport = null
var _cutin_camera: Camera2D = null
var _custom_art_sprite: Sprite2D = null
var _custom_art_mat: ShaderMaterial = null
var _custom_art_cache: Dictionary = {}
var _banner_ctrl: PilotLiveBannerController = null
var _rig_ctrl: PlanarCombatRig = null
var _cutin_display: TextureRect = null
var _cutin_mask_mat: ShaderMaterial = null
var _callout_container: Control = null
var _callout_bg: ColorRect = null
var _callout_label: Label = null
var _impact_overlay_rect: ColorRect = null
var _impact_overlay_mat: ShaderMaterial = null


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_nodes()
	_hide_all()


func _build_nodes() -> void:
	# 1. Capa de dimming / speedlines sobre el mundo congelado (debajo del Cut-In)
	_dim_rect = ColorRect.new()
	_dim_rect.name = "WorldDimOverlay"
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_mat = ShaderMaterial.new()
	_dim_mat.shader = ImpactShatterShader
	_dim_rect.material = _dim_mat
	add_child(_dim_rect)

	# 1b. Escenario 3D Cel-Shaded HDR (Acto 2 fondo / Acto 3 púas y 28 esquirlas 3D)
	_stage_3d = Stage3DScript.new()
	_stage_3d.name = "Ultimate3DStageRig"
	add_child(_stage_3d)

	_stage_3d_bg_display = TextureRect.new()
	_stage_3d_bg_display.name = "Stage3DBgDisplay"
	_stage_3d_bg_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_3d_bg_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_3d_bg_display.stretch_mode = TextureRect.STRETCH_SCALE
	_stage_3d_bg_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_3d_bg_display.texture = _stage_3d.get_texture()
	_stage_3d_bg_display.visible = false
	add_child(_stage_3d_bg_display)

	# 2. SubViewport HDR dedicado para renderizar el Cut-In (Arte Dedicado, LiveBanner 2.5D o CombatRig Pose)
	_cutin_viewport = SubViewport.new()
	_cutin_viewport.name = "CutInHDRViewport"
	_cutin_viewport.size = VIEWPORT_RES
	_cutin_viewport.transparent_bg = true
	_cutin_viewport.use_hdr_2d = true
	_cutin_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_cutin_viewport)

	_cutin_camera = Camera2D.new()
	_cutin_camera.name = "CutInCamera"
	_cutin_camera.ignore_rotation = false
	_cutin_camera.enabled = true
	_cutin_viewport.add_child(_cutin_camera)

	_custom_art_sprite = Sprite2D.new()
	_custom_art_sprite.name = "CustomCutInArtSprite"
	_custom_art_sprite.visible = false
	_custom_art_mat = ShaderMaterial.new()
	_custom_art_mat.shader = CutInSkinCompositeShader
	_custom_art_sprite.material = _custom_art_mat
	_cutin_viewport.add_child(_custom_art_sprite)

	# 3. Display con máscara geométrica (Diagonal / Visor HSR / HUD WuWa / Slash ZZZ)
	_cutin_display = TextureRect.new()
	_cutin_display.name = "CutInMaskedDisplay"
	_cutin_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cutin_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_display.stretch_mode = TextureRect.STRETCH_SCALE
	_cutin_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_display.texture = _cutin_viewport.get_texture()
	_cutin_mask_mat = ShaderMaterial.new()
	_cutin_mask_mat.shader = CutInMaskShader
	_cutin_display.material = _cutin_mask_mat
	add_child(_cutin_display)

	# 4. Callout tipográfico cinemático (ZERO HORIZON // EXECUTE, OPTIC MATRIX // WEAK POINT)
	_callout_container = Control.new()
	_callout_container.name = "CalloutBanner"
	_callout_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_callout_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_callout_container)

	_callout_bg = ColorRect.new()
	_callout_bg.name = "CalloutStrip"
	_callout_bg.color = Color(0.03, 0.015, 0.05, 0.86)
	_callout_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout_container.add_child(_callout_bg)

	_callout_label = Label.new()
	_callout_label.name = "CalloutLabel"
	_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_callout_label.add_theme_font_size_override("font_size", 34)
	_callout_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.98, 1.0))
	_callout_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_callout_label.add_theme_constant_override("shadow_offset_x", 2)
	_callout_label.add_theme_constant_override("shadow_offset_y", 2)
	_callout_bg.add_child(_callout_label)

	# 5. Overlay superior de Impact Frames Full-Screen (B/N Carmesí HDR + Fractura Cristal Obsidiana)
	_impact_overlay_rect = ColorRect.new()
	_impact_overlay_rect.name = "FullscreenImpactOverlay"
	_impact_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_impact_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_overlay_mat = ShaderMaterial.new()
	_impact_overlay_mat.shader = ImpactShatterShader
	_impact_overlay_rect.material = _impact_overlay_mat
	add_child(_impact_overlay_rect)

	# 6. Capa frontal 3D para Acto 3 (24 púas radiales Sakuga 3D y 28 esquirlas obsidiana 3D)
	_stage_3d_fg_display = TextureRect.new()
	_stage_3d_fg_display.name = "Stage3DFgDisplay"
	_stage_3d_fg_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_3d_fg_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_3d_fg_display.stretch_mode = TextureRect.STRETCH_SCALE
	_stage_3d_fg_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_3d_fg_display.texture = _stage_3d.get_texture()
	_stage_3d_fg_display.visible = false
	add_child(_stage_3d_fg_display)

	_palette = PaletteResolverScript.resolve(null)
	set_palette(_palette)


func _ensure_banner_actor() -> void:
	if _banner_ctrl != null and is_instance_valid(_banner_ctrl):
		return
	_banner_ctrl = LiveBannerCtrlScript.new()
	_banner_ctrl.name = "LiveBannerActor"
	if ResourceLoader.exists(DEFAULT_LIVE_BANNER_PATH):
		var cfg: PilotLiveBannerConfig = ResourceLoader.load(DEFAULT_LIVE_BANNER_PATH) as PilotLiveBannerConfig
		if cfg != null:
			_banner_ctrl.set_config(cfg.duplicate(true) as PilotLiveBannerConfig)
	_cutin_viewport.add_child(_banner_ctrl)
	_apply_skins_to_actors()


func _ensure_rig_actor() -> void:
	if _rig_ctrl != null and is_instance_valid(_rig_ctrl):
		return
	_rig_ctrl = PlanarRigScript.new()
	_rig_ctrl.name = "CombatRigPoseActor"
	if ResourceLoader.exists(DEFAULT_PROFILE_PATH):
		_rig_ctrl.pilot_profile = ResourceLoader.load(DEFAULT_PROFILE_PATH)
	_rig_ctrl.enable_live_animations = true
	_rig_ctrl.enable_face_live = true
	_rig_ctrl.enable_3d_wings = false
	_rig_ctrl.enable_base_propulsion_wings = true
	_cutin_viewport.add_child(_rig_ctrl)
	_apply_skins_to_actors()


func set_skin_presets(pilot_skin: PilotSkinPreset, pilot_stars: int = 1, wings_skin: PilotSkinPreset = null, wings_stars: int = 1) -> void:
	_pilot_skin = pilot_skin
	_pilot_stars = clampi(pilot_stars, 1, 3)
	_wings_skin = wings_skin
	_wings_stars = clampi(wings_stars, 1, 3)

	var eff_skin: PilotSkinPreset = _wings_skin if _wings_skin != null else _pilot_skin
	var resolved: Dictionary = PaletteResolverScript.resolve(eff_skin)
	var suit_dark: Color = eff_skin.suit_dark_color if (eff_skin != null and not eff_skin.is_base_skin) else Color(0.06, 0.04, 0.11, 1.0)
	set_palette(resolved, suit_dark)
	_apply_skins_to_actors()


func set_palette(palette: Dictionary, suit_dark: Color = Color(0.06, 0.04, 0.11, 1.0)) -> void:
	_palette = palette
	if palette.has("accent"):
		_accent_color = palette["accent"] as Color
	if palette.has("contrast_crosshair"):
		_contrast_color = palette["contrast_crosshair"] as Color
	if palette.has("stage_bg"):
		_stage_bg_color = palette["stage_bg"] as Color
	if _stage_3d != null:
		_stage_3d.apply_palette(palette, suit_dark)
	_sync_custom_art_shader(false)


func get_stage_3d() -> Ultimate3DStageRig:
	return _stage_3d


func _sync_custom_art_shader(is_ultimate_3d: bool) -> void:
	if _custom_art_mat == null:
		return
	var is_base: float = 1.0 if (_pilot_skin == null or _pilot_skin.is_base_skin) else 0.0
	_custom_art_mat.set_shader_parameter("skin_accent_color", _accent_color)
	_custom_art_mat.set_shader_parameter("contrast_crosshair_color", _contrast_color)
	_custom_art_mat.set_shader_parameter("is_base_skin", is_base)
	if is_ultimate_3d and _ult_cfg != null:
		_custom_art_mat.set_shader_parameter("bg_key_threshold", _ult_cfg.art_bg_key_threshold)
		_custom_art_mat.set_shader_parameter("recolor_strength", _ult_cfg.art_recolor_strength)
		_custom_art_mat.set_shader_parameter("enable_bg_key", 1.0 if _ult_cfg.enable_3d_stage else 0.0)
	else:
		_custom_art_mat.set_shader_parameter("bg_key_threshold", 0.16)
		_custom_art_mat.set_shader_parameter("recolor_strength", 0.85)
		_custom_art_mat.set_shader_parameter("enable_bg_key", 0.0)


func _apply_skins_to_actors() -> void:
	if _banner_ctrl != null and is_instance_valid(_banner_ctrl):
		_banner_ctrl.apply_skin_preset(_pilot_skin, _pilot_stars)
		_banner_ctrl.apply_wings_skin_preset(_wings_skin, _wings_stars)
	if _rig_ctrl != null and is_instance_valid(_rig_ctrl):
		if _pilot_skin != null:
			_rig_ctrl.apply_skin_preset(_pilot_skin, _pilot_stars)
		_rig_ctrl.apply_wings_skin_preset(_wings_skin, _wings_stars)


func set_time_scale(scale_val: float) -> void:
	_time_scale = clampf(scale_val, 0.05, 2.0)


func set_frozen(frozen: bool) -> void:
	_is_frozen = frozen


func is_playing() -> bool:
	return _mode != ActiveMode.NONE


func get_normalized_progress() -> float:
	if _total_duration <= 0.001:
		return 0.0
	return clampf(_elapsed / _total_duration, 0.0, 1.0)


func get_current_phase_name() -> String:
	if _mode == ActiveMode.NONE:
		return "IDLE"
	if _mode == ActiveMode.SKILL and _skill_cfg != null:
		var cutin_end: float = maxf(0.05, _skill_cfg.time_stop_sec - _skill_cfg.impact_frame_sec)
		return "SKILL_CUTIN" if _elapsed < cutin_end else "SKILL_IMPACT_FRAME"
	if _mode == ActiveMode.ULTIMATE and _ult_cfg != null:
		var t1: float = _ult_cfg.cutin_phase_sec
		var t_beat1_end: float = t1 + _ult_cfg.impact_bw_phase_sec * 0.52
		var t2: float = t1 + _ult_cfg.impact_bw_phase_sec
		var t3: float = t2 + _ult_cfg.impact_shatter_phase_sec
		if _elapsed < t1:
			return "ULT_3D_STAGE_CUTIN" if _ult_cfg.enable_3d_stage else "ULT_WALLPAPER_CUTIN"
		elif _elapsed < t_beat1_end:
			return "ULT_IMPACT_BEAT1_BW"
		elif _elapsed < t2:
			return "ULT_IMPACT_BEAT2_CONTRAST"
		elif _elapsed < t3:
			return "ULT_IMPACT_BEAT3_SHATTER_3D"
		return "ULT_RELEASE_FLASH"
	return "IDLE"


func _load_custom_art(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	if _custom_art_cache.has(res_path):
		return _custom_art_cache[res_path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_p: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_p):
			var img: Image = Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_custom_art_cache[res_path] = tex
	return tex


func _fit_custom_art(tex: Texture2D) -> void:
	if _custom_art_sprite == null or tex == null:
		return
	_custom_art_sprite.texture = tex
	var sz: Vector2 = tex.get_size()
	var scale_fit: float = maxf(float(VIEWPORT_RES.x) / maxf(sz.x, 1.0), float(VIEWPORT_RES.y) / maxf(sz.y, 1.0))
	_custom_art_sprite.scale = Vector2(scale_fit, scale_fit)
	_custom_art_sprite.position = Vector2.ZERO
	_custom_art_sprite.visible = true


func play_skill_cutin(cfg: PilotSkillConfig, center_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	_skill_cfg = cfg if cfg != null else SkillConfigScript.new()
	_skill_cfg.ensure_defaults()
	_ult_cfg = null
	_mode = ActiveMode.SKILL
	_elapsed = 0.0
	_total_duration = _skill_cfg.time_stop_sec
	_impact_center_uv = center_uv.clamp(Vector2.ZERO, Vector2.ONE)
	_release_emitted = false
	_last_impact_phase = -1

	var custom_tex: Texture2D = _load_custom_art(_skill_cfg.cutin_art_path) if _skill_cfg.use_custom_cutin_art else null
	if custom_tex != null:
		_fit_custom_art(custom_tex)
		if _banner_ctrl != null:
			_banner_ctrl.visible = false
		if _rig_ctrl != null:
			_rig_ctrl.visible = false
	else:
		if _custom_art_sprite != null:
			_custom_art_sprite.visible = false
		_ensure_banner_actor()
		if _rig_ctrl != null:
			_rig_ctrl.visible = false
		if _banner_ctrl != null:
			_banner_ctrl.visible = true
			_banner_ctrl.reset_select_sequence()
			_banner_ctrl.trigger_hover_impulse(0.65)
	_cutin_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_callout_label.text = _skill_cfg.callout_text
	_evaluate_current_frame(0.0)


func play_ultimate_cutin(cfg: PilotUltimateConfig, center_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	_ult_cfg = cfg if cfg != null else UltimateConfigScript.new()
	_ult_cfg.ensure_defaults()
	_skill_cfg = null
	_mode = ActiveMode.ULTIMATE
	_elapsed = 0.0
	_total_duration = _ult_cfg.total_timestop_sec
	_impact_center_uv = center_uv.clamp(Vector2.ZERO, Vector2.ONE)
	_secondary_color = _ult_cfg.secondary_crack_color
	_release_emitted = false
	_last_impact_phase = -1

	if _stage_3d != null:
		_stage_3d.configure_from_ult(_ult_cfg)
	_sync_ultimate_actor_mode()
	_sync_custom_art_shader(true)
	_cutin_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_callout_label.text = _ult_cfg.callout_title
	_evaluate_current_frame(0.0)


func _sync_ultimate_actor_mode() -> void:
	if _ult_cfg == null:
		return
	if _ult_cfg.render_mode == PilotUltimateConfig.CutInRenderMode.CUSTOM_CUTIN_ART:
		var custom_tex: Texture2D = _load_custom_art(_ult_cfg.cutin_art_path)
		if custom_tex != null:
			_fit_custom_art(custom_tex)
			if _banner_ctrl != null:
				_banner_ctrl.visible = false
			if _rig_ctrl != null:
				_rig_ctrl.visible = false
			return
	if _custom_art_sprite != null:
		_custom_art_sprite.visible = false
	if _ult_cfg.render_mode == PilotUltimateConfig.CutInRenderMode.LIVE_BANNER_25D:
		_ensure_banner_actor()
		if _rig_ctrl != null:
			_rig_ctrl.visible = false
		if _banner_ctrl != null:
			_banner_ctrl.visible = true
			_banner_ctrl.trigger_select_sequence()
	else:
		_ensure_rig_actor()
		if _banner_ctrl != null:
			_banner_ctrl.visible = false
		if _rig_ctrl != null:
			_rig_ctrl.visible = true
			var dir_v: Vector2 = _ult_cfg.rig_view_direction.normalized() if _ult_cfg.rig_view_direction.length_squared() > 0.001 else Vector2(0.7, 0.7)
			_rig_ctrl.set_locomotion_state(dir_v, 0.25, dir_v, true)
			_rig_ctrl.set_face_overfocus_boost(_ult_cfg.eye_flare_boost)


func scrub_to_normalized(t_norm: float) -> void:
	if _mode == ActiveMode.NONE or _total_duration <= 0.001:
		return
	_elapsed = clampf(t_norm, 0.0, 1.0) * _total_duration
	if _mode == ActiveMode.ULTIMATE:
		_sync_ultimate_actor_mode()
	_evaluate_current_frame(0.016)


func refresh_live_config() -> void:
	if _mode == ActiveMode.NONE:
		return
	if _mode == ActiveMode.ULTIMATE and _ult_cfg != null:
		_ult_cfg.ensure_defaults()
		_total_duration = _ult_cfg.total_timestop_sec
		_secondary_color = _ult_cfg.secondary_crack_color
		_callout_label.text = _ult_cfg.callout_title
		_sync_ultimate_actor_mode()
	elif _mode == ActiveMode.SKILL and _skill_cfg != null:
		_skill_cfg.ensure_defaults()
		_total_duration = _skill_cfg.time_stop_sec
		_callout_label.text = _skill_cfg.callout_text
	_evaluate_current_frame(0.0)


func stop_and_hide() -> void:
	_mode = ActiveMode.NONE
	_elapsed = 0.0
	_total_duration = 0.0
	_release_emitted = false
	_last_impact_phase = -1
	_hide_all()


func _hide_all() -> void:
	if _dim_rect != null:
		_dim_rect.visible = false
	if _stage_3d_bg_display != null:
		_stage_3d_bg_display.visible = false
	if _stage_3d_fg_display != null:
		_stage_3d_fg_display.visible = false
	if _stage_3d != null:
		_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.HIDDEN, 0.0, 0.0)
	if _cutin_display != null:
		_cutin_display.visible = false
	if _callout_container != null:
		_callout_container.visible = false
	if _impact_overlay_rect != null:
		_impact_overlay_rect.visible = false
	if _cutin_viewport != null:
		_cutin_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if _mode == ActiveMode.NONE:
		return
	var step_dt: float = 0.0 if _is_frozen else (clampf(delta, 0.0, 0.05) * _time_scale)
	_elapsed += step_dt
	_evaluate_current_frame(step_dt)

	if not _is_frozen and _elapsed >= _total_duration:
		var finished_mode: StringName = &"skill" if _mode == ActiveMode.SKILL else &"ultimate"
		if not _release_emitted:
			_release_emitted = true
			cutin_release_reached.emit(finished_mode)
		stop_and_hide()
		cutin_finished.emit(finished_mode)


func _evaluate_current_frame(step_dt: float) -> void:
	if _mode == ActiveMode.SKILL and _skill_cfg != null:
		_eval_skill_frame(step_dt)
	elif _mode == ActiveMode.ULTIMATE and _ult_cfg != null:
		_eval_ultimate_frame(step_dt)


func _eval_skill_frame(_step_dt: float) -> void:
	var cfg: PilotSkillConfig = _skill_cfg
	var cutin_end: float = maxf(0.05, cfg.time_stop_sec - cfg.impact_frame_sec)
	var t_norm: float = clampf(_elapsed / maxf(cfg.time_stop_sec, 0.001), 0.0, 1.0)
	var reveal: float = clampf(_elapsed / 0.10, 0.0, 1.0)

	# Encuadre del Ojo Amatista + Monóculo HUD (arte dedicado o fallback LiveBanner)
	if _custom_art_sprite != null and _custom_art_sprite.visible:
		_cutin_camera.position = cfg.eye_uv_offset * 220.0 + Vector2(lerpf(-28.0, 22.0, ease(t_norm, 0.4)), sin(_elapsed * 5.0) * 3.5)
		var z_c: float = cfg.eye_zoom_scale + ease(t_norm, 0.35) * 0.22
		_cutin_camera.zoom = Vector2(z_c, z_c)
	else:
		_cutin_camera.position = Vector2(0.0, -238.0) + cfg.eye_uv_offset * 320.0 + Vector2(t_norm * 18.0, 0.0)
		var z: float = cfg.eye_zoom_scale + t_norm * 0.16
		_cutin_camera.zoom = Vector2(z, z)
	_cutin_camera.rotation_degrees = cfg.strip_angle_deg * 0.18

	# En Skill [R] ocultar el escenario 3D y mantener shader del arte sin recorte de fondo
	if _stage_3d_bg_display != null:
		_stage_3d_bg_display.visible = false
	if _stage_3d_fg_display != null:
		_stage_3d_fg_display.visible = false
	if _stage_3d != null:
		_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.HIDDEN, 0.0, 0.0)
	_sync_custom_art_shader(false)

	# Dimming detrás de la franja
	_dim_rect.visible = true
	_dim_mat.set_shader_parameter("effect_phase", 0)
	_dim_mat.set_shader_parameter("effect_intensity", 0.72)
	_dim_mat.set_shader_parameter("center_uv", _impact_center_uv)
	_dim_mat.set_shader_parameter("accent_color", _accent_color)
	_dim_mat.set_shader_parameter("contrast_color", _contrast_color)
	_dim_mat.set_shader_parameter("stage_bg_color", _stage_bg_color)
	_dim_mat.set_shader_parameter("radial_speedlines_strength", 0.55)
	_dim_mat.set_shader_parameter("time_sec", _elapsed)

	# Máscara de Cut-In (0=Diagonal, 1=Visor HSR, 2=HUD WuWa)
	_cutin_display.visible = true
	_cutin_mask_mat.set_shader_parameter("mask_mode", int(cfg.cutin_style))
	_cutin_mask_mat.set_shader_parameter("reveal_progress", ease(reveal, 0.25))
	_cutin_mask_mat.set_shader_parameter("strip_angle_deg", cfg.strip_angle_deg)
	_cutin_mask_mat.set_shader_parameter("strip_height_ratio", cfg.strip_height_ratio)
	_cutin_mask_mat.set_shader_parameter("strip_y_ratio", cfg.strip_y_ratio)
	_cutin_mask_mat.set_shader_parameter("accent_color", _accent_color)
	_cutin_mask_mat.set_shader_parameter("time_sec", _elapsed)

	# Callout
	_layout_callout(cfg.strip_y_ratio + cfg.strip_height_ratio * 0.55, 0.52, _elapsed < cutin_end)

	# Impact Frame Sakuga B/N (2 beats invertidos) al final del Time-Stop de Skill
	if _elapsed >= cutin_end:
		if _last_impact_phase != 1:
			_last_impact_phase = 1
			cutin_impact_frame_entered.emit(1)
		var imp_norm: float = clampf((_elapsed - cutin_end) / maxf(cfg.impact_frame_sec, 0.001), 0.0, 1.0)
		var strobe: float = 0.0 if imp_norm < 0.5 else 1.0
		_impact_overlay_rect.visible = true
		_impact_overlay_mat.set_shader_parameter("effect_phase", 1)
		_impact_overlay_mat.set_shader_parameter("effect_intensity", 1.0)
		_impact_overlay_mat.set_shader_parameter("bw_invert_strobe", strobe)
		_impact_overlay_mat.set_shader_parameter("center_uv", _impact_center_uv)
		_impact_overlay_mat.set_shader_parameter("accent_color", _accent_color)
		_impact_overlay_mat.set_shader_parameter("bw_luma_threshold", cfg.bw_luma_threshold)
		_impact_overlay_mat.set_shader_parameter("accent_hdr_boost", cfg.accent_hdr_boost)
		_impact_overlay_mat.set_shader_parameter("radial_speedlines_strength", 0.95)
		_impact_overlay_mat.set_shader_parameter("chromatic_aberration_px", 10.0)
		_impact_overlay_mat.set_shader_parameter("time_sec", _elapsed)
	else:
		_impact_overlay_rect.visible = false


func _eval_ultimate_frame(_step_dt: float) -> void:
	var cfg: PilotUltimateConfig = _ult_cfg
	var t1: float = cfg.cutin_phase_sec
	var t2: float = t1 + cfg.impact_bw_phase_sec
	var t3: float = t2 + cfg.impact_shatter_phase_sec
	var cutin_norm: float = clampf(_elapsed / maxf(t1, 0.001), 0.0, 1.0)
	var reveal: float = clampf(_elapsed / 0.12, 0.0, 1.0)

	# Cámara Wallpaper Engine (Close-Up animado + drift suave + Dutch Tilt + pulso orgánico)
	var drift: Vector2 = cfg.camera_drift_px * ease(cutin_norm, 0.45)
	if cfg.render_mode == PilotUltimateConfig.CutInRenderMode.CUSTOM_CUTIN_ART and _custom_art_sprite != null and _custom_art_sprite.visible:
		var breath_y: float = sin(_elapsed * 3.4 * cfg.breath_speed_mult) * 5.0
		_cutin_camera.position = Vector2(cfg.face_focus_offset_px.x, -cfg.face_focus_offset_px.y * 0.4) + drift + Vector2(0.0, breath_y)
		var z_art: float = cfg.face_closeup_zoom + ease(cutin_norm, 0.35) * 0.24
		_cutin_camera.zoom = Vector2(z_art, z_art)
	elif cfg.render_mode == PilotUltimateConfig.CutInRenderMode.LIVE_BANNER_25D:
		_cutin_camera.position = Vector2(0.0, -cfg.face_focus_offset_px.y) + Vector2(cfg.face_focus_offset_px.x, 0.0) + drift
		var z_b: float = cfg.face_closeup_zoom + cutin_norm * 0.22
		_cutin_camera.zoom = Vector2(z_b, z_b)
	else:
		_cutin_camera.position = Vector2(cfg.face_focus_offset_px.x, -cfg.face_focus_offset_px.y * 0.38) + drift * 0.55
		var z_r: float = cfg.rig_closeup_zoom + cutin_norm * 0.28
		_cutin_camera.zoom = Vector2(z_r, z_r)
		if _rig_ctrl != null:
			var sway: float = sin(_elapsed * 3.8 * cfg.breath_speed_mult) * 2.5
			_rig_ctrl.rotation_degrees = cfg.rig_torso_lean_deg + sway * 0.35
			_rig_ctrl.position = Vector2(0.0, sin(_elapsed * 2.6 * cfg.breath_speed_mult) * 6.0)
	_cutin_camera.rotation_degrees = cfg.dutch_tilt_deg * (0.65 + 0.35 * cutin_norm)

	# Máscara de composición (3=Asymmetric Slash, 4=Fullscreen Bleed, 5=Letterbox)
	var mask_idx: int = 3
	if cfg.frame_composition == PilotUltimateConfig.FrameComposition.FULLSCREEN_BLEED:
		mask_idx = 4
	elif cfg.frame_composition == PilotUltimateConfig.FrameComposition.CINEMATIC_LETTERBOX:
		mask_idx = 5

	var show_cutin: bool = _elapsed < t3
	_dim_rect.visible = show_cutin
	_dim_mat.set_shader_parameter("effect_phase", 0)
	_dim_mat.set_shader_parameter("effect_intensity", 0.85)
	_dim_mat.set_shader_parameter("center_uv", _impact_center_uv)
	_dim_mat.set_shader_parameter("accent_color", _accent_color)
	_dim_mat.set_shader_parameter("contrast_color", _contrast_color)
	_dim_mat.set_shader_parameter("stage_bg_color", _stage_bg_color)
	_dim_mat.set_shader_parameter("radial_speedlines_strength", cfg.radial_speedlines_strength)
	_dim_mat.set_shader_parameter("time_sec", _elapsed)

	_sync_custom_art_shader(true)
	if _stage_3d != null:
		_stage_3d.configure_from_ult(cfg)

	_cutin_display.visible = show_cutin
	_cutin_mask_mat.set_shader_parameter("mask_mode", mask_idx)
	_cutin_mask_mat.set_shader_parameter("reveal_progress", ease(reveal, 0.22))
	_cutin_mask_mat.set_shader_parameter("accent_color", _accent_color)
	_cutin_mask_mat.set_shader_parameter("time_sec", _elapsed)

	_layout_callout(0.76, 0.62, _elapsed < t2)

	# Acto 2 (Escenario 3D detrás) & Acto 3 (3 Beats: B/N + Púas 3D -> Negativo Contrastante -> 28 Esquirlas 3D)
	var t_beat1_end: float = t1 + cfg.impact_bw_phase_sec * 0.52
	if _elapsed < t1:
		_impact_overlay_rect.visible = false
		if _stage_3d_fg_display != null:
			_stage_3d_fg_display.visible = false
		if _stage_3d != null and _stage_3d_bg_display != null:
			_stage_3d_bg_display.visible = cfg.enable_3d_stage
			if cfg.enable_3d_stage:
				_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.ACT2_CUTIN_STAGE, cutin_norm, _elapsed)
			else:
				_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.HIDDEN, 0.0, _elapsed)
	elif _elapsed < t_beat1_end:
		# Beat 1: B/N Binario + Sobel + 24 Púas Radiales 3D
		if _last_impact_phase != 1:
			_last_impact_phase = 1
			cutin_impact_frame_entered.emit(1)
		var b1_t: float = clampf((_elapsed - t1) / maxf(t_beat1_end - t1, 0.001), 0.0, 1.0)
		_impact_overlay_mat.set_shader_parameter("bw_invert_strobe", 0.0)
		_push_impact_overlay(1, 1.0, cfg)
		if _stage_3d_bg_display != null:
			_stage_3d_bg_display.visible = false
		if _stage_3d != null and _stage_3d_fg_display != null:
			_stage_3d_fg_display.visible = cfg.enable_3d_stage
			if cfg.enable_3d_stage:
				_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.ACT3_BEAT1_SPIKES, b1_t, _elapsed)
	elif _elapsed < t2:
		# Beat 2: Negativo invertido + corte quirúrgico en contrast_crosshair + Púas 3D contrastantes
		if _last_impact_phase != 2:
			_last_impact_phase = 2
			cutin_impact_frame_entered.emit(2)
		var b2_t: float = clampf((_elapsed - t_beat1_end) / maxf(t2 - t_beat1_end, 0.001), 0.0, 1.0)
		_impact_overlay_mat.set_shader_parameter("bw_invert_strobe", 1.0)
		_push_impact_overlay(1, 1.0, cfg)
		if _stage_3d_bg_display != null:
			_stage_3d_bg_display.visible = false
		if _stage_3d != null and _stage_3d_fg_display != null:
			_stage_3d_fg_display.visible = cfg.enable_3d_stage
			if cfg.enable_3d_stage:
				_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.ACT3_BEAT2_CONTRAST, b2_t, _elapsed)
	elif _elapsed < t3:
		# Beat 3: Fractura Voronoi Obsidiana + 28 Esquirlas 3D explotando hacia la cámara
		if _last_impact_phase != 3:
			_last_impact_phase = 3
			cutin_impact_frame_entered.emit(3)
		var b3_t: float = clampf((_elapsed - t2) / maxf(cfg.impact_shatter_phase_sec, 0.001), 0.0, 1.0)
		_push_impact_overlay(2, 0.98, cfg)
		if _stage_3d_bg_display != null:
			_stage_3d_bg_display.visible = false
		if _stage_3d != null and _stage_3d_fg_display != null:
			_stage_3d_fg_display.visible = cfg.enable_3d_stage
			if cfg.enable_3d_stage:
				_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.ACT3_BEAT3_SHATTER, b3_t, _elapsed)
	else:
		if not _release_emitted:
			_release_emitted = true
			cutin_release_reached.emit(&"ultimate")
		if _stage_3d_bg_display != null:
			_stage_3d_bg_display.visible = false
		if _stage_3d_fg_display != null:
			_stage_3d_fg_display.visible = false
		if _stage_3d != null:
			_stage_3d.set_stage_state(Ultimate3DStageRig.StageMode.HIDDEN, 0.0, _elapsed)
		var rel_t: float = 1.0 - clampf((_elapsed - t3) / maxf(cfg.release_flash_sec, 0.001), 0.0, 1.0)
		_push_impact_overlay(3, rel_t, cfg)


func _push_impact_overlay(phase: int, intensity: float, cfg: PilotUltimateConfig) -> void:
	_impact_overlay_rect.visible = intensity > 0.005
	_impact_overlay_mat.set_shader_parameter("effect_phase", phase)
	_impact_overlay_mat.set_shader_parameter("effect_intensity", intensity)
	_impact_overlay_mat.set_shader_parameter("center_uv", _impact_center_uv)
	_impact_overlay_mat.set_shader_parameter("accent_color", _accent_color)
	_impact_overlay_mat.set_shader_parameter("contrast_color", _contrast_color)
	_impact_overlay_mat.set_shader_parameter("secondary_color", _secondary_color)
	_impact_overlay_mat.set_shader_parameter("stage_bg_color", _stage_bg_color)
	_impact_overlay_mat.set_shader_parameter("bw_luma_threshold", cfg.bw_luma_threshold)
	_impact_overlay_mat.set_shader_parameter("accent_hdr_boost", cfg.accent_hdr_boost)
	_impact_overlay_mat.set_shader_parameter("shatter_cell_density", cfg.shatter_cell_density)
	_impact_overlay_mat.set_shader_parameter("shatter_crack_width_px", cfg.shatter_crack_width_px)
	_impact_overlay_mat.set_shader_parameter("shatter_refraction_px", cfg.shatter_refraction_px)
	_impact_overlay_mat.set_shader_parameter("radial_speedlines_strength", cfg.radial_speedlines_strength)
	_impact_overlay_mat.set_shader_parameter("chromatic_aberration_px", cfg.chromatic_aberration_px)
	_impact_overlay_mat.set_shader_parameter("time_sec", _elapsed)


func _layout_callout(y_ratio: float, width_ratio: float, show: bool) -> void:
	_callout_container.visible = show
	if not show:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280.0, 720.0)
	var w: float = vp_size.x * width_ratio
	var h: float = 52.0
	_callout_bg.size = Vector2(w, h)
	_callout_bg.position = Vector2((vp_size.x - w) * 0.5, vp_size.y * y_ratio - h * 0.5)
	_callout_label.size = Vector2(w, h)
	_callout_label.position = Vector2.ZERO
