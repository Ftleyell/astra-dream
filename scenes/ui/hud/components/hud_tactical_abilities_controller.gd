class_name HUDTacticalAbilitiesController
extends RefCounted

## HUDTacticalAbilitiesController.gd
## Controlador especializado para la barra de habilidades tácticas en el HUD:
## - Indicadores y cooldowns de Dash con medidor de recarga y modo Enfoque.
## - Enfriamiento de Láser táctico con sweep visual y etiqueta de tiempo.
## - Cargas de Bombas espaciales con pips iluminados y overlay de agotado.
## - Conmutador visual de Auto-Aim vs Apuntado Manual.

var dash_button_body: Control
var dash_cd_overlay: ColorRect
var dash_cd_num: Label
var dash_pip_1: Panel
var dash_pip_2: Panel
var dash_label: Label

var laser_button_body: Control
var laser_cd_overlay: ColorRect
var laser_cd_num: Label
var laser_cd_label: Label

var bomb_button_body: Control
var bomb_overlay: ColorRect
var bomb_pip_1: Panel
var bomb_pip_2: Panel
var bomb_pip_3: Panel
var bomb_label: Label

var aim_mode_label: Label

var _pip_lit_style: StyleBoxFlat
var _pip_dim_style: StyleBoxFlat
var _bomb_pip_lit_style: StyleBoxFlat
var _bomb_pip_dim_style: StyleBoxFlat

func setup(elements: Dictionary) -> void:
	dash_button_body = elements.get("dash_button_body") as Control
	dash_cd_overlay = elements.get("dash_cd_overlay") as ColorRect
	dash_cd_num = elements.get("dash_cd_num") as Label
	dash_pip_1 = elements.get("dash_pip_1") as Panel
	dash_pip_2 = elements.get("dash_pip_2") as Panel
	dash_label = elements.get("dash_label") as Label

	laser_button_body = elements.get("laser_button_body") as Control
	laser_cd_overlay = elements.get("laser_cd_overlay") as ColorRect
	laser_cd_num = elements.get("laser_cd_num") as Label
	laser_cd_label = elements.get("laser_cd_label") as Label

	bomb_button_body = elements.get("bomb_button_body") as Control
	bomb_overlay = elements.get("bomb_overlay") as ColorRect
	bomb_pip_1 = elements.get("bomb_pip_1") as Panel
	bomb_pip_2 = elements.get("bomb_pip_2") as Panel
	bomb_pip_3 = elements.get("bomb_pip_3") as Panel
	bomb_label = elements.get("bomb_label") as Label

	aim_mode_label = elements.get("aim_mode_label") as Label

	_setup_styles()

func _setup_styles() -> void:
	_pip_lit_style = StyleBoxFlat.new()
	_pip_lit_style.bg_color = Color(0.1, 0.95, 0.8, 1.0)
	_pip_lit_style.set_corner_radius_all(3)
	_pip_lit_style.shadow_color = Color(0.0, 0.9, 1.0, 0.6)
	_pip_lit_style.shadow_size = 4

	_pip_dim_style = StyleBoxFlat.new()
	_pip_dim_style.bg_color = Color(0.08, 0.14, 0.22, 0.55)
	_pip_dim_style.set_border_width_all(1)
	_pip_dim_style.border_color = Color(0.15, 0.25, 0.38, 0.5)
	_pip_dim_style.set_corner_radius_all(3)

	_bomb_pip_lit_style = StyleBoxFlat.new()
	_bomb_pip_lit_style.bg_color = Color(1.0, 0.35, 1.0, 1.0)
	_bomb_pip_lit_style.set_corner_radius_all(3)
	_bomb_pip_lit_style.shadow_color = Color(1.0, 0.2, 1.0, 0.7)
	_bomb_pip_lit_style.shadow_size = 4

	_bomb_pip_dim_style = StyleBoxFlat.new()
	_bomb_pip_dim_style.bg_color = Color(0.12, 0.08, 0.16, 0.55)
	_bomb_pip_dim_style.set_border_width_all(1)
	_bomb_pip_dim_style.border_color = Color(0.28, 0.18, 0.35, 0.5)
	_bomb_pip_dim_style.set_corner_radius_all(3)

