class_name ArcanaCardBuilder
extends RefCounted

## ArcanaCardBuilder.gd
## Generador visual procedural y controlador de tarjetas estilo Psycho-Pop para ArcanaSelectionModal.
## Construye de forma desacoplada la jerarquía visual de cada pacto arcano, etiquetas de atajo,
## deltas de estadísticas, descripciones de bendición/maldición y botones de confirmación.

const ArcanaStatsInspector = preload("res://scenes/ui/arcana/components/arcana_stats_inspector.gd")

const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_NEON_CYAN := Color("#00F0FF")
const COLOR_BOON_GREEN := Color("#44FF88")
const COLOR_CURSE_RED := Color("#FF3366")


static func build_card(
	arc: ArcanaData,
	index: int,
	on_chosen_callback: Callable,
	on_focused_callback: Callable,
	is_mouse_locked_callable: Callable
) -> Dictionary:
	var accent: Color = arc.color_accent if arc.color_accent != Color.BLACK else COLOR_NEON_CYAN

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(310, 490)
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	card_sb.border_color = accent
	card_sb.set_border_width_all(2)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(0)
	card_sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	card_sb.shadow_size = 10
	card_panel.add_theme_stylebox_override("panel", card_sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# 1. Indicador de Atajo de Teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 0.95))
	hotkey_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hotkey_lbl)

	# 2. Badge del Cuadrante
	var quad_badge := Label.new()
	quad_badge.text = "[ %s ]" % arc.get_quadrant_title().to_upper()
	quad_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quad_badge.add_theme_color_override("font_color", accent.lightened(0.2))
	quad_badge.add_theme_font_size_override("font_size", 10)
	vbox.add_child(quad_badge)

	# 3. Nombre de la Arcana
	var name_label := Label.new()
	name_label.text = arc.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 4. Separador decorativo neón
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = accent
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# 5. Icono o Glifo Central
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if arc.icon:
		icon_rect.texture = arc.icon
	icon_rect.modulate = accent
	vbox.add_child(icon_rect)

	# 6. Panel de alteraciones exactas de estadísticas (Stat Deltas Badges)
	var stat_deltas_box := VBoxContainer.new()
	stat_deltas_box.add_theme_constant_override("separation", 3)

	if arc.stat_modifiers.is_empty():
		var neutral_badge := Label.new()
		neutral_badge.text = "◈ PACTO SIN ALTERACIONES DIRECTAS ◈"
		neutral_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		neutral_badge.add_theme_font_size_override("font_size", 10)
		neutral_badge.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		stat_deltas_box.add_child(neutral_badge)
	else:
		for mod_key in arc.stat_modifiers.keys():
			var s_key := String(mod_key)
			var target_stat := StringName(s_key.trim_suffix("_pct"))
			var is_pct: bool = s_key.ends_with("_pct")
			var mod_val: float = float(arc.stat_modifiers[mod_key])

			var stat_display_name: String = ArcanaStatsInspector.get_stat_display_name(target_stat)
			var sign_str: String = "+" if mod_val > 0 else ""
			var val_str: String = ("%s%.0f%%" % [sign_str, mod_val * 100.0]) if is_pct else ("%s%.0f" % [sign_str, mod_val])
			var arrow_str: String = "▲" if mod_val >= 0 else "▼"
			var col_badge: Color = COLOR_BOON_GREEN if mod_val >= 0 else COLOR_CURSE_RED

			var badge_panel := PanelContainer.new()
			var badge_sb := StyleBoxFlat.new()
			badge_sb.bg_color = Color(col_badge.r, col_badge.g, col_badge.b, 0.12)
			badge_sb.border_color = col_badge
			badge_sb.border_width_left = 3
			badge_sb.set_border_width_all(1)
			badge_sb.set_corner_radius_all(2)
			badge_panel.add_theme_stylebox_override("panel", badge_sb)

			var badge_margin := MarginContainer.new()
			badge_margin.add_theme_constant_override("margin_left", 6)
			badge_margin.add_theme_constant_override("margin_right", 6)
			badge_margin.add_theme_constant_override("margin_top", 2)
			badge_margin.add_theme_constant_override("margin_bottom", 2)
			badge_panel.add_child(badge_margin)

			var badge_lbl := Label.new()
			badge_lbl.text = "%s %s  %s" % [arrow_str, val_str, stat_display_name]
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.add_theme_font_size_override("font_size", 11)
			badge_lbl.add_theme_color_override("font_color", col_badge)
			badge_margin.add_child(badge_lbl)

			stat_deltas_box.add_child(badge_panel)

	vbox.add_child(stat_deltas_box)

	# 7. Sección de Bendición (Boon)
	var boon_panel := PanelContainer.new()
	boon_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var boon_sb := StyleBoxFlat.new()
	boon_sb.bg_color = Color(0.05, 0.15, 0.08, 0.75)
	boon_sb.border_color = COLOR_BOON_GREEN
	boon_sb.border_width_left = 3
	boon_sb.set_corner_radius_all(0)
	boon_panel.add_theme_stylebox_override("panel", boon_sb)

	var boon_margin := MarginContainer.new()
	boon_margin.add_theme_constant_override("margin_left", 8)
	boon_margin.add_theme_constant_override("margin_right", 8)
	boon_margin.add_theme_constant_override("margin_top", 6)
	boon_margin.add_theme_constant_override("margin_bottom", 6)
	boon_panel.add_child(boon_margin)

	var boon_vbox := VBoxContainer.new()
	boon_vbox.add_theme_constant_override("separation", 2)
	boon_margin.add_child(boon_vbox)

	var boon_header := Label.new()
	boon_header.text = "▲ BENDICIÓN TÁCTICA"
	boon_header.add_theme_color_override("font_color", COLOR_BOON_GREEN)
	boon_header.add_theme_font_size_override("font_size", 11)
	boon_vbox.add_child(boon_header)

	var boon_desc := Label.new()
	boon_desc.text = arc.description_boon
	boon_desc.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	boon_desc.add_theme_font_size_override("font_size", 11)
	boon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boon_vbox.add_child(boon_desc)

	vbox.add_child(boon_panel)

	# 8. Sección de Maldición / Tributo (Curse)
	var curse_panel := PanelContainer.new()
	curse_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var curse_sb := StyleBoxFlat.new()
	curse_sb.bg_color = Color(0.2, 0.04, 0.06, 0.75)
	curse_sb.border_color = COLOR_CURSE_RED
	curse_sb.border_width_left = 3
	curse_sb.set_corner_radius_all(0)
	curse_panel.add_theme_stylebox_override("panel", curse_sb)

	var curse_margin := MarginContainer.new()
	curse_margin.add_theme_constant_override("margin_left", 8)
	curse_margin.add_theme_constant_override("margin_right", 8)
	curse_margin.add_theme_constant_override("margin_top", 6)
	curse_margin.add_theme_constant_override("margin_bottom", 6)
	curse_panel.add_child(curse_margin)

	var curse_vbox := VBoxContainer.new()
	curse_vbox.add_theme_constant_override("separation", 2)
	curse_margin.add_child(curse_vbox)

	var curse_header := Label.new()
	curse_header.text = "▼ TRIBUTO / MALDICIÓN"
	curse_header.add_theme_color_override("font_color", COLOR_CURSE_RED)
	curse_header.add_theme_font_size_override("font_size", 11)
	curse_vbox.add_child(curse_header)

	var curse_desc := Label.new()
	curse_desc.text = arc.description_curse
	curse_desc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	curse_desc.add_theme_font_size_override("font_size", 11)
	curse_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	curse_vbox.add_child(curse_desc)

	vbox.add_child(curse_panel)

	# 9. Botón de Selección con UIFocusHelper
	var btn := Button.new()
	btn.text = "PACTAR CON ARCANA [%d]" % (index + 1)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.focus_mode = Control.FOCUS_ALL

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_DEEP_BLACK
	btn_normal.border_color = accent
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = accent
	btn_hover.border_color = COLOR_PURE_WHITE
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_hover_color", COLOR_DEEP_BLACK)

	UIFocusHelper.apply_cyber_focus(btn)

	btn.pressed.connect(func():
		if is_mouse_locked_callable.call():
			return
		on_chosen_callback.call(arc)
	)
	btn.focus_entered.connect(func():
		on_focused_callback.call(index)
	)
	card_panel.mouse_entered.connect(func():
		on_focused_callback.call(index)
	)

	vbox.add_child(btn)

	return {
		"panel": card_panel,
		"button": btn
	}


static func apply_selection_style(
	panel: PanelContainer,
	button: Button,
	arc: ArcanaData,
	is_selected: bool
) -> void:
	if not is_instance_valid(panel) or not arc:
		return

	var accent: Color = arc.color_accent if arc.color_accent != Color.BLACK else COLOR_NEON_CYAN
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(0)

	if is_selected:
		sb.bg_color = Color(0.08, 0.10, 0.16, 0.98)
		sb.border_color = COLOR_PURE_WHITE
		sb.set_border_width_all(3)
		sb.border_width_top = 8
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.5)
		sb.shadow_size = 14
		if is_instance_valid(button):
			button.grab_focus()
	else:
		sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
		sb.border_color = accent * Color(1.0, 1.0, 1.0, 0.7)
		sb.set_border_width_all(2)
		sb.border_width_top = 5
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.2)
		sb.shadow_size = 6

	panel.add_theme_stylebox_override("panel", sb)
