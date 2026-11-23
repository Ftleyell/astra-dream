extends BaseTestSuite
## Suite aislada de verificación para WorkbenchHub, HUDWorkbench, DialogueWorkbench,
## CharacterSelectWorkbench, CombatGym y WorkbenchSaveSandbox.

const WorkbenchSaveSandboxScript = preload("res://sandbox/workbenches/shared/workbench_save_sandbox.gd")
const WorkbenchHubScript = preload("res://sandbox/workbenches/workbench_hub.gd")
const HUDWorkbenchScript = preload("res://sandbox/workbenches/hud_workbench/hud_workbench.gd")
const DialogueWorkbenchScript = preload("res://sandbox/workbenches/dialogue_workbench/dialogue_workbench.gd")
const CharSelectWorkbenchScript = preload("res://sandbox/workbenches/character_select_workbench/character_select_workbench.gd")
const CombatGymScript = preload("res://sandbox/combat_gym/combat_gym.gd")
const CombatGymDummyScript = preload("res://sandbox/combat_gym/combat_gym_dummy.gd")
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")
const WorkbenchHubScene: PackedScene = preload("res://sandbox/workbenches/workbench_hub.tscn")
const HUDWorkbenchScene: PackedScene = preload("res://sandbox/workbenches/hud_workbench/hud_workbench.tscn")
const DialogueWorkbenchScene: PackedScene = preload("res://sandbox/workbenches/dialogue_workbench/dialogue_workbench.tscn")
const CharSelectWorkbenchScene: PackedScene = preload("res://sandbox/workbenches/character_select_workbench/character_select_workbench.tscn")
const CombatGymScene: PackedScene = preload("res://sandbox/combat_gym/combat_gym.tscn")

var _had_save_backup: bool = false
var _save_backup_text: String = ""


func _ready() -> void:
	timeout_seconds = 18.0
	super._ready()
	_backup_profile_file()
	await _run_tests()


func _backup_profile_file() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		_had_save_backup = true
		_save_backup_text = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _restore_profile_file() -> void:
	Engine.time_scale = 1.0
	if _had_save_backup:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup_text)
			f.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _cleanup_and_quit(exit_code: int) -> void:
	_restore_profile_file()
	await super._cleanup_and_quit(exit_code)


func _await_frames(count: int = 2) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _run_tests() -> void:
	await _test_save_sandbox()
	await _test_workbench_hub()
	await _test_hud_workbench()
	await _test_dialogue_workbench()
	await _test_character_select_workbench()
	await _test_combat_gym()
	pass_suite("Workbenches y Combat Gym verificados sobre producción sin mutar SaveManager ni producción")


func _test_save_sandbox() -> void:
	SaveManager.set_biomass(111)
	var before_raw: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	var sb: WorkbenchSaveSandboxScript = WorkbenchSaveSandboxScript.new()
	sb.backup()
	SaveManager.set_biomass(9999)
	SaveManager.equip_skin("pilot:valentina", "pilot_valentina_crimson_nebula")
	assert_true(SaveManager.get_biomass() == 9999, "La mutación en sandbox debe aplicarse temporalmente")
	sb.restore()
	var after_raw: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	assert_true(before_raw == after_raw, "WorkbenchSaveSandbox.restore() debe restaurar el perfil exacto")
	await _await_frames(1)


