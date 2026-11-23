extends BaseTestSuite
## Suite de verificación Fase 4: Sistema Unificado de Skins 100% por Shaders
## (Piloto, Alas 2D/3D, Arma 3D, Banner, Hub 3D, Carrusel, CharacterSelect y Gacha).

const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const ProfileStorageScript = preload("res://core/systems/persistence/profile_storage.gd")
const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const BannerCtrlScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")
const OrbitalRingCtrlScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const CharacterSelectScene: PackedScene = preload("res://scenes/ui/character_select/character_select.tscn")
const HubWorldScene: PackedScene = preload("res://scenes/ui/hub/hub_world.tscn")
const GachaModalScript = preload("res://scenes/ui/gacha/gacha_modal.gd")

const CATALOG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_skin_catalog.tres"
const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const BANNER_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_live_banner.tres"

var _had_save_backup: bool = false
var _save_backup_text: String = ""


func _ready() -> void:
	timeout_seconds = 15.0
	super._ready()
	_backup_profile_file()
	await _run_tests()


func _backup_profile_file() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		_had_save_backup = true
		_save_backup_text = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _restore_profile_file() -> void:
	if _had_save_backup:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup_text)
			f.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _run_tests() -> void:
	_test_catalog_and_json_cleanup()
	_test_follow_pilot_and_save_migration()
	await _test_runtime_controllers_and_hub_parity()
	await _test_ui_carousel_charsel_and_gacha()
	_test_zero_sandbox_refs()
	_restore_profile_file()
	pass_suite("Fase 4 verificada: Skins 100% por shaders, follow_pilot, Hub 3D, Banner, Carrusel y Gacha Live.")


func _test_catalog_and_json_cleanup() -> void:
	var catalog: PilotShaderSkinCatalog = ResourceLoader.load(CATALOG_PATH) as PilotShaderSkinCatalog
	assert_true(catalog != null, "Debe cargar valentina_v2_skin_catalog.tres")
	assert_true(catalog.base_preset != null and catalog.base_preset.is_base_skin, "Catálogo debe enlazar 00_base.tres como base_preset")
	assert_true(catalog.entries.size() == 27, "Catálogo de Valentina debe contener exactamente 27 entradas (actual=%d)" % catalog.entries.size())

	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var val: CharacterData = roster.get(&"valentina", null)
	assert_true(val != null and val.has_shader_skins(), "valentina.tres debe enlazar shader_skin_catalog")

	CosmeticsManagerScript.reload_database()
	var all_skins: Dictionary = CosmeticsManagerScript.get_all_skins()
	for sid_v: Variant in all_skins.keys():
		var s: Dictionary = all_skins[sid_v] as Dictionary
		if str(s.get("target_id", "")).to_lower() == "valentina":
			assert_true(bool(s.get("is_shader_skin", false)), "Valentina solo debe tener skins por shader en CosmeticsManager: %s" % str(sid_v))
			assert_true(not str(s.get("texture_path", "")).contains("recolors"), "No deben quedar rutas PNG recolor legacy para Valentina: %s" % str(sid_v))

	for entry: ShaderSkinEntry in catalog.entries:
		assert_true(all_skins.has(entry.id), "CosmeticsManager debe incluir entrada shader %s" % entry.id)

	var wings_list: Array[Dictionary] = CosmeticsManagerScript.get_skins_for_target("wings", "valentina")
	var ship_alias_list: Array[Dictionary] = CosmeticsManagerScript.get_skins_for_target("ship", "valentina")
	assert_true(wings_list.size() == 9, "Deben existir 9 skins de alas para Valentina (actual=%d)" % wings_list.size())
	assert_true(ship_alias_list.size() == 9, "Alias 'ship' debe resolver las 9 skins de alas de Valentina")


