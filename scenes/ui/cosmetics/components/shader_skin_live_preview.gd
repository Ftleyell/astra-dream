class_name ShaderSkinLivePreview
extends SubViewportContainer
## Vista previa en vivo por SubViewport para skins 100% por shader (Piloto, Alas 3D y Arma 3D).
## Se auto-pausa cuando está oculto en el árbol o pausado explícitamente para coste GPU cero en reposo.

const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const AstralWings3DCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const Weapon3DRendererScript = preload("res://scenes/pilots/weapons/orbital_weapon_3d_renderer.gd")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette_black_vfx.gdshader")
const DEFAULT_STYLE_PATH := "res://data/pilots/styles/02_valentina_razor_sharp.tres"

var _mode: String = ""
var _profile: PilotRigProfile = null
var _viewport_px: Vector2i = Vector2i(360, 440)
var _subviewport: SubViewport = null
var _camera_2d: Camera2D = null
var _pilot_rig: PlanarCombatRig = null
var _wings_ctrl: AstralWings3DController = null
var _weapon_renderer: OrbitalWeapon3DRenderer = null

var _current_preset: PilotSkinPreset = null
var _current_star_level: int = 1
var _is_locked: bool = false
var _is_paused: bool = false
var _turntable_time: float = 0.0
var _silhouette_mat: ShaderMaterial = null


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if not resized.is_connected(_update_camera_fit):
		resized.connect(_update_camera_fit)
	_sync_update_mode()


func configure(category: String, profile: PilotRigProfile, viewport_px: Vector2i = Vector2i(360, 440)) -> void:
	var norm_mode: String = "wings" if (category == "wings" or category == "ship") else ("weapon" if category == "weapon" else "pilot")
	var size_changed: bool = (_viewport_px != viewport_px)
	_viewport_px = Vector2i(maxi(viewport_px.x, 64), maxi(viewport_px.y, 64))
	_profile = profile

	if _mode != norm_mode or _subviewport == null or not is_instance_valid(_subviewport):
		_rebuild_preview(norm_mode)
	elif norm_mode == "pilot" and _pilot_rig != null and profile != null and _pilot_rig.pilot_profile != profile:
		_pilot_rig.load_pilot_profile(profile)
		_apply_default_pilot_style()

	if not stretch and size_changed and _subviewport != null and is_instance_valid(_subviewport):
		_subviewport.size = _viewport_px
	_update_camera_fit()
	_sync_update_mode()
	if _current_preset != null:
		apply_skin_preset(_current_preset, _current_star_level, _is_locked)


func _rebuild_preview(norm_mode: String) -> void:
	_clear_preview_nodes()
	_mode = norm_mode
	_turntable_time = 0.0

	if _mode == "weapon":
		_weapon_renderer = Weapon3DRendererScript.new() as OrbitalWeapon3DRenderer
		_weapon_renderer.name = "WeaponPreviewSubViewport"
		_weapon_renderer.size = _viewport_px
		_weapon_renderer.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_weapon_renderer)
		_subviewport = _weapon_renderer
		_step_weapon_turntable(0.0)
	else:
		_subviewport = SubViewport.new()
		_subviewport.name = "PreviewSubViewport"
		_subviewport.size = _viewport_px
		_subviewport.disable_3d = true
		_subviewport.transparent_bg = true
		_subviewport.use_hdr_2d = true
		_subviewport.msaa_2d = Viewport.MSAA_4X
		_subviewport.handle_input_locally = false
		_subviewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_subviewport)

		_camera_2d = Camera2D.new()
		_camera_2d.name = "PreviewCamera2D"
		_camera_2d.enabled = true
		_subviewport.add_child(_camera_2d)

		if _mode == "pilot":
			_pilot_rig = PlanarCombatRigScript.new() as PlanarCombatRig
			_pilot_rig.name = "PreviewPilotRig"
			if _profile != null:
				_pilot_rig.pilot_profile = _profile
			_pilot_rig.enable_live_animations = true
			_pilot_rig.enable_face_live = true
			_pilot_rig.enable_base_propulsion_wings = false
			_pilot_rig.enable_3d_wings = false
			_pilot_rig.enable_procedural_wings = false
			_pilot_rig.enable_boot_thrusters = false
			_pilot_rig.enable_afterimage = false
			_pilot_rig.position = Vector2.ZERO
			_subviewport.add_child(_pilot_rig)
			_apply_default_pilot_style()
			var hero_dir: Vector2 = Vector2(0.32, 0.95).normalized()
			_pilot_rig.set_locomotion_state(hero_dir, 0.0, hero_dir, true)
			_pilot_rig.set_shader_param_all("enable_inward_outline", false)
		elif _mode == "wings":
			_wings_ctrl = AstralWings3DCtrlScript.new() as AstralWings3DController
			_wings_ctrl.name = "PreviewWings3D"
			if _profile != null and _profile.wings_3d_config is PilotWings3DConfig:
				_wings_ctrl.set_config(_profile.wings_3d_config as PilotWings3DConfig)
			_wings_ctrl.set_auto_fire_burst(false)
			_wings_ctrl.position = Vector2.ZERO
			_subviewport.add_child(_wings_ctrl)
			_wings_ctrl.set_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, true)


func _apply_default_pilot_style() -> void:
	if _pilot_rig == null:
		return
	var style: RigStyleProfile = null
	if _profile != null:
		for st: RigStyleProfile in _profile.style_profiles:
			if st != null and st.id == "02_valentina_razor_sharp":
				style = st
				break
	if style == null and ResourceLoader.exists(DEFAULT_STYLE_PATH):
		style = ResourceLoader.load(DEFAULT_STYLE_PATH) as RigStyleProfile
	if style != null:
		_pilot_rig.apply_style_profile(style)


