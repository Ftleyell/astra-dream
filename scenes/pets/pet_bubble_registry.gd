class_name PetBubbleRegistry
extends RefCounted

## Registro estático de configs .tres y estilos de skins 100% por shader para pets 3D.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const CONFIG_DIR: String = "res://data/pets/bubble_v2"
const DEFAULT_PET_ID: StringName = &"mochi"

static var _cache: Dictionary = {}


static func get_config(pet_id: StringName) -> PetBubbleVisualConfig:
	var key: String = String(pet_id).to_lower().strip_edges()
	if key.is_empty():
		key = String(DEFAULT_PET_ID)
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key] as PetBubbleVisualConfig

	var path: String = "%s/%s.tres" % [CONFIG_DIR, key]
	if ResourceLoader.exists(path):
		var cfg: PetBubbleVisualConfig = ResourceLoader.load(path) as PetBubbleVisualConfig
		if cfg != null:
			_cache[key] = cfg
			return cfg

	var fallback_path: String = "%s/%s.tres" % [CONFIG_DIR, String(DEFAULT_PET_ID)]
	if ResourceLoader.exists(fallback_path):
		var fb: PetBubbleVisualConfig = ResourceLoader.load(fallback_path) as PetBubbleVisualConfig
		if fb != null:
			_cache[key] = fb
			return fb
	return null


static func resolve_skin_style(skin_id: String, stars: int = 1) -> Dictionary:
	var clean_id: String = skin_id.strip_edges()
	if clean_id.is_empty() or clean_id == "base" or clean_id == "default":
		return {"active": false}

	var skin_data: Dictionary = CosmeticsManager.get_skin(clean_id)
	if skin_data.is_empty():
		return {"active": false}

	var glow_hex: String = str(skin_data.get("glow_hex", "#00F0FF"))
	var accent_hex: String = str(skin_data.get("accent_hex", "#FF007F"))
	var glow_col: Color = Color.from_string(glow_hex, Color.CYAN)
	var accent_col: Color = Color.from_string(accent_hex, Color.MAGENTA)

	var clamped_stars: int = clampi(stars, 1, 3)
	var star_boost: float = 0.0
	if clamped_stars == 2:
		star_boost = 0.35
	elif clamped_stars >= 3:
		star_boost = 0.75

	var theme_col: Color = glow_col.lerp(accent_col, 0.25)
	var rim_col: Color = glow_col.lerp(Color.WHITE, 0.32)
	var inner_col: Color = accent_col.lerp(glow_col, 0.45)
	var grade_col: Color = glow_col.lerp(accent_col, 0.35).lerp(Color.WHITE, 0.32)

	return {
		"active": true,
		"theme_color": theme_col,
		"rim_color": rim_col,
		"inner_glow_color": inner_col,
		"grade_color": grade_col,
		"grade_strength": 0.42 + star_boost * 0.14,
		"star_boost": star_boost,
		"tint_strength": 0.78,
	}