func _test_workbench_hub() -> void:
	var profiles: Array[Dictionary] = PilotLabSelectorScript.scan_profile_entries()
	assert_true(profiles.size() >= 1, "PilotLabSelector debe detectar al menos valentina_v2_profile.tres")
	assert_true(str(profiles[0].get("pilot_id", "")) == "valentina_v2", "valentina_v2 debe figurar primero en PilotLabSelector")
	var val_prof_path: String = str(profiles[0].get("profile_path", ""))
	PilotLabSelectorScript.set_selected_profile_path(val_prof_path)
	assert_true(PilotLabSelectorScript.get_selected_profile_path() == val_prof_path, "get_selected_profile_path debe reflejar la selección")
	var face_resolved: String = PilotLabSelectorScript.resolve_sibling_config_path(val_prof_path, "face_anim", "")
	assert_true(face_resolved.ends_with("valentina_v2_face_anim.tres"), "resolve_sibling_config_path debe resolver valentina_v2_face_anim.tres")

	var hub: WorkbenchHubScript = WorkbenchHubScene.instantiate() as WorkbenchHubScript
	assert_true(hub != null, "WorkbenchHub debe instanciar")
	add_child(hub)
	await _await_frames(2)

	for key_v: Variant in WorkbenchHubScript.WORKBENCH_SCENES.keys():
		var path_str: String = str(WorkbenchHubScript.WORKBENCH_SCENES[key_v])
		assert_true(ResourceLoader.exists(path_str), "La escena '%s' (%s) debe existir" % [str(key_v), path_str])

	for lab_key_v: Variant in WorkbenchHubScript.PILOT_RIG_LAB_SCENES.keys():
		var lab_path_str: String = str(WorkbenchHubScript.PILOT_RIG_LAB_SCENES[lab_key_v])
		assert_true(ResourceLoader.exists(lab_path_str), "El lab '%s' (%s) debe existir" % [str(lab_key_v), lab_path_str])

	PilotLabSelectorScript.set_selected_profile_path("")
	hub.queue_free()
	await _await_frames(2)


func _test_hud_workbench() -> void:
	var wb: HUDWorkbenchScript = HUDWorkbenchScene.instantiate() as HUDWorkbenchScript
	assert_true(wb != null, "HUDWorkbench debe instanciar")
	add_child(wb)
	await _await_frames(2)

	assert_true(is_instance_valid(wb.hud), "HUDWorkbench debe montar GameHUD real")
	wb.set_weapon_count(0)
	assert_true(wb.hud.weapon_slots_row.get_child_count() == 4, "WeaponSlotsRow debe mostrar 4 ranuras fijas con 0 armas")
	wb.set_weapon_count(4)
	assert_true(wb.hud.weapon_slots_row.get_child_count() == 4, "WeaponSlotsRow debe mostrar 4 ranuras fijas con 4 armas")
	assert_true(wb.hud.weapon_slots_row.get_node_or_null("WeaponSlot_0") != null, "WeaponSlot_0 debe existir tras equipar 4 armas")
	assert_true(wb.hud.weapon_slots_row.get_node_or_null("WeaponSlot_3") != null, "WeaponSlot_3 debe existir tras equipar 4 armas")

	wb.set_health_state(35.0, 120.0, 40.0)
	wb.set_boss_bar_visible(true, 0.5)
	assert_true(wb.hud.boss_health_bar.visible, "BossHealthBar debe activarse desde HUDWorkbench")
	wb.toggle_guides()
	assert_true(wb.alignment_overlay.show_guides, "Las guías de alineación deben activarse")
	assert_true(not wb.get_layout_metrics_text().is_empty(), "Telemetría de layout del HUD no debe estar vacía")

	wb.queue_free()
	await _await_frames(2)


func _test_dialogue_workbench() -> void:
	var wb: DialogueWorkbenchScript = DialogueWorkbenchScene.instantiate() as DialogueWorkbenchScript
	assert_true(wb != null, "DialogueWorkbench debe instanciar")
	add_child(wb)
	await _await_frames(2)

	assert_true(is_instance_valid(wb.narrative_director), "DialogueWorkbench debe montar CombatNarrativeDirector")
	assert_true(is_instance_valid(wb.backdrop_layer), "DialogueWorkbench debe montar DialogueBackdropLayer")

	var portraits: Dictionary = wb.get_pilot_dch_portraits("valentina")
	assert_true(portraits.has("Normal") and portraits.has("Flipped"), "valentina.dch debe exponer al menos Normal y Flipped")

	wb.trigger_scenario("rival_face")
	await _await_frames(2)
	wb.stop_active_dialogue()
	await _await_frames(1)

	assert_true(not PauseArbitrator.is_reason_active(&"dialogue"), "stop_active_dialogue() debe liberar pausa 'dialogue'")
	assert_true(not PauseArbitrator.is_reason_active(&"briefing"), "stop_active_dialogue() debe liberar pausa 'briefing'")

	wb.queue_free()
	await _await_frames(2)


