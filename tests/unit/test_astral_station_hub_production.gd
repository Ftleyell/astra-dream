extends BaseTestSuite

## Suite de verificación de Producción — Estación Astral v4 (AstralStationHub).
## Valida:
## 1. Instanciación limpia de astral_station_hub.tscn con is_dev_lab_mode = false y launch_real_combat = true.
## 2. SettingsModal abre/cierra correctamente bloqueando y liberando locomoción del jugador.
## 3. Aislamiento absoluto: CERO referencias a res://sandbox/ en scenes/ui/hub/astral_station/ y data/hub/default_astral_*.tres.
## 4. Todos los puntos de entrada reales de producción apuntan a astral_station_hub.tscn.

const HUB_SCENE_PATH: String = "res://scenes/ui/hub/astral_station/astral_station_hub.tscn"


func _ready() -> void:
	timeout_seconds = 18.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_zero_sandbox_refs_in_production()
	_test_production_entry_points()
	await _test_production_hub_instantiation_and_settings()
	pass_suite("Producción Estación Astral v4 verificada: 0 refs a sandbox, SettingsModal, launch_real_combat=true y 5 entry points enlazados.")


func _test_production_hub_instantiation_and_settings() -> void:
	var packed: PackedScene = ResourceLoader.load(HUB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar astral_station_hub.tscn")
	var hub: AstralStationHub = packed.instantiate() as AstralStationHub
	assert_true(hub != null, "Debe instanciar como AstralStationHub")
	add_child(hub)
	await get_tree().process_frame

	assert_true(not hub.is_dev_lab_mode, "Producción debe iniciar con is_dev_lab_mode = false")
	assert_true(hub.departure_controller != null and hub.departure_controller.launch_real_combat, "En producción departure_controller.launch_real_combat debe ser true")
	assert_true(hub.hud != null and not hub.hud.is_dev_panel_visible(), "Panel Dev debe permanecer oculto en producción")
	assert_true(not get_tree().paused, "get_tree().paused debe iniciar en false")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale debe iniciar en 1.0")
	assert_true(hub.player != null and hub.player.rig_avatar != null, "Jugador y HubRigAvatar3D deben instanciarse")
	assert_true(hub.settings_modal != null, "Producción debe instanciar SettingsModal")

	hub.open_settings_modal()
	assert_true(hub.settings_modal.visible, "open_settings_modal debe mostrar SettingsModal")
	assert_true(hub.player.is_movement_locked, "SettingsModal abierto debe bloquear movimiento del jugador")

	hub.close_settings_modal()
	assert_true(not hub.settings_modal.visible, "close_settings_modal debe ocultar SettingsModal")
	assert_true(not hub.player.is_movement_locked, "Cerrar SettingsModal debe desbloquear movimiento del jugador")

	hub.queue_free()
	await get_tree().process_frame


func _test_zero_sandbox_refs_in_production() -> void:
	var files: Array[String] = _collect_files_recursive("res://scenes/ui/hub/astral_station")
	files.append("res://data/hub/default_astral_station_config.tres")
	files.append("res://data/hub/default_astral_floating_layout.tres")
	files.append("res://data/hub/default_hub_gacha_3d_config.tres")

	for path: String in files:
		if not FileAccess.file_exists(path):
			assert_true(false, "Archivo de producción esperado no existe: %s" % path)
			continue
		var txt: String = FileAccess.get_file_as_string(path)
		assert_true(not txt.contains("res://sandbox/"), "Cero referencias a sandbox en producción (%s)" % path)


func _test_production_entry_points() -> void:
	for path: String in [
		"res://scenes/ui/title_screen/title_screen.gd",
		"res://scenes/ui/main_menu/main_menu.gd",
		"res://scenes/combat/controllers/combat_end_run_controller.gd",
		"res://scenes/ui/pause_menu/pause_menu.gd",
		"res://scenes/ui/character_select/components/character_select_launch_controller.gd",
	]:
		var txt: String = FileAccess.get_file_as_string(path)
		assert_true(txt.contains(HUB_SCENE_PATH), "Entry point %s debe apuntar a astral_station_hub.tscn" % path)


func _collect_files_recursive(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return result
	da.list_dir_begin()
	var item: String = da.get_next()
	while not item.is_empty():
		if not item.begins_with("."):
			var full: String = dir_path.path_join(item)
			if da.current_is_dir():
				result.append_array(_collect_files_recursive(full))
			else:
				var ext: String = item.get_extension().to_lower()
				if ext in ["gd", "tscn", "tres", "gdshader"]:
					result.append(full)
		item = da.get_next()
	da.list_dir_end()
	return result
