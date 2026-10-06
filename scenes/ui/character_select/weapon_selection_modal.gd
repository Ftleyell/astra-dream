class_name WeaponSelectionModal
extends CanvasLayer

## WeaponSelectionModal.gd
## Modal de selección y loadout de Armas adicionales del Arsenal por Heroína/Piloto.
## Permite elegir qué armas de la tienda/pool aparecerán durante las subidas de nivel.
## Exige un mínimo obligatorio de 8 armas activas para evitar monopolios o exploits de pool reducida.

const WeaponCatalog = preload("res://data/weapons/weapon_catalog.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")

const MIN_ACTIVE_WEAPONS: int = 8

@export_group("Dimensiones de Ventana")
@export var modal_size: Vector2 = Vector2(1060, 620)
@export var margin_horizontal: int = 24
@export var margin_vertical: int = 20
@export var content_separation: int = 14

@export_group("Cuadrícula de Armas")
@export var grid_columns: int = 3
@export var grid_h_separation: int = 12
@export var grid_v_separation: int = 10

@export_group("Dimensiones de Tarjetas")
@export var card_size: Vector2 = Vector2(310, 80)
@export var icon_size: Vector2 = Vector2(40, 40)
@export var badge_min_width: float = 76.0

@export_group("Reglas de Pool")
@export var min_active_weapons: int = 8

signal closed()
signal weapons_updated(char_id: StringName, active_weapons: Array[StringName])

var is_open: bool = false
var current_character_id: StringName = &"nova"
var active_weapon_ids: Array[StringName] = []

var dim_overlay: ColorRect = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var min_rule_label: Label = null
var warning_label: Label = null
var weapons_grid: GridContainer = null

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
	dim_overlay.color = Color(0.015, 0.02, 0.04, 0.92)
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var blur_shader: Shader = preload("res://shaders/screen_blur.gdshader")
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_mat.set_shader_parameter("blur_amount", 2.8)
	blur_mat.set_shader_parameter("tint_color", Color(0.015, 0.02, 0.05, 0.85))
	dim_overlay.material = blur_mat

	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_overlay.gui_input.connect(_on_dim_overlay_gui_input)

	add_child(dim_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	dim_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = modal_size
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
	margin.add_theme_constant_override("margin_left", margin_horizontal)
	margin.add_theme_constant_override("margin_top", margin_vertical)
	margin.add_theme_constant_override("margin_right", margin_horizontal)
	margin.add_theme_constant_override("margin_bottom", margin_vertical)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", content_separation)
	margin.add_child(root_vbox)

	# 1. Header Row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	header_row.add_child(title_box)

	title_label = Label.new()
	title_label.text = "ARSENAL DE ARMAS // POOL DE SALVAS"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Selecciona qué armas adicionales podrán aparecer durante el combate."
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

	min_rule_label = Label.new()
	min_rule_label.text = "(MÍNIMO %d ACTIVAS OBLIGATORIAS)" % min_active_weapons
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

	# 3. Scrollable Grid of Weapons
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	weapons_grid = GridContainer.new()
	weapons_grid.columns = grid_columns
	weapons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_grid.add_theme_constant_override("h_separation", grid_h_separation)
	weapons_grid.add_theme_constant_override("v_separation", grid_v_separation)
	scroll.add_child(weapons_grid)

	# 4. Actions Row (Footer Hint)
	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [ESC] O CLIC EN EL FONDO PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)


func open_modal(char_id: StringName = &"") -> void:
	if not char_id.is_empty():
		current_character_id = char_id

	is_open = true
	show()

	if SaveManager.has_method("get_character_active_weapons"):
		active_weapon_ids = SaveManager.get_character_active_weapons(current_character_id)
	else:
		active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()

	if active_weapon_ids.size() < min_active_weapons:
		active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()
		if SaveManager.has_method("set_character_active_weapons"):
			SaveManager.set_character_active_weapons(current_character_id, active_weapon_ids)

	if min_rule_label:
		min_rule_label.text = "(MÍNIMO %d ACTIVAS OBLIGATORIAS)" % min_active_weapons

	_update_header_text()
	_populate_grid()
	_update_counter_label()

	if _card_buttons.size() > 0 and is_instance_valid(_card_buttons[0]):
		_card_buttons[0].call_deferred("grab_focus")


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport():
			get_viewport().set_input_as_handled()
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(&"ui_click", 0.0, 1.0)
		close_modal()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return


