class_name SettingsModal
extends CanvasLayer

signal closed

@onready var master_slider: HSlider = $Panel/VBoxContainer/TabContainer/Pantalla_Audio/VBox/AudioGrid/MasterSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/TabContainer/Pantalla_Audio/VBox/AudioGrid/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/TabContainer/Pantalla_Audio/VBox/AudioGrid/SfxSlider
@onready var resolution_option: OptionButton = $Panel/VBoxContainer/TabContainer/Pantalla_Audio/VBox/DisplayGrid/ResolutionOption
@onready var fullscreen_check: CheckBox = $Panel/VBoxContainer/TabContainer/Pantalla_Audio/VBox/DisplayGrid/FullscreenCheck

@onready var kb_rebind_container: VBoxContainer = $Panel/VBoxContainer/TabContainer/Teclado_Raton/ScrollContainer/RebindList
@onready var deadzone_slider: HSlider = $Panel/VBoxContainer/TabContainer/Mando_Joystick/VBox/DeadzoneRow/DeadzoneSlider
@onready var deadzone_label: Label = $Panel/VBoxContainer/TabContainer/Mando_Joystick/VBox/DeadzoneRow/DeadzoneValue
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var rebind_popup: Panel = $RebindPopup
@onready var rebind_prompt: Label = $RebindPopup/VBox/PromptLabel

var rebind_action: StringName = &""
var is_rebinding: bool = false

var resolutions: Array[Dictionary] = [
	{ "name": "1920 × 1080 (16:9 Full HD)", "size": Vector2i(1920, 1080) },
	{ "name": "2560 × 1440 (16:9 QHD / 2K)", "size": Vector2i(2560, 1440) },
	{ "name": "3840 × 2160 (16:9 4K UHD)", "size": Vector2i(3840, 2160) },
	{ "name": "1280 × 720 (16:9 HD)", "size": Vector2i(1280, 720) },
	{ "name": "2560 × 1080 (21:9 Ultrawide)", "size": Vector2i(2560, 1080) },
	{ "name": "3440 × 1440 (21:9 UWQHD)", "size": Vector2i(3440, 1440) },
	{ "name": "1920 × 1200 (16:10 WUXGA)", "size": Vector2i(1920, 1200) },
	{ "name": "1280 × 800 (16:10 Steam Deck)", "size": Vector2i(1280, 800) },
	{ "name": "1366 × 768 (16:9 Laptop)", "size": Vector2i(1366, 768) }
]

var actions_to_rebind: Array[Dictionary] = [
	{ "action": &"move_up", "label": "Mover Arriba" },
	{ "action": &"move_down", "label": "Mover Abajo" },
	{ "action": &"move_left", "label": "Mover Izquierda" },
	{ "action": &"move_right", "label": "Mover Derecha" },
	{ "action": &"fire_active", "label": "Disparo Activo (Láser)" },
	{ "action": &"toggle_aim_mode", "label": "Alternar Apuntado Pasivo (Auto/Manual)" },
	{ "action": &"dash", "label": "Dash (Invulnerabilidad)" },
	{ "action": &"bomb", "label": "Bomba de Pantalla" },
	{ "action": &"dialogue_skip", "label": "Saltar Diálogo" }
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60 # Asegura estar siempre por encima del menú de pausa (layer 50) y modales (layer 30/20)
	hide()
	rebind_popup.hide()

	close_button.pressed.connect(close_settings)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)

	master_slider.value_changed.connect(func(v): _on_volume_slider_changed("Master", v))
	music_slider.value_changed.connect(func(v): _on_volume_slider_changed("Music", v))
	sfx_slider.value_changed.connect(func(v): _on_volume_slider_changed("SFX", v))

	deadzone_slider.value_changed.connect(_on_deadzone_changed)

	_sync_ui_with_settings_manager()
	_init_resolutions()
	_populate_rebind_list()

	UIFocusHelper.apply_cyber_focus(close_button)
	UIFocusHelper.apply_cyber_focus(fullscreen_check)
	UIFocusHelper.apply_cyber_focus(resolution_option)
	UIFocusHelper.apply_cyber_focus(master_slider)
	UIFocusHelper.apply_cyber_focus(music_slider)
	UIFocusHelper.apply_cyber_focus(sfx_slider)
	UIFocusHelper.apply_cyber_focus(deadzone_slider)