func _test_follow_pilot_and_save_migration() -> void:
	var legacy_payload: Dictionary = {
		"version": 1,
		"biomass": 1200,
		"selected_character": "valentina",
		"equipped_skins": {
			"pilot:valentina": "pilot_valentina_gotica",
			"ship:valentina": "ship_valentina_gotica",
			"weapon:valentina": "weapon_valentina_crimson_blood",
			"pilot:nova": "pilot_nova_gotica",
		},
		"character_loadouts": {
			"valentina": {
				"equipped_pilot_skin": "pilot_valentina_gotica",
				"equipped_ship_skin": "ship_valentina_gotica",
				"equipped_weapon_skin": "weapon_valentina_gotica",
			},
			"nova": {
				"equipped_pilot_skin": "pilot_nova_gotica",
			},
		},
	}
	var sanitized: Dictionary = ProfileStorageScript.clean_and_validate_data(legacy_payload)
	var eq_map: Dictionary = sanitized.get("equipped_skins", {})
	assert_true(str(eq_map.get("pilot:valentina", "")) == "base", "pilot_valentina_gotica obsoleta debe migrar a 'base'")
	assert_true(str(eq_map.get("wings:valentina", "")) == "follow_pilot", "ship_valentina_gotica obsoleta debe migrar a 'follow_pilot'")
	assert_true(str(eq_map.get("ship:valentina", "")) == "follow_pilot", "ship:valentina debe sincronizarse con wings:valentina")
	assert_true(str(eq_map.get("weapon:valentina", "")) == "follow_pilot", "weapon_valentina_crimson_blood obsoleta debe migrar a 'follow_pilot'")
	assert_true(str(eq_map.get("pilot:nova", "")) == "pilot_nova_gotica", "Skins de otros pilotos deben preservarse intactas")

	var val_loadout: Dictionary = (sanitized.get("character_loadouts", {}) as Dictionary).get("valentina", {})
	assert_true(str(val_loadout.get("equipped_pilot_skin", "")) == "base", "Loadout migrado de Valentina pilot debe ser 'base'")
	assert_true(str(val_loadout.get("equipped_wings_skin", "")) == "follow_pilot", "Loadout migrado de Valentina wings debe ser 'follow_pilot'")
	assert_true(str(val_loadout.get("equipped_weapon_skin", "")) == "follow_pilot", "Loadout migrado de Valentina weapon debe ser 'follow_pilot'")

	# Verificar resolución follow_pilot vs override independiente
	SaveManager.lock_all_skins()
	SaveManager.unlock_or_upgrade_skin("pilot_valentina_cyber_emerald")
	SaveManager.unlock_or_upgrade_skin("wings_valentina_solar_valkyrie")
	SaveManager.unlock_or_upgrade_skin("weapon_valentina_2b_yorha")

	SaveManager.equip_skin("pilot:valentina", "pilot_valentina_cyber_emerald")
	SaveManager.equip_skin("wings:valentina", CosmeticsManagerScript.FOLLOW_PILOT_SKIN_ID)
	SaveManager.equip_skin("weapon:valentina", CosmeticsManagerScript.FOLLOW_PILOT_SKIN_ID)

	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "pilot").id == "cyber_emerald", "Piloto debe resolver cyber_emerald")
	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "wings").id == "cyber_emerald", "Alas en follow_pilot deben heredar cyber_emerald")
	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "weapon").id == "cyber_emerald", "Arma en follow_pilot debe heredar cyber_emerald")

	SaveManager.equip_skin("wings:valentina", "wings_valentina_solar_valkyrie")
	SaveManager.equip_skin("weapon:valentina", "weapon_valentina_2b_yorha")
	assert_true(SaveManagerScriptCheck(SaveManager.get_equipped_skin("ship:valentina")) == "wings_valentina_solar_valkyrie", "ship:valentina debe espejar wings:valentina")
	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "wings").id == "solar_valkyrie", "Alas independientes deben resolver solar_valkyrie")
	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "weapon").id == "2b_yorha", "Arma independiente debe resolver 2b_yorha")
	assert_true(CosmeticsManagerScript.resolve_pilot_skin_preset(&"valentina", "pilot").id == "cyber_emerald", "Piloto debe conservar cyber_emerald")


