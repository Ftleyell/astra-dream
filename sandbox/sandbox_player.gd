extends Node2D

const ORBITAL_TERMINAL_SCENE = preload("res://scenes/ui/components/orbital_terminal/orbital_ignition_terminal.tscn")
const ORBITAL_ENV = preload("res://scenes/ui/components/orbital_terminal/orbital_environment.tres")

var orbital_terminal: OrbitalIgnitionTerminal = null
var hints_label: Label = null

func _ready() -> void:
	if has_node("Camera2D"):
		($Camera2D as Camera2D).position = Vector2.ZERO
	if has_node("Background"):
		($Background as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_crear_entorno_hdr()
	_crear_terminal_orbital()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			if is_instance_valid(orbital_terminal):
				orbital_terminal.reset_terminal()
		elif event.keycode == KEY_TAB:
			if is_instance_valid(orbital_terminal):
				orbital_terminal.grab_focus()

func _crear_entorno_hdr() -> void:
	if not has_node("WorldEnvironment"):
		var we := WorldEnvironment.new()
		we.name = "WorldEnvironment"
		we.environment = ORBITAL_ENV
		add_child(we)

func _crear_terminal_orbital() -> void:
	orbital_terminal = ORBITAL_TERMINAL_SCENE.instantiate() as OrbitalIgnitionTerminal
	orbital_terminal.name = "OrbitalIgnitionTerminal"
	# Centrado directamente en el viewport frente a la cámara (720x36)
	orbital_terminal.position = Vector2(-360.0, -18.0)
	orbital_terminal.ignition_committed.connect(_on_orbital_ignition_committed)
	add_child(orbital_terminal)

	hints_label = Label.new()
	hints_label.name = "TerminalHintsLabel"
	hints_label.text = "[TERMINAL ORBITAL DIEGÉTICA] • Hover: Escaneo / Shimmer • [TAB]: Fijación de Objetivo • Click / [SPACE]: Ignición • [R]: Reset"
	hints_label.add_theme_font_size_override("font_size", 13)
	hints_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95, 0.75))
	hints_label.position = Vector2(-360.0, 48.0)
	add_child(hints_label)

func _on_orbital_ignition_committed() -> void:
	print("[ORBITAL TERMINAL] >>> IGNICIÓN CONFIRMADA <<<")
