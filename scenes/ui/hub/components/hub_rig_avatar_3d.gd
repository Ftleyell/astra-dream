class_name HubRigAvatar3D
extends Node3D
## Avatar 2.5D vivo de Valentina v2 para el Hub 3D.
## Renderiza PlanarCombatRig (sin alas ni anillo orbital) dentro de un SubViewport HDR 2D (MSAA 4x)
## proyectado sobre un Sprite3D inclinado para cámara fija 2.5D Diorama, con levitación Zero-G.

const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const HubDioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: HubDioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")
const OrbitalRingCtrlScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const OrbitalConfigScript = preload("res://data/pilots/schemas/pilot_orbital_weapon_config.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const DEFAULT_GROUNDED_CFG: GroundedConfigScript = preload("res://data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

signal footstep_triggered(foot: StringName, strength: float)
const Pilot3DIntegrateShader = preload("res://scenes/ui/hub/shaders/hub_pilot_3d_integrate.gdshader")
const DEFAULT_ORBITAL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const DEFAULT_RING_TEXTURE_PATH: String = "res://assets/pilots/valentina_v2/planar/weapons/valentina_mecha_ring_packed.png"

@export var diorama_config: HubDioramaConfigScript = DEFAULT_DIORAMA_CONFIG
@export var enable_3d_scene_lighting: bool = false

var _subviewport: SubViewport = null
var _camera_2d: Camera2D = null
var _rig: PlanarCombatRig = null
var _orbital_ring: OrbitalRingCtrlScript = null
var _avatar_sprite: Sprite3D = null
var _integrate_3d_mat: ShaderMaterial = null

var _loaded_profile: PilotRigProfile = null
var _current_style: RigStyleProfile = null
var _current_skin: PilotSkinPreset = null
var _current_wings_skin: PilotSkinPreset = null
var _current_weapon_skin: PilotSkinPreset = null
var _current_star_level: int = 1
var _current_wings_star_level: int = 1
var _current_weapon_star_level: int = 1
var _orbital_weapon_enabled: bool = false
var _wings_3d_showcase_enabled: bool = false
var _is_flight_traversal: bool = false
var _wing_bloom_settle_timer: float = 0.0
var _wing_fold_pending: bool = false
var _light_dir_2d: Vector2 = Vector2(0.45, -0.89).normalized()

var _hover_time: float = 0.0
var _hover_factor: float = 0.5
var _showcase_lift_y: float = 0.0
var _target_tilt_deg: float = -22.0
var _launch_scale_mult: float = 1.0
var _sprite_opacity: float = 1.0
var _preview_anim_kind: StringName = &""
var _preview_anim_timer: float = 0.0
var _preview_anim_duration: float = 0.0
var _preview_weapon_fired: bool = false
var _last_move_dir: Vector2 = Vector2.DOWN
var _last_aim_dir: Vector2 = Vector2.DOWN
var _last_speed_norm: float = 0.0
var _is_initialized: bool = false


func _ready() -> void:
	_ensure_nodes_ready()


func _process(delta: float) -> void:
	_ensure_nodes_ready()
	if _subviewport == null or _avatar_sprite == null:
		return

	var visible_now: bool = is_visible_in_tree()
	var target_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if visible_now else SubViewport.UPDATE_DISABLED
	if _subviewport.render_target_update_mode != target_mode:
		_subviewport.render_target_update_mode = target_mode
	if not visible_now:
		return

	var cfg: HubDioramaConfigScript = _resolve_config()
	_hover_time += delta
	_step_preview_micro_animation(delta)
	_step_flight_wing_transitions(delta)
	var preview_lift: float = _compute_preview_lift()
	if is_grounded_mode():
		var g_cfg: GroundedConfigScript = get_grounded_config()
		var lift_norm: float = _rig.get_grounded_pelvis_lift_norm() if _rig != null else 0.0
		var floor_y: float = g_cfg.hub_avatar_floor_y if g_cfg != null else 0.008
		var is_glide: bool = g_cfg != null and g_cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP
		var is_moon: bool = g_cfg != null and g_cfg.gait_style == GroundedConfigScript.GaitStyle.MOON_HOP
		var step_lift_m: float = 0.028
		if is_glide:
			step_lift_m = g_cfg.glide_3d_lift_m
		elif g_cfg != null:
			step_lift_m = g_cfg.hub_step_lift_3d_m
		_avatar_sprite.position.y = floor_y + lift_norm * step_lift_m + _showcase_lift_y + preview_lift
		_hover_factor = clampf(lift_norm if (is_glide or is_moon) else (lift_norm * 0.65), 0.0, 1.0)
		if _rig != null:
			var step_ev: Dictionary = _rig.consume_grounded_step_event()
			if not step_ev.is_empty():
				footstep_triggered.emit(step_ev.get("foot", &"left") as StringName, float(step_ev.get("strength", 0.7)))
	else:
		var wave: float = 0.5 + 0.5 * sin(_hover_time * TAU * cfg.avatar_idle_bob_hz)
		var amp_mult: float = lerpf(1.0, 0.45, clampf(_last_speed_norm, 0.0, 1.0))
		var bob_y: float = (wave - 0.5) * 2.0 * cfg.avatar_idle_bob_amp * amp_mult
		_avatar_sprite.position.y = cfg.avatar_hover_height + bob_y + _showcase_lift_y + preview_lift
		_hover_factor = clampf(0.25 + wave * 0.45, 0.0, 1.0)
	_avatar_sprite.scale = Vector3(_launch_scale_mult, cfg.avatar_aspect_y_comp * _launch_scale_mult, 1.0)
	if absf(_avatar_sprite.rotation_degrees.x - _target_tilt_deg) > 0.05:
		_avatar_sprite.rotation_degrees.x = lerpf(_avatar_sprite.rotation_degrees.x, _target_tilt_deg, clampf(10.0 * delta, 0.0, 1.0))
	if _orbital_weapon_enabled and _orbital_ring != null and is_instance_valid(_orbital_ring):
		_orbital_ring.step(delta)


func _resolve_config() -> HubDioramaConfigScript:
	if diorama_config != null:
		return diorama_config
	return DEFAULT_DIORAMA_CONFIG


func _resolve_default_profile(cfg: HubDioramaConfigScript) -> PilotRigProfile:
	if _loaded_profile != null:
		return _loaded_profile
	if ResourceLoader.exists(cfg.default_profile_path):
		return ResourceLoader.load(cfg.default_profile_path) as PilotRigProfile
	return null


func _resolve_default_style(profile: PilotRigProfile, cfg: HubDioramaConfigScript) -> RigStyleProfile:
	if profile != null:
		for st: RigStyleProfile in profile.style_profiles:
			if st != null and st.id == "02_valentina_razor_sharp":
				return st
	if ResourceLoader.exists(cfg.default_style_path):
		return ResourceLoader.load(cfg.default_style_path) as RigStyleProfile
	return null


func _ensure_nodes_ready() -> void:
	if _is_initialized and is_instance_valid(_subviewport) and is_instance_valid(_rig) and is_instance_valid(_avatar_sprite):
		return

	var cfg: HubDioramaConfigScript = _resolve_config()
	_light_dir_2d = cfg.hub_light_dir_2d.normalized() if cfg.hub_light_dir_2d.length_squared() > 0.0001 else Vector2(0.45, -0.89).normalized()

	_subviewport = get_node_or_null("AvatarSubViewport") as SubViewport
	if _subviewport == null:
		_subviewport = SubViewport.new()
		_subviewport.name = "AvatarSubViewport"
		add_child(_subviewport)
	_subviewport.size = Vector2i(cfg.viewport_size, cfg.viewport_size)
	_subviewport.disable_3d = true
	_subviewport.transparent_bg = true
	_subviewport.use_hdr_2d = true
	_subviewport.msaa_2d = Viewport.MSAA_4X
	_subviewport.handle_input_locally = false
	_subviewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_camera_2d = _subviewport.get_node_or_null("AvatarCamera2D") as Camera2D
	if _camera_2d == null:
		_camera_2d = Camera2D.new()
		_camera_2d.name = "AvatarCamera2D"
		_subviewport.add_child(_camera_2d)
	_camera_2d.enabled = true
	_camera_2d.position = cfg.rig_camera_center_offset
	_camera_2d.zoom = Vector2(cfg.rig_camera_zoom, cfg.rig_camera_zoom)

	var resolved_profile: PilotRigProfile = _resolve_default_profile(cfg)
	_loaded_profile = resolved_profile

	_rig = _subviewport.get_node_or_null("PlanarCombatRig") as PlanarCombatRig
	if _rig == null:
		_rig = PlanarCombatRigScript.new() as PlanarCombatRig
		_rig.name = "PlanarCombatRig"
		_rig.pilot_profile = resolved_profile
		_rig.enable_live_animations = true
		_rig.enable_face_live = true
		_rig.enable_base_propulsion_wings = false
		_rig.enable_3d_wings = false
		_rig.enable_procedural_wings = false
		_rig.enable_boot_thrusters = false
		_rig.enable_afterimage = false
		_rig.z_index = 5
		_rig.position = Vector2.ZERO
		_subviewport.add_child(_rig)

	_apply_hub_rig_visuals(resolved_profile, cfg)

	_avatar_sprite = get_node_or_null("AvatarSprite3D") as Sprite3D
	if _avatar_sprite == null:
		_avatar_sprite = Sprite3D.new()
		_avatar_sprite.name = "AvatarSprite3D"
		add_child(_avatar_sprite)
	_avatar_sprite.texture = _subviewport.get_texture()
	_avatar_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_target_tilt_deg = cfg.avatar_tilt_deg
	_avatar_sprite.rotation_degrees = Vector3(cfg.avatar_tilt_deg, 0.0, 0.0)
	_avatar_sprite.scale = Vector3(1.0, cfg.avatar_aspect_y_comp, 1.0)
	_avatar_sprite.shaded = false
	_avatar_sprite.double_sided = true
	_avatar_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_avatar_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_avatar_sprite.pixel_size = cfg.avatar_pixel_size
	_avatar_sprite.offset = Vector2(0.0, cfg.avatar_feet_offset_px)
	var init_y: float = get_grounded_config().hub_avatar_floor_y if is_grounded_mode() else cfg.avatar_hover_height
	_avatar_sprite.position = Vector3(0.0, init_y, 0.0)
	_hover_factor = 0.0 if is_grounded_mode() else 0.5
	_avatar_sprite.render_priority = 2
	_avatar_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if enable_3d_scene_lighting:
		set_3d_scene_lighting_enabled(true)

	_is_initialized = true


func _apply_hub_rig_visuals(profile: PilotRigProfile, cfg: HubDioramaConfigScript) -> void:
	if _rig == null:
		return
	_rig.enable_base_propulsion_wings = false
	_rig.enable_3d_wings = false
	_rig.enable_procedural_wings = false
	_rig.enable_boot_thrusters = false
	_rig.enable_afterimage = false
	_rig.set_transition_style(PlanarCombatRig.TransitionStyle.WHIP_SNAP_AFTERIMAGE)

	var style_to_apply: RigStyleProfile = _current_style if _current_style != null else _resolve_default_style(profile, cfg)
	if style_to_apply != null:
		_current_style = style_to_apply
		_rig.apply_style_profile(style_to_apply)

	var skin_to_apply: PilotSkinPreset = _current_skin
	if skin_to_apply == null and profile != null and not profile.skins.is_empty():
		skin_to_apply = profile.skins[0]
	if skin_to_apply != null:
		_current_skin = skin_to_apply
		_rig.apply_skin_preset(skin_to_apply, _current_star_level)

	_rig.set_recolor_method(1)
	_rig.set_hair_style_mode(0)
	set_light_dir_2d(_light_dir_2d)
	_rig.set_zoom_scale(1.05)
	_rig.set_live_animations_enabled(true)
	_rig.set_face_live_enabled(true)
	_sync_rig_locomotion_mode(profile)
	_rig.set_locomotion_state(_last_move_dir, _last_speed_norm, _last_aim_dir, true)


func _sync_rig_locomotion_mode(profile: PilotRigProfile = null) -> void:
	if _rig == null:
		return
	var use_grounded: bool = is_grounded_mode()
	_rig.set_locomotion_mode(PlanarCombatRig.LocomotionMode.GROUNDED_HUB if use_grounded else PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT)
	var p_eff: PilotRigProfile = profile if profile != null else _loaded_profile
	var zero_g_fps: float = p_eff.stepped_fps if p_eff != null else 15.0
	_rig.set_stepped_fps(60.0 if use_grounded else zero_g_fps)


func load_pilot_profile(profile: PilotRigProfile) -> void:
	_ensure_nodes_ready()
	var cfg: HubDioramaConfigScript = _resolve_config()
	var resolved_profile: PilotRigProfile = profile
	if resolved_profile == null:
		resolved_profile = _resolve_default_profile(cfg)
	if resolved_profile == null or _rig == null:
		return

	if _loaded_profile != null and (resolved_profile == _loaded_profile or (resolved_profile.pilot_id == _loaded_profile.pilot_id and not resolved_profile.pilot_id.is_empty())):
		return

	_loaded_profile = resolved_profile
	_current_skin = null
	_rig.enable_base_propulsion_wings = false
	_rig.enable_3d_wings = false
	_rig.enable_procedural_wings = false
	_rig.enable_boot_thrusters = false
	_rig.enable_afterimage = false
	_rig.load_pilot_profile(resolved_profile)
	_apply_hub_rig_visuals(resolved_profile, cfg)


func set_motion_state(move_dir_2d: Vector2, speed_norm: float, aim_dir_2d: Vector2, snap_instant: bool = false) -> void:
	_ensure_nodes_ready()
	if move_dir_2d.length_squared() > 0.002:
		_last_move_dir = move_dir_2d.normalized()
	if aim_dir_2d.length_squared() > 0.002:
		_last_aim_dir = aim_dir_2d.normalized()
	_last_speed_norm = clampf(speed_norm, 0.0, 1.5)
	if _rig != null:
		_rig.set_locomotion_state(_last_move_dir, _last_speed_norm, _last_aim_dir, snap_instant)


func apply_skin_preset(preset: PilotSkinPreset, star_level: int = 1) -> void:
	_ensure_nodes_ready()
	if preset == null:
		return
	_current_skin = preset
	_current_star_level = clampi(star_level, 1, 3)
	if _rig != null:
		_rig.apply_skin_preset(preset, _current_star_level)


func apply_wings_skin_preset(preset: PilotSkinPreset, star_level: int = 1) -> void:
	_ensure_nodes_ready()
	if preset == null:
		return
	_current_wings_skin = preset
	_current_wings_star_level = clampi(star_level, 1, 3)
	if _rig != null:
		_rig.apply_wings_skin_preset(preset, _current_wings_star_level)


func apply_weapon_skin_preset(preset: PilotSkinPreset, star_level: int = 1) -> void:
	_ensure_nodes_ready()
	if preset == null:
		return
	_current_weapon_skin = preset
	_current_weapon_star_level = clampi(star_level, 1, 3)
	if _orbital_ring != null and is_instance_valid(_orbital_ring):
		_orbital_ring.apply_skin_preset(preset, _current_weapon_star_level)


func set_loadout_showcase_enabled(wings_enabled: bool, orbital_weapon_enabled: bool, wings_anim_state: int = -1) -> void:
	_ensure_nodes_ready()
	_wings_3d_showcase_enabled = wings_enabled
	if _rig != null:
		_sync_rig_locomotion_mode()
		_rig.set_3d_wings_enabled(wings_enabled)
		if wings_enabled:
			if wings_anim_state >= 0:
				_rig.set_3d_wings_anim_state(wings_anim_state, false)
			_rig.trigger_3d_wings_pulse()
			if _current_wings_skin != null:
				_rig.apply_wings_skin_preset(_current_wings_skin, _current_wings_star_level)
		else:
			_rig.clear_3d_wings_manual_override()

	_orbital_weapon_enabled = orbital_weapon_enabled
	if orbital_weapon_enabled:
		_ensure_orbital_ring_ready()
		if _orbital_ring != null:
			_orbital_ring.visible = true
			_orbital_ring.process_mode = Node.PROCESS_MODE_INHERIT
			if _current_weapon_skin != null:
				_orbital_ring.apply_skin_preset(_current_weapon_skin, _current_weapon_star_level)
			_orbital_ring.step(0.0)
	elif _orbital_ring != null and is_instance_valid(_orbital_ring):
		_orbital_ring.visible = false
		_orbital_ring.process_mode = Node.PROCESS_MODE_DISABLED


func set_camera_pitch_alignment(cam_pitch_deg: float, snap: bool = false) -> void:
	_ensure_nodes_ready()
	var cfg: HubDioramaConfigScript = _resolve_config()
	var t_closeup: float = clampf((-cam_pitch_deg - 6.0) / 36.0, 0.0, 1.0)
	_target_tilt_deg = lerpf(-3.5, cfg.avatar_tilt_deg, t_closeup)
	if snap and _avatar_sprite != null:
		_avatar_sprite.rotation_degrees.x = _target_tilt_deg
	if _rig != null:
		# t_closeup = 1.0 en FREE_ROAM lejano (líneas SDF más sólidas a 1.05x) y 0.0 en primer plano (1.85x)
		_rig.set_zoom_scale(lerpf(1.85, 1.05, t_closeup))


func set_showcase_lift_offset(extra_y: float) -> void:
	_showcase_lift_y = maxf(0.0, extra_y)
	if _avatar_sprite != null:
		var cfg: HubDioramaConfigScript = _resolve_config()
		var base_y: float = get_grounded_config().hub_avatar_floor_y if is_grounded_mode() else cfg.avatar_hover_height
		_avatar_sprite.position.y = base_y + _showcase_lift_y + _compute_preview_lift()


func feed_world_displacement(dist_m: float) -> void:
	if _rig != null and is_grounded_mode():
		_rig.feed_world_displacement(dist_m)


func trigger_grounded_pivot(turn_sign: float = 1.0) -> void:
	if _rig != null and is_grounded_mode():
		_rig.trigger_grounded_pivot(turn_sign)


func is_grounded_mode() -> bool:
	return not _is_flight_traversal and not _wings_3d_showcase_enabled


func is_flight_traversal_active() -> bool:
	return _is_flight_traversal


func set_flight_traversal_state(is_flying: bool, instant: bool = false) -> void:
	_ensure_nodes_ready()
	if _is_flight_traversal == is_flying and not instant:
		return
	_is_flight_traversal = is_flying
	if _rig == null:
		return

	if is_flying:
		_wing_fold_pending = false
		_wings_3d_showcase_enabled = true
		_sync_rig_locomotion_mode()
		_rig.set_3d_wings_enabled(true)
		if instant:
			_wing_bloom_settle_timer = 0.0
			_rig.clear_3d_wings_manual_override()
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, true)
		else:
			_wing_bloom_settle_timer = 0.58
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM, false)
			_rig.trigger_3d_wings_pulse()
		if _current_wings_skin != null:
			_rig.apply_wings_skin_preset(_current_wings_skin, _current_wings_star_level)
	else:
		_wing_bloom_settle_timer = 0.0
		_sync_rig_locomotion_mode()
		if instant or not _rig.enable_3d_wings:
			_wing_fold_pending = false
			_wings_3d_showcase_enabled = false
			_rig.clear_3d_wings_manual_override()
			_rig.set_3d_wings_enabled(false)
		else:
			_wing_fold_pending = true
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_FOLD, false)


