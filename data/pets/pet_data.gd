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

const CANONICAL_PET_IDS: Array[StringName] = [&"mochi", &"kuro", &"luna", &"pip", &"cosmo"]

static func load_roster() -> Dictionary:
	var roster: Dictionary = {}
	var ordered := load_roster_ordered()
	for p in ordered:
		if p and p.pet_id:
			roster[p.pet_id] = p
	return roster

static func load_roster_ordered() -> Array[PetData]:
	var list: Array[PetData] = []
	var loaded_ids: Dictionary = {}

	if DirAccess.dir_exists_absolute(ROSTER_DIR):
		var da := DirAccess.open(ROSTER_DIR)
		if da:
			da.list_dir_begin()
			var fname := da.get_next()
			while not fname.is_empty():
				if not da.current_is_dir() and (fname.ends_with(".tres") or fname.ends_with(".tres.remap") or fname.ends_with(".res") or fname.ends_with(".res.remap")):
					var clean_name := fname.trim_suffix(".remap")
					var res_path := ROSTER_DIR.path_join(clean_name)
					if ResourceLoader.exists(res_path):
						var res = load(res_path)
						if res is PetData:
							var pd: PetData = res
							if not loaded_ids.has(pd.pet_id):
								loaded_ids[pd.pet_id] = true
								list.append(pd)
				fname = da.get_next()
			da.list_dir_end()

	# Canonical fallback esencial para builds exportadas en PCK donde DirAccess no lista archivos empaquetados
	for pid in CANONICAL_PET_IDS:
		if not loaded_ids.has(pid):
			var direct_path := "%s/%s.tres" % [ROSTER_DIR, str(pid)]
			if ResourceLoader.exists(direct_path):
				var res = load(direct_path)
				if res is PetData:
					var pd: PetData = res
					loaded_ids[pd.pet_id] = true
					list.append(pd)

	list.sort_custom(func(a: PetData, b: PetData) -> bool:
		return a.sort_order < b.sort_order
	)
	return list

static func get_pet(id: StringName) -> PetData:
	var direct_path := "%s/%s.tres" % [ROSTER_DIR, str(id)]
	if ResourceLoader.exists(direct_path):
		var res = load(direct_path)
		if res is PetData:
			return res

	var roster := load_roster()
	if roster.has(id):
		return roster[id]
	elif not roster.is_empty():
		return roster.values()[0]
	return null

static var _cached_textures: Dictionary = {}

func get_icon_texture() -> Texture2D:
	if _cached_textures.has(pet_id) and _cached_textures[pet_id] != null:
		return _cached_textures[pet_id]

	# 1. Si icon ya está cargado válidamente
	if icon:
		_cached_textures[pet_id] = icon
		return icon

	var icon_path := "res://assets/pets/pet_%s.png" % str(pet_id).to_lower()

	# 2. Carga estándar ResourceLoader (caso normal con .ctex importado)
	if ResourceLoader.exists(icon_path):
		var res = load(icon_path)
		if res is Texture2D:
			icon = res
			_cached_textures[pet_id] = res
			return res

	# 3. Carga directa de buffer binario PNG (inmune a falta de cache .godot o fallas de importación en pull limpio)
	if FileAccess.file_exists(icon_path):
		var bytes := FileAccess.get_file_as_bytes(icon_path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				var tex := ImageTexture.create_from_image(img)
				icon = tex
				_cached_textures[pet_id] = tex
				return tex

	# 4. Carga directa desde filesystem del sistema operativo
	var global_path := ProjectSettings.globalize_path(icon_path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			icon = tex
			_cached_textures[pet_id] = tex
			return tex

	# 5. Generación procedural de emergencia (evita cualquier textura nula / cuadro vacío)
	var fallback_img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	fallback_img.fill(theme_color)
	var fallback_tex := ImageTexture.create_from_image(fallback_img)
	icon = fallback_tex
	_cached_textures[pet_id] = fallback_tex
	return fallback_tex

