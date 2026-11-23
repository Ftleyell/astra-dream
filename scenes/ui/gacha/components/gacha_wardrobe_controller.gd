class_name GachaWardrobeController
extends RefCounted

## GachaWardrobeController.gd
## Controlador del Armario y Colección de Skins:
## - Filtros por categoría (naves, pilotos, armas, mascotas, navegantes).
## - Conmutador de visibilidad (ocultar skins bloqueadas).
## - Construcción reactiva de cartas de cosméticos con opciones de equipar/desequipar.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")
const ShaderSkinLivePreviewScript = preload("res://scenes/ui/cosmetics/components/shader_skin_live_preview.gd")
const ShaderSkinSwatchScript = preload("res://scenes/ui/cosmetics/components/shader_skin_swatch.gd")

signal skin_equipped(slot_key: String, skin_id: String)

var _wardrobe_content: VBoxContainer
var _hide_locked_check: CheckBox
var _wardrobe_grid: GridContainer
var _live_inspector_preview: ShaderSkinLivePreview = null
var _live_inspector_tex: TextureRect = null
var _live_inspector_title: Label = null
var _live_inspector_sub: Label = null
var _selected_preview_skin_id: String = ""

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
		{"id": "ship", "label": "🪽 ALAS / NAVES"},
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

	# Body split: Grid (izquierda) + único ShaderSkinLivePreview compartido (derecha)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	_wardrobe_content.add_child(body_hbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(scroll)

	_wardrobe_grid = GridContainer.new()
	_wardrobe_grid.columns = 3
	_wardrobe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wardrobe_grid.add_theme_constant_override("h_separation", 14)
	_wardrobe_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_wardrobe_grid)

	var inspector_panel := PanelContainer.new()
	inspector_panel.custom_minimum_size = Vector2(248, 0)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.05, 0.04, 0.12, 0.96)
	isb.border_color = Color(0.0, 0.85, 1.0, 0.55)
	isb.set_border_width_all(2)
	isb.set_corner_radius_all(10)
	isb.content_margin_left = 12
	isb.content_margin_right = 12
	isb.content_margin_top = 12
	isb.content_margin_bottom = 12
	inspector_panel.add_theme_stylebox_override("panel", isb)
	body_hbox.add_child(inspector_panel)

	var insp_vbox := VBoxContainer.new()
	insp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_vbox.add_theme_constant_override("separation", 8)
	inspector_panel.add_child(insp_vbox)

	var insp_hdr := Label.new()
	insp_hdr.text = "VISTA PREVIA EN VIVO"
	insp_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_hdr.add_theme_font_size_override("font_size", 12)
	insp_hdr.add_theme_color_override("font_color", Color(0.2, 0.94, 1.0, 1.0))
	insp_vbox.add_child(insp_hdr)

	var insp_holder := CenterContainer.new()
	insp_holder.custom_minimum_size = Vector2(220, 260)
	insp_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp_vbox.add_child(insp_holder)

	_live_inspector_preview = ShaderSkinLivePreviewScript.new() as ShaderSkinLivePreview
	_live_inspector_preview.custom_minimum_size = Vector2(220, 260)
	_live_inspector_preview.visible = false
	_live_inspector_preview.set_preview_paused(true)
	insp_holder.add_child(_live_inspector_preview)

	_live_inspector_tex = TextureRect.new()
	_live_inspector_tex.custom_minimum_size = Vector2(180, 180)
	_live_inspector_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_live_inspector_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_live_inspector_tex.visible = false
	insp_holder.add_child(_live_inspector_tex)

	_live_inspector_title = Label.new()
	_live_inspector_title.text = "Selecciona un aspecto"
	_live_inspector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live_inspector_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_inspector_title.add_theme_font_size_override("font_size", 13)
	insp_vbox.add_child(_live_inspector_title)

	_live_inspector_sub = Label.new()
	_live_inspector_sub.text = ""
	_live_inspector_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live_inspector_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_inspector_sub.add_theme_font_size_override("font_size", 11)
	_live_inspector_sub.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.85))
	insp_vbox.add_child(_live_inspector_sub)

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

	var first_skin: Dictionary = {}
	var first_stars: int = 1
	var first_unlocked: bool = false
	var selected_skin_data: Dictionary = {}
	var selected_stars: int = 1
	var selected_unlocked: bool = false

	for sid: String in all_skins.keys():
		var skin: Dictionary = all_skins[sid]
		if not CosmeticsManager.is_skin_eligible_for_gacha(skin):
			continue
		var cat: String = skin.get("category", "")
		if category_id != "all":
			if category_id == "ship" or category_id == "wings":
				if cat != "ship" and cat != "wings":
					continue
			elif cat != category_id:
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

		if first_skin.is_empty():
			first_skin = skin
			first_stars = stars
			first_unlocked = is_unlocked
		if sid == _selected_preview_skin_id or (selected_skin_data.is_empty() and is_equipped):
			selected_skin_data = skin
			selected_stars = stars
			selected_unlocked = is_unlocked

		var item_card: Control = _create_wardrobe_card(skin, is_unlocked, stars, is_equipped, slot_key)
		_wardrobe_grid.add_child(item_card)

	if not selected_skin_data.is_empty():
		_update_inspector_preview(selected_skin_data, selected_stars, selected_unlocked)
	elif not first_skin.is_empty():
		_update_inspector_preview(first_skin, first_stars, first_unlocked)
	else:
		_clear_inspector_preview()

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
	frame.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_update_inspector_preview(skin, stars, is_unlocked)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	if CosmeticsManager.is_shader_skin(skin):
		var swatch: ShaderSkinSwatch = ShaderSkinSwatchScript.new() as ShaderSkinSwatch
		swatch.custom_minimum_size = Vector2(80, 80)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var preset: PilotSkinPreset = CosmeticsManager.get_skin_preset(str(skin.get("id", "")))
		swatch.configure_swatch(preset, str(skin.get("category", "pilot")), maxi(stars, 1), not is_unlocked, false)
		vbox.add_child(swatch)
	else:
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
				_sync_loadout_for_slot(slot_key, "")
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
				_sync_loadout_for_slot(slot_key, sid)
				_selected_preview_skin_id = sid
				skin_equipped.emit(slot_key, sid)
				filter_wardrobe(active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(eq_btn)
			vbox.add_child(eq_btn)

	return frame


func _sync_loadout_for_slot(slot_key: String, skin_id: String) -> void:
	var parts: PackedStringArray = slot_key.split(":")
	if parts.size() < 2:
		return
	var cat: String = parts[0]
	var tid: StringName = StringName(parts[1].to_lower())
	if cat in ["pilot", "wings", "ship", "weapon"]:
		var loadout: Dictionary = SaveManager.get_character_loadout(tid)
		var has_shader: bool = CosmeticsManager.has_shader_skin_catalog(tid)
		var fallback_val: String = CosmeticsManager.FOLLOW_PILOT_SKIN_ID if (has_shader and cat in ["wings", "ship", "weapon"]) else "base"
		var eff_id: String = skin_id if not skin_id.is_empty() else fallback_val
		match cat:
			"pilot":
				loadout["equipped_pilot_skin"] = eff_id
				loadout["pilot_skin"] = eff_id
			"wings", "ship":
				loadout["equipped_wings_skin"] = eff_id
				loadout["equipped_ship_skin"] = eff_id
				loadout["ship_skin"] = eff_id
			"weapon":
				loadout["equipped_weapon_skin"] = eff_id
				loadout["weapon_skin"] = eff_id
		SaveManager.set_character_loadout(tid, loadout)


func _update_inspector_preview(skin: Dictionary, stars: int, is_unlocked: bool) -> void:
	if skin.is_empty():
		_clear_inspector_preview()
		return
	var sid: String = str(skin.get("id", ""))
	_selected_preview_skin_id = sid
	if _live_inspector_title != null:
		_live_inspector_title.text = str(skin.get("skin_name", sid))
	if _live_inspector_sub != null:
		var t_name: String = str(skin.get("target_name", ""))
		var star_tag: String = ("%d★" % stars) if is_unlocked else "BLOQUEADA"
		_live_inspector_sub.text = "%s · %s" % [t_name, star_tag]

	if CosmeticsManager.is_shader_skin(skin):
		if _live_inspector_tex != null:
			_live_inspector_tex.visible = false
		if _live_inspector_preview != null:
			var cat: String = str(skin.get("category", "pilot"))
			var tid: StringName = StringName(str(skin.get("target_id", "valentina")).to_lower())
			var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
			var cd: CharacterData = roster.get(tid, null)
			var prof: PilotRigProfile = cd.pilot_rig_profile if cd != null else null
			_live_inspector_preview.configure(cat, prof, Vector2i(220, 260))
			var preset: PilotSkinPreset = CosmeticsManager.get_skin_preset(sid)
			_live_inspector_preview.apply_skin_preset(preset, maxi(stars, 1), not is_unlocked)
			_live_inspector_preview.visible = true
			_live_inspector_preview.set_preview_paused(false)
	else:
		if _live_inspector_preview != null:
			_live_inspector_preview.set_preview_paused(true)
			_live_inspector_preview.visible = false
		if _live_inspector_tex != null:
			_live_inspector_tex.texture = CosmeticsManager.get_skin_texture(skin)
			_live_inspector_tex.visible = (_live_inspector_tex.texture != null)
			if is_unlocked:
				CosmeticsManager.apply_skin_to_canvas_item(_live_inspector_tex, sid, stars, false)
			else:
				_live_inspector_tex.material = null
				_live_inspector_tex.modulate = Color(0.35, 0.35, 0.45, 0.7)


func _clear_inspector_preview() -> void:
	_selected_preview_skin_id = ""
	if _live_inspector_preview != null:
		_live_inspector_preview.set_preview_paused(true)
		_live_inspector_preview.visible = false
	if _live_inspector_tex != null:
		_live_inspector_tex.visible = false
	if _live_inspector_title != null:
		_live_inspector_title.text = "Sin aspectos visibles"
	if _live_inspector_sub != null:
		_live_inspector_sub.text = ""


func get_live_inspector_preview() -> ShaderSkinLivePreview:
	return _live_inspector_preview


func pause_inspector_preview() -> void:
	if _live_inspector_preview != null:
		_live_inspector_preview.set_preview_paused(true)
