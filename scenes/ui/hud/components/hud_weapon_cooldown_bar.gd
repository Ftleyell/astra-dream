class_name HudWeaponCooldownBar
extends RefCounted

## HudWeaponCooldownBar.gd
## Controlador especializado para la barra de armas del HUD:
## - 4 Ranuras fijas de armas equipadas con niveles, tooltips y bordes por rareza.
## - Renderizado de estados vacíos con placeholders "+" para espacios disponibles.
## - Actualización en tiempo real de barridos de cooldown (CDOverlay) vía anchor vertical.

const TOTAL_SLOTS: int = 4

var weapon_slots_row: HBoxContainer = null

func setup(p_slots_row: HBoxContainer) -> void:
	weapon_slots_row = p_slots_row

func update_weapon_slots(weapons: Array, player_stats: Variant) -> void:
	if not is_instance_valid(weapon_slots_row):
		return

	for child in weapon_slots_row.get_children():
		weapon_slots_row.remove_child(child)
		child.queue_free()

	for slot_idx in range(TOTAL_SLOTS):
		if slot_idx < weapons.size() and weapons[slot_idx] != null:
			var inst = weapons[slot_idx]
			var wdata: WeaponData = inst.weapon_data
			var w_level: int = inst.level

			var chip := PanelContainer.new()
			chip.name = "WeaponSlot_%d" % slot_idx
			chip.custom_minimum_size = Vector2(54, 54)
			chip.clip_contents = true

			var eff_dmg: float = inst.get_effective_damage(player_stats)
			var eff_cd: float = inst.get_effective_cooldown(player_stats)
			chip.tooltip_text = "[Ranura %d] %s (★%d)\nDaño: %.1f | Enfriamiento: %.2fs\n%s" % [
				slot_idx + 1,
				wdata.weapon_name,
				w_level,
				eff_dmg,
				eff_cd,
				wdata.description
			]

			var rarity_color: Color = get_rarity_color(wdata.rarity)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.04, 0.06, 0.12, 0.95)
			style.set_border_width_all(2)
			style.border_color = rarity_color
			style.set_corner_radius_all(6)
			chip.add_theme_stylebox_override("panel", style)

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(inner)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if wdata.icon:
				icon_rect.texture = wdata.icon
			inner.add_child(icon_rect)

			var cd_overlay := ColorRect.new()
			cd_overlay.name = "CDOverlay"
			cd_overlay.color = Color(0.01, 0.02, 0.05, 0.75)
			cd_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cd_overlay.visible = false
			inner.add_child(cd_overlay)

			var slot_lbl := Label.new()
			slot_lbl.text = str(slot_idx + 1)
			slot_lbl.add_theme_font_size_override("font_size", 10)
			slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.5))
			slot_lbl.position = Vector2(4, 36)
			slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(slot_lbl)

			var lvl_lbl := Label.new()
			lvl_lbl.text = "★%d" % w_level
			lvl_lbl.add_theme_font_size_override("font_size", 11)
			lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			lvl_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
			lvl_lbl.add_theme_constant_override("shadow_offset_x", 1)
			lvl_lbl.add_theme_constant_override("shadow_offset_y", 1)
			lvl_lbl.position = Vector2(30, 2)
			lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(lvl_lbl)

			weapon_slots_row.add_child(chip)
		else:
			var empty_chip := PanelContainer.new()
			empty_chip.name = "WeaponSlot_Empty_%d" % slot_idx
			empty_chip.custom_minimum_size = Vector2(54, 54)
			empty_chip.tooltip_text = "Ranura #%d [Vacía]\n(Espacio disponible para nuevas armas)" % [slot_idx + 1]

			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.02, 0.04, 0.08, 0.45)
			style.border_color = Color(0.2, 0.35, 0.5, 0.35)
			style.set_border_width_all(1)
			style.set_corner_radius_all(6)
			empty_chip.add_theme_stylebox_override("panel", style)

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_chip.add_child(inner)

			var plus_lbl := Label.new()
			plus_lbl.text = "+"
			plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			plus_lbl.add_theme_font_size_override("font_size", 18)
			plus_lbl.add_theme_color_override("font_color", Color(0.3, 0.45, 0.6, 0.4))
			plus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(plus_lbl)

			var slot_lbl := Label.new()
			slot_lbl.text = str(slot_idx + 1)
			slot_lbl.add_theme_font_size_override("font_size", 10)
			slot_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5, 0.35))
			slot_lbl.position = Vector2(4, 36)
			slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(slot_lbl)

			weapon_slots_row.add_child(empty_chip)

func update_weapon_cooldown_sweeps(equipped_weapons: Array, player_stats: Variant) -> void:
	if not is_instance_valid(weapon_slots_row):
		return
	var slots: Array[Node] = weapon_slots_row.get_children()
	var count: int = mini(slots.size(), equipped_weapons.size())
	for i in range(count):
		var inst = equipped_weapons[i]
		if not inst:
			continue
		var slot_card: Node = slots[i]
		var cd_overlay := slot_card.find_child("CDOverlay", true, false) as ColorRect
		if not cd_overlay:
			continue
		var max_cd: float = inst.get_effective_cooldown(player_stats)
		if inst.active_cooldown > 0.02 and max_cd > 0.0:
			cd_overlay.visible = true
			var ratio: float = clampf(inst.active_cooldown / max_cd, 0.0, 1.0)
			cd_overlay.anchor_top = 1.0 - ratio
		else:
			cd_overlay.visible = false

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
			return Color.WHITE