func _sync_ui_with_settings_manager() -> void:
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr:
		master_slider.value = mgr.master_volume
		music_slider.value = mgr.music_volume
		sfx_slider.value = mgr.sfx_volume
		fullscreen_check.button_pressed = mgr.fullscreen
		deadzone_slider.value = mgr.gamepad_deadzone
		deadzone_label.text = "%.2f" % mgr.gamepad_deadzone
	else:
		var mode := DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func open_settings() -> void:
	show()
	_sync_ui_with_settings_manager()
	_init_resolutions()
	_populate_rebind_list()
	close_button.grab_focus()

func close_settings() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	closed.emit()

func _init_resolutions() -> void:
	resolution_option.clear()
	var cur_size: Vector2i = DisplayServer.window_get_size()
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr:
		cur_size = mgr.resolution_size
	var selected_idx := 0

	for i in range(resolutions.size()):
		var r: Dictionary = resolutions[i]
		resolution_option.add_item(r["name"], i)
		if cur_size == r["size"]:
			selected_idx = i

	resolution_option.select(selected_idx)

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < resolutions.size():
		var new_size: Vector2i = resolutions[index]["size"]
		var is_fs: bool = fullscreen_check.button_pressed
		var mgr = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.save_display_settings(new_size, is_fs)
		else:
			DisplayServer.window_set_size(new_size)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	var sel_idx: int = resolution_option.selected
	var cur_res: Vector2i = resolutions[sel_idx]["size"] if (sel_idx >= 0 and sel_idx < resolutions.size()) else Vector2i(1920, 1080)
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr:
		mgr.save_display_settings(cur_res, button_pressed)
	else:
		if button_pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_slider_changed(bus_name: String, value: float) -> void:
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr:
		var m_val: float = master_slider.value
		var mu_val: float = music_slider.value
		var s_val: float = sfx_slider.value
		mgr.save_audio_settings(m_val, mu_val, s_val)
	else:
		_set_bus_volume(bus_name, value)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if value <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db := linear_to_db(value)
			AudioServer.set_bus_volume_db(bus_idx, db)

func _on_deadzone_changed(val: float) -> void:
	deadzone_label.text = "%.2f" % val
	for entry in actions_to_rebind:
		var act: StringName = entry["action"]
		InputMap.action_set_deadzone(act, val)
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr:
		mgr.save_deadzone_setting(val)

func _populate_rebind_list() -> void:
	for child in kb_rebind_container.get_children():
		child.queue_free()

	for entry in actions_to_rebind:
		var act: StringName = entry["action"]
		var label_str: String = entry["label"]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var name_lbl := Label.new()
		name_lbl.text = label_str
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_str := _get_action_key_text(act)
		var key_lbl := Label.new()
		key_lbl.text = "[ %s ]" % key_str
		key_lbl.modulate = Color(0.4, 0.9, 1.0, 1.0)
		key_lbl.custom_minimum_size = Vector2(140, 0)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var btn := Button.new()
		btn.text = "Reasignar"
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(func(): _start_rebind(act, label_str))

		row.add_child(name_lbl)
		row.add_child(key_lbl)
		row.add_child(btn)
		kb_rebind_container.add_child(row)

func _get_action_key_text(act: StringName) -> String:
	var events := InputMap.action_get_events(act)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "Clic Izquierdo"
				MOUSE_BUTTON_RIGHT: return "Clic Derecho"
				MOUSE_BUTTON_MIDDLE: return "Clic Central"
				_: return "Ratón %d" % ev.button_index
	return "No asignado"

func _start_rebind(act: StringName, label_str: String) -> void:
	rebind_action = act
	is_rebinding = true
	rebind_prompt.text = "Presiona una tecla o clic del ratón para:\n'%s'\n\n(Presiona ESC para cancelar)" % label_str
	rebind_popup.show()

func _input(event: InputEvent) -> void:
	if is_rebinding:
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_cancel_rebind()
				return
			_apply_rebind(event)
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_apply_rebind(event)
		return

	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_settings()

func _apply_rebind(new_event: InputEvent) -> void:
	if rebind_action != &"":
		# Eliminar eventos de teclado/ratón previos de esa acción (conservando los de gamepad)
		var old_events := InputMap.action_get_events(rebind_action)
		var preserved_events: Array[InputEvent] = []
		for ev in old_events:
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				preserved_events.append(ev)

		InputMap.action_erase_events(rebind_action)
		for ev in preserved_events:
			InputMap.action_add_event(rebind_action, ev)

		# Agregar el nuevo evento asignado
		InputMap.action_add_event(rebind_action, new_event)

		var mgr = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.save_keybinding(rebind_action, new_event)

	_cancel_rebind()
	_populate_rebind_list()

func _cancel_rebind() -> void:
	is_rebinding = false
	rebind_action = &""
	rebind_popup.hide()
