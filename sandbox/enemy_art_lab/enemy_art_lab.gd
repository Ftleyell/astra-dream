extends Node2D

## Dedicated Enemy 2.5D Workbench (Sandbox).
## Focused strictly on inspecting, tilting, lighting, piloting, and calibrating enemy rigs
## (Void Scarab 2.5D) with NO Valentina rig cluttering the viewport.

const CosmosCombatEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const VoidScarabRigScript = preload("res://scenes/combat/enemies/rig/void_scarab_rig_25d.gd")
const ScarabConfigScript = preload("res://data/enemies/schemas/enemy_scarab_rig_config.gd")
const ScarabStyleScript = preload("res://data/enemies/schemas/enemy_faction_style.gd")
const SequenceDirectorScript = preload("res://sandbox/enemy_art_lab/enemy_sequence_director.gd")
const HudScript = preload("res://sandbox/enemy_art_lab/enemy_art_lab_hud.gd")
const DefaultScarabConfigRes = preload("res://data/enemies/void_scarab/void_scarab_config.tres")
const DefaultScarabStyleRes = preload("res://data/enemies/void_scarab/style_biomech_void.tres")

const SCARAB_CONFIG_PATH: String = "res://data/enemies/void_scarab/void_scarab_config.tres"
const SCARAB_STYLE_PATH: String = "res://data/enemies/void_scarab/style_biomech_void.tres"

enum ControlMode {
	COSMOS_SEQUENCE = 0,
	INSPECT_25D = 1,
	PILOT_WASD = 2,
	STALK_MOUSE_AI = 3,
}

enum BackdropMode {
	STUDIO_GRID = 0,
	DEEP_VOID = 1,
	COSMOS_LIVE = 2,
}

const CONTROL_LABELS: Array[String] = ["Secuencias Cosmos", "Inspect 2.5D (Drag)", "Pilot Scarab (WASD)", "Stalk Mouse AI"]
const BACKDROP_LABELS: Array[String] = ["Studio Grid", "Deep Void", "Cosmos Live"]
const BIOME_ORDER: Array[StringName] = [
	&"perseus_rift",
	&"hyperion_forge",
	&"carina_abyss",
	&"crimson_veil",
	&"silica_corona",
	&"bootes_void",
]

const PILOT_ACCEL: float = 1650.0
const PILOT_MAX_SPEED: float = 440.0
const PILOT_TURBO_SPEED: float = 760.0


class _StudioBackdrop extends Node2D:
	var owner_lab: Node2D = null

	func _draw() -> void:
		if owner_lab == null:
			return
		var bg_mode: int = int(owner_lab.get("_backdrop_mode"))
		if bg_mode == BackdropMode.COSMOS_LIVE:
			return

		var center: Vector2 = owner_lab.call("get_workbench_center")
		var bg_col: Color = Color(0.055, 0.062, 0.110, 1.0) if bg_mode == BackdropMode.STUDIO_GRID else Color(0.015, 0.016, 0.032, 1.0)
		draw_rect(Rect2(center - Vector2(2600.0, 2600.0), Vector2(5200.0, 5200.0)), bg_col, true)

		if bg_mode == BackdropMode.STUDIO_GRID:
			var grid_col := Color(0.22, 0.30, 0.48, 0.18)
			var step_px: float = 48.0
			for gx: int in range(-18, 19):
				var x: float = center.x + float(gx) * step_px
				draw_line(Vector2(x, center.y - 900.0), Vector2(x, center.y + 900.0), grid_col, 1.0)
			for gy: int in range(-18, 19):
				var y: float = center.y + float(gy) * step_px
				draw_line(Vector2(center.x - 900.0, y), Vector2(center.x + 900.0, y), grid_col, 1.0)
			draw_arc(center, 110.0, 0.0, TAU, 48, Color(0.32, 0.85, 0.65, 0.22), 1.5)
			draw_arc(center, 220.0, 0.0, TAU, 64, Color(0.55, 0.45, 0.92, 0.16), 1.2)

		# Draw live Key Light Orb & directional ray so 2.5D shading is visually verifiable
		var light_dir: Vector2 = owner_lab.call("get_active_light_dir")
		var light_pos: Vector2 = center + light_dir * 165.0
		draw_line(light_pos, center, Color(1.0, 0.92, 0.62, 0.28), 1.8)
		draw_circle(light_pos, 11.0, Color(1.0, 0.94, 0.68, 0.90))
		draw_circle(light_pos, 18.0, Color(1.0, 0.86, 0.45, 0.22))


