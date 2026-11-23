class_name HubCameraController3D
extends RefCounted

## HubCameraController3D.gd
## Controlador de cámara fija 2.5D Diorama para el Hangar 3D (HubWorld).
## - Fija FOV, pitch y offset desde HubDioramaConfig sin giros orbitales ni zoom dinámico.
## - Coordina el paralaje espacial en base a la posición de la cámara.

const HubDioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: HubDioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")


static func resolve_config(config: HubDioramaConfigScript) -> HubDioramaConfigScript:
	return config if config != null else DEFAULT_DIORAMA_CONFIG


static func compute_clamped_camera_pos(target_pos: Vector3, config: HubDioramaConfigScript = null) -> Vector3:
	var cfg: HubDioramaConfigScript = resolve_config(config)
	var raw: Vector3 = target_pos + cfg.camera_offset
	return Vector3(
		clampf(raw.x, cfg.camera_clamp_min.x, cfg.camera_clamp_max.x),
		clampf(raw.y, cfg.camera_clamp_min.y, cfg.camera_clamp_max.y),
		clampf(raw.z, cfg.camera_clamp_min.z, cfg.camera_clamp_max.z)
	)


static func configure_diorama_camera(
	camera: Camera3D,
	target_pos: Vector3,
	config: HubDioramaConfigScript = null
) -> void:
	if not is_instance_valid(camera):
		return
	var cfg: HubDioramaConfigScript = resolve_config(config)
	camera.fov = cfg.camera_fov
	camera.current = true
	camera.top_level = true
	camera.rotation_degrees = Vector3(cfg.camera_pitch_deg, 0.0, 0.0)
	var clamped_pos: Vector3 = compute_clamped_camera_pos(target_pos, cfg)
	if camera.is_inside_tree():
		camera.global_position = clamped_pos
	else:
		camera.position = clamped_pos


static func update_diorama_camera(
	camera: Camera3D,
	target_pos: Vector3,
	delta: float,
	config: HubDioramaConfigScript = null
) -> void:
	if not is_instance_valid(camera):
		return
	var cfg: HubDioramaConfigScript = resolve_config(config)
	camera.fov = cfg.camera_fov
	camera.rotation_degrees = Vector3(cfg.camera_pitch_deg, 0.0, 0.0)
	var clamped_target: Vector3 = compute_clamped_camera_pos(target_pos, cfg)
	if delta <= 0.0 or not camera.is_inside_tree():
		if camera.is_inside_tree():
			camera.global_position = clamped_target
		else:
			camera.position = clamped_target
		return
	var weight: float = clampf(cfg.camera_follow_smooth * delta, 0.0, 1.0)
	var next_pos: Vector3 = camera.global_position.lerp(clamped_target, weight)
	camera.global_position = Vector3(
		clampf(next_pos.x, cfg.camera_clamp_min.x, cfg.camera_clamp_max.x),
		clampf(next_pos.y, cfg.camera_clamp_min.y, cfg.camera_clamp_max.y),
		clampf(next_pos.z, cfg.camera_clamp_min.z, cfg.camera_clamp_max.z)
	)


static func setup_camera(
	player_controller: CharacterBody3D,
	camera: Camera3D,
	hub: Node3D,
	config: HubDioramaConfigScript = null
) -> Camera3D:
	var resolved_cam: Camera3D = camera
	if is_instance_valid(player_controller) and "camera" in player_controller and is_instance_valid(player_controller.camera):
		resolved_cam = player_controller.camera
	else:
		if not resolved_cam and is_instance_valid(hub):
			resolved_cam = hub.get_node_or_null("Camera3D") as Camera3D
		if is_instance_valid(resolved_cam):
			configure_diorama_camera(resolved_cam, Vector3.ZERO, config)
	return resolved_cam


static func update_parallax(
	camera: Camera3D,
	hangar_builder: HubHangarBuilder3D
) -> void:
	if is_instance_valid(camera) and hangar_builder and hangar_builder.has_method("update_parallax"):
		hangar_builder.update_parallax(camera.global_position)
