class_name SkinSelectionModal
extends CanvasLayer

## Modal de Aspectos (Skins) con Carrusel CoverFlow estilo Navegadoras y Mascotas.
## Permite previsualizar en gran formato las skins de Pilotos (Fullbody), Naves,
## Armas, Mascotas y Navegadoras con estrellas, shaders de glow y equipamiento instantáneo.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

signal skin_selected(slot_key: String, skin_id: String)
signal closed()
signal open_gacha_requested()

var is_open: bool = false
var _category: String = "pilot"
var _target_id: String = "nova"
var _slot_key: String = ""
var _display_title: String = ""
var _default_texture: Texture2D = null

# Lista de skins disponibles para el target actual
var _skins: Array[Dictionary] = []
var current_index: int = 0
var _nav_dots: Array[Button] = []
var _active_tween: Tween = null

var _selected_skin_id: String:
	get:
		if _skins.is_empty() or current_index < 0 or current_index >= _skins.size():
			return ""
		return _skins[current_index].get("id", "")
	set(val):
		for i in range(_skins.size()):
			if _skins[i].get("id", "") == val:
				current_index = i
				_display_current_skin(false, 0)
				break

# Nodos UI
var _title_label: Label
var _tabs_container: HBoxContainer
var _tab_buttons: Dictionary = {} # "pilot": Button, "ship": Button, "weapon": Button

var _prev_btn: Button
var _next_btn: Button
var _left_card: Button
var _left_texture: TextureRect
var _left_label: Label

var _artwork_frame: PanelContainer
var _fullbody_texture: TextureRect
var _locked_overlay: Control
var _lock_desc: Label
var _stars_badge: Label

var _right_card: Button
var _right_texture: TextureRect
var _right_label: Label

var _dots_container: HBoxContainer

var _skin_name_label: Label
var _palette_label: Label
var _status_badge: Label
var _desc_label: Label

var _equip_btn: Button
var _default_btn: Button
var _gacha_btn: Button
var _close_btn: Button

