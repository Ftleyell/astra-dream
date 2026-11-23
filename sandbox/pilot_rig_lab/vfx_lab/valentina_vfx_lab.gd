extends Node2D
## Laboratorio aislado de VFX de Propulsión (Sandevistan Astral — Valentina v2).
## Permite probar Propulsión Base vs Ráfaga Prolongada, calibrar el .tres en vivo
## y verificar legibilidad frente a balas danmaku simuladas.

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const TrailCtrlScript = preload("res://scenes/pilots/vfx/sandevistan_trail_controller.gd")
const BasePropCtrlScript = preload("res://scenes/pilots/vfx/valentina_base_propulsion_controller.gd")
const BasePropConfigScript = preload("res://data/pilots/schemas/pilot_base_propulsion_config.gd")
const VFXLabHUDScript = preload("res://sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab_hud.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const VFX_CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres"
const BASE_PROPULSION_CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_base_propulsion.tres"
const STYLES_DIR: String = "res://data/pilots/styles"
const ABERRATION_SHADER_PATH: String = "res://scenes/pilots/shaders/sandevistan_edge_aberration.gdshader"

const MANUAL_MAX_SPEED_PX: float = 340.0
const MANUAL_ACCEL: float = 1650.0
const MANUAL_FRICTION: float = 1150.0
const BRAKE_FRICTION: float = 3200.0
const ORBIT_RADIUS_PX: float = 195.0
const AUTO_BURST_PERIOD_SEC: float = 3.2
const DANMAKU_ORB_COUNT: int = 24

enum FlightDemoMode {
	AUTO_S_CURVE = 0,
	AUTO_ORBIT_KITING = 1,
	AUTO_BURST_LOOP = 2,
	MANUAL = 3,
}

var _profile: PilotRigProfile = null
var _vfx_config: PilotPropulsionVFXConfig = null
var _base_prop_config: BasePropConfigScript = null
var _backdrop: BackdropScript = null
var _camera: Camera2D = null
var _rig: PlanarCombatRig = null
var _trail_ctrl: SandevistanTrailController = null
var _base_prop_ctrl: BasePropCtrlScript = null
var _danmaku_layer: Node2D = null
var _aberration_rect: ColorRect = null
var _aberration_mat: ShaderMaterial = null
var _hud_refs: Dictionary = {}

var _flight_mode: int = FlightDemoMode.AUTO_S_CURVE
var _sim_time: float = 0.0
var _auto_burst_timer: float = 1.6
var _burst_remaining: float = 0.0
var _hitstop_remaining: float = 0.0
var _aberration_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.RIGHT
var _target_zoom: float = 1.25
var _show_danmaku_orbs: bool = true
var _enable_burst_slowmo: bool = true
var _sandevistan_enabled: bool = true
var _danmaku_orbs: Array[Dictionary] = []


func _ready() -> void:
	_load_resources()
	_build_environment()
	_build_scene_nodes()
	_build_danmaku_orbs()
	_build_postfx_aberration()
	_configure_rig_defaults()
	if _base_prop_ctrl != null and _rig != null:
		_base_prop_ctrl.attach_to_rig(_rig)

	_hud_refs = VFXLabHUDScript.build_hud(self, _vfx_config, {
		"on_mode_selected": Callable(self, "_on_mode_selected"),
		"on_trigger_burst": Callable(self, "trigger_sandevistan_burst"),
		"on_clear_ghosts": Callable(self, "_on_clear_ghosts"),
		"on_orbs_toggled": Callable(self, "_on_orbs_toggled"),
		"on_slowmo_toggled": Callable(self, "_on_slowmo_toggled"),
		"on_sandevistan_toggled": Callable(self, "_on_sandevistan_toggled"),
		"on_save_config": Callable(self, "_on_save_config"),
		"on_reload_config": Callable(self, "_on_reload_config"),
	}, _base_prop_config)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_SPACE:
				trigger_sandevistan_burst()
			elif kev.keycode == KEY_B:
				_trigger_hard_brake()
			elif kev.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				if _flight_mode != FlightDemoMode.MANUAL:
					_set_flight_mode(FlightDemoMode.MANUAL)
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.55, 2.8)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.55, 2.8)


