class_name SkinSelectionModal
extends CanvasLayer

## SkinSelectionModal.gd
## Modal de Aspectos (Skins) con Carrusel CoverFlow estilo Navegadoras y Mascotas.
## Permite previsualizar en gran formato las skins de Pilotos (Fullbody), Naves,
## Armas, Mascotas y Navegadoras con estrellas, shaders de glow y equipamiento instantáneo.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SkinCategoryTabs = preload("res://scenes/ui/cosmetics/components/skin_category_tabs.gd")
const SkinCoverFlowRenderer = preload("res://scenes/ui/cosmetics/components/skin_cover_flow_renderer.gd")
const SkinDossierController = preload("res://scenes/ui/cosmetics/components/skin_dossier_controller.gd")

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

# Controladores Modulares
var category_tabs: SkinCategoryTabs = null
var cover_flow_renderer: SkinCoverFlowRenderer = null
var dossier_controller: SkinDossierController = null

# Nodos UI clave
var _title_label: Label = null
var _close_btn: Button = null


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

	var tabs_box := HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 8)
	header_bar.add_child(tabs_box)

	category_tabs = SkinCategoryTabs.new()
	category_tabs.setup(tabs_box, Callable(self, "_switch_category"))

	_close_btn = Button.new()
	_close_btn.text = " ✖ CERRAR "
	_close_btn.custom_minimum_size = Vector2(100, 36)
	_close_btn.pressed.connect(close_modal)
	UIFocusHelper.apply_cyber_focus(_close_btn)
	header_bar.add_child(_close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# 2. CoverFlow Section
	var cover_flow_row := HBoxContainer.new()
	cover_flow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cover_flow_row.add_theme_constant_override("separation", 18)
	cover_flow_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cover_flow_row)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(48, 200)
	prev_btn.add_theme_font_size_override("font_size", 24)
	cover_flow_row.add_child(prev_btn)

	var left_card := Button.new()
	left_card.custom_minimum_size = Vector2(160, 240)
	left_card.flat = true
	left_card.modulate = Color(1.0, 1.0, 1.0, 0.55)
	var left_vbox := VBoxContainer.new()
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_card.add_child(left_vbox)

	var left_tex := TextureRect.new()
	left_tex.custom_minimum_size = Vector2(130, 180)
	left_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(left_tex)

	var left_lbl := Label.new()
	left_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_lbl.add_theme_font_size_override("font_size", 11)
	left_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(left_lbl)
	cover_flow_row.add_child(left_card)

	# Tarjeta Central Hero
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(340, 360)
	frame.pivot_offset = Vector2(170, 180)
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0.08, 0.07, 0.20, 0.95)
	frame_sb.border_color = Color(0.2, 0.95, 1.0, 0.9)
	frame_sb.set_border_width_all(2)
	frame_sb.set_corner_radius_all(12)
	frame_sb.shadow_color = Color(0.12, 0.88, 1.0, 0.3)
	frame_sb.shadow_size = 10
	frame.add_theme_stylebox_override("panel", frame_sb)
	cover_flow_row.add_child(frame)

	var frame_vbox := VBoxContainer.new()
	frame_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(frame_vbox)

	var stars_lbl := Label.new()
	stars_lbl.text = "★★★"
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 16)
	stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	frame_vbox.add_child(stars_lbl)

	var art_viewport := Control.new()
	art_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_viewport.clip_contents = true
	frame_vbox.add_child(art_viewport)

	var fullbody_tex := TextureRect.new()
	fullbody_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullbody_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fullbody_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_viewport.add_child(fullbody_tex)

	var locked_overlay := Control.new()
	locked_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dark_rect := ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.color = Color(0.02, 0.02, 0.05, 0.78)
	locked_overlay.add_child(dark_rect)

	var lock_center := CenterContainer.new()
	lock_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lock_vbox := VBoxContainer.new()
	lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var lock_ico := Label.new()
	lock_ico.text = "🔒"
	lock_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_ico.add_theme_font_size_override("font_size", 34)
	lock_vbox.add_child(lock_ico)
	var lock_desc := Label.new()
	lock_desc.text = "BLOQUEADO EN GACHA"
	lock_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_desc.add_theme_font_size_override("font_size", 11)
	lock_desc.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
	lock_vbox.add_child(lock_desc)
	lock_center.add_child(lock_vbox)
	locked_overlay.add_child(lock_center)
	art_viewport.add_child(locked_overlay)

	var right_card := Button.new()
	right_card.custom_minimum_size = Vector2(160, 240)
	right_card.flat = true
	right_card.modulate = Color(1.0, 1.0, 1.0, 0.55)
	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_card.add_child(right_vbox)

	var right_tex := TextureRect.new()
	right_tex.custom_minimum_size = Vector2(130, 180)
	right_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(right_tex)

	var right_lbl := Label.new()
	right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_lbl.add_theme_font_size_override("font_size", 11)
	right_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(right_lbl)
	cover_flow_row.add_child(right_card)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(48, 200)
	next_btn.add_theme_font_size_override("font_size", 24)
	cover_flow_row.add_child(next_btn)

	var dots_box := HBoxContainer.new()
	dots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(dots_box)

	cover_flow_renderer = SkinCoverFlowRenderer.new()
	cover_flow_renderer.setup(
		prev_btn, next_btn,
		left_card, left_tex, left_lbl,
		frame, fullbody_tex, locked_overlay, lock_desc, stars_lbl,
		right_card, right_tex, right_lbl,
		dots_box,
		Callable(self, "_cycle"),
		Callable(self, "_set_index")
	)

	# 3. Dossier Panel Inferior
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

	var sname_lbl := Label.new()
	sname_lbl.text = "NOMBRE DEL ASPECTO"
	sname_lbl.add_theme_font_size_override("font_size", 18)
	sname_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	info_header.add_child(sname_lbl)

	var pal_lbl := Label.new()
	pal_lbl.text = "[Paleta Cósmica]"
	pal_lbl.add_theme_font_size_override("font_size", 13)
	pal_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
	info_header.add_child(pal_lbl)

	var d_spacer := Control.new()
	d_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_header.add_child(d_spacer)

	var stat_badge := Label.new()
	stat_badge.text = "DESBLOQUEADO"
	stat_badge.add_theme_font_size_override("font_size", 12)
	info_header.add_child(stat_badge)

	var desc_lbl := Label.new()
	desc_lbl.text = "Descripción del aspecto y efectos estelares."
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.85))
	dossier_vbox.add_child(desc_lbl)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 16)
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dossier_vbox.add_child(actions_row)

	var equip_btn := Button.new()
	equip_btn.text = "★ EQUIPAR ASPECTO"
	equip_btn.custom_minimum_size = Vector2(240, 42)
	actions_row.add_child(equip_btn)

	var default_btn := Button.new()
	default_btn.text = "↺ COLOR ORIGINAL"
	default_btn.custom_minimum_size = Vector2(200, 42)
	actions_row.add_child(default_btn)

	var gacha_btn := Button.new()
	gacha_btn.text = "🎰 IR AL GACHA"
	gacha_btn.custom_minimum_size = Vector2(180, 42)
	actions_row.add_child(gacha_btn)

	dossier_controller = SkinDossierController.new()
	dossier_controller.setup(
		sname_lbl, pal_lbl, stat_badge, desc_lbl,
		equip_btn, default_btn, gacha_btn,
		Callable(self, "_on_equip_pressed"),
		Callable(self, "_on_default_pressed"),
		Callable(self, "_on_gacha_pressed")
	)


