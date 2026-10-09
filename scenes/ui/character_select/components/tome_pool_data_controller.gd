class_name TomePoolDataController
extends RefCounted

## TomePoolDataController.gd
## Controlador puro desacoplado de lógica y persistencia del pool de tomos para TomeSelectionModal.
## Gestiona el conjunto de tomos activos por piloto, validación de mínimos y guardado.

const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")

var current_character_id: StringName = &"nova"
var active_tome_ids: Array[StringName] = []
var min_active_tomes: int = 6


func initialize(char_id: StringName, min_required: int = 6) -> void:
	if not char_id.is_empty():
		current_character_id = char_id
	min_active_tomes = min_required

	if SaveManager.has_method("get_character_active_tomes"):
		active_tome_ids = SaveManager.get_character_active_tomes(current_character_id)
	else:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()

	if active_tome_ids.size() < min_active_tomes:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
		persist()


func is_tome_active(tome_id: StringName) -> bool:
	return active_tome_ids.has(tome_id)


func can_deactivate_tome() -> bool:
	return active_tome_ids.size() > min_active_tomes


func toggle_tome(tome_id: StringName) -> bool:
	var is_active: bool = is_tome_active(tome_id)
	if is_active:
		if not can_deactivate_tome():
			return false
		active_tome_ids.erase(tome_id)
	else:
		if not active_tome_ids.has(tome_id):
			active_tome_ids.append(tome_id)

	persist()
	return true


func reset_to_default() -> void:
	active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
	persist()


func persist() -> void:
	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)


func get_active_count() -> int:
	return active_tome_ids.size()


func get_total_count() -> int:
	return TomeCatalog.ALL_TOME_IDS.size()
