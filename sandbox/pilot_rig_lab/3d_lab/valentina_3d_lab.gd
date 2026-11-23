extends Node2D
## Laboratorio 3D Cel-Shaded ArcSys (3D Lab — Valentina v2).
## Demuestra las Alas Psíquicas "Astral Seraph" construidas con el mismo pipeline
## procedural ArrayMesh + doble normal + SubViewport HDR del Rail-Lance 3D,
## con 6 animaciones 3D, Z-sorting real atrás/delante del rig 2D y comparativa A/B con 2D.

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const WingsCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_wings_3d_config.gd")
const HUDScript = preload("res://sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab_hud.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_wings_3d.tres"
const STYLES_DIR: String = "res://data/pilots/styles"

const VIEW_YAW_DEG: Dictionary = {
	"s": 0.0,
	"se": 45.0,
	"e": 90.0,
	"ne": 135.0,
	"n": 180.0,
	"nw": -135.0,
	"w": -90.0,
	"sw": -45.0,
}

var _profile: PilotRigProfile = null
var _config: ConfigScript = null
var _backdrop: BackdropScript = null
var _camera: Camera2D = null
var _rig: PlanarCombatRig = null
var _wings_ctrl: WingsCtrlScript = null
var _hud_refs: Dictionary = {}

var _target_zoom: float = 1.35
var _yaw_deg: float = 0.0
var _turntable_enabled: bool = false
var _compare_2d_enabled: bool = false
var _show_pilot: bool = true
var _idle_pilot: bool = true
var _sim_velocity: Vector2 = Vector2.ZERO
var _active_skin_idx: int = 0


func _ready() -> void:
	_load_resources()
	_build_environment()
	_build_scene_nodes()
	_configure_rig_defaults()

	var skin_choices: Array[PilotSkinPreset] = []
	if _profile != null:
		skin_choices = _profile.skins

	_hud_refs = HUDScript.build_hud(self, _config, {
		"on_anim_selected": Callable(self, "_on_anim_selected"),
		"on_trigger_pulse": Callable(self, "trigger_pulse"),
		"on_auto_burst_toggled": Callable(self, "_on_auto_burst_toggled"),
		"on_view_selected": Callable(self, "_on_view_selected"),
		"on_yaw_deg_changed": Callable(self, "_on_yaw_deg_changed"),
		"on_turntable_toggled": Callable(self, "_on_turntable_toggled"),
		"on_light_orbit_toggled": Callable(self, "_on_light_orbit_toggled"),
		"on_compare_2d_toggled": Callable(self, "_on_compare_2d_toggled"),
		"on_show_pilot_toggled": Callable(self, "_on_show_pilot_toggled"),
		"on_idle_pilot_toggled": Callable(self, "_on_idle_pilot_toggled"),
		"on_follow_skin_toggled": Callable(self, "_on_follow_skin_toggled"),
		"on_skin_selected": Callable(self, "_on_skin_selected"),
		"on_save_config": Callable(self, "_on_save_config"),
		"on_reload_config": Callable(self, "_on_reload_config"),
	}, skin_choices)

	_apply_yaw_deg(0.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			match kev.keycode:
				KEY_1:
					_select_anim_with_hud(WingsCtrlScript.AnimState.IDLE_ZERO_G)
				KEY_2:
					_select_anim_with_hud(WingsCtrlScript.AnimState.CRUISE_BOOST)
				KEY_3:
					_select_anim_with_hud(WingsCtrlScript.AnimState.SERAPH_BLOOM)
				KEY_4:
					_select_anim_with_hud(WingsCtrlScript.AnimState.AEGIS_GUARD)
				KEY_5:
					_select_anim_with_hud(WingsCtrlScript.AnimState.FULL_BURST)
				KEY_6:
					_select_anim_with_hud(WingsCtrlScript.AnimState.VORTEX_SPIN)
				KEY_SPACE:
					trigger_pulse()
				KEY_T:
					_turntable_enabled = not _turntable_enabled
					var tchk: CheckBox = _hud_refs.get("turntable_chk", null) as CheckBox
					if is_instance_valid(tchk):
						tchk.set_pressed_no_signal(_turntable_enabled)
				KEY_B:
					_on_compare_2d_toggled(not _compare_2d_enabled)
					var bchk: CheckBox = _hud_refs.get("compare_2d_chk", null) as CheckBox
					if is_instance_valid(bchk):
						bchk.set_pressed_no_signal(_compare_2d_enabled)
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.55, 2.8)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.55, 2.8)
			elif mev.button_index == MOUSE_BUTTON_LEFT:
				trigger_pulse()


