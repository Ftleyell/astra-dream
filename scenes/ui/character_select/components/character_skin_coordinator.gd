class_name CharacterSkinCoordinator
extends RefCounted

## CharacterSkinCoordinator.gd
## Controlador modular de personalización, selección de skins cosméticas,
## integración con carrusel/gacha y persistencia de atuendos en SaveManager.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")

var cosmetic_carousel_modal: Node = null
var gacha_modal: Node = null

var roster_dict: Dictionary = {} # Dictionary[StringName, CharacterData]

var on_character_refresh_needed: Callable = Callable()
var on_focus_save_needed: Callable = Callable()
var on_focus_restore_needed: Callable = Callable()


func setup_from_root(
	root: Control,
	p_roster_dict: Dictionary,
	p_on_refresh: Callable,
	p_on_save_focus: Callable,
	p_on_restore_focus: Callable
) -> void:
	var carousel: Node = root.get_node_or_null("CosmeticCarouselModal")
	var gacha: Node = root.get_node_or_null("GachaModal")
	setup(carousel, gacha, p_roster_dict, p_on_refresh, p_on_save_focus, p_on_restore_focus)


func setup(
	p_cosmetic_carousel: Node,
	p_gacha_modal: Node,
	p_roster_dict: Dictionary,
	p_on_refresh: Callable,
	p_on_save_focus: Callable,
	p_on_restore_focus: Callable
) -> void:
	cosmetic_carousel_modal = p_cosmetic_carousel
	gacha_modal = p_gacha_modal
	roster_dict = p_roster_dict
	on_character_refresh_needed = p_on_refresh
	on_focus_save_needed = p_on_save_focus
	on_focus_restore_needed = p_on_restore_focus


func apply_heroine_loadout(char_id: StringName) -> void:
	var loadout: Dictionary = SaveManager.get_character_loadout(char_id)
	if loadout.has("selected_pet") and not str(loadout["selected_pet"]).is_empty():
		SaveManager.set_selected_pet(StringName(str(loadout["selected_pet"])))
	if loadout.has("selected_navigator") and not str(loadout["selected_navigator"]).is_empty():
		SaveManager.set_selected_navigator(StringName(str(loadout["selected_navigator"])))

	var cur_pet_str: String = String(SaveManager.get_selected_pet()).to_lower()
	var pet_skin: String = str(loadout.get("equipped_pet_skin", ""))
	if not pet_skin.is_empty():
		SaveManager.equip_skin("pet:" + cur_pet_str, pet_skin)
	else:
		SaveManager.unequip_skin("pet:" + cur_pet_str)

	var cur_nav_str: String = String(SaveManager.get_selected_navigator()).to_lower()
	var nav_skin: String = str(loadout.get("equipped_navigator_skin", ""))
	if not nav_skin.is_empty():
		SaveManager.equip_skin("navigator:" + cur_nav_str, nav_skin)
	else:
		SaveManager.unequip_skin("navigator:" + cur_nav_str)

	var cid_str: String = String(char_id).to_lower()
	var ship_skin: String = str(loadout.get("equipped_ship_skin", loadout.get("ship_skin", "base")))
	if ship_skin.is_empty():
		ship_skin = "base"
	SaveManager.equip_skin("ship:" + cid_str, ship_skin)

	var weapon_skin: String = str(loadout.get("equipped_weapon_skin", loadout.get("weapon_skin", "base")))
	if weapon_skin.is_empty():
		weapon_skin = "base"
	SaveManager.equip_skin("weapon:" + cid_str, weapon_skin)

	var pilot_skin: String = str(loadout.get("equipped_pilot_skin", loadout.get("pilot_skin", "base")))
	if pilot_skin.is_empty():
		pilot_skin = "base"
	SaveManager.equip_skin("pilot:" + cid_str, pilot_skin)


func open_ship_customization(current_character_id: StringName) -> void:
	var char_data: CharacterData = roster_dict.get(current_character_id, null)
	_save_focus()
	if cosmetic_carousel_modal and char_data:
		cosmetic_carousel_modal.open_modal("ship", current_character_id, char_data)