func update_dash(current_charges: int, max_charges: int, recharge_ratio: float, is_focus: bool, dash_max_time: float) -> void:
	if dash_pip_1:
		dash_pip_1.add_theme_stylebox_override("panel", _pip_lit_style if current_charges >= 1 else _pip_dim_style)
	if dash_pip_2:
		dash_pip_2.add_theme_stylebox_override("panel", _pip_lit_style if current_charges >= 2 else _pip_dim_style)

	var is_recharging: bool = (current_charges < max_charges)
	if is_recharging:
		var cd_fraction: float = clampf(1.0 - recharge_ratio, 0.0, 1.0)
		if dash_cd_overlay and dash_button_body:
			dash_cd_overlay.visible = true
			var h: float = dash_button_body.size.y if dash_button_body.size.y > 0.0 else 88.0
			var w: float = dash_button_body.size.x if dash_button_body.size.x > 0.0 else 88.0
			dash_cd_overlay.size = Vector2(w, h * cd_fraction)
			dash_cd_overlay.position = Vector2.ZERO

		if dash_cd_num:
			dash_cd_num.visible = true
			var time_left: float = maxf(0.0, dash_max_time * (1.0 - recharge_ratio))
			dash_cd_num.text = "%.1f" % time_left
	else:
		if dash_cd_overlay:
			dash_cd_overlay.visible = false
		if dash_cd_num:
			dash_cd_num.visible = false
			dash_cd_num.text = ""

	if dash_label:
		if is_focus:
			dash_label.text = "ENFOQUE"
			dash_label.modulate = Color(1.0, 0.3, 0.9, 1.0)
		elif current_charges > 0:
			dash_label.text = "[LISTO]"
			dash_label.modulate = Color(0.3, 1.0, 0.6, 1.0)
		else:
			dash_label.text = "[%d%%]" % int(recharge_ratio * 100.0)
			dash_label.modulate = Color(0.7, 0.7, 0.7, 1.0)

func update_laser_cooldown(current: float, max_val: float) -> void:
	if current <= 0.0:
		if laser_cd_overlay:
			laser_cd_overlay.visible = false
		if laser_cd_num:
			laser_cd_num.visible = false
			laser_cd_num.text = ""
		if laser_cd_label:
			laser_cd_label.text = "[LISTO]"
			laser_cd_label.modulate = Color(0.2, 1.0, 1.0, 1.0)
	else:
		var cd_fraction: float = clampf(current / maxf(0.001, max_val), 0.0, 1.0)
		if laser_cd_overlay and laser_button_body:
			laser_cd_overlay.visible = true
			var h: float = laser_button_body.size.y if laser_button_body.size.y > 0.0 else 88.0
			var w: float = laser_button_body.size.x if laser_button_body.size.x > 0.0 else 88.0
			laser_cd_overlay.size = Vector2(w, h * cd_fraction)
			laser_cd_overlay.position = Vector2.ZERO

		if laser_cd_num:
			laser_cd_num.visible = true
			laser_cd_num.text = "%.1f" % current

		if laser_cd_label:
			laser_cd_label.text = "[%.1fs]" % current
			laser_cd_label.modulate = Color(1.0, 0.7, 0.2, 1.0)

func update_bomb_count(remaining: int) -> void:
	if bomb_pip_1:
		bomb_pip_1.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 1 else _bomb_pip_dim_style)
	if bomb_pip_2:
		bomb_pip_2.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 2 else _bomb_pip_dim_style)
	if bomb_pip_3:
		bomb_pip_3.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 3 else _bomb_pip_dim_style)

	if bomb_overlay:
		bomb_overlay.visible = (remaining <= 0)
		if remaining <= 0:
			bomb_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	if bomb_label:
		bomb_label.text = "x%d" % remaining

func update_aim_mode(is_manual: bool) -> void:
	if not aim_mode_label:
		return
	if is_manual:
		aim_mode_label.text = "[E] AIM: MANUAL"
		aim_mode_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 1.0))
	else:
		aim_mode_label.text = "[E] AIM: AUTO"
		aim_mode_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
