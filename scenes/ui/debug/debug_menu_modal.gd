class_name DebugMenuModal
extends CanvasLayer

## Modal de Depuración y Trampas para el Menú de Despliegue.
## Totalmente navegable con WASD y flechas.
## En los campos de entrada numéricos, [ESPACIO] confirma y fija el valor emulando [ENTER].

signal closed()

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

@onready var modal_panel: PanelContainer = $CenterContainer/MainPanel
@onready var infinite_hp_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/HpCheck
@onready var infinite_credits_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/CreditsCheck
@onready var infinite_consumables_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/ConsumablesCheck

@onready var stats_container: VBoxContainer = $CenterContainer/MainPanel/Margin/VBox/StatsScroll/StatsList
@onready var reset_button: Button = $CenterContainer/MainPanel/Margin/VBox/ActionsRow/ResetButton
@onready var close_button: Button = $CenterContainer/MainPanel/Margin/VBox/ActionsRow/CloseButton

var current_pilot_data: CharacterData = null
var _stat_controls: Dictionary = {} # stat_name -> { "slider": HSlider, "input": LineEdit, "config": Dictionary }
var is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	hide()

	if infinite_hp_check:
		infinite_hp_check.toggled.connect(_on_infinite_hp_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_hp_check)

	if infinite_credits_check:
		infinite_credits_check.toggled.connect(_on_infinite_credits_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_credits_check)

	if infinite_consumables_check:
		infinite_consumables_check.toggled.connect(_on_infinite_consumables_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_consumables_check)

	if reset_button:
		reset_button.pressed.connect(reset_to_defaults)
		UIFocusHelper.apply_cyber_focus(reset_button)

	if close_button:
		close_button.pressed.connect(close_menu)
		UIFocusHelper.apply_cyber_focus(close_button)

	_build_stats_ui()
	_setup_focus_chain()

func open_menu(pilot_data: CharacterData = null) -> void:
	current_pilot_data = pilot_data
	is_open = true
	show()

	# Cargar estado actual de DebugManager
	if infinite_hp_check:
		infinite_hp_check.set_pressed_no_signal(DebugManager.infinite_hp)
	if infinite_credits_check:
		infinite_credits_check.set_pressed_no_signal(DebugManager.infinite_credits)
	if infinite_consumables_check:
		infinite_consumables_check.set_pressed_no_signal(DebugManager.infinite_consumables)

	_refresh_stats_display()

	if infinite_hp_check:
		infinite_hp_check.grab_focus()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_menu()
		return
	get_viewport().set_input_as_handled()

func _build_stats_ui() -> void:
	if not stats_container:
		return

	for child in stats_container.get_children():
		child.queue_free()
	_stat_controls.clear()

	for stat_name in DebugManager.STAT_CONFIGS.keys():
		var cfg: Dictionary = DebugManager.STAT_CONFIGS[stat_name]
		var row := HBoxContainer.new()
		row.name = "Row_" + String(stat_name)
		row.custom_minimum_size = Vector2(0, 36)
		row.add_theme_constant_override("separation", 16)

		# 1. Etiqueta con nombre amigable
		var lbl := Label.new()
		lbl.text = cfg.name
		lbl.custom_minimum_size = Vector2(240, 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		row.add_child(lbl)

		# 2. Slider horizontal
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(360, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = cfg.min
		slider.max_value = cfg.max
		slider.step = cfg.step
		slider.value = cfg.default
		UIFocusHelper.apply_cyber_focus(slider)
		row.add_child(slider)

		# 3. Input numérico LineEdit
		var line_edit := LineEdit.new()
		line_edit.custom_minimum_size = Vector2(120, 32)
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.text = cfg.format % cfg.default
		UIFocusHelper.apply_cyber_focus(line_edit)
		row.add_child(line_edit)

		# Sincronización Slider -> Input & DebugManager
		slider.value_changed.connect(func(val: float):
			line_edit.text = cfg.format % val
			DebugManager.set_stat_override(stat_name, val)
		)

		# Sincronización Input -> Slider & DebugManager (Enter y Barra Espaciadora)
		line_edit.text_submitted.connect(func(txt: String):
			_commit_input_value(stat_name, line_edit, slider, cfg)
		)

		# Capturar la Barra Espaciadora en el LineEdit para fijar el valor como si fuera Enter
		line_edit.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and not ev.echo:
				if ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
					_commit_input_value(stat_name, line_edit, slider, cfg)
					get_viewport().set_input_as_handled()
		)

		stats_container.add_child(row)
		_stat_controls[stat_name] = {
			"slider": slider,
			"input": line_edit,
			"config": cfg
		}

func _commit_input_value(stat_name: StringName, line_edit: LineEdit, slider: HSlider, cfg: Dictionary) -> void:
	var clean_text := line_edit.text.strip_edges()
	var val: float = clean_text.to_float()
	val = clampf(val, cfg.min, cfg.max)

	slider.set_value_no_signal(val)
	line_edit.text = cfg.format % val
	DebugManager.set_stat_override(stat_name, val)

	# Feedback sonoro sutil
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.5, 1.4)

	# Destello visual en el LineEdit para confirmar la fijación del valor
	var tw := create_tween()
	tw.tween_property(line_edit, "modulate", Color(0.2, 1.0, 0.4, 1.0), 0.08)
	tw.tween_property(line_edit, "modulate", Color.WHITE, 0.15)

