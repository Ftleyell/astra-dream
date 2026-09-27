class_name SkinSelectionModal
extends CanvasLayer

## Modal compacto y específico para seleccionar y equipar skins de un elemento
## (Nave, Piloto, Arma, Mascota o Navegadora).

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

signal skin_selected(slot_key: String, skin_id: String)
signal closed()
signal open_gacha_requested()

var is_open: bool = false
var _category: String = ""
var _target_id: String = ""
var _slot_key: String = ""
var _default_texture: Texture2D = null

var _selected_skin_id: String = ""
var _preview_stars: int = 1

# Nodos construidos o referenciados
var _title_label: Label
var _preview_icon: TextureRect
var _preview_title: Label
var _preview_desc: Label
var _equip_btn: Button
var _default_btn: Button
var _gacha_btn: Button
var _close_btn: Button
var _grid_container: GridContainer
var _item_buttons: Array[Button] = []

func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "DimOverlay"
	dim.color = Color(0.01, 0.01, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.14, 0.98)
	sb.border_color = Color(0.1, 0.85, 1.0, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(root_vbox)

	# Header
	var header_bar := HBoxContainer.new()
	root_vbox.add_child(header_bar)

	_title_label = Label.new()
	_title_label.text = "🎨 SELECTOR DE SKINS"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	header_bar.add_child(_title_label)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(h_spacer)

	_close_btn = Button.new()
	_close_btn.text = " ✖ CERRAR "
	_close_btn.pressed.connect(close_modal)
	UIFocusHelper.apply_cyber_focus(_close_btn)
	header_bar.add_child(_close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Main Columns (Left: Preview, Right: Grid of skins)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	root_vbox.add_child(cols)

	# Left Column: Preview & Action
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(300, 0)
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left_box.add_theme_constant_override("separation", 12)
	cols.add_child(left_box)

	var prev_frame := PanelContainer.new()
	prev_frame.custom_minimum_size = Vector2(260, 240)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.03, 0.02, 0.08, 0.9)
	fsb.border_color = Color(0.5, 0.3, 0.9, 0.7)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(10)
	prev_frame.add_theme_stylebox_override("panel", fsb)
	left_box.add_child(prev_frame)

	var prev_center := CenterContainer.new()
	prev_frame.add_child(prev_center)

	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = Vector2(160, 160)
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_center.add_child(_preview_icon)

	_preview_title = Label.new()
	_preview_title.text = "Por Defecto"
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_title.add_theme_font_size_override("font_size", 16)
	_preview_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	left_box.add_child(_preview_title)

	_preview_desc = Label.new()
	_preview_desc.text = "Apariencia original"
	_preview_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_desc.add_theme_font_size_override("font_size", 12)
	_preview_desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.8))
	left_box.add_child(_preview_desc)

	_equip_btn = Button.new()
	_equip_btn.text = "✅ EQUIPAR SKIN"
	_equip_btn.custom_minimum_size = Vector2(240, 44)
	_equip_btn.pressed.connect(_on_equip_pressed)
	UIFocusHelper.apply_cyber_focus(_equip_btn)
	left_box.add_child(_equip_btn)

	_default_btn = Button.new()
	_default_btn.text = "⚪ USAR POR DEFECTO"
	_default_btn.custom_minimum_size = Vector2(240, 36)
	_default_btn.pressed.connect(_on_default_pressed)
	UIFocusHelper.apply_cyber_focus(_default_btn)
	left_box.add_child(_default_btn)

	# Right Column: List & Gacha link
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 10)
	cols.add_child(right_box)

	var list_header := Label.new()
	list_header.text = "COLECCIÓN DESBLOQUEADA"
	list_header.add_theme_font_size_override("font_size", 13)
	list_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.8))
	right_box.add_child(list_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(scroll)

	_grid_container = GridContainer.new()
	_grid_container.columns = 3
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.add_theme_constant_override("h_separation", 12)
	_grid_container.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid_container)

	_gacha_btn = Button.new()
	_gacha_btn.text = "🎰 CONSEGUIR MÁS SKINS EN LA MÁQUINA GACHA"
	_gacha_btn.custom_minimum_size = Vector2(0, 40)
	_gacha_btn.pressed.connect(_on_gacha_btn_pressed)
	UIFocusHelper.apply_cyber_focus(_gacha_btn)
	right_box.add_child(_gacha_btn)

func open_for_target(category: String, target_id: String, display_title: String, default_texture: Texture2D) -> void:
	_category = category
	_target_id = target_id
	_slot_key = "%s:%s" % [category, target_id]
	_default_texture = default_texture
	_selected_skin_id = SaveManager.get_equipped_skin(_slot_key)
	_title_label.text = "🎨 SKINS PARA: %s" % display_title.to_upper()

	is_open = true
	show()
	_populate_grid()
	_update_preview()
	get_tree().paused = true

	if not _item_buttons.is_empty():
		_item_buttons[0].grab_focus()
	elif _equip_btn:
		_equip_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false
	closed.emit()