func _process(delta: float) -> void:
	if _rig == null or _trail_ctrl == null or _vfx_config == null:
		return

	# Hitstop breve en arranque/impacto (mantiene intacta la estela detrás)
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(0.0, _hitstop_remaining - delta)
		_update_aberration(delta)
		return

	var is_burst: bool = _burst_remaining > 0.0
	if is_burst:
		_burst_remaining = maxf(0.0, _burst_remaining - delta)

	var world_dt: float = delta * (_vfx_config.burst_world_time_scale if (is_burst and _enable_burst_slowmo) else 1.0)
	_update_danmaku_orbs(world_dt)
	_update_aberration(delta)

	var prev_pos: Vector2 = _rig.position
	var aim_dir: Vector2 = _last_move_dir

	match _flight_mode:
		FlightDemoMode.AUTO_S_CURVE:
			aim_dir = _step_auto_s_curve(delta, is_burst)
		FlightDemoMode.AUTO_ORBIT_KITING:
			aim_dir = _step_auto_orbit_kiting(delta, is_burst)
		FlightDemoMode.AUTO_BURST_LOOP:
			aim_dir = _step_auto_burst_loop(delta, is_burst)
		FlightDemoMode.MANUAL:
			aim_dir = _step_manual_flight(delta, is_burst)

	var actual_vel: Vector2 = (_rig.position - prev_pos) / maxf(delta, 0.0001)
	if actual_vel.length_squared() > 16.0:
		_last_move_dir = actual_vel.normalized()

	var speed_norm: float = clampf(actual_vel.length() / MANUAL_MAX_SPEED_PX, 0.0, 1.0)
	_rig.set_locomotion_state(_last_move_dir, speed_norm, aim_dir, is_burst)
	if _base_prop_ctrl != null:
		_base_prop_ctrl.step(delta, _rig, actual_vel, is_burst)
	if _sandevistan_enabled or is_burst:
		_trail_ctrl.step(delta, _rig, actual_vel, is_burst)
	else:
		_trail_ctrl.step(delta, _rig, Vector2.ZERO, false)

	if _camera != null:
		var cam_target: Vector2 = _rig.position * 0.45
		_camera.position = _camera.position.lerp(cam_target, clampf(delta * 5.5, 0.0, 1.0))
		var cur_z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 9.0, 0.0, 1.0))
		_camera.zoom = Vector2(cur_z, cur_z)

	_update_telemetry_label(actual_vel.length(), is_burst)


func trigger_sandevistan_burst() -> void:
	if _vfx_config == null or _trail_ctrl == null or _rig == null:
		return
	_burst_remaining = _vfx_config.burst_duration_sec
	_hitstop_remaining = _vfx_config.burst_hitstop_sec
	if _vfx_config.aberration_enabled:
		_aberration_timer = _vfx_config.aberration_decay_sec
	_trail_ctrl.trigger_burst_impulse(_rig)


func get_rig() -> PlanarCombatRig:
	return _rig


func get_trail_controller() -> SandevistanTrailController:
	return _trail_ctrl


func get_vfx_config() -> PilotPropulsionVFXConfig:
	return _vfx_config


func get_base_propulsion_controller() -> BasePropCtrlScript:
	return _base_prop_ctrl


func get_base_propulsion_config() -> BasePropConfigScript:
	return _base_prop_config