func _test_character_select_workbench() -> void:
	var before_raw: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""

	var wb: CharSelectWorkbenchScript = CharSelectWorkbenchScene.instantiate() as CharSelectWorkbenchScript
	assert_true(wb != null, "CharacterSelectWorkbench debe instanciar")
	add_child(wb)
	await _await_frames(2)

	assert_true(is_instance_valid(wb.char_select), "CharacterSelectWorkbench debe montar CharacterSelectUI")
	wb.open_loadout_view()
	await _await_frames(1)
	assert_true(wb.char_select.main_margin_container.visible, "Loadout view debe mostrar main_margin_container")

	wb.open_hero_picker()
	await _await_frames(1)
	assert_true(wb.char_select.hero_picker_modal.is_open, "HeroPickerModal debe abrirse bajo demanda")

	wb.apply_valentina_skin("pilot:valentina", "pilot_valentina_crimson_nebula")
	assert_true(SaveManager.get_equipped_skin("pilot:valentina") == "pilot_valentina_crimson_nebula", "La skin shader debe aplicarse al save temporal")

	wb.queue_free()
	await _await_frames(2)

	var after_raw: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	assert_true(before_raw == after_raw, "Al salir de CharacterSelectWorkbench, el save original debe quedar intacto")


func _test_combat_gym() -> void:
	var gym: CombatGymScript = CombatGymScene.instantiate() as CombatGymScript
	assert_true(gym != null, "CombatGym debe instanciar")
	add_child(gym)
	await _await_frames(3)

	assert_true(is_instance_valid(gym.player), "CombatGym debe montar Player real")
	assert_true(gym.player.has_rig_v2(), "Player en CombatGym debe activar PlayerRigV2Controller para Valentina")
	assert_true(is_instance_valid(gym.hud), "CombatGym debe montar GameHUD real")

	gym.set_weapon_count(4)
	await _await_frames(2)
	assert_true(gym.weapon_controller.equipped_weapons.size() == 4, "WeaponController debe tener 4 armas equipadas")
	var ring_ctrl: OrbitalWeaponRingController = gym.player.get_rig_v2_controller().get_ring_controller()
	assert_true(ring_ctrl != null and ring_ctrl.get_slot_count() == 4, "Anillo Orbital debe sincronizar 4 slots")

	var metrics: Dictionary = gym.get_ring_equidistance_metrics()
	assert_true(float(metrics.get("health_ring_radius_px", 0.0)) > 0.0, "HealthRing radius efectivo debe ser > 0")
	assert_true(float(metrics.get("orbital_radius_x_px", 0.0)) > 0.0, "OrbitalRing radius_x efectivo debe ser > 0")
	assert_true(float(metrics.get("orbital_radius_y_px", 0.0)) > 0.0, "OrbitalRing radius_y efectivo debe ser > 0")

	var dummies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	assert_true(dummies.size() >= 1, "CombatGym debe iniciar con al menos 1 CombatGymDummy en escena")
	var dummy: CombatGymDummyScript = dummies[0] as CombatGymDummyScript
	assert_true(dummy != null, "El nodo en grupo enemies debe ser CombatGymDummy")
	var ctx: HitContext = HitContext.create_direct_hit(125.0)
	dummy.take_damage(ctx)
	assert_true(is_equal_approx(dummy.total_damage_taken, 125.0), "CombatGymDummy debe registrar daño recibido vía HitContext")

	gym.set_gym_time_scale(0.25)
	gym.toggle_gym_pause()
	assert_true(PauseArbitrator.is_reason_active(&"combat_gym_pause"), "CombatGym debe usar PauseArbitrator para pausar")

	gym.queue_free()
	await _await_frames(2)
	assert_true(not PauseArbitrator.is_reason_active(&"combat_gym_pause"), "Al salir de CombatGym se debe liberar la pausa")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "Al salir de CombatGym se debe restaurar Engine.time_scale = 1.0")
