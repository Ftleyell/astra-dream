class_name ShaderSkinEntry
extends Resource
## Entrada de catálogo cosmético 100% por shader para pilotos v2 (Piloto, Alas o Arma Orbital).

@export var id: String = ""
@export_enum("pilot", "wings", "weapon") var category: String = "pilot"
@export var target_id: StringName = &"valentina"
@export var target_name: String = "Valentina"
@export var skin_name: String = ""
@export_multiline var description: String = ""
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export var preset: PilotSkinPreset = null


func to_cosmetic_dict() -> Dictionary:
	var accent_col: Color = preset.accent_color if preset != null else Color(0.86, 0.18, 0.32, 1.0)
	var panel_col: Color = preset.panel_color if preset != null else Color(0.36, 0.38, 0.44, 1.0)
	var dark_col: Color = preset.suit_dark_color if preset != null else Color(0.16, 0.15, 0.20, 1.0)
	var hair_col: Color = preset.hair_color if preset != null else Color(0.86, 0.88, 0.94, 1.0)
	var palette_id: String = preset.id if preset != null else ""
	var preset_path: String = preset.resource_path if preset != null else ""
	var accent_hex: String = "#" + accent_col.to_html(false)
	return {
		"id": id,
		"category": category,
		"target_id": String(target_id).to_lower(),
		"target_name": target_name,
		"palette_id": palette_id,
		"skin_name": skin_name,
		"description": description,
		"rarity": rarity,
		"is_shader_skin": true,
		"render_mode": "shader_v2",
		"preset_path": preset_path,
		"glow_hex": accent_hex,
		"accent_hex": accent_hex,
		"panel_hex": "#" + panel_col.to_html(false),
		"suit_dark_hex": "#" + dark_col.to_html(false),
		"hair_hex": "#" + hair_col.to_html(false),
		"texture_path": "",
	}