func open_for_target(category: String, target_id: String, display_title: String, default_texture: Texture2D) -> void:
	_category = category
	_target_id = target_id
	_display_title = display_title
	_default_texture = default_texture
	_slot_key = "%s:%s" % [category, target_id]

	is_open = true
	show()
	get_tree().paused = true

	if category_tabs:
		category_tabs.configure_tab_visibility(category)

	_load_category_skins()

	if dossier_controller and dossier_controller.equip_btn and not dossier_controller.equip_btn.disabled:
		dossier_controller.equip_btn.grab_focus()
	elif cover_flow_renderer and cover_flow_renderer.next_btn:
		cover_flow_renderer.next_btn.grab_focus()


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
	if category_tabs:
		category_tabs.cycle_tabs(dir)


func _switch_category(new_cat: String) -> void:
	if _category == new_cat:
		return
	_category = new_cat

	if _category in ["pilot", "ship", "weapon"]:
		const CharacterDataScript = preload("res://data/characters/character_data.gd")
		var roster = CharacterDataScript.load_roster()
		var char_data = roster.get(StringName(_target_id), null)
		if char_data:
			_display_title = char_data.display_name
			if _category == "pilot":
				var fb: Texture2D = char_data.get_fullbody_texture(false)
				if not fb:
					fb = char_data.get_fullbody_texture(true)
				if not fb:
					fb = char_data.get_portrait_texture()
				_default_texture = fb
			elif _category == "ship":
				_default_texture = char_data.get_ship_texture()
			elif _category == "weapon":
				_default_texture = char_data.get_weapon_texture()
	elif _category == "pet":
		_target_id = String(SaveManager.get_selected_pet())
		_display_title = _target_id.capitalize()
		const PetDataScript = preload("res://data/pets/pet_data.gd")
		var p_data = PetDataScript.get_pet(StringName(_target_id))
		if p_data:
			_default_texture = p_data.get_icon_texture()
	elif _category == "navigator":
		_target_id = String(SaveManager.get_selected_navigator())
		_display_title = _target_id.capitalize()
		const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")
		var n_data = NavigatorDataScript.get_navigator(StringName(_target_id))
		if n_data:
			_default_texture = n_data.get_portrait_texture()

	_slot_key = "%s:%s" % [_category, _target_id]
	_load_category_skins()


