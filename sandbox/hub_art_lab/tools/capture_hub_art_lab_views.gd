extends Node

## Herramienta de captura en ventana GPU real (Vulkan / Mobile + AgX + Bloom) para auditar Hub Art Lab 3D.
## Uso:
##   Godot --path . --windowed --resolution 1280x720 res://sandbox/hub_art_lab/tools/capture_hub_art_lab_views.tscn [-- --out=<abs_dir>]

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/hub_art_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://sandbox/hub_art_lab/components/hub_lab_station_node.gd")

var _out_dir: String = ""
var _lab: LabScript = null


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_lab = LabScene.instantiate() as LabScript
	_lab.name = "HubArtLab"
	add_child(_lab)

	await _wait_frames(14)
	await _capture_sequence()


func _parse_args() -> void:
	for raw_arg: String in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--out="):
			_out_dir = raw_arg.trim_prefix("--out=").strip_edges()
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("res://sandbox/hub_art_lab/captures")
	elif _out_dir.begins_with("res://"):
		_out_dir = ProjectSettings.globalize_path(_out_dir)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _capture_file(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var full_path: String = _out_dir.path_join(filename)
	if img == null or img.is_empty():
		printerr("CAPTURE_EMPTY=", full_path)
		return
	var err: Error = img.save_png(full_path)
	if err != OK:
		printerr("CAPTURE_ERR=", full_path, " code=", err)
		return
	print("CAPTURED=", full_path)


func _capture_sequence() -> void:
	# 1. FREE_ROAM limpio (HUD oculto)
	if _lab.hud != null:
		_lab.hud.visible = false
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	await _wait_frames(4)
	await _capture_file("01_free_roam_clean.png")

	# 2. FREE_ROAM con HUD de calibración visible
	if _lab.hud != null:
		_lab.hud.visible = true
	await _wait_frames(3)
	await _capture_file("02_free_roam_hud.png")

	# 3. Foco en Cápsula Central (auto-alineación frontal 's' + zoom suave)
	if _lab.hud != null:
		_lab.hud.visible = false
	_lab.trigger_capsule_focus()
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	await _wait_frames(6)
	await _capture_file("03_capsule_focus.png")

	# 4. Antesala: Consolas (Izq ONLINE vs Der CALIBRATING) + Anillo Norte + Ventanal Cosmos
	_lab.exit_capsule_focus()
	_lab.player.global_position = Vector3(0.0, 0.05, -2.5)
	_lab.player.face_front_idle(true)
	if _lab.left_station != null:
		_lab.left_station.set_station_state(StationNodeScript.StationState.ONLINE)
	if _lab.right_station != null:
		_lab.right_station.set_station_state(StationNodeScript.StationState.CALIBRATING)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	await _wait_frames(6)
	await _capture_file("04_antesala_stations.png")

	# 5. Ignición Norte (SERAPH_BLOOM 3D wings + Anillo Norte cargado + Ventanal Cosmos)
	_lab.trigger_ignition_preview()
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	await _wait_frames(24)
	await _capture_file("05_ignition_launch.png")

	# 6. Vista panorámica arquitectónica de la cubierta en "U"
	_lab._finish_ignition_preview()
	_lab.exit_capsule_focus()
	_lab.player.global_position = _lab.config.player_spawn_pos
	_lab.player.face_front_idle(true)
	_lab.set_process(false)
	_lab.camera.global_position = Vector3(0.0, 15.5, 19.5)
	_lab.camera.rotation_degrees = Vector3(-37.0, 0.0, 0.0)
	_lab.camera.fov = 46.0
	await _wait_frames(4)
	await _capture_file("06_overview_u_deck.png")

	# 7. Toma media-baja angulada mostrando ambos muros laterales, costillas, bahías y 4 consolas
	_lab.camera.global_position = Vector3(0.0, 4.4, 10.6)
	_lab.camera.look_at(Vector3(0.0, 1.75, -3.5), Vector3.UP)
	_lab.camera.fov = 56.0
	await _wait_frames(4)
	await _capture_file("07_walls_and_wings.png")

	get_tree().quit(0)
