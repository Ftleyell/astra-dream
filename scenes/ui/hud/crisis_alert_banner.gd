class_name CrisisAlertBanner
extends CanvasLayer

## Banner de Alerta Holográfica de Crisis:
## Despliega una advertencia cyberpunk de 3 segundos previa al impacto del evento.
## Incluye efecto de parpadeo, conteo 3.. 2.. 1.. y alerta sonora.

signal alert_finished(crisis_id: String)

@onready var root_container: Control = $RootContainer
@onready var title_label: Label = $RootContainer/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $RootContainer/Panel/VBoxContainer/SubtitleLabel
@onready var countdown_label: Label = $RootContainer/Panel/VBoxContainer/CountdownLabel
@onready var panel: Panel = $RootContainer/Panel

var current_crisis_id: String = ""
var countdown_timer: float = 3.0
var is_active: bool = false

func _ready() -> void:
	layer = 25
	visible = false
	if root_container:
		root_container.modulate.a = 0.0

func show_crisis_alert(crisis_id: String, title: String, subtitle: String, tint_color: Color = Color(1.0, 0.35, 0.1)) -> void:
	current_crisis_id = crisis_id
	countdown_timer = 3.0
	is_active = true
	visible = true

	if title_label:
		title_label.text = "⚠ %s ⚠" % title.to_upper()
		title_label.modulate = tint_color
	if subtitle_label:
		subtitle_label.text = subtitle
	if countdown_label:
		countdown_label.text = "IMPACTO INMINENTE EN: 3"
		countdown_label.modulate = Color(1.0, 0.95, 0.4)

	# Animación de entrada
	root_container.modulate.a = 0.0
	root_container.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(root_container, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(root_container, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

	_play_alarm_sound(1.0)

func _process(delta: float) -> void:
	if not is_active:
		return

	var prev_second := int(ceilf(countdown_timer))
	countdown_timer -= delta
	var current_second := int(ceilf(countdown_timer))

	if current_second != prev_second and current_second > 0:
		if countdown_label:
			countdown_label.text = "IMPACTO INMINENTE EN: %d" % current_second
			# Pulso al cambiar de segundo
			var pulse := create_tween()
			pulse.tween_property(countdown_label, "scale", Vector2(1.2, 1.2), 0.1)
			pulse.tween_property(countdown_label, "scale", Vector2.ONE, 0.15)
		_play_alarm_sound(1.0 + (3.0 - current_second) * 0.2)

	if countdown_timer <= 0.0:
		_complete_alert()

func _complete_alert() -> void:
	is_active = false
	var tw := create_tween()
	tw.tween_property(root_container, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(root_container, "scale", Vector2(1.1, 0.9), 0.35)
	tw.tween_callback(func():
		visible = false
		alert_finished.emit(current_crisis_id)
	)

func _play_alarm_sound(pitch: float) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", pitch)