func set_orbital_weapon_deployed(deployed: bool) -> void:
	_ensure_nodes_ready()
	_orbital_weapon_enabled = deployed
	if deployed:
		_ensure_orbital_ring_ready()
		if _orbital_ring != null:
			_orbital_ring.visible = true
			_orbital_ring.process_mode = Node.PROCESS_MODE_INHERIT
			if _current_weapon_skin != null:
				_orbital_ring.apply_skin_preset(_current_weapon_skin, _current_weapon_star_level)
			_orbital_ring.step(0.0)
	elif _orbital_ring != null and is_instance_valid(_orbital_ring):
		_orbital_ring.visible = false
		_orbital_ring.process_mode = Node.PROCESS_MODE_DISABLED


func apply_cosmic_lighting_sample(sample: CosmicLightingSampleScript, delta: float = 0.016) -> void:
	apply_station_lighting(sample, delta)


func _step_flight_wing_transitions(delta: float) -> void:
	if _rig == null:
		return
	if _wing_bloom_settle_timer > 0.0:
		_wing_bloom_settle_timer = maxf(0.0, _wing_bloom_settle_timer - delta)
		if _wing_bloom_settle_timer <= 0.0 and _is_flight_traversal:
			_rig.clear_3d_wings_manual_override()
	if _wing_fold_pending:
		var w_ctrl: AstralWings3DController = _rig.get_3d_wings_controller()
		var done: bool = (w_ctrl == null) or w_ctrl.is_fold_complete()
		if done:
			_wing_fold_pending = false
			if not _is_flight_traversal:
				_wings_3d_showcase_enabled = false
				_rig.clear_3d_wings_manual_override()
				_rig.set_3d_wings_enabled(false)
				_sync_rig_locomotion_mode()


