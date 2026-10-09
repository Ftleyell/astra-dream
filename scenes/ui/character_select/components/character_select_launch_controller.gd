class_name CharacterSelectLaunchController
extends RefCounted

## Controlador desacoplado para el ciclo de lanzamiento y retorno al Hub en CharacterSelect.

func commit_launch(char_id: StringName, tree: SceneTree) -> void:
	if not SaveManager.is_character_unlocked(char_id):
		return

	SaveManager.set_selected_character(char_id)
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
	var ship_skin: String = str(loadout.get("equipped_ship_skin", ""))
	if not ship_skin.is_empty():
		SaveManager.equip_skin("ship:" + cid_str, ship_skin)
	else:
		SaveManager.unequip_skin("ship:" + cid_str)

	var weapon_skin: String = str(loadout.get("equipped_weapon_skin", ""))
	if not weapon_skin.is_empty():
		SaveManager.equip_skin("weapon:" + cid_str, weapon_skin)
	else:
		SaveManager.unequip_skin("weapon:" + cid_str)

	var pilot_skin: String = str(loadout.get("equipped_pilot_skin", ""))
	if not pilot_skin.is_empty():
		SaveManager.equip_skin("pilot:" + cid_str, pilot_skin)
	else:
		SaveManager.unequip_skin("pilot:" + cid_str)

	if tree:
		var root: Node = tree.root
		if root and root.has_node("SceneTransition"):
			var st: Node = root.get_node("SceneTransition")
			if st.has_method("change_scene_to_file"):
				st.call("change_scene_to_file", "res://scenes/combat/main_game.tscn")
				return
		tree.call_deferred("change_scene_to_file", "res://scenes/combat/main_game.tscn")


func exit_to_hub(tree: SceneTree, speed_selector: CharacterSpeedSelector = null) -> void:
	if speed_selector:
		speed_selector.set_game_speed(1.0)
	if tree:
		var root: Node = tree.root
		if root and root.has_node("SceneTransition"):
			var st: Node = root.get_node("SceneTransition")
			if st.has_method("change_scene_to_file"):
				st.call("change_scene_to_file", "res://scenes/ui/hub/hub_world.tscn")
				return
		tree.call_deferred("change_scene_to_file", "res://scenes/ui/hub/hub_world.tscn")
