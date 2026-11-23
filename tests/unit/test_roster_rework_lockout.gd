extends BaseTestSuite
## Suite de verificación Fase 2: Promoción Single Source of Truth, Lockout de Roster,
## Migración de Saves, Filtrado Gacha y Live Banner 2.5D en CharacterSelectUI.

const CharacterSelectScene: PackedScene = preload("res://scenes/ui/character_select/character_select.tscn")
const LaunchControllerScript = preload("res://scenes/ui/character_select/components/character_select_launch_controller.gd")
const LiveBannerViewportScript = preload("res://scenes/ui/character_select/components/character_live_banner_viewport.gd")
const BannerControllerScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")
const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const ProfileStorageScript = preload("res://core/systems/persistence/profile_storage.gd")


func _ready() -> void:
	timeout_seconds = 15.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	_test_roster_rework_ready_flags_and_valentina_resources()
	_test_save_migration_preserves_legacy_data()
	_test_gacha_excludes_non_ready_pilots()
	await _test_character_select_and_live_banner()
	_test_single_source_of_truth_zero_sandbox_refs()
	pass_suite("Fase 2 verificada: Single Source of Truth, bloqueo de roster, migración, Gacha y Live Banner.")


func _test_roster_rework_ready_flags_and_valentina_resources() -> void:
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	assert_true(roster.has(&"valentina"), "Roster debe contener a &valentina")

	var expected_locked: Array[StringName] = [&"nova", &"kira", &"selene", &"roxy", &"echo", &"nyx"]
	assert_true(roster[&"valentina"].is_playable_rework_ready == true, "Solo Valentina debe tener is_playable_rework_ready == true")
	for cid: StringName in expected_locked:
		assert_true(roster.has(cid), "Roster debe contener a %s" % String(cid))
		assert_true(roster[cid].is_playable_rework_ready == false, "Piloto %s debe estar bloqueada (is_playable_rework_ready == false)" % String(cid))

	var val: CharacterData = roster[&"valentina"]
	assert_true(val.pilot_rig_profile != null, "valentina.tres debe referenciar PilotRigProfile")
	assert_true(val.live_banner_config != null, "valentina.tres debe referenciar PilotLiveBannerConfig")
	assert_true(val.avatar_icon != null, "valentina.tres debe referenciar avatar_icon")
	assert_true(val.portrait_icon != null, "valentina.tres debe referenciar portrait_icon")
	assert_true(val.pilot_rig_profile.resource_path.begins_with("res://data/pilots/"), "pilot_rig_profile debe vivir en res://data/pilots/")
	assert_true(val.live_banner_config.resource_path.begins_with("res://data/pilots/"), "live_banner_config debe vivir en res://data/pilots/")
	assert_true(val.avatar_icon.resource_path.begins_with("res://assets/pilots/"), "avatar_icon debe vivir en res://assets/pilots/")
	assert_true(val.portrait_icon.resource_path.begins_with("res://assets/pilots/"), "portrait_icon debe vivir en res://assets/pilots/")


func _test_save_migration_preserves_legacy_data() -> void:
	for legacy_id: String in ["nova", "echo", ""]:
		var legacy_payload: Dictionary = {
			"version": 1,
			"biomass": 2450,
			"antimatter": 88,
			"selected_character": legacy_id,
			"unlocked_characters": ["nova", "echo", "roxy"],
			"character_banlists": {"nova": ["escudo"], "valentina": ["manzana"]},
			"character_loadouts": {
				"nova": {"selected_pet": "kuro", "equipped_pilot_skin": "pilot_nova_stealth"},
				"valentina": {"selected_pet": "mochi", "equipped_pilot_skin": "base"},
			},
		}
		var sanitized: Dictionary = ProfileStorageScript.clean_and_validate_data(legacy_payload)
		assert_true(sanitized.get("selected_character") == &"valentina", "selected_character='%s' debe migrar a &valentina" % legacy_id)
		assert_true(int(sanitized.get("biomass", 0)) == 2450, "Biomasa debe preservarse tras migración")
		assert_true(int(sanitized.get("antimatter", 0)) == 88, "Antimateria debe preservarse tras migración")
		var unlocked_chars: Array = sanitized.get("unlocked_characters", [])
		assert_true(unlocked_chars.has(&"valentina"), "Valentina debe asegurarse como desbloqueada")
		assert_true(unlocked_chars.has(&"nova") and unlocked_chars.has(&"echo"), "Desbloqueos previos deben preservarse")
		var bans: Dictionary = sanitized.get("character_banlists", {})
		assert_true(bans.has(&"nova") and bans.has(&"valentina"), "Banlists previas deben preservarse")
		var loadouts: Dictionary = sanitized.get("character_loadouts", {})
		assert_true(str(loadouts.get("nova", {}).get("selected_pet", "")) == "kuro", "Loadout previo de Nova debe preservarse")


