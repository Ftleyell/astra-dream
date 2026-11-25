extends Node

## Herramienta de captura en ventana GPU real (Vulkan / Mobile + AgX + Bloom) para auditar Hub Art Lab 3D.
## Uso:
##   Godot --path . --windowed --resolution 1280x720 res://sandbox/hub_art_lab/tools/capture_hub_art_lab_views.tscn [-- --out=<abs_dir>]

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/hub_art_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")

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
	_lab.apply_progression_preset(&"all_online")

	# 1. FREE_ROAM puente principal (iluminación nueva, normal maps, cero stumps, oeste limpio)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(8)
	await _capture_file("01_free_roam_bridge.png")

	# 2. Cápsula Central Hero + HUD oculto al abrir panel
	_lab.trigger_capsule_focus(true)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(8)
	await _capture_file("02_capsule_hero.png")
	_lab.exit_capsule_focus()

	# 3. Espejo de Skins temático (piloto en suelo frente al arco vestidor)
	_lab.open_station_by_id(&"skins_mirror")
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(10)
	await _capture_file("03_skins_mirror.png")
	_lab.modal_coordinator.close_active_modal()

	# 4. Nexo de Talentos (piloto encuadrada limpia + HUD estación oculto)
	_lab.open_station_by_id(&"talents_nexus")
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(10)
	await _capture_file("09_talents_modal_framed.png")
	_lab.modal_coordinator.close_active_modal()

	# 5. Bahía de Ignición Norte rediseñada (abierta al piso) + despegue dinámico Fase B/C
	_lab.player.global_position = _lab.config.ignition_ring_pos + Vector3(0.0, 0.0, 2.5)
	_lab.player.face_north_idle(true)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(6)
	await _capture_file("04a_ignition_pad_idle.png")

	_lab.trigger_ignition_preview()
	for _f: int in range(44):
		await get_tree().process_frame
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(4)
	await _capture_file("04b_ignition_takeoff.png")
	_lab._finish_ignition_preview()

	# 6. Zoom scroll hasta Primera Persona mirando el Ventanal Cosmos
	_lab.player.global_position = Vector3(0.0, 0.05, -2.5)
	_lab.player.face_north_idle(true)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.set_scroll_zoom_immediate(1.0)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.set_visibility_fade(0.0)
	await _wait_frames(6)
	await _capture_file("05_first_person_cosmos.png")
	_lab.camera_rig.reset_scroll_zoom()
	_lab.player.set_visibility_fade(1.0)

	# 7. Superestructura Sur y cielo espacial 3D (cero vacío negro)
	_lab.set_process(false)
	if _lab.hud != null:
		_lab.hud.set_clean_hud_visible(false)
	_lab.camera.global_position = Vector3(0.0, 4.8, 4.5)
	_lab.camera.look_at(Vector3(0.0, -1.6, 17.5), Vector3.UP)
	_lab.camera.fov = 50.0
	await _wait_frames(6)
	await _capture_file("06_south_superstructure.png")

	# 8. Las 4 consolas temáticas de la Antesala
	_lab.player.global_position = _lab.config.player_spawn_pos
	_lab.player.face_front_idle(true)
	_lab.camera.global_position = Vector3(0.0, 9.2, 6.2)
	_lab.camera.look_at(Vector3(0.0, 1.0, -4.4), Vector3.UP)
	_lab.camera.fov = 52.0
	_lab.player.rig_avatar.set_camera_pitch_alignment(-34.0, true)
	await _wait_frames(6)
	await _capture_file("07_antesala_4_consoles.png")

	# 9. Galería Oeste Adyacente siguiendo en FREE_ROAM real (cámara debe mostrar las 5 reliquias)
	_lab.set_west_mastery_override(3)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.player.global_position = Vector3(-13.8, 0.05, 0.8)
	_lab.player.face_front_idle(true)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	_lab.player.rig_avatar.rotation_degrees.y = _lab.camera.rotation_degrees.y
	await _wait_frames(6)
	await _capture_file("08_west_trophy_chamber.png")
	_lab.player.rig_avatar.rotation_degrees.y = 0.0

	get_tree().quit(0)
