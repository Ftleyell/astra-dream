class_name HubCameraController3D
extends RefCounted

## HubCameraController3D.gd
## Controlador cinemático y configuración de cámara para el Hangar 3D (HubWorld).
## - Inicialización de parámetros de cámara (FOV, posición y target de mirada).
## - Coordinación de paralaje espacial en base a la posición de la cámara.

static func setup_camera(
	player_controller: CharacterBody3D,
	camera: Camera3D,
	hub: Node3D
) -> Camera3D:
	var resolved_cam: Camera3D = camera
	if is_instance_valid(player_controller) and "camera" in player_controller and is_instance_valid(player_controller.camera):
		resolved_cam = player_controller.camera
	elif not resolved_cam and is_instance_valid(hub):
		resolved_cam = hub.get_node_or_null("Camera3D") as Camera3D
		if resolved_cam:
			resolved_cam.fov = 85.0
			resolved_cam.position = Vector3(0.0, 3.2, 5.0)
			resolved_cam.look_at(Vector3.ZERO, Vector3.UP)
	return resolved_cam

static func update_parallax(
	camera: Camera3D,
	hangar_builder: HubHangarBuilder3D
) -> void:
	if is_instance_valid(camera) and hangar_builder and hangar_builder.has_method("update_parallax"):
		hangar_builder.update_parallax(camera.global_position)
