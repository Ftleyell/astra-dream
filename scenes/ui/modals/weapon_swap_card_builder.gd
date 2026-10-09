class_name WeaponSwapCardBuilder
extends RefCounted

## WeaponSwapCardBuilder.gd
## Constructor y estilizado de tarjetas de ranuras equipadas y arma entrante para WeaponSwapModal.

const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")


static func build_incoming_card(incoming_weapon: WeaponData) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var in_icon_panel := PanelContainer.new()
	in_icon_panel.custom_minimum_size = Vector2(88, 88)
	in_icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var in_icon_sb := StyleBoxFlat.new()
	in_icon_sb.bg_color = Color(0.02, 0.04, 0.08, 0.95)
	in_icon_sb.border_color = Color(0.2, 1.0, 0.6, 0.9)
	in_icon_sb.set_border_width_all(2)
	in_icon_sb.set_corner_radius_all(6)
	in_icon_panel.add_theme_stylebox_override("panel", in_icon_sb)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if incoming_weapon.icon:
		icon_rect.texture = incoming_weapon.icon
	in_icon_panel.add_child(icon_rect)
	hbox.add_child(in_icon_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.set("theme_override_constants/separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "★ NUEVA ADQUISICIÓN: %s" % incoming_weapon.weapon_name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	info_vbox.add_child(name_lbl)

	var stat_lbl := Label.new()
	stat_lbl.text = "⚡ Daño Base: %.0f   |   ⏱️ Enfriamiento: %.2fs" % [
		incoming_weapon.base_damage,
		incoming_weapon.base_cooldown
	]
	stat_lbl.add_theme_font_size_override("font_size", 12)
	stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	info_vbox.add_child(stat_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = incoming_weapon.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
	info_vbox.add_child(desc_lbl)

	hbox.add_child(info_vbox)
	return hbox


static func build_slot_card(
	slot_idx: int,
	inst: WeaponInstanceData,
	incoming_weapon: WeaponData,
	on_replace_pressed: Callable
) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(195, 290)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var w_rarity: Enums.Rarity = inst.weapon_data.rarity if inst.weapon_data else Enums.Rarity.COMMON
	var border_col: Color = get_rarity_color(w_rarity)

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.04, 0.06, 0.11, 0.95)
	csb.border_color = border_col
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 10
	csb.content_margin_right = 10
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", csb)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	pc.add_child(card_vbox)

	var is_base_weapon: bool = (slot_idx == 0)

	var slot_title := Label.new()
	slot_title.text = "🔒 RANURA #1 (FIJA)" if is_base_weapon else ("[Tecla %d] RANURA #%d" % [slot_idx + 1, slot_idx + 1])
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title.add_theme_font_size_override("font_size", 12)
	slot_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_base_weapon else Color(0.2, 0.9, 1.0))
	card_vbox.add_child(slot_title)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(88, 88)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.02, 0.04, 0.07, 0.95)
	icon_sb.border_color = border_col
	icon_sb.set_border_width_all(2)
	icon_sb.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_sb)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if inst.weapon_data and inst.weapon_data.icon:
		icon_rect.texture = inst.weapon_data.icon
	icon_panel.add_child(icon_rect)
	card_vbox.add_child(icon_panel)

	var w_name: String = inst.weapon_data.weapon_name if inst.weapon_data else "Arma"
	var name_lbl := Label.new()
	name_lbl.text = w_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(name_lbl)

	var stats_p_vbox := VBoxContainer.new()
	stats_p_vbox.set("theme_override_constants/separation", 2)

	var cur_dmg: float = inst.get_effective_damage()
	var cur_cd: float = inst.get_effective_cooldown()

	var stat_dmg_lbl := Label.new()
	stat_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_dmg_lbl.add_theme_font_size_override("font_size", 10)
	if incoming_weapon and not is_base_weapon:
		var in_dmg: float = incoming_weapon.base_damage
		if in_dmg > cur_dmg:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (➔ %.0f ▲)" % [cur_dmg, in_dmg]
			stat_dmg_lbl.add_theme_color_override("font_color", Color("#00FF9D"))
		elif in_dmg < cur_dmg:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (➔ %.0f ▼)" % [cur_dmg, in_dmg]
			stat_dmg_lbl.add_theme_color_override("font_color", Color("#FF6677"))
		else:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (=)" % cur_dmg
			stat_dmg_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		stat_dmg_lbl.text = "⚡ Daño Actual: %.0f" % cur_dmg
		stat_dmg_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	stats_p_vbox.add_child(stat_dmg_lbl)

	var stat_cd_lbl := Label.new()
	stat_cd_lbl.text = "⏱️ Enfriamiento: %.2fs" % cur_cd
	stat_cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_cd_lbl.add_theme_font_size_override("font_size", 10)
	stat_cd_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	stats_p_vbox.add_child(stat_cd_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "★ Nivel: %d %s" % [inst.level, ("" if is_base_weapon else "(➔ Hereda: ★%d)" % inst.level)]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	stats_p_vbox.add_child(level_lbl)

	var recycle_credits: int = WeaponController.calculate_recycle_credits(inst.level)
	var recycle_lbl := Label.new()
	recycle_lbl.text = "◈ NO SUSTITUIBLE ◈" if is_base_weapon else ("Reciclaje: +%d 🪙" % recycle_credits)
	recycle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_lbl.add_theme_font_size_override("font_size", 10)
	recycle_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7) if is_base_weapon else Color(1.0, 0.78, 0.2))
	stats_p_vbox.add_child(recycle_lbl)

	card_vbox.add_child(stats_p_vbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(spacer)

	var rep_btn := Button.new()
	rep_btn.name = "ReplaceBtn"
	rep_btn.text = "BLOQUEADA" if is_base_weapon else ("Sustituir [%d]" % [slot_idx + 1])
	rep_btn.custom_minimum_size = Vector2(0, 32)
	rep_btn.disabled = is_base_weapon
	if is_base_weapon:
		rep_btn.focus_mode = Control.FOCUS_NONE
		rep_btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		rep_btn.focus_mode = Control.FOCUS_ALL
		UIFocusHelper.apply_cyber_focus(rep_btn)
		rep_btn.pressed.connect(on_replace_pressed.bind(slot_idx))
	card_vbox.add_child(rep_btn)

	return pc


static func get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON:
			return Color(0.5, 0.8, 1.0, 0.95)
		Enums.Rarity.UNCOMMON:
			return Color(0.2, 0.95, 0.4, 0.95)
		Enums.Rarity.RARE:
			return Color(1.0, 0.8, 0.15, 1.0)
		Enums.Rarity.LEGENDARY:
			return Color(0.9, 0.3, 1.0, 1.0)
		_:
			return Color(0.6, 0.7, 0.8, 0.95)
