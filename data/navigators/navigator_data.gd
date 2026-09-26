class_name NavigatorData
extends Resource

## Definición y configuración de una Navegante (Oficial Táctica de Enlace y Radar).

@export_group("Identity")
@export var navigator_id: StringName = &"lyra"
@export var display_name: String = "Lyra"
@export var title: String = "Cartógrafa Biológica"
@export_multiline var specialty_desc: String = "Detecta biomasa y segmentos planetarios cercanos."
@export var buff_name: String = "Sobrecarga de Propulsión"
@export_multiline var buff_desc: String = "+25% Velocidad y x2 Radio de Imán por 10s al sincronizar el objetivo."
@export var theme_color: Color = Color(0.2, 0.95, 0.65, 1.0)
@export var is_secret: bool = false
@export var sort_order: int = 0
@export var target_type: StringName = &"planet" # &"planet", &"pact", &"monolith", &"satellite", &"anomaly"

@export_group("Visuals")
@export var portrait_texture: Texture2D
@export var fullbody_texture: Texture2D

@export_group("Comms Dialogue")
@export var dialogue_callouts: Array[String] = []

const ROSTER_DIR := "res://data/navigators/roster"
const CANONICAL_NAVIGATOR_IDS: Array[StringName] = [&"lyra", &"vespera", &"caelia", &"zephyr", &"iris"]

static var _cached_portraits: Dictionary = {}
static var _cached_fullbodies: Dictionary = {}

static func load_roster() -> Dictionary:
	var roster: Dictionary = {}
	var ordered := load_roster_ordered()
	for nav in ordered:
		if nav and nav.navigator_id:
			roster[nav.navigator_id] = nav
	return roster

static func load_roster_ordered() -> Array[NavigatorData]:
	var list: Array[NavigatorData] = []
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
						if res is NavigatorData:
							var nd: NavigatorData = res
							if not loaded_ids.has(nd.navigator_id):
								loaded_ids[nd.navigator_id] = true
								list.append(nd)
				fname = da.get_next()
			da.list_dir_end()

	# Fallback canónico para asegurar consistencia
	for nid in CANONICAL_NAVIGATOR_IDS:
		if not loaded_ids.has(nid):
			var direct_path := "%s/%s.tres" % [ROSTER_DIR, str(nid)]
			if ResourceLoader.exists(direct_path):
				var res = load(direct_path)
				if res is NavigatorData:
					var nd: NavigatorData = res
					loaded_ids[nd.navigator_id] = true
					list.append(nd)

	list.sort_custom(func(a: NavigatorData, b: NavigatorData) -> bool:
		return a.sort_order < b.sort_order
	)
	return list

static func get_navigator(id: StringName) -> NavigatorData:
	var direct_path := "%s/%s.tres" % [ROSTER_DIR, str(id)]
	if ResourceLoader.exists(direct_path):
		var res = load(direct_path)
		if res is NavigatorData:
			return res

	var roster := load_roster()
	if roster.has(id):
		return roster[id]
	elif not roster.is_empty():
		return roster.values()[0]
	return null

func get_portrait_texture() -> Texture2D:
	if _cached_portraits.has(navigator_id) and _cached_portraits[navigator_id] != null:
		return _cached_portraits[navigator_id]

	if portrait_texture:
		_cached_portraits[navigator_id] = portrait_texture
		return portrait_texture

	var path := "res://assets/characters/navigators/portraits/portrait_%s.png" % str(navigator_id).to_lower()
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			portrait_texture = res
			_cached_portraits[navigator_id] = res
			return res

	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				var tex := ImageTexture.create_from_image(img)
				portrait_texture = tex
				_cached_portraits[navigator_id] = tex
				return tex

	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			portrait_texture = tex
			_cached_portraits[navigator_id] = tex
			return tex

	# Fallback procedural
	var fallback_img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	fallback_img.fill(theme_color)
	var fallback_tex := ImageTexture.create_from_image(fallback_img)
	portrait_texture = fallback_tex
	_cached_portraits[navigator_id] = fallback_tex
	return fallback_tex

func get_fullbody_texture() -> Texture2D:
	if _cached_fullbodies.has(navigator_id) and _cached_fullbodies[navigator_id] != null:
		return _cached_fullbodies[navigator_id]

	if fullbody_texture:
		_cached_fullbodies[navigator_id] = fullbody_texture
		return fullbody_texture

	var path := "res://assets/characters/navigators/full/navigator_%s.png" % str(navigator_id).to_lower()
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			fullbody_texture = res
			_cached_fullbodies[navigator_id] = res
			return res

	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				var tex := ImageTexture.create_from_image(img)
				fullbody_texture = tex
				_cached_fullbodies[navigator_id] = tex
				return tex

	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			fullbody_texture = tex
			_cached_fullbodies[navigator_id] = tex
			return tex

	return get_portrait_texture()
