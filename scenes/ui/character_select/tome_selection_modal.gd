class_name TomeSelectionModal
extends CanvasLayer

## TomeSelectionModal.gd
## Modal de selección y loadout de Tomos Arcanos de Atributos por Heroína/Piloto.
## Permite elegir qué tomos de estadísticas aparecerán durante las subidas de nivel.
## Exige un mínimo obligatorio de 6 tomos activos para evitar monopolios o exploits de pool reducida.

const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")

const MIN_ACTIVE_TOMES: int = 6

signal closed()
signal tomes_updated(char_id: StringName, active_tomes: Array[StringName])

var is_open: bool = false
var current_character_id: StringName = &"nova"
var active_tome_ids: Array[StringName] = []

var dim_overlay: ColorRect = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var warning_label: Label = null
var tomes_grid: GridContainer = null
var reset_button: Button = null
var close_button: Button = null

var _card_panels: Dictionary[StringName, PanelContainer] = {}
var _card_badges: Dictionary[StringName, Label] = {}
var _card_buttons: Array[Button] = []
var _warning_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	_build_ui()
	hide()


func _build_ui() -> void:
	dim_overlay = ColorRect.new()
	dim_overlay.name = "DimOverlay"
	dim_overlay.color = Color(0.01, 0.015, 0.03, 0.88)
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 620)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
	sb.border_color = Color(0, 0.85, 1, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0.85, 1, 0.25)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# 1. Header Row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	header_row.add_child(title_box)

	title_label = Label.new()
	title_label.text = "BIBLIOTECA DE TOMOS // LOADOUT DE ATRIBUTOS"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Selecciona qué tomos de estadísticas podrán aparecer durante el combate."
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	title_box.add_child(subtitle_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var counter_box := VBoxContainer.new()
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_child(counter_box)

	counter_label = Label.new()
	counter_label.add_theme_font_size_override("font_size", 16)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	counter_box.add_child(counter_label)

	var min_rule_label := Label.new()
	min_rule_label.text = "(MÍNIMO %d ACTIVOS OBLIGATORIOS)" % MIN_ACTIVE_TOMES
	min_rule_label.add_theme_font_size_override("font_size", 11)
	min_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	min_rule_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	counter_box.add_child(min_rule_label)

	# 2. Warning Label (Oculto / Flasheable)
	warning_label = Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 13)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)

	# 3. Scrollable Grid of Tomes
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	tomes_grid = GridContainer.new()
	tomes_grid.columns = 3
	tomes_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tomes_grid.add_theme_constant_override("h_separation", 12)
	tomes_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(tomes_grid)

	# 4. Actions Row (Footer)
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(actions_row)

	reset_button = Button.new()
	reset_button.text = "⚡ RESTAURAR TODOS (18)"
	reset_button.custom_minimum_size = Vector2(210, 42)
	reset_button.pressed.connect(_on_reset_pressed)
	UIFocusHelper.apply_cyber_focus(reset_button)
	actions_row.add_child(reset_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(bottom_spacer)

	close_button = Button.new()
	close_button.text = "CONFIRMAR Y CERRAR [ESC]"
	close_button.custom_minimum_size = Vector2(220, 42)
	close_button.pressed.connect(close_modal)
	UIFocusHelper.apply_cyber_focus(close_button)
	actions_row.add_child(close_button)


func open_modal(char_id: StringName = &"") -> void:
	if not char_id.is_empty():
		current_character_id = char_id

	is_open = true
	show()

	if SaveManager.has_method("get_character_active_tomes"):
		active_tome_ids = SaveManager.get_character_active_tomes(current_character_id)
	else:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()

	if active_tome_ids.size() < MIN_ACTIVE_TOMES:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
		if SaveManager.has_method("set_character_active_tomes"):
			SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	_update_header_text()
	_populate_grid()
	_update_counter_label()

	if close_button:
		close_button.grab_focus()


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()


func _update_header_text() -> void:
	if subtitle_label:
		subtitle_label.text = "PILOTO: %s — Activa o desactiva tomos para la subida de nivel." % [str(current_character_id).to_upper()]


func _update_counter_label() -> void:
	if not counter_label:
		return
	var count: int = active_tome_ids.size()
	var total: int = TomeCatalog.ALL_TOME_IDS.size()
	counter_label.text = "TOMOS ACTIVOS: %d / %d" % [count, total]
	if count <= MIN_ACTIVE_TOMES:
		counter_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))