func get_grounded_config() -> GroundedConfigScript:
	if _rig != null:
		var rig_cfg: GroundedConfigScript = _rig.get_grounded_locomotion_config()
		if rig_cfg != null:
			return rig_cfg
	if _loaded_profile != null and _loaded_profile.grounded_locomotion_config is GroundedConfigScript:
		return _loaded_profile.grounded_locomotion_config as GroundedConfigScript
	return DEFAULT_GROUNDED_CFG


func set_grounded_config_override(cfg: GroundedConfigScript) -> void:
	_ensure_nodes_ready()
	if _rig != null and cfg != null:
		_rig.set_grounded_locomotion_config(cfg)


func set_grounded_manual_scrub(enabled: bool, phase_rad: float, walk_blend_val: float = 1.0) -> void:
	_ensure_nodes_ready()
	if _rig != null:
		_rig.set_grounded_manual_scrub(enabled, phase_rad, walk_blend_val)


func get_active_accent_color() -> Color:
	if _current_skin != null:
		return _current_skin.accent_color
	return Color(0.55, 0.88, 1.0, 1.0)


func set_launch_scale_multiplier(mult: float) -> void:
	_launch_scale_mult = clampf(mult, 0.35, 1.5)
	if _avatar_sprite != null:
		var cfg: HubDioramaConfigScript = _resolve_config()
		_avatar_sprite.scale = Vector3(_launch_scale_mult, cfg.avatar_aspect_y_comp * _launch_scale_mult, 1.0)


