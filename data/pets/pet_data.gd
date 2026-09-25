class_name PetData
extends Resource

## Definición y configuración de datos de una Mascota / Dron de Ayuda universal.

@export_group("Identity")
@export var pet_id: StringName = &"mochi"
@export var display_name: String = "Mochi"
@export var title: String = "Cazador de Polvo Estelar"
@export_multiline var description: String = ""
@export_multiline var power_description: String = ""
@export var icon: Texture2D
@export var theme_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var is_secret: bool = false
@export var unlock_time_req: float = 0.0
@export var sort_order: int = 0

const ROSTER_DIR := "res://data/pets/roster"

static func load_roster() -> Dictionary:
	var roster: Dictionary = {}
	var ordered := load_roster_ordered()
	for p in ordered:
		if p and p.pet_id:
			roster[p.pet_id] = p
	return roster

static func load_roster_ordered() -> Array[PetData]:
	var list: Array[PetData] = []
	var da := DirAccess.open(ROSTER_DIR)
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while not fname.is_empty():
			if not da.current_is_dir() and (fname.ends_with(".tres") or fname.ends_with(".res")):
				var res = load(ROSTER_DIR.path_join(fname))
				if res is PetData:
					list.append(res)
			fname = da.get_next()
		da.list_dir_end()
	
	list.sort_custom(func(a: PetData, b: PetData) -> bool:
		return a.sort_order < b.sort_order
	)
	return list

static func get_pet(id: StringName) -> PetData:
	var roster := load_roster()
	if roster.has(id):
		return roster[id]
	elif not roster.is_empty():
		return roster.values()[0]
	return null
