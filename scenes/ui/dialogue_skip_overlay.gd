class_name DialogueSkipOverlay
extends CanvasLayer

## Overlay that monitors active Dialogic timelines and allows skipping any dialogue
## sequence in its entirety by holding the Spacebar (or gamepad dialogue skip button).

signal skip_requested()

const HOLD_DURATION: float = 0.65

var current_hold: float = 0.0

@onready var margin_container: MarginContainer = $MarginContainer
@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var progress_bar: ProgressBar = $MarginContainer/PanelContainer/VBoxContainer/ProgressBar
@onready var prompt_label: Label = $MarginContainer/PanelContainer/VBoxContainer/PromptLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	hide()
	if progress_bar:
		progress_bar.value = 0.0
	if prompt_label:
		prompt_label.text = "Mantén [ESPACIO] para saltar"

	# Permitir clic directo con el ratón como vía accesible adicional
	if panel:
		panel.gui_input.connect(_on_panel_gui_input)

func _process(delta: float) -> void:
	# La animación de muerte de jefes no debe ser skipeable bajo ninguna circunstancia
	if CinematicDeathSequence.is_sequence_active:
		if visible:
			hide()
		current_hold = 0.0
		if progress_bar:
			progress_bar.value = 0.0
		return

	var is_dialogue_active: bool = false
	var dialogic = get_node_or_null("/root/Dialogic")
	if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
		is_dialogue_active = true

	var parent_game = get_tree().get_first_node_in_group("main_game")
	if parent_game and parent_game.has_method("is_cinematic_or_death_active") and parent_game.is_cinematic_or_death_active():
		is_dialogue_active = true

	if not is_dialogue_active:
		if visible:
			hide()
		current_hold = 0.0
		if progress_bar:
			progress_bar.value = 0.0
		return

	if not visible:
		show()

	# Detectar pulsación continua de la barra espaciadora o acción dialogue_skip
	var is_holding: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("dialogue_skip")
	if is_holding:
		current_hold += delta
		var progress: float = clampf(current_hold / HOLD_DURATION, 0.0, 1.0)
		if progress_bar:
			progress_bar.value = progress

		if current_hold >= HOLD_DURATION:
			current_hold = 0.0
			if progress_bar:
				progress_bar.value = 0.0
			_execute_skip()
	else:
		if current_hold > 0.0:
			current_hold = maxf(0.0, current_hold - delta * 4.0)
			if progress_bar:
				progress_bar.value = clampf(current_hold / HOLD_DURATION, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	# Consumir la tecla ESC durante el diálogo o cinemática para que no abra el menú de pausa accidentalmente
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var dialogic = get_node_or_null("/root/Dialogic")
		var is_dlg: bool = dialogic != null and "current_timeline" in dialogic and dialogic.current_timeline != null
		var parent_game = get_tree().get_first_node_in_group("main_game")
		var is_cine: bool = parent_game != null and parent_game.has_method("is_cinematic_or_death_active") and parent_game.is_cinematic_or_death_active()
		if is_dlg or is_cine or CinematicDeathSequence.is_sequence_active:
			get_viewport().set_input_as_handled()

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_execute_skip()

func _execute_skip() -> void:
	if CinematicDeathSequence.is_sequence_active:
		return

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 1.8, 1.2)

	skip_requested.emit()

	var dialogic: Node = get_node_or_null("/root/Dialogic")
	if dialogic and dialogic.has_method("end_timeline"):
		dialogic.end_timeline(true)

	hide()
