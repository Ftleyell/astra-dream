class_name UIFocusHelper
extends RefCounted

static var cyber_focus_style: StyleBox = preload("res://assets/ui/styles/ui_focus_cyber_border.tres")

## Aplica el estilo neón cyberpunk de foco, escalado interactivo y sonido al navegar con ASDW
static func apply_cyber_focus(control: Control, play_sound: bool = true) -> void:
	if not control:
		return

	if control is Button:
		control.add_theme_stylebox_override("focus", cyber_focus_style)
	else:
		control.focus_mode = Control.FOCUS_ALL

	control.pivot_offset = control.size * 0.5
	if not control.resized.is_connected(_update_pivot.bind(control)):
		control.resized.connect(_update_pivot.bind(control))

	if not control.focus_entered.is_connected(_on_focus_entered.bind(control, play_sound)):
		control.focus_entered.connect(_on_focus_entered.bind(control, play_sound))

	if not control.focus_exited.is_connected(_on_focus_exited.bind(control)):
		control.focus_exited.connect(_on_focus_exited.bind(control))

static func _update_pivot(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5

static func _on_focus_entered(control: Control, play_sound: bool) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if play_sound:
		var audio_mgr := control.get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")

static func _on_focus_exited(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