func SaveManagerScriptCheck(val: Variant) -> String:
	return str(val)


func _test_runtime_controllers_and_hub_parity() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	assert_true(profile != null and profile.skins.size() >= 10, "valentina_v2_profile.tres debe tener sus 10 presets")

	var cyber_preset: PilotSkinPreset = profile.skins[2]
	var solar_preset: PilotSkinPreset = profile.skins[3]
	var eva_preset: PilotSkinPreset = profile.skins[7]

	# 1. PlanarCombatRig + Alas 3D + Alas 2D Base (mutuamente excluyentes con preservación lazy de skin)
	var rig: PlanarCombatRig = PlanarCombatRigScript.new() as PlanarCombatRig
	rig.pilot_profile = profile
	rig.enable_3d_wings = true
	rig.enable_base_propulsion_wings = false
	add_child(rig)
	await get_tree().process_frame

	rig.apply_skin_preset(cyber_preset, 2)
	assert_true(rig.get_active_skin_id() == "cyber_emerald", "Rig debe activar skin cyber_emerald")
	assert_true(rig.get_3d_wings_controller().get_active_skin_id() == "cyber_emerald", "Alas 3D en follow_pilot deben heredar cyber_emerald")

	rig.apply_wings_skin_preset(solar_preset, 3)
	assert_true(rig.get_active_skin_id() == "cyber_emerald", "Cuerpo del rig debe conservar cyber_emerald tras cambiar alas")
	assert_true(rig.get_active_wings_skin_id() == "solar_valkyrie", "Rig debe registrar override de alas solar_valkyrie")
	assert_true(rig.get_3d_wings_controller().get_active_skin_id() == "solar_valkyrie", "Alas 3D deben aplicar override solar_valkyrie")

	rig.set_base_propulsion_wings_enabled(true)
	assert_true(rig.get_base_propulsion_controller() != null, "Alas 2D base deben montarse al activar modo base")
	assert_true(rig.get_base_propulsion_controller().get_active_skin_id() == "solar_valkyrie", "Alas 2D base deben heredar override solar_valkyrie preservado")

	rig.apply_wings_skin_preset(null, 1)
	assert_true(rig.get_base_propulsion_controller().get_active_skin_id() == "follow_pilot", "Al limpiar override, Alas 2D deben volver a follow_pilot")

	rig.set_3d_wings_enabled(true)
	assert_true(rig.get_3d_wings_controller() != null and rig.get_3d_wings_controller().get_active_skin_id() == "cyber_emerald", "Al volver a Alas 3D tras limpiar override, deben seguir al piloto cyber_emerald")
	rig.queue_free()

	# 2. OrbitalWeaponRingController + OrbitalWeapon3DRenderer
	var ring: OrbitalWeaponRingController = OrbitalRingCtrlScript.new() as OrbitalWeaponRingController
	add_child(ring)
	ring.set_config(ResourceLoader.load("res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"))
	ring.set_weapon_3d_enabled(true)
	ring.apply_skin_preset(eva_preset, 2)
	ring.set_mouse_target_local(Vector2(180.0, 0.0))
	ring.step(0.016)
	var renderer_3d: OrbitalWeapon3DRenderer = ring.get_slot_3d_renderer(0)
	assert_true(renderer_3d != null, "Slot 0 debe tener OrbitalWeapon3DRenderer activo")
	assert_true(renderer_3d.get_surface_base_color(2).is_equal_approx(eva_preset.accent_color), "Cristal 3D del arma debe tomar accent_color de eva_unit_01")
	ring.queue_free()

	# 3. PilotLiveBannerController
	var banner_cfg: PilotLiveBannerConfig = ResourceLoader.load(BANNER_CFG_PATH) as PilotLiveBannerConfig
	var banner := BannerCtrlScript.new() as PilotLiveBannerController
	banner.set_config(banner_cfg)
	add_child(banner)
	await get_tree().process_frame
	banner.apply_skin_preset(cyber_preset, 2)
	assert_true(banner.get_active_skin_id() == "cyber_emerald", "LiveBanner debe activar skin cyber_emerald")
	var banner_mat: ShaderMaterial = banner.get_banner_sprite().material as ShaderMaterial
	assert_true(banner_mat.get_shader_parameter("skin_recolor_enabled") == true, "Shader de LiveBanner debe activar skin_recolor_enabled")
	banner.apply_wings_skin_preset(solar_preset, 3)
	assert_true(banner.get_active_wings_skin_id() == "solar_valkyrie", "LiveBanner debe aceptar override independiente de alas")
	assert_true(banner_mat.get_shader_parameter("use_custom_wings_accent") == true, "Shader de LiveBanner debe activar use_custom_wings_accent")
	banner.queue_free()

	# 4. HubWorld + HubPlayerController3D + HubRigAvatar3D
	SaveManager.unlock_or_upgrade_skin("pilot_valentina_void_amethyst")
	SaveManager.unlock_or_upgrade_skin("pilot_valentina_arctic_phantom")
	SaveManager.equip_skin("pilot:valentina", "pilot_valentina_void_amethyst")
	var val_lo: Dictionary = SaveManager.get_character_loadout(&"valentina")
	val_lo["equipped_pilot_skin"] = "pilot_valentina_void_amethyst"
	SaveManager.set_character_loadout(&"valentina", val_lo)

	var hub: HubWorld = HubWorldScene.instantiate() as HubWorld
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var pc: HubPlayerController3D = hub.player_controller as HubPlayerController3D
	assert_true(pc != null and pc.rig_avatar != null, "HubWorld debe tener HubRigAvatar3D")
	assert_true(pc.rig_avatar.get_active_skin_id() == "void_amethyst", "HubRigAvatar3D debe iniciar con skin equipada void_amethyst")

	SaveManager.equip_skin("pilot:valentina", "pilot_valentina_arctic_phantom")
	hub._on_modal_closed()
	assert_true(pc.rig_avatar.get_active_skin_id() == "arctic_phantom", "HubRigAvatar3D debe refrescar inmediatamente a arctic_phantom tras cerrar modal")
	hub.queue_free()
	await get_tree().process_frame


