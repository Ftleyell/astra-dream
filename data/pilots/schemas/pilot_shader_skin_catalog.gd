class_name PilotShaderSkinCatalog
extends Resource
## Catálogo unificado de skins 100% por shader para una piloto v2.
## Centraliza los 3 slots (pilot, wings, weapon) enlazando PilotSkinPreset (.tres).

@export var pilot_id: StringName = &"valentina"
@export var display_name: String = "Valentina"
@export var wings_slot_title: String = "ALAS / PROPULSIÓN"
@export var wings_slot_display_name: String = "Alas Astral Seraph"
@export var weapon_slot_title: String = "ARMA ORBITAL"
@export var weapon_slot_display_name: String = "Rail-Lance Orbital"
@export var base_preset: PilotSkinPreset = null
@export var entries: Array[ShaderSkinEntry] = []


func get_entry(skin_id: String) -> ShaderSkinEntry:
	if skin_id.is_empty():
		return null
	for entry: ShaderSkinEntry in entries:
		if entry != null and entry.id == skin_id:
			return entry
	return null


func get_entries_by_category(cat: String) -> Array[ShaderSkinEntry]:
	var norm_cat: String = "wings" if cat == "ship" else cat
	var result: Array[ShaderSkinEntry] = []
	for entry: ShaderSkinEntry in entries:
		if entry != null and entry.category == norm_cat:
			result.append(entry)
	return result


func resolve_preset(skin_id: String) -> PilotSkinPreset:
	if skin_id.is_empty() or skin_id == "base" or skin_id == "default":
		return base_preset
	for entry: ShaderSkinEntry in entries:
		if entry == null:
			continue
		if entry.id == skin_id:
			return entry.preset if entry.preset != null else base_preset
		if entry.preset != null and entry.preset.id == skin_id:
			return entry.preset
	return base_preset