func _process(delta: float) -> void:
	if _camera != null:
		var next_z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 10.0, 0.0, 1.0))
		_camera.zoom = Vector2(next_z, next_z)
		if _rig != null:
			_rig.set_zoom_scale(next_z)

	# Simulación de vuelo WASD / Flechas para probar barrido Newtoniano y estelas
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0

	var target_vel: Vector2 = input_vec.normalized() * 320.0 if input_vec.length_squared() > 0.01 else Vector2.ZERO
	_sim_velocity = _sim_velocity.lerp(target_vel, clampf(delta * 8.5, 0.0, 1.0))

	if _turntable_enabled:
		_yaw_deg = wrapf(_yaw_deg + delta * 52.0, -180.0, 180.0)
		var yslider: HSlider = _hud_refs.get("yaw_slider", null) as HSlider
		if is_instance_valid(yslider):
			yslider.set_value_no_signal(_yaw_deg)
		_apply_yaw_deg(_yaw_deg, false)
	elif input_vec.length_squared() > 0.01:
		var move_yaw_deg: float = rad_to_deg(atan2(input_vec.x, input_vec.y))
		_yaw_deg = move_yaw_deg
		var yslider2: HSlider = _hud_refs.get("yaw_slider", null) as HSlider
		if is_instance_valid(yslider2):
			yslider2.set_value_no_signal(_yaw_deg)
		_apply_yaw_deg(_yaw_deg, false)
	elif _rig != null:
		var yaw_rad: float = deg_to_rad(_yaw_deg)
		var dir_vec := Vector2(sin(yaw_rad), cos(yaw_rad))
		_rig.set_locomotion_state(dir_vec, _sim_velocity.length(), dir_vec, false)

	if _wings_ctrl != null:
		_wings_ctrl.set_pilot_velocity_2d(_sim_velocity)
		_wings_ctrl.set_mouse_target_local(_wings_ctrl.get_local_mouse_position())
		_wings_ctrl.step(delta, false)
		_update_telemetry()


func trigger_pulse() -> void:
	if _wings_ctrl != null:
		_wings_ctrl.trigger_pulse(-1)


func get_rig() -> PlanarCombatRig:
	return _rig


func get_wings_controller() -> WingsCtrlScript:
	return _wings_ctrl


func get_config() -> ConfigScript:
	return _config


func _load_resources() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(CONFIG_PATH):
		_config = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.08
	env.glow_intensity = 0.62
	env.glow_bloom = 0.14
	var we := WorldEnvironment.new()
	we.name = "Wings3DLabWorldEnvironment"
	we.environment = env
	add_child(we)


func _build_scene_nodes() -> void:
	_backdrop = BackdropScript.new()
	_backdrop.name = "SpaceBackdrop"
	_backdrop.show_light_gizmo = false
	add_child(_backdrop)
	_backdrop.set_mode(BackdropScript.BackdropMode.SPACE_NEBULA)

	_camera = Camera2D.new()
	_camera.name = "Wings3DLabCamera"
	_camera.position = Vector2(-85.0, -10.0) # Compensa panel izquierdo
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	add_child(_camera)

	_rig = PlanarRigScript.new()
	_rig.name = "Valentina3DLabRig"
	_rig.pilot_profile = _profile
	_rig.z_index = 5
	_rig.enable_face_live = true
	_rig.enable_base_propulsion_wings = false
	add_child(_rig)

	_wings_ctrl = WingsCtrlScript.new()
	_wings_ctrl.name = "AstralWings3DController"
	_wings_ctrl.set_config(_config)
	add_child(_wings_ctrl)


func _configure_rig_defaults() -> void:
	if _rig == null:
		return
	var latest_style: RigStyleProfile = null
	var dir := DirAccess.open(STYLES_DIR)
	if dir != null:
		var files: Array[String] = []
		for f: String in dir.get_files():
			if f.ends_with(".tres"):
				files.append(f)
		files.sort()
		if not files.is_empty():
			latest_style = ResourceLoader.load("%s/%s" % [STYLES_DIR, files[-1]]) as RigStyleProfile
	if latest_style != null:
		_rig.apply_style_profile(latest_style)
	if _profile != null and not _profile.skins.is_empty():
		_rig.apply_skin_preset(_profile.skins[0])
		if _wings_ctrl != null:
			_wings_ctrl.apply_skin_preset(_profile.skins[0])

	_rig.set_idle_anim_enabled(_idle_pilot)
	_rig.set_base_propulsion_wings_enabled(false)