func _load_category_skins() -> void:
	_title_label.text = "🎨 ASPECTOS: %s (%s)" % [_display_title.to_upper(), _category.to_upper()]
	_slot_key = "%s:%s" % [_category, _target_id]

	if category_tabs:
		category_tabs.update_styles(_category)

	_skins = CosmeticsManager.get_skins_for_target(_category, _target_id)

	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)
	current_index = 0
	for i in range(_skins.size()):
		if _skins[i].get("id", "") == currently_equipped:
			current_index = i
			break

	if cover_flow_renderer:
		cover_flow_renderer.build_dots(_skins.size(), current_index)
	_display_current_skin(false, 0)


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
		if dossier_controller:
			dossier_controller.show_empty_state()
		if cover_flow_renderer:
			cover_flow_renderer.render_empty(_default_texture)
		return

	var count := _skins.size()
	var cur_skin: Dictionary = _skins[current_index]
	var sid: String = cur_skin.get("id", "")

	var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
	var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)
	var is_equipped: bool = (currently_equipped == sid)
	var has_any_equipped: bool = not currently_equipped.is_empty()

	if cover_flow_renderer:
		cover_flow_renderer.update_dots(current_index)

	if dossier_controller:
		dossier_controller.update_dossier(cur_skin, is_unlocked, is_equipped, has_any_equipped)

	var prev_idx := (current_index - 1 + count) % count
	var next_idx := (current_index + 1) % count
	var prev_skin: Dictionary = _skins[prev_idx]
	var next_skin: Dictionary = _skins[next_idx]
	var is_pilot: bool = (_category == "pilot")

	if cover_flow_renderer:
		cover_flow_renderer.render_skin(
			cur_skin, is_unlocked, stars, is_pilot, _default_texture,
			prev_skin, next_skin, animated, slide_dir
		)


func _on_equip_pressed() -> void:
	if _skins.is_empty():
		return
	var cur_skin: Dictionary = _skins[current_index]
	var sid: String = cur_skin.get("id", "")
	var currently_equipped := SaveManager.get_equipped_skin(_slot_key)

	if currently_equipped == sid:
		SaveManager.unequip_skin(_slot_key)
		skin_selected.emit(_slot_key, "")
	else:
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