func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "DimOverlay"
	dim.color = Color(0.01, 0.01, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 680)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.12, 0.98)
	sb.border_color = Color(0.12, 0.88, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# 1. Header con Título, Pestañas de Categoría y Botón Cerrar
	var header_bar := HBoxContainer.new()
	header_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_bar)

	_title_label = Label.new()
	_title_label.text = "🎨 ASPECTOS Y SKINS CÓSMICAS"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	header_bar.add_child(_title_label)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(h_spacer)

	_tabs_container = HBoxContainer.new()
	_tabs_container.add_theme_constant_override("separation", 8)
	header_bar.add_child(_tabs_container)
	_create_category_tabs()

	_close_btn = Button.new()
	_close_btn.text = " ✖ CERRAR "
	_close_btn.custom_minimum_size = Vector2(100, 36)
	_close_btn.pressed.connect(close_modal)
	UIFocusHelper.apply_cyber_focus(_close_btn)
	header_bar.add_child(_close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# 2. CoverFlow Section (Prev, LeftCard, ArtworkFrame, RightCard, Next)
	var cover_flow_row := HBoxContainer.new()
	cover_flow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cover_flow_row.add_theme_constant_override("separation", 18)
	cover_flow_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cover_flow_row)

	# Flecha Izquierda
	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	_prev_btn.custom_minimum_size = Vector2(44, 180)
	_prev_btn.add_theme_font_size_override("font_size", 24)
	_prev_btn.pressed.connect(func(): _cycle(-1))
	UIFocusHelper.apply_cyber_focus(_prev_btn)
	cover_flow_row.add_child(_prev_btn)

	# Tarjeta Izquierda (Previsualización menor)
	_left_card = Button.new()
	_left_card.custom_minimum_size = Vector2(140, 200)
	_left_card.flat = true
	_left_card.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_left_card.pressed.connect(func(): _cycle(-1))
	UIFocusHelper.apply_cyber_focus(_left_card)
	var left_vbox := VBoxContainer.new()
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_card.add_child(left_vbox)
	_left_texture = TextureRect.new()
	_left_texture.custom_minimum_size = Vector2(110, 150)
	_left_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_vbox.add_child(_left_texture)
	_left_label = Label.new()
	_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_label.add_theme_font_size_override("font_size", 10)
	left_vbox.add_child(_left_label)
	cover_flow_row.add_child(_left_card)

	# Tarjeta Central Principal (CoverFlow Hero)
	_artwork_frame = PanelContainer.new()
	_artwork_frame.custom_minimum_size = Vector2(280, 290)
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0.08, 0.07, 0.20, 0.95)
	frame_sb.border_color = Color(0.2, 0.95, 1.0, 0.9)
	frame_sb.set_border_width_all(2)
	frame_sb.set_corner_radius_all(10)
	_artwork_frame.add_theme_stylebox_override("panel", frame_sb)
	cover_flow_row.add_child(_artwork_frame)

	var frame_vbox := VBoxContainer.new()
	frame_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_artwork_frame.add_child(frame_vbox)

	# Badge de Estrellas Superior
	_stars_badge = Label.new()
	_stars_badge.text = "★★★"
	_stars_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars_badge.add_theme_font_size_override("font_size", 16)
	_stars_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	frame_vbox.add_child(_stars_badge)

	var art_viewport := Control.new()
	art_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_vbox.add_child(art_viewport)

	_fullbody_texture = TextureRect.new()
	_fullbody_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fullbody_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fullbody_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_viewport.add_child(_fullbody_texture)

	# Overlay de Candado si no está desbloqueada
	_locked_overlay = Control.new()
	_locked_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dark_rect := ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.color = Color(0.02, 0.02, 0.05, 0.78)
	_locked_overlay.add_child(dark_rect)

	var lock_center := CenterContainer.new()
	lock_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lock_vbox := VBoxContainer.new()
	lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var lock_ico := Label.new()
	lock_ico.text = "🔒"
	lock_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_ico.add_theme_font_size_override("font_size", 34)
	lock_vbox.add_child(lock_ico)
	_lock_desc = Label.new()
	_lock_desc.text = "BLOQUEADO EN GACHA"
	_lock_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_desc.add_theme_font_size_override("font_size", 11)
	_lock_desc.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
	lock_vbox.add_child(_lock_desc)
	lock_center.add_child(lock_vbox)
	_locked_overlay.add_child(lock_center)
	art_viewport.add_child(_locked_overlay)

	# Tarjeta Derecha
	_right_card = Button.new()
	_right_card.custom_minimum_size = Vector2(140, 200)
	_right_card.flat = true
	_right_card.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_right_card.pressed.connect(func(): _cycle(1))
	UIFocusHelper.apply_cyber_focus(_right_card)
	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_right_card.add_child(right_vbox)
	_right_texture = TextureRect.new()
	_right_texture.custom_minimum_size = Vector2(110, 150)
	_right_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_vbox.add_child(_right_texture)
	_right_label = Label.new()
	_right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_label.add_theme_font_size_override("font_size", 10)
	right_vbox.add_child(_right_label)
	cover_flow_row.add_child(_right_card)

	# Flecha Derecha
	_next_btn = Button.new()
	_next_btn.text = "▶"
	_next_btn.custom_minimum_size = Vector2(44, 180)
	_next_btn.add_theme_font_size_override("font_size", 24)
	_next_btn.pressed.connect(func(): _cycle(1))
	UIFocusHelper.apply_cyber_focus(_next_btn)
	cover_flow_row.add_child(_next_btn)

	# Paginación por puntos (Dots)
	_dots_container = HBoxContainer.new()
	_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(_dots_container)

	# 3. Dossier Panel Inferior (Información detallada y Botones de Acción)
	var dossier_panel := PanelContainer.new()
	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color(0.08, 0.07, 0.18, 0.9)
	d_sb.border_color = Color(0.15, 0.5, 0.8, 0.5)
	d_sb.set_border_width_all(1)
	d_sb.set_corner_radius_all(8)
	d_sb.content_margin_left = 18
	d_sb.content_margin_right = 18
	d_sb.content_margin_top = 12
	d_sb.content_margin_bottom = 12
	dossier_panel.add_theme_stylebox_override("panel", d_sb)
	root_vbox.add_child(dossier_panel)

	var dossier_vbox := VBoxContainer.new()
	dossier_vbox.add_theme_constant_override("separation", 8)
	dossier_panel.add_child(dossier_vbox)

	var info_header := HBoxContainer.new()
	info_header.add_theme_constant_override("separation", 14)
	dossier_vbox.add_child(info_header)

	_skin_name_label = Label.new()
	_skin_name_label.text = "NOMBRE DEL ASPECTO"
	_skin_name_label.add_theme_font_size_override("font_size", 18)
	_skin_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	info_header.add_child(_skin_name_label)

	_palette_label = Label.new()
	_palette_label.text = "[Paleta Cósmica]"
	_palette_label.add_theme_font_size_override("font_size", 13)
	_palette_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
	info_header.add_child(_palette_label)

	var d_spacer := Control.new()
	d_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_header.add_child(d_spacer)

	_status_badge = Label.new()
	_status_badge.text = "DESBLOQUEADO"
	_status_badge.add_theme_font_size_override("font_size", 12)
	info_header.add_child(_status_badge)

	_desc_label = Label.new()
	_desc_label.text = "Descripción del aspecto y efectos estelares."
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.85))
	dossier_vbox.add_child(_desc_label)

	# Fila de Botones de Acción
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 16)
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dossier_vbox.add_child(actions_row)

	_equip_btn = Button.new()
	_equip_btn.text = "★ EQUIPAR ASPECTO"
	_equip_btn.custom_minimum_size = Vector2(240, 42)
	_equip_btn.pressed.connect(_on_equip_pressed)
	UIFocusHelper.apply_cyber_focus(_equip_btn)
	actions_row.add_child(_equip_btn)

	_default_btn = Button.new()
	_default_btn.text = "↺ COLOR ORIGINAL"
	_default_btn.custom_minimum_size = Vector2(200, 42)
	_default_btn.pressed.connect(_on_default_pressed)
	UIFocusHelper.apply_cyber_focus(_default_btn)
	actions_row.add_child(_default_btn)

	_gacha_btn = Button.new()
	_gacha_btn.text = "🎰 IR AL GACHA"
	_gacha_btn.custom_minimum_size = Vector2(180, 42)
	_gacha_btn.pressed.connect(_on_gacha_pressed)
	UIFocusHelper.apply_cyber_focus(_gacha_btn)
	actions_row.add_child(_gacha_btn)