func _refresh_stats_display() -> void:
	for stat_name in _stat_controls.keys():
		var ctrl: Dictionary = _stat_controls[stat_name]
		var slider: HSlider = ctrl.slider
		var input: LineEdit = ctrl.input
		var cfg: Dictionary = ctrl.config

		var default_val: float = cfg.default
		if current_pilot_data and stat_name in current_pilot_data:
			default_val = float(current_pilot_data.get(stat_name))

		var current_val: float = DebugManager.get_stat_override(stat_name, default_val)
		slider.set_value_no_signal(current_val)
		input.text = cfg.format % current_val

func _setup_focus_chain() -> void:
	# Enlace de navegación WASD completo entre Toggles, Sliders, Inputs y Botones
	if infinite_hp_check and infinite_credits_check and infinite_consumables_check:
		infinite_hp_check.focus_neighbor_right = infinite_credits_check.get_path()
		infinite_credits_check.focus_neighbor_left = infinite_hp_check.get_path()
		infinite_credits_check.focus_neighbor_right = infinite_consumables_check.get_path()
		infinite_consumables_check.focus_neighbor_left = infinite_credits_check.get_path()

	var stat_keys := _stat_controls.keys()
	if stat_keys.is_empty():
		return

	var first_stat: StringName = stat_keys[0]
	var last_stat: StringName = stat_keys[-1]
	var first_ctrl: Dictionary = _stat_controls[first_stat]
	var last_ctrl: Dictionary = _stat_controls[last_stat]

	if infinite_hp_check:
		infinite_hp_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_credits_check:
		infinite_credits_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_consumables_check:
		infinite_consumables_check.focus_neighbor_bottom = first_ctrl.input.get_path()

	for i in range(stat_keys.size()):
		var s_name: StringName = stat_keys[i]
		var ctrl: Dictionary = _stat_controls[s_name]
		var slider: HSlider = ctrl.slider
		var input: LineEdit = ctrl.input

		# Izquierda / Derecha dentro de la fila
		slider.focus_neighbor_right = input.get_path()
		input.focus_neighbor_left = slider.get_path()

		# Arriba
		if i > 0:
			var prev_ctrl: Dictionary = _stat_controls[stat_keys[i - 1]]
			slider.focus_neighbor_top = prev_ctrl.slider.get_path()
			input.focus_neighbor_top = prev_ctrl.input.get_path()
		else:
			slider.focus_neighbor_top = infinite_hp_check.get_path()
			input.focus_neighbor_top = infinite_consumables_check.get_path()

		# Abajo
		if i < stat_keys.size() - 1:
			var next_ctrl: Dictionary = _stat_controls[stat_keys[i + 1]]
			slider.focus_neighbor_bottom = next_ctrl.slider.get_path()
			input.focus_neighbor_bottom = next_ctrl.input.get_path()
		else:
			slider.focus_neighbor_bottom = reset_button.get_path()
			input.focus_neighbor_bottom = close_button.get_path()

	if reset_button and close_button:
		reset_button.focus_neighbor_top = last_ctrl.slider.get_path()
		reset_button.focus_neighbor_right = close_button.get_path()
		close_button.focus_neighbor_top = last_ctrl.input.get_path()
		close_button.focus_neighbor_left = reset_button.get_path()

func reset_to_defaults() -> void:
	DebugManager.stat_overrides.clear()
	_refresh_stats_display()
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)

func _on_infinite_hp_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_hp = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_credits_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_credits = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_consumables_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_consumables = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true