func _test_gacha_excludes_non_ready_pilots() -> void:
	var all_skins: Dictionary = CosmeticsManagerScript.get_all_skins()
	assert_true(not all_skins.is_empty(), "Base de datos cosmética no debe estar vacía")

	var seen_categories: Dictionary = {}
	for banner_id: String in ["general", "ships", "pilots"]:
		var filtered: Array[Dictionary] = GachaBannerEngineScript.filter_skins_for_banner(all_skins, banner_id)
		assert_true(not filtered.is_empty(), "Banner '%s' debe conservar skins elegibles" % banner_id)
		for entry: Dictionary in filtered:
			var cat: String = str(entry.get("category", ""))
			var tid: String = str(entry.get("target_id", "")).to_lower()
			seen_categories[cat] = true
			if cat in ["pilot", "ship", "weapon"]:
				assert_true(tid == "valentina", "Banner '%s' filtró skin no elegible: %s:%s" % [banner_id, cat, tid])

		for _i: int in range(30):
			var rolled: Dictionary = CosmeticsManagerScript.roll_banner_skin(banner_id, _i % 10 == 9)
			assert_true(not rolled.is_empty(), "roll_banner_skin('%s') debe devolver skin válida" % banner_id)
			var r_cat: String = str(rolled.get("category", ""))
			var r_tid: String = str(rolled.get("target_id", "")).to_lower()
			if r_cat in ["pilot", "ship", "weapon"]:
				assert_true(r_tid == "valentina", "roll_banner_skin('%s') no debe sortear %s:%s" % [banner_id, r_cat, r_tid])

	assert_true(seen_categories.has("pet") and seen_categories.has("navigator"), "Pets y Navegadoras deben seguir elegibles en Gacha")


func _test_character_select_and_live_banner() -> void:
	var ui: CharacterSelectUI = CharacterSelectScene.instantiate() as CharacterSelectUI
	assert_true(ui != null, "character_select.tscn debe instanciar como CharacterSelectUI")
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.hero_picker_modal != null and ui.hero_picker_modal.is_open, "HeroPickerModal debe iniciar abierto")
	var picker: HeroPickerModal = ui.hero_picker_modal

	# Bloqueo al intentar confirmar Nova o Roxy en HeroPickerModal
	var nova_idx: int = -1
	var roxy_idx: int = -1
	var val_idx: int = -1
	for i: int in range(picker._roster.size()):
		var cid: StringName = picker._roster[i].character_id
		if cid == &"nova":
			nova_idx = i
		elif cid == &"roxy":
			roxy_idx = i
		elif cid == &"valentina":
			val_idx = i
	assert_true(nova_idx >= 0 and roxy_idx >= 0 and val_idx >= 0, "Roster de HeroPickerModal debe contener nova, roxy y valentina")

	picker._select_index(nova_idx)
	picker._confirm_selection()
	assert_true(picker.is_open == true, "HeroPickerModal debe bloquear confirmación de Nova")

	picker._select_index(roxy_idx)
	picker._confirm_selection()
	assert_true(picker.is_open == true, "HeroPickerModal debe bloquear confirmación de Roxy")

	# Seleccionar Valentina -> LiveBanner activo con 12 cuchillas + CanvasGroup z_index = 0
	picker._select_index(val_idx)
	await get_tree().process_frame
	var picker_banner_vp: LiveBannerViewportScript = picker.live_banner_viewport
	assert_true(picker_banner_vp != null and picker_banner_vp.visible, "HeroPickerModal debe activar CharacterLiveBannerViewport para Valentina")
	var picker_ctrl: BannerControllerScript = picker_banner_vp.get_banner_controller()
	assert_true(picker_ctrl != null and picker_ctrl.get_wing_shard_count() == 12, "LiveBanner de Valentina debe cargar las 12 cuchillas de alas")
	var ugroup: CanvasGroup = picker_ctrl.get_unified_group()
	assert_true(ugroup != null and picker_ctrl.get_character_root().z_index == 0 and picker_ctrl.get_banner_sprite().z_index == 0, "Invariante CanvasGroup: hijos z_index == 0")

	var confirmed_ids: Array[StringName] = []
	picker.hero_confirmed.connect(func(cid: StringName) -> void: confirmed_ids.append(cid))
	picker._confirm_selection()
	await get_tree().process_frame
	assert_true(confirmed_ids.size() == 1 and confirmed_ids[0] == &"valentina", "Confirmar Valentina debe emitir hero_confirmed(&'valentina')")
	assert_true(picker_ctrl.is_pilot_selected() == true, "Confirmar Valentina debe disparar trigger_select_sequence()")

	# Verificar Showcase principal de CharacterSelectUI
	assert_true(ui.pilot_showcase != null and ui.pilot_showcase.live_banner_viewport != null and ui.pilot_showcase.live_banner_viewport.visible, "CharacterPilotShowcase debe mostrar CharacterLiveBannerViewport para Valentina")
	ui.pilot_showcase.trigger_deploy_lock_in()
	var showcase_ctrl: BannerControllerScript = ui.pilot_showcase.live_banner_viewport.get_banner_controller()
	assert_true(showcase_ctrl != null and showcase_ctrl.is_pilot_selected() == true, "trigger_deploy_lock_in debe disparar secuencia de selección en showcase")

	# Verificar bloqueo de CharacterSelectLaunchController para pilotos no listos
	SaveManager.set_selected_character(&"valentina")
	var launch_ctrl := LaunchControllerScript.new()
	launch_ctrl.commit_launch(&"nova", null)
	assert_true(SaveManager.get_selected_character() == &"valentina", "commit_launch(&'nova') debe bloquearse y no persistir &'nova'")

	ui.queue_free()
	await get_tree().process_frame


func _test_single_source_of_truth_zero_sandbox_refs() -> void:
	for root_dir: String in ["res://scenes/pilots", "res://data/pilots"]:
		var files: Array[String] = []
		_collect_files_recursive(root_dir, files)
		assert_true(not files.is_empty(), "El directorio promovido %s no debe estar vacío" % root_dir)
		for fpath: String in files:
			var text: String = FileAccess.get_file_as_string(fpath)
			assert_true(not text.contains("sandbox/pilot_rig_lab"), "Referencia prohibida a sandbox/pilot_rig_lab en producción: %s" % fpath)


func _collect_files_recursive(dir_path: String, out_files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect_files_recursive(full, out_files)
			else:
				var ext: String = entry.get_extension().to_lower()
				if ext in ["gd", "gdshader", "gdshaderinc", "tres"]:
					out_files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