func _update_header_text() -> void:
	if subtitle_label:
		subtitle_label.text = "PILOTO: %s — Activa o desactiva armas para la subida de nivel." % [str(current_character_id).to_upper()]


func _update_counter_label() -> void:
	if not counter_label:
		return
	var count: int = active_weapon_ids.size()
	var total: int = WeaponCatalog.POOL_WEAPON_IDS.size()
	counter_label.text = "ARMAS ACTIVAS: %d / %d" % [count, total]
	if count <= min_active_weapons:
		counter_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))


func _populate_grid() -> void:
	if not weapons_grid:
		return

	for child in weapons_grid.get_children():
		child.queue_free()

	_card_panels.clear()
	_card_badges.clear()
	_card_buttons.clear()

	var pool_weapons: Array[WeaponData] = WeaponCatalog.get_pool_weapons()
	for weapon in pool_weapons:
		if not weapon:
			continue
		var card := _build_weapon_card(weapon)
		weapons_grid.add_child(card)


func _build_weapon_card(weapon: WeaponData) -> Control:
	var wid: StringName = weapon.weapon_id
	var is_active: bool = active_weapon_ids.has(wid)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = card_size
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
	icon_rect.custom_minimum_size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = weapon.icon
	hbox.add_child(icon_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = weapon.get_display_name()
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Daño: %d | Recarga: %.2fs" % [int(weapon.base_damage), weapon.base_cooldown]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	vbox.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = weapon.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	vbox.add_child(desc_lbl)

	var badge_lbl := Label.new()
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.custom_minimum_size = Vector2(badge_min_width, 0)
	hbox.add_child(badge_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(btn)

	btn.pressed.connect(_on_card_pressed.bind(wid))
	UIFocusHelper.apply_cyber_focus(btn, true)

	_card_panels[wid] = panel
	_card_badges[wid] = badge_lbl
	_card_buttons.append(btn)

	_refresh_card_visual(wid, is_active)

	return panel


func _refresh_card_visual(weapon_id: StringName, is_active: bool) -> void:
	var panel: PanelContainer = _card_panels.get(weapon_id, null)
	var badge: Label = _card_badges.get(weapon_id, null)
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


func _on_card_pressed(weapon_id: StringName) -> void:
	var is_active: bool = active_weapon_ids.has(weapon_id)

	if is_active:
		if active_weapon_ids.size() <= min_active_weapons:
			_show_warning("¡MÍNIMO %d ARMAS OBLIGATORIAS PARA DESPLEGAR!" % min_active_weapons)
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx(&"ui_error", 0.0, 0.9)
			return

		active_weapon_ids.erase(weapon_id)
		_refresh_card_visual(weapon_id, false)
	else:
		active_weapon_ids.append(weapon_id)
		_refresh_card_visual(weapon_id, true)

	if SaveManager.has_method("set_character_active_weapons"):
		SaveManager.set_character_active_weapons(current_character_id, active_weapon_ids)

	_update_counter_label()
	weapons_updated.emit(current_character_id, active_weapon_ids)


func _on_reset_pressed() -> void:
	active_weapon_ids = WeaponCatalog.POOL_WEAPON_IDS.duplicate()
	if SaveManager.has_method("set_character_active_weapons"):
		SaveManager.set_character_active_weapons(current_character_id, active_weapon_ids)

	for wid: StringName in WeaponCatalog.POOL_WEAPON_IDS:
		_refresh_card_visual(wid, true)

	_update_counter_label()
	weapons_updated.emit(current_character_id, active_weapon_ids)


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
