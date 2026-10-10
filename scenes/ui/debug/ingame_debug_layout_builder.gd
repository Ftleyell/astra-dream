class_name IngameDebugLayoutBuilder
extends RefCounted

## IngameDebugLayoutBuilder.gd
## Construye y desacopla la generación procedimental de filas de configuración
## y widgets interactivos para IngameDebugModal (sliders de stats, armas y botones de oleadas).

const UIFocusHelperScript = preload("res://core/utils/ui_focus_helper.gd")


static func populate_stats_sliders(
	parent_container: VBoxContainer,
	stat_sliders_dict: Dictionary,
	stat_configs: Dictionary,
	on_value_changed_callback: Callable
) -> void:
	if not parent_container or not stat_sliders_dict.is_empty():
		return

	for stat_name in stat_configs.keys():
		var cfg: Dictionary = stat_configs[stat_name]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var lbl := Label.new()
		lbl.text = String(cfg.get("name", str(stat_name)))
		lbl.custom_minimum_size = Vector2(170, 24)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = float(cfg.get("min", 0.0))
		slider.max_value = float(cfg.get("max", 100.0))
		slider.step = float(cfg.get("step", 1.0))
		slider.value = float(cfg.get("default", 0.0))
		slider.custom_minimum_size = Vector2(200, 24)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(60, 24)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 12)
		var fmt: String = String(cfg.get("format", "%.1f"))
		val_lbl.text = fmt % slider.value
		row.add_child(val_lbl)

		var current_stat: StringName = stat_name
		slider.value_changed.connect(func(new_val: float):
			val_lbl.text = fmt % new_val
			if on_value_changed_callback.is_valid():
				on_value_changed_callback.call(current_stat, new_val)
		)

		stat_sliders_dict[stat_name] = { "slider": slider, "label": val_lbl }
		parent_container.add_child(row)


static func populate_weapon_buttons(
	parent_grid: GridContainer,
	available_weapons: Array[Dictionary],
	on_inject_callback: Callable
) -> void:
	if not parent_grid:
		return

	for wep in available_weapons:
		var btn := Button.new()
		btn.text = "+ " + String(wep.get("name", "Arma"))
		btn.custom_minimum_size = Vector2(180, 36)
		btn.add_theme_font_size_override("font_size", 12)
		var wep_path: String = String(wep.get("path", ""))
		var wep_name: String = String(wep.get("name", ""))
		btn.pressed.connect(func():
			if on_inject_callback.is_valid():
				on_inject_callback.call(wep_path, wep_name)
		)
		UIFocusHelperScript.apply_cyber_focus(btn)
		parent_grid.add_child(btn)


static func populate_wave_jump_buttons(
	parent_container: HBoxContainer,
	milestone_waves: Array[int],
	on_jump_callback: Callable
) -> void:
	if not parent_container:
		return

	for w in milestone_waves:
		var btn := Button.new()
		btn.text = "Oleada %d" % w
		btn.custom_minimum_size = Vector2(85, 34)
		btn.add_theme_font_size_override("font_size", 12)
		var wave_num: int = w
		btn.pressed.connect(func():
			if on_jump_callback.is_valid():
				on_jump_callback.call(wave_num)
		)
		UIFocusHelperScript.apply_cyber_focus(btn)
		parent_container.add_child(btn)