func set_sprite_opacity(alpha: float) -> void:
	_sprite_opacity = clampf(alpha, 0.0, 1.0)
	if _avatar_sprite != null:
		_avatar_sprite.modulate.a = _sprite_opacity
	if _integrate_3d_mat != null:
		_integrate_3d_mat.set_shader_parameter("opacity", _sprite_opacity)


func set_3d_scene_lighting_enabled(enabled: bool) -> void:
	enable_3d_scene_lighting = enabled
	if _avatar_sprite == null:
		return
	if enabled:
		if _integrate_3d_mat == null:
			_integrate_3d_mat = ShaderMaterial.new()
			_integrate_3d_mat.shader = Pilot3DIntegrateShader
		if _subviewport != null:
			_integrate_3d_mat.set_shader_parameter("avatar_tex", _subviewport.get_texture())
		_integrate_3d_mat.set_shader_parameter("opacity", _sprite_opacity)
		_avatar_sprite.material_override = _integrate_3d_mat
	else:
		_avatar_sprite.material_override = null


func apply_station_lighting(sample: CosmicLightingSampleScript, delta: float) -> void:
	if sample == null or _rig == null:
		return
	_rig.apply_cosmic_lighting(sample, delta)
	if _integrate_3d_mat != null:
		_integrate_3d_mat.set_shader_parameter("rim_tint", sample.rim_key_color)
		_integrate_3d_mat.set_shader_parameter("shadow_tint", sample.shadow_tint.lerp(sample.key_light_tint, 0.35))
		_integrate_3d_mat.set_shader_parameter("rim_strength", clampf(0.14 + sample.rim_tint_weight * 0.14, 0.10, 0.34))
	if _orbital_ring != null and is_instance_valid(_orbital_ring):
		var eff_sample: CosmicLightingSampleScript = _rig.get_last_cosmic_lighting()
		_orbital_ring.apply_cosmic_lighting(eff_sample if eff_sample != null else sample)


