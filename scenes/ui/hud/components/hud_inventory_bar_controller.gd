class_name HUDInventoryBarController
extends RefCounted

const TomeDataScript = preload("res://data/tomes/tome_data.gd")

## HUDInventoryBarController.gd
## Controlador especializado para el inventario in-run en el HUD:
## - 4 Ranuras fijas de armas equipadas con niveles, tooltips y barridos de CD.
## - Fichas de ítems pasivos coleccionados con contador de acumulaciones.
## - Contadores numéricos de créditos y biomasa con animación punch.

var weapon_slots_row: HBoxContainer
var tome_slots_row: HBoxContainer
var inventory_row: HBoxContainer
var credits_label: Label
var biomass_label: Label
var credit_icon: TextureRect

var current_credits: int = 120
var current_biomass: int = 0
var _inventory_chips: Dictionary[StringName, PanelContainer] = {}
var _credit_punch_tween: Tween = null

func setup(elements: Dictionary) -> void:
	weapon_slots_row = elements.get("weapon_slots_row") as HBoxContainer
	tome_slots_row = elements.get("tome_slots_row") as HBoxContainer
	inventory_row = elements.get("inventory_row") as HBoxContainer
	credits_label = elements.get("credits_label") as Label
	biomass_label = elements.get("biomass_label") as Label
	credit_icon = elements.get("credit_icon") as TextureRect

func get_inventory_chips() -> Dictionary[StringName, PanelContainer]:
	return _inventory_chips

func update_weapon_slots(weapons: Array, player_stats: Variant) -> void:
	if not weapon_slots_row:
		return
	for child in weapon_slots_row.get_children():
		weapon_slots_row.remove_child(child)
		child.queue_free()

	const TOTAL_SLOTS: int = 4
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

			var rarity_color := get_rarity_color(wdata.rarity)
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

func update_tome_slots(tomes: Array, levels: Dictionary) -> void:
	if not tome_slots_row:
		return
	for child in tome_slots_row.get_children():
		tome_slots_row.remove_child(child)
		child.queue_free()

	const TOTAL_TOME_SLOTS: int = 4
	for slot_idx in range(TOTAL_TOME_SLOTS):
		var chip := PanelContainer.new()
		chip.name = "TomeSlot_%d" % slot_idx
		chip.custom_minimum_size = Vector2(40, 40)
		chip.clip_contents = true

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.05, 0.09, 0.9)
		style.set_corner_radius_all(6)

		if slot_idx < tomes.size() and tomes[slot_idx] != null:
			var tome: TomeDataScript = tomes[slot_idx]
			var t_level: int = int(levels.get(tome.tome_id, 1))

			style.set_border_width_all(2)
			style.border_color = Color(0.9, 0.75, 0.2, 0.85)
			chip.add_theme_stylebox_override("panel", style)

			var bonus_text: String = tome.get_bonus_description(t_level)
			chip.tooltip_text = "[Tomo %d] %s (Nvl. %d)\n%s\nEfecto: %s" % [
				slot_idx + 1,
				tome.display_name,
				t_level,
				tome.description,
				bonus_text
			]

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(inner)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if tome.icon:
				icon_rect.texture = tome.icon
			inner.add_child(icon_rect)

			var lvl_lbl := Label.new()
			lvl_lbl.text = "★%d" % t_level
			lvl_lbl.add_theme_font_size_override("font_size", 10)
			lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
			lvl_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			lvl_lbl.add_theme_constant_override("shadow_outline_size", 2)
			lvl_lbl.position = Vector2(16, 22)
			lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(lvl_lbl)
		else:
			style.set_border_width_all(1)
			style.border_color = Color(0.2, 0.3, 0.4, 0.4)
			chip.add_theme_stylebox_override("panel", style)
			chip.tooltip_text = "[Ranura de Tomo %d] Vacía" % (slot_idx + 1)

		tome_slots_row.add_child(chip)

func update_weapon_cooldown_sweeps(equipped_weapons: Array, player_stats: Variant) -> void:
	if not weapon_slots_row:
		return
	var slots := weapon_slots_row.get_children()
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

func add_or_update_inventory_chip(item: ItemData, count: int) -> void:
	if not inventory_row:
		return

	var id: StringName = item.item_id
	if _inventory_chips.has(id):
		var chip: PanelContainer = _inventory_chips[id]
		var count_lbl := chip.get_node_or_null("Margin/CountLabel") as Label
		if count_lbl:
			count_lbl.text = "x%d" % count
		chip.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]
		return

	# Crear ficha de inventario de 32x32 px con icono de 24x24 px
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(32, 32)
	chip.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]

	var rarity_color := get_rarity_color(item.rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.9)
	style.set_border_width_all(1)
	style.border_color = rarity_color
	style.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", style)
	chip.modulate.a = 0.85

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.icon:
		icon_rect.texture = item.icon

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set("theme_override_constants/margin_left", 2)
	margin.set("theme_override_constants/margin_right", 2)
	margin.set("theme_override_constants/margin_top", 2)
	margin.set("theme_override_constants/margin_bottom", 2)

	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.text = "x%d" % count
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	count_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_lbl.add_theme_constant_override("shadow_offset_x", 1)
	count_lbl.add_theme_constant_override("shadow_offset_y", 1)
	count_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_END

	chip.add_child(icon_rect)
	margin.add_child(count_lbl)
	chip.add_child(margin)

	inventory_row.add_child(chip)
	_inventory_chips[id] = chip

func update_credits(amount: int, tree_ref: SceneTree = null) -> void:
	var diff: int = amount - current_credits
	current_credits = amount
	_refresh_economy_label()

	if diff > 0 and tree_ref and is_instance_valid(credit_icon) and credit_icon.is_inside_tree():
		if _credit_punch_tween and _credit_punch_tween.is_valid():
			_credit_punch_tween.kill()
		credit_icon.pivot_offset = credit_icon.size / 2.0
		_credit_punch_tween = tree_ref.create_tween()
		_credit_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.35, 1.35), 0.1)
		_credit_punch_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.0, 1.0), 0.16)

func update_biomass(_run_amount: int, total_persistent: int) -> void:
	current_biomass = total_persistent
	_refresh_economy_label()

func _refresh_economy_label() -> void:
	if credits_label:
		credits_label.text = "%d C" % current_credits
	if biomass_label:
		biomass_label.text = "%d" % current_biomass

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
