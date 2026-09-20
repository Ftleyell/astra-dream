class_name SettingsModal
extends CanvasLayer

@onready var master_slider: HSlider = $Panel/VBoxContainer/AudioGrid/MasterSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/AudioGrid/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/AudioGrid/SfxSlider
@onready var fullscreen_check: CheckBox = $Panel/VBoxContainer/DisplayRow/FullscreenCheck
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_button.pressed.connect(hide)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	master_slider.value_changed.connect(func(v): _set_bus_volume("Master", v))
	music_slider.value_changed.connect(func(v): _set_bus_volume("Music", v))
	sfx_slider.value_changed.connect(func(v): _set_bus_volume("SFX", v))

	# Cargar estado actual de pantalla completa
	var mode := DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func open_settings() -> void:
	show()

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if value <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			# Conversión de porcentaje lineal (0..1) a decibelios (-40 dB .. 0 dB)
			var db := linear_to_db(value)
			AudioServer.set_bus_volume_db(bus_idx, db)