var _backdrop: _StudioBackdrop = null
var _cosmos_env: CosmosCombatEnvironment = null
var _cosmos_root: CosmosRootNode = null
var _host_controller: CosmosHostControllerScript = null
var _camera: Camera2D = null
var _scarab_primary: VoidScarabRigScript = null
var _swarm_nodes: Array[VoidScarabRigScript] = []
var _sequence_director: SequenceDirectorScript = null
var _hud: CanvasLayer = null

var _scarab_cfg: ScarabConfigScript = null
var _scarab_style: ScarabStyleScript = null
var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()

var _control_mode: int = ControlMode.COSMOS_SEQUENCE
var _backdrop_mode: int = BackdropMode.COSMOS_LIVE
var _target_zoom: float = 1.15
var _swarm_enabled: bool = false
var _variant_idx: int = -1
var _debug_mode: int = 0
var _teleport_mode: int = 0
var _biome_cycle_idx: int = 0

var _auto_light_orbit: bool = true
var _bright_light_mode: bool = false
var _light_angle_deg: float = -125.0
var _light_z: float = 0.58
var _lock_tilt: bool = false
var _manual_tilt: Vector2 = Vector2.ZERO
var _flat_ab_active: bool = false

var _dragging_tilt: bool = false
var _dragging_light: bool = false
var _drag_anchor: Vector2 = Vector2.ZERO

var _scarab_vel: Vector2 = Vector2.ZERO
var _ai_orbit_angle: float = 0.0
var _ai_strike_timer: float = 2.6
var _pilot_attack_phase: int = 0
var _pilot_attack_timer: float = 0.0
var _save_flash_msg: String = ""
var _save_flash_timer: float = 0.0


func _ready() -> void:
	_scarab_cfg = DefaultScarabConfigRes.duplicate() as ScarabConfigScript
	_scarab_style = DefaultScarabStyleRes.duplicate() as ScarabStyleScript
	_build_environment()
	_build_backdrops()
	_build_camera_and_scarabs()
	if _backdrop_mode == BackdropMode.COSMOS_LIVE:
		_ensure_cosmos_built()
	_build_sequence_director()
	_build_hud()
	_sync_backdrop_visibility()
	if _sequence_director != null and _scarab_primary != null:
		_sequence_director.start_sequence(SequenceDirectorScript.SequenceId.PATROL_CRUISE, _scarab_primary.position, _host_controller)


func _build_sequence_director() -> void:
	_sequence_director = SequenceDirectorScript.new()
	_sequence_director.name = "EnemySequenceDirector"
	_sequence_director.z_index = 4
	add_child(_sequence_director)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.12
	env.glow_intensity = 0.62
	env.glow_bloom = 0.16
	var we := WorldEnvironment.new()
	we.name = "EnemyWorkbenchEnvironment"
	we.environment = env
	add_child(we)


func _build_backdrops() -> void:
	_backdrop = _StudioBackdrop.new()
	_backdrop.name = "StudioBackdrop"
	_backdrop.owner_lab = self
	_backdrop.z_index = -50
	add_child(_backdrop)


func _ensure_cosmos_built() -> void:
	if _cosmos_env != null:
		return
	_cosmos_env = CosmosCombatEnvScene.instantiate() as CosmosCombatEnvironment
	_cosmos_env.name = "CosmosCombatEnvironment"
	_cosmos_env.z_index = -100
	add_child(_cosmos_env)
	if _camera != null:
		_cosmos_env.set_camera_reference(_camera)
	_cosmos_root = _cosmos_env.cosmos_root
	_host_controller = _cosmos_env.get_host_controller()
	if _cosmos_root != null:
		_cosmos_root.player_target = _scarab_primary
		_cosmos_root.bind_camera_to_streamers()


func _build_camera_and_scarabs() -> void:
	_scarab_primary = VoidScarabRigScript.new()
	_scarab_primary.name = "VoidScarabPrimary"
	_scarab_primary.rig_config = _scarab_cfg
	_scarab_primary.style_profile = _scarab_style
	_scarab_primary.position = Vector2.ZERO
	_scarab_primary.rotation = -PI * 0.5 # Default facing UP in Studio inspect
	_scarab_primary.z_index = 6
	add_child(_scarab_primary)

	_camera = Camera2D.new()
	_camera.name = "WorkbenchCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 10.0
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	_camera.position = Vector2.ZERO
	add_child(_camera)

	_swarm_nodes.clear()
	for i: int in range(6):
		var sw: VoidScarabRigScript = VoidScarabRigScript.new()
		sw.name = "VoidScarabSwarm_%d" % i
		sw.rig_config = _scarab_cfg
		sw.style_profile = _scarab_style
		sw.visible = false
		sw.z_index = 4
		add_child(sw)
		_swarm_nodes.append(sw)


