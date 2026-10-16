class_name HUDInventoryBarController
extends RefCounted

const TomeDataScript = preload("res://data/tomes/tome_data.gd")

## HUDInventoryBarController.gd
## Controlador especializado para el inventario in-run en el HUD:
## - Ranuras de tomos equipados con niveles y tooltips.
## - Fichas de ítems pasivos coleccionados con contador de acumulaciones.

var tome_slots_row: HBoxContainer
var inventory_row: HBoxContainer

var _inventory_chips: Dictionary[StringName, PanelContainer] = {}

func setup(elements: Dictionary) -> void:
	tome_slots_row = elements.get("tome_slots_row") as HBoxContainer
	inventory_row = elements.get("inventory_row") as HBoxContainer

func get_inventory_chips() -> Dictionary[StringName, PanelContainer]:
	return _inventory_chips


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