func play_pilot_skin_turnaround() -> void:
	_preview_anim_kind = &"pilot_turnaround"
	_preview_anim_timer = 0.0
	_preview_anim_duration = 1.45
	_preview_weapon_fired = false


func play_wings_skin_flourish() -> void:
	_preview_anim_kind = &"wings_flourish"
	_preview_anim_timer = 0.0
	_preview_anim_duration = 1.10
	_preview_weapon_fired = false
	if _rig != null:
		_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM, false)
		_rig.trigger_3d_wings_pulse()


func play_weapon_skin_inspect() -> void:
	_preview_anim_kind = &"weapon_inspect"
	_preview_anim_timer = 0.0
	_preview_anim_duration = 1.15
	_preview_weapon_fired = false
	if _orbital_ring != null and is_instance_valid(_orbital_ring):
		_orbital_ring.set_orbit_angle_manual(PI * 0.25)
		_orbital_ring.trigger_fire(0, true)


func _compute_preview_lift() -> float:
	if _preview_anim_kind == &"wings_flourish" and _preview_anim_duration > 0.01:
		var t: float = clampf(_preview_anim_timer / _preview_anim_duration, 0.0, 1.0)
		return sin(t * PI) * 0.16
	return 0.0


func _step_preview_micro_animation(delta: float) -> void:
	if _preview_anim_kind.is_empty():
		return
	_preview_anim_timer += delta
	var t: float = clampf(_preview_anim_timer / maxf(_preview_anim_duration, 0.01), 0.0, 1.0)
	match _preview_anim_kind:
		&"pilot_turnaround":
			if _rig != null:
				if t < 0.28:
					_rig.set_locomotion_state(Vector2(0.7, 0.7).normalized(), 0.25, Vector2(0.7, 0.7).normalized(), false)
				elif t < 0.56:
					_rig.set_locomotion_state(Vector2(-0.7, 0.7).normalized(), 0.25, Vector2(-0.7, 0.7).normalized(), false)
				else:
					_rig.set_locomotion_state(Vector2.DOWN, 0.0, Vector2.DOWN, false)
		&"wings_flourish":
			if t >= 0.78 and _rig != null:
				_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, false)
		&"weapon_inspect":
			if _orbital_ring != null and is_instance_valid(_orbital_ring):
				var sweep_ang: float = PI * 0.5 + sin(t * TAU) * 1.15
				_orbital_ring.set_orbit_angle_manual(sweep_ang)
				if t >= 0.45 and not _preview_weapon_fired:
					_preview_weapon_fired = true
					_orbital_ring.trigger_fire(0, true)

	if t >= 1.0:
		_preview_anim_kind = &""
		_preview_anim_timer = 0.0
		if _rig != null and _wings_3d_showcase_enabled:
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, false)
			_rig.set_locomotion_state(_last_move_dir, _last_speed_norm, _last_aim_dir, false)


