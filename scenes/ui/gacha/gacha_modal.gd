class_name GachaModal
extends CanvasLayer

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")

signal skin_unlocked(skin_id: String, stars: int)
signal skin_equipped(slot_key: String, skin_id: String)
signal modal_closed()

var is_animating: bool = false
var _active_tab: int = 0 # 0 = Gacha, 1 = Wardrobe
var _active_category_filter: String = "all"
var _hide_locked: bool = false

# UI Nodes
var _panel: PanelContainer
var _token_count_label: Label
var _biomass_count_label: Label
var _tab_gacha_btn: Button
var _tab_wardrobe_btn: Button
var _gacha_content: VBoxContainer
var _wardrobe_content: VBoxContainer
var _hide_locked_check: CheckBox
var _results_layer: PanelContainer
var _results_grid: GridContainer
var _animation_overlay: Control
var _wardrobe_grid: GridContainer

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980, 680)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.12, 0.98)
	sb.border_color = Color(0.0, 0.94, 1.0, 0.9) # Cyan neon
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(root_vbox)

	# --- TOP HEADER ---
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_vbox.add_child(top_bar)

	var title := Label.new()
	title.text = "🎰 CÁPSULAS GACHA DE COSMÉTICOS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	top_bar.add_child(title)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	_token_count_label = Label.new()
	_token_count_label.text = "🎟️ Fichas: 0"
	_token_count_label.add_theme_font_size_override("font_size", 16)
	_token_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	top_bar.add_child(_token_count_label)

	var token_spacer := Control.new()
	token_spacer.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(token_spacer)

	_biomass_count_label = Label.new()
	_biomass_count_label.text = "✨ Polvo Estelar: 0"
	_biomass_count_label.add_theme_font_size_override("font_size", 16)
	_biomass_count_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))
	top_bar.add_child(_biomass_count_label)

	var close_btn := Button.new()
	close_btn.text = " ✖ CERRAR "
	close_btn.pressed.connect(_on_close_pressed)
	top_bar.add_child(close_btn)

	# --- TAB SWITCHER ---
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(tab_bar)

	_tab_gacha_btn = Button.new()
	_tab_gacha_btn.text = "🎰 MÁQUINA DE TIRADAS"
	_tab_gacha_btn.custom_minimum_size = Vector2(240, 38)
	_tab_gacha_btn.pressed.connect(func(): _switch_tab(0))
	tab_bar.add_child(_tab_gacha_btn)

	_tab_wardrobe_btn = Button.new()
	_tab_wardrobe_btn.text = "👗 ARMARIO / COLECCIÓN DE SKINS"
	_tab_wardrobe_btn.custom_minimum_size = Vector2(280, 38)
	_tab_wardrobe_btn.pressed.connect(func(): _switch_tab(1))
	tab_bar.add_child(_tab_wardrobe_btn)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	# --- TAB 1: GACHA ROLLS CONTENT ---
	_gacha_content = VBoxContainer.new()
	_gacha_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gacha_content.add_theme_constant_override("separation", 16)
	root_vbox.add_child(_gacha_content)

	# Banner
	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.1, 0.08, 0.22, 0.8)
	bsb.border_color = Color(0.8, 0.3, 1.0, 0.6)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(10)
	bsb.content_margin_left = 24
	bsb.content_margin_right = 24
	bsb.content_margin_top = 16
	bsb.content_margin_bottom = 16
	banner.add_theme_stylebox_override("panel", bsb)
	_gacha_content.add_child(banner)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 6)
	banner.add_child(b_vbox)

	var b_title := Label.new()
	b_title.text = "🌟 SISTEMA DE PROGRESIÓN DE ESTRELLAS (1★ ➔ 2★ ➔ 3★)"
	b_title.add_theme_font_size_override("font_size", 16)
	b_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	b_vbox.add_child(b_title)

	var b_desc := Label.new()
	b_desc.text = "• 1★: Recolor Base | •• 2★: Shader de Glow Neón | ••• 3★: Resonancia y Partículas Estelares\n• Los duplicados de cosméticos en nivel 3★ se convierten automáticamente en +150 Polvo Estelar."
	b_desc.add_theme_font_size_override("font_size", 13)
	b_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1.0))
	b_vbox.add_child(b_desc)

	# Action Buttons Box
	var roll_btn_box := HBoxContainer.new()
	roll_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_btn_box.add_theme_constant_override("separation", 24)
	_gacha_content.add_child(roll_btn_box)

	var pull_1_btn := Button.new()
	pull_1_btn.text = "🎟️ TIRADA SIMPLE\n(1 Ficha)"
	pull_1_btn.custom_minimum_size = Vector2(200, 60)
	pull_1_btn.pressed.connect(func(): _execute_gacha_pulls(1))
	roll_btn_box.add_child(pull_1_btn)

	var pull_5_btn := Button.new()
	pull_5_btn.text = "🎟️ MULTI-TIRADA x5\n(5 Fichas)"
	pull_5_btn.custom_minimum_size = Vector2(200, 60)
	pull_5_btn.pressed.connect(func(): _execute_gacha_pulls(5))
	roll_btn_box.add_child(pull_5_btn)

	var pull_10_btn := Button.new()
	pull_10_btn.text = "🎟️ MULTI-TIRADA x10\n(10 Fichas)"
	pull_10_btn.custom_minimum_size = Vector2(200, 60)
	pull_10_btn.pressed.connect(func(): _execute_gacha_pulls(10))
	roll_btn_box.add_child(pull_10_btn)

	# --- TAB 2: WARDROBE CONTENT ---
	_wardrobe_content = VBoxContainer.new()
	_wardrobe_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wardrobe_content.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_wardrobe_content)
	_wardrobe_content.hide()

	# Filter buttons
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 10)
	_wardrobe_content.add_child(filter_bar)

	var cats := [
		{"id": "all", "label": "TODAS"},
		{"id": "ship", "label": "🚀 NAVES"},
		{"id": "pilot", "label": "👩‍✈️ PILOTOS"},
		{"id": "weapon", "label": "⚡ ARMAS"},
		{"id": "pet", "label": "🐾 PETS"},
		{"id": "navigator", "label": "📡 NAVEGADORAS"}
	]
	for c in cats:
		var b := Button.new()
		b.text = c["label"]
		var cid: String = c["id"]
		b.pressed.connect(func(): _filter_wardrobe(cid))
		UIFocusHelper.apply_cyber_focus(b)
		filter_bar.add_child(b)

	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(filter_spacer)

	_hide_locked_check = CheckBox.new()
	_hide_locked_check.text = "👁️ Ocultar no adquiridos"
	_hide_locked_check.button_pressed = _hide_locked
	_hide_locked_check.toggled.connect(func(pressed: bool):
		_hide_locked = pressed
		_filter_wardrobe(_active_category_filter)
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

	# --- RESULTS REVEAL OVERLAY ---
	_results_layer = PanelContainer.new()
	_results_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.02, 0.01, 0.06, 0.95)
	_results_layer.add_theme_stylebox_override("panel", rsb)
	add_child(_results_layer)
	_results_layer.hide()

	var res_vbox := VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.add_theme_constant_override("separation", 20)
	_results_layer.add_child(res_vbox)

	var res_title := Label.new()
	res_title.text = "🎉 ¡RECOMPENSAS DEL GACHA OBTENIDAS! 🎉"
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_title.add_theme_font_size_override("font_size", 22)
	res_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	res_vbox.add_child(res_title)

	var res_scroll := ScrollContainer.new()
	res_scroll.custom_minimum_size = Vector2(850, 420)
	res_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_child(res_scroll)

	var res_center := CenterContainer.new()
	res_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_scroll.add_child(res_center)

	_results_grid = GridContainer.new()
	_results_grid.columns = 5
	_results_grid.add_theme_constant_override("h_separation", 14)
	_results_grid.add_theme_constant_override("v_separation", 14)
	res_center.add_child(_results_grid)

	var res_close_btn := Button.new()
	res_close_btn.text = "✨ RECLAMAR Y CONTINUAR"
	res_close_btn.custom_minimum_size = Vector2(260, 48)
	res_close_btn.pressed.connect(func(): _results_layer.hide(); _refresh_currency())
	res_vbox.add_child(res_close_btn)