func _test_ui_carousel_charsel_and_gacha() -> void:
	SaveManager.unlock_or_upgrade_skin("pilot_valentina_arctic_phantom")
	SaveManager.equip_skin("pilot:valentina", "pilot_valentina_arctic_phantom")
	SaveManager.equip_skin("wings:valentina", CosmeticsManagerScript.FOLLOW_PILOT_SKIN_ID)
	SaveManager.equip_skin("weapon:valentina", CosmeticsManagerScript.FOLLOW_PILOT_SKIN_ID)

	var ui: CharacterSelectUI = CharacterSelectScene.instantiate() as CharacterSelectUI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	if ui.hero_picker_modal != null and ui.hero_picker_modal.is_open:
		var picker: HeroPickerModal = ui.hero_picker_modal
		for i: int in range(picker._roster.size()):
			if picker._roster[i].character_id == &"valentina":
				picker._select_index(i)
				break
		picker._confirm_selection()
		await get_tree().process_frame

	assert_true(ui.equipment_cards != null and ui.equipment_cards.ship_title != null, "EquipmentCards debe exponer ship_title")
	assert_true(ui.equipment_cards.ship_title.text == "ALAS / PROPULSIÓN", "Tarjeta de Nave debe renombrarse a 'ALAS / PROPULSIÓN' para Valentina v2")
	assert_true(ui.equipment_cards.weapon_title.text == "ARMA ORBITAL", "Tarjeta de Arma debe mostrar 'ARMA ORBITAL' para Valentina v2")
	var showcase_ctrl: PilotLiveBannerController = ui.pilot_showcase.live_banner_viewport.get_banner_controller()
	assert_true(showcase_ctrl != null and showcase_ctrl.get_active_skin_id() == "arctic_phantom", "Showcase Live Banner debe sincronizar skin equipada arctic_phantom")

	for pair: Array in [["_on_ship_card_pressed", "wings"], ["_on_weapon_card_pressed", "weapon"], ["_on_pilot_skin_pressed", "pilot"]]:
		ui.call(str(pair[0]))
		await get_tree().process_frame
		var modal: CosmeticCarouselModal = ui.cosmetic_carousel_modal
		var preview: ShaderSkinLivePreview = modal.get_live_preview()
		assert_true(modal.is_open and preview != null and preview.visible, "Carrusel '%s' debe mostrar ShaderSkinLivePreview" % str(pair[1]))
		assert_true(preview.get_active_mode() == str(pair[1]), "ShaderSkinLivePreview debe operar en modo '%s'" % str(pair[1]))
		modal.close_modal()
		await get_tree().process_frame
		assert_true(preview.get_preview_viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED, "LivePreview debe pausarse (UPDATE_DISABLED) al cerrar carrusel")

	ui.queue_free()
	await get_tree().process_frame

	# GachaModal: pulls + Wardrobe shader inspector + pausa al cambiar tab
	var gacha: GachaModal = GachaModalScript.new() as GachaModal
	add_child(gacha)
	await get_tree().process_frame
	SaveManager.add_gacha_tokens(40)

	for bid: String in ["general", "ships", "pilots"]:
		gacha._select_banner(bid)
		var pulls: Array[Dictionary] = gacha.execute_pulls(10)
		assert_true(pulls.size() == 10, "Banner '%s' debe resolver 10 pulls" % bid)
		for p: Dictionary in pulls:
			var sdata: Dictionary = p.get("skin_data", {})
			assert_true(CosmeticsManagerScript.is_skin_eligible_for_gacha(sdata), "Pull en '%s' solo debe entregar skins elegibles" % bid)
			assert_true(not str(sdata.get("texture_path", "")).contains("recolors/pilots/fullbody_valentina"), "Gacha no debe sortear PNGs legacy de Valentina")

	gacha._switch_tab(1)
	gacha._filter_wardrobe("ship")
	await get_tree().process_frame
	var insp: ShaderSkinLivePreview = gacha._wardrobe_controller.get_live_inspector_preview()
	assert_true(insp != null, "Armario Gacha debe incluir ShaderSkinLivePreview compartido")
	gacha._switch_tab(0)
	await get_tree().process_frame
	assert_true(insp.get_preview_viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED, "Inspector de Armario debe pausarse al salir de la pestaña Armario")

	gacha.queue_free()
	await get_tree().process_frame


func _test_zero_sandbox_refs() -> void:
	var targets: Array[String] = [
		"res://core/systems/cosmetics_manager.gd",
		"res://scenes/ui/cosmetics",
		"res://scenes/ui/gacha",
		"res://data/pilots",
		"res://scenes/pilots",
	]
	for t: String in targets:
		if FileAccess.file_exists(t):
			var txt: String = FileAccess.get_file_as_string(t)
			assert_true(not txt.contains("sandbox/pilot_rig_lab"), "Referencia prohibida a sandbox en %s" % t)
		else:
			var files: Array[String] = []
			_collect_code_files(t, files)
			for fp: String in files:
				var txt: String = FileAccess.get_file_as_string(fp)
				assert_true(not txt.contains("sandbox/pilot_rig_lab"), "Referencia prohibida a sandbox en %s" % fp)


func _collect_code_files(dir_path: String, out_files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect_code_files(full, out_files)
			elif entry.get_extension().to_lower() in ["gd", "gdshader", "gdshaderinc", "tres"]:
				out_files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
