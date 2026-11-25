class_name HubLabCameraRig
extends RefCounted

## Máquina de estados de cámara 2.5D Diorama + 6 Presets de Foco para Estación Astral v2.
## En FREE_ROAM mantiene exactamente FOV 38°, pitch -42° y yaw 0° sin giros orbitales.

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")

enum Mode {
	FREE_ROAM = 0,
	CAPSULE_PILOT_FOCUS = 1,
	STATION_FOCUS = 2,
	IGNITION_LAUNCH = 3,
	SKINS_MIRROR_FOCUS = 4,
	GACHA_SUMMON_CINEMATIC = 5,
	TROPHY_FOCUS = 6,
}

var current_mode: Mode = Mode.FREE_ROAM
var focus_world_pos: Vector3 = Vector3.ZERO
var shake_offset: Vector3 = Vector3.ZERO
var ignition_push_in_t: float = 0.0

var scroll_zoom_t: float = 0.0
var _current_zoom_t: float = 0.0
var fp_yaw_deg: float = 0.0
var fp_pitch_offset_deg: float = 0.0


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
	if mode != Mode.IGNITION_LAUNCH:
		ignition_push_in_t = 0.0
	if mode != Mode.GACHA_SUMMON_CINEMATIC:
		shake_offset = Vector3.ZERO
	if mode != Mode.FREE_ROAM:
		scroll_zoom_t = 0.0
		_current_zoom_t = 0.0
		fp_yaw_deg = 0.0
		fp_pitch_offset_deg = 0.0


func adjust_scroll_zoom(delta_t: float) -> void:
	scroll_zoom_t = clampf(scroll_zoom_t + delta_t, 0.0, 1.0)
	if scroll_zoom_t < 0.65:
		fp_yaw_deg = 0.0
		fp_pitch_offset_deg = 0.0


func reset_scroll_zoom() -> void:
	scroll_zoom_t = 0.0
	_current_zoom_t = 0.0
	fp_yaw_deg = 0.0
	fp_pitch_offset_deg = 0.0


func set_scroll_zoom_immediate(z_t: float) -> void:
	scroll_zoom_t = clampf(z_t, 0.0, 1.0)
	_current_zoom_t = scroll_zoom_t


func get_effective_zoom_t() -> float:
	return _current_zoom_t


func is_first_person() -> bool:
	return current_mode == Mode.FREE_ROAM and _current_zoom_t >= 0.80


func apply_first_person_look(delta_yaw: float, delta_pitch: float) -> void:
	fp_yaw_deg = clampf(fp_yaw_deg + delta_yaw, -75.0, 75.0)
	fp_pitch_offset_deg = clampf(fp_pitch_offset_deg + delta_pitch, -20.0, 22.0)


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

	_last_player_pos_x = player_pos.x
	var target_pos: Vector3 = _compute_target_pos(player_pos, config) + shake_offset
	var target_pitch: float = _compute_target_pitch(config)
	var target_yaw: float = _compute_target_yaw()
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
		lerpf(camera.rotation_degrees.y, target_yaw, weight),
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
		Mode.IGNITION_LAUNCH:
			var eff_offset: Vector3 = config.ignition_launch_offset.lerp(config.ignition_push_in_offset, ignition_push_in_t)
			return focus_world_pos + eff_offset
		_:
			var west_t: float = _compute_west_blend()
			var clamped_base := Vector3(
				clampf(player_pos.x + config.free_roam_offset.x, config.camera_clamp_min.x, config.camera_clamp_max.x),
				clampf(player_pos.y + config.free_roam_offset.y, config.camera_clamp_min.y, config.camera_clamp_max.y),
				clampf(player_pos.z + config.free_roam_offset.z, config.camera_clamp_min.z, config.camera_clamp_max.z)
			)
			# En Galería Oeste (-12..-19), la cámara se posa en el borde interior abierto (-9.6, 3.05, 3.25) mirando al portal sin chocar jambas
			var west_cam_pos := Vector3(-9.6, 3.05, clampf(player_pos.z + 2.45, 2.2, 3.6))
			var eff_base: Vector3 = clamped_base.lerp(west_cam_pos, west_t)
			if _current_zoom_t <= 0.001:
				return eff_base
			var closeup_pos: Vector3 = player_pos + Vector3(0.0, 1.88, 2.75)
			var fp_pos: Vector3 = player_pos + Vector3(0.0, 1.62, -0.18)
			if _current_zoom_t <= 0.65:
				var t3: float = clampf(_current_zoom_t / 0.65, 0.0, 1.0)
				t3 = t3 * t3 * (3.0 - 2.0 * t3)
				return eff_base.lerp(closeup_pos, t3)
			var t1: float = clampf((_current_zoom_t - 0.65) / 0.35, 0.0, 1.0)
			t1 = t1 * t1 * (3.0 - 2.0 * t1)
			return closeup_pos.lerp(fp_pos, t1)


func _compute_target_yaw() -> float:
	if current_mode != Mode.FREE_ROAM:
		return 0.0
	if _current_zoom_t > 0.65:
		return fp_yaw_deg
	return lerpf(0.0, 52.0, _compute_west_blend())


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
		Mode.IGNITION_LAUNCH:
			return lerpf(config.ignition_launch_pitch_deg, config.ignition_push_in_pitch_deg, ignition_push_in_t)
		_:
			var west_pitch: float = lerpf(config.free_roam_pitch_deg, -16.0, _compute_west_blend())
			if _current_zoom_t <= 0.001:
				return west_pitch
			if _current_zoom_t <= 0.65:
				var t3: float = clampf(_current_zoom_t / 0.65, 0.0, 1.0)
				return lerpf(west_pitch, -10.5, t3)
			var t1: float = clampf((_current_zoom_t - 0.65) / 0.35, 0.0, 1.0)
			return lerpf(-10.5, -2.0 + fp_pitch_offset_deg, t1)


var _last_player_pos_x: float = 0.0


func _compute_west_blend() -> float:
	var t: float = clampf((-_last_player_pos_x - 8.8) / 3.2, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
		Mode.IGNITION_LAUNCH:
			return lerpf(config.ignition_launch_fov, config.ignition_push_in_fov, ignition_push_in_t)
		_:
			var west_fov: float = lerpf(config.free_roam_fov, 46.0, _compute_west_blend())
			if _current_zoom_t <= 0.001:
				return west_fov
			if _current_zoom_t <= 0.65:
				var t3: float = clampf(_current_zoom_t / 0.65, 0.0, 1.0)
				return lerpf(west_fov, 41.0, t3)
			var t1: float = clampf((_current_zoom_t - 0.65) / 0.35, 0.0, 1.0)
			return lerpf(41.0, 56.0, t1)
