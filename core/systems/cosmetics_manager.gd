class_name CosmeticsManager
extends RefCounted

const DATABASE_PATH := "res://data/cosmetics/skin_database.json"
const CATEGORIES_DIR := "res://data/cosmetics/categories"
const CATEGORY_FILES := {
	"ship": "res://data/cosmetics/categories/skins_ships.json",
	"pilot": "res://data/cosmetics/categories/skins_pilots.json",
	"weapon": "res://data/cosmetics/categories/skins_weapons.json",
	"pet": "res://data/cosmetics/categories/skins_pets.json",
	"navigator": "res://data/cosmetics/categories/skins_navigators.json",
}
const PALETTES_FILE := "res://data/cosmetics/categories/palettes.json"
const GLOW_SHADER := preload("res://shaders/skin_glow_vfx.gdshader")

static var _cached_database: Dictionary = {}
static var _is_loaded: bool = false
static var _discovered_category_files: Dictionary = {}

static func discover_category_files() -> Dictionary:
	var files: Dictionary = {}
	# Registrar archivos base conocidos por retrocompatibilidad
	for cat in CATEGORY_FILES.keys():
		files[cat] = CATEGORY_FILES[cat]

	# Escanear CATEGORIES_DIR dinámicamente para descubrir archivos nuevos de mods o categorías
	if DirAccess.dir_exists_absolute(CATEGORIES_DIR):
		var dir := DirAccess.open(CATEGORIES_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while not file_name.is_empty():
				if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "palettes.json":
					var full_path := CATEGORIES_DIR.path_join(file_name)
					# Inferir nombre de categoría del archivo: skins_ships.json -> ship, etc.
					var cat_name := file_name.trim_suffix(".json")
					if cat_name.begins_with("skins_"):
						cat_name = cat_name.trim_prefix("skins_")
					# Normalizar plural a singular conocido
					if cat_name.ends_with("s") and files.has(cat_name.trim_suffix("s")):
						cat_name = cat_name.trim_suffix("s")
					files[cat_name] = full_path
				file_name = dir.get_next()
			dir.list_dir_end()
	_discovered_category_files = files
	return files

static func load_database() -> Dictionary:
	if _is_loaded and not _cached_database.is_empty():
		return _cached_database

	# Cargar desde la arquitectura modular fragmentada por categorías
	if FileAccess.file_exists(PALETTES_FILE):
		var merged_db: Dictionary = {"version": "1.0", "palettes": {}, "skins": {}}
		var pal_file := FileAccess.open(PALETTES_FILE, FileAccess.READ)
		if pal_file:
			var p_data = JSON.parse_string(pal_file.get_as_text())
			if p_data is Dictionary:
				merged_db["palettes"] = p_data.get("palettes", {})
			pal_file.close()

		var category_files := discover_category_files()
		for cat_path in category_files.values():
			if FileAccess.file_exists(cat_path):
				var c_file := FileAccess.open(cat_path, FileAccess.READ)
				if c_file:
					var c_data = JSON.parse_string(c_file.get_as_text())
					if c_data is Dictionary and c_data.has("skins"):
						var cat_skins: Dictionary = c_data["skins"]
						for sid in cat_skins.keys():
							merged_db["skins"][sid] = cat_skins[sid]
					c_file.close()

		if not merged_db["skins"].is_empty():
			_cached_database = merged_db
			_is_loaded = true
			return _cached_database

	# Fallback a archivo monolítico legado si existiera
	if FileAccess.file_exists(DATABASE_PATH):
		var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
		if file:
			var parser := JSON.new()
			var err := parser.parse(file.get_as_text())
			file.close()
			if err == OK and parser.data is Dictionary:
				_cached_database = parser.data
				_is_loaded = true
				return _cached_database

	push_warning("CosmeticsManager: Database not found")
	return {}

static func get_category_skins(category: String) -> Dictionary:
	var category_files := discover_category_files()
	var path: String = category_files.get(category, "")
	if path != "" and FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if d is Dictionary and d.has("skins"):
				return d["skins"]
	var result: Dictionary = {}
	for s in get_skins_by_category(category):
		result[s.get("id", "")] = s
	return result

static func reload_database() -> Dictionary:
	_cached_database.clear()
	_is_loaded = false
	return load_database()

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

static func roll_banner_skin(banner_id: String, is_pity: bool = false) -> Dictionary:
	var skins := get_all_skins()
	if skins.is_empty():
		return {}

	# Filtrar pool según el banner temático
	var banner_skins: Array[Dictionary] = []
	for sid in skins.keys():
		var s: Dictionary = skins[sid]
		var cat: String = s.get("category", "")
		match banner_id:
			"ships":
				if cat == "ship" or cat == "weapon":
					banner_skins.append(s)
			"pilots":
				if cat == "pilot" or cat == "navigator":
					banner_skins.append(s)
			_: # "general"
				banner_skins.append(s)

	if banner_skins.is_empty():
		return roll_random_skin()

	var common_pool: Array[Dictionary] = []
	var rare_pool: Array[Dictionary] = []
	var epic_pool: Array[Dictionary] = []

	for s in banner_skins:
		var rarity: String = s.get("rarity", "common")
		if rarity == "epic":
			epic_pool.append(s)
		elif rarity == "rare":
			rare_pool.append(s)
		else:
			common_pool.append(s)

	# Si se activa el Pity (10 tiradas acumuladas), garantizar Épico (o Raro si no hay épico)
	if is_pity:
		if not epic_pool.is_empty():
			return epic_pool[randi() % epic_pool.size()]
		elif not rare_pool.is_empty():
			return rare_pool[randi() % rare_pool.size()]

	# Probabilidades estándar: 15% Épico, 35% Raro, 50% Común
	var roll := randf()
	if roll < 0.15 and not epic_pool.is_empty():
		return epic_pool[randi() % epic_pool.size()]
	elif roll < 0.50 and not rare_pool.is_empty():
		return rare_pool[randi() % rare_pool.size()]
	elif not common_pool.is_empty():
		return common_pool[randi() % common_pool.size()]

	return banner_skins[randi() % banner_skins.size()]

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

static func get_skin_texture(skin_data: Dictionary) -> Texture2D:
	var tex_path: String = skin_data.get("texture_path", "")
	if not tex_path.is_empty():
		var tex := load_texture(tex_path)
		if tex:
			return tex
	# Fallback para armas según target_id
	var cat: String = skin_data.get("category", "")
	if cat == "weapon":
		var tid: String = skin_data.get("target_id", "")
		var weapon_path := "res://assets/characters/weapons/weapon_%s.png" % tid
		if ResourceLoader.exists(weapon_path):
			var w_tex = load(weapon_path)
			if w_tex is Texture2D:
				return w_tex
		var default_gun := "res://assets/models/kenney_space_kit/Side/weapon_gun.png"
		if ResourceLoader.exists(default_gun):
			var g_tex = load(default_gun)
			if g_tex is Texture2D:
				return g_tex
	return null

static func apply_skin_to_canvas_item(item: CanvasItem, skin_id: String, star_level: int = 1, apply_texture: bool = true) -> void:
	if not is_instance_valid(item):
		return
		
	var skin_data := get_skin(skin_id)
	if skin_data.is_empty():
		item.material = null
		return
		
	if apply_texture:
		var tex := get_skin_texture(skin_data)
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


static func apply_pilot_selection_to_canvas_item(item: CanvasItem, skin_id: String, star_level: int = 1, is_flipped: bool = false) -> void:
	if not is_instance_valid(item):
		return

	var skin_data := get_skin(skin_id)
	if skin_data.is_empty():
		item.material = null
		return

	var tex_path := ""
	if is_flipped:
		tex_path = skin_data.get("selection_flipped_texture_path", "")
	if tex_path.is_empty():
		tex_path = skin_data.get("selection_texture_path", "")
	if tex_path.is_empty():
		tex_path = skin_data.get("texture_path", "")

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

static func apply_skin_to_sprite3d(sprite: Sprite3D, skin_id: String, star_level: int = 1, is_back: bool = false, is_flipped: bool = false) -> void:
	if not is_instance_valid(sprite):
		return

	var skin_data := get_skin(skin_id)
	if skin_data.is_empty():
		sprite.material_override = null
		return

	var tex_path := ""
	if is_back:
		if is_flipped:
			tex_path = skin_data.get("back_flipped_texture_path", "")
		if tex_path.is_empty():
			tex_path = skin_data.get("back_texture_path", "")
	else:
		if is_flipped:
			tex_path = skin_data.get("flipped_texture_path", "")
		if tex_path.is_empty():
			tex_path = skin_data.get("texture_path", "")

	if tex_path.is_empty():
		tex_path = skin_data.get("texture_path", "")

	var tex := load_texture(tex_path)
	if tex:
		sprite.texture = tex

	if star_level <= 1:
		sprite.material_override = null
	else:
		var spatial_shader = load("res://shaders/skin_glow_spatial.gdshader")
		if spatial_shader:
			var mat := ShaderMaterial.new()
			mat.shader = spatial_shader
			mat.set_shader_parameter("texture_albedo", sprite.texture)
			mat.set_shader_parameter("star_level", star_level)

			var glow_hex: String = skin_data.get("glow_hex", "#00F0FF")
			var accent_hex: String = skin_data.get("accent_hex", "#FF007F")
			mat.set_shader_parameter("glow_color", Color.from_string(glow_hex, Color.CYAN))
			mat.set_shader_parameter("accent_color", Color.from_string(accent_hex, Color.MAGENTA))
			mat.set_shader_parameter("glow_intensity", 1.8 if star_level >= 3 else 1.2)
			mat.set_shader_parameter("pulse_speed", 3.0 if star_level >= 3 else 2.0)
			sprite.material_override = mat
	return

static func apply_skin_to_dialogue_portrait(portrait_node: Node, char_identifier: String, portrait_name: String) -> bool:
	if not is_instance_valid(portrait_node):
		return false

	var char_id := char_identifier.to_lower().strip_edges()

	# Determinar si el personaje que habla es el piloto activo o la mascota activa de la run
	var active_pilot := ""
	var active_pet := ""

	var sm_script = load("res://core/autoloads/save_manager.gd")
	if sm_script:
		if sm_script.has_method("get_selected_character"):
			active_pilot = String(sm_script.get_selected_character()).to_lower()
		if sm_script.has_method("get_selected_pet"):
			active_pet = String(sm_script.get_selected_pet()).to_lower()

	var is_active_pilot := (not active_pilot.is_empty() and char_id == active_pilot)
	var is_active_pet := (not active_pet.is_empty() and char_id == active_pet)

	# Regla estricta a la run activa: solo el piloto y mascota del jugador reflejan skins en diálogo
	if not is_active_pilot and not is_active_pet:
		return false

	var slot_key := ""
	if is_active_pilot:
		slot_key = "pilot:" + char_id
	elif is_active_pet:
		slot_key = "pet:" + char_id

	var skin_id := ""
	var stars := 1
	if sm_script:
		if sm_script.has_method("get_equipped_skin"):
			skin_id = sm_script.get_equipped_skin(slot_key)
		if sm_script.has_method("get_skin_stars") and not skin_id.is_empty():
			stars = sm_script.get_skin_stars(skin_id)

	if skin_id.is_empty():
		return false

	var skin_data := get_skin(skin_id)
	if skin_data.is_empty():
		return false

	# Detectar orientación flipped
	var is_flipped := false
	var p_lower := portrait_name.to_lower()
	if "flip" in p_lower:
		is_flipped = true
	elif portrait_node is Sprite2D and (portrait_node as Sprite2D).flip_h:
		is_flipped = true

	var tex_path := ""
	if is_flipped:
		tex_path = skin_data.get("portrait_flipped_texture_path", "")
		if tex_path.is_empty():
			tex_path = skin_data.get("flipped_texture_path", "")

	if tex_path.is_empty():
		tex_path = skin_data.get("portrait_texture_path", "")
	if tex_path.is_empty():
		tex_path = skin_data.get("texture_path", "")

	if tex_path.is_empty():
		return false

	var tex := load_texture(tex_path)
	if not tex:
		return false

	if portrait_node is Sprite2D:
		var s := portrait_node as Sprite2D
		s.texture = tex
		if is_flipped and not skin_data.get("portrait_flipped_texture_path", "").is_empty():
			s.flip_h = false
	elif portrait_node is TextureRect:
		(portrait_node as TextureRect).texture = tex

	# Aplicar efectos de video / shader según el nivel de estrellas
	if portrait_node is CanvasItem:
		apply_skin_to_canvas_item(portrait_node as CanvasItem, skin_id, stars, false)

	return true
