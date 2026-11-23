extends Node2D
## Arena de pruebas interactiva del Pilot Rig Planar 8-Dir fiel al Shader Lab.
## Renderiza con SubViewport SSAA 2x + HDR 2D + máscaras calibradas de cadera/medias.
## Una estrella central emite luz que cambia de color mientras Valentina orbita
## a su alrededor sin quitarle la mira de encima, conservando giros 8-Dir y transiciones.
## Controles:
##   - WASD / Flechas: tomar control manual en 8 direcciones (desactiva órbita auto)
##   - Ratón (en modo manual): apuntar cabeza independientemente del vuelo
##   - Rueda: zoom | Shift: turbo | Espacio: dash | Click / J: retroceso | K: impacto | B: air-brake

const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const MeshBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd")
const CalibStoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const HudBuilder = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd")
const LabStarScript = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_star.gd")

const PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"
const STYLES_DIR: String = "res://sandbox/pilot_rig_lab/data/styles"
const SSAA_SHADER_PATH: String = "res://sandbox/pilot_rig_lab/shader_lab/ssaa_downsample.gdshader"
const ALL_VIEWS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const MAX_WORLD_VP_DIM: float = 4096.0
const ORBIT_RADIUS: float = 165.0
const ORBIT_ANGULAR_SPEED: float = 0.82
const AUTO_ORBIT_BRAKE_CYCLE_SEC: float = 3.8

var _profile: PilotRigProfile = null
var _styles: Array[RigStyleProfile] = []
var _hip_shadows: Dictionary = {}
var _stocking_pinches: Dictionary = {}

var _world_vp: SubViewport = null
var _world_display_layer: CanvasLayer = null
var _world_display: TextureRect = null
var _ssaa_material: ShaderMaterial = null
var _ss_scale: float = 2.0
var _logical_zoom: float = 1.45
var _target_zoom: float = 1.45

var _world_env: WorldEnvironment = null
var _backdrop: BackdropScript = null
var _camera: Camera2D = null
var _star: LabStarScript = null
var _rig: PlanarCombatRig = null
var _reticle: Node2D = null
var _aim_line: Line2D = null
var _orbit_enemy: Sprite2D = null
var _hud_refs: Dictionary = {}

var _auto_demo: bool = true
var _orbit_phase: float = 0.0
var _orbit_enemy_enabled: bool = false
var _orbit_enemy_angle: float = 0.0
var _q_time: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _last_manual_move_dir: Vector2 = Vector2.DOWN
var _aim_world: Vector2 = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _ready() -> void:
	process_priority = 10
	_load_profile_and_styles()
	_setup_supersampled_world_viewport()
	_build_world_environment()

	_backdrop = BackdropScript.new()
	_backdrop.name = "ShaderLabBackdrop"
	_backdrop.show_light_gizmo = false
	_world_vp.add_child(_backdrop)
	_backdrop.set_mode(BackdropScript.BackdropMode.SPACE_NEBULA)

	_camera = Camera2D.new()
	_camera.name = "CombatLabCamera"
	_camera.position = Vector2(ORBIT_RADIUS * 0.45, 0.0)
	_world_vp.add_child(_camera)

	_star = LabStarScript.new()
	_star.name = "OrbitLightStar"
	_star.orbit_radius = ORBIT_RADIUS
	_star.position = Vector2.ZERO
	_world_vp.add_child(_star)

	_aim_line = Line2D.new()
	_aim_line.width = 1.5
	_aim_line.default_color = Color(1.0, 0.28, 0.42, 0.45)
	_aim_line.z_index = 4
	_world_vp.add_child(_aim_line)

	_reticle = _build_reticle()
	_world_vp.add_child(_reticle)

	_rig = PlanarRigScript.new()
	_rig.name = "PilotPlanarRig"
	_rig.pilot_profile = _profile
	_rig.enable_3d_wings = true
	_rig.position = Vector2(ORBIT_RADIUS, 0.0)
	_world_vp.add_child(_rig)

	_build_orbit_enemy()

	_hud_refs = HudBuilder.build_hud(self, _rig, _styles, {
		"on_style_selected": Callable(self, "_apply_style_index"),
		"on_auto_demo": Callable(self, "_on_auto_demo_toggled"),
		"on_manual_control": Callable(self, "_on_manual_control_toggled"),
		"on_pose_mode_selected": Callable(self, "_on_pose_mode_selected"),
		"on_reload_base_pose": Callable(self, "_reload_base_pose_tres"),
		"on_idle_anim_toggled": Callable(self, "_on_idle_anim_toggled"),
		"on_loco_anim_toggled": Callable(self, "_on_loco_anim_toggled"),
		"on_kiting_anim_toggled": Callable(self, "_on_kiting_anim_toggled"),
		"on_turn_anim_toggled": Callable(self, "_on_turn_anim_toggled"),
		"on_jiggle_anim_toggled": Callable(self, "_on_jiggle_anim_toggled"),
		"on_face_anim_toggled": Callable(self, "_on_face_anim_toggled"),
		"on_face_personality_selected": Callable(self, "_on_face_personality_selected"),
		"on_face_comms_pressed": Callable(self, "_on_face_comms_pressed"),
		"on_zoom": Callable(self, "_on_zoom_preset_selected"),
		"on_white_bg": Callable(self, "_set_white_background"),
		"on_space_nebula": Callable(self, "_set_space_nebula_background"),
		"on_orbit_enemy": func(v: bool) -> void:
			_orbit_enemy_enabled = v
			if _orbit_enemy != null:
				_orbit_enemy.visible = v,
	})

	_apply_initial_defaults()
	_sync_world_viewport_size()


