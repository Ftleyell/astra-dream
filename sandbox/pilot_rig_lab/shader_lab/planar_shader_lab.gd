extends Node2D
## Laboratorio A/B de Shaders y Estilizado Agresivo — Valentina v2.
## Escena completamente aislada para iterar sobre shaders, iluminación 2.5D y presets .tres
## comparando lado a lado contra el baseline limpio calibrado.

const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const ViewRouterScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd")
const MeshBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd")
const CalibStoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const HudScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_hud.gd")

const PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"
const STYLES_DIR: String = "res://sandbox/pilot_rig_lab/data/styles"
const SSAA_SHADER_PATH: String = "res://sandbox/pilot_rig_lab/shader_lab/ssaa_downsample.gdshader"
const MAX_WORLD_VP_DIM: float = 4096.0
const ALL_VIEWS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const SIDE_BY_SIDE_OFFSET_X: float = 165.0
const HEAD_CYCLE_SEC: float = 1.6
const LIGHT_ROTATE_DEG_PER_SEC: float = 48.0

enum CompareMode {
	SIDE_BY_SIDE = 0,
	HERO_ONLY = 1,
	STACKED_TAB = 2,
}

var _profile: PilotRigProfile = null
var _styles: Array[RigStyleProfile] = []
var _skins: Array[PilotSkinPreset] = []
var _hairs: Array[PilotHairPreset] = []

var _world_vp: SubViewport = null
var _world_display_layer: CanvasLayer = null
var _world_display: TextureRect = null
var _ssaa_material: ShaderMaterial = null
var _ss_scale: float = 2.0
var _logical_zoom: float = 1.45

var _camera: Camera2D = null
var _backdrop: BackdropScript = null
var _hud: HudScript = null
var _baseline_rig: PlanarCombatRig = null
var _shader_rig: PlanarCombatRig = null
var _baseline_tag: Label = null
var _shader_tag: Label = null

var _zone_masks: Dictionary = {}
var _hip_shadows: Dictionary = {}
var _stocking_pinches: Dictionary = {}

var _active_view: String = "s"
var _allowed_heads: Array[String] = []
var _head_idx: int = 0
var _compare_mode: int = CompareMode.SIDE_BY_SIDE
var _tab_holding_baseline: bool = false

var _anim_playing: bool = false
var _head_cycle_enabled: bool = false
var _anim_time: float = 0.0
var _light_angle_deg: float = 234.0
var _dragging: bool = false
var _current_skin_idx: int = 0
var _current_hair_idx: int = 0
var _q_time: float = 0.0


func _ready() -> void:
	_load_profile_and_assets()
	_setup_supersampled_world_viewport()

	_backdrop = BackdropScript.new()
	_backdrop.name = "ShaderLabBackdrop"
	_world_vp.add_child(_backdrop)
	_backdrop.set_mode(3)

	_camera = Camera2D.new()
	_camera.name = "LabCamera"
	_camera.position = Vector2(-105.0, -10.0)
	_camera.zoom = Vector2(_logical_zoom * _ss_scale, _logical_zoom * _ss_scale)
	_world_vp.add_child(_camera)

	_baseline_rig = _create_rig("BaselineRig", Vector2(-SIDE_BY_SIDE_OFFSET_X, 0.0))
	_shader_rig = _create_rig("ShaderRig", Vector2(SIDE_BY_SIDE_OFFSET_X, 0.0))

	_baseline_tag = _create_world_tag("A: BASELINE (00_original)", Vector2(-SIDE_BY_SIDE_OFFSET_X - 78.0, -135.0), Color(0.75, 0.82, 0.92, 0.85))
	_shader_tag = _create_world_tag("B: SHADER EN VIVO", Vector2(SIDE_BY_SIDE_OFFSET_X - 64.0, -135.0), Color(1.0, 0.85, 0.45, 0.95))

	_hud = HudScript.new()
	_hud.name = "ShaderLabHud"
	add_child(_hud)
	_hud.build_ui(_get_style_labels(), _get_skin_labels(), _get_hair_labels())
	_hud.set_backdrop_index(3)
	_connect_hud()

	var def_style_idx: int = _styles.size() - 1 if _styles.size() > 1 else 0
	_select_view("s")
	_apply_baseline_defaults()
	_apply_style_index(def_style_idx)
	_hud.refresh_style_list(_get_style_labels(), def_style_idx)
	_apply_light_options()
	_disable_inward_outline_all()
	_sync_world_viewport_size()
	_update_compare_layout()
	_apply_pose_to_rig(_baseline_rig)
	_apply_pose_to_rig(_shader_rig)


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
	_sync_world_viewport_size()


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
	if _camera != null:
		var eff_z: float = _get_effective_zoom()
		_camera.zoom = Vector2(eff_z, eff_z)
		if _baseline_rig != null:
			_baseline_rig.set_zoom_scale(eff_z)
		if _shader_rig != null:
			_shader_rig.set_zoom_scale(eff_z)


