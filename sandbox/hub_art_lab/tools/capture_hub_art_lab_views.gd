extends Node

## Herramienta de captura en ventana GPU real (Vulkan Forward+ + AgX + Bloom) para auditar la Mandala Octagonal de 9 Islas.

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/hub_art_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const CameraRigScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_camera_rig.gd")

var _out_dir: String = ""
var _lab: LabScript = null


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_lab = LabScene.instantiate() as LabScript
	_lab.name = "HubArtLab"
	add_child(_lab)

	await _wait_frames(12)
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

	# 1. Octágono Central + 4 aberturas reales caladas al Cosmos + 8 puentes rectos
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(6)
	await _capture_file("01_free_roam_octagon_center.png")

	# 2. Cápsula Hero (shader propio astrolabio + arcos limpios)
	_lab.trigger_capsule_focus(true)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(6)
	await _capture_file("02_capsule_hero.png")
	_lab.exit_capsule_focus()

	# 3. Ala Norte — Pasarela-Observatorio Abierta (Spotlight Skins sobre Cosmos puro)
	_lab.open_station_by_id(&"skins_mirror")
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(8)
	await _capture_file("03_north_skins_spotlight.png")
	_lab.modal_coordinator.close_active_modal()

	# 4. Ala Sur — Gran Octágono Ceremonial de Talentos (abertura central calada + 3 anillos constelación)
	_lab.player.global_position = Vector3(0.0, 0.02, 13.45)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.player.face_front_idle(true)
	_lab.camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_lab.camera_rig.update(_lab.camera, Vector3(0.0, 0.0, 15.82), 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(6)
	await _capture_file("04_south_talents_altar.png")

	# 5. Bastión Este (Gacha 3D + 5 Balizas Prismáticas en brazos cantiléver)
	_lab.player.global_position = Vector3(13.2, 0.02, 0.0)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.player.face_front_idle(true)
	_lab.camera_rig.update(_lab.camera, Vector3(16.0, 0.0, 0.0), 0.0, _lab.config, true)
	await _wait_frames(6)
	await _capture_file("05_east_mirrored_gacha.png")

	# 6. Bastión Oeste Espejado (5 Reliquias en brazos cantiléver + Yaw 0 fijo)
	_lab.set_west_mastery_override(3)
	_lab.player.global_position = Vector3(-13.2, 0.02, 0.0)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.player.face_front_idle(true)
	_lab.camera_rig.update(_lab.camera, Vector3(-16.0, 0.0, 0.0), 0.0, _lab.config, true)
	await _wait_frames(6)
	await _capture_file("06_west_mirrored_relics.png")

	# 7. Isla SW Compañeros (Proyector + Órbita Viva al Vacío de Mascotas)
	_lab.player.global_position = Vector3(-10.2, 0.02, 11.4)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.player.face_front_idle(true)
	_lab.camera_rig.update(_lab.camera, Vector3(-10.2, 0.0, 10.2), 0.0, _lab.config, true)
	await _wait_frames(6)
	await _capture_file("07_sw_companions_pet_orbit.png")

	# 8. Vuelo espacial entre islas (Alas 3D + Anillo Orbital sin ningún recorte cuadrado)
	_lab.player.global_position = Vector3(9.5, 0.44, 3.8)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.player.rig_avatar.set_orbital_weapon_deployed(true)
	_lab.camera_rig.update(_lab.camera, _lab.player.global_position, 0.0, _lab.config, true)
	_lab.player.rig_avatar.set_camera_pitch_alignment(_lab.camera.rotation_degrees.x, true)
	await _wait_frames(8)
	await _capture_file("08_space_flight_wings.png")
	_lab.player.rig_avatar.set_orbital_weapon_deployed(false)

	# 9. Onda media de Desmaterialización Tecnológica sobre la Mandala
	_lab.player.global_position = Vector3(5.6, 0.44, -2.0)
	_lab.player.evaluate_platform_traversal(0.0, true)
	_lab.departure_controller.launch_real_combat = false
	_lab.departure_controller.trigger_radial_departure(Vector2(0.7, -0.7).normalized())
	_lab.departure_controller._step_departure(0.30)
	_lab.camera_rig.update(_lab.camera, Vector3(3.0, 0.4, -0.8), 0.0, _lab.config, true)
	await _wait_frames(1)
	await _capture_file("09_radial_demat_midwave.png")

	get_tree().quit(0)
