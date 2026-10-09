class_name WeaponPoolDataController
extends RefCounted

## WeaponPoolDataController.gd
## Controlador puro desacoplado de lógica y persistencia del pool de armas para WeaponSelectionModal.
## Gestiona el conjunto de armas activas por piloto, validación de mínimos y guardado.

const WeaponCatalog = preload("res://data/weapons/weapon_catalog.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")

var current_character_id: StringName = &"nova"
var active_weapon_ids: Array[StringName] = []
var min_active_weapons: int = 8


func initialize(char_id: StringName, min_required: int = 8) -> void:
	if not char_id.is_empty():
		current_character_id = char_id
	min_active_weapons = min_required

	if SaveManager.has_method("get_character_active_weapons"):
		active_weapon_ids = SaveManager.get_character_active_weapons(current_character_id)
	else:
		active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()

	if active_weapon_ids.size() < min_active_weapons:
		active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()
		persist()


func is_weapon_active(weapon_id: StringName) -> bool:
	return active_weapon_ids.has(weapon_id)


func can_deactivate_weapon() -> bool:
	return active_weapon_ids.size() > min_active_weapons


func toggle_weapon(weapon_id: StringName) -> bool:
	var is_active: bool = is_weapon_active(weapon_id)
	if is_active:
		if not can_deactivate_weapon():
			return false
		active_weapon_ids.erase(weapon_id)
	else:
		if not active_weapon_ids.has(weapon_id):
			active_weapon_ids.append(weapon_id)

	persist()
	return true


func reset_to_default() -> void:
	active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()
	persist()


func persist() -> void:
	if SaveManager.has_method("set_character_active_weapons"):
		SaveManager.set_character_active_weapons(current_character_id, active_weapon_ids)


func get_active_count() -> int:
	return active_weapon_ids.size()


func get_total_count() -> int:
	return WeaponCatalog.POOL_WEAPON_IDS.size()