func _build_hud() -> void:
	_hud = HudScript.new()
	add_child(_hud)
	_hud.call("setup", _scarab_cfg, _scarab_style)
	_hud.call("set_light_ui", _light_angle_deg, _light_z)
	_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active)

	_hud.connect("state_selected", _on_state_selected)
	_hud.connect("bite_requested", _on_bite_snap)
	_hud.connect("hit_flash_requested", _on_hit_flash)
	_hud.connect("shatter_toggle_requested", _on_shatter_toggle)
	_hud.connect("swarm_toggle_requested", _on_swarm_toggle)
	_hud.connect("motion_mode_cycled", _on_motion_mode_cycled)
	_hud.connect("variant_cycled", _on_variant_cycled)
	_hud.connect("backdrop_cycled", _on_backdrop_cycled)
	_hud.connect("auto_light_toggled", _on_auto_light_toggled)
	_hud.connect("bright_light_toggled", _on_bright_light_toggled)
	_hud.connect("lock_tilt_toggled", _on_lock_tilt_toggled)
	_hud.connect("reset_tilt_requested", _on_reset_tilt)
	_hud.connect("flat_compare_toggled", _on_flat_compare_toggled)
	_hud.connect("debug_mode_selected", _on_debug_mode_selected)
	_hud.connect("cosmos_biome_requested", _cycle_cosmos_biome)
	_hud.connect("cosmos_vantage_requested", _cycle_teleport_vantage)
	_hud.connect("save_config_requested", _save_scarab_configs)
	_hud.connect("calibration_changed", _apply_calibration_and_style)
	_hud.connect("show_pivots_toggled", _on_show_pivots_toggled)
	_hud.connect("sequence_selected", func(seq_idx: int) -> void: select_sequence(seq_idx, false))
	_hud.connect("auto_reel_toggled", _on_auto_reel_toggled)
	_hud.connect("light_params_changed", func(ang: float, lz: float) -> void:
		_auto_light_orbit = false
		_light_angle_deg = ang
		_light_z = lz
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)
	)
	if _sequence_director != null:
		_hud.call("set_sequence_ui", _sequence_director.auto_reel, _sequence_director.active_sequence, _control_mode == ControlMode.COSMOS_SEQUENCE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_TAB:
			if kev.pressed and not kev.echo:
				_on_flat_compare_toggled(true)
			elif not kev.pressed:
				_on_flat_compare_toggled(false)
			return
		if kev.pressed and not kev.echo:
			match kev.keycode:
				KEY_1: _on_state_selected(0)
				KEY_2: _on_state_selected(1)
				KEY_3: _on_state_selected(2)
				KEY_4: _on_state_selected(3)
				KEY_F: _on_bite_snap()
				KEY_H: _on_hit_flash()
				KEY_X: _on_shatter_toggle()
				KEY_P: _on_motion_mode_cycled()
				KEY_B: _on_backdrop_cycled()
				KEY_M: _on_swarm_toggle()
				KEY_V: _on_variant_cycled()
				KEY_L: _on_auto_light_toggled()
				KEY_E: _on_bright_light_toggled()
				KEY_R: _on_reset_tilt()
				KEY_C: _hud.call("toggle_calibration")
				KEY_G: _on_auto_reel_toggled()
				KEY_T: _cycle_teleport_vantage()
				KEY_K: _cycle_cosmos_biome()
				KEY_SPACE:
					if _control_mode == ControlMode.PILOT_WASD:
						_trigger_pilot_attack()
					else:
						_on_bite_snap()
				KEY_0: _on_debug_mode_selected(0)
				KEY_5: _on_debug_mode_selected(5)
				KEY_6: _on_debug_mode_selected(6)
				KEY_7: _on_debug_mode_selected(7)
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.button_index == MOUSE_BUTTON_WHEEL_UP and mev.pressed:
			_target_zoom = clampf(_target_zoom * 1.12, 0.55, 4.2)
		elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN and mev.pressed:
			_target_zoom = clampf(_target_zoom / 1.12, 0.55, 4.2)
		elif mev.button_index == MOUSE_BUTTON_LEFT:
			if mev.pressed:
				if _control_mode == ControlMode.INSPECT_25D:
					_dragging_tilt = true
					_drag_anchor = mev.position
				elif _control_mode == ControlMode.PILOT_WASD:
					_trigger_pilot_attack()
			else:
				_dragging_tilt = false
		elif mev.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_light = mev.pressed
			if mev.pressed:
				_auto_light_orbit = false
				_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)
				_update_light_from_mouse()
	elif event is InputEventMouseMotion:
		var mmv: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging_tilt and _control_mode == ControlMode.INSPECT_25D:
			var d: Vector2 = (mmv.position - _drag_anchor) / 140.0
			_manual_tilt = Vector2(clampf(d.x, -1.0, 1.0), clampf(d.y, -1.0, 1.0))
		elif _dragging_light:
			_update_light_from_mouse()


