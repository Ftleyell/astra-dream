class_name ShaderSkinSwatch
extends ColorRect
## Emblema ligero zero-SubViewport que renderiza la paleta real de un PilotSkinPreset
## usando shader_skin_swatch.gdshader para tarjetas densas (Armario, Resumen, Carrusel lateral).

const SWATCH_SHADER := preload("res://scenes/pilots/shaders/shader_skin_swatch.gdshader")

var _mat: ShaderMaterial = null
var _preset: PilotSkinPreset = null
var _category_mode: int = 0
var _star_level: int = 1
var _is_locked: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_ensure_material()


func _ensure_material() -> void:
	if _mat != null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = SWATCH_SHADER
	material = _mat


func configure_swatch(
	preset: PilotSkinPreset,
	category: String,
	star_level: int = 1,
	is_locked: bool = false,
	is_follow_pilot: bool = false
) -> void:
	_ensure_material()
	_preset = preset
	_star_level = clampi(star_level, 1, 3)
	_is_locked = is_locked
	if is_follow_pilot:
		_category_mode = 3
	elif category == "wings" or category == "ship":
		_category_mode = 1
	elif category == "weapon":
		_category_mode = 2
	else:
		_category_mode = 0

	var acc: Color = preset.accent_color if preset != null else Color(0.86, 0.18, 0.32, 1.0)
	var pan: Color = preset.panel_color if preset != null else Color(0.36, 0.38, 0.44, 1.0)
	var drk: Color = preset.suit_dark_color if preset != null else Color(0.16, 0.15, 0.20, 1.0)
	var har: Color = preset.hair_color if preset != null else Color(0.86, 0.88, 0.94, 1.0)

	_mat.set_shader_parameter("accent_color", acc)
	_mat.set_shader_parameter("panel_color", pan)
	_mat.set_shader_parameter("suit_dark_color", drk)
	_mat.set_shader_parameter("hair_color", har)
	_mat.set_shader_parameter("category_mode", _category_mode)
	_mat.set_shader_parameter("star_level", _star_level)
	_mat.set_shader_parameter("is_locked", _is_locked)


func get_category_mode() -> int:
	return _category_mode