func _apply_yaw_deg(deg: float, snap_rig: bool) -> void:
	_yaw_deg = deg
	var yaw_rad: float = deg_to_rad(deg)
	if _wings_ctrl != null:
		_wings_ctrl.set_pilot_yaw_rad(yaw_rad)
	if _rig != null:
		var dir_vec := Vector2(sin(yaw_rad), cos(yaw_rad))
		_rig.set_locomotion_state(dir_vec, _sim_velocity.length(), dir_vec, snap_rig)


func _select_anim_with_hud(anim_idx: int) -> void:
	var opt: OptionButton = _hud_refs.get("anim_opt", null) as OptionButton
	if is_instance_valid(opt):
		opt.select(anim_idx)
	_on_anim_selected(anim_idx)


func _update_telemetry() -> void:
	var lbl: Label = _hud_refs.get("telemetry_label", null) as Label
	if not is_instance_valid(lbl) or _wings_ctrl == null:
		return
	var fb: Vector2i = _wings_ctrl.get_front_back_counts()
	lbl.text = "Yaw: %+5.1f° | Front: %d / Back: %d | Tris: %d" % [
		_yaw_deg,
		fb.x,
		fb.y,
		_wings_ctrl.get_total_triangle_count(),
	]


func _on_anim_selected(anim_idx: int) -> void:
	if _wings_ctrl != null:
		_wings_ctrl.set_anim_state(anim_idx, false)


func _on_auto_burst_toggled(enabled: bool) -> void:
	if _wings_ctrl != null:
		_wings_ctrl.set_auto_fire_burst(enabled)


func _on_view_selected(view_key: String) -> void:
	_turntable_enabled = false
	var tchk: CheckBox = _hud_refs.get("turntable_chk", null) as CheckBox
	if is_instance_valid(tchk):
		tchk.set_pressed_no_signal(false)
	var deg: float = float(VIEW_YAW_DEG.get(view_key, 0.0))
	var yslider: HSlider = _hud_refs.get("yaw_slider", null) as HSlider
	if is_instance_valid(yslider):
		yslider.set_value_no_signal(deg)
	_apply_yaw_deg(deg, true)


func _on_yaw_deg_changed(deg: float) -> void:
	_turntable_enabled = false
	var tchk: CheckBox = _hud_refs.get("turntable_chk", null) as CheckBox
	if is_instance_valid(tchk):
		tchk.set_pressed_no_signal(false)
	_apply_yaw_deg(deg, false)


func _on_turntable_toggled(enabled: bool) -> void:
	_turntable_enabled = enabled


func _on_light_orbit_toggled(enabled: bool) -> void:
	if _wings_ctrl != null:
		_wings_ctrl.set_auto_light_orbit(enabled)


func _on_compare_2d_toggled(enabled: bool) -> void:
	_compare_2d_enabled = enabled
	if _wings_ctrl != null:
		_wings_ctrl.visible = not enabled
	if _rig != null:
		_rig.set_base_propulsion_wings_enabled(enabled)


func _on_show_pilot_toggled(enabled: bool) -> void:
	_show_pilot = enabled
	if _rig != null:
		_rig.visible = enabled


func _on_idle_pilot_toggled(enabled: bool) -> void:
	_idle_pilot = enabled
	if _rig != null:
		_rig.set_idle_anim_enabled(enabled)


func _on_follow_skin_toggled(_enabled: bool) -> void:
	if _profile != null and _active_skin_idx >= 0 and _active_skin_idx < _profile.skins.size():
		if _wings_ctrl != null:
			_wings_ctrl.apply_skin_preset(_profile.skins[_active_skin_idx])


func _on_skin_selected(idx: int) -> void:
	if _profile == null or idx < 0 or idx >= _profile.skins.size():
		return
	_active_skin_idx = idx
	var skin: PilotSkinPreset = _profile.skins[idx]
	if _rig != null:
		_rig.apply_skin_preset(skin)
	if _wings_ctrl != null:
		_wings_ctrl.apply_skin_preset(skin)


func _on_save_config() -> void:
	if _config == null:
		return
	var err: Error = ResourceSaver.save(_config, CONFIG_PATH)
	var lbl: Label = _hud_refs.get("status_label", null) as Label
	if is_instance_valid(lbl):
		lbl.text = "Guardado OK: valentina_v2_wings_3d.tres" if err == OK else "Error al guardar (%d)" % err


func _on_reload_config() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		var reloaded: ConfigScript = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
		if reloaded != null:
			_config = reloaded
			_config.ensure_defaults()
			if _wings_ctrl != null:
				_wings_ctrl.set_config(_config)
	var lbl: Label = _hud_refs.get("status_label", null) as Label
	if is_instance_valid(lbl):
		lbl.text = "Recargado: valentina_v2_wings_3d.tres"