func _update_light_from_mouse() -> void:
	if _scarab_primary == null:
		return
	var offset: Vector2 = get_global_mouse_position() - _scarab_primary.global_position
	if offset.length_squared() > 4.0:
		_light_angle_deg = rad_to_deg(offset.angle())
		_light_z = clampf(1.25 - offset.length() / 320.0, 0.18, 1.45)
		_hud.call("set_light_ui", _light_angle_deg, _light_z)


func _process(delta: float) -> void:
	_step_light(delta)
	_step_scarab_control(delta)
	_step_camera_and_swarm(delta)
	if _backdrop != null and _backdrop.visible:
		_backdrop.queue_redraw()
	_update_status(delta)


func _step_light(delta: float) -> void:
	if _auto_light_orbit and _backdrop_mode != BackdropMode.COSMOS_LIVE:
		_light_angle_deg = wrapf(_light_angle_deg + delta * 44.0, -180.0, 180.0)
		if _hud != null:
			_hud.call("set_light_ui", _light_angle_deg, _light_z)

	if _backdrop_mode == BackdropMode.COSMOS_LIVE and _host_controller != null and _scarab_primary != null:
		_host_controller.sample_lighting_at(_scarab_primary.global_position, _lighting_sample)
		_scarab_primary.apply_cosmic_lighting(_lighting_sample)
		if _hud != null:
			_hud.call("set_light_ui", rad_to_deg(_lighting_sample.light_dir_2d.angle()), _light_z)
		for sw: VoidScarabRigScript in _swarm_nodes:
			if sw.visible:
				_host_controller.sample_lighting_at(sw.global_position, _lighting_sample)
				sw.apply_cosmic_lighting(_lighting_sample)
		if _cosmos_root != null:
			_cosmos_root.set_player_aura_light(
				_scarab_primary.get_active_energy_color(),
				Vector2.ZERO,
				260.0,
				_scarab_primary.get_core_aura_energy(),
				Vector2.RIGHT.rotated(_scarab_primary.rotation + PI * 0.5)
			)
	else:
		var l_dir: Vector2 = get_active_light_dir()
		if _scarab_primary != null:
			_scarab_primary.set_light_override(l_dir, _light_z, 0.0)
		for sw: VoidScarabRigScript in _swarm_nodes:
			if sw.visible:
				sw.set_light_override(l_dir, _light_z, 0.0)