func is_3d_wings_showcase_enabled() -> bool:
	return _wings_3d_showcase_enabled


func is_orbital_weapon_showcase_enabled() -> bool:
	return _orbital_weapon_enabled


func _ensure_orbital_ring_ready() -> void:
	if _orbital_ring != null and is_instance_valid(_orbital_ring):
		return
	if _subviewport == null:
		return

	_orbital_ring = OrbitalRingCtrlScript.new() as OrbitalRingCtrlScript
	_orbital_ring.name = "HubShowcaseOrbitalRing"
	_orbital_ring.z_index = 0
	_orbital_ring.scale = Vector2(0.72, 0.72)

	var orb_cfg: OrbitalConfigScript = null
	if ResourceLoader.exists(DEFAULT_ORBITAL_CFG_PATH):
		var loaded_res: Resource = ResourceLoader.load(DEFAULT_ORBITAL_CFG_PATH)
		if loaded_res is OrbitalConfigScript:
			orb_cfg = loaded_res.duplicate(true) as OrbitalConfigScript
	if orb_cfg == null:
		orb_cfg = OrbitalConfigScript.new()
	orb_cfg.ensure_defaults()
	orb_cfg.weapon_count = 1
	orb_cfg.ring_center_offset = Vector2(0.0, -10.0)
	orb_cfg.ring_radius_x = 110.0
	orb_cfg.ring_radius_y = 54.0
	orb_cfg.weapon_base_scale = 0.105
	_orbital_ring.set_config(orb_cfg)
	_orbital_ring.set_weapon_3d_enabled(true)
	_orbital_ring.set_orbit_mode(OrbitalRingCtrlScript.OrbitMode.AUTO_RADIAL)
	if ResourceLoader.exists(DEFAULT_RING_TEXTURE_PATH):
		var ring_tex: Texture2D = ResourceLoader.load(DEFAULT_RING_TEXTURE_PATH) as Texture2D
		if ring_tex != null:
			_orbital_ring.set_ring_texture(ring_tex)
	_subviewport.add_child(_orbital_ring)
	_orbital_ring.step(0.0)