func open_weapon_customization(current_character_id: StringName) -> void:
	var char_data: CharacterData = roster_dict.get(current_character_id, null)
	_save_focus()
	if cosmetic_carousel_modal and char_data:
		cosmetic_carousel_modal.open_modal("weapon", current_character_id, char_data)


func open_pilot_customization(current_character_id: StringName) -> void:
	_save_focus()
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if cosmetic_carousel_modal and data:
		cosmetic_carousel_modal.open_modal("pilot", current_character_id, data)
	elif gacha_modal:
		gacha_modal.open_gacha_modal()


func open_gacha_from_skins() -> void:
	if not gacha_modal:
		return
	_save_focus()
	gacha_modal.open_gacha_modal()
	gacha_modal._switch_tab(0)


func handle_cosmetic_carousel_closed(category: String, target_id: StringName, skin_id: String, fallback_character_id: StringName) -> void:
	var target_char: StringName = target_id if not target_id.is_empty() else fallback_character_id
	var loadout: Dictionary = SaveManager.get_character_loadout(target_char)
	match category:
		"ship":
			loadout["equipped_ship_skin"] = skin_id
			loadout["ship_skin"] = skin_id
		"weapon":
			loadout["equipped_weapon_skin"] = skin_id
			loadout["weapon_skin"] = skin_id
		"pilot":
			loadout["equipped_pilot_skin"] = skin_id
			loadout["pilot_skin"] = skin_id
	SaveManager.set_character_loadout(target_char, loadout)
	
	_trigger_refresh(target_char)
	_restore_focus()


func handle_skin_selected(slot_key: String, skin_id: String, fallback_character_id: StringName) -> void:
	var target_char: StringName = fallback_character_id
	var parts: PackedStringArray = slot_key.split(":")
	if parts.size() > 1 and roster_dict.has(StringName(parts[1])):
		target_char = StringName(parts[1])

	var loadout: Dictionary = SaveManager.get_character_loadout(target_char)
	if slot_key.begins_with("ship:"):
		loadout["equipped_ship_skin"] = skin_id
		loadout["ship_skin"] = skin_id
	elif slot_key.begins_with("weapon:"):
		loadout["equipped_weapon_skin"] = skin_id
		loadout["weapon_skin"] = skin_id
	elif slot_key.begins_with("pilot:"):
		loadout["equipped_pilot_skin"] = skin_id
		loadout["pilot_skin"] = skin_id
	elif slot_key.begins_with("pet:"):
		loadout["equipped_pet_skin"] = skin_id
	elif slot_key.begins_with("navigator:"):
		loadout["equipped_navigator_skin"] = skin_id
	SaveManager.set_character_loadout(target_char, loadout)
	_trigger_refresh(target_char)


func handle_pet_selected(pet_id: StringName, current_character_id: StringName) -> void:
	SaveManager.set_selected_pet(pet_id)
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["selected_pet"] = String(pet_id)
	SaveManager.set_character_loadout(current_character_id, loadout)


func handle_pet_skin_equipped(skin_id: String, current_character_id: StringName) -> void:
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["equipped_pet_skin"] = skin_id
	SaveManager.set_character_loadout(current_character_id, loadout)


func handle_navigator_selected(nav_id: StringName, current_character_id: StringName) -> void:
	SaveManager.set_selected_navigator(nav_id)
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["selected_navigator"] = String(nav_id)
	SaveManager.set_character_loadout(current_character_id, loadout)


func handle_navigator_skin_equipped(skin_id: String, current_character_id: StringName) -> void:
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["equipped_navigator_skin"] = skin_id
	SaveManager.set_character_loadout(current_character_id, loadout)


func _save_focus() -> void:
	if on_focus_save_needed.is_valid():
		on_focus_save_needed.call()


func _restore_focus() -> void:
	if on_focus_restore_needed.is_valid():
		on_focus_restore_needed.call()


func _trigger_refresh(target_char: StringName) -> void:
	if on_character_refresh_needed.is_valid():
		on_character_refresh_needed.call(target_char)
