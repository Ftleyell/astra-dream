class_name HubLabCameraRig
extends RefCounted

## Máquina de estados de cámara 2.5D Diorama + Foco Suave para Hub Art Lab.
## En FREE_ROAM mantiene exactamente FOV 38°, pitch -42° y yaw 0° sin giros orbitales.

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")

enum Mode {
	FREE_ROAM = 0,
	CAPSULE_PILOT_FOCUS = 1,
	STATION_FOCUS = 2,
	IGNITION_LAUNCH = 3,
}

var current_mode: Mode = Mode.FREE_ROAM
var focus_world_pos: Vector3 = Vector3.ZERO


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


func get_mode() -> Mode:
	return current_mode


func update(
	camera: Camera3D,
	player_pos: Vector3,
	delta: float,
	config: ConfigScript,
	snap: bool = false
) -> void:
	if camera == null or config == null:
		return

	var target_pos: Vector3 = _compute_target_pos(player_pos, config)
	var target_pitch: float = _compute_target_pitch(config)
	var target_fov: float = _compute_target_fov(config)

	if snap or delta <= 0.0:
		if camera.is_inside_tree():
			camera.global_position = target_pos
		else:
			camera.position = target_pos
		camera.rotation_degrees = Vector3(target_pitch, 0.0, 0.0)
		camera.fov = target_fov
		return

	var weight: float = clampf(config.camera_transition_smooth * delta, 0.0, 1.0)
	var cur_pos: Vector3 = camera.global_position if camera.is_inside_tree() else camera.position
	var next_pos: Vector3 = cur_pos.lerp(target_pos, weight)
	if camera.is_inside_tree():
		camera.global_position = next_pos
	else:
		camera.position = next_pos
	camera.rotation_degrees = Vector3(lerpf(camera.rotation_degrees.x, target_pitch, weight), 0.0, 0.0)
	camera.fov = lerpf(camera.fov, target_fov, weight)


func _compute_target_pos(player_pos: Vector3, config: ConfigScript) -> Vector3:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return focus_world_pos + config.capsule_focus_offset
		Mode.STATION_FOCUS:
			return focus_world_pos + config.station_focus_offset
		Mode.IGNITION_LAUNCH:
			return focus_world_pos + config.ignition_launch_offset
		_:
			var raw: Vector3 = player_pos + config.free_roam_offset
			return Vector3(
				clampf(raw.x, config.camera_clamp_min.x, config.camera_clamp_max.x),
				clampf(raw.y, config.camera_clamp_min.y, config.camera_clamp_max.y),
				clampf(raw.z, config.camera_clamp_min.z, config.camera_clamp_max.z)
			)


func _compute_target_pitch(config: ConfigScript) -> float:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return config.capsule_focus_pitch_deg
		Mode.STATION_FOCUS:
			return config.station_focus_pitch_deg
		Mode.IGNITION_LAUNCH:
			return config.ignition_launch_pitch_deg
		_:
			return config.free_roam_pitch_deg


func _compute_target_fov(config: ConfigScript) -> float:
	match current_mode:
		Mode.CAPSULE_PILOT_FOCUS:
			return config.capsule_focus_fov
		Mode.STATION_FOCUS:
			return config.station_focus_fov
		Mode.IGNITION_LAUNCH:
			return config.ignition_launch_fov
		_:
			return config.free_roam_fov