func open_gacha_modal() -> void:
	_refresh_currency()
	_switch_tab(0)
	show()
	get_tree().paused = true

func _refresh_currency() -> void:
	var tokens := SaveManager.get_gacha_tokens()
	var bio := SaveManager.get_biomass()
	_token_count_label.text = "🎟️ Fichas: %d" % tokens
	_biomass_count_label.text = "✨ Polvo Estelar: %d" % bio

func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	if tab_idx == 0:
		_gacha_content.show()
		_wardrobe_content.hide()
		_tab_gacha_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		_gacha_content.hide()
		_wardrobe_content.show()
		_tab_gacha_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_filter_wardrobe(_active_category_filter)

func execute_pulls(count: int) -> Array[Dictionary]:
	var current_tokens := SaveManager.get_gacha_tokens()
	if current_tokens < count:
		return []

	# Spend tokens
	SaveManager.spend_gacha_tokens(count)
	if _token_count_label and _biomass_count_label:
		_refresh_currency()

	# Generate pulls
	var pulled_results: Array[Dictionary] = []
	for i in range(count):
		var raw_skin := CosmeticsManager.roll_random_skin()
		if raw_skin.is_empty():
			continue
		var skin_id: String = raw_skin.get("id", "")
		var upgrade_res := SaveManager.unlock_or_upgrade_skin(skin_id)
		
		pulled_results.append({
			"skin_data": raw_skin,
			"upgrade_data": upgrade_res
		})

	if _results_grid and _results_layer:
		_display_pull_results(pulled_results)

	return pulled_results

func _execute_gacha_pulls(count: int) -> void:
	var current_tokens := SaveManager.get_gacha_tokens()
	if current_tokens < count:
		# Flash token label red
		if _token_count_label:
			_token_count_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
			var tw := create_tween()
			if tw:
				tw.tween_property(_token_count_label, "modulate", Color.WHITE, 0.6)
		return

	execute_pulls(count)