func _clear_preview_nodes() -> void:
	_pilot_rig = null
	_wings_ctrl = null
	_weapon_renderer = null
	_camera_2d = null
	if _subviewport != null and is_instance_valid(_subviewport):
		remove_child(_subviewport)
		_subviewport.queue_free()
	_subviewport = null


func _update_camera_fit() -> void:
	if _camera_2d == null or not is_instance_valid(_camera_2d):
		return
	var ref_dim: float = maxf(minf(float(_viewport_px.x), float(_viewport_px.y)), 64.0)
	if size.x >= 32.0 and size.y >= 32.0:
		ref_dim = minf(size.x, size.y)
	if _mode == "pilot":
		var z: float = (ref_dim / 512.0) * 2.15
		_camera_2d.position = Vector2(0.0, 10.0)
		_camera_2d.zoom = Vector2(z, z)
		if _pilot_rig != null:
			_pilot_rig.set_zoom_scale(z)
	elif _mode == "wings":
		var z_w: float = (ref_dim / 512.0) * 1.15
		_camera_2d.position = Vector2(0.0, -24.0)
		_camera_2d.zoom = Vector2(z_w, z_w)


func apply_skin_preset(preset: PilotSkinPreset, star_level: int = 1, is_locked_silhouette: bool = false) -> void:
	_current_preset = preset
	_current_star_level = clampi(star_level, 1, 3)
	set_locked_silhouette(is_locked_silhouette)

	if _mode == "pilot" and _pilot_rig != null:
		if preset != null:
			_pilot_rig.apply_skin_preset(preset, _current_star_level)
	elif _mode == "wings" and _wings_ctrl != null:
		_wings_ctrl.apply_skin_preset(preset, _current_star_level)
	elif _mode == "weapon" and _weapon_renderer != null:
		var recolor_on: bool = preset != null and not preset.is_base_skin
		if recolor_on:
			_weapon_renderer.apply_skin_palette(
				true,
				preset.accent_color,
				preset.panel_color,
				preset.suit_dark_color,
				_current_star_level
			)
		else:
			_weapon_renderer.apply_skin_palette(
				false,
				Weapon3DRendererScript.BASE_CRYSTAL_COLOR,
				Weapon3DRendererScript.BASE_ARMOR_COLOR,
				Weapon3DRendererScript.BASE_CHASSIS_COLOR,
				_current_star_level
			)
		_step_weapon_turntable(0.0)


func set_locked_silhouette(locked: bool) -> void:
	_is_locked = locked
	if locked:
		if _silhouette_mat == null:
			_silhouette_mat = ShaderMaterial.new()
			_silhouette_mat.shader = SILHOUETTE_SHADER
		material = _silhouette_mat
	else:
		material = null


func set_preview_paused(paused: bool) -> void:
	_is_paused = paused
	_sync_update_mode()


func _sync_update_mode() -> void:
	if _subviewport == null or not is_instance_valid(_subviewport):
		return
	var active: bool = (not _is_paused) and is_visible_in_tree()
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if _mode == "wings" and _wings_ctrl != null and is_instance_valid(_wings_ctrl):
		_wings_ctrl.set_viewports_active(active)


func _process(delta: float) -> void:
	if _subviewport == null or not is_instance_valid(_subviewport):
		return
	var active: bool = (not _is_paused) and is_visible_in_tree()
	var target_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if _subviewport.render_target_update_mode != target_mode:
		_subviewport.render_target_update_mode = target_mode
	if _mode == "wings" and _wings_ctrl != null and is_instance_valid(_wings_ctrl):
		_wings_ctrl.set_viewports_active(active)
	if not active:
		return
	if _mode == "weapon" and _weapon_renderer != null:
		_step_weapon_turntable(delta)
	elif _mode == "wings" and _wings_ctrl != null:
		_wings_ctrl.step(delta, false)


func _step_weapon_turntable(delta: float) -> void:
	if _weapon_renderer == null:
		return
	_turntable_time += delta
	var yaw: float = 0.65 + _turntable_time * 0.72
	var aim_3d := Vector3(cos(yaw), 0.16 * sin(_turntable_time * 0.9), sin(yaw)).normalized()
	var glow_col: Color = _current_preset.accent_color if (_current_preset != null and not _current_preset.is_base_skin) else Weapon3DRendererScript.BASE_CRYSTAL_COLOR
	var rim_col: Color = glow_col.lerp(Color.WHITE, 0.35)
	_weapon_renderer.update_pose(
		aim_3d,
		Vector3.UP,
		0.0,
		0.0,
		0.35,
		0.15,
		Color(0.32, 0.36, 0.62, 1.0),
		0.65,
		rim_col,
		0.55,
		0.18,
		glow_col
	)


func get_active_mode() -> String:
	return _mode


func get_preview_viewport() -> SubViewport:
	return _subviewport


func get_active_skin_id() -> String:
	if _current_preset == null or _current_preset.is_base_skin or _current_preset.id.is_empty():
		return "base"
	return _current_preset.id


func get_pilot_rig() -> PlanarCombatRig:
	return _pilot_rig


func get_wings_controller() -> AstralWings3DController:
	return _wings_ctrl


func get_weapon_renderer() -> OrbitalWeapon3DRenderer:
	return _weapon_renderer