func _create_category_tabs() -> void:
	var tabs: Array[Dictionary] = [
		{ "cat": "pilot", "label": "👤 PILOTO" },
		{ "cat": "ship", "label": "🚀 NAVE" },
		{ "cat": "weapon", "label": "🔫 ARMA" },
		{ "cat": "pet", "label": "🐱 MASCOTA" },
		{ "cat": "navigator", "label": "📡 NAVEGADORA" }
	]

	for t in tabs:
		var btn := Button.new()
		btn.text = t["label"]
		btn.custom_minimum_size = Vector2(105, 34)
		var cat_name: String = t["cat"]
		btn.pressed.connect(func(): _switch_category(cat_name))
		UIFocusHelper.apply_cyber_focus(btn)
		_tabs_container.add_child(btn)
		_tab_buttons[cat_name] = btn

func _switch_category(new_cat: String) -> void:
	if _category == new_cat:
		return
	_category = new_cat
	# Actualizar target_id según corresponda
	if _category == "pet":
		_target_id = String(SaveManager.get_selected_pet())
		_display_title = _target_id.capitalize()
	elif _category == "navigator":
		_target_id = String(SaveManager.get_selected_navigator())
		_display_title = _target_id.capitalize()
	_slot_key = "%s:%s" % [_category, _target_id]
	_load_category_skins()

