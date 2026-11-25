class_name HubLabCameraRig
extends RefCounted

## Máquina de estados de cámara Telefoto 2.5D 1:1 para Estación Astral Flotante.
## Mantiene FOV 26°, pitch -46° y yaw bloqueado en 0.0° sin giros bruscos en ninguna zona (incluidas Reliquias Oeste).

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")

enum Mode {
	FREE_ROAM = 0,
	CAPSULE_PILOT_FOCUS = 1,
	STATION_FOCUS = 2,
	IGNITION_LAUNCH = 3,
	SKINS_MIRROR_FOCUS = 4,
	GACHA_SUMMON_CINEMATIC = 5,
	TROPHY_FOCUS = 6,
	SEAMLESS_DEPARTURE = 7,
}

var current_mode: Mode = Mode.FREE_ROAM
var focus_world_pos: Vector3 = Vector3.ZERO
var shake_offset: Vector3 = Vector3.ZERO
var ignition_push_in_t: float = 0.0
var scroll_zoom_t: float = 0.0
var _current_zoom_t: float = 0.0


func configure(camera: Camera3D, config: ConfigScript) -> void:
	if camera == null or config == null:
		return
	camera.current = true
	camera.top_level = true
	camera.fov = config.free_roam_fov
	camera.rotation_degrees = Vector3(config.free_roam_pitch_deg, 0.0, 0.0)


func set_mode(mode: Mode, p_focus_world_pos: Vector3 = Vector3.ZERO) -> void:
	current_mode = mode
	focus_world_pos = p_focus_world_pos
	if mode != Mode.IGNITION_LAUNCH and mode != Mode.SEAMLESS_DEPARTURE:
		ignition_push_in_t = 0.0
	if mode != Mode.GACHA_SUMMON_CINEMATIC and mode != Mode.SEAMLESS_DEPARTURE:
		shake_offset = Vector3.ZERO
	if mode != Mode.FREE_ROAM:
		scroll_zoom_t = 0.0
		_current_zoom_t = 0.0


func adjust_scroll_zoom(delta_t: float) -> void:
	# Zoom telefoto suave acotado sin primera persona ni cambio de yaw
	scroll_zoom_t = clampf(scroll_zoom_t + delta_t, 0.0, 0.65)


func reset_scroll_zoom() -> void:
	scroll_zoom_t = 0.0
	_current_zoom_t = 0.0


func set_scroll_zoom_immediate(z_t: float) -> void:
	scroll_zoom_t = clampf(z_t, 0.0, 0.65)
	_current_zoom_t = scroll_zoom_t


func get_effective_zoom_t() -> float:
	return _current_zoom_t


func is_first_person() -> bool:
	return false


func apply_first_person_look(_delta_yaw: float, _delta_pitch: float) -> void:
	pass


func get_mode() -> Mode:
	return current_mode


func set_ignition_push_in(t: float) -> void:
	ignition_push_in_t = clampf(t, 0.0, 1.0)


func set_shake_offset(offset: Vector3) -> void:
	shake_offset = offset


func update(
	camera: Camera3D,
	player_pos: Vector3,
	delta: float,
	config: ConfigScript,
	snap: bool = false
) -> void:
	if camera == null or config == null:
		return

	if current_mode == Mode.FREE_ROAM:
		if snap or delta <= 0.0:
			_current_zoom_t = scroll_zoom_t
		else:
			_current_zoom_t = lerpf(_current_zoom_t, scroll_zoom_t, clampf(10.0 * delta, 0.0, 1.0))

	var target_pos: Vector3 = _compute_target_pos(player_pos, config) + shake_offset
	var target_pitch: float = _compute_target_pitch(config)
	var target_yaw: float = 0.0
	var target_fov: float = _compute_target_fov(config)

	if snap or delta <= 0.0:
		if camera.is_inside_tree():
			camera.global_position = target_pos
		else:
			camera.position = target_pos
		camera.rotation_degrees = Vector3(target_pitch, target_yaw, 0.0)
		camera.fov = target_fov
		return

	var weight: float = clampf(config.camera_transition_smooth * delta, 0.0, 1.0)
	var cur_pos: Vector3 = camera.global_position if camera.is_inside_tree() else camera.position
	var next_pos: Vector3 = cur_pos.lerp(target_pos, weight)
	if camera.is_inside_tree():
		camera.global_position = next_pos
	else:
		camera.position = next_pos
	camera.rotation_degrees = Vector3(
		lerpf(camera.rotation_degrees.x, target_pitch, weight),
		0.0,
		0.0
	)
	camera.fov = lerpf(camera.fov, target_fov, weight)


func _compute_target_pos(player_pos: Vector3, config: ConfigScript) -> Vector3:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return focus_world_pos + config.capsule_focus_offset
		Mode.SKINS_MIRROR_FOCUS:
			return focus_world_pos + config.skins_mirror_focus_offset
		Mode.STATION_FOCUS:
			return focus_world_pos + config.station_focus_offset
		Mode.GACHA_SUMMON_CINEMATIC:
			return focus_world_pos + config.gacha_cinematic_offset
		Mode.TROPHY_FOCUS:
			return focus_world_pos + config.trophy_focus_offset
		Mode.SEAMLESS_DEPARTURE, Mode.IGNITION_LAUNCH:
			return player_pos + config.departure_focus_offset
		_:
			var clamped_base := Vector3(
				clampf(player_pos.x + config.free_roam_offset.x, config.camera_clamp_min.x, config.camera_clamp_max.x),
				clampf(player_pos.y + config.free_roam_offset.y, config.camera_clamp_min.y, config.camera_clamp_max.y),
				clampf(player_pos.z + config.free_roam_offset.z, config.camera_clamp_min.z, config.camera_clamp_max.z)
			)
			if _current_zoom_t <= 0.001:
				return clamped_base
			var closeup_pos: Vector3 = player_pos + Vector3(0.0, 5.2, 5.0)
			var t3: float = clampf(_current_zoom_t / 0.65, 0.0, 1.0)
			t3 = t3 * t3 * (3.0 - 2.0 * t3)
			return clamped_base.lerp(closeup_pos, t3)


func _compute_target_pitch(config: ConfigScript) -> float:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return config.capsule_focus_pitch_deg
		Mode.SKINS_MIRROR_FOCUS:
			return config.skins_mirror_focus_pitch_deg
		Mode.STATION_FOCUS:
			return config.station_focus_pitch_deg
		Mode.GACHA_SUMMON_CINEMATIC:
			return config.gacha_cinematic_pitch_deg
		Mode.TROPHY_FOCUS:
			return config.trophy_focus_pitch_deg
		Mode.SEAMLESS_DEPARTURE, Mode.IGNITION_LAUNCH:
			return config.departure_focus_pitch_deg
		_:
			if _current_zoom_t <= 0.001:
				return config.free_roam_pitch_deg
			var t3: float = clampf(_current_zoom_t / 0.65, 0.0, 1.0)
			return lerpf(config.free_roam_pitch_deg, -34.0, t3)


func _compute_target_fov(config: ConfigScript) -> float:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return config.capsule_focus_fov
		Mode.SKINS_MIRROR_FOCUS:
			return config.skins_mirror_focus_fov
		Mode.STATION_FOCUS:
			return config.station_focus_fov
		Mode.GACHA_SUMMON_CINEMATIC:
			return config.gacha_cinematic_fov
		Mode.TROPHY_FOCUS:
			return config.trophy_focus_fov
		Mode.SEAMLESS_DEPARTURE, Mode.IGNITION_LAUNCH:
			return config.departure_focus_fov
		_:
			return config.free_roam_fov
