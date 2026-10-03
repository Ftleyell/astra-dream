class_name GachaWardrobeController
extends RefCounted

## GachaWardrobeController.gd
## Controlador del Armario y Colección de Skins:
## - Filtros por categoría (naves, pilotos, armas, mascotas, navegantes).
## - Conmutador de visibilidad (ocultar skins bloqueadas).
## - Construcción reactiva de cartas de cosméticos con opciones de equipar/desequipar.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")

signal skin_equipped(slot_key: String, skin_id: String)

var _wardrobe_content: VBoxContainer
var _hide_locked_check: CheckBox
var _wardrobe_grid: GridContainer

var active_category_filter: String = "all"
var hide_locked: bool = false

var wardrobe_content: VBoxContainer:
	get: return _wardrobe_content

var hide_locked_check: CheckBox:
	get: return _hide_locked_check

var wardrobe_grid: GridContainer:
	get: return _wardrobe_grid

func setup(parent_vbox: VBoxContainer) -> void:
	_wardrobe_content = VBoxContainer.new()
	_wardrobe_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wardrobe_content.add_theme_constant_override("separation", 10)
	parent_vbox.add_child(_wardrobe_content)
	_wardrobe_content.hide()

	# Filter buttons
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 10)
	_wardrobe_content.add_child(filter_bar)

	var cats: Array[Dictionary] = [
		{"id": "all", "label": "TODAS"},
		{"id": "ship", "label": "🚀 NAVES"},
		{"id": "pilot", "label": "👩‍✈️ PILOTOS"},
		{"id": "weapon", "label": "⚡ ARMAS"},
		{"id": "pet", "label": "🐾 PETS"},
		{"id": "navigator", "label": "📡 NAVEGADORAS"}
	]
	for c: Dictionary in cats:
		var b := Button.new()
		b.text = c["label"]
		var cid: String = c["id"]
		b.pressed.connect(func(): filter_wardrobe(cid))
		UIFocusHelper.apply_cyber_focus(b)
		filter_bar.add_child(b)

	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(filter_spacer)

	_hide_locked_check = CheckBox.new()
	_hide_locked_check.text = "👁️ Ocultar no adquiridos"
	_hide_locked_check.button_pressed = hide_locked
	_hide_locked_check.toggled.connect(func(pressed: bool):
		hide_locked = pressed
		filter_wardrobe(active_category_filter)
	)
	UIFocusHelper.apply_cyber_focus(_hide_locked_check)
	filter_bar.add_child(_hide_locked_check)

	# Scrollable Wardrobe Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wardrobe_content.add_child(scroll)

	_wardrobe_grid = GridContainer.new()
	_wardrobe_grid.columns = 4
	_wardrobe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wardrobe_grid.add_theme_constant_override("h_separation", 16)
	_wardrobe_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_wardrobe_grid)

func filter_wardrobe(category_id: String) -> void:
	active_category_filter = category_id
	if not _wardrobe_grid:
		return

	for child: Node in _wardrobe_grid.get_children():
		_wardrobe_grid.remove_child(child)
		child.queue_free()

	var all_skins: Dictionary = CosmeticsManager.get_all_skins()
	var unlocked_dict: Dictionary = SaveManager.get_unlocked_skins()
	var equipped_dict: Dictionary = SaveManager.get_equipped_skins()

	for sid: String in all_skins.keys():
		var skin: Dictionary = all_skins[sid]
		var cat: String = skin.get("category", "")
		if category_id != "all" and cat != category_id:
			continue

		var is_unlocked: bool = unlocked_dict.has(sid)
		if hide_locked and not is_unlocked:
			continue

		var stars: int = 0
		if is_unlocked:
			var entry = unlocked_dict[sid]
			if entry is Dictionary:
				stars = int(entry.get("stars", 1))
			else:
				stars = int(entry)

		var target_id: String = skin.get("target_id", "")
		var slot_key: String = "%s:%s" % [cat, target_id]
		var is_equipped: bool = (equipped_dict.get(slot_key, "") == sid)

		var item_card: Control = _create_wardrobe_card(skin, is_unlocked, stars, is_equipped, slot_key)
		_wardrobe_grid.add_child(item_card)

func _create_wardrobe_card(skin: Dictionary, is_unlocked: bool, stars: int, is_equipped: bool, slot_key: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(210, 260)

	var glow_hex: String = skin.get("glow_hex", "#00F0FF")
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.05, 0.12, 0.95) if is_unlocked else Color(0.04, 0.03, 0.08, 0.7)
	csb.border_color = Color.from_string(glow_hex, Color.CYAN) if is_unlocked else Color(0.25, 0.25, 0.35, 0.5)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = CosmeticsManager.get_skin_texture(skin)
	if tex:
		icon.texture = tex
	if is_unlocked:
		CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars, false)
	else:
		icon.modulate = Color(0.3, 0.3, 0.4, 0.6)
	vbox.add_child(icon)

	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 13)
	t_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if is_unlocked else Color(0.6, 0.6, 0.6, 0.8))
	vbox.add_child(t_name)

	var s_name := Label.new()
	s_name.text = skin.get("skin_name", "")
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.add_theme_font_size_override("font_size", 11)
	s_name.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.9) if is_unlocked else Color(0.5, 0.5, 0.5, 0.7))
	vbox.add_child(s_name)

	var star_lbl := Label.new()
	var star_str: String = ""
	for i: int in range(stars):
		star_str += "⭐"
	star_lbl.text = star_str if is_unlocked else "🔒 BLOQUEADO"
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if is_unlocked else Color(0.5, 0.5, 0.6, 0.8))
	vbox.add_child(star_lbl)

	if is_unlocked:
		var sid: String = skin.get("id", "")
		if is_equipped:
			var btn_box := HBoxContainer.new()
			btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_box.add_theme_constant_override("separation", 6)
			vbox.add_child(btn_box)

			var eq_lbl := Label.new()
			eq_lbl.text = "✅ ACTIVA"
			eq_lbl.add_theme_font_size_override("font_size", 11)
			eq_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
			btn_box.add_child(eq_lbl)

			var unequip_btn := Button.new()
			unequip_btn.text = "QUITAR"
			unequip_btn.custom_minimum_size = Vector2(70, 26)
			unequip_btn.add_theme_font_size_override("font_size", 10)
			unequip_btn.pressed.connect(func():
				SaveManager.unequip_skin(slot_key)
				skin_equipped.emit(slot_key, "")
				filter_wardrobe(active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(unequip_btn)
			btn_box.add_child(unequip_btn)
		else:
			var eq_btn := Button.new()
			eq_btn.text = "EQUIPAR"
			eq_btn.custom_minimum_size = Vector2(110, 28)
			eq_btn.pressed.connect(func():
				SaveManager.equip_skin(slot_key, sid)
				skin_equipped.emit(slot_key, sid)
				filter_wardrobe(active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(eq_btn)
			vbox.add_child(eq_btn)

	return frame