func _step_scarab_control(delta: float) -> void:
	if _scarab_primary == null:
		return

	var ang_vel: float = 0.0
	var fwd_norm: float = 0.0
	var accel_norm: float = 0.0
	var prev_speed: float = _scarab_vel.length()

	if _control_mode == ControlMode.COSMOS_SEQUENCE and _sequence_director != null:
		var prev_seq: int = _sequence_director.active_sequence
		var seq_info: Dictionary = _sequence_director.step_sequence(delta, _scarab_primary, _swarm_nodes, _host_controller)
		_scarab_vel = seq_info.get("velocity", Vector2.ZERO) as Vector2
		var want_swarm: bool = bool(seq_info.get("swarm_active", false))
		if _swarm_enabled != want_swarm:
			_swarm_enabled = want_swarm
			for sw: VoidScarabRigScript in _swarm_nodes:
				sw.visible = _swarm_enabled
			_target_zoom = _sequence_director.get_recommended_zoom()
		elif prev_seq != _sequence_director.active_sequence:
			_target_zoom = _sequence_director.get_recommended_zoom()
		if _hud != null:
			_hud.call("set_sequence_ui", _sequence_director.auto_reel, _sequence_director.active_sequence, true)
		return

	if _control_mode == ControlMode.INSPECT_25D:
		if not _dragging_tilt and not _lock_tilt:
			_manual_tilt = _manual_tilt.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
		var rot_rel: float = _scarab_primary.rotation + PI * 0.5
		var local_tilt: Vector2 = _manual_tilt.rotated(-rot_rel)
		_scarab_primary.set_tilt_25d(local_tilt.x, local_tilt.y)
		_scarab_primary.position = _scarab_primary.position.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
		_scarab_primary.rotation = lerp_angle(_scarab_primary.rotation, -PI * 0.5, clampf(delta * 8.0, 0.0, 1.0))

	elif _control_mode == ControlMode.PILOT_WASD:
		var raw_x: float = (1.0 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0.0)
		var raw_y: float = (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
		var inp := Vector2(raw_x, raw_y)
		if inp.length_squared() > 1.0:
			inp = inp.normalized()
		var max_spd: float = PILOT_TURBO_SPEED if Input.is_key_pressed(KEY_SHIFT) else PILOT_MAX_SPEED
		_scarab_vel = _scarab_vel.move_toward(inp * max_spd, PILOT_ACCEL * delta)
		_scarab_primary.position += _scarab_vel * delta

		var spd: float = _scarab_vel.length()
		fwd_norm = clampf(spd / PILOT_MAX_SPEED, 0.0, 1.3)
		accel_norm = clampf(((spd - prev_speed) / maxf(delta, 0.001)) / PILOT_ACCEL, -1.0, 1.0)
		if spd > 18.0:
			var prev_r: float = _scarab_primary.rotation
			_scarab_primary.rotation = lerp_angle(prev_r, _scarab_vel.angle(), clampf(delta * 10.0, 0.0, 1.0))
			ang_vel = wrapf(_scarab_primary.rotation - prev_r, -PI, PI) / maxf(delta, 0.001)

		if _pilot_attack_phase > 0:
			_pilot_attack_timer -= delta
			if _pilot_attack_phase == 1 and _pilot_attack_timer <= 0.0:
				_pilot_attack_phase = 2
				_pilot_attack_timer = 0.44
				_scarab_primary.set_anim_state(VoidScarabRigScript.AnimState.ATTACK_LUNGE)
				_scarab_vel += Vector2.RIGHT.rotated(_scarab_primary.rotation) * 520.0
			elif _pilot_attack_phase == 2 and _pilot_attack_timer <= 0.0:
				_pilot_attack_phase = 0
		elif _scarab_primary.get_anim_state() != VoidScarabRigScript.AnimState.DEATH_SHATTER:
			var desired_st: int = VoidScarabRigScript.AnimState.CRUISE_BANK if spd > 35.0 else VoidScarabRigScript.AnimState.IDLE_HOVER
			if _scarab_primary.get_anim_state() != desired_st:
				_scarab_primary.set_anim_state(desired_st)
		_scarab_primary.set_tilt_25d(0.0, 0.0)

	else: # STALK_MOUSE_AI
		var target_pt: Vector2 = get_global_mouse_position()
		var prev_r: float = _scarab_primary.rotation
		_ai_orbit_angle += delta * 1.45
		var desired_pos: Vector2 = target_pt + Vector2(cos(_ai_orbit_angle) * 165.0, sin(_ai_orbit_angle) * 120.0)
		var to_des: Vector2 = desired_pos - _scarab_primary.position
		_scarab_vel = _scarab_vel.lerp(to_des * 3.8, clampf(delta * 5.0, 0.0, 1.0))
		_scarab_primary.position += _scarab_vel * delta
		if _scarab_vel.length_squared() > 25.0:
			_scarab_primary.rotation = lerp_angle(prev_r, _scarab_vel.angle(), clampf(delta * 9.0, 0.0, 1.0))
			ang_vel = wrapf(_scarab_primary.rotation - prev_r, -PI, PI) / maxf(delta, 0.001)
		fwd_norm = clampf(_scarab_vel.length() / 360.0, 0.0, 1.0)
		accel_norm = clampf(((_scarab_vel.length() - prev_speed) / maxf(delta, 0.001)) / 900.0, -1.0, 1.0)

		_ai_strike_timer -= delta
		if _ai_strike_timer <= 0.0:
			_ai_strike_timer = 3.2
			_scarab_primary.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)
		elif _ai_strike_timer <= 2.35 and _scarab_primary.get_anim_state() == VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH:
			_scarab_primary.set_anim_state(VoidScarabRigScript.AnimState.ATTACK_LUNGE)
			_scarab_vel += Vector2.RIGHT.rotated(_scarab_primary.rotation) * 440.0
		_scarab_primary.set_tilt_25d(0.0, 0.0)

	_scarab_primary.step(delta, ang_vel, fwd_norm, accel_norm)


