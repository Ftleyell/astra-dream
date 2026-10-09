class_name NavigatorDataController
extends RefCounted

## NavigatorDataController.gd
## Controlador puro desacoplado de lógica, skins y persistencia para NavigatorSelectionModal.
## Gestiona la lista de navegantes, resolución de skins base y cosméticas,
## índices activos de navegación y persistencia de selecciones en SaveManager.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")

var navigators: Array = []
var available_skins: Array[Dictionary] = []
var current_index: int = 0
var skin_index: int = 0


func load_roster() -> void:
	navigators = NavigatorDataScript.load_roster_ordered()
	var selected_nid: StringName = SaveManager.get_selected_navigator()
	var initial_index: int = 0
	for i in range(navigators.size()):
		if navigators[i].navigator_id == selected_nid:
			initial_index = i
			break
	current_index = initial_index
	load_available_skins()


func load_available_skins() -> void:
	available_skins.clear()
	if navigators.is_empty() or current_index < 0 or current_index >= navigators.size():
		return

	var cur_nav = navigators[current_index]
	var nid_str: String = String(cur_nav.navigator_id).to_lower()
	var slot_key: String = "navigator:" + nid_str

	# Slot 0: Aspecto original/base
	var base_skin: Dictionary = {
		"id": "",
		"skin_name": "Aspecto Estándar",
		"texture": cur_nav.get_portrait_texture(),
		"is_base": true,
		"is_unlocked": true,
		"stars": 0,
		"glow_hex": "#00F0FF"
	}
	available_skins.append(base_skin)

	# Slots 1..N: Aspectos alternativos desbloqueables
	var raw_skins: Array[Dictionary] = CosmeticsManager.get_skins_for_target("navigator", nid_str)
	for s: Dictionary in raw_skins:
		var sid: String = s.get("id", "")
		var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
		var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1
		var tex: Texture2D = CosmeticsManager.load_texture(s.get("texture_path", ""))
		if not tex:
			tex = cur_nav.get_portrait_texture()
		var skin_entry: Dictionary = {
			"id": sid,
			"skin_name": s.get("name", "Aspecto"),
			"texture": tex,
			"is_base": false,
			"is_unlocked": is_unlocked,
			"stars": stars,
			"glow_hex": s.get("glow_hex", "#00F0FF"),
			"desc": s.get("desc", "")
		}
		available_skins.append(skin_entry)

	# Sintonizar skin_index según lo equipado en SaveManager
	var equipped_sid: String = SaveManager.get_equipped_skin(slot_key)
	skin_index = 0
	if not equipped_sid.is_empty():
		for i in range(1, available_skins.size()):
			if available_skins[i].get("id", "") == equipped_sid:
				skin_index = i
				break


func cycle_horizontal(direction: int) -> int:
	if navigators.is_empty():
		return current_index
	var count: int = navigators.size()
	var next_idx: int = (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	set_index(next_idx)
	return current_index


func cycle_vertical(direction: int) -> int:
	if available_skins.size() <= 1:
		return skin_index
	var count: int = available_skins.size()
	var next_idx: int = (skin_index + direction) % count
	if next_idx < 0:
		next_idx += count
	skin_index = next_idx
	return skin_index


func set_index(new_idx: int) -> void:
	if new_idx < 0 or new_idx >= navigators.size():
		return
	if new_idx == current_index:
		return
	current_index = new_idx
	load_available_skins()


func set_skin_index(new_skin_idx: int) -> void:
	if new_skin_idx < 0 or new_skin_idx >= available_skins.size():
		return
	skin_index = new_skin_idx


func get_current_navigator():
	if navigators.is_empty() or current_index < 0 or current_index >= navigators.size():
		return null
	return navigators[current_index]


func get_current_skin() -> Dictionary:
	if skin_index >= 0 and skin_index < available_skins.size():
		return available_skins[skin_index]
	return {}


func is_current_unlocked() -> bool:
	var cur_nav = get_current_navigator()
	if not cur_nav:
		return false
	return SaveManager.is_navigator_unlocked(cur_nav.navigator_id)


func is_current_selected() -> bool:
	var cur_nav = get_current_navigator()
	if not cur_nav:
		return false
	return cur_nav.navigator_id == SaveManager.get_selected_navigator()


func confirm_selection() -> Dictionary:
	var cur_nav = get_current_navigator()
	if not cur_nav or not is_current_unlocked():
		return {"success": false, "navigator_id": &"", "slot_key": "", "skin_id": ""}

	var nid: StringName = cur_nav.navigator_id
	SaveManager.set_selected_navigator(nid)

	var nid_str: String = String(nid).to_lower()
	var slot_key: String = "navigator:" + nid_str
	var sid: String = ""

	if skin_index > 0 and skin_index < available_skins.size():
		var cur_skin: Dictionary = available_skins[skin_index]
		var target_sid: String = cur_skin.get("id", "")
		if SaveManager.is_skin_unlocked(target_sid):
			sid = target_sid
			SaveManager.equip_skin(slot_key, sid)
		else:
			SaveManager.unequip_skin(slot_key)
	else:
		SaveManager.unequip_skin(slot_key)

	return {
		"success": true,
		"navigator_id": nid,
		"slot_key": slot_key,
		"skin_id": sid
	}