func _populate_grid() -> void:
	for child in _grid_container.get_children():
		_grid_container.remove_child(child)
		child.queue_free()
	_item_buttons.clear()

	var unlocked_dict := SaveManager.get_unlocked_skins()
	var all_target_skins := CosmeticsManager.get_skins_for_target(_category, _target_id)
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)

	# 1. Botón Por Defecto
	var def_btn := _create_mini_card(
		"Por Defecto",
		"Original",
		0,
		_default_texture,
		"",
		_selected_skin_id.is_empty(),
		currently_equipped.is_empty()
	)
	_grid_container.add_child(def_btn)
	_item_buttons.append(def_btn)

	# 2. Skins desbloqueadas
	for skin in all_target_skins:
		var sid: String = skin.get("id", "")
		if not unlocked_dict.has(sid):
			continue # Solo mostrar adquiridas en este selector específico

		var stars: int = SaveManager.get_skin_stars(sid)
		var tex_path: String = skin.get("texture_path", "")
		var tex: Texture2D = CosmeticsManager.load_texture(tex_path)
		var is_selected: bool = (_selected_skin_id == sid)
		var is_equipped: bool = (currently_equipped == sid)

		var card := _create_mini_card(
			skin.get("skin_name", "Skin"),
			"%d★" % stars,
			stars,
			tex,
			sid,
			is_selected,
			is_equipped
		)
		_grid_container.add_child(card)
		_item_buttons.append(card)

func _create_mini_card(name_txt: String, sub_txt: String, stars: int, tex: Texture2D, sid: String, is_selected: bool, is_equipped: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 110)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.18, 0.95)
	if is_selected:
		sb.border_color = Color(0.2, 1.0, 0.8, 1.0)
		sb.set_border_width_all(2)
	elif is_equipped:
		sb.border_color = Color(1.0, 0.85, 0.2, 0.9)
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(0.3, 0.3, 0.5, 0.5)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	if not sid.is_empty():
		CosmeticsManager.apply_skin_to_canvas_item(icon, sid, stars)
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = name_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl)

	var tag := Label.new()
	if is_equipped:
		tag.text = "✅ EQUIPADA"
		tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	elif stars > 0:
		var s := ""
		for i in range(stars):
			s += "⭐"
		tag.text = s
		tag.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
	else:
		tag.text = sub_txt
		tag.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	vbox.add_child(tag)

	btn.pressed.connect(func():
		_selected_skin_id = sid
		_update_preview()
		_populate_grid()
	)
	UIFocusHelper.apply_cyber_focus(btn)
	return btn

func _update_preview() -> void:
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)
	var is_this_equipped: bool = (_selected_skin_id == currently_equipped)

	if _selected_skin_id.is_empty():
		_preview_icon.texture = _default_texture
		_preview_icon.material = null
		_preview_title.text = "Por Defecto"
		_preview_title.modulate = Color.WHITE
		_preview_desc.text = "Apariencia original del sistema"
		_equip_btn.text = "✅ EQUIPAR POR DEFECTO"
		_equip_btn.disabled = is_this_equipped
	else:
		var skin := CosmeticsManager.get_skin(_selected_skin_id)
		var stars: int = SaveManager.get_skin_stars(_selected_skin_id)
		_preview_stars = stars

		var tex_path: String = skin.get("texture_path", "")
		var tex: Texture2D = CosmeticsManager.load_texture(tex_path)
		_preview_icon.texture = tex
		CosmeticsManager.apply_skin_to_canvas_item(_preview_icon, _selected_skin_id, stars)

		_preview_title.text = skin.get("skin_name", "Skin")
		_preview_title.modulate = Color(0.2, 0.9, 1.0, 1.0)

		var star_str := ""
		for i in range(stars):
			star_str += "⭐"
		var effect_str := "Recolor Base"
		if stars == 2:
			effect_str = "Glow Neón"
		elif stars == 3:
			effect_str = "Aura y Resonancia Estelar"

		_preview_desc.text = "%s (%s)" % [star_str, effect_str]
		_equip_btn.text = "✅ EQUIPAR SKIN" if not is_this_equipped else "✅ ACTUALMENTE ACTIVA"
		_equip_btn.disabled = is_this_equipped

func _on_equip_pressed() -> void:
	SaveManager.equip_skin(_slot_key, _selected_skin_id)
	skin_selected.emit(_slot_key, _selected_skin_id)
	_update_preview()
	_populate_grid()

func _on_default_pressed() -> void:
	_selected_skin_id = ""
	SaveManager.unequip_skin(_slot_key)
	skin_selected.emit(_slot_key, "")
	_update_preview()
	_populate_grid()

func _on_gacha_btn_pressed() -> void:
	close_modal()
	open_gacha_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()