func _populate_grid() -> void:
	if not tomes_grid:
		return

	for child in tomes_grid.get_children():
		child.queue_free()

	_card_panels.clear()
	_card_badges.clear()
	_card_buttons.clear()

	var all_tomes: Array = TomeCatalog.get_all_tomes()
	for tome in all_tomes:
		if not tome:
			continue
		var card := _build_tome_card(tome)
		tomes_grid.add_child(card)


func _build_tome_card(tome: TomeDataScript) -> Control:
	var tid: StringName = tome.tome_id
	var is_active: bool = active_tome_ids.has(tid)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 80)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = tome.icon
	hbox.add_child(icon_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = tome.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(name_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.text = "%s por nivel" % tome.get_bonus_description(1)
	bonus_lbl.add_theme_font_size_override("font_size", 11)
	bonus_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	vbox.add_child(bonus_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = tome.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	vbox.add_child(desc_lbl)

	var badge_lbl := Label.new()
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.custom_minimum_size = Vector2(76, 0)
	hbox.add_child(badge_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(btn)

	btn.pressed.connect(_on_card_pressed.bind(tid))
	UIFocusHelper.apply_cyber_focus(btn, true)

	_card_panels[tid] = panel
	_card_badges[tid] = badge_lbl
	_card_buttons.append(btn)

	_refresh_card_visual(tid, is_active)

	return panel


func _refresh_card_visual(tome_id: StringName, is_active: bool) -> void:
	var panel: PanelContainer = _card_panels.get(tome_id, null)
	var badge: Label = _card_badges.get(tome_id, null)
	if not panel or not badge:
		return

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)

	if is_active:
		style.bg_color = Color(0.04, 0.08, 0.15, 0.95)
		style.set_border_width_all(2)
		style.border_color = Color(0.15, 0.75, 1.0, 0.85)
		style.shadow_color = Color(0, 0.85, 1, 0.15)
		style.shadow_size = 4
		panel.modulate = Color.WHITE
		badge.text = "[ ACTIVO ]"
		badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	else:
		style.bg_color = Color(0.02, 0.03, 0.05, 0.75)
		style.set_border_width_all(1)
		style.border_color = Color(0.35, 0.25, 0.25, 0.6)
		panel.modulate = Color(0.55, 0.55, 0.55, 0.6)
		badge.text = "[ EXCLUIDO ]"
		badge.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))

	panel.add_theme_stylebox_override("panel", style)


func _on_card_pressed(tome_id: StringName) -> void:
	var is_active: bool = active_tome_ids.has(tome_id)

	if is_active:
		if active_tome_ids.size() <= MIN_ACTIVE_TOMES:
			_show_warning("¡MÍNIMO %d TOMOS OBLIGATORIOS PARA DESPLEGAR!" % MIN_ACTIVE_TOMES)
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx(&"ui_error", 0.0, 0.9)
			return

		active_tome_ids.erase(tome_id)
		_refresh_card_visual(tome_id, false)
	else:
		active_tome_ids.append(tome_id)
		_refresh_card_visual(tome_id, true)

	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	_update_counter_label()
	tomes_updated.emit(current_character_id, active_tome_ids)


func _on_reset_pressed() -> void:
	active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	for tid: StringName in TomeCatalog.ALL_TOME_IDS:
		_refresh_card_visual(tid, true)

	_update_counter_label()
	tomes_updated.emit(current_character_id, active_tome_ids)


func _show_warning(msg: String) -> void:
	if not warning_label:
		return
	warning_label.text = msg
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	warning_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	_warning_tween = create_tween()
	_warning_tween.tween_interval(1.8)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.4)
