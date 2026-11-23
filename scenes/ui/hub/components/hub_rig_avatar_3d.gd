class_name HubRigAvatar3D
extends Node3D
## Avatar 2.5D vivo de Valentina v2 para el Hub 3D.
## Renderiza PlanarCombatRig (sin alas ni anillo orbital) dentro de un SubViewport HDR 2D (MSAA 4x)
## proyectado sobre un Sprite3D inclinado para cámara fija 2.5D Diorama, con levitación Zero-G.

const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const HubDioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: HubDioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")

@export var diorama_config: HubDioramaConfigScript = DEFAULT_DIORAMA_CONFIG

var _subviewport: SubViewport = null
var _camera_2d: Camera2D = null
var _rig: PlanarCombatRig = null
var _avatar_sprite: Sprite3D = null

var _loaded_profile: PilotRigProfile = null
var _current_style: RigStyleProfile = null
var _current_skin: PilotSkinPreset = null
var _current_star_level: int = 1
var _light_dir_2d: Vector2 = Vector2(0.45, -0.89).normalized()

var _hover_time: float = 0.0
var _hover_factor: float = 0.5
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
	var wave: float = 0.5 + 0.5 * sin(_hover_time * TAU * cfg.avatar_idle_bob_hz)
	var amp_mult: float = lerpf(1.0, 0.45, clampf(_last_speed_norm, 0.0, 1.0))
	var bob_y: float = (wave - 0.5) * 2.0 * cfg.avatar_idle_bob_amp * amp_mult
	_avatar_sprite.position.y = cfg.avatar_hover_height + bob_y
	_hover_factor = clampf(0.25 + wave * 0.45, 0.0, 1.0)


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
	_avatar_sprite.rotation_degrees = Vector3(cfg.avatar_tilt_deg, 0.0, 0.0)
	_avatar_sprite.scale = Vector3(1.0, cfg.avatar_aspect_y_comp, 1.0)
	_avatar_sprite.shaded = false
	_avatar_sprite.double_sided = true
	_avatar_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_avatar_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_avatar_sprite.pixel_size = cfg.avatar_pixel_size
	_avatar_sprite.offset = Vector2(0.0, cfg.avatar_feet_offset_px)
	_avatar_sprite.position = Vector3(0.0, cfg.avatar_hover_height, 0.0)
	_avatar_sprite.render_priority = 2
	_avatar_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	_rig.set_shader_param_all("enable_inward_outline", false)
	set_light_dir_2d(_light_dir_2d)
	_rig.set_zoom_scale(cfg.rig_camera_zoom)
	_rig.set_live_animations_enabled(true)
	_rig.set_face_live_enabled(true)
	_rig.set_locomotion_state(_last_move_dir, _last_speed_norm, _last_aim_dir, true)


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