func open_for_target(category: String, target_id: String, display_title: String, default_texture: Texture2D) -> void:
	_category = category
	_target_id = target_id
	_display_title = display_title
	_default_texture = default_texture
	_slot_key = "%s:%s" % [category, target_id]

	is_open = true
	show()
	get_tree().paused = true

	# Configurar visibilidad de pestañas
	var is_character_system: bool = (_category in ["pilot", "ship", "weapon"])
	for cat in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cat]
		if is_character_system:
			btn.visible = (cat in ["pilot", "ship", "weapon"])
		else:
			btn.visible = (cat == _category)

	_load_category_skins()

	if _equip_btn and not _equip_btn.disabled:
		_equip_btn.grab_focus()
	elif _next_btn:
		_next_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return

	# CoverFlow navigation
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			get_viewport().set_input_as_handled()
			_cycle(-1)
			return
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_cycle(1)
			return
		elif event.keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_cycle_tabs(-1)
			return
		elif event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_cycle_tabs(1)
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)

func _cycle_tabs(dir: int) -> void:
	var tabs: Array = ["pilot", "ship", "weapon"]
	if not (_category in tabs):
		return
	var cur := tabs.find(_category)
	var next_idx := (cur + dir) % tabs.size()
	if next_idx < 0:
		next_idx += tabs.size()
	_switch_category(tabs[next_idx])

func _load_category_skins() -> void:
	_title_label.text = "🎨 ASPECTOS: %s (%s)" % [_display_title.to_upper(), _category.to_upper()]
	_slot_key = "%s:%s" % [_category, _target_id]

	# Actualizar estilo de pestañas
	for cat in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cat]
		if cat == _category:
			btn.modulate = Color(0.2, 1.0, 0.85, 1.0)
		else:
			btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

	_skins = CosmeticsManager.get_skins_for_target(_category, _target_id)
	
	# Encontrar índice de la actualmente equipada
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)
	current_index = 0
	for i in range(_skins.size()):
		if _skins[i].get("id", "") == currently_equipped:
			current_index = i
			break

	_build_dots()
	_display_current_skin(false, 0)

func _build_dots() -> void:
	for child in _dots_container.get_children():
		_dots_container.remove_child(child)
		child.queue_free()
	_nav_dots.clear()

	for i in range(_skins.size()):
		var dot := Button.new()
		dot.custom_minimum_size = Vector2(24, 24)
		dot.flat = true
		dot.text = "●" if i == current_index else "○"
		dot.add_theme_font_size_override("font_size", 16)
		dot.focus_mode = Control.FOCUS_NONE
		var target_idx := i
		dot.pressed.connect(func():
			if current_index != target_idx:
				var dir := 1 if target_idx > current_index else -1
				_set_index(target_idx, dir)
		)
		_dots_container.add_child(dot)
		_nav_dots.append(dot)

