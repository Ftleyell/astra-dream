extends Node

## SettingsManager.gd
## Autoload encargado de cargar, aplicar y guardar la configuración del juego
## en 'user://settings.cfg' de forma persistente.

const SETTINGS_PATH := "user://settings.cfg"

var config: ConfigFile = ConfigFile.new()

# Valores por defecto
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.85
var resolution_size: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
var gamepad_deadzone: float = 0.15

signal settings_changed()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_and_apply_settings()

func load_and_apply_settings() -> void:
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		master_volume = config.get_value("audio", "master", 0.8)
		music_volume = config.get_value("audio", "music", 0.7)
		sfx_volume = config.get_value("audio", "sfx", 0.85)

		var w := int(config.get_value("display", "width", 1920))
		var h := int(config.get_value("display", "height", 1080))
		resolution_size = Vector2i(w, h)
		fullscreen = bool(config.get_value("display", "fullscreen", false))

		gamepad_deadzone = float(config.get_value("controller", "deadzone", 0.15))

		_load_keybindings_from_config()
	else:
		# Guardar defaults si no existe
		save_all_settings()

	apply_all_settings()

func apply_all_settings() -> void:
	# 1. Aplicar Audio
	set_bus_volume("Master", master_volume)
	set_bus_volume("Music", music_volume)
	set_bus_volume("SFX", sfx_volume)

	# 2. Aplicar Pantalla
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution_size)
		# Centrar ventana si es posible
		var screen_center := DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
		DisplayServer.window_set_position(screen_center - resolution_size / 2)

	settings_changed.emit()

func set_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db_val := linear_to_db(linear_val) if linear_val > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(idx, db_val)
		AudioServer.set_bus_mute(idx, linear_val <= 0.0001)

func save_audio_settings(p_master: float, p_music: float, p_sfx: float) -> void:
	master_volume = p_master
	music_volume = p_music
	sfx_volume = p_sfx
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)
	set_bus_volume("Master", master_volume)
	set_bus_volume("Music", music_volume)
	set_bus_volume("SFX", sfx_volume)
	settings_changed.emit()

func save_display_settings(p_res: Vector2i, p_fullscreen: bool) -> void:
	resolution_size = p_res
	fullscreen = p_fullscreen
	config.set_value("display", "width", resolution_size.x)
	config.set_value("display", "height", resolution_size.y)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
	apply_all_settings()

func save_deadzone_setting(p_deadzone: float) -> void:
	gamepad_deadzone = p_deadzone
	config.set_value("controller", "deadzone", gamepad_deadzone)
	config.save(SETTINGS_PATH)
	settings_changed.emit()

func save_keybinding(action_name: StringName, event: InputEvent) -> void:
	# Modificar InputMap conservando joypad events
	var old_events := InputMap.action_get_events(action_name)
	var preserved_events: Array[InputEvent] = []
	for ev in old_events:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			preserved_events.append(ev)

	InputMap.action_erase_events(action_name)
	for ev in preserved_events:
		InputMap.action_add_event(action_name, ev)
	InputMap.action_add_event(action_name, event)

	# Serializar evento de teclado/ratón a ConfigFile
	if event is InputEventKey:
		config.set_value("keybindings", String(action_name), {
			"type": "key",
			"keycode": int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		})
	elif event is InputEventMouseButton:
		config.set_value("keybindings", String(action_name), {
			"type": "mouse",
			"button_index": event.button_index
		})
	config.save(SETTINGS_PATH)
	settings_changed.emit()

func _load_keybindings_from_config() -> void:
	if not config.has_section("keybindings"):
		return
	for act_str in config.get_section_keys("keybindings"):
		var act_name := StringName(act_str)
		if not InputMap.has_action(act_name):
			continue
		var val = config.get_value("keybindings", act_str)
		if val is Dictionary:
			var ev_type = val.get("type", "")
			var new_event: InputEvent = null
			if ev_type == "key":
				var k := InputEventKey.new()
				k.keycode = val.get("keycode", 0)
				k.physical_keycode = val.get("keycode", 0)
				new_event = k
			elif ev_type == "mouse":
				var m := InputEventMouseButton.new()
				m.button_index = val.get("button_index", 1)
				new_event = m

			if new_event:
				# Reasignar conservando gamepad
				var old_events := InputMap.action_get_events(act_name)
				var preserved: Array[InputEvent] = []
				for ev in old_events:
					if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
						preserved.append(ev)
				InputMap.action_erase_events(act_name)
				for ev in preserved:
					InputMap.action_add_event(act_name, ev)
				InputMap.action_add_event(act_name, new_event)

func save_all_settings() -> void:
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "width", resolution_size.x)
	config.set_value("display", "height", resolution_size.y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("controller", "deadzone", gamepad_deadzone)
	config.save(SETTINGS_PATH)

func set_audio_volume(bus_name: String, linear_val: float) -> void:
	match bus_name.to_lower():
		"master": master_volume = linear_val
		"music": music_volume = linear_val
		"sfx": sfx_volume = linear_val
	save_audio_settings(master_volume, music_volume, sfx_volume)

func get_audio_volume(bus_name: String) -> float:
	match bus_name.to_lower():
		"master": return master_volume
		"music": return music_volume
		"sfx": return sfx_volume
	return 1.0

func set_deadzone(p_deadzone: float) -> void:
	save_deadzone_setting(p_deadzone)

func get_deadzone() -> float:
	return gamepad_deadzone

func set_fullscreen(p_full: bool) -> void:
	save_display_settings(resolution_size, p_full)

func is_fullscreen() -> bool:
	return fullscreen

func set_resolution(p_res: Vector2i) -> void:
	save_display_settings(p_res, fullscreen)

func get_resolution() -> Vector2i:
	return resolution_size

func save_settings() -> Error:
	save_all_settings()
	return OK

func load_settings() -> void:
	load_and_apply_settings()