func _load_profile_and_styles() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile

	_styles.clear()
	var dir: DirAccess = DirAccess.open(STYLES_DIR)
	if dir != null:
		var files: PackedStringArray = dir.get_files()
		var sorted_files: Array[String] = []
		for f: String in files:
			if f.ends_with(".tres"):
				sorted_files.append(f)
		sorted_files.sort()
		for f: String in sorted_files:
			var full_p: String = "%s/%s" % [STYLES_DIR, f]
			var res: Resource = ResourceLoader.load(full_p, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res is RigStyleProfile:
				_styles.append(res as RigStyleProfile)
	if _styles.is_empty() and _profile != null:
		for st: RigStyleProfile in _profile.style_profiles:
			if st != null:
				_styles.append(st)

	for v_key: String in ALL_VIEWS:
		var meta_path: String = "%s/%s/parts_5/parts_5_meta.json" % [MeshBuilderScript.ASSETS_ROOT, v_key]
		var meta_d: Dictionary = MeshBuilderScript.load_json_dict(meta_path)
		_hip_shadows[v_key] = CalibStoreScript.parse_hip_cast_shadow_from_meta(meta_d, v_key)
		_stocking_pinches[v_key] = CalibStoreScript.parse_stocking_pinch_from_meta(meta_d)


func _setup_supersampled_world_viewport() -> void:
	_world_vp = SubViewport.new()
	_world_vp.name = "SupersampledWorldViewport"
	_world_vp.disable_3d = true
	_world_vp.transparent_bg = false
	_world_vp.use_hdr_2d = true
	_world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_world_vp.msaa_2d = Viewport.MSAA_2X if _ss_scale > 1.01 else Viewport.MSAA_DISABLED
	add_child(_world_vp)

	_world_display_layer = CanvasLayer.new()
	_world_display_layer.name = "WorldDisplayLayer"
	_world_display_layer.layer = 0
	add_child(_world_display_layer)

	if ResourceLoader.exists(SSAA_SHADER_PATH):
		var ssaa_shader: Shader = ResourceLoader.load(SSAA_SHADER_PATH) as Shader
		if ssaa_shader != null:
			_ssaa_material = ShaderMaterial.new()
			_ssaa_material.shader = ssaa_shader

	_world_display = TextureRect.new()
	_world_display.name = "WorldDisplayRect"
	_world_display.texture = _world_vp.get_texture()
	_world_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_display.stretch_mode = TextureRect.STRETCH_SCALE
	_world_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_world_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_display_layer.add_child(_world_display)

	get_viewport().size_changed.connect(_sync_world_viewport_size)


func _get_effective_zoom() -> float:
	if _world_vp == null:
		return _logical_zoom * _ss_scale
	var vis_sz: Vector2 = get_viewport().get_visible_rect().size
	var phys_scale: float = float(_world_vp.size.y) / maxf(vis_sz.y, 1.0)
	return _logical_zoom * maxf(phys_scale, 0.25)


func _sync_world_viewport_size() -> void:
	if _world_vp == null:
		return
	var vis_sz: Vector2 = get_viewport().get_visible_rect().size
	var win_px: Vector2i = DisplayServer.window_get_size()
	var base_w: float = float(win_px.x) if (win_px.x >= 64 and win_px.y >= 64) else vis_sz.x
	var base_h: float = float(win_px.y) if (win_px.x >= 64 and win_px.y >= 64) else vis_sz.y
	var raw_w: float = maxf(64.0, base_w * _ss_scale)
	var raw_h: float = maxf(64.0, base_h * _ss_scale)
	var max_dim: float = maxf(raw_w, raw_h)
	if max_dim > MAX_WORLD_VP_DIM:
		var cap_ratio: float = MAX_WORLD_VP_DIM / max_dim
		raw_w *= cap_ratio
		raw_h *= cap_ratio
	var target_w: int = maxi(64, int(round(raw_w)))
	var target_h: int = maxi(64, int(round(raw_h)))
	_world_vp.size = Vector2i(target_w, target_h)
	_world_vp.msaa_2d = Viewport.MSAA_2X if _ss_scale > 1.01 else Viewport.MSAA_DISABLED
	var eff_ss: float = clampf(float(target_h) / maxf(base_h, 1.0), 1.0, 2.5)
	if _world_display != null:
		if _ss_scale > 1.01 and _ssaa_material != null:
			_ssaa_material.set_shader_parameter("ss_scale", eff_ss)
			_world_display.material = _ssaa_material
		else:
			_world_display.material = null
	_apply_camera_zoom()


func _apply_camera_zoom() -> void:
	if _camera == null:
		return
	var eff_z: float = _get_effective_zoom()
	_camera.zoom = Vector2(eff_z, eff_z)
	if _rig != null:
		_rig.set_zoom_scale(eff_z)


func _build_world_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	env.glow_intensity = 0.50
	env.glow_bloom = 0.08
	_world_env = WorldEnvironment.new()
	_world_env.name = "LabWorldEnvironment"
	_world_env.environment = env
	_world_vp.add_child(_world_env)


func _build_orbit_enemy() -> void:
	var tex: Texture2D = load("res://assets/sprites/enemies/enemy_drone.png") as Texture2D
	if tex == null:
		return
	_orbit_enemy = Sprite2D.new()
	_orbit_enemy.name = "OrbitingBaseEnemy"
	_orbit_enemy.texture = tex
	_orbit_enemy.scale = Vector2(0.045, 0.045)
	_orbit_enemy.z_index = 12
	_orbit_enemy.visible = false
	_world_vp.add_child(_orbit_enemy)


func _build_reticle() -> Node2D:
	var n := Node2D.new()
	n.z_index = 25
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i: int in range(25):
		var a: float = float(i) / 24.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	ring.points = pts
	ring.width = 1.8
	ring.default_color = Color(1.0, 0.26, 0.42, 0.85)
	n.add_child(ring)
	return n


func _apply_initial_defaults() -> void:
	_rig.set_transition_style(PlanarCombatRig.TransitionStyle.WHIP_SNAP_AFTERIMAGE)
	_rig.enable_afterimage = false

	var def_style_idx: int = _styles.size() - 1 if _styles.size() > 1 else 0
	var profile_opt: OptionButton = _hud_refs.get("profile_opt", null) as OptionButton
	if profile_opt != null and def_style_idx < profile_opt.item_count:
		profile_opt.select(def_style_idx)
	_apply_style_index(def_style_idx)

	if _profile != null and not _profile.skins.is_empty():
		_rig.apply_skin_preset(_profile.skins[0])
	_rig.set_recolor_method(1)
	_rig.set_hair_style_mode(0)
	_rig.set_shader_param_all("enable_inward_outline", false)
	_apply_calibrated_leg_shaders_all_views()

	# Estado inicial en órbita mirando a la estrella (animaciones nativas de PlanarCombatRig)
	var init_tangent := Vector2(0.0, 1.0)
	var init_aim := Vector2(-1.0, 0.0)
	_rig.set_locomotion_state(init_tangent, 0.85, init_aim, true)
	_rig.set_live_animations_enabled(true)
	_sync_star_lighting()


func _on_pose_mode_selected(idx: int) -> void:
	if _rig != null:
		_rig.set_anim_layer_mode(idx)


func _on_idle_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_idle_anim_enabled(enabled)


func _on_loco_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_loco_anim_enabled(enabled)


func _on_kiting_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_kiting_anim_enabled(enabled)


func _on_turn_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_turn_anim_enabled(enabled)


func _on_jiggle_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_jiggle_anim_enabled(enabled)


func _on_face_anim_toggled(enabled: bool) -> void:
	if _rig != null:
		_rig.set_face_anim_enabled_live(enabled)


func _on_face_personality_selected(profile_id: int) -> void:
	if _rig != null:
		var rt: Variant = _rig.get_animation_runtime()
		if rt != null:
			rt.set_face_personality_profile(profile_id, _rig)
		else:
			_rig.set_face_personality_profile(profile_id)


func _on_face_comms_pressed() -> void:
	if _rig != null:
		_rig.trigger_comms_talk()


func _reload_base_pose_tres() -> void:
	if _rig != null:
		_rig.reload_animation_configs_from_disk()


func _apply_style_index(idx: int) -> void:
	if _rig == null or idx < 0 or idx >= _styles.size():
		return
	var st: RigStyleProfile = _styles[idx]
	_rig.apply_style_profile(st)
	_rig.set_shader_param_all("enable_inward_outline", false)
	_sync_star_lighting()


func _apply_calibrated_leg_shaders_all_views() -> void:
	if _rig == null:
		return
	var views: Dictionary = _rig.get_views()
	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		var polys: Dictionary = vd.get("polys", {}) as Dictionary
		var bc_poly: Polygon2D = polys.get("body_core", null) as Polygon2D
		var bc_tex: Texture2D = bc_poly.texture if bc_poly != null else null
		var bc_rect: Variant = (bc_poly.material as ShaderMaterial).get_shader_parameter("part_rig_rect") if (bc_poly != null and bc_poly.material is ShaderMaterial) else Vector4(0.0, 0.0, 1.0, 1.0)
		var sh_cfg: Dictionary = _hip_shadows.get(v_key, {}) as Dictionary
		var sp_cfg: Dictionary = _stocking_pinches.get(v_key, {}) as Dictionary

		for p_key: String in polys.keys():
			var poly: Polygon2D = polys[p_key] as Polygon2D
			if poly == null or not (poly.material is ShaderMaterial):
				continue
			var is_r: bool = p_key.begins_with("leg_r")
			var is_l: bool = p_key.begins_with("leg_l")
			if not (is_r or is_l):
				continue
			var mat: ShaderMaterial = poly.material as ShaderMaterial
			var use_cast: bool = bool(sh_cfg.get("enabled", true)) and bc_tex != null
			mat.set_shader_parameter("enable_hip_cast_shadow", use_cast)
			if use_cast:
				mat.set_shader_parameter("hip_cast_body_tex", bc_tex)
				mat.set_shader_parameter("hip_cast_body_rect", bc_rect)
				mat.set_shader_parameter("hip_cast_pelvis_delta", Vector2.ZERO)
				mat.set_shader_parameter("hip_cast_shadow_offset_px", sh_cfg.get("offset", Vector2(0.8, 3.2)) as Vector2)
				mat.set_shader_parameter("hip_cast_shadow_color", sh_cfg.get("color", Color(0.82, 0.68, 0.74, 1.0)) as Color)
			var use_pinch: bool = bool(sp_cfg.get("enabled", true))
			mat.set_shader_parameter("enable_stocking_pinch", use_pinch)
			if use_pinch:
				var v_key_sp: String = "v_l" if is_l else "v_r"
				var tilt_key: String = "tilt_l" if is_l else "tilt_r"
				var v_val_sp: float = float(sp_cfg.get(v_key_sp, sp_cfg.get("v", 0.25)))
				mat.set_shader_parameter("stocking_pinch_v", v_val_sp)
				mat.set_shader_parameter("stocking_pinch_center_u", CalibStoreScript.compute_pinch_center_u(poly.texture, v_val_sp))
				mat.set_shader_parameter("stocking_pinch_tilt", float(sp_cfg.get(tilt_key, sp_cfg.get("tilt", 0.0))))
				mat.set_shader_parameter("stocking_pinch_strength", float(sp_cfg.get("strength", 0.045)))
				mat.set_shader_parameter("stocking_pinch_width", float(sp_cfg.get("width", 0.032)))
				mat.set_shader_parameter("stocking_pinch_shadow", float(sp_cfg.get("shadow", 0.20)))


func _sync_star_lighting() -> void:
	if _rig == null or _star == null:
		return
	var to_star: Vector2 = _star.global_position - _rig.global_position
	var l_dir: Vector2 = to_star.normalized() if to_star.length_squared() > 1.0 else Vector2(-0.58, -0.81).normalized()
	var st: RigStyleProfile = _rig.get_current_style_profile()
	var use_nd: bool = st.use_normal_depth if st != null else true
	var base_rim: float = (st.normal_rim_strength if use_nd else 0.0) if st != null else 0.96
	var hdr_cap: float = st.hdr_cap if st != null else 1.78
	_rig.set_normal_depth_options(use_nd, l_dir, base_rim, hdr_cap)

	if st != null and st.stylize_enabled:
		var key_tint: Color = _star.get_key_light_tint(st.key_light_tint)
		var rim_col: Color = _star.get_rim_key_color()
		_rig.set_shader_param_all("key_light_tint", key_tint)
		_rig.set_shader_param_all("rim_key_color", rim_col)
		_rig.set_pass2_param("rim_key_color", rim_col)
	_star.set_target_world_pos(_rig.global_position)


func _on_auto_demo_toggled(enabled: bool) -> void:
	_set_manual_control(not enabled)


func _on_manual_control_toggled(enabled: bool) -> void:
	_set_manual_control(enabled)


func _set_manual_control(manual_enabled: bool) -> void:
	_auto_demo = not manual_enabled
	var auto_chk: CheckBox = _hud_refs.get("auto_demo_chk", null) as CheckBox
	var manual_chk: CheckBox = _hud_refs.get("manual_control_chk", null) as CheckBox
	if auto_chk != null:
		auto_chk.set_pressed_no_signal(not manual_enabled)
	if manual_chk != null:
		manual_chk.set_pressed_no_signal(manual_enabled)
	if manual_enabled:
		var vp: Viewport = get_viewport()
		if vp != null:
			vp.gui_release_focus()
		if _velocity.length_squared() > 16.0:
			_last_manual_move_dir = _velocity.normalized()
	elif _rig != null and _star != null:
		var offset: Vector2 = _rig.global_position - _star.global_position
		if offset.length_squared() > 4.0:
			_orbit_phase = offset.angle()


func _on_zoom_preset_selected(idx: int) -> void:
	var z_vals: Array[float] = [2.0, 1.45, 1.15, 0.65]
	_target_zoom = z_vals[clampi(idx, 0, z_vals.size() - 1)]


func _set_white_background(enabled: bool) -> void:
	if _backdrop == null:
		return
	_backdrop.set_mode(BackdropScript.BackdropMode.LIGHT_STUDIO if enabled else BackdropScript.BackdropMode.DARK_STUDIO)


func _set_space_nebula_background(enabled: bool) -> void:
	if _backdrop == null:
		return
	_backdrop.set_mode(BackdropScript.BackdropMode.SPACE_NEBULA if enabled else BackdropScript.BackdropMode.DARK_STUDIO)


func _trigger_air_brake_test() -> void:
	if _rig == null:
		return
	var cur_dir: Vector2 = _velocity.normalized() if _velocity.length() > 10.0 else _last_manual_move_dir
	_velocity = -cur_dir * 260.0
	_rig.trigger_air_brake(1.0)
	_rig.set_locomotion_state(-cur_dir, 1.15, (_aim_world - _rig.global_position).normalized())


func _get_mouse_world_position() -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var win_sz: Vector2 = get_viewport().get_visible_rect().size
	var m_offset: Vector2 = get_viewport().get_mouse_position() - win_sz * 0.5
	return _camera.global_position + m_offset / maxf(_logical_zoom, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.15, 0.40, 8.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.15, 0.40, 8.0)
			elif mb.button_index == MOUSE_BUTTON_LEFT and _rig != null:
				_rig.trigger_attack_recoil((_aim_world - _rig.global_position).normalized())
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and _rig != null:
			if ke.keycode == KEY_SPACE:
				var dash_dir: Vector2 = _velocity.normalized() if _velocity.length() > 10.0 else _last_manual_move_dir
				if not _auto_demo:
					_velocity = dash_dir * 420.0
				_rig.trigger_dash_burst(dash_dir)
			elif ke.keycode == KEY_J:
				_rig.trigger_attack_recoil((_aim_world - _rig.global_position).normalized())
			elif ke.keycode == KEY_K:
				var hit_dir: Vector2 = (_rig.global_position - _aim_world).normalized()
				_rig.trigger_hit_react(hit_dir)
			elif ke.keycode == KEY_B:
				_trigger_air_brake_test()
			elif ke.keycode == KEY_C:
				_rig.trigger_comms_talk()


static func compute_auto_orbit_drive(t: float) -> float:
	var cycle_u: float = fposmod(maxf(t, 0.0), AUTO_ORBIT_BRAKE_CYCLE_SEC) / AUTO_ORBIT_BRAKE_CYCLE_SEC
	return smoothstep(0.02, 0.16, cycle_u) * (1.0 - smoothstep(0.52, 0.64, cycle_u))


static func compute_auto_glance_angle(t: float) -> float:
	var cycle_u: float = fposmod(maxf(t, 0.0), AUTO_ORBIT_BRAKE_CYCLE_SEC) / AUTO_ORBIT_BRAKE_CYCLE_SEC
	if cycle_u < 0.68 or cycle_u > 0.96:
		return 0.0
	var g_u: float = (cycle_u - 0.68) / 0.28
	var env: float = smoothstep(0.0, 0.25, g_u) * (1.0 - smoothstep(0.65, 1.0, g_u))
	var cycle_idx: int = int(floor(maxf(t, 0.0) / AUTO_ORBIT_BRAKE_CYCLE_SEC))
	var side: float = 1.0 if (cycle_idx % 2 == 0) else -1.0
	return deg_to_rad(42.0) * side * env


func _process(delta: float) -> void:
	_q_time += delta

	var status_lbl: Label = _hud_refs.get("status_lbl", null) as Label

	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W):
		input_vec.y -= 1.0

	if input_vec.length_squared() > 0.01 and _auto_demo:
		_set_manual_control(true)

	if _auto_demo:
		var orbit_drive: float = compute_auto_orbit_drive(_q_time)
		_orbit_phase = wrapf(_orbit_phase + delta * ORBIT_ANGULAR_SPEED * orbit_drive, 0.0, TAU)
		var star_pos: Vector2 = _star.global_position if _star != null else Vector2.ZERO
		var target_pos: Vector2 = star_pos + Vector2(cos(_orbit_phase), sin(_orbit_phase)) * ORBIT_RADIUS
		var prev_pos: Vector2 = _rig.position
		_rig.position = _rig.position.lerp(target_pos, 1.0 - exp(-12.0 * delta))
		if delta > 0.0001:
			_velocity = (_rig.position - prev_pos) / delta
		var tangent_dir := Vector2(-sin(_orbit_phase), cos(_orbit_phase))
		_aim_world = star_pos
		var base_aim_vec: Vector2 = _aim_world - _rig.global_position
		var aim_dir: Vector2 = base_aim_vec.normalized() if base_aim_vec.length_squared() > 1.0 else Vector2.DOWN
		var glance_ang: float = compute_auto_glance_angle(_q_time)
		if absf(glance_ang) > 0.001:
			aim_dir = aim_dir.rotated(glance_ang)
		_rig.set_turbo_active(false)
		_rig.set_locomotion_state(tangent_dir, 0.95 * orbit_drive, aim_dir)
	else:
		var is_turbo: bool = Input.is_key_pressed(KEY_SHIFT)
		var spd: float = 360.0 if is_turbo else 220.0
		var has_input: bool = input_vec.length_squared() > 0.01
		var target_v: Vector2 = input_vec.normalized() * spd if has_input else Vector2.ZERO
		var vel_rate: float = 22.0 if has_input else 15.0
		_velocity = _velocity.lerp(target_v, 1.0 - exp(-vel_rate * delta))
		_rig.position += _velocity * delta
		_aim_world = _get_mouse_world_position()
		if has_input:
			_last_manual_move_dir = input_vec.normalized()
		var mv_dir: Vector2 = _last_manual_move_dir
		var spd_n: float = clampf(_velocity.length() / 220.0, 0.0, 1.45)
		var to_aim: Vector2 = _aim_world - _rig.global_position
		var aim_dir_m: Vector2 = to_aim.normalized() if to_aim.length_squared() > 1.0 else _last_manual_move_dir
		_rig.set_turbo_active(is_turbo and has_input)
		_rig.set_locomotion_state(mv_dir, spd_n, aim_dir_m)

	_sync_star_lighting()

	var cam_target: Vector2 = _star.global_position.lerp(_rig.global_position, 0.45) if (_auto_demo and _star != null) else _rig.global_position
	_camera.global_position = _camera.global_position.lerp(cam_target, 1.0 - exp(-8.0 * delta))
	_logical_zoom = lerpf(_logical_zoom, _target_zoom, 1.0 - exp(-14.0 * delta))
	_apply_camera_zoom()

	_reticle.global_position = _aim_world
	_aim_line.points = PackedVector2Array([_rig.global_position + Vector2(0.0, -28.0), _aim_world])

	if _orbit_enemy_enabled and _orbit_enemy != null:
		_orbit_enemy_angle += delta * 1.45
		_orbit_enemy.global_position = _rig.global_position + Vector2(cos(_orbit_enemy_angle), sin(_orbit_enemy_angle)) * 115.0
		_orbit_enemy.rotation = (_rig.global_position - _orbit_enemy.global_position).angle() + PI * 0.5

	if status_lbl != null:
		var add_fx: String = _rig.get_active_additive_summary()
		var loco_tag: String = _rig.get_loco_state_tag()
		var base_txt: String = "%s | %s" % [_rig.get_active_view_summary(), loco_tag]
		if _rig.is_face_live_enabled():
			base_txt = "%s | Face=%s" % [base_txt, _rig.get_face_mood_tag()]
		status_lbl.text = "%s | %s" % [base_txt, add_fx] if add_fx != "NONE" else base_txt