func _step_camera_and_swarm(delta: float) -> void:
	if _camera != null and _scarab_primary != null:
		var look_ahead: Vector2 = _scarab_vel * 0.16 if (_control_mode == ControlMode.COSMOS_SEQUENCE or _control_mode == ControlMode.PILOT_WASD) else Vector2.ZERO
		_camera.position = _camera.position.lerp(_scarab_primary.position + look_ahead, clampf(delta * 9.0, 0.0, 1.0))
		var next_z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 8.0, 0.0, 1.0))
		_camera.zoom = Vector2(next_z, next_z)
		_scarab_primary.set_zoom_scale(next_z)
		for sw: VoidScarabRigScript in _swarm_nodes:
			sw.set_zoom_scale(next_z)

	if _swarm_enabled and _scarab_primary != null and _control_mode != ControlMode.COSMOS_SEQUENCE:
		for i: int in range(_swarm_nodes.size()):
			var sw: VoidScarabRigScript = _swarm_nodes[i]
			var a: float = _ai_orbit_angle * 0.8 + (TAU / 6.0) * float(i)
			var r: float = 225.0 + 30.0 * sin(_ai_orbit_angle * 1.6 + float(i))
			sw.position = _scarab_primary.position + Vector2(cos(a) * r, sin(a) * r * 0.72)
			sw.rotation = (_scarab_primary.position - sw.position).angle()
			sw.step(delta, 0.75, 0.6)


func _trigger_pilot_attack() -> void:
	if _scarab_primary == null:
		return
	_pilot_attack_phase = 1
	_pilot_attack_timer = 0.42
	_scarab_primary.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)


func _on_state_selected(idx: int) -> void:
	_pilot_attack_phase = 0
	if _scarab_primary != null:
		_scarab_primary.set_anim_state(idx)
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.set_anim_state(idx)


func _on_bite_snap() -> void:
	if _scarab_primary != null:
		_scarab_primary.trigger_bite_snap()
	for sw: VoidScarabRigScript in _swarm_nodes:
		if sw.visible:
			sw.trigger_bite_snap()


func _on_hit_flash() -> void:
	if _scarab_primary != null:
		_scarab_primary.trigger_hit_flash()
	for sw: VoidScarabRigScript in _swarm_nodes:
		if sw.visible:
			sw.trigger_hit_flash()


func _on_shatter_toggle() -> void:
	if _scarab_primary == null:
		return
	if _scarab_primary.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER:
		_scarab_primary.respawn()
	else:
		_scarab_primary.set_anim_state(VoidScarabRigScript.AnimState.DEATH_SHATTER)


func _on_swarm_toggle() -> void:
	_swarm_enabled = not _swarm_enabled
	_target_zoom = 0.95 if _swarm_enabled else 1.85
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.visible = _swarm_enabled


func _on_motion_mode_cycled() -> void:
	set_control_mode((_control_mode + 1) % 4)


func set_control_mode(mode: int) -> void:
	_control_mode = clampi(mode, 0, 3)
	_dragging_tilt = false
	_pilot_attack_phase = 0
	if _control_mode == ControlMode.COSMOS_SEQUENCE:
		if _sequence_director != null and _scarab_primary != null:
			_sequence_director.set_beacon_visible(true)
			_sequence_director.start_sequence(_sequence_director.active_sequence, _scarab_primary.position, _host_controller)
			_target_zoom = _sequence_director.get_recommended_zoom()
	else:
		if _sequence_director != null:
			_sequence_director.set_beacon_visible(false)
		if _swarm_enabled:
			_swarm_enabled = false
			for sw: VoidScarabRigScript in _swarm_nodes:
				sw.visible = false
		if _control_mode == ControlMode.INSPECT_25D:
			_target_zoom = maxf(_target_zoom, 2.05)
		elif _control_mode == ControlMode.PILOT_WASD or _control_mode == ControlMode.STALK_MOUSE_AI:
			_target_zoom = minf(_target_zoom, 1.35)
	if _hud != null and _sequence_director != null:
		_hud.call("set_sequence_ui", _sequence_director.auto_reel, _sequence_director.active_sequence, _control_mode == ControlMode.COSMOS_SEQUENCE)


func select_sequence(seq_id: int, auto_reel_flag: bool = false) -> void:
	if _backdrop_mode != BackdropMode.COSMOS_LIVE:
		_set_backdrop_mode(BackdropMode.COSMOS_LIVE)
	_control_mode = ControlMode.COSMOS_SEQUENCE
	if _sequence_director != null and _scarab_primary != null:
		if _scarab_primary.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER:
			_scarab_primary.respawn()
		_sequence_director.set_auto_reel(auto_reel_flag)
		_sequence_director.start_sequence(seq_id, _scarab_primary.position, _host_controller)
		_swarm_enabled = _sequence_director.is_swarm_needed()
		for sw: VoidScarabRigScript in _swarm_nodes:
			sw.visible = _swarm_enabled
		_target_zoom = _sequence_director.get_recommended_zoom()
		if _hud != null:
			_hud.call("set_sequence_ui", _sequence_director.auto_reel, _sequence_director.active_sequence, true)