func _cycle(direction: int) -> void:
	if _skins.is_empty():
		return
	var count := _skins.size()
	var next_idx := (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_index(next_idx, direction)

func _set_index(new_idx: int, slide_dir: int = 0) -> void:
	if new_idx == current_index:
		return
	current_index = new_idx
	_display_current_skin(true, slide_dir)

func _display_current_skin(animated: bool = false, slide_dir: int = 0) -> void:
	if _skins.is_empty():
		_display_empty_state()
		return

	var count := _skins.size()
	var cur_skin: Dictionary = _skins[current_index]
	var sid: String = cur_skin.get("id", "")
	var sname: String = cur_skin.get("skin_name", "Aspecto")
	var pal_name: String = cur_skin.get("palette_id", "").replace("_", " ").capitalize()
	var desc: String = cur_skin.get("description", "")
	var rarity: String = cur_skin.get("rarity", "common").to_upper()

	var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
	var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)
	var is_equipped: bool = (currently_equipped == sid)

	# Actualizar Dots
	for i in range(_nav_dots.size()):
		_nav_dots[i].text = "●" if i == current_index else "○"

	# Actualizar Dossier
	_skin_name_label.text = sname
	_palette_label.text = "[Paleta: %s | Rareza: %s]" % [pal_name, rarity]
	_desc_label.text = desc

	# Estrellas y efectos
	var star_str := ""
	for s in range(stars):
		star_str += "★"
	if stars == 1:
		_stars_badge.text = "%s 1★ RECOLOR BASE" % star_str
		_stars_badge.modulate = Color(0.8, 0.9, 1.0)
	elif stars == 2:
		_stars_badge.text = "%s 2★ AURA DE PLASMA Y RESPLANDOR" % star_str
		_stars_badge.modulate = Color(0.2, 0.95, 1.0)
	else:
		_stars_badge.text = "%s 3★ MÁXIMO NIVEL (DESTELLOS CÓSMICOS)" % star_str
		_stars_badge.modulate = Color(1.0, 0.88, 0.2)

	# Estado y Botón de Equipar
	if is_equipped:
		_status_badge.text = "✓ EQUIPADO"
		_status_badge.modulate = Color(0.2, 1.0, 0.4)
		_equip_btn.text = "✓ EQUIPADO (CLIC PARA DESEQUIPAR)"
		_equip_btn.disabled = false
		_equip_btn.modulate = Color(0.3, 1.0, 0.5)
	elif is_unlocked:
		_status_badge.text = "DESBLOQUEADO"
		_status_badge.modulate = Color(0.2, 0.9, 1.0)
		_equip_btn.text = "★ EQUIPAR ASPECTO"
		_equip_btn.disabled = false
		_equip_btn.modulate = Color(1.0, 1.0, 1.0)
	else:
		_status_badge.text = "🔒 BLOQUEADO"
		_status_badge.modulate = Color(1.0, 0.4, 0.4)
		_equip_btn.text = "🔒 BLOQUEADO EN GACHA"
		_equip_btn.disabled = true
		_equip_btn.modulate = Color(0.6, 0.6, 0.6)

	_locked_overlay.visible = not is_unlocked
	_default_btn.disabled = (currently_equipped == "")

	# Cargar Textura y Shader en Tarjeta Central
	var tex_path: String = cur_skin.get("texture_path", "")
	var tex := CosmeticsManager.load_texture(tex_path)
	if not tex and _default_texture:
		tex = _default_texture
	_fullbody_texture.texture = tex

	if is_unlocked and stars > 1:
		CosmeticsManager.apply_skin_to_canvas_item(_fullbody_texture, sid, stars)
	else:
		_fullbody_texture.material = null

	# Previews Lateral Izquierdo y Derecho (CoverFlow)
	var prev_idx := (current_index - 1 + count) % count
	var next_idx := (current_index + 1) % count

	var prev_skin: Dictionary = _skins[prev_idx]
	var next_skin: Dictionary = _skins[next_idx]

	var prev_tex := CosmeticsManager.load_texture(prev_skin.get("texture_path", ""))
	_left_texture.texture = prev_tex if prev_tex else _default_texture
	_left_label.text = prev_skin.get("skin_name", "")

	var next_tex := CosmeticsManager.load_texture(next_skin.get("texture_path", ""))
	_right_texture.texture = next_tex if next_tex else _default_texture
	_right_label.text = next_skin.get("skin_name", "")

	# Animación de CoverFlow elástica
	if animated:
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()
		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_artwork_frame.scale = Vector2(0.92, 0.92)
		_artwork_frame.position.x += float(slide_dir) * 40.0
		_active_tween.tween_property(_artwork_frame, "scale", Vector2(1.0, 1.0), 0.28)
		_active_tween.tween_property(_artwork_frame, "position:x", 0.0, 0.28)

func _display_empty_state() -> void:
	_skin_name_label.text = "SIN ASPECTOS"
	_palette_label.text = ""
	_desc_label.text = "No hay aspectos disponibles para esta categoría."
	_fullbody_texture.texture = _default_texture
	_fullbody_texture.material = null
	_locked_overlay.hide()
	_equip_btn.disabled = true
	_default_btn.disabled = true

func _on_equip_pressed() -> void:
	if _skins.is_empty():
		return
	var cur_skin: Dictionary = _skins[current_index]
	var sid: String = cur_skin.get("id", "")
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)

	if currently_equipped == sid:
		# Desequipar
		SaveManager.unequip_skin(_slot_key)
		skin_selected.emit(_slot_key, "")
	else:
		# Equipar
		SaveManager.equip_skin(_slot_key, sid)
		skin_selected.emit(_slot_key, sid)

	_display_current_skin(false, 0)

func _on_default_pressed() -> void:
	SaveManager.unequip_skin(_slot_key)
	skin_selected.emit(_slot_key, "")
	_display_current_skin(false, 0)

func _on_gacha_pressed() -> void:
	close_modal()
	open_gacha_requested.emit()