func _display_pull_results(results: Array[Dictionary]) -> void:
	# Clear previous cards
	for child in _results_grid.get_children():
		child.queue_free()

	for res in results:
		var skin: Dictionary = res.get("skin_data", {})
		var upg: Dictionary = res.get("upgrade_data", {})
		var card := _create_reward_card(skin, upg)
		_results_grid.add_child(card)

	_results_layer.show()

func _create_reward_card(skin: Dictionary, upg: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(150, 190)

	var stars: int = int(upg.get("new_stars", 1))
	var status: String = str(upg.get("status", "new"))
	var glow_hex: String = skin.get("glow_hex", "#00F0FF")

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.06, 0.16, 0.95)
	csb.border_color = Color.from_string(glow_hex, Color.CYAN)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 10
	csb.content_margin_right = 10
	csb.content_margin_top = 8
	csb.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	frame.add_child(vbox)

	# Image Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = skin.get("texture_path", "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars)
	vbox.add_child(icon)

	# Target Name
	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 12)
	t_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(t_name)

	# Skin / Palette Name
	var s_name := Label.new()
	s_name.text = skin.get("skin_name", "")
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.add_theme_font_size_override("font_size", 11)
	s_name.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 1.0))
	vbox.add_child(s_name)

	# Stars Label
	var star_str := ""
	for i in range(stars):
		star_str += "⭐"
	var stars_lbl := Label.new()
	stars_lbl.text = star_str
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stars_lbl)

	# Status tag
	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	match status:
		"new":
			tag.text = "¡NUEVO DESBLOQUEO!"
			tag.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		"upgraded":
			tag.text = "¡MEJORA A %d★!" % stars
			tag.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
		"max_converted":
			tag.text = "⭐ 3★ ➔ +150 POLVO"
			tag.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	vbox.add_child(tag)

	return frame

func _filter_wardrobe(category: String) -> void:
	_active_category_filter = category
	for child in _wardrobe_grid.get_children():
		_wardrobe_grid.remove_child(child)
		child.queue_free()

	var skins: Array[Dictionary] = []
	if category == "all":
		var all_dict := CosmeticsManager.get_all_skins()
		for k in all_dict.keys():
			skins.append(all_dict[k])
	else:
		skins = CosmeticsManager.get_skins_by_category(category)

	var unlocked := SaveManager.get_unlocked_skins()
	var equipped := SaveManager.get_equipped_skins()

	for skin in skins:
		var sid: String = skin.get("id", "")
		var is_unlocked: bool = unlocked.has(sid)
		if _hide_locked and not is_unlocked:
			continue
		var stars: int = SaveManager.get_skin_stars(sid)
		var slot_key: String = "%s:%s" % [skin.get("category", ""), skin.get("target_id", "")]
		var is_equipped: bool = (String(equipped.get(slot_key, "")) == sid)

		var card := _create_wardrobe_card(skin, is_unlocked, stars, is_equipped, slot_key)
		_wardrobe_grid.add_child(card)

func _create_wardrobe_card(skin: Dictionary, is_unlocked: bool, stars: int, is_equipped: bool, slot_key: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(210, 230)

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.07, 0.05, 0.14, 0.95) if is_unlocked else Color(0.03, 0.02, 0.06, 0.7)
	csb.border_color = Color(0.2, 1.0, 0.8, 0.9) if is_equipped else (Color(0.8, 0.4, 1.0, 0.7) if is_unlocked else Color(0.25, 0.25, 0.35, 0.4))
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	frame.add_child(vbox)

	# Vista previa gráfica con Shader
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = skin.get("texture_path", "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)

	if is_unlocked:
		CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars)
	else:
		icon.modulate = Color(0.25, 0.25, 0.35, 0.6)
	vbox.add_child(icon)

	# Nombre de la entidad (Nave, Piloto, Pet, etc.)
	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 11)
	t_name.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.85))
	vbox.add_child(t_name)

	# Nombre de la skin / paleta
	var title := Label.new()
	title.text = skin.get("skin_name", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if is_unlocked else Color(0.5, 0.5, 0.6, 0.8))
	vbox.add_child(title)

	# Estrellas o Candado
	var star_lbl := Label.new()
	var star_str := ""
	for i in range(stars):
		star_str += "⭐"
	star_lbl.text = star_str if is_unlocked else "🔒 BLOQUEADO"
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if is_unlocked else Color(0.5, 0.5, 0.6, 0.8))
	vbox.add_child(star_lbl)

	# Controles de Equipar / Quitar
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
				_filter_wardrobe(_active_category_filter)
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
				_filter_wardrobe(_active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(eq_btn)
			vbox.add_child(eq_btn)

	return frame


func close_modal() -> void:
	_on_close_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _results_layer and _results_layer.visible:
			_results_layer.hide()
			_refresh_currency()
			get_viewport().set_input_as_handled()
			return
		close_modal()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	hide()
	get_tree().paused = false
	modal_closed.emit()

