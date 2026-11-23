class_name WorkbenchUIKit
extends RefCounted
## Kit UI compartido para construir paneles laterales sci-fi uniformes en Workbenches y Combat Gym.


static func create_panel_layer(
	parent: Node,
	title_text: String,
	hint_text: String,
	panel_width: float = 320.0,
	anchor_right_side: bool = true,
	layer_index: int = 80
) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "WorkbenchPanelLayer"
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "WorkbenchControlPanel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if anchor_right_side:
		panel.anchor_left = 1.0
		panel.anchor_top = 0.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -10.0 - panel_width
		panel.offset_top = 10.0
		panel.offset_right = -10.0
		panel.offset_bottom = -10.0
	else:
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 10.0
		panel.offset_top = 10.0
		panel.offset_right = 10.0 + panel_width
		panel.offset_bottom = -10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.11, 0.88)
	style.border_color = Color(0.18, 0.85, 0.98, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(root_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.28, 0.92, 1.0, 1.0))
	header.add_child(title)

	var toggle_btn := Button.new()
	toggle_btn.text = "[H] Ocultar"
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.add_theme_font_size_override("font_size", 11)
	header.add_child(toggle_btn)

	var hint := Label.new()
	hint.text = hint_text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90, 0.85))
	root_vbox.add_child(hint)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72, 0.95))
	root_vbox.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	toggle_btn.pressed.connect(func() -> void:
		panel.visible = not panel.visible
	)

	return {
		"layer": layer,
		"panel": panel,
		"vbox": vbox,
		"toggle_btn": toggle_btn,
		"status_label": status_label,
	}


static func add_section(vbox: VBoxContainer, title: String) -> Label:
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.62, 1.0))
	vbox.add_child(lbl)
	return lbl


static func add_button(vbox: VBoxContainer, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(callback)
	vbox.add_child(btn)
	return btn


static func add_button_row(vbox: VBoxContainer, specs: Array[Dictionary]) -> Array[Button]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vbox.add_child(row)
	var created: Array[Button] = []
	for spec: Dictionary in specs:
		var btn := Button.new()
		btn.text = str(spec.get("text", "Btn"))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11)
		var cb: Variant = spec.get("cb", Callable())
		if cb is Callable and (cb as Callable).is_valid():
			btn.pressed.connect(cb as Callable)
		row.add_child(btn)
		created.append(btn)
	return created


static func add_slider(
	vbox: VBoxContainer,
	label_text: String,
	min_val: float,
	max_val: float,
	step_val: float,
	initial: float,
	callback: Callable
) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(96.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(48.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.text = "%.2f" % initial if step_val < 1.0 else "%d" % int(roundf(initial))
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v if step_val < 1.0 else "%d" % int(roundf(v))
		if callback.is_valid():
			callback.call(v)
	)

	return {
		"slider": slider,
		"label": lbl,
		"value_label": val_lbl,
	}


static func add_option(
	vbox: VBoxContainer,
	label_text: String,
	items: Array[String],
	callback: Callable
) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.focus_mode = Control.FOCUS_NONE
	opt.add_theme_font_size_override("font_size", 11)
	for item_str: String in items:
		opt.add_item(item_str)
	opt.item_selected.connect(func(idx: int) -> void:
		if callback.is_valid():
			callback.call(idx, opt.get_item_text(idx))
	)
	row.add_child(opt)
	return opt


static func add_check(
	vbox: VBoxContainer,
	label_text: String,
	initial: bool,
	callback: Callable
) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 11)
	cb.toggled.connect(func(pressed: bool) -> void:
		if callback.is_valid():
			callback.call(pressed)
	)
	vbox.add_child(cb)
	return cb


static func add_readout(vbox: VBoxContainer, initial_text: String = "") -> Label:
	var lbl := Label.new()
	lbl.text = initial_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96, 0.92))
	vbox.add_child(lbl)
	return lbl
