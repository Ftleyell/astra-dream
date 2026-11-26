class_name HoldToResetOverlay
extends CanvasLayer

const HOLD_DURATION: float = 1.2

var current_hold: float = 0.0

@onready var backdrop: ColorRect = $Backdrop
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	backdrop.color.a = 0.0
	progress_bar.value = 0.0

func _process(delta: float) -> void:
	var cur_scene: Node = get_tree().current_scene if get_tree() != null else null
	if cur_scene != null and ((cur_scene.has_method("is_hub_mode_active") and cur_scene.is_hub_mode_active()) or (cur_scene.has_method("is_title_or_materializing_active") and cur_scene.is_title_or_materializing_active())):
		if visible:
			current_hold = 0.0
			hide()
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	# Comprobar si se mantiene presionada la tecla R
	if Input.is_key_pressed(KEY_R):
		if not visible:
			show()
		current_hold += delta
		var progress: float = clampf(current_hold / HOLD_DURATION, 0.0, 1.0)
		backdrop.color.a = progress * 0.96
		progress_bar.value = progress

		if current_hold >= HOLD_DURATION:
			_execute_reset()
	else:
		if current_hold > 0.0:
			# Desvanecimiento rápido si se suelta antes de tiempo
			current_hold = maxf(0.0, current_hold - delta * 3.5)
			var progress: float = clampf(current_hold / HOLD_DURATION, 0.0, 1.0)
			backdrop.color.a = progress * 0.96
			progress_bar.value = progress
			if current_hold <= 0.0:
				hide()

func _execute_reset() -> void:
	PauseArbitrator.force_unpause_all()
	get_tree().reload_current_scene()