func get_active_skin_id() -> String:
	if _rig != null:
		return _rig.get_active_skin_id()
	if _current_skin == null or _current_skin.is_base_skin or _current_skin.id.is_empty():
		return "base"
	return _current_skin.id


func apply_style_profile(style: RigStyleProfile) -> void:
	_ensure_nodes_ready()
	if style == null:
		return
	_current_style = style
	if _rig != null:
		_rig.apply_style_profile(style)
		set_light_dir_2d(_light_dir_2d)


func set_light_dir_2d(light_dir: Vector2) -> void:
	var n_dir: Vector2 = light_dir.normalized() if light_dir.length_squared() > 0.0001 else Vector2(0.45, -0.89).normalized()
	_light_dir_2d = n_dir
	if _rig != null:
		_rig.set_shader_param_all("light_dir_2d", n_dir)
		_rig.set_pass2_param("light_dir_2d", n_dir)


func get_rig() -> PlanarCombatRig:
	_ensure_nodes_ready()
	return _rig


func get_subviewport() -> SubViewport:
	_ensure_nodes_ready()
	return _subviewport


func get_sprite_3d() -> Sprite3D:
	_ensure_nodes_ready()
	return _avatar_sprite


func get_viewport_texture() -> ViewportTexture:
	_ensure_nodes_ready()
	return _subviewport.get_texture() if _subviewport != null else null


func get_hover_factor() -> float:
	return _hover_factor


func get_active_view_key() -> String:
	_ensure_nodes_ready()
	return _rig.get_active_view_key() if _rig != null else "s"


func get_active_head_key() -> String:
	_ensure_nodes_ready()
	return _rig.get_active_head_key() if _rig != null else "head_front"