func _load_resources() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(VFX_CONFIG_PATH):
		_vfx_config = ResourceLoader.load(VFX_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PilotPropulsionVFXConfig
	if _vfx_config == null:
		_vfx_config = PilotPropulsionVFXConfig.new()
	_vfx_config.ensure_defaults()
	if ResourceLoader.exists(BASE_PROPULSION_CONFIG_PATH):
		_base_prop_config = ResourceLoader.load(BASE_PROPULSION_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BasePropConfigScript
	if _base_prop_config == null:
		_base_prop_config = BasePropConfigScript.new()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.15
	env.glow_intensity = 0.55
	env.glow_bloom = 0.10
	var we := WorldEnvironment.new()
	we.name = "VFXLabWorldEnvironment"
	we.environment = env
	add_child(we)


func _build_scene_nodes() -> void:
	_backdrop = BackdropScript.new()
	_backdrop.name = "SpaceBackdrop"
	_backdrop.show_light_gizmo = false
	add_child(_backdrop)
	_backdrop.set_mode(BackdropScript.BackdropMode.SPACE_NEBULA)

	_camera = Camera2D.new()
	_camera.name = "VFXLabCamera"
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	add_child(_camera)

	_trail_ctrl = TrailCtrlScript.new()
	_trail_ctrl.name = "SandevistanTrailController"
	_trail_ctrl.set_config(_vfx_config)
	add_child(_trail_ctrl)

	_base_prop_ctrl = BasePropCtrlScript.new()
	_base_prop_ctrl.name = "ValentinaBasePropulsionController"
	_base_prop_ctrl.z_index = 4
	_base_prop_ctrl.set_config(_base_prop_config)
	add_child(_base_prop_ctrl)

	_rig = PlanarRigScript.new()
	_rig.name = "ValentinaVFXRig"
	_rig.pilot_profile = _profile
	_rig.z_index = 5
	_rig.enable_face_live = true
	add_child(_rig)

	_danmaku_layer = Node2D.new()
	_danmaku_layer.name = "DanmakuReadabilityLayer"
	_danmaku_layer.z_index = 8
	add_child(_danmaku_layer)


func _configure_rig_defaults() -> void:
	if _rig == null:
		return
	_rig.enable_afterimage = false
	_rig.set_live_animations_enabled(true)

	# Cargar estilo 02_valentina_razor_sharp si existe
	var dir: DirAccess = DirAccess.open(STYLES_DIR)
	var latest_style: RigStyleProfile = null
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


func _build_danmaku_orbs() -> void:
	_danmaku_orbs.clear()
	for i: int in range(DANMAKU_ORB_COUNT):
		var angle: float = float(i) / float(DANMAKU_ORB_COUNT) * TAU
		var radius: float = 120.0 + float(i % 4) * 65.0
		var is_gold: bool = (i % 3 == 0)
		var orb := Polygon2D.new()
		var pts := PackedVector2Array()
		for k: int in range(12):
			var a: float = float(k) / 12.0 * TAU
			pts.append(Vector2(cos(a), sin(a)) * (6.5 if is_gold else 5.2))
		orb.polygon = pts
		orb.color = Color(1.0, 0.82, 0.25, 0.95) if is_gold else Color(1.0, 0.22, 0.36, 0.95)
		orb.position = Vector2(cos(angle), sin(angle)) * radius
		_danmaku_layer.add_child(orb)
		_danmaku_orbs.append({
			"node": orb,
			"angle": angle,
			"radius": radius,
			"ang_vel": (0.55 if (i % 2 == 0) else -0.42),
		})


func _update_danmaku_orbs(world_dt: float) -> void:
	if _danmaku_layer == null:
		return
	_danmaku_layer.visible = _show_danmaku_orbs
	if not _show_danmaku_orbs:
		return
	for item: Dictionary in _danmaku_orbs:
		var ang: float = float(item["angle"]) + float(item["ang_vel"]) * world_dt
		item["angle"] = ang
		var r: float = float(item["radius"])
		var n: Polygon2D = item["node"] as Polygon2D
		if is_instance_valid(n):
			n.position = Vector2(cos(ang), sin(ang)) * r


func _build_postfx_aberration() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.name = "AberrationPostFXLayer"
	post_layer.layer = 15
	add_child(post_layer)

	_aberration_rect = ColorRect.new()
	_aberration_rect.name = "EdgeAberrationRect"
	_aberration_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aberration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aberration_rect.color = Color(1.0, 1.0, 1.0, 1.0)

	if ResourceLoader.exists(ABERRATION_SHADER_PATH):
		_aberration_mat = ShaderMaterial.new()
		_aberration_mat.shader = ResourceLoader.load(ABERRATION_SHADER_PATH) as Shader
		_aberration_mat.set_shader_parameter("strength_px", 0.0)
		_aberration_rect.material = _aberration_mat
	post_layer.add_child(_aberration_rect)


func _update_aberration(delta: float) -> void:
	if _aberration_mat == null or _vfx_config == null:
		return
	if _aberration_timer > 0.0 and _vfx_config.aberration_enabled:
		_aberration_timer = maxf(0.0, _aberration_timer - delta)
		var norm: float = _aberration_timer / maxf(0.01, _vfx_config.aberration_decay_sec)
		_aberration_mat.set_shader_parameter("strength_px", _vfx_config.aberration_peak_px * norm * norm)
	else:
		_aberration_mat.set_shader_parameter("strength_px", 0.0)


func _step_auto_s_curve(delta: float, is_burst: bool) -> Vector2:
	var spd_mult: float = _vfx_config.burst_speed_mult if is_burst else 1.0
	_sim_time += delta * 1.15 * spd_mult
	_auto_burst_timer -= delta
	if _auto_burst_timer <= 0.0:
		_auto_burst_timer = AUTO_BURST_PERIOD_SEC
		trigger_sandevistan_burst()

	var target := Vector2(sin(_sim_time) * 260.0, sin(_sim_time * 2.0) * 125.0)
	_rig.position = _rig.position.lerp(target, clampf(delta * 10.0, 0.0, 1.0))
	var tangent := Vector2(cos(_sim_time) * 260.0, cos(_sim_time * 2.0) * 250.0)
	return tangent.normalized() if tangent.length_squared() > 1.0 else Vector2.RIGHT


func _step_auto_orbit_kiting(delta: float, is_burst: bool) -> Vector2:
	var spd_mult: float = _vfx_config.burst_speed_mult if is_burst else 1.0
	_sim_time += delta * 1.25 * spd_mult
	_rig.position = Vector2(cos(_sim_time), sin(_sim_time)) * ORBIT_RADIUS_PX
	# Kiting: mira hacia el centro mientras orbita lateralmente
	return (-_rig.position).normalized()


func _step_auto_burst_loop(delta: float, is_burst: bool) -> Vector2:
	var spd_mult: float = _vfx_config.burst_speed_mult if is_burst else 0.9
	_sim_time += delta * 1.85 * spd_mult
	if not is_burst:
		trigger_sandevistan_burst()
	var target := Vector2(cos(_sim_time) * 240.0, sin(_sim_time * 1.5) * 150.0)
	_rig.position = _rig.position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	return _last_move_dir


func _step_manual_flight(delta: float, is_burst: bool) -> Vector2:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	var max_spd: float = MANUAL_MAX_SPEED_PX * (_vfx_config.burst_speed_mult if is_burst else 1.0)
	if input_vec.length_squared() > 0.01:
		var dir: Vector2 = input_vec.normalized()
		_velocity = _velocity.move_toward(dir * max_spd, MANUAL_ACCEL * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, MANUAL_FRICTION * delta)

	_rig.position += _velocity * delta
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - _rig.global_position
	return to_mouse.normalized() if to_mouse.length_squared() > 4.0 else _last_move_dir


func _trigger_hard_brake() -> void:
	_velocity = _velocity.move_toward(Vector2.ZERO, BRAKE_FRICTION * 0.12)
	_hitstop_remaining = _vfx_config.burst_hitstop_sec * 0.8


func _set_flight_mode(mode_idx: int) -> void:
	_flight_mode = mode_idx
	var opt: OptionButton = _hud_refs.get("mode_opt", null) as OptionButton
	if opt != null and opt.selected != mode_idx:
		opt.select(mode_idx)


func _on_mode_selected(idx: int) -> void:
	_flight_mode = idx
	_velocity = Vector2.ZERO


func _on_clear_ghosts() -> void:
	if _trail_ctrl != null:
		_trail_ctrl.clear_all_ghosts()
	if _base_prop_ctrl != null:
		_base_prop_ctrl.clear_trails()


func _on_orbs_toggled(enabled: bool) -> void:
	_show_danmaku_orbs = enabled


func _on_slowmo_toggled(enabled: bool) -> void:
	_enable_burst_slowmo = enabled


func _on_sandevistan_toggled(enabled: bool) -> void:
	_sandevistan_enabled = enabled
	if not enabled and _trail_ctrl != null:
		_trail_ctrl.clear_all_ghosts()


func _on_save_config() -> void:
	if _vfx_config == null:
		return
	var err_s: Error = ResourceSaver.save(_vfx_config, VFX_CONFIG_PATH)
	var err_b: Error = OK
	if _base_prop_config != null:
		err_b = ResourceSaver.save(_base_prop_config, BASE_PROPULSION_CONFIG_PATH)
	var status: Label = _hud_refs.get("status_label", null) as Label
	if status != null:
		status.text = "Guardados Sandevistan + Propulsión Base (.tres)" if (err_s == OK and err_b == OK) else "Error al guardar (%d/%d)" % [err_s, err_b]


func _on_reload_config() -> void:
	if ResourceLoader.exists(VFX_CONFIG_PATH):
		var reloaded: PilotPropulsionVFXConfig = ResourceLoader.load(
			VFX_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as PilotPropulsionVFXConfig
		if reloaded != null:
			reloaded.ensure_defaults()
			_vfx_config = reloaded
			if _trail_ctrl != null:
				_trail_ctrl.set_config(_vfx_config)
	if ResourceLoader.exists(BASE_PROPULSION_CONFIG_PATH):
		var reloaded_b: BasePropConfigScript = ResourceLoader.load(
			BASE_PROPULSION_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as BasePropConfigScript
		if reloaded_b != null:
			_base_prop_config = reloaded_b
			if _base_prop_ctrl != null:
				_base_prop_ctrl.set_config(_base_prop_config)
	var status: Label = _hud_refs.get("status_label", null) as Label
	if status != null:
		status.text = "Configuraciones recargadas desde .tres"


func _update_telemetry_label(speed_px: float, is_burst: bool) -> void:
	var lbl: Label = _hud_refs.get("telemetry_label", null) as Label
	if lbl == null or _trail_ctrl == null:
		return
	var regime: String = "SANDEVISTAN" if is_burst else "BASE"
	var eff_l: int = int(roundf(_base_prop_ctrl.get_effort_left() * 100.0)) if _base_prop_ctrl != null else 0
	var eff_r: int = int(roundf(_base_prop_ctrl.get_effort_right() * 100.0)) if _base_prop_ctrl != null else 0
	lbl.text = "Ghosts:%d | Vel:%d | Empuje L:%d%% R:%d%% | %s" % [
		_trail_ctrl.get_active_ghost_count(),
		int(roundf(speed_px)),
		eff_l,
		eff_r,
		regime,
	]
