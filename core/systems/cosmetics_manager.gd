class_name CosmeticsManager
extends RefCounted

const DATABASE_PATH := "res://data/cosmetics/skin_database.json"
const GLOW_SHADER := preload("res://shaders/skin_glow_vfx.gdshader")

static var _cached_database: Dictionary = {}
static var _is_loaded: bool = false

static func load_database() -> Dictionary:
	if _is_loaded and not _cached_database.is_empty():
		return _cached_database

	if not FileAccess.file_exists(DATABASE_PATH):
		push_warning("CosmeticsManager: Database not found at %s" % DATABASE_PATH)
		return {}

	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if not file:
		return {}

	var json_str := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK or not (parser.data is Dictionary):
		push_error("CosmeticsManager: JSON parse error in %s" % DATABASE_PATH)
		return {}

	_cached_database = parser.data
	_is_loaded = true
	return _cached_database

static func get_all_skins() -> Dictionary:
	var db := load_database()
	return db.get("skins", {})

static func get_skin(skin_id: String) -> Dictionary:
	var skins := get_all_skins()
	return skins.get(skin_id, {})

static func get_skins_by_category(category: String) -> Array[Dictionary]:
	var skins := get_all_skins()
	var result: Array[Dictionary] = []
	for sid in skins.keys():
		var s: Dictionary = skins[sid]
		if s.get("category", "") == category:
			result.append(s)
	return result

static func get_skins_for_target(category: String, target_id: String) -> Array[Dictionary]:
	var skins := get_all_skins()
	var result: Array[Dictionary] = []
	for sid in skins.keys():
		var s: Dictionary = skins[sid]
		if s.get("category", "") == category and s.get("target_id", "") == target_id:
			result.append(s)
	return result

static func roll_random_skin() -> Dictionary:
	var skins := get_all_skins()
	if skins.is_empty():
		return {}
	
	var common_pool: Array[Dictionary] = []
	var rare_pool: Array[Dictionary] = []
	var epic_pool: Array[Dictionary] = []
	
	for s_id in skins.keys():
		var s: Dictionary = skins[s_id]
		var rarity: String = s.get("rarity", "common")
		if rarity == "epic":
			epic_pool.append(s)
		elif rarity == "rare":
			rare_pool.append(s)
		else:
			common_pool.append(s)
			
	var roll := randf()
	if roll < 0.15 and not epic_pool.is_empty():
		return epic_pool[randi() % epic_pool.size()]
	elif roll < 0.50 and not rare_pool.is_empty():
		return rare_pool[randi() % rare_pool.size()]
	elif not common_pool.is_empty():
		return common_pool[randi() % common_pool.size()]
		
	var all_keys := skins.keys()
	return skins[all_keys[randi() % all_keys.size()]]

static func load_texture(tex_path: String) -> Texture2D:
	if tex_path.is_empty():
		return null
	if ResourceLoader.exists(tex_path):
		var res = load(tex_path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(tex_path):
		var img := Image.new()
		var err := img.load(tex_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	return null

static func apply_skin_to_canvas_item(item: CanvasItem, skin_id: String, star_level: int = 1) -> void:
	if not is_instance_valid(item):
		return
		
	var skin_data := get_skin(skin_id)
	if skin_data.is_empty():
		item.material = null
		return
		
	var tex_path: String = skin_data.get("texture_path", "")
	var tex := load_texture(tex_path)
	if tex:
		if item is Sprite2D:
			(item as Sprite2D).texture = tex
		elif item is TextureRect:
			(item as TextureRect).texture = tex
			
	if star_level <= 1:
		item.material = null
	else:
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("star_level", star_level)
		
		var glow_hex: String = skin_data.get("glow_hex", "#00F0FF")
		var accent_hex: String = skin_data.get("accent_hex", "#FF007F")
		mat.set_shader_parameter("glow_color", Color.from_string(glow_hex, Color.CYAN))
		mat.set_shader_parameter("accent_color", Color.from_string(accent_hex, Color.MAGENTA))
		mat.set_shader_parameter("glow_intensity", 1.8 if star_level >= 3 else 1.2)
		mat.set_shader_parameter("pulse_speed", 3.0 if star_level >= 3 else 2.0)
		item.material = mat
