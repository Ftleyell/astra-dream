class_name GameOverLayoutBuilder
extends RefCounted

## Constructor desacoplado para poblar visualmente contenedores de loadout
## (Arcanas, Ítems, Armas) y generar chips estilizados en la UI de GameOver.

static func populate_arcanas(container: HFlowContainer, arcanas_list: Array) -> void:
	if not container:
		return
	for c in container.get_children():
		c.queue_free()

	if arcanas_list.is_empty():
		_add_empty_label(container, "Ningún pacto astra sellado.")
		return

	for arc in arcanas_list:
		if not (arc is ArcanaData):
			continue
		var arc_data := arc as ArcanaData
		var chip: PanelContainer = create_chip(arc_data.name, arc_data.color_accent, arc_data.icon, Vector2(28, 28))
		container.add_child(chip)

static func populate_items(container: HFlowContainer, items_list: Array) -> void:
	if not container:
		return
	for c in container.get_children():
		c.queue_free()

	if items_list.is_empty():
		_add_empty_label(container, "Ningún ítem recolectado.")
		return

	for item_entry in items_list:
		var item_res: ItemData = item_entry.get("data") if item_entry is Dictionary else null
		var count: int = int(item_entry.get("count", 1)) if item_entry is Dictionary else 1
		if not item_res:
			continue
		var chip_text: String = item_res.item_name
		if count > 1:
			chip_text += " [x%d]" % count
		
		var rarity_col: Color = _resolve_rarity_color(item_res.rarity)
		var chip: PanelContainer = create_chip(chip_text, rarity_col, item_res.icon, Vector2(28, 28))
		container.add_child(chip)

static func populate_weapons(container: HFlowContainer, weapons_list: Array) -> void:
	if not container:
		return
	for c in container.get_children():
		c.queue_free()

	if weapons_list.is_empty():
		_add_empty_label(container, "Arma básica estándar.")
		return

	for w_info in weapons_list:
		var w_name: String = ""
		var w_lvl: int = 1
		var w_icon: Texture2D = null
		if w_info is Dictionary:
			w_name = str(w_info.get("name", ""))
			var raw_id: String = str(w_info.get("id", ""))
			if w_name.is_empty() or w_name == "Arma" or w_name.contains("_"):
				w_name = WeaponData.get_stylized_name_for_id(raw_id if not raw_id.is_empty() else w_name)
			w_lvl = int(w_info.get("level", 1))
			w_icon = w_info.get("icon", null)
		elif "weapon_data" in w_info and w_info.weapon_data:
			if w_info.weapon_data.has_method("get_display_name"):
				w_name = w_info.weapon_data.get_display_name()
			elif "weapon_name" in w_info.weapon_data and not w_info.weapon_data.weapon_name.is_empty():
				w_name = w_info.weapon_data.weapon_name
			else:
				w_name = WeaponData.get_stylized_name_for_id(str(w_info.weapon_data.weapon_id))
			w_lvl = int(w_info.level) if "level" in w_info else 1
			w_icon = w_info.weapon_data.icon if "icon" in w_info.weapon_data else null
		elif "weapon_id" in w_info:
			w_name = WeaponData.get_stylized_name_for_id(str(w_info.weapon_id))
		else:
			w_name = WeaponData.get_stylized_name_for_id(str(w_info))

		if w_name.is_empty():
			w_name = "Arma Estelar"

		var chip_text: String = "%s (Nv. %d)" % [w_name, w_lvl]
		var chip: PanelContainer = create_chip(chip_text, Color(1.0, 0.8, 0.25, 1.0), w_icon, Vector2(32, 32))
		container.add_child(chip)

static func create_chip(text: String, accent_color: Color, icon_tex: Texture2D = null, icon_size: Vector2 = Vector2(24, 24)) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
	style.shadow_size = 4
	chip.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	if icon_tex:
		var tr: TextureRect = TextureRect.new()
		tr.texture = icon_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = icon_size
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(tr)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.92, 0.96, 1.0, 1.0)
	hbox.add_child(lbl)

	chip.add_child(hbox)
	return chip

static func _add_empty_label(container: HFlowContainer, empty_text: String) -> void:
	var empty_lbl: Label = Label.new()
	empty_lbl.text = empty_text
	empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.6)
	empty_lbl.add_theme_font_size_override("font_size", 12)
	container.add_child(empty_lbl)

static func _resolve_rarity_color(rarity: int) -> Color:
	match rarity:
		Enums.Rarity.UNCOMMON:
			return Color(0.2, 0.9, 0.4, 1.0)
		Enums.Rarity.RARE:
			return Color(0.1, 0.6, 1.0, 1.0)
		Enums.Rarity.EPIC:
			return Color(0.8, 0.3, 1.0, 1.0)
		Enums.Rarity.LEGENDARY:
			return Color(1.0, 0.75, 0.2, 1.0)
		_:
			return Color(0.3, 0.8, 0.9, 1.0)
