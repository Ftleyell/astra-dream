class_name LevelUpCardBuilder
extends RefCounted

## LevelUpCardBuilder.gd
## Generador visual procedural y controlador de estilos de tarjetas de mejora para LevelUpModal.
## Construye las cartas de nivel con icono representativo, tier de rareza, valor numérico
## destacado y botón de selección compacto para evitar clicks involuntarios.

const LevelUpStatsInspector = preload("res://scenes/ui/level_up/components/level_up_stats_inspector.gd")

const STAT_ICON_MAP: Dictionary = {
	&"base_damage": "res://assets/icons/items/icon_sword.svg",
	&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
	&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
	&"crit_damage": "res://assets/icons/items/icon_lens.svg",
	&"max_health": "res://assets/icons/items/icon_heart.svg",
	&"move_speed": "res://assets/icons/items/icon_boots.svg",
	&"luck": "res://assets/icons/items/icon_clover.svg",
	&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
	&"armor": "res://assets/icons/items/icon_shield.svg",
	&"health_regen": "res://assets/icons/items/icon_apple.svg",
	&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
}


static func get_tier_info(tier: Enums.Tier) -> Dictionary:
	match tier:
		Enums.Tier.TIER_1:
			return {
				"name": "TIER 1 (Común)",
				"color": Color(0.5, 0.8, 1.0, 0.95)
			}
		Enums.Tier.TIER_2:
			return {
				"name": "TIER 2 (Poco Común)",
				"color": Color(0.2, 0.95, 0.4, 0.95)
			}
		Enums.Tier.TIER_3:
			return {
				"name": "TIER 3 (Raro)",
				"color": Color(1.0, 0.8, 0.15, 1.0)
			}
		Enums.Tier.TIER_4:
			return {
				"name": "TIER 4 (Legendario)",
				"color": Color(0.9, 0.35, 1.0, 1.0)
			}
		_:
			return {
				"name": "TIER 1",
				"color": Color.WHITE
			}


static func build_stat_card(
	card: StatCardData,
	index: int,
	on_chosen_callback: Callable,
	on_focused_callback: Callable,
	is_mouse_locked_callable: Callable
) -> Dictionary:
	# Respaldo automático de icono según la estadística afectada si viene nulo
	if not card.icon:
		var stat_key: StringName = card.target_stat
		if STAT_ICON_MAP.has(stat_key) and ResourceLoader.exists(STAT_ICON_MAP[stat_key]):
			card.icon = load(STAT_ICON_MAP[stat_key]) as Texture2D

	var tier_info: Dictionary = get_tier_info(card.tier)
	var tier_color: Color = tier_info["color"]

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(240, 320)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	card_style.set_border_width_all(2)
	card_style.border_color = tier_color * Color(1.0, 1.0, 1.0, 0.5)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10.0)
	card_panel.add_theme_stylebox_override("panel", card_style)

	# Foco visual al pasar el cursor sobre la carta
	card_panel.mouse_entered.connect(func():
		on_focused_callback.call(index)
	)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	# Etiqueta de Tier con color indicador
	var tier_lbl := Label.new()
	tier_lbl.text = tier_info["name"]
	tier_lbl.modulate = tier_color
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 12)

	# Marco contenedor del icono de 64x64 px centrado
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = tier_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.icon:
		icon_rect.texture = card.icon
		icon_rect.modulate = tier_color
	icon_panel.add_child(icon_rect)

	# Formato de valor y nombre para lectura instantánea
	var stat_name_display: String = LevelUpStatsInspector.get_stat_display_name(card.target_stat)
	var mod_sign: String = "+" if card.modifier_value > 0 else ""
	var mod_text: String = ""
	if card.is_percentage:
		mod_text = "%s%.0f%%" % [mod_sign, card.modifier_value * 100.0]
	elif card.target_stat == &"health_regen":
		mod_text = "%s%.1f/s" % [mod_sign, card.modifier_value]
	else:
		mod_text = "%s%.0f" % [mod_sign, card.modifier_value]

	# Hero badge: Valor numérico destacado (26pt)
	var hero_val_lbl := Label.new()
	hero_val_lbl.name = "HeroValueBadge"
	hero_val_lbl.text = mod_text
	hero_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_val_lbl.add_theme_font_size_override("font_size", 26)
	hero_val_lbl.add_theme_color_override("font_color", Color("#00FF9D") if card.modifier_value >= 0 else Color("#FF4466"))

	# Etiqueta de Atributo concisa
	var stat_lbl := Label.new()
	stat_lbl.name = "StatNameLabel"
	stat_lbl.text = stat_name_display
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	stat_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_lbl.add_theme_font_size_override("font_size", 13)
	stat_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	# Botón de selección interactivo compacto (110x30, evita miss-clicks)
	var select_btn := Button.new()
	select_btn.text = "Elegir [%d]" % (index + 1)
	select_btn.custom_minimum_size = Vector2(110, 30)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select_btn.add_theme_font_size_override("font_size", 12)
	select_btn.add_theme_color_override("font_color", tier_color.lightened(0.2))

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	btn_normal.border_color = tier_color
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.12, 0.20, 0.32, 0.98)
	btn_hover.border_color = tier_color.lightened(0.3)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color = Color(0.15, 0.24, 0.38, 0.98)
	btn_focus.border_color = Color.WHITE
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(5)
	btn_focus.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("focus", btn_focus)

	select_btn.pressed.connect(func():
		if is_mouse_locked_callable.call():
			return
		on_chosen_callback.call(card)
	)
	select_btn.focus_entered.connect(func():
		on_focused_callback.call(index)
	)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(tier_lbl)
	vbox.add_child(icon_panel)
	vbox.add_child(hero_val_lbl)
	vbox.add_child(stat_lbl)
	vbox.add_child(select_btn)
	card_panel.add_child(vbox)

	return {
		"panel": card_panel,
		"button": select_btn,
		"tier_color": tier_color
	}


static func apply_card_selection_style(
	panel: PanelContainer,
	button: Button,
	color: Color,
	is_selected: bool
) -> void:
	if not is_instance_valid(panel):
		return

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)

	if is_selected:
		style.bg_color = Color(0.10, 0.14, 0.22, 0.98)
		style.set_border_width_all(3)
		style.border_color = color.lightened(0.3)
		style.shadow_color = color * Color(1.0, 1.0, 1.0, 0.45)
		style.shadow_size = 8
		if is_instance_valid(button):
			button.grab_focus()
	else:
		style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
		style.set_border_width_all(2)
		style.border_color = color * Color(1.0, 1.0, 1.0, 0.5)
		style.shadow_size = 0

	panel.add_theme_stylebox_override("panel", style)