func _on_auto_reel_toggled() -> void:
	if _sequence_director == null:
		return
	var next_reel: bool = not _sequence_director.auto_reel
	_sequence_director.set_auto_reel(next_reel)
	if _control_mode != ControlMode.COSMOS_SEQUENCE:
		set_control_mode(ControlMode.COSMOS_SEQUENCE)
	if _hud != null:
		_hud.call("set_sequence_ui", _sequence_director.auto_reel, _sequence_director.active_sequence, _control_mode == ControlMode.COSMOS_SEQUENCE)


func _cycle_cosmos_biome() -> void:
	if _backdrop_mode != BackdropMode.COSMOS_LIVE:
		_set_backdrop_mode(BackdropMode.COSMOS_LIVE)
	if _host_controller == null:
		return
	_biome_cycle_idx = (_biome_cycle_idx + 1) % BIOME_ORDER.size()
	_host_controller.change_region(BIOME_ORDER[_biome_cycle_idx], 1.2)


func _on_backdrop_cycled() -> void:
	_set_backdrop_mode((_backdrop_mode + 1) % 3)


func _set_backdrop_mode(mode: int) -> void:
	_backdrop_mode = mode % 3
	if _backdrop_mode == BackdropMode.COSMOS_LIVE:
		_ensure_cosmos_built()
	_sync_backdrop_visibility()


func _sync_backdrop_visibility() -> void:
	var cosmos_on: bool = (_backdrop_mode == BackdropMode.COSMOS_LIVE)
	if _backdrop != null:
		_backdrop.visible = not cosmos_on
	if _cosmos_env != null:
		_cosmos_env.visible = cosmos_on
	if _cosmos_root != null:
		_cosmos_root.visible = cosmos_on
		for layer_name: StringName in [&"ParallaxNebulaDeep", &"CanvasLayerStarfield", &"CanvasLayerForegroundAtmo"]:
			var cl: CanvasLayer = _cosmos_root.get_node_or_null(NodePath(layer_name)) as CanvasLayer
			if cl != null:
				cl.visible = cosmos_on


func _on_auto_light_toggled() -> void:
	_auto_light_orbit = not _auto_light_orbit
	if _hud != null:
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)


func _on_bright_light_toggled() -> void:
	_bright_light_mode = not _bright_light_mode
	if _scarab_style != null:
		_scarab_style.studio_exposure = 1.65 if _bright_light_mode else 1.12
		_scarab_style.ambient_fill_strength = 0.72 if _bright_light_mode else 0.36
	_apply_calibration_and_style()
	if _hud != null:
		_hud.call("sync_sliders_from_config")
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)


func _on_lock_tilt_toggled() -> void:
	_lock_tilt = not _lock_tilt
	if _hud != null:
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)


func _on_reset_tilt() -> void:
	_manual_tilt = Vector2.ZERO
	_lock_tilt = false
	if _hud != null:
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)


func _on_show_pivots_toggled(enabled: bool) -> void:
	if _scarab_primary != null:
		_scarab_primary.set_show_pivots(enabled)


func _on_flat_compare_toggled(enabled: bool) -> void:
	_flat_ab_active = enabled
	if _scarab_primary != null:
		_scarab_primary.set_flat_baseline_mode(enabled)
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.set_flat_baseline_mode(enabled)
	if _hud != null:
		_hud.call("set_toggle_labels", _auto_light_orbit, _lock_tilt, _flat_ab_active, _bright_light_mode)


func _on_variant_cycled() -> void:
	_variant_idx += 1
	if _scarab_style != null and _variant_idx >= _scarab_style.variant_tints.size():
		_variant_idx = -1
	if _scarab_primary != null:
		_scarab_primary.set_variant_index(_variant_idx)
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.set_variant_index(_variant_idx)


func _on_debug_mode_selected(mode: int) -> void:
	_debug_mode = clampi(mode, 0, 7)
	if _scarab_primary != null:
		_scarab_primary.set_debug_view_mode(_debug_mode)
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.set_debug_view_mode(_debug_mode)


func _apply_calibration_and_style() -> void:
	if _scarab_primary != null:
		_scarab_primary.apply_rig_calibration()
		_scarab_primary.apply_style_profile(_scarab_style)
	for sw: VoidScarabRigScript in _swarm_nodes:
		sw.apply_rig_calibration()
		sw.apply_style_profile(_scarab_style)


func _save_scarab_configs() -> void:
	var err1: Error = ResourceSaver.save(_scarab_cfg, SCARAB_CONFIG_PATH) if _scarab_cfg != null else ERR_INVALID_DATA
	var err2: Error = ResourceSaver.save(_scarab_style, SCARAB_STYLE_PATH) if _scarab_style != null else ERR_INVALID_DATA
	_save_flash_msg = "Guardado OK (.tres)" if (err1 == OK and err2 == OK) else ("Error guardando: %d/%d" % [err1, err2])
	_save_flash_timer = 3.0