func _set_supersampling(scale_factor: float) -> void:
	_ss_scale = clampf(scale_factor, 1.0, 2.5)
	_sync_world_viewport_size()


func _create_rig(node_name: String, pos: Vector2) -> PlanarCombatRig:
	var rig: PlanarCombatRig = PlanarRigScript.new()
	rig.name = node_name
	rig.position = pos
	rig.pilot_profile = _profile
	_world_vp.add_child(rig)
	rig.calibration_manual_pose = true
	return rig


func _create_world_tag(txt: String, pos: Vector2, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos
	lbl.modulate = col
	_world_vp.add_child(lbl)
	return lbl


func _load_profile_and_assets() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if _profile != null:
		for s: PilotSkinPreset in _profile.skins:
			if s != null:
				_skins.append(s)
		for h: PilotHairPreset in _profile.hair_presets:
			if h != null:
				_hairs.append(h)

	_reload_styles_from_disk()

	for v_key: String in ALL_VIEWS:
		_zone_masks["%s_r" % v_key] = _load_png_tex("res://sandbox/pilot_rig_lab/proto/leg_r_%s_persp_mask.png" % v_key)
		_zone_masks["%s_l" % v_key] = _load_png_tex("res://sandbox/pilot_rig_lab/proto/leg_l_%s_persp_mask.png" % v_key)
		var meta_path: String = "%s/%s/parts_5/parts_5_meta.json" % [MeshBuilderScript.ASSETS_ROOT, v_key]
		var meta_d: Dictionary = MeshBuilderScript.load_json_dict(meta_path)
		_hip_shadows[v_key] = CalibStoreScript.parse_hip_cast_shadow_from_meta(meta_d, v_key)
		_stocking_pinches[v_key] = CalibStoreScript.parse_stocking_pinch_from_meta(meta_d)


func _reload_styles_from_disk() -> void:
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


func _get_style_labels() -> Array[String]:
	var out: Array[String] = []
	for st: RigStyleProfile in _styles:
		out.append(st.label if not st.label.is_empty() else st.id)
	return out


func _get_skin_labels() -> Array[String]:
	var out: Array[String] = []
	for sk: PilotSkinPreset in _skins:
		out.append(sk.label if not sk.label.is_empty() else sk.id)
	return out


func _get_hair_labels() -> Array[String]:
	var out: Array[String] = []
	for hr: PilotHairPreset in _hairs:
		out.append(hr.label if not hr.label.is_empty() else hr.id)
	return out


func _connect_hud() -> void:
	_hud.view_selected.connect(_select_view)
	_hud.head_step_requested.connect(_step_head)
	_hud.head_cycle_toggled.connect(func(on: bool) -> void: _head_cycle_enabled = on)
	_hud.compare_mode_changed.connect(func(idx: int) -> void:
		_compare_mode = idx
		_update_compare_layout()
	)
	_hud.anim_toggled.connect(func(on: bool) -> void:
		_anim_playing = on
		if not _anim_playing:
			_anim_time = 0.0
			_apply_pose_to_rig(_baseline_rig)
			_apply_pose_to_rig(_shader_rig)
	)
	_hud.backdrop_changed.connect(func(idx: int) -> void:
		if _backdrop != null:
			_backdrop.set_mode(idx)
	)
	_hud.supersampling_changed.connect(_set_supersampling)
	_hud.debug_view_changed.connect(func(idx: int) -> void:
		if _shader_rig != null:
			_shader_rig.set_debug_view_mode(idx)
	)
	_hud.pinch_debug_toggled.connect(func(on: bool) -> void:
		if _shader_rig != null:
			_shader_rig.set_shader_param_all("debug_stocking_pinch_overlay", on)
	)
	_hud.style_preset_selected.connect(_apply_style_index)
	_hud.skin_preset_selected.connect(_apply_skin_index)
	_hud.hair_preset_selected.connect(_apply_hair_index)
	_hud.hair_style_mode_changed.connect(func(idx: int) -> void:
		if _shader_rig != null:
			_shader_rig.set_hair_style_mode(idx)
	)
	_hud.recolor_method_changed.connect(func(idx: int) -> void:
		if _shader_rig != null:
			_shader_rig.set_recolor_method(idx)
	)
	_hud.reset_style_requested.connect(func() -> void:
		_apply_style_index(0)
		_hud.refresh_style_list(_get_style_labels(), 0)
		_hud.set_save_feedback("Aplicado 00_original.", true)
	)
	_hud.definitive_style_requested.connect(func() -> void:
		var def_idx: int = 1 if _styles.size() > 1 else 0
		_apply_style_index(def_idx)
		_hud.refresh_style_list(_get_style_labels(), def_idx)
		_hud.set_save_feedback("Aplicado estilo definitivo.", true)
	)
	_hud.save_preset_requested.connect(_save_current_preset)
	_hud.light_options_changed.connect(_apply_light_options)
	_hud.counter_rim_options_changed.connect(_sync_counter_rim_colors)
	_hud.shader_param_changed.connect(func(p_name: String, val: Variant) -> void:
		if _shader_rig != null:
			_shader_rig.set_shader_param_all(p_name, val)
	)
	_hud.pass2_param_changed.connect(func(p_name: String, val: Variant) -> void:
		if _shader_rig != null:
			_shader_rig.set_pass2_param(p_name, val)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_camera(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_camera(1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and _camera != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_camera.position -= mm.relative / maxf(_logical_zoom, 0.05)
	elif event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_TAB:
			_tab_holding_baseline = kev.pressed
			if _compare_mode == CompareMode.STACKED_TAB:
				_update_compare_layout()
			return
		if not kev.pressed or kev.echo:
			return
		match kev.keycode:
			KEY_H:
				if _hud != null:
					_hud.toggle_panel()
			KEY_R:
				_reset_camera()
			KEY_BRACKETLEFT:
				_step_head(-1)
			KEY_BRACKETRIGHT:
				_step_head(1)
			KEY_1:
				_select_view("s")
			KEY_2:
				_select_view("se")
			KEY_3:
				_select_view("e")
			KEY_4:
				_select_view("ne")
			KEY_5:
				_select_view("n")
			KEY_6:
				_select_view("nw")
			KEY_7:
				_select_view("w")
			KEY_8:
				_select_view("sw")


func _process(delta: float) -> void:
	_q_time += delta
	if _shader_rig != null:
		_shader_rig.set_q_time(_q_time)

	if _hud != null and _hud.get_check_val("auto_rotate_light"):
		_light_angle_deg = wrapf(_light_angle_deg + LIGHT_ROTATE_DEG_PER_SEC * delta, 0.0, 360.0)
		_hud.set_light_angle_deg_ui(_light_angle_deg)
		_apply_light_options()

	if _anim_playing or _head_cycle_enabled:
		_anim_time += delta
		if _head_cycle_enabled and _allowed_heads.size() > 1:
			var step_i: int = int(floor(_anim_time / HEAD_CYCLE_SEC)) % _allowed_heads.size()
			if step_i != _head_idx:
				_head_idx = step_i
				_apply_active_view_and_head()
		if _anim_playing:
			_apply_pose_to_rig(_baseline_rig)
			_apply_pose_to_rig(_shader_rig)


func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var win_sz: Vector2 = get_viewport().get_visible_rect().size
	var m_offset: Vector2 = get_viewport().get_mouse_position() - win_sz * 0.5
	var world_before: Vector2 = _camera.position + m_offset / maxf(_logical_zoom, 0.05)
	_logical_zoom = clampf(_logical_zoom * factor, 0.40, 10.0)
	_camera.position = world_before - m_offset / maxf(_logical_zoom, 0.05)
	var eff_z: float = _get_effective_zoom()
	_camera.zoom = Vector2(eff_z, eff_z)
	if _baseline_rig != null:
		_baseline_rig.set_zoom_scale(eff_z)
	if _shader_rig != null:
		_shader_rig.set_zoom_scale(eff_z)


func _reset_camera() -> void:
	if _camera == null:
		return
	_logical_zoom = 1.45
	_camera.position = Vector2(-105.0, -10.0)
	var eff_z: float = _get_effective_zoom()
	_camera.zoom = Vector2(eff_z, eff_z)
	if _baseline_rig != null:
		_baseline_rig.set_zoom_scale(eff_z)
	if _shader_rig != null:
		_shader_rig.set_zoom_scale(eff_z)


func _select_view(view_key: String) -> void:
	if not ALL_VIEWS.has(view_key):
		return
	_active_view = view_key
	var raw_heads: Array = ViewRouterScript.ALLOWED_HEADS_BY_BODY_8DIR.get(
		view_key, [ViewRouterScript.get_default_head_for_body(view_key)]
	) as Array
	_allowed_heads.clear()
	for h: Variant in raw_heads:
		_allowed_heads.append(str(h))
	_head_idx = 0
	_apply_active_view_and_head()


func _step_head(delta_idx: int) -> void:
	if _allowed_heads.is_empty():
		return
	_head_idx = posmod(_head_idx + delta_idx, _allowed_heads.size())
	_apply_active_view_and_head()


func _apply_active_view_and_head() -> void:
	var h_key: String = _allowed_heads[_head_idx] if not _allowed_heads.is_empty() else "front"
	if _baseline_rig != null:
		_baseline_rig.set_static_inspection(true, _active_view, h_key)
		_apply_pose_to_rig(_baseline_rig)
	if _shader_rig != null:
		_shader_rig.set_static_inspection(true, _active_view, h_key)
		_apply_pose_to_rig(_shader_rig)
	if _hud != null:
		_hud.set_active_view_ui(_active_view, h_key)


func _update_compare_layout() -> void:
	if _baseline_rig == null or _shader_rig == null:
		return
	match _compare_mode:
		CompareMode.SIDE_BY_SIDE:
			_baseline_rig.visible = true
			_shader_rig.visible = true
			_baseline_rig.position = Vector2(-SIDE_BY_SIDE_OFFSET_X, 0.0)
			_shader_rig.position = Vector2(SIDE_BY_SIDE_OFFSET_X, 0.0)
			_baseline_tag.visible = true
			_shader_tag.visible = true
			_baseline_tag.position = Vector2(-SIDE_BY_SIDE_OFFSET_X - 78.0, -135.0)
			_shader_tag.position = Vector2(SIDE_BY_SIDE_OFFSET_X - 64.0, -135.0)
		CompareMode.HERO_ONLY:
			_baseline_rig.visible = false
			_shader_rig.visible = true
			_shader_rig.position = Vector2.ZERO
			_baseline_tag.visible = false
			_shader_tag.visible = true
			_shader_tag.position = Vector2(-64.0, -135.0)
		CompareMode.STACKED_TAB:
			_baseline_rig.position = Vector2.ZERO
			_shader_rig.position = Vector2.ZERO
			_baseline_rig.visible = _tab_holding_baseline
			_shader_rig.visible = not _tab_holding_baseline
			_baseline_tag.visible = _tab_holding_baseline
			_shader_tag.visible = not _tab_holding_baseline
			_baseline_tag.position = Vector2(-78.0, -135.0)
			_shader_tag.position = Vector2(-64.0, -135.0)
	_update_light_gizmo()


func _apply_baseline_defaults() -> void:
	if _baseline_rig == null:
		return
	if not _styles.is_empty():
		_baseline_rig.apply_style_profile(_styles[0])
	if not _skins.is_empty():
		_baseline_rig.apply_skin_preset(_skins[0])
	_baseline_rig.set_normal_depth_options(false, Vector2(-0.58, -0.81).normalized(), 0.0, 1.0)


func _apply_style_index(idx: int) -> void:
	if _shader_rig == null or idx < 0 or idx >= _styles.size():
		return
	var st: RigStyleProfile = _styles[idx]
	_shader_rig.apply_style_profile(st)
	if _hud != null:
		_hud.sync_from_style_profile(st)


func _apply_skin_index(idx: int) -> void:
	if _shader_rig == null or idx < 0 or idx >= _skins.size():
		return
	_current_skin_idx = idx
	var sk: PilotSkinPreset = _skins[idx]
	_shader_rig.apply_skin_preset(sk)
	if _current_hair_idx >= 0 and _current_hair_idx < _hairs.size():
		_shader_rig.apply_hair_preset(_hairs[_current_hair_idx], sk.hair_color)
	_sync_counter_rim_colors()


func _apply_hair_index(idx: int) -> void:
	if _shader_rig == null or idx < 0 or idx >= _hairs.size():
		return
	_current_hair_idx = idx
	var skin_hair: Color = _skins[_current_skin_idx].hair_color if (_current_skin_idx < _skins.size()) else Color(0.86, 0.89, 0.96, 1.0)
	_shader_rig.apply_hair_preset(_hairs[idx], skin_hair)


func _apply_light_options() -> void:
	if _shader_rig == null or _hud == null:
		return
	_light_angle_deg = _hud.get_slider_val("light_angle_deg", 234.0)
	var rad: float = deg_to_rad(_light_angle_deg)
	var l_dir := Vector2(cos(rad), sin(rad)).normalized()
	var use_nd: bool = _hud.get_check_val("use_normal_depth", true)
	var n_rim: float = _hud.get_slider_val("normal_rim_strength", 0.78)
	var hdr_b: float = _hud.get_slider_val("hdr_cap", 1.85)
	_shader_rig.set_normal_depth_options(use_nd, l_dir, n_rim, hdr_b)
	_update_light_gizmo()


func _sync_counter_rim_colors() -> void:
	if _shader_rig == null or _hud == null:
		return
	var use_acc: bool = _hud.get_check_val("counter_rim_use_skin_accent", true)
	var ovr_col: Color = _hud.get_color_val("counter_rim_override_color", Color(0.86, 0.18, 0.32, 1.0))
	var skin_acc: Color = _skins[_current_skin_idx].accent_color if (_current_skin_idx >= 0 and _current_skin_idx < _skins.size()) else Color(0.86, 0.18, 0.32, 1.0)
	_shader_rig.set_shader_param_all("counter_rim_use_skin_accent", use_acc)
	_shader_rig.set_shader_param_all("counter_rim_override_color", ovr_col)
	_shader_rig.set_pass2_param("rim_counter_color", skin_acc if use_acc else ovr_col)


func _update_light_gizmo() -> void:
	if _backdrop == null or _shader_rig == null:
		return
	var rad: float = deg_to_rad(_light_angle_deg)
	var l_dir := Vector2(cos(rad), sin(rad)).normalized()
	_backdrop.set_light_gizmo(_shader_rig.position, l_dir, true)


func _disable_inward_outline_all() -> void:
	for rig: PlanarCombatRig in [_baseline_rig, _shader_rig]:
		if rig == null:
			continue
		rig.set_shader_param_all("enable_inward_outline", false)


func _save_current_preset(raw_name: String) -> void:
	var clean: String = raw_name.strip_edges().to_lower().replace(" ", "_")
	clean = clean.replace(".tres", "")
	if clean.is_empty():
		_hud.set_save_feedback("Ingresá un nombre de archivo (ej: 01_valentina_definitive).", false)
		return
	var save_path: String = "%s/%s.tres" % [STYLES_DIR, clean]
	var label_txt: String = clean.capitalize()
	for st: RigStyleProfile in _styles:
		if st.id == clean and not st.label.is_empty():
			label_txt = st.label
			break
	var profile: RigStyleProfile = _hud.export_current_style_profile(clean, label_txt)
	var err: Error = ResourceSaver.save(profile, save_path)
	if err != OK:
		_hud.set_save_feedback("Error al guardar (%d): %s" % [int(err), save_path], false)
		return
	_reload_styles_from_disk()
	var found_idx: int = 0
	for i: int in range(_styles.size()):
		if _styles[i].id == clean:
			found_idx = i
			break
	_hud.refresh_style_list(_get_style_labels(), found_idx)
	_hud.set_save_feedback("Guardado: %s" % save_path, true)


func _apply_pose_to_rig(rig: PlanarCombatRig) -> void:
	if rig == null:
		return
	var vd: Dictionary = rig.get_views().get(_active_view, {}) as Dictionary
	if vd.is_empty():
		return
	var bones: Dictionary = vd.get("bones", {}) as Dictionary
	var rest_rots: Dictionary = vd.get("rest_rots", {}) as Dictionary
	var rest_pos: Dictionary = vd.get("rest_pos", {}) as Dictionary
	var polys: Dictionary = vd.get("polys", {}) as Dictionary

	# Restaurar rest pose base o aplicar respiración sutil si está en Play
	var breath: float = sin(_anim_time * 1.4) if _anim_playing else 0.0
	var pelvis_delta: Vector2 = Vector2(0.0, breath * 1.8)
	if bones.has("Pelvis") and rest_pos.has("Pelvis"):
		(bones["Pelvis"] as Bone2D).position = (rest_pos["Pelvis"] as Vector2) + pelvis_delta
	if bones.has("Spine_Mid") and rest_rots.has("Spine_Mid"):
		(bones["Spine_Mid"] as Bone2D).rotation = float(rest_rots["Spine_Mid"]) + breath * 0.012

	# Aplicar hip cast shadow y stocking pinch calibrados desde parts_5_meta.json
	var bc_poly: Polygon2D = polys.get("body_core", null) as Polygon2D
	var bc_tex: Texture2D = bc_poly.texture if bc_poly != null else null
	var bc_rect: Variant = (bc_poly.material as ShaderMaterial).get_shader_parameter("part_rig_rect") if (bc_poly != null and bc_poly.material is ShaderMaterial) else Vector4(0.0, 0.0, 1.0, 1.0)
	var sh_cfg: Dictionary = _hip_shadows.get(_active_view, {}) as Dictionary
	var sp_cfg: Dictionary = _stocking_pinches.get(_active_view, {}) as Dictionary

	for p_key: String in polys.keys():
		var poly: Polygon2D = polys[p_key] as Polygon2D
		if poly == null or not (poly.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = poly.material as ShaderMaterial
		var is_r: bool = p_key.begins_with("leg_r")
		var is_l: bool = p_key.begins_with("leg_l")
		if is_r or is_l:
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


func _load_png_tex(res_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img: Image = Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
