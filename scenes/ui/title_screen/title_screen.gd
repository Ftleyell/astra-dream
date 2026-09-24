class_name TitleScreen
extends Control

## TitleScreen.gd
## Pantalla inicial de bienvenida del juego.
## Muestra el logo 'ASTRA: DREAM' y el prompt 'Toca cualquier tecla para continuar'.
## Permite abrir la ventana de Notas del Parche con el botón o la tecla N.
## Al recibir cualquier input principal, transiciona cinematográficamente hacia el Hub 3D.

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel
@onready var fade_rect: ColorRect = $FadeRect
@onready var patch_notes_btn: Button = get_node_or_null("PatchNotesButton") as Button
@onready var patch_notes_modal: CanvasLayer = get_node_or_null("PatchNotesModal") as CanvasLayer

var _is_transitioning: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	if fade_rect:
		fade_rect.modulate.a = 1.0
		fade_rect.visible = true
		var tw_in := create_tween()
		tw_in.tween_property(fade_rect, "modulate:a", 0.0, 0.45)
		tw_in.tween_callback(func(): fade_rect.visible = false)

	_start_prompt_pulse()

	if patch_notes_btn:
		patch_notes_btn.pressed.connect(open_patch_notes)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("menu")


func _start_prompt_pulse() -> void:
	if not prompt_label:
		return
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()

	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(prompt_label, "modulate:a", 0.25, 0.75).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	# Si la ventana de notas del parche está abierta, ignorar transición
	if patch_notes_modal and patch_notes_modal.visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_N:
			open_patch_notes()
			get_viewport().set_input_as_handled()
			return
		_trigger_continue()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		_trigger_continue()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.is_pressed():
		_trigger_continue()
		get_viewport().set_input_as_handled()


func open_patch_notes() -> void:
	if _is_transitioning:
		return
	if patch_notes_modal and patch_notes_modal.has_method("open_modal"):
		patch_notes_modal.call("open_modal")


func _trigger_continue() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()

	if prompt_label:
		prompt_label.modulate = Color(0.2, 1.0, 0.6, 1.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		var tw_out := create_tween()
		tw_out.tween_property(fade_rect, "modulate:a", 1.0, 0.35)
		tw_out.tween_callback(_go_to_hub)
	else:
		_go_to_hub()


func _go_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