func _cycle_teleport_vantage() -> void:
	if _backdrop_mode != BackdropMode.COSMOS_LIVE:
		_set_backdrop_mode(BackdropMode.COSMOS_LIVE)
	if _host_controller == null or _scarab_primary == null:
		return
	var active: Dictionary = _host_controller.get_active_solar_systems()
	var best_sys: CosmosSolarSystem2D = null
	var best_dist: float = INF
	for sys_v: Variant in active.values():
		var sys: CosmosSolarSystem2D = sys_v as CosmosSolarSystem2D
		if sys != null and is_instance_valid(sys) and sys.visible and sys.star_body != null:
			var d: float = _scarab_primary.global_position.distance_to(sys.global_position)
			if d < best_dist:
				best_dist = d
				best_sys = sys
	if best_sys == null:
		return
	var star_world: Vector2 = best_sys.star_body.global_position
	var mode: int = _teleport_mode % 3
	_teleport_mode += 1
	if mode == 0 or best_sys.planets.is_empty():
		_scarab_primary.global_position = star_world + Vector2(680.0, 220.0)
	else:
		var planet: CosmosOrbitalBody2D = best_sys.planets[0]
		var p_rad: float = float(planet.get_meta(&"visual_radius", 130.0))
		var p_dir: Vector2 = planet.position.normalized() if planet.position.length_squared() > 1.0 else Vector2.RIGHT
		_scarab_primary.global_position = star_world + planet.position + (p_dir if mode == 1 else -p_dir) * (p_rad + 150.0)
	_scarab_vel = Vector2.ZERO


func _update_status(delta: float) -> void:
	if _save_flash_timer > 0.0:
		_save_flash_timer = maxf(_save_flash_timer - delta, 0.0)
	if _hud == null:
		return
	var st_idx: int = _scarab_primary.get_anim_state() if _scarab_primary != null else 0
	var st_lbl: String = VoidScarabRigScript.STATE_LABELS[clampi(st_idx, 0, VoidScarabRigScript.STATE_LABELS.size() - 1)]
	var tilt_v: Vector2 = _scarab_primary.get_tilt_25d() if _scarab_primary != null else Vector2.ZERO
	var var_names: Array[String] = ["Abyssal", "Crimson", "Cryo", "Solar"]
	var var_lbl: String = "Base" if _variant_idx < 0 else (var_names[_variant_idx] if _variant_idx < var_names.size() else ("Var #%d" % (_variant_idx + 1)))
	var ab_note: String = " [FLAT BASELINE A/B]" if _flat_ab_active else ""
	var save_note: String = ("  |  %s" % _save_flash_msg) if _save_flash_timer > 0.0 else ""

	var seq_note: String = (" | %s" % _sequence_director.get_status_label()) if (_control_mode == ControlMode.COSMOS_SEQUENCE and _sequence_director != null) else ""
	var biome_lbl: String = String(_host_controller.get_current_region_id()) if (_backdrop_mode == BackdropMode.COSMOS_LIVE and _host_controller != null) else "studio"

	var txt: String = (
		"ENEMY COSMIC WORKBENCH — Void Scarab%s%s\n" % [ab_note, save_note]
		+ "Mode: %s%s | State: %s | Cosmos: %s (%s) | Var: %s | Zoom: %.2fx\n" % [
			CONTROL_LABELS[_control_mode], seq_note, st_lbl, BACKDROP_LABELS[_backdrop_mode], biome_lbl, var_lbl, _target_zoom
		]
		+ "Spd: %.0f px/s | Light: %.0f° Z=%.2f | [G]=AutoReel | [K]=Biome | [T]=SolarVantage | [C]=Inspector | [Tab]=A/B" % [
			_scarab_vel.length(), _light_angle_deg, _light_z
		]
	)
	_hud.call("set_status_text", txt)


func get_workbench_center() -> Vector2:
	return _scarab_primary.position if _scarab_primary != null else Vector2.ZERO


func get_active_light_dir() -> Vector2:
	var r: float = deg_to_rad(_light_angle_deg)
	return Vector2(cos(r), sin(r))


func get_primary_scarab() -> VoidScarabRigScript:
	return _scarab_primary


func get_backdrop_mode() -> int:
	return _backdrop_mode


func get_control_mode() -> int:
	return _control_mode


func get_sequence_director() -> SequenceDirectorScript:
	return _sequence_director


func get_cosmos_environment() -> CosmosCombatEnvironment:
	return _cosmos_env
